-- =============================================================================
-- Campus Space Management System — Phase 2 Schema Migration
-- Group G08 — Microsoft SQL Server (only permitted DBMS)
-- Phase 2, Task 10: Schema Migration
-- Deliverable: outputs/10-schema-migration-G08.sql
-- =============================================================================
--
-- BASELINE:
--   This script runs on a database already built with
--   outputs/05-db-definition-G08.sql (the Phase 1 schema, 9 tables + indexes +
--   the overlap/unavailable trigger) and populated with
--   outputs/06-sample-data-G08.sql.
--
-- ADDITIVE / DATA-PRESERVING GUARANTEES (non-negotiable):
--   * No DROP TABLE, TRUNCATE TABLE, DROP COLUMN, DROP CONSTRAINT, or DROP INDEX
--     on ANY Phase 1 object.
--   * Every Phase 1 table, column, constraint, index, and trigger stays exactly
--     as Phase 1 created it. Existing Phase 1 rows are never deleted or rewritten.
--   * Phase 2 only ADDS objects, and ADDS columns/constraints to the two Phase 1
--     tables marked [Modified] in outputs/09-updated-erd-and-logical-design-G08.md:
--       - maintenance_records  (+ impact_level, + asset_id)
--       - booking_decisions    (+ decision_source, decided_by becomes nullable)
--     The single permitted Phase 1 definition change is the nullability of
--     booking_decisions.decided_by (Output 09 section 4.2).
--   * The migration is purely additive; the concurrency-safe stored procedures
--     belong to Tasks 11-13/15 and are NOT written here.
--
-- RUN INSTRUCTIONS:
--   * Run on a SQL Server-compatible environment ONLY (local SQL Server, a SQL
--     Server container, or Azure SQL). Never PostgreSQL / MySQL / Supabase.
--   * Take a full database backup before running.
--   * QUOTED_IDENTIFIER must be ON for every session that writes to bookings:
--     the filtered index IX_bookings_space_status_time (section 4.1) requires
--     it. In particular, the Phase 1 baseline (outputs/05) must be built with
--     QUOTED_IDENTIFIER ON (the SSMS default, or `sqlcmd -I`) so the Phase 1
--     trigger TR_bookings_PreventOverlapAndUnavailable is created with that
--     setting — a trigger created with QUOTED_IDENTIFIER OFF would fail (error
--     1934) when its internal updated_at refresh touches the new filtered
--     index. The migration itself sets QUOTED_IDENTIFIER ON and ANSI_NULLS ON
--     at the top of this script.
--   * The entire migration is wrapped in ONE transaction: SET XACT_ABORT ON +
--     BEGIN TRANSACTION ... final XACT_STATE() commit/rollback guard, so a
--     failure at any point leaves the database exactly as it was. GO separates
--     batches but does NOT end the transaction.
--
-- OBJECT CREATION PLAN (mandatory execution order, per the Task 10 skill):
--   1. New standalone tables (FK-dependency order):
--        auto_approval_policies (09:4.6) -> policy_booking_types (09:4.7)
--        -> space_facility_requirements (09:4.9) -> maintenance_impact_history (09:4.3)
--        -> booking_advisory_acknowledgments (09:4.4) -> booking_alerts (09:4.5)
--   2. facility_assets (09:4.8) + backfill by expanding space_facilities.quantity
--   3. ALTER the two Phase 1 tables: maintenance_records (09:4.1) and
--      booking_decisions (09:4.2), with data backfills
--   4. Supporting indexes (09:7) incl. the filtered IX_bookings_space_status_time
--      and the two filtered UNIQUE indexes on auto_approval_policies (09:4.6)
--   5. Derived-fact view space_facility_summary (09:8 / 09:9.8)
--   6. Task-10 triggers (09:10): impact-history audit, escalation/downgrade
--      alerts, advisory-ack requirement, required-asset block
--   7. Closing summary + verification queries
-- =============================================================================

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
PRINT N'Phase 2 schema migration started (all changes are transactional).';
GO

