---
name: 10-schema-migration
description: Execute a safe, re-runnable T-SQL migration that upgrades a populated Phase 1 database to the Phase 2 schema, preserving every existing row and implementing the Phase 2 business rules via triggers and views.
compatibility: opencode
---

# Step 10: Schema Migration Skill

Produces `outputs/10-schema-migration-G08.sql` — the physical implementation of the Phase 2
design defined in Output 09.

**Authority:** Output 09 is the schema specification; Output 08 is the rationale. Where this
file and Output 09 disagree, Output 09 wins (Step Precedence Rule, `AGENTS.md` §2).

---

## 0. Scope boundary — what Task 10 is NOT

Task 10 delivers **schema objects and data preservation only**. The following belong to later
tasks and must not appear in `10-...sql`:

| Out of scope | Belongs to |
|---|---|
| Stored procedures (`usp_ApproveBooking`, `usp_CreateBookingAutoApproved`, `usp_CompleteBooking`) | Task 12 |
| `SERIALIZABLE` / `UPDLOCK`/`HOLDLOCK` transaction bodies, `sp_getapplock`, retry logic | Task 12 |
| Concurrency demonstration or test harnesses | Task 13 |
| Bulk/volume data generation (3 academic years, 100k+ bookings) | Task 14 |
| Index tuning experiments, execution plans, before/after timings | Task 15 |
| The four §1.3 analytical report queries | Task 16 |

**In scope:** tables, columns, constraints, indexes, views, triggers, and the data movement
required to carry Phase 1 rows into the Phase 2 shape.

Creating a Phase 2 *index* is Task 10 (the schema needs it). *Measuring* it is Task 15.

---

## 1. Data preservation philosophy

Phase 2 is **additive by default**, with **three documented exceptions** authorized in
`AGENTS.md`. There are no others.

| Amendment | Change |
|---|---|
| §1a | `facilities` table dropped; `facility_name` becomes a `CHECK`-constrained attribute |
| §1b | `space_facilities` table dropped; its key pair is a stored projection of `facility_assets` |
| §1c | `user_accounts.role` column dropped; replaced by the `user_roles(user_id, role)` junction |

### 1.1 Archive before every destructive step (mandatory)

Nothing is dropped until its contents are copied verbatim into a `mig_archive_*` table in the
same transaction. These archive tables are **migration artifacts, not part of the Phase 2
schema** — label them as such in comments so no later task mistakes them for design objects.

### 1.2 Carry the data, not just the shape

Dropping a table whose rows are the only record of a fact is data loss, even when the design
document calls the table redundant. Two migrations are mandatory and must run **before** the
corresponding drop:

- **`space_facilities` → `facility_assets`.** Phase 1 stores equipment as a count
  (`quantity`). Phase 2 stores individual units. The migration must **expand** each
  `(space_id, facility_id, quantity)` row into exactly `quantity` `facility_assets` rows,
  resolving `facility_id → facility_name` through `facilities` **while it still exists**, and
  generating `serial_number` with the documented internal scheme
  `<space_code>-<FACILITY>-<seq>` (Output 09 §5.6, L12). Phase 1 `condition` and `note` text
  must be carried onto the generated units — it contains real operational information
  (e.g. `'3 stations have faulty keyboards'`).
- **`user_accounts.role` → `user_roles`.** Seed one row per existing user before dropping the
  column, so every Phase 1 account keeps the role it had.

### 1.3 Adding a `NOT NULL` column to a populated table

Add with a **migration-only** `DEFAULT` to backfill existing rows, then **drop the default** in
the same script if the final schema carries none (Output 09 §5.11: `impact_level` has no
standing default — impact level is a Facility Manager judgment and must never be silently
defaulted for a new record).

Constraints that legacy rows could violate (`CK_maintenance_records_asset_scope_level`,
`CK_booking_decisions_source_actor`) are added **after** the backfill, never before.

---

## 2. Implementation scope (from Output 09)

- **8 new tables:** `facility_assets`, `space_facility_requirements`, `maintenance_impact_history`,
  `booking_advisory_acknowledgments`, `auto_approval_policies`, `policy_booking_types`,
  `booking_alerts`, `user_roles`.
