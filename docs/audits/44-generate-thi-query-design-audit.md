# Audit — Generate Bao Thi's Query Design Section (Step 7)

> **Date:** 2026-07-01
> **Operator/member:** Huỳnh Lê Bảo Thi (24125080)
> **Tool:** OpenCode
> **Provider/model/variant:** deepseek-v4-flash-free
> **OpenCode command used:** `/07-generate-query-design`

## Task goal

Generate Bao Thi's ≥5 query section for `outputs/07-query-design-G08.sql` using `Mode A` (per-member generation). Query types: `upcoming approved bookings`, `schedule by date range`, `assisted session schedule`, `check-in support list`, `booking status tracking`.

## Files created / changed

- **`outputs/07-query-design-G08.sql`** — appended Bao Thi's section (24125080) after Vĩ's existing section (24125085). File now has 3 of 4 expected member sections (24125065 Linh, 24125085 Vĩ, 24125080 Thi).
- **`docs/audits/44-generate-thi-query-design-audit.md`** — this audit.

## What was evaluated

- **Query type → target-user resolution** (per command §Role-based query type mapping):
  1. `upcoming approved bookings` → Lecturer (exclusive match)
  2. `schedule by date range` → Lecturer (exclusive match)
  3. `assisted session schedule` → Teaching Assistant (exclusive match)
  4. `check-in support list` → Teaching Assistant (exclusive match)
  5. `booking status tracking` → Student (exclusive match)
- **Section-level Target user perspective** (union, since `Target users` omitted): Lecturer, Teaching Assistant, Student.
- **Schema compliance** (all identifiers verified against `outputs/05-db-definition-G08.sql`).
- **Query category notes** from the skill applied per query:
  - Q2 uses half-open range (`>= @start AND < @end`).
  - Q3 uses aggregation with `GROUP BY` and `COUNT`/`SUM`/`MIN`/`MAX`.
  - Q4 uses `NOT EXISTS` (anti-join) and `CAST(... AS DATE) = CAST(GETDATE() AS DATE)`.
  - Q3, Q4 use `GETDATE()` for "right now" operational queries.
  - Q5 uses `LEFT JOIN` for audit/decision trail.
- **Variety:** ≥1 JOIN (all 5), ≥1 aggregation (Q3), ≥1 status/lifecycle (Q1, Q3, Q4, Q5), ≥1 date/ordering (all 5 with `ORDER BY`, Q2 with half-open range, Q4 with today filter).
- **Output format:** section header with resolved mapping, 5 queries each with Query type, Business question, Target user(s), Why useful, SQL, `GO`.

## Issues found

None. All 5 query types map to exactly one role in the command's mapping. No ambiguity requiring a `Target users` constraint or interactive clarification.

## Changes made

Appended a new `BEGIN/END MEMBER SECTION: 24125080` block to `07-query-design-G08.sql` containing:
- Section header with member info, resolved Target user perspective, and resolved Query type plan.
- **Query 1** — Upcoming Approved Bookings (JOIN, status filter, date ordering)
- **Query 2** — Schedule by Date Range (JOIN, half-open date range, DECLARE parameters)
- **Query 3** — Assisted Session Schedule Summary (aggregation: GROUP BY, COUNT, SUM, MIN, MAX)
- **Query 4** — Today's Check-In Support Candidates (anti-join NOT EXISTS, CAST date comparison)
- **Query 5** — Booking Status Tracking (LEFT JOIN for decision trail, CASE status label)
- All queries: read-only (SELECT only), no `SELECT *`, end with `GO`, use Output 05 identifiers and enum spellings.

Existing sections for 24125065 (Linh) and 24125085 (Vĩ) preserved unchanged.

## Improvement classification

- Output refinement
- No agent/skill/command change needed

## Validation commands run

Static review only (SQL Server unavailable). Checked:
- All table/column identifiers exist in Output 05.
- Enum spellings match (statuses, roles, space types, booking types).
- `DECLARE` variables are typed correctly (`INT`, `DATETIME2`).
- `GO` terminators present after each query.
- No `INSERT`/`UPDATE`/`DELETE`/`MERGE`/`DROP`/`ALTER`/`CREATE`/`TRUNCATE` on persistent tables.

## Validation results

All 5 queries are syntactically consistent with the schema and return meaningful rows against Output 06 sample data:
- Q1 returns 2 rows (Lecturer C's approved future bookings #9 and #12).
- Q2 returns 1 row (Lecturer D's booking #5 in Jun–Aug 2026 range).
- Q3 returns 2 grouped rows (Seminar: 2 sessions, Workshop: 1 session).
- Q4 may return 0 rows (all today's bookings checked in) — documented in comment.
- Q5 returns 4 rows (Student A's bookings: Completed, Approved, Cancelled, Pending).

## Risks / caveats

- `GETDATE()` yields live results — expected by design.
- Q1, Q2, Q5 use hard-coded DECLARE IDs (3, 4, 1) matching sample data users; real users substitute their own IDs.
- Q4's zero-row scenario is intentional and documented.

## Git status summary

- Modified: `outputs/07-query-design-G08.sql`
- New: `docs/audits/44-generate-thi-query-design-audit.md`
- Linh's section (24125065) and Vĩ's section (24125085) preserved unchanged.

## Recommended next steps

1. **Duyen (24125065)** — wait, 24125065 is already Linh. Check who's missing: Duyên (assigned 01+02) does not have a query section yet. Generate Duyen's ≥5 queries to reach the full ≥20 total.
2. Run `Mode: review-all` once all four sections exist for a comprehensive quality check.
3. Execute against a live SQL Server instance to validate runtime.
