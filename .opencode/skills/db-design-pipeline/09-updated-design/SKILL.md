---
name: 09-updated-design
description: Update the Phase 1 ERD and relational schema for Phase 2 — maintenance impact levels, per-booking advisory acknowledgements, and concurrency-safe booking — without breaking Phase 1 relationships.
compatibility: opencode
---

# Step 09: Updated Conceptual ERD + Logical Design Skill

This skill is the **evolving quality rubric and behaviour guide** for producing `outputs/09-updated-erd-and-logical-design-G08.md`. It is **not a hard-coded answer**. The design must be **derived from the inputs**: extend the Phase 1 baseline (Outputs 02 and 03) with the Phase 2 decisions bound in Output 08. Every Phase 1 table/column stays verbatim.

## 1. Purpose

Task 09 produces the **extended design deliverable** for Task 10 (schema migration). It delivers two artefacts that together support the **three pillars of Phase 2**:

1. **Maintenance Impact Levels** — `maintenance_records.impact_level` (`Advisory` / `OutOfService`) plus a `maintenance_impact_history` escalation audit trail.
2. **Advisory Acknowledgements** — `booking_advisory_acknowledgments` as the mandatory link between a booking and every active advisory on its space.
3. **Concurrent Booking Support** — the schema shape that lets simultaneous booking/approval be serialized correctly (auto-approval policy, `booking_decisions.decision_source`, and the filtered index `IX_bookings_space_status_time` as the structural range-locking requirement).

Task 09 is also where the full **1NF/2NF/3NF audit of the extended schema** (deferred from Output 08 §1.5) is formally performed, one worksheet per newly defined/changed relation.

## 2. Required inputs

- `outputs/08-requirement-change-analysis-G08.md` — **immediate previous-step authority (binding)**: §2 (tables/columns), §3 (relationships + Home/Visitor bridge), §4 (business rules, incl. the concurrency/trigger pattern), §6 (traceability matrix).
- `outputs/02-erd-design-G08.md` — **Phase 1 Conceptual ERD**; the updated ERD overlays it, never overwrites it.
- `outputs/03-logical-design-G08.md` — **Phase 1 Logical Schema**; the updated schema extends it additively.
- `outputs/01-business-req-analysis-G08.md` — business-rule traceability (context only).
- `AGENTS.md` — §2 (source-of-truth, Step Precedence), §3 (Mermaid rendering, Home ID vs. Visitor ID, Relationship Labeling), §4 (SQL Server rules).
- `.opencode/skills/db-design-pipeline/02-erd-design/SKILL.md`, `03-logical-design/SKILL.md`, `SKILL.md` — Step 2/3 conventions and shared pipeline rules.

## 3. Scope and safety discipline

