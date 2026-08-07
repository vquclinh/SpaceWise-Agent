-- =============================================================================
-- Campus Space Management System — Phase 2 Schema Migration (Task 10)
-- Group G08 — Microsoft SQL Server
-- Deliverable : outputs/10-schema-migration-G08.sql  (MERGED HYBRID)
-- Purpose    : Additive migration of the Phase 1 database (outputs 05 & 06)
--              into the Phase 2 schema defined in Output 09. Every Phase 2
--              extension is applied while preserving 100% of Phase 1 data
--              (no Phase 1 table, column, row, or constraint is dropped or
--              renamed).
--
-- HYBRID DESIGN (merge of two team drafts):
--   STAGE 1 — TRANSACTIONAL SCHEMA & DATA (one atomic transaction):
--             SET XACT_ABORT ON + BEGIN TRY + BEGIN TRANSACTION wraps every
--             CREATE TABLE / ALTER / backfill / index, so a failure rolls
--             back perfectly. Per-object idempotency guards (OBJECT_ID,
--             COL_LENGTH, sys.indexes, sys.constraints) make a full re-run
--             after a successful run a safe no-op. The facility_assets
--             backfill retains the advanced Numbers-table (CTE) serial-number
--             generator.
--             FAIL-FAST: if any statement fails, the CATCH block captures the
--             error (ERROR_MESSAGE/SEVERITY/STATE), rolls back, prints the
--             details, persists a #migration_failed session marker, and
--             re-raises the error via RAISERROR so client tools / CI-CD get a
--             non-zero exit code. (RAISERROR aborts the current batch, so a
--             SET NOEXEC after it in the same batch could never run.) The
--             batch right after the transaction consumes the marker and turns
--             on SET NOEXEC — every subsequent Stage 2 batch is then parsed
--             but NOT executed. SET NOEXEC OFF at the very end of the script
--             restores normal execution mode for the session.
--   STAGE 2 — LOGIC OBJECTS (after COMMIT + GO):
--             Triggers and the view are created AFTER the transaction as raw
--             T-SQL batches separated by GO, using CREATE OR ALTER (SQL Server
--             2016 SP1+) — no EXEC(N'...') strings, so the definitions keep
--             full readability and syntax highlighting. CREATE OR ALTER is
--             itself idempotent.
--
-- Merge notes (pass 3):
--   * Wrapper + backfill logic: taken from the original transactional draft.
--   * Idempotency guards + clean CREATE OR ALTER triggers/view: taken from
--     the friend draft (10-schema-migration-G08-friend.sql, now retired).
--   * 6 triggers (R3/R5/R7/R8/R9/R12) + 1 view moved to Stage 2, verbatim
--     from the friend draft (incl. TRIGGER_NESTLEVEL recursion guards, table
--     variables, and the SESSION_CONTEXT actor fallback chain ending in
--     reporter_id).
--   * The hidden TR_maintenance_SyncSpaceStatus trigger and the separate
--     TR_maintenance_ValidateAssetScope trigger from the earlier draft are NOT
--     carried over: the friend draft merges the asset-scope validation into
--     TR_maintenance_SyncAssetStatus (R7) and deliberately omits the space-
--     status syncing approach (which contradicted Output 08's architecture).
--   * Fail-fast (passes 4/5): the CATCH block re-raises the captured error
--     with RAISERROR (non-zero exit for CI-CD) BEFORE NOEXEC is engaged. A
--     #migration_failed marker persists across the GO boundary, so the batch
--     immediately after the transaction can SET NOEXEC ON (a SET placed after
--     RAISERROR inside the same batch would never execute — the raised error
--     aborts the batch). SET NOEXEC OFF resets the session at script end.
--
-- Run        : RE-RUNNABLE / IDEMPOTENT. Apply on a SQL Server 2016 SP1+
--              database where outputs/05 and 06 already ran. Validate on a
--              SQL Server-compatible environment only.
-- =============================================================================

-- Connection-level settings: required by SQL Server for filtered indexes,
-- indexed views, and trigger definitions (persist for the whole session;
-- do not rely on client-tool defaults for these).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

-- =============================================================================
-- STAGE 1 — TRANSACTIONAL SCHEMA & DATA
-- One batch, one transaction (XACT_ABORT ON): every statement below either
-- commits together or rolls back together. All DDL is guarded so a re-run
-- after a successful prior run performs no duplicate work.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT N'=== Task 10 Phase 2 migration begins ===';
PRINT N'Baseline: Phase 1 database (outputs 05 + 06) must already be present.';

-- Drop any fail-fast marker left by a previous failed run of this script in
-- the same session, so the CATCH block can re-create it idempotently.
IF OBJECT_ID(N'tempdb..#migration_failed') IS NOT NULL
    DROP TABLE #migration_failed;

BEGIN TRY
    BEGIN TRANSACTION;

    -- =========================================================================
    -- PHASE A — NEW STANDALONE TABLES (no dependency on Phase B/C artifacts)
    -- =========================================================================

    -- A1. auto_approval_policies (Output 09 §5.14)
    IF OBJECT_ID(N'dbo.auto_approval_policies', N'U') IS NULL
    BEGIN
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
            -- At most one policy per specific space (NULLs are distinct, so a
            -- plain UNIQUE on the nullable column only constrains non-NULL
            -- space_ids — exactly the desired space-specific scope).
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
    END

    -- A2. policy_booking_types (Output 09 §5.15) — junction, no array types in SQL Server
    IF OBJECT_ID(N'dbo.policy_booking_types', N'U') IS NULL
    BEGIN
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
    END

    -- A3. space_facility_requirements (Output 09 §5.7) — pure sparse junction.
    --     Presence of a row means "required"; there is NO is_required attribute
    --     column (it was removed in Output 09 for full 3NF).
    IF OBJECT_ID(N'dbo.space_facility_requirements', N'U') IS NULL
    BEGIN
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
    END

    -- =========================================================================
    -- PHASE B — facility_assets + BACKFILL BY EXPANDING space_facilities.quantity
    -- =========================================================================

    -- B1. facility_assets (Output 09 §5.6) + B2 backfill (Numbers-table, set-based).
    --     Serial-number scheme MUST be globally unique (UQ_..._serial_number is a
    --     GLOBAL unique), so it includes space_id + facility_id + sequence.
    --     The backfill is wrapped in EXEC(N'...'): this DML targets
    --     facility_assets, created by a CREATE TABLE earlier in this same batch,
    --     so compilation is deferred to runtime (after the table exists) —
    --     avoids any batch-compile resolution error while keeping the backfill
    --     inside the single transaction. Both table creation and backfill are
    --     guarded by the same OBJECT_ID check: a re-run skips both (no
    --     duplicate asset rows can be inserted).
    IF OBJECT_ID(N'dbo.facility_assets', N'U') IS NULL
    BEGIN
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
    END
    ELSE
    BEGIN
        PRINT N'  facility_assets already exists — table creation + backfill skipped (idempotent re-run).';
    END

    -- =========================================================================
    -- PHASE C — ALTER EXISTING PHASE 1 TABLES (additive + data backfill)
    -- =========================================================================

    -- C1. maintenance_records: add asset_id (FK -> facility_assets) + impact_level.
    --     Order matters: asset_id is added NULL first, then impact_level is
    --     backfilled NOT NULL DEFAULT N'OutOfService' (Phase 1's blanket
    --     blocking rule), then the CHECK constraints are added — legacy rows
    --     (asset_id NULL, impact_level OutOfService) pass
    --     CK_maintenance_records_asset_scope_level because asset_id IS NULL.
    --     The transient DEFAULT is dropped afterwards so future inserts must
    --     state the level explicitly (Output 08 §2.2).
    IF COL_LENGTH(N'dbo.maintenance_records', N'asset_id') IS NULL
    BEGIN
        PRINT N'Adding asset_id to maintenance_records...';
        ALTER TABLE dbo.maintenance_records
            ADD asset_id INT NULL;
    END

    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE name = N'FK_maintenance_records_asset_id'
    )
    BEGIN
        PRINT N'Adding FK_maintenance_records_asset_id...';
        ALTER TABLE dbo.maintenance_records
            ADD CONSTRAINT FK_maintenance_records_asset_id
                FOREIGN KEY (asset_id) REFERENCES dbo.facility_assets(asset_id);
    END

    IF COL_LENGTH(N'dbo.maintenance_records', N'impact_level') IS NULL
    BEGIN
        PRINT N'Adding impact_level to maintenance_records (default backfills legacy rows to OutOfService)...';
        ALTER TABLE dbo.maintenance_records
            ADD impact_level NVARCHAR(20) NOT NULL
                CONSTRAINT DF_maintenance_records_impact_level DEFAULT (N'OutOfService');
    END

    IF NOT EXISTS (
        SELECT 1 FROM sys.check_constraints
        WHERE name = N'CK_maintenance_records_impact_level'
    )
    BEGIN
        PRINT N'Adding CK_maintenance_records_impact_level...';
        ALTER TABLE dbo.maintenance_records
            ADD CONSTRAINT CK_maintenance_records_impact_level CHECK (
                impact_level IN (N'Advisory', N'OutOfService')
            );
    END

    -- Only space-level records may be OutOfService; asset-scoped records are
    -- structurally forced to Advisory (one broken unit never closes a room).
    IF NOT EXISTS (
        SELECT 1 FROM sys.check_constraints
        WHERE name = N'CK_maintenance_records_asset_scope_level'
    )
    BEGIN
        PRINT N'Adding CK_maintenance_records_asset_scope_level...';
        ALTER TABLE dbo.maintenance_records
            ADD CONSTRAINT CK_maintenance_records_asset_scope_level CHECK (
                asset_id IS NULL OR impact_level = N'Advisory'
            );
    END

    -- Drop the backfill default after all legacy rows carry the value.
    IF EXISTS (
        SELECT 1 FROM sys.default_constraints
        WHERE name = N'DF_maintenance_records_impact_level'
    )
    BEGIN
        PRINT N'Dropping impact_level backfill default constraint...';
        ALTER TABLE dbo.maintenance_records
            DROP CONSTRAINT DF_maintenance_records_impact_level;
    END

    -- C2. booking_decisions: make decided_by nullable + add decision_source
    IF COL_LENGTH(N'dbo.booking_decisions', N'decision_source') IS NULL
    BEGIN
        PRINT N'Adding booking_decisions.decision_source (default backfills legacy rows to Staff)...';
        ALTER TABLE dbo.booking_decisions
            ADD decision_source NVARCHAR(10) NOT NULL
                CONSTRAINT DF_booking_decisions_decision_source DEFAULT (N'Staff');
    END

    IF EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.booking_decisions')
          AND name = N'decided_by'
          AND is_nullable = 0
    )
    BEGIN
        PRINT N'Making booking_decisions.decided_by nullable (System decisions have no staff actor)...';
        ALTER TABLE dbo.booking_decisions ALTER COLUMN decided_by INT NULL;
    END

    IF NOT EXISTS (
        SELECT 1 FROM sys.check_constraints
        WHERE name = N'CK_booking_decisions_decision_source'
    )
    BEGIN
        PRINT N'Adding CK_booking_decisions_decision_source...';
        ALTER TABLE dbo.booking_decisions
            ADD CONSTRAINT CK_booking_decisions_decision_source CHECK (
                decision_source IN (N'Staff', N'System')
            );
    END

    -- Paired source/actor check (added after backfill: all legacy rows are
    -- Staff + decided_by NOT NULL, so it validates immediately).
    IF NOT EXISTS (
        SELECT 1 FROM sys.check_constraints
        WHERE name = N'CK_booking_decisions_source_actor'
    )
    BEGIN
        PRINT N'Adding CK_booking_decisions_source_actor...';
        ALTER TABLE dbo.booking_decisions
            ADD CONSTRAINT CK_booking_decisions_source_actor CHECK (
                (decision_source = N'System' AND decided_by IS NULL)
                OR (decision_source = N'Staff'  AND decided_by IS NOT NULL)
            );
    END

    -- =========================================================================
    -- PHASE D — REMAINING NEW TABLES THAT REFERENCE ALTERED / NEW TABLES
    -- =========================================================================

    -- D1. maintenance_impact_history (Output 09 §5.13) — escalation/downgrade audit
    IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
    BEGIN
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

        -- Audit-trail completeness: the ALTER TABLE ... ADD with a DEFAULT
        -- backfilled impact_level WITHOUT firing AFTER triggers, so legacy
        -- records have no history row. Insert one creation row per legacy
        -- record so the audit trail never omits them (changed_by = reporter_id,
        -- the never-NULL fallback). Wrapped in EXEC(N'...'): this DML reads
        -- maintenance_records.impact_level, a column added by ALTER TABLE
        -- earlier in this same batch — EXEC defers compilation to runtime,
        -- avoiding an 'Invalid column name' batch-parse failure while the
        -- whole migration stays inside the single transaction. Only runs when
        -- the table was just created (re-run = no-op).
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
    END

    -- D2. booking_advisory_acknowledgments (Output 09 §5.12) — legal consent record
    IF OBJECT_ID(N'dbo.booking_advisory_acknowledgments', N'U') IS NULL
    BEGIN
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
    END

    -- D3. booking_alerts (Output 09 §5.16) — persisted escalation / relocation lookup
    IF OBJECT_ID(N'dbo.booking_alerts', N'U') IS NULL
    BEGIN
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

        -- Per-scope deduplication. A single UNIQUE over a nullable source
        -- column would treat NULLs as distinct, so two filtered unique
        -- indexes are used (Output 09 §5.16).
        PRINT N'Creating filtered unique indexes on booking_alerts...';
        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes
            WHERE name = N'UQ_booking_alerts_maint'
              AND object_id = OBJECT_ID(N'dbo.booking_alerts')
        )
            CREATE UNIQUE INDEX UQ_booking_alerts_maint ON dbo.booking_alerts (maintenance_id, booking_id)
                WHERE alert_type = N'MaintenanceEscalated';

        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes
            WHERE name = N'UQ_booking_alerts_asset'
              AND object_id = OBJECT_ID(N'dbo.booking_alerts')
        )
            CREATE UNIQUE INDEX UQ_booking_alerts_asset ON dbo.booking_alerts (asset_id, booking_id)
                WHERE alert_type = N'RequiredAssetRelocated';
    END

    -- =========================================================================
    -- PHASE E — PHASE 2 INDEXES (Output 09 §10). I1 (IX_bookings_space_status_time)
    --           is load-bearing for the SERIALIZABLE + UPDLOCK/HOLDLOCK
    --           concurrency conflict check; the others support the §1.3 reports,
    --           the room finder, and the maintenance impact lookups.
    -- =========================================================================

    -- I1: overlap-check range locking (conflict predicate) + report (a)/(b)
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_bookings_space_status_time'
          AND object_id = OBJECT_ID(N'dbo.bookings')
    )
    BEGIN
        PRINT N'Creating IX_bookings_space_status_time (filtered, concurrency load-bearing)...';
        CREATE INDEX IX_bookings_space_status_time ON dbo.bookings (space_id, requested_start_time, requested_end_time)
            WHERE status IN (N'Approved', N'CheckedIn');
    END

    -- I2: semester-range scans for reports (a) approved hours / (b) weekday-hour
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_bookings_space_status_start'
          AND object_id = OBJECT_ID(N'dbo.bookings')
    )
    BEGIN
        PRINT N'Creating IX_bookings_space_status_start...';
        CREATE INDEX IX_bookings_space_status_start ON dbo.bookings (space_id, status, requested_start_time)
            WHERE status IN (N'Approved', N'CheckedIn', N'Completed');
    END

    -- I3: active OutOfService blocking set for the impact-level check
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_maintenance_blocking'
          AND object_id = OBJECT_ID(N'dbo.maintenance_records')
    )
    BEGIN
        PRINT N'Creating IX_maintenance_blocking...';
        CREATE INDEX IX_maintenance_blocking ON dbo.maintenance_records (space_id, start_time, completion_time)
            WHERE impact_level = N'OutOfService' AND status NOT IN (N'Completed', N'Cancelled');
    END

    -- I4: active advisory set for display + ack-completeness + room finder
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_maintenance_advisory'
          AND object_id = OBJECT_ID(N'dbo.maintenance_records')
    )
    BEGIN
        PRINT N'Creating IX_maintenance_advisory...';
        CREATE INDEX IX_maintenance_advisory ON dbo.maintenance_records (space_id, start_time, completion_time)
            WHERE impact_level = N'Advisory' AND status NOT IN (N'Completed', N'Cancelled');
    END

    -- I5: escalation trigger window-overlap join
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_maintenance_escalation_window'
          AND object_id = OBJECT_ID(N'dbo.maintenance_records')
    )
    BEGIN
        PRINT N'Creating IX_maintenance_escalation_window...';
        CREATE INDEX IX_maintenance_escalation_window ON dbo.maintenance_records (impact_level, status, start_time, completion_time);
    END

    -- I6: required-asset availability (R8) + v_space_facility_summary aggregation
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_assets_location_status'
          AND object_id = OBJECT_ID(N'dbo.facility_assets')
    )
    BEGIN
        PRINT N'Creating IX_assets_location_status...';
        CREATE INDEX IX_assets_location_status ON dbo.facility_assets (space_id, facility_id, asset_status);
    END

    -- I7: FK lookup / catalogue-type drill-downs
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_assets_facility_id'
          AND object_id = OBJECT_ID(N'dbo.facility_assets')
    )
    BEGIN
        PRINT N'Creating IX_assets_facility_id...';
        CREATE INDEX IX_assets_facility_id ON dbo.facility_assets (facility_id);
    END

    -- I8/I9: ack-completeness joins
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_ack_booking'
          AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgments')
    )
    BEGIN
        PRINT N'Creating IX_ack_booking...';
        CREATE INDEX IX_ack_booking ON dbo.booking_advisory_acknowledgments (booking_id, maintenance_id);
    END

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_ack_maintenance'
          AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgments')
    )
    BEGIN
        PRINT N'Creating IX_ack_maintenance...';
        CREATE INDEX IX_ack_maintenance ON dbo.booking_advisory_acknowledgments (maintenance_id);
    END

    -- I10/I11: escalation / open action list
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_alerts_maintenance'
          AND object_id = OBJECT_ID(N'dbo.booking_alerts')
    )
    BEGIN
        PRINT N'Creating IX_alerts_maintenance...';
        CREATE INDEX IX_alerts_maintenance ON dbo.booking_alerts (maintenance_id, booking_id);
    END

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_alerts_open'
          AND object_id = OBJECT_ID(N'dbo.booking_alerts')
    )
    BEGIN
        PRINT N'Creating IX_alerts_open...';
        CREATE INDEX IX_alerts_open ON dbo.booking_alerts (acknowledged_at) WHERE acknowledged_at IS NULL;
    END

    -- I12: impact-change audit trail
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_history_maintenance'
          AND object_id = OBJECT_ID(N'dbo.maintenance_impact_history')
    )
    BEGIN
        PRINT N'Creating IX_history_maintenance...';
        CREATE INDEX IX_history_maintenance ON dbo.maintenance_impact_history (maintenance_id, changed_at);
    END

    -- I13: room finder (capacity + type), excludes permanently closed/retired
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_roomfinder_capacity_type'
          AND object_id = OBJECT_ID(N'dbo.spaces')
    )
    BEGIN
        PRINT N'Creating IX_roomfinder_capacity_type...';
        CREATE INDEX IX_roomfinder_capacity_type ON dbo.spaces (capacity, space_type)
            WHERE current_status IN (N'Available', N'InUse');
    END

    -- I14/I15: auto-approval eligibility lookups
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_policies_scope'
          AND object_id = OBJECT_ID(N'dbo.auto_approval_policies')
    )
    BEGIN
        PRINT N'Creating IX_policies_scope...';
        CREATE INDEX IX_policies_scope ON dbo.auto_approval_policies (space_type, is_active);
    END

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_policies_booking_types'
          AND object_id = OBJECT_ID(N'dbo.policy_booking_types')
    )
    BEGIN
        PRINT N'Creating IX_policies_booking_types...';
        CREATE INDEX IX_policies_booking_types ON dbo.policy_booking_types (booking_type, policy_id);
    END

    -- UQ_auto_approval_policies_active_space_type: data-integrity guard — at most
    -- one ACTIVE type-wide policy per space_type. Filtered unique: SQL Server
    -- treats NULLs as distinct, so specific-space override rows (space_id set,
    -- space_type NULL) are untouched; only type-wide rows are constrained.
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'UQ_auto_approval_policies_active_space_type'
          AND object_id = OBJECT_ID(N'dbo.auto_approval_policies')
    )
    BEGIN
        PRINT N'Creating UQ_auto_approval_policies_active_space_type (filtered unique)...';
        CREATE UNIQUE INDEX UQ_auto_approval_policies_active_space_type
            ON dbo.auto_approval_policies (space_type)
            WHERE space_type IS NOT NULL AND is_active = 1;
    END

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
    -- Capture the error payload immediately (ERROR_*() functions are only
    -- meaningful inside the CATCH scope).
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrState INT = ERROR_STATE();

    -- RAISERROR treats its message string as a printf-style format string:
    -- escape any literal '%' so a message containing one (e.g. a conversion
    -- error quoting a value such as '50% off') cannot raise a secondary
    -- format error (10360) that would mask the real failure.
    DECLARE @ErrMsgRaise NVARCHAR(4000) = REPLACE(@ErrMsg, N'%', N'%%');

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT N'ERROR ' + CAST(ERROR_NUMBER() AS NVARCHAR(12)) + N': ' + @ErrMsg;
    PRINT N'Migration rolled back — no partial Phase 2 schema applied.';

    -- Session-persistent failure marker: RAISERROR below (severity >= 11)
    -- ABORTS the current batch, so a SET NOEXEC written after it here would
    -- never execute — that would silently re-break the fail-fast mechanism.
    -- The marker survives the GO boundary and is consumed by the FAIL-FAST
    -- SAFETY LOCK batch that follows.
    CREATE TABLE #migration_failed (error_message NVARCHAR(4000) NOT NULL);
    INSERT INTO #migration_failed (error_message) VALUES (@ErrMsg);

    -- Signal a hard failure to the client / CI-CD BEFORE NOEXEC is engaged:
    -- an unhandled severity-11+ error produces a non-zero exit code (e.g.
    -- sqlcmd -b / a CI pipeline) and is surfaced in SSMS messages. This is
    -- what turns a silent, "successful-looking" rollback into a real failure.
    RAISERROR(@ErrMsgRaise, @ErrSeverity, @ErrState);
