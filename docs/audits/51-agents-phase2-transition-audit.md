# Audit — Transition AGENTS.md from Phase 1 to Phase 2 (System Extension)

> Date: 2026-08-03
> Operator/member: Truong Thi My Duyen
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: none (direct prompt)

## Task goal

Update `AGENTS.md` to transition the project from Phase 1 to Phase 2 — System Extension: (1) re-state the current phase as Phase 2 focused on maintenance impact levels, concurrency control, and granular asset tracking; (2) re-order the source-of-truth hierarchy to prioritize Phase 2 documents; (3) make the strict "Microsoft SQL Server only" DBMS rule explicit and forbid PostgreSQL features (`tsrange`, GiST, deferred triggers, etc.); (4) add a Phase 2 technical-rules section (concurrency, reserved vs. actual time, asset-level tracking); (5) extend the deliverable list with Tasks 08–16; (6) add Phase 2 critical business rules — while preserving the file's professional format and the snake_case naming convention.

## Files created / changed

- `AGENTS.md` — updated (current phase, source-of-truth order, strict DBMS rule, new Section 5 Phase 2 technical rules, Task 08–16 deliverables, team-workflow updates, renumbered sections 5–11, Phase 2 critical business rules).
- `.opencode/commands/04-generate-design-validation.md`, `05-generate-db-definition.md`, `06-generate-sample-data.md` — downstream consistency fix: audit-policy cross-reference "AGENTS.md section 7" → "AGENTS.md section 8".
- `docs/audits/51-agents-phase2-transition-audit.md` — this audit.

## What was evaluated

- The Phase 2 task/deliverable list in `CS486_Project_Phase02.pdf` §3.2 (text extracted via `pypdf`; the PDF could not be read directly by the model).
- Phase 2 business logic in `req/business-requirement-P2.md` (incl. `[CONFIRMED]`/`[EXTENSION]`/`[OPEN]` tags) and `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` (SQL Server concurrency strategy, trigger patterns, naming).
- The existing Task 08 skill (`.opencode/skills/db-design-pipeline/08-requirement-change-analysis/SKILL.md`), which confirms outputs go to `outputs/`.
- The current `AGENTS.md` structure, its internal cross-references ("see section 10", "section 7"), and downstream files referencing AGENTS.md section numbers.

## Issues found

1. Section 1 still described Phase 1 / setup stage ("Setup stage now", "generated later by the group") although the seven Phase 1 outputs already exist in `outputs/`.
2. Source-of-truth order had no Phase 2 documents at all.
3. No explicit "SQL Server is the only permitted DBMS / PostgreSQL forbidden" rule; the Phase 2 spec had already been rewritten to SQL Server, so the rulebook lagged.
4. Deliverable list covered Tasks 01–07 only; Tasks 08–16 (exact names confirmed from the PDF §3.2) were missing.
5. Inserting a new technical-rules section required renumbering sections 5–10 and fixing cross-references ("(see section 10)" → 11, "(section 7)" → 8); `.opencode/commands/04/05/06` still pointed at "AGENTS.md section 7" for the audit policy.
6. Team-workflow section contained setup-era wording ("empty placeholders", "outputs/ empty except .gitkeep") that no longer matches reality.

## Changes made

