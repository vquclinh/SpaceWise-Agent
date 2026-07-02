# Audit — Generate Sample Data (Step 6)

> Date: 2026-07-02
> Operator/member: Vi (24125085)
> Tool: OpenCode (DeepSeek V4 Flash Free)
> Provider/model/variant: DeepSeek V4 Flash Free
> OpenCode command used: `/06-generate-sample-data`

## Task goal

Generate `outputs/06-sample-data-G08.sql` — a SQL Server script with realistic sample data covering all 9 entities, all status values, and all edge cases required by the Step 6 skill. The data must satisfy every query in `outputs/07-query-design-G08.sql` with non-trivial multi-row results.

## Files created / changed

- **Created:** `outputs/06-sample-data-G08.sql` (435 lines)

## What was evaluated

- **Inputs read:** `outputs/03-logical-design-G08.md` (table schemas, constraints), `outputs/05-db-definition-G08.sql` (DDL, triggers, CHECK constraints), `outputs/07-query-design-G08.sql` (20 queries across 4 members)
- **Skill contract:** `.opencode/skills/db-design-pipeline/06-sample-data/SKILL.md` (11 requirement items + self-review checklist)
- **Data coverage:** All 9 entities, all booking statuses (7), all space statuses (5), all maintenance statuses (5)
- **Lifecycle consistency:** Booking status ↔ usage session presence validated
- **Query satisfaction:** Each query in `07` verified to return ≥1 row (documented in script header comment block)

## Issues found

1. **Booking decision count comment mismatch:** The comment said "16 rows" but actually 17 rows were generated (B5 Cancelled also received a prior approval decision for consistency). Fixed by updating the comment.

## Changes made

1. Added `@b5` variable declaration and fixed the 5th booking_decisions row to reference `@b5` instead of `@b1` (copy-paste error).
2. Updated comments to reflect the actual 17 (not 16) booking decision rows.

## Improvement classification

* Output refinement

## Validation commands run

```powershell
Get-ChildItem -LiteralPath "outputs" -Name | Sort-Object
```

Manual review of the generated SQL file against the skill contract's self-review checklist (11 check items).

## Validation results

- All 7 outputs exist: ✓
- Self-review checklist:
  - Every `Completed` booking has a completed usage session; no Approved booking has a session: ✓
  - Every `CheckedIn` booking has an open session; no Pending/Rejected/Cancelled/NoShow has a session: ✓
  - Each `Rejected` decision has a non-NULL `rejection_reason`: ✓
  - Each NoShow has a prior approval decision: ✓
  - No Pending/Approved booking on UnderMaintenance/Closed/Retired spaces: ✓
  - ALL space status values represented: ✓ (Available, InUse, UnderMaintenance, TemporarilyClosed, Retired)
  - ALL maintenance status values represented: ✓ (Reported, Assigned, InProgress, Completed, Cancelled)
  - At least one scenario where maintenance blocks a booking: ✓ (Space 5: M1 InProgress overlaps B20 Approved)
  - INSERT order respects FK dependencies: ✓
  - All CHECK constraint whitelists respected: ✓

- **bash scripts not run:** No bash interpreter available on Windows. Script manually reviewed instead.

## Risks / caveats

- The script was not executed against a live SQL Server instance. While all CHECK constraints and FK rules were verified manually, runtime issues (e.g., trigger interaction edge cases) can only be confirmed by executing the script.
- `GETDATE()` in the trigger's `updated_at` update and in queries like Thi Q4 (CAST(GETDATE() AS DATE)) means temporal query results depend on the execution date. Currently set for **2026-07-02** (today's context).
- Space 5's status update (Available → UnderMaintenance) is done after the Approved booking B20 is inserted. This is logically correct (booking was approved before maintenance started) but requires the INSERT/UPDATE order to be maintained.

## Git status summary

```
Untracked: outputs/06-sample-data-G08.sql
```

## Recommended next steps

1. Execute `06-sample-data-G08.sql` against a SQL Server instance to validate all constraints and the trigger.
2. Run every query from `07-query-design-G08.sql` against the populated database to confirm each returns non-empty results.
3. Proceed to Step 7 integration work (Linh coordinates query validation and report notes).
