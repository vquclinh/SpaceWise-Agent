---
description: Generate Task 10 (Phase 2 Schema Migration) — the official additive, data-preserving MSSQL migration script outputs/10-schema-migration-G08.sql using outputs/09 as the technical blueprint.
---

# /10-generate-schema-migration

This command produces the **official Phase 2 deliverable** `outputs/10-schema-migration-G08.sql`. It is an **execution entrypoint** — it does not contain the SQL answer; the migration script must be derived from the required inputs using `outputs/09` as the technical blueprint and the Phase 1 DDL baseline as the starting point.

## Goal

Generate `outputs/10-schema-migration-G08.sql` — the migration that takes a database already running the Phase 1 schema (`outputs/05-db-definition-G08.sql`, with Phase 1 data in place) and extends it to the full Phase 2 schema described by `outputs/09-updated-erd-and-logical-design-G08.md`. The script MUST be **additive and data-preserving**:

- Every Phase 1 table, column, constraint, index, and trigger stays exactly as Phase 1 created it.
- **No `DROP TABLE` or `TRUNCATE TABLE` for any Phase 1 table.** No destructive `ALTER TABLE ... DROP COLUMN`, and no `DROP` of any Phase 1 constraint or index.
- Existing Phase 1 rows are never deleted or rewritten by this script.

## Primary authority

`outputs/09-updated-erd-and-logical-design-G08.md` is the **technical blueprint (binding)**. Use these sections:

- §3 — Detailed Logical Schema Diagram: the full extended schema (columns, types, keys) for the 7 new tables and the 2 modified tables.
- §4 — Updated Logical Data Dictionary: exact per-column data types and constraints (PK/FK/UK/NN/CHECK/DEFAULT) for all 9 affected tables.
- §6 — Candidate key audit: the natural UKs to enforce, including the filtered UNIQUE indexes on `auto_approval_policies`.
- §7 — Index design: the filtered conflict-check index and the supporting indexes to create.
- §8 — Referential integrity: the Phase 2 FK additions (additive only).
- §10 — Business-rule enforcement strategy: which rules are enforced by triggers in Task 10 vs. stored procedures in Tasks 11–13/15.

## Dependencies (read, in order of authority)

1. `outputs/09-updated-erd-and-logical-design-G08.md` — **primary authority / technical blueprint (binding)**.
2. `outputs/08-requirement-change-analysis-G08.md` — supplementary authority for business-rule semantics (impact levels, advisory acknowledgements, concurrency, asset tracking).
3. `outputs/05-db-definition-G08.sql` — **the Phase 1 baseline the migration runs on top of**; read it to (a) confirm existing object names/types so the migration matches them exactly, and (b) ensure nothing Phase 1 is dropped or altered destructively.
4. `AGENTS.md` — §4 (SQL Server rules), §5 (Phase 2 technical rules), §9 (validation policy).
5. `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` and `CS486_Project_Phase02.pdf` — supplementary Phase 2 context.

## Task Logic

Execute the steps in this order:

1. **Load the skills:** Load `.opencode/skills/db-design-pipeline/09-updated-design/SKILL.md` (the Task 09 design contract this migration implements) and `.opencode/skills/db-design-pipeline/05-db-definition/SKILL.md` (DDL conventions: GO batching, trigger placement, the `ROLLBACK + RAISERROR` rejection pattern, closing constraint summary). Supplement with the shared pipeline rules `.opencode/skills/db-design-pipeline/SKILL.md`.
2. **Verify the baseline:** Read `outputs/05-db-definition-G08.sql` and confirm every Phase 1 object it creates must remain untouched. The migration only adds new objects and adds columns/constraints to `maintenance_records` and `booking_decisions` exactly as Output 09 §4 specifies.
3. **Document the migration approach in the script header:** a comment block stating (a) the baseline it targets, (b) the additive/data-preserving guarantees, (c) run instructions (execute against an existing Phase 1 database; take a backup before running; SQL Server-compatible environment only), and (d) the ordered object-creation plan.
4. **Extend the two Phase 1 tables** (guarded, additive `ALTER TABLE`):
   - `maintenance_records`: add `impact_level` and `asset_id` per §4.1 — backfill `impact_level` with `DEFAULT 'OutOfService'` (Phase 1's blanket rule == out-of-service), then **drop the DEFAULT** (per Output 09 §4.1 / Task 09 skill §5.2). Add the `asset_id` FK → `facility_assets(asset_id)`.
   - `booking_decisions`: add `decision_source` (NN, DEFAULT `'Staff'`, CHECK in `('Staff','System')`) and alter `decided_by` to NULL with the same-table pairing CHECK per §4.2.
   - Use object-existence guards (e.g., `COL_LENGTH` / `sys.columns` / `sys.default_constraints` checks) so re-running the migration is safe and never destructive.
5. **Create the 7 new tables in FK-dependency order:** `facility_assets`, `space_facility_requirements`, `auto_approval_policies`, `policy_booking_types`, `maintenance_impact_history`, `booking_advisory_acknowledgments`, `booking_alerts` — every column, type, PK/FK/UK/CHECK/DEFAULT per §4.3–§4.9, with the natural UKs from §6 (including `UNIQUE (booking_id, maintenance_id)` on the acknowledgements and the sparse-list `space_facility_requirements` convention).
6. **Create the indexes** from §7: the filtered conflict-check index `IX_bookings_space_status_time`, the two filtered UNIQUE indexes on `auto_approval_policies` (§4.6: `space_id` when set; active `space_type` when set), and the supporting indexes (§7.2).
7. **Create the derived-fact view `space_facility_summary`** computing `total_units`/`available_units` per `(space_id, facility_id)` from `facility_assets` rows — a view, never a stored count.
8. **Create the Task-10 triggers** per §10's Task column: the impact-history audit trigger, the escalation/downgrade trigger (escalation to `OutOfService` creates `booking_alerts`; **downgrade `OutOfService` → `Advisory` automatically closes the still-unresolved alerts**), the advisory-ack-required trigger, and the required-asset-block trigger. Follow the 05 skill's GO batching (`CREATE TRIGGER` must be the first statement in its batch) and the `ROLLBACK + RAISERROR` rejection pattern.
9. **Close with a summary** (per the 05 skill §6) of every object the migration created — tables, added columns, constraints, indexes, view, triggers — each mapped to its Output 09 section.

## Safety Invariants (non-negotiable)

- **Additive and data-preserving.** No `DROP TABLE`, `TRUNCATE TABLE`, `DROP COLUMN`, or `DROP CONSTRAINT`/`DROP INDEX` on any Phase 1 object. Phase 1 rows are never touched.
- **No Phase 1 renames or retypes.** New columns use new names; existing column definitions are not altered except the single specified nullability change on `booking_decisions.decided_by`.
- **SQL Server syntax exclusively.** Only MSSQL constructs (`IDENTITY`, `DATETIME2`, `NVARCHAR`, `GETDATE()`, filtered indexes, `GO` batching). No PostgreSQL/MySQL/Supabase constructs (`tsrange`, `EXCLUDE USING gist`, deferred triggers, `'infinity'` timestamps, `GIN`, `SET LOCAL`).
- **Enforcement boundary:** this migration contains the schema, the derived view, and the Task-10 triggers only. The concurrency-safe stored procedures (`SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)`, `sp_getapplock`, 1205/1222 retry) belong to Tasks 11–13/15 — do NOT write them here.
- **No other deliverables.** Do not generate, modify, or overwrite outputs 01–09 or 11–16, `AGENTS.md`, or `.opencode/skills/db-design-pipeline/SKILL.md`.

## Self-Review

After writing, verify explicitly:

1. Does the script run against the exact Phase 1 schema from `outputs/05` without dropping or truncating any Phase 1 table and without touching existing data?
2. Are all 9 affected tables present exactly per Output 09 §4 — the 7 new tables and the 2 modified tables (`maintenance_records.impact_level` + `asset_id`; `booking_decisions.decision_source` + nullable `decided_by`)?
3. Is `impact_level` backfilled via DEFAULT and the DEFAULT then dropped, as §4.1 specifies?
4. Are the filtered UNIQUE indexes on `auto_approval_policies` created per §4.6 (`space_id` when set; active `space_type` when set)?
5. Are the indexes from §7 created, including the filtered conflict-check index `IX_bookings_space_status_time`?
6. Is `space_facility_summary` a view (derived counts), not a stored-count table?
7. Are the Task-10 triggers isolated in their own GO batches (first statement in batch), and does the escalation/downgrade trigger handle the downgrade auto-close rule?
8. Is every statement SQL Server syntax, with no destructive or non-MSSQL constructs?
9. Does the script end with a summary of created objects for review?

If the self-review reveals a systemic weakness that a future Task 10 skill should encode (a skill for Task 10 does not exist yet), record it in the audit as a **"Recommended skill improvement"**. Do NOT silently edit a skill file during a normal generation run.

## Validation

- Run the script on a **SQL Server-compatible environment only** (local SQL Server, a SQL Server container, or Azure SQL) against a fresh Phase 1 database built from `outputs/05` plus `outputs/06` sample data — never PostgreSQL, MySQL, or Supabase.
- Confirm the migration succeeds, the Phase 1 tables and their rows survive intact, and the new objects exist (a small verification query block at the end is welcome).
- Note any `scripts/` Phase 2 validation-script extensions needed in the audit.

## Audit Policy

After generation or refinement, you MUST follow the repository audit policy (`AGENTS.md` section 8). Create a new audit log in `docs/audits/` using `docs/audits/AUDIT_TEMPLATE.md`. Record the Phase 2 task (Task 10) and the SQL deliverable evaluated.