- **3 modified Phase 1 tables:** `user_accounts` (drop `role`), `maintenance_records`
  (add `asset_id`, `impact_level`; `space_id` **stays `NOT NULL`** — no XOR, Output 09 §8.3),
  `booking_decisions` (add `decision_source`, relax `decided_by`).
- **2 dropped Phase 1 tables:** `facilities`, `space_facilities`.
- **Final inventory: 15 tables** = 7 Phase 1 retained + 8 new.
- **View:** `v_space_facility_summary` — must be `UNION`-based over `facility_assets` and
  `space_facility_requirements` (Output 09 §6). A version based on `facility_assets` alone
  silently loses the `total_units = 0, is_required = 1` row, which is exactly the state rule R8
  detects.
- **Indexes:** the Section 10 table of Output 09 — 17 new plus `I16`, which is the implicit
  index of a pre-existing Phase 1 `UNIQUE` constraint and must **not** be created explicitly.

---

## 3. Trigger implementation (rules R1–R16)

One Phase 1 trigger is **modified**; thirteen are **new**.

### 3.1 Modify

- **`TR_bookings_PreventOverlapAndUnavailable`** — remove `'UnderMaintenance'` from its
  `spaces.current_status` check: under Output 09 §4.1 that column is never a maintenance-blocking
  predicate, so leaving it would wrongly block spaces flagged for *advisory*-only reasons. It
  keeps `TemporarilyClosed` / `Retired` (legitimate non-maintenance closures), extends its
  overlap check to `IN ('Approved','CheckedIn')`, and gains the `OutOfService` impact-level
  check. It remains a **validation backstop only** — the concurrency mechanism is Task 12.

### 3.2 Create

| Trigger | Rule | Purpose |
|---|---|---|
| `TR_maintenance_impact_history` | R9 | Records every `impact_level` create/change with the actor fallback chain |
| `TR_maintenance_escalation` | R5 | On escalation to `OutOfService`, one `booking_alerts` row per overlapping `Approved`/`CheckedIn` booking |
| `TR_maintenance_AdvisoryAddedAlert` | L11 | New advisory on a space with approved bookings → `AdvisoryAddedAfterApproval` alerts; does not invalidate the booking |
| `TR_maintenance_SyncAssetStatus` | §5.6 | Keeps `facility_assets.asset_status` in step with active asset-scoped maintenance |
| `TR_maintenance_TargetInvariant` | D-1 | **Creation-time only:** if `asset_id IS NOT NULL`, the asset must currently belong to the recorded `space_id`. Never re-checked afterwards — `space_id` is an immutable snapshot and the asset is free to relocate |
| `TR_bookings_AdvisoryAckRequired` | R3 | Set-based `NOT EXISTS` check — **never** a `COUNT` comparison (Output 09 §9.5.3) |
| `TR_bookings_RequiredAssetCheck` | R8 | Blocks `Approved`/`CheckedIn` when a required facility has no `Available` unit |
| `TR_facility_assets_RelocationAlert` | R12 | Relocation of a required unit → `RequiredAssetRelocated` alerts |
| `TR_ack_AdvisoryOnly` | L10 | `booking_advisory_acknowledgments.maintenance_id` must reference an `Advisory` record |
| `TR_booking_decisions_StaffRole` | R13 | `decided_by` holds a staff-type role when `decision_source = 'Staff'` |
| `TR_maintenance_StaffRole` | R14 | `assigned_staff_id` holds `FacilityStaff` or `FacilityManager` |
| `TR_booking_alerts_StaffRole` | R15 | `acknowledged_by_staff_id` holds a staff-type role |
| `TR_impact_history_StaffRole` | R16 | The resolved `changed_by` actor holds a staff-type role |

R13–R16 exist because §1c removed the single `user_accounts.role` column: these checks are now
**cross-table** against `user_roles` and cannot be `CHECK` constraints.

### 3.3 Cross-cutting trigger standards

