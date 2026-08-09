# Output 14: Phase 2 Data Generator - G08

## Purpose

This folder contains SQL Server scripts that generate a large Phase 2 workload
for query tuning and analytical reporting.

The generator targets:

- 3 academic years: `2023-09-01` through `2026-08-31`
- 120,000 deterministic `G08-P2` booking records
- generated users, roles, spaces, assets, required-facility policies,
  auto-approval policies, maintenance records, advisory acknowledgements,
  cancellations, no-shows, usage sessions, and escalation alerts

## Prerequisites

Run these first on a SQL Server database:

1. `outputs/05-db-definition-G08.sql`
2. `outputs/06-sample-data-G08.sql`
3. `outputs/10-schema-migration-G08.sql`
4. `outputs/12-concurrency-implementation-G08.sql` if stored procedures are
   being tested in the same database

The generator requires the Phase 2 schema from Output 10. It refuses to run if
Phase 2 tables such as `facility_assets`, `user_roles`, and
`booking_advisory_acknowledgments` are missing.

## Run Order

1. Execute `01-generate-phase2-volume-data-G08.sql`.
2. Execute `02-validate-phase2-volume-data-G08.sql`.
3. Use `outputs/16-analytical-queries-G08.sql` for reports.
4. Use `outputs/15-index-tuning-report-G08.md` as the benchmark protocol.

## Re-run Behavior

The generator is intentionally non-destructive:

- If at least 120,000 generated bookings already exist, it prints a summary and
  exits.
- If a partial generated workload exists, it raises an error instead of deleting
  or overwriting data.

Use a fresh restored benchmark database when you need to regenerate the workload
from scratch.

