# Audit — Generate Linh's Query Design Section (Mode A)

> Date: 2026-06-26
> Operator/member: Võ Quốc Linh (24125065)
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: /07-generate-query-design

## Task goal

Generate the query design section for member Võ Quốc Linh (24125065) in `outputs/07-query-design-G08.sql` with 5 meaningful SQL Server queries covering: space availability, booking lifecycle, maintenance monitoring, utilization summary, and facility-based search — all read-only, per the command spec and skill rubric.

## Files created / changed

- `outputs/07-query-design-G08.sql` — created (was empty, now contains file-level header + Linh's `BEGIN/END` section)
- `docs/audits/42-generate-linh-query-design-audit.md` — this file

## What was evaluated

- Command arguments matched: Member = Võ Quốc Linh (24125065), Query types = 5 distinct (space availability, booking lifecycle, maintenance monitoring, utilization summary, facility-based search) — no missing/duplicate types; Target users omitted (resolved from §Role-based query type mapping).
- Inputs read: `outputs/05-db-definition-G08.sql` (schema authority with 9 tables, exact enum spellings), `outputs/06-sample-data-G08.sql` (sample data reference), the 07-query-design skill (query category notes/rubric).
- Target user resolution:
  - space availability → Facility Staff + Facility Manager (appears under both roles)
  - booking lifecycle → Facility Staff (only)
  - maintenance monitoring → Facility Staff (only)
  - utilization summary → Facility Manager (only)
  - facility-based search → Facility Staff + Facility Manager (appears under both roles)
  - Union = [Facility Staff, Facility Manager] → `Target user perspective`
- Section keyed by Student ID `24125065`; file was empty so no existing sections to preserve.
- Self-review against §Output format, §Requirements, and skill's Query category notes.

## Issues found

None. The file was empty; no pre-existing sections to conflict with.

## Changes made

Created `outputs/07-query-design-G08.sql` with:
- File-level header (since file was empty/new)
- Linh's `BEGIN/END MEMBER SECTION: 24125065` block containing:
  - Target user perspective declaration
  - Query type plan with resolved target user(s)
  - **Query 1** (space availability): interval-overlap `NOT EXISTS` anti-join for bookable slots; DECLARE parameters; ORDER BY building/room.
  - **Query 2** (booking lifecycle): multi-table JOIN + LEFT JOIN across bookings/users/spaces/decisions/sessions; CASE for staff action labels; custom ORDER BY priority.
  - **Query 3** (maintenance monitoring): DECLARE @t TABLE for open statuses; DATEDIFF for days-open aging; JOIN with spaces + reporters.
  - **Query 4** (utilization summary): aggregation (COUNT, SUM, AVG with *1.0); DATEDIFF(MINUTE) / 60.0; completed sessions only (actual_end_time IS NOT NULL); GROUP BY all non-aggregated columns.
  - **Query 5** (facility-based search): multi-facility join; DECLARE @t TABLE for required facilities; HAVING COUNT = required count; capacity + status filter.

## Improvement classification

- Output refinement
- No agent/skill/command change needed

## Validation commands run

Static review only (SQL Server not available in this environment). Checks applied manually:

```text
# Structural checks (manual):
- ✓ 5 queries, each ending with GO
- ✓ Each query has Query type, Business question, Target user(s), Why useful, SQL
- ✓ No SELECT *
- ✓ Read-only (SELECT / DECLARE / INSERT INTO @t only)
- ✓ All identifiers exist in Output 05 DDL
- ✓ All enum spellings match Output 05 CHECK constraints
- ✓ Variety: JOIN (Q2/Q3/Q4/Q5), aggregation (Q4/Q5), status/lifecycle (Q2/Q3), date/ordering (all)
- ✓ Query type → Target user(s) mapping matches §Role-based query type mapping
- ✓ Skill notes applied: interval-overlap logic, @open_statuses for open maintenance, completed-only utilization, AVG *1.0, facility-junction join, NOT EXISTS anti-join, DECLARE parameters
```

## Validation results

All structural/rubric checks passed on static review. No SQL Server runtime verification was performed.

## Risks / caveats

- SQL Server runtime verification was not performed. Queries were designed against Output 05 DDL and Output 06 sample data but not executed.
- The `DECLARE @open_statuses TABLE` / `INSERT INTO @open_statuses` pattern in Query 3 is read-only and does not modify persistent data.
- `GETDATE()` in Query 3 and Query 4 is evaluated at runtime — results depend on when the script is run.
- DECLARE parameters use hard-coded example values (`@search_start`, `@min_capacity`, required facility names); real usage would adjust these.

## Git status summary

```
?? outputs/07-query-design-G08.sql
?? docs/audits/42-generate-linh-query-design-audit.md
```

Both files are untracked (new). No existing files modified.

## Recommended next steps

1. Verify the queries by running against a SQL Server instance after Outputs 05 and 06.
2. Other members (Duyen, Thi, Vi) generate their own sections using Mode A — e.g.:
   - `/07-generate-query-design Member: <Name> (<ID>); Query types: <5 types>`
3. Run Mode B (`/07-generate-query-design Mode: review-all`) once all four sections exist to validate the complete file.
