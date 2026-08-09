/* ===========================================================================
   Task 13 — Concurrency Test Data Seed  (G08, Phase 2)
   File     : outputs/13-concurrency-tests-G08/00-setup-test-data.sql
   Target   : Microsoft SQL Server 2016 SP1+
   Requires : Phase 1 schema migrated by outputs/10-schema-migration-G08.sql
              (15 tables, TR_* backstops, filtered indexes) AND the four
              stored procedures from outputs/12-concurrency-implementation-G08.sql
              (usp_ApproveBooking, usp_CreateBookingAutoApproved,
              usp_EscalateMaintenance, usp_CompleteBooking).
   Purpose  : Seed a PRISTINE, self-contained test dataset for the concurrency
              race demonstrations (files 01, 02, 03, 04). It creates dedicated
              test users, two test spaces, auto-approval policy rows and the
              specific Pending bookings each race script expects.

   ---------------------------------------------------------------------------
   MANDATORY RUN ORDER (dual-window SSMS methodology, AGENTS.md §? / skill):
       1. Execute this file ONCE in a single SSMS window against the migrated
          Phase 2 database.
       2. Validate the seed summary SELECT at the end (each count above 0).
       3. Then open the race files (01..04) and follow THEIR per-session
          instructions. Each race file is self-contained (its PREVENTION part
          re-derives the test booking IDs by purpose string) and tolerant of
          being re-run after this seed.

   IDEMPOTENCE: This script is guarded so re-running it never inserts
   duplicate users/spaces/policies/bookings. Running it again AFTER a race
   file therefore RE-ESTABLISHES a pristine environment (used by the race
   files' own "reset" blocks which mark conflicting test bookings Cancelled).

   SAFETY: contains only seed INSERTs. No race is executed here. No object is
   dropped. The generated data uses the 'T13-' purpose prefix so the race
   files can select exactly the rows owned by the test harness.
   =========================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET IMPLICIT_TRANSACTIONS OFF;

BEGIN TRANSACTION;
BEGIN TRY

    /* ---------------------------------------------------------------------
       1. TEST DEPARTMENT  (reuse / create)
       --------------------------------------------------------------------- */
    IF NOT EXISTS (SELECT 1 FROM dbo.departments WHERE department_name = N'T13 Test dept')
    BEGIN
        INSERT INTO dbo.departments (department_name) VALUES (N'T13 Test dept');
        PRINT N'[setup] T13 Test dept created.';
    END
    ELSE PRINT N'[setup] T13 Test dept already present.';

    DECLARE @dept_id INT = (SELECT department_id FROM dbo.departments WHERE department_name = N'T13 Test dept');

    /* ---------------------------------------------------------------------
       1. TEST USERS (user_accounts has NO role column after §1c; roles live
          in user_roles)
       ------------------------------------------------------------------- */
    DECLARE @u_requester_a INT, @u_requester_b INT, @u_staff_a INT,
            @u_staff_b     INT, @u_staff_assign INT, @u_reporter INT;

    IF NOT EXISTS (SELECT 1 FROM dbo.user_accounts WHERE email = N't13.requester.a@university.edu.vn')
    BEGIN
        INSERT INTO dbo.user_accounts (email, full_name, phone_number, account_status, department_id, created_at, updated_at)
        VALUES (N't13.requester.a@university.edu.vn', N'T13 Requester Alpha',
                N'0901333001', N'Active', @dept_id, GETDATE(), GETDATE());
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.user_accounts WHERE email = N't13.requester.b@university.edu.vn')
    BEGIN
        INSERT INTO dbo.user_accounts (email, full_name, phone_number, account_status, department_id, created_at, updated_at)
        VALUES (N't13.requester.b@university.edu.vn', N'T13 Requester Bravo',
                N'0901333002', N'Active', @dept_id, GETDATE(), GETDATE());
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.user_accounts WHERE email = N't13.staff.a@university.edu.vn')
    BEGIN
        INSERT INTO dbo.user_accounts (email, full_name, phone_number, account_status, department_id, created_at, updated_at)
        VALUES (N't13.staff.a@university.edu.vn', N'T13 Staff Alpha',
                N'0901333003', N'Active', @dept_id, GETDATE(), GETDATE());
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.user_accounts WHERE email = N't13.staff.b@university.edu.vn')
    BEGIN
        INSERT INTO dbo.user_accounts (email, full_name, phone_number, account_status, department_id, created_at, updated_at)
        VALUES (N't13.staff.b@university.edu.vn', N'T13 Staff Bravo',
                N'0901333004', N'Active', @dept_id, GETDATE(), GETDATE());
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.user_accounts WHERE email = N't13.staff.assign@university.edu.vn')
    BEGIN
        INSERT INTO dbo.user_accounts (email, full_name, phone_number, account_status, department_id, created_at, updated_at)
        VALUES (N't13.staff.assign@university.edu.vn', N'T13 Staff Assigned',
                N'0901333005', N'Active', @dept_id, GETDATE(), GETDATE());
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.user_accounts WHERE email = N't13.reporter@university.edu.vn')
    BEGIN
        INSERT INTO dbo.user_accounts (email, full_name, phone_number, account_status, department_id, created_at, updated_at)
        VALUES (N't13.reporter@university.edu.vn', N'T13 Reporter',
                N'0901333006', N'Active', @dept_id, GETDATE(), GETDATE());
    END

    SET @u_requester_a  = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.requester.a@university.edu.vn');
    SET @u_requester_b  = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.requester.b@university.edu.vn');
    SET @u_staff_a      = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.staff.a@university.edu.vn');
    SET @u_staff_b      = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.staff.b@university.edu.vn');
    SET @u_staff_assign = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.staff.assign@university.edu.vn');
    SET @u_reporter     = (SELECT user_id FROM dbo.user_accounts WHERE email = N't13.reporter@university.edu.vn');

    /* Roles — the requesting students hold Student, the decision makers hold
       FacilityStaff and FacilityManager (authorised by the R13/R14/R15/R16
       staff-role triggers). */
    INSERT INTO dbo.user_roles (user_id, role)
    SELECT x.user_id, x.role
    FROM (VALUES
        (@u_requester_a,  N'Student'),
        (@u_requester_b,  N'Student'),
        (@u_staff_a,      N'FacilityStaff'),
        (@u_staff_b,      N'FacilityStaff'),
        (@u_staff_assign, N'FacilityStaff'),
        (@u_reporter,     N'Student')
    ) AS x(user_id, role)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.user_roles ur WHERE ur.user_id = x.user_id AND ur.role = x.role);

    /* ---------------------------------------------------------------------
       2. TEST SPACES
       ------------------------------------------------------------------- */
    IF NOT EXISTS (SELECT 1 FROM dbo.spaces WHERE space_code = N'T13-T-AUD')
    BEGIN
        INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number,
                                capacity, current_status, usage_policy, created_at, updated_at)
        VALUES (N'T13-T-AUD', N'Test Auditorium', N'Auditorium', N'Test Building', 1, N'001',
                100, N'Available', NULL, GETDATE(), GETDATE());
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.spaces WHERE space_code = N'T13-T-CLS')
    BEGIN
        INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number,
                                capacity, current_status, usage_policy, created_at, updated_at)
        VALUES (N'T13-T-CLS', N'Test Classroom', N'Classroom', N'Test Building', 1, N'002',
                40, N'Available', NULL, GETDATE(), GETDATE());
    END

    DECLARE @space_aud INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'T13-T-AUD');
    DECLARE @space_cls INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'T13-T-CLS');

    /* ---------------------------------------------------------------------
       3. AUTO-APPROVAL POLICY for the Auditorium TEST SPACE
          (space-specific override; required by usp_CreateBookingAutoApproved
          in file 02's instant path, and harmless elsewhere.)
       ------------------------------------------------------------------- */
    IF NOT EXISTS (SELECT 1 FROM dbo.auto_approval_policies WHERE space_id = @space_aud)
    BEGIN
        INSERT INTO dbo.auto_approval_policies (space_id, space_type, max_participants, is_active, created_at, updated_at)
        VALUES (@space_aud, NULL, 100, 1, GETDATE(), GETDATE());
    END

    DECLARE @policy_id INT = (SELECT policy_id FROM dbo.auto_approval_policies WHERE space_id = @space_aud AND is_active = 1);

    /* Booking types allowed under the policy (must include the types used by file 02). */
    INSERT INTO dbo.policy_booking_types (policy_id, booking_type)
    SELECT @policy_id, x.bt
    FROM (VALUES (N'Meeting'), (N'Lecture'), (N'Seminar'), (N'Workshop'), (N'StudentActivity'), (N'ProjectWork')) AS x(bt)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.policy_booking_types pbt WHERE pbt.policy_id = @policy_id AND pbt.booking_type = x.bt);

    /* ---------------------------------------------------------------------
       4. PENDING BOOKINGS the race files depend on.
          All are Pending (so usp_ApproveBooking accepts them), none carries a
          booking_alerts/advisory ack yet, and each is tagged with the 'T13-'
          purpose prefix so the race files locate it without ID coupling.
          The windows deliberately OVERLAP each other on the same space.
       ------------------------------------------------------------------- */
    IF NOT EXISTS (SELECT 1 FROM dbo.bookings WHERE purpose = N'T13-A-BOOKING-A')
    BEGIN
        INSERT INTO dbo.bookings
              (requester_id, space_id, requested_start_time, requested_end_time,
               purpose, expected_participants, booking_type, status, created_at, updated_at)
        VALUES (@u_requester_a, @space_aud,
                '2026-09-01 09:00:00', '2026-09-01 10:30:00',
                N'T13-A-BOOKING-A', 20, N'Meeting', N'Pending', GETDATE(), GETDATE());
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.bookings WHERE purpose = N'T13-A-BOOKING-B')
    BEGIN
        INSERT INTO dbo.bookings
              (requester_id, space_id, requested_start_time, requested_end_time,
               purpose, expected_participants, booking_type, status, created_at, updated_at)
        VALUES (@u_requester_b, @space_aud,
                '2026-09-01 10:00:00', '2026-09-01 11:30:00',
                N'T13-A-BOOKING-B', 25, N'ProjectWork', N'Pending', GETDATE(), GETDATE());
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.bookings WHERE purpose = N'T13-B-BOOKING-MANUAL')
    BEGIN
        INSERT INTO dbo.bookings
              (requester_id, space_id, requested_start_time, requested_end_time,
               purpose, expected_participants, booking_type, status, created_at, updated_at)
        VALUES (@u_requester_b, @space_aud,
                '2026-09-02 08:45:00', '2026-09-02 10:10:00',
                N'T13-B-BOOKING-MANUAL', 15, N'Lecture', N'Pending', GETDATE(), GETDATE());
    END

    /* ---------------------------------------------------------------------
       5. ADVISORY MAINTENANCE + ACK for the Race C space (T13-T-CLS).
          - Advisory record M with an open window spanning the test booking.
          - assigned_staff = a FacilityStaff (satisfies TR_maintenance_StaffRole).
          - acknowledged by the requester so that approving the Race C booking
            does not trip the advisory-ack trigger when we later escalate.
       ------------------------------------------------------------------- */
    IF NOT EXISTS (SELECT 1 FROM dbo.maintenance_records WHERE problem_description = N'T13 Race C advisory')
    BEGIN
        INSERT INTO dbo.maintenance_records
              (space_id, reporter_id, assigned_staff_id, problem_description, problem_category,
               status, start_time, completion_time, result_note, impact_level, asset_id,
               created_at, updated_at)
        VALUES (@space_cls, @u_reporter, @u_staff_assign, N'T13 Race C advisory', N'BrokenProjector',
                N'InProgress', '2026-10-01 00:00:00', NULL, NULL, N'Advisory', NULL,
                GETDATE(), GETDATE());
    END

    DECLARE @maint_advisory INT = (SELECT maintenance_id FROM dbo.maintenance_records WHERE problem_description = N'T13 Race C advisory');

    IF NOT EXISTS (SELECT 1 FROM dbo.bookings WHERE purpose = N'T13-C-BOOKING')
    BEGIN
        INSERT INTO dbo.bookings
              (requester_id, space_id, requested_start_time, requested_end_time,
               purpose, expected_participants, booking_type, status, created_at, updated_at)
        VALUES (@u_requester_b, @space_cls,
                '2026-10-01 10:00:00', '2026-10-01 12:00:00',
                N'T13-C-BOOKING', 20, N'Meeting', N'Pending', GETDATE(), GETDATE());
    END

    DECLARE @bk_c INT = (SELECT booking_id FROM dbo.bookings WHERE purpose = N'T13-C-BOOKING');

    /* The acknowledgement row the approval paths demand for an active Advisory. */
    IF NOT EXISTS (SELECT 1 FROM dbo.booking_advisory_acknowledgments a
                   WHERE a.booking_id = @bk_c AND a.maintenance_id = @maint_advisory)
    BEGIN
        INSERT INTO dbo.booking_advisory_acknowledgments (booking_id, maintenance_id, acknowledged_by, acknowledged_at)
        VALUES (@bk_c, @maint_advisory, @u_requester_b, GETDATE());
    END

    COMMIT TRANSACTION;

    PRINT '';
    PRINT N'===== T13 SEED COMPLETE =====';
    SELECT N'users'  AS item, COUNT(*) AS cnt FROM dbo.user_roles
    UNION ALL SELECT N'spaces', COUNT(*) FROM dbo.spaces WHERE space_code IN (N'T13-T-AUD', N'T13-T-CLS')
    UNION ALL SELECT N'bookings', COUNT(*) FROM dbo.bookings WHERE purpose LIKE N'T13-%';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO