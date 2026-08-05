-- =============================================================================
-- Campus Space Management System — Phase 2 Schema Migration (Task 10)
-- Group G08 — Microsoft SQL Server
-- Deliverable : outputs/10-schema-migration-G08.sql
-- Purpose    : Additive migration of the Phase 1 database (outputs 05 & 06)
--              into the Phase 2 schema defined in Output 09. Every Phase 2
--              extension is applied while preserving 100% of Phase 1 data
--              (no Phase 1 table, column, row, or constraint is dropped or
--              renamed).
-- Run        : ONCE, on a SQL Server database where outputs/05 and 06 already
--              ran. Validate on a SQL Server-compatible environment only.
--
-- Design      : one batch (no GO) so that a single TRY/CATCH guards the whole
--              transaction. CREATE TRIGGER / CREATE VIEW must be the first
--              statement in their batch, so they are created via EXEC(N'...')
--              dynamic SQL inside the transaction (SQL Server DDL is
--              transactional; XACT_ABORT ON rolls back everything on error).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT N'=== Task 10 Phase 2 migration begins ===';
PRINT N'Baseline: Phase 1 database (outputs 05 + 06) must already be present.';

BEGIN TRY
    BEGIN TRANSACTION;

    -- =========================================================================
    -- PHASE A — NEW STANDALONE TABLES (no dependency on Phase B/C artifacts)
    -- =========================================================================

    -- A1. auto_approval_policies (Output 09 §5.14)
    PRINT N'Creating auto_approval_policies...';
    CREATE TABLE dbo.auto_approval_policies (
        policy_id              INT           NOT NULL IDENTITY(1,1),
        space_type             NVARCHAR(30)  NULL,
        space_id               INT           NULL,
        max_participants       INT           NULL,
        requires_advisory_ack  BIT           NOT NULL CONSTRAINT DF_auto_approval_policies_requires_advisory_ack DEFAULT 1,
        is_active              BIT           NOT NULL CONSTRAINT DF_auto_approval_policies_is_active DEFAULT 1,
        created_at             DATETIME2     NOT NULL CONSTRAINT DF_auto_approval_policies_created_at DEFAULT GETDATE(),
        updated_at             DATETIME2     NOT NULL CONSTRAINT DF_auto_approval_policies_updated_at DEFAULT GETDATE(),
        CONSTRAINT PK_auto_approval_policies PRIMARY KEY (policy_id),
        CONSTRAINT FK_auto_approval_policies_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        CONSTRAINT UQ_auto_approval_policies_space_id UNIQUE (space_id),
        CONSTRAINT CK_auto_approval_policies_space_type CHECK (
            space_type IN (N'Auditorium', N'Classroom', N'ComputerLaboratory',
                           N'ProjectLaboratory', N'MeetingRoom', N'StudentWorkspace')
        ),
        CONSTRAINT CK_auto_approval_policies_max_participants CHECK (max_participants > 0),
        -- Exactly one of space_type / space_id is set (XOR)
        CONSTRAINT CK_auto_approval_policies_scope CHECK (
            (space_type IS NULL AND space_id IS NOT NULL)
            OR (space_type IS NOT NULL AND space_id IS NULL)
        )
    );

    -- A2. policy_booking_types (Output 09 §5.15) — junction, no array types in SQL Server
    PRINT N'Creating policy_booking_types...';
    CREATE TABLE dbo.policy_booking_types (
        policy_id    INT           NOT NULL,
        booking_type NVARCHAR(30)  NOT NULL,
        CONSTRAINT PK_policy_booking_types PRIMARY KEY (policy_id, booking_type),
        CONSTRAINT FK_policy_booking_types_policy_id FOREIGN KEY (policy_id)
            REFERENCES dbo.auto_approval_policies(policy_id),
        CONSTRAINT CK_policy_booking_types_booking_type CHECK (
            booking_type IN (N'Lecture', N'Examination', N'Seminar', N'Workshop',
                             N'Meeting', N'StudentActivity', N'AdministrativeEvent',
                             N'ResearchActivity', N'ProjectWork')
        )
    );

    -- A3. space_facility_requirements (Output 09 §5.7) — pure sparse junction.
    --     Presence of a row means "required"; there is NO is_required attribute
    --     column (it was removed in Output 09 for full 3NF).
    PRINT N'Creating space_facility_requirements...';
    CREATE TABLE dbo.space_facility_requirements (
        space_id    INT  NOT NULL,
        facility_id INT  NOT NULL,
        CONSTRAINT PK_space_facility_requirements PRIMARY KEY (space_id, facility_id),
        CONSTRAINT FK_space_facility_requirements_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        CONSTRAINT FK_space_facility_requirements_facility_id FOREIGN KEY (facility_id)
            REFERENCES dbo.facilities(facility_id)
    );

    -- =========================================================================
    -- PHASE B — facility_assets + BACKFILL BY EXPANDING space_facilities.quantity
    -- =========================================================================

    -- B1. facility_assets (Output 09 §5.6)
    PRINT N'Creating facility_assets...';
    CREATE TABLE dbo.facility_assets (
        asset_id           INT            NOT NULL IDENTITY(1,1),
        facility_id        INT            NOT NULL,
        space_id           INT            NOT NULL,
        serial_number      NVARCHAR(50)   NOT NULL,
        asset_status       NVARCHAR(20)   NOT NULL CONSTRAINT DF_facility_assets_asset_status DEFAULT N'Available',
        condition          NVARCHAR(MAX)  NULL,
        last_checked_date  DATE           NULL,
        created_at         DATETIME2      NOT NULL CONSTRAINT DF_facility_assets_created_at DEFAULT GETDATE(),
        updated_at         DATETIME2      NOT NULL CONSTRAINT DF_facility_assets_updated_at DEFAULT GETDATE(),
        CONSTRAINT PK_facility_assets PRIMARY KEY (asset_id),
        CONSTRAINT UQ_facility_assets_serial_number UNIQUE (serial_number),
        CONSTRAINT FK_facility_assets_facility_id FOREIGN KEY (facility_id)
            REFERENCES dbo.facilities(facility_id),
        CONSTRAINT FK_facility_assets_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        CONSTRAINT CK_facility_assets_asset_status CHECK (
            asset_status IN (N'Available', N'InUse', N'UnderMaintenance', N'Retired')
        )
    );

    -- B2. Backfill rows from space_facilities.quantity (Numbers-table, set-based).
    --     Serial-number scheme MUST be globally unique (UQ_..._serial_number is a
    --     GLOBAL unique), so it includes space_id + facility_id + sequence.
    --     Wrapped in EXEC(N'...'): this DML targets facility_assets, created by a
    --     CREATE TABLE earlier in this same batch, so compilation is deferred to
    --     runtime (after the table exists) — avoids any batch-compile resolution
    --     error while keeping the backfill inside the single transaction.
    PRINT N'Backfilling facility_assets from space_facilities.quantity...';
    EXEC(N'WITH N1 AS (SELECT x.n FROM (VALUES (0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) x(n)),
         N2 AS (SELECT n FROM N1 CROSS JOIN N1),                    -- 100
         N3 AS (SELECT n FROM N2 CROSS JOIN N2),                    -- 10,000
         Nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS seq FROM N3)
    INSERT INTO dbo.facility_assets
        (facility_id, space_id, serial_number, asset_status, condition, created_at, updated_at)
    SELECT sf.facility_id,
           sf.space_id,
           CONCAT(N''SN-'', sf.space_id, N''-'', sf.facility_id, N''-'', RIGHT(N''0000'' + CAST(n.seq AS NVARCHAR(10)), 4)),
           N''Available'',
           sf.condition,
           GETDATE(),
           GETDATE()
    FROM dbo.space_facilities sf
    JOIN Nums n ON n.seq <= sf.quantity
    WHERE sf.quantity > 0;');

    PRINT N'  facility_assets backfilled: ' +
          CAST((SELECT COUNT(*) FROM dbo.facility_assets) AS NVARCHAR(12)) + N' asset rows created.';
    PRINT N'  expected (SUM of quantity): ' +
          CAST((SELECT ISNULL(SUM(quantity),0) FROM dbo.space_facilities) AS NVARCHAR(12)) + N'.';

    -- =========================================================================
    -- PHASE C — ALTER EXISTING PHASE 1 TABLES (additive + data backfill)
    -- =========================================================================

    -- C1. maintenance_records: add asset_id (FK to facility_assets) + impact_level
    PRINT N'Adding asset_id to maintenance_records (FK -> facility_assets)...';
    ALTER TABLE dbo.maintenance_records
        ADD asset_id INT NULL
            CONSTRAINT FK_maintenance_records_asset_id
            FOREIGN KEY (asset_id) REFERENCES dbo.facility_assets(asset_id);

    -- impact_level is added NOT NULL with DEFAULT N'OutOfService'. The DEFAULT is
    -- what backfills every existing Phase 1 record (Phase 1's blanket rule
    -- == out-of-service). The default is DROPPED after the backfill so future
    -- inserts must state the level explicitly (Output 08 §2.2).
    PRINT N'Adding impact_level to maintenance_records (default backfills legacy rows to OutOfService)...';
    ALTER TABLE dbo.maintenance_records
        ADD impact_level NVARCHAR(20) NOT NULL
            CONSTRAINT DF_maintenance_records_impact_level DEFAULT (N'OutOfService');

    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT CK_maintenance_records_impact_level CHECK (
            impact_level IN (N'Advisory', N'OutOfService')
        );

    -- Only space-level records may be OutOfService; asset-scoped records are
    -- structurally forced to Advisory.
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT CK_maintenance_records_asset_scope_level CHECK (
            asset_id IS NULL OR impact_level = N'Advisory'
        );

    -- Drop the backfill default after all legacy rows carry the value.
    PRINT N'Dropping impact_level backfill default constraint...';
    ALTER TABLE dbo.maintenance_records
        DROP CONSTRAINT DF_maintenance_records_impact_level;

    -- C2. booking_decisions: make decided_by nullable + add decision_source
    PRINT N'Making booking_decisions.decided_by nullable (System decisions have no staff actor)...';
    ALTER TABLE dbo.booking_decisions ALTER COLUMN decided_by INT NULL;

    PRINT N'Adding booking_decisions.decision_source (default backfills legacy rows to Staff)...';
    ALTER TABLE dbo.booking_decisions
        ADD decision_source NVARCHAR(10) NOT NULL
            CONSTRAINT DF_booking_decisions_decision_source DEFAULT (N'Staff');

    ALTER TABLE dbo.booking_decisions
        ADD CONSTRAINT CK_booking_decisions_decision_source CHECK (
            decision_source IN (N'Staff', N'System')
        );

    -- Paired source/actor check (added after backfill: all legacy rows are
    -- Staff + decided_by NOT NULL, so it validates immediately).
    ALTER TABLE dbo.booking_decisions
        ADD CONSTRAINT CK_booking_decisions_source_actor CHECK (
            (decision_source = N'System' AND decided_by IS NULL)
            OR (decision_source = N'Staff'  AND decided_by IS NOT NULL)
        );

    -- =========================================================================
    -- PHASE D — REMAINING NEW TABLES THAT REFERENCE ALTERED / NEW TABLES
    -- =========================================================================

    -- D1. maintenance_impact_history (Output 09 §5.13) — escalation/downgrade audit
    PRINT N'Creating maintenance_impact_history...';
    CREATE TABLE dbo.maintenance_impact_history (
        history_id        INT            NOT NULL IDENTITY(1,1),
        maintenance_id    INT            NOT NULL,
        changed_by        INT            NOT NULL,
        old_impact_level  NVARCHAR(20)   NULL,
        new_impact_level  NVARCHAR(20)   NOT NULL,
        changed_at        DATETIME2      NOT NULL CONSTRAINT DF_maintenance_impact_history_changed_at DEFAULT GETDATE(),
        change_reason     NVARCHAR(MAX)  NULL,
        CONSTRAINT PK_maintenance_impact_history PRIMARY KEY (history_id),
        CONSTRAINT FK_maintenance_impact_history_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES dbo.maintenance_records(maintenance_id),
        CONSTRAINT FK_maintenance_impact_history_changed_by FOREIGN KEY (changed_by)
            REFERENCES dbo.user_accounts(user_id),
        CONSTRAINT CK_maintenance_impact_history_old_level CHECK (
            old_impact_level IS NULL OR old_impact_level IN (N'Advisory', N'OutOfService')
        ),
        CONSTRAINT CK_maintenance_impact_history_new_level CHECK (
            new_impact_level IN (N'Advisory', N'OutOfService')
        )
    );

    -- Audit-trail completeness: ALTER TABLE ... ADD with a DEFAULT backfilled
    -- impact_level WITHOUT firing AFTER triggers, so legacy records have no
    -- history row. Insert one creation row per legacy record so the audit trail
    -- never omits them (changed_by = reporter_id, the never-NULL fallback).
    -- Wrapped in EXEC(N'...'): this DML reads maintenance_records.impact_level,
    -- a column added by ALTER TABLE earlier in this same batch. Ad-hoc batches
    -- resolve column names at compile time, so the statement must be compiled
    -- AFTER the ALTER has executed; EXEC defers compilation to runtime, avoiding
    -- an 'Invalid column name' batch-parse failure while the whole migration
    -- stays inside the single transaction.
    PRINT N'Backfilling maintenance_impact_history for legacy maintenance records...';
    EXEC(N'INSERT INTO dbo.maintenance_impact_history
        (maintenance_id, changed_by, old_impact_level, new_impact_level, changed_at, change_reason)
    SELECT mr.maintenance_id,
           mr.reporter_id,
           NULL,
           mr.impact_level,
           GETDATE(),
           N''Migration backfill''
    FROM dbo.maintenance_records mr
    WHERE NOT EXISTS (SELECT 1 FROM dbo.maintenance_impact_history h
                      WHERE h.maintenance_id = mr.maintenance_id);');

    -- D2. booking_advisory_acknowledgments (Output 09 §5.12) — legal consent record
    PRINT N'Creating booking_advisory_acknowledgments...';
    CREATE TABLE dbo.booking_advisory_acknowledgments (
        ack_id           INT            NOT NULL IDENTITY(1,1),
        booking_id       INT            NOT NULL,
        maintenance_id   INT            NOT NULL,
        acknowledged_by  INT            NOT NULL,
        acknowledged_at  DATETIME2      NOT NULL CONSTRAINT DF_booking_advisory_acknowledgments_acknowledged_at DEFAULT GETDATE(),
        CONSTRAINT PK_booking_advisory_acknowledgments PRIMARY KEY (ack_id),
        CONSTRAINT UQ_booking_advisory_acknowledgments_booking_maintenance UNIQUE (booking_id, maintenance_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_booking_id FOREIGN KEY (booking_id)
            REFERENCES dbo.bookings(booking_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES dbo.maintenance_records(maintenance_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_acknowledged_by FOREIGN KEY (acknowledged_by)
            REFERENCES dbo.user_accounts(user_id)
    );

    -- D3. booking_alerts (Output 09 §5.16) — persisted escalation / relocation lookup
    PRINT N'Creating booking_alerts...';
    CREATE TABLE dbo.booking_alerts (
        alert_id                  INT            NOT NULL IDENTITY(1,1),
        maintenance_id            INT            NULL,
        asset_id                  INT            NULL,
        booking_id                INT            NOT NULL,
        alert_type                NVARCHAR(30)   NOT NULL CONSTRAINT DF_booking_alerts_alert_type DEFAULT N'MaintenanceEscalated',
        created_at                DATETIME2      NOT NULL CONSTRAINT DF_booking_alerts_created_at DEFAULT GETDATE(),
        acknowledged_by_staff_id  INT            NULL,
        acknowledged_at           DATETIME2      NULL,
        CONSTRAINT PK_booking_alerts PRIMARY KEY (alert_id),
        CONSTRAINT FK_booking_alerts_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES dbo.maintenance_records(maintenance_id),
        CONSTRAINT FK_booking_alerts_asset_id FOREIGN KEY (asset_id)
            REFERENCES dbo.facility_assets(asset_id),
        CONSTRAINT FK_booking_alerts_booking_id FOREIGN KEY (booking_id)
            REFERENCES dbo.bookings(booking_id),
        CONSTRAINT FK_booking_alerts_staff_id FOREIGN KEY (acknowledged_by_staff_id)
            REFERENCES dbo.user_accounts(user_id),
        CONSTRAINT CK_booking_alerts_alert_type CHECK (
            alert_type IN (N'MaintenanceEscalated', N'RequiredAssetRelocated')
        ),
        -- Handling fields paired
        CONSTRAINT CK_booking_alerts_handled CHECK (
            (acknowledged_by_staff_id IS NULL AND acknowledged_at IS NULL)
            OR (acknowledged_by_staff_id IS NOT NULL AND acknowledged_at IS NOT NULL)
        ),
        -- Source-scope XOR: exactly one of maintenance_id / asset_id, matching alert_type
        CONSTRAINT CK_booking_alerts_source_scope CHECK (
            (alert_type = N'MaintenanceEscalated'  AND maintenance_id IS NOT NULL AND asset_id IS NULL)
            OR (alert_type = N'RequiredAssetRelocated' AND asset_id IS NOT NULL AND maintenance_id IS NULL)
        )
    );

    -- Per-scope deduplication. A single UNIQUE over a nullable source column would
    -- treat NULLs as distinct, so two filtered unique indexes are used.
    PRINT N'Creating filtered unique indexes on booking_alerts...';
    CREATE UNIQUE INDEX UQ_booking_alerts_maint ON dbo.booking_alerts (maintenance_id, booking_id)
        WHERE alert_type = N'MaintenanceEscalated';
    CREATE UNIQUE INDEX UQ_booking_alerts_asset  ON dbo.booking_alerts (asset_id, booking_id)
        WHERE alert_type = N'RequiredAssetRelocated';

    -- =========================================================================
    -- PHASE E — CONSTRAINTS & TRIGGERS (created via EXEC: CREATE TRIGGER must be
    --           the first statement in its batch, and this script is one batch)
    -- =========================================================================

    -- E1. TR_maintenance_impact_history — INSERT writes the creation row
    --     (old_impact_level = NULL); UPDATE writes a row only when impact_level
    --     actually changed. changed_by resolves from SESSION_CONTEXT with the
    --     fallback chain and is NEVER NULL/fabricated.
    PRINT N'Creating trigger TR_maintenance_impact_history...';
    EXEC(N'CREATE TRIGGER dbo.TR_maintenance_impact_history
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @actor INT = NULLIF(CONVERT(INT, SESSION_CONTEXT(N''current_user_id'')), 0);

    -- INSERT: creation row with old level NULL, actor falls back to reporter.
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
        -- UPDATE: row only when the level actually changed;
        -- actor falls back to assigned staff, then reporter.
        INSERT INTO dbo.maintenance_impact_history
            (maintenance_id, changed_by, old_impact_level, new_impact_level, changed_at, change_reason)
        SELECT i.maintenance_id,
               COALESCE(@actor, i.assigned_staff_id, i.reporter_id),
               d.impact_level, i.impact_level, GETDATE(), NULL
        FROM inserted i
        JOIN deleted d ON d.maintenance_id = i.maintenance_id
        WHERE d.impact_level <> i.impact_level;
    END
END;');

    -- E2. TR_bookings_AdvisoryAckRequired — enforces the mandatory statement order
    --     Pending -> Ack rows -> Approved (SQL Server has no deferred constraint
    --     triggers; this is the only workable pattern for manual, instant, and
    --     migration paths). Fires when a booking reaches Approved/CheckedIn and ANY
    --     active Advisory overlapping the window lacks a matching acknowledgement
    --     (NOT EXISTS, per-advisory) — not a COUNT-vs-COUNT comparison.
    PRINT N'Creating trigger TR_bookings_AdvisoryAckRequired...';
    EXEC(N'CREATE TRIGGER dbo.TR_bookings_AdvisoryAckRequired
ON dbo.bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.status IN (N''Approved'', N''CheckedIn'')
          AND EXISTS (
              SELECT 1
              FROM dbo.maintenance_records mr
              WHERE mr.space_id = i.space_id
                AND mr.impact_level = N''Advisory''
                AND mr.status NOT IN (N''Completed'', N''Cancelled'')
                AND mr.start_time < i.requested_end_time
                AND COALESCE(mr.completion_time, CAST(''9999-12-31 23:59:59'' AS DATETIME2)) > i.requested_start_time
                AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.booking_advisory_acknowledgments ack
                    WHERE ack.booking_id = i.booking_id
                      AND ack.maintenance_id = mr.maintenance_id
                )
          )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N''Every active advisory on this space must be acknowledged before the booking can be approved.'', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE b SET updated_at = GETDATE()
        FROM dbo.bookings b INNER JOIN inserted i ON b.booking_id = i.booking_id;
    END
END;');

    -- E3. TR_bookings_RequiredAssetCheck (Output 09 §7 R8) — block approval when a
    --     required facility type for the space has zero Available asset units,
    --     even with no space-level OutOfService record.
    PRINT N'Creating trigger TR_bookings_RequiredAssetCheck...';
    EXEC(N'CREATE TRIGGER dbo.TR_bookings_RequiredAssetCheck
ON dbo.bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.status IN (N''Approved'', N''CheckedIn'')
          AND EXISTS (
              SELECT 1
              FROM dbo.space_facility_requirements r
              WHERE r.space_id = i.space_id
                AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.facility_assets fa
                    WHERE fa.space_id = i.space_id
                      AND fa.facility_id = r.facility_id
                      AND fa.asset_status = N''Available''
                )
          )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N''A required facility for this space has no available unit; the booking cannot be approved.'', 16, 1);
        RETURN;
    END
END;');

    -- E4. TR_maintenance_SyncAssetStatus (Output 09 §5.6) — an active maintenance
    --     record targeting an asset flips its status to UnderMaintenance and, on
    --     completion/cancellation, releases it back to Available.
    PRINT N'Creating trigger TR_maintenance_SyncAssetStatus...';
    EXEC(N'CREATE TRIGGER dbo.TR_maintenance_SyncAssetStatus
ON dbo.maintenance_records
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @affected TABLE (asset_id INT NOT NULL);

    INSERT INTO @affected (asset_id)
        SELECT asset_id FROM inserted WHERE asset_id IS NOT NULL
        UNION
        SELECT asset_id FROM deleted WHERE asset_id IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @affected) RETURN;

    UPDATE fa
    SET fa.asset_status =
            CASE WHEN EXISTS (
                    SELECT 1 FROM dbo.maintenance_records mr
                    WHERE mr.asset_id = fa.asset_id
                      AND mr.impact_level = N''Advisory''
                      AND mr.status NOT IN (N''Completed'', N''Cancelled'')
                 )
                 THEN N''UnderMaintenance''
                 ELSE N''Available''
            END,
        fa.updated_at = GETDATE()
    FROM dbo.facility_assets fa
    WHERE fa.asset_id IN (SELECT asset_id FROM @affected);
END;');

    -- E5. TR_maintenance_ValidateAssetScope (Output 09 §5.11) — cross-consistency
    --     invariant: an asset-scoped maintenance record (asset_id set) must point
    --     at an asset located in the SAME space as the record. Cannot be a CHECK
    --     (cross-table), so it is enforced by this trigger and documented as an
    --     application invariant. Guards the R8/R2 logic, which assumes asset rows
    --     and maintenance rows agree on location.
    PRINT N'Creating trigger TR_maintenance_ValidateAssetScope...';
    EXEC(N'CREATE TRIGGER dbo.TR_maintenance_ValidateAssetScope
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.facility_assets fa ON fa.asset_id = i.asset_id
        WHERE i.asset_id IS NOT NULL
          AND fa.space_id <> i.space_id
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N''An asset-scoped maintenance record must reference an asset located in the same space as the record.'', 16, 1);
        RETURN;
    END
END;');

    -- E6. TR_maintenance_escalation (Output 09 §5.16) — fires on BOTH INSERT
    --     (a record created directly as OutOfService) and UPDATE (escalation
    --     Advisory -> OutOfService). One booking_alerts row per ALREADY-Approved/
    --     CheckedIn booking overlapping the maintenance window (the required
    --     escalation lookup). Staff handle notifications manually. NOT EXISTS +
    --     the filtered unique index UQ_booking_alerts_maint prevent duplicate
    --     alerts if the record is touched again.
    PRINT N'Creating trigger TR_maintenance_escalation...';
    EXEC(N'CREATE TRIGGER dbo.TR_maintenance_escalation
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.booking_alerts (maintenance_id, asset_id, booking_id, alert_type, created_at)
    SELECT i.maintenance_id,
           NULL,
           b.booking_id,
           N''MaintenanceEscalated'',
           GETDATE()
    FROM inserted i
    JOIN dbo.bookings b
      ON b.space_id = i.space_id
     AND b.status IN (N''Approved'', N''CheckedIn'')
     AND b.requested_start_time < COALESCE(i.completion_time, CAST(''9999-12-31 23:59:59'' AS DATETIME2))
     AND b.requested_end_time   > i.start_time
    WHERE i.impact_level = N''OutOfService''
      AND i.status NOT IN (N''Completed'', N''Cancelled'')
      AND NOT EXISTS (SELECT 1 FROM dbo.booking_alerts a
                      WHERE a.maintenance_id = i.maintenance_id
                        AND a.booking_id = b.booking_id
                        AND a.alert_type = N''MaintenanceEscalated'');
END;');

    -- E7. TR_facility_assets_RelocationAlert (Output 09 §5.16, [EXTENSION]) — on
    --     UPDATE facility_assets.space_id, flag every Approved/CheckedIn booking
    --     of the origin space when the moved unit''s facility type is required
    --     there (R8 relocation alert).
    PRINT N'Creating trigger TR_facility_assets_RelocationAlert...';
    EXEC(N'CREATE TRIGGER dbo.TR_facility_assets_RelocationAlert
ON dbo.facility_assets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM inserted i JOIN deleted d ON d.asset_id = i.asset_id
        WHERE COALESCE(i.space_id, 0) <> COALESCE(d.space_id, 0)
    ) RETURN;

    INSERT INTO dbo.booking_alerts (maintenance_id, asset_id, booking_id, alert_type, created_at)
    SELECT NULL, i.asset_id, b.booking_id, N''RequiredAssetRelocated'', GETDATE()
    FROM inserted i
    JOIN deleted d ON d.asset_id = i.asset_id
    JOIN dbo.space_facility_requirements r
      ON r.space_id = d.space_id AND r.facility_id = i.facility_id
    JOIN dbo.bookings b
      ON b.space_id = d.space_id
     AND b.status IN (N''Approved'', N''CheckedIn'')
    WHERE COALESCE(i.space_id, 0) <> COALESCE(d.space_id, 0)
      AND NOT EXISTS (SELECT 1 FROM dbo.booking_alerts a
                      WHERE a.asset_id = i.asset_id AND a.booking_id = b.booking_id
                        AND a.alert_type = N''RequiredAssetRelocated'');
END;');

    -- E8. TR_maintenance_SyncSpaceStatus — HIDDEN IMPLEMENTATION TRIGGER that
    --     keeps spaces.current_status consistent with maintenance impact levels,
    --     so the LEGACY Phase 1 trigger (TR_bookings_PreventOverlapAndUnavailable,
    --     which blocks Pending/Approved when current_status IN ('UnderMaintenance',
    --     'TemporarilyClosed','Retired')) treats rooms correctly WITHOUT any Phase 1
    --     code change:
    --       * any ACTIVE OutOfService record on the space  => 'UnderMaintenance'
    --                                                         (bookings blocked)
    --       * only Advisory records, or no records at all  => 'Available'
    --                                                         (Advisory rooms stay
    --                                                          bookable — this is
    --                                                          what "tricks" the
    --                                                          Phase 1 trigger)
    --     Guard: non-maintenance closure/live states ('TemporarilyClosed',
    --     'Retired','InUse') are NEVER overwritten to 'Available' — otherwise a
    --     Retired or TemporarilyClosed space with an advisory would become
    --     bookable, corrupting the Phase 1 baseline. Phase 1 current_status values
    --     are preserved at migration time; this trigger governs future changes.
    PRINT N'Creating hidden trigger TR_maintenance_SyncSpaceStatus...';
    EXEC(N'CREATE TRIGGER dbo.TR_maintenance_SyncSpaceStatus
ON dbo.maintenance_records
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @affected_spaces TABLE (space_id INT NOT NULL PRIMARY KEY);

    INSERT INTO @affected_spaces (space_id)
        SELECT space_id FROM inserted
        UNION
        SELECT space_id FROM deleted;

    IF NOT EXISTS (SELECT 1 FROM @affected_spaces) RETURN;

    UPDATE s
    SET s.current_status =
            CASE WHEN EXISTS (
                    SELECT 1 FROM dbo.maintenance_records mr
                    WHERE mr.space_id = s.space_id
                      AND mr.impact_level = N''OutOfService''
                      AND mr.status NOT IN (N''Completed'', N''Cancelled'')
                 )
                 THEN N''UnderMaintenance''
                 -- Release only maintenance-governed statuses back to Available;
                 -- never clobber explicit closures or live-use states.
                 WHEN s.current_status IN (N''UnderMaintenance'', N''Available'')
                 THEN N''Available''
                 ELSE s.current_status
            END,
        s.updated_at = GETDATE()
    FROM dbo.spaces s
    WHERE s.space_id IN (SELECT space_id FROM @affected_spaces);
END;');

    -- =========================================================================
    -- PHASE F — DERIVED VIEW (3NF): unit counts derived, never stored.
    --           Physical name v_space_facility_summary (Output 09 §6); the
    --           Output 08 §2.3 synonym is space_facility_summary.
    -- =========================================================================
    PRINT N'Creating view v_space_facility_summary...';
    EXEC(N'CREATE VIEW dbo.v_space_facility_summary AS
SELECT
    sf.space_id,
    sf.facility_id,
    f.facility_name,
    COUNT(fa.asset_id)                                  AS total_units,
    SUM(CASE WHEN fa.asset_status = N''Available'' THEN 1 ELSE 0 END) AS available_units,
    CASE WHEN r.facility_id IS NULL THEN 0 ELSE 1 END   AS is_required
FROM dbo.space_facilities sf
JOIN dbo.facilities f          ON f.facility_id = sf.facility_id
LEFT JOIN dbo.facility_assets fa
       ON fa.facility_id = sf.facility_id
      AND fa.space_id   = sf.space_id
LEFT JOIN dbo.space_facility_requirements r
       ON r.space_id = sf.space_id
      AND r.facility_id = sf.facility_id
GROUP BY sf.space_id, sf.facility_id, f.facility_name,
         CASE WHEN r.facility_id IS NULL THEN 0 ELSE 1 END;');

    -- =========================================================================
    -- PHASE G — PHASE 2 INDEXES (Output 09 §10). I1 (IX_bookings_space_status_time)
    --           is load-bearing for the SERIALIZABLE + UPDLOCK/HOLDLOCK
    --           concurrency conflict check; the others support the §1.3 reports,
    --           the room finder, and the maintenance impact lookups.
    -- =========================================================================

    -- I1: overlap-check range locking (conflict predicate) + report (a)/(b)
    PRINT N'Creating IX_bookings_space_status_time (filtered, concurrency load-bearing)...';
    CREATE INDEX IX_bookings_space_status_time ON dbo.bookings (space_id, requested_start_time, requested_end_time)
        WHERE status IN (N'Approved', N'CheckedIn');

    -- I2: semester-range scans for reports (a) approved hours / (b) weekday-hour
    PRINT N'Creating IX_bookings_space_status_start...';
    CREATE INDEX IX_bookings_space_status_start ON dbo.bookings (space_id, status, requested_start_time)
        WHERE status IN (N'Approved', N'CheckedIn', N'Completed');

    -- I3: active OutOfService blocking set for the impact-level check
    PRINT N'Creating IX_maintenance_blocking...';
    CREATE INDEX IX_maintenance_blocking ON dbo.maintenance_records (space_id, start_time, completion_time)
        WHERE impact_level = N'OutOfService' AND status NOT IN (N'Completed', N'Cancelled');

    -- I4: active advisory set for display + ack-completeness + room finder
    PRINT N'Creating IX_maintenance_advisory...';
    CREATE INDEX IX_maintenance_advisory ON dbo.maintenance_records (space_id, start_time, completion_time)
        WHERE impact_level = N'Advisory' AND status NOT IN (N'Completed', N'Cancelled');

    -- I5: escalation trigger window-overlap join
    PRINT N'Creating IX_maintenance_escalation_window...';
    CREATE INDEX IX_maintenance_escalation_window ON dbo.maintenance_records (impact_level, status, start_time, completion_time);

    -- I6: required-asset availability (R8) + v_space_facility_summary aggregation
    PRINT N'Creating IX_assets_location_status...';
    CREATE INDEX IX_assets_location_status ON dbo.facility_assets (space_id, facility_id, asset_status);

    -- I7: FK lookup / catalogue-type drill-downs
    PRINT N'Creating IX_assets_facility_id...';
    CREATE INDEX IX_assets_facility_id ON dbo.facility_assets (facility_id);

    -- I8/I9: ack-completeness joins
    PRINT N'Creating IX_ack_booking and IX_ack_maintenance...';
    CREATE INDEX IX_ack_booking      ON dbo.booking_advisory_acknowledgments (booking_id, maintenance_id);
    CREATE INDEX IX_ack_maintenance  ON dbo.booking_advisory_acknowledgments (maintenance_id);

    -- I10/I11: escalation / open action list
    PRINT N'Creating IX_alerts_maintenance and IX_alerts_open...';
    CREATE INDEX IX_alerts_maintenance ON dbo.booking_alerts (maintenance_id, booking_id);
    CREATE INDEX IX_alerts_open        ON dbo.booking_alerts (acknowledged_at) WHERE acknowledged_at IS NULL;

    -- I12: impact-change audit trail
    PRINT N'Creating IX_history_maintenance...';
    CREATE INDEX IX_history_maintenance ON dbo.maintenance_impact_history (maintenance_id, changed_at);

    -- I13: room finder (capacity + type), excludes permanently closed/retired
    PRINT N'Creating IX_roomfinder_capacity_type...';
    CREATE INDEX IX_roomfinder_capacity_type ON dbo.spaces (capacity, space_type)
        WHERE current_status IN (N'Available', N'InUse');

    -- I14/I15: auto-approval eligibility lookups
    PRINT N'Creating IX_policies_scope and IX_policies_booking_types...';
    CREATE INDEX IX_policies_scope        ON dbo.auto_approval_policies (space_type, is_active);
    CREATE INDEX IX_policies_booking_types ON dbo.policy_booking_types (booking_type, policy_id);

    -- UQ_auto_approval_policies_active_space_type: data-integrity guard — at most
    -- one ACTIVE type-wide policy per space_type. Filtered unique: SQL Server
    -- treats NULLs as distinct, so specific-space override rows (space_id set,
    -- space_type NULL) are untouched; only type-wide rows are constrained.
    PRINT N'Creating UQ_auto_approval_policies_active_space_type (filtered unique)...';
    CREATE UNIQUE INDEX UQ_auto_approval_policies_active_space_type
        ON dbo.auto_approval_policies (space_type)
        WHERE space_type IS NOT NULL AND is_active = 1;

    -- =========================================================================
    -- VERIFICATION (runs inside the transaction, before COMMIT)
    -- =========================================================================
    PRINT N'=== Verification ===';
    DECLARE @v_assets     INT = (SELECT COUNT(*) FROM dbo.facility_assets);
    DECLARE @v_sumqty     INT = (SELECT ISNULL(SUM(quantity),0) FROM dbo.space_facilities);
    DECLARE @v_hist     INT = (SELECT COUNT(*) FROM dbo.maintenance_impact_history);
    DECLARE @v_maint    INT = (SELECT COUNT(*) FROM dbo.maintenance_records);

    PRINT N'  facility_assets rows      : ' + CAST(@v_assets AS NVARCHAR(12));
    PRINT N'  SUM(space_facilities.qty) : ' + CAST(@v_sumqty  AS NVARCHAR(12));
    IF @v_assets <> @v_sumqty
    BEGIN
        PRINT N'  ERROR: total asset-row parity mismatch!';
    END
    ELSE
    BEGIN
        PRINT N'  OK: asset backfill matches space_facilities quantities.';
    END

    -- Detailed per-space parity check: identify EXACTLY which space_id (+facility_id)
    -- has SUM(quantity) <> COUNT(facility_assets rows), instead of a coarse total.
    DECLARE @parity CURSOR FOR
        SELECT sf.space_id, sf.facility_id,
               SUM(sf.quantity),
               (SELECT COUNT(*) FROM dbo.facility_assets fa
                WHERE fa.space_id = sf.space_id AND fa.facility_id = sf.facility_id)
        FROM dbo.space_facilities sf
        GROUP BY sf.space_id, sf.facility_id
        HAVING SUM(sf.quantity) <>
               (SELECT COUNT(*) FROM dbo.facility_assets fa
                WHERE fa.space_id = sf.space_id AND fa.facility_id = sf.facility_id);

    DECLARE @ps_id INT, @pf_id INT, @pexp INT, @pact INT, @pmis INT = 0;
    OPEN @parity;
    FETCH NEXT FROM @parity INTO @ps_id, @pf_id, @pexp, @pact;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @pmis = @pmis + 1;
        PRINT N'  ERROR: Space ' + CAST(@ps_id AS NVARCHAR(10)) + N' count mismatch';
        PRINT N'         (facility_id ' + CAST(@pf_id AS NVARCHAR(10)) +
              N': expected ' + CAST(@pexp AS NVARCHAR(10)) +
              N', actual ' + CAST(@pact AS NVARCHAR(10)) + N')';
        FETCH NEXT FROM @parity INTO @ps_id, @pf_id, @pexp, @pact;
    END
    CLOSE @parity;
    DEALLOCATE @parity;
    IF @pmis = 0
        PRINT N'  OK: per-space/facility asset counts all match.';
    ELSE
        PRINT N'  ERROR: ' + CAST(@pmis AS NVARCHAR(10)) +
              N' (space, facility) pair(s) have an asset-count mismatch.';

    PRINT N'  impact-history rows       : ' + CAST(@v_hist  AS NVARCHAR(12)) +
          N'  (maintenance records: ' + CAST(@v_maint AS NVARCHAR(12)) + N')';
    IF @v_hist < @v_maint
    BEGIN
        PRINT N'  WARNING: not every maintenance record has a history row.';
    END

    -- Data-preservation spot checks (Phase 1 counts must be unchanged by the DDL)
    DECLARE @v_bookings INT = (SELECT COUNT(*) FROM dbo.bookings);
    DECLARE @v_spaces   INT = (SELECT COUNT(*) FROM dbo.spaces);
    DECLARE @v_decisions INT = (SELECT COUNT(*) FROM dbo.booking_decisions);
    PRINT N'  bookings preserved: ' + CAST(@v_bookings AS NVARCHAR(12)) +
          N' | spaces: ' + CAST(@v_spaces AS NVARCHAR(12)) +
          N' | booking_decisions: ' + CAST(@v_decisions AS NVARCHAR(12));

    COMMIT TRANSACTION;
    PRINT N'=== Task 10 migration committed successfully. ===';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    PRINT N'ERROR ' + CAST(ERROR_NUMBER() AS NVARCHAR(12)) + N': ' + ERROR_MESSAGE();
    PRINT N'Migration rolled back — no partial Phase 2 schema applied.';
    THROW;
END CATCH;
GO