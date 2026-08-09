/* ===========================================================================
   Task 13 — Race B: Instant vs. Manual (auto-approval vs. staff approval)
   File     : outputs/13-concurrency-tests-G08/02-race-B-instant-vs-manual.sql
   Target   : Microsoft SQL Server 2016 SP1+ (SSMS dual-window methodology)
   Design   : outputs/11-concurrency-design-G08.md §II.2 (Race B)
   Contract : outputs/11-concurrency-design-G08.md §VI (C1, C3, C5, C6)

   ---------------------------------------------------------------------------
   RACE B  —  The invariant is PATH-INDEPENDENT. A staff member manually
   approves the Pending request T13-B-BOOKING-MANUAL on space T13-T-AUD
   (window 08:45–10:10) while the INSTANT path auto-approves a NEW request for
   the overlapping 09:00–10:30 on the SAME space via usp_CreateBookingAutoApproved.

   HOW TO RUN (dual-window SSMS):
     0. Run 00-setup-test-data.sql ONCE first.
     1. PART A (BASELINE) — raw, trigger-only logic on BOTH sides:
          Window 1: Session A-block (raw INSTANT emulation) — holds ~5s.
          Window 2: Session B-block (raw MANUAL approval) — during A's gap.
          Either  : VERIFY — two overlapping Approved rows (invariant broken).
          RESET   : retire the two raw rows to Cancelled.
        PART B (PREVENTION) — the same collision via the procedures:
          Window 1: Session A (usp_CreateBookingAutoApproved) — holds ~6s.
          Window 2: Session B (usp_ApproveBooking) — during A's wait.
          VERIFY : exactly one Approved row; the manual side fails cleanly.
   =========================================================================== */

/* ###########################################################################
   PART A — BASELINE : "auto-approval script" vs "manual approval script",
   both raw statements that rely only on the trigger backstops.
   ########################################################################### */

/* ---------------------------------------------------------------------------
 * SESSION A (window 1) — INSTANT path emulated as raw statements.
   (Pending → decision → Approved — mimicking the auto-policy statement order
    WITHOUT SERIALIZABLE isolation or UPDLOCK/HOLDLOCK.)
-------------------------------------------------------------------------- */
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO
DECLARE @u_reqA INT = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.requester.a@university.edu.vn');
DECLARE @space_aud INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'T13-T-AUD');

BEGIN TRANSACTION;
    INSERT INTO dbo.bookings
          (requester_id, space_id, requested_start_time, requested_end_time,
           purpose, expected_participants, booking_type, status)
    VALUES (@u_reqA, @space_aud,
            '2026-09-02 09:00:00', '2026-09-02 10:30:00',
            N'T13-B-INSTANT-RAW', 15, N'ProjectWork', N'Pending');
    DECLARE @raw_inst INT = SCOPE_IDENTITY();

    -- no active advisory on T13-T-AUD at seed -> no acknowledgment rows
    INSERT INTO dbo.booking_decisions
          (booking_id, decided_by, decision, decision_time,
           decision_note, rejection_reason, decision_source)
    VALUES (@raw_inst, NULL, N'Approved', GETDATE(), NULL, NULL, N'System');

    UPDATE dbo.bookings SET status = N'Approved' WHERE booking_id = @raw_inst;
    PRINT N'[Baseline-Instant-A] Approved booking ' + CAST(@raw_inst AS NVARCHAR(20)) + '.';
    WAITFOR DELAY '00:00:05';
COMMIT TRANSACTION;
PRINT N'[Baseline-Instant-A] committed.  (Run Session B during the wait.)';
GO

/* ---------------------------------------------------------------------------
 * SESSION B (window 2) — staff member approves the SEEDed Pending request
   T13-B-BOOKING-MANUAL (08:45→10:10) via raw UPDATE, no serialization.
   This overlaps the instant request (09:00→10:30).
-------------------------------------------------------------------------- */
BEGIN TRANSACTION;
    DECLARE @bk_manual_raw INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-B-BOOKING-MANUAL');
    DECLARE @staff_s       INT = (SELECT user_id   FROM dbo.user_accounts WHERE email = N't13.staff.b@university.edu.vn');

    -- Probe sees no committed blocker (the instant row is still uncommitted).
    IF EXISTS (
        SELECT 1 FROM dbo.bookings b
        WHERE b.space_id = (SELECT space_id FROM dbo.bookings WHERE booking_id = @bk_manual_raw)
          AND b.status IN (N'Approved', N'CheckedIn')
          AND b.requested_start_time < '2026-09-02 10:10:00'
          AND b.requested_end_time   > '2026-09-02 08:45:00'
    ) THROW 50098, N'[Baseline-Manual-B] unexpectedly blocked', 1;

    WAITFOR DELAY '00:00:01';
    UPDATE dbo.bookings SET status = N'Approved' WHERE booking_id = @bk_manual_raw;

    INSERT INTO dbo.booking_decisions
          (booking_id, decided_by, decision, decision_time,
           decision_note, rejection_reason, decision_source)
    VALUES (@bk_manual_raw, @staff_s, N'Approved', GETDATE(), NULL, NULL, 'Staff');

