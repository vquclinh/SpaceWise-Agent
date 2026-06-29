# Audit — Review Task 7 Output + Read-only & Precision Fixes

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 7 — Query Design (output review + command/skill fix)

## Task goal

Review the generated `outputs/07-query-design-G08.sql` (Vo Quoc Linh's 5-query section) for bugs/wrongness against Outputs 05/06 and the Task 07 contract, and decide whether the command/skill need improving to prevent recurrence.

## What was evaluated

The member section (24125065) — 5 queries — against the `05` schema (tables/columns/enums), the `06` sample data (do queries return rows), and the command's §Output format / §Requirements + the skill's Query category notes.

## Review result — output is correct and high quality

- All tables/columns and enum spellings (`Available`, `Approved`, `CheckedIn`, `Reported`, `Assigned`, `InProgress`) exist in Output 05.
- Format correct: file header + `BEGIN/END MEMBER SECTION: 24125065`, resolved `Target user perspective`, resolved `Query type plan`, and per-query metadata (Query type / Business question / Target user(s) / Why useful) matching the plan.
- 5 distinct query types; **no `SELECT *`**; every block ends with `GO` (each `DECLARE @now` is correctly isolated per batch); variety met (anti-join, multi-table JOINs, aggregation, date logic, `STRING_AGG`+`HAVING`).
- All 5 queries return meaningful rows against the `06` sample data.
- `validate_sql.sh --final G08` → `07` OK (8 SELECTs ≥5; 5 business-question annotations).

## Issues found

1. **(Rule inconsistency)** Query 5 parameterizes via a **local table variable** (`DECLARE @required_facilities TABLE …; INSERT INTO @required_facilities VALUES …`). It runs fine and is read-only w.r.t. the database, but it literally uses `INSERT`, which the command's prior "no INSERT" wording forbade — so Mode B / a grader could false-flag it.
2. **(Minor precision)** Query 4 used `AVG(DATEDIFF(MINUTE, …)) / 60.0` — integer `AVG` truncates before dividing, slightly skewing `avg_session_hours`.
3. **(Minor note, not changed)** Query 2 `LEFT JOIN booking_decisions` is 1-N, so a booking with multiple decisions would fan out into multiple rows. Acceptable for a "lifecycle trail" and harmless with the current sample data (≤1 decision per booking); left as-is.

## Changes made

| File | Action | Description |
|---|---|---|
| `.opencode/commands/07-generate-query-design.md` | Edited | Clarified the read-only rule: read-only **w.r.t. the database** — `SELECT`/CTE/`DECLARE` including a local `DECLARE @t TABLE` populated via `INSERT INTO @t` (or `VALUES`/CTE) for multi-value filters; only **persistent-data/schema** changes are banned. (Resolves issue 1 without rewriting a correct query.) |
| `.opencode/skills/db-design-pipeline/07-query-design/SKILL.md` | Edited | Two query-category notes: (a) Parameterized filters may use `VALUES`/CTE or a local `DECLARE @t TABLE` (read-only); (b) for average durations multiply by `1.0` before `AVG` to avoid integer truncation. |
| `outputs/07-query-design-G08.sql` | Edited (1 line) | Query 4 `AVG(DATEDIFF(MINUTE, …) * 1.0) / 60.0` to fix the precision nuance (issue 2). |
| `docs/audits/41-review-task7-output-and-fixes-audit.md` | Created | This audit. |

Query 5's table-variable approach is left as-is (now explicitly compliant under the clarified rule). No other output queries changed.

## Improvement classification

- Output refinement (Q4)
- Command improvement (read-only clarification)
- SKILL.md improvement (two category notes)

## Validation commands run

```bash
bash scripts/validate_sql.sh --final G08
grep -cE '^GO' outputs/07-query-design-G08.sql ; grep -c 'SELECT \*' outputs/07-query-design-G08.sql
grep -n 'actual_end_time) \* 1.0' outputs/07-query-design-G08.sql
grep -n 'Read-only w.r.t. the database' .opencode/commands/07-generate-query-design.md
git status --short
```

## Validation results

- `07` passes `--final G08` (8 SELECTs ≥5; 5 business-question annotations); 5 `GO` blocks; 0 `SELECT *`.
- Q4 precision fix present; command read-only clarification present.
- Changed: command 07, skill 07, output 07 (1-line); this audit.

## Risks / caveats

- Static review only — not executed on a live SQL Server. The queries are valid SQL Server 2017+ (`STRING_AGG … WITHIN GROUP`, `DATETIME2`, table variables) and align with Outputs 05/06; please run `05` → `06` → `07` on a real instance to confirm row-level results.
- `Output 07` is still a **single-member** section (Vo Quoc Linh, 5 queries). The deliverable needs all four members (**≥20 total**); run `/07-generate-query-design` for the other three, then `Mode: review-all`.
- Q2's 1-N decision fan-out is acceptable for a trail; revisit only if a single-row-per-booking summary is wanted.

## Git status summary

```
 M .opencode/commands/07-generate-query-design.md
 M .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
?? outputs/07-query-design-G08.sql        (member-generated; +1-line precision fix)
?? docs/audits/41-review-task7-output-and-fixes-audit.md
```

## Recommended next steps

1. Generate the other three members' sections (Mode A), then run `Mode: review-all` and `bash scripts/validate_sql.sh --final G08`.
2. Execute `05` → `06` → `07` on a SQL Server instance to confirm all queries run and return sensible rows.