END CATCH;
GO

-- =============================================================================
-- FAIL-FAST SAFETY LOCK (batch immediately after the transactional stage)
-- When Stage 1 failed, the CATCH block left the #temporary marker behind;
-- this batch consumes it and turns on SET NOEXEC — a session-level switch
-- that takes effect immediately, so every subsequent batch (Stage 2:
-- triggers + view) is parsed but NEVER executed, even though the client
-- keeps sending batches past the GO separators. When Stage 1 committed, no
-- marker exists and this batch is a no-op (NOEXEC stays OFF for Stage 2).
-- =============================================================================
IF OBJECT_ID(N'tempdb..#migration_failed') IS NOT NULL
BEGIN
    PRINT N'Stage 1 failed — SET NOEXEC ON engaged; Stage 2 (triggers + view) is SKIPPED.';
    SET NOEXEC ON;
END
GO

-- =============================================================================
-- STAGE 2 — LOGIC OBJECTS (created AFTER the transactional stage)
-- Raw T-SQL batches separated by GO, using CREATE OR ALTER (SQL Server 2016
-- SP1+). No EXEC(N'...') strings: full readability, syntax highlighting, and
-- idempotent re-runs (CREATE OR ALTER preserves permissions on re-apply).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TRIGGER 1 — TR_maintenance_impact_history (R9, Output 09 §5.13)
-- INSERT  → writes the creation row (old_impact_level = NULL).
-- UPDATE  → writes one row per real impact_level change.
-- Actor fallback chain (SESSION_CONTEXT is unreliable inside triggers):
--   UPDATE: changed_by = COALESCE(actor, assigned_staff_id, reporter_id)
--   INSERT: changed_by = COALESCE(actor, reporter_id)
-- Never NULL, never fabricated.
-- change_reason: explicit CONVERT(NVARCHAR(MAX), SESSION_CONTEXT(...)) because
-- SESSION_CONTEXT returns SQL_VARIANT (data-type safety).
-- ---------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.TR_maintenance_impact_history
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @actor_id INT = TRY_CONVERT(INT, SESSION_CONTEXT(N'current_user_id'));

    -- Creation rows (INSERT only).
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.maintenance_impact_history
            (maintenance_id, changed_by, old_impact_level, new_impact_level,
             changed_at, change_reason)
        SELECT i.maintenance_id,
               COALESCE(@actor_id, i.reporter_id),
               NULL,
               i.impact_level,
               GETDATE(),
               N'Creation'
        FROM inserted i;
        RETURN;
    END

    -- Escalation/downgrade rows (UPDATE only, and only when the level changed).
    IF UPDATE(impact_level)
    BEGIN
        INSERT INTO dbo.maintenance_impact_history
            (maintenance_id, changed_by, old_impact_level, new_impact_level,
             changed_at, change_reason)
        SELECT i.maintenance_id,
               COALESCE(@actor_id, i.assigned_staff_id, i.reporter_id),
               d.impact_level,
               i.impact_level,
               GETDATE(),
               CONVERT(NVARCHAR(MAX), SESSION_CONTEXT(N'impact_change_reason'))
        FROM inserted i
        INNER JOIN deleted d
            ON d.maintenance_id = i.maintenance_id
        WHERE ISNULL(d.impact_level, N'') <> ISNULL(i.impact_level, N'');
    END
END
GO

-- ---------------------------------------------------------------------------
-- TRIGGER 2 — TR_maintenance_SyncAssetStatus (R7, Output 09 §5.6)
-- Keeps facility_assets.asset_status in sync with active maintenance records:
--   * any ACTIVE (not Completed/Cancelled) record targeting the asset → the
--     unit is flipped to 'UnderMaintenance'.
--   * when no active record targets the unit any more → it is released back
--     to 'Available' (only if it is currently showing 'UnderMaintenance', so
--     'InUse' / 'Retired' staff-set states are never stomped).
-- Also enforces the cross-table invariant that an asset-scoped record may only
-- reference an asset currently housed in the record's own space (Output 09
-- §5.11: cannot be a CHECK because it is cross-table — enforced here in the
-- trigger path).
-- ---------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.TR_maintenance_SyncAssetStatus
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    -- Invariant guard: an asset-scoped record must reference an asset housed
    -- in the record's own space. Cannot be a normal CHECK (cross-table).
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.facility_assets fa
            ON fa.asset_id = i.asset_id
        WHERE i.asset_id IS NOT NULL
          AND fa.space_id <> i.space_id
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N'Maintenance record references an asset that is not housed in the record''s space.', 16, 1);
        RETURN;
    END

    -- Affected asset set (INSERTED ∪ DELETED asset_id, ignoring space-level rows).
    -- Table variable: avoids TempDB allocation/logging contention under high
    -- concurrency (small, single-statement lifetime — never spilled to disk).
    DECLARE @mv_sync_affected TABLE (asset_id INT NOT NULL);

    INSERT INTO @mv_sync_affected (asset_id)
    SELECT DISTINCT asset_id
    FROM (
        SELECT asset_id FROM inserted WHERE asset_id IS NOT NULL
        UNION ALL
        SELECT asset_id FROM deleted WHERE asset_id IS NOT NULL
    ) AS src;

    IF NOT EXISTS (SELECT 1 FROM @mv_sync_affected)
        RETURN;

    -- 1) Active maintenance targets the asset → UnderMaintenance.
    --    (Asset-scoped records are structurally Advisory per
    --    CK_maintenance_records_asset_scope_level, so no impact filter needed.)
    UPDATE fa
    SET fa.asset_status = N'UnderMaintenance'
    FROM dbo.facility_assets fa
    INNER JOIN @mv_sync_affected x ON x.asset_id = fa.asset_id
    WHERE fa.asset_status <> N'Retired'
      AND EXISTS (
          SELECT 1
          FROM dbo.maintenance_records m
          WHERE m.asset_id = fa.asset_id
            AND m.status NOT IN (N'Completed', N'Cancelled')
      );

    -- 2) No active maintenance targets it, and it was flipped by (1) → Available.
    UPDATE fa
    SET fa.asset_status = N'Available'
    FROM dbo.facility_assets fa
    INNER JOIN @mv_sync_affected x ON x.asset_id = fa.asset_id
    WHERE fa.asset_status = N'UnderMaintenance'
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.maintenance_records m
          WHERE m.asset_id = fa.asset_id
            AND m.status NOT IN (N'Completed', N'Cancelled')
      );
END
GO

-- ---------------------------------------------------------------------------
-- TRIGGER 3 — TR_maintenance_escalation (R5, Output 09 §5.16)
-- Generates booking_alerts (alert_type = 'MaintenanceEscalated') for every
-- already-Approved/CheckedIn booking overlapping the maintenance window, when
-- a record becomes OutOfService — on INSERT (created at OutOfService) or on
-- UPDATE (escalation Advisory → OutOfService).
-- EXCEPT-based transition detection: an UPDATE that leaves the row already
-- OutOfService (e.g. editing the problem description) does not re-run the
-- overlap scan. NOT EXISTS guard + the filtered unique index
-- UQ_booking_alerts_maint make the alert set idempotent (escalate → downgrade
-- → escalate again yields no duplicate rows).
-- ---------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.TR_maintenance_escalation
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    -- m = rows now OutOfService & active, minus rows already OutOfService
    -- before the statement (EXCEPT neutralises both INSERT and UPDATE).
    INSERT INTO dbo.booking_alerts (maintenance_id, booking_id, alert_type)
    SELECT m.maintenance_id,
           b.booking_id,
           N'MaintenanceEscalated'
    FROM (
        SELECT i.maintenance_id, i.space_id, i.start_time, i.completion_time
        FROM inserted i
        WHERE i.impact_level = N'OutOfService'
          AND i.status NOT IN (N'Completed', N'Cancelled')
        EXCEPT
        SELECT d.maintenance_id, d.space_id, d.start_time, d.completion_time
        FROM deleted d
        WHERE d.impact_level = N'OutOfService'
    ) m
    INNER JOIN dbo.bookings b
        ON  b.space_id   = m.space_id
        AND b.status     IN (N'Approved', N'CheckedIn')
        AND b.requested_start_time < COALESCE(m.completion_time, CAST('9999-12-31' AS DATETIME2))
        AND b.requested_end_time   > m.start_time
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.booking_alerts a
        WHERE a.alert_type      = N'MaintenanceEscalated'
          AND a.maintenance_id  = m.maintenance_id
          AND a.booking_id      = b.booking_id
    );
