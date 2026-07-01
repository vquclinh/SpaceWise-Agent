# Rubric: 07-query-design-G<Group#>.sql

Specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions)
— do not repeat those here.

## Source of truth
Grade against `05-db-definition-G<Group#>.sql` (must execute against it) and
`06-sample-data-G<Group#>.sql` (must produce meaningful, non-trivial results against it).
Also grade against the project brief's requirement: each query must include a business
question, target user(s), short explanation of usefulness, and the SQL statement itself —
this is a per-query documentation requirement, not optional.

## Group-size quota
This group has 4 members. The brief requires each student to design and execute at least
5 meaningful queries, so the group total must be **at least 20 queries**. Treat fewer than
20 as an automatic completeness deduction regardless of individual query quality — this is
checked first, before any per-query grading.

- Verify (if attribution is given, e.g. a comment or section per member) that the 20+
  queries are reasonably distributed across the 4 members, not e.g. 17 queries from one
  student and 1 each from the other three. If no per-member attribution exists in the file,
  note this as a documentation gap to flag in the report (the group report needs to show
  individual contribution per the submission requirements).
- Queries beyond 20 are welcome and should be graded the same as any other — no cap.

## How to grade (mechanical step first)
If you have execution access, run `05-db-definition` + `06-sample-data` then execute every
query in this file against that database. Note:
- Any query that fails to execute (syntax error, wrong column/table name, type mismatch)
  — blocker, regardless of how good the underlying idea is.
- Any query that executes but returns zero rows or an obviously wrong result given the
  sample data (e.g. an "overlapping bookings" query that returns nothing when you know
  sample data contains no overlaps to find, which is fine — but flag if it returns nothing
  due to a logic bug instead, e.g. wrong join condition).
If you cannot execute, manually trace each query's joins/filters against the schema and
sample data structure.

## Per-query criteria (apply to each of the 20+ queries)

### 1. Required documentation present (weight: high)
Each query must include all four required elements from the brief:
- Business question (a real question a stakeholder would ask, not "show all bookings").
- Target user(s) (e.g. Facility Manager, Department Administrator, student) — specific
  role(s) from the system's actor list, not generically "admin" or "user."
- Short explanation of why the query is useful (ties the question to a real operational
  need described in the requirement: fairness, avoiding conflicts, preserving history,
  utilization tracking, etc.).
- The SQL statement.
Missing any one of the four elements on a given query is a deduction for that query.

### 2. Business relevance (weight: high)
The question should map to something explicitly or implicitly named in the requirement:
booking history, upcoming bookings, spaces under maintenance, no-show bookings,
facility utilization, conflict avoidance, approval/rejection patterns, equipment availability,
busiest spaces/times, staff workload (maintenance assignment, approvals handled), etc.
Generic "SELECT * FROM table" style queries with no real business framing should be
flagged as low-value even if technically valid.

### 3. SQL correctness & quality (weight: high)
- Executes without error against the actual schema.
- Uses appropriate joins (not implicit cross joins via comma syntax with missing WHERE
  conditions), correct aggregation/GROUP BY, correct filtering.
- Avoids unnecessary `SELECT *` in favor of named columns where the result is meant to
  be read by a specific user role (a report-style query should return readable, labeled
  columns).
- Uses appropriate SQL constructs for the complexity of the question — flag if every query
  in the set is a trivial single-table SELECT with no joins/aggregates/subqueries at all
  across all 20+, since that suggests insufficient depth across the group as a whole (see
  "Coverage" below).

### 4. Result meaningfulness against sample data (weight: medium)
Query should return a non-trivial, interpretable result set when run against task 6's data
— not empty, not the entire table unfiltered. If task 6's data doesn't support a query well
(e.g. a "busiest month" query but all sample bookings are in one month), that's worth
noting as an inherited gap from task 6 rather than purely penalizing task 7.

## Group-level (aggregate) criteria — apply once across all 20+ queries

### 5. Diversity of business areas covered (weight: high)
Across all 20+ queries, check for reasonable spread across the different operational areas
named in the requirement, not 20 variations on the same theme. Expect to see queries
touching most of:
- Booking lifecycle / status tracking (pending, approved, rejected, cancelled, no-show)
- Conflict / overlap checking
- Space availability and maintenance status
- Facility/equipment inventory and utilization
- User/role-based activity (e.g. bookings per department, approvals per staff member)
- Historical reporting (usage history, trends over time)
- Operational alerts (e.g. spaces needing maintenance, upcoming bookings needing
  check-in)
Flag if entire areas are completely unaddressed across all 20+ queries (e.g. no query ever
touches Maintenance Record, or no query ever touches Facility).

### 6. Diversity of SQL technique (weight: medium)
Across the set, expect to see a mix of: simple filters, joins across 2+ tables, aggregation
(COUNT/SUM/AVG with GROUP BY), subqueries or CTEs, date/time range logic, and at least
one query addressing the no-overlap or unavailable-space business rule directly (e.g.
"find any bookings that violate the no-overlap rule" as a data-quality check query, or
"list currently unavailable spaces"). A set where every query is structurally identical
(same single-table-filter pattern repeated 20 times with different WHERE clauses) should
be marked down here even if each individual query is documented correctly.

### 7. Coverage of "important exceptional cases" (weight: medium)
At least a few queries should specifically surface exceptional/edge-case data: no-show
bookings, rejected bookings with reasons, spaces currently under maintenance, overdue or
long-running maintenance records, conflicting/attempted-overlap detection. This connects
directly to the brief's requirement that sample data and querying together demonstrate
exceptional-case handling, not just the happy path.

### 8. Per-member balance and attribution (weight: low — documentation, not quality)
As noted under "Group-size quota" — confirm a roughly even split (≈5 each) is visible or
stated, since the report needs to describe individual contribution.

## Scoring guidance for this task
- Group-size quota (20+ queries) is a gate, not a weighted criterion — check first, and cap
  the overall task score at "Adequate (3)" or below if the quota isn't met, regardless of
  individual query quality, since this is an explicit hard requirement from the brief.
- Per-query documentation + business relevance + SQL correctness (criteria 1–3) ~45%
  combined — applied as an average across all queries.
- Result meaningfulness (4) ~10%.
- Diversity of business areas and technique (5 & 6) ~30% combined — this is what
  distinguishes a strong query set from 20 minor variants of the same idea.
- Exceptional-case coverage and attribution (7 & 8) ~15% combined.

## Common failure patterns to watch for
- Group total just barely at 20 with several being near-duplicates (e.g. "bookings in
  January" / "bookings in February" / "bookings in March" counted as 3 distinct queries
  with no other variation) — check for genuine substantive difference, not just parameter
  swaps.
- Missing target user or explanation on several queries, especially if the four students'
  sections were merged without normalizing format.
- No query addressing facility/equipment utilization at all — an area explicitly named in
  the requirement but easy to overlook.
- No query that surfaces or tests the overlap-prevention or maintenance-blocking business
  rules — the two rules most central to the system's stated purpose.
- Queries that only work because they don't actually test the rule they claim to (e.g. a
  "find overlapping bookings" query whose join condition can never match due to a logic
  error, silently returning zero rows that look like "no conflicts" instead of "broken
  query").