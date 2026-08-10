/* ===========================================================================
   Output 14: Phase 2 Volume Data Generator - G08
   Target   : Microsoft SQL Server 2016 SP1+
   Purpose  : Generate a deterministic three-academic-year workload with at
              least 100,000 bookings for Tasks 15 and 16.

   Prerequisites:
      1. outputs/05-db-definition-G08.sql
      2. outputs/06-sample-data-G08.sql
      3. outputs/10-schema-migration-G08.sql

   Generated workload:
      - 240 users with user_roles rows
      - 72 spaces with facility_assets and required-facility rows
      - type-wide auto-approval policies for MeetingRoom and StudentWorkspace
      - 120,000 bookings from 2023-09-01 through 2026-08-31
      - decisions, usage sessions, cancellations, no-shows
      - advisory maintenance acknowledgements
      - maintenance escalation alerts

   Safety:
      - Non-destructive. Existing Phase 1 / Phase 2 data is preserved.
      - Re-run safe only after a complete prior run. Partial generated data
        fails loudly so staff can restore a clean benchmark database.
   =========================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET IMPLICIT_TRANSACTIONS OFF;

DECLARE @target_bookings        INT = 120000;
DECLARE @target_users           INT = 240;
DECLARE @target_spaces          INT = 72;
DECLARE @academic_start_dt      DATETIME2 = CONVERT(DATETIME2, N'2023-09-01T00:00:00', 126);
DECLARE @academic_end_exclusive DATETIME2 = CONVERT(DATETIME2, N'2026-09-01T00:00:00', 126);
DECLARE @total_days             INT = DATEDIFF(DAY, CONVERT(DATE, @academic_start_dt),
                                                    CONVERT(DATE, @academic_end_exclusive));
DECLARE @generated_department_id INT;
DECLARE @staff_id                INT;
DECLARE @space_count             INT;
DECLARE @requester_count         INT;
DECLARE @existing_generated      INT;
DECLARE @inserted_count          INT;
DECLARE @msg                     NVARCHAR(400);

PRINT N'============================================================';
PRINT N' Output 14 Phase 2 workload generator started ' + CONVERT(NVARCHAR(30), SYSDATETIME(), 121);
PRINT N'============================================================';

IF @@TRANCOUNT > 0
    THROW 52000, N'Run this generator in a session with no open transaction.', 1;

IF OBJECT_ID(N'dbo.facility_assets', N'U') IS NULL
   OR OBJECT_ID(N'dbo.space_facility_requirements', N'U') IS NULL
   OR OBJECT_ID(N'dbo.user_roles', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_advisory_acknowledgments', N'U') IS NULL
   OR OBJECT_ID(N'dbo.auto_approval_policies', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_alerts', N'U') IS NULL
BEGIN
    THROW 52001, N'Phase 2 schema not found. Run outputs/10-schema-migration-G08.sql before Output 14.', 1;
END;

IF OBJECT_ID(N'dbo.facilities', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.space_facilities', N'U') IS NOT NULL
   OR COL_LENGTH(N'dbo.user_accounts', N'role') IS NOT NULL
BEGIN
    THROW 52002, N'Phase 2 baseline amendments are not applied. Run the current Output 10 migration first.', 1;
END;

SELECT @existing_generated = COUNT(*)
FROM dbo.bookings
WHERE purpose LIKE N'P2 volume workload #%';

IF @existing_generated >= @target_bookings
BEGIN
    IF NOT EXISTS (
           SELECT 1 FROM dbo.bookings
           WHERE purpose LIKE N'P2 volume workload #%' AND status = N'Cancelled'
       )
       OR NOT EXISTS (
           SELECT 1 FROM dbo.bookings
           WHERE purpose LIKE N'P2 volume workload #%' AND status = N'NoShow'
       )
       OR NOT EXISTS (
           SELECT 1
           FROM dbo.booking_decisions bd
           JOIN dbo.bookings b ON b.booking_id = bd.booking_id
           WHERE b.purpose LIKE N'P2 volume workload #%'
             AND bd.decision_source = N'System'
       )
       OR NOT EXISTS (
           SELECT 1
           FROM dbo.maintenance_records
           WHERE problem_description LIKE N'P2 generated advisory window #%'
             AND impact_level = N'Advisory'
       )
       OR NOT EXISTS (
           SELECT 1
           FROM dbo.booking_advisory_acknowledgments a
           JOIN dbo.bookings b ON b.booking_id = a.booking_id
           WHERE b.purpose LIKE N'P2 volume workload #%'
       )
       OR NOT EXISTS (
           SELECT 1
           FROM dbo.booking_alerts ba
           JOIN dbo.maintenance_records m ON m.maintenance_id = ba.maintenance_id
           WHERE ba.alert_type = N'MaintenanceEscalated'
             AND m.problem_description LIKE N'P2 generated escalation scenario #%'
       )
    BEGIN
        THROW 52012, N'Generated booking rows exist, but required Phase 2 dependent workload rows are incomplete. Restore a clean benchmark database before regenerating.', 1;
    END;

    PRINT N'Generated workload already exists. No rows were changed.';
    SELECT N'generated bookings already present' AS metric, @existing_generated AS value
    UNION ALL
    SELECT N'generated maintenance records',
           COUNT(*) FROM dbo.maintenance_records
           WHERE problem_description LIKE N'P2 generated %'
    UNION ALL
    SELECT N'generated advisory acknowledgements',
           COUNT(*) FROM dbo.booking_advisory_acknowledgments a
           JOIN dbo.bookings b ON b.booking_id = a.booking_id
           WHERE b.purpose LIKE N'P2 volume workload #%';
    RETURN;
END;

IF @existing_generated > 0
BEGIN
    SET @msg = N'Partial generated workload found (' + CONVERT(NVARCHAR(20), @existing_generated)
             + N' bookings). Restore a clean benchmark database before regenerating.';
    THROW 52003, @msg, 1;
END;

BEGIN TRY
BEGIN TRANSACTION;

/* ---------------------------------------------------------------------------
   1. Generated department, users, and roles
   --------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM dbo.departments WHERE department_name = N'G08 Phase 2 Benchmark Department')
BEGIN
    INSERT INTO dbo.departments (department_name)
    VALUES (N'G08 Phase 2 Benchmark Department');
END;

SELECT TOP (1) @generated_department_id = department_id
FROM dbo.departments
WHERE department_name = N'G08 Phase 2 Benchmark Department'
ORDER BY department_id;

;WITH n AS (
    SELECT TOP (@target_users)
           ROW_NUMBER() OVER (ORDER BY a.object_id) AS rn
    FROM sys.all_objects AS a
)
INSERT INTO dbo.user_accounts
      (email, full_name, phone_number, account_status, department_id, created_at, updated_at)
SELECT N'g08.p2.user' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3) + N'@university.edu.vn',
       N'G08 Phase 2 User ' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3),
       N'0998' + RIGHT(N'000000' + CONVERT(NVARCHAR(10), rn), 6),
       CASE WHEN rn % 41 = 0 THEN N'Suspended'
            WHEN rn % 29 = 0 THEN N'Inactive'
            ELSE N'Active' END,
       @generated_department_id,
       DATEADD(DAY, -30, @academic_start_dt),
       DATEADD(DAY, -30, @academic_start_dt)
FROM n
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.user_accounts ua
    WHERE ua.email = N'g08.p2.user' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3) + N'@university.edu.vn'
);

;WITH generated_users AS (
    SELECT ua.user_id,
           ROW_NUMBER() OVER (ORDER BY ua.email) AS rn
    FROM dbo.user_accounts ua
    WHERE ua.email LIKE N'g08.p2.user%@university.edu.vn'
)
INSERT INTO dbo.user_roles (user_id, role)
SELECT user_id,
       CASE WHEN rn % 24 = 0 THEN N'FacilityManager'
            WHEN rn % 12 = 0 THEN N'FacilityStaff'
            WHEN rn % 10 = 0 THEN N'DepartmentAdministrator'
            WHEN rn % 5  = 0 THEN N'Lecturer'
            WHEN rn % 3  = 0 THEN N'TeachingAssistant'
            ELSE N'Student' END
FROM generated_users gu
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.user_roles ur
    WHERE ur.user_id = gu.user_id
      AND ur.role =
          CASE WHEN rn % 24 = 0 THEN N'FacilityManager'
               WHEN rn % 12 = 0 THEN N'FacilityStaff'
               WHEN rn % 10 = 0 THEN N'DepartmentAdministrator'
               WHEN rn % 5  = 0 THEN N'Lecturer'
               WHEN rn % 3  = 0 THEN N'TeachingAssistant'
               ELSE N'Student' END
);

;WITH generated_users AS (
    SELECT ua.user_id,
           ROW_NUMBER() OVER (ORDER BY ua.email) AS rn
    FROM dbo.user_accounts ua
    WHERE ua.email LIKE N'g08.p2.user%@university.edu.vn'
)
INSERT INTO dbo.user_roles (user_id, role)
SELECT user_id, N'Student'
FROM generated_users gu
WHERE rn % 31 = 0
  AND NOT EXISTS (
      SELECT 1 FROM dbo.user_roles ur
      WHERE ur.user_id = gu.user_id AND ur.role = N'Student'
  );

;WITH generated_users AS (
    SELECT ua.user_id,
           ROW_NUMBER() OVER (ORDER BY ua.email) AS rn
    FROM dbo.user_accounts ua
    WHERE ua.email LIKE N'g08.p2.user%@university.edu.vn'
)
INSERT INTO dbo.user_roles (user_id, role)
SELECT user_id, N'FacilityStaff'
FROM generated_users gu
WHERE rn % 37 = 0
  AND NOT EXISTS (
      SELECT 1 FROM dbo.user_roles ur
      WHERE ur.user_id = gu.user_id AND ur.role = N'FacilityStaff'
  );

SELECT TOP (1) @staff_id = ua.user_id
FROM dbo.user_accounts ua
JOIN dbo.user_roles ur ON ur.user_id = ua.user_id
WHERE ua.account_status = N'Active'
  AND ur.role IN (N'FacilityManager', N'FacilityStaff')
ORDER BY CASE WHEN ur.role = N'FacilityManager' THEN 0 ELSE 1 END, ua.user_id;

IF @staff_id IS NULL
    THROW 52004, N'No active generated staff user exists after role generation.', 1;

/* ---------------------------------------------------------------------------
   2. Generated spaces, assets, requirements, and policies
   --------------------------------------------------------------------------- */