END
GO

-- ---------------------------------------------------------------------------
-- TRIGGER 4 — TR_facility_assets_RelocationAlert (R12, [EXTENSION])
-- Output 09 §5.16/§11. When an asset is relocated OUT of a space where its
-- facility type is REQUIRED, every Approved/CheckedIn booking of the origin
-- space is flagged with alert_type = 'RequiredAssetRelocated'.
-- Ghost-alert guards: the alert fires ONLY when
--   (1) the location actually changed (i.space_id <> d.space_id), AND
--   (2) the asset was in a working state before the move
--       (d.asset_status = N'Available') — moving a unit that was already
--       UnderMaintenance / InUse / Retired must not raise the alert, AND
--   (3) no other Available unit of the same facility type remains in the
--       origin space (the relocation actually leaves the space short).
-- NOT EXISTS guard + filtered unique index UQ_booking_alerts_asset keep the
-- alert set idempotent.
-- ---------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.TR_facility_assets_RelocationAlert
ON dbo.facility_assets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    INSERT INTO dbo.booking_alerts (asset_id, booking_id, alert_type)
    SELECT i.asset_id,
           b.booking_id,
           N'RequiredAssetRelocated'
    FROM inserted i
    INNER JOIN deleted d
        ON d.asset_id = i.asset_id
    INNER JOIN dbo.space_facility_requirements r
        ON  r.space_id    = d.space_id
        AND r.facility_id = i.facility_id
    INNER JOIN dbo.bookings b
        ON  b.space_id = d.space_id
        AND b.status   IN (N'Approved', N'CheckedIn')
    WHERE i.space_id <> d.space_id          -- location actually changed
      AND d.asset_status = N'Available'     -- was working before the move
      AND NOT EXISTS (                      -- no other Available unit remains
          SELECT 1
          FROM dbo.facility_assets fa2
          WHERE fa2.space_id     = d.space_id
            AND fa2.facility_id  = i.facility_id
            AND fa2.asset_status = N'Available'
      )
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.booking_alerts a
          WHERE a.alert_type = N'RequiredAssetRelocated'
            AND a.asset_id   = i.asset_id
            AND a.booking_id = b.booking_id
      );
