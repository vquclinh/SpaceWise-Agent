-- =============================================================================
-- Campus Space Management System — Phase 2 Schema Migration (DDL)
-- Group G08 — Microsoft SQL Server
-- Phase 2, Task 10: Schema Migration (non-destructive)
-- =============================================================================
--
-- This script upgrades a POPULATED Phase 1 database (outputs/05-db-definition-
-- G08.sql already executed) to the Phase 2 architecture defined in
-- outputs/09-updated-erd-and-logical-design-G08.md (Sections 5, 6, 7, 10).
--
-- Migration philosophy (AGENTS.md §5, Output 09 §1):
--   * ADDITIVE ONLY — no Phase 1 table, column, constraint, index, trigger or
--     data is dropped or renamed. Phase 1 objects are preserved verbatim.
--   * Master-first order — new master tables (facility_assets,
--     auto_approval_policies, ...) are created before tables that reference them.
--   * Legacy backfill — NOT NULL columns added to populated tables use a DEFAULT
--     so existing rows are backfilled; the transient default is then dropped.
--   * Security — no ON DELETE CASCADE anywhere (historical preservation).
--
-- How to run: open in SSMS / Azure Data Studio / sqlcmd against the target
-- database (select the correct database context first, e.g. USE [SpaceWise];).
-- The script is idempotent where possible (guards against objects/columns that
-- already exist) and otherwise follows a strict logical GO-batch order.
--
-- Requirements: SQL Server 2016+ (SESSION_CONTEXT, filtered indexes);
-- CREATE OR ALTER for views/triggers requires SQL Server 2016 SP1 or later.
--
-- Deliverable summary at the end of the file.
-- =============================================================================

-- Connection-level settings: required by SQL Server for filtered indexes,
-- indexed views, and trigger definitions (must be ON for the whole script).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