;WITH n AS (
    SELECT TOP (@target_spaces)
           ROW_NUMBER() OVER (ORDER BY a.object_id) AS rn
    FROM sys.all_objects AS a
),
typed AS (
    SELECT rn,
           CASE (rn - 1) % 6
                WHEN 0 THEN N'Classroom'
                WHEN 1 THEN N'ComputerLaboratory'
                WHEN 2 THEN N'MeetingRoom'
                WHEN 3 THEN N'Auditorium'
                WHEN 4 THEN N'ProjectLaboratory'
                ELSE N'StudentWorkspace'
           END AS space_type
    FROM n
)
INSERT INTO dbo.spaces
      (space_code, space_name, space_type, building, floor, room_number,
       capacity, current_status, usage_policy, created_at, updated_at)
SELECT N'G08-P2-' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3),
       N'G08 Phase 2 Benchmark Space ' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3),
       space_type,
       N'Benchmark Building ' + CHAR(65 + ((rn - 1) % 6)),
       1 + ((rn - 1) % 5),
       N'P2-' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3),
       CASE space_type
            WHEN N'Auditorium'          THEN 160 + (rn % 40)
            WHEN N'ComputerLaboratory'  THEN 30 + (rn % 15)
            WHEN N'ProjectLaboratory'   THEN 24 + (rn % 12)
            WHEN N'MeetingRoom'         THEN 12 + (rn % 18)
            WHEN N'StudentWorkspace'    THEN 16 + (rn % 20)
            ELSE 40 + (rn % 40) END,
       N'Available',
       N'Generated benchmark space for Phase 2 analytics and tuning.',
       DATEADD(DAY, -60, @academic_start_dt),
       DATEADD(DAY, -60, @academic_start_dt)
