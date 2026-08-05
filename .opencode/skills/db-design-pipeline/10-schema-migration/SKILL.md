---
name: 10-schema-migration
description: Act as a Database Administrator and author the additive SQL Server migration (outputs/10-schema-migration-G08.sql) from the Phase 1 baseline (outputs 05/06) to the Phase 2 schema (output 09) — new tables, facility_assets backfill, altered columns with data backfill, constraints, triggers, derived view, all inside one transactional block.
compatibility: opencode
---

# Step 10: Schema Migration Skill (DBA role)

This skill guides the agent acting as a **Database Administrator** to author the physical migration script. The output must be saved to `outputs/10-schema-migration-G08.sql`.

## Authority & Scope

- **Primary authority:** `outputs/09-updated-erd-and-logical-design-G08.md` is the immediate previous step; per the Step Precedence Rule it wins for the target schema (table shapes, column names, constraint names, view reference SQL).
- **Secondary authority:** `outputs/08-requirement-change-analysis-G08.md` supplies the change rationale (impact levels, concurrency, asset tracking, `changed_by` fallback chain, statement order).
- **Baseline to preserve:** the Phase 1 database defined by `outputs/05-db-definition-G08.sql` and populated by `outputs/06-sample-data-G08.sql`. The migration is **additive only** — no Phase 1 table, column, constraint, or row is dropped or renamed. If the target design appears to require a Phase 1 change, **STOP and flag it**; do not silently deviate.
- **Strict DBMS rule:** Microsoft SQL Server syntax only. No PostgreSQL constructs (`tsrange`, `EXCLUDE USING gist`, `DEFERRABLE`, `GIN`/array indexes, `'infinity'`, `SET LOCAL`). Use `SESSION_CONTEXT`/`sp_set_session_context`, `COALESCE(completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2))`, and SQL Server lock hints.
- **Conventions:** `snake_case` identifiers, PascalCase enum values, every constraint explicitly named (`CONSTRAINT [Name] [Type]`), `CONSTRAINT DF_<table>_<column> DEFAULT <value>` for defaults, `DATETIME2` timestamps, `NVARCHAR` text.

## Non-negotiable Execution Order

The order below is dependency-driven: a table may only be created after every table its FK references exists, and column backfills must finish before the constraints that validate the backfilled data are added. Do not reorder phases to "optimise".

### Phase A — Create new standalone tables (no dependency on Phase B/C artifacts)

1. `auto_approval_policies` — per Output 09 §5.14: `policy_id` (PK, IDENTITY), `space_type` (`NULL`), `space_id` (`NULL`), `max_participants` (`NULL`), `requires_advisory_ack BIT NOT NULL DEFAULT 1`, `is_active BIT NOT NULL DEFAULT 1`, `created_at`, `updated_at`, plus:
   - `CONSTRAINT UQ_auto_approval_policies_space_id UNIQUE (space_id)` (SQL Server treats multiple NULLs as distinct, so this constrains only specific-space overrides).
   - `CONSTRAINT CK_auto_approval_policies_scope CHECK ((space_type IS NULL AND space_id IS NOT NULL) OR (space_type IS NOT NULL AND space_id IS NULL))` — exactly one of `space_type`/`space_id`.
2. `policy_booking_types` — per Output 09 §5.15: composite PK `(policy_id, booking_type)`, FK → `auto_approval_policies(policy_id)`, `CHECK` on the Phase 1 booking-type enum.
3. `space_facility_requirements` — per Output 09 §5.7: **pure sparse junction**, composite PK `(space_id, facility_id)` and nothing else. Presence of a row means "required"; there is **no `is_required` column** (the attribute was removed in Output 09 — a full 3NF junction). Do not reintroduce it.

### Phase B — `facility_assets` + backfill (asset-level tracking)

