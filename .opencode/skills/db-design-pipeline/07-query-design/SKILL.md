---
name: 07-query-design
description: Query-quality rubric and reusable query-pattern notes for Step 7. Workflow, arguments, output format, and requirements live in the /07-generate-query-design command.
compatibility: opencode
---

# Step 7: Query Design Skill

This skill is the **query-writing rubric** for Step 7 — the SQL quality bar and reusable **query-pattern notes**. The **workflow, arguments, output format, and requirements** live in the `/07-generate-query-design` command; this skill does **not** repeat them. No fixed member→role/category assignments and no final SQL answers here.

## Schema authority
- `outputs/05-db-definition-G08.sql` is the **schema authority** — reference only its tables/columns and match its enum spellings exactly (`'Approved'`, `'UnderMaintenance'`, `'NoShow'`, …).
- `outputs/06-sample-data-G08.sql` is the **sample-data reference** — design queries that return meaningful rows against it. A deliberate absence/violation check that may legitimately return zero rows should say so in a short comment.

## Query category notes
Compact, reusable guardrails by category (not final SQL). Apply only those relevant to the member's chosen query types.

- **Availability / scheduling:** use interval-overlap logic for conflict checks — a requested slot overlaps an existing booking when `@slot_start < existing_end AND @slot_end > existing_start`. Avoid `BETWEEN`-only checks.
- **Operational / current-state:** use `GETDATE()` for "right now" queries, not hard-coded timestamps.
- **Maintenance monitoring:** distinguish current/open maintenance from historical completed maintenance using the status values defined in Output 05.
- **Utilization / duration:** compute completed-usage duration from completed sessions/bookings with actual start and actual end times; do not count in-progress sessions as completed utilization.
- **Audit / decision trail:** explain approvals/rejections from booking-decision records; do not infer decision history from booking status alone.
- **No-show / lifecycle:** treat `NoShow` as a post-approval result with no completed usage session, unless schema/data says otherwise.
- **Facility matching:** join through the actual Output 05 tables (e.g. the space–facility junction); do not invent facility columns on `spaces`.
- **Absence / anti-join:** prefer `NOT EXISTS` over `NOT IN` when nullable columns may be involved.
- **Ranking / top-N:** use `SELECT TOP (n) … ORDER BY …`; add `WITH TIES` when tied rows should be kept.
- **Aggregation / grouping:** every non-aggregated `SELECT` column must appear in `GROUP BY`; choose `COUNT(col)` vs `COUNT(*)` deliberately when NULLs matter. For average durations, multiply by `1.0` before `AVG` (e.g. `AVG(DATEDIFF(MINUTE, …) * 1.0)`) so integer `AVG` does not truncate.
- **Date ranges:** prefer half-open ranges (`>= @start AND < @end`) to avoid boundary double-counting.
- **Parameterized filters:** `DECLARE` reusable dates/statuses/thresholds/user-or-space codes; for a set of values use a `VALUES`/CTE list or a local `DECLARE @t TABLE` (read-only). Never use unexplained magic identity-id literals (use a natural key, a lookup, or a `DECLARE`).
- **SQL Server CTE safety:** start a CTE with `;WITH` when it follows another statement or a `DECLARE` block.

## Self-check (before finishing a member section)
The section must satisfy the command's **§ Output format** and **§ Requirements** (single source for structure and rules). Beyond those, verify the rubric-specific points:
- [ ] The relevant **Query category notes** above were applied.
- [ ] Each query maps to one declared, distinct query type; its **Target user(s)** match the **resolved mapping** (the command resolves query type → target user via its §Role-based query type mapping).
- [ ] Variety across the 5: ≥1 JOIN, ≥1 aggregation, ≥1 status/lifecycle, ≥1 date/ordering.
- [ ] Each query returns rows against Output 06 — or a comment explains an intentional zero-row check.
