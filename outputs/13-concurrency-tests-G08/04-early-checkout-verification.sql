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

   HOW TO RUN:
     0. Requires 00-setup-test-data.sql (space T13-T-AUD, users, policy).
     1. Run this file in ONE SSMS window. It is self-driving.
     2. Observe the printed steps:
          Step 1  -> create + approve a 09:00-12:00 reservation, check in.
          Step 2  -> a NEW request for 10:00-11:30 (inside the reserved
                     window) is REJECTED while the booking is CheckedIn.
          Step 3  -> early check-out with usp_CompleteBooking.
          Step 4  -> the SAME 10:00-11:30 request is now APPROVED immediately.
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

/* ===========================================================================
   STEP 1 — book, approve, and check in a full 09:00-12:00 reservation.
   ===========================================================================*/
PRINT N'Step 1: create + approve a 09:00-12:00 reservation on the test space.';
DECLARE @b_id INT;
INSERT INTO dbo.bookings
      (requester_id, space_id, requested_start_time, requested_end_time,
       purpose, expected_participants, booking_type, status)
VALUES (@req, @s, '2026-08-10 09:00:00', '2026-08-10 12:00:00',
        N'T13-ECO-PRIMARY', 10, N'Meeting', N'Pending');
SET @b_id = SCOPE_IDENTITY();

EXEC dbo.usp_ApproveBooking @booking_id = @b_id, @staff_id = @stf,
                            @decision_note = N'ECO test';
PRINT N'    booking ' + CAST(@b_id AS NVARCHAR(20)) + N' approved.';

DECLARE @ss_id INT;
INSERT INTO dbo.usage_sessions (booking_id, checked_in_by, actual_start_time, initial_condition)
VALUES (@b_id, @stf, '2026-08-10 09:15:00', N'ECO test — clean');
SET @ss_id = SCOPE_IDENTITY();
UPDATE dbo.bookings SET status = N'CheckedIn' WHERE booking_id = @b_id;
PRINT N'    checked in (usage session ' + CAST(@ss_id AS NVARCHAR(20)) + N'); status now CheckedIn.';

/* =========================================================================
   Step 2 — a new booking for the leftover 10:00-11:30 (inside the reserved
   [09:00,12:00) window) must be REJECTED while the first is CheckedIn.
   =========================================================================*/
PRINT N'';
PRINT N'Step 2: attempt to book the leftover 10:00-11:30 while CheckedIn — must be REJECTED.';
DECLARE @b_pre INT;
BEGIN TRY
    EXEC dbo.usp_CreateBookingAutoApproved
         @space_id              = @s,
         @requester_id          = @req,
         @requested_start_time  = '2026-08-10 10:00:00',
         @requested_end_time    = '2026-08-10 11:30:00',
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
   Step 3 — EARLY CHECK-OUT. usp_CompleteBooking records actual end = GETDATE()
   and flips status to Completed. This immediately releases the remainder.
   =========================================================================*/
PRINT N'';
PRINT N'Step 3: early check-out with usp_CompleteBooking (before reserved 12:00).';
EXEC dbo.usp_CompleteBooking @booking_id = @b_id, @staff_id = @stf,
                             @final_condition = N'ECO — good';
PRINT N'    booking ' + CAST(@b_id AS NVARCHAR(20)) + N' completed.';

/* =========================================================================
   Step 4 — the SAME 10:00-11:30 request now succeeds immediately.
   =========================================================================*/
PRINT N'';
PRINT N'Step 4: re-request the leftover window AFTER early check-out — must succeed.';
DECLARE @b2 INT;
BEGIN TRY
    EXEC dbo.usp_CreateBookingAutoApproved
         @space_id              = @s,
         @requester_id          = @req,
         @requested_start_time  = '2026-08-10 10:00:00',
         @requested_end_time    = '2026-08-10 11:30:00',
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