COMMIT TRANSACTION;
PRINT N'[Baseline-Manual-B] committed.  (Return to Window 1 and COMMIT.)';
GO

/* VERIFY — two overlapping Approved rows (invariant broken). */
SELECT purpose, status, requested_start_time, requested_end_time
FROM   dbo.bookings
WHERE  purpose IN (N'T13-B-BOOKING-MANUAL', N'T13-B-INSTANT-RAW')
ORDER  BY requested_start_time;
GO

/* RESET — restore the pristine two-row state for Part B:
   - retire the raw INSTANT row (T13-B-INSTANT-RAW) to Cancelled so it never
     blocks anything again and its count doesn't leak into the Part B VERIFY.
   - put the SEEDed manual booking back to Pending, because Part B's Session B
     is supposed to approve it (usp_ApproveBooking rejects non-Pending rows). */
UPDATE dbo.bookings SET status = N'Cancelled'
WHERE  purpose = N'T13-B-INSTANT-RAW'
  AND  status = N'Approved';
UPDATE dbo.bookings SET status = N'Pending'
WHERE  purpose = N'T13-B-BOOKING-MANUAL'
  AND  status = N'Approved';
PRINT N'RESET done — instant raw row retired; manual booking back to Pending.';
GO


/* ###########################################################################
   PART B — PREVENTION : the same collision through the procedures.
   usp_CreateBookingAutoApproved and usp_ApproveBooking share the SAME
   SERIALIZABLE + UPDLOCK/HOLDLOCK conflict check (path-independent) backed
   by filtered index I1 (IX_bookings_space_status_time).
   ########################################################################### */

/* ---------------------------------------------------------------------------
 * SESSION A (window 1) — instant side via the real auto-approval procedure.
-------------------------------------------------------------------------- */
DECLARE @u_reqA INT = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.requester.a@university.edu.vn');
DECLARE @space_aud INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'T13-T-AUD');
DECLARE @booking_auto INT;
BEGIN TRANSACTION;            -- test harness: keep the proc's range lock alive
    EXEC dbo.usp_CreateBookingAutoApproved
         @space_id              = @space_aud,
         @requester_id          = @u_reqA,
         @requested_start_time  = '2026-09-02 09:00:00',
         @requested_end_time    = '2026-09-02 10:30:00',
         @expected_participants = 15,
         @booking_type          = N'ProjectWork',
         @purpose               = N'T13-B-INSTANT-PROTECTED',
         @booking_id            = @booking_auto OUTPUT;
    PRINT N'[Prevention-Instant-A] auto-created booking ' + CAST(@booking_auto AS NVARCHAR(20)) + N'.';
    WAITFOR DELAY '00:00:06';
COMMIT TRANSACTION;
PRINT '[Prevention-Instant-A] committed.';
GO

/* ---------------------------------------------------------------------------
 * SESSION B (window 2) — manual side, run DURING A's wait.
 * Expected: blocked on A's key range; after A commits it re-reads and THROWs
 * 50001 (or retryable 1205/1222 that the caller retries, then 50001).
-------------------------------------------------------------------------- */
BEGIN TRY
    DECLARE @bk_manual_p  INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-B-BOOKING-MANUAL');
    DECLARE @staff_manual INT = (SELECT user_id   FROM dbo.user_accounts WHERE email = N't13.staff.b@university.edu.vn');
    EXEC dbo.usp_ApproveBooking @booking_id = @bk_manual_p, @staff_id = @staff_manual;
    PRINT N'[Prevention-Manual-B] SUCCEEDED — UNEXPECTED.';
END TRY
BEGIN CATCH
    PRINT N'[Prevention-Manual-B] correctly FAILED.';
    PRINT '    Error number : ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
    PRINT '    Error message: ' + ERROR_MESSAGE();
END CATCH;
GO

/* VERIFY — only one Approved row may remain under the overlap. */
SELECT purpose, status, requested_start_time, requested_end_time
FROM   dbo.bookings
WHERE  purpose IN (N'T13-B-BOOKING-MANUAL', N'T13-B-INSTANT-PROTECTED')
ORDER  BY requested_start_time;
-- Expected: one Approved (winner) and one Pending (clean loser).
GO