FROM typed t
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.spaces s
    WHERE s.space_code = N'G08-P2-' + RIGHT(N'000' + CONVERT(NVARCHAR(10), t.rn), 3)
);

IF OBJECT_ID(N'tempdb..#generated_spaces') IS NOT NULL DROP TABLE #generated_spaces;

SELECT ROW_NUMBER() OVER (ORDER BY s.space_code) AS space_ord,
       s.space_id,
       s.space_code,
       s.space_type,
       s.capacity
INTO #generated_spaces
FROM dbo.spaces s
WHERE s.space_code LIKE N'G08-P2-%';

SELECT @space_count = COUNT(*) FROM #generated_spaces;

IF @space_count < @target_spaces
    THROW 52005, N'Generated space count is below target.', 1;

;WITH facility_plan AS (
    SELECT gs.space_id,
           gs.space_code,
           v.facility_name,
           v.unit_count
    FROM #generated_spaces gs
    CROSS APPLY (VALUES
        (N'Projector',
            CASE WHEN gs.space_type IN (N'Classroom', N'MeetingRoom', N'Auditorium', N'ProjectLaboratory')
                 THEN 2 ELSE 1 END),
        (N'Whiteboard', 2),
        (N'AirConditioner',
            CASE WHEN gs.space_type = N'Auditorium' THEN 6 ELSE 2 END),
        (N'ComputerStation',
            CASE WHEN gs.space_type = N'ComputerLaboratory' THEN gs.capacity
                 WHEN gs.space_type = N'ProjectLaboratory' THEN 8
                 ELSE 0 END),
        (N'SpeakerSystem',
            CASE WHEN gs.space_type IN (N'Auditorium', N'MeetingRoom') THEN 2 ELSE 0 END),
        (N'VideoConference',
            CASE WHEN gs.space_type IN (N'MeetingRoom', N'Auditorium') THEN 1 ELSE 0 END),
        (N'SmartBoard',
            CASE WHEN gs.space_type IN (N'Classroom', N'ProjectLaboratory') THEN 1 ELSE 0 END)
    ) AS v(facility_name, unit_count)
    WHERE v.unit_count > 0
),
nums AS (
    SELECT TOP (250)
           ROW_NUMBER() OVER (ORDER BY a.object_id) AS n
    FROM sys.all_objects a
)
INSERT INTO dbo.facility_assets
      (space_id, facility_name, serial_number, asset_status,
       condition, last_checked_date, created_at, updated_at)