1. Create `facility_assets` per Output 09 §5.6: `asset_id` (PK, IDENTITY), `facility_id` (FK → `facilities`), `space_id` (FK → `spaces`), `serial_number NVARCHAR(50) NOT NULL` with `CONSTRAINT UQ_facility_assets_serial_number UNIQUE (serial_number)`, `asset_status` with `DF_facility_assets_asset_status DEFAULT N'Available'` and `CHECK (asset_status IN (N'Available',N'InUse',N'UnderMaintenance',N'Retired'))`, `condition`, `last_checked_date`, `created_at`, `updated_at`.
2. **Backfill by expanding `space_facilities.quantity` into individual asset rows** — one row per unit per `(space_id, facility_id)`, using **Numbers-table (set-based, recommended)** or a **WHILE loop** (acceptable for small pilot data).
   - **Serial-number scheme must be globally unique** (`UQ_facility_assets_serial_number` is a *global* unique constraint). A scheme of only `facility_id + seq` collides across spaces; always include `space_id`: `CONCAT(N'SN-', sf.space_id, N'-', sf.facility_id, N'-', seq)`.
   - Set `asset_status = N'Available'` for all backfilled rows (Phase 1 has no per-unit state); carry `space_facilities.condition` into `condition` where available.
   - Rows with `quantity = 0` or `quantity IS NULL` produce no asset rows.

**Numbers-table backfill (recommended):**

```sql
WITH N1 AS (SELECT x.n FROM (VALUES (0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) x(n)),
     N2 AS (SELECT n FROM N1 CROSS JOIN N1),                    -- 100
     N3 AS (SELECT n FROM N2 CROSS JOIN N2),                    -- 10,000
     Nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS seq FROM N3)
INSERT INTO dbo.facility_assets (facility_id, space_id, serial_number, asset_status, condition, created_at, updated_at)
SELECT sf.facility_id,
       sf.space_id,
       CONCAT(N'SN-', sf.space_id, N'-', sf.facility_id, N'-', FORMAT(n.seq, N'D4')),
       N'Available',
       sf.condition,
       GETDATE(),
       GETDATE()
FROM dbo.space_facilities sf
JOIN Nums n ON n.seq <= sf.quantity
WHERE sf.quantity > 0;
```

**WHILE-loop backfill (alternative, small data):**

```sql
DECLARE @space_id INT, @facility_id INT, @qty INT, @i INT;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT space_id, facility_id, quantity FROM dbo.space_facilities WHERE quantity > 0;
OPEN cur;
FETCH NEXT FROM cur INTO @space_id, @facility_id, @qty;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @i = 1;
    WHILE @i <= @qty
    BEGIN
        INSERT INTO dbo.facility_assets (facility_id, space_id, serial_number, asset_status, condition, created_at, updated_at)
        VALUES (@facility_id, @space_id,
                CONCAT(N'SN-', @space_id, N'-', @facility_id, N'-', FORMAT(@i, N'D4')),
                N'Available', NULL, GETDATE(), GETDATE());
        SET @i = @i + 1;
    END;
    FETCH NEXT FROM cur INTO @space_id, @facility_id, @qty;
END;
CLOSE cur;
DEALLOCATE cur;
```

### Phase C — Alter existing Phase 1 tables (add columns + backfill)

**`maintenance_records`** (per Output 09 §5.11 — must run after Phase B because of the FK):

