# Output 15: Index Tuning Report - G08

> Phase: Phase 2 - System Extension  
> Target DBMS: Microsoft SQL Server 2016 SP1+  
> Workload source: `outputs/14-data-generator-G08/`  
> Query source: `outputs/16-analytical-queries-G08.sql`

## 1. Scope

This report tunes the four required Phase 2 performance surfaces:

1. Booking conflict check used by manual approval and auto-approval.
2. Room finder: available spaces by capacity, facility list, and time window.
3. Reporting query A: total approved booking hours by space for a semester.
4. Reporting query B: approved bookings by weekday and hour for a semester.

The generated benchmark workload is deterministic: `120,000` generated bookings
over `2023-09-01` through `2026-08-31`, plus generated maintenance,
advisory acknowledgements, usage sessions, cancellations, no-shows, assets, and
alerts.

## 2. Execution Evidence Status

SQL Server execution was not available in the current editing environment: no
`sqlcmd` client was installed, and repository validation scripts are currently
deleted in the worktree. Because of that, this report does **not** invent
logical-read counts or elapsed timings.

The benchmark protocol below is exact and ready to run in SSMS or Azure Data
Studio after loading Outputs 05, 06, 10, 12, and 14. The final group report
should paste the captured `STATISTICS IO`, `STATISTICS TIME`, and actual
execution-plan screenshots into the measurement table in Section 7.

## 3. Measurement Protocol

Use the same SQL Server database for all runs.

1. Restore or create a fresh Phase 2 benchmark database.
2. Run:
   - `outputs/05-db-definition-G08.sql`
   - `outputs/06-sample-data-G08.sql`
   - `outputs/10-schema-migration-G08.sql`
   - `outputs/14-data-generator-G08/01-generate-phase2-volume-data-G08.sql`
   - `outputs/14-data-generator-G08/02-validate-phase2-volume-data-G08.sql`
3. In SSMS or Azure Data Studio, enable **Include Actual Execution Plan**.
4. For each benchmark query:
   - run the "before" version after dropping the candidate index;
   - run `DBCC FREEPROCCACHE` and `DBCC DROPCLEANBUFFERS` only in an isolated
     benchmark database, never on shared SQL Server;
   - run the query three times and record the median elapsed time;
   - create the candidate index;
   - repeat the query three times and record the median elapsed time.

Measurement commands:

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
-- paste one benchmark query here
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
```

## 4. Tuned Query 1 - Booking Conflict Check

### Query Surface

```sql
DECLARE @space_id INT = (
    SELECT TOP (1) space_id
    FROM dbo.spaces
    WHERE space_code LIKE N'G08-P2-%'
    ORDER BY space_id
);
DECLARE @new_start_time DATETIME2 = CONVERT(DATETIME2, N'2025-03-10T08:00:00', 126);
DECLARE @new_end_time   DATETIME2 = CONVERT(DATETIME2, N'2025-03-10T10:00:00', 126);

SELECT TOP (1) b.booking_id
FROM dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
WHERE b.space_id = @space_id
  AND b.status IN (N'Approved', N'CheckedIn')
  AND b.requested_start_time < @new_end_time
  AND b.requested_end_time > @new_start_time;
```

### Before

Without a matching filtered index, SQL Server can use `IX_bookings_space_id` and
then evaluate `status` and time overlap as residual predicates, or it can scan a
larger booking index. That is still logically correct, but lock granularity is
worse under `SERIALIZABLE`: SQL Server may lock many unrelated rows or escalate.

### After Index

Already defined by Output 10 as the concurrency-critical index:

```sql
CREATE INDEX IX_bookings_space_status_time
ON dbo.bookings (space_id, requested_start_time, requested_end_time)
WHERE status IN (N'Approved', N'CheckedIn');
```

Expected plan improvement:

- filtered nonclustered index seek on `space_id`;
- smaller active row set because only `Approved` and `CheckedIn` rows are in the
  index;
- key-range locks are applied to the relevant active-booking range instead of a
  broad table/index range;
- fewer logical reads and lower blocking footprint.

## 5. Tuned Query 2 - Room Finder

### Query Surface

The room finder uses the same logic as Query 3 in Output 16:

- capacity and non-retired/non-closed space filter;
- no current `Approved`/`CheckedIn` overlap;
- no overlapping `OutOfService` maintenance;
- every required facility has at least one available unit.

### Before

Without the Phase 2 indexes, SQL Server must scan `spaces`, repeatedly probe a
large `bookings` set for each candidate space, and aggregate asset rows without
a useful `(space_id, facility_name, asset_status)` key.

### After Indexes

Already defined by Output 10:

```sql
CREATE INDEX IX_roomfinder_capacity_type
ON dbo.spaces (capacity, space_type)
WHERE current_status <> N'TemporarilyClosed'
  AND current_status <> N'Retired';

CREATE INDEX IX_bookings_space_status_time
ON dbo.bookings (space_id, requested_start_time, requested_end_time)
WHERE status IN (N'Approved', N'CheckedIn');

