# Audit — Enhance Task 08 Skill with Phase 2 Architectural Reconciliations

> Date: 2026-08-03
> Operator/member: Truong Thi My Duyen
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: none (direct prompt)

## Task goal

Enhance `.opencode/skills/db-design-pipeline/08-requirement-change-analysis/SKILL.md` with mandatory architectural guidance so any subsequent Task 08 execution resolves Phase 1/Phase 2 logic conflicts robustly: Status vs. Impact logic reconciliation, audit-trail fallback for `changed_by`, sparse-list asset requirements, concrete SQL Server race scenarios, 3NF scope deferral to Task 09, and granular traceability mapping. Preserve the skill's overall structure; do not generate the Task 08 output.

## Files created / changed

- `.opencode/skills/db-design-pipeline/08-requirement-change-analysis/SKILL.md` — enhanced (Analysis Requirements sections 1–6 + Quality Checklist).
- `docs/audits/53-skill08-arch-guidance-audit.md` — this audit.

## What was evaluated

- The existing Task 08 skill structure (frontmatter, 6 Analysis Requirements subsections, Quality Checklist) — unchanged headings, enriched content only.
- The mandatory guidance against the Phase 2 sources: `req/business-requirement-P2.md` (tags, open questions), `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` (§2.7 `space_facility_requirements`, §5.1 trigger/`SESSION_CONTEXT`, §6 concurrency, §7 filtered index), and the Phase 1 baseline (outputs 03/04/05: `spaces.current_status` semantics, `TR_bookings_PreventOverlapAndUnavailable`).

## Issues found

1. The skill did not force a decision on the conflict between Phase 1's `UnderMaintenance` status blocking and Phase 2's advisory impact level — the agent could repeat the Phase 1 trigger-only mental model.
2. `maintenance_impact_history.changed_by` relied on `SESSION_CONTEXT` alone; a trigger firing in a session where the application never set it would record NULL/fail.
3. `space_facility_requirements.is_required` was unspecified in the skill; the spec's `DEFAULT 0` + "empty by default" wording is ambiguous for a sparse-list intent.
4. Race scenarios were named ("Double Approval", "Instant vs Manual") but not specified as concrete, enumerable SQL Server interleavings.
5. No statement about where 3NF validation of the new Phase 2 tables happens (must be Task 09, not Task 08).
6. Traceability matrix guidance was entity-level; the Lead Architect requires granular artifact-level mapping.

## Changes made

- **Section 1:** added mandatory "Status vs. Impact Logic Reconciliation" (blocking queries `maintenance_records` for `OutOfService` overlap; `spaces.current_status` maintenance values become display-only; `TemporarilyClosed`/`Retired` remain; Phase 1 trigger demoted to backstop) and mandatory "3NF scope" (deferred to Task 09; only derivability flags in Output 08).
- **Section 2:** added mandatory "Audit Trail Robustness" — `changed_by` fallback chain for INSERT (`COALESCE(SESSION_CONTEXT, reporter_id)`) and UPDATE (`COALESCE(SESSION_CONTEXT, assigned_staff_id, reporter_id)`, never NULL/fabricated), documented for Task 10; added mandatory "Asset Requirement Defaults" — `space_facility_requirements` as sparse list with `is_required BIT NOT NULL DEFAULT 1`, presence = required.
- **Section 4:** explicit `OutOfService` overlap predicate with `COALESCE(completion_time, '9999-12-31')`; mandatory Status vs. Impact implications bullet (advisory display + escalation lookup never read `current_status`); mandatory acknowledgement-enforcement statement order (Pending → ack rows → Approved).
- **Section 5:** mandatory enumeration of concrete race scenarios — (1) double manual approval, (2) instant vs. manual, (3) instant vs. instant, (4) optional early-check-out race — each with interleaving + violated invariant; prevention logic references `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK` key-range locking, filtered index, `sp_getapplock`, 1205/1222 retry.
- **Section 6:** mandatory granular logic mapping (overlap predicate, ack trigger + order, escalation trigger + `booking_alerts`, concurrency procedure + filtered index, `space_facility_summary` view, `is_required` convention, `changed_by` fallback).
- **Quality Checklist:** extended 4 → 10 checkboxes covering all six new mandates.
- Structure preserved: same frontmatter, same 6 subsections, same checklist section; additions are bullets/items inside them.

## Improvement classification

- SKILL.md improvement

## Validation commands run

- Read-back of the full updated SKILL.md.
- Grep of the updated file for the six mandatory items (`Status vs. Impact`, `fallback chain`, `DEFAULT 1`, `Double Manual Approval`, `deferred to Task 09`, `Granular logic mapping`).
- Confirmed `outputs/08-requirement-change-analysis-G08.md` was NOT modified (git status).

## Validation results

- All six mandatory guidance items are present and marked **(mandatory)**.
- Section numbering and overall layout identical to the original (frontmatter + "Analysis Requirements" 1–6 + "Quality Checklist") — structure preserved.
- No output generation: `outputs/08-requirement-change-analysis-G08.md` untouched (still the version produced in the earlier session).

## Risks / caveats

- The `is_required DEFAULT 1` sparse-list convention intentionally diverges from `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` §2.7 (`DEFAULT 0`): the Lead Architect's choice (presence = required) is now the skill contract; Task 09/10 must follow the skill, and the spec divergence should be noted in the Task 08 output for the TA review.
- `changed_by` fallback relies on `COALESCE` over `SESSION_CONTEXT`; SQL Server 2016+ assumed (consistent with AGENTS.md §4).

## Git status summary

- Modified: `.opencode/skills/db-design-pipeline/08-requirement-change-analysis/SKILL.md`.
- This audit file is new and untracked. Pre-existing untracked/modified files from earlier sessions remain unchanged. No commit requested; nothing committed.

## Recommended next steps

- When the team runs Task 08 again, the skill now forces the six reconciliations; the existing Output 08 should be re-run (or patched) to reflect them — e.g., display-only `current_status`, `changed_by` fallback, `is_required DEFAULT 1`, and 3NF deferral note.
- Author the Task 08 command file, then proceed to Task 09 (Logical Design Update, including the 3NF validation of the extended schema).
