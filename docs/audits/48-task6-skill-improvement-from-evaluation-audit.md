# Audit — Improve 06-sample-data SKILL.md From Task 6 Evaluation

> Date: 2026-07-02
> Operator/member: Vi
> Tool: OpenCode AI (manual edit)
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: N/A (manual edit instruction)

## Task goal

Read `docs/evaluations/task-06-evaluation.md` (Task 6 evaluation report), identify the specific issues flagged, and update `.opencode/skills/db-design-pipeline/06-sample-data/SKILL.md` with explicit constraints and checklist items that prevent the AI from repeating those problems. Also add a strict instruction requiring the AI to read `outputs/07-query-design-G08.sql` before generating sample data.

## Files created / changed

- `.opencode/skills/db-design-pipeline/06-sample-data/SKILL.md` (edited — 4 changes)
- `docs/audits/48-task6-skill-improvement-from-evaluation-audit.md` (created)

## What was evaluated

`docs/evaluations/task-06-evaluation.md` — the evaluation report for sample data generated in Task 6. The report scored 4.8/5 with four minor issues:

1. Space statuses `InUse` and `Retired` missing from sample data.
2. Maintenance statuses `Assigned` and `Cancelled` missing.
3. NoShow booking (#7) lacking a corresponding `booking_decisions` record (logically must be approved before becoming NoShow).
4. No explicit demonstration of maintenance blocking a pre-existing approved booking.

## Issues found

The SKILL.md file had several gaps that allowed these issues to occur:

- Section 1 (Data Coverage) used vague language ("`Available`, `InUse`, `UnderMaintenance`, etc.") that did not force ALL space status values to appear.
- Section 2 (Complexity & Edge Cases) did not enumerate all required maintenance statuses.
- No explicit rule required a `booking_decisions` record for NoShow bookings.
- No explicit rule required a maintenance-blocking-booking scenario.
- The checklist (Section 7) lacked corresponding check items for these requirements.
- No prerequisite instructed the AI to read the query design file, risking data that would not satisfy Step 7 queries.

## Changes made

Four targeted edits to `SKILL.md`:

**Edit 1 — Added section 0 "Prerequisite: Query Awareness"** (lines 11–15)
- Mandates reading `outputs/07-query-design-G08.sql` BEFORE writing INSERT statements.
- Requires every query to return ≥1 row (preferably 2+).
- Requires a verification comment block at the top of the script.

**Edit 2 — Tightened section 1 space-status requirement** (line 20)
- Replaced vague "`Available`, `InUse`, `UnderMaintenance`, etc." with explicit enumeration: `Available`, `InUse`, `UnderMaintenance`, `TemporarilyClosed`, `Retired`.
- Added "Every space status value must appear on at least one space row."

**Edit 3 — Strengthened section 2 edge-case requirements** (lines 22–28)
- Bookings: `ALL possible booking statuses` listed explicitly (was vague "etc.").
- Maintenance: `ALL possible maintenance statuses` listed explicitly (was absent).
- NoShow: `MUST have a corresponding booking_decisions row` with `decision = 'Approved'` and timestamp before booking start.
- Maintenance blocks booking: added new requirement for an explicit conflict scenario.

**Edit 4 — Expanded section 7 checklist** (lines 53–63)
- Added check: "Every NoShow booking has a prior Approved booking_decisions record."
- Added check: "ALL space status values (...) are represented in the data."
- Added check: "ALL maintenance status values (...) are represented in the data."
- Added check: "At least one scenario exists where maintenance blocks a booking."
- Added check: "Query file was read; every query returns ≥1 row."

## Improvement classification

- SKILL.md improvement
- Validation/test improvement

## Validation commands run

```powershell
Get-ChildItem -LiteralPath ".opencode\skills\db-design-pipeline\06-sample-data\SKILL.md"
```

## Validation results

File exists and is syntactically valid Markdown. Visual inspection confirms all 4 edits applied correctly — section 0, tightened section 1, expanded section 2, expanded section 7 checklist.

## Risks / caveats

- The maintenance-blocking-booking scenario requires careful logical sequencing (a space was available, a booking was approved, THEN maintenance was scheduled). The AI must handle temporal ordering in the INSERT statements, which can be tricky with identity columns and FK dependencies.
- The query-awareness prerequisite adds a cross-file dependency on `07-query-design-G08.sql`, which must already exist for this to work. The pipeline order normally ensures this (Step 7 is created after Step 6 conceptually, but the prerequisite says to read it). This may need a note that Step 7 is a shared responsibility file — if it doesn't exist yet, the AI should still generate data that would broadly support common query patterns.

## Git status summary

Two files affected (SKILL.md edited, audit created). No staged changes.

## Recommended next steps

- Run a fresh Task 6 generation to verify the updated SKILL prevents the four issues.
- Consider adding similar evaluation-driven feedback loops for other steps (Task 5, Task 7).