-- =============================================================================
-- 1. NEW STANDALONE TABLES (Output 09 sections 4.6, 4.7, 4.9, 4.3, 4.4, 4.5)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1.1 auto_approval_policies (Output 09 section 4.6)
--     Instant-booking eligibility configuration. Exactly one of
--     (space_type / space_id) must be set; the two natural UKs (specific-space
--     override; active space_type) are enforced by filtered UNIQUE indexes in
--     section 4.2.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.auto_approval_policies', N'U') IS NULL
BEGIN
    PRINT N'Creating table auto_approval_policies...';
    CREATE TABLE auto_approval_policies (
        policy_id             INT            NOT NULL IDENTITY(1,1),
        space_type            NVARCHAR(30)   NULL,
        space_id              INT            NULL,
        max_participants      INT            NULL,
        requires_advisory_ack BIT            NOT NULL DEFAULT 1,
        is_active             BIT            NOT NULL DEFAULT 1,
        created_at            DATETIME2      NOT NULL DEFAULT GETDATE(),
        updated_at            DATETIME2      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT PK_auto_approval_policies PRIMARY KEY (policy_id),
        CONSTRAINT FK_auto_approval_policies_space_id FOREIGN KEY (space_id)
            REFERENCES spaces(space_id),
        CONSTRAINT CK_auto_approval_policies_space_type CHECK (
            space_type IN ('Auditorium', 'Classroom', 'ComputerLaboratory',
                           'ProjectLaboratory', 'MeetingRoom', 'StudentWorkspace')
        ),
        CONSTRAINT CK_auto_approval_policies_max_participants CHECK (
            max_participants IS NULL OR max_participants > 0
        ),
        CONSTRAINT CK_auto_approval_policies_exactly_one_target CHECK (
            (space_type IS NULL AND space_id IS NOT NULL)
            OR (space_type IS NOT NULL AND space_id IS NULL)
        )
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.2 policy_booking_types (Output 09 section 4.7)
--     Junction for the allowed booking_type values of a policy (SQL Server has
--     no array type). booking_type CHECK mirrors the Phase 1 CK_bookings_booking_type.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.policy_booking_types', N'U') IS NULL
BEGIN
    PRINT N'Creating table policy_booking_types...';
    CREATE TABLE policy_booking_types (
        policy_id    INT            NOT NULL,
        booking_type NVARCHAR(30)   NOT NULL,
        CONSTRAINT PK_policy_booking_types PRIMARY KEY (policy_id, booking_type),
        CONSTRAINT FK_policy_booking_types_policy_id FOREIGN KEY (policy_id)
            REFERENCES auto_approval_policies(policy_id),
        CONSTRAINT CK_policy_booking_types_booking_type CHECK (
            booking_type IN ('Lecture', 'Examination', 'Seminar', 'Workshop',
                             'Meeting', 'StudentActivity', 'AdministrativeEvent',
                             'ResearchActivity', 'ProjectWork')
        )
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.3 space_facility_requirements (Output 09 section 4.9)
--     Sparse-list convention: presence in the table means the facility type is
--     REQUIRED for the space (is_required defaults to 1; do not insert 0 rows).
--     Drives the required-asset availability block (Output 09 section 10).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.space_facility_requirements', N'U') IS NULL
BEGIN
    PRINT N'Creating table space_facility_requirements...';
    CREATE TABLE space_facility_requirements (
        space_id    INT NOT NULL,
        facility_id INT NOT NULL,
        is_required BIT NOT NULL DEFAULT 1,
        CONSTRAINT PK_space_facility_requirements PRIMARY KEY (space_id, facility_id),
        CONSTRAINT FK_space_facility_requirements_space_id FOREIGN KEY (space_id)
            REFERENCES spaces(space_id),
        CONSTRAINT FK_space_facility_requirements_facility_id FOREIGN KEY (facility_id)
            REFERENCES facilities(facility_id)
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.4 maintenance_impact_history (Output 09 section 4.3)
--     Escalation/downgrade audit trail, populated by TR_maintenance_impact_history
--     (old_impact_level = NULL on the creation row; changed_by resolved via the
--     SESSION_CONTEXT fallback chain, never NULL or fabricated).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
BEGIN
    PRINT N'Creating table maintenance_impact_history...';
    CREATE TABLE maintenance_impact_history (
        history_id       INT            NOT NULL IDENTITY(1,1),
        maintenance_id   INT            NOT NULL,
        old_impact_level NVARCHAR(20)   NULL,
        new_impact_level NVARCHAR(20)   NOT NULL,
        changed_by       INT            NOT NULL,
        changed_at       DATETIME2      NOT NULL,
        change_reason    NVARCHAR(200)  NULL,
        CONSTRAINT PK_maintenance_impact_history PRIMARY KEY (history_id),
        CONSTRAINT FK_maintenance_impact_history_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES maintenance_records(maintenance_id),
        CONSTRAINT FK_maintenance_impact_history_changed_by FOREIGN KEY (changed_by)
            REFERENCES user_accounts(user_id),
        CONSTRAINT CK_maintenance_impact_history_old_impact_level CHECK (
            old_impact_level IS NULL OR old_impact_level IN ('Advisory', 'OutOfService')
        ),
        CONSTRAINT CK_maintenance_impact_history_new_impact_level CHECK (
            new_impact_level IN ('Advisory', 'OutOfService')
        )
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.5 booking_advisory_acknowledgments (Output 09 section 4.4)
--     One acknowledgement row per (booking, active advisory). The composite
--     natural UK (booking_id, maintenance_id) guarantees one ack per advisory
--     per booking; the surrogate ack_id exists for FK ergonomics only.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.booking_advisory_acknowledgments', N'U') IS NULL
BEGIN
    PRINT N'Creating table booking_advisory_acknowledgments...';
    CREATE TABLE booking_advisory_acknowledgments (
        ack_id          INT            NOT NULL IDENTITY(1,1),
        booking_id      INT            NOT NULL,
        maintenance_id  INT            NOT NULL,
        acknowledged_by INT            NOT NULL,
        acknowledged_at DATETIME2      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT PK_booking_advisory_acknowledgments PRIMARY KEY (ack_id),
        CONSTRAINT UQ_booking_advisory_ack_booking_maintenance UNIQUE (booking_id, maintenance_id),
        CONSTRAINT FK_booking_advisory_ack_booking_id FOREIGN KEY (booking_id)
            REFERENCES bookings(booking_id),
        CONSTRAINT FK_booking_advisory_ack_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES maintenance_records(maintenance_id),
        CONSTRAINT FK_booking_advisory_ack_acknowledged_by FOREIGN KEY (acknowledged_by)
            REFERENCES user_accounts(user_id)
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.6 booking_alerts (Output 09 section 4.5)
--     Escalation consequence list: one 'MaintenanceEscalated' alert per affected
--     Approved/CheckedIn booking, populated by TR_maintenance_escalation and
--     consumed by report (d) / Task 16.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.booking_alerts', N'U') IS NULL
BEGIN
    PRINT N'Creating table booking_alerts...';
    CREATE TABLE booking_alerts (
        alert_id                 INT            NOT NULL IDENTITY(1,1),
        maintenance_id           INT            NOT NULL,
        booking_id               INT            NOT NULL,
        alert_type               NVARCHAR(30)   NOT NULL,
        created_at               DATETIME2      NOT NULL DEFAULT GETDATE(),
        acknowledged_by_staff_id INT            NULL,
        acknowledged_at          DATETIME2      NULL,
        CONSTRAINT PK_booking_alerts PRIMARY KEY (alert_id),
        CONSTRAINT FK_booking_alerts_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES maintenance_records(maintenance_id),
        CONSTRAINT FK_booking_alerts_booking_id FOREIGN KEY (booking_id)
            REFERENCES bookings(booking_id),
        CONSTRAINT FK_booking_alerts_acknowledged_by_staff_id FOREIGN KEY (acknowledged_by_staff_id)
            REFERENCES user_accounts(user_id),
        CONSTRAINT CK_booking_alerts_alert_type CHECK (
            alert_type IN ('MaintenanceEscalated')
        )
    );
END
GO

-- =============================================================================
-- 2. facility_assets + BACKFILL (Output 09 section 4.8, section 5)
-- =============================================================================
-- Individual facility units with serial numbers. One row per physical unit.
-- Phase 1 space_facilities.quantity stays as catalogue metadata; unit counts
-- are derived from these rows via the space_facility_summary view (section 5),
-- never re-synced.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.facility_assets', N'U') IS NULL
BEGIN
    PRINT N'Creating table facility_assets...';
    CREATE TABLE facility_assets (
        asset_id          INT            NOT NULL IDENTITY(1,1),
        facility_id       INT            NOT NULL,
        space_id          INT            NOT NULL,
        serial_number     NVARCHAR(40)   NOT NULL,
        asset_status      NVARCHAR(20)   NOT NULL,
        condition         NVARCHAR(200)  NULL,
        last_checked_date DATE           NULL,
        created_at        DATETIME2      NOT NULL DEFAULT GETDATE(),
        updated_at        DATETIME2      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT PK_facility_assets PRIMARY KEY (asset_id),
        CONSTRAINT UQ_facility_assets_serial_number UNIQUE (serial_number),
        CONSTRAINT FK_facility_assets_facility_id FOREIGN KEY (facility_id)
            REFERENCES facilities(facility_id),
        CONSTRAINT FK_facility_assets_space_id FOREIGN KEY (space_id)
            REFERENCES spaces(space_id),
        CONSTRAINT CK_facility_assets_asset_status CHECK (
            asset_status IN ('Available', 'InUse', 'UnderMaintenance', 'Retired')
        )
    );
END
GO

-- Backfill: expand every space_facilities.quantity > 0 into that many asset
-- rows. Serial numbers are GLOBALLY unique (serial_number is a UNIQUE column):
-- a global ROW_NUMBER() across all units guarantees no collision even when the
-- same facility appears in several spaces. Phase 1 had no asset-level state,
-- so every migrated unit is 'Available'.
IF OBJECT_ID(N'dbo.facility_assets', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM facility_assets)
BEGIN
    DECLARE @max_qty INT = (SELECT MAX(quantity) FROM space_facilities);
    IF @max_qty IS NULL
        SET @max_qty = 0;

    PRINT N'Backfilling facility_assets from space_facilities.quantity...';
    WITH numbers(n) AS (
        SELECT 1 AS n
        UNION ALL
        SELECT n + 1 AS n
        FROM numbers
        WHERE n < @max_qty
    ),
    units AS (
        SELECT sf.space_id,
               sf.facility_id,
               sf.condition,
               n.n AS unit_no
        FROM space_facilities sf
        INNER JOIN numbers n ON n.n <= sf.quantity
        WHERE sf.quantity > 0
    )
    INSERT INTO facility_assets
        (facility_id, space_id, serial_number, asset_status, condition, last_checked_date, created_at, updated_at)
    SELECT u.facility_id,
           u.space_id,
           N'FAC-' + CAST(u.facility_id AS NVARCHAR(10))
                 + N'-' + RIGHT(N'000000' + CAST(ROW_NUMBER() OVER (ORDER BY u.facility_id, u.space_id, u.unit_no) AS NVARCHAR(10)), 6)
                   AS serial_number,
           N'Available' AS asset_status,
           u.condition,
           NULL,
           GETDATE(),
           GETDATE()
    FROM units u
    OPTION (MAXRECURSION 0);

    PRINT N'  facility_assets backfill complete.';
END
GO

-- =============================================================================
-- 3. ALTER THE TWO PHASE 1 TABLES (Output 09 sections 4.1 and 4.2)
--    Guarded and additive; only the specified nullability change is made.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 3.1 maintenance_records: add impact_level (Output 09 section 4.1)
--     Existing Phase 1 rows are backfilled to 'OutOfService' (Phase 1's blanket
--     rule == out-of-service) via a temporary DEFAULT that is then dropped, so
--     future inserts must state the level explicitly.
-- ---------------------------------------------------------------------------
-- NOTE: each ALTER (ADD column / ADD constraint / DROP default) is in its own
-- batch because SQL Server binds column references at batch-compile time: a
-- CHECK or FK that references a column added in the SAME batch fails with
-- "Invalid column name". The transaction still spans all batches.
IF COL_LENGTH(N'dbo.maintenance_records', N'impact_level') IS NULL
BEGIN
    PRINT N'Adding impact_level to maintenance_records...';
    ALTER TABLE maintenance_records ADD impact_level NVARCHAR(20) NOT NULL
        CONSTRAINT DF_maintenance_records_impact_level DEFAULT 'OutOfService';
    PRINT N'  Backfilled existing maintenance rows to impact_level = ''OutOfService''.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_maintenance_records_impact_level')
BEGIN
    PRINT N'Adding CK_maintenance_records_impact_level...';
    ALTER TABLE maintenance_records ADD CONSTRAINT CK_maintenance_records_impact_level
        CHECK (impact_level IN ('Advisory', 'OutOfService'));
END
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_maintenance_records_impact_level')
BEGIN
    PRINT N'Dropping temporary DEFAULT DF_maintenance_records_impact_level (future inserts must state impact_level).';
    ALTER TABLE maintenance_records DROP CONSTRAINT DF_maintenance_records_impact_level;
END
GO

-- ---------------------------------------------------------------------------
-- 3.2 maintenance_records: add asset_id FK (Output 09 section 4.1)
--     NULL = space-level record (Phase 1 behavior); non-NULL = scoped to one
--     unit. Existing Phase 1 records are space-level, so asset_id stays NULL.
--     (facility_assets already exists from section 2, so the FK target is valid.)
-- ---------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.maintenance_records', N'asset_id') IS NULL
BEGIN
    PRINT N'Adding asset_id to maintenance_records...';
    ALTER TABLE maintenance_records ADD asset_id INT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_maintenance_records_asset_id')
BEGIN
    PRINT N'Adding FK_maintenance_records_asset_id -> facility_assets.asset_id...';
    ALTER TABLE maintenance_records ADD CONSTRAINT FK_maintenance_records_asset_id
        FOREIGN KEY (asset_id) REFERENCES facility_assets(asset_id);
END
GO

-- ---------------------------------------------------------------------------
-- 3.3 booking_decisions: add decision_source (Output 09 section 4.2)
--     The DEFAULT 'Staff' backfills every existing Phase 1 decision (all were
--     staff-made) and is KEPT as the permanent default (unlike impact_level).
-- ---------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.booking_decisions', N'decision_source') IS NULL
BEGIN
    PRINT N'Adding decision_source to booking_decisions...';
    ALTER TABLE booking_decisions ADD decision_source NVARCHAR(10) NOT NULL
        CONSTRAINT DF_booking_decisions_decision_source DEFAULT 'Staff';
    PRINT N'  Backfilled existing decisions to decision_source = ''Staff''.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_booking_decisions_decision_source')
BEGIN
    PRINT N'Adding CK_booking_decisions_decision_source...';
    ALTER TABLE booking_decisions ADD CONSTRAINT CK_booking_decisions_decision_source
        CHECK (decision_source IN ('Staff', 'System'));
END
GO

-- ---------------------------------------------------------------------------
-- 3.4 booking_decisions: make decided_by nullable + pairing CHECK
--     (Output 09 section 4.2). System decisions have no staff actor, so
--     decided_by becomes NULLable and the same-table CHECK pairs
--     decision_source with the null-ness of decided_by.
-- ---------------------------------------------------------------------------
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.booking_decisions')
      AND name = N'decided_by'
      AND is_nullable = 0
)
BEGIN
    PRINT N'Altering booking_decisions.decided_by to NULL (System decisions have no staff actor)...';
    ALTER TABLE booking_decisions ALTER COLUMN decided_by INT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_booking_decisions_decision_source_actor')
BEGIN
    PRINT N'Adding CK_booking_decisions_decision_source_actor (pairing source with actor)...';
    ALTER TABLE booking_decisions ADD CONSTRAINT CK_booking_decisions_decision_source_actor
        CHECK (
            (decision_source = 'System' AND decided_by IS NULL)
            OR (decision_source = 'Staff' AND decided_by IS NOT NULL)
        );
END
GO

-- =============================================================================
-- 4. SUPPORTING INDEXES (Output 09 sections 7.1 and 7.2)
--    All created after the tables/ALTERs and before the triggers.
-- =============================================================================

-- 4.1 Filtered conflict-check index (Output 09 section 7.1) — the physical
--     structural requirement that enables SERIALIZABLE + WITH (UPDLOCK, HOLDLOCK)
--     key-range locking on the shared booking conflict check (Tasks 11-13/15).
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_bookings_space_status_time' AND object_id = OBJECT_ID(N'dbo.bookings')
)
BEGIN
    PRINT N'Creating filtered index IX_bookings_space_status_time (conflict-check range locking)...';
    CREATE NONCLUSTERED INDEX IX_bookings_space_status_time
        ON bookings (space_id, requested_start_time, requested_end_time)
        WHERE status IN ('Approved', 'CheckedIn');
END

-- 4.2 Filtered UNIQUE indexes on auto_approval_policies (Output 09 section 4.6)
--     SQL Server has no partial UNIQUE *constraint* syntax, so the two natural
--     candidate keys are enforced as filtered UNIQUE indexes:
--       - at most one specific-space override policy per space
--       - at most one ACTIVE type-level policy per space type
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_auto_approval_policies_space_id' AND object_id = OBJECT_ID(N'dbo.auto_approval_policies')
)
BEGIN
    PRINT N'Creating filtered UNIQUE index UQ_auto_approval_policies_space_id...';
    CREATE UNIQUE NONCLUSTERED INDEX UQ_auto_approval_policies_space_id
        ON auto_approval_policies (space_id)
        WHERE space_id IS NOT NULL;
