# Step 8: Requirement Change Analysis — G08 (Phase 2)

> **Document:** `outputs/08-requirement-change-analysis-G08.md`
> **Phase:** Phase 2 — System Extension (CS486, Group G08)
> **Baseline:** Phase 1 outputs 01–07 (`outputs/`)
> **Inputs:** `CS486_Project_Phase02.pdf`, `req/business-requirement-P2.md`, `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md`, Phase 1 outputs 01–07
> **Target DBMS:** Microsoft SQL Server (only permitted DBMS; all Phase 2 SQL uses SQL Server syntax)

---

## 1. Change Impact Overview

### 1.1 Phase 2 goals (from `CS486_Project_Phase02.pdf` §1)

After the one-semester pilot of the Phase 1 system, the Facility Manager announced:

1. **Requirement change — maintenance impact levels (§1.1):** the blanket "a space under maintenance cannot be booked" rule is refined into two levels — **out-of-service** (the space itself is unusable; blocks booking exactly as Phase 1) and **advisory** (only part of the equipment/comfort is affected; the space remains bookable but every active advisory must be shown to, and acknowledged by, the requester at booking time). A space may have several active maintenance records at different levels at the same time, and a level may be escalated or downgraded while the record is open. Escalation to out-of-service must make all already-approved overlapping bookings identifiable to staff.
2. **New operating condition — concurrent booking and approval (§1.2):** at semester start, many users submit requests for the same popular spaces within a short interval. Selected space types may **auto-approve** requests at submission time; all others keep the manual staff workflow. The Phase 1 invariant — no two approved bookings may overlap on the same space — must now hold **under concurrency** (multiple users/staff acting simultaneously, via either path).
3. **New reporting needs (§1.3):** four reports — (a) total approved booking hours per space per semester, (b) approved bookings by weekday and hour per semester, (c) the "room finder" (available spaces matching required capacity + facility list within a time window), and (d) approved bookings affected by an escalation to out-of-service.

### 1.2 What remains unchanged (Phase 1 baseline)

- All **9 Phase 1 tables** (`departments`, `user_accounts`, `spaces`, `facilities`, `space_facilities`, `bookings`, `booking_decisions`, `usage_sessions`, `maintenance_records`), every column, and every value of the existing status enums (`Pending`, `Approved`, `Rejected`, `Cancelled`, `CheckedIn`, `Completed`, `NoShow`; `Available`…`Retired`; `Reported`…`Cancelled`) — **no renames, no drops**.
- The booking lifecycle, approval decision audit trail (`booking_decisions` 1–N per booking), check-in/check-out recording, and maintenance record shape from Phase 1.
- Historical record preservation — no `ON DELETE CASCADE` anywhere.
- The Phase 1 trigger `TR_bookings_PreventOverlapAndUnavailable` **stays** — but its role is demoted to a **validation backstop**; it is not the concurrency mechanism (see Section 5), and its `current_status`-based maintenance check is superseded by the direct impact-level check (see Section 4.1).
- Core `created_at` / `updated_at` metadata convention on core entities.
- Naming conventions: `snake_case` tables/columns, PascalCase enum values, named `PK_`/`FK_`/`CK_`/`UQ_`/`TR_`/`IX_` constraints.

### 1.3 What changes in Phase 2

| Aspect | Phase 1 | Phase 2 |
|---|---|---|
| Maintenance blocking | Any active maintenance blocks the space | Only `OutOfService` blocks; `Advisory` requires per-booking acknowledgement |
| Booking-blocking signal | `spaces.current_status` (`'UnderMaintenance'` flag) | Direct `maintenance_records` query for active `impact_level = 'OutOfService'` overlap; `spaces.current_status` kept for **UI display only** (see Section 4.1) |
| Approval path | Manual staff only, all requests start `Pending` | Adds **auto-approval** path for eligible space types (`decision_source = 'System'`) |
| Conflict prevention | `AFTER` trigger (per-statement validation) | Trigger + **concurrency control** (`SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK`, or `sp_getapplock`) in stored procedures; retry on 1205/1222 |
| Facility tracking | `space_facilities.quantity` (a count) | Individual units in `facility_assets` (serial numbers); quantity stays as catalogue metadata, counts derived via a view |
| Maintenance target | Space only | Space or a specific asset (`maintenance_records.asset_id`) |
| Booking interval logic | Reserved window used everywhere | Status-driven: `Approved`/`CheckedIn` block with reserved interval; `Completed` releases immediately (actual occupancy) |
| Escalation handling | Not modeled | `maintenance_impact_history` audit trail + `booking_alerts` affected-bookings list |
| Reporting | Phase 1 history views | + 4 analytical reports (§1.3) with indexing/tuning |

### 1.4 DBMS transition note (explicit)

Phase 1 already targets **Microsoft SQL Server**; Phase 2 adds schema/triggers/procedures **in SQL Server syntax only** and deliberately avoids PostgreSQL constructs: no `tsrange`, no `EXCLUDE USING gist`/`btree_gist` (replaced by the serializable range-lock pattern of Section 5), no deferred/`DEFERRABLE` constraint triggers (replaced by `AFTER` triggers + documented statement order), no `GIN`/array indexes (SQL Server has no array type — `policy_booking_types` junction table instead), no `'infinity'` timestamps (`COALESCE(completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2))` instead), no `SET LOCAL` (`sp_set_session_context` / `SESSION_CONTEXT` instead, SQL Server 2016+).

### 1.5 Normalization scope (3NF)

A full Normalization Validation (3NF) of the **extended Phase 2 schema** (the new tables in Section 2.1 and the modified columns in Section 2.2) will be **formally performed in Task 09 (Logical Design Update)**, where functional dependencies and candidate keys of the extended relations are audited relation by relation. Output 08 deliberately limits itself to flagging derivability constraints that shape the design now — most notably that unit counts must never be stored because they summarize `facility_assets` rows (Section 2.3), and that `is_early_checkout` must remain a derived fact (Section 4.4) — while the full 3NF verification of the extended schema is Task 09's scope.

**Mini-Validation (worked example) — `booking_advisory_acknowledgments`:** as a spot-probe of the most complex new relation (a composite-key associative entity), its compliance is demonstrated here; the exhaustive relation-by-relation audit remains Task 09's scope:

- **1NF — atomic attributes:** every column (`ack_id`, `booking_id`, `maintenance_id`, `acknowledged_by`, `acknowledged_at`) is single-valued and scalar; there are no repeating groups — one row per (booking, advisory) pair, enforced by `UNIQUE (booking_id, maintenance_id)`.
- **2NF — full functional dependency on the composite key:** the natural candidate key is the composite `(booking_id, maintenance_id)`. The non-key attributes (`acknowledged_by`, `acknowledged_at`) depend on the **whole** pair: neither `booking_id` alone nor `maintenance_id` alone determines when an acknowledgement happened or who made it, so no partial dependency exists. (The surrogate `ack_id` PK added in Task 10 is a foreign-key-ergonomics convenience; the dependency analysis uses the natural key.)
- **3NF — no transitive dependencies:** the advisory's descriptive text (e.g., `problem_description`) remains in the parent `maintenance_records`; the acknowledgement row stores only keys and timestamps, so no non-key attribute depends on another non-key attribute.

The relation is **3NF-compliant as designed**.

### 1.6 Scope boundary and downstream impact

**Scope discipline.** Output 08 records requirements and architectural decisions only; it does **not** modify or overwrite any existing Phase 1 deliverables. This document is analysis — no DDL, no data, no changes to `outputs/01`–`07`.

**Downstream impact on Phase 1 outputs (04–07) — which future tasks consume them:**

| Phase 1 output | Consumed by (future task) | Impact |
|---|---|---|
| `04-design-validation-G08.md` | Task 09 — updated ERD and logical design (Output 09) | Re-validated against the extended schema: new relations 3NF-checked (mini-probe in Section 1.5), new relationships re-checked (Section 3), extended design re-validated in Output 09 |
| `05-db-definition-G08.sql` | Task 10 — schema migration (Output 10) | Migration baseline: extended **additively** (new tables, new columns, new triggers); never rewritten or dropped |
| `06-sample-data-G08.sql` | Task 14 — data generator (Output 14) | Baseline seeding data; Phase 2 generator adds ≥ 3 academic years and ≥ 100,000 bookings on top of it |
| `07-query-design-G08.sql` | Task 16 — analytical queries (Output 16) | Phase 1 queries remain valid; the four §1.3 reports are added in Task 16, tuned in Task 15 |

Phase 1 outputs 01–03 (business analysis, conceptual ERD, logical design) are consumed as **context only**; they are likewise not edited — Task 09 produces the *new* updated design document (Output 09) rather than overwriting Outputs 02/03.

---

## 2. Affected Entities and Attributes

**Schema-extension scope at a glance:** 7 new Phase 2 tables (**[Added]**), 2 existing Phase 1 tables extended (**[Modified]**). Phase 1 tables not listed below are untouched.

### 2.1 New entities (**[Added]**)

| New table | Purpose | Key attributes (columns) |
|---|---|---|
| `maintenance_impact_history` **[Added]** | Audit trail for escalation/downgrade — a single `impact_level` column on `maintenance_records` shows only the current state | `history_id` (PK, IDENTITY), `maintenance_id` (FK), `old_impact_level` (NULL on creation), `new_impact_level` (`CHECK` in `('Advisory','OutOfService')`), `changed_by` (FK → `user_accounts`), `changed_at`, `change_reason` |
| `booking_advisory_acknowledgments` **[Added]** | Records that the requester was shown and acknowledged each active advisory for a specific booking | `ack_id` (PK, IDENTITY), `booking_id` (FK), `maintenance_id` (FK), `acknowledged_by` (FK), `acknowledged_at`; `UNIQUE (booking_id, maintenance_id)` — one ack per advisory per booking |
| `auto_approval_policies` **[Added]** | Defines which space types (or specific spaces) may be auto-approved, and under what conditions | `policy_id` (PK, IDENTITY), `space_type` (`NULL`)/`space_id` (`NULL`) — exactly one set (`CHECK`), `max_participants`, `requires_advisory_ack`, `is_active`, `created_at`, `updated_at` |
| `policy_booking_types` **[Added]** | Junction for the allowed `booking_type` values of a policy (SQL Server has no array type) | Composite PK (`policy_id`, `booking_type`), `CHECK` on `booking_type` matching `CK_bookings_booking_type` |
| `facility_assets` **[Added]** | Individual facility units with serial numbers (the asset-level tracking core) | `asset_id` (PK, IDENTITY), `facility_id` (FK — the catalogue type, e.g. "Projector"), `space_id` (FK — current location), `serial_number` (`UNIQUE`), `asset_status` (`CHECK` in `('Available','InUse','UnderMaintenance','Retired')`), `condition`, `last_checked_date`, `created_at`, `updated_at` |
| `space_facility_requirements` **[Added]** | Marks facility types that must have at least one available unit for the space to be bookable for its normal purpose (**[EXTENSION]**). **Sparse list:** a row exists only for facility types that are required — inserting a row with `is_required = 0` is redundant by design | Composite PK (`space_id`, `facility_id`), `is_required` (`BIT NOT NULL DEFAULT 1` — presence in the table means "required") |
| `booking_alerts` **[Added]** | Persists the escalation result list so it survives after the report runs and staff can mark it handled (**[EXTENSION]**) | `alert_id` (PK, IDENTITY), `maintenance_id` (FK), `booking_id` (FK), `alert_type` (`CHECK` in `('MaintenanceEscalated')`), `created_at`, `acknowledged_by_staff_id`, `acknowledged_at` |

