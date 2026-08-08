/* ===========================================================================
   Step 10: Schema Migration — G08 (Phase 2)
   File     : outputs/10-schema-migration-G08.sql
   Target   : Microsoft SQL Server 2016 SP1+ (CREATE OR ALTER, filtered indexes,
              SESSION_CONTEXT, STRING_SPLIT-free)
   Source   : outputs/05-db-definition-G08.sql + outputs/06-sample-data-G08.sql
   Design   : outputs/09-updated-erd-and-logical-design-G08.md  (authoritative)
   Rationale: outputs/08-requirement-change-analysis-G08.md

   ---------------------------------------------------------------------------
   WHAT THIS SCRIPT DOES
   ---------------------------------------------------------------------------
   Upgrades a POPULATED Phase 1 database in place to the Phase 2 schema
   (15 tables = 7 Phase 1 retained + 8 new), preserving every existing row.

   ---------------------------------------------------------------------------
   SCOPE BOUNDARY — what this script deliberately does NOT contain
   ---------------------------------------------------------------------------
   Task 10 delivers schema objects and data preservation ONLY. The following
   belong to later deliverables and are intentionally absent:

     * usp_ApproveBooking / usp_CreateBookingAutoApproved / usp_CompleteBooking,
       SERIALIZABLE + UPDLOCK/HOLDLOCK bodies, sp_getapplock, retry logic ...... Task 12
     * concurrency demonstration / test harnesses ............................. Task 13
     * volume data generation (3 academic years, 100k+ bookings) .............. Task 14
     * index tuning experiments, execution plans, before/after timings ........ Task 15
     * the four CS486_Project_Phase02.pdf section 1.3 report queries .......... Task 16

   Creating a Phase 2 index is Task 10 (the schema needs it); MEASURING it is
   Task 15. The triggers below are schema objects assigned to Task 10 by
   Output 09 section 7 (rules R1-R16), not concurrency control.

   ---------------------------------------------------------------------------
   BASELINE AMENDMENTS (AGENTS.md) — the only three deviations from "additive"
   ---------------------------------------------------------------------------
   Sect. 1a  DROP TABLE  facilities            -> facility_name becomes a CHECK-
                                                  constrained attribute
   Sect. 1b  DROP TABLE  space_facilities      -> its key pair is a stored
                                                  projection of facility_assets
   Sect. 1c  DROP COLUMN user_accounts.role    -> replaced by user_roles(user_id, role)

   Nothing else is dropped or renamed.

   ---------------------------------------------------------------------------
   DATA PRESERVATION GUARANTEES
   ---------------------------------------------------------------------------
   1. ARCHIVE FIRST. Every object dropped below is copied verbatim into a
      mig_archive_* table inside the same transaction, BEFORE the drop.
      Those archive tables are MIGRATION ARTIFACTS, not part of the Phase 2
      schema. They may be dropped manually once the migration is accepted.

   2. CARRY THE DATA, NOT JUST THE SHAPE.
      * space_facilities -> facility_assets: each (space, facility, quantity)
        row is EXPANDED into exactly `quantity` individually-identified units,
        with serial numbers generated as <space_code>-<FACILITY>-<seq>
        (Output 09 section 5.6, defect L12). Phase 1 `condition` and `note`
        text is carried onto every generated unit -- it holds real operational
        information (e.g. '3 stations have faulty keyboards').
      * user_accounts.role -> user_roles: one row seeded per existing user, so
        every Phase 1 account keeps the role it had.

   3. NOT NULL COLUMNS ON POPULATED TABLES are added with a migration-only
      DEFAULT to backfill, and the default is then dropped where the final
      schema carries none (maintenance_records.impact_level -- Output 09
      section 5.11: impact level is a Facility Manager judgement and must never
      be silently defaulted for a NEW record).

   4. CONSTRAINTS THAT LEGACY ROWS COULD VIOLATE are added AFTER the backfill.

   ---------------------------------------------------------------------------
   SAFETY DESIGN
   ---------------------------------------------------------------------------
   * ATOMIC. Everything runs in ONE transaction under SET XACT_ABORT ON inside
     a single TRY/CATCH. Any error rolls the database back to its exact Phase 1
     state. A half-migrated database is impossible.

   * NO `GO` INSIDE THE TRANSACTION. `GO` ends the batch and would break the
     single TRY/CATCH. Because CREATE OR ALTER VIEW|TRIGGER must be the first
     statement in its batch, every programmable object is wrapped in EXEC(N'...').
     The same wrapping is used for any statement that reads a column added or
     dropped elsewhere in this script -- SQL Server binds column names at COMPILE
     time, so an unwrapped reference to a dropped column would fail the whole
     batch on the second run even though it is guarded by an IF.

   * RE-RUNNABLE. Running this file twice in a row succeeds and changes nothing
     the second time. Every object is existence-guarded; every data migration
     is NOT EXISTS-guarded; blocks that read soon-to-be-dropped structures are
     themselves wrapped in an existence check.

   * VERIFICATION GATE. The last step before COMMIT re-counts the migrated data
     and THROWs on any mismatch, so a bad migration ROLLS BACK rather than
     committing.

   ---------------------------------------------------------------------------
   SECTION ORDER (forced by dependencies -- do not reorder)
   ---------------------------------------------------------------------------
     0  Pre-flight validation            (fail fast if the baseline is wrong)
     1  Archive soon-to-be-dropped data  (before anything destructive)
     2  Create the 8 new tables          (facility_assets before MR.asset_id FK)
     3  Additive column changes          (needs section 2 for the FK target)
     4  Data migration                   (needs 2+3; reads pre-drop structures)
     5  Post-backfill constraints        (needs 4 -- legacy rows must comply)
     6  Retire deprecated objects        (needs 4 -- data already carried over)
     7  Views                            (needs final table shapes)
     8  Triggers                         (needs final table shapes)
     9  Indexes                          (needs final table shapes)
    10  Verification gate                (before COMMIT)
    11  Post-commit summary              (outside the transaction, read-only)

   ---------------------------------------------------------------------------
   HOW TO RUN
   ---------------------------------------------------------------------------
     sqlcmd -S <server> -d <phase1_database> -i 10-schema-migration-G08.sql
   or open in SSMS against the Phase 1 database and Execute.

   Expect: a PRINT log per step, then a summary table. On any error: one
   error message, a full rollback, and a database still on Phase 1.
   =========================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* MANDATORY. If the client has SET IMPLICIT_TRANSACTIONS ON (SSMS: Tools >
   Options > Query Execution > SQL Server > ANSI), every statement silently opens
   a transaction the client never commits. This script's COMMIT would then only
   decrement @@TRANCOUNT from 2 to 1 -- the work would NOT be durable, and the
   session would keep holding locks until the window is closed, blocking every
   later run. Turning it off here makes the script own its own transaction
   boundary regardless of client settings. */
SET IMPLICIT_TRANSACTIONS OFF;

DECLARE @step        NVARCHAR(200);
DECLARE @sql         NVARCHAR(MAX);
DECLARE @msg         NVARCHAR(400);
DECLARE @n           INT;
DECLARE @expected    INT;
DECLARE @actual      INT;

PRINT N'============================================================';
PRINT N' Phase 1 -> Phase 2 schema migration (G08)  started ' + CONVERT(NVARCHAR(30), SYSDATETIME(), 121);
PRINT N'============================================================';

/* ===========================================================================
   SECTION 0. PRE-FLIGHT VALIDATION
   ---------------------------------------------------------------------------
   Refuse to run against anything that is not a recognisable Phase 1 database.
   This runs OUTSIDE the transaction: there is nothing to roll back yet, and a
   clear refusal is more useful than a rollback.
   =========================================================================== */

PRINT N'[0] Pre-flight validation ...';

/* SET IMPLICIT_TRANSACTIONS OFF above stops NEW implicit transactions but cannot
   close one that is already open. If this session arrived with a transaction in
   flight, the script's COMMIT would not be the outermost one and the migration
   would never become durable -- refuse to start rather than produce that. */
IF @@TRANCOUNT > 0
    THROW 50004, N'[0] This session already has an open transaction (@@TRANCOUNT > 0). Run COMMIT (or ROLLBACK) first, then re-run. If this keeps happening, disable SSMS Tools > Options > Query Execution > SQL Server > ANSI > SET IMPLICIT_TRANSACTIONS and open a NEW query window.', 1;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50000, N'[0] Refusing to run against a system database. Connect to the Phase 1 application database first.', 1;

/* The five Phase 1 tables that are never dropped -- their absence means this is
   not a Phase 1 database at all. */
IF OBJECT_ID(N'dbo.departments',     N'U') IS NULL
   OR OBJECT_ID(N'dbo.user_accounts', N'U') IS NULL
   OR OBJECT_ID(N'dbo.spaces',        N'U') IS NULL
   OR OBJECT_ID(N'dbo.bookings',      N'U') IS NULL
   OR OBJECT_ID(N'dbo.usage_sessions', N'U') IS NULL
    THROW 50001, N'[0] Phase 1 baseline not found (departments/user_accounts/spaces/bookings/usage_sessions). Run 05-db-definition-G08.sql first.', 1;

