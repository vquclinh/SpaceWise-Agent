# Rubric: 05-db-definition-G<Group#>.sql

Specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions)
— do not repeat those here.

## Source of truth
Grade against `03-logical-design-G<Group#>.md` as primary source, with
`04-design-validation-G<Group#>.md` as the authority on any fixes/revisions that should
have been applied here. Also check directly against the business rules in task 1/PDF for
the non-structural rules (e.g. no overlapping bookings) that only become real at this
implementation stage. This is the first output that should actually execute — verify it runs,
don't just read it.

## How to grade (mechanical step first)
Before scoring on paper, actually attempt to run the DDL script (if you have execution
access) against a clean database instance:
- Note any syntax errors, dialect issues, or execution-order problems (e.g. a table
  referencing a FK to a table not yet created) as blocker-severity.
- If you cannot execute it, do a careful manual parse and flag this limitation in your
  eval output rather than silently skipping the check.

## Criteria

### 1. Table coverage (weight: high)
Every relation from task 3 (post task-4 fixes, if any) has a corresponding `CREATE TABLE`
statement. No silently dropped or silently added tables versus the logical design.

### 2. Column coverage & types (weight: high)
Every attribute from the logical design appears as a column with an appropriate SQL type:
- IDs: consistent type across the schema (e.g. all INT/SERIAL or all UUID — check FK and
  PK types actually match each other, a common silent bug).
- Timestamps (requested/actual start/end times, decision time, completion time): proper
  date/time type, not stored as text.
- Status/role/type fields: either an ENUM type, a CHECK-constrained VARCHAR, or a
  reference table — any is acceptable, but the chosen allowed values must match the
  domains noted in task 3 exactly (e.g. Booking status must include all of: pending,
  approved, rejected, cancelled, checked in, completed, no-show — check none are
  missing or misspelled).
- Capacity/expected participants: numeric, with a sensible CHECK (e.g. > 0) if the group
  chose to add one.

### 3. Primary keys (weight: high)
Every table has a `PRIMARY KEY` declared correctly (single or composite, matching task 3).

### 4. Foreign keys & referential integrity (weight: high)
- Every FK from task 3 is implemented with `REFERENCES`, correct target table/column,
  and matching data type.
- Multiple distinct FKs to the same table (requester_id, decided_by, checked_in_by,
  completed_by on Booking; reporter_id, assigned_to on Maintenance Record) are each
  present and separately named — verify this carried through from task 3 correctly, since
  it's easy to lose during DDL writing even if task 3 got it right on paper.
- `ON DELETE` / `ON UPDATE` behavior is specified deliberately (e.g. RESTRICT or
  CASCADE) rather than left to database default without comment — flag if absent and
  the choice would matter (e.g. what happens to bookings if a user account is deleted).

### 5. NOT NULL / nullability (weight: medium)
Matches the participation constraints from the ERD/logical design: mandatory fields
(requester_id, space_id, requested start/end time, status) are NOT NULL; fields that only
populate later in the booking lifecycle (decided_by, decision_time, checked_in_by,
actual_start_time, completed_by, actual_end_time) are nullable.

### 6. CHECK constraints for business rules (weight: high)
This is the key payoff of task 5 — verify implementation of rules that are checkable at the
single-row or simple-expression level:
- `end_time > start_time` (and `actual_end_time > actual_start_time` where applicable) on
  Booking.
- Status domains constrained to the exact allowed value lists (via CHECK or ENUM).
- `expected_participants <= capacity` if the group chose to enforce this at the DB level
  (optional, but if claimed in task 4 it must appear here).
- Rejection reason: some form of conditional requirement (CHECK with a CASE, or
  application-level note if not DB-enforceable) that a rejected booking has a reason — if
  not enforceable via plain CHECK without subqueries, the group should have flagged this
  as application-level logic in task 4; verify DDL doesn't silently drop it from consideration.

### 7. No-overlap booking rule (weight: high)
This is the hardest rule and a strong signal of implementation quality. Standard CHECK
constraints cannot express cross-row constraints in most SQL dialects, so verify the group
used one of:
- A unique constraint over an exclusion-capable feature (e.g. PostgreSQL `EXCLUDE USING
  gist` with a time-range type), or
- A trigger that checks for overlapping approved bookings on the same space before
  insert/update, or
- An explicit note (if neither is implemented) that this rule is enforced at the application
  layer instead, with reasoning.
A DDL file with no mechanism and no explanatory note for this rule should be treated as a
blocker-severity gap, since it's the headline business rule from the original requirement
("the same space cannot have two approved bookings with overlapping time periods").

### 8. Unavailable-space booking rule (weight: medium)
Verify some mechanism (trigger, or explicit note of application-level enforcement) exists
preventing bookings against spaces marked under maintenance, closed, or retired — same
reasoning as criterion 7: likely not a simple CHECK, so the group needs either a trigger or
an explicit documented deferral to the application layer.

### 9. Defaults (weight: low)
Sensible defaults where appropriate: e.g. booking status defaults to 'pending', account
status defaults to 'active', timestamps default to current time where it makes sense
(created_at-style columns, if the group added them).

### 10. Style / readability (weight: low)
Consistent naming convention (snake_case throughout, consistent singular/plural table
naming), comments explaining non-obvious constraints (especially the overlap-prevention
mechanism), logical statement ordering (tables created before any FK referencing them).

## Scoring guidance for this task
- Executability and structural correctness (criteria 1–5) ~35% combined — these are
  pass/fail in nature; a script that doesn't run or has wrong FK types is a hard blocker
  regardless of how well rules are handled elsewhere.
- Business-rule enforcement (criteria 6–8) ~45% combined, with criterion 7 (overlap rule)
  weighted as the single heaviest individual criterion in this task — it's the requirement's
  headline rule and the clearest test of whether the group actually engineered a solution
  versus just wrote tables.
- Defaults and style (9–10) ~20% combined.

## Common failure patterns to watch for
- Script fails to execute due to table creation order (FK referencing a not-yet-created
  table) — easy automatic blocker, check this first.
- ID type mismatch between a PK declared as SERIAL/INT and a FK declared as VARCHAR
  or vice versa.
- Status CHECK constraints that don't match the exact value list from task 1 (e.g. missing
  'no-show' or using 'checked-in' vs. 'checked in' inconsistently with other docs).
- No overlap-prevention mechanism at all, and no note acknowledging the gap — silent
  omission of the most important rule in the entire project.
- `ON DELETE CASCADE` applied carelessly to Booking via User, which would silently
  delete booking history if a user account is removed — contradicts the requirement's
  stated goal of preserving usage history.