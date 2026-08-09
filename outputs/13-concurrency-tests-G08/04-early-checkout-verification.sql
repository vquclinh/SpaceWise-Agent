/* ===========================================================================
   Task 13 — Early Check-out Verification
   File:  outputs/13-concurrency-tests-G08/04-early-checkout-verification.sql
   Target: Microsoft SQL Server 2016 SP1+ (single SSMS window)
   Design: outputs/09-updated-erd-and-logical-design-G08.md section 9.4;
           outputs/11-concurrency-design-G08.md section III.8
   Procedure: usp_CompleteBooking (outputs/12-concurrency-implementation-G08.sql)

   PURPOSE — Prove the [EXTENSION] "reserved vs actual occupancy time"
   behaviour: while a booking is Approved/CheckedIn it blocks its FULL
   reserved window; the instant it is early-checked-out (Completed) the
   REMAINING portion of the window becomes bookable IMMEDIATELY — no trigger,
   timer, or stored flag. The release falls out of the status-driven conflict
   filter (status IN (Approved, CheckedIn) is the blocking predicate).

   DATE-INDEPENDENT WINDOWS — usp_CompleteBooking stamps
   actual_end_time = GETDATE(), and CK_usage_sessions_end_time requires
   actual_end_time > actual_start_time. To satisfy that on EVERY run date,
   no wall-clock literal is used. One clock anchor is captured at the start
   (@now = GETDATE()) and every window is derived with DATEADD:

        primary reservation : GETDATE() - 1 hour  ->  GETDATE() + 2 hours
        actual check-in     : GETDATE() - 30 minutes   (always < now)
        leftover probe      : GETDATE() - 20 minutes -> GETDATE() + 30 min
                              (strictly INSIDE the reserved window)

   HOW TO RUN:
     0. Requires 00-setup-test-data.sql (space T13-T-AUD, users, policy).
     1. Run this file in ONE SSMS window. It is self-driving.
     2. Observe the printed steps:
          Step 1  -> create + approve a full ~3-hour reservation, check in.
          Step 2  -> a NEW request for the leftover window (inside the
                     reserved interval) is REJECTED while the booking is
                     CheckedIn.
          Step 3  -> early check-out with usp_CompleteBooking.
          Step 4  -> the SAME leftover window is now APPROVED immediately.
          Step 5  -> summary query.
   =========================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* Pre-flight cleanup — this file is self-driving but RE-RUNNABLE: it owns
   its own run-time bookings (T13-ECO-* are never seeded), so removing any
   leftovers from a previous run keeps the assertion steps deterministic. */
DELETE FROM dbo.booking_advisory_acknowledgments
WHERE  booking_id IN (SELECT booking_id FROM dbo.bookings WHERE purpose LIKE N'T13-ECO-%');
DELETE FROM dbo.booking_alerts
WHERE  booking_id IN (SELECT booking_id FROM dbo.bookings WHERE purpose LIKE N'T13-ECO-%');
DELETE FROM dbo.booking_decisions
WHERE  booking_id IN (SELECT booking_id FROM dbo.bookings WHERE purpose LIKE N'T13-ECO-%');
DELETE FROM dbo.usage_sessions
WHERE  booking_id IN (SELECT booking_id FROM dbo.bookings WHERE purpose LIKE N'T13-ECO-%');
DELETE FROM dbo.bookings WHERE purpose LIKE N'T13-ECO-%';

/* Step 0 — harness objects */
DECLARE @s   INT = (SELECT space_id   FROM dbo.spaces       WHERE space_code = N'T13-T-AUD');
DECLARE @req INT = (SELECT user_id    FROM dbo.user_accounts WHERE email = N't13.requester.a@university.edu.vn');
DECLARE @stf INT = (SELECT user_id    FROM dbo.user_accounts WHERE email = N't13.staff.a@university.edu.vn');

IF @s IS NULL OR @req IS NULL OR @stf IS NULL
    THROW 50000, N'Test data missing — run 00-setup-test-data.sql first.', 1;

/* --- One clock anchor: all windows are derived from a single GETDATE()
      snapshot, so the step-to-step overlap logic stays exact no matter what
      the wall-clock date/time is when the demo runs. --------------------- */
DECLARE @now        DATETIME2 = GETDATE();
DECLARE @win_start  DATETIME2 = DATEADD(HOUR,   -1, @now);   -- reserved start (1h ago)
DECLARE @win_end    DATETIME2 = DATEADD(HOUR,    2, @now);   -- reserved end   (2h ahead)
DECLARE @checkin_at DATETIME2 = DATEADD(MINUTE, -30, @now);  -- actual start: always < now
DECLARE @gap_start  DATETIME2 = DATEADD(MINUTE, -20, @now);  -- leftover window: strictly
DECLARE @gap_end    DATETIME2 = DATEADD(MINUTE,  30, @now);  -- inside [@win_start, @win_end)

