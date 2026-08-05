---
description: Task 10 (Schema Migration) — generate the additive T-SQL migration that transforms the Phase 1 database into the Phase 2 database, preserving all Phase 1 data. Run on a SQL Server-compatible environment.
---

# /10-generate-schema-migration

DBA command that authors `outputs/10-schema-migration-G08.sql`. It migrates the Phase 1 baseline (`outputs/05-db-definition-G08.sql` + `outputs/06-sample-data-G08.sql`) to the Phase 2 schema defined in Output 09, preserving 100% of Phase 1 data.

**Roles:** this command owns the **workflow and output requirements**; the task skill (`.opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md`) owns the **DBA technical rules** (execution order, backfill T-SQL, trigger specs, view SQL, transactional-safety pattern). They do not repeat each other.

## Usage

```text
/10-generate-schema-migration
```

## Instructions for the Agent

1. **Use the Task 10 Skill:** read `.opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md` and follow every rule.
2. **Read inputs:** `outputs/09-updated-erd-and-logical-design-G08.md` (target schema — primary authority), `outputs/08-requirement-change-analysis-G08.md` (change rationale), `outputs/05-db-definition-G08.sql` + `outputs/06-sample-data-G08.sql` (Phase 1 baseline to preserve), and `outputs/04-design-validation-G08.md` as needed.
3. **Generate:** create `outputs/10-schema-migration-G08.sql` covering **every** Phase 2 extension from Output 09 (asset tracking, maintenance impact levels, ack junction, escalation history, auto-approval policies, booking alerts, reserved-vs-actual, required-asset block) as additive DDL + data backfill + constraints + triggers + view + indexes.
4. **Preserve Phase 1:** no Phase 1 table/column/data is dropped or renamed; the script must be runnable on a Phase 1 database and transform it in place.
5. **Target DBMS:** Microsoft SQL Server only.
6. **Log progress** with `PRINT` statements at each phase (e.g., `PRINT N'Adding impact_level to maintenance_records...'`).
7. **Include the filtered index** `IX_bookings_space_status_time` (`bookings (space_id, requested_start_time, requested_end_time) WHERE status IN (N'Approved',N'CheckedIn')`) — load-bearing for the concurrency conflict check — plus the other Output 09 §10 indexes.
8. **Transactional safety:** wrap the whole migration in `BEGIN TRANSACTION` / `TRY` / `CATCH` / `COMMIT` with `SET XACT_ABORT ON` and `XACT_STATE()`-guarded rollback; create triggers/views via `EXEC(N'...')` (a single `TRY/CATCH` cannot span `GO` batches).
9. **Safety constraint:** do not modify any other deliverable.
10. **Audit policy:** after generation, follow the repository audit policy (AGENTS.md §8) and create a new audit in `docs/audits/` from `AUDIT_TEMPLATE.md`. (If the operator explicitly defers the audit, do not create one.)

## Output format (annotated header + phased, PRINT-logged sections)

```sql
-- =============================================================================
-- Campus Space Management System — Phase 2 Schema Migration (Task 10)
-- Group G08 — Microsoft SQL Server
-- Deliverable: outputs/10-schema-migration-G08.sql
-- Purpose: additive migration of the Phase 1 database (outputs 05–06) into the
--          Phase 2 schema (Output 09). Preserves all Phase 1 data.
-- Run: on the SQL Server database that already ran outputs/05 + 06.
-- =============================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
PRINT N'Start: Phase 2 migration...';
BEGIN TRY
    BEGIN TRANSACTION;
    -- Phase A: new standalone tables (PRINT each)
    -- Phase B: facility_assets + backfill from space_facilities.quantity
    -- Phase C: alter maintenance_records + booking_decisions (backfill + drop default)
    -- Phase D: dependent new tables (history, acks, alerts)
    -- Phase E: constraints & triggers (created via EXEC(N'...'))
    -- Phase F: derived view v_space_facility_summary
    -- Phase G: Phase 2 indexes incl. IX_bookings_space_status_time
    -- Verification: asset-row parity, backfill audits
    COMMIT TRANSACTION;
    PRINT N'Done: migration committed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT N'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
```

## Verification

The output must run on a **SQL Server-compatible environment** only (local SQL Server, a SQL Server container, or Azure SQL). Generic check:

```text
sqlcmd -S <server> -d <database> -i outputs/10-schema-migration-G08.sql
```

Record results in the audit; if SQL Server is unavailable, note the review was **static only**. The backfill must satisfy `COUNT(facility_assets) = SUM(space_facilities.quantity)` and no Phase 1 row may be altered or removed.