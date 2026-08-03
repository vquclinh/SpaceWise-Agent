# Audit — Output 08 Architectural Refinement, Race Documentation, and Academic Bridging

> Date: 2026-08-03
> Operator/member: Truong Thi My Duyen
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: none (direct prompt)

## Task goal

Refine `outputs/08-requirement-change-analysis-G08.md` in three work packages, without changing any architectural decision, SQL Server logic, trigger pattern, or naming convention:

1. **Alignment pass:** apply the six mandatory reconciliations from the enhanced Task 08 skill (audit 53) to the already-generated Output 08 — Status vs. Impact reconciliation, `changed_by` fallback, sparse-list `is_required`, concrete race interleavings, 3NF scope deferral, granular traceability.
2. **Race documentation:** record the booking-approval vs. maintenance-escalation race as open question #5 in Section 7 (Known Limitation for Tasks 11/12).
3. **Academic/visual bridging:** name the race academically (check-then-act / lost-update), label entities `[Added]`/`[Modified]`, add a Crow's Foot + Home ID / Visitor ID conceptual bridge in Section 3, a mini-3NF worked example in Section 1.5, and a scope-boundary/downstream-impact subsection (1.6).

## Files created / changed

- `outputs/08-requirement-change-analysis-G08.md` — refined (Sections 1.3/1.5/1.6, 2.1/2.2, 3, 4.1–4.6, 5.1–5.5, 6, 7, 8).
- `docs/audits/54-output08-refinement-architectural-audit.md` — this audit.

## What was evaluated

- Output 08 against the six mandates of the Task 08 skill (`.opencode/skills/db-design-pipeline/08-requirement-change-analysis/SKILL.md`) and against AGENTS.md (§3 editing rules, §4 SQL Server-only rule, §5 Phase 2 technical rules, §8 audit policy).
- Consistency of all internal cross-references after the §4 renumbering (4.1 Status vs. Impact, 4.2 impact levels, 4.3 escalation, 4.4 early check-out, 4.5 auto-approval, 4.6 asset block).
- Absence of stale `spaces.current_status`-based blocking wording and of any PostgreSQL constructs.
- Phase 1 baseline preservation (9 tables verbatim; Outputs 01–07 untouched).

## Issues found