PRINT N'Reserved window : ' + CONVERT(NVARCHAR(33), @win_start, 121) + N' -> ' + CONVERT(NVARCHAR(33), @win_end, 121);
PRINT N'Actual check-in : ' + CONVERT(NVARCHAR(33), @checkin_at, 121);
PRINT N'Leftover probe  : ' + CONVERT(NVARCHAR(33), @gap_start, 121) + N' -> ' + CONVERT(NVARCHAR(33), @gap_end, 121);
PRINT N'';

/* ===========================================================================
   STEP 1 — book, approve, and check in the full reserved window on the
   test space.
   ===========================================================================*/
PRINT N'Step 1: create + approve the reservation, then check in.';
DECLARE @b_id INT;
INSERT INTO dbo.bookings
      (requester_id, space_id, requested_start_time, requested_end_time,
       purpose, expected_participants, booking_type, status)
VALUES (@req, @s, @win_start, @win_end,
        N'T13-ECO-PRIMARY', 10, N'Meeting', N'Pending');
SET @b_id = SCOPE_IDENTITY();

EXEC dbo.usp_ApproveBooking @booking_id = @b_id, @staff_id = @stf,
                            @decision_note = N'ECO test';
PRINT N'    booking ' + CAST(@b_id AS NVARCHAR(20)) + N' approved.';

DECLARE @ss_id INT;
INSERT INTO dbo.usage_sessions (booking_id, checked_in_by, actual_start_time, initial_condition)
VALUES (@b_id, @stf, @checkin_at, N'ECO test — clean');
SET @ss_id = SCOPE_IDENTITY();
UPDATE dbo.bookings SET status = N'CheckedIn' WHERE booking_id = @b_id;
PRINT N'    checked in (usage session ' + CAST(@ss_id AS NVARCHAR(20)) + N'); status now CheckedIn.';

/* =========================================================================
   Step 2 — a new booking for the leftover window (inside the reserved
   [@win_start, @win_end) interval) must be REJECTED while the first is
   CheckedIn.
   =========================================================================*/
PRINT N'';
PRINT N'Step 2: request the leftover window while CheckedIn — must be REJECTED.';
DECLARE @b_pre INT;
BEGIN TRY
    EXEC dbo.usp_CreateBookingAutoApproved
         @space_id              = @s,
         @requester_id          = @req,
         @requested_start_time  = @gap_start,
         @requested_end_time    = @gap_end,
         @expected_participants = 8,
         @booking_type          = N'Meeting',
         @purpose               = N'T13-ECO-PRE',
         @booking_id            = @b_pre OUTPUT;
    PRINT N'    *ERROR* a new overlapping booking was approved while CheckedIn!';
END TRY
BEGIN CATCH
    PRINT N'    OK (expected): rejected — ' + ERROR_MESSAGE();
END CATCH;

/* =========================================================================
   Step 3 — EARLY CHECK-OUT. usp_CompleteBooking writes
   actual_end_time = GETDATE() and flips status to Completed. This
   immediately releases the remainder of the reserved window.
   =========================================================================*/
PRINT N'';
PRINT N'Step 3: early check-out with usp_CompleteBooking (before the reserved end).';
EXEC dbo.usp_CompleteBooking @booking_id = @b_id, @staff_id = @stf,
                             @final_condition = N'ECO — good';
PRINT N'    booking ' + CAST(@b_id AS NVARCHAR(20)) + N' completed.';

/* =========================================================================
   Step 4 — the SAME leftover window now succeeds immediately.
   =========================================================================*/
PRINT N'';
PRINT N'Step 4: re-request the leftover window AFTER early check-out — must succeed.';
DECLARE @b2 INT;
BEGIN TRY
    EXEC dbo.usp_CreateBookingAutoApproved
         @space_id              = @s,
         @requester_id          = @req,
         @requested_start_time  = @gap_start,
         @requested_end_time    = @gap_end,
         @expected_participants = 8,
         @booking_type          = N'Meeting',
         @purpose               = N'T13-ECO-POST',
         @booking_id            = @b2 OUTPUT;
    PRINT N'    SUCCESS: leftover window released + re-approved (new booking ' + CAST(@b2 AS NVARCHAR(20)) + N').';
END TRY
BEGIN CATCH
    PRINT N'    ***FAIL*** early check-out did NOT release the window: ' + ERROR_MESSAGE();
END CATCH;

/* =========================================================================
   Step 5 — summary of the bookings involved in this verification.
   =========================================================================*/
PRINT N'';
PRINT N'Summary of the bookings involved:';
SELECT purpose, status, requested_start_time, requested_end_time
FROM   dbo.bookings
WHERE  purpose IN (N'T13-ECO-PRIMARY', N'T13-ECO-POST')
ORDER  BY requested_start_time;
GO