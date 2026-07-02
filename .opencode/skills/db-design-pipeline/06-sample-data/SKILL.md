---
name: 06-sample-data
description: Generates realistic SQL INSERT statements to populate the database.
compatibility: opencode
---

# Step 6: Sample Data Preparation Skill

When executing this skill, generate SQL `INSERT` statements that adhere to these requirements:

**0. Prerequisite: Query Awareness**
- BEFORE writing any INSERT statements, read `outputs/07-query-design-G08.sql` completely.
- Ensure the sample data produces meaningful, multi-row results for EVERY query in that file. Each query's filtering/aggregation must return at least 1 row (preferably 2+ rows).
- If a query filters by status, date range, role, or specific relationship, populate data so that query returns a non-trivial result.

**1. Data Coverage**
- Insert records for all 9 entities defined in Step 5.
- Include varied roles (Student, Lecturer, etc.) and statuses.
- Populate spaces with ALL statuses defined in the DDL: `Available`, `InUse`, `UnderMaintenance`, `TemporarilyClosed`, and `Retired`. Every space status value must appear on at least one space row.

**2. Complexity & Edge Cases**
- Create at least one "Overlapping Booking" scenario to verify that your trigger logic (defined in Step 5) would work.
- Include bookings with ALL possible booking statuses: `Pending`, `Approved`, `Rejected`, `Cancelled`, `CheckedIn`, `Completed`, `NoShow`.
- Include maintenance records with ALL possible maintenance statuses: `Reported`, `Assigned`, `InProgress`, `Completed`, `Cancelled`.
- Every `NoShow` booking MUST have a corresponding `booking_decisions` row with `decision = 'Approved'` and a decision timestamp before the booking start — a booking must be approved before it can become a no-show.
- Create at least one explicit scenario where a space's maintenance window or temporary closure conflicts with a pre-existing approved booking, demonstrating the "maintenance blocks booking" business rule. Document this with inline comments.
- Create maintenance records for spaces to verify that those spaces cannot be booked.

**2a. Booking ↔ Usage-Session lifecycle consistency (MUST)**
A booking's `status` must match the state of its usage session, or the data is logically inconsistent:
- A booking that has a **completed** usage session (both `actual_end_time` and `completed_by` set) MUST have `status = 'Completed'` — never `Approved`.
- A booking with an **open** usage session (checked in, not completed) MUST have `status = 'CheckedIn'`.
- A booking with `status IN ('Pending','Rejected','Cancelled','NoShow')` MUST NOT have a usage session.
- A `Rejected` booking must have a `booking_decisions` row whose `decision = 'Rejected'` and a non-NULL `rejection_reason`. Any `Approved`/`CheckedIn`/`Completed`/`NoShow` booking should have at least one `Approved` decision record.
- Do not place a booking (status `Pending`/`Approved`) on a space whose `current_status` is `UnderMaintenance`/`TemporarilyClosed`/`Retired`.

**3. Relational Integrity**
- Ensure that the order of `INSERT` statements respects Foreign Key dependencies (e.g., insert `departments` before `user_accounts`; insert `spaces` before `bookings`).

**4. Metadata**
- Populate `created_at` and `updated_at` timestamps using `GETDATE()` or realistic past dates.

**5. Volume**
- Generate enough data (e.g., 5-10 rows per master table) to ensure that your upcoming Step 7 queries return meaningful, multi-row results.

**6. Formatting**
- Use standard SQL Server `INSERT INTO` syntax.
- Wrap the entire script in a single transaction if possible, or include clear `GO` separators between logical blocks.
- Prefer resolving foreign keys via lookups (e.g. `(SELECT space_id FROM spaces WHERE space_code = N'...')` or a `DECLARE @var = (SELECT ...)`) rather than hard-coding identity numbers like `booking_id = 8`. Hard-coded IDs assume insert order equals identity order and cause silent mismatches (e.g. a comment that says "Booking #7" pointing at id 8).

**7. Self-Review Checklist (run before finishing)**
- [ ] Every `Completed` booking has a completed usage session; every booking with a completed session is `Completed` (not `Approved`).
- [ ] Every `CheckedIn` booking has an open (not-completed) usage session; no `Pending`/`Rejected`/`Cancelled`/`NoShow` booking has a session.
- [ ] Each `Rejected` decision has a non-NULL `rejection_reason`; approved-lifecycle bookings have an approval decision.
- [ ] Every `NoShow` booking has a prior `Approved` booking_decisions record (cannot become NoShow without being approved first).
- [ ] No booking is placed on an `UnderMaintenance`/`TemporarilyClosed`/`Retired` space.
- [ ] ALL space status values (`Available`, `InUse`, `UnderMaintenance`, `TemporarilyClosed`, `Retired`) are represented in the data.
- [ ] ALL maintenance status values (`Reported`, `Assigned`, `InProgress`, `Completed`, `Cancelled`) are represented in the data.
- [ ] At least one scenario exists where maintenance blocks a booking (a space has maintenance while a booking exists or conflicts with it).
- [ ] Comments that reference a booking match the actual `booking_id` used (or FK lookups are used so this cannot drift).
- [ ] INSERT order respects FK dependencies; all enum values match the Step 5 CHECK whitelists.
- [ ] Query file `outputs/07-query-design-G08.sql` was read before generation, and every query returns ≥1 row from the generated data (verified in a top comment block).