CREATE INDEX IX_maintenance_blocking
ON dbo.maintenance_records (space_id, start_time, completion_time)
WHERE impact_level = N'OutOfService'
  AND status <> N'Completed'
  AND status <> N'Cancelled';

CREATE INDEX IX_assets_location_status
ON dbo.facility_assets (space_id, facility_name, asset_status);
```

Expected plan improvement:

- seek or narrow scan of candidate spaces by capacity;
- semi-join anti-probes against active bookings using the filtered booking
  index;
- semi-join anti-probes against active out-of-service windows using the
  filtered maintenance index;
- facility availability resolved from a compact asset index instead of scanning
  all asset rows.

## 6. Tuned Reporting Queries

### 6.1 Total Approved Booking Hours by Space

Output 10 already includes:

```sql
CREATE INDEX IX_bookings_space_status_start
ON dbo.bookings (space_id, status, requested_start_time)
WHERE status IN (N'Approved', N'CheckedIn', N'Completed');
```

That index is useful for per-space drill-downs, but the semester report scans a
date range across all spaces. A range-first reporting index is better for the
benchmark workload:

```sql
CREATE INDEX IX_bookings_report_semester_range
ON dbo.bookings (requested_start_time, space_id)
INCLUDE (booking_id, requested_end_time, status)
WHERE status IN (N'Approved', N'CheckedIn', N'Completed');
```

Expected plan improvement:

- range seek on `requested_start_time` for the semester window;
- covered access to `space_id`, `requested_end_time`, and `status`;
- lookup into `usage_sessions` through its existing unique key on `booking_id`;
- lower memory grant before the final aggregate by space.

### 6.2 Approved Bookings by Weekday and Hour

The same `IX_bookings_report_semester_range` index supports the heatmap query:

```sql
CREATE INDEX IX_bookings_report_semester_range
ON dbo.bookings (requested_start_time, space_id)
INCLUDE (booking_id, requested_end_time, status)
WHERE status IN (N'Approved', N'CheckedIn', N'Completed');
```

Expected plan improvement:

- range seek by semester instead of scanning the full booking table;
- grouping by `DATEPART(WEEKDAY, requested_start_time)` and
  `DATEPART(HOUR, requested_start_time)` happens over only the semester subset;
- fewer logical reads and a smaller aggregate input.

## 7. Measurement Table

Fill these values after running the protocol in Section 3.

| Workload | Before index plan | Before logical reads | Before CPU / elapsed | After index plan | After logical reads | After CPU / elapsed |
|---|---:|---:|---:|---:|---:|---:|
| Booking conflict check | Not executed in this environment | Not executed | Not executed | Expected: filtered index seek on `IX_bookings_space_status_time` | Not executed | Not executed |
| Room finder | Not executed in this environment | Not executed | Not executed | Expected: `IX_roomfinder_capacity_type` + filtered anti-probes | Not executed | Not executed |
| Total approved hours | Not executed in this environment | Not executed | Not executed | Expected: range seek on `IX_bookings_report_semester_range` | Not executed | Not executed |
| Weekday/hour heatmap | Not executed in this environment | Not executed | Not executed | Expected: range seek on `IX_bookings_report_semester_range` | Not executed | Not executed |

## 8. Recommended Index Bundle for Benchmarking

Output 10 already creates the core Phase 2 operational indexes. For the Task 15
reporting benchmark, add this reporting-specific index after measuring the
before state:

```sql
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_bookings_report_semester_range'
      AND object_id = OBJECT_ID(N'dbo.bookings')
)
BEGIN
    CREATE INDEX IX_bookings_report_semester_range
    ON dbo.bookings (requested_start_time, space_id)
    INCLUDE (booking_id, requested_end_time, status)
    WHERE status IN (N'Approved', N'CheckedIn', N'Completed');
END;
```

## 9. Tradeoffs

- The conflict-check filtered index is not optional. It is a correctness support
  index because it keeps SQL Server key-range locking granular under
  `SERIALIZABLE`.
- The room-finder indexes improve semi-join probes but add write cost to
  `bookings`, `maintenance_records`, and `facility_assets`. That cost is
  acceptable because booking approval and room search are primary workflows.
- The reporting index duplicates part of Output 10's report index. Keep it only
  if benchmark measurements show the range-first key materially improves the
  semester-wide reports.
- Do not replace trigger/procedure correctness with indexes. Indexes make the
  predicates seekable; the business guarantees still come from constraints,
  triggers, and Task 12 transactions.

## 10. Conclusion

The required tuning strategy is:

- keep `IX_bookings_space_status_time` for conflict checks and concurrency;
- keep the room-finder supporting indexes from Output 10;
- add `IX_bookings_report_semester_range` if the generated 120,000-row workload
  confirms lower reads for the two semester reports.

Actual timings must be captured in a SQL Server environment before the final PDF
report is submitted.