1. `ALTER TABLE ... ADD asset_id INT NULL` + `CONSTRAINT FK_maintenance_records_asset_id FOREIGN KEY (asset_id) REFERENCES facility_assets(asset_id)` — NULL = space-level record (Phase 1 behaviour preserved).
2. `ALTER TABLE ... ADD impact_level NVARCHAR(20) NOT NULL` with `CONSTRAINT DF_maintenance_records_impact_level DEFAULT N'OutOfService'` — the DEFAULT guarantees the `ALTER TABLE ... ADD` succeeds on the populated table and **backfills every existing Phase 1 record with `'OutOfService'`** (Phase 1's blanket rule ≡ out-of-service). Add `CONSTRAINT CK_maintenance_records_impact_level CHECK (impact_level IN (N'Advisory',N'OutOfService'))`.
3. **After the backfill, drop the default** (`ALTER TABLE ... DROP CONSTRAINT DF_maintenance_records_impact_level`) so future inserts must state the level explicitly (Output 08 §2.2). Existing rows keep `'OutOfService'`.
4. Add `CONSTRAINT CK_maintenance_records_asset_scope_level CHECK (asset_id IS NULL OR impact_level = N'Advisory')` — only space-level records may be `OutOfService`; asset-scoped records are always `Advisory`.

> Note: `ALTER TABLE ... ADD` backfills the default without firing AFTER triggers, so the impact audit trail for legacy rows is NOT created by `TR_maintenance_impact_history`. For audit completeness, explicitly insert one history row per legacy record with `old_impact_level = NULL`, `new_impact_level = N'OutOfService'`, `changed_by = reporter_id`, `change_reason = N'Migration backfill'` after `maintenance_impact_history` exists (Phase D) — this keeps the "never NULL/fabricated actor" invariant.

**`booking_decisions`** (per Output 09 §5.9):

1. Make `decided_by` nullable: `ALTER TABLE ... ALTER COLUMN decided_by INT NULL` (a System decision has no staff actor; a nullable FK is used instead of a sentinel "SYSTEM" user row).
2. Add `decision_source NVARCHAR(10) NOT NULL` with `CONSTRAINT DF_booking_decisions_decision_source DEFAULT N'Staff'` — backfills all existing records to `'Staff'` — plus `CONSTRAINT CK_booking_decisions_decision_source CHECK (decision_source IN (N'Staff',N'System'))`.
3. Add the actor pairing check **after the backfill** (existing rows are all `Staff` + `decided_by NOT NULL`, so it validates immediately):
   ```sql
   ALTER TABLE dbo.booking_decisions
       ADD CONSTRAINT CK_booking_decisions_source_actor CHECK (
           (decision_source = N'System' AND decided_by IS NULL)
           OR (decision_source = N'Staff'  AND decided_by IS NOT NULL)
       );
   ```

### Phase D — Remaining new tables that reference altered tables

1. `maintenance_impact_history` — per Output 09 §5.13: `history_id` (PK, IDENTITY), `maintenance_id` (FK → `maintenance_records`), `changed_by` (FK → `user_accounts`), `old_impact_level` (NULL on creation; CHECK), `new_impact_level` (CHECK in `('Advisory','OutOfService')`), `changed_at`, `change_reason`.
2. `booking_advisory_acknowledgments` — per Output 09 §5.12: `ack_id` (PK, IDENTITY), `booking_id` (FK), `maintenance_id` (FK), `acknowledged_by` (FK → `user_accounts`), `acknowledged_at`, plus `CONSTRAINT UQ_booking_advisory_acknowledgments_booking_maintenance UNIQUE (booking_id, maintenance_id)` (one ack per advisory per booking).
3. `booking_alerts` — per Output 09 §5.16: `alert_id` (PK, IDENTITY), `maintenance_id` (NULL), `asset_id` (NULL), `booking_id` (NOT NULL), `alert_type` (CHECK in `('MaintenanceEscalated','RequiredAssetRelocated')`), `created_at`, `acknowledged_by_staff_id` (NULL), `acknowledged_at` (NULL), plus the paired-handling CHECK and the **source-scope XOR CHECK** (`MaintenanceEscalated` ⇒ `maintenance_id` set / `asset_id` NULL; `RequiredAssetRelocated` ⇒ the reverse). Add the two **filtered unique indexes** (per Output 09 §5.16) because a single UNIQUE over a nullable source column cannot deduplicate:
   ```sql
   CREATE UNIQUE INDEX UQ_booking_alerts_maint ON dbo.booking_alerts (maintenance_id, booking_id)
       WHERE alert_type = N'MaintenanceEscalated';
   CREATE UNIQUE INDEX UQ_booking_alerts_asset  ON dbo.booking_alerts (asset_id, booking_id)
       WHERE alert_type = N'RequiredAssetRelocated';
   ```

### Phase E — Constraints & triggers

**`TR_maintenance_impact_history`** — `AFTER INSERT, UPDATE` on `maintenance_records`; INSERT writes the creation row with `old_impact_level = NULL`; UPDATE writes a row only when `impact_level` actually changed. `changed_by` must implement the **fallback chain** and never be NULL or fabricated:
- INSERT: `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), reporter_id)` — the reporter created the record.
- UPDATE: `COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), assigned_staff_id, reporter_id)` — fall back to the assigned staff, then the reporter.

```sql
CREATE TRIGGER dbo.TR_maintenance_impact_history
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @actor INT = NULLIF(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), 0);

    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.maintenance_impact_history
            (maintenance_id, changed_by, old_impact_level, new_impact_level, changed_at, change_reason)
        SELECT i.maintenance_id,
               COALESCE(@actor, i.reporter_id),
               NULL, i.impact_level, GETDATE(), NULL
        FROM inserted i;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.maintenance_impact_history
            (maintenance_id, changed_by, old_impact_level, new_impact_level, changed_at, change_reason)
        SELECT i.maintenance_id,
               COALESCE(@actor, i.assigned_staff_id, i.reporter_id),
               d.impact_level, i.impact_level, GETDATE(), NULL
        FROM inserted i
        JOIN deleted d ON d.maintenance_id = i.maintenance_id
        WHERE d.impact_level <> i.impact_level;
    END
END;
```

**`TR_bookings_AdvisoryAckRequired`** — `AFTER INSERT, UPDATE` on `bookings`; fires when a booking transitions into `Approved`/`CheckedIn` and there exists an active `Advisory` maintenance record overlapping the booking's reserved window whose `maintenance_id` has no matching `booking_advisory_acknowledgments` row. The **mandatory statement order** this trigger enforces (documented, Output 08 §4.2 / Output 09 §7 R3): the booking must be inserted as `Pending` → acknowledgement rows inserted → status updated to `Approved`, all inside one transaction (SQL Server has no deferred constraint triggers, so this ordering is the only workable pattern for every path: manual, instant, and migration). The trigger compares `COUNT(DISTINCT active advisory overlapping)` vs `COUNT(DISTINCT acknowledged)` for the booking:

```sql
CREATE TRIGGER dbo.TR_bookings_AdvisoryAckRequired
ON dbo.bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.status IN (N'Approved', N'CheckedIn')
          AND (
              SELECT COUNT(DISTINCT mr.maintenance_id)
              FROM dbo.maintenance_records mr
              WHERE mr.space_id = i.space_id
                AND mr.impact_level = N'Advisory'
                AND mr.status NOT IN (N'Completed', N'Cancelled')
                AND mr.start_time < i.requested_end_time
                AND COALESCE(mr.completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2)) > i.requested_start_time
          ) <> (
              SELECT COUNT(DISTINCT ack.maintenance_id)
              FROM dbo.booking_advisory_acknowledgments ack
              WHERE ack.booking_id = i.booking_id
          )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N'Every active advisory on this space must be acknowledged before the booking can be approved.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE b SET updated_at = GETDATE()
        FROM dbo.bookings b INNER JOIN inserted i ON b.booking_id = i.booking_id;
    END
END;
```

**Related triggers referenced by Output 09 (implement for design consistency):**
- `TR_bookings_RequiredAssetCheck` (Output 09 §7 R8) — blocks placement into `Approved`/`CheckedIn` when a required facility type (`space_facility_requirements` sparse list) for the space has zero `'Available'` asset rows, even with no space-level `OutOfService` record.
- `TR_maintenance_SyncAssetStatus` (Output 09 §5.6) — an active maintenance record targeting an asset flips `facility_assets.asset_status` to `UnderMaintenance`; released back to `Available` on completion/cancellation.
- `TR_maintenance_escalation` (Output 09 §5.16) — on escalation to `OutOfService`, one `booking_alerts` row per already-`Approved`/`CheckedIn` overlapping booking.
- `TR_facility_assets_RelocationAlert` (Output 09 §5.16, [EXTENSION]) — on `UPDATE facility_assets.space_id`, relocation alerts for approved bookings of the origin space when the moved unit's type is required there.

Keep the Phase 1 trigger `TR_bookings_PreventOverlapAndUnavailable` **verbatim** as a validation backstop only (Output 08 §1) — it is not the concurrency mechanism.

### Phase F — Derived view (3NF)

Create the unit-count view. **Naming:** Output 09 §6 names the physical object `v_space_facility_summary` (immediate previous step — use this name in the DDL); Output 08 §2.3 refers to it as `space_facility_summary`. Follow Output 09 and document the synonym. Unit counts are **derived, never stored** (3NF: storing a count that must track asset rows would be a functional-dependency duplication). Use the reference definition from Output 09 §6:

```sql
CREATE VIEW dbo.v_space_facility_summary AS
SELECT
    sf.space_id,
    sf.facility_id,
    f.facility_name,
    COUNT(fa.asset_id)                                AS total_units,
    SUM(CASE WHEN fa.asset_status = N'Available' THEN 1 ELSE 0 END) AS available_units,
    CASE WHEN r.facility_id IS NULL THEN 0 ELSE 1 END AS is_required
FROM dbo.space_facilities sf
JOIN dbo.facilities f          ON f.facility_id = sf.facility_id
LEFT JOIN dbo.facility_assets fa
       ON fa.facility_id = sf.facility_id
      AND fa.space_id   = sf.space_id
LEFT JOIN dbo.space_facility_requirements r
       ON r.space_id = sf.space_id
      AND r.facility_id = sf.facility_id
GROUP BY sf.space_id, sf.facility_id, f.facility_name,
         CASE WHEN r.facility_id IS NULL THEN 0 ELSE 1 END;
```

### Phase G — Indexes for new tables

Add the indexes called out in Output 09 §10, at minimum the asset availability index used by the required-asset check (R8) and the view aggregation:

```sql
CREATE INDEX IX_assets_location_status ON dbo.facility_assets (space_id, facility_id, asset_status);
```

## Transactional Safety (mandatory)

Wrap the **entire migration** in a single `BEGIN TRANSACTION` / `COMMIT` block with `TRY`/`CATCH` error handling. Requirements:

- SQL Server DDL is transactional, but `CREATE TRIGGER`/`CREATE VIEW` must be the first statement in their batch, and a single `TRY/CATCH` cannot span `GO` batches. Therefore author the whole script as **one batch without `GO`** and create triggers/views via `EXEC(N'...')` dynamic SQL inside the transaction.
- Use `SET XACT_ABORT ON` and guard the rollback with `XACT_STATE()`.
- On any error, roll back **all** phases — no partial migration may be committed.

```sql
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    -- Phase A..G: table creation, backfills, column alters, constraints, indexes
    EXEC(N'CREATE TRIGGER dbo.TR_maintenance_impact_history ON dbo.maintenance_records AFTER INSERT, UPDATE AS ...');
    EXEC(N'CREATE TRIGGER dbo.TR_bookings_AdvisoryAckRequired ON dbo.bookings AFTER INSERT, UPDATE AS ...');
    EXEC(N'CREATE VIEW dbo.v_space_facility_summary AS ...');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

- Optionally wrap with `IF OBJECT_ID(...) IS NOT NULL DROP ...` guards inside the transaction for idempotent re-runs on a fresh DB, but never `DROP` any Phase 1 object.

## Quality Checklist

- [ ] Migration is **additive only**: every Phase 1 table, column, constraint, and row survives unchanged (diff against `outputs/05` and `06`).
- [ ] Execution order is dependency-correct: standalone tables → `facility_assets` backfill → `maintenance_records`/`booking_decisions` alters → dependent tables → triggers → view.
- [ ] `facility_assets` backfill produces one row per unit, serial numbers are **globally unique** (`space_id` included in the scheme), and it is verified with `COUNT(*) = SUM(quantity)` before COMMIT.
- [ ] `maintenance_records.impact_level` backfilled to `'OutOfService'` for all legacy rows, then the default constraint is dropped.
- [ ] `booking_decisions.decision_source` backfilled to `'Staff'`, `decided_by` made nullable, and `CK_booking_decisions_source_actor` added after the backfill.
- [ ] `TR_maintenance_impact_history` implements the full `changed_by` fallback chain (never NULL/fabricated).
- [ ] `TR_bookings_AdvisoryAckRequired` enforces the `Pending → Acks → Approved` statement order for every path.
- [ ] `v_space_facility_summary` (Output 08: `space_facility_summary`) derives unit counts; no stored counter exists anywhere.
- [ ] Entire script is one transactional block with `XACT_ABORT ON` and `XACT_STATE()`-guarded rollback; triggers/views created via `EXEC(N'...')`.
- [ ] 100% SQL Server syntax (no Postgres constructs); validated on a SQL Server-compatible environment only.
