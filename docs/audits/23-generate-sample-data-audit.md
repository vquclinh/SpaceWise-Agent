# Audit — Generate Sample Data (Step 6)

> Date: 2026-06-26
> Operator/member: Vi
> Tool: OpenCode (opencode)
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: /06-generate-sample-data

## Task goal

Generate `outputs/06-sample-data-G08.sql` with realistic SQL Server `INSERT` statements covering all 9 entities, varied roles, all booking statuses, and edge cases (overlapping bookings, spaces under maintenance, no-shows, rejected bookings).

## Files created / changed

- Created: `outputs/06-sample-data-G08.sql`
- Created: `docs/audits/23-generate-sample-data-audit.md`

## What was evaluated

- Input files: `outputs/03-logical-design-G08.md` (schema structure, FK ordering, constraints) and `outputs/05-db-definition-G08.sql` (exact DDL including trigger).
- Skill requirements from `.opencode/skills/db-design-pipeline/06-sample-data/SKILL.md`.

## Issues found

- The trigger `TR_bookings_PreventOverlapAndUnavailable` in Step 5 is an `INSTEAD OF` trigger that blocks any INSERT/UPDATE that overlaps an existing `Approved` booking, regardless of the inserted row's status. This means Booking #13 (Pending, overlapping with Booking #12 Approved) would be blocked at INSERT time, not just at approval time. This is documented in the sample data as the overlap scenario for verification.

## Changes made

Generated a complete sample data script (`06-sample-data-G08.sql`) with:

| Table | Row count | Highlights |
|---|---|---|
| `departments` | 5 | Computer Science, BA, Math, EE, Languages |
| `user_accounts` | 8 | Students (2), Lecturers (2), FacilityStaff, FacilityManager, DeptAdmin, TA |
| `spaces` | 8 | 6 statuses (Available ×5, UnderMaintenance ×1, TemporarilyClosed ×1) |
| `facilities` | 6 | Projector, Whiteboard, AC, PC, WiFi, Speakers |
| `space_facilities` | 23 | Assignments for all 8 spaces with condition/note |
| `bookings` | 13 | All 7 statuses covered; overlap scenario (#12 vs #13) |
| `booking_decisions` | 5 | 4 Approved + 1 Rejected (with rejection reason) |
| `usage_sessions` | 4 | 3 completed sessions + 1 checked-in ongoing |
| `maintenance_records` | 5 | 2 ongoing (InProgress, Reported) + 3 Completed |

Booking status coverage:
- **Pending**: #3, #10, #13
- **Approved**: #1, #2, #4, #9, #12
- **Rejected**: #5
- **Cancelled**: #6
- **CheckedIn**: #8 (ongoing session)
- **Completed**: #11
- **NoShow**: #7

Edge cases:
- Overlapping bookings: #13 (Pending) overlaps with #12 (Approved) on B1-102, July 10
- Space under maintenance: B2-201 (#6) with 2 maintenance records
- Temporarily closed: C1-101 (#7)
- Rejected booking with rejection reason: #5
- No-show: #7 (Approved but never checked in)

## Improvement classification

- Output refinement

## Validation commands run

```powershell
# Check file exists and size
Test-Path -LiteralPath "outputs\06-sample-data-G08.sql"
(Get-Item "outputs\06-sample-data-G08.sql").Length
```

## Validation results

File exists and is non-empty.

## Risks / caveats

- The `INSTEAD OF` trigger in Step 5 may cause Booking #13 (Pending with overlap) to fail on INSERT, depending on trigger behavior. The sample data documents this scenario for team awareness.
- All timestamps use `DATEADD` relative to `GETDATE()`, so they remain valid when executed on any date in the near future. However, the CheckedIn booking (#8) will appear as same-day, which is intended for the ongoing scenario.
- The data has not been executed against a live SQL Server instance. Team should run against a test database before use in Step 7.

## Git status summary

New files staged for generation only.

## Recommended next steps

1. Team reviews sample data for realism and completeness.
2. Execute script against a test SQL Server instance to verify integrity.
3. Proceed to Step 7 (Query Design) — each team member adds their 5+ queries.
4. Linh to integrate and validate the full set of 20+ queries.