END

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_auto_approval_policies_active_space_type' AND object_id = OBJECT_ID(N'dbo.auto_approval_policies')
)
BEGIN
    PRINT N'Creating filtered UNIQUE index UQ_auto_approval_policies_active_space_type...';
    CREATE UNIQUE NONCLUSTERED INDEX UQ_auto_approval_policies_active_space_type
        ON auto_approval_policies (space_type)
        WHERE space_type IS NOT NULL AND is_active = 1;
END

-- 4.3 Supporting Phase 2 indexes (Output 09 section 7.2).
--     IX_facility_assets_serial_number is deliberately NOT created separately:
--     the UQ_facility_assets_serial_number UNIQUE constraint already creates the
--     backing unique index (avoiding a duplicate index).
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_facility_assets_space_facility_status' AND object_id = OBJECT_ID(N'dbo.facility_assets')
)
BEGIN
    PRINT N'Creating IX_facility_assets_space_facility_status...';
    CREATE NONCLUSTERED INDEX IX_facility_assets_space_facility_status
        ON facility_assets (space_id, facility_id, asset_status);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_maintenance_records_impact_level' AND object_id = OBJECT_ID(N'dbo.maintenance_records')
)
BEGIN
    PRINT N'Creating IX_maintenance_records_impact_level...';
    CREATE NONCLUSTERED INDEX IX_maintenance_records_impact_level
        ON maintenance_records (space_id, status, impact_level, start_time, completion_time);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_maintenance_impact_history_mid' AND object_id = OBJECT_ID(N'dbo.maintenance_impact_history')
)
BEGIN
    PRINT N'Creating IX_maintenance_impact_history_mid...';
    CREATE NONCLUSTERED INDEX IX_maintenance_impact_history_mid
        ON maintenance_impact_history (maintenance_id);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_booking_advisory_ack_booking' AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgments')
)
BEGIN
    PRINT N'Creating IX_booking_advisory_ack_booking...';
    CREATE NONCLUSTERED INDEX IX_booking_advisory_ack_booking
        ON booking_advisory_acknowledgments (booking_id);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_booking_alerts_booking' AND object_id = OBJECT_ID(N'dbo.booking_alerts')
)
BEGIN
    PRINT N'Creating IX_booking_alerts_booking...';
    CREATE NONCLUSTERED INDEX IX_booking_alerts_booking
        ON booking_alerts (booking_id);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_auto_approval_policies_active' AND object_id = OBJECT_ID(N'dbo.auto_approval_policies')
)
BEGIN
    PRINT N'Creating IX_auto_approval_policies_active...';
    CREATE NONCLUSTERED INDEX IX_auto_approval_policies_active
        ON auto_approval_policies (space_type, space_id, is_active);
