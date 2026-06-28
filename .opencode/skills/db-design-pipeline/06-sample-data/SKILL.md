---
name: 06-sample-data
description: Generates realistic SQL INSERT statements to populate the database.
compatibility: opencode
---

# Step 6: Sample Data Preparation Skill

When executing this skill, generate SQL `INSERT` statements that adhere to these requirements:

**1. Data Coverage**
- Insert records for all 9 entities defined in Step 5.
- Include varied roles (Student, Lecturer, etc.) and statuses.
- Populate spaces with all statuses (`Available`, `InUse`, `UnderMaintenance`, etc.).

**2. Complexity & Edge Cases**
- Create at least one "Overlapping Booking" scenario to verify that your trigger logic (defined in Step 5) would work.
- Include bookings with all possible statuses (Pending, Approved, Rejected, etc.).
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
- [ ] No booking is placed on an `UnderMaintenance`/`TemporarilyClosed`/`Retired` space.
- [ ] Comments that reference a booking match the actual `booking_id` used (or FK lookups are used so this cannot drift).
- [ ] INSERT order respects FK dependencies; all enum values match the Step 5 CHECK whitelists.