# Audit — Task 10 Skill: MS SQL Server Integrity Constraints

> Date: 2026-08-05
> Operator/member: (session)
> Tool: OpenCode (edit + read)
> Provider/model/variant: deepseek-v4-flash-free (opencode/deepseek-v4-flash-free)
> OpenCode command used: none (direct conversation task)

## Task goal

Extend `.opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md`
section 4 (Technical Standards) with three MS SQL Server integrity mandates:

1. **UNIQUE NULL Handling** — forbid standard `UNIQUE` on nullable columns where
   multiple NULLs are business-required; mandate filtered unique indexes
   (`CREATE UNIQUE INDEX ... WHERE ... IS NOT NULL`).
2. **Data Type Fidelity in Views** — derived boolean flags must be explicitly
   `CAST(... AS BIT)` to match the physical schema's `BIT` columns.
3. **Policy Integrity** — auto-approval policy scopes (space-specific and
   active type-wide) must each be deduplicated via filtered unique indexes.

Constraint: keep the Skill a quality rubric, not a hard-coded answer.

## Files created / changed

- Changed: `.opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md`
  (section 4, three new bullets appended after "Data Type Safety")
- Created: `docs/audits/57-skill10-integrity-constraints-audit.md` (this audit)

## What was evaluated

- Existing section 4 content and tone; new bullets follow the established
  "mandate + rationale + mechanism" pattern of the rubric.
- SQL Server semantics verified against MS docs knowledge: standard `UNIQUE`
  treats NULLs as distinct (multiple NULLs allowed), so it cannot enforce
  "at most one non-NULL scope" — a filtered unique index is the correct
  mechanism; `CASE WHEN ... THEN 0 ELSE 1 END` yields `INT`, requiring
  `CAST(... AS BIT)` for schema-consistent `BIT` output.
- Downstream consistency with `outputs/10-schema-migration-G08.sql`:
  the script already uses filtered unique indexes for `booking_alerts`
  (`UQ_booking_alerts_maint` / `UQ_booking_alerts_asset`); `is_required` in
  `v_space_facility_summary` currently returns `INT` (CASE 0/1 without CAST) —
  a compliance gap introduced by mandate 2.

## Issues found

1. `v_space_facility_summary.is_required` in the migration script is derived
   as `CASE WHEN r.facility_id IS NULL THEN 0 ELSE 1 END` — yields `INT`, not
   `BIT`; non-conformant with the new "Data Type Fidelity in Views" mandate.
2. `auto_approval_policies` currently relies on the scope-XOR CHECK
   (`CK_auto_approval_policies_scope`) and a plain `UNIQUE (space_id)` —
   the plain UNIQUE cannot prevent multiple *active* type-wide policies for
   the same `space_type` (NULL `space_id` rows are all distinct); the new
   "Policy Integrity" mandate requires dedicated filtered unique indexes.
3. No other violations found: `booking_alerts` filtered unique indexes and
   the NULL-handling pattern already conform.

## Changes made

SKILL.md only (rubric-level; no DDL changed in this task):

- Added bullet **UNIQUE NULL Handling**: standard `UNIQUE` on nullable
  columns forbidden where multiple NULLs are required; filtered unique
  index (`... WHERE ... IS NOT NULL`) mandated, `UQ_` prefix + `IF NOT
  EXISTS` guard guidance.
- Added bullet **Data Type Fidelity in Views**: `CAST(... AS BIT)` required
  for derived boolean flags; rationale (CASE yields INT, breaks type
  consistency).
- Added bullet **Policy Integrity**: every policy scope (space-specific and
  active type-wide) must be enforced by its own filtered unique index to
  prevent overlapping configurations; predicates documented against
  Output 09 scope semantics before DDL.

## Improvement classification

* SKILL.md improvement

## Validation commands run

- Read-back of edited SKILL.md section 4 (edit applied cleanly)
- No SQL execution needed (rubric-only change)

## Validation results

- Three new mandates present, rubric-style (requirement + rationale +
  mechanism, no full DDL pasted).
- Existing content untouched; ordering and naming conventions preserved.

## Risks / caveats

- The migration script (`outputs/10-schema-migration-G08.sql`) is not yet
  conformant with mandates 2 and 3 (view BIT cast; policy filtered unique
  indexes). If the script is updated, it must be re-validated on the scratch
  database (`G08_MigrationTest` on `localhost\MSSQL2025`) including
  duplicate-policy rejection tests.
- Mandate 3's "active type-wide" predicate (`is_active = 1`) is a design
  decision from Output 09; the exact filter predicate must stay consistent
  with `auto_approval_policies` scope rules when DDL is written.

## Git status summary

- Untracked: `.opencode/skills/db-design-pipeline/10-schema-migration/`
  (includes this session's edits), `outputs/10-schema-migration-G08.sql`
- No commits made (per repo policy, no commit unless asked).

## Recommended next steps

1. Decide whether to align `outputs/10-schema-migration-G08.sql` with the new
   mandates: (a) `CAST(CASE ... END AS BIT)` for `is_required` in the view;
   (b) replace/augment the policy-scope uniqueness with filtered unique
   indexes (space-specific, and active type-wide).
2. If yes: apply edits, re-run the migration on the fresh scratch DB, and
   re-run the functional tests (relocation ghost-alert, escalation, ack gate,
   asset gate) plus new duplicate-policy rejection checks.
3. Consider adding checklist entries for the three new mandates in the
   Quality Checklist section of SKILL.md.