SELECT fp.space_id,
       fp.facility_name,
       fp.space_code + N'-' + UPPER(fp.facility_name) + N'-' + RIGHT(N'000' + CONVERT(NVARCHAR(10), nums.n), 3),
       N'Available',
       N'Generated benchmark unit in working condition.',
       CONVERT(DATE, DATEADD(DAY, -14, @academic_start_dt)),
       DATEADD(DAY, -14, @academic_start_dt),
       DATEADD(DAY, -14, @academic_start_dt)
FROM facility_plan fp
JOIN nums ON nums.n <= fp.unit_count
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.facility_assets fa
    WHERE fa.serial_number = fp.space_code + N'-' + UPPER(fp.facility_name) + N'-' + RIGHT(N'000' + CONVERT(NVARCHAR(10), nums.n), 3)
);

INSERT INTO dbo.space_facility_requirements (space_id, facility_name)
SELECT gs.space_id, rf.facility_name
FROM #generated_spaces gs
CROSS APPLY (VALUES
    (N'AirConditioner'),
    (CASE WHEN gs.space_type = N'ComputerLaboratory' THEN N'ComputerStation' ELSE N'Projector' END)
) AS rf(facility_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.space_facility_requirements r
    WHERE r.space_id = gs.space_id
      AND r.facility_name = rf.facility_name
);

IF NOT EXISTS (
    SELECT 1 FROM dbo.auto_approval_policies
    WHERE space_type = N'MeetingRoom' AND is_active = 1
)
BEGIN
    INSERT INTO dbo.auto_approval_policies (space_type, space_id, max_participants, is_active, created_at, updated_at)
    VALUES (N'MeetingRoom', NULL, 24, 1, DATEADD(DAY, -30, @academic_start_dt), DATEADD(DAY, -30, @academic_start_dt));
END;

IF NOT EXISTS (
    SELECT 1 FROM dbo.auto_approval_policies
    WHERE space_type = N'StudentWorkspace' AND is_active = 1
)
BEGIN
    INSERT INTO dbo.auto_approval_policies (space_type, space_id, max_participants, is_active, created_at, updated_at)
    VALUES (N'StudentWorkspace', NULL, 20, 1, DATEADD(DAY, -30, @academic_start_dt), DATEADD(DAY, -30, @academic_start_dt));
END;

INSERT INTO dbo.policy_booking_types (policy_id, booking_type)
SELECT p.policy_id, bt.booking_type
FROM dbo.auto_approval_policies p
CROSS APPLY (VALUES (N'Meeting'), (N'StudentActivity'), (N'Workshop'), (N'ProjectWork')) AS bt(booking_type)
WHERE p.space_type IN (N'MeetingRoom', N'StudentWorkspace')
  AND p.is_active = 1
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.policy_booking_types pbt
      WHERE pbt.policy_id = p.policy_id
        AND pbt.booking_type = bt.booking_type
  );

/* ---------------------------------------------------------------------------
   3. Booking staging table
   --------------------------------------------------------------------------- */

IF OBJECT_ID(N'tempdb..#requesters') IS NOT NULL DROP TABLE #requesters;

;WITH requesters AS (
    SELECT DISTINCT ua.user_id
    FROM dbo.user_accounts ua
    JOIN dbo.user_roles ur ON ur.user_id = ua.user_id
    WHERE ua.email LIKE N'g08.p2.user%@university.edu.vn'
      AND ua.account_status = N'Active'
      AND ur.role IN (N'Student', N'Lecturer', N'TeachingAssistant',
                      N'DepartmentAdministrator', N'FacilityManager')
)
SELECT ROW_NUMBER() OVER (ORDER BY user_id) AS requester_ord,
       user_id
INTO #requesters
FROM requesters;

SELECT @requester_count = COUNT(*) FROM #requesters;

IF @requester_count < 100
    THROW 52006, N'Not enough active generated requesters exist.', 1;