**Audit Trail Robustness — `maintenance_impact_history.changed_by` fallback:** a trigger has no notion of the application user beyond the DB role, so `changed_by` is normally resolved from `SESSION_CONTEXT`. To keep the audit trail complete when the application session never set the context, the trigger must implement a **fallback chain** reading the parent maintenance record: on INSERT use `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), reporter_id)`; on UPDATE use `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), assigned_staff_id, reporter_id)`. `changed_by` must never be written as NULL or as a fabricated value; the fallback must be implemented in the Task 10 trigger.

### 2.2 Modified entities (**[Modified]** — Phase 1 tables extended, never renamed or dropped)

| Table | Change | Rationale |
|---|---|---|
| `maintenance_records` **[Modified]** | **Add** `impact_level` `NVARCHAR(20) NOT NULL` with `CHECK (impact_level IN ('Advisory','OutOfService'))` | The core Phase 2 maintenance change. Required and judgment-set by staff (not derived). Migration backfills existing rows with `DEFAULT 'OutOfService'` (Phase 1's blanket rule == out-of-service) and then drops the default. |
| `maintenance_records` **[Modified]** | **Add** `asset_id` `INT NULL`, FK → `facility_assets(asset_id)` (**[EXTENSION]**) | NULL = space-level record (Phase 1 behavior); non-NULL = scoped to one unit. An asset-scoped record never blocks the space by itself — it only feeds the required-facility check and advisory display. |
| `booking_decisions` **[Modified]** | **Add** `decision_source` `NVARCHAR(10) NOT NULL DEFAULT 'Staff'` with `CHECK` in `('Staff','System')`; **change** `decided_by` from `NOT NULL` to `NULL` with same-table `CHECK ((decision_source = 'System' AND decided_by IS NULL) OR (decision_source = 'Staff' AND decided_by IS NOT NULL))` | Auto-approval decisions are stored in the same decision-record shape as staff decisions, distinguished by `decision_source`. A nullable FK is preferred over a sentinel "SYSTEM" user row, which would pollute `user_accounts` reporting. Existing rows are unaffected (they all have a real staff `decided_by`). |

### 2.3 Attribute refinement: quantity-based → asset-based tracking

- Phase 1 stored equipment as a count (`space_facilities.quantity`, e.g. "2 projectors"). Phase 2 adds `facility_assets` so units are individually identifiable ("Projector #001", "Projector #002"), each with a `serial_number` and its own `asset_status`.
- **`space_facilities.quantity` is retained** as Phase-1-compatible catalogue metadata (used by the room-finder query); it is **not** kept in sync with asset rows.
- Unit counts are **derived, never stored**: a view `space_facility_summary` computes `total_units` / `available_units` per `(space_id, facility_id)` from `facility_assets` with `SUM(CASE WHEN ...)`. Storing a count that must track the asset rows would be a functional-dependency duplication (a 3NF violation).
- This is what makes advisory maintenance meaningful: "one of several AC units is down" becomes a trackable asset state instead of a sentence in a note field.

---

## 3. Relationship Changes

All additions are **new relationships**; none of the 14 Phase 1 FK relationships is altered. `space_facilities`, `usage_sessions`, and the other Phase 1 links remain verbatim. The **Conceptual Notation** column restates each relationship in the Crow's Foot language of the Phase 1 conceptual ERD (Output 02) so the Phase 2 physical extensions can be traced back to the same design vocabulary — every new relationship follows the Phase 1 lifecycle/optionality rule, hence the `0..N` (zero-or-more) on every "many" side.

| New relationship | Cardinality | Conceptual notation (Crow's Foot) | FK / structure | Notes |
|---|---|---|---|---|
| `maintenance_records` → `maintenance_impact_history` | 1 → N | `1 ── 0..N` | `maintenance_impact_history.maintenance_id` | Populated by trigger `TR_maintenance_impact_history` on INSERT/UPDATE of `impact_level` |
| `maintenance_records` → `booking_alerts` | 1 → N | `1 ── 0..N` | `booking_alerts.maintenance_id` | Escalation results; populated by `TR_maintenance_escalation` |
| `bookings` → `booking_alerts` | 1 → N | `1 ── 0..N` | `booking_alerts.booking_id` | Same escalation list |
| `bookings` ↔ `maintenance_records` (via `booking_advisory_acknowledgments`) | M ↔ N resolved | `M ── N`, resolved to two `1 ── 0..N` legs through the associative entity | `ack.booking_id`, `ack.maintenance_id` + `UNIQUE (booking_id, maintenance_id)` | New cross-entity link between bookings and maintenance records; nothing was changed on either side |
| `facilities` → `facility_assets` | 1 → N | `1 ── 0..N` | `facility_assets.facility_id` | Catalogue type → units (**[EXTENSION]**) |
| `spaces` → `facility_assets` | 1 → N | `1 ── 0..N` | `facility_assets.space_id` | Current location of each unit (**[EXTENSION]**) |
| `maintenance_records` → `facility_assets` | 0..1 → 1 (optional) | `0..1 ── 1` (optional FK on the left) | `maintenance_records.asset_id` (NULL = space-level) | Asset-scoped maintenance (**[EXTENSION]**) |
| `spaces` ↔ `facilities` (via `space_facility_requirements`) | M ↔ N | `M ── N`, resolved to two `1 ── 0..N` legs through the associative entity | composite PK (`space_id`, `facility_id`) + `is_required` | In addition to the existing `space_facilities` junction (**[EXTENSION]**) |
| `auto_approval_policies` → `policy_booking_types` | 1 → N | `1 ── 0..N` | `policy_booking_types.policy_id` | Junction for allowed booking types |
| `auto_approval_policies` → `spaces` | 0..1 → 1 (optional) | `0..1 ── 1` (optional FK on the left) | `auto_approval_policies.space_id` | Specific-space override; `space_type` is an enum reference with no FK (Phase 1 enum) |

**Conceptual bridge — Home ID / Visitor ID (Phase 1 convention):** following the Phase 1 conceptual purity rule, every identifier belongs to exactly **one** defining entity (its "Home"), and each new linking column in a dependent table is a "Visitor" copy of that identifier. Mapping the new relationships: `maintenance_id` is Home in `maintenance_records` and Visitor in `maintenance_impact_history` and `booking_alerts`; `booking_id` is Home in `bookings` and Visitor in `booking_alerts` and `booking_advisory_acknowledgments`; `facility_id` is Home in `facilities` and Visitor in `facility_assets` and `space_facility_requirements`; `space_id` is Home in `spaces` and Visitor in `facility_assets`, `space_facility_requirements`, and `auto_approval_policies`. No Home changes place, and the `0..N` readings above match the Phase 1 lifecycle rule (e.g., a newly created policy may have zero booking types yet).

Cardinality-change note: **none** of the existing relationships changes cardinality; the only "shape" change is `booking_decisions.decided_by` becoming optional (the deciding user relationship 1 → 0..1) so that `decision_source = 'System'` decisions can exist without a staff member.

---

## 4. New Business Rules Analysis

### 4.1 Status vs. Impact reconciliation (critical decision)

**Conflict identified:** Phase 1 blocks bookings when `spaces.current_status = 'UnderMaintenance'` (the Phase 1 trigger rejects `Pending`/`Approved` bookings for any space whose `current_status` is `UnderMaintenance`, `TemporarilyClosed`, or `Retired`). Phase 2 allows bookings during **advisory** maintenance — but if the `current_status` flag were still derived from *any* active maintenance record, advisory-affected spaces would be wrongly blocked, and if it were not, out-of-service blocking would silently depend on a flag maintained outside the booking flow.

**Decision:** the system **stops relying on `spaces.current_status` for booking-blocking decisions**. Booking creation and approval logic must query `maintenance_records` directly:

```sql
-- Impact-level check (replaces the status-based maintenance check)
SELECT 1
FROM maintenance_records m
WHERE m.space_id = @space_id
  AND m.status NOT IN ('Completed', 'Cancelled')          -- active record
  AND m.impact_level = 'OutOfService'                     -- blocks only at this level
  AND m.start_time < @new_end
  AND COALESCE(m.completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2)) > @new_start;
```

- Only an active record with `impact_level = 'OutOfService'` overlapping the requested window blocks booking/approval. `Advisory` records never block — they only drive the acknowledgement requirement (Section 4.3).
- `spaces.current_status` is retained **for UI display purposes only** (e.g., showing "Under Maintenance" on the space card); its maintenance-derived value is kept in sync by staff workflows but is **not part of any booking-blocking predicate**. `TemporarilyClosed` and `Retired` remain legitimate non-maintenance blocking states read from `spaces.current_status`.
- The Phase 1 trigger's `current_status` check stays only as a backstop for non-maintenance closures; the primary maintenance block is the impact-level check above, executed inside the concurrency-safe procedures (Section 5.5) on every booking/approval path.

### 4.2 Maintenance impact levels: `Advisory` vs. `OutOfService`

**Out-of-service** (`'OutOfService'`) — the space itself is unusable (electrical repair, floor replacement, AC replacement):
- Blocks booking for **any overlapping time period** — exactly the Phase 1 rule, scoped to this level and enforced via the impact-level check of Section 4.1 (never via `spaces.current_status`).
- A maintenance record is "active" when `status NOT IN ('Completed', 'Cancelled')`. The booking must not be created/approved if the requested window overlaps an active out-of-service period on that space: `start_time < requested_end_time AND COALESCE(completion_time, '9999-12-31') > requested_start_time`.

**Advisory** (`'Advisory'`) — only part of the equipment or comfort is affected (one broken projector, one faulty AC among several):
- Does **not** block booking.
- Requires: the requester is shown every currently active advisory on the space at booking time, and **one acknowledgement is stored per booking per active advisory** (`booking_advisory_acknowledgments`, `UNIQUE (booking_id, maintenance_id)`).
- A booking cannot be finalized as `Approved` (or `CheckedIn`) while an unacknowledged active advisory exists on that space — enforced by trigger `TR_bookings_AdvisoryAckRequired`, which compares `COUNT(DISTINCT active advisory)` vs. `COUNT(DISTINCT acknowledged)` for the booking.
- Because SQL Server has no deferred triggers, the equivalent of a "commit-time" check is achieved with a documented **statement order inside the transaction**: insert booking as `Pending` → insert acknowledgement rows → update status to `Approved`. The trigger fires on the status-change statement, at which point the acknowledgements are already visible in the same transaction.

**Multiple concurrent records:** a space may have zero, one, or many active maintenance records at independent impact levels simultaneously. The rules above compose: any active `OutOfService` overlap blocks; every active `Advisory` overlapping the window must be acknowledged. Implementation is query-based (no special storage).

### 4.3 Escalation / downgrade policy

- `impact_level` may change while the record is open (advisory → out-of-service, or back). Every change is recorded in `maintenance_impact_history` by trigger `TR_maintenance_impact_history` (INSERT records the initial level with `old_impact_level = NULL`; UPDATE records only when the value actually changed; `changed_by` comes from `sp_set_session_context` with a **fallback chain** — `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), assigned_staff_id, reporter_id)` on UPDATE, `reporter_id` on INSERT — so the audit row never carries a NULL or fabricated actor, per Section 2.1).
- **Escalation consequence:** when a record is escalated to `OutOfService`, the system must make every **already-`Approved`/`CheckedIn` booking** that overlaps the maintenance period **identifiable to staff** — trigger `TR_maintenance_escalation` inserts one `booking_alerts` row (`alert_type = 'MaintenanceEscalated'`) per affected booking. This is a **lookup/report** (report (d) of §1.3), not an automatic notification: contacting requesters remains a manual staff action (email/SMS delivery is out of scope, consistent with Phase 1 §17).
- Open question carried forward: who may downgrade `OutOfService` → `Advisory`, and whether downgrade automatically re-opens the space for booking (see Section 7).

### 4.4 Early check-out: Reserved vs. Actual occupancy time

Phase 1 already stores both `bookings.requested_start_time/requested_end_time` (reserved) and `usage_sessions.actual_start_time/actual_end_time` (actual). **No new column** is added; Phase 2 changes **which interval the conflict-check/availability queries use, driven by booking status**:

| Status | Blocks new bookings? | Interval used |
|---|---|---|
| `Pending` | No | — |
| `Approved` | Yes | `[requested_start_time, requested_end_time)` |
| `CheckedIn` | Yes | `[requested_start_time, requested_end_time)` — upper bound stays the reserved end; an early end is not known until it happens |
| `Completed` | **No** | Historical only: `[actual_start_time, actual_end_time)` |
| `Cancelled` / `Rejected` / `NoShow` | No | — |

- **Immediate release on early check-out:** the moment check-out records `actual_end_time` and the booking becomes `Completed`, the row drops out of the `IN ('Approved','CheckedIn')` filter that every conflict check must use — the remaining reserved window becomes bookable **immediately**, with no trigger, timer, or stored flag. `is_early_checkout` is a derived fact (`actual_end_time < requested_end_time`) computed at query time (3NF: never store a fact that summarizes two stored timestamps).
- Overlap predicate (SQL Server has no range type): `s1 < e2 AND e1 > s2` on half-open intervals.
- For utilization reporting, use the actual interval where a session exists, falling back to the reserved interval for approved-but-never-checked-in bookings (`COALESCE(us.actual_start_time, b.requested_start_time)` / `COALESCE(us.actual_end_time, b.requested_end_time)`).
- Business rule: a user who checks out early has **no claim** on the remaining reserved time; they must submit a new request.

### 4.5 Auto-approval (instant booking)

- Eligibility is configured per **space type** (or a specific-space override) in `auto_approval_policies` + `policy_booking_types`.
- At submission, the instant path checks the policy: allowed `booking_type`, `expected_participants <= min(space capacity, max_participants)`, no overlapping `Approved`/`CheckedIn` booking, no active `OutOfService` overlap, and all active advisories acknowledged.
- If all conditions hold, the booking is approved immediately and a `booking_decisions` row records the decision with `decision_source = 'System'` and `decided_by = NULL` (enforced by the same-table CHECK).
- If the request does not satisfy the policy, it falls through to the unchanged Phase 1 manual workflow.
- Open question (product decision): if two instant requests race for the same slot, the loser may be auto-rejected or re-queued as `Pending` — not stated in either PDF (see Section 7).

### 4.6 Asset-level booking block (**[EXTENSION]**, team-proposed)

- If a facility type marked `is_required = 1` in `space_facility_requirements` for a space has **zero available units** (`facility_assets.asset_status = 'Available'` for that space + facility), a booking must be blocked **even without a space-level out-of-service record** — trigger `TR_bookings_RequiredAssetCheck` enforces this when a booking is placed into `Approved`/`CheckedIn`.
- This is how "maintenance on the last remaining unit of a required facility" closes the space without needing `spaces.current_status = 'UnderMaintenance'`.
- Impact level remains a Facility Manager judgment call — the system surfaces available-unit counts (`space_facility_summary`) to help, but never derives `impact_level` automatically.

---

## 5. Concurrency & Race Condition Analysis (Critical)

### 5.1 Why the Phase 1 trigger is not the concurrency mechanism

**Academic framing — a check-then-act / lost-update race.** The failure analyzed below is the textbook **check-then-act race** (also classified as a **lost-update** anomaly in the concurrency literature): two transactions each *check* the availability predicate (Section 5.4), both observe the identical conflict-free state, and both proceed to *act* (insert/approve) on the basis of that stale observation. Because the check and the act are separated in time and the second writer never sees the first writer's uncommitted row, the second write silently loses the guarantee the first write established — the classic time-of-check-to-time-of-use (TOCTOU) hazard. Validation (the trigger) cannot repair this; only serialization can. This is precisely why Section 5.5 replaces the *check-then-act* sequence with a serialized check-and-act under `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK`.

`TR_bookings_PreventOverlapAndUnavailable` is a per-statement `AFTER` trigger: it only sees rows **visible at statement time**. Two concurrent transactions (Session A, Session B) can interleave as follows:

1. A and B both run the conflict check (`SELECT ... WHERE space_id = @s AND status IN ('Approved','CheckedIn') AND ... overlap ...`); neither sees the other's not-yet-committed row.
2. A inserts its booking; the trigger fires, sees no committed overlap, and commits.
3. B inserts its booking; the trigger fires, **still sees no conflict** (A's row was committed after B's check, but the trigger predicate evaluates against committed data visible to B — and by the time B's trigger runs, the interleaving can still pass if B's statement-level snapshot does not include A's commit), then commits.

Result: two overlapping approved bookings — the invariant is violated. The trigger **validates; it does not serialize**. Phase 2 therefore adds an explicit serialization layer.

### 5.2 Race scenario A: "Double approval"

Two staff members simultaneously approve two **different** `Pending` bookings for the same space and overlapping window. Step-by-step interleaving under the default `READ COMMITTED` isolation:

1. T1 (Staff 1) opens the approval transaction for booking X; T2 (Staff 2) opens the approval transaction for booking Y — same `space_id`, overlapping requested window.
2. T1 runs the conflict check for X: reads `bookings` and sees only committed rows; Y is still `Pending` (uncommitted or not yet updated), so no conflict is found.
3. T2 runs the conflict check for Y: likewise sees no conflict — X is not yet `Approved`/committed.
4. T1 updates X to `Approved` and commits; its `AFTER` trigger fires and sees no committed overlap at its statement time.
5. T2 updates Y to `Approved` and commits; its trigger's statement snapshot does not include X's commit, so it also passes.

Result: two overlapping `Approved` bookings for the same slot — the invariant is violated. **Mitigation requirement:** both approval transactions must run the conflict check under `SERIALIZABLE` isolation with `WITH (UPDLOCK, HOLDLOCK)` hints (or serialize per space with `sp_getapplock`). T2's conflict check then **blocks on T1's key-range lock** until T1 commits, re-reads under `SERIALIZABLE`, sees X as `Approved`, and fails cleanly instead of both succeeding.

### 5.3 Race scenario B: "Manual vs. auto" (and instant vs. instant)

A staff member manually approves request X while the system auto-approves request Y for the same slot (or two instant requests race). Interleaving:

1. The instant path reads `auto_approval_policies` and availability for Y; the manual path runs its availability check for X — both see an empty `Approved`/`CheckedIn` set for the window.
2. Both pass their checks and write: X becomes `Approved` with a `booking_decisions` row (`decision_source = 'Staff'`); Y becomes `Approved` with a decision row (`decision_source = 'System'`, `decided_by = NULL`).
3. Both commit; each trigger sees no committed overlap at its own statement time.

Result: the same overlap as 5.2, now produced by two different paths. The invariant is explicitly path-independent, so **both paths must share the same concurrency-safe conflict check** — the shared procedure pattern of Section 5.5 with `SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)` (or `sp_getapplock`) is **mandatory for the instant-booking path and the manual-approval path alike**, and the multi-statement instant flow (read policy → insert booking → insert acknowledgements → update status to `Approved`) must be wrapped in a single `SERIALIZABLE` transaction.

### 5.4 Conflict determination

Both paths must run the same conflict predicate against the same blocking statuses:

```sql
SELECT 1
FROM bookings b WITH (UPDLOCK, HOLDLOCK)
WHERE b.space_id = @space_id
  AND b.status IN ('Approved', 'CheckedIn')
  AND b.requested_start_time < @new_end
  AND b.requested_end_time   > @new_start;
```

### 5.5 Proposed prevention logic (Microsoft SQL Server mechanisms)

**Requirement (mandatory, not optional):** every booking-creation and approval path must use `SERIALIZABLE` isolation with `WITH (UPDLOCK, HOLDLOCK)` hints on the conflict check, or serialize per space with `sp_getapplock` — this is what closes race scenarios 5.2 and 5.3.

**Primary defense — stored procedure with `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK` range locking.** The conflict check runs as a `SELECT` taking update locks (`UPDLOCK`) on every matching row and, under `SERIALIZABLE`, key-range locks (`HOLDLOCK`) covering the predicate range *including the gap* where a new conflicting row would land. Locks are held until `COMMIT`, making check-then-insert atomic per space/window:

- A concurrent booking attempt on the same space **waits at its own conflict check** instead of slipping past it; when the first transaction commits, the second re-reads under `SERIALIZABLE`, sees the now-committed conflict, and fails cleanly.
- If the interleaving creates a lock cycle, SQL Server picks a deadlock victim (**error 1205**) or raises a lock timeout (**1222**) — the application retries with a bounded retry count/backoff; a retry that then hits the overlap error means the slot was genuinely taken.
- Requests for different spaces, or disjoint windows on the same space, take disjoint locks — concurrency is sacrificed only where the invariant requires it.
- Granular key-range locking needs an index matching the predicate — the filtered index `IX_bookings_space_status_time` on `(space_id, requested_start_time, requested_end_time) WHERE status IN ('Approved','CheckedIn')`; without it SQL Server may escalate to a table lock (still correct, less concurrent).
- **Application discipline replaces the exclusion constraint:** every code path that creates or approves bookings (instant-booking procedure, manual-approval procedure, any future API) must run this hinted conflict check inside a serializable transaction.

**Alternative — per-space application lock (`sp_getapplock`).** `EXEC sp_getapplock @Resource = CONCAT('booking_space_', @space_id), @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;` guarantees at most one transaction inside the check-then-insert sequence per space. Simpler mental model; tradeoff: it serializes *all* bookings on a space (including non-conflicting windows) and every code path must remember to take the lock (application-defined, not schema-enforced). Can be combined with the primary defense as belt-and-braces.

**Defense in depth.** `TR_bookings_PreventOverlapAndUnavailable` stays as a backstop for any path that bypasses the stored procedures.

**Multi-statement flows.** The surrounding logic (read `auto_approval_policies`, decide, insert booking, insert acknowledgement rows) is a read-then-write sequence with its own race potential; it is wrapped in a `SERIALIZABLE` transaction. Where PostgreSQL signals serialization failure (40001), SQL Server raises deadlock 1205 / lock timeout 1222 → application retry.

**Where the trigger-based rules (§4.2–§4.6) fit:** they enforce business rules at statement level; the concurrency procedures ensure the invariant holds under simultaneity. Both layers coexist: procedures prevent the race, triggers catch any rule violation on the committed state.

---

## 6. Phase 2 Traceability Matrix

Links every Phase 2 requirement from `req/business-requirement-P2.md` (tags: **[CONFIRMED]** = stated in the Phase 2 PDF, **[EXTENSION]** = team-proposed) to its database component(s).

| # | Phase 2 requirement | Tag | Database component / rule |
|---|---|---|---|
| 1 | Maintenance records carry an impact level (`Advisory` / `OutOfService`) | [CONFIRMED] | `maintenance_records.impact_level` `NOT NULL` + `CK` whitelist (PascalCase values) |
| 2 | **Blocking rule:** `OutOfService` blocks booking for any overlapping period (Phase 1 rule scoped to this level) | [CONFIRMED] | **Impact-level check** (Section 4.1): query `maintenance_records` directly for active (`status NOT IN ('Completed','Cancelled')`) records with `impact_level = 'OutOfService'` overlapping the requested window (`start_time < end AND COALESCE(completion_time,'9999-12-31') > start`) — replaces the Phase 1 `current_status`-based maintenance check; the Phase 1 trigger stays as backstop for non-maintenance closures only |
| 3 | `Advisory` does not block; every active advisory acknowledged per booking before approval | [CONFIRMED] | `booking_advisory_acknowledgments` + `UNIQUE (booking_id, maintenance_id)` + trigger `TR_bookings_AdvisoryAckRequired` + mandatory statement order (Pending → acks → Approved) |
| 4 | A space may have several active maintenance records at different impact levels simultaneously | [CONFIRMED] | No new storage; query-based composition of rules 2–3 (active = `status NOT IN ('Completed','Cancelled')`) |
| 5 | Impact level may be escalated/downgraded while open | [CONFIRMED] | `maintenance_impact_history` + trigger `TR_maintenance_impact_history`; `changed_by` fallback chain — `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), assigned_staff_id, reporter_id)` on UPDATE, `reporter_id` on INSERT (never NULL/fabricated) |
| 6 | Escalation to `OutOfService` makes overlapping `Approved`/`CheckedIn` bookings identifiable to staff (escalation lookup) | [CONFIRMED] | `booking_alerts` + trigger `TR_maintenance_escalation` (`alert_type = 'MaintenanceEscalated'`); report (d) §1.3 → Task 16; manual requester contact (out of scope) |
| 7 | Selected space types may auto-approve eligible requests at submission time | [CONFIRMED] | `auto_approval_policies` + `policy_booking_types`; instant-booking procedure evaluates policy inside `SERIALIZABLE` transaction |
| 8 | Auto-approval decision stored in the same decision-record shape as a staff decision, distinguished by `decision_source` | [CONFIRMED] | `booking_decisions.decision_source` (`'Staff'`/`'System'`) + `decided_by` nullable + same-table `CK` pairing source with null-ness |
| 9 | Core invariant: no two `Approved`/`CheckedIn` bookings overlap on the same space, under concurrency, both paths | [CONFIRMED] | `usp_CreateBooking` (and every approval path): `SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)` conflict check; filtered index `IX_bookings_space_status_time` for key-range locking; retry on 1205/1222; `sp_getapplock` alternative; Phase 1 trigger as backstop |
| 10 | Reserved vs. actual occupancy: conflict checks use the reserved interval for `Approved`/`CheckedIn`; `Completed` blocks nothing | [EXTENSION] | Status-driven interval selection (Section 4.4); no new columns; overlap predicate `s1 < e2 AND e1 > s2` |
| 11 | Early check-out immediately releases the remaining reserved window; no claim for the early user | [EXTENSION] | Derived fact: booking `Completed` ⇒ drops out of blocking filter; `is_early_checkout` computed (`actual_end_time < requested_end_time`), never stored (3NF) |
| 12 | Facilities tracked as individual units with serial numbers instead of quantity counts | [EXTENSION] | `facility_assets` (`asset_id`, `serial_number` `UNIQUE`, `asset_status`); `space_facilities.quantity` kept as catalogue metadata; counts derived via view `space_facility_summary` |
| 13 | Maintenance may target a specific asset rather than only the space | [EXTENSION] | `maintenance_records.asset_id` nullable FK → `facility_assets`; asset-scoped records never block the space by themselves |
| 14 | Booking blocked when a facility marked `required` for the space has no available unit, even without a space-level `OutOfService` record | [EXTENSION] | `space_facility_requirements.is_required` (`BIT NOT NULL DEFAULT 1`, sparse list — presence = required) + trigger `TR_bookings_RequiredAssetCheck` (blocks `Approved`/`CheckedIn` when zero `'Available'` units) |
| 15 | Report: total approved booking hours per space for a semester | [CONFIRMED] | Task 16 analytical query: `bookings` (status `Approved`/`Completed`/`CheckedIn`) + `usage_sessions` with `COALESCE` interval fallback + `DATEDIFF(MINUTE, ...)/60.0` |
| 16 | Report: number of approved bookings by weekday and hour for a semester | [CONFIRMED] | Task 16 analytical query (`DATEPART(WEEKDAY)`/`DATEPART(HOUR)` grouping on `requested_start_time`) |
| 17 | Report: room finder — available spaces for required capacity + facility list within a time window | [CONFIRMED] | Task 16 query: `spaces` (capacity) + `space_facilities`/`facility_assets` availability + the **impact-level check** of Section 4.1 for maintenance blocking (`current_status` used only for `TemporarilyClosed`/`Retired`); tuned with composite indexes in Task 15 |
| 18 | Report: approved bookings affected by escalation to out-of-service | [CONFIRMED] | Task 16 query over `booking_alerts` / overlap predicate on escalated records |
| 19 | SQL Server only — no PostgreSQL constructs anywhere in Phase 2 | [CONFIRMED] | All Tasks 08–16 use SQL Server syntax: `IDENTITY`, `DATETIME2`, `NVARCHAR`, `BIT`, `GETDATE()`, `WITH (UPDLOCK, HOLDLOCK)`, `sp_getapplock`, `SESSION_CONTEXT`, `GO` batches; no `tsrange`/GiST/`DEFERRABLE`/`'infinity'`/`SET LOCAL` |
| 20 | Migration preserves Phase 1 data and documents the approach | [CONFIRMED] | Task 10: additive DDL only (no renames/drops); FK targets created first; `impact_level` backfilled via `DEFAULT 'OutOfService'` then default dropped; `decision_source` `DEFAULT 'Staff'`; overlap pre-check before deploying procedure/index |
| 21 | Status vs. Impact reconciliation: maintenance blocking derives from `maintenance_records`, not from `spaces.current_status` | [CONFIRMED] (architectural decision, Section 4.1) | Impact-level check on `maintenance_records` (`impact_level = 'OutOfService'` + active + overlap) used by every booking/approval path and the room finder; `spaces.current_status` maintenance values are **UI display only**; the Phase 1 trigger's `current_status` check remains only for `TemporarilyClosed`/`Retired` backstop |

---

## 7. Assumptions and Open Questions (Phase 2)

**Assumptions carried forward** from Phase 1 (`business-requirement.md` §15) still hold: recurring bookings out of scope, capacity stored but not necessarily enforced, single-space bookings, etc.

**New assumptions:**

- Auto-approval eligibility is configured per space type (not per individual space), unless a specific-space override is needed — to be confirmed with the Facility Manager persona/TA.
- "Requester was informed" for an advisory is satisfied by the in-system acknowledgement at booking time; it implies no external notification channel.
- An auto-approval decision uses the same decision-record shape as a staff decision (§4.5).

**New open questions (to resolve before/during Task 09–10):**

1. **Losing request handling:** if two instant-booking requests race for the same slot, should the loser be auto-rejected, or automatically re-queued as `Pending` for manual review? (Product decision; not stated in either PDF.)
2. **"Required" facility definition:** what exactly makes a facility `required` for a space (§4.6)? Team-invented concept — needs confirmation before treated as gradeable scope.
3. **No-show auto-release:** the proposal to auto-mark `NoShow` after 15 minutes and release the space is **unconfirmed**; Phase 1 left "who may cancel, and until when" open, and the 15-minute figure needs the same confirmation.
4. **Downgrade authority:** who may downgrade `OutOfService` → `Advisory`, and does downgrade automatically re-open the space, or must staff update `spaces.current_status` separately?
5. **Booking Approval vs. Maintenance Escalation Race:** a race condition exists where Staff A is approving a booking while Staff B is simultaneously escalating a maintenance record (`Advisory` → `OutOfService`) for the same space and time window. If the booking approval's `OutOfService` check (Section 4.1) completes just before the escalation is committed, the booking may be approved; conversely, if the escalation trigger (`TR_maintenance_escalation`) runs before the booking is committed, it misses the new booking, leaving it out of the `booking_alerts` list. **Potential mitigation:** to fully close this gap, the concurrency-safe primitives defined in Section 5 (`SERIALIZABLE` range locks, or `sp_getapplock` on the space resource) should be shared across both the booking approval procedures and the maintenance escalation workflow, so that an escalation and an approval on the same space cannot interleave. **Current status:** recorded as a Known Limitation to be addressed during the detailed implementation of Tasks 11 and 12.

---

## 8. Quality Checklist

- [x] **Transition to MS SQL Server syntax explicitly mentioned** — Section 1.4 (§19 of the traceability matrix).
- [x] **Early Return case (Reserved vs. Actual time) addressed** — Section 4.4 (status-driven interval table, immediate release, derived `is_early_checkout`, §10–11 of the matrix).
- [x] **Out-of-service maintenance overlaps clearly identified as blocking** — Section 4.2 + impact-level check in Section 4.1 (active `OutOfService` overlap predicate), traceability rows 2, 4, 21.
- [x] **Escalation consequence (identifying affected bookings) detailed** — Section 4.3 (`booking_alerts` + `TR_maintenance_escalation`, report (d)), traceability rows 5–6.
- [x] **Concurrency race scenarios and SQL Server prevention logic** — Section 5 (double-approval and manual-vs-auto races with interleavings; `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK`; `sp_getapplock`; filtered index; 1205/1222 retry; trigger as backstop).
- [x] **Quantity → asset transition analyzed** — Section 2.3 (`facility_assets`, `space_facility_summary` view, catalogue metadata vs. derived counts).
- [x] **Status vs. Impact reconciliation decided** — Section 4.1 (blocking queries `maintenance_records` for `OutOfService`; `spaces.current_status` display-only), traceability rows 2 and 21.
- [x] **`maintenance_impact_history.changed_by` fallback defined** — Sections 2.1 and 4.3 (`COALESCE(SESSION_CONTEXT, assigned_staff_id, reporter_id)`; INSERT → `reporter_id`), traceability row 5.
- [x] **`space_facility_requirements` sparse-list convention stated** — Section 2.1 (`is_required BIT NOT NULL DEFAULT 1`, presence = required), traceability row 14.
- [x] **3NF validation for the extended schema deferred to Task 09** — Section 1.5, with a worked 1NF/2NF/3NF mini-validation of `booking_advisory_acknowledgments`.
- [x] **Traceability matrix links the Blocking Rule to the Impact-level check** — rows 2, 17, 21 (no row references the old status-based maintenance check as the blocking mechanism).
- [x] **Academic terminology for the race condition** — Section 5.1 names the failure as a check-then-act / lost-update race (TOCTOU), tying it to the `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK` remedy in Section 5.5.
- [x] **Visual entity labeling** — Section 2: 7 tables labeled **[Added]**, 2 labeled **[Modified]** for reviewer-scope clarity.
- [x] **Conceptual relationship bridge** — Section 3: Crow's Foot notation column (`1 ── 0..N`, `M ── N`, `0..1 ── 1`) plus the Home ID / Visitor ID mapping consistent with the Phase 1 ERD.
- [x] **Scope boundary and downstream impact stated** — Section 1.6: Output 08 modifies no Phase 1 deliverable; impacts on Outputs 04–07 mapped to Tasks 09/10/14/16.
