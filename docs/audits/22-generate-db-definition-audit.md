# Audit — 22: Generate Database Definition (DDL)

> Date: 2026-06-26
> Operator/member: Vi (AI agent)
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: `/05-generate-db-definition`

## Task goal

Generate the Microsoft SQL Server DDL script (`outputs/05-db-definition-G08.sql`) implementing all 9 tables with constraints, indexes, and triggers based on the validated logical design (Output 03) and design validation (Output 04).

## Files created / changed

- Created: `outputs/05-db-definition-G08.sql`
- Created: `docs/audits/22-generate-db-definition-audit.md`

## What was evaluated

- All 9 table definitions from `03-logical-design-G08.md` Section 3 (columns, types, nullability)
- All 4 UNIQUE constraints (Section 5)
- All 16 CHECK constraints (Section 5)
- All DEFAULT values (Section 5)
- All 13 index recommendations (Section 6)
- Trigger strategy for business rules 1 & 2 from Output 04 Sections 4-5
- FK definitions (13 relationships) from Section 4 & Output 04 Section 6

## Issues found

None during generation. The logical design was complete and consistent.

## Changes made

Created a complete DDL script with:

1. **9 tables** in dependency order (departments → user_accounts → spaces → facilities → space_facilities → bookings → booking_decisions → usage_sessions → maintenance_records)
2. **All constraints**: 9 PK, 13 FK, 4 UNIQUE, 16 CHECK, 7 DEFAULT
3. **13 indexes** for lookup/filter paths
4. **1 INSTEAD OF trigger** (`TR_bookings_PreventOverlapAndUnavailable`) enforcing:
   - No overlapping approved bookings (rule 1)
   - Space availability check (rule 2)
5. **Detailed constraint summary** at end for professor/TA review
6. Trigger uses `THROW` (SQL Server 2012+) for error handling
7. Uses `NVARCHAR`, `DATETIME2`, `IDENTITY(1,1)` — correct SQL Server syntax

## Improvement classification

- Output refinement

## Validation commands run

N/A — setup stage (no SQL Server instance available for validation).

## Validation results

N/A — manual review confirms all constraints match the logical design specification.

## Risks / caveats

- The `INSTEAD OF` trigger on `bookings` replaces standard INSERT/UPDATE logic, which means it explicitly sets `created_at`/`updated_at`. If external tools or bulk inserts bypass the trigger, those timestamps may be stale.
- The overlap check reads from `bookings` while the trigger runs; under `READ COMMITTED` (default), concurrent transactions could create overlapping bookings. For production, `SERIALIZABLE` isolation or `UPDLOCK`/`HOLDLOCK` hints should be considered.
- No `ON DELETE` actions are specified (all default to `NO ACTION`), which is correct for data preservation but means deletion of referenced master records requires explicit handling.

## Git status summary

New files staged:
- `outputs/05-db-definition-G08.sql`
- `docs/audits/22-generate-db-definition-audit.md`

## Recommended next steps

1. Execute the DDL against a SQL Server instance to validate syntax.
2. Generate sample data (`06-sample-data-G08.sql`) to populate the schema.
3. Proceed to query design (`07-query-design-G08.sql`).