IF CEILING(CONVERT(DECIMAL(18, 2), @target_bookings) / @space_count) > @total_days * 7
    THROW 52007, N'Configured target exceeds the non-overlapping slot grid.', 1;

IF OBJECT_ID(N'tempdb..#booking_stage') IS NOT NULL DROP TABLE #booking_stage;

;WITH nums AS (
    SELECT TOP (@target_bookings)
           ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) AS rn
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
base AS (
    SELECT nums.rn AS generated_seq,
           gs.space_id,
           gs.space_code,
           gs.space_type,
           gs.capacity,
           req.user_id AS requester_id,
           (nums.rn - 1) / @space_count AS slot_index
    FROM nums
    JOIN #generated_spaces gs
      ON gs.space_ord = ((nums.rn - 1) % @space_count) + 1
    JOIN #requesters req
      ON req.requester_ord = ((nums.rn - 1) % @requester_count) + 1
)
SELECT b.generated_seq,
       b.requester_id,
       b.space_id,
       b.space_code,
       b.space_type,
       b.capacity,
       DATEADD(HOUR, 8 + (2 * (b.slot_index % 7)),
           DATEADD(DAY, (b.slot_index * 37) % @total_days, @academic_start_dt)) AS requested_start_time,
       DATEADD(HOUR, 10 + (2 * (b.slot_index % 7)),
           DATEADD(DAY, (b.slot_index * 37) % @total_days, @academic_start_dt)) AS requested_end_time,
       CASE b.generated_seq % 9
            WHEN 0 THEN N'Lecture'
            WHEN 1 THEN N'Examination'
            WHEN 2 THEN N'Seminar'
            WHEN 3 THEN N'Workshop'
            WHEN 4 THEN N'Meeting'
            WHEN 5 THEN N'StudentActivity'
            WHEN 6 THEN N'AdministrativeEvent'
            WHEN 7 THEN N'ResearchActivity'
            ELSE N'ProjectWork' END AS booking_type,
       CASE WHEN b.capacity <= 5 THEN b.capacity
            ELSE 5 + (b.generated_seq % (b.capacity - 4)) END AS expected_participants,
       CASE WHEN b.generated_seq % 20 = 0 THEN N'Cancelled'
            WHEN b.generated_seq % 25 = 0 THEN N'NoShow'
            WHEN b.generated_seq % 13 = 0 THEN N'Rejected'
            WHEN b.generated_seq % 17 = 0 THEN N'Pending'
            WHEN b.generated_seq % 23 = 0 THEN N'CheckedIn'
            WHEN b.generated_seq % 29 = 0 THEN N'Approved'
            ELSE N'Completed' END AS final_status,
       N'P2 volume workload #' + RIGHT(N'000000' + CONVERT(NVARCHAR(10), b.generated_seq), 6) AS purpose,
       DATEADD(DAY, -14, DATEADD(HOUR, 8 + (2 * (b.slot_index % 7)),
           DATEADD(DAY, (b.slot_index * 37) % @total_days, @academic_start_dt))) AS created_at
INTO #booking_stage
FROM base b;

IF (SELECT COUNT(*) FROM #booking_stage) <> @target_bookings
    THROW 52008, N'Booking stage row count does not match target.', 1;

/* ---------------------------------------------------------------------------
   4. Advisory maintenance windows that require acknowledgements
   --------------------------------------------------------------------------- */

IF NOT EXISTS (
    SELECT 1 FROM dbo.maintenance_records
    WHERE problem_description LIKE N'P2 generated advisory window #%'
)
BEGIN
    ;WITH advisory_candidates AS (
        SELECT generated_seq, space_id, requested_start_time, requested_end_time,
               ROW_NUMBER() OVER (ORDER BY generated_seq) AS rn
        FROM #booking_stage
        -- Keep this divisor independent of the status distribution; using 500
        -- would only select rows already classified as Cancelled.
        WHERE generated_seq % 7 = 0
          AND final_status IN (N'Approved', N'CheckedIn', N'Completed', N'NoShow')
    )
    INSERT INTO dbo.maintenance_records
          (space_id, reporter_id, assigned_staff_id, problem_description,
           problem_category, status, start_time, completion_time, result_note,
           created_at, updated_at, impact_level, asset_id)
    SELECT space_id,
           @staff_id,
           @staff_id,
           N'P2 generated advisory window #' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3),
           CASE rn % 5
                WHEN 0 THEN N'BrokenProjector'
                WHEN 1 THEN N'ACFailure'
                WHEN 2 THEN N'DamagedFurniture'
                WHEN 3 THEN N'NetworkProblem'
                ELSE N'Other' END,
           N'InProgress',
           DATEADD(MINUTE, -15, requested_start_time),
           DATEADD(MINUTE, 15, requested_end_time),
           N'Advisory generated before approval so acknowledgements can be recorded.',
           DATEADD(DAY, -20, requested_start_time),
           DATEADD(DAY, -20, requested_start_time),
           N'Advisory',
           NULL
    FROM advisory_candidates
    WHERE rn <= 240;
