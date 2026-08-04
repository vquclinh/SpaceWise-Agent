---
name: 10-schema-migration
description: Generate the Task 10 Phase 2 schema migration — an additive, data-preserving Microsoft SQL Server migration script (new Phase 2 tables, facility_assets backfill from space_facilities.quantity, Phase 1 table alterations, data backfills, triggers, the space_facility_summary view, and full transactional safety). Use when producing outputs/10-schema-migration-G08.sql from outputs/09.
compatibility: opencode
---

# Step 10: Schema Migration Skill (Phase 2)

This skill is the **evolving quality rubric and behaviour guide** for producing `outputs/10-schema-migration-G08.sql`. It is **not a hard-coded answer**. The migration must be **derived from the inputs**: `outputs/09-updated-erd-and-logical-design-G08.md` is the technical blueprint (binding); `outputs/05-db-definition-G08.sql` is the Phase 1 baseline the script runs on top of. Every Phase 1 object stays verbatim; the migration only **adds** structures and **adds columns/constraints** to the two Phase 1 tables Output 09 explicitly marks as modified.

## 1. Purpose

Task 10 converts the validated Phase 2 design into the **official additive migration script**. A database already running the Phase 1 schema (built from Output 05, populated by Output 06) is extended to the full Phase 2 schema. The script must:

- **Preserve all Phase 1 data.** No `DROP TABLE`, `TRUNCATE TABLE`, `DROP COLUMN`, `DROP CONSTRAINT`, or `DROP INDEX` on any Phase 1 object. Existing rows are never deleted or rewritten.
- **Use Microsoft SQL Server syntax exclusively.** `IDENTITY`, `DATETIME2`, `NVARCHAR`, `GETDATE()`, filtered indexes, `GO` batching. No PostgreSQL/MySQL/Supabase constructs (`tsrange`, `EXCLUDE USING gist`, deferred triggers, `'infinity'`, `GIN`, `SET LOCAL`).
- **Stay within the Task 10 boundary.** This migration delivers schema, backfill, the derived view, and the Task-10 triggers. The concurrency-safe stored procedures (`SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)`, `sp_getapplock`, 1205/1222 retry) belong to Tasks 11–13/15 — do **not** write them here.

## 2. Required inputs

- `outputs/09-updated-erd-and-logical-design-G08.md` — **primary authority / technical blueprint (binding)**: §3 (logical schema diagram), §4 (data dictionary), §6 (candidate keys), §7 (index design), §8 (referential integrity), §10 (enforcement strategy).
- `outputs/08-requirement-change-analysis-G08.md` — supplementary authority for business-rule semantics.
- `outputs/05-db-definition-G08.sql` — **the Phase 1 baseline**: existing table/column names, constraint names, index names, and trigger names must be matched exactly and left untouched.
- `AGENTS.md` — §4 (SQL Server rules), §5 (Phase 2 technical rules), §9 (validation policy).

## 3. Order of execution (mandatory)

Execute the migration in exactly this order — it guarantees every FK target exists before it is referenced, and it keeps the two Phase 1 `ALTER` statements until after their new FK targets exist:

1. **Create the new standalone tables** (everything that does **not** depend on `facility_assets`), in FK-dependency order: `auto_approval_policies` → `policy_booking_types` → `space_facility_requirements` → `maintenance_impact_history` → `booking_advisory_acknowledgments` → `booking_alerts`. (`auto_approval_policies` is the canonical "standalone" example; the rest follow because they reference only Phase 1 tables.)
2. **Create `facility_assets` and backfill it** by expanding the counts from `space_facilities.quantity` (see §5). This MUST precede step 3 because `maintenance_records.asset_id` is an FK → `facility_assets.asset_id`.
3. **Alter the two Phase 1 tables**: `maintenance_records` (add `impact_level`, `asset_id`) and `booking_decisions` (add `decision_source`, make `decided_by` nullable), with their data backfills (see §6).
4. **Create the supporting indexes** (Output 09 §7), including the filtered conflict-check index and the two filtered UNIQUE indexes on `auto_approval_policies` (Output 09 §4.6).
5. **Create the derived-fact view** `space_facility_summary` (§7).
6. **Create the Task-10 triggers** (§8), each isolated in its own `GO` batch.
7. **Close with a summary** of every object the migration created, mapped to its Output 09 section (per the 05 skill §6).

