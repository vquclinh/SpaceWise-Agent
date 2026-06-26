---
name: 05-db-definition
description: Generates Microsoft SQL Server DDL based on the validated logical design.
compatibility: opencode
---

# Step 5: Database Definition (DDL) Skill

When executing this skill, ensure your SQL script adheres to the following:

**1. Table Creation**
- Use `CREATE TABLE` for all 9 entities defined in the logical design.
- Assign `IDENTITY(1,1)` to all surrogate Primary Keys.
- Apply `NOT NULL` to all mandatory fields.

**2. Constraint Implementation**
- Implement all `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, and `CHECK` constraints validated in Step 4.
- Specifically include the requested `CHECK` constraints for rejection reasons and check-out session consistency.

**3. Critical Business Rules Enforcement**
- Document the strategy for rules that cannot be enforced via simple `CHECK` constraints (Overlap Prevention and Space Availability). 
- Provide the SQL code for the `INSTEAD OF` or `AFTER` triggers for these two rules, as documented in the validation step.

**4. Indexing Strategy**
- Include `CREATE INDEX` statements for the lookup/filter paths identified in the logical design (e.g., `bookings.status`, `bookings.requested_start_time`, `maintenance_records.status`).

**5. Comments**
- Use SQL comments (`--`) to explain complex constraint logic or trigger behavior for the professor/TA to review.

**6. Formatting**
- Ensure the file ends with a clear summary of which constraints handle which business rules.