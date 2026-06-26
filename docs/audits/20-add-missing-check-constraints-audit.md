# Audit — Add Missing CHECK Constraints to Logical Design (Output 03)

> Date: 2026-06-26
> Operator/member: Vi (group G08)
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: `/04-generate-design-validation` (follow-up fix)

## Task goal

Add two missing CHECK constraints identified in Output 04 (Design Validation) to Output 03 (Logical Design):
1. `booking_decisions.rejection_reason` must be non-NULL when `decision = 'Rejected'`
2. `usage_sessions.completed_by` and `actual_end_time` must be paired (both NULL or both non-NULL)

## Files created / changed

- Modified: `outputs/03-logical-design-G08.md`
  - Section 3.7 `booking_decisions`: Added `CHECK (decision <> 'Rejected' OR rejection_reason IS NOT NULL)` to `rejection_reason` column
  - Section 3.8 `usage_sessions`: Added `CHECK ((completed_by IS NULL AND actual_end_time IS NULL) OR (completed_by IS NOT NULL AND actual_end_time IS NOT NULL))` to `completed_by` column
  - Section 5 Check Constraints: Added both new constraints to the summary table
- Created: `docs/audits/20-add-missing-check-constraints-audit.md`

## What was evaluated

- `outputs/04-design-validation-G08.md` Section 7, Issues 1 and 2
- `outputs/03-logical-design-G08.md` Sections 3.7, 3.8, and 5 for missing constraints

## Issues found

Two CHECK constraints were missing from Output 03, identified during the design validation phase. Both are now added.

## Changes made

1. **booking_decisions.rejection_reason** — Added `CHECK (decision <> 'Rejected' OR rejection_reason IS NOT NULL)`. This ensures that whenever a decision of 'Rejected' is recorded, the rejection reason must be provided, aligning with business rule 3 from Output 01.

2. **usage_sessions (completed_by / actual_end_time)** — Added `CHECK ((completed_by IS NULL AND actual_end_time IS NULL) OR (completed_by IS NOT NULL AND actual_end_time IS NOT NULL))`. This ensures the completion staff and end time are always set together, preventing inconsistent states.

3. **Constraint Summary (Section 5)** — Both new CHECK constraints added to the Check Constraints table for completeness.

## Improvement classification

- Output refinement

## Validation commands run

N/A — setup-stage bash scripts not available on this platform.

## Validation results

Files verified by visual inspection. All changes are consistent with Output 04 recommendations.

## Risks / caveats

- The paired null CHECK on `usage_sessions` is a table-level constraint referencing two columns. This is valid in SQL Server and will be enforced on any INSERT or UPDATE affecting either column.
- No other outputs (01, 02, 04, 05, 06, 07) were modified as required.

## Git status summary

Modified:
- `outputs/03-logical-design-G08.md`
New:
- `docs/audits/20-add-missing-check-constraints-audit.md`

## Recommended next steps

1. Proceed to Step 5: Generate DDL (`outputs/05-db-definition-G08.sql`), which should now include both new CHECK constraints.
2. If Output 04 is regenerated, its Issues 1 and 2 should be marked as resolved.