- **Re-entrancy guard — use the trigger's own depth, not the session's.** Begin every trigger
  with:
  ```sql
  IF TRIGGER_NESTLEVEL(@@PROCID, 'AFTER', 'DML') > 1 RETURN;
  ```
  A bare `TRIGGER_NESTLEVEL() > 1` is **wrong** here: it counts the whole nesting stack, so a
  trigger legitimately fired *by another* trigger (e.g. `TR_impact_history_StaffRole` validating
  a row written by `TR_maintenance_impact_history`) would silently skip its check. Guard against
  re-entry into the *same* trigger only.
- **Set-based, never row-by-row.** Triggers fire once per statement; `inserted`/`deleted` may
  hold many rows. No `SELECT @var = ... FROM inserted`, no cursors.
- **Relocation-alert precision.** `RequiredAssetRelocated` fires only when the unit was
  **`Available` before the move** (read the pre-move state from `deleted`). Moving a unit that
  was already `UnderMaintenance`, `InUse`, or `Retired` takes nothing away from the origin
  space's bookings and must not raise an alert.
- **`SESSION_CONTEXT` is `SQL_VARIANT`.** Never assign it untyped. Use
  `TRY_CONVERT(INT, SESSION_CONTEXT(N'current_user_id'))` for actors so an unset key degrades to
  the documented fallback chain instead of raising a conversion error, and
  `CONVERT(NVARCHAR(MAX), ...)` for text targets.
- **Fail loudly.** A rule violation must `THROW` (or `RAISERROR ... 16`) after rolling back, not
  silently swallow the statement.

---

## 4. Technical standards

### 4.1 Atomicity — one transaction, all or nothing

The whole migration runs inside a **single** `BEGIN TRANSACTION` / `COMMIT` under
`SET XACT_ABORT ON`, wrapped in one `TRY`/`CATCH` that rolls back on any error. A half-migrated
database must be impossible.

**Consequence:** `GO` may not appear inside the transaction — it ends the batch and breaks the
single `TRY`/`CATCH`. But `CREATE OR ALTER VIEW|TRIGGER` must be the *first statement in its
batch*. Resolve this by wrapping every programmable object in dynamic SQL:

```sql
EXEC (N'CREATE OR ALTER TRIGGER dbo.TR_... ON dbo.... AFTER INSERT AS BEGIN ... END');
```

The same wrapping is required for **any statement that references a column added earlier in the
same batch** — deferred name resolution fails at compile time, not run time.

### 4.2 Re-runnability (idempotence)

Running the script twice in a row must succeed and change nothing the second time. Guard every
object:

| Object | Guard |
|---|---|
| Table | `IF OBJECT_ID(N'dbo.x', N'U') IS NULL CREATE TABLE ...` |
| Column | `IF COL_LENGTH('dbo.t','c') IS NULL ALTER TABLE ... ADD ...` |
| Constraint | `IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_...' AND parent_object_id = OBJECT_ID(...))` |
| Index | `IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_...' AND object_id = OBJECT_ID(...))` |
| View / trigger | `CREATE OR ALTER` (inherently idempotent) |
| Data migration | `INSERT ... WHERE NOT EXISTS (...)` |
| Drop | `IF OBJECT_ID(...) IS NOT NULL DROP ...` |

**Second-run subtlety:** after a successful first run `space_facilities` and
`user_accounts.role` no longer exist, so the blocks that read them must themselves be wrapped in
an existence check — not merely their inner `INSERT`.

`CREATE OR ALTER` is required for views/triggers; the `DROP ... CREATE` pattern is **forbidden**
because it resets permissions and leaves a window where dependent objects are unresolved.

### 4.3 Verification gate before `COMMIT`

The last step inside the transaction re-counts the migrated data and `THROW`s if anything is off,
so a bad migration **rolls back instead of committing**. At minimum:

- `COUNT(*)` of `facility_assets` equals `SUM(quantity)` from the archived `space_facilities`.
- `COUNT(*)` of `user_roles` equals the archived user count.
- No `maintenance_records.impact_level` is `NULL`; no `booking_decisions.decision_source` is `NULL`.
- Every expected table, view, and index exists.

### 4.4 Conventions

