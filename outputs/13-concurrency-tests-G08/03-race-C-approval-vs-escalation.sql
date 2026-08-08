/* ===========================================================================
   Task 13 — Race C: Approval vs. Maintenance Escalation (deadlock risk)
   File     : outputs/13-concurrency-tests-G08/03-race-C-approval-vs-escalation.sql
   Target   : Microsoft SQL Server 2016 SP1+ (SSMS dual-window methodology)
   Design   : outputs/11-concurrency-design-G08.md §II.3 (Race C), §III.5
   Contract : outputs/11-concurrency-design-G08.md §VI (C1, C4, C5, C6)

   ---------------------------------------------------------------------------
   RACE C  —  A Pending booking on space T13-T-CLS (T13-C-BOOKING,
   window 10:00-12:00) is being approved by staff WHILE Facility staff
   simultaneously escalates the space's ADVISORY maintenance record
   (T13 Race C advisory) to OutOfService.
      * Without a lock-ordering rule, approval walks bookings -> maintenance
        and escalation walks maintenance -> bookings: a deadlock cycle, or an
        approval that silently slips past an escalated OutOfService window.
      * With the Task 12 lock-order rule, BOTH procedures acquire the
        bookings range FIRST (C4), so they serialize on the same resource
        instead of forming a lock loop.

   HOW TO RUN (dual-window SSMS):
     0. Load 00-setup-test-data.sql FIRST.
     1. PART A (BASELINE) — both sides raw, trigger-only:
          Window 1: Session A (approve T13-C-BOOKING via raw UPDATE) holds ~5s.
          Window 2: Session B (escalate advisory -> OutOfService via raw
                    UPDATE) during A's wait.
          VERIFY: both operations completed — the advisory record is now
                  OutOfService AND the overlapping booking is Approved
                  (the escalate raced in after the check).
        PART B (PREVENTION) — same collision via the procedures:
          1) Window 1: Session A (usp_ApproveBooking on T13-C-BOOKING).
             Window 2: Session B (usp_EscalateMaintenance) during A's wait.
             Expected: B blocks behind A's bookings-range lock (lock-order
             C4); A publishes first; B's escalation then succeeds and the
             trigger TR_maintenance_escalation writes ONE booking_alerts row
             (MaintenanceEscalated) for the now-Approved booking.
             If instead B escalates BEFORE A's approval, A re-reads under
             SERIALIZABLE and THROWs 50002 (OutOfService overlap).
             Either branch is legal (Task 11 A.2: escalation identifies,
             not rewrites). The rule being validated is "no deadlock + no
             booking approved against an already-blocked slot". If you do
             observe a 1205 deadlock instead, RETRY the losing side (C5).
   =========================================================================== */

/* ###########################################################################
   PART A — BASELINE : approval vs. escalation, both raw UPDATEs, no ordering.
   ########################################################################### */

/* ---------------------------------------------------------------------------
 * SESSION A (window 1) — the booking is approved via the trigger-only path.
 *                    The phase FIRES while the escalator UPDATE is still
 *                    uncommitted from Session B, so the trigger's
 *                    OutOfService-check sees the record still as Advisory.
-------------------------------------------------------------------------- */
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO
DECLARE @space_cls3 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'T13-T-CLS');
DECLARE @bk_c3      INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-C-BOOKING');

BEGIN TRANSACTION;
    IF EXISTS (
        SELECT 1
        FROM   dbo.maintenance_records m
        WHERE  m.space_id = @space_cls3
          AND  m.impact_level = N'OutOfService'
          AND  m.status NOT IN (N'Completed', N'Cancelled')
          AND  m.start_time < '2026-10-01 12:00:00'
          AND  COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2))
                 > '2026-10-01 10:00:00'
    ) THROW 50099, N'[Baseline-C-A] OutOfService already present', 1;

    -- the trigger's OutOfService sub-probe also returns empty at this point.
    WAITFOR DELAY '00:00:05';
    UPDATE dbo.bookings SET status = N'Approved' WHERE booking_id = @bk_c3;
    PRINT N'[Baseline-C-A] booking approved (trigger saw Advisory only).';
    WAITFOR DELAY '00:00:01';
COMMIT TRANSACTION;
PRINT N'[Baseline-C-A] committed.  (Run B while A waits.)';
GO

/* ---------------------------------------------------------------------------
 * SESSION B (window 2) — escalate the advisory to OutOfService (raw UPDATE),
 *                    run during A's delay so the booking row is still visible
 *                    as not-yet-out-of-service.
-------------------------------------------------------------------------- */
DECLARE @maint_c3 INT = (SELECT maintenance_id FROM dbo.maintenance_records WHERE problem_description = N'T13 Race C advisory');
BEGIN TRANSACTION;
    UPDATE dbo.maintenance_records
    SET    impact_level = N'OutOfService', updated_at = GETDATE()
    WHERE  maintenance_id = @maint_c3
      AND  impact_level = N'Advisory';
    PRINT N'[Baseline-C-B] escalated advisory to OutOfService.';