-- =============================================================================
-- SECTION 1 — NEW TABLES (7)
-- All named constraints follow the CONSTRAINT [Name] [Type] convention.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1.1 facility_assets [NEW] — Output 09 §5.6 (granular asset tracking)
--     Master table: references facilities + spaces (Phase 1), referenced by
--     maintenance_records.asset_id, booking_alerts.asset_id, and the view.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.facility_assets', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.facility_assets (
        asset_id            INT            NOT NULL IDENTITY(1,1),
        facility_id         INT            NOT NULL,
        space_id            INT            NOT NULL,
        serial_number       NVARCHAR(50)   NOT NULL,
        asset_status        NVARCHAR(20)   NOT NULL
            CONSTRAINT DF_facility_assets_asset_status DEFAULT N'Available',
        condition           NVARCHAR(MAX)  NULL,
        last_checked_date   DATE           NULL,
        created_at          DATETIME2      NOT NULL
            CONSTRAINT DF_facility_assets_created_at DEFAULT GETDATE(),
        updated_at          DATETIME2      NOT NULL
            CONSTRAINT DF_facility_assets_updated_at DEFAULT GETDATE(),
        CONSTRAINT PK_facility_assets PRIMARY KEY (asset_id),
        CONSTRAINT UQ_facility_assets_serial_number UNIQUE (serial_number),
        CONSTRAINT FK_facility_assets_facility_id FOREIGN KEY (facility_id)
            REFERENCES dbo.facilities(facility_id),
        CONSTRAINT FK_facility_assets_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        CONSTRAINT CK_facility_assets_asset_status CHECK (
            asset_status IN (N'Available', N'InUse',
                             N'UnderMaintenance', N'Retired')
        )
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.2 space_facility_requirements [NEW] — Output 09 §5.7 (sparse list)
--     Pure junction table: presence of a row means the facility type is
--     REQUIRED for the space. No attribute column (is_required was removed —
--     Output 09 final design). Master: references spaces + facilities.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.space_facility_requirements', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.space_facility_requirements (
        space_id    INT            NOT NULL,
        facility_id INT            NOT NULL,
        CONSTRAINT PK_space_facility_requirements PRIMARY KEY (space_id, facility_id),
        CONSTRAINT FK_space_facility_requirements_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        CONSTRAINT FK_space_facility_requirements_facility_id FOREIGN KEY (facility_id)
            REFERENCES dbo.facilities(facility_id)
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.3 auto_approval_policies [NEW] — Output 09 §5.14 (instant-booking eligibility)
--     Master table: optional space-specific override (space_id) XOR type-wide
--     scope (space_type enum, no FK). Referenced by policy_booking_types.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.auto_approval_policies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.auto_approval_policies (
        policy_id            INT            NOT NULL IDENTITY(1,1),
        space_type           NVARCHAR(30)   NULL,
        space_id             INT            NULL,
        max_participants     INT            NULL,
        requires_advisory_ack BIT           NOT NULL
            CONSTRAINT DF_auto_approval_policies_requires_advisory_ack DEFAULT 1,
        is_active            BIT            NOT NULL
            CONSTRAINT DF_auto_approval_policies_is_active DEFAULT 1,
        created_at           DATETIME2      NOT NULL
            CONSTRAINT DF_auto_approval_policies_created_at DEFAULT GETDATE(),
        updated_at           DATETIME2      NOT NULL
            CONSTRAINT DF_auto_approval_policies_updated_at DEFAULT GETDATE(),
        CONSTRAINT PK_auto_approval_policies PRIMARY KEY (policy_id),
        CONSTRAINT FK_auto_approval_policies_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        -- NOTE: no plain UNIQUE on space_id — it is nullable, and a standard
        -- UNIQUE would treat NULLs as distinct (Skill 10 UNIQUE NULL Handling).
        -- Scope uniqueness is enforced by the filtered unique indexes in
        -- Section 3: UQ_auto_approval_policies_space_id (space-specific) and
        -- UQ_auto_approval_policies_active_space_type (active type-wide).
        CONSTRAINT CK_auto_approval_policies_space_type CHECK (
            space_type IN (N'Auditorium', N'Classroom', N'ComputerLaboratory',
                           N'ProjectLaboratory', N'MeetingRoom', N'StudentWorkspace')
        ),
        CONSTRAINT CK_auto_approval_policies_max_participants CHECK (
            max_participants > 0
        ),
        -- Scope XOR: exactly one of space_type / space_id is set.
        CONSTRAINT CK_auto_approval_policies_scope CHECK (
            (space_type IS NULL AND space_id IS NOT NULL)
            OR (space_type IS NOT NULL AND space_id IS NULL)
        )
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.4 policy_booking_types [NEW] — Output 09 §5.15 (allowed booking types per policy)
--     References auto_approval_policies (created above).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.policy_booking_types', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.policy_booking_types (
        policy_id    INT            NOT NULL,
        booking_type NVARCHAR(30)   NOT NULL,
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
GO

-- ---------------------------------------------------------------------------
-- 1.5 maintenance_impact_history [NEW] — Output 09 §5.13 (escalation/downgrade audit)
--     References maintenance_records + user_accounts (Phase 1 tables).
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.maintenance_impact_history (
        history_id        INT            NOT NULL IDENTITY(1,1),
        maintenance_id    INT            NOT NULL,
        changed_by        INT            NOT NULL,
        old_impact_level  NVARCHAR(20)   NULL,
        new_impact_level  NVARCHAR(20)   NOT NULL,
        changed_at        DATETIME2      NOT NULL
            CONSTRAINT DF_maintenance_impact_history_changed_at DEFAULT GETDATE(),
        change_reason     NVARCHAR(MAX)  NULL,
        CONSTRAINT PK_maintenance_impact_history PRIMARY KEY (history_id),
        CONSTRAINT FK_maintenance_impact_history_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES dbo.maintenance_records(maintenance_id),
        CONSTRAINT FK_maintenance_impact_history_changed_by FOREIGN KEY (changed_by)
            REFERENCES dbo.user_accounts(user_id),
        CONSTRAINT CK_maintenance_impact_history_old_level CHECK (
            old_impact_level IS NULL
            OR old_impact_level IN (N'Advisory', N'OutOfService')
        ),
        CONSTRAINT CK_maintenance_impact_history_new_level CHECK (
            new_impact_level IN (N'Advisory', N'OutOfService')
        )
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.6 booking_advisory_acknowledgments [NEW] — Output 09 §5.12 (legal consent)
--     References bookings + maintenance_records + user_accounts.
--     Natural key (booking_id, maintenance_id) via composite UNIQUE.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.booking_advisory_acknowledgments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.booking_advisory_acknowledgments (
        ack_id          INT            NOT NULL IDENTITY(1,1),
        booking_id      INT            NOT NULL,
        maintenance_id  INT            NOT NULL,
        acknowledged_by INT            NOT NULL,
        acknowledged_at DATETIME2      NOT NULL
            CONSTRAINT DF_booking_advisory_acknowledgments_acknowledged_at DEFAULT GETDATE(),
        CONSTRAINT PK_booking_advisory_acknowledgments PRIMARY KEY (ack_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_booking_id FOREIGN KEY (booking_id)
            REFERENCES dbo.bookings(booking_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES dbo.maintenance_records(maintenance_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_acknowledged_by FOREIGN KEY (acknowledged_by)
            REFERENCES dbo.user_accounts(user_id),
        -- One acknowledgement per (booking, advisory) pair.
        CONSTRAINT UQ_booking_advisory_acknowledgments_booking_maintenance
            UNIQUE (booking_id, maintenance_id)
    );
END
GO

-- ---------------------------------------------------------------------------
-- 1.7 booking_alerts [NEW] — Output 09 §5.16 (escalation + relocation alerts)
--     References maintenance_records, facility_assets, bookings, user_accounts.
--     Source scope is exactly one of maintenance_id (MaintenanceEscalated) or
--     asset_id (RequiredAssetRelocated) — enforced by the source-scope XOR.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.booking_alerts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.booking_alerts (
        alert_id                INT            NOT NULL IDENTITY(1,1),
        maintenance_id          INT            NULL,
        asset_id                INT            NULL,
        booking_id              INT            NOT NULL,
        alert_type              NVARCHAR(30)   NOT NULL
            CONSTRAINT DF_booking_alerts_alert_type DEFAULT N'MaintenanceEscalated',
        created_at              DATETIME2      NOT NULL
            CONSTRAINT DF_booking_alerts_created_at DEFAULT GETDATE(),
        acknowledged_by_staff_id INT           NULL,
        acknowledged_at         DATETIME2      NULL,
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
        -- Handling fields paired (both NULL, or both set).
        CONSTRAINT CK_booking_alerts_handled CHECK (
            (acknowledged_by_staff_id IS NULL AND acknowledged_at IS NULL)
            OR (acknowledged_by_staff_id IS NOT NULL AND acknowledged_at IS NOT NULL)
        ),
        -- Source-scope XOR: exactly one of maintenance_id / asset_id is set,
        -- and it must match alert_type.
        CONSTRAINT CK_booking_alerts_source_scope CHECK (
            (alert_type = N'MaintenanceEscalated'
                AND maintenance_id IS NOT NULL AND asset_id IS NULL)
            OR (alert_type = N'RequiredAssetRelocated'
                AND asset_id IS NOT NULL AND maintenance_id IS NULL)
        )
    );
END
GO

-- =============================================================================
-- SECTION 2 — TABLE MODIFICATIONS (2, additive only)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 2.1 maintenance_records [MOD] — Output 09 §5.11
--     1) ADD impact_level NOT NULL with DEFAULT N'OutOfService' (legacy rows
--        are backfilled inline by the DEFAULT during the ALTER = Phase 1's
--        blanket blocking rule; no separate backfill UPDATE needed).
--     2) DROP the transient DEFAULT so future inserts must state the level
--        explicitly (Output 09 §5.11 migration path).
--     3) ADD asset_id (NULL, FK → facility_assets).
--     4) ADD CHECK constraints: impact_level whitelist + asset-scope guard
--        (CK_maintenance_records_asset_scope_level — the "invalid relocation"
--        check: only space-level records may be OutOfService, so a single
--        broken unit can never close an entire room).
-- ---------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.maintenance_records', N'impact_level') IS NULL
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD impact_level NVARCHAR(20) NOT NULL
            CONSTRAINT DF_maintenance_records_impact_level DEFAULT N'OutOfService';
END
GO

-- Drop the transient default so future inserts must state the level explicitly.
IF EXISTS (
    SELECT 1 FROM sys.default_constraints
    WHERE name = N'DF_maintenance_records_impact_level'
)
    ALTER TABLE dbo.maintenance_records
        DROP CONSTRAINT DF_maintenance_records_impact_level;
GO

IF COL_LENGTH(N'dbo.maintenance_records', N'asset_id') IS NULL
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD asset_id INT NULL;
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_maintenance_records_asset_id'
)
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT FK_maintenance_records_asset_id
            FOREIGN KEY (asset_id) REFERENCES dbo.facility_assets(asset_id);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_maintenance_records_impact_level'
)
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT CK_maintenance_records_impact_level
            CHECK (impact_level IN (N'Advisory', N'OutOfService'));
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_maintenance_records_asset_scope_level'
)
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT CK_maintenance_records_asset_scope_level
            CHECK (asset_id IS NULL OR impact_level = N'Advisory');
