# Rubric: 06-sample-data-G<Group#>.sql

Specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions)
— do not repeat those here.

## Source of truth
Grade against `05-db-definition-G<Group#>.sql` as the schema it must respect, and against
the business rules/scenarios in `01-business-req-analysis-G<Group#>.md` and the PDF for
what scenarios the data needs to exercise. This is the first output where you check both
"does it load" and "does it tell a believable story" — sample data that's structurally valid
but unrealistic (e.g. all bookings on one day, no rejections, no maintenance) fails the
purpose of this task even if every INSERT runs cleanly.

## How to grade (mechanical step first)
If you have execution access, run `05-db-definition` then this script against a clean
database and confirm every INSERT succeeds with no constraint violations. If something
fails, note exactly which statement and which constraint it violates — that's a blocker.
If you cannot execute, manually trace at least the high-risk inserts (overlapping bookings,
FK references, status transitions) against the schema's declared constraints.

## Criteria

### 1. Referential integrity (weight: high)
Every FK value inserted (space_id, requester_id, decided_by, etc.) references a row that
actually exists and was inserted earlier in the script (insertion order matters — flag if a
row references something not yet inserted). No orphaned references.

### 2. Coverage of all tables (weight: high)
Every table from the schema has sample rows — including ones that are easy to forget
like Facility and Maintenance Record. A schema with zero maintenance records or zero
facility entries fails to test a meaningful part of the system.

### 3. Coverage of all roles (weight: medium)
Sample Users include at least one of each role: student, lecturer, teaching assistant,
facility staff, department administrator, facility manager — since downstream queries
(task 7) likely need to filter or join by role, and a missing role makes some legitimate
business questions untestable.

### 4. Coverage of all status values (weight: high)
For each status-type column, sample data includes rows in every (or nearly every) listed
status value, not just the "happy path":
- Booking status: pending, approved, rejected, cancelled, checked in, completed, and
  no-show should all appear at least once.
- Space status: at least one space in each of available, under maintenance, and ideally
  also temporarily closed / retired.
- Maintenance status: open/in-progress and completed should both appear.
A dataset that only has 'approved' and 'completed' bookings, with no rejected/cancelled/
no-show examples, should be marked down — these are exactly the rows task 7's queries
and the report's "important exceptional cases" requirement need to exist.

### 5. Business rule compliance (weight: high)
- No two *approved* bookings on the same space have overlapping time ranges — verify
  this manually for at least the bookings sharing a space, since this is the rule most likely
  to be silently violated if the group wasn't careful (and if the DDL's overlap-prevention
  trigger/constraint works, this should be enforced automatically — use that as a sanity
  check: did the INSERTs need to dodge the constraint, or could they have violated it?).
- No bookings against spaces marked under maintenance, closed, or retired at the time of
  the booking.
- Rejected bookings have a rejection reason populated.
- Checked-in/completed bookings have their actual-time and condition fields populated;
  pending/rejected/cancelled bookings should NOT have those fields populated (leaving
  them NULL correctly demonstrates the lifecycle was understood).
- Maintenance records that block a space show a sensible time window, and ideally at
  least one example where a maintenance window overlaps what would otherwise be a
  booking request, to test the "space under maintenance cannot be booked" rule downstream
  in task 7's queries.

### 6. Exceptional / edge cases explicitly present (weight: high)
The project brief asks for data supporting "normal operations and important exceptional
cases" — check for deliberate inclusion of:
- A no-show booking.
- A rejected booking with a clear, realistic rejection reason.
- A cancelled booking.
- An attempted double-booking scenario that the schema correctly prevents (this can be
  demonstrated via a comment showing a blocked INSERT, rather than literally trying to
  break the live script) — or, if the group tested this separately, a note referencing it.
- A space currently under maintenance with at least one pre-existing approved booking
  that had to be relocated/cancelled because of it, if the group wants to show that
  scenario (optional but a strong sign of thoroughness).

### 7. Realism / narrative coherence (weight: medium)
Names, emails, departments, room numbers, dates, and times should read as plausible
campus data rather than placeholder strings like `user1@test.com` / `Room A`. Time spans
should make sense (e.g. an exam booking during a plausible exam period, not at 3am).
This matters because task 7's queries and the report will be judged partly on whether the
underlying data tells a coherent story.

### 8. Volume (weight: low)
Enough rows per table to make queries in task 7 meaningful (e.g. enough bookings that a
"most-used space" or "busiest month" query produces a non-trivial answer) — a handful of
rows per table (2-3) is too thin; aim for at least enough variety that aggregate queries
return differentiated results. Exact numbers aren't graded, but obviously inadequate
volume should be flagged.

## Scoring guidance for this task
- Referential integrity and rule compliance (criteria 1 & 5) are pass/fail in spirit — weight
  them ~30% combined, and treat any violation found as blocker-severity since it means
  the schema's own constraints were bypassed or the data is simply wrong.
- Status/role/table coverage and exceptional cases (criteria 2–4, 6) ~45% combined — this
  is the core value of "sample data" as distinct from "valid data": it has to actually
  exercise the interesting parts of the design.
- Realism and volume (7–8) ~25% combined.

## Common failure patterns to watch for
- All bookings inserted as 'approved' or 'completed' with no rejected/cancelled/no-show
  examples — the most common shortcut groups take and the easiest to catch.
- Actual-time/condition fields populated on bookings that are still 'pending' (a logical
  contradiction — those fields shouldn't exist until check-in/completion happens).
- No maintenance records, or maintenance records with no connection to any space's
  booking conflicts.
- INSERT order violating FK dependency order (inserting Bookings before the Users or
  Spaces they reference).
- Rejection reason left NULL on rejected bookings.
- Every user has the same role, defeating any role-based query in task 7.