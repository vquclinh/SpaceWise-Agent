/* ===========================================================================
   Task 13 — Global Cleanup: restore the pristine post-migration state
   File:  outputs/13-concurrency-tests-G08/99-cleanup.sql
   Target: Microsoft SQL Server 2016 SP1+ (single SSMS window)

   PURPOSE — DELETE every row the Task 13 harness planted into the database:
     (1) the seed dataset written by 00-setup-test-data.sql (test department,
         the six t13.* users + their user_roles rows, the two T13-T-* spaces,
         the auto-approval policy + policy_booking_types, the four Pending
         bookings, the 'T13 Race C advisory' maintenance record and its
         acknowledgement row), AND
     (2) every row the race/verification files 01-04 generate at run time
         (T13-B-INSTANT-RAW / T13-B-INSTANT-PROTECTED bookings, T13-ECO-*
         bookings + their usage_sessions, the booking_decisions written by
         usp_ApproveBooking / usp_CreateBookingAutoApproved, and the
         booking_alerts / maintenance_impact_history rows written by the
         escalation triggers in file 03).

   RESULT — the database is back EXACTLY to the state it had right after
   outputs/10-schema-migration-G08.sql committed. No trace of the T13
   harness remains, so outputs/14-data-generator-G08.sql starts from a clean
   slate. It is safe (and a no-op) to run the file more than once.

   IDENTIFICATION — every harness row carries a stable T13 marker:
       bookings.purpose                  LIKE N'T13-%'
       spaces.space_code                 LIKE N'T13-%'
       user_accounts.email               LIKE N't13.%' / N'T13.%'
       maintenance_records.problem_description LIKE N'T13 %'  (the seed advisory)
       departments.department_name       = N'T13 Test dept'
   Deleting ONLY by these keys never touches Phase 1 baseline data or the
   outputs/06 sample data.

   FK-SAFE DELETE ORDER (children before parents):
       1. booking_alerts / booking_advisory_acknowledgments (child of
          bookings AND maintenance_records AND user_accounts)
       2. usage_sessions / booking_decisions        (child of bookings, users)
       3. maintenance_impact_history                (child of maintenance, users)
       4. policy_booking_types -> auto_approval_policies   (child spaces)
       5. policy_booking_types / auto_approval_policies
       6. bookings                                  (child of spaces, users)
       7. maintenance_records                       (child of spaces, users)
       8. facility_assets / space_facility_requirements (child of spaces)
       9. user_roles -> user_accounts
      10. spaces -> user_accounts -> departments
   =========================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;
BEGIN TRY

    /* ---- 1. Rows that hang off the T13 bookings / maintenance records ---- */
    DELETE FROM dbo.booking_alerts
    WHERE  booking_id IN (SELECT booking_id FROM dbo.bookings WHERE purpose LIKE N'T13-%')
       OR  maintenance_id IN (
                SELECT maintenance_id FROM dbo.maintenance_records
                WHERE problem_description LIKE N'T13 %'
                   OR space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%')
           );
    PRINT N'[cleanup] booking_alerts deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.booking_advisory_acknowledgments
    WHERE  booking_id IN (SELECT booking_id FROM dbo.bookings WHERE purpose LIKE N'T13-%')
       OR  maintenance_id IN (
                SELECT maintenance_id FROM dbo.maintenance_records
                WHERE problem_description LIKE N'T13 %'
                   OR space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%')
           );
    PRINT N'[cleanup] booking_advisory_acknowledgments deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.usage_sessions
    WHERE  booking_id IN (SELECT booking_id FROM dbo.bookings WHERE purpose LIKE N'T13-%');
    PRINT N'[cleanup] usage_sessions deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.booking_decisions
    WHERE  booking_id IN (SELECT booking_id FROM dbo.bookings WHERE purpose LIKE N'T13-%');
    PRINT N'[cleanup] booking_decisions deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.maintenance_impact_history
    WHERE  maintenance_id IN (
                SELECT maintenance_id FROM dbo.maintenance_records
                WHERE problem_description LIKE N'T13 %'
                   OR space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%')
           );
    PRINT N'[cleanup] maintenance_impact_history deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    /* ---- 2. Auto-approval policy tree (space-specific, owns the policy) -- */
    DELETE FROM dbo.policy_booking_types
    WHERE  policy_id IN (
                SELECT p.policy_id
                FROM   dbo.auto_approval_policies p
                WHERE  p.space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%')
           );
    PRINT N'[cleanup] policy_booking_types deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.auto_approval_policies
    WHERE  space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%');
    PRINT N'[cleanup] auto_approval_policies deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    /* ---- 3. The bookings and maintenance rows themselves ----------------- */
    DELETE FROM dbo.bookings WHERE purpose LIKE N'T13-%';
    PRINT N'[cleanup] bookings deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.maintenance_records
    WHERE  problem_description LIKE N'T13 %'
       OR  space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%');
    PRINT N'[cleanup] maintenance_records deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    /* ---- 4. Space-owned catalogues (not seeded, but removed for safety when
              a tester manually added T13 assets / requirements) ------------ */
    DELETE FROM dbo.facility_assets
    WHERE  space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%');
    PRINT N'[cleanup] facility_assets deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.space_facility_requirements
    WHERE  space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%');
    PRINT N'[cleanup] space_facility_requirements deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    /* ---- 5. The core resources: roles, spaces, users, department --------- */
    DELETE FROM dbo.user_roles
    WHERE  user_id IN (
                SELECT user_id FROM dbo.user_accounts
                WHERE email LIKE N't13.%' OR email LIKE N'T13.%'
           );
    PRINT N'[cleanup] user_roles deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.spaces WHERE space_code LIKE N'T13-%';
    PRINT N'[cleanup] spaces deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.user_accounts WHERE email LIKE N't13.%' OR email LIKE N'T13.%';
    PRINT N'[cleanup] user_accounts deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    DELETE FROM dbo.departments WHERE department_name = N'T13 Test dept';
    PRINT N'[cleanup] departments deleted: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

    COMMIT TRANSACTION;

    /* ---- 6. Verification: every T13 marker must be gone ------------------- */
    PRINT N'';
    PRINT N'===== T13 CLEANUP COMPLETE =====';
    SELECT 'bookings'    AS marker, COUNT(*) AS remaining
    FROM   dbo.bookings
    WHERE  purpose LIKE N'T13-%'
    UNION ALL
    SELECT 'spaces', COUNT(*)
    FROM   dbo.spaces
    WHERE  space_code LIKE N'T13-%'
    UNION ALL
    SELECT 'users', COUNT(*)
    FROM   dbo.user_accounts
    WHERE  email LIKE N't13.%' OR email LIKE N'T13.%'
    UNION ALL
    SELECT 'maintenance', COUNT(*)
    FROM   dbo.maintenance_records
    WHERE  problem_description LIKE N'T13 %'
       OR  space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%')
    UNION ALL
    SELECT 'policies', COUNT(*)
    FROM   dbo.auto_approval_policies
    WHERE  space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T13-%');

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO