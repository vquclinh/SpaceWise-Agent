# Audit — Task 10 Skill: Advanced T-SQL Best Practices

> Date: 2026-08-05
> Operator/member: (session)
> Tool: OpenCode (edit + read)
> Provider/model/variant: deepseek-v4-flash-free (opencode/deepseek-v4-flash-free)
> OpenCode command used: none (direct conversation task)

## Task goal

Extend `.opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md` with four
advanced T-SQL mandates while keeping the document a quality rubric (not a
hard-coded answer):

1. **Modern Syntax** — `CREATE OR ALTER` for Views, Stored Procedures, and Triggers; forbid `DROP ... CREATE`.
2. **Trigger Defense** — `IF TRIGGER_NESTLEVEL() > 1 RETURN;` at the start of every trigger.
3. **Logical Precision (Relocation Alert)** — `RequiredAssetRelocated` must fire only when the moved asset was `N'Available'` (from `deleted`) before the move.
4. **Data Type Safety** — explicit `CONVERT(NVARCHAR(MAX), SESSION_CONTEXT(...))` for `NVARCHAR(MAX)` targets and `TRY_CONVERT(INT, ...)` for integer actors.

## Files created / changed

- Changed: `.opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md`
  (sections "3. Trigger Logic" and "4. Technical Standards")
- Created: `docs/audits/56-skill10-t-sql-best-practices-audit.md` (this audit)

## What was evaluated

- The existing SKILL.md rubric content (43 lines, sections 1–4 + checklist) for
  placement and tone of the new mandates.
- SQL Server capability: `CREATE OR ALTER TRIGGER`/`VIEW`/`PROCEDURE` requires
  SQL Server 2016 SP1+ (matches the script's existing "SQL Server 2016+" header).
- The current `outputs/10-schema-migration-G08.sql` implementation, which still
  uses the now-forbidden `DROP ... CREATE` pattern for the view and triggers —
  a known compliance gap introduced by this rule change.

## Issues found

1. The current migration script (`outputs/10-schema-migration-G08.sql`) uses
   `DROP VIEW` / `DROP TRIGGER` + `CREATE` — now non-conformant with the new
   "Modern Syntax" mandate (permissions reset, non-idempotent pattern).
2. `TR_facility_assets_RelocationAlert` in the script fires on any
   cross-space asset move; it does not yet restrict firing to assets whose
   pre-move status was `N'Available'`.
3. No `TRIGGER_NESTLEVEL()` guard exists in any trigger in the script.
4. `SESSION_CONTEXT` conversion in `TR_maintenance_impact_history` already uses
   `CONVERT(NVARCHAR(MAX), ...)` and `TRY_CONVERT(INT, ...)` — conformant.

## Changes made

SKILL.md updates only (rubric-level, no code changes to the deliverable):

- **Section 3** gained a "Cross-cutting trigger standards" sub-list:
  - Trigger Defense: `IF TRIGGER_NESTLEVEL() > 1 RETURN;` at the top of every
    trigger body, checked against the trigger's own nesting depth, with
    rationale (re-entrant write-back / chained recursion).
  - Logical Precision: `RequiredAssetRelocated` fires only when `deleted.asset_status = N'Available'`; moves of `UnderMaintenance` / `InUse` / `Retired` units must not alert.
- **Section 4** gained:
  - Modern Syntax: `CREATE OR ALTER` for Views/Procedures/Triggers (2016 SP1+),
    preserves permissions, idempotent; `DROP ... CREATE` forbidden.
  - Data Type Safety: `SESSION_CONTEXT` is `SQL_VARIANT`; explicit
    `CONVERT(NVARCHAR(MAX), ...)` for `NVARCHAR(MAX)` (e.g., `change_reason`)
    and `TRY_CONVERT(INT, ...)` for actor keys with documented fallback.

## Improvement classification

* SKILL.md improvement

## Validation commands run

- `git status --short` (untracked: skill folder + migration script)
- Read-back of the edited SKILL.md sections (both edits applied cleanly)
- No SQL execution needed for this change (rubric-only)

## Validation results

- Both edits applied successfully; document remains a rubric (requirements +
  rationale, no full trigger implementations pasted).
- Rubric now conformant with the four requested mandates.
- Note: existing migration script compliance must be handled in a follow-up
  (see Risks / recommended next steps).

## Risks / caveats

- **Deliberate deviation flagged:** the already-validated
  `outputs/10-schema-migration-G08.sql` now violates the new Modern Syntax and
  Relocation-Precision mandates. If the script is regenerated to conform, it
  must be re-validated against the SQL Server scratch database
  (`G08_MigrationTest` on `localhost\MSSQL2025`), including the
  `TRIGGER_NESTLEVEL()` guard (which does not change behavior for legitimate
  single-level fires) and the relocation `deleted`-state filter.
- `CREATE OR ALTER TRIGGER` cannot be used for the script's guard pattern that
  runs `IF OBJECT_ID(...) IS NULL` — the mandate applies to Views/Procedures/
  Triggers only; `CREATE TABLE` guards remain `IF OBJECT_ID ... IS NULL`.
- Script-level idempotency must not rely on `CREATE OR ALTER` alone for objects
  whose *options* (e.g., filtered-index requirements, `SET QUOTED_IDENTIFIER`)
  differ between first and subsequent runs.

## Git status summary

- Untracked: `.opencode/skills/db-design-pipeline/10-schema-migration/`
  (skill folder, incl. this session's edits), `outputs/10-schema-migration-G08.sql`
- No commits made (per repo policy, no commit unless asked).

## Recommended next steps

1. Decide whether to update `outputs/10-schema-migration-G08.sql` to the new
   mandates (switch view/triggers to `CREATE OR ALTER` with existence-aware
   batches, add `TRIGGER_NESTLEVEL()` guards, restrict relocation alerts to
   `deleted.asset_status = N'Available'`).
2. If yes: apply edits, re-run the migration on a fresh scratch DB, and
   re-execute the functional trigger tests (impact history, sync, escalation,
   advisory ack, required-asset check, relocation alert) before finalizing.
3. Update the Quality Checklist in SKILL.md with the new mandate checks if a
   further rubric pass is wanted.