END
GO

-- =============================================================================
-- 5. DERIVED-FACT VIEW: space_facility_summary (Output 09 sections 8 and 9.8)
--    Unit counts are DERIVED from facility_assets rows, never stored (a stored
--    count would break 3NF by summarising facility_assets). Phase 1
--    space_facilities.quantity remains catalogue metadata and is NOT re-synced.
-- =============================================================================
IF OBJECT_ID(N'dbo.space_facility_summary', N'V') IS NULL
BEGIN
    PRINT N'Creating view space_facility_summary (derived unit counts)...';
    EXEC(N'CREATE VIEW space_facility_summary AS
           SELECT fa.space_id,
                  fa.facility_id,
                  COUNT_BIG(*)                                                   AS total_units,
                  SUM(CASE WHEN fa.asset_status = ''Available'' THEN 1 ELSE 0 END) AS available_units
           FROM facility_assets fa
           GROUP BY fa.space_id, fa.facility_id;');
END
GO

-- =============================================================================
-- 6. TASK-10 TRIGGERS (Output 09 section 10)
--    Every trigger is AFTER INSERT, UPDATE, isolated in its own GO batch
--    (CREATE TRIGGER must be the first statement in its batch), and rejects a
--    violating statement with ROLLBACK TRANSACTION; RAISERROR(...); RETURN;
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 6.1 TR_maintenance_impact_history — escalation/downgrade audit trail
--     (Output 09 sections 4.3 and 10).
--       * INSERT: records the initial level with old_impact_level = NULL and
--         changed_by = reporter_id.
--       * UPDATE: records only when impact_level ACTUALLY changed, using the
--         changed_by fallback chain
--         COALESCE(SESSION_CONTEXT('current_user_id'), assigned_staff_id, reporter_id).
--       * Refreshes maintenance_records.updated_at on UPDATE.
--     NOTE: this is the ONLY maintenance_records trigger that refreshes
--     updated_at. TR_maintenance_escalation does not, which prevents
--     nested-trigger ping-pong (nested triggers are ON by default while
--     RECURSIVE_TRIGGERS is OFF).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.TR_maintenance_impact_history', N'TR') IS NOT NULL
    EXEC(N'DROP TRIGGER dbo.TR_maintenance_impact_history;');
GO

CREATE TRIGGER TR_maintenance_impact_history
ON maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT transition: initial impact level (deleted is empty on INSERT).
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO maintenance_impact_history
            (maintenance_id, old_impact_level, new_impact_level, changed_by, changed_at, change_reason)
        SELECT i.maintenance_id,
               NULL,
               i.impact_level,
               i.reporter_id,
               GETDATE(),
               NULL
        FROM inserted i;
    END

    -- UPDATE transition: only when impact_level actually changed.
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO maintenance_impact_history
            (maintenance_id, old_impact_level, new_impact_level, changed_by, changed_at, change_reason)
        SELECT i.maintenance_id,
               d.impact_level,
               i.impact_level,
               COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')),
                        i.assigned_staff_id,
                        i.reporter_id),
               GETDATE(),
               NULL
        FROM inserted i
        INNER JOIN deleted d ON d.maintenance_id = i.maintenance_id
        WHERE i.impact_level <> d.impact_level;
    END

    -- Keep maintenance_records.updated_at fresh on UPDATE only.
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE m
        SET updated_at = GETDATE()
        FROM maintenance_records m
        INNER JOIN inserted i ON m.maintenance_id = i.maintenance_id;
    END
