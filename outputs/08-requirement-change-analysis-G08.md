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

- **7 of the 9 Phase 1 tables are retained; 3 of them carry the column-level changes listed below, and 4 are untouched.** Two tables are **dropped** under documented, explicitly authorized Phase 2 baseline amendments: `facilities` (`AGENTS.md` §1a) and `space_facilities` (`AGENTS.md` §1b, Section 2.3c). Both drops remove a **stored-derivable fact** rather than fix a normal-form violation on the table itself — `facilities` was already in BCNF (Section 2.3b) and `space_facilities`'s key pair `(space_id, facility_name)` is exactly the distinct projection of `facility_assets` (Section 2.3c) — so both are recorded as deliberate denormalizations/redundancy removals, not 3NF requirements. These are the only two exceptions to the otherwise-inviolable "no drops of Phase 1 tables" rule. Of the 7 retained tables, **3 are modified**: (1) **`space_facilities.quantity` was removed** before the table itself was later dropped — a genuine **3NF** fix at the time, since unit counts must be derived from `facility_assets` via `COUNT(*)`, never stored (Section 2.3a; moot now that the table is gone, but recorded for the historical record in Appendix A); (2) **`maintenance_records`** gains `impact_level` and a nullable `asset_id`, with `space_id` staying `NOT NULL` — see Section 2.4 for why no XOR-driven nullability change is needed; (3) **`user_accounts.role` is dropped** and replaced by a `user_roles(user_id, role)` junction table (`AGENTS.md` §1c, Section 2.2) — a cardinality correction, not a normalization fix, since one person may hold several roles; (4) **`booking_decisions`** gains `decision_source` and a relaxed `decided_by`. The 4 untouched Phase 1 tables are `departments`, `spaces`, `bookings`, and `usage_sessions`. All other Phase 1 columns, all status enum values (`Pending`…`NoShow`; `Available`…`Retired`; `Reported`…`Cancelled`), and all existing data are preserved verbatim.
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
| Facility catalogue | Separate `facilities` table (`facility_id` PK, `facility_name` UNIQUE, `description`) | `facilities` **dropped** (documented amendment, `AGENTS.md` §1a); `facility_name` briefly lived on `space_facilities`, which is itself now **dropped** (`AGENTS.md` §1b, Section 2.3c) — `facility_name` is `CHECK`-constrained independently on `facility_assets` and `space_facility_requirements` |
| Facility tracking | `space_facilities.quantity` (a count) | `quantity` **eliminated** (3NF, while the table still existed); individual units live in `facility_assets`, linked directly to `spaces` (`FK_facility_assets_space_id`) with `facility_name` as an independent `CHECK`-constrained column; counts derived via `COUNT(*)` on `facility_assets` |
| Facility catalogue table | `space_facilities` held `(space_id, facility_name)` as a distinct catalogue | `space_facilities` **dropped** (Section 2.3c) — its key pair was a stored projection of `facility_assets`; `v_space_facility_summary` now unions `facility_assets` and `space_facility_requirements` to keep zero-unit-but-required rows visible |
| User roles | `user_accounts.role` — single-valued | `role` **dropped**; replaced by `user_roles(user_id, role)` junction — one user may hold several roles (documented amendment, `AGENTS.md` §1c; cardinality correction, not normalization) |
| Maintenance target | Space only (`space_id NOT NULL`) | `space_id` **stays `NOT NULL`** — an immutable historical snapshot of the affected space, present on every record; optional `asset_id` narrows an equipment-level issue to one unit (not mutually exclusive with `space_id` — Section 2.4) |
| Booking interval logic | Reserved window used everywhere | Status-driven: `Approved`/`CheckedIn` block with reserved interval; `Completed` releases immediately (actual occupancy) |
| Escalation handling | Not modeled | `maintenance_impact_history` audit trail + `booking_alerts` affected-bookings list |
| Reporting | Phase 1 history views | + 4 analytical reports (§1.3) with indexing/tuning |

### 1.4 DBMS transition note (explicit)

Phase 1 already targets **Microsoft SQL Server**; Phase 2 adds schema/triggers/procedures **in SQL Server syntax only** and deliberately avoids PostgreSQL constructs: no `tsrange`, no `EXCLUDE USING gist`/`btree_gist` (replaced by the serializable range-lock pattern of Section 5), no deferred/`DEFERRABLE` constraint triggers (replaced by `AFTER` triggers + documented statement order), no `GIN`/array indexes (SQL Server has no array type — `policy_booking_types` junction table instead), no `'infinity'` timestamps (`COALESCE(completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2))` instead), no `SET LOCAL` (`sp_set_session_context` / `SESSION_CONTEXT` instead, SQL Server 2016+).

### 1.5 Normalization scope (3NF)

A full Normalization Validation (3NF) of the **extended Phase 2 schema** (the new tables in Section 2.1 and the modified columns in Section 2.2) will be **formally performed in Task 09 (Logical Design Update)**, where functional dependencies and candidate keys of the extended relations are audited relation by relation. Output 08 deliberately limits itself to flagging derivability constraints that shape the design now — most notably that unit counts must never be stored because they summarize `facility_assets` rows (Section 2.3a), that `is_early_checkout` must remain a derived fact (Section 4.4), and that `maintenance_records.space_id` is an **independent historical fact**, not a derived one: since assets are permitted to relocate between spaces, the functional dependency `asset_id → space_id` does not hold (refuted by a relocation counterexample, Section 2.4), so no transitive dependency exists to eliminate and no XOR constraint is needed — while the full 3NF verification of the extended schema is Task 09's scope.

**Mini-Validation (worked example) — `booking_advisory_acknowledgments`:** as a spot-probe of the most complex new relation (a composite-key associative entity), its compliance is demonstrated here; the exhaustive relation-by-relation audit remains Task 09's scope:

- **1NF — atomic attributes:** every column (`ack_id`, `booking_id`, `maintenance_id`, `acknowledged_by`, `acknowledged_at`) is single-valued and scalar; there are no repeating groups — one row per (booking, advisory) pair, enforced by `UNIQUE (booking_id, maintenance_id)`.
- **2NF — full functional dependency on the composite key:** the natural candidate key is the composite `(booking_id, maintenance_id)`. The non-key attributes (`acknowledged_by`, `acknowledged_at`) depend on the **whole** pair: neither `booking_id` alone nor `maintenance_id` alone determines when an acknowledgement happened or who made it, so no partial dependency exists. (The surrogate `ack_id` PK added in Task 10 is a foreign-key-ergonomics convenience; the dependency analysis uses the natural key.)
- **3NF — no transitive dependencies:** the advisory's descriptive text (e.g., `problem_description`) remains in the parent `maintenance_records`; the acknowledgement row stores only keys and timestamps, so no non-key attribute depends on another non-key attribute.

The relation is **3NF-compliant as designed**.

### 1.6 Scope boundary and downstream impact

**Scope discipline.** Output 08 records requirements and architectural decisions only; it does **not** modify or overwrite any existing Phase 1 deliverables. This document is analysis — no DDL, no data, no edits to the `outputs/01`–`07` files themselves. **Three exceptions are recorded, not silently absorbed:** the `facilities` table drop (`AGENTS.md` §1a), the `space_facilities` table drop (`AGENTS.md` §1b, Section 2.3c), and the `user_accounts.role` column drop (`AGENTS.md` §1c, Section 2.2) are documented amendments to the Phase 1 baseline, not routine additive extensions — each is called out explicitly everywhere it has consequences, rather than blended into the "unchanged" narrative.

**Downstream impact on Phase 1 outputs (04–07) — which future tasks consume them:**

| Phase 1 output | Consumed by (future task) | Impact |
|---|---|---|
| `04-design-validation-G08.md` | Task 09 — updated ERD and logical design (Output 09) | Re-validated against the extended schema: new relations 3NF-checked (mini-probe in Section 1.5), new relationships re-checked (Section 3), extended design re-validated in Output 09 |
| `05-db-definition-G08.sql` | Task 10 — schema migration (Output 10, **`outputs/10-schema-migration-G08.sql` — present in the repository but stale (S3):** it was generated against a pre-correction schema and must be regenerated from this document and Output 09 as they now stand before Task 11 or any later task consumes it) | Migration baseline: extended **additively** (new tables, new columns, new triggers) **except** for the three documented amendments — `facilities` is dropped (§1a), `space_facilities` is dropped (§1b, Section 2.3c), and `user_accounts.role` is dropped in favor of `user_roles` (§1c, Section 2.2); `maintenance_records` gains a nullable `asset_id` column — `space_id` **stays `NOT NULL`** (Section 2.4) |
| `06-sample-data-G08.sql` | Task 14 — data generator (Output 14) | Baseline seeding data; Phase 2 generator adds ≥ 3 academic years and ≥ 100,000 bookings on top of it |
| `07-query-design-G08.sql` | Task 16 — analytical queries (Output 16) | Phase 1 queries remain valid; the four §1.3 reports are added in Task 16, tuned in Task 15 |

Phase 1 outputs 01–03 (business analysis, conceptual ERD, logical design) are consumed as **context only**; they are likewise not edited — Task 09 produces the *new* updated design document (Output 09) rather than overwriting Outputs 02/03. **`outputs/10-schema-migration-G08.sql` exists in the repository but is stale (S3):** it was generated before these corrections and is inconsistent with Output 08/Output 09 as they now stand — it must be **regenerated** from this document and Output 09, not read as authoritative in its current form.

---

## 2. Affected Entities and Attributes

**Schema-extension scope at a glance:** 8 new Phase 2 tables (**[Added]**), 3 existing Phase 1 tables extended (**[Modified]**: `user_accounts`, `maintenance_records`, `booking_decisions`), 2 existing Phase 1 tables dropped under documented baseline amendments (**[Removed]**: `facilities` — `AGENTS.md` §1a; `space_facilities` — `AGENTS.md` §1b, Section 2.3c). The 4 untouched Phase 1 tables (`departments`, `spaces`, `bookings`, `usage_sessions`) are not listed below. **Total after Phase 2: 15 tables = 7 retained + 8 new.**

### 2.1 New entities (**[Added]**)

