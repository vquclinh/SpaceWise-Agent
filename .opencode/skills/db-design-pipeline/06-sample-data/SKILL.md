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

**3. Relational Integrity**
- Ensure that the order of `INSERT` statements respects Foreign Key dependencies (e.g., insert `departments` before `user_accounts`; insert `spaces` before `bookings`).

**4. Metadata**
- Populate `created_at` and `updated_at` timestamps using `GETDATE()` or realistic past dates.

**5. Volume**
- Generate enough data (e.g., 5-10 rows per master table) to ensure that your upcoming Step 7 queries return meaningful, multi-row results.

**6. Formatting**
- Use standard SQL Server `INSERT INTO` syntax.
- Wrap the entire script in a single transaction if possible, or include clear `GO` separators between logical blocks.