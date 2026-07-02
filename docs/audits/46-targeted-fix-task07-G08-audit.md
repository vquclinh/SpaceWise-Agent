# Audit — Targeted Fix Task 07 Query Design G08

> Date: 2026-07-03
> Operator/member: OpenCode
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: none

## Task goal

Apply a narrow targeted fix pass to `outputs/07-query-design-G08.sql` for only the six issues specified by the user:

1. Fix `24125085` Query 1 so the department booking summary includes `CheckedIn` and keeps departments with zero bookings.
2. Fix `24125028` Query 5 so the fill-rate wording matches `expected_participants`, not nonexistent actual attendance.
3. Fix `24125065` Query 1 by replacing the fixed `2026-07-10 09:00-11:00` window with a rolling 14-days-from-today 09:00-11:00 window.
4. Fix `24125065` Query 5 wording so it does not overclaim "available spaces" while the SQL still allows `InUse`.
5. Fix `24125028` Query 3 by documenting that zero rows can be a valid result.
6. Fix `24125028` Query 4 by changing "top offenders" wording to "ranked list of users" without changing SQL behavior.

## Files created / changed

- `outputs/07-query-design-G08.sql` — modified with only the six targeted fixes.
- `docs/audits/46-targeted-fix-task07-G08-audit.md` — created and later reformatted to match `docs/audits/AUDIT_TEMPLATE.md`.

No Outputs 01-06 were modified.

## What was evaluated

- Current clean `outputs/07-query-design-G08.sql` after the user's repo reset.
- `outputs/05-db-definition-G08.sql` for table, column, and enum compatibility.
- `outputs/06-sample-data-G08.sql` for sample-data date behavior and status coverage.
- `docs/audits/AUDIT_TEMPLATE.md` and nearby audits for audit-format consistency.
- Requested review audits:
  - `docs/audits/46-review-task07-query-design-G08-audit.md` was requested but was not present after the repo reset.
  - `docs/audits/47-review-outputs01-06-G08-audit.md` was requested if present but was not present after the repo reset.

## Issues found

- `24125085` Query 1 omitted valid status `CheckedIn` and used `INNER JOIN`, so departments with no bookings disappeared.
- `24125028` Query 5 described actual participants / actual fill rate, but the schema has only `bookings.expected_participants`.
- `24125065` Query 1 used a fixed date window inconsistent with `GETDATE()`-relative sample data.
- `24125065` Query 5 used "available spaces" wording even though the status filter only excludes `UnderMaintenance`, `TemporarilyClosed`, and `Retired`.
- `24125028` Query 3 may correctly return zero rows, but the usefulness comment did not say that.
- `24125028` Query 4 said "top offenders" while the SQL returns all users ranked by no-show percentage.

## Changes made

| Requested fix | Status | Location/query | Change made |
|---|---|---|---|
| Fix 1 | Fixed | `24125085` Query 1 | Added `checked_in_count`; changed `departments -> user_accounts -> bookings` joins to `LEFT JOIN`; wrapped participant total with `COALESCE`. |
| Fix 2 | Fixed | `24125028` Query 5 | Reworded title/business question/usefulness to expected fill rate; renamed aliases to `avg_expected_fill_rate_pct`, `min_expected_fill_rate_pct`, and `max_expected_fill_rate_pct`; kept `b.expected_participants`. |
| Fix 3 | Fixed | `24125065` Query 1 | Replaced fixed date declarations with the requested `@target_date` pattern for 09:00-11:00 on the date 14 days from today. |
| Fix 4 | Fixed | `24125065` Query 5 | Reworded title/business question/usefulness to say non-closed/bookable spaces instead of available spaces; left the existing status filter unchanged. |
| Fix 5 | Fixed | `24125028` Query 3 | Added a short note that the query may return zero rows when no approved booking overlaps active maintenance. |
| Fix 6 | Fixed | `24125028` Query 4 | Changed "top offenders" to "ranked list of users"; SQL still returns all users sorted by no-show percentage. |

Explicit non-changes:

- Query count stayed 20.
- Member sections stayed 4.
- Member names/spellings were not changed.
- Hard-coded IDs were not globally replaced.
- Local helper table variables were not converted to CTEs.
- Query types, ownership, and ordering were not changed.
- No broad refactor was done.
- No extra suggestions were applied.

## Improvement classification

* Output refinement
* Documentation improvement
* No agent/skill/command change needed

## Validation commands run

```bash
bash scripts/check_required_files.sh --final G08
bash scripts/validate_sql.sh --final G08
grep -c "Business question:" outputs/07-query-design-G08.sql
grep -c "Target user(s):" outputs/07-query-design-G08.sql
grep -c "Why this query is useful:" outputs/07-query-design-G08.sql
grep -cE '^GO$' outputs/07-query-design-G08.sql
grep -ni "SELECT \\*" outputs/07-query-design-G08.sql || true
grep -niE "\\b(INSERT|UPDATE|DELETE|MERGE|DROP|ALTER|CREATE|TRUNCATE|SELECT[[:space:]]+INTO)\\b" outputs/07-query-design-G08.sql || true
git diff -- outputs/07-query-design-G08.sql
git diff --check
git status --short
command -v sqlcmd
```

## Validation results

- `bash scripts/check_required_files.sh --final G08`: PASS. All 7 required deliverables are present.
- `bash scripts/validate_sql.sh --final G08`: PASS. The script found SQL deliverables, key/constraint evidence, sample inserts, 24 `SELECT` occurrences, and 20 `Business question` annotations.
- Business questions: 20.
- Target user annotations: 20.
- Why-useful annotations: 20.
- `GO` blocks: 20.
- `SELECT *`: no matches.
- Persistent DML/DDL scan: only local table-variable inserts were found:
  - `INSERT INTO @open_statuses`
  - `INSERT INTO @required_facilities`
- The local table-variable inserts are not persistent database changes and were intentionally left unchanged.
- `git diff -- outputs/07-query-design-G08.sql`: showed only the six targeted edits in Output 07.
- `git diff --check`: PASS. No whitespace errors.
- `command -v sqlcmd`: no path returned; live SQL Server execution was not available.

## Risks / caveats

- Live SQL Server execution was not performed because `sqlcmd` is unavailable in this environment.
- Upstream Output 01-06 issues from the previous review request remain separate and were not fixed here.
- Existing hard-coded identity IDs outside the six requested fixes remain intentionally unchanged.
- The requested review audits 46 and 47 were not available after the repository reset, so this pass relied on the user's attached instructions plus the current schema/sample/query files.

## Git status summary

Current expected status:

```text
 M outputs/07-query-design-G08.sql
?? docs/audits/46-targeted-fix-task07-G08-audit.md
```

Only Output 07 and this audit file were changed.

## Recommended next steps

1. Run live SQL Server validation when `sqlcmd`, SSMS, Azure Data Studio, or another SQL Server-compatible environment is available.
2. Keep upstream Output 01-06 fixes separate from this narrow Task 07 pass.
3. Before final submission, do one final read-only review of all 20 Task 07 queries for presentation consistency.