END
GO

-- ---------------------------------------------------------------------------
-- TRIGGER 5 — TR_bookings_AdvisoryAckRequired (R3, Output 09 §5.12)
-- A booking may not reach (or remain in) Approved/CheckedIn while any ACTIVE
-- ADVISORY maintenance record overlaps its reserved window without a matching
-- booking_advisory_acknowledgments row. Statement order inside the booking
-- procedures (Pending → acks → Approved) satisfies the check; this trigger is
-- the rule-validation backstop for any path that bypasses the procedures.
-- ---------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.TR_bookings_AdvisoryAckRequired
ON dbo.bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        CROSS APPLY (
            SELECT COUNT(DISTINCT m.maintenance_id) AS advisory_count
            FROM dbo.maintenance_records m
            WHERE m.space_id = i.space_id
              AND m.impact_level = N'Advisory'
              AND m.status NOT IN (N'Completed', N'Cancelled')
              AND m.start_time < i.requested_end_time
              AND COALESCE(m.completion_time, CAST('9999-12-31' AS DATETIME2)) > i.requested_start_time
        ) adv
        CROSS APPLY (
            SELECT COUNT(DISTINCT a.maintenance_id) AS ack_count
            FROM dbo.booking_advisory_acknowledgments a
            WHERE a.booking_id = i.booking_id
        ) ack
        WHERE i.status IN (N'Approved', N'CheckedIn')
          AND adv.advisory_count > ack.ack_count
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N'Every active advisory on this space must be acknowledged before the booking can be approved/checked in.', 16, 1);
        RETURN;
    END