| New table | Purpose | Key attributes (columns) |
|---|---|---|
| `maintenance_impact_history` **[Added]** | Audit trail for escalation/downgrade — a single `impact_level` column on `maintenance_records` shows only the current state | `history_id` (PK, IDENTITY), `maintenance_id` (FK), `old_impact_level` (NULL on creation), `new_impact_level` (`CHECK` in `('Advisory','OutOfService')`), `changed_by` (FK → `user_accounts`), `changed_at`, `change_reason` |
| `booking_advisory_acknowledgments` **[Added]** | Records that the requester was shown and acknowledged each active advisory for a specific booking | `ack_id` (PK, IDENTITY), `booking_id` (FK), `maintenance_id` (FK), `acknowledged_by` (FK), `acknowledged_at`; `UNIQUE (booking_id, maintenance_id)` — one ack per advisory per booking |
| `auto_approval_policies` **[Added]** | Defines which space types (or specific spaces) may be auto-approved, and under what conditions | `policy_id` (PK, IDENTITY), `space_type` (`NULL`)/`space_id` (`NULL`) — exactly one set (`CHECK`), `max_participants` (`NULL` = no policy-level cap, the space's own capacity still applies), `is_active`, `created_at`, `updated_at`. **No `requires_advisory_ack` column:** advisory acknowledgement is a mandatory legal constraint on every approval path (Section 4.2), not a per-policy configuration knob, so no such column exists (Appendix A, L9). |
| `policy_booking_types` **[Added]** | Junction for the allowed `booking_type` values of a policy (SQL Server has no array type) | Composite PK (`policy_id`, `booking_type`), `CHECK` on `booking_type` matching `CK_bookings_booking_type` |
| `facility_assets` **[Added]** | Individual facility units, each identified by an internal or manufacturer serial (the asset-level tracking core) | `asset_id` (PK, IDENTITY), `space_id` (**FK → `spaces(space_id)`** — T-1: no longer a composite FK, since `space_facilities` is dropped, Section 2.3c), `facility_name` (**`CHECK` whitelist**, independently constrained on this table — see the two-whitelist maintenance note in Output 09 §5.6), `serial_number` (`NOT NULL`, `UNIQUE` — an internal identifier scheme, e.g. `<space_code>-<FACILITY>-<seq>`, is used for units with no manufacturer serial such as whiteboards or furniture; L12), `asset_status` (`CHECK` in `('Available','InUse','UnderMaintenance','Retired')`), `condition`, `last_checked_date`, `created_at`, `updated_at` |
| `space_facility_requirements` **[Added]** | States that a facility type must have at least one *available* unit for the space to be bookable — a policy about the space that must hold even when the space currently has zero units of that type (**[EXTENSION], team-invented — see §4.6 / §7 open question 2, and Output 09 §5.7/§8.2 for why this must be a separate table, D-2**). **Pure sparse junction:** presence of a row means "required"; no attribute column | Composite PK (`space_id`, `facility_name`), **FK → `spaces(space_id)`** plus its own `CHECK` whitelist on `facility_name` (T-1: no longer a composite FK to `space_facilities`, which is dropped, Section 2.3c) |
| `booking_alerts` **[Added]** | Persists the escalation/advisory result list so it survives after the report runs and staff can mark it handled (**[EXTENSION]**) | `alert_id` (PK, IDENTITY), `maintenance_id` (FK), `asset_id` (FK), `booking_id` (FK), `alert_type` (`CHECK` in `('MaintenanceEscalated','RequiredAssetRelocated','AdvisoryAddedAfterApproval')` — the third value added per L11), `created_at`, `acknowledged_by_staff_id`, `acknowledged_at` |
| `user_roles` **[Added]** | Records every role a user holds — replaces the single-valued `user_accounts.role` (documented amendment, `AGENTS.md` §1c, Section 2.2) because one person may legitimately hold several roles (a Facility Manager who also books rooms as a requester) | Composite PK (`user_id`, `role`), `user_id` (**FK → `user_accounts(user_id)`**), `role` (`CHECK` in the same six Phase 1 values). Pure junction, no non-key attributes — the same shape as `policy_booking_types`; the shape follows from the relationship being many-to-many with no properties of its own, **not** from a 3NF argument (T-4) |

**Audit Trail Robustness — `maintenance_impact_history.changed_by` fallback:** a trigger has no notion of the application user beyond the DB role, so `changed_by` is normally resolved from `SESSION_CONTEXT`. To keep the audit trail complete when the application session never set the context, the trigger must implement a **fallback chain** reading the parent maintenance record: on INSERT use `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), reporter_id)`; on UPDATE use `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), assigned_staff_id, reporter_id)`. `changed_by` must never be written as NULL or as a fabricated value; the fallback must be implemented in the Task 10 trigger.

### 2.2 Modified entities (**[Modified]** — Phase 1 tables extended)

**Documented baseline exceptions (`AGENTS.md` §1a–§1c):** the `facilities` and `space_facilities` rows below are not additive extensions — they are the two authorized table drops in this project. The `user_accounts.role` row is the one authorized column drop. All three are listed here, called out explicitly, rather than silently folded into "unchanged."

| Table | Change | Rationale |
|---|---|---|
| `facilities` **[Removed — documented exception, §1a]** | **Drop** the table entirely. `facility_name` was absorbed into `space_facilities`; `description` has no replacement column and is dropped as data. | Flattening decision, authorized by the Senior Lead Architect (`AGENTS.md` §1a). `facility_name` becomes a `CHECK`-constrained attribute instead of an FK-validated catalogue reference — consistent with how every other type/status column in this schema is already modeled without a separate lookup table. |
| `space_facilities` **[Removed — documented exception, §1b]** | **Drop** the table entirely (T-1). Its key pair `(space_id, facility_name)` was exactly the distinct projection of `facility_assets`; its `condition` duplicated `facility_assets.condition`; its `note` had no consumer and is dropped as data. | The pair was a stored-derivable fact — the same class of redundancy `quantity` removal targeted (Section 2.3a), now applied to the table itself (Section 2.3c). Authorized by the Senior Lead Architect (`AGENTS.md` §1b). `facility_assets` and `space_facility_requirements` now link directly to `spaces`, each with its own `CHECK` whitelist on `facility_name`. |
| `user_accounts` **[Modified — documented exception, §1c]** | **Drop** `role` and `CK_user_accounts_role`; every other column is untouched. **Migration:** create `user_roles`, run `INSERT INTO user_roles (user_id, role) SELECT user_id, role FROM user_accounts`, verify row counts match, then drop the column and its CHECK. | A **cardinality / domain-fidelity correction, not a normalization fix (T-4):** the single-valued `role` column violated neither 1NF nor 3NF — it modeled a multi-valued reality (one person may hold several roles) as single-valued. Authorized by the Senior Lead Architect (`AGENTS.md` §1c). No Phase 1 data is lost — every existing user keeps the role they had, now as their first `user_roles` row. Downstream: role checks that were `CHECK`-enforceable on a single column become cross-table application invariants — enumerated in Section 2.2's continuation below. |
| `maintenance_records` **[Modified]** | **Add** `impact_level` `NVARCHAR(20) NOT NULL` with `CHECK (impact_level IN ('Advisory','OutOfService'))` | The core Phase 2 maintenance change. Required and judgment-set by staff (not derived). **`DEFAULT 'OutOfService'` is a migration-only artifact (R2):** Task 10 adds it via `ALTER TABLE ... ADD impact_level NOT NULL DEFAULT 'OutOfService'` purely to backfill legacy Phase 1 rows (Phase 1's blanket rule == out-of-service), then drops the default in the same migration script. In the **final schema** `impact_level` is `NOT NULL` with **no default** — every new maintenance record must supply an impact level explicitly, since impact level is a Facility Manager judgment call (Section 4.6) that must never be silently defaulted for a newly reported problem. |
| `maintenance_records` **[Modified]** | **Add** `asset_id` `INT NULL`, FK → `facility_assets(asset_id)`. **No change to `space_id`** — it stays `NOT NULL`, exactly as in Phase 1; **no XOR constraint** is added (D-1, Section 2.4: the suspected FD `asset_id → space_id` is refuted by assets relocating between spaces, so no transitive dependency exists to guard against). `CONSTRAINT CK_maintenance_records_asset_scope_level CHECK (asset_id IS NULL OR impact_level = N'Advisory')` **is** added (**[EXTENSION]**, disclosed in Section 4.2 as a team design decision, not a stated requirement) | `space_id` is an immutable historical snapshot of the affected space at report time; `asset_id` optionally narrows the issue to one unit. A Task 10 trigger enforces the creation-time application invariant that a named asset must belong to the recorded `space_id` (Section 2.4). |
| `booking_decisions` **[Modified]** | **Add** `decision_source` `NVARCHAR(10) NOT NULL DEFAULT 'Staff'` with `CHECK` in `('Staff','System')`; **change** `decided_by` from `NOT NULL` to `NULL` with same-table `CHECK ((decision_source = 'System' AND decided_by IS NULL) OR (decision_source = 'Staff' AND decided_by IS NOT NULL))` | Auto-approval decisions are stored in the same decision-record shape as staff decisions, distinguished by `decision_source`. A nullable FK is preferred over a sentinel "SYSTEM" user row, which would pollute `user_accounts` reporting. Existing rows are unaffected (they all have a real staff `decided_by`). |

**Downstream cost of dropping `user_accounts.role` (T-4) — role checks lose `CHECK` enforcement.** Every place this design assumed "this user is staff" was, before T-4, implicitly checkable against a single `user_accounts.role` column. After T-4 each becomes a cross-table predicate of the form `EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = @id AND ur.role IN (...))`, which cannot be a `CHECK` constraint (it spans two tables) and must instead be a trigger-enforced application invariant. Enumerated explicitly rather than left implicit:

- `booking_decisions.decided_by` — must hold a staff-type role when `decision_source = N'Staff'`.
- `maintenance_records.assigned_staff_id` — must hold `FacilityStaff` or `FacilityManager`.
- `booking_alerts.acknowledged_by_staff_id` — must hold a staff-type role.
- `maintenance_impact_history.changed_by` — the `SESSION_CONTEXT` fallback chain (Section 2.1) must resolve to a user holding a staff-type role.
- Any rule in Output 09 §7 or §9 whose wording says "staff" now depends on this same cross-table check.

This increases the trigger surface: Task 10 must implement each of these four invariants, or the schema will not enforce what this document claims.

### 2.3a Attribute refinement: quantity-based → asset-based tracking (3NF-driven)

- Phase 1 stored equipment as a count (`space_facilities.quantity`, e.g. "2 projectors"). Phase 2 adds `facility_assets` so units are individually identifiable ("Projector #001", "Projector #002"), each with a `serial_number` and its own `asset_status`.
- **`space_facilities.quantity` is eliminated** — storing a count that must mirror the number of `facility_assets` rows is a 3NF violation (a stored fact derivable from another table). Unit counts are **derived via `COUNT(*)` on `facility_assets`** through the view `v_space_facility_summary`. This is the **only** genuinely normalization-driven change in this section — Section 2.3b covers the separate, non-normalization decision to drop `facilities`.
- This is what makes advisory maintenance meaningful: "one of several AC units is down" becomes a trackable asset state instead of a sentence in a note field.

### 2.3b Flattening `facilities` into `space_facilities` (deliberate denormalization — [EXTENSION], NOT 3NF-driven)

`facilities(facility_id PK, facility_name UNIQUE, description)` was already in **BCNF** on its own — removing an already-normalized lookup table improves no normal form (Appendix A, L13). This is a **deliberate denormalization**, tagged **[EXTENSION]** because it is a team design decision with no basis in `CS486_Project_Phase02.pdf`.

**Historical note — this subsection describes the `AGENTS.md` §1a amendment as it stood at the time.** `space_facilities` itself is subsequently **dropped** under the separate `AGENTS.md` §1b amendment (Section 2.3c) — the "single source of which facility types a space is equipped with" role described below no longer exists as a table; `facility_name` is now `CHECK`-constrained independently on `facility_assets` and `space_facility_requirements`. This subsection is retained because the `facilities → facility_name` absorption it describes is a distinct decision from the later `space_facilities` drop, and both must be visible.

- **`facilities` is dropped and `facility_name` was absorbed into `space_facilities`** (documented amendment, `AGENTS.md` §1a). `facility_name` is `CHECK`-constrained to the same closed set the old `facilities` catalogue held (`'Projector'`, `'Whiteboard'`, `'AirConditioner'`, `'ComputerStation'`, `'SpeakerSystem'`, `'VideoConference'`, `'SmartBoard'`), so type-name integrity is preserved by a `CHECK` whitelist instead of a lookup table — the same pattern already used for `space_type`, `booking_type`, and every status column in this schema.
- `facility_assets` originally linked to `space_facilities` via a composite FK; per Section 2.3c, that FK is now superseded by a plain `FK → spaces(space_id)` plus an independent `CHECK` on `facility_name` (the original composite-FK physical-necessity explanation is preserved in Appendix A as superseded).
- **Trade-offs of this decision, recorded honestly rather than hidden behind normalization language:**
  - Adding a new facility type now requires an `ALTER TABLE ... ADD CONSTRAINT` on **two** tables (`facility_assets`, `space_facility_requirements` — Section 2.3c), instead of a one-row `INSERT` into `facilities`.
  - Renaming a facility type is **nearly impossible** in practice: the string is embedded independently in `facility_assets` and `space_facility_requirements` with no shared referential link between the two, so a rename requires coordinated updates across both.
  - The `facility_name NVARCHAR(100)` string is **duplicated across 2 tables** (`facility_assets`, `space_facility_requirements` — reduced from 3 once `space_facilities` itself is dropped, Section 2.3c), increasing storage versus a single-integer `facility_id`.
  - **Real data loss:** the `facilities.description` column (e.g., "Standard HDMI projector with 1080p resolution") has no replacement home and is dropped as data — an explicit, intentional narrowing of scope rather than a silent loss.
  - **Benefit in exchange:** consistency with how `space_type`, `booking_type`, and every status column are already modeled in this schema (no separate lookup table), and one fewer `JOIN` in every catalogue query.

### 2.3c Dropping `space_facilities` — a stored projection, not a table worth keeping (T-1)

`space_facilities` held exactly four columns: `space_id`, `facility_name`, `condition`, `note`.

- **The key pair is a stored projection.** `(space_id, facility_name)` is precisely `SELECT DISTINCT space_id, facility_name FROM facility_assets` — "space A is equipped with facility type T" is exactly "at least one row exists in `facility_assets` with that pair." Storing it separately is the same category of redundancy as storing `quantity` (Section 2.3a): a fact derivable from another relation, kept in a second place where it can drift.
- **`condition` duplicated `facility_assets.condition`** with no defined source of truth — this is exactly the defect logged as L4, which was previously *documented* rather than *fixed*. Dropping the table resolves L4 structurally instead of by explanation.
- **`note` has no consumer anywhere in the design** and is dropped as data — an explicit, intentional narrowing of scope, exactly as `facilities.description` was in Section 2.3b.
- **The composite FK is not lost, it is voided.** `FK_facility_assets_space_facility` and `FK_space_facility_requirements_space_facility` existed to guarantee "this asset belongs to a catalogued combination." With no catalogue, that guarantee is not merely unenforced — it is **meaningless**, because an asset's own existence is what defines the combination. The constraint is vacuous, not a lost protection.
- **The one thing genuinely lost:** the ability to record "space A is equipped with facility type T" while zero units of T are present. No query in this design needs that state — the room finder needs *available* units, rule R8 reads `space_facility_requirements` directly (Section 2.1), and the advisory/blocking queries read `maintenance_records` (Section 2.4/4.1–4.2). The one place that *does* depend on this state is `v_space_facility_summary` (Output 09 §6), which is why that view's rebasing onto a `UNION` of `facility_assets` and `space_facility_requirements` is load-bearing, not cosmetic — a plain re-base onto `facility_assets` alone would silently drop the `total_units = 0, is_required = 1` row that rule R8 exists to detect.

**Schema consequence:** `facility_assets.space_id` becomes a plain `FK → spaces(space_id)`; `facility_name` on both `facility_assets` and `space_facility_requirements` becomes an independent `CHECK` whitelist (identical set on both — see the two-whitelist maintenance note in Output 09 §5.6/§5.7). Authorized by `AGENTS.md` §1b.

### 2.3d Migrating `space_facilities` into `facility_assets` — expansion, not projection (Appendix A, B6)

Sections 2.3a–2.3c establish that `space_facilities`'s key pair is a **stored projection** of `facility_assets` in the **final** schema — but that framing describes the destination, not the migration path. At migration time the dependency runs the opposite direction: `space_facilities` holds the **only** record of what equipment each space is currently equipped with (as a count), and `facility_assets` starts **empty**. Dropping `space_facilities` without first expanding its rows into `facility_assets` is **total data loss** of every space's facility inventory, not a redundancy removal. This is stated explicitly here because Sections 2.3a–2.3c alone do not say it, and a reader of Output 08/09 in isolation would not otherwise know the drop is unsafe without an expansion step first.

- **Expansion rule:** the migration expands each Phase 1 `space_facilities` row `(space_id, facility_id, quantity, condition, note)` — resolving `facility_id → facility_name` through the `facilities` table while it still exists — into exactly `quantity` individual `facility_assets` rows, one per unit.
- **`serial_number` generation:** units with no manufacturer serial number receive the internal identifier scheme `<space_code>-<FACILITY>-<seq>` documented in Output 09 §5.6 (L12), assigned at generation time so every generated row satisfies `facility_assets.serial_number NOT NULL UNIQUE`.
- **`condition`/`note` carry-over:** Phase 1's `condition` and `note` text is carried onto every unit generated from that row rather than dropped as data — it holds real operational information (e.g., "3 stations have faulty keyboards") that would otherwise be lost outright.
- **`asset_status` seeding rule (decision A1, [EXTENSION]):** a generated unit is seeded `UnderMaintenance` **only where `quantity = 1`** — i.e., only where the Phase 1 condition text can be attributed to one specific unit. Where `quantity > 1`, the condition text describes the group and cannot be pinned to any one unit — marking all of them `UnderMaintenance` would be factually wrong and operationally harmful, because rule R8 (Section 4.6) would then block every booking of the room while most units still work. Multi-unit groups are instead seeded `Available` with the original condition text preserved in `facility_assets.condition`, and surfaced for per-unit staff assessment. `asset_status` is staff-maintained operational state under the two-tier policy (Output 09 §6) — the migration does not guess it.
- **Scope boundary:** this expansion is **data preservation**, squarely Task 10's responsibility — it moves existing Phase 1 facts into the new shape without inventing new ones. It is not data generation: Task 14's generator adds new volume (≥ 3 academic years, ≥ 100,000 bookings) on top of the preserved baseline and is not responsible for the Phase 1 → Phase 2 facility-inventory carry-over.

### 2.4 Maintenance targeting: `space_id` and `asset_id` coexist — no XOR needed (3NF analysis)

**What `space_id` actually means (T-3a — the framing the formal proof needs).** `maintenance_records.space_id` does not mean "where the asset currently is." It means **"whose bookings are affected."** These are different facts that merely coincide at the moment the record is filed. Compare an invoice that stores `shipping_address` even though the customer record already has `address`: that is not redundancy — the invoice records where the goods *were sent* (immutable history), while the customer row holds the *current* address. A value that coincides today but can legitimately diverge tomorrow is not a copy of the other. The formal refuted-FD proof below is correct and unchanged; this framing is why the proof lands.

**Candidate transitive dependency (D-1):** storing both `space_id` (`NOT NULL`) and `asset_id` (nullable) on `maintenance_records` raises the question of whether this creates a transitive dependency — `maintenance_id → asset_id → space_id` — since an asset's location is separately recorded via `facility_assets.space_id`, which would make the stored `space_id` a redundant copy. This reasoning does not survive testing.

**Testing the suspected FD `asset_id → space_id`:** a functional dependency only holds if it is true in *every legal instance* of the schema, not just the common case. Counterexample: projector **X** is installed in room **101** and breaks → maintenance record **M1** is filed (`asset_id = X`, `space_id = 101`). Facilities staff repair **X**, then reinstall it in room **202**, where it breaks again → maintenance record **M2** is filed (`asset_id = X`, `space_id = 202`). Two tuples (`M1`, `M2`) share the same `asset_id` but differ on `space_id` ⇒ the FD `asset_id → space_id` is **refuted**.

**Conclusion:** because assets are permitted to move between spaces — a real business process; a broken unit is typically removed for repair and may be reinstalled elsewhere — `asset_id` does **not** determine `space_id`. Therefore **no transitive dependency exists**, and `space_id` on `maintenance_records` is an **independent historical fact**, not a redundant copy of something derivable from `asset_id`. The relation satisfies 3NF **without any XOR constraint**. `CK_maintenance_records_target_xor` is accordingly **removed**.

**Design (revised):**

| Column | Null | Meaning |
|---|---|---|
| `space_id` | `NOT NULL` (Phase 1 baseline, unchanged) | The affected space **at the time the problem was reported** — an immutable historical snapshot |
| `asset_id` | `NULL` | The specific unit, when this is an equipment-level issue |

**Supporting rule — `space_id` is an immutable snapshot:** when `facility_assets.space_id` changes (the unit is relocated), existing `maintenance_records` rows referencing that asset are **not** updated to follow it. This is precisely what keeps historical reporting correct — a maintenance record continues to describe the room the problem actually occurred in, regardless of where the unit is relocated afterward.

**Application invariant (not a `CHECK` — it spans tables):** at **INSERT time**, if `asset_id IS NOT NULL`, the referenced asset must currently belong to the recorded `space_id`. This is enforced by a trigger in Task 10, and applies **only at creation time, not thereafter** — which is exactly what the snapshot semantics above require (the asset is free to move after the record is filed without invalidating it).

**Consequences for the blocking and advisory queries (Section 4.1–4.2):**
- The `OutOfService` blocking query keeps `WHERE m.space_id = @space_id` — and is now **complete by construction**, since every `maintenance_records` row carries a `space_id`, whether or not it also carries an `asset_id`.
- The advisory acknowledgement query needs **no `JOIN` through `facility_assets`** to find asset-level advisories: since `space_id` is always populated, `WHERE m.space_id = @space_id` alone finds both space-level and asset-level active advisories for a space (Appendix A, D-1).
- `CONSTRAINT CK_maintenance_records_asset_scope_level CHECK (asset_id IS NULL OR impact_level = N'Advisory')` is **retained** (it addresses a different concern — whether an asset-scoped record may reach `OutOfService` — unrelated to the XOR removed above), but is now explicitly disclosed as a separate **[EXTENSION]** team design decision, not a stated requirement — see Section 4.2 (D-3).

**Considered and rejected: splitting into `maintenance_records_space` and `maintenance_records_asset` (T-3c).** A two-table split (one parent for space-level records, one for asset-level records) was evaluated and rejected, for four reasons:

1. `maintenance_impact_history`, `booking_alerts`, and `booking_advisory_acknowledgments` all reference `maintenance_id`. With two parent tables, each child needs either two nullable FK columns plus an XOR — reintroducing, in three separate places, exactly the construct D-1 removed from `maintenance_records` itself — or would itself have to be duplicated per parent.
2. `IDENTITY` on two parent tables produces colliding identifiers: `maintenance_id = 42` could exist in both tables simultaneously, so `booking_alerts` could no longer reference "maintenance record 42" unambiguously without also storing which table it came from.
3. Every space-scoped query — the `OutOfService` blocking check (Section 4.1), the advisory-ack check (Section 4.2), report (d) (escalation lookup), and the escalation lookup itself — becomes a `UNION` of two relations instead of a single-table filter.
4. The only gain would be `asset_id NOT NULL` on one table instead of nullable on one — a marginal typing benefit that does not offset the three costs above.

Recording the alternative here is deliberate: showing it was evaluated and why it lost is worth more than silently never mentioning it.

---

## 3. Relationship Changes

Phase 2 **adds** new relationships, **removes** the `facilities → space_facilities` relationship entirely (documented amendment, `AGENTS.md` §1a), then **removes `space_facilities` from the diagram altogether** (documented amendment, `AGENTS.md` §1b, T-1) — `facility_assets` and `space_facility_requirements` now link **directly** to `spaces` — and **adds** an optional `asset_id` narrowing column on `maintenance_records` — with **no XOR** and **no cardinality change** on `maintenance_records → spaces` (D-1, Section 2.4). It also **adds** `user_accounts → user_roles` (T-4), replacing the single-valued `user_accounts.role` column. None of the remaining Phase 1 FK relationships between `departments → user_accounts`, `user_accounts → bookings`, `spaces → bookings`, `bookings → booking_decisions`, `user_accounts → booking_decisions`, `bookings → usage_sessions`, `user_accounts → usage_sessions` (checked_in_by, completed_by), `spaces → maintenance_records`, or `user_accounts → maintenance_records` (reporter_id, assigned_staff_id) is altered. The **Conceptual Notation** column restates each relationship in the Crow's Foot language.

| New/Changed relationship | Cardinality | Conceptual notation (Crow's Foot) | FK / structure | Notes |
|---|---|---|---|---|
| `facilities` → `space_facilities` **[Removed]** | — | — | — | The `facilities` table is dropped; `facility_name` was briefly absorbed into `space_facilities` (Section 2.3b) |
| `spaces` → `space_facilities` **[Removed]** | — | — | — | `space_facilities` itself is now dropped (T-1, Section 2.3c) — this relationship no longer exists in either direction |
| `spaces` → `facility_assets` **[New]** | 1 → 0..N | `1 ── 0..N` | `CONSTRAINT FK_facility_assets_space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id)` | Direct FK (T-1: no longer routed through `space_facilities`); `facility_name` is a separately `CHECK`-constrained column, not part of this FK |
| `spaces` → `space_facility_requirements` **[New]** | 1 → 0..N | `1 ── 0..N` | `CONSTRAINT FK_space_facility_requirements_space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id)` | Direct FK (T-1); `facility_name` is a separately `CHECK`-constrained column, not part of this FK |
| `maintenance_records` → `facility_assets` **[New]** | 0..1 → 0..N | `0..1 ── 0..N` | `maintenance_records.asset_id` (nullable) | `NULL` = space-level-only record (no specific unit named); non-`NULL` narrows the issue to one unit, alongside the always-present `space_id` (Section 2.4) — not mutually exclusive, no XOR |
| `maintenance_records` → `maintenance_impact_history` | 1 → 0..N | `1 ── 0..N` | `maintenance_impact_history.maintenance_id` | Populated by trigger |
| `maintenance_records` → `booking_alerts` | 0..1 → 0..N | `0..1 ── 0..N` | `booking_alerts.maintenance_id` (nullable, XOR with `asset_id`) | Escalation results |
| `facility_assets` → `booking_alerts` **[EXTENSION]** | 0..1 → 0..N | `0..1 ── 0..N` | `booking_alerts.asset_id` (nullable, XOR with `maintenance_id`) | Relocation alerts |
| `bookings` → `booking_alerts` | 1 → 0..N | `1 ── 0..N` | `booking_alerts.booking_id` | Same escalation/relocation list |
| `bookings` ↔ `maintenance_records` (via `booking_advisory_acknowledgments`) | M ↔ N resolved | `M ── N`, resolved to two `1 ── 0..N` legs | `ack.booking_id`, `ack.maintenance_id` + `UNIQUE` | Advisory consent junction |
| `auto_approval_policies` → `policy_booking_types` | 1 → 0..N | `1 ── 0..N` | `policy_booking_types.policy_id` | Junction for allowed booking types |
| `auto_approval_policies` → `spaces` | 0..1 → 1 (optional) | `0..1 ── 1` | `auto_approval_policies.space_id` | Specific-space override |
| `user_accounts` → `user_roles` **[New]** | 1 → 0..N | `1 ── 0..N` | `CONSTRAINT FK_user_roles_user_id FOREIGN KEY (user_id) REFERENCES user_accounts(user_id)` | T-4: replaces the single-valued `user_accounts.role` column. A zero-role user is a valid lifecycle state — a junction table cannot declaratively require at least one row; the Phase 1 migration seeds every existing user with exactly one role row |

**Conceptual bridge — Home ID / Visitor ID (Phase 1 convention):** `facility_name` **no longer has a defining entity of its own** (T-1) — it is an independent `CHECK`-constrained attribute appearing separately on `facility_assets` and `space_facility_requirements`, with no Home ID/Visitor ID relationship between the two; `maintenance_id` is Home in `maintenance_records` and Visitor in `maintenance_impact_history`, `booking_alerts`, and `booking_advisory_acknowledgments`; `booking_id` is Home in `bookings` and Visitor in `booking_alerts` and `booking_advisory_acknowledgments`; `asset_id` is Home in `facility_assets` and Visitor in `maintenance_records` (nullable, optional equipment-level narrowing — no XOR, Section 2.4) and `booking_alerts` (nullable, XOR with `maintenance_id` — unrelated to the maintenance-records XOR removal); `space_id` is Home in `spaces` and Visitor in `facility_assets`, `space_facility_requirements` (both direct FKs now, T-1), `maintenance_records` (**mandatory, `NOT NULL`, immutable snapshot** — Section 2.4), and `auto_approval_policies`; `user_id` is Home in `user_accounts` and Visitor in `user_roles` (T-4), among its other existing Visitor copies.

Cardinality-change note: `booking_decisions.decided_by` becomes optional (1 → 0..1) so that `decision_source = 'System'` decisions can exist without a staff member. `maintenance_records → spaces` **remains mandatory (1)**, unchanged from Phase 1 — Section 2.4 explains why no XOR-driven cardinality change is needed.

---

## 4. New Business Rules Analysis

### 4.1 Status vs. Impact reconciliation (critical decision)

**Conflict identified:** Phase 1 blocks bookings when `spaces.current_status = 'UnderMaintenance'` (the Phase 1 trigger rejects `Pending`/`Approved` bookings for any space whose `current_status` is `UnderMaintenance`, `TemporarilyClosed`, or `Retired`). Phase 2 allows bookings during **advisory** maintenance — but if the `current_status` flag were still derived from *any* active maintenance record, advisory-affected spaces would be wrongly blocked, and if it were not, out-of-service blocking would silently depend on a flag maintained outside the booking flow.

**Decision:** the system **stops relying on `spaces.current_status` for booking-blocking decisions**. Booking creation and approval logic must query `maintenance_records` directly:

```sql
-- Impact-level check (replaces the status-based maintenance check)
-- Complete by construction: every maintenance_records row carries a
-- space_id (an immutable snapshot, Section 2.4) whether or not it also
-- names an asset_id, so this WHERE clause finds every blocking record
-- with no JOIN through facility_assets needed.
SELECT 1
FROM maintenance_records m
WHERE m.space_id = @space_id
  AND m.status NOT IN ('Completed', 'Cancelled')          -- active record
  AND m.impact_level = 'OutOfService'                     -- blocks only at this level
  AND m.start_time < @new_end
  AND COALESCE(m.completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2)) > @new_start;
```

- Only an active record with `impact_level = 'OutOfService'` overlapping the requested window blocks booking/approval. `Advisory` records never block — they only drive the acknowledgement requirement (Section 4.3).
- **Completeness (no JOIN needed):** every `maintenance_records` row carries a `space_id` (Section 2.4 — an immutable historical snapshot, present whether or not the record also names an `asset_id`), so the blocking query above finds all `OutOfService` records for the space directly. `CK_maintenance_records_asset_scope_level` ([EXTENSION] team decision, Section 4.2) additionally guarantees that asset-scoped records can never be `OutOfService` in the first place — a single broken unit can never close a room through this path — but the query's completeness does not depend on that constraint; it follows from `space_id` being `NOT NULL` on every row.
- `spaces.current_status` is retained **for UI display purposes only** (e.g., showing "Under Maintenance" on the space card); its maintenance-derived value is kept in sync by staff workflows but is **not part of any booking-blocking predicate**. `TemporarilyClosed` and `Retired` remain legitimate non-maintenance blocking states read from `spaces.current_status`.
- The Phase 1 trigger's `current_status` check stays only as a backstop for non-maintenance closures; the primary maintenance block is the impact-level check above, executed inside the concurrency-safe procedures (Section 5.5) on every booking/approval path.
- **The Phase 1 trigger `TR_bookings_PreventOverlapAndUnavailable` must itself be modified, not merely reinterpreted (Appendix A, B8):** "stays as a backstop" does not mean "stays unchanged." Three changes are required so the backstop actually matches the rules above instead of silently enforcing the old Phase 1 behavior in parallel with them:
  1. **Remove `'UnderMaintenance'` from its `spaces.current_status` check.** Under this section's decision, `current_status` is never a maintenance-blocking predicate — leaving `'UnderMaintenance'` in the trigger's closure check would wrongly block a space flagged for advisory-only reasons, contradicting the impact-level check it is supposed to back up. `TemporarilyClosed` and `Retired` stay, since those remain legitimate non-maintenance blocking states.
  2. **Extend the overlap check from `status = 'Approved'` to `status IN ('Approved','CheckedIn')`** — matching the status-driven interval selection of Section 4.4; a `CheckedIn` booking still occupies its reserved window and must still be caught by the backstop.
  3. **Add the `OutOfService` impact-level check**, querying `maintenance_records` directly (the same predicate as the impact-level check above), so the trigger backstops the *current* blocking rule rather than the superseded `current_status`-based one.
  It remains a **validation backstop only** — it does not replace or substitute for the concurrency mechanism, which is Task 12's `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK` procedures (Section 5).

### 4.2 Maintenance impact levels: `Advisory` vs. `OutOfService`

**What makes a problem space-level vs. asset-level (T-3b — cross-referenced from Output 09 §5.11).** The dividing line is **not** "building damage vs. equipment damage." It is whether the failing thing is registered in `facility_assets`:

| Scope | Meaning | Examples |
|---|---|---|
| `asset_id IS NULL` — space-level | The problem is a property of the room itself, not attributable to any one tracked unit | Cracked wall, broken door or lock, damaged flooring, ceiling leak, whole-room power loss, in-wall sockets, flooding, cleaning/odour, central HVAC not registered as assets |
| `asset_id IS NOT NULL` — asset-level | The problem is a property of one tracked unit with its own identifier | Projector #3 lamp failure, one of four AC units dead, one of forty lab PCs faulty |

**The boundary is operational, not physical.** If each AC unit in a room is individually registered in `facility_assets`, an AC failure is asset-level. If the building instead runs central HVAC that is never registered as an asset, the identical symptom ("the room is too hot") is space-level — because there is no tracked unit to attribute it to. The same physical fault can therefore be classified differently in different rooms, depending only on what this space's `facility_assets` inventory happens to contain. One consequence holds for both kinds without exception: `space_id` is `NOT NULL` on every record — even an asset-level record must name the room whose bookers need to be warned (Section 2.4).

**Out-of-service** (`'OutOfService'`) — the space itself is unusable (electrical repair, floor replacement, AC replacement):
- Blocks booking for **any overlapping time period** — exactly the Phase 1 rule, scoped to this level and enforced via the impact-level check of Section 4.1 (never via `spaces.current_status`).
- A maintenance record is "active" when `status NOT IN ('Completed', 'Cancelled')`. The booking must not be created/approved if the requested window overlaps an active out-of-service period on that space: `start_time < requested_end_time AND COALESCE(completion_time, '9999-12-31') > requested_start_time`.
- **[EXTENSION] disclosure — `CK_maintenance_records_asset_scope_level` (D-3):** this constraint (`CHECK (asset_id IS NULL OR impact_level = N'Advisory')`) does **not** appear in `CS486_Project_Phase02.pdf`; it is a **team design decision**, retained but disclosed honestly here rather than presented as a stated requirement. It structurally prevents any record naming an `asset_id` from being `OutOfService` — a single broken unit never closes an entire room through this path. **Trade-off:** this narrows expressiveness — a room with only one air conditioner genuinely becomes unusable when that unit fails, yet an asset-scoped record is forbidden from escalating to `OutOfService` to reflect that. **Compensating workflow:** in that case, staff file an *additional* space-level record (`asset_id = NULL`, `impact_level = 'OutOfService'`) to close the room directly, or rely on rule R8 (`space_facility_requirements`) to block bookings via the required-facility mechanism when the failed unit is the last available one. **Benefit in exchange:** the `OutOfService` blocking query (Section 4.1) never has to distinguish space-level from equipment-level records — it is a flat `impact_level = 'OutOfService'` filter.

**Advisory** (`'Advisory'`) — only part of the equipment or comfort is affected (one broken projector, one faulty AC among several):
- Does **not** block booking.
- Requires: the requester is shown every currently active advisory **affecting the space** at booking time, and **one acknowledgement is stored per booking per active advisory** (`booking_advisory_acknowledgments`, `UNIQUE (booking_id, maintenance_id)`).
- Because `space_id` is always populated on every `maintenance_records` row — including asset-scoped ones (Section 2.4) — "active advisories affecting the space" is simply every active `Advisory` record with `m.space_id = @space_id`; no `JOIN` through `facility_assets` is needed to find asset-level advisories.
- A booking cannot be finalized as `Approved` (or `CheckedIn`) while an unacknowledged active advisory exists — enforced by trigger `TR_bookings_AdvisoryAckRequired`. Counting active advisories against counting acknowledged ones is not equivalent to checking set containment — a count can match by coincidence while the specific unacknowledged advisory differs from the specific acknowledged one (Appendix A, L2). The check is instead a **set-based existence test**:
  ```sql
  -- A booking may not enter Approved/CheckedIn while any active advisory remains unacknowledged
  NOT EXISTS (
      SELECT 1
      FROM dbo.maintenance_records m
      WHERE m.space_id      = @space_id
        AND m.impact_level  = N'Advisory'
        AND m.status NOT IN (N'Completed', N'Cancelled')
        AND m.start_time < @requested_end
        AND COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2)) > @requested_start
        AND NOT EXISTS (
              SELECT 1 FROM dbo.booking_advisory_acknowledgments a
              WHERE a.booking_id = @booking_id AND a.maintenance_id = m.maintenance_id)
  )
  ```
- **Application invariant (L10, not a `CHECK` — cross-table):** `booking_advisory_acknowledgments.maintenance_id` must reference a record whose `impact_level = 'Advisory'` — a booking should never be able to "acknowledge" an `OutOfService` record. This cannot be expressed as a `CHECK` constraint (it spans two tables); it is enforced by a trigger in Task 10 and documented here as an application invariant.
- **[EXTENSION] Advisory added after approval (L11):** rule R3 (the ack-completeness trigger) only gates the *status transition into* `Approved`/`CheckedIn` — it does not re-run when a new advisory is filed against a space that already has approved bookings. Chosen behavior: a newly-filed advisory does **not** retroactively invalidate an already-`Approved` booking; instead, a trigger writes a `booking_alerts` row (`alert_type = N'AdvisoryAddedAfterApproval'`) so staff — and, through them, the requester — are informed. This is a third `alert_type` value alongside `MaintenanceEscalated` and `RequiredAssetRelocated` (Output 09 §5.16); `CK_booking_alerts_source_scope` gains a matching branch.
- Because SQL Server has no deferred triggers, the equivalent of a "commit-time" check is achieved with a documented **statement order inside the transaction**: insert booking as `Pending` → insert acknowledgement rows → update status to `Approved`. The trigger fires on the status-change statement, at which point the acknowledgements are already visible in the same transaction.

**Multiple concurrent records:** a space may have zero, one, or many active maintenance records at independent impact levels simultaneously. The rules above compose: any active `OutOfService` overlap blocks; every active `Advisory` overlapping the window (space-level or asset-level) must be acknowledged. Implementation is query-based (no special storage).

### 4.3 Escalation / downgrade policy

- `impact_level` may change while the record is open (advisory → out-of-service, or back). Every change is recorded in `maintenance_impact_history` by trigger `TR_maintenance_impact_history` (INSERT records the initial level with `old_impact_level = NULL`; UPDATE records only when the value actually changed; `changed_by` comes from `sp_set_session_context` with a **fallback chain** — `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), assigned_staff_id, reporter_id)` on UPDATE, `reporter_id` on INSERT — so the audit row never carries a NULL or fabricated actor, per Section 2.1).
- **Escalation constraint (disclosed [EXTENSION] — Section 4.2, D-3):** only records with `asset_id IS NULL` (space-level) can be escalated to `OutOfService`. Records with `asset_id IS NOT NULL` (equipment-level) are structurally locked to `Advisory` by `CK_maintenance_records_asset_scope_level` — a team design decision, not a stated requirement.
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

- Eligibility is configured per **space type** (or a specific-space override) in `auto_approval_policies` + `policy_booking_types`. **Precedence (L8):** when both a type-wide policy and a specific-space override exist for the same space, the **specific-space override always wins**; the type-wide policy is ignored entirely for that space. At most one **active** type-wide policy may exist per `space_type` — enforced by a filtered unique index (Output 09 §10) — so eligibility evaluation is deterministic.
- At submission, the instant path checks the policy: allowed `booking_type`; **`(max_participants IS NULL OR expected_participants <= max_participants) AND expected_participants <= spaces.capacity`** — `NULL` means no policy-level participant cap, only the space's own capacity applies; the NULL-safe form is required because SQL Server's three-valued logic evaluates `expected_participants <= NULL` to `UNKNOWN`, which a plain comparison would silently read as "not eligible" (S2); no overlapping `Approved`/`CheckedIn` booking, no active `OutOfService` overlap, and all active advisories (space-level and asset-level) acknowledged.
- If all conditions hold, the booking is approved immediately and a `booking_decisions` row records the decision with `decision_source = 'System'` and `decided_by = NULL` (enforced by the same-table CHECK).
- If the request does not satisfy the policy, it falls through to the unchanged Phase 1 manual workflow.
- Open question (product decision): if two instant requests race for the same slot, the loser may be auto-rejected or re-queued as `Pending` — not stated in either PDF (see Section 7).

### 4.6 Asset-level booking block (**[EXTENSION]**, team-proposed)

- If a facility type marked as required in `space_facility_requirements` for a space has **zero available units** (`facility_assets.asset_status = 'Available'` for that space + facility), a booking must be blocked **even without a space-level out-of-service record** — trigger `TR_bookings_RequiredAssetCheck` enforces this when a booking is placed into `Approved`/`CheckedIn`.
- `space_facility_requirements` links directly to `spaces` via `FK → spaces(space_id)` plus its own `CHECK` whitelist on `facility_name` (T-1 — no longer routed through `space_facilities`, which is dropped, Section 2.3c). This is how "maintenance on the last remaining unit of a required facility" closes the space without needing `spaces.current_status = 'UnderMaintenance'`.
- Impact level remains a Facility Manager judgment call — the system surfaces available-unit counts (`v_space_facility_summary`) to help, but never derives `impact_level` automatically.
- **Why `space_facility_requirements` must be its own table (T-2 — the real reason, replacing the D-2 rationale):** "space A may not be booked without a working projector" is a policy **about the space**, and it must be expressible **when the space currently has zero projectors** — because zero available units is precisely the condition R8 blocks on. It therefore cannot live on `facility_assets` (assets come and go; the policy must outlive them and hold when none exist), and after the `space_facilities` drop (T-1) there is no catalogue table left to host it either. A separate relation is **structurally required**, not a stylistic choice — sparsity, presence-as-semantics, and separable permissions (the original D-2 justification) were never the real reason; see Appendix A for that superseded rationale in full.
- **Contingency, stated explicitly:** this table's necessity is entirely downstream of rule R8, which is itself a team **[EXTENSION]** still listed as an unconfirmed team-invented concept (§7, open question 2). If R8 were dropped, `space_facility_requirements` and rule R12 (relocation alerts, which read the required set) would go with it — see §7 for this dependency chain kept visible rather than buried.

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

**Mandatory lock-ordering rule (L7 — closes the approval-vs-escalation deadlock risk):** any transaction that touches both `bookings` and `maintenance_records` (directly, or via `booking_alerts`) must acquire locks in the fixed order **`bookings` → `maintenance_records` → `booking_alerts`**. The Task 12 escalation workflow must comply with this order even though it logically reads `maintenance_records` first. Deadlocks **remain possible** even with this rule — SQL Server does not enforce lock ordering automatically, it only avoids the *guaranteed* deadlock that opposite orderings would create — so bounded retry on errors **1205** (deadlock victim) and **1222** (lock timeout) is **mandatory, not optional**, on every code path in this section.

**Defense in depth.** `TR_bookings_PreventOverlapAndUnavailable` stays as a backstop for any path that bypasses the stored procedures.

**Multi-statement flows.** The surrounding logic (read `auto_approval_policies`, decide, insert booking, insert acknowledgement rows) is a read-then-write sequence with its own race potential; it is wrapped in a `SERIALIZABLE` transaction. Where PostgreSQL signals serialization failure (40001), SQL Server raises deadlock 1205 / lock timeout 1222 → application retry.

**Where the trigger-based rules (§4.2–§4.6) fit:** they enforce business rules at statement level; the concurrency procedures ensure the invariant holds under simultaneity. Both layers coexist: procedures prevent the race, triggers catch any rule violation on the committed state.

---

## 6. Phase 2 Traceability Matrix

Links every Phase 2 requirement from `req/business-requirement-P2.md` (tags: **[CONFIRMED]** = stated in the Phase 2 PDF, **[EXTENSION]** = team-proposed) to its database component(s).

| # | Phase 2 requirement | Tag | Database component / rule |
|---|---|---|---|
| 1 | Maintenance records carry an impact level (`Advisory` / `OutOfService`) | [CONFIRMED] | `maintenance_records.impact_level` `NOT NULL` + `CK` whitelist (PascalCase values) |
| 2 | **Blocking rule:** `OutOfService` blocks booking for any overlapping period (Phase 1 rule scoped to this level) | [CONFIRMED] | **Impact-level check** (Section 4.1): query `maintenance_records` directly for active records with `impact_level = 'OutOfService'` overlapping the requested window; complete by construction since every row carries `space_id` (Section 2.4); `CK_maintenance_records_asset_scope_level` ([EXTENSION], Section 4.2) additionally guarantees asset-scoped records can never be `OutOfService` |
| 3 | `Advisory` does not block; every active advisory acknowledged per booking before approval | [CONFIRMED] | `booking_advisory_acknowledgments` + `UNIQUE (booking_id, maintenance_id)` + trigger `TR_bookings_AdvisoryAckRequired`; advisory query is a flat `m.space_id = @space_id` filter (no JOIN needed — Section 2.4); set-based `NOT EXISTS` ack check (Section 4.2, L2) |
| 4 | A space may have several active maintenance records at different impact levels simultaneously | [CONFIRMED] | No new storage; query-based composition of rules 2–3 (active = `status NOT IN ('Completed','Cancelled')`) |
| 5 | Impact level may be escalated/downgraded while open | [CONFIRMED] | `maintenance_impact_history` + trigger `TR_maintenance_impact_history`; `changed_by` fallback chain; only records with `asset_id IS NULL` may escalate to `OutOfService` (`CK_maintenance_records_asset_scope_level`, disclosed [EXTENSION] — Section 4.2) |
| 6 | Escalation to `OutOfService` makes overlapping `Approved`/`CheckedIn` bookings identifiable to staff | [CONFIRMED] | `booking_alerts` + trigger `TR_maintenance_escalation` (`alert_type = 'MaintenanceEscalated'`); report (d) §1.3 → Task 16 |
| 7 | Selected space types may auto-approve eligible requests at submission time | [CONFIRMED] | `auto_approval_policies` + `policy_booking_types`; instant-booking procedure evaluates policy inside `SERIALIZABLE` transaction |
| 8 | Auto-approval decision stored in the same decision-record shape as a staff decision, distinguished by `decision_source` | [CONFIRMED] | `booking_decisions.decision_source` (`'Staff'`/`'System'`) + `decided_by` nullable + same-table `CK` pairing source with null-ness |
| 9 | Core invariant: no two `Approved`/`CheckedIn` bookings overlap on the same space, under concurrency, both paths | [CONFIRMED] | `SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)` conflict check; filtered index `IX_bookings_space_status_time`; retry on 1205/1222; `sp_getapplock` alternative; Phase 1 trigger as backstop |
| 10 | Reserved vs. actual occupancy: conflict checks use the reserved interval for `Approved`/`CheckedIn`; `Completed` blocks nothing | [EXTENSION] | Status-driven interval selection (Section 4.4); no new columns; overlap predicate `s1 < e2 AND e1 > s2` |
| 11 | Early check-out immediately releases the remaining reserved window; no claim for the early user | [EXTENSION] | Derived fact: booking `Completed` ⇒ drops out of blocking filter; `is_early_checkout` computed, never stored (3NF) |
| 12 | Facilities tracked as individual units with serial numbers; `quantity` eliminated | [EXTENSION] | `facility_assets` (`asset_id`, `serial_number` `UNIQUE`, `asset_status`); **direct `FK → spaces(space_id)`** plus an independent `CHECK` whitelist on `facility_name` (T-1); counts derived via view `v_space_facility_summary`; `facilities` **and** `space_facilities` both **dropped** (documented amendments, `AGENTS.md` §1a/§1b) |
| 13 | Maintenance records may optionally narrow an issue to a specific asset, in addition to always recording the affected space (rewritten per D-1 — no XOR) | [EXTENSION] | `maintenance_records.asset_id` (nullable) coexists with `space_id` (`NOT NULL`, immutable historical snapshot — Section 2.4); **no XOR** — the FD `asset_id → space_id` is refuted by a relocation counterexample (assets move between spaces); a Task 10 trigger enforces the creation-time invariant that a named asset must belong to the recorded space; `CK_maintenance_records_asset_scope_level` ([EXTENSION], disclosed with trade-offs in Section 4.2) forces asset-scoped records to `Advisory` |
| 14 | Booking blocked when a facility marked `required` for the space has no available unit | [EXTENSION] | `space_facility_requirements` (pure sparse junction, **direct `FK → spaces(space_id)`** plus its own `CHECK` whitelist, T-1) + trigger `TR_bookings_RequiredAssetCheck`; table's necessity is entirely downstream of this rule (T-2, §7 open question 2) |
| 15 | Report: total approved booking hours per space for a semester | [CONFIRMED] | Task 16 analytical query |
| 16 | Report: number of approved bookings by weekday and hour for a semester | [CONFIRMED] | Task 16 analytical query |
| 17 | Report: room finder — available spaces for required capacity + facility list within a time window | [CONFIRMED] | Task 16 query: `spaces` + `facility_assets`/`space_facility_requirements` (via `v_space_facility_summary`) + impact-level check; tuned in Task 15 |
| 18 | Report: approved bookings affected by escalation to out-of-service | [CONFIRMED] | Task 16 query over `booking_alerts` |
| 19 | SQL Server only — no PostgreSQL constructs anywhere in Phase 2 | [CONFIRMED] | All Tasks 08–16 use SQL Server syntax |
| 20 | Migration preserves Phase 1 data and documents the approach | [CONFIRMED] | Task 10 (**existing `outputs/10-schema-migration-G08.sql` is stale, S3 — generated pre-correction; must be regenerated from Output 08/09 as they now stand**): additive DDL for everything except the three documented exceptions — `facilities` dropped (§1a), `space_facilities` dropped (§1b), `user_accounts.role` dropped in favor of `user_roles` with a verified-row-count migration (§1c); `maintenance_records` gains a nullable `asset_id` column — `space_id` stays `NOT NULL` (Section 2.4) |
| 21 | Status vs. Impact reconciliation | [CONFIRMED] | Impact-level check on `maintenance_records`; `spaces.current_status` is **UI display only** |
| 22 | A user may legitimately hold more than one role (e.g., a Facility Manager who also books rooms as a requester) | [EXTENSION] | `user_roles(user_id, role)` junction (T-4) replaces the single-valued `user_accounts.role` column (documented amendment, `AGENTS.md` §1c); a cardinality/domain-fidelity correction, not a normalization fix; downstream staff-role checks become trigger-enforced cross-table invariants (Section 2.2) |

---

## 7. Assumptions and Open Questions (Phase 2)

**Assumptions carried forward** from Phase 1 (`business-requirement.md` §15) still hold: recurring bookings out of scope, capacity stored but not necessarily enforced, single-space bookings, etc.

**New assumptions:**

- Auto-approval eligibility is configured per space type (not per individual space), unless a specific-space override is needed — to be confirmed with the Facility Manager persona/TA.
- "Requester was informed" for an advisory is satisfied by the in-system acknowledgement at booking time; it implies no external notification channel.
- An auto-approval decision uses the same decision-record shape as a staff decision (§4.5).

**New open questions (to resolve before/during Task 09–10):**

1. **Losing request handling:** if two instant-booking requests race for the same slot, should the loser be auto-rejected, or automatically re-queued as `Pending` for manual review? (Product decision; not stated in either PDF.)
2. **"Required" facility definition:** what exactly makes a facility `required` for a space (§4.6)? Team-invented concept — needs confirmation before treated as gradeable scope. **Dependency chain (T-2):** rule R8 is the sole reason `space_facility_requirements` exists as a table at all, and rule R12 (relocation alerts) reads the same required-set data. If R8 is not confirmed as in-scope, both `space_facility_requirements` and R12 fall with it — this is not a hypothetical risk to a peripheral feature, it is the entire justification for that table's existence.
3. **No-show auto-release:** the proposal to auto-mark `NoShow` after 15 minutes and release the space is **unconfirmed**; Phase 1 left "who may cancel, and until when" open, and the 15-minute figure needs the same confirmation.
4. **Downgrade authority:** who may downgrade `OutOfService` → `Advisory`, and does downgrade automatically re-open the space, or must staff update `spaces.current_status` separately?
5. **Booking Approval vs. Maintenance Escalation Race:** a race condition exists where Staff A is approving a booking while Staff B is simultaneously escalating a maintenance record (`Advisory` → `OutOfService`) for the same space and time window. **Mechanism (L7):** the concurrency-safe primitives (`SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)`, or `sp_getapplock`) are shared across booking approval and maintenance escalation workflows, under the mandatory lock-ordering rule `bookings → maintenance_records → booking_alerts` (Section 5.5). **Current status: mechanism defined** (Section 5.5); what remains is **verification via concurrency testing in Task 12**, not open design work.

---

## 8. Quality Checklist

- [x] **Transition to MS SQL Server syntax explicitly mentioned** — Section 1.4 (§19 of the traceability matrix).
- [x] **Early Return case (Reserved vs. Actual time) addressed** — Section 4.4 (status-driven interval table, immediate release, derived `is_early_checkout`, §10–11 of the matrix).
- [x] **Out-of-service maintenance overlaps clearly identified as blocking** — Section 4.2 + impact-level check in Section 4.1, traceability rows 2, 4, 21.
- [x] **Escalation consequence (identifying affected bookings) detailed** — Section 4.3 (`booking_alerts` + `TR_maintenance_escalation`, report (d)), traceability rows 5–6.
- [x] **Concurrency race scenarios and SQL Server prevention logic** — Section 5 (`SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK`; `sp_getapplock`; filtered index; 1205/1222 retry; trigger as backstop).
- [x] **Quantity eliminated, `facilities` and `space_facilities` dropped, asset transition analyzed** — Sections 2.3a/2.3b/2.3c (`facility_assets` and `space_facility_requirements` linked directly to `spaces`, T-1; `v_space_facility_summary` view; `quantity` removed for genuine **3NF** reasons, Section 2.3a; `facility_id`/`facilities` removed as a **denormalization**, Section 2.3b; `space_facilities` removed as a **stored-projection redundancy**, Section 2.3c — both drops documented, `AGENTS.md` §1a/§1b).
- [x] **Maintenance targeting analyzed — no XOR needed** — Section 2.4 (semantic framing — `space_id` means "whose bookings are affected," not "where the asset is," T-3a; FD `asset_id → space_id` tested and refuted by a relocation counterexample; `space_id` stays `NOT NULL` as an immutable snapshot; `CK_maintenance_records_target_xor` removed; creation-time application invariant enforced by a Task 10 trigger; `CK_maintenance_records_asset_scope_level` retained but disclosed as [EXTENSION] — Section 4.2; two-table split considered and rejected, T-3c).
- [x] **Space-level vs. asset-level boundary defined** — Section 4.2 (T-3b: the boundary is operational — whether the failing thing is registered in `facility_assets` — not physical building-vs-equipment).
- [x] **Status vs. Impact reconciliation decided** — Section 4.1 (blocking queries `maintenance_records` for `OutOfService`; `spaces.current_status` display-only), traceability rows 2 and 21.
- [x] **`maintenance_impact_history.changed_by` fallback defined** — Sections 2.1 and 4.3, traceability row 5.
- [x] **`space_facility_requirements` kept, rationale replaced** — Section 4.6 (T-2: the table is structurally required because the required-facility policy must hold when zero units exist, not for sparsity/permissions reasons); its dependency on rule R8 kept visible in §7 open question 2.
- [x] **Multi-role users** — Section 2.2, traceability row 22 (`user_roles` junction replaces `user_accounts.role`, `AGENTS.md` §1c; cardinality correction, not normalization, T-4; downstream staff-role checks enumerated).
- [x] **3NF validation for the extended schema deferred to Task 09** — Section 1.5, with a worked mini-validation of `booking_advisory_acknowledgments` and the refuted-FD analysis (no XOR needed) in Section 2.4.
- [x] **Traceability matrix links the Blocking Rule to the Impact-level check** — rows 2, 17, 21.
- [x] **Academic terminology for the race condition** — Section 5.1 (check-then-act / lost-update / TOCTOU).
- [x] **Visual entity labeling** — Section 2: **8 tables [Added]**, **3 [Modified]** (`user_accounts`, `maintenance_records`, `booking_decisions`), **2 [Removed]** (`facilities`, `space_facilities`, both documented exceptions); **4 untouched** (`departments`, `spaces`, `bookings`, `usage_sessions`). **Total: 15 tables = 7 retained + 8 new.**
- [x] **Conceptual relationship bridge** — Section 3: Crow's Foot notation + Home ID / Visitor ID mapping.
- [x] **Scope boundary and downstream impact stated** — Section 1.6.

A full history of the corrections applied across all review passes is recorded in **Appendix A** rather than inline here, so this checklist states only what the current design achieves.

---

## Appendix A — Revision Notes (audit corrections)

This appendix preserves the full revision history that the body text no longer carries inline (Section 8's checklist points to design outcomes only). Grouped by review pass. Cross-reference: Output 09 carries its own Appendix A with the same ID scheme; several IDs (D-1 through D-3, and most L-IDs) touch both documents.

### Pass 1 — locked decisions (D-1, D-2, D-3)

| ID | Section(s) | What an earlier draft said | What it says now, and why |
|---|---|---|---|
| D-1 | §1.5, §2.4, §3, §4.1–4.3, §6, §7, §8 | An earlier draft argued that storing both `space_id` (`NOT NULL`) and `asset_id` (nullable) on `maintenance_records` creates a transitive dependency `maintenance_id → asset_id → space_id`, because an asset's location is "already known" via `facility_assets.space_id` — so `space_id` was made nullable and mutually exclusive with `asset_id` via `CK_maintenance_records_target_xor` (an XOR). | The suspected FD `asset_id → space_id` is refuted by a counterexample: projector **X** is installed in room **101**, breaks, and is repaired (maintenance record **M1**: `asset_id = X`, `space_id = 101`); it is then reinstalled in room **202**, breaks again (record **M2**: `asset_id = X`, `space_id = 202`). Two tuples share `asset_id` but differ on `space_id`, so the FD does not hold in every legal instance and is refuted. Because assets are permitted to relocate between spaces — a real business process — no transitive dependency exists, and `space_id` is an independent historical fact (the space *at the time the problem was reported*), not a redundant derivation. `space_id` reverts to `NOT NULL` (Phase 1 baseline, unchanged) and `CK_maintenance_records_target_xor` is removed. A supporting rule keeps this consistent: `space_id` is an immutable snapshot — when `facility_assets.space_id` later changes (the asset is relocated), existing `maintenance_records` rows are not updated to follow it. A Task 10 trigger enforces a creation-time-only application invariant: if `asset_id IS NOT NULL` at INSERT time, the asset must currently belong to the recorded `space_id`. |
| D-2 | §2.1 (`space_facility_requirements` row) | An earlier draft justified the sparse, attribute-free shape of `space_facility_requirements` as "3NF: pure junction, no non-key attributes." | That justification is wrong — a plain `is_required BIT NOT NULL DEFAULT 0` column on `space_facilities` would satisfy 3NF equally well (full dependency on the whole key, no partial or transitive dependency). Normalization does not decide between the two designs. The real reasons, disclosed as [EXTENSION]: sparsity (the "required" set is small, so a boolean column would read `0` almost everywhere), presence-as-semantics (rule R8 reads the row set via `EXISTS`/`NOT EXISTS`, with no `NULL`/garbage-value state to guard against), and separable permissions/auditing (declaring a facility "required" can be a distinct permission and audit trail from catalogue writes). Full rationale in Output 09 §5.7/§8.2. |
| D-3 | §2.2, §2.4, §4.2, §4.3, §6 | An earlier draft retained `CK_maintenance_records_asset_scope_level` (forcing asset-scoped records to `Advisory`, never `OutOfService`) without flagging it as anything other than an implied requirement. | The constraint is disclosed as **[EXTENSION]** — it does not appear in `CS486_Project_Phase02.pdf`; it is a team design decision. Trade-off stated honestly: a room with only one air conditioner genuinely becomes unusable when that unit fails, yet an asset-scoped record cannot escalate to `OutOfService` to reflect that. Compensating workflow: staff file an additional space-level record (`asset_id = NULL`, `impact_level = 'OutOfService'`), or rely on rule R8 (`space_facility_requirements`) when the failed unit is the last available one. Benefit: the `OutOfService` blocking query never has to distinguish space-level from equipment-level records. |

### Pass 1 — lettered defects (L1–L20; only those with a location in this document)

| ID | Section(s) | What an earlier draft said | What it says now, and why |
|---|---|---|---|
| L1 | §2.2 (`space_facilities` row) | An earlier draft asserted the dropped default constraint was literally named `DF_space_facilities_quantity`. | `quantity`'s `DEFAULT 1` is declared inline and unnamed in the Phase 1 DDL (`outputs/05-db-definition-G08.sql:103`: `quantity INT NOT NULL DEFAULT 1`, no `CONSTRAINT` clause) — SQL Server auto-generates a name such as `DF__space_fac__quant__3B75D760`, so Task 10 must resolve the real name via `sys.default_constraints` before dropping it. `CK_space_facilities_quantity`, by contrast, **is** explicitly named in the Phase 1 DDL and is dropped by that name. |
| L2 | §4.2 | An earlier draft's advisory-ack completeness check compared `COUNT(DISTINCT active advisory)` against `COUNT(DISTINCT acknowledged)`. | Counting is not equivalent to set containment: if a booking acknowledged advisory #1 (now `Completed`) while a different advisory #2 is newly active and unacknowledged, the counts `1 = 1` would pass incorrectly. Replaced with a set-based `NOT EXISTS` existence test (shown in full in §4.2) that directly checks whether any active advisory lacks a matching acknowledgement row. |
| L7 | §5.5, §7 (open question 5) | An earlier draft did not specify a lock-acquisition order between the booking-approval and maintenance-escalation workflows. | Both workflows touch `bookings` and `maintenance_records`; without a fixed order they could acquire these tables in opposite sequences — a textbook deadlock setup. A mandatory lock-ordering rule is added: any transaction touching both tables (directly or via `booking_alerts`) must acquire locks in the fixed order `bookings → maintenance_records → booking_alerts`, even though escalation logically reads `maintenance_records` first. Deadlocks remain possible regardless (ordering reduces, not eliminates, contention), so bounded retry on 1205/1222 stays mandatory. |
| L8 | §4.5 | An earlier draft did not state what happens when both a type-wide `auto_approval_policies` row and a specific-space override could apply to the same space, nor prevent two active type-wide policies for the same `space_type`. | Precedence rule added: the specific-space override always wins; the type-wide policy is ignored entirely for that space. A filtered unique index (Output 09 §5.14/§10, I17) additionally guarantees at most one active type-wide policy per `space_type`, making eligibility evaluation deterministic. |
| L9 | §2.1 (`auto_approval_policies` row) | An earlier draft included a `requires_advisory_ack` column on `auto_approval_policies`. | The column was never read — advisory acknowledgement is a mandatory legal constraint on every approval path (§4.2), not a per-policy configuration knob. The dead column is dropped rather than kept unused. |
| L10 | §4.2 | An earlier draft did not state that `booking_advisory_acknowledgments.maintenance_id` must reference an `Advisory` record. | Application invariant added: a booking should never be able to "acknowledge" an `OutOfService` record, since `OutOfService` never requires acknowledgement. This cannot be a `CHECK` (it spans two tables); it is enforced by a Task 10 trigger. |
| L11 | §2.1, §4.2 | An earlier draft's `booking_alerts.alert_type` enumeration covered only `MaintenanceEscalated` and `RequiredAssetRelocated`, with no mechanism for a newly-filed advisory against a space that already has approved bookings. | A third `alert_type` value, `AdvisoryAddedAfterApproval`, is added ([EXTENSION]). Chosen behavior: a newly-filed advisory does not retroactively invalidate an already-`Approved` booking; instead a trigger writes a `booking_alerts` row so staff (and through them the requester) are informed. `CK_booking_alerts_source_scope` gains a matching branch. |
| L12 | §2.1 | An earlier draft did not address facility types with no manufacturer serial number (whiteboards, furniture, power outlets) under a `NOT NULL UNIQUE serial_number` column. | Policy stated: `serial_number` stays `NOT NULL UNIQUE`; units with no manufacturer serial are assigned an internal identifier following the scheme `<space_code>-<FACILITY>-<seq>` at asset-creation time, so `serial_number` remains a valid candidate key regardless of origin. |
| L13 | §2.3b | An earlier draft titled the `facilities`-flattening change "3NF-driven." | That label is wrong: `facilities(facility_id PK, facility_name UNIQUE, description)` was already in BCNF on its own — removing an already-normalized lookup table improves no normal form. Retitled as a deliberate denormalization, tagged [EXTENSION], and split from the genuinely-3NF `quantity` removal into two subsections: §2.3a (quantity, real 3NF) and §2.3b (facilities flattening, denormalization). |
| L15 | §2.3b | An earlier draft repeated the "why `space_id` must stay a physical column in `facility_assets`" explanation in more than one place. | The physical-necessity explanation (a SQL Server composite FK constrains columns that already exist in the child table; it cannot conjure a location out of a link alone) is kept once, in Output 09 §5.6, and referenced from here rather than duplicated. |

### Pass 2 — index and cross-reference defects (R1–R8)

Of the eight Pass 2 defects, only three have a location in this document; the remaining five (R1, R3, R5, R6, R8) are Output 09-only (indexing and ERD-notation defects) and have no corresponding content here.

| ID | Section(s) | What an earlier draft said | What it says now, and why |
|---|---|---|---|
| R2 | §2.2 | An earlier draft listed `impact_level`'s rationale as backfilling legacy rows "and then drops the default," without stating explicitly, in the same terms as Output 09, that the final schema carries no default at all. | Reworded so both documents read identically: `DEFAULT 'OutOfService'` is a migration-only artifact — Task 10 adds it via `ALTER TABLE ... ADD impact_level NOT NULL DEFAULT 'OutOfService'` purely to backfill legacy Phase 1 rows, then drops the default in the same script. In the final schema, `impact_level` is `NOT NULL` with no default — every new record must supply an impact level explicitly, since it is a Facility Manager judgment call that must never be silently defaulted. |
| R4 | §3 (relationship table), §8 | Two references to the pre-split "Section 2.3" survived the L13 split into §2.3a/§2.3b without being repointed. | Both repointed: the `facilities → space_facilities [Removed]` row now cites §2.3b (the denormalization topic); the checklist's quantity/facilities item now cites §2.3a for the quantity/3NF claim and §2.3b for the facility_id/denormalization claim. |
| R7 | §8 | The checklist item for this row credited both "`quantity`/`facility_id` removed for 3NF" as a single, undifferentiated claim. | Split to match the body: `quantity` removal is credited to 3NF (§2.3a); `facility_id` removal is credited to the denormalization that drops `facilities` (§2.3b), not to normalization. |

### Pass 3 — substantive defects (S1–S3) and structural cleanup

| ID | Section(s) | What changed, and why |
|---|---|---|
| S1 | (no location in this document) | The `usp_CompleteBooking` scoping defect is Output 09 §9.5-only; Output 08 §5.5 never named specific procedures, so no matching wording existed here to fix. |
| S2 | §4.5 | The auto-approval eligibility description used a plain `expected_participants <= min(space capacity, max_participants)` comparison. Because `max_participants` is nullable and SQL Server's three-valued logic evaluates `x <= NULL` to `UNKNOWN` (not `TRUE`), a policy with no configured cap would silently never auto-approve — the opposite of the intended "no cap" meaning. Rewritten as `(max_participants IS NULL OR expected_participants <= max_participants) AND expected_participants <= spaces.capacity`. |
| S3 | §1.6, traceability row 20 | Three passages asserted `outputs/10-schema-migration-G08.sql` "does not exist yet" / "not yet generated." The file is in fact present in the repository, generated against a pre-correction schema (it still creates `IX_alerts_open` on `(acknowledged_at)`, retains `DF_maintenance_records_impact_level`, and predates every D-/L-/R- correction). Reworded to state accurately that the file exists but is **stale** and must be regenerated from Output 08/09 as they now stand before Task 11 or any later task consumes it. |
| Structural | Whole document | Pass 3 relocated ~15 inline "an earlier draft said X, now Y" passages into this appendix, leaving the body in present tense with bare pointers (e.g., "(Appendix A, L2)") where a reader needs to know a design choice was deliberated. [EXTENSION] disclosures, the D-1 refuted-FD proof, the lock-ordering rule, and the `space_id`-immutable-snapshot rule remain in the body in full — they are substantive design content, not revision history. The two catch-all "Audit corrections applied" checklist bullets are removed; their content is fully preserved above rather than deleted. |

### Pass 4 — model changes from design review (T-0–T-5)

Unlike Passes 1–3, these are real schema changes arising from a design review, not corrections of wording. Two require new documented baseline amendments.

| ID | Section(s) | What the design was | What it is now, and why |
|---|---|---|---|
| T-0 | §1.2, §1.6, `AGENTS.md` | `AGENTS.md` §1a authorized exactly one baseline exception (`facilities`). | Two more amendments added: `AGENTS.md` §1b (`space_facilities` table drop) and §1c (`user_accounts.role` column drop), both authorized by Truong Thi My Duyen (24125028), Senior Lead Database Architect. Every "one documented exception" / "one exception" sentence in this document is updated to "three documented exceptions" or lists all three explicitly. |
| T-1 | §1.2, §1.3, §2, §2.1, §2.2, §2.3b, §2.3c (new), §3, §4.6, §6 (rows 12/14/17/20), §8 | `space_facilities` existed as the catalogue table declaring which facility types a space is equipped with, keyed by composite `(space_id, facility_name)`; `facility_assets` and `space_facility_requirements` linked to it via composite FK. | `space_facilities` is **dropped entirely** (`AGENTS.md` §1b) — its key pair was a stored projection of `facility_assets` (`SELECT DISTINCT space_id, facility_name FROM facility_assets`), its `condition` duplicated `facility_assets.condition` (the L4 defect, now resolved structurally instead of by explanation), and its `note` had no consumer. `facility_assets.space_id` becomes a plain `FK → spaces(space_id)`; `facility_name` becomes an independently `CHECK`-constrained column on both `facility_assets` and `space_facility_requirements` (two whitelists to keep in sync manually — the compounded cost of §1a + §1b). The one thing genuinely lost — recording "space A has facility type T" while zero units exist — is verified to have no consumer in this design except `v_space_facility_summary` (Output 09 §6), which is why that view's `UNION`-based rebasing is load-bearing, not cosmetic. New Section 2.3c documents the full reasoning; §2.3b is retained as historical record of the earlier `facilities`-only amendment, with a forward pointer added. |
| T-2 | §2.1, §4.6, §7 (open question 2) | D-2's rationale for keeping `space_facility_requirements` as a separate table cited sparsity, presence-as-semantics, and separable permissions. | That rationale is replaced entirely: sparsity is not a reason (a `BIT` column is bit-packed, "mostly zero" costs nothing); presence-as-semantics is not a reason (`is_required = 1` and row-existence are equally checkable); separable permissions is not a reason (this project has no permission model in scope). The real reason, visible only after T-1: "space A may not be booked without a working projector" is a policy about the space that must hold when the space has **zero** projectors — it cannot live on `facility_assets` (assets come and go) and, after T-1, there is no `space_facilities` left to host it either. A separate relation is structurally required. The dependency on rule R8 (itself an unconfirmed [EXTENSION], §7 open question 2) is now stated explicitly: if R8 is dropped, this table and rule R12 go with it. The original D-2 rationale (§2.1, superseded) is preserved in the Pass 1 table above rather than deleted twice. |
| T-3 | §2.4, §4.2 (new subsection) | The refuted-FD proof for `maintenance_records.space_id`/`asset_id` stood alone, with no semantic framing for why the formal proof matters, no definition of the space-level/asset-level boundary, and no record of alternative designs considered. | (a) Semantic framing added before the proof: `space_id` means "whose bookings are affected," not "where the asset is" — compared to an invoice's `shipping_address` coexisting with a customer's current `address`. (b) New §4.2 subsection defines the boundary as operational, not physical: whether the failing thing is registered in `facility_assets`, not "building vs. equipment" — the same physical AC failure is asset-level if units are tracked, space-level if the building runs untracked central HVAC. (c) A two-table split (`maintenance_records_space` / `maintenance_records_asset`) is recorded as considered and rejected: it would reintroduce a nullable-FK XOR in three child tables, create colliding `IDENTITY` values across two parents, and turn every space-scoped query into a `UNION`, for the sole benefit of `asset_id NOT NULL` on one table. No schema change resulted from T-3; the documentation is strengthened. |
| T-4 | §1.2, §1.3, §2.1, §2.2, §3, §6 (row 22) | `user_accounts.role` was a single-valued `NVARCHAR(30)` column with a `CHECK` whitelist, unable to represent a person holding more than one role. | `role` and `CK_user_accounts_role` are dropped; a new `user_roles(user_id, role)` junction (composite PK, no non-key attributes, same shape as `policy_booking_types`) replaces it (`AGENTS.md` §1c). Migration: create `user_roles`, `INSERT INTO user_roles (user_id, role) SELECT user_id, role FROM user_accounts`, verify row counts match, then drop the column. Recorded explicitly as a **cardinality/domain-fidelity correction, not a normalization fix** — the single-valued column violated neither 1NF nor 3NF. Downstream, four role checks that were `CHECK`-enforceable on one column become trigger-enforced cross-table invariants, enumerated in §2.2 (`booking_decisions.decided_by`, `maintenance_records.assigned_staff_id`, `booking_alerts.acknowledged_by_staff_id`, `maintenance_impact_history.changed_by`'s fallback chain). |
| T-5 | §1.2, §1.3, §2, §6, §8 | Table and relation counts from Pass 3 (7 new + 3 modified = 10 relations validated; "8 of 9 Phase 1 tables retained") predate T-1's second table drop and T-4's new table. | Recomputed from scratch: Phase 1 had 9 tables; 2 are now dropped (`facilities` §1a, `space_facilities` §1b) → **7 retained**. Of those 7: **3 modified** (`user_accounts` — role dropped; `maintenance_records` — `asset_id`/`impact_level` added; `booking_decisions` — `decision_source` added, `decided_by` relaxed) and **4 unchanged** (`departments`, `spaces`, `bookings`, `usage_sessions`). **8 new tables** (the 7 from Pass 1 plus `user_roles`). **Total: 15 = 7 + 8.** Every count sentence in §1.2, §1.3, §2, §6, and §8 is re-derived rather than assumed carried over — "3 modified" is coincidentally the same number as before Pass 4, but a different set (`space_facilities` leaves the modified set by being dropped; `user_accounts` joins it). |

### Pass 5 — reconciliation against the tested migration script (B1–B8)

Building and running `outputs/10-schema-migration-G08.sql` against a populated Phase 1 database (idempotency proven; rollback proven) surfaced defects that live in the design documents, not in the script — the script already works around all of them. Of the eight Pass 5 defects, only two have primary content in this document (B6, B8); B1–B5 and B7 are Output 09-only (index/trigger/NULL-semantics corrections) and have no corresponding wording here — see Output 09's Appendix A for those.

| ID | Section(s) | What this document said | What it says now, and why |
|---|---|---|---|
| B6 | §2.3d (new) | Sections 2.3a–2.3c stated that `space_facilities` is dropped because its key pair is a stored projection of `facility_assets`, but never stated that at migration time the dependency runs the **other way**: `space_facilities` holds the only record of what equipment each space has, and `facility_assets` starts empty. | Total data loss if the drop is not preceded by an expansion step — not previously stated anywhere in either document. New §2.3d specifies the expansion: each `(space_id, facility_id, quantity)` row expands into `quantity` `facility_assets` rows, resolving `facility_id → facility_name` through `facilities` while it still exists; `serial_number` uses the `<space_code>-<FACILITY>-<seq>` scheme (Output 09 §5.6, L12) for units with no manufacturer serial; Phase 1 `condition`/`note` text is carried onto every generated unit; and `asset_status` is seeded `UnderMaintenance` **only where `quantity = 1`** (decision A1, [EXTENSION]) — multi-unit groups are seeded `Available` with the condition text preserved, since the text describes the group and cannot be pinned to one unit, and mis-seeding would make rule R8 block bookings over units that are actually fine. Stated explicitly as Task 10's data-preservation responsibility, distinct from Task 14's data generation (≥ 3 academic years, ≥ 100,000 bookings). |
| B8 | §4.1 | §4.1 said the Phase 1 trigger `TR_bookings_PreventOverlapAndUnavailable` "stays" as a backstop but never stated it must be **modified** — leaving a reader to assume "stays" meant "stays unchanged." | Three required changes are now specified: (1) remove `'UnderMaintenance'` from the trigger's `spaces.current_status` check — that column is never a maintenance-blocking predicate under this section's decision, so leaving it in would wrongly block a space flagged for advisory-only reasons; `TemporarilyClosed` and `Retired` stay. (2) Extend the overlap check from `status = 'Approved'` to `status IN ('Approved','CheckedIn')`, matching the status-driven interval selection of Section 4.4. (3) Add the `OutOfService` impact-level check, querying `maintenance_records` directly, so the trigger backstops the *current* blocking rule rather than the superseded `current_status`-based one. It remains a validation backstop only — the concurrency mechanism stays Task 12's `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK` procedures (Section 5). Output 09 §7 names the trigger inventory in full and adds a standing note on the `TRIGGER_NESTLEVEL` re-entry guard used by all 14 Task 10 triggers (B8, Output 09-only). |
