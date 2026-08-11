USE SpaceWiseP2Demo
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

DROP INDEX IF EXISTS IX_bookings_space_status_time ON dbo.bookings;
GO

----
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

DECLARE @space_id INT =
(
    SELECT TOP (1) space_id
    FROM dbo.bookings
    WHERE purpose LIKE N'P2 volume workload #%'
    ORDER BY booking_id
);

DECLARE @new_start_time DATETIME2 = '2025-10-08T08:00:00';
DECLARE @new_end_time   DATETIME2 = '2025-10-08T10:00:00';

SELECT TOP (1) b.booking_id
FROM dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
WHERE b.space_id = @space_id
AND b.status IN (N'Approved', N'CheckedIn')
AND b.requested_start_time < @new_end_time
AND b.requested_end_time > @new_start_time;
GO

CREATE INDEX IX_bookings_space_status_time
ON dbo.bookings (space_id, requested_start_time, requested_end_time)
WHERE status IN (N'Approved', N'CheckedIn');
GO