END
GO

-- ---------------------------------------------------------------------------
-- TRIGGER 6 — TR_bookings_RequiredAssetCheck (R8, Output 09 §7)
-- A booking may not reach Approved/CheckedIn while any facility type marked
-- REQUIRED for the space has no Available unit (even without a space-level
-- OutOfService record). Asset-level maintenance is always 'Advisory' (per
-- CK_maintenance_records_asset_scope_level) — an unavailable last unit closes
-- the space only through this path.
-- ---------------------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.TR_bookings_RequiredAssetCheck
ON dbo.bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL() > 1 RETURN;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.space_facility_requirements r
            ON r.space_id = i.space_id
        WHERE i.status IN (N'Approved', N'CheckedIn')
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.facility_assets fa
              WHERE fa.facility_id  = r.facility_id
                AND fa.space_id     = r.space_id
                AND fa.asset_status = N'Available'
          )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR(N'A required facility for this space currently has no available unit.', 16, 1);
        RETURN;
    END
END
GO

-- ---------------------------------------------------------------------------
-- VIEW — v_space_facility_summary (Output 09 §6)
-- 3NF: unit counts are derived from facility_assets rows, never stored.
-- The Phase 1 space_facilities.quantity stays as catalogue metadata only.
-- CREATE OR ALTER VIEW (preserves permissions, idempotent re-runs).
-- ---------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.v_space_facility_summary
AS
SELECT
    sf.space_id,
    sf.facility_id,
    f.facility_name,
    COUNT(fa.asset_id)                                          AS total_units,
    SUM(CASE WHEN fa.asset_status = N'Available' THEN 1 ELSE 0 END) AS available_units,
    CAST(CASE WHEN r.facility_id IS NULL THEN 0 ELSE 1 END AS BIT) AS is_required
