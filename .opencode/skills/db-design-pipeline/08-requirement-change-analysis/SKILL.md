---
name: 08-requirement-change-analysis
description: Analyze how Phase 2 requirements extend and impact the Phase 1 database system, focusing on maintenance levels, concurrency, and asset tracking.
compatibility: opencode
---

# Step 08: Requirement Change Analysis Skill

This skill guides the agent to perform a deep-dive analysis of Phase 2 extensions. The output must be saved to `outputs/08-requirement-change-analysis-G08.md`.

This analysis is the authoritative reconciliation between the Phase 1 baseline (outputs 01–07) and the Phase 2 logic. Every design conflict must be resolved explicitly in the output; do not leave decisions implicit. Items marked **(mandatory)** are architectural requirements, not suggestions.

## Analysis Requirements

### 1. Change Impact Overview
- Summarize the high-level goals of Phase 2.
- Identify which parts of Phase 1 remain unchanged and which parts require modification.
- **Status vs. Impact Logic Reconciliation (mandatory):** analyze the conflict between the Phase 1 rule (active maintenance ⇒ `spaces.current_status = 'UnderMaintenance'` ⇒ space blocked) and the Phase 2 impact levels. Decide and document: **booking-blocking logic must now query `maintenance_records` directly** — only active records (`status NOT IN ('Completed','Cancelled')`) with `impact_level = 'OutOfService'` block bookings via the overlap rule; `Advisory` records never block. Consequently `spaces.current_status` loses its maintenance-blocking role for booking decisions: its maintenance-derived value becomes **purely for UI/display** (e.g., showing "Under Maintenance" on the space card). `TemporarilyClosed` and `Retired` remain meaningful via `spaces.current_status` for non-maintenance closures. Note in the output that the Phase 1 trigger's `current_status IN ('UnderMaintenance', …)` check stays only as a backstop for closures that are not maintenance-driven.
- **3NF scope (mandatory):** explicitly state that Normalization Validation (3NF) for the **extended Phase 2 schema** is **deferred to Task 09 (Logical Design Update)**. Output 08 must not perform a full 3NF audit of the new tables; it only flags derivability constraints (e.g., unit counts must never be stored — they summarize `facility_assets` rows and must be derived via a view).

### 2. Affected Entities and Attributes
- **New Entities:** Identify and justify new entities (e.g., `facility_assets`, `booking_advisory_acknowledgments`, `auto_approval_policies`).
- **Modified Entities:** List Phase 1 entities that need new columns (e.g., `maintenance_records` adding `impact_level`, `booking_decisions` becoming nullable).
- **Attribute Refinement:** Analyze the shift from "quantity-based" to "asset-based" tracking.
- **Audit Trail Robustness (mandatory):** for `maintenance_impact_history.changed_by`, define a **fallback chain** for when `SESSION_CONTEXT` is not set by the application:
  - INSERT: `changed_by = COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), reporter_id)` — the reporter created the record.
  - UPDATE: `changed_by = COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), assigned_staff_id, reporter_id)` — fall back to the assigned staff member, then to the reporter.
  - Document this fallback in the output so Task 10 (schema migration) implements the trigger accordingly; never allow `changed_by` to be NULL or fabricated.
- **Asset Requirement Defaults (mandatory):** treat `space_facility_requirements` as a **sparse list**: a row exists only for facility types that MUST have at least one available unit for the space to be bookable for its normal purpose. Therefore set `is_required` to `DEFAULT 1` (`BIT NOT NULL DEFAULT 1`); **presence in the table means "required"**. A space with no rows has no critical-asset concept (Phase 1 behavior preserved). State this convention explicitly in the output.

### 3. Relationship Changes
- Describe new relationships between Phase 1 and Phase 2 entities.
- Identify any changes in cardinality (e.g., `bookings` to `maintenance_records` via acknowledgments).

### 4. New Business Rules Analysis
- Formulate precise logic for the two maintenance impact levels (`advisory` vs `out-of-service`):
  - `OutOfService` blocks: no booking may overlap `[start_time, COALESCE(completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2)))` for an active record.
  - `Advisory` never blocks; it only triggers the acknowledgement requirement.