GO

-- ---------------------------------------------------------------------------
-- 2.2 booking_decisions [MOD] — Output 09 §5.9
--     1) ADD decision_source NOT NULL DEFAULT N'Staff' (legacy rows are all
--        staff decisions).
--     2) MAKE decided_by nullable (System auto-approval has no actor).
--     3) ADD CHECK constraints: decision_source whitelist + the source-actor
--        XOR pairing (CK_booking_decisions_source_actor). Existing rows
--        (Staff + decided_by NOT NULL) validate under WITH CHECK.
-- ---------------------------------------------------------------------------
IF COL_LENGTH(N'dbo.booking_decisions', N'decision_source') IS NULL
BEGIN
    ALTER TABLE dbo.booking_decisions
        ADD decision_source NVARCHAR(10) NOT NULL
            CONSTRAINT DF_booking_decisions_decision_source DEFAULT N'Staff';
END
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.booking_decisions')
      AND name = N'decided_by'
      AND is_nullable = 0
)
    ALTER TABLE dbo.booking_decisions
        ALTER COLUMN decided_by INT NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_booking_decisions_decision_source'
)
    ALTER TABLE dbo.booking_decisions
        ADD CONSTRAINT CK_booking_decisions_decision_source
            CHECK (decision_source IN (N'Staff', N'System'));
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = N'CK_booking_decisions_source_actor'
)
    ALTER TABLE dbo.booking_decisions
        ADD CONSTRAINT CK_booking_decisions_source_actor
            CHECK (
                (decision_source = N'System' AND decided_by IS NULL)
                OR (decision_source = N'Staff' AND decided_by IS NOT NULL)
            );
