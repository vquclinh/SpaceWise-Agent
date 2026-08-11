/* ===========================================================================
   Task 13 — Race A: Double Approval (Manual vs. Manual)
   File     : outputs/13-concurrency-tests-G08/01-race-A-double-approval.sql
   Target   : Microsoft SQL Server 2016 SP1+ (SSMS dual-window methodology)
   Design   : outputs/11-concurrency-design-G08.md §II.1 (Race A)
   Contract : outputs/11-concurrency-design-G08.md §VI (C1, C5, C6)

   ---------------------------------------------------------------------------
   RACE A  —  Two staff members simultaneously approve two DIFFERENT Pending
   requests (T13-A-BOOKING-A and T13-A-BOOKING-B) for the SAME space with
   OVERLAPPING windows. Under the trigger-only Phase 1 rule the second approval
   check does not see the first (not yet committed), so BOTH can win the slot
   and BOTH commit — the invariant breaks.

   HOW TO RUN (dual-window SSMS):
     1. Run 00-setup-test-data.sql ONCE first.
     2. Open TWO SSMS query windows against the same migrated Phase 2 DB.
     3. PART A — BASELINE (the Phase 1 flaw):
          Window 1 : run the Session A-baseline block (WITHOUT the trailing
                     COMMIT of that block being executed first!).
          Window 2 : run the Session B-baseline block WHILE A's 5-second
                     delay is running.
          Window 1 : come back and run its COMMIT.
          Either   : run the VERIFY block — both rows Approved + overlapping.
          One window: run the RESET block (returns both to Pending).
        PART B — PREVENTION (the Task 12 serialization):
          Window 1 : run Session A-prevention (holds the row ~6s).
          Window 2 : run Session B-prevention DURING A's wait.
          Either   : VERIFY — exactly one Approved, the other Pending.
   =========================================================================== */

/* ###########################################################################
   PART A — BASELINE : trigger-only behaviour under READ COMMITTED.
   ########################################################################### */

-- ---------------------------------------------------------------------------
-- SESSION A (window 1) — approve booking A via RAW UPDATE (Phase 1 path)
-- ---------------------------------------------------------------------------
use SpaceWiseP2Demo

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- Phase 1 default
GO
DECLARE @bkA INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-A-BOOKING-A');

BEGIN TRANSACTION;
    /* "check" — conflict probe sees only committed rows: empty slot.         */
    IF EXISTS (
        SELECT 1 FROM dbo.bookings b
        WHERE b.space_id = (SELECT space_id FROM dbo.bookings WHERE booking_id = @bkA)
          AND b.status IN (N'Approved', N'CheckedIn')
          AND b.requested_start_time < '2026-09-01 10:30:00'
          AND b.requested_end_time   > '2026-09-01 09:00:00'
    ) THROW 50098, N'[Baseline-A] slot already blocked', 1;

    -- A "decides" and flips its OWN row to Approved FIRST, but does NOT commit.
    -- The AFTER trigger fires now and sees no committed conflict (B is not
    -- even started). Then we HOLD the open transaction for ~5s:
    UPDATE dbo.bookings SET status = N'Approved' WHERE booking_id = @bkA;
    PRINT N'[Baseline-A] booking A set Approved (uncommitted); holding lock... commit below.';

    /* This 5-second hold is the race window: run Session B now, then return
       and COMMIT TRANSACTION here. The uncommitted row is invisible to B's
       probe (READ COMMITTED), so B "wins" the same slot too. */
    WAITFOR DELAY '00:00:05';
    SELECT purpose, status FROM dbo.bookings WHERE booking_id = @bkA;
GO
-- Run Window 2 now, then return and execute:  COMMIT TRANSACTION;
PRINT N'[Baseline-A] (final COMMIT line is below; run it after session B).';
COMMIT TRANSACTION;   -- run AFTER running Session B.

/* ---------------------------------------------------------------------------
   SESSION B (window 2) — approve booking B via the raw UPDATE path, while
   Session A is still inside its WAITFOR DELAY (A uncommitted).
--------------------------------------------------------------------------- */
DECLARE @bkB INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-A-BOOKING-B');

