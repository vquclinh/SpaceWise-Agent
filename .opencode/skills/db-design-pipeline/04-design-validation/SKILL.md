---
name: 04-design-validation
description: Validates the logical schema against the conceptual ERD and business rules.
compatibility: opencode
---

# Step 4: Design Validation Skill

When executing this skill, generate the validation document with the following exact structure:

**1. ERD to Relational Schema Verification**
Verify that all 9 conceptual entities from Step 2 successfully map to physical tables in Step 3, and all conceptual relationships (Crow's Foot lines) are materialized as explicit Foreign Key columns.

**2. Business Rules Addressed**
Detail how all rules identified in Step 1 are actively enforced via table structures, constraints, or database triggers.

**3. Normalization Check (3NF)**
Confirm the schema satisfies 3NF: All attributes are atomic (1NF), all non-key attributes depend on the entire primary key (2NF), and there are no transitive dependencies (3NF).

**4. Overlap Conflict Prevention Logic**
Explain that a standard `CHECK` constraint cannot compare multiple rows. Document the cross-row enforcement strategy (a trigger, stored procedure, or application-layer validation) that blocks `(NewStart < ExistingEnd) AND (NewEnd > ExistingStart)` for `Approved` bookings on the same space. **The strategy you describe must match the accepted DDL in Output 05** — if Output 05 uses a gated `AFTER INSERT, UPDATE` trigger, describe that; `INSTEAD OF` may be noted only as an alternative tradeoff. Do not paste Output 05's full trigger body or its trigger name here.

**5. Status-Based Booking Prevention Validation**
Document how the system explicitly rejects bookings if the target space is `UnderMaintenance`, `TemporarilyClosed`, or `Retired` by cross-referencing `spaces.current_status`.

**6. Referential Integrity Validation**
Explain how Foreign Keys enforce strict referential integrity (e.g., restricting deletions on master tables to preserve historical `bookings`). Explicitly note the `UNIQUE` constraint on `usage_sessions.booking_id` that guarantees the 1-to-0..1 relationship.

**7. Identified Design Issues & Resolutions**
Log any structural flaws found during the mapping process and how they were resolved (e.g., adding the rejection reason column, or fixing the check-in cardinality).