END;
GO

-- ---------------------------------------------------------------------------
-- 6.2 TR_maintenance_escalation — escalation alerts + downgrade auto-close
--     (Output 09 section 10).
--       * Escalation to 'OutOfService' (record created as OutOfService, or
--         updated to OutOfService): inserts one booking_alerts row
--         ('MaintenanceEscalated') per already-Approved/CheckedIn booking that
--         overlaps the maintenance interval. Duplicate OPEN alerts are
--         suppressed; a re-escalation after a downgrade creates a fresh alert.
--       * Downgrade 'OutOfService' -> 'Advisory': auto-closes every still-open
--         alert for the record (acknowledged_at + acknowledged_by_staff_id),
--         because the out-of-service block that justified them has been lifted.
--         The audit row for the downgrade is written by
--         TR_maintenance_impact_history.
--     This trigger does NOT refresh updated_at (see note at 6.1).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.TR_maintenance_escalation', N'TR') IS NOT NULL
    EXEC(N'DROP TRIGGER dbo.TR_maintenance_escalation;');
GO

CREATE TRIGGER TR_maintenance_escalation
ON maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Escalation -> OutOfService: alert every affected active booking.
    IF EXISTS (SELECT 1 FROM inserted i WHERE i.impact_level = 'OutOfService')
    BEGIN
        INSERT INTO booking_alerts
            (maintenance_id, booking_id, alert_type, created_at, acknowledged_by_staff_id, acknowledged_at)
        SELECT i.maintenance_id,
               b.booking_id,
               'MaintenanceEscalated',
               GETDATE(),
               NULL,
               NULL
        FROM inserted i
        INNER JOIN bookings b
            ON  b.space_id = i.space_id
            AND b.status IN ('Approved', 'CheckedIn')
            AND b.requested_start_time < COALESCE(i.completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2))
            AND b.requested_end_time   > i.start_time
        WHERE i.impact_level = 'OutOfService'
          AND i.status NOT IN ('Completed', 'Cancelled')
          AND NOT EXISTS (
              SELECT 1
              FROM booking_alerts ba
              WHERE ba.maintenance_id = i.maintenance_id
                AND ba.booking_id      = b.booking_id
                AND ba.alert_type      = 'MaintenanceEscalated'
                AND ba.acknowledged_at IS NULL
          );
    END

    -- Downgrade OutOfService -> Advisory: auto-close unresolved alerts.
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON d.maintenance_id = i.maintenance_id
        WHERE d.impact_level = 'OutOfService'
          AND i.impact_level = 'Advisory'
    )
    BEGIN
        UPDATE ba
        SET ba.acknowledged_at          = GETDATE(),
            ba.acknowledged_by_staff_id = COALESCE(CONVERT(INT, SESSION_CONTEXT(N'current_user_id')),
                                                   i.assigned_staff_id,
                                                   i.reporter_id)
        FROM booking_alerts ba
        INNER JOIN inserted i ON ba.maintenance_id = i.maintenance_id
        INNER JOIN deleted d ON d.maintenance_id  = i.maintenance_id
        WHERE d.impact_level = 'OutOfService'
          AND i.impact_level = 'Advisory'
          AND ba.acknowledged_at IS NULL;
    END