END;

/* ---------------------------------------------------------------------------
   5. Insert bookings as Pending, acknowledge advisories, then publish decisions
   --------------------------------------------------------------------------- */

INSERT INTO dbo.bookings
      (requester_id, space_id, requested_start_time, requested_end_time,
       purpose, expected_participants, booking_type, status, cancelled_at,
       cancel_reason, created_at, updated_at)
SELECT requester_id, space_id, requested_start_time, requested_end_time,
       purpose, expected_participants, booking_type, N'Pending', NULL,
       NULL, created_at, created_at
FROM #booking_stage;

SELECT @inserted_count = @@ROWCOUNT;

IF @inserted_count <> @target_bookings
    THROW 52009, N'Inserted booking count does not match target.', 1;

IF OBJECT_ID(N'tempdb..#inserted_bookings') IS NOT NULL DROP TABLE #inserted_bookings;

SELECT b.booking_id,
       st.generated_seq,
       st.requester_id,
       st.space_id,
       st.space_type,
       st.booking_type,
       st.expected_participants,
       st.requested_start_time,
       st.requested_end_time,
       st.final_status,
       st.created_at
INTO #inserted_bookings
FROM #booking_stage st
JOIN dbo.bookings b
  ON b.purpose = st.purpose
 AND b.space_id = st.space_id
 AND b.requested_start_time = st.requested_start_time
 AND b.requested_end_time = st.requested_end_time;

IF (SELECT COUNT(*) FROM #inserted_bookings) <> @target_bookings
    THROW 52010, N'Could not map inserted booking IDs back to the stage rows.', 1;

INSERT INTO dbo.booking_advisory_acknowledgments
      (booking_id, maintenance_id, acknowledged_by, acknowledged_at)
SELECT ib.booking_id,
       m.maintenance_id,
       ib.requester_id,
       DATEADD(MINUTE, 1, ib.created_at)
FROM #inserted_bookings ib
JOIN dbo.maintenance_records m
  ON m.space_id = ib.space_id
 AND m.impact_level = N'Advisory'
 AND m.status NOT IN (N'Completed', N'Cancelled')
 AND m.start_time < ib.requested_end_time
 AND COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2)) > ib.requested_start_time
WHERE ib.final_status IN (N'Approved', N'CheckedIn', N'Completed', N'NoShow')
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.booking_advisory_acknowledgments a
      WHERE a.booking_id = ib.booking_id
        AND a.maintenance_id = m.maintenance_id
  );

UPDATE b
SET status = N'Approved',
    updated_at = DATEADD(MINUTE, 10, ib.created_at)
FROM dbo.bookings b
JOIN #inserted_bookings ib ON ib.booking_id = b.booking_id
WHERE ib.final_status IN (N'Approved', N'CheckedIn', N'Completed', N'NoShow');

INSERT INTO dbo.booking_decisions
      (booking_id, decided_by, decision, decision_time, decision_note,
       rejection_reason, decision_source)
SELECT ib.booking_id,
       CASE WHEN ib.final_status IN (N'Approved', N'CheckedIn', N'Completed', N'NoShow')
              AND ((ib.space_type = N'MeetingRoom'      AND ib.expected_participants <= 24)
                OR (ib.space_type = N'StudentWorkspace' AND ib.expected_participants <= 20))
              AND ib.booking_type IN (N'Meeting', N'StudentActivity', N'Workshop', N'ProjectWork')
              AND ib.generated_seq % 3 = 0
            THEN NULL
            ELSE @staff_id END,
       CASE WHEN ib.final_status = N'Rejected' THEN N'Rejected' ELSE N'Approved' END,
       DATEADD(MINUTE, 11, ib.created_at),
       CASE WHEN ib.final_status = N'Rejected'
            THEN N'Generated rejection for workload diversity.'
            ELSE N'Generated approval decision for Phase 2 workload.' END,
       CASE WHEN ib.final_status = N'Rejected'
            THEN N'Generated rejection: policy or schedule mismatch.'
            ELSE NULL END,
       CASE WHEN ib.final_status IN (N'Approved', N'CheckedIn', N'Completed', N'NoShow')
              AND ((ib.space_type = N'MeetingRoom'      AND ib.expected_participants <= 24)
                OR (ib.space_type = N'StudentWorkspace' AND ib.expected_participants <= 20))
              AND ib.booking_type IN (N'Meeting', N'StudentActivity', N'Workshop', N'ProjectWork')
              AND ib.generated_seq % 3 = 0
            THEN N'System'
            ELSE N'Staff' END
