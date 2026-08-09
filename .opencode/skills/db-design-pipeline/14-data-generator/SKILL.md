# Skill: Phase 2 Data Generator (Task 14)

**Role:** SQL Server Data Engineer  
**Target DBMS:** Microsoft SQL Server 2016 SP1+  
**Output Directory:** `outputs/14-data-generator-G08/`

## 1. Objective

Generate deterministic SQL Server scripts that create the large Phase 2 workload
required by `CS486_Project_Phase02.pdf`: at least three academic years of data
and at least 100,000 booking records.

## 2. Required Inputs

Read before writing:

- `CS486_Project.pdf`
- `CS486_Project_Phase02.pdf`
- `AGENTS.md`
- `req/business-requirement-P2.md`
- Phase 1 outputs `outputs/01` through `outputs/07`
- `outputs/08-requirement-change-analysis-G08.md`
- `outputs/09-updated-erd-and-logical-design-G08.md`
- `outputs/10-schema-migration-G08.sql`
- Outputs `11`, `12`, and `13` if present

## 3. Required Files

Create or update exactly these files:

- `outputs/14-data-generator-G08/README.md`
- `outputs/14-data-generator-G08/01-generate-phase2-volume-data-G08.sql`
- `outputs/14-data-generator-G08/02-validate-phase2-volume-data-G08.sql`

## 4. Data Requirements

The generator must:

- require the migrated Phase 2 schema from Output 10;
- use SQL Server syntax only;
- generate at least 100,000 bookings, targeting 120,000 unless instructed
  otherwise;
- span at least three academic years, defaulting to `2023-09-01` through
  `2026-08-31`;
- include generated users, `user_roles`, spaces, `facility_assets`,
  `space_facility_requirements`, `auto_approval_policies`,
  `policy_booking_types`, bookings, booking decisions, usage sessions,
  maintenance records, advisory acknowledgements, cancellations, no-shows, and
  escalation alerts;
- use deterministic `G08-P2-*` / `P2 generated *` markers;
- preserve existing Phase 1 and Phase 2 rows;
- refuse to run on a partial generated workload instead of deleting data.

## 5. Validation Requirements

The validation script must prove:

- generated booking count is at least 100,000;
- generated booking dates cover at least three academic years;
- generated cancellations, no-shows, maintenance records, advisory
  acknowledgements, approved decisions, System decisions, and escalation alerts
  exist;
- generated `Approved`/`CheckedIn` bookings have no overlapping active booking
  on the same space.

## 6. SQL Rules

- Use `NVARCHAR` and Unicode `N''` literals.
- Use `DATETIME2`, `DATEADD`, `DATEDIFF`, `DATEPART`, and SQL Server CTEs.
- Do not use PostgreSQL constructs.
- Use half-open overlap predicates:
  `existing_start < @new_end AND existing_end > @new_start`.
- Do not use `spaces.current_status = 'UnderMaintenance'` as a maintenance
  blocking predicate; use `maintenance_records.impact_level = 'OutOfService'`.