- **Section 1:** current phase is now Phase 2 — System Extension (maintenance impact levels, concurrency control, granular asset tracking); Phase 1 deliverables 01–07 are the preserved migration baseline; out-of-scope note updated ("see section 11").
- **Section 2:** new order — (1) `CS486_Project_Phase02.pdf`, (2) `req/business-requirement-P2.md` + `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md`, (3) Phase 1 `outputs/` as migration baseline, (4) original Phase 1 requirements; Step Precedence Rule extended with Phase 2 examples and the baseline-wins rule.
- **Section 3:** added Naming Convention bullet (snake_case tables/columns, PascalCase enum values, Phase 1 names kept verbatim).
- **Section 4:** added strict DBMS rule — SQL Server only; PostgreSQL forbidden (`tsrange`, `EXCLUDE USING gist`/`btree_gist`, `DEFERRABLE` triggers, `GIN`/array indexes, `'infinity'`, `SET LOCAL`); listed Phase 2 SQL tasks (10, 12, 13, 14, 16).
- **Section 5 (new):** Phase 2 technical rules — Concurrency Control (SERIALIZABLE + UPDLOCK/HOLDLOCK or sp_getapplock; trigger is backstop; retry on 1205/1222), Time Logic Reserved vs. Actual (status-driven conflict interval; immediate release on early check-out; derived, not stored), Asset Tracking (facility_assets with serial numbers; quantity stays catalogue metadata; counts via view; required-facility booking block).
- **Section 6:** renamed "Phase 1 and Phase 2 output rules"; added the exact Task 08–16 file list plus the Phase 2 constraints (≥3 academic years, ≥100,000 bookings, all §1.3 reports in 16, tuning targets in 15, conflict demonstration in 13, data-preserving migration in 10).
- **Section 7:** team workflow updated — Phase 1 commands completed; Tasks 08–16 commands/skills are placeholders to be authored by owners (only Task 08 skill exists); outputs discipline updated (Phase 1 set exists, Phase 2 extends; no regenerating Phase 1 from scratch).
- **Sections 8–11:** renumbered (Audit / Validation / Git / Deployment); audit-policy wording now "which Phase 1 or Phase 2 step or output"; validation policy now Phase-1-final + Phase-2 (SQL deliverables validated on SQL Server-compatible environments only); git rule now "outputs/ limited to Phase 1 01–07 and Phase 2 08–16 + .gitkeep"; deployment policy updated to "Phases 1 and 2".
- **Critical business rules:** kept Phase 1 rules 1–7; added Phase 2 rules 8–13 with `[CONFIRMED]`/`[EXTENSION]` tags matching `req/business-requirement-P2.md` (impact levels, escalation lookup, concurrency invariant, reserved vs. actual, asset-level tracking, auto-approval/`decision_source`).
- **Downstream fixes:** `04/05/06-generate-*.md` audit-policy references updated to "AGENTS.md section 8".

## Improvement classification

- AGENTS.md improvement
- Command improvement (cross-reference fix in commands 04/05/06)
- Documentation improvement

## Validation commands run

- `git status --short` and `git diff --stat` — confirmed only AGENTS.md (+ downstream command refs) changed; 93 lines touched (59 insertions, 34 deletions).
- Grep for stale references: "AGENTS.md section 7" no longer present in `.opencode/commands/`; "see section 10" / "(section 7)" cross-references gone from AGENTS.md.
- Full re-read of AGENTS.md — section numbers 1–11 sequential, cross-references consistent ("see section 11" in §1; "(section 8)" in §7/§11), Task 08–16 names match the PDF §3.2 extraction, all new table/column examples follow snake_case and Phase 1 names are untouched.

## Validation results

- No leftover Phase-1-only setup wording ("setup stage", "intentionally empty" placeholders for 01–07, "outputs/ empty except .gitkeep").
- Deliverable names match `CS486_Project_Phase02.pdf` §3.2 exactly (08-requirement-change-analysis, 09-updated-erd-and-logical-design, 10-schema-migration, 11-concurrency-design, 12-concurrency-implementation, 13-concurrency-tests, 14-data-generator, 15-index-tuning-report, 16-analytical-queries).
- Repo validation scripts were not run: this change touches no `outputs/` deliverables and no SQL; scripts are Phase-1-output oriented and unaffected.

## Risks / caveats

- Section renumbering (5–10 → 6–11) could leave stale "section N" references in any file not grepped (checked README.md, `.opencode/commands/`, `docs/`; only the three command files referenced AGENTS.md section numbers and were fixed). `outputs/01-business-req-analysis-G08.md` references "AGENTS.md §4" which is still correct.
- The Phase 2 task split is intentionally left open ("to be agreed by the team") — no member names invented for Tasks 08–16.
- Task 08 skill exists but its generation command does not; per the updated §7, Output 08 must not be generated until the command/skill pair is complete.

## Git status summary

- Modified: `AGENTS.md`, `.opencode/commands/04/05/06-generate-*.md`.
- Untracked (pre-existing from earlier sessions): `.opencode/skills/db-design-pipeline/08-requirement-change-analysis/`, `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md`, `CS486_Project_Phase02.pdf`, `req/business-requirement-P2.md`, `docs/audits/50-rewrite-p2-spec-sql-server-audit.md`.
- This audit file is new and untracked. No commit requested; nothing committed.

## Recommended next steps

- Team agrees the Phase 2 task split (Tasks 08–16 owners) and authors the per-task commands + skills (starting with Task 08, whose skill already exists) following the audit policy.
- Generate `outputs/08-requirement-change-analysis-G08.md` once the Task 08 command exists, then proceed 09 → 16 in order.
- Validate SQL deliverables (10, 12, 13, 14, 16) on a SQL Server-compatible environment only.