- Define the "Escalation Policy" and its impact on existing approved bookings (the affected-bookings lookup via `booking_alerts`).
- Define the "Early Check-out" logic and how it releases slots (status-driven interval: `Approved`/`CheckedIn` block with the reserved interval; `Completed` releases immediately; `is_early_checkout` is derived, never stored).
- **Status vs. Impact implications (mandatory):** confirm that the advisory-aware booking flow (showing advisories at booking time) and the escalation lookup query `maintenance_records` directly, never `spaces.current_status`; document that maintenance-driven values of `current_status` are kept in sync for display only.
- **Acknowledgement enforcement (mandatory):** document the SQL Server statement order required by the advisory-acknowledgement trigger — insert the booking as `Pending` → insert `booking_advisory_acknowledgments` rows → update status to `Approved`, all inside one transaction. SQL Server has no deferred constraint triggers, so this ordering is the only workable pattern; every booking path (manual, instant, migration) must follow it.

### 5. Concurrency & Race Condition Analysis (Critical)
- **Identify Scenarios:** Describe concrete MS SQL Server race conditions, at minimum:
  1. **Double Manual Approval:** two staff members approve two different `Pending` bookings for the same space and overlapping window at the same instant.
  2. **Instant vs. Manual:** an auto-approval submission races a manual approval of another request for the same slot.
  3. **Instant vs. Instant:** two auto-approval submissions race for the same slot.
  4. If applicable, check-in / early check-out racing with a new booking on the released window.
  For each scenario, show the interleaving that lets both transactions pass the availability check, and state which invariant is violated.
- **Conflict Determination:** Explain how simultaneous operations might check availability and lead to overlapping approved bookings.
- **Proposed Prevention Logic:** Briefly analyze how MS SQL Server transactions or locking will mitigate these — e.g., `SERIALIZABLE` isolation with `WITH (UPDLOCK, HOLDLOCK)` key-range locking in the conflict check (supported by the filtered index `IX_bookings_space_status_time`), or `sp_getapplock` per space; application retry on deadlock (1205) / lock timeout (1222); the Phase 1 trigger remains a backstop only.

### 6. Phase 2 Traceability Matrix
- Create a table linking every Phase 2 requirement (from `business-requirement-P2.md`) to specific database components or rules.
- **Granular logic mapping (mandatory):** the "database component" column must resolve to granular artifacts, not just entity names — e.g., the `OutOfService` overlap predicate (columns + statuses involved), the advisory-ack trigger and its statement order, the escalation trigger + `booking_alerts`, the concurrency procedure + filtered index, the `space_facility_summary` view, the `is_required` sparse-list convention, and the `changed_by` fallback chain. Every requirement row must map to at least one such artifact.

## Quality Checklist
- [ ] Does the analysis explicitly mention the transition to MS SQL Server syntax?
- [ ] Is the "Early Return" case (Reserved vs Actual time) addressed?
- [ ] Are "Out-of-service" maintenance overlaps clearly identified as blocking?
- [ ] Is the escalation consequence (identifying affected bookings) detailed?
- [ ] Is the Status vs. Impact reconciliation decided: blocking queries `maintenance_records` for `OutOfService` overlap; `spaces.current_status` is display-only for maintenance?
- [ ] Is the `maintenance_impact_history.changed_by` fallback chain (`SESSION_CONTEXT` → `assigned_staff_id` → `reporter_id`) defined and documented for Task 10?
- [ ] Is the `space_facility_requirements` sparse-list convention with `is_required` `DEFAULT 1` stated?
- [ ] Are the concrete SQL Server race scenarios enumerated (double manual approval; instant vs. manual; instant vs. instant)?
- [ ] Is 3NF validation for the extended schema explicitly deferred to Task 09 (Logical Design Update)?
- [ ] Does the traceability matrix map every Phase 2 requirement to granular logic components?