## 4. Transactional safety (mandatory)

Wrap the **entire migration** in one transaction so a failure at any point leaves the database exactly as it was:

- `SET XACT_ABORT ON;` as the first statement — any runtime error aborts the batch and marks the transaction for rollback.
- `BEGIN TRANSACTION;` immediately after, before the first object creation.
- `GO` batch separators do **not** end the transaction — the `BEGIN TRAN` spans every batch until the final commit.
- **Final batch error handling:** commit only if the transaction is committable, otherwise roll back and report:

```sql
IF XACT_STATE() = 1
    COMMIT TRANSACTION;
ELSE IF XACT_STATE() = -1
BEGIN
    ROLLBACK TRANSACTION;
    RAISERROR('Schema migration failed; all Phase 2 changes rolled back.', 16, 1);
END;
```

- Because a single `TRY/CATCH` cannot span `GO` boundaries, the `XACT_ABORT ON` + final `XACT_STATE()` guard is the reliable pattern for a multi-batch transaction. Do not try to `COMMIT` inside each batch.
- State in the header comment: run against an existing Phase 1 database, take a backup first, execute on a SQL Server-compatible environment only.

## 5. `facility_assets` creation and backfill (granular asset rows)

**Create the table** per Output 09 §4.8: `asset_id INT IDENTITY PK`; `facility_id INT NOT NULL FK → facilities.facility_id`; `space_id INT NOT NULL FK → spaces.space_id`; `serial_number NVARCHAR(40) NOT NULL UNIQUE`; `asset_status NVARCHAR(20) NOT NULL` CHECK `('Available','InUse','UnderMaintenance','Retired')`; `condition NVARCHAR(200) NULL`; `last_checked_date DATE NULL`; `created_at`/`updated_at DATETIME2 NOT NULL DEFAULT GETDATE()`.

**Backfill — expand `space_facilities.quantity` into one row per unit.** For every `(space_id, facility_id)` whose `quantity > 0`, insert exactly `quantity` rows with **globally unique** serial numbers. Two acceptable T-SQL approaches:

- **Numbers-table (preferred, set-based):** generate a sequence of numbers (recursive CTE or a cross-join of catalog views with `ROW_NUMBER() OVER (ORDER BY (SELECT NULL))`), cross-apply it to `space_facilities` with `n <= sf.quantity`, and insert one row per pair using a `ROW_NUMBER()`-derived per-unit sequence.
- **WHILE loop (fallback):** iterate while `sf.quantity > COUNT(*)` of existing `facility_assets` rows for that `(space_id, facility_id)` and insert the remaining units one batch at a time.

**Serial-number rule:** must be globally unique because `serial_number` is a UNIQUE column (Output 09 §6 — the composite `(space_id, facility_id, serial_number)` is deliberately **not** used; `serial_number` alone is the natural key). Recommended pattern — prefix derived from the facility + zero-padded sequence, e.g. `'FAC-' + CAST(sf.facility_id AS VARCHAR) + '-' + RIGHT('00000' + CAST(seq AS VARCHAR), 5)`. Never reuse a serial across facilities.

**Backfill values:** `asset_status = 'Available'` (Phase 1 had no asset-level state; nothing is under maintenance at migration time), `condition` may copy `space_facilities.condition` or stay NULL, `last_checked_date = NULL`, `created_at`/`updated_at = GETDATE()`. Document in a comment that Phase 1 `space_facilities.quantity` stays as catalogue metadata and unit counts are computed from `facility_assets` via the view (§7) — never re-synced.

