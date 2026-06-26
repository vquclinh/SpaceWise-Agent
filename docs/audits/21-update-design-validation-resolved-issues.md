# Audit — Update Design Validation for Resolved CHECK Constraint Issues

> Date: 2026-06-26
> Operator/member: Vi (group G08)
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: `/04-generate-design-validation` (follow-up fix)

## Task goal

Update `outputs/04-design-validation-G08.md` Section 7 to mark Issue 2 (rejection_reason conditional CHECK) and Issue 3 (completed_by/actual_end_time paired null CHECK) as resolved, since the corresponding CHECK constraints were added to Output 03.

## Files created / changed

- Modified: `outputs/04-design-validation-G08.md`
  - Section 7 Issue 2: Changed "Resolution" block to "Status: Resolved in Output 03 by adding CHECK ..."
  - Section 7 Issue 3: Changed "Resolution" block to "Status: Resolved in Output 03 by adding CHECK ..."
  - Section Summary: Updated Design Issues row to note "5 ISSUES LOGGED (2 resolved)"
- Created: `docs/audits/21-update-design-validation-resolved-issues.md`

## What was evaluated

- `outputs/04-design-validation-G08.md` Section 7 (Issues 1-5) and Summary table
- Consistency with the previous Output 03 fix (audit 20)

## Issues found

N/A — this is a status update reflecting prior fixes.

## Changes made

1. **Issue 2 (rejection_reason):** Replaced the "Resolution" paragraph (which recommended adding a CHECK) with a "Status: Resolved" line confirming the CHECK constraint already exists in Output 03.
2. **Issue 3 (completed_by):** Same treatment — replaced recommendation with "Status: Resolved" line.
3. **Summary table:** Updated the Design Issues row to read "5 ISSUES LOGGED (2 resolved)" with a note that Issues 2 and 3 are resolved.

## Improvement classification

- Output refinement

## Validation commands run

N/A — setup-stage bash scripts not available on this platform.

## Validation results

Files verified by visual inspection. No other outputs were modified.

## Risks / caveats

- Issue 1 (BookingDecision 1-to-N), Issue 4 (status transitions), and Issue 5 (InUse auto-management) remain unresolved as accepted limitations. These are documented as intentional design choices.

## Git status summary

Modified:
- `outputs/04-design-validation-G08.md`
New:
- `docs/audits/21-update-design-validation-resolved-issues.md`

## Recommended next steps

1. Proceed to Step 5: Generate DDL (`outputs/05-db-definition-G08.sql`).
2. After all 7 outputs exist, run final validation.
