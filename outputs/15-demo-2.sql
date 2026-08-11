/* ============================================================
    PART 1 - DROP INDEX
    ============================================================ */

DROP INDEX IF EXISTS IX_bookings_space_status_time ON dbo.bookings;
GO
/* ============================================================
     PART 2 - QUERY INSERT
     Run once after DROP INDEX, then run again after CREATE INDEX.
     ============================================================ */

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

BEGIN TRANSACTION;

DECLARE @requester_id INT;
DECLARE @space_id INT;
DECLARE @capacity INT;
DECLARE @started_at DATETIME2(7);
DECLARE @inserted_rows INT;

DECLARE @demo_start DATETIME2(0) = DATETIME2FROMPARTS(2030, 1, 1, 8, 0, 0, 0,
0);
DECLARE @demo_end   DATETIME2(0) = DATETIME2FROMPARTS(2030, 1, 1, 18, 0, 0, 0,
0);

SELECT TOP (1) @requester_id = ua.user_id
FROM dbo.user_accounts ua
WHERE ua.account_status = N'Active'
ORDER BY ua.user_id;

SELECT TOP (1)
        @space_id = s.space_id,
        @capacity = s.capacity
FROM dbo.spaces s
WHERE s.current_status NOT IN (N'TemporarilyClosed', N'Retired')
AND NOT EXISTS (
    SELECT 1
    FROM dbo.bookings b
    WHERE b.space_id = s.space_id
        AND b.status IN (N'Approved', N'CheckedIn')
        AND b.requested_start_time < @demo_end
        AND b.requested_end_time > @demo_start
)
AND NOT EXISTS (
    SELECT 1
    FROM dbo.maintenance_records m
    WHERE m.space_id = s.space_id
        AND m.impact_level IN (N'OutOfService', N'Advisory')
        AND m.status NOT IN (N'Completed', N'Cancelled')
        AND m.start_time < @demo_end
        AND (m.completion_time IS NULL OR m.completion_time > @demo_start)
)
ORDER BY s.space_id;

IF @requester_id IS NULL OR @space_id IS NULL
    THROW 53001, N'No valid requester or space found for insert demo.', 1;

SET @started_at = SYSDATETIME();

INSERT INTO dbo.bookings (
    requester_id,
    space_id,
    requested_start_time,
    requested_end_time,
    purpose,
    expected_participants,
    booking_type,
    status,
    created_at,
    updated_at
)
SELECT @requester_id,
        @space_id,
        DATEADD(HOUR, v.slot_no * 2, @demo_start),
        DATEADD(HOUR, v.slot_no * 2 + 2, @demo_start),
        N'Index insert cost demo',
        CASE WHEN @capacity < 5 THEN @capacity ELSE 5 END,
        N'Meeting',
        N'Approved',
        SYSUTCDATETIME(),
        SYSUTCDATETIME()
FROM (VALUES (0), (1), (2), (3), (4)) AS v(slot_no);

SET @inserted_rows = @@ROWCOUNT;

SELECT N'Insert demo query' AS demo_name,
        @inserted_rows AS inserted_rows,
        DATEDIFF(MILLISECOND, @started_at, SYSDATETIME()) AS elapsed_ms;

ROLLBACK TRANSACTION;
GO

/* ============================================================
    PART 3 - CREATE INDEX
    ============================================================ */

CREATE INDEX IX_bookings_space_status_time
ON dbo.bookings (space_id, requested_start_time, requested_end_time)
WHERE status IN (N'Approved', N'CheckedIn');
GO