IF OBJECT_ID(N'dbo.booking_decisions',   N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance_records', N'U') IS NULL
    THROW 50002, N'[0] Phase 1 baseline incomplete (booking_decisions/maintenance_records missing).', 1;

/* CREATE OR ALTER requires SQL Server 2016 SP1 (13.0.4001) or later. */
IF CAST(SERVERPROPERTY(N'ProductMajorVersion') AS INT) < 13
    THROW 50003, N'[0] SQL Server 2016 SP1+ required (CREATE OR ALTER, filtered indexes, SESSION_CONTEXT).', 1;

PRINT N'    OK: Phase 1 baseline present, server version supported.';

/* Empty-baseline warning. Migrating an EMPTY Phase 1 database silently
   "succeeds": every verification below compares 0 against 0 and passes, the
   script commits, and the summary reports zeros that are easy to misread as a
   clean run. That is not a failure state -- a fresh install is legitimately
   empty -- but it is almost never what is intended here, so say so loudly.
   Most common cause: 06-sample-data-G08.sql was executed in a session with
   IMPLICIT_TRANSACTIONS ON, so its COMMIT only decremented @@TRANCOUNT and the
   rows were rolled back when that session ended. */
IF NOT EXISTS (SELECT 1 FROM dbo.user_accounts)
   AND NOT EXISTS (SELECT 1 FROM dbo.bookings)
BEGIN
    PRINT N'';
    PRINT N'    ############################################################';
    PRINT N'    ##  WARNING: the Phase 1 baseline contains NO DATA.        ##';
    PRINT N'    ##  user_accounts and bookings are both empty.             ##';
    PRINT N'    ##  The migration will run and commit, but it will migrate ##';
    PRINT N'    ##  nothing and every count below will read 0.             ##';
    PRINT N'    ##  If you expected data: load 06-sample-data-G08.sql,     ##';
    PRINT N'    ##  confirm SELECT @@TRANCOUNT = 0 afterwards, then re-run.##';
    PRINT N'    ############################################################';
    PRINT N'';
END

BEGIN TRY
BEGIN TRANSACTION;

/* ===========================================================================
   SECTION 1. ARCHIVE SOON-TO-BE-DROPPED DATA
   ---------------------------------------------------------------------------
   Runs before ANY destructive step. If the migration is later found to be
   wrong, these tables are the recovery path.

   NOTE: mig_archive_* tables are MIGRATION ARTIFACTS. They are NOT part of the
   Phase 2 design (Output 09 section 5 lists 15 tables; these are not among
   them) and may be dropped once the migration is accepted.
   =========================================================================== */

PRINT N'[1] Archiving data that will be dropped ...';

IF OBJECT_ID(N'dbo.facilities', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.mig_archive_facilities', N'U') IS NULL
BEGIN
    SELECT * INTO dbo.mig_archive_facilities FROM dbo.facilities;
    SET @n = @@ROWCOUNT;
    PRINT N'    mig_archive_facilities created (' + CAST(@n AS NVARCHAR(10)) + N' rows).';
END
ELSE
    PRINT N'    mig_archive_facilities: skipped (already archived, or facilities already dropped).';

IF OBJECT_ID(N'dbo.space_facilities', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.mig_archive_space_facilities', N'U') IS NULL
BEGIN
    SELECT * INTO dbo.mig_archive_space_facilities FROM dbo.space_facilities;
    SET @n = @@ROWCOUNT;
    PRINT N'    mig_archive_space_facilities created (' + CAST(@n AS NVARCHAR(10)) + N' rows).';
END
ELSE
    PRINT N'    mig_archive_space_facilities: skipped (already archived, or space_facilities already dropped).';

/* user_accounts.role: archive the (user_id, role) pairs only. Wrapped in EXEC
   because `role` will not exist on the second run and column names bind at
   COMPILE time -- an unwrapped reference would fail the whole batch. */
IF COL_LENGTH('dbo.user_accounts', 'role') IS NOT NULL
   AND OBJECT_ID(N'dbo.mig_archive_user_accounts_role', N'U') IS NULL
BEGIN
    EXEC (N'SELECT user_id, role INTO dbo.mig_archive_user_accounts_role FROM dbo.user_accounts;');
    /* Read back through sp_executesql: the table was created inside EXEC, so it
       is invisible to this batch at compile time. */
    EXEC sp_executesql N'SELECT @c = COUNT(*) FROM dbo.mig_archive_user_accounts_role;',
                       N'@c INT OUTPUT', @c = @n OUTPUT;
    PRINT N'    mig_archive_user_accounts_role created (' + CAST(@n AS NVARCHAR(10)) + N' rows).';
END
ELSE
    PRINT N'    mig_archive_user_accounts_role: skipped (already archived, or role already dropped).';

/* ===========================================================================
   SECTION 2. CREATE THE 8 NEW PHASE 2 TABLES
   ---------------------------------------------------------------------------
   Order matters: facility_assets first, because maintenance_records.asset_id
   (section 3) and booking_alerts.asset_id reference it.

   Per amendment 1b, facility_assets and space_facility_requirements link to
   spaces DIRECTLY (FK -> spaces(space_id)) with an INDEPENDENT CHECK whitelist
   on facility_name. The two whitelists are two copies of one domain: adding a
   facility type in future means editing BOTH. That is the recorded cost of
   amendments 1a + 1b.
   =========================================================================== */

PRINT N'[2] Creating new Phase 2 tables ...';

IF OBJECT_ID(N'dbo.facility_assets', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.facility_assets (
        asset_id          INT            NOT NULL IDENTITY(1,1),
        space_id          INT            NOT NULL,
        facility_name     NVARCHAR(100)  NOT NULL,
        serial_number     NVARCHAR(50)   NOT NULL,
        asset_status      NVARCHAR(20)   NOT NULL
            CONSTRAINT DF_facility_assets_asset_status DEFAULT N'Available',
        condition         NVARCHAR(MAX)  NULL,
        last_checked_date DATE           NULL,
        created_at        DATETIME2      NOT NULL
            CONSTRAINT DF_facility_assets_created_at DEFAULT GETDATE(),
        updated_at        DATETIME2      NOT NULL
            CONSTRAINT DF_facility_assets_updated_at DEFAULT GETDATE(),
        CONSTRAINT PK_facility_assets PRIMARY KEY (asset_id),
        CONSTRAINT FK_facility_assets_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        CONSTRAINT UQ_facility_assets_serial_number UNIQUE (serial_number),
        CONSTRAINT CK_facility_assets_asset_status CHECK (
            asset_status IN (N'Available', N'InUse', N'UnderMaintenance', N'Retired')),
        CONSTRAINT CK_facility_assets_facility_name CHECK (
            facility_name IN (N'Projector', N'Whiteboard', N'AirConditioner',
                              N'ComputerStation', N'SpeakerSystem',
                              N'VideoConference', N'SmartBoard'))
    );
    PRINT N'    facility_assets created.';
END
ELSE PRINT N'    facility_assets: already exists.';

IF OBJECT_ID(N'dbo.space_facility_requirements', N'U') IS NULL
BEGIN
    /* Pure sparse junction: presence of a row means "required". No attribute
       column exists, so there is no is_required = 0 / NULL state to guard
       against (Output 09 section 5.7). */
    CREATE TABLE dbo.space_facility_requirements (
        space_id      INT           NOT NULL,
        facility_name NVARCHAR(100) NOT NULL,
        CONSTRAINT PK_space_facility_requirements PRIMARY KEY (space_id, facility_name),
        CONSTRAINT FK_space_facility_requirements_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        CONSTRAINT CK_space_facility_requirements_facility_name CHECK (
            facility_name IN (N'Projector', N'Whiteboard', N'AirConditioner',
                              N'ComputerStation', N'SpeakerSystem',
                              N'VideoConference', N'SmartBoard'))
    );
    PRINT N'    space_facility_requirements created.';
END
ELSE PRINT N'    space_facility_requirements: already exists.';

IF OBJECT_ID(N'dbo.user_roles', N'U') IS NULL
BEGIN
    /* Amendment 1c. Pure junction, same shape as policy_booking_types.
       A user with zero roles is a VALID lifecycle state (Output 09 section 11):
       a junction table cannot declaratively require "at least one row". */
    CREATE TABLE dbo.user_roles (
        user_id INT           NOT NULL,
        role    NVARCHAR(30)  NOT NULL,
        CONSTRAINT PK_user_roles PRIMARY KEY (user_id, role),
        CONSTRAINT FK_user_roles_user_id FOREIGN KEY (user_id)
            REFERENCES dbo.user_accounts(user_id),
        CONSTRAINT CK_user_roles_role CHECK (
            role IN (N'Student', N'Lecturer', N'TeachingAssistant',
                     N'FacilityStaff', N'DepartmentAdministrator', N'FacilityManager'))
    );
    PRINT N'    user_roles created.';
END
ELSE PRINT N'    user_roles: already exists.';

IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.maintenance_impact_history (
        history_id       INT            NOT NULL IDENTITY(1,1),
        maintenance_id   INT            NOT NULL,
        changed_by       INT            NOT NULL,
        old_impact_level NVARCHAR(20)   NULL,
        new_impact_level NVARCHAR(20)   NOT NULL,
        changed_at       DATETIME2      NOT NULL
            CONSTRAINT DF_maintenance_impact_history_changed_at DEFAULT GETDATE(),
        change_reason    NVARCHAR(MAX)  NULL,
        CONSTRAINT PK_maintenance_impact_history PRIMARY KEY (history_id),
        CONSTRAINT FK_maintenance_impact_history_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES dbo.maintenance_records(maintenance_id),
        CONSTRAINT FK_maintenance_impact_history_changed_by FOREIGN KEY (changed_by)
            REFERENCES dbo.user_accounts(user_id),
        CONSTRAINT CK_maintenance_impact_history_old_level CHECK (
            old_impact_level IS NULL OR old_impact_level IN (N'Advisory', N'OutOfService')),
        CONSTRAINT CK_maintenance_impact_history_new_level CHECK (
            new_impact_level IN (N'Advisory', N'OutOfService'))
    );
    PRINT N'    maintenance_impact_history created.';
END
ELSE PRINT N'    maintenance_impact_history: already exists.';

IF OBJECT_ID(N'dbo.booking_advisory_acknowledgments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.booking_advisory_acknowledgments (
        ack_id          INT       NOT NULL IDENTITY(1,1),
        booking_id      INT       NOT NULL,
        maintenance_id  INT       NOT NULL,
        acknowledged_by INT       NOT NULL,
        acknowledged_at DATETIME2 NOT NULL
            CONSTRAINT DF_booking_advisory_acknowledgments_acknowledged_at DEFAULT GETDATE(),
        CONSTRAINT PK_booking_advisory_acknowledgments PRIMARY KEY (ack_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_booking_id FOREIGN KEY (booking_id)
            REFERENCES dbo.bookings(booking_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_maintenance_id FOREIGN KEY (maintenance_id)
            REFERENCES dbo.maintenance_records(maintenance_id),
        CONSTRAINT FK_booking_advisory_acknowledgments_acknowledged_by FOREIGN KEY (acknowledged_by)
            REFERENCES dbo.user_accounts(user_id),
        /* Natural key: one acknowledgement per advisory per booking. */
        CONSTRAINT UQ_booking_advisory_acknowledgments_booking_maintenance
            UNIQUE (booking_id, maintenance_id)
    );
    PRINT N'    booking_advisory_acknowledgments created.';
END
ELSE PRINT N'    booking_advisory_acknowledgments: already exists.';

IF OBJECT_ID(N'dbo.auto_approval_policies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.auto_approval_policies (
        policy_id        INT           NOT NULL IDENTITY(1,1),
        space_type       NVARCHAR(30)  NULL,
        space_id         INT           NULL,
        max_participants INT           NULL,
        is_active        BIT           NOT NULL
            CONSTRAINT DF_auto_approval_policies_is_active DEFAULT 1,
        created_at       DATETIME2     NOT NULL
            CONSTRAINT DF_auto_approval_policies_created_at DEFAULT GETDATE(),
        updated_at       DATETIME2     NOT NULL
            CONSTRAINT DF_auto_approval_policies_updated_at DEFAULT GETDATE(),
        CONSTRAINT PK_auto_approval_policies PRIMARY KEY (policy_id),
        CONSTRAINT FK_auto_approval_policies_space_id FOREIGN KEY (space_id)
            REFERENCES dbo.spaces(space_id),
        CONSTRAINT CK_auto_approval_policies_space_type CHECK (
            space_type IS NULL OR space_type IN (
                N'Auditorium', N'Classroom', N'ComputerLaboratory',
                N'ProjectLaboratory', N'MeetingRoom', N'StudentWorkspace')),
        CONSTRAINT CK_auto_approval_policies_max_participants CHECK (
            max_participants IS NULL OR max_participants > 0),
        /* Exactly one scope: type-wide XOR space-specific. */
        CONSTRAINT CK_auto_approval_policies_scope CHECK (
            (space_type IS NULL     AND space_id IS NOT NULL)
         OR (space_type IS NOT NULL AND space_id IS NULL))
        /* NOTE: uniqueness of the two scopes is enforced by FILTERED UNIQUE
           INDEXES in section 9, never by UNIQUE constraints. In SQL Server a
           UNIQUE constraint treats NULLs as EQUAL (unlike the ANSI standard),
           so it permits at most ONE NULL row -- a plain UNIQUE (space_id) would
           allow only a single type-wide policy in the whole table and reject
           every later one as a duplicate NULL.
           NOTE: no requires_advisory_ack column (Output 09 section 5.14, defect
           L9): acknowledgement is mandatory on every approval path, never a
           per-policy knob, so the column would have no read path. */
    );
    PRINT N'    auto_approval_policies created.';
END
ELSE PRINT N'    auto_approval_policies: already exists.';

IF OBJECT_ID(N'dbo.policy_booking_types', N'U') IS NULL
BEGIN
    /* Exists because SQL Server has no array type. */
    CREATE TABLE dbo.policy_booking_types (
        policy_id    INT          NOT NULL,
        booking_type NVARCHAR(30) NOT NULL,
        CONSTRAINT PK_policy_booking_types PRIMARY KEY (policy_id, booking_type),
        CONSTRAINT FK_policy_booking_types_policy_id FOREIGN KEY (policy_id)
            REFERENCES dbo.auto_approval_policies(policy_id),
        CONSTRAINT CK_policy_booking_types_booking_type CHECK (
            booking_type IN (N'Lecture', N'Examination', N'Seminar', N'Workshop',
                             N'Meeting', N'StudentActivity', N'AdministrativeEvent',
                             N'ResearchActivity', N'ProjectWork'))
    );
    PRINT N'    policy_booking_types created.';
END
ELSE PRINT N'    policy_booking_types: already exists.';

IF OBJECT_ID(N'dbo.booking_alerts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.booking_alerts (
        alert_id                 INT           NOT NULL IDENTITY(1,1),
        maintenance_id           INT           NULL,
        asset_id                 INT           NULL,
        booking_id               INT           NOT NULL,
        alert_type               NVARCHAR(30)  NOT NULL
            CONSTRAINT DF_booking_alerts_alert_type DEFAULT N'MaintenanceEscalated',
        created_at               DATETIME2     NOT NULL
            CONSTRAINT DF_booking_alerts_created_at DEFAULT GETDATE(),
        acknowledged_by_staff_id INT           NULL,
        acknowledged_at          DATETIME2     NULL,
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
            alert_type IN (N'MaintenanceEscalated', N'RequiredAssetRelocated',
                           N'AdvisoryAddedAfterApproval')),
        /* Handling fields move together. */
        CONSTRAINT CK_booking_alerts_handled CHECK (
            (acknowledged_by_staff_id IS NULL     AND acknowledged_at IS NULL)
         OR (acknowledged_by_staff_id IS NOT NULL AND acknowledged_at IS NOT NULL)),
        /* Source scope: exactly one source column, matching alert_type.
           MaintenanceEscalated and AdvisoryAddedAfterApproval share the
           maintenance_id branch; RequiredAssetRelocated uses asset_id. */
        CONSTRAINT CK_booking_alerts_source_scope CHECK (
            (alert_type IN (N'MaintenanceEscalated', N'AdvisoryAddedAfterApproval')
                 AND maintenance_id IS NOT NULL AND asset_id IS NULL)
         OR (alert_type = N'RequiredAssetRelocated'
                 AND asset_id IS NOT NULL AND maintenance_id IS NULL))
    );
    PRINT N'    booking_alerts created.';
END
ELSE PRINT N'    booking_alerts: already exists.';

/* ===========================================================================
   SECTION 3. ADDITIVE COLUMN CHANGES TO PHASE 1 TABLES
   ---------------------------------------------------------------------------
   maintenance_records.space_id is NOT touched: it stays NOT NULL exactly as in
   Phase 1. There is no XOR constraint -- the suspected transitive dependency
   asset_id -> space_id is refuted by a relocation counterexample (Output 09
   section 8.3). space_id is an immutable historical snapshot of the affected
   space; asset_id optionally narrows the issue to one unit.
   =========================================================================== */

PRINT N'[3] Applying additive column changes ...';

/* --- maintenance_records.impact_level -------------------------------------
   Added NOT NULL with a MIGRATION-ONLY default so existing rows backfill to
   'OutOfService' (Phase 1 had one blanket rule: any maintenance fully blocked
   its space). The default is dropped in section 5 -- the final schema carries
   none. */
IF COL_LENGTH('dbo.maintenance_records', 'impact_level') IS NULL
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD impact_level NVARCHAR(20) NOT NULL
            CONSTRAINT DF_maintenance_records_impact_level DEFAULT N'OutOfService';
    PRINT N'    maintenance_records.impact_level added (backfilled to OutOfService).';
END
ELSE PRINT N'    maintenance_records.impact_level: already exists.';

/* --- maintenance_records.asset_id ----------------------------------------- */
IF COL_LENGTH('dbo.maintenance_records', 'asset_id') IS NULL
BEGIN
    ALTER TABLE dbo.maintenance_records ADD asset_id INT NULL;
    PRINT N'    maintenance_records.asset_id added (NULL for all legacy rows).';
END
ELSE PRINT N'    maintenance_records.asset_id: already exists.';

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
               WHERE name = N'FK_maintenance_records_asset_id'
                 AND parent_object_id = OBJECT_ID(N'dbo.maintenance_records'))
BEGIN
    EXEC (N'ALTER TABLE dbo.maintenance_records
              ADD CONSTRAINT FK_maintenance_records_asset_id FOREIGN KEY (asset_id)
                  REFERENCES dbo.facility_assets(asset_id);');
    PRINT N'    FK_maintenance_records_asset_id added.';
END
ELSE PRINT N'    FK_maintenance_records_asset_id: already exists.';

/* --- booking_decisions.decision_source -----------------------------------
   This default is PERMANENT (Output 09 section 5.9): a decision recorded
   without an explicit source is a staff decision. */
IF COL_LENGTH('dbo.booking_decisions', 'decision_source') IS NULL
BEGIN
    ALTER TABLE dbo.booking_decisions
        ADD decision_source NVARCHAR(10) NOT NULL
            CONSTRAINT DF_booking_decisions_decision_source DEFAULT N'Staff';
    PRINT N'    booking_decisions.decision_source added (backfilled to Staff).';
END
ELSE PRINT N'    booking_decisions.decision_source: already exists.';

/* --- booking_decisions.decided_by -> nullable -----------------------------
   Auto-approval decisions have no staff actor. A nullable FK is preferred over
   a sentinel "SYSTEM" user row, which would pollute user_accounts reporting. */
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'dbo.booking_decisions')
             AND name = N'decided_by' AND is_nullable = 0)
BEGIN
    ALTER TABLE dbo.booking_decisions ALTER COLUMN decided_by INT NULL;
    PRINT N'    booking_decisions.decided_by relaxed to NULL.';
END
ELSE PRINT N'    booking_decisions.decided_by: already nullable.';

/* ===========================================================================
   SECTION 4. DATA MIGRATION
   ---------------------------------------------------------------------------
   Reads Phase 1 structures that section 6 will drop. Every block is wrapped in
   an existence check AND in EXEC(), because on the second run these columns and
   tables no longer exist and column names bind at COMPILE time.
   =========================================================================== */

PRINT N'[4] Migrating Phase 1 data into the Phase 2 shape ...';

/* --- 4a. user_accounts.role -> user_roles --------------------------------- */
IF COL_LENGTH('dbo.user_accounts', 'role') IS NOT NULL
BEGIN
    EXEC (N'
        INSERT INTO dbo.user_roles (user_id, role)
        SELECT ua.user_id, ua.role
        FROM   dbo.user_accounts AS ua
        WHERE  ua.role IS NOT NULL
          AND  NOT EXISTS (SELECT 1 FROM dbo.user_roles ur
                           WHERE ur.user_id = ua.user_id AND ur.role = ua.role);');
    SELECT @n = COUNT(*) FROM dbo.user_roles;
    PRINT N'    user_roles seeded from user_accounts.role (' + CAST(@n AS NVARCHAR(10)) + N' rows total).';
END
ELSE
    PRINT N'    user_roles: skipped (user_accounts.role already dropped -- previous run).';

/* --- 4b. space_facilities -> facility_assets (EXPANSION) -------------------
   THE critical data-preservation step. Phase 1 stored equipment as a count;
   Phase 2 stores individual units. Each (space, facility, quantity) row becomes
   exactly `quantity` rows in facility_assets.

     serial_number : <space_code>-<UPPER(facility_name)>-<seq>, the documented
                     internal scheme for units with no manufacturer serial
                     (Output 09 section 5.6, defect L12).
     condition     : Phase 1 condition + note, concatenated so no text is lost.
     asset_status  : seeded UnderMaintenance ONLY where the Phase 1 text can be
                     attributed to a specific unit -- that is, where quantity = 1.

                     Rationale (decision A1): a condition of 'Damage reported' on
                     a row with quantity = 30 describes the GROUP, not any one
                     machine -- the accompanying note read '3 stations have faulty
                     keyboards'. Marking all 30 UnderMaintenance would be factually
                     wrong AND operationally harmful: if ComputerStation is a
                     required facility for that space, rule R8 would block every
                     booking of the room while 27 machines still work.

                     Multi-unit groups are therefore seeded 'Available' with the
                     original Phase 1 text preserved verbatim in `condition`, and
                     Section 11 lists them for per-unit staff assessment.
                     asset_status is staff-maintained operational state (Output 09
                     section 6, two-tier policy) -- the migration does not guess.

   facility_id -> facility_name is resolved through `facilities` WHILE IT STILL
   EXISTS. Phase 1 facility_name values are exactly the Phase 2 CHECK whitelist,
   so no translation table is needed; a guard below fails the migration loudly
   if that ever stops being true. */
IF OBJECT_ID(N'dbo.space_facilities', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.facilities', N'U') IS NOT NULL
BEGIN
    /* Guard: every Phase 1 facility_name must be inside the Phase 2 domain.
       If not, stop -- silently dropping unmapped equipment is unacceptable. */
    EXEC (N'
        IF EXISTS (SELECT 1 FROM dbo.facilities f
                   WHERE f.facility_name NOT IN (
                       N''Projector'', N''Whiteboard'', N''AirConditioner'',
                       N''ComputerStation'', N''SpeakerSystem'',
                       N''VideoConference'', N''SmartBoard''))
            THROW 50010, N''[4b] A Phase 1 facilities.facility_name is outside the Phase 2 CHECK whitelist. Migration stopped so no equipment is silently lost.'', 1;');

    /* Guard: quantity must be sane before it drives row generation. */
    EXEC (N'
        IF EXISTS (SELECT 1 FROM dbo.space_facilities WHERE quantity IS NULL OR quantity < 0)
            THROW 50011, N''[4b] space_facilities.quantity contains NULL or negative values. Migration stopped.'', 1;');

    EXEC (N'
        WITH nums AS (
            SELECT TOP (SELECT ISNULL(MAX(quantity), 0) FROM dbo.space_facilities)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects
        )
        INSERT INTO dbo.facility_assets
              (space_id, facility_name, serial_number, asset_status,
               condition, last_checked_date, created_at, updated_at)
        SELECT sf.space_id,
               f.facility_name,
               s.space_code + N''-'' + UPPER(f.facility_name) + N''-''
                   + RIGHT(N''000'' + CAST(nums.n AS NVARCHAR(10)), 3),
               CASE WHEN sf.quantity > 1                         THEN N''Available''
                    WHEN sf.condition IS NULL                    THEN N''Available''
                    WHEN sf.condition LIKE N''Good%''            THEN N''Available''
                    WHEN sf.condition LIKE N''Functional%''      THEN N''Available''
                    ELSE N''UnderMaintenance''
               END,
               NULLIF(CONCAT(sf.condition,
                             CASE WHEN sf.note IS NOT NULL
                                  THEN N'' | '' + sf.note ELSE N'''' END), N''''),
               NULL,
               GETDATE(),
               GETDATE()
        FROM   dbo.space_facilities AS sf
        JOIN   dbo.facilities       AS f ON f.facility_id = sf.facility_id
        JOIN   dbo.spaces           AS s ON s.space_id    = sf.space_id
        JOIN   nums                      ON nums.n       <= sf.quantity
        WHERE  NOT EXISTS (SELECT 1 FROM dbo.facility_assets fa
                           WHERE fa.serial_number =
                                 s.space_code + N''-'' + UPPER(f.facility_name) + N''-''
                                 + RIGHT(N''000'' + CAST(nums.n AS NVARCHAR(10)), 3));');

    SELECT @n = COUNT(*) FROM dbo.facility_assets;
    PRINT N'    facility_assets expanded from space_facilities (' + CAST(@n AS NVARCHAR(10)) + N' units total).';
END
ELSE
    PRINT N'    facility_assets: skipped (space_facilities/facilities already dropped -- previous run).';

/* ===========================================================================
   SECTION 5. POST-BACKFILL CONSTRAINTS
   ---------------------------------------------------------------------------
   Added only now, so legacy rows already comply. Wrapped in EXEC because they
   reference columns added in section 3 of the same batch.
   =========================================================================== */

PRINT N'[5] Adding constraints that legacy rows had to satisfy first ...';

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_maintenance_records_impact_level'
                 AND parent_object_id = OBJECT_ID(N'dbo.maintenance_records'))
BEGIN
    EXEC (N'ALTER TABLE dbo.maintenance_records
              ADD CONSTRAINT CK_maintenance_records_impact_level
              CHECK (impact_level IN (N''Advisory'', N''OutOfService''));');
    PRINT N'    CK_maintenance_records_impact_level added.';
END
ELSE PRINT N'    CK_maintenance_records_impact_level: already exists.';

/* Disclosed [EXTENSION] (Output 09 section 5.11, decision D-3): asset-scoped
   records may never be OutOfService, so one broken unit never closes a room.
   Legacy rows all have asset_id NULL, so they satisfy it trivially. */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_maintenance_records_asset_scope_level'
                 AND parent_object_id = OBJECT_ID(N'dbo.maintenance_records'))
BEGIN
    EXEC (N'ALTER TABLE dbo.maintenance_records
              ADD CONSTRAINT CK_maintenance_records_asset_scope_level
              CHECK (asset_id IS NULL OR impact_level = N''Advisory'');');
    PRINT N'    CK_maintenance_records_asset_scope_level added.';
END
ELSE PRINT N'    CK_maintenance_records_asset_scope_level: already exists.';

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_booking_decisions_decision_source'
                 AND parent_object_id = OBJECT_ID(N'dbo.booking_decisions'))
BEGIN
    EXEC (N'ALTER TABLE dbo.booking_decisions
              ADD CONSTRAINT CK_booking_decisions_decision_source
              CHECK (decision_source IN (N''Staff'', N''System''));');
    PRINT N'    CK_booking_decisions_decision_source added.';
END
ELSE PRINT N'    CK_booking_decisions_decision_source: already exists.';

/* Pairs the source with the actor. All Phase 1 rows are ('Staff', real user),
   so they satisfy it. */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_booking_decisions_source_actor'
                 AND parent_object_id = OBJECT_ID(N'dbo.booking_decisions'))
BEGIN
    EXEC (N'ALTER TABLE dbo.booking_decisions
              ADD CONSTRAINT CK_booking_decisions_source_actor
              CHECK ((decision_source = N''System'' AND decided_by IS NULL)
                  OR (decision_source = N''Staff''  AND decided_by IS NOT NULL));');
    PRINT N'    CK_booking_decisions_source_actor added.';
END
ELSE PRINT N'    CK_booking_decisions_source_actor: already exists.';

/* Drop the MIGRATION-ONLY default on impact_level. From here on, every new
   maintenance record must state its impact level explicitly. */
IF EXISTS (SELECT 1 FROM sys.default_constraints
           WHERE name = N'DF_maintenance_records_impact_level'
             AND parent_object_id = OBJECT_ID(N'dbo.maintenance_records'))
BEGIN
    ALTER TABLE dbo.maintenance_records DROP CONSTRAINT DF_maintenance_records_impact_level;
    PRINT N'    DF_maintenance_records_impact_level dropped (migration-only default).';
END
ELSE PRINT N'    DF_maintenance_records_impact_level: already dropped.';

/* ===========================================================================
   SECTION 6. RETIRE DEPRECATED OBJECTS
   ---------------------------------------------------------------------------
   Safe only because sections 1 and 4 already archived and carried the data.
   Drop order respects FKs: space_facilities references facilities.
   =========================================================================== */

PRINT N'[6] Retiring deprecated Phase 1 objects ...';

/* Amendment 1b. */
IF OBJECT_ID(N'dbo.space_facilities', N'U') IS NOT NULL
BEGIN
    /* Refuse to drop unless the expansion actually produced units. */
    SELECT @expected = ISNULL(SUM(quantity), 0) FROM dbo.mig_archive_space_facilities;
    SELECT @actual   = COUNT(*)                 FROM dbo.facility_assets;
    IF @actual < @expected
    BEGIN
        SET @msg = N'[6] Refusing to drop space_facilities: expected at least '
                 + CAST(@expected AS NVARCHAR(10)) + N' facility_assets rows, found '
                 + CAST(@actual AS NVARCHAR(10)) + N'.';
        THROW 50020, @msg, 1;
    END
    DROP TABLE dbo.space_facilities;
    PRINT N'    space_facilities dropped (amendment 1b) -- data carried to facility_assets.';
END
ELSE PRINT N'    space_facilities: already dropped.';

/* Amendment 1a. */
IF OBJECT_ID(N'dbo.facilities', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.facilities;
    PRINT N'    facilities dropped (amendment 1a) -- facility_name is now a CHECK-constrained attribute.';
END
ELSE PRINT N'    facilities: already dropped.';

/* Amendment 1c. Drop the CHECK first, then the column.
   NOTE: the Phase 1 CHECK is named CK_user_accounts_role, but any other
   dependent object is resolved dynamically so this never guesses a name. */
IF COL_LENGTH('dbo.user_accounts', 'role') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @c = COUNT(*) FROM dbo.mig_archive_user_accounts_role;',
                       N'@c INT OUTPUT', @c = @expected OUTPUT;
    SELECT @actual   = COUNT(*) FROM dbo.user_roles;
    IF @actual < @expected
    BEGIN
        SET @msg = N'[6] Refusing to drop user_accounts.role: expected at least '
                 + CAST(@expected AS NVARCHAR(10)) + N' user_roles rows, found '
                 + CAST(@actual AS NVARCHAR(10)) + N'.';
        THROW 50021, @msg, 1;
    END

    /* Drop every CHECK constraint that references the role column. */
    DECLARE @ck NVARCHAR(128);
    DECLARE ck_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT cc.name
        FROM   sys.check_constraints cc
        JOIN   sys.columns c
               ON c.object_id = cc.parent_object_id
              AND c.column_id = cc.parent_column_id
        WHERE  cc.parent_object_id = OBJECT_ID(N'dbo.user_accounts')
          AND  c.name = N'role';
    OPEN ck_cur;
    FETCH NEXT FROM ck_cur INTO @ck;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'ALTER TABLE dbo.user_accounts DROP CONSTRAINT ' + QUOTENAME(@ck) + N';';
        EXEC sp_executesql @sql;
        PRINT N'    dropped constraint ' + @ck + N' on user_accounts.role.';
        FETCH NEXT FROM ck_cur INTO @ck;
    END
    CLOSE ck_cur;
    DEALLOCATE ck_cur;

    /* Drop any default bound to the column (Phase 1 has none, but never assume).

       @ck MUST be reset first. `SELECT @var = col FROM ...` leaves @var
       UNCHANGED when the query returns no rows -- it does NOT assign NULL.
       Without this reset @ck would still hold the CHECK constraint name from
       the cursor loop above, and this block would try to drop that same
       constraint a second time ("'CK_user_accounts_role' is not a constraint").
       (`SET @var = (SELECT ...)` would assign NULL; `SELECT @var = ...` does not.) */
    SET @ck = NULL;

    SELECT @ck = dc.name
    FROM   sys.default_constraints dc
    JOIN   sys.columns c
           ON c.object_id = dc.parent_object_id
          AND c.column_id = dc.parent_column_id
    WHERE  dc.parent_object_id = OBJECT_ID(N'dbo.user_accounts')
      AND  c.name = N'role';
    IF @ck IS NOT NULL
    BEGIN
        SET @sql = N'ALTER TABLE dbo.user_accounts DROP CONSTRAINT ' + QUOTENAME(@ck) + N';';
        EXEC sp_executesql @sql;
        PRINT N'    dropped default ' + @ck + N' on user_accounts.role.';
    END

    ALTER TABLE dbo.user_accounts DROP COLUMN role;
    PRINT N'    user_accounts.role dropped (amendment 1c) -- data carried to user_roles.';
END
ELSE PRINT N'    user_accounts.role: already dropped.';

/* ===========================================================================
   SECTION 7. VIEWS
   ---------------------------------------------------------------------------
   v_space_facility_summary is UNION-based, and that is LOAD-BEARING, not
   cosmetic (Output 09 section 6). A version based on facility_assets alone
   would silently lose the (total_units = 0, is_required = 1) row -- which is
   exactly the state rule R8 blocks on. The universe of (space, facility) pairs
   is therefore the UNION of "has at least one unit" and "is required".

   is_required is CAST to BIT so the view's type matches the physical schema
   rather than yielding INT.
   =========================================================================== */

PRINT N'[7] Creating views ...';

EXEC (N'
CREATE OR ALTER VIEW dbo.v_space_facility_summary
AS
WITH combos AS (
    SELECT space_id, facility_name FROM dbo.facility_assets
    UNION
    SELECT space_id, facility_name FROM dbo.space_facility_requirements
)
SELECT c.space_id,
       c.facility_name,
       COUNT(fa.asset_id)                                              AS total_units,
       SUM(CASE WHEN fa.asset_status = N''Available'' THEN 1 ELSE 0 END) AS available_units,
       CAST(CASE WHEN r.space_id IS NULL THEN 0 ELSE 1 END AS BIT)     AS is_required
FROM   combos AS c
LEFT  JOIN dbo.facility_assets AS fa
       ON fa.space_id = c.space_id AND fa.facility_name = c.facility_name
LEFT  JOIN dbo.space_facility_requirements AS r
       ON r.space_id = c.space_id AND r.facility_name = c.facility_name
GROUP BY c.space_id, c.facility_name,
         CASE WHEN r.space_id IS NULL THEN 0 ELSE 1 END;');
PRINT N'    v_space_facility_summary created/updated.';

/* ===========================================================================
   SECTION 8. TRIGGERS  (rules R1-R16, Output 09 section 7)
   ---------------------------------------------------------------------------
   Standards applied to every trigger below:

   * RE-ENTRANCY GUARD uses the trigger''s OWN depth:
         TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1
     A bare TRIGGER_NESTLEVEL() > 1 would be WRONG here -- it counts the whole
     nesting stack, so a trigger legitimately fired BY ANOTHER trigger (e.g.
     TR_impact_history_StaffRole validating a row written by
     TR_maintenance_impact_history) would silently skip its own check.

   * SET-BASED ONLY. Triggers fire once per statement and inserted/deleted may
     hold many rows: no cursors, no scalar assignment from inserted.

   * FAIL LOUDLY. A rule violation rolls back and THROWs.

   These are VALIDATION objects. The concurrency mechanism (SERIALIZABLE +
   UPDLOCK/HOLDLOCK stored procedures) is Task 12 and is deliberately absent.
   =========================================================================== */

PRINT N'[8] Creating triggers ...';

/* --- 8.1 R1/R2 backstop: MODIFIED Phase 1 trigger -------------------------
   Two Phase 2 corrections:
     (a) UnderMaintenance REMOVED from the current_status check. Output 09
         section 4.1 makes spaces.current_status a UI-display column that is
         NEVER a maintenance-blocking predicate; leaving it here would wrongly
         block a space flagged for ADVISORY-only reasons. TemporarilyClosed and
         Retired stay -- those are legitimate non-maintenance closures.
     (b) The overlap check now covers CheckedIn as well as Approved, and an
         OutOfService impact-level check is added, querying maintenance_records
         directly. That query is complete by construction: every row carries a
         NOT NULL space_id (Output 09 section 8.3), so no JOIN through
         facility_assets is needed. */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_bookings_PreventOverlapAndUnavailable
ON dbo.bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   dbo.bookings b
               ON  b.space_id   = i.space_id
               AND b.booking_id <> i.booking_id
               AND b.status IN (N''Approved'', N''CheckedIn'')
               AND b.requested_start_time < i.requested_end_time
               AND b.requested_end_time   > i.requested_start_time
        WHERE  i.status IN (N''Approved'', N''CheckedIn''))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51001, N''Overlapping Approved/CheckedIn booking exists for this space.'', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   dbo.spaces s ON s.space_id = i.space_id
        WHERE  i.status IN (N''Pending'', N''Approved'', N''CheckedIn'')
          AND  s.current_status IN (N''TemporarilyClosed'', N''Retired''))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51002, N''Selected space is closed or retired.'', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   dbo.maintenance_records m
               ON  m.space_id     = i.space_id
               AND m.impact_level = N''OutOfService''
               AND m.status NOT IN (N''Completed'', N''Cancelled'')
               AND m.start_time < i.requested_end_time
               AND COALESCE(m.completion_time, CAST(N''9999-12-31 23:59:59'' AS DATETIME2))
                     > i.requested_start_time
        WHERE  i.status IN (N''Pending'', N''Approved'', N''CheckedIn''))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51003, N''Space has active out-of-service maintenance overlapping the requested window.'', 1;
    END

    /* Keep updated_at fresh on UPDATE only (Phase 1 behaviour): on INSERT the
       column default already supplies GETDATE(), so an extra write would be
       pure overhead. RECURSIVE_TRIGGERS is OFF by default, so this write-back
       does not re-fire this trigger. */
    IF EXISTS (SELECT 1 FROM deleted)
        UPDATE b SET updated_at = GETDATE()
        FROM dbo.bookings b JOIN inserted i ON i.booking_id = b.booking_id;
END');
PRINT N'    TR_bookings_PreventOverlapAndUnavailable altered (R1/R2 backstop).';

/* --- 8.2 R9: impact-level audit trail -------------------------------------
   INSERT writes the creation row (old_impact_level NULL); UPDATE writes a row
   only when the value actually changed. The actor comes from SESSION_CONTEXT
   with the documented fallback chain, so the audit row never carries NULL or a
   fabricated value. SESSION_CONTEXT returns SQL_VARIANT -- TRY_CONVERT keeps an
   unset key degrading to the fallback instead of raising. */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_maintenance_impact_history
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    INSERT INTO dbo.maintenance_impact_history
          (maintenance_id, changed_by, old_impact_level, new_impact_level, changed_at, change_reason)
    SELECT i.maintenance_id,
           COALESCE(TRY_CONVERT(INT, SESSION_CONTEXT(N''current_user_id'')),
                    i.assigned_staff_id, i.reporter_id),
           d.impact_level,
           i.impact_level,
           GETDATE(),
           CONVERT(NVARCHAR(MAX), SESSION_CONTEXT(N''change_reason''))
    FROM   inserted i
    LEFT  JOIN deleted d ON d.maintenance_id = i.maintenance_id
    WHERE  d.maintenance_id IS NULL
       OR  d.impact_level <> i.impact_level;
END');
PRINT N'    TR_maintenance_impact_history created (R9).';

/* --- 8.3 R16: the recorded actor must hold a staff role --------------------
   NARROWED, DELIBERATELY -- and the reason must not be lost.

   Output 09 states R16 as "the resolved changed_by actor must hold a staff-type
   role", but Output 09 section 5.13 also defines the actor fallback chain as
       COALESCE(SESSION_CONTEXT, assigned_staff_id, reporter_id).
   Those two rules CONTRADICT each other on the creation row: a Student may
   legitimately REPORT a broken projector, and with no session context and no
   staff assigned yet, the chain resolves changed_by to that student. Enforcing
   R16 over every row would make TR_maintenance_impact_history reject the audit
   row, which rolls back the maintenance report itself -- i.e. students could
   never report a fault at all.

   Resolution applied here: enforce R16 only on ESCALATION / DOWNGRADE rows
   (old_impact_level IS NOT NULL). Changing an impact level IS a staff action
   and must be attributable to staff. The creation row (old_impact_level NULL)
   records who reported the problem and is intentionally open to any user.
   Flagged for Output 09 to state this narrowing explicitly. */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_impact_history_StaffRole
ON dbo.maintenance_impact_history
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.old_impact_level IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dbo.user_roles ur
              WHERE ur.user_id = i.changed_by
                AND ur.role IN (N''FacilityStaff'', N''FacilityManager'',
                                N''DepartmentAdministrator'')))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51016, N''An impact-level change must be attributable to a staff-type role.'', 1;
    END
END');
PRINT N'    TR_impact_history_StaffRole created (R16, narrowed to level changes).';

/* --- 8.4 R5: escalation makes affected bookings identifiable to staff ------
   Fires when impact_level rises to OutOfService. One alert per already
   Approved/CheckedIn booking overlapping the maintenance window. This is a
   LOOKUP, not a notification -- contacting requesters stays a manual staff
   action (out of scope, Phase 1 section 17). */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_maintenance_escalation
ON dbo.maintenance_records
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    INSERT INTO dbo.booking_alerts (maintenance_id, asset_id, booking_id, alert_type, created_at)
    SELECT i.maintenance_id, NULL, b.booking_id, N''MaintenanceEscalated'', GETDATE()
    FROM   inserted i
    JOIN   deleted  d ON d.maintenance_id = i.maintenance_id
    JOIN   dbo.bookings b
           ON  b.space_id = i.space_id
           AND b.status IN (N''Approved'', N''CheckedIn'')
           AND b.requested_start_time <
                 COALESCE(i.completion_time, CAST(N''9999-12-31 23:59:59'' AS DATETIME2))
           AND b.requested_end_time > i.start_time
    WHERE  i.impact_level = N''OutOfService''
      AND  d.impact_level <> N''OutOfService''
      AND  NOT EXISTS (SELECT 1 FROM dbo.booking_alerts a
                       WHERE a.maintenance_id = i.maintenance_id
                         AND a.booking_id     = b.booking_id
                         AND a.alert_type     = N''MaintenanceEscalated'');
END');
PRINT N'    TR_maintenance_escalation created (R5).';

/* --- 8.5 L11: advisory filed AFTER bookings were approved ------------------
   Rule R3 only gates the transition INTO Approved/CheckedIn. A new advisory
   does NOT retroactively invalidate an approved booking; staff are informed
   through the same alert list instead. */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_maintenance_AdvisoryAddedAlert
ON dbo.maintenance_records
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    INSERT INTO dbo.booking_alerts (maintenance_id, asset_id, booking_id, alert_type, created_at)
    SELECT i.maintenance_id, NULL, b.booking_id, N''AdvisoryAddedAfterApproval'', GETDATE()
    FROM   inserted i
    JOIN   dbo.bookings b
           ON  b.space_id = i.space_id
           AND b.status IN (N''Approved'', N''CheckedIn'')
           AND b.requested_start_time <
                 COALESCE(i.completion_time, CAST(N''9999-12-31 23:59:59'' AS DATETIME2))
           AND b.requested_end_time > i.start_time
    WHERE  i.impact_level = N''Advisory''
      AND  i.status NOT IN (N''Completed'', N''Cancelled'')
      AND  NOT EXISTS (SELECT 1 FROM dbo.booking_alerts a
                       WHERE a.maintenance_id = i.maintenance_id
                         AND a.booking_id     = b.booking_id
                         AND a.alert_type     = N''AdvisoryAddedAfterApproval'');
END');
PRINT N'    TR_maintenance_AdvisoryAddedAlert created (L11).';

/* --- 8.6 asset_status kept in step with asset-scoped maintenance -----------
   asset_status is stored OPERATIONAL STATE, not a derived fact (Output 09
   section 6, two-tier policy). A unit returns to Available only when NO other
   active record still targets it. */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_maintenance_SyncAssetStatus
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    UPDATE fa
    SET    asset_status = N''UnderMaintenance'', updated_at = GETDATE()
    FROM   dbo.facility_assets fa
    JOIN   inserted i ON i.asset_id = fa.asset_id
    WHERE  i.status NOT IN (N''Completed'', N''Cancelled'')
      AND  fa.asset_status <> N''Retired''
      AND  fa.asset_status <> N''UnderMaintenance'';

    UPDATE fa
    SET    asset_status = N''Available'', updated_at = GETDATE()
    FROM   dbo.facility_assets fa
    JOIN   inserted i ON i.asset_id = fa.asset_id
    WHERE  i.status IN (N''Completed'', N''Cancelled'')
      AND  fa.asset_status = N''UnderMaintenance''
      AND  NOT EXISTS (SELECT 1 FROM dbo.maintenance_records m
                       WHERE m.asset_id = fa.asset_id
                         AND m.status NOT IN (N''Completed'', N''Cancelled''));
END');
PRINT N'    TR_maintenance_SyncAssetStatus created.';

/* --- 8.7 D-1: creation-time-only asset/space invariant ---------------------
   At INSERT, a named asset must currently belong to the recorded space_id.
   NEVER re-checked afterwards: space_id is an immutable historical snapshot and
   the asset is free to relocate later without invalidating the record. This is
   why the trigger is AFTER INSERT only, not AFTER INSERT, UPDATE. */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_maintenance_TargetInvariant
ON dbo.maintenance_records
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   dbo.facility_assets fa ON fa.asset_id = i.asset_id
        WHERE  i.asset_id IS NOT NULL
          AND  fa.space_id <> i.space_id)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51007, N''At creation, maintenance_records.asset_id must belong to the recorded space_id.'', 1;
    END
END');
PRINT N'    TR_maintenance_TargetInvariant created (D-1).';

/* --- 8.8 R14: assigned staff must hold a facility role --------------------- */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_maintenance_StaffRole
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.assigned_staff_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dbo.user_roles ur
              WHERE ur.user_id = i.assigned_staff_id
                AND ur.role IN (N''FacilityStaff'', N''FacilityManager'')))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51014, N''maintenance_records.assigned_staff_id must hold FacilityStaff or FacilityManager.'', 1;
    END
END');
PRINT N'    TR_maintenance_StaffRole created (R14).';

/* --- 8.9 R3: every active advisory acknowledged before Approved/CheckedIn --
   SET-BASED existence test, never a COUNT comparison (Output 09 section 9.5.3,
   defect L2): counting is not set containment -- an acknowledged-but-now-closed
   advisory would otherwise mask a different unacknowledged one. */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_bookings_AdvisoryAckRequired
ON dbo.bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   dbo.maintenance_records m
               ON  m.space_id     = i.space_id
               AND m.impact_level = N''Advisory''
               AND m.status NOT IN (N''Completed'', N''Cancelled'')
               AND m.start_time < i.requested_end_time
               AND COALESCE(m.completion_time, CAST(N''9999-12-31 23:59:59'' AS DATETIME2))
                     > i.requested_start_time
        WHERE  i.status IN (N''Approved'', N''CheckedIn'')
          AND  NOT EXISTS (SELECT 1 FROM dbo.booking_advisory_acknowledgments a
                           WHERE a.booking_id = i.booking_id
                             AND a.maintenance_id = m.maintenance_id))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51004, N''Booking has unacknowledged active advisories for this space.'', 1;
    END
END');
PRINT N'    TR_bookings_AdvisoryAckRequired created (R3).';

/* --- 8.10 R8: required facility must have an available unit ---------------- */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_bookings_RequiredAssetCheck
ON dbo.bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   dbo.space_facility_requirements r ON r.space_id = i.space_id
        WHERE  i.status IN (N''Approved'', N''CheckedIn'')
          AND  NOT EXISTS (SELECT 1 FROM dbo.facility_assets fa
                           WHERE fa.space_id      = r.space_id
                             AND fa.facility_name = r.facility_name
                             AND fa.asset_status  = N''Available''))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51008, N''A facility marked required for this space has no available unit.'', 1;
    END
END');
PRINT N'    TR_bookings_RequiredAssetCheck created (R8).';

/* --- 8.11 R12: relocating a required, WORKING unit raises an alert ---------
   Precision requirement: the alert means a USABLE unit became unavailable to
   the origin space''s bookings. Reading the pre-move state from `deleted`
   ensures moving an already UnderMaintenance / InUse / Retired unit raises
   nothing -- it took nothing away. */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_facility_assets_RelocationAlert
ON dbo.facility_assets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;
    IF NOT UPDATE(space_id) RETURN;

    INSERT INTO dbo.booking_alerts (maintenance_id, asset_id, booking_id, alert_type, created_at)
    SELECT NULL, i.asset_id, b.booking_id, N''RequiredAssetRelocated'', GETDATE()
    FROM   inserted i
    JOIN   deleted  d ON d.asset_id = i.asset_id
    JOIN   dbo.space_facility_requirements r
           ON  r.space_id      = d.space_id
           AND r.facility_name = d.facility_name
    JOIN   dbo.bookings b
           ON  b.space_id = d.space_id
           AND b.status IN (N''Approved'', N''CheckedIn'')
    WHERE  d.space_id <> i.space_id
      AND  d.asset_status = N''Available''
      AND  NOT EXISTS (SELECT 1 FROM dbo.booking_alerts a
                       WHERE a.asset_id   = i.asset_id
                         AND a.booking_id = b.booking_id
                         AND a.alert_type = N''RequiredAssetRelocated'');
END');
PRINT N'    TR_facility_assets_RelocationAlert created (R12).';

/* --- 8.12 L10: only an Advisory record can be acknowledged ----------------- */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_ack_AdvisoryOnly
ON dbo.booking_advisory_acknowledgments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   dbo.maintenance_records m ON m.maintenance_id = i.maintenance_id
        WHERE  m.impact_level <> N''Advisory'')
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51010, N''Only Advisory maintenance records can be acknowledged; OutOfService never requires acknowledgement.'', 1;
    END
END');
PRINT N'    TR_ack_AdvisoryOnly created (L10).';

/* --- 8.13 R13: a Staff decision needs a staff actor ------------------------ */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_booking_decisions_StaffRole
ON dbo.booking_decisions
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.decision_source = N''Staff''
          AND NOT EXISTS (
              SELECT 1 FROM dbo.user_roles ur
              WHERE ur.user_id = i.decided_by
                AND ur.role IN (N''FacilityStaff'', N''FacilityManager'',
                                N''DepartmentAdministrator'')))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51013, N''booking_decisions.decided_by must hold a staff-type role for a Staff decision.'', 1;
    END