END;
GO

-- ---------------------------------------------------------------------------
-- 6.3 TR_bookings_AdvisoryAckRequired — mandatory advisory acknowledgements
--     (Output 09 sections 4.4 and 10).
--     A booking cannot be finalized as 'Approved' or 'CheckedIn' while an
--     active Advisory on its space lacks an acknowledgement. The check compares
--     COUNT(DISTINCT active advisory overlapping the reserved window) against
--     COUNT(DISTINCT acknowledged advisory) for the booking.
--     GATE: only status IN ('Approved','CheckedIn'); Pending/Cancelled/
--     Completed/NoShow transitions are never blocked.
--     Statement order relied on (Tasks 11-13): insert booking as Pending ->
--     insert acknowledgement rows -> update status to Approved. This trigger
--     validates at the moment of the Approved/CheckedIn transition.
--     This trigger does NOT refresh bookings.updated_at — the Phase 1 trigger
--     TR_bookings_PreventOverlapAndUnavailable already does that, and a second
--     refresh would cause nested-trigger ping-pong.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.TR_bookings_AdvisoryAckRequired', N'TR') IS NOT NULL
    EXEC(N'DROP TRIGGER dbo.TR_bookings_AdvisoryAckRequired;');
GO

CREATE TRIGGER TR_bookings_AdvisoryAckRequired
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.status IN ('Approved', 'CheckedIn')
          AND (
              -- active Advisory records on the booking's space overlapping the reserved window
              SELECT COUNT(DISTINCT m.maintenance_id)
              FROM maintenance_records m
              WHERE m.space_id = i.space_id
                AND m.status NOT IN ('Completed', 'Cancelled')
                AND m.impact_level = 'Advisory'
                AND m.start_time < i.requested_end_time
                AND COALESCE(m.completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2)) > i.requested_start_time
          ) > (
              -- acknowledgements stored against this booking
              SELECT COUNT(DISTINCT a.maintenance_id)
              FROM booking_advisory_acknowledgments a
              WHERE a.booking_id = i.booking_id
          )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Booking cannot be finalized: every active advisory on this space must be acknowledged.', 16, 1);
        RETURN;
    END