GO

-- =============================================================================
-- SECTION 3 — FILTERED UNIQUE INDEXES (per-scope dedup)
-- Output 09 §5.16 + Skill 10 (UNIQUE NULL Handling / Policy Integrity).
-- A single UNIQUE over (maintenance_id, booking_id, alert_type) cannot work
-- because the source column is NULL in the other scope — SQL Server treats
-- NULLs as distinct. Filtered unique indexes enforce "at most one alert per
-- (source, booking) event" per scope, and "at most one policy per scope" for
-- auto_approval_policies (space-specific, and active type-wide).
-- =============================================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_booking_alerts_maint'
      AND object_id = OBJECT_ID(N'dbo.booking_alerts')
)
    CREATE UNIQUE INDEX UQ_booking_alerts_maint
        ON dbo.booking_alerts (maintenance_id, booking_id)
        WHERE alert_type = N'MaintenanceEscalated';
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_booking_alerts_asset'
      AND object_id = OBJECT_ID(N'dbo.booking_alerts')
)
    CREATE UNIQUE INDEX UQ_booking_alerts_asset
        ON dbo.booking_alerts (asset_id, booking_id)
        WHERE alert_type = N'RequiredAssetRelocated';
GO

-- Policy scope dedup (Skill 10 Policy Integrity): space_id is nullable, so a
-- standard UNIQUE would treat NULLs as distinct and let duplicate scopes in.
--   * space-specific scope: at most one policy per space (space_id NOT NULL).
--   * active type-wide scope: at most one ACTIVE policy per space_type;
--     inactive or space-specific rows (space_id set) are excluded from the
--     uniqueness set, so they may coexist freely.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_auto_approval_policies_space_id'
      AND object_id = OBJECT_ID(N'dbo.auto_approval_policies')
)
    CREATE UNIQUE INDEX UQ_auto_approval_policies_space_id
        ON dbo.auto_approval_policies (space_id)
        WHERE space_id IS NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_auto_approval_policies_active_space_type'
      AND object_id = OBJECT_ID(N'dbo.auto_approval_policies')
)
    CREATE UNIQUE INDEX UQ_auto_approval_policies_active_space_type
        ON dbo.auto_approval_policies (space_type)
        WHERE space_type IS NOT NULL
          AND is_active = 1;