1. The original Output 08 (pre-refinement) still used the Phase 1 trigger mental model in places: the §1.3 "Booking-blocking signal" row and traceability rows still implied `current_status`-based maintenance blocking, and §4 lacked the explicit Status vs. Impact reconciliation decision.
2. Section 4 subsection numbering was stale after earlier edits (references to §4.1/§4.2/§4.3 for escalation/early-return/auto-approval did not match the renumbered headings).
3. The race analysis did not name the failure mode in academic terms (no check-then-act / lost-update framing), and Section 2/3 lacked the Phase 1 design-language bridge (entity status labels, Crow's Foot + Home ID / Visitor ID).
4. Section 7 had no record of the booking-approval vs. maintenance-escalation race, which is a genuine serialization gap between the approval procedures and the escalation trigger.

## Changes made

- **Section 1:** trigger backstop note demoted (validation backstop only; `current_status` maintenance check superseded by impact-level check); §1.3 blocking-signal row rewritten to the direct `maintenance_records` query with `current_status` display-only; §1.5 reworked into the 3NF-deferral statement with a worked **mini-validation** of `booking_advisory_acknowledgments` (1NF atomic, 2NF full dependency on composite `(booking_id, maintenance_id)`, 3NF no transitive dependency — advisory text stays in the parent); new **§1.6 Scope boundary and downstream impact** — explicit "Output 08 records requirements and architectural decisions only; it does not modify or overwrite any existing Phase 1 deliverables", plus a table mapping Outputs 04–07 to Tasks 09/10/14/16.
- **Section 2:** scope-summary line; all 7 new tables labeled **[Added]**, both extended Phase 1 tables labeled **[Modified]** (in table rows and headings); `space_facility_requirements` documented as a sparse list with `is_required BIT NOT NULL DEFAULT 1`; new "Audit Trail Robustness" paragraph with the `changed_by` fallback chain (`COALESCE(SESSION_CONTEXT, assigned_staff_id, reporter_id)` on UPDATE, `reporter_id` on INSERT — never NULL/fabricated).
- **Section 3:** new "Conceptual notation (Crow's Foot)" column (`1 ── 0..N`, `M ── N` resolved legs, `0..1 ── 1`) plus a Home ID / Visitor ID mapping paragraph bridging the Phase 1 ERD language to the Phase 2 physical schema; lead-in restating the lifecycle/optionality rule.
- **Section 4:** new §4.1 "Status vs. Impact reconciliation (critical decision)" with conflict explanation and the impact-level check SQL (`SELECT 1 FROM maintenance_records m WHERE ... impact_level = 'OutOfService' AND overlap`); §4.2/§4.3 updated accordingly; escalation §4.3 documents the `changed_by` fallback chain inline; all later subsection references renumbered consistently.
- **Section 5:** §5.1 opens with the academic framing — the failure is a **check-then-act / lost-update race** (TOCTOU), and only serialization repairs it; §5.2/§5.3 rewritten as step-by-step interleavings under `READ COMMITTED` ("Double approval" and "Manual vs. auto" incl. instant-vs-instant) with the mandatory `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK` (or `sp_getapplock`) mitigation; §5.5 states the mechanism as a mandatory requirement covering both paths and the impact-level check.
- **Section 6 (traceability matrix):** rows 2, 5, 10, 14, 17 updated to reference the impact-level check, fallback chain, sparse-list convention, and section numbers; new row 21 recording the Status vs. Impact reconciliation decision; row 20 unchanged.
- **Section 7:** new open question **#5 — Booking Approval vs. Maintenance Escalation Race** (Staff A approving vs. Staff B escalating Advisory → OutOfService on the same space/window; booking may pass the OutOfService check pre-commit, or `TR_maintenance_escalation` may miss the new booking from `booking_alerts`; mitigation = share the Section 5 primitives across approval procedures and the escalation workflow; status = Known Limitation for Tasks 11/12).
- **Section 8 (Quality Checklist):** extended 11 → 16 items covering the new content (mini-3NF, academic framing, entity labels, conceptual bridge, scope boundary).
- No SQL, trigger pattern, or naming convention changed; no Phase 1 output touched.

## Improvement classification

- Output refinement
- Documentation improvement (academic framing and conceptual bridge add reviewer-facing clarity)

## Validation commands run

- `git status --short` — confirmed only expected files; Output 08 remained untracked (never committed; unchanged from earlier sessions except this refinement).
- Grep for all `Section 4.x` / `§4.x` references (30 matches) — verified every reference matches the renumbered §4.1–4.6.
- Select-String for status-based blocking remnants (`current_status` × blocking) — remaining occurrences are only the deliberate "display-only" / "superseded" statements.
- Read-back of edited regions (Sections 1.3/1.5/1.6, 2, 3, 5.1, 6, 7, 8) plus full-file read.

## Validation results

- All six skill mandates present in Output 08; internal section references consistent; no stale blocking wording; no PostgreSQL constructs introduced.
- Section 7 numbering is sequential (1–5); item 5 recorded as Known Limitation with mitigation direction referencing Section 5.
- Scope discipline verified: `outputs/01`–`07` unmodified.

## Risks / caveats

- The escalation-vs-approval race (Section 7, item 5) is intentionally unresolved here: it requires sharing the concurrency primitives across the escalation workflow, which is implementation territory for Tasks 11/12. Output 08 records it as a Known Limitation so it cannot be lost.
- The mini-3NF argument for `booking_advisory_acknowledgments` uses the natural composite key `(booking_id, maintenance_id)` for the dependency analysis (the surrogate `ack_id` PK is an FK-ergonomics convenience); the formal relation-by-relation 3NF audit remains Task 09's scope.
- The `0..1 ── 1` Crow's Foot reading for `maintenance_records` → `facility_assets` mirrors the document's existing cardinality column (each record targets at most one asset); an asset accumulating multiple maintenance records over its lifetime is not expressed in this cardinality and should be re-examined in Task 09.
- No audit was created during the three refinement prompts themselves (per explicit constraints); this single audit now records the whole session's changes.

## Git status summary

- Modified: `outputs/08-requirement-change-analysis-G08.md` (untracked — never committed).
- New: `docs/audits/54-output08-refinement-architectural-audit.md` (this audit).
- Pre-existing changes from earlier sessions remain as-is: `AGENTS.md`, `.opencode/commands/04|05|06-*.md` (modified); `.opencode/skills/db-design-pipeline/08-requirement-change-analysis/`, `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md`, `CS486_Project_Phase02.pdf`, `req/business-requirement-P2.md`, audits 50–53 (untracked).
- No commit requested; nothing committed.

## Recommended next steps

- Task 09 (updated ERD + logical design): perform the formal 3NF audit of the extended schema, validate the Home ID / Visitor ID mapping of Section 3, and re-check the `facility_assets` maintenance cardinality.
- Tasks 11/12 (concurrency design + implementation): close the Section 7 item-5 race by sharing `SERIALIZABLE`/`sp_getapplock` primitives between approval procedures and the maintenance escalation workflow, and demonstrate it in Task 13 tests.
- Team review of Output 08 (owner: Lead Architect; reviewers per AGENTS.md §7) before Task 09 starts.