END;
GO

-- ---------------------------------------------------------------------------
-- 6.4 TR_bookings_RequiredAssetCheck — required-asset availability block
--     (Output 09 section 10).
--     A booking cannot be finalized as 'Approved'/'CheckedIn' when a facility
--     marked required for the space (space_facility_requirements.is_required = 1)
--     has zero 'Available' units in facility_assets — even without a space-level
--     OutOfService record. Backed by IX_facility_assets_space_facility_status.
--     GATE: only status IN ('Approved','CheckedIn'). Does not refresh updated_at.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.TR_bookings_RequiredAssetCheck', N'TR') IS NOT NULL
    EXEC(N'DROP TRIGGER dbo.TR_bookings_RequiredAssetCheck;');
GO

CREATE TRIGGER TR_bookings_RequiredAssetCheck
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN space_facility_requirements r
            ON r.space_id     = i.space_id
           AND r.is_required  = 1
        WHERE i.status IN ('Approved', 'CheckedIn')
          AND NOT EXISTS (
              SELECT 1
              FROM facility_assets fa
              WHERE fa.space_id     = i.space_id
                AND fa.facility_id  = r.facility_id
                AND fa.asset_status = 'Available'
          )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Booking cannot be finalized: a required facility for this space has no available unit.', 16, 1);
        RETURN;
    END
END;
GO

-- =============================================================================
-- FINAL COMMIT / ROLLBACK GUARD (single transaction, all batches)
-- =============================================================================
IF XACT_STATE() = 1
BEGIN
    COMMIT TRANSACTION;
    PRINT N'Phase 2 schema migration committed successfully.';
END
ELSE IF XACT_STATE() = -1
BEGIN
    ROLLBACK TRANSACTION;
    RAISERROR('Schema migration failed; all Phase 2 changes rolled back.', 16, 1);
END
GO

-- =============================================================================
-- VERIFICATION QUERIES (run only after a successful commit)
-- =============================================================================
PRINT N'--- Verification: new Phase 2 tables ---';
SELECT name AS new_table
FROM sys.tables
WHERE name IN ('auto_approval_policies', 'policy_booking_types',
               'space_facility_requirements', 'maintenance_impact_history',
               'booking_advisory_acknowledgments', 'booking_alerts',
               'facility_assets')
ORDER BY name;

PRINT N'--- Verification: Phase 1 tables still present (9) ---';
SELECT name AS phase1_table
FROM sys.tables
WHERE name IN ('departments', 'user_accounts', 'spaces', 'facilities',
               'space_facilities', 'bookings', 'booking_decisions',
               'usage_sessions', 'maintenance_records')
ORDER BY name;