## 6. Alter Phase 1 tables and data backfilling

### 6.1 `maintenance_records` (Output 09 §4.1)

- **Add `impact_level NVARCHAR(20) NOT NULL`** with a **temporary** `DEFAULT 'OutOfService'` constraint so existing Phase 1 rows are backfilled to `OutOfService` (Phase 1's blanket maintenance rule == out-of-service). Then **drop the temporary DEFAULT** so future inserts must state the level explicitly. Add the CHECK `('Advisory','OutOfService')` and keep the NOT NULL.
- **Add `asset_id INT NULL`** FK → `facility_assets.asset_id` — NULL = space-level record (Phase 1 behavior); asset-scoped records never block the space by themselves.
- Add a comment: existing rows represent space-level maintenance (no asset), so `asset_id` stays NULL for them.

### 6.2 `booking_decisions` (Output 09 §4.2)

- **Add `decision_source NVARCHAR(10) NOT NULL`** with `DEFAULT 'Staff'` and CHECK `('Staff','System')`. The DEFAULT also backfills all existing Phase 1 decisions to `'Staff'` (Phase 1 decisions were all staff-made). Unlike `impact_level`, the DEFAULT **remains** — it is the intended permanent default per Output 09 §4.2.
- **Make `decided_by` nullable** (`ALTER COLUMN decided_by INT NULL`) so `decision_source = 'System'` decisions can exist without a staff member.
- **Add the pairing CHECK**: `(decision_source = 'System' AND decided_by IS NULL) OR (decision_source = 'Staff' AND decided_by IS NOT NULL)`.

**Guarding:** use object-existence guards before each `ALTER` (e.g. `COL_LENGTH('dbo.maintenance_records', 'impact_level') IS NULL` before `ADD`, checks against `sys.columns` / `sys.default_constraints`) so re-running the migration is safe and never destructive.

## 7. `space_facility_summary` view (derived counts, 3NF)

Create a view (never a stored-count table) computing unit counts per `(space_id, facility_id)` from `facility_assets`:

```sql
CREATE VIEW space_facility_summary AS
SELECT fa.space_id,
       fa.facility_id,
       COUNT_BIG(*)                              AS total_units,
       SUM(CASE WHEN fa.asset_status = 'Available' THEN 1 ELSE 0 END) AS available_units
FROM facility_assets fa
GROUP BY fa.space_id, fa.facility_id;
```

Rationale to state in a comment: `total_units`/`available_units` are **derived facts** — storing them would create a transitive (3NF-breaking) summary of `facility_assets`. The view keeps the schema 3NF-compliant (Output 09 §9.8).

## 8. Constraints and triggers (Task-10 set)

Every trigger must be `AFTER INSERT, UPDATE` (not `INSTEAD OF`), isolated in its own `GO` batch (`CREATE TRIGGER` must be the **first** statement in the batch), and use `ROLLBACK TRANSACTION; RAISERROR(...); RETURN;` to reject a violating statement (per the 05 skill). Gate each rule so it fires only for the relevant transition.

### 8.1 `TR_maintenance_impact_history` — escalation/downgrade audit

`AFTER INSERT, UPDATE ON maintenance_records`. It is the audit trail behind `maintenance_impact_history` (Output 09 §4.3, §10):

- **INSERT:** for each inserted row, insert a history row with `old_impact_level = NULL`, `new_impact_level = i.impact_level`, `changed_at = GETDATE()`, `change_reason = NULL`.
- **UPDATE:** fire only when `impact_level` **actually changed** (`i.impact_level <> d.impact_level`); insert `old_impact_level = d.impact_level`, `new_impact_level = i.impact_level`.
- **`changed_by` fallback chain (mandatory, never NULL or fabricated):**
  - UPDATE: `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), i.assigned_staff_id, i.reporter_id)`
  - INSERT: `i.reporter_id`
- Keep `maintenance_records.updated_at` fresh on UPDATE.

### 8.2 `TR_bookings_AdvisoryAckRequired` — mandatory advisory acknowledgements

`AFTER INSERT, UPDATE ON bookings`. Enforces Output 08 §4.2 / Output 09 §10: **a booking cannot be finalized as `Approved` (or `CheckedIn`) while an active `Advisory` on its space lacks an acknowledgement.**

- **Gate:** only rows where `i.status IN ('Approved','CheckedIn')`. Updates to `Pending`, `Cancelled`, `Completed`, `NoShow`, etc. must never be blocked by this trigger.
- **Check per inserted booking:** compare
  - `COUNT(DISTINCT)` of **active advisories** on the booking's space overlapping `[start_time, COALESCE(completion_time,'9999-12-31'))` — active maintenance (`status NOT IN ('Completed','Cancelled')`, `impact_level = 'Advisory'`) — against
  - `COUNT(DISTINCT)` of acknowledgements in `booking_advisory_acknowledgments` for that `booking_id`.
- If any active advisory is unacknowledged → `ROLLBACK; RAISERROR; RETURN;`.
- **Mandatory statement order (document it in the script and rely on it in the stored procedures, Tasks 11–13):** the transaction must insert `bookings` as `Pending`, insert the acknowledgement rows, and only then update the status to `Approved`. This trigger validates at the moment of the `Approved`/`CheckedIn` transition.

### 8.3 `TR_maintenance_escalation` — escalation alerts + downgrade auto-close

`AFTER INSERT, UPDATE ON maintenance_records`. Handles both directions of `impact_level` change (Output 09 §10):

- **Escalation → `OutOfService`:** for every already-`Approved`/`CheckedIn` booking on the space overlapping `[start_time, COALESCE(completion_time,'9999-12-31'))`, insert a `booking_alerts` row with `alert_type = 'MaintenanceEscalated'` (one row per affected booking).
- **Downgrade `OutOfService` → `Advisory`:** auto-close the still-unresolved alerts for that record — set `acknowledged_at = GETDATE()` and `acknowledged_by_staff_id` to the acting staff (session-context fallback) on every open alert (`acknowledged_at IS NULL`), because the out-of-service block that justified them has been lifted. The `maintenance_impact_history` row still records the downgrade.

### 8.4 `TR_bookings_RequiredAssetCheck` — required-asset block

`AFTER INSERT, UPDATE ON bookings`. Enforces Output 09 §10: a booking cannot be finalized `Approved`/`CheckedIn` when a facility marked **required** for the space (`space_facility_requirements.is_required = 1`) has zero `'Available'` units in `facility_assets`. **Gate:** `i.status IN ('Approved','CheckedIn')` only. Supported by `IX_facility_assets_space_facility_status`.

## 9. Indexes (Output 09 §7)

Create after the tables/ALTERs, before the triggers:

- `IX_bookings_space_status_time` — **filtered** non-clustered on `bookings (space_id, requested_start_time, requested_end_time)` `WHERE status IN ('Approved','CheckedIn')`. The physical structural requirement for `SERIALIZABLE` + `UPDLOCK/HOLDLOCK` key-range locking (Tasks 11–13/15).
- `UQ_auto_approval_policies_space_id` — **filtered UNIQUE** on `auto_approval_policies (space_id)` `WHERE space_id IS NOT NULL` (Output 09 §4.6).
- `UQ_auto_approval_policies_active_space_type` — **filtered UNIQUE** on `auto_approval_policies (space_type)` `WHERE space_type IS NOT NULL AND is_active = 1` (Output 09 §4.6).
- `IX_facility_assets_space_facility_status` — `facility_assets (space_id, facility_id, asset_status)`.
- `IX_facility_assets_serial_number` — unique on `facility_assets (serial_number)` (enforces the natural UK; the table's UNIQUE constraint already provides this, so add it only if the UNIQUE constraint was created inline — avoid duplication).
- `IX_maintenance_records_impact_level` — `maintenance_records (space_id, status, impact_level, start_time, completion_time)`.
- `IX_maintenance_impact_history_mid` — `maintenance_impact_history (maintenance_id)`.
- `IX_booking_advisory_ack_booking` — `booking_advisory_acknowledgments (booking_id)`.
- `IX_booking_alerts_booking` — `booking_alerts (booking_id)`.
- `IX_auto_approval_policies_active` — `auto_approval_policies (space_type, space_id, is_active)`.

## 10. Quality checklist (run before finishing)

- [ ] Whole script wrapped in `SET XACT_ABORT ON` + `BEGIN TRANSACTION` ... final `XACT_STATE()` commit/rollback guard.
- [ ] Execution order respected: standalone tables → `facility_assets` + backfill → Phase 1 ALTERs → indexes → view → triggers.
- [ ] No `DROP TABLE` / `TRUNCATE TABLE` / `DROP COLUMN` / `DROP CONSTRAINT` / `DROP INDEX` on any Phase 1 object; Phase 1 data untouched.
- [ ] `facility_assets` backfill expands every `space_facilities.quantity > 0` into individual rows with globally unique serial numbers (Numbers-table or WHILE loop).
- [ ] `maintenance_records.impact_level` backfilled via temporary DEFAULT `'OutOfService'`, then the DEFAULT is dropped; `asset_id` FK added.
- [ ] `booking_decisions.decision_source` added with DEFAULT `'Staff'` (backfill) + CHECK; `decided_by` made nullable; pairing CHECK added.
- [ ] Object-existence guards make the script safe to re-run.
- [ ] `TR_maintenance_impact_history` uses the `changed_by` fallback chain (UPDATE: session-context → `assigned_staff_id` → `reporter_id`; INSERT: `reporter_id`).
- [ ] `TR_bookings_AdvisoryAckRequired` gated to `Approved`/`CheckedIn`, comparing active-advisory vs acknowledged counts; statement order documented.
- [ ] `TR_maintenance_escalation` creates alerts on escalation and auto-closes unresolved alerts on downgrade; `TR_bookings_RequiredAssetCheck` blocks when a required facility has no `Available` unit.
- [ ] Every trigger isolated in its own `GO` batch and `AFTER INSERT, UPDATE`; rejections use `ROLLBACK; RAISERROR; RETURN;`.
- [ ] `space_facility_summary` is a view (derived counts), not a stored-count table.
- [ ] Filtered indexes `IX_bookings_space_status_time` and the two `auto_approval_policies` filtered UNIQUE indexes present.
- [ ] Every statement is Microsoft SQL Server syntax; no non-MSSQL constructs.
- [ ] Script ends with a summary of created objects mapped to Output 09 sections.

## 11. Common mistakes to avoid

- Dropping or truncating a Phase 1 table to "rebuild" it — the migration must be purely additive.
- Creating `facility_assets` **after** the `maintenance_records` ALTER that references it (FK dependency).
- Backfilling asset rows by copying `space_facilities` rows without expanding by `quantity`, or minting non-unique serial numbers.
- Leaving the temporary `impact_level` DEFAULT in place (future inserts would silently default to `OutOfService`).
- Backfilling `decision_source` to anything other than `'Staff'` for Phase 1 decisions, or keeping `decided_by` NOT NULL (blocks System decisions).
- Gating advisory-ack/required-asset triggers on every status instead of only `Approved`/`CheckedIn` (blocks cancels/completions).
- Hard-coding the `changed_by` fallback to a fabricated value instead of the `COALESCE(session_context, assigned_staff_id, reporter_id)` chain.
- `COMMIT`-ing inside each `GO` batch (loses the all-or-nothing guarantee).
- Adding duplicate unique indexes (the UNIQUE constraint on `serial_number` already creates one).
- Using PostgreSQL/MySQL/Supabase syntax in any statement.