BEGIN TRANSACTION;
    IF EXISTS (
        SELECT 1 FROM dbo.bookings b
        WHERE b.space_id = (SELECT space_id FROM dbo.bookings WHERE booking_id = @bkB)
          AND b.status IN (N'Approved', N'CheckedIn')
          AND b.requested_start_time < '2026-09-01 11:30:00'
          AND b.requested_end_time   > '2026-09-01 10:00:00'
    ) THROW 50098, N'[Baseline-B] unexpected slot blocked already', 1;

    -- B's conflict probe also sees an empty slot (A not committed yet).
    WAITFOR DELAY '00:00:01';
    UPDATE dbo.bookings SET status = N'Approved' WHERE booking_id = @bkB;
    PRINT N'[Baseline-B] booking B set Approved.';
COMMIT TRANSACTION;
PRINT N'[Baseline-B] committed.  (Go back to Window 1 and run its COMMIT.)';
GO

/* ---------------------------------------------------------------------------
 * VERIFY (run in either window AFTER both windows have committed)
   Expected: BOTH rows Approved AND overlapping → the invariant is violated.
--------------------------------------------------------------------------- */
SELECT purpose, status, requested_start_time, requested_end_time
FROM   dbo.bookings
WHERE  purpose IN (N'T13-A-BOOKING-A', N'T13-A-BOOKING-B')
ORDER  BY requested_start_time;
/* -- Expected result: a clear double-booking. ---------------------------- */

/* ---------------------------------------------------------------------------
 * RESET (run in one window; restores booking A & B to Pending for PART B)
--------------------------------------------------------------------------- */
UPDATE dbo.bookings SET status = N'Pending'
WHERE purpose IN (N'T13-A-BOOKING-A', N'T13-A-BOOKING-B')
  AND status = N'Approved';
PRINT N'RESET done — A and B are Pending again for Part B.';
GO


/* ###########################################################################
   PART B — PREVENTION : usp_ApproveBooking serializes the two approvals.
   ###########################################################################
The two procedures run the SAME conflict check (SERIALIZABLE + UPDLOCK/HOLDLOCK,
SQL Server key-range locking via index I1). The second session blocks on A's
row lock; when A commits, the second re-reads and THROWs 50001 (overlap).
A 1205 (deadlock victim) or 1222 (lock timeout) may surface instead — the
contract says CALLER retries those, then eventually sees the terminal 50001.
---------------------------------------------------------------------------- */

-- ---------------------------------------------------------------------------
-- SESSION A (window 1) — approve booking A via usp_ApproveBooking
----------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- Session default before run
GO
DECLARE @staffA INT = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.staff.a@university.edu.vn');
DECLARE @bkA_p INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-A-BOOKING-A');

IF @bkA_p IS NULL THROW 50000, N'Test data missing — run 00-setup and Part A reset first', 1;

BEGIN TRANSACTION;
    /* The outer transaction is a TEST HARNESS: the procedure COMMITs its own
       inner transaction, but the outer one of this window keeps the procedure's
       key-range locks alive across the delay.                               */
    EXEC dbo.usp_ApproveBooking
         @booking_id    = @bkA_p,
         @staff_id      = @staffA,
         @decision_note = N'Task13 prevention A';
    WAITFOR DELAY '00:00:06';
    PRINT N'[Prevention-A] internal success; holding outer lock via delay...';
COMMIT TRANSACTION;
PRINT '[Prevention-A] committed — A is officially Approved.';
GO

/* ---------------------------------------------------------------------------
 * SESSION B (window 2) — approve booking B through the SAME procedure during
 * A's wait. Expect a terminal 50001 (overlap), or a retryable 1205/1222 that
 * the caller would retry and then see 50001.
-------------------------------------------------------------------------- */
BEGIN TRY
    DECLARE @staffB INT = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.staff.b@university.edu.vn');
    DECLARE @bkB_p INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-A-BOOKING-B');
    EXEC dbo.usp_ApproveBooking
         @booking_id    = @bkB_p,
         @staff_id      = @staffB,
         @decision_note = N'Task-A prevention B';
    PRINT N'[Prevention-B] SUCCEEDED — UNEXPECTED (only one may win).';
END TRY
BEGIN CATCH
    PRINT N'[Prevention-B] correctly FAILED.';
    PRINT '    Error number : ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
    PRINT '    Error message: ' + ERROR_MESSAGE();
END CATCH;
GO

/* VERIFY — at most one Approved row; the loser stayed Pending. */
SELECT purpose, status
FROM   dbo.bookings
WHERE  purpose IN (N'T13-A-BOOKING-A', N'T13-A-BOOKING-B');
-- Expected: ONE row Approved, the other Pending. Invariant preserved.
GO