FROM #inserted_bookings ib
WHERE ib.final_status IN (N'Approved', N'CheckedIn', N'Completed', N'NoShow', N'Rejected');

INSERT INTO dbo.usage_sessions
      (booking_id, checked_in_by, actual_start_time, initial_condition,
       completed_by, actual_end_time, final_condition, usage_notes)
SELECT ib.booking_id,
       @staff_id,
       DATEADD(MINUTE, 5 + (ib.generated_seq % 4), ib.requested_start_time),
       N'Generated check-in: room accepted by requester.',
       CASE WHEN ib.final_status = N'Completed' THEN @staff_id ELSE NULL END,
       CASE WHEN ib.final_status = N'Completed'
            THEN DATEADD(MINUTE, -5 * (ib.generated_seq % 5), ib.requested_end_time)
            ELSE NULL END,
       CASE WHEN ib.final_status = N'Completed'
            THEN N'Generated completion: room returned in usable condition.'
            ELSE NULL END,
       CASE WHEN ib.final_status = N'Completed'
            THEN N'Generated completed usage session.'
            ELSE N'Generated active checked-in session.' END
FROM #inserted_bookings ib
WHERE ib.final_status IN (N'Completed', N'CheckedIn')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.usage_sessions us WHERE us.booking_id = ib.booking_id
  );

UPDATE b
SET status = ib.final_status,
    cancelled_at = CASE WHEN ib.final_status = N'Cancelled'
                        THEN DATEADD(DAY, -1, ib.requested_start_time)
                        ELSE b.cancelled_at END,
    cancel_reason = CASE WHEN ib.final_status = N'Cancelled'
                         THEN N'Generated cancellation for Phase 2 workload.'
                         ELSE b.cancel_reason END,
    updated_at = CASE WHEN ib.final_status = N'Completed'
                      THEN ib.requested_end_time
                      WHEN ib.final_status = N'CheckedIn'
                      THEN ib.requested_start_time
                      WHEN ib.final_status IN (N'NoShow', N'Cancelled', N'Rejected')
                      THEN DATEADD(MINUTE, 20, ib.created_at)
                      ELSE b.updated_at END
FROM dbo.bookings b
JOIN #inserted_bookings ib ON ib.booking_id = b.booking_id
WHERE ib.final_status IN (N'Completed', N'CheckedIn', N'NoShow', N'Cancelled', N'Rejected');

/* ---------------------------------------------------------------------------
   6. Maintenance escalation scenarios that create affected-booking alerts
   --------------------------------------------------------------------------- */

IF NOT EXISTS (
    SELECT 1 FROM dbo.maintenance_records
    WHERE problem_description LIKE N'P2 generated escalation scenario #%'
)
BEGIN
    ;WITH affected_candidates AS (
        SELECT TOP (120)
               ib.booking_id, ib.space_id, ib.requested_start_time,
               ib.requested_end_time,
               ROW_NUMBER() OVER (ORDER BY ib.generated_seq) AS rn
        FROM #inserted_bookings ib
        JOIN dbo.bookings b ON b.booking_id = ib.booking_id
        WHERE b.status IN (N'Approved', N'CheckedIn')
        ORDER BY ib.generated_seq
    )
    INSERT INTO dbo.maintenance_records
          (space_id, reporter_id, assigned_staff_id, problem_description,
           problem_category, status, start_time, completion_time, result_note,
           created_at, updated_at, impact_level, asset_id)
    SELECT space_id,
           @staff_id,
           @staff_id,
           N'P2 generated escalation scenario #' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3),
           CASE rn % 3 WHEN 0 THEN N'ACFailure'
                       WHEN 1 THEN N'NetworkProblem'
                       ELSE N'Other' END,
           N'InProgress',
           DATEADD(MINUTE, -30, requested_start_time),
           DATEADD(MINUTE, 30, requested_end_time),
           N'Generated advisory that will be escalated to OutOfService.',
           DATEADD(DAY, -1, requested_start_time),
           DATEADD(DAY, -1, requested_start_time),
           N'Advisory',
           NULL
    FROM affected_candidates;

    EXEC sys.sp_set_session_context @key = N'current_user_id', @value = @staff_id;
    EXEC sys.sp_set_session_context @key = N'change_reason', @value = N'Generated Phase 2 escalation benchmark.';

    UPDATE dbo.maintenance_records
    SET impact_level = N'OutOfService',
        updated_at = DATEADD(MINUTE, 1, updated_at),
        result_note = N'Generated escalation to OutOfService for affected-booking report.'
    WHERE problem_description LIKE N'P2 generated escalation scenario #%'
      AND impact_level = N'Advisory';

    EXEC sys.sp_set_session_context @key = N'change_reason', @value = NULL;
    EXEC sys.sp_set_session_context @key = N'current_user_id', @value = NULL;