COMMIT TRANSACTION;
PRINT N'[Baseline-C-B] committed.';
GO

/* VERIFY — both operations succeeded (the race outcome). */
DECLARE @maint_c3 INT = (SELECT maintenance_id FROM dbo.maintenance_records WHERE problem_description = N'T13 Race C advisory');
SELECT b.purpose, b.status AS booking_status,
       m.space_id AS m_space, m.impact_level AS maintenance_level
FROM   dbo.bookings b
CROSS  JOIN dbo.maintenance_records m
WHERE  b.purpose = N'T13-C-BOOKING'
  AND  m.maintenance_id = @maint_c3;
GO

/* RESET — restore pristine: booking back to Pending, maintenance back to
   Advisory so Part B can run cleanly. (Role: for the demo; in real use the
   escalated record would stay.) */
DECLARE @bk_c3     INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-C-BOOKING');
DECLARE @maint_c3r INT = (SELECT maintenance_id FROM dbo.maintenance_records WHERE problem_description = N'T13 Race C advisory');
BEGIN TRANSACTION;
    UPDATE dbo.bookings SET status = N'Pending' WHERE booking_id = @bk_c3 AND status = N'Approved';
    UPDATE dbo.maintenance_records SET impact_level = N'Advisory' WHERE maintenance_id = @maint_c3r AND impact_level = N'OutOfService';
COMMIT TRANSACTION;
PRINT N'RESET done — booking back to Pending, advisory back to Advisory.';
GO

/* ###########################################################################
   PART B — PREVENTION : the same collision through the Task 12 procedures.
   usp_ApproveBooking (C1) and usp_EscalateMaintenance (C4) both take the
   bookings key-range lock FIRST. Instead of bookings→maintenance vs
   maintenance→bookings (a deadlock cycle), both line up in the same order.
   ########################################################################### */

/* SESSION A (window 1) — approve T13-C-BOOKING via the procedure, hold. */
BEGIN TRANSACTION;
    DECLARE @bkc_p  INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-C-BOOKING');
    DECLARE @staff_c INT = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.staff.a@university.edu.vn');
    EXEC dbo.usp_ApproveBooking @booking_id = @bkc_p, @staff_id = @staff_c;
    WAITFOR DELAY '00:00:06';
    PRINT N'[Prevention-C-A] approval executed; outer lock held.';
COMMIT TRANSACTION;
PRINT N'[Prevention-C-A] committed.';
GO

/* ---------------------------------------------------------------------------
 * SESSION B (window 2) — escalate the advisory to OutOfService during A's
 * wait. It will first wait on the bookings range lock A holds, then complete.
 * (Contract C4 lock ordering means B cannot form a deadlock cycle with A.)
 * Expected NET result: B succeeds and the escalation trigger writes ONE
 * booking_alerts row for the Approved booking (identify, not rewrite), OR —
 * if B reached the range first — A fails cleanly with 50002 when it
 * re-reads under SERIALIZABLE. A 1205 occurring here is the bounded-retry
 * case (C5): rerun the losing side.
-------------------------------------------------------------------------- */
BEGIN TRY
    DECLARE @maint_from INT = (SELECT maintenance_id FROM dbo.maintenance_records WHERE problem_description = N'T13 Race C advisory');
    DECLARE @staff_fm   INT = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.staff.b@university.edu.vn');
    EXEC dbo.usp_EscalateMaintenance
         @maintenance_id = @maint_from,
         @staff_id       = @staff_fm,
         @reason         = N'Task-B escalation C (test)';
    PRINT N'[Prevention-C-B] escalation completed.';
END TRY
BEGIN CATCH
    PRINT N'[Prevention-C-B] FAILED.';
    PRINT '    Error number : ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
    PRINT '    Error message: ' + ERROR_MESSAGE();
END CATCH;
GO

/* VERIFY — post-state. In every legal branch either the booking stayed
   Pending (blocked by OutOfService) or, if it was approved first, the
   escalation produced booking_alerts (the Task-10 alert path, Track-3
   escalation lookup). There is never a SUCCESS on both sides — no approval
   slips past an already-escalated OutOfService window. */
DECLARE @maint_c3 INT = (SELECT maintenance_id FROM dbo.maintenance_records WHERE problem_description = N'T13 Race C advisory');
SELECT b.purpose, b.status AS booking_status
FROM   dbo.bookings b
WHERE  b.purpose = N'T13-C-BOOKING';
SELECT alert_type, booking_id
FROM   dbo.booking_alerts
WHERE  maintenance_id = @maint_c3;
GO