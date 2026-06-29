# Audit — Generate Vĩ's Query Design Section (Step 7)

> **Date:** 2026-06-30
> **Operator/member:** Lê Quốc Vĩ (24125085)
> **Tool:** OpenCode
> **Provider/model/variant:** deepseek-v4-flash-free
> **OpenCode command used:** `/07-generate-query-design`

## Task goal

Generate Vĩ's ≥5 query section for `outputs/07-query-design-G08.sql` using `Mode A` (per-member generation). Query types: `department booking summary`, `approval/rejection audit trail`, `cancelled/no-show bookings`, `personal booking history`, `booking status distribution`.

## Files created / changed

- **`outputs/07-query-design-G08.sql`** — appended Vĩ's section (24125085) after Linh's existing section (24125065). File now has 2 of 4 expected member sections.
- **`docs/audits/43-generate-vi-query-design-audit.md`** — this audit.

## What was evaluated

- **Query type → target-user resolution** (per command §Role-based query type mapping):
  1. `department booking summary` → Department Administrator (exclusive match)
  2. `approval/rejection audit trail` → Department Administrator (exclusive match)
  3. `cancelled/no-show bookings` → Student (exclusive match)
  4. `personal booking history` → Student (exclusive match)
  5. `booking status distribution` → Facility Manager (exclusive match)
- **Section-level Target user perspective** (union): Department Administrator, Student, Facility Manager.
- **Schema compliance** (all identifiers verified against `outputs/05-db-definition-G08.sql`).
- **Query category notes** from the skill applied per query.
- **Variety:** ≥1 JOIN (all 5), ≥1 aggregation (Q1, Q5), ≥1 status/lifecycle (Q2, Q3), ≥1 date/ordering (Q4).
- **Output format:** header, 5 queries each with Query type, Business question, Target user(s), Why useful, SQL, GO.

## Issues found

None. All 5 query types map to exactly one role in the command's mapping. No ambiguity requiring a `Target users` constraint or interactive clarification.

## Changes made

Appended a new `BEGIN/END MEMBER SECTION: 24125085` block to `07-query-design-G08.sql` containing:
- Section header with member info, resolved Target user perspective, and resolved Query type plan.
- **Query 1** — Department Booking Summary (aggregation, JOIN, GROUP BY)
- **Query 2** — Approval/Rejection Audit Trail (status/lifecycle, multi-JOIN, ORDER BY)
- **Query 3** — Cancelled/No-Show Bookings (status filter, DECLARE parameter, ORDER BY)
- **Query 4** — Personal Booking History (date/ordering, DATEDIFF, DECLARE parameter)
- **Query 5** — Booking Status Distribution (windowing aggregation, percentage)
- All queries: read-only (SELECT only), no `SELECT *`, end with `GO`.

## Improvement classification

- Output refinement
- No agent/skill/command change needed

## Validation commands run

Static review only (SQL Server unavailable). Checked:
- All table/column identifiers exist in Output 05.
- Enum spellings match (statuses, roles, space types, etc.).
- `DECLARE` variables are typed correctly.
- `GO` terminators present after each query.
- No `INSERT`/`UPDATE`/`DELETE`/`MERGE`/`DROP`/`ALTER`/`CREATE`/`TRUNCATE` on persistent tables.

## Validation results

All 5 queries are syntactically consistent with the schema and sample data. They return meaningful rows against Output 06 (e.g., Query 1 returns per-department aggregates, Query 5 returns status distribution with percentages).

## Risks / caveats

- `GETDATE()` in sample data means results shift with current date — this is expected and by design for a live database.
- Query 3 and Query 4 use hard-coded `DECLARE @student_id` values (1 and 2) which match sample data; users would substitute their own IDs.

## Git status summary

- Modified: `outputs/07-query-design-G08.sql`
- New: `docs/audits/43-generate-vi-query-design-audit.md`
- Linh's existing section (24125065) preserved unchanged.

## Recommended next steps

1. Other members (Thi, Duyen) generate their ≥5 queries each → full file reaches ≥20 total.
2. Run `Mode: review-all` once all four sections exist for a comprehensive quality check.
3. Execute against a live SQL Server instance to validate runtime.
