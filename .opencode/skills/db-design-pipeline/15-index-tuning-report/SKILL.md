# Skill: Phase 2 Index Tuning Report (Task 15)

**Role:** SQL Server Query Tuning Analyst  
**Target DBMS:** Microsoft SQL Server 2016 SP1+  
**Output File:** `outputs/15-index-tuning-report-G08.md`

## 1. Objective

Generate the Phase 2 index tuning report. The report must tune the booking
conflict check, the room finder query, and two reporting queries other than the
room finder.

## 2. Required Inputs

Read before writing:

- `CS486_Project_Phase02.pdf`
- `AGENTS.md`
- `req/business-requirement-P2.md`
- `outputs/09-updated-erd-and-logical-design-G08.md`
- `outputs/10-schema-migration-G08.sql`
- `outputs/11-concurrency-design-G08.md`
- `outputs/12-concurrency-implementation-G08.sql`
- `outputs/14-data-generator-G08/`
- `outputs/16-analytical-queries-G08.sql` if present

## 3. Required Coverage

The report must cover:

1. Booking conflict check.
2. Room finder.
3. Total approved booking hours by space.
4. Approved bookings by weekday and hour.

For each query surface, document:

- the query pattern;
- the before-index concern;
- candidate or existing indexes;
- expected or measured execution-plan change;
- logical read and timing measurement method.

## 4. Measurement Discipline

Use SQL Server tooling only:

- `SET STATISTICS IO ON`;
- `SET STATISTICS TIME ON`;
- actual execution plans in SSMS or Azure Data Studio.

If SQL Server is not available, clearly state that timings were not executed.
Do not fabricate before/after numbers. Provide executable benchmark snippets so
a teammate can capture measurements later.

## 5. SQL Server Index Rules

- Use SQL Server filtered-index syntax only.
- Keep filtered-index predicates legal for SQL Server.
- The booking conflict check must use a filtered index matching
  `status IN (N'Approved', N'CheckedIn')`.
- The room finder must be supported by capacity/status, active booking,
  out-of-service maintenance, and asset-availability access paths.