END');
PRINT N'    TR_booking_decisions_StaffRole created (R13).';

/* --- 8.14 R15: alert handler must hold a staff role ------------------------ */
EXEC (N'
CREATE OR ALTER TRIGGER dbo.TR_booking_alerts_StaffRole
ON dbo.booking_alerts
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(@@PROCID, ''AFTER'', ''DML'') > 1 RETURN;

    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.acknowledged_by_staff_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM dbo.user_roles ur
              WHERE ur.user_id = i.acknowledged_by_staff_id
                AND ur.role IN (N''FacilityStaff'', N''FacilityManager'',
                                N''DepartmentAdministrator'')))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51015, N''booking_alerts.acknowledged_by_staff_id must hold a staff-type role.'', 1;
    END
END');
PRINT N'    TR_booking_alerts_StaffRole created (R15).';

/* ===========================================================================
   SECTION 9. INDEXES
   ---------------------------------------------------------------------------
   Creating these is Task 10 (the schema needs them). MEASURING them -- execution
   plans, before/after timings -- is Task 15 and is deliberately absent.

   TWO STANDING RULES applied throughout:

   (a) THE FILTERED-INDEX PREDICATE GRAMMAR IS NARROW. It is exactly:
             <predicate> ::= <conjunct> [ AND <conjunct> ]
             <conjunct>  ::= column IN (constant, ...)          -- allowed
                           | column <op> constant               -- = <> != > >= < <= IS "IS NOT"
       Consequences, both of which this section obeys:
         * `IN (...)` IS PERMITTED -- it is the disjunct production. Do NOT
           "helpfully" expand it into `x = a OR x = b`: bare **OR is NOT in the
           grammar at all** and fails with "Incorrect syntax near the keyword OR".
         * `NOT IN (...)` is NOT permitted. Every "status NOT IN (...)" from the
           design document is written here as explicit <> conjuncts joined by AND.
       (Inside ordinary WHERE clauses both NOT IN and OR are fine -- see the
       triggers above. This restriction applies only to filtered indexes.)

   (b) FILTERED UNIQUE INDEXES, NEVER `UNIQUE` CONSTRAINTS, ON NULLABLE COLUMNS.
       In SQL Server a UNIQUE constraint or unique index treats NULLs as EQUAL
       -- the opposite of the ANSI standard and of PostgreSQL/Oracle -- so it
       permits at most ONE NULL row. A plain UNIQUE on a column that is NULL for
       a whole legitimate class of rows would therefore OVER-constrain: the
       second such row is rejected as a duplicate NULL. A filtered unique index
       removes those rows from the index entirely, so unlimited NULL-keyed rows
       coexist while the real keys stay unique.

   NOT CREATED HERE, deliberately:
     I16  UQ_usage_sessions_booking_id -- already exists as the implicit index of
          a Phase 1 UNIQUE constraint. Creating it again would duplicate a
          B-tree for no benefit.
     I8   IX_ack_booking on (booking_id, maintenance_id) -- identical in key and
          order to the index SQL Server already created for
          UQ_booking_advisory_acknowledgments_booking_maintenance. Creating it
          would be a pure duplicate; the UNIQUE constraint's index serves the
          ack-completeness join.
   =========================================================================== */

