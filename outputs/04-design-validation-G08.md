# Step 4: Design Validation for G08

## 1. ERD to Relational Schema Verification

All 9 conceptual entities from the conceptual ERD (Step 2) successfully map to physical tables in the logical schema (Step 3):

| Conceptual Entity (Step 2) | Logical Table (Step 3) | Mapping Status |
|---|---|---|
| Department | `departments` | Present |
| UserAccount | `user_accounts` | Present |
| Space | `spaces` | Present |
| Facility | `facilities` | Present |
| SpaceFacility | `space_facilities` | Present |
| Booking | `bookings` | Present |
| BookingDecision | `booking_decisions` | Present |
| UsageSession | `usage_sessions` | Present |
| MaintenanceRecord | `maintenance_records` | Present |

All 14 Crow's Foot relationship lines from the conceptual ERD are materialized as explicit Foreign Key columns:

| Relationship (Step 2) | FK Column | Referenced Table |
|---|---|---|
| Department → UserAccount | `user_accounts.department_id` | `departments` |
| UserAccount → Booking (requests) | `bookings.requester_id` | `user_accounts` |
| Space → Booking | `bookings.space_id` | `spaces` |
| Booking → BookingDecision | `booking_decisions.booking_id` | `bookings` |
| UserAccount → BookingDecision (decides) | `booking_decisions.decided_by` | `user_accounts` |
| Booking → UsageSession | `usage_sessions.booking_id` | `bookings` |
| UserAccount → UsageSession (checks in) | `usage_sessions.checked_in_by` | `user_accounts` |
| UserAccount → UsageSession (completes) | `usage_sessions.completed_by` | `user_accounts` |
| Space → SpaceFacility | `space_facilities.space_id` | `spaces` |
| Facility → SpaceFacility | `space_facilities.facility_id` | `facilities` |
| Space → MaintenanceRecord | `maintenance_records.space_id` | `spaces` |
| UserAccount → MaintenanceRecord (reports) | `maintenance_records.reporter_id` | `user_accounts` |
| UserAccount → MaintenanceRecord (assigned) | `maintenance_records.assigned_staff_id` | `user_accounts` |

**Conclusion:** Entity-to-table mapping is complete (9/9), and relationship-to-FK mapping is complete (14/14). No conceptual element is lost.

## 2. Business Rules Addressed

| Rule # | Rule Description | Enforcement Mechanism |
|---|---|---|
| 1 | No overlapping approved bookings | `AFTER INSERT, UPDATE` trigger checks overlap for Approved bookings on the same space |
| 2 | Unavailable space cannot be booked | `AFTER INSERT, UPDATE` trigger blocks insert/update when space status is `UnderMaintenance`, `TemporarilyClosed`, or `Retired` for Pending/Approved bookings |
| 3 | Booking lifecycle statuses | `CHECK` constraint `CK_bookings_status` whitelists valid statuses |
| 4 | Requested end time after start time | `CHECK` constraint `CK_bookings_time_range` |
| 5 | Positive expected participants | `CHECK` constraint `CK_bookings_expected_participants` |
| 6 | Approval stores deciding staff, decision time, decision note, rejection reason | Columns `decided_by`, `decision_time`, `decision_note`, `rejection_reason` on `booking_decisions`; `CK_booking_decisions_rejection_reason` enforces rejection reason when `decision = 'Rejected'` |
| 7 | Only staff can decide | Enforced at application layer (role-based access); schema stores FK to `user_accounts` as `decided_by` |
| 8 | Check-in records actual start time, checked-in-by, initial condition | Columns `actual_start_time`, `checked_in_by`, `initial_condition` on `usage_sessions` |
| 9 | Check-out records actual end time, final condition, usage notes | Columns `actual_end_time`, `completed_by`, `final_condition`, `usage_notes` on `usage_sessions` |
| 10 | Only approved bookings can be checked in | Enforced at application layer; schema does not prevent inserting a `usage_sessions` row for any booking |
| 11 | Only checked-in bookings can be completed | Enforced at application layer; schema relies on `CK_usage_sessions_completion` for paired null consistency |
| 12 | Actual end time after actual start time | `CHECK` constraint `CK_usage_sessions_end_time` |
| 13 | Active maintenance blocks booking | Enforced by the gated `AFTER INSERT, UPDATE` trigger (same trigger as Rule 1) — space with non-completed/cancelled maintenance is marked `UnderMaintenance` in `spaces.current_status` |
| 14 | Maintenance references a space | `FK_maintenance_records_space_id` |
| 15 | Historical records preserved | No `ON DELETE CASCADE` on any FK; records remain in `bookings`, `booking_decisions`, `usage_sessions`, `maintenance_records` indefinitely |
| 16 | Capacity guideline | Columns exist (`capacity`, `expected_participants`) but no constraint enforces this — recorded as an open question |
| 17 | Active account access control | `account_status` column with CHECK constraint; enforcement of which statuses can book is at application layer |
| 18 | Overlap definition | Standard interval overlap logic used in trigger: `s1 < e2 AND e1 > s2` |
| 19 | Booking refers to one space | `bookings.space_id` is a single non-nullable FK — exactly one space per booking |
| 20 | created_at/updated_at metadata | Present on `user_accounts`, `spaces`, `bookings`, `maintenance_records` with `DEFAULT GETDATE()` |

## 3. Normalization Check (3NF)

### 1NF (Atomicity)

All table columns contain atomic values:
- No multi-valued attributes exist in any table.
- `space_facilities` resolves the M-N relationship between Space and Facility, eliminating the need for repeating groups.
- Composite attributes (e.g., address) are decomposed into `building`, `floor`, `room_number`.
- All array-like or list data is stored in separate related tables.
- **Result:** Schema satisfies 1NF.

### 2NF (Full Functional Dependency)

Every non-key attribute depends on the entire primary key:
- All tables with surrogate single-column PKs (8 of 9 tables) trivially satisfy 2NF — since the PK is a single column, any partial dependency is impossible.
- The junction table `space_facilities` has a composite PK `(space_id, facility_id)`. Its non-key attributes (`quantity`, `condition`, `note`) depend on the full combination of space and facility (i.e., how many of a given facility are in a given space). There is no partial dependency on just `space_id` or just `facility_id`.
- **Result:** Schema satisfies 2NF.

### 3NF (No Transitive Dependencies)

No non-key attribute depends transitively on another non-key attribute:
- `departments`: `department_name` depends directly on `department_id`.
- `user_accounts`: All attributes depend on `user_id`. `department_id` is a FK (not a transitive dependency — it references a different entity's key).
- `spaces`: All attributes depend on `space_id`. No non-key attribute determines another non-key attribute.
- `facilities`: `facility_name` and `description` depend directly on `facility_id`.
- `space_facilities`: `quantity`, `condition`, `note` depend on the composite PK (space + facility combination).
- `bookings`: All attributes depend on `booking_id`. `requester_id` and `space_id` are FKs, not transitive dependencies.
- `booking_decisions`: All attributes depend on `decision_id`. `booking_id` and `decided_by` are FKs.
- `usage_sessions`: All attributes depend on `session_id`. `booking_id`, `checked_in_by`, `completed_by` are FKs.
- `maintenance_records`: All attributes depend on `maintenance_id`. `space_id`, `reporter_id`, `assigned_staff_id` are FKs.
- **Result:** Schema satisfies 3NF.

### Overall Normalization Verdict

The schema is fully normalized to **3NF**. No denormalization was necessary because the domain model is straightforward and the query patterns (booking history, space availability, maintenance tracking) are well served by the normalized structure with appropriate indexes.

## 4. Overlap Conflict Prevention Logic

### Why a CHECK constraint is insufficient

A standard `CHECK` constraint operates on a single row and cannot compare values across multiple rows. The overlap rule — no two Approved bookings for the same space with overlapping time ranges — requires cross-row comparison: `(NewStart < ExistingEnd) AND (NewEnd > ExistingStart)`. This cannot be expressed in a column-level or table-level CHECK constraint.

### Accepted strategy (matching Output 05 DDL)

The accepted implementation is a single **gated `AFTER INSERT, UPDATE` trigger** on the `bookings` table. This trigger enforces two business rules in one pass:

1. **Overlap check** — Only fires for rows that are or have become `Approved`. It detects whether the inserted/updated row's time range overlaps any existing `Approved` booking for the same space (excluding itself).

2. **Unavailable-space check** — Fires when a booking is being placed into an active state (`Pending` or `Approved`). It rejects the operation if the referenced space's `current_status` is `UnderMaintenance`, `TemporarilyClosed`, or `Retired`. Lifecycle transitions such as `Cancelled`, `Completed`, or `NoShow` are not blocked even if the space later became unavailable.

The trigger uses `AFTER` (not `INSTEAD OF`) so that `IDENTITY` / `SCOPE_IDENTITY()` continue working for callers and normal DML operations are not disrupted. On violation, the trigger issues `ROLLBACK TRANSACTION` and `RAISERROR`.

### Alternative approaches considered

- **INSTEAD OF trigger:** Valid alternative that validates before the write, but breaks `SCOPE_IDENTITY()` and requires manually re-implementing the INSERT/UPDATE logic.
- **Stored procedure enforcement:** All writes go through a dedicated procedure that validates business rules before executing DML. Provides good encapsulation but relies on application discipline to use the procedure rather than direct INSERT/UPDATE.
- **Application-layer enforcement:** Validation logic in the application code before sending SQL. Simplest to implement but can be bypassed if multiple clients connect directly to the database.

## 5. Status-Based Booking Prevention Validation

### Rule

A booking cannot be placed or approved for a space whose `current_status` is `UnderMaintenance`, `TemporarilyClosed`, or `Retired`.

### Implementation

The gated `AFTER INSERT, UPDATE` trigger cross-references the `spaces` table through the `space_id` FK. The check logic:

1. Joins `inserted` (the new/updated booking rows) with `spaces` on `space_id`.
2. Filters for rows where `inserted.status IN ('Pending', 'Approved')` and `spaces.current_status IN ('UnderMaintenance', 'TemporarilyClosed', 'Retired')`.
3. If any matching row is found, the trigger rolls back the transaction and raises an error.

### Edge cases handled

- **Status transitions that bypass the check:** Cancelling, completing, or marking a booking as No-show is always allowed regardless of the space's current status. This prevents a situation where an in-progress booking cannot be closed because maintenance started on the space.
- **Non-active booking creation:** A booking inserted directly with `Rejected` or `Cancelled` status (e.g., as a historical import) is not blocked — the check only applies to `Pending` and `Approved` states.
- **Space status changes after booking approval:** If a space's status changes to `UnderMaintenance` after a booking was already approved, the existing approved booking remains valid. The rule only blocks new or newly approved bookings.

### Visual flow

```
New/Updated Booking (INSERT/UPDATE on bookings)
  │
  ├── Is status 'Pending' or 'Approved'?
  │     ├── Yes → Check spaces.current_status for the space
  │     │           ├── 'UnderMaintenance' / 'TemporarilyClosed' / 'Retired'
  │     │           │     → ROLLBACK, RAISERROR
  │     │           └── 'Available' / 'InUse'
  │     │                 → Proceed
  │     └── No (Cancelled/Completed/NoShow/etc.) → Skip check, proceed
  │
  └── Is status 'Approved'?
        ├── Yes → Check for overlapping Approved bookings on same space
        │           ├── Overlap found → ROLLBACK, RAISERROR
        │           └── No overlap → Proceed
        └── No → Skip overlap check, proceed
```

## 6. Referential Integrity Validation

### Foreign Key Constraints

All 13 Foreign Key constraints enforce strict referential integrity:

| FK Constraint | Parent Table | Referenced Table | Effect on Deletion |
|---|---|---|---|
| `FK_user_accounts_department_id` | `user_accounts` | `departments` | Restrict (default) |
| `FK_bookings_requester_id` | `bookings` | `user_accounts` | Restrict |
| `FK_bookings_space_id` | `bookings` | `spaces` | Restrict |
| `FK_booking_decisions_booking_id` | `booking_decisions` | `bookings` | Restrict |
| `FK_booking_decisions_decided_by` | `booking_decisions` | `user_accounts` | Restrict |
| `FK_usage_sessions_booking_id` | `usage_sessions` | `bookings` | Restrict |
| `FK_usage_sessions_checked_in_by` | `usage_sessions` | `user_accounts` | Restrict |
| `FK_usage_sessions_completed_by` | `usage_sessions` | `user_accounts` | Restrict |
| `FK_space_facilities_space_id` | `space_facilities` | `spaces` | Restrict |
| `FK_space_facilities_facility_id` | `space_facilities` | `facilities` | Restrict |
| `FK_maintenance_records_space_id` | `maintenance_records` | `spaces` | Restrict |
| `FK_maintenance_records_reporter_id` | `maintenance_records` | `user_accounts` | Restrict |
| `FK_maintenance_records_assigned_staff_id` | `maintenance_records` | `user_accounts` | Restrict |

All FKs use the default `NO ACTION` (restrict) on delete. No `ON DELETE CASCADE` is specified anywhere — this is intentional to preserve historical records. For example, deleting a `spaces` row is prevented if that space has past or future bookings, ensuring booking history remains intact.

### UNIQUE Constraint for 1-to-0..1 Relationship

The `UNIQUE` constraint on `usage_sessions.booking_id` (`UQ_usage_sessions_booking_id`) guarantees that each booking can have at most one usage session. This materializes the conceptual 1-to-0..1 relationship between Booking and UsageSession. Combined with the `NOT NULL` on `usage_sessions.booking_id` and the FK to `bookings`, this enforces:
- Every usage session belongs to exactly one booking (FK + NOT NULL).
- No two usage sessions can reference the same booking (UNIQUE).
- A booking may have zero usage sessions (no row in `usage_sessions`).

### Other UNIQUE Constraints

| Table | Column | Purpose |
|---|---|---|
| `user_accounts` | `email` | Natural business identifier — prevents duplicate user registrations |
| `spaces` | `space_code` | Business code — ensures each room/space has a unique code |
| `facilities` | `facility_name` | Business identifier — prevents duplicate facility entries |

## 7. Identified Design Issues & Resolutions

### Issue 1: Rejection Reason Mandatory on Rejection

**Problem:** During the mapping from conceptual to logical design, the `rejection_reason` attribute on BookingDecision could be optional for approvals but must be mandatory for rejections. Without a constraint, a staff member could reject a booking without providing a reason.

**Resolution:** A conditional `CHECK` constraint `CK_booking_decisions_rejection_reason` was added: `decision <> 'Rejected' OR rejection_reason IS NOT NULL`. This enforces that `rejection_reason` must be non-NULL when `decision = 'Rejected'`, while allowing it to be NULL when `decision = 'Approved'`.

### Issue 2: Check-in / Check-out Completion Field Pairing

**Problem:** The check-out fields (`completed_by`, `actual_end_time`, `final_condition`, `usage_notes`) should be either all NULL (session not yet completed) or all non-NULL (session completed). Without a constraint, partial updates could leave inconsistent data.

**Resolution:** A `CHECK` constraint `CK_usage_sessions_completion` enforces paired null consistency: `(completed_by IS NULL AND actual_end_time IS NULL) OR (completed_by IS NOT NULL AND actual_end_time IS NOT NULL)`. Note that `final_condition` and `usage_notes` are not included in this constraint — they are allowed to be NULL even after completion if the staff member chooses not to fill them, keeping the constraint targeted and practical.

### Issue 3: Overlap Detection Cannot Use CHECK

**Problem:** The critical business rule "No overlapping approved bookings for the same space" requires cross-row comparison, which a standard CHECK constraint cannot perform.

**Resolution:** An `AFTER INSERT, UPDATE` trigger was adopted as the enforcement mechanism. This was documented as the accepted strategy in the logical design (Step 3) and implemented in the DDL (Step 5). The trigger also enforces the unavailable-space rule in a single pass, providing consistent enforcement for both critical rules.

### Issue 4: Booking Lifecycle State Transitions Not Enforced at Schema Level

**Problem:** The booking lifecycle (Pending → Approved/Rejected → CheckedIn → Completed/NoShow) has specific valid transitions that cannot be fully expressed with a simple CHECK constraint on a status column.

**Resolution:** The CHECK constraint `CK_bookings_status` whitelists all valid status values, preventing arbitrary status strings. The specific state transition logic (e.g., preventing a direct transition from Pending to Completed) is deferred to the application layer. Adding a trigger to enforce state transitions was considered but rejected to keep the trigger scope focused on the two critical cross-row business rules. This tradeoff is documented as a known limitation.

### Issue 5: Capacity Enforcement (Open Question)

**Problem:** The system stores both `spaces.capacity` and `bookings.expected_participants`, but the business requirement does not specify whether `expected_participants <= capacity` is a hard rule or a soft guideline.

**Resolution:** No constraint was added. Both values are stored and available for application-level or reporting-level comparison. This remains an open question for the project team to resolve with the stakeholder.

### Issue 6: UsageSession Checked-in-by / Completed-by Role Ambiguity

**Problem:** The conceptual ERD shows two separate relationships from UserAccount to UsageSession ("checks in" and "completes"). In the logical schema, these become two columns (`checked_in_by`, `completed_by`) in the same table. Without clarity, a single staff member could be recorded as both the check-in and check-out staff, which may be acceptable or not depending on policy.

**Resolution:** The schema allows the same staff member to be both `checked_in_by` and `completed_by`, which is a valid real-world scenario (e.g., the same facility staff member handles both check-in and check-out). No constraint prevents this. If the policy changes, an application-level check can enforce separation.
