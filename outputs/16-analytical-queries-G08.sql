/* ===========================================================================
   Output 16: Analytical Queries - G08 (Phase 2)
   Target   : Microsoft SQL Server 2016 SP1+

   Reports implemented from CS486_Project_Phase02.pdf section 1.3:
      1. Total approved booking hours of each space for a given semester.
      2. Number of approved bookings by weekday and hour for a given semester.
      3. Available spaces satisfying capacity and facility requirements within
         a given time period.
      4. Approved bookings affected when maintenance is escalated to
         OutOfService.

   Status convention:
      Approved lifecycle rows are bookings with an Approved decision and a
      current status in (Approved, CheckedIn, Completed). Cancelled, Rejected,
      Pending, and NoShow rows are excluded from approved-hours reports.

   Time convention:
      Completed rows use actual usage-session timestamps when present.
      Approved/CheckedIn rows use the reserved requested interval.
   =========================================================================== */

SET NOCOUNT ON;

/* ===========================================================================
   Query 1
   ---------------------------------------------------------------------------
   Business question:
      For a given semester, how many approved booking hours did each space
      accumulate?
   Target user(s):
      Facility Manager, Department Administrator.
   Why this query is useful:
      It identifies highly used and underused spaces, supporting semester
      planning, maintenance windows, and capacity decisions.
   Parameters:
      Change @semester_start and @semester_end for the reporting semester.
   =========================================================================== */

DECLARE @semester_start DATETIME2 = CONVERT(DATETIME2, N'2025-09-01T00:00:00', 126);
DECLARE @semester_end   DATETIME2 = CONVERT(DATETIME2, N'2026-01-19T00:00:00', 126);

;WITH approved_bookings AS (
    SELECT b.booking_id,
           b.space_id,
           COALESCE(us.actual_start_time, b.requested_start_time) AS effective_start_time,
           COALESCE(us.actual_end_time, b.requested_end_time) AS effective_end_time
    FROM dbo.bookings b
    LEFT JOIN dbo.usage_sessions us ON us.booking_id = b.booking_id
    WHERE b.status IN (N'Approved', N'CheckedIn', N'Completed')
      AND b.requested_start_time < @semester_end
      AND b.requested_end_time > @semester_start
      AND EXISTS (
          SELECT 1
          FROM dbo.booking_decisions bd
          WHERE bd.booking_id = b.booking_id
            AND bd.decision = N'Approved'
      )
),
clipped AS (
    SELECT booking_id,
           space_id,
           CASE WHEN effective_start_time < @semester_start
                THEN @semester_start ELSE effective_start_time END AS clipped_start_time,
           CASE WHEN effective_end_time > @semester_end
                THEN @semester_end ELSE effective_end_time END AS clipped_end_time
    FROM approved_bookings
    WHERE effective_start_time < @semester_end
      AND effective_end_time > @semester_start
)
SELECT s.space_id,
       s.space_code,
       s.space_name,
       s.space_type,
       COUNT(c.booking_id) AS approved_booking_count,
       CAST(SUM(DATEDIFF(MINUTE, c.clipped_start_time, c.clipped_end_time)) / 60.0 AS DECIMAL(12, 2))
           AS approved_booking_hours
FROM dbo.spaces s
LEFT JOIN clipped c ON c.space_id = s.space_id
GROUP BY s.space_id, s.space_code, s.space_name, s.space_type
ORDER BY approved_booking_hours DESC, s.space_code;
GO

/* ===========================================================================
   Query 2
   ---------------------------------------------------------------------------
   Business question:
      For a given semester, how many approved bookings start on each weekday
      and hour?
   Target user(s):
      Facility Manager, Facility Staff.
   Why this query is useful:
      It shows demand peaks by day and hour, helping staff schedule cleaning,
      room inspections, and future capacity allocation.
   Parameters:
      Change @semester_start and @semester_end for the reporting semester.
   =========================================================================== */

SET DATEFIRST 1;

DECLARE @semester_start DATETIME2 = CONVERT(DATETIME2, N'2025-09-01T00:00:00', 126);
DECLARE @semester_end   DATETIME2 = CONVERT(DATETIME2, N'2026-01-19T00:00:00', 126);

SELECT DATEPART(WEEKDAY, b.requested_start_time) AS weekday_number_monday_1,
       CASE DATEPART(WEEKDAY, b.requested_start_time)
            WHEN 1 THEN N'Monday'
            WHEN 2 THEN N'Tuesday'
            WHEN 3 THEN N'Wednesday'
            WHEN 4 THEN N'Thursday'
            WHEN 5 THEN N'Friday'
            WHEN 6 THEN N'Saturday'
            ELSE N'Sunday' END AS weekday_name,
       DATEPART(HOUR, b.requested_start_time) AS start_hour,
       COUNT(*) AS approved_booking_count
FROM dbo.bookings b
WHERE b.status IN (N'Approved', N'CheckedIn', N'Completed')
  AND b.requested_start_time >= @semester_start
  AND b.requested_start_time < @semester_end
  AND EXISTS (
      SELECT 1
      FROM dbo.booking_decisions bd
      WHERE bd.booking_id = b.booking_id
        AND bd.decision = N'Approved'
  )
GROUP BY DATEPART(WEEKDAY, b.requested_start_time),
         CASE DATEPART(WEEKDAY, b.requested_start_time)
              WHEN 1 THEN N'Monday'
              WHEN 2 THEN N'Tuesday'
              WHEN 3 THEN N'Wednesday'
              WHEN 4 THEN N'Thursday'
              WHEN 5 THEN N'Friday'
              WHEN 6 THEN N'Saturday'
              ELSE N'Sunday' END,
         DATEPART(HOUR, b.requested_start_time)
