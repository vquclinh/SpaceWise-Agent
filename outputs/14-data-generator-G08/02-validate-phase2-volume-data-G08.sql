/* ===========================================================================
   Output 14: Phase 2 Volume Data Validation - G08
   Target   : Microsoft SQL Server 2016 SP1+
   Purpose  : Validate the generated workload from
              01-generate-phase2-volume-data-G08.sql.
   =========================================================================== */

SET NOCOUNT ON;

DECLARE @min_bookings INT = 100000;
DECLARE @booking_count INT;
DECLARE @min_start DATETIME2;
DECLARE @max_end DATETIME2;
DECLARE @span_days INT;
DECLARE @failures TABLE (
    check_name NVARCHAR(100) NOT NULL,
    result_detail NVARCHAR(400) NOT NULL
);

SELECT @booking_count = COUNT(*),
       @min_start = MIN(requested_start_time),
       @max_end = MAX(requested_end_time)
FROM dbo.bookings
WHERE purpose LIKE N'P2 volume workload #%';

SET @span_days = DATEDIFF(DAY, @min_start, @max_end);

IF @booking_count < @min_bookings
    INSERT INTO @failures VALUES
    (N'booking volume', N'Expected at least 100,000 generated bookings.');

IF @span_days < 1090
    INSERT INTO @failures VALUES
    (N'academic-year span', N'Generated bookings do not span at least three academic years.');

IF NOT EXISTS (
    SELECT 1 FROM dbo.bookings
    WHERE purpose LIKE N'P2 volume workload #%' AND status = N'Cancelled'
)
    INSERT INTO @failures VALUES
    (N'cancellations', N'No generated cancelled bookings found.');

IF NOT EXISTS (
    SELECT 1 FROM dbo.bookings
    WHERE purpose LIKE N'P2 volume workload #%' AND status = N'NoShow'
)
    INSERT INTO @failures VALUES
    (N'no-shows', N'No generated no-show bookings found.');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.booking_decisions bd
    JOIN dbo.bookings b ON b.booking_id = bd.booking_id
    WHERE b.purpose LIKE N'P2 volume workload #%'
      AND bd.decision = N'Approved'
)
    INSERT INTO @failures VALUES
    (N'approved decisions', N'No generated approved booking decisions found.');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.booking_decisions bd
    JOIN dbo.bookings b ON b.booking_id = bd.booking_id
    WHERE b.purpose LIKE N'P2 volume workload #%'
      AND bd.decision_source = N'System'
)
    INSERT INTO @failures VALUES
    (N'system decisions', N'No generated System auto-approval decisions found.');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.usage_sessions us
    JOIN dbo.bookings b ON b.booking_id = us.booking_id
    WHERE b.purpose LIKE N'P2 volume workload #%'
      AND b.status = N'Completed'
      AND us.actual_end_time IS NOT NULL
)
    INSERT INTO @failures VALUES
    (N'usage sessions', N'No generated completed usage sessions found.');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.maintenance_records
    WHERE problem_description LIKE N'P2 generated %'
)
    INSERT INTO @failures VALUES
    (N'maintenance records', N'No generated maintenance records found.');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.maintenance_records
    WHERE problem_description LIKE N'P2 generated %'
      AND impact_level = N'Advisory'
)
    INSERT INTO @failures VALUES
    (N'advisory maintenance', N'No generated Advisory maintenance records found.');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.maintenance_records
    WHERE problem_description LIKE N'P2 generated escalation scenario #%'
      AND impact_level = N'OutOfService'
)
    INSERT INTO @failures VALUES
    (N'out-of-service escalation', N'No generated OutOfService escalation records found.');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.booking_advisory_acknowledgments a
    JOIN dbo.bookings b ON b.booking_id = a.booking_id
    WHERE b.purpose LIKE N'P2 volume workload #%'
)
    INSERT INTO @failures VALUES
    (N'advisory acknowledgements', N'No generated advisory acknowledgements found.');

IF NOT EXISTS (
    SELECT 1
    FROM dbo.booking_alerts ba
    JOIN dbo.maintenance_records m ON m.maintenance_id = ba.maintenance_id
    WHERE ba.alert_type = N'MaintenanceEscalated'
      AND m.problem_description LIKE N'P2 generated escalation scenario #%'
)
    INSERT INTO @failures VALUES
    (N'escalation alerts', N'No generated maintenance escalation alerts found.');

IF EXISTS (
    SELECT 1
    FROM dbo.bookings b1
    JOIN dbo.bookings b2
      ON b1.space_id = b2.space_id
     AND b1.booking_id < b2.booking_id
     AND b1.requested_start_time < b2.requested_end_time
     AND b1.requested_end_time > b2.requested_start_time
    WHERE b1.purpose LIKE N'P2 volume workload #%'
      AND b2.purpose LIKE N'P2 volume workload #%'
      AND b1.status IN (N'Approved', N'CheckedIn')
      AND b2.status IN (N'Approved', N'CheckedIn')
)
    INSERT INTO @failures VALUES
    (N'active overlap invariant', N'Generated Approved/CheckedIn bookings overlap on the same space.');

IF EXISTS (
    SELECT 1 FROM @failures
)
BEGIN
    SELECT check_name, result_detail
    FROM @failures
    ORDER BY check_name;
    THROW 52100, N'Output 14 generated workload validation failed.', 1;
END;

PRINT N'Output 14 generated workload validation passed.';

SELECT N'Generated bookings' AS metric, @booking_count AS value
UNION ALL
SELECT N'Generated span days', @span_days
UNION ALL
SELECT N'Cancelled generated bookings',
       COUNT(*) FROM dbo.bookings
       WHERE purpose LIKE N'P2 volume workload #%' AND status = N'Cancelled'
UNION ALL
SELECT N'No-show generated bookings',
       COUNT(*) FROM dbo.bookings
       WHERE purpose LIKE N'P2 volume workload #%' AND status = N'NoShow'
UNION ALL
SELECT N'Generated advisory acknowledgements',
       COUNT(*) FROM dbo.booking_advisory_acknowledgments a
       JOIN dbo.bookings b ON b.booking_id = a.booking_id
       WHERE b.purpose LIKE N'P2 volume workload #%'
UNION ALL
SELECT N'Generated maintenance records',
       COUNT(*) FROM dbo.maintenance_records
       WHERE problem_description LIKE N'P2 generated %'
UNION ALL
SELECT N'Generated escalation alerts',
       COUNT(*) FROM dbo.booking_alerts ba
       JOIN dbo.maintenance_records m ON m.maintenance_id = ba.maintenance_id
       WHERE ba.alert_type = N'MaintenanceEscalated'
         AND m.problem_description LIKE N'P2 generated escalation scenario #%';

SELECT b.status, COUNT(*) AS generated_booking_count
FROM dbo.bookings b
WHERE b.purpose LIKE N'P2 volume workload #%'
GROUP BY b.status
ORDER BY b.status;

SELECT YEAR(b.requested_start_time) AS calendar_year,
       COUNT(*) AS generated_booking_count
FROM dbo.bookings b
WHERE b.purpose LIKE N'P2 volume workload #%'
GROUP BY YEAR(b.requested_start_time)
ORDER BY calendar_year;