END;

/* ---------------------------------------------------------------------------
   7. Additional asset-level maintenance variety
   --------------------------------------------------------------------------- */

IF NOT EXISTS (
    SELECT 1 FROM dbo.maintenance_records
    WHERE problem_description LIKE N'P2 generated asset maintenance #%'
)
BEGIN
    ;WITH asset_candidates AS (
        SELECT TOP (360)
               fa.asset_id,
               fa.space_id,
               ROW_NUMBER() OVER (ORDER BY fa.asset_id) AS rn
        FROM dbo.facility_assets fa
        JOIN #generated_spaces gs ON gs.space_id = fa.space_id
        WHERE fa.asset_status = N'Available'
        ORDER BY fa.asset_id
    )
    INSERT INTO dbo.maintenance_records
          (space_id, reporter_id, assigned_staff_id, problem_description,
           problem_category, status, start_time, completion_time, result_note,
           created_at, updated_at, impact_level, asset_id)
    SELECT space_id,
           @staff_id,
           @staff_id,
           N'P2 generated asset maintenance #' + RIGHT(N'000' + CONVERT(NVARCHAR(10), rn), 3),
           CASE rn % 6
                WHEN 0 THEN N'BrokenProjector'
                WHEN 1 THEN N'ACFailure'
                WHEN 2 THEN N'DamagedFurniture'
                WHEN 3 THEN N'CleaningIssue'
                WHEN 4 THEN N'NetworkProblem'
                ELSE N'Other' END,
           CASE WHEN rn % 11 = 0 THEN N'Completed'
                WHEN rn % 17 = 0 THEN N'Cancelled'
                WHEN rn % 3 = 0 THEN N'Assigned'
                ELSE N'InProgress' END,
           DATEADD(DAY, (rn * 19) % @total_days, @academic_start_dt),
           CASE WHEN rn % 11 = 0
                THEN DATEADD(HOUR, 6, DATEADD(DAY, (rn * 19) % @total_days, @academic_start_dt))
                ELSE NULL END,
           CASE WHEN rn % 11 = 0 THEN N'Generated asset repair completed.'
                WHEN rn % 17 = 0 THEN N'Generated asset repair cancelled.'
                ELSE N'Generated asset issue still open for advisory workload.' END,
           DATEADD(DAY, (rn * 19) % @total_days, @academic_start_dt),
           DATEADD(DAY, (rn * 19) % @total_days, @academic_start_dt),
           N'Advisory',
           asset_id
    FROM asset_candidates;
END;

COMMIT TRANSACTION;

PRINT N'Output 14 generation committed.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'============================================================';
PRINT N' Output 14 Phase 2 workload generator summary';
PRINT N'============================================================';

SELECT N'Generated bookings' AS metric, COUNT(*) AS value
FROM dbo.bookings
WHERE purpose LIKE N'P2 volume workload #%'
UNION ALL
SELECT N'Generated cancellations', COUNT(*)
FROM dbo.bookings
WHERE purpose LIKE N'P2 volume workload #%' AND status = N'Cancelled'
UNION ALL
SELECT N'Generated no-shows', COUNT(*)
FROM dbo.bookings
WHERE purpose LIKE N'P2 volume workload #%' AND status = N'NoShow'
UNION ALL
SELECT N'Generated usage sessions', COUNT(*)
FROM dbo.usage_sessions us
JOIN dbo.bookings b ON b.booking_id = us.booking_id
WHERE b.purpose LIKE N'P2 volume workload #%'
UNION ALL
SELECT N'Generated advisory acknowledgements', COUNT(*)
FROM dbo.booking_advisory_acknowledgments a
JOIN dbo.bookings b ON b.booking_id = a.booking_id
WHERE b.purpose LIKE N'P2 volume workload #%'
UNION ALL
SELECT N'Generated maintenance records', COUNT(*)
FROM dbo.maintenance_records
WHERE problem_description LIKE N'P2 generated %'
UNION ALL
SELECT N'Generated escalation alerts', COUNT(*)
FROM dbo.booking_alerts ba
JOIN dbo.maintenance_records m ON m.maintenance_id = ba.maintenance_id
WHERE ba.alert_type = N'MaintenanceEscalated'
  AND m.problem_description LIKE N'P2 generated escalation scenario #%';

PRINT N'Run 02-validate-phase2-volume-data-G08.sql next.';