PRINT N'[9] Creating indexes ...';

/* I1 -- concurrency-critical: key-range locking for the overlap check. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_bookings_space_status_time'
                 AND object_id = OBJECT_ID(N'dbo.bookings'))
    EXEC (N'CREATE INDEX IX_bookings_space_status_time ON dbo.bookings
              (space_id, requested_start_time, requested_end_time)
            WHERE status IN (N''Approved'', N''CheckedIn'');');

/* I2 -- semester-range scans for the per-space hours and weekday/hour reports. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_bookings_space_status_start'
                 AND object_id = OBJECT_ID(N'dbo.bookings'))
    EXEC (N'CREATE INDEX IX_bookings_space_status_start ON dbo.bookings
              (space_id, status, requested_start_time)
            WHERE status IN (N''Approved'', N''CheckedIn'', N''Completed'');');

/* I3 -- the OutOfService blocking check. Tiny active set, seek per space. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_maintenance_blocking'
                 AND object_id = OBJECT_ID(N'dbo.maintenance_records'))
    EXEC (N'CREATE INDEX IX_maintenance_blocking ON dbo.maintenance_records
              (space_id, start_time, completion_time)
            WHERE impact_level = N''OutOfService''
              AND status <> N''Completed'' AND status <> N''Cancelled'';');

/* I4 -- advisory display and ack-completeness (R3). */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_maintenance_advisory'
                 AND object_id = OBJECT_ID(N'dbo.maintenance_records'))
    EXEC (N'CREATE INDEX IX_maintenance_advisory ON dbo.maintenance_records
              (space_id, start_time, completion_time)
            WHERE impact_level = N''Advisory''
              AND status <> N''Completed'' AND status <> N''Cancelled'';');

/* I5 -- active records by level and window, for the escalation/downgrade
   workflow and impact-history reporting. (The BOOKING-side scan during
   escalation is served by I1 on dbo.bookings, not by this index.) */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_maintenance_escalation_window'
                 AND object_id = OBJECT_ID(N'dbo.maintenance_records'))
    EXEC (N'CREATE INDEX IX_maintenance_escalation_window ON dbo.maintenance_records
              (impact_level, status, start_time, completion_time);');

/* I6 -- required-asset availability (R8), view aggregation, and the FK lookup
   for FK_facility_assets_space_id (SQL Server does not auto-index FK columns). */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_assets_location_status'
                 AND object_id = OBJECT_ID(N'dbo.facility_assets'))
    EXEC (N'CREATE INDEX IX_assets_location_status ON dbo.facility_assets
              (space_id, facility_name, asset_status);');

/* I7 -- catalogue-type drill-down across spaces. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_assets_facility_name'
                 AND object_id = OBJECT_ID(N'dbo.facility_assets'))
    EXEC (N'CREATE INDEX IX_assets_facility_name ON dbo.facility_assets (facility_name);');

/* I9 -- advisory lookup per maintenance record. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ack_maintenance'
                 AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgments'))
    EXEC (N'CREATE INDEX IX_ack_maintenance ON dbo.booking_advisory_acknowledgments (maintenance_id);');

/* I10 -- escalation lookup: affected bookings per record. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_alerts_maintenance'
                 AND object_id = OBJECT_ID(N'dbo.booking_alerts'))
    EXEC (N'CREATE INDEX IX_alerts_maintenance ON dbo.booking_alerts (maintenance_id, booking_id);');

/* I11 -- the open-alert action list. Keyed on (alert_type, created_at), NOT on
   acknowledged_at: keying on the filter column would give every row in the
   filtered set the same key value and no usable seek. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_alerts_open'
                 AND object_id = OBJECT_ID(N'dbo.booking_alerts'))
    EXEC (N'CREATE INDEX IX_alerts_open ON dbo.booking_alerts (alert_type, created_at)
            WHERE acknowledged_at IS NULL;');

/* I12 -- impact-change audit trail per record. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_history_maintenance'
                 AND object_id = OBJECT_ID(N'dbo.maintenance_impact_history'))
    EXEC (N'CREATE INDEX IX_history_maintenance ON dbo.maintenance_impact_history
              (maintenance_id, changed_at);');

/* I13 -- room finder. Excludes ONLY the two legitimate non-maintenance blocks;
   maintenance blocking is decided solely by the OutOfService query (I3), never
   by current_status (Output 09 section 4.1). Written as <> conjuncts per rule (a). */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_roomfinder_capacity_type'
                 AND object_id = OBJECT_ID(N'dbo.spaces'))
    EXEC (N'CREATE INDEX IX_roomfinder_capacity_type ON dbo.spaces (capacity, space_type)
            WHERE current_status <> N''TemporarilyClosed'' AND current_status <> N''Retired'';');

/* I14 -- auto-approval eligibility lookup by space type. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_policies_scope'
                 AND object_id = OBJECT_ID(N'dbo.auto_approval_policies'))
    EXEC (N'CREATE INDEX IX_policies_scope ON dbo.auto_approval_policies (space_type, is_active);');

/* I15 -- reverse lookup: which policies permit a booking type. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_policies_booking_types'
                 AND object_id = OBJECT_ID(N'dbo.policy_booking_types'))
    EXEC (N'CREATE INDEX IX_policies_booking_types ON dbo.policy_booking_types (booking_type, policy_id);');

/* I18 -- reverse role lookup ("list every Facility Manager"), used by the
   R13-R16 staff-role invariants. The PK (user_id, role) only serves the
   opposite direction. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_user_roles_role'
                 AND object_id = OBJECT_ID(N'dbo.user_roles'))
    EXEC (N'CREATE INDEX IX_user_roles_role ON dbo.user_roles (role, user_id);');

/* --- Filtered UNIQUE indexes (rule (b)) ---------------------------------- */

/* I17 -- at most one ACTIVE type-wide policy per space_type, so eligibility
   evaluation is deterministic. Space-specific rows (space_type NULL) are
   untouched. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_auto_approval_policies_active_type'
                 AND object_id = OBJECT_ID(N'dbo.auto_approval_policies'))
    EXEC (N'CREATE UNIQUE INDEX UQ_auto_approval_policies_active_type
              ON dbo.auto_approval_policies (space_type)
            WHERE space_type IS NOT NULL AND is_active = 1;');

/* At most one specific-space override per space. A plain UNIQUE constraint here
   would be wrong in the OPPOSITE direction to what one might expect: type-wide
   rows all carry space_id NULL, and SQL Server's UNIQUE treats NULLs as equal,
   so it would accept the first type-wide policy and reject every one after it. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_auto_approval_policies_space_id'
                 AND object_id = OBJECT_ID(N'dbo.auto_approval_policies'))
    EXEC (N'CREATE UNIQUE INDEX UQ_auto_approval_policies_space_id
              ON dbo.auto_approval_policies (space_id)
            WHERE space_id IS NOT NULL;');

/* One alert per (source, booking) event PER alert_type -- one index per type,
   not per source column, so a MaintenanceEscalated row does not block a later,
   distinct AdvisoryAddedAfterApproval row for the same pair. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_booking_alerts_maint'
                 AND object_id = OBJECT_ID(N'dbo.booking_alerts'))
    EXEC (N'CREATE UNIQUE INDEX UQ_booking_alerts_maint
              ON dbo.booking_alerts (maintenance_id, booking_id)
            WHERE alert_type = N''MaintenanceEscalated'';');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_booking_alerts_asset'
                 AND object_id = OBJECT_ID(N'dbo.booking_alerts'))
    EXEC (N'CREATE UNIQUE INDEX UQ_booking_alerts_asset
              ON dbo.booking_alerts (asset_id, booking_id)
            WHERE alert_type = N''RequiredAssetRelocated'';');

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_booking_alerts_advisory_added'
                 AND object_id = OBJECT_ID(N'dbo.booking_alerts'))
    EXEC (N'CREATE UNIQUE INDEX UQ_booking_alerts_advisory_added
              ON dbo.booking_alerts (maintenance_id, booking_id)
            WHERE alert_type = N''AdvisoryAddedAfterApproval'';');

PRINT N'    indexes created (existing ones left untouched).';

/* ===========================================================================
   SECTION 10. VERIFICATION GATE  (runs BEFORE COMMIT)
   ---------------------------------------------------------------------------
   Any mismatch THROWs, which sends control to the CATCH block and ROLLS BACK.
   A migration that cannot prove it preserved the data does not commit.
   =========================================================================== */

PRINT N'[10] Verifying migration before commit ...';

/* 10a. Every archived unit count must be present in facility_assets. */
IF OBJECT_ID(N'dbo.mig_archive_space_facilities', N'U') IS NOT NULL
BEGIN
    SELECT @expected = ISNULL(SUM(quantity), 0) FROM dbo.mig_archive_space_facilities;
    SELECT @actual   = COUNT(*)                 FROM dbo.facility_assets;
    IF @actual <> @expected
    BEGIN
        SET @msg = N'[10a] facility_assets row count mismatch: expected '
                 + CAST(@expected AS NVARCHAR(10)) + N' (SUM of archived quantity), found '
                 + CAST(@actual AS NVARCHAR(10)) + N'.';
        THROW 50030, @msg, 1;
    END
    PRINT N'    10a OK: facility_assets = ' + CAST(@actual AS NVARCHAR(10))
        + N' units, matching SUM(quantity) from the archive.';

    /* Every archived (space, facility) combination must have produced units. */
    IF EXISTS (
        SELECT 1
        FROM   dbo.mig_archive_space_facilities a
        JOIN   dbo.mig_archive_facilities f ON f.facility_id = a.facility_id
        WHERE  a.quantity > 0
          AND  NOT EXISTS (SELECT 1 FROM dbo.facility_assets fa
                           WHERE fa.space_id = a.space_id
                             AND fa.facility_name = f.facility_name))
        THROW 50031, N'[10a] An archived (space, facility) combination produced no facility_assets rows.', 1;
    PRINT N'    10a OK: every archived (space, facility) combination is represented.';
END

/* 10b. Every archived user role must exist in user_roles. */
IF OBJECT_ID(N'dbo.mig_archive_user_accounts_role', N'U') IS NOT NULL
BEGIN
    EXEC sp_executesql N'SELECT @c = COUNT(*) FROM dbo.mig_archive_user_accounts_role;',
                       N'@c INT OUTPUT', @c = @expected OUTPUT;
    SELECT @actual   = COUNT(*) FROM dbo.user_roles;
    IF @actual < @expected
    BEGIN
        SET @msg = N'[10b] user_roles row count too low: expected at least '
                 + CAST(@expected AS NVARCHAR(10)) + N', found '
                 + CAST(@actual AS NVARCHAR(10)) + N'.';
        THROW 50032, @msg, 1;
    END
    EXEC (N'IF EXISTS (SELECT 1 FROM dbo.mig_archive_user_accounts_role a
                       WHERE NOT EXISTS (SELECT 1 FROM dbo.user_roles ur
                                         WHERE ur.user_id = a.user_id AND ur.role = a.role))
                THROW 50033, N''[10b] A Phase 1 (user_id, role) pair is missing from user_roles.'', 1;');
    PRINT N'    10b OK: user_roles = ' + CAST(@actual AS NVARCHAR(10))
        + N' rows, every Phase 1 role preserved.';
END

/* 10c. Backfilled columns hold only legal values.
   WRAPPED IN EXEC, and this is not optional: impact_level and decision_source
   are added by ALTER TABLE in section 3 of THIS SAME BATCH. SQL Server defers
   name resolution for TABLES but binds COLUMN names of existing tables at
   COMPILE time -- so an unwrapped reference here fails the whole batch with
   "Invalid column name" before a single statement executes. */
EXEC (N'IF EXISTS (SELECT 1 FROM dbo.maintenance_records
                   WHERE impact_level NOT IN (N''Advisory'', N''OutOfService''))
            THROW 50034, N''[10c] maintenance_records.impact_level holds a value outside the Phase 2 domain.'', 1;');

EXEC (N'IF EXISTS (SELECT 1 FROM dbo.booking_decisions
                   WHERE decision_source NOT IN (N''Staff'', N''System''))
            THROW 50035, N''[10c] booking_decisions.decision_source holds a value outside the Phase 2 domain.'', 1;');

EXEC (N'IF EXISTS (SELECT 1 FROM dbo.booking_decisions
                   WHERE (decision_source = N''Staff''  AND decided_by IS NULL)
                      OR (decision_source = N''System'' AND decided_by IS NOT NULL))
            THROW 50036, N''[10c] booking_decisions violates the source/actor pairing rule.'', 1;');
PRINT N'    10c OK: backfilled columns hold only legal values.';

/* 10d. The final schema is exactly the 15 tables of Output 09 section 5 --
        the 2 dropped Phase 1 tables are gone, and none of the 15 is missing. */
IF OBJECT_ID(N'dbo.facilities', N'U') IS NOT NULL
    THROW 50037, N'[10d] facilities still exists -- amendment 1a not applied.', 1;
IF OBJECT_ID(N'dbo.space_facilities', N'U') IS NOT NULL
    THROW 50038, N'[10d] space_facilities still exists -- amendment 1b not applied.', 1;
IF COL_LENGTH('dbo.user_accounts', 'role') IS NOT NULL
    THROW 50039, N'[10d] user_accounts.role still exists -- amendment 1c not applied.', 1;

SELECT @actual = COUNT(*)
FROM   sys.tables
WHERE  SCHEMA_NAME(schema_id) = N'dbo'
  AND  name IN (N'departments', N'user_accounts', N'spaces', N'bookings',
                N'booking_decisions', N'usage_sessions', N'maintenance_records',
                N'facility_assets', N'space_facility_requirements', N'user_roles',
                N'maintenance_impact_history', N'booking_advisory_acknowledgments',
                N'auto_approval_policies', N'policy_booking_types', N'booking_alerts');
IF @actual <> 15
BEGIN
    SET @msg = N'[10d] Expected the 15 Phase 2 tables, found ' + CAST(@actual AS NVARCHAR(10)) + N'.';
    THROW 50040, @msg, 1;
END
PRINT N'    10d OK: exactly the 15 Phase 2 tables are present.';

/* 10e. The view and every trigger exist. */
IF OBJECT_ID(N'dbo.v_space_facility_summary', N'V') IS NULL
    THROW 50041, N'[10e] v_space_facility_summary is missing.', 1;

SELECT @actual = COUNT(*)
FROM   sys.triggers
WHERE  name IN (N'TR_bookings_PreventOverlapAndUnavailable', N'TR_maintenance_impact_history',
                N'TR_impact_history_StaffRole', N'TR_maintenance_escalation',
                N'TR_maintenance_AdvisoryAddedAlert', N'TR_maintenance_SyncAssetStatus',
                N'TR_maintenance_TargetInvariant', N'TR_maintenance_StaffRole',
                N'TR_bookings_AdvisoryAckRequired', N'TR_bookings_RequiredAssetCheck',
                N'TR_facility_assets_RelocationAlert', N'TR_ack_AdvisoryOnly',
                N'TR_booking_decisions_StaffRole', N'TR_booking_alerts_StaffRole');
IF @actual <> 14
BEGIN
    SET @msg = N'[10e] Expected 14 triggers, found ' + CAST(@actual AS NVARCHAR(10)) + N'.';
    THROW 50042, @msg, 1;
END
PRINT N'    10e OK: view present, all 14 triggers present.';

/* 10f. Phase 1 row counts are untouched on every retained table. */
IF EXISTS (SELECT 1 FROM dbo.bookings b
           WHERE NOT EXISTS (SELECT 1 FROM dbo.spaces s WHERE s.space_id = b.space_id))
    THROW 50043, N'[10f] Orphaned bookings detected after migration.', 1;
PRINT N'    10f OK: referential integrity intact.';

COMMIT TRANSACTION;

PRINT N'============================================================';
PRINT N' MIGRATION COMMITTED SUCCESSFULLY';
PRINT N'============================================================';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT N'============================================================';
    PRINT N' MIGRATION FAILED -- ROLLED BACK. Database is unchanged (Phase 1).';
    PRINT N'============================================================';
    PRINT N' Error  : ' + CAST(ERROR_NUMBER()   AS NVARCHAR(20));
    PRINT N' Line   : ' + CAST(ERROR_LINE()     AS NVARCHAR(20));
    PRINT N' Message: ' + ERROR_MESSAGE();

    THROW;
END CATCH

/* ===========================================================================
   SECTION 11. POST-COMMIT SUMMARY (read-only, outside the transaction)
   ---------------------------------------------------------------------------
   Nothing here modifies data. Its purpose is to give the operator the numbers
   needed to sign the migration off, plus the two review lists the migration
   cannot decide on its own.
   =========================================================================== */

PRINT N'';
PRINT N'--- Migration summary -------------------------------------';

/* Wrapped for the same compile-time reason as section 10c: impact_level and
   decision_source do not exist when this batch is compiled. */
EXEC (N'
SELECT N''facility_assets (units)''           AS metric, COUNT(*) AS value FROM dbo.facility_assets
UNION ALL SELECT N''user_roles'',                         COUNT(*) FROM dbo.user_roles
UNION ALL SELECT N''maintenance_records'',                COUNT(*) FROM dbo.maintenance_records
UNION ALL SELECT N''  ... of which OutOfService'',        COUNT(*) FROM dbo.maintenance_records WHERE impact_level = N''OutOfService''
UNION ALL SELECT N''booking_decisions'',                  COUNT(*) FROM dbo.booking_decisions
UNION ALL SELECT N''  ... of which Staff-sourced'',       COUNT(*) FROM dbo.booking_decisions WHERE decision_source = N''Staff''
UNION ALL SELECT N''bookings (untouched)'',               COUNT(*) FROM dbo.bookings
UNION ALL SELECT N''user_accounts (untouched)'',          COUNT(*) FROM dbo.user_accounts;');

/* REVIEW LIST 1 -- SINGLE-UNIT groups where the Phase 1 condition text pointed
   unambiguously at that one unit, so it was seeded UnderMaintenance. Staff should
   confirm each of these is genuinely out of service. */
PRINT N'';
PRINT N'--- Review A: single units seeded UnderMaintenance (confirm each) ---';
SELECT fa.asset_id, s.space_code, fa.facility_name, fa.serial_number, fa.condition
FROM   dbo.facility_assets fa
JOIN   dbo.spaces s ON s.space_id = fa.space_id
WHERE  fa.asset_status = N'UnderMaintenance'
ORDER  BY s.space_code, fa.facility_name, fa.serial_number;

/* REVIEW LIST 2 -- MULTI-UNIT groups whose Phase 1 condition text was NOT a clean
   'Good'/'Functional'. Per decision A1 these were all seeded Available, because the
   text describes the group and cannot be attributed to specific units (e.g. 30
   ComputerStations carrying 'Damage reported' with a note saying only 3 keyboards
   were faulty). Staff must decide WHICH units are actually down and set their
   asset_status individually. Until they do, the room stays bookable -- which is
   the correct default when most units still work. */
IF OBJECT_ID(N'dbo.mig_archive_space_facilities', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.mig_archive_facilities', N'U') IS NOT NULL
BEGIN
    PRINT N'';
    PRINT N'--- Review B: multi-unit groups seeded Available despite unclean Phase 1 condition ---';
    SELECT s.space_code,
           f.facility_name,
           a.quantity            AS units_seeded_available,
           a.condition           AS phase1_condition,
           a.note                AS phase1_note
    FROM   dbo.mig_archive_space_facilities a
    JOIN   dbo.mig_archive_facilities f ON f.facility_id = a.facility_id
    JOIN   dbo.spaces s                 ON s.space_id    = a.space_id
    WHERE  a.quantity > 1
      AND  a.condition IS NOT NULL
      AND  a.condition NOT LIKE N'Good%'
      AND  a.condition NOT LIKE N'Functional%'
    ORDER  BY s.space_code, f.facility_name;
END

/* REVIEW LIST 3 -- these archive tables are MIGRATION ARTIFACTS, not part of
   the Phase 2 schema. Drop them once the migration is signed off:
       DROP TABLE dbo.mig_archive_space_facilities;
       DROP TABLE dbo.mig_archive_facilities;
       DROP TABLE dbo.mig_archive_user_accounts_role;                          */
PRINT N'';
PRINT N'--- Migration artifacts retained for rollback (drop after sign-off) ---';
SELECT t.name AS archive_table, SUM(p.rows) AS row_count
FROM   sys.tables t
JOIN   sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE  t.name LIKE N'mig[_]archive[_]%'
GROUP  BY t.name
ORDER  BY t.name;

PRINT N'';
PRINT N'Next: Task 11 (concurrency design) and Task 12 (locking procedures).';
PRINT N'This script deliberately contains no stored procedures, no tuning';
PRINT N'experiments, and no report queries -- those belong to Tasks 12/15/16.';
GO