PRINT N'--- Verification: Phase 1 row counts preserved ---';
SELECT 'departments'           AS tbl, COUNT(*) AS rows_cnt FROM departments
UNION ALL SELECT 'user_accounts', COUNT(*) FROM user_accounts
UNION ALL SELECT 'spaces',        COUNT(*) FROM spaces
UNION ALL SELECT 'facilities',    COUNT(*) FROM facilities
UNION ALL SELECT 'space_facilities', COUNT(*) FROM space_facilities
UNION ALL SELECT 'bookings',      COUNT(*) FROM bookings
UNION ALL SELECT 'booking_decisions', COUNT(*) FROM booking_decisions
UNION ALL SELECT 'usage_sessions', COUNT(*) FROM usage_sessions
UNION ALL SELECT 'maintenance_records', COUNT(*) FROM maintenance_records;

PRINT N'--- Verification: new / modified columns ---';
SELECT t.name AS table_name,
       c.name AS column_name,
       c.is_nullable,
       c.max_length
FROM sys.columns c
INNER JOIN sys.tables t ON t.object_id = c.object_id
WHERE (t.name = 'maintenance_records' AND c.name IN ('impact_level', 'asset_id'))
   OR (t.name = 'booking_decisions'   AND c.name IN ('decision_source', 'decided_by'))
ORDER BY t.name, c.name;

PRINT N'--- Verification: facility_assets backfill ---';
SELECT (SELECT COUNT(*) FROM facility_assets)      AS asset_rows,
       (SELECT SUM(quantity) FROM space_facilities) AS expected_units_from_quantity;

PRINT N'--- Verification: Phase 2 indexes ---';
SELECT i.name, i.is_unique, i.filter_definition
FROM sys.indexes i
WHERE i.name IN ('IX_bookings_space_status_time',
                 'UQ_auto_approval_policies_space_id',
                 'UQ_auto_approval_policies_active_space_type',
                 'IX_facility_assets_space_facility_status',
                 'IX_maintenance_records_impact_level',
                 'IX_maintenance_impact_history_mid',
                 'IX_booking_advisory_ack_booking',
                 'IX_booking_alerts_booking',
                 'IX_auto_approval_policies_active')
ORDER BY i.name;

PRINT N'--- Verification: derived-fact view ---';
SELECT name AS view_name
FROM sys.views
WHERE name = 'space_facility_summary';

PRINT N'--- Verification: Task-10 triggers ---';
SELECT t.name AS trigger_name
FROM sys.triggers t
WHERE t.name IN ('TR_maintenance_impact_history', 'TR_maintenance_escalation',
                 'TR_bookings_AdvisoryAckRequired', 'TR_bookings_RequiredAssetCheck')
ORDER BY t.name;

-- =============================================================================
-- CLOSING SUMMARY OF CREATED OBJECTS (mapped to Output 09 sections)
-- =============================================================================
--
-- 7 new tables:
--   auto_approval_policies               (09:4.6)   + 2 filtered UNIQUE indexes (09:4.6)
--   policy_booking_types                 (09:4.7)
--   space_facility_requirements          (09:4.9)
--   maintenance_impact_history           (09:4.3)   + IX_maintenance_impact_history_mid (09:7.2)
--   booking_advisory_acknowledgments     (09:4.4)   + UQ (booking_id, maintenance_id) (09:6) + IX_booking_advisory_ack_booking (09:7.2)
--   booking_alerts                       (09:4.5)   + IX_booking_alerts_booking (09:7.2)
--   facility_assets                      (09:4.8)   + UQ serial_number (09:6) + IX_facility_assets_space_facility_status (09:7.2)
--
-- 2 Phase 1 tables modified (additive only):
--   maintenance_records  + impact_level (backfilled 'OutOfService' then DEFAULT dropped) + asset_id FK (09:4.1)
--   booking_decisions    + decision_source (DEFAULT 'Staff' kept) + decided_by nullable + pairing CHECK (09:4.2)
--
-- Indexes:
--   IX_bookings_space_status_time        filtered, conflict-check range locking (09:7.1)
--   UQ_auto_approval_policies_space_id         filtered UNIQUE (09:4.6 / 09:6)
--   UQ_auto_approval_policies_active_space_type filtered UNIQUE (09:4.6 / 09:6)
--   IX_maintenance_records_impact_level  (09:7.2)
--
-- View:
--   space_facility_summary               derived unit counts, 3NF-preserving (09:8 / 09:9.8)
--
-- Triggers (09:10):
--   TR_maintenance_impact_history        impact-history audit (INSERT/UPDATE on maintenance_records)
--   TR_maintenance_escalation            escalation alerts + downgrade auto-close (INSERT/UPDATE on maintenance_records)
--   TR_bookings_AdvisoryAckRequired      advisory acknowledgement requirement (INSERT/UPDATE on bookings)
--   TR_bookings_RequiredAssetCheck       required-asset availability block (INSERT/UPDATE on bookings)
--
-- Enforcement boundary (per the Task 10 skill section 1): the concurrency-safe
-- stored procedures (SERIALIZABLE + WITH (UPDLOCK, HOLDLOCK), sp_getapplock,
-- 1205/1222 retry) belong to Tasks 11-13/15 and are NOT part of this migration.
-- =============================================================================