FROM dbo.space_facilities sf
JOIN dbo.facilities f
    ON f.facility_id = sf.facility_id
LEFT JOIN dbo.facility_assets fa
    ON  fa.facility_id = sf.facility_id
    AND fa.space_id    = sf.space_id
LEFT JOIN dbo.space_facility_requirements r
    ON  r.space_id    = sf.space_id
    AND r.facility_id = sf.facility_id
GROUP BY sf.space_id, sf.facility_id, f.facility_name,
         CASE WHEN r.facility_id IS NULL THEN 0 ELSE 1 END;
GO

-- =============================================================================
-- POST-MIGRATION VERIFICATION QUERIES (run manually if desired)
-- =============================================================================
--
-- -- Verify the 7 new tables + 2 modified tables.
-- SELECT name, type_desc FROM sys.tables
-- WHERE name IN (N'facility_assets', N'space_facility_requirements',
--                N'auto_approval_policies', N'policy_booking_types',
--                N'maintenance_impact_history', N'booking_advisory_acknowledgments',
--                N'booking_alerts')
-- ORDER BY name;
--
-- -- Verify impact_level backfill (should be 0 rows / all legacy = OutOfService).
-- SELECT impact_level, COUNT(*) AS rows FROM dbo.maintenance_records GROUP BY impact_level;
--
-- -- Verify the XOR scope checks reject invalid alert rows.
-- INSERT INTO dbo.booking_alerts (maintenance_id, asset_id, booking_id, alert_type)
-- VALUES (NULL, NULL, 1, N'MaintenanceEscalated');      -- must FAIL (source NULL)
-- INSERT INTO dbo.booking_alerts (maintenance_id, asset_id, booking_id, alert_type)
-- VALUES (1, 1, 1, N'MaintenanceEscalated');            -- must FAIL (both set)
--
-- -- Verify the filtered unique indexes reject duplicates per source scope.
-- INSERT INTO dbo.booking_alerts (maintenance_id, booking_id, alert_type)
-- VALUES (1, 1, N'MaintenanceEscalated');
-- INSERT INTO dbo.booking_alerts (maintenance_id, booking_id, alert_type)
-- VALUES (1, 1, N'MaintenanceEscalated');               -- must FAIL (duplicate)

-- =============================================================================
-- DELIVERABLE SUMMARY (Task 10)
-- =============================================================================
--
-- NEW TABLES (7):        facility_assets, space_facility_requirements,
--                        auto_approval_policies, policy_booking_types,
--                        maintenance_impact_history,
--                        booking_advisory_acknowledgments, booking_alerts
-- MODIFIED TABLES (2):   maintenance_records (+impact_level NOT NULL backfilled
--                        'OutOfService', +asset_id, +CK impact_level,
--                        +CK asset_scope_level, +FK asset_id; transient
--                        default dropped) and booking_decisions
--                        (+decision_source DEFAULT 'Staff', decided_by → NULL,
--                        +CK decision_source, +CK source_actor XOR)
-- PRESERVED (idempotent): all Phase 1 tables, columns, constraints, indexes,
--                        triggers and data — additive-only migration.
-- FILTERED UNIQUE INDEXES (2): UQ_booking_alerts_maint, UQ_booking_alerts_asset
-- VIEW (1):              v_space_facility_summary (CREATE OR ALTER)
-- INDEXES (15):          I1–I15 from Output 09 §10 (+ UQ_auto_approval_policies_
--                        active_space_type; I16 = Phase 1 implicit UNIQUE)
-- TRIGGERS (6 + Phase 1 backstop retained; all CREATE OR ALTER + recursion
-- guarded):
--                        TR_maintenance_impact_history   (R9)
--                        TR_maintenance_SyncAssetStatus  (R7 + cross-table guard)
--                        TR_maintenance_escalation       (R5)
--                        TR_facility_assets_RelocationAlert (R12 [EXTENSION])
--                        TR_bookings_AdvisoryAckRequired (R3)
--                        TR_bookings_RequiredAssetCheck  (R8)
--                        TR_bookings_PreventOverlapAndUnavailable (Phase 1, backstop)
-- 100% Microsoft SQL Server syntax; no PostgreSQL constructs; no ON DELETE CASCADE.
-- =============================================================================

-- =============================================================================
-- FAIL-FAST RESET
-- If Stage 1 failed, the FAIL-FAST SAFETY LOCK batch (right after the
-- transactional stage) set SET NOEXEC ON, which suppressed every Stage 2
-- batch (triggers + view) in this session. Restore normal execution mode so
-- the user's session is not left in NOEXEC mode after the script ends.
-- When Stage 1 committed successfully, NOEXEC was never set and this line is
-- a harmless no-op.
-- =============================================================================
SET NOEXEC OFF;