GO

-- =============================================================================
-- SECTION 4 — VIEW (derived counts, never stored)
-- Output 09 §6 v_space_facility_summary.
-- CREATE OR ALTER VIEW (Skill 10: preserves permissions, idempotent).
-- =============================================================================
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
-- SECTION 5 — PHASE 2 INDEXES (Output 09 §10, I1–I15)
-- I16 (usage_sessions UQ_usage_sessions_booking_id) is implicit — created by
-- the Phase 1 UNIQUE constraint; no explicit CREATE INDEX needed.
-- Phase 1 indexes are preserved verbatim (not dropped).
-- The filtered indexes below are load-bearing for the concurrency mechanism
-- in Task 12: SERIALIZABLE key-range locking is only granular when an index
-- matches the range predicate.
-- =============================================================================

-- I1 -- overlap-check range locking + report (a)/(b) per-space aggregates
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_bookings_space_status_time'
      AND object_id = OBJECT_ID(N'dbo.bookings')
)
    CREATE INDEX IX_bookings_space_status_time
        ON dbo.bookings (space_id, requested_start_time, requested_end_time)
        WHERE status IN (N'Approved', N'CheckedIn');
GO

-- I2 -- semester-range scans for reports (a)/(b); focused on requested_start_time
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_bookings_space_status_start'
      AND object_id = OBJECT_ID(N'dbo.bookings')
)
    CREATE INDEX IX_bookings_space_status_start
        ON dbo.bookings (space_id, status, requested_start_time)
        WHERE status IN (N'Approved', N'CheckedIn', N'Completed');
GO

-- I3 -- impact-level blocking check (Section 9.5.2): tiny active blocking set
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_maintenance_blocking'
      AND object_id = OBJECT_ID(N'dbo.maintenance_records')
)
    CREATE INDEX IX_maintenance_blocking
        ON dbo.maintenance_records (space_id, start_time, completion_time)
        WHERE impact_level = N'OutOfService'
          AND status <> N'Completed'
          AND status <> N'Cancelled';
GO

-- I4 -- advisory display + ack-completeness (R3); room finder maintenance filter
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_maintenance_advisory'
      AND object_id = OBJECT_ID(N'dbo.maintenance_records')
)
    CREATE INDEX IX_maintenance_advisory
        ON dbo.maintenance_records (space_id, start_time, completion_time)
        WHERE impact_level = N'Advisory'
          AND status <> N'Completed'
          AND status <> N'Cancelled';
GO

-- I5 -- escalation trigger: find overlapping Approved/CheckedIn bookings
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_maintenance_escalation_window'
      AND object_id = OBJECT_ID(N'dbo.maintenance_records')
)
    CREATE INDEX IX_maintenance_escalation_window
        ON dbo.maintenance_records (impact_level, status, start_time, completion_time);
GO

-- I6 -- required-asset availability (R8) + v_space_facility_summary aggregation
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_assets_location_status'
      AND object_id = OBJECT_ID(N'dbo.facility_assets')
)
    CREATE INDEX IX_assets_location_status
        ON dbo.facility_assets (space_id, facility_id, asset_status);
GO

-- I7 -- FK lookup, catalogue-type drill-downs
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_assets_facility_id'
      AND object_id = OBJECT_ID(N'dbo.facility_assets')
)
    CREATE INDEX IX_assets_facility_id
        ON dbo.facility_assets (facility_id);
GO

-- I8 -- ack-completeness join (R3). The composite UNIQUE constraint
--      UQ_booking_advisory_acknowledgments_booking_maintenance already creates
--      an identical index; I8 is kept per Output 09 §10 for covered-query clarity.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_ack_booking'
      AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgments')
)
    CREATE INDEX IX_ack_booking
        ON dbo.booking_advisory_acknowledgments (booking_id, maintenance_id);
