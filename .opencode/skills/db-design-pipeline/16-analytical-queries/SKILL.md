# Skill: Phase 2 Analytical Queries (Task 16)

**Role:** SQL Server Reporting Query Designer  
**Target DBMS:** Microsoft SQL Server 2016 SP1+  
**Output File:** `outputs/16-analytical-queries-G08.sql`

## 1. Objective

Generate the SQL Server analytical query file implementing every report listed
in `CS486_Project_Phase02.pdf` section 1.3.

## 2. Required Inputs

Read before writing:

- `CS486_Project_Phase02.pdf`
- `AGENTS.md`
- `req/business-requirement-P2.md`
- `outputs/09-updated-erd-and-logical-design-G08.md`
- `outputs/10-schema-migration-G08.sql`
- `outputs/14-data-generator-G08/`
- `outputs/15-index-tuning-report-G08.md` if present

## 3. Required Reports

Implement these four reports:

1. Total approved booking hours of each space for a given semester.
2. Number of approved bookings by weekday and hour for a given semester.
3. Available spaces satisfying required capacity and required facility list
   within a given time period.
4. Approved bookings affected when a maintenance record is escalated to
   `OutOfService`.

## 4. Query Format

Each query must include comments for:

- business question;
- target user(s);
- why the query is useful;
- parameters.

Use SQL Server parameter variables and table variables where useful. Do not use
PostgreSQL arrays, range types, or JSON-specific parameter tricks.

## 5. Business Logic Rules

- Approved reporting rows are current statuses `Approved`, `CheckedIn`, and
  `Completed` that have an approved decision.
- Completed rows may use `usage_sessions` actual timestamps when present.
- Conflict checks use `Approved`/`CheckedIn` reserved intervals only.
- Room finder must exclude overlapping `OutOfService` maintenance.
- Room finder must check `facility_assets.asset_status = N'Available'` for
  requested facility types.
- Escalation lookup should read persisted `booking_alerts` where present, but
  still be able to compute affected bookings from the maintenance window.

