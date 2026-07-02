## Task 7: Query Design
Overall score: 4.9 / 5

| Criterion | Score | Notes |
|---|---|---|
| 1. Required documentation present | 5 | All 20 queries include all 4 required elements: business question, target user(s), explanation of usefulness, and SQL statement. Format is consistent across all members. |
| 2. Business relevance | 5 | Every query maps to a clear operational need from the requirement: space availability, booking lifecycle, maintenance monitoring, utilization, audit trails, conflict detection, no-show analytics, equipment readiness, etc. No generic "SELECT *" queries. |
| 3. SQL correctness & quality | 4 | All queries use proper T-SQL syntax, appropriate joins (INNER/LEFT as needed), named column aliases, no SELECT *. Minor issue: Duyen Q1's CTE uses `MAX(mr.status)` on a string column — the alphabetically highest status label is semantically misleading (e.g. "Reported" could display even when the actual issue is "InProgress"), though the logic is functionally correct. |
| 4. Result meaningfulness against sample data | 5 | Sample data (06) includes a detailed coverage verification section explicitly mapping each query to expected row counts. Every query is designed to return non-trivial, multi-row results. |
| 5. Diversity of business areas | 5 | Excellent spread across: booking lifecycle/status tracking, conflict/overlap checking, space availability & maintenance status, facility/equipment utilization, user/role-based activity, historical reporting, and operational alerts. No area is unaddressed. |
| 6. Diversity of SQL technique | 5 | Strong mix: simple filters, multi-table joins (3+ tables), aggregation with GROUP BY, window functions (percentage with OVER()), subqueries (NOT EXISTS), CTE (WITH), self-join for overlap detection, date/time range logic, table variables, CASE expressions for status labels. |
| 7. Exceptional-case coverage | 5 | Thoroughly covered: no-show bookings (Vi Q3, Duyen Q4), rejected bookings with reasons (Vi Q2, Thi Q5), spaces under maintenance (Linh Q3, Duyen Q1), overlapping pending conflicts (Duyen Q2), maintenance-impacting approved bookings (Duyen Q3). |
| 8. Per-member balance and attribution | 5 | Each of the 4 members contributes exactly 5 queries. Every section is clearly attributed with student ID, name, target user perspective, and a query-type plan. Excellent for the group report's individual contribution tracking. |

**Strengths:**
- Full 20-query quota met with perfect per-member balance (5 each).
- All 4 required documentation elements present in every query — no gaps.
- Wide SQL technique diversity (CTEs, window functions, self-joins, subqueries, table variables).
- Every business area from the requirement is addressed.
- Exceptional-case handling is thorough (no-show, rejection, overlap, maintenance blocking).
- Schema references are fully consistent with the DDL in task 05.

**Issues found:**
- [minor] Duyen Q1 (Equipment Readiness Check, line 483–491): `MAX(mr.status)` on a string column returns the alphabetically highest status value, not the most semantically meaningful one. For a space with both "Assigned" and "InProgress" issues, the displayed status may not accurately reflect the most relevant issue. Consider using `STRING_AGG` or a priority-based `CASE` instead if precision is needed.

**Inherited issues from earlier tasks (if any):**
- None identified. The sample data (task 06) was explicitly designed to support every query in this file, and the DDL schema (task 05) matches all column/table references.

**Suggested fixes:**
- (Optional) In Duyen Q1, replace `MAX(mr.status)` with a priority-based expression (e.g. `CASE WHEN ... THEN 'Critical' ...`) or use `STRING_AGG` to list all open statuses for more informative output.
