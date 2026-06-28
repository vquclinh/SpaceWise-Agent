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
- Provide the trigger SQL for these two rules. **Prefer an `AFTER INSERT, UPDATE` trigger over `INSTEAD OF`** because:
  - `AFTER` keeps `IDENTITY` / `SCOPE_IDENTITY()` working for callers (an `INSTEAD OF INSERT` trigger breaks `SCOPE_IDENTITY()` and forces a fragile manual re-INSERT).
  - `AFTER` validates the already-written rows and rolls back on failure — no need to re-implement the INSERT/UPDATE.
- **Gate each rule so it only fires for the relevant transition (do NOT over-enforce):**
  - *Overlap rule:* only reject when the **new/updated row is `Approved`** and it overlaps an **existing `Approved`** booking for the same space (`i.status = 'Approved'`). Overlap test: `existing.start < new.end AND existing.end > new.start`.
  - *Availability rule:* only reject when the booking is being placed into an **active state** (`status IN ('Pending','Approved')`) for a space whose `current_status IN ('UnderMaintenance','TemporarilyClosed','Retired')`. **Do not block** `Cancelled` / `Completed` / `NoShow` updates of existing bookings on a now-unavailable space.
- To reject inside a trigger, use `ROLLBACK TRANSACTION; RAISERROR('...', 16, 1); RETURN;` (universally parseable). If you use `THROW`, ensure the preceding statement is terminated with `;`.
- Do **not** turn capacity-vs-participants into a hard rule here — it is an open/inferred question, not a confirmed constraint.

**4. Indexing Strategy**
- Include `CREATE INDEX` statements for the lookup/filter paths identified in the logical design (e.g., `bookings.status`, `bookings.requested_start_time`, `maintenance_records.status`).

**5. Comments**
- Use SQL comments (`--`) to explain complex constraint logic or trigger behavior for the professor/TA to review.

**6. Formatting**
- Ensure the file ends with a clear summary of which constraints handle which business rules.

**7. Batch Separators (GO) — MUST**
- Use a `GO` batch separator **after each `CREATE TABLE ... );` block**. This makes the DDL easier to debug table-by-table in SSMS / Azure Data Studio / sqlcmd and keeps each object in its own batch.
- `CREATE TRIGGER` (and `CREATE PROCEDURE` / `VIEW` / `FUNCTION`) **must be the first statement in its batch**. Isolate each trigger in its own batch: put a `GO` immediately **before** the `CREATE TRIGGER` and a `GO` **after** its `END;`.
- Concretely: after the last `CREATE INDEX`, emit `GO`, then `CREATE TRIGGER ...`, then `END;`, then `GO`. Without the preceding `GO`, SQL Server fails with *"CREATE TRIGGER must be the first statement in the query batch."* and the trigger is never created (so the business rules silently go unenforced).
- Avoid duplicated/empty `GO` lines; one separator per real batch boundary. The script is meant to run top-to-bottom in one file.

**8. Self-Review Checklist (run before finishing)**
- [ ] Every `CREATE TABLE` precedes the tables that reference it (FK dependency order).
- [ ] Every table has a PK; all FKs, UNIQUEs, CHECKs, DEFAULTs from Step 3/4 are present.
- [ ] `GO` appears after every `CREATE TABLE` block.
- [ ] `CREATE TRIGGER` statements are isolated in their own batches with `GO` before and after.
- [ ] Trigger is `AFTER` (not `INSTEAD OF`) unless there is a specific reason; `SCOPE_IDENTITY()` is not broken.
- [ ] Overlap rule fires only for `Approved` new rows; availability rule fires only for `Pending`/`Approved` placements — cancel/complete/no-show updates are NOT blocked.
- [ ] Rejections use `ROLLBACK; RAISERROR; RETURN;` (or `THROW` with a preceding `;`).
- [ ] No invented hard constraints (e.g. capacity remains open/inferred).
- [ ] The whole script runs cleanly on a fresh SQL Server database in one pass.