GO

-- I9 -- advisory lookup per maintenance record
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_ack_maintenance'
      AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgments')
)
    CREATE INDEX IX_ack_maintenance
        ON dbo.booking_advisory_acknowledgments (maintenance_id);
GO

-- I10 -- escalation lookup / report (d): retrieve affected bookings per record
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_alerts_maintenance'
      AND object_id = OBJECT_ID(N'dbo.booking_alerts')
)
    CREATE INDEX IX_alerts_maintenance
        ON dbo.booking_alerts (maintenance_id, booking_id);
GO

-- I11 -- open action list for staff
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_alerts_open'
      AND object_id = OBJECT_ID(N'dbo.booking_alerts')
)
    CREATE INDEX IX_alerts_open
        ON dbo.booking_alerts (acknowledged_at)
        WHERE acknowledged_at IS NULL;
GO

-- I12 -- impact-change audit trail per record
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_history_maintenance'
      AND object_id = OBJECT_ID(N'dbo.maintenance_impact_history')
)
    CREATE INDEX IX_history_maintenance
        ON dbo.maintenance_impact_history (maintenance_id, changed_at);
GO

-- I13 -- room finder (report (c)): capacity + type seek, excludes closed/retired
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_roomfinder_capacity_type'
      AND object_id = OBJECT_ID(N'dbo.spaces')
)
    CREATE INDEX IX_roomfinder_capacity_type
        ON dbo.spaces (capacity, space_type)
        WHERE current_status IN (N'Available', N'InUse');
GO

-- I14 -- auto-approval eligibility lookup by space type
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_policies_scope'
      AND object_id = OBJECT_ID(N'dbo.auto_approval_policies')
)
    CREATE INDEX IX_policies_scope
        ON dbo.auto_approval_policies (space_type, is_active);
GO

-- I15 -- reverse lookup: which policies permit a booking type
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_policies_booking_types'
      AND object_id = OBJECT_ID(N'dbo.policy_booking_types')
)
    CREATE INDEX IX_policies_booking_types
        ON dbo.policy_booking_types (booking_type, policy_id);
GO

-- =============================================================================
-- SECTION 6 — TRIGGERS (business rules R1–R12)
-- Trigger list in this migration:
--   * TR_maintenance_impact_history        (R9)  — escalation/downgrade audit
--   * TR_maintenance_SyncAssetStatus       (R7)  — asset_status synchronisation
--   * TR_maintenance_escalation            (R5)  — OutOfService escalation alerts
--   * TR_facility_assets_RelocationAlert   (R12) — [EXTENSION] relocation alerts
--   * TR_bookings_AdvisoryAckRequired      (R3)  — advisory acknowledgement gate
--   * TR_bookings_RequiredAssetCheck       (R8)  — last-available-unit gate
-- The Phase 1 trigger TR_bookings_PreventOverlapAndUnavailable is retained
-- verbatim as the concurrency-validation backstop (Output 09 §7).
-- Every trigger is defined with CREATE OR ALTER TRIGGER (Skill 10 modern
-- syntax: preserves permissions, idempotent re-runs) and opens with the
-- TRIGGER_NESTLEVEL() recursion guard.
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
-- SESSION_CONTEXT returns SQL_VARIANT (Skill 10 data-type safety).
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
-- trigger path, per the Task 10 design note).
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
-- NOT EXISTS guard + the filtered unique index UQ_booking_alerts_maint make
-- the alert set idempotent (escalate → downgrade → escalate again yields no
-- duplicate rows).
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
-- Ghost-alert guard (Skill 10 logical precision): the alert fires ONLY when
--   (1) the location actually changed (i.space_id <> d.space_id), AND
--   (2) the asset was in a working state before the move
--       (d.asset_status = N'Available') — moving a unit that was already
--       UnderMaintenance / InUse / Retired must not raise the alert.
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
      AND d.asset_status = N'Available'     -- asset was working before the move
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

-- =============================================================================
-- SECTION 7 — POST-MIGRATION VERIFICATION QUERIES (run manually if desired)
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
-- VIEW (1):              v_space_facility_summary
-- INDEXES (15):          I1–I15 from Output 09 §10 (I16 = Phase 1 implicit UNIQUE)
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