ORDER BY weekday_number_monday_1, start_hour;
GO

/* ===========================================================================
   Query 3
   ---------------------------------------------------------------------------
   Business question:
      Which spaces are available for a requested time period, satisfy a minimum
      capacity, and have all required facility types available?
   Target user(s):
      Requesters, Facility Staff.
   Why this query is useful:
      It is the operational room finder. It applies booking conflicts,
      OutOfService maintenance, closed/retired space status, and facility
      availability in one query.
   Parameters:
      Change @required_capacity, @required_start_time, @required_end_time, and
      the rows inserted into @required_facilities.
   =========================================================================== */

DECLARE @required_capacity INT = 24;
DECLARE @required_start_time DATETIME2 = CONVERT(DATETIME2, N'2025-10-08T08:00:00', 126);
DECLARE @required_end_time   DATETIME2 = CONVERT(DATETIME2, N'2025-10-08T10:00:00', 126);

DECLARE @required_facilities TABLE (
    facility_name NVARCHAR(100) NOT NULL PRIMARY KEY
);

INSERT INTO @required_facilities (facility_name)
VALUES (N'Projector'), (N'AirConditioner');

SELECT s.space_id,
       s.space_code,
       s.space_name,
       s.space_type,
       s.building,
       s.floor,
       s.room_number,
       s.capacity,
       COUNT(DISTINCT rf.facility_name) AS required_facilities_matched
FROM dbo.spaces s
LEFT JOIN @required_facilities rf ON 1 = 1
WHERE s.capacity >= @required_capacity
  AND s.current_status <> N'TemporarilyClosed'
  AND s.current_status <> N'Retired'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.bookings b
      WHERE b.space_id = s.space_id
        AND b.status IN (N'Approved', N'CheckedIn')
        AND b.requested_start_time < @required_end_time
        AND b.requested_end_time > @required_start_time
  )
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.maintenance_records m
      WHERE m.space_id = s.space_id
        AND m.impact_level = N'OutOfService'
        AND m.status <> N'Completed'
        AND m.status <> N'Cancelled'
        AND m.start_time < @required_end_time
        AND COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2)) > @required_start_time
  )
  AND NOT EXISTS (
      SELECT 1
      FROM @required_facilities need
      WHERE NOT EXISTS (
          SELECT 1
          FROM dbo.facility_assets fa
          WHERE fa.space_id = s.space_id
            AND fa.facility_name = need.facility_name
            AND fa.asset_status = N'Available'
      )
  )
GROUP BY s.space_id, s.space_code, s.space_name, s.space_type,
         s.building, s.floor, s.room_number, s.capacity
ORDER BY s.capacity ASC, s.space_code;
GO

/* ===========================================================================
   Query 4
   ---------------------------------------------------------------------------
   Business question:
      Which approved or checked-in bookings are affected when a maintenance
      record is escalated to OutOfService?
   Target user(s):
      Facility Manager, Facility Staff.
   Why this query is useful:
      It gives staff the action list required by Phase 2: contact affected
      requesters, relocate bookings, or cancel bookings manually.
   Parameters:
      Set @maintenance_id to the escalated maintenance record. The default picks
      the latest generated escalation scenario if Output 14 has been loaded.
   =========================================================================== */

DECLARE @maintenance_id INT;

SELECT TOP (1) @maintenance_id = m.maintenance_id
FROM dbo.maintenance_records m
WHERE m.impact_level = N'OutOfService'
  AND m.problem_description LIKE N'P2 generated escalation scenario #%'
ORDER BY m.maintenance_id DESC;

;WITH target_maintenance AS (
    SELECT m.maintenance_id,
           m.space_id,
           m.problem_description,
           m.problem_category,
           m.start_time,
           COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2)) AS effective_completion_time
    FROM dbo.maintenance_records m
    WHERE m.maintenance_id = @maintenance_id
      AND m.impact_level = N'OutOfService'
),
affected_bookings AS (
    SELECT tm.maintenance_id,
           b.booking_id
    FROM target_maintenance tm
    JOIN dbo.bookings b
      ON b.space_id = tm.space_id
     AND b.status IN (N'Approved', N'CheckedIn')
     AND b.requested_start_time < tm.effective_completion_time
     AND b.requested_end_time > tm.start_time
)
SELECT tm.maintenance_id,
       tm.problem_description,
       tm.problem_category,
       s.space_code,
       s.space_name,
       b.booking_id,
       b.status AS booking_status,
       b.requested_start_time,
       b.requested_end_time,
       ua.full_name AS requester_name,
       ua.email AS requester_email,
       ba.alert_id,
       CASE WHEN ba.alert_id IS NULL THEN N'NotPersisted'
            WHEN ba.acknowledged_at IS NULL THEN N'Open'
            ELSE N'Handled' END AS alert_status,
       ba.created_at AS alert_created_at,
       ba.acknowledged_at AS alert_acknowledged_at
FROM affected_bookings ab
JOIN target_maintenance tm ON tm.maintenance_id = ab.maintenance_id
JOIN dbo.bookings b ON b.booking_id = ab.booking_id
JOIN dbo.spaces s ON s.space_id = b.space_id
JOIN dbo.user_accounts ua ON ua.user_id = b.requester_id
LEFT JOIN dbo.booking_alerts ba
  ON ba.maintenance_id = tm.maintenance_id
 AND ba.booking_id = b.booking_id
 AND ba.alert_type = N'MaintenanceEscalated'
ORDER BY b.requested_start_time, b.booking_id;
GO