- **Extend, do not regenerate.** Output 09 is a new document; it must not overwrite or rename anything in Outputs 01–03.
- **Keep Phase 1 structures verbatim.** No Phase 1 table, column, or enum value may be renamed, dropped, or repurposed. Phase 2 only **adds** tables/columns and, where Output 08 specifies, changes nullability on `booking_decisions.decided_by`.
- **No executable DDL in Task 09** (Task 10's scope). SQL Server types and key-structure choices are referenced as design decisions only.

### 3.4 Logical Schema Diagram Standard

In addition to the Conceptual ERD, the agent MUST produce a **Detailed Logical Schema Diagram** using Mermaid `erDiagram`.

- **Table Boxes:** each box must list every column in the table.
- **Physical Markers:** use `PK`, `FK`, and `UK` labels inside the Mermaid boxes for every key.
- **Data Types:** include the specific MS SQL Server data types (e.g., `int`, `nvarchar`, `datetime2`) in the diagram boxes.
- **Relationship Labels:** label every relationship line with the actual Foreign Key column name (e.g., `||--o{ : "requester_id"`).
- **Scope:** the diagram must show the full extended schema (Phase 1 + Phase 2 tables).

## 4. Logical Mapping Standard

Every table in the updated Logical Schema MUST be documented using this standard. The **full Data Dictionary** covers all **9 Phase 2 affected tables** — the 7 new tables plus the 2 modified tables (Phase 1 columns on the modified tables are restated, not omitted).

### 4.1 Per-table Data Dictionary format

For **every** table, produce a markdown table with exactly these headers:

| Column | Data Type | Constraints (PK/FK/UK/NN) | Description |
|---|---|---|---|

- **Column** — the column name.
- **Data Type** — a specific MS SQL Server type (`INT IDENTITY`, `NVARCHAR(n)`/`NVARCHAR(MAX)`, `DATETIME2`, `BIT`, `DATE`); no generic types.
- **Constraints (PK/FK/UK/NN)** — mark **PK** (primary key), **FK** (foreign key, with target), **UK** (unique/candidate key), and **NN** (NOT NULL) on each column, plus any **CHECK**/DEFAULT noted in the description column when not expressible in the header.
- **Description** — one-line purpose of the column.

### 4.2 FK Enforcement (trace back to Home ID)

Every Foreign Key MUST be explicitly traced back to its Home ID — the column and table where the identifier is defined. Write the target explicitly:

- `maintenance_id` `FK` → `maintenance_records.maintenance_id`
- `booking_id` `FK` → `bookings.booking_id`
- `asset_id` `FK` → `facility_assets.asset_id`
- `acknowledged_by` `FK` → `user_accounts.user_id`

Do not write a bare FK without its target table + column. This gives 100% traceability from the Visitor ID (dependent table) to the Home ID (defining table).

### 4.3 Candidate Key Audit (natural UKs)

Explicitly identify every natural **candidate key** as a **UK** — do not rely on a UNIQUE constraint being implied. At minimum, name:

- `facility_assets.serial_number` — natural UK (unique physical unit identifier).
- `facility_assets (space_id, facility_id, serial_number)` — composite natural UK.
- `booking_advisory_acknowledgments (booking_id, maintenance_id)` — composite natural UK (one ack per advisory per booking); base the 2NF analysis on this natural key, not the surrogate `ack_id`.
- `space_facility_requirements (space_id, facility_id)` — composite (already the PK).
- `auto_approval_policies` — `space_id` / `space_type` when set (mark inferred / team-confirm if not confirmed).

List candidate keys explicitly per relation in the Data Dictionary and in the candidate-key summary.

### 4.4 Index Design (physical structural requirement)

The filtered index **`IX_bookings_space_status_time`** must be recorded in the logical design as a **physical structural requirement**, not an optional suggestion:

- Definition: on `bookings (space_id, requested_start_time, requested_end_time)` `WHERE status IN ('Approved','CheckedIn')` (non-clustered, filtered).
- Purpose: it is what enables `SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)` key-range locking on the conflict check (Output 08 §5.5). Without it, SQL Server may escalate to a table lock (still correct, less concurrent).
- State the definition and its role in design-strategy terms; the `CREATE INDEX` DDL belongs to Task 10 / Task 15.

Also justify the supporting Phase 2 indexes (e.g., `facility_assets (space_id, facility_id, asset_status)`, `maintenance_records (space_id, status, impact_level, start_time, completion_time)`) each with its use case.

### 4.5 Referential Integrity (additive FK discipline)

- **Phase 1 FKs remain unchanged.** All 14 Phase 1 FK relationships from Output 03 are preserved exactly — no FK is dropped, renamed, re-targeted, or re-purposed.
- **Phase 2 FKs are added additively.** New FKs (e.g., `maintenance_records.asset_id → facility_assets(asset_id)`, `booking_advisory_acknowledgments.maintenance_id → maintenance_records(maintenance_id)`) are new constraints on new or existing tables; the only nullability change permitted is `booking_decisions.decided_by` becoming nullable (Output 08 §2.2).
- State this discipline in the Relationship-to-FK mapping: one row per Phase 1 + new relationship, marking which are Phase 1 (unchanged) and which are Phase 2 (added).

## 5. Pillar 1 — Maintenance impact levels

### 5.1 Conceptual

- Extend `maintenance_records` conceptually with the descriptive attribute `impact_level` (the entity keeps only its own Home ID).
- Add the new entity `maintenance_impact_history` — the escalation/downgrade audit trail.
- Add the Crow's Foot leg `maintenance_records` `1 ── 0..N` `maintenance_impact_history`.
- Escalation consequence: add `booking_alerts`, linked from both `maintenance_records` and `bookings`, so an escalation to `OutOfService` can surface every already-`Approved`/`CheckedIn` overlapping booking.

### 5.2 Logical

**maintenance_records** (Phase 1, [Modified]):
- Add `impact_level` NVARCHAR(20) NOT NULL — CHECK `('Advisory','OutOfService')`; set on migration via DEFAULT, then the DEFAULT is dropped (Task 10).
- Add `asset_id` INT NULL — FK → `facility_assets.asset_id`; NULL = space-level (Phase 1 behavior); never blocks the space by itself.

**maintenance_impact_history** [new] — `history_id` INT IDENTITY (PK); `maintenance_id` INT NOT NULL (FK → `maintenance_records.maintenance_id`); `old_impact_level` NVARCHAR(20) NULL (NULL on creation); `new_impact_level` NVARCHAR(20) NOT NULL (CHECK `('Advisory','OutOfService')`); `changed_by` INT NOT NULL (FK → `user_accounts.user_id`, resolved via the fallback chain, never NULL); `changed_at` DATETIME2 NOT NULL; `change_reason` NVARCHAR(200) NULL.

Record a design note for the `changed_by` fallback: `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), assigned_staff_id, reporter_id)` on UPDATE and `reporter_id` on INSERT (Output 08 §2.1); the trigger that uses it belongs to Task 10.

## 6. Pillar 2 — Advisory acknowledgements

### 6.1 Behaviour (from Output 08 §4.2)

- `Advisory` maintenance never blocks booking; it only triggers the acknowledgement requirement.
- Before a booking can be finalized `Approved`, **each** active advisory on the space must have **one** acknowledgement stored against the booking.
- SQL Server has no deferred triggers, so enforcement relies on a documented statement order in the booking transaction: insert booking as `Pending` → insert acknowledgement rows → update status to `Approved`.

### 6.2 Conceptual

- Add the associative entity `booking_advisory_acknowledgments`.
- Resolve the M↔N link between `bookings` and `maintenance_records` through it: draw two legs — `bookings` `1 ── 0..N` `booking_advisory_acknowledgments` and `maintenance_records` `1 ── 0..N` `booking_advisory_acknowledgments` — never a direct M–N line.

### 6.3 Logical

**booking_advisory_acknowledgments** [new] — `ack_id` INT IDENTITY (PK, surrogate, FK-ergonomics only); `booking_id` INT NOT NULL (FK → `bookings.booking_id`); `maintenance_id` INT NOT NULL (FK → `maintenance_records.maintenance_id`); `acknowledged_by` INT NOT NULL (FK → `user_accounts.user_id`); `acknowledged_at` DATETIME2 NOT NULL DEFAULT GETDATE().

- **Natural candidate key `UNIQUE (booking_id, maintenance_id)`** — one ack per advisory per booking (the composite identifies the row; base the 2NF analysis on this natural key, not the surrogate `ack_id`).

## 7. Pillar 3 — Concurrent booking support

### 7.1 Structural requirements for serialization

- **`booking_decisions.decision_source`** — auto-approval stores a decision in the same shape as a staff decision, distinguished by source. Add `decision_source` NVARCHAR(10) NOT NULL DEFAULT `'Staff'` CHECK `('Staff','System')`; change `decided_by` from `NOT NULL` to `NULL` with a same-table pairing CHECK — `(decision_source='System' AND decided_by IS NULL) OR (decision_source='Staff' AND decided_by IS NOT NULL)`. A nullable FK is preferred over a sentinel "SYSTEM" user row.
- **`auto_approval_policies`** + **`policy_booking_types`** — eligibility config and its allowed booking types (SQL Server has no array type, hence the junction).
- **Filtered index `IX_bookings_space_status_time`** — the structural requirement enabling key-range locking on the conflict check. Record it in the logical design as a just-proposed index on `bookings (space_id, requested_start_time, requested_end_time) WHERE status IN ('Approved','CheckedIn')`. Document (in design-strategy terms) that it backs `SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)` range locking; the procedure and index DDL belong to Tasks 11–13/15.

### 7.2 Logical definitions

**auto_approval_policies** [new] — `policy_id` INT IDENTITY (PK); `space_type` NVARCHAR(30) NULL; `space_id` INT NULL (FK → `spaces.space_id`); CHECK that exactly one of `space_type`/`space_id` is set; `max_participants` INT NULL; `requires_advisory_ack` BIT NOT NULL DEFAULT 1; `is_active` BIT NOT NULL DEFAULT 1; `created_at`, `updated_at` DATETIME2 NOT NULL.

**policy_booking_types** [new] — `policy_id` INT NOT NULL (FK → `auto_approval_policies.policy_id`); `booking_type` NVARCHAR(30) NOT NULL CHECK matching `CK_bookings_booking_type`; composite PK (`policy_id`, `booking_type`).

**booking_decisions** (Phase 1, [Modified]) — keep all Phase 1 columns; add `decision_source` and change `decided_by` to nullable per §7.1.

Concurrency design strategy (state, don't restate): the instant and manual approval paths must share one serialized conflict check (Output 08 §5); the Phase 1 overlap trigger remains a backstop only.

## 8. Facility asset tracking for granular maintenance reporting

**facility_assets** [new] — `asset_id` INT IDENTITY (PK); `facility_id` INT NOT NULL (FK → `facilities.facility_id`, catalogue type); `space_id` INT NOT NULL (FK → `spaces.space_id`, current location); `serial_number` NVARCHAR(40) NOT NULL UNIQUE; `asset_status` NVARCHAR(20) NOT NULL CHECK `('Available','InUse','UnderMaintenance','Retired')`; `condition` NVARCHAR(200) NULL; `last_checked_date` DATE NULL; `created_at`, `updated_at` DATETIME2 NOT NULL. **Candidate keys:** `serial_number` and the composite `(space_id, facility_id, serial_number)`.

- **Granular maintenance reporting:** a maintenance record may target a single unit (`maintenance_records.asset_id`), and "one of several AC units is down" becomes a trackable asset state rather than a note-field sentence.
- `space_facilities.quantity` stays as Phase 1 catalogue metadata; unit counts are **derived via the view `space_facility_summary`**, never stored (§10).

**space_facility_requirements** [new] — `space_id` INT NOT NULL (FK → `spaces.space_id`); `facility_id` INT NOT NULL (FK → `facilities.facility_id`); `is_required` BIT NOT NULL DEFAULT 1; composite PK (`space_id`, `facility_id`). **Sparse-list convention:** presence in the table means "required"; do not insert `is_required = 0` rows. Supports the required-asset availability block (Output 08 §4.6).

## 9. Relationship-to-FK mapping and indexes

- One row per Phase 1 + **new** relationship mapping the Crow's Foot line to its FK column(s)/junction, including the new links of §§5–8; **never alter an existing Phase 1 FK** (additive discipline per §4.5). Mark each row as **[Phase 1, unchanged]** or **[Phase 2, added]**.
- Index recommendations (logical): the conflict-check filtered index `IX_bookings_space_status_time` (§4.4, §7.1), an index on `facility_assets (space_id, facility_id, asset_status)`, and a supporting unique index for `facility_assets.serial_number`. Implementation references Task 15.

## 10. Derived fact policy (must NOT be stored)

- **Unit counts are derived, never stored.** No `total_units`/`available_units` column anywhere; describe the view `space_facility_summary` computing `total_units`/`available_units` per `(space_id, facility_id)` from `facility_assets` rows (its `CREATE VIEW` belongs to Task 10).
- **`is_early_checkout` is a derived fact**, computed at query time (`actual_end_time < requested_end_time`), never stored.
- Utilization queries use `COALESCE(usage_sessions.actual_start_time/actual_end_time, bookings.requested_start_time/requested_end_time)`.

## 11. Home ID vs. Visitor ID enforcement boundary

**Only in the Logical Schema do Visitor (FK) columns exist; the Conceptual ERD shows Home IDs only, via relationship lines.**

- `asset_id` — Home in `facility_assets`; Visitor in `maintenance_records.asset_id`.
- `booking_id` — Home in `bookings`; Visitor in `booking_advisory_acknowledgments.booking_id`, `booking_alerts.booking_id`.
- `maintenance_id` — Home in `maintenance_records`; Visitor in `maintenance_impact_history.maintenance_id`, `booking_advisory_acknowledgments.maintenance_id`, `booking_alerts.maintenance_id`.
- `facility_id` — Home in `facilities`; Visitor in `facility_assets.facility_id`, `space_facility_requirements.facility_id`.
- `space_id` — Home in `spaces`; Visitor in `facility_assets.space_id`, `space_facility_requirements.space_id`, `auto_approval_policies.space_id`.

No Phase 1 Home ID changes place; the only cardinality change is `booking_decisions.decided_by` becoming optional.

## 12. 3NF validation audit — the 9 tables

This is the **formal 1NF/2NF/3NF audit** deferred from Output 08 §1.5. Write **one worksheet per each of the 9 tables** identified in Output 08 — the 7 new (`facility_assets`, `booking_advisory_acknowledgments`, `maintenance_impact_history`, `auto_approval_policies`, `policy_booking_types`, `space_facility_requirements`, `booking_alerts`) plus the 2 modified (`maintenance_records`, `booking_decisions`). For each record:

- **FDs**; primary key and natural/main **candidate keys** (surrogate vs. natural), noting which key 2NF uses.
- **1NF** — atomic, single-valued, no repeating groups.
- **2NF** — no partial dependency on a composite key (for the associative `booking_advisory_acknowledgments`, `policy_booking_types`, `space_facility_requirements` verify every non-key attribute is a function of the full pair).
- **3NF** — no transitive dependency (e.g. the advisory description stays in `maintenance_records`; the ack row keeps only keys + timestamp).
- Verdict (compliant / exception) + any decomposition note, following Output 08 §1.5's worked `booking_advisory_acknowledgments` sample. Flag unresolved corners rather than overclaiming.

The candidate keys audited in §4.3 must be the same keys used here — the audit and the Data Dictionary must not disagree.

## 13. Business-rule enforcement strategy (design strategy, not code)

- Blocking (`OutOfService` overlap): a query-style impact check on `maintenance_records` — active (`status NOT IN ('Completed','Cancelled')`) with `impact_level='OutOfService'` overlapping `[start_time, COALESCE(completion_time,'9999-12-31'))`; `spaces.current_status` stays UI-display only for maintenance.
- Advisory-ack requirement: `UNIQUE (booking_id, maintenance_id)` + the statement order (Pending → acks → Approved).
- Escalation audit + alert: `maintenance_impact_history` + `booking_alerts` populated by escalation triggers.
- Required-asset block: `space_facility_requirements.is_required = 1` with zero `'Available'` units blocks `Approved`/`CheckedIn`.
- Booking-overlap invariant: supported by the concurrency design of Output 08 §5 (referenced; the procedure/index DDL belongs to Tasks 11–13/15).

## 14. Quality checklist

- [ ] No Phase 1 table/column renamed or dropped; everything overlays Output 02/03.
- [ ] Conceptual ERD: Mermaid Crow's Foot; 2-column `attr` boxes; Home ID only in its defining box; **no Visitor ID/FK** column anywhere.
- [ ] No data types, no PK/FK/UK markers, no indexes, no DDL in the conceptual diagram.
- [ ] The three pillars present: `maintenance_records` + `maintenance_impact_history`; `booking_advisory_acknowledgments`; and the concurrency elements (`auto_approval_policies`, `policy_booking_types`, `booking_decisions.decision_source`, filtered index `IX_bookings_space_status_time`).
- [ ] M–N links resolved via associative entities (2 legs), never a direct M–N line.
- [ ] Relationship-to-FK mapping matches Output 08 §3; exactly one narrative row per conceptual line; Phase 1 vs Phase 2 rows marked.
- [ ] **Logical Mapping Standard:** every one of the 9 affected tables has a Data Dictionary table with headers `Column | Data Type | Constraints (PK/FK/UK/NN) | Description`.
- [ ] **FK enforcement:** every FK explicitly traced to its Home ID (e.g., `maintenance_id` FK → `maintenance_records.maintenance_id`); no bare FK without a target.
- [ ] **Candidate key audit:** natural UKs explicitly named (e.g., `facility_assets.serial_number`, `(booking_id, maintenance_id)`); consistent with the 3NF audit.
- [ ] **SQL Server fidelity:** every column has a specific MS SQL Server type (DATETIME2 / NVARCHAR / BIT / INT IDENTITY); no generic types.
- [ ] **Index design:** the filtered index `IX_bookings_space_status_time` recorded as a physical structural requirement for range-locking.
- [ ] **Referential integrity:** all Phase 1 FKs unchanged; Phase 2 FKs added additively.
- [ ] Logical tables/columns defined with MS SQL Server types (DATETIME2 / NVARCHAR / BIT / INT IDENTITY).
- [ ] `facility_assets` integrated for granular-maintenance tracking.
- [ ] Formal 1NF/2NF/3NF audit documented per each of the 9 tables; none overclaimed.
- [ ] Unit counts derived via `space_facility_summary`; `is_early_checkout` and all counts never stored.
- [ ] Relationship labels in the logical diagram use actual FK column names and are readable (or a workaround is documented).

## 15. Common mistakes to avoid

- Rewriting/renaming a Phase 1 entity instead of extending it.
- Putting Visitor/FK columns in the Conceptual ERD.
- Storing a unit count or `is_early_checkout`.
- Expecting a `CHECK` to enforce cross-row overlap/blocking or the required-asset rule.
- Omitting candidate keys, or using FK names as labels in the conceptual diagram.
- Hard-coding a trigger body / existing index name without reading Output 08; being inconsistent on the filtered-index name.
- Syncing `space_facilities.quantity` with asset rows instead of relying on the view.
- Writing a Data Dictionary entry without marking PK/FK/UK/NN, or writing an FK without its Home-ID target table + column.
- Omitting a Phase 1 FK from the referential-integrity statement or altering it instead of adding additively.
- Using generic/unspecified data types instead of concrete SQL Server types in the Data Dictionary.