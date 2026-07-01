# Rubric: 01-business-req-analysis-G<Group#>.md

Specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale,
report format, general dimensions) — do not repeat those here.

## Source of truth
Grade against the original requirement description (CS486_Project.pdf, section 1) and
nothing else. If the output invents requirements not implied by the source, flag as
"unsupported assumption" rather than penalizing on its own — but do penalize if it
contradicts the source.

## Criteria

### 1. Business purpose (weight: low)
- States the goal of the system in 2-4 sentences: manage booking/usage of shared
  campus spaces, avoid overlapping bookings, prevent use of unavailable spaces,
  preserve history.
- Fail if purpose is missing, copied verbatim from the prompt with no synthesis, or
  misses the conflict-prevention angle entirely.

### 2. Actors identified (weight: medium)
Must identify, at minimum:
- Student
- Lecturer
- Teaching Assistant
- Facility Staff
- Department Administrator
- Facility Manager

Each actor should have a one-line description of their interaction with the system
(e.g. "submits booking requests", "approves/rejects bookings", "checks in/out sessions").
Missing an actor = partial credit deduction per actor. Inventing actors not in the source
without justification = flag.

### 3. Entities identified (weight: high)
Expected core entities (names may vary, but concepts must be present):
- User
- Space
- Facility (equipment per space)
- Booking / Booking Request
- Maintenance Record
- (Optional but good: Approval/Decision as separate concept, or folded into Booking)

For each entity, check that the analysis lists attributes matching the source, e.g.:
- User: user ID, full name, email, phone, role, department, account status
- Space: space code, name, type, building, floor, room number, capacity, status,
  usage policy
- Booking: requester, space, requested start/end time, purpose, expected participants,
  status, decision maker, decision time, decision note, rejection reason, check-in/out
  fields, actual start/end time, space condition, usage notes
- Maintenance Record: space, reporter, assigned staff, problem description, start time,
  completion time, status, result note

Deduct for entities missing entirely, or attributes silently dropped without note.

### 4. Relationships & cardinalities (weight: high)
Must correctly capture, at minimum:
- User submits many Bookings (1:N)
- Booking is for one Space (N:1)
- Space has many Facilities (1:N)
- Booking is approved/rejected by one User acting as staff (N:1, role-constrained)
- Space has many Maintenance Records (1:N)
- Maintenance Record reported by one User, assigned to one User (two distinct N:1
  relationships — check these aren't collapsed into one)

Flag if cardinalities are stated backwards (e.g. "Space has many Bookings" written as
1:1) or omitted entirely.

### 5. Business rules extracted (weight: high)
Must explicitly list, as rules (not just embedded in prose):
- No two approved bookings on the same space may have overlapping time periods.
- A space under maintenance, closed, or retired cannot be booked.
- Rejected bookings must store a rejection reason.
- Check-in records actual start time, who checked in, initial condition.
- Completion records actual end time, final condition, usage notes.
- A space under maintenance cannot be booked (overlaps with above — should appear,
  not be missing).

Each omitted rule is a meaningful deduction since these become CHECK constraints /
triggers later — missing them here means missing them in every downstream task.

### 6. Traceability to later phases (weight: medium)
- Document should be usable as direct input to ERD design (task 2) without requiring
  the reader to re-read the original PDF. If a grader unfamiliar with the source could
  not draw a reasonable ERD from this doc alone, deduct here.

## Scoring guidance for this task
- Treat criteria 3, 4, and 5 (entities, relationships, business rules) as the load-bearing
  sections — weight them roughly 60% of this task's score combined.
- Actors and business purpose are lower-stakes; weight ~20% combined.
- Traceability is a holistic check; weight ~20%.

## Common failure patterns to watch for
- Restating the PDF prose without structuring it into actors/entities/relationships/rules.
- Listing entities without attributes, or attributes without types/notes on constraints.
- Treating "decision" (approve/reject) as an attribute of Booking only, without noting it
  needs a staff-user reference and timestamp — this is an early signal the student didn't
  think through the relationship to User.
- Omitting the no-show and cancelled booking statuses.
- Skipping facility (equipment) as its own concept and just listing it as a text field on
  Space — acceptable but should be flagged as a design choice to revisit in task 2 if the
  group wants a queryable facility list.