- **SQL Server syntax only:** `IDENTITY(1,1)`, `DATETIME2`, `NVARCHAR`, `BIT`, filtered indexes.
  No PostgreSQL constructs.
- **Every constraint explicitly named** (`PK_`, `FK_`, `CK_`, `UQ_`, `DF_`, `IX_`, `TR_`).
- **Filtered unique indexes, not `UNIQUE` constraints, on nullable columns.** In SQL Server a
  `UNIQUE` constraint or unique index treats NULLs as **equal** — the opposite of the ANSI
  standard and of PostgreSQL/Oracle — so it permits **at most one NULL row**. A plain
  `UNIQUE (space_id)` on `auto_approval_policies` would therefore accept the first type-wide
  policy (`space_id` NULL) and reject every one after it as a duplicate NULL. The failure mode is
  **over**-constraining, not under-constraining; a filtered unique index removes the NULL-keyed
  rows from the index entirely. Required for `UQ_auto_approval_policies_space_id`,
  `UQ_auto_approval_policies_active_type`, `UQ_booking_alerts_maint`, `UQ_booking_alerts_asset`,
  `UQ_booking_alerts_advisory_added`.
- **`CAST(... AS BIT)`** on every derived boolean in a view, so `is_required` matches the
  physical `BIT` type rather than yielding `INT`.
- **The filtered-index predicate grammar is narrow.** It is exactly
  `<conjunct> [AND <conjunct>]`, where a conjunct is either `column IN (constant, …)` or
  `column <op> constant` (`=`, `<>`, `!=`, `>`, `>=`, `<`, `<=`, `IS`, `IS NOT`). Two traps,
  in opposite directions:
    - `IN (...)` **is permitted** — do not "helpfully" rewrite it as `x = a OR x = b`. Bare
      `OR` is not in the grammar at all and fails with *Incorrect syntax near the keyword 'OR'*.
    - `NOT IN (...)` **is not permitted** — write it as `<>` conjuncts joined by `AND`.

  Both restrictions apply **only** to filtered indexes; inside ordinary `WHERE` clauses (and
  trigger bodies) `OR` and `NOT IN` are perfectly fine.
- **Unnamed Phase 1 defaults.** `space_facilities.quantity`'s `DEFAULT 1` is inline and unnamed;
  its real name is server-generated. Resolve it from `sys.default_constraints` before dropping —
  never assume `DF_space_facilities_quantity` (Output 09 §5.5, L1).

---

## 5. Document the approach

`AGENTS.md` §6 requires Task 10 to *"preserve existing Phase 1 data and document the migration
approach."* The script's header comment must state: prerequisites, the three amendments and what
each preserves, the section order and why that order is forced by dependencies, the
re-runnability guarantee, and the rollback behaviour.

---

## Quality checklist

- [ ] Does the script run end-to-end on a **populated** Phase 1 database (05 + 06) without error?
- [ ] Does running it a **second time** succeed and change nothing?
- [ ] Does an induced failure mid-script roll back to a clean Phase 1 state — no partial schema?
- [ ] Is every dropped object archived first?
- [ ] Are `space_facilities` rows expanded into `facility_assets` with generated serials, and are
      `condition`/`note` carried over?
- [ ] Does `user_roles` contain exactly one row per pre-existing user?
- [ ] Does `impact_level` backfill to `'OutOfService'`, and is the migration-only default then dropped?
- [ ] Is `booking_decisions.decided_by` nullable with `CK_booking_decisions_source_actor` added after backfill?
- [ ] Is `v_space_facility_summary` `UNION`-based, with `is_required` cast to `BIT`?
- [ ] Do all filtered unique indexes exist, and is `I16` **not** created explicitly?
- [ ] Does every trigger guard re-entry with `TRIGGER_NESTLEVEL(@@PROCID, 'AFTER', 'DML') > 1`?
- [ ] Is every trigger set-based (no cursors, no scalar assignment from `inserted`)?
- [ ] Does the verification gate run **before** `COMMIT` and `THROW` on mismatch?
- [ ] Does the file contain **zero** stored procedures, tuning experiments, or report queries?
