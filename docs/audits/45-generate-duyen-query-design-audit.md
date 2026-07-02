# Audit — Generate Duyên Query Design Section (Member 24125028)

> Date: 2026-07-02
> Operator/member: OpenCode (for Trương Thị Mỹ Duyên)
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: `/07-generate-query-design Member: Trương Thị Mỹ Duyên (24125028); Query types: equipment readiness check, potential conflict detection, maintenance impact analysis, no-show behavior analytics, space utilization efficiency`

## Task goal

Generate the Step 7 query design section for member **Trương Thị Mỹ Duyên (24125028)** with 5 queries matching the 5 declared query types, appended to `outputs/07-query-design-G08.sql` while preserving all existing member sections.

## Files created / changed

- `outputs/07-query-design-G08.sql` — appended member section `24125028` at the end (lines 466–619)
- `docs/audits/45-generate-duyen-query-design-audit.md` — this audit

## What was evaluated

1. **Argument validation:** Member name, Student ID, and 5 distinct query types were provided and valid.
2. **Target user resolution** (command's §Role-based query type mapping + custom inference):
   - *equipment readiness check* → inferred from `space_facilities` + `maintenance_records` logic → Facility Staff, Facility Manager
   - *potential conflict detection* → Pending–Pending overlap → Facility Staff, Facility Manager
   - *maintenance impact analysis* → maintenance monitoring (Facility Staff) + backlog (Facility Manager) → Facility Staff, Facility Manager
   - *no-show behavior analytics* → no-show analysis (Facility Manager) + no-show candidates (Facility Staff) → Facility Staff, Facility Manager
   - *space utilization efficiency* → utilization summary + space usage ranking → Facility Manager
   - Union: **Facility Staff, Facility Manager**
3. **Existing file content:** 3 member sections (24125065 Linh, 24125085 Vi, 24125080 Thi) were preserved exactly.
4. **Schema authority:** All identifiers match `05-db-definition-G08.sql`; enum spellings match CHECK constraints.
5. **Query design requirements:** ≥5 queries per member; 4-part comment format; read-only; no `SELECT *`; `GO` termination; `DECLARE` for parameters.
6. **Variety:** ≥1 JOIN (all), ≥1 aggregation (Q4, Q5), ≥1 status/lifecycle (all), ≥1 date/ordering (all).

## Issues found

- **Sample data gap:** The sample data has no two Pending bookings for the same space with overlapping time ranges, so Q2 (potential conflict detection) may return zero rows. This is expected and documented in the query's "Why useful" comment.

## Changes made

Appended a complete member section for Student ID `24125028` with:

| # | Query type | Target user(s) | Key technique |
|---|-----------|---------------|--------------|
| 1 | equipment readiness check | Facility Staff, Facility Manager | CTE (`;WITH`) + LEFT JOIN on active maintenance + CASE readiness classification |
| 2 | potential conflict detection | Facility Staff, Facility Manager | Self-JOIN with interval-overlap (`<` / `>`) |
| 3 | maintenance impact analysis | Facility Staff, Facility Manager | Cross-table interval overlap with `ISNULL(completion_time, …)` |
| 4 | no-show behavior analytics | Facility Staff, Facility Manager | Aggregation with `SUM(CASE …)` ratio computation |
| 5 | space utilization efficiency | Facility Manager | `AVG(expected_participants * 1.0 / capacity)` with min/max |

## Improvement classification

* Output refinement

## Validation commands run

```powershell
# Static review — no SQL Server available for runtime validation
Get-Content outputs/07-query-design-G08.sql | Select-String "BEGIN MEMBER SECTION" | Measure-Object
```

## Validation results

- **4 member sections found** (24125065, 24125085, 24125080, 24125028)
- **20 queries total** (5 per member)
- Each query has: Query type, Business question, Target user(s), Why useful, SQL, and `GO`
- No `SELECT *` found
- All identifiers match Output 05 schema
- Existing sections unchanged

## Risks / caveats

- SQL Server was unavailable; validation was **static only**. Full runtime validation requires:
  ```text
  sqlcmd -S <server> -d <database> -i outputs/05-db-definition-G08.sql
  sqlcmd -S <server> -d <database> -i outputs/06-sample-data-G08.sql
  sqlcmd -S <server> -d <database> -i outputs/07-query-design-G08.sql
  ```
- Q2 may return zero rows with the current sample data (no Pending–Pending conflicts). This is by design and commented.

## Git status summary

- `outputs/07-query-design-G08.sql` — modified (appended Duyên's section)
- `docs/audits/45-generate-duyen-query-design-audit.md` — new file

## Recommended next steps

1. Run runtime validation on SQL Server to confirm all 20 queries execute without error.
2. Generate the remaining member sections if any are missing (all 4 are now present — complete).
3. Consider adding sample data with Pending–Pending overlaps to demonstrate Q2 returns meaningful rows.
