-- =============================================================================
-- Campus Space Management System — Database Definition (DDL)
-- Group G08 — Microsoft SQL Server
-- Phase 1, Step 5: Database Definition
-- =============================================================================

-- This script creates the 9 tables, constraints, indexes, and triggers
-- for the SpaceWise system. Run on a fresh database in a single batch.

-- =============================================================================
-- 1. TABLE: departments
-- =============================================================================

CREATE TABLE departments (
    department_id   INT           NOT NULL IDENTITY(1,1),
    department_name NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_departments PRIMARY KEY (department_id)
);

-- =============================================================================
-- 2. TABLE: user_accounts
-- =============================================================================

CREATE TABLE user_accounts (
    user_id        INT            NOT NULL IDENTITY(1,1),
    email          NVARCHAR(255)  NOT NULL,
    full_name      NVARCHAR(100)  NOT NULL,
    phone_number   NVARCHAR(20)   NULL,
    role           NVARCHAR(30)   NOT NULL,
    account_status NVARCHAR(20)   NOT NULL DEFAULT 'Active',
    department_id  INT            NOT NULL,
    created_at     DATETIME2      NOT NULL DEFAULT GETDATE(),
    updated_at     DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_user_accounts PRIMARY KEY (user_id),
    CONSTRAINT UQ_user_accounts_email UNIQUE (email),
    CONSTRAINT FK_user_accounts_department_id FOREIGN KEY (department_id)
        REFERENCES departments(department_id),
    CONSTRAINT CK_user_accounts_role CHECK (
        role IN ('Student', 'Lecturer', 'TeachingAssistant',
                 'FacilityStaff', 'DepartmentAdministrator', 'FacilityManager')
    ),
    CONSTRAINT CK_user_accounts_account_status CHECK (
        account_status IN ('Active', 'Inactive', 'Suspended')
    )
);

-- =============================================================================
-- 3. TABLE: spaces
-- =============================================================================

CREATE TABLE spaces (
    space_id        INT            NOT NULL IDENTITY(1,1),
    space_code      NVARCHAR(20)   NOT NULL,
    space_name      NVARCHAR(100)  NOT NULL,
    space_type      NVARCHAR(30)   NOT NULL,
    building        NVARCHAR(100)  NOT NULL,
    floor           INT            NOT NULL,
    room_number     NVARCHAR(20)   NOT NULL,
    capacity        INT            NOT NULL,
    current_status  NVARCHAR(20)   NOT NULL DEFAULT 'Available',
    usage_policy    NVARCHAR(MAX)  NULL,
    created_at      DATETIME2      NOT NULL DEFAULT GETDATE(),
    updated_at      DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_spaces PRIMARY KEY (space_id),
    CONSTRAINT UQ_spaces_space_code UNIQUE (space_code),
    CONSTRAINT CK_spaces_space_type CHECK (
        space_type IN ('Auditorium', 'Classroom', 'ComputerLaboratory',
                       'ProjectLaboratory', 'MeetingRoom', 'StudentWorkspace')
    ),
    CONSTRAINT CK_spaces_capacity CHECK (capacity > 0),
    CONSTRAINT CK_spaces_current_status CHECK (
        current_status IN ('Available', 'InUse', 'UnderMaintenance',
                           'TemporarilyClosed', 'Retired')
    )
);

-- =============================================================================
-- 4. TABLE: facilities
-- =============================================================================

CREATE TABLE facilities (
    facility_id   INT            NOT NULL IDENTITY(1,1),
    facility_name NVARCHAR(100)  NOT NULL,
    description   NVARCHAR(MAX)  NULL,
    CONSTRAINT PK_facilities PRIMARY KEY (facility_id),
    CONSTRAINT UQ_facilities_facility_name UNIQUE (facility_name)
);

-- =============================================================================
-- 5. TABLE: space_facilities (Junction)
-- =============================================================================

CREATE TABLE space_facilities (
    space_id     INT            NOT NULL,
    facility_id  INT            NOT NULL,
    quantity     INT            NOT NULL DEFAULT 1,
    condition    NVARCHAR(100)  NULL,
    note         NVARCHAR(MAX)  NULL,
    CONSTRAINT PK_space_facilities PRIMARY KEY (space_id, facility_id),
    CONSTRAINT FK_space_facilities_space_id FOREIGN KEY (space_id)
        REFERENCES spaces(space_id),
    CONSTRAINT FK_space_facilities_facility_id FOREIGN KEY (facility_id)
        REFERENCES facilities(facility_id),
    CONSTRAINT CK_space_facilities_quantity CHECK (quantity >= 0)
);

-- =============================================================================
-- 6. TABLE: bookings
-- =============================================================================

CREATE TABLE bookings (
    booking_id             INT            NOT NULL IDENTITY(1,1),
    requester_id           INT            NOT NULL,
    space_id               INT            NOT NULL,
    requested_start_time   DATETIME2      NOT NULL,
    requested_end_time     DATETIME2      NOT NULL,
    purpose                NVARCHAR(MAX)  NOT NULL,
    expected_participants  INT            NOT NULL,
    booking_type           NVARCHAR(30)   NOT NULL,
    status                 NVARCHAR(20)   NOT NULL DEFAULT 'Pending',
    cancelled_at           DATETIME2      NULL,
    cancel_reason          NVARCHAR(MAX)  NULL,
    created_at             DATETIME2      NOT NULL DEFAULT GETDATE(),
    updated_at             DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_bookings PRIMARY KEY (booking_id),
    CONSTRAINT FK_bookings_requester_id FOREIGN KEY (requester_id)
        REFERENCES user_accounts(user_id),
    CONSTRAINT FK_bookings_space_id FOREIGN KEY (space_id)
        REFERENCES spaces(space_id),
    CONSTRAINT CK_bookings_time_range CHECK (
        requested_end_time > requested_start_time
    ),
    CONSTRAINT CK_bookings_expected_participants CHECK (expected_participants > 0),
    CONSTRAINT CK_bookings_booking_type CHECK (
        booking_type IN ('Lecture', 'Examination', 'Seminar', 'Workshop',
                         'Meeting', 'StudentActivity', 'AdministrativeEvent',
                         'ResearchActivity', 'ProjectWork')
    ),
    CONSTRAINT CK_bookings_status CHECK (
        status IN ('Pending', 'Approved', 'Rejected', 'Cancelled',
                   'CheckedIn', 'Completed', 'NoShow')
    )
);

-- =============================================================================
-- 7. TABLE: booking_decisions
-- =============================================================================

CREATE TABLE booking_decisions (
    decision_id      INT            NOT NULL IDENTITY(1,1),
    booking_id       INT            NOT NULL,
    decided_by       INT            NOT NULL,
    decision         NVARCHAR(10)   NOT NULL,
    decision_time    DATETIME2      NOT NULL DEFAULT GETDATE(),
    decision_note    NVARCHAR(MAX)  NULL,
    rejection_reason NVARCHAR(MAX)  NULL,
    CONSTRAINT PK_booking_decisions PRIMARY KEY (decision_id),
    CONSTRAINT FK_booking_decisions_booking_id FOREIGN KEY (booking_id)
        REFERENCES bookings(booking_id),
    CONSTRAINT FK_booking_decisions_decided_by FOREIGN KEY (decided_by)
        REFERENCES user_accounts(user_id),
    CONSTRAINT CK_booking_decisions_decision CHECK (
        decision IN ('Approved', 'Rejected')
    ),
    -- Rejection reason is mandatory when decision = 'Rejected'
    CONSTRAINT CK_booking_decisions_rejection_reason CHECK (
        decision <> 'Rejected' OR rejection_reason IS NOT NULL
    )
);

-- =============================================================================
-- 8. TABLE: usage_sessions
-- =============================================================================

CREATE TABLE usage_sessions (
    session_id        INT            NOT NULL IDENTITY(1,1),
    booking_id        INT            NOT NULL,
    checked_in_by     INT            NOT NULL,
    actual_start_time DATETIME2      NOT NULL,
    initial_condition NVARCHAR(MAX)  NULL,
    completed_by      INT            NULL,
    actual_end_time   DATETIME2      NULL,
    final_condition   NVARCHAR(MAX)  NULL,
    usage_notes       NVARCHAR(MAX)  NULL,
    CONSTRAINT PK_usage_sessions PRIMARY KEY (session_id),
    CONSTRAINT UQ_usage_sessions_booking_id UNIQUE (booking_id),
    CONSTRAINT FK_usage_sessions_booking_id FOREIGN KEY (booking_id)
        REFERENCES bookings(booking_id),
    CONSTRAINT FK_usage_sessions_checked_in_by FOREIGN KEY (checked_in_by)
        REFERENCES user_accounts(user_id),
    CONSTRAINT FK_usage_sessions_completed_by FOREIGN KEY (completed_by)
        REFERENCES user_accounts(user_id),
    -- Completion fields must be both NULL or both non-NULL
    CONSTRAINT CK_usage_sessions_completion CHECK (
        (completed_by IS NULL AND actual_end_time IS NULL)
        OR (completed_by IS NOT NULL AND actual_end_time IS NOT NULL)
    ),
    -- Actual end time must be after actual start time when provided
    CONSTRAINT CK_usage_sessions_end_time CHECK (
        actual_end_time IS NULL OR actual_end_time > actual_start_time
    )
);

-- =============================================================================
-- 9. TABLE: maintenance_records
-- =============================================================================

CREATE TABLE maintenance_records (
    maintenance_id     INT            NOT NULL IDENTITY(1,1),
    space_id           INT            NOT NULL,
    reporter_id        INT            NOT NULL,
    assigned_staff_id  INT            NULL,
    problem_description NVARCHAR(MAX) NOT NULL,
    problem_category   NVARCHAR(50)   NULL,
    status             NVARCHAR(20)   NOT NULL DEFAULT 'Reported',
    start_time         DATETIME2      NOT NULL,
    completion_time    DATETIME2      NULL,
    result_note        NVARCHAR(MAX)  NULL,
    created_at         DATETIME2      NOT NULL DEFAULT GETDATE(),
    updated_at         DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_maintenance_records PRIMARY KEY (maintenance_id),
    CONSTRAINT FK_maintenance_records_space_id FOREIGN KEY (space_id)
        REFERENCES spaces(space_id),
    CONSTRAINT FK_maintenance_records_reporter_id FOREIGN KEY (reporter_id)
        REFERENCES user_accounts(user_id),
    CONSTRAINT FK_maintenance_records_assigned_staff_id FOREIGN KEY (assigned_staff_id)
        REFERENCES user_accounts(user_id),
    CONSTRAINT CK_maintenance_records_problem_category CHECK (
        problem_category IN ('BrokenProjector', 'ACFailure', 'DamagedFurniture',
                             'CleaningIssue', 'NetworkProblem', 'Other')
    ),
    CONSTRAINT CK_maintenance_records_status CHECK (
        status IN ('Reported', 'Assigned', 'InProgress', 'Completed', 'Cancelled')
    ),
    CONSTRAINT CK_maintenance_records_completion_time CHECK (
        completion_time IS NULL OR completion_time > start_time
    )
);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- user_accounts
CREATE INDEX IX_user_accounts_department_id ON user_accounts (department_id);

-- spaces
CREATE INDEX IX_spaces_current_status ON spaces (current_status);
CREATE INDEX IX_spaces_space_type ON spaces (space_type);

-- bookings
CREATE INDEX IX_bookings_requester_id ON bookings (requester_id);
CREATE INDEX IX_bookings_space_id ON bookings (space_id);
CREATE INDEX IX_bookings_status ON bookings (status);
CREATE INDEX IX_bookings_time_range ON bookings (requested_start_time, requested_end_time);
CREATE INDEX IX_bookings_requester_status ON bookings (requester_id, status);

-- booking_decisions
CREATE INDEX IX_booking_decisions_booking_id ON booking_decisions (booking_id);

-- usage_sessions
CREATE INDEX IX_usage_sessions_checked_in_by ON usage_sessions (checked_in_by);

-- maintenance_records
CREATE INDEX IX_maintenance_records_space_id ON maintenance_records (space_id);
CREATE INDEX IX_maintenance_records_status ON maintenance_records (status);

-- space_facilities (PK covers space_id; index for facility_id lookups)
CREATE INDEX IX_space_facilities_facility_id ON space_facilities (facility_id);

-- =============================================================================
-- TRIGGERS: Business Rule Enforcement
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TRIGGER: TR_bookings_PreventOverlapAndUnavailable
--
-- Enforces two critical business rules:
--   1. No overlapping approved bookings for the same space.
--   2. A space under maintenance, temporarily closed, or retired
--      cannot be booked.
--
-- Implemented as an INSTEAD OF trigger so that validation happens before
-- the row is written, and only valid modifications proceed.
-- ---------------------------------------------------------------------------

CREATE TRIGGER TR_bookings_PreventOverlapAndUnavailable
ON bookings
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @now DATETIME2 = GETDATE();

    -- Rule 1: Prevent overlapping approved bookings
    -- Two time ranges [s1, e1) and [s2, e2) overlap when s1 < e2 AND e1 > s2
    IF EXISTS (
        SELECT 1
        FROM bookings b
        INNER JOIN inserted i
            ON b.space_id = i.space_id
            AND b.booking_id <> i.booking_id
            AND b.status = 'Approved'
            AND b.requested_start_time < i.requested_end_time
            AND b.requested_end_time > i.requested_start_time
    )
    BEGIN
        THROW 50001, 'Overlapping approved booking exists for this space.', 1;
    END

    -- Rule 2: Prevent booking an unavailable space
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN spaces s ON i.space_id = s.space_id
        WHERE s.current_status IN ('UnderMaintenance', 'TemporarilyClosed', 'Retired')
    )
    BEGIN
        THROW 50002, 'Selected space is not available for booking.', 1;
    END

    -- Validation passed — perform the actual operation
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        -- UPDATE branch: apply changes, refresh updated_at
        UPDATE b
        SET
            requester_id           = i.requester_id,
            space_id               = i.space_id,
            requested_start_time   = i.requested_start_time,
            requested_end_time     = i.requested_end_time,
            purpose                = i.purpose,
            expected_participants  = i.expected_participants,
            booking_type           = i.booking_type,
            status                 = i.status,
            cancelled_at           = i.cancelled_at,
            cancel_reason          = i.cancel_reason,
            updated_at             = @now
        FROM bookings b
        INNER JOIN inserted i ON b.booking_id = i.booking_id;
    END
    ELSE
    BEGIN
        -- INSERT branch: identity PK auto-generates
        INSERT INTO bookings (
            requester_id, space_id, requested_start_time, requested_end_time,
            purpose, expected_participants, booking_type, status,
            cancelled_at, cancel_reason, created_at, updated_at
        )
        SELECT
            requester_id, space_id, requested_start_time, requested_end_time,
            purpose, expected_participants, booking_type, status,
            cancelled_at, cancel_reason, @now, @now
        FROM inserted;
    END
END;
GO

-- =============================================================================
-- CONSTRAINT SUMMARY (for professor/TA review)
-- =============================================================================
--
-- PRIMARY KEY constraints: 9 (one per table)
--   departments        → PK_departments                     (department_id)
--   user_accounts      → PK_user_accounts                   (user_id)
--   spaces             → PK_spaces                          (space_id)
--   facilities         → PK_facilities                      (facility_id)
--   space_facilities   → PK_space_facilities                (space_id, facility_id)
--   bookings           → PK_bookings                        (booking_id)
--   booking_decisions  → PK_booking_decisions               (decision_id)
--   usage_sessions     → PK_usage_sessions                  (session_id)
--   maintenance_records → PK_maintenance_records            (maintenance_id)
--
-- FOREIGN KEY constraints: 13 (one per relationship)
--   user_accounts.department_id           → departments.department_id
--   bookings.requester_id                 → user_accounts.user_id
--   bookings.space_id                     → spaces.space_id
--   booking_decisions.booking_id          → bookings.booking_id
--   booking_decisions.decided_by          → user_accounts.user_id
--   usage_sessions.booking_id             → bookings.booking_id
--   usage_sessions.checked_in_by          → user_accounts.user_id
--   usage_sessions.completed_by           → user_accounts.user_id
--   space_facilities.space_id             → spaces.space_id
--   space_facilities.facility_id          → facilities.facility_id
--   maintenance_records.space_id          → spaces.space_id
--   maintenance_records.reporter_id       → user_accounts.user_id
--   maintenance_records.assigned_staff_id → user_accounts.user_id
--
-- UNIQUE constraints: 4
--   user_accounts.email
--   spaces.space_code
--   facilities.facility_name
--   usage_sessions.booking_id             (enforces 1-to-0..1 with bookings)
--
-- CHECK constraints: 16
--   CK_user_accounts_role                  — role whitelist (6 values)
--   CK_user_accounts_account_status        — status whitelist (3 values)
--   CK_spaces_space_type                   — type whitelist (6 values)
--   CK_spaces_capacity                     — capacity > 0
--   CK_spaces_current_status               — status whitelist (5 values)
--   CK_space_facilities_quantity           — quantity >= 0
--   CK_bookings_time_range                 — end > start
--   CK_bookings_expected_participants      — participants > 0
--   CK_bookings_booking_type               — type whitelist (9 values)
--   CK_bookings_status                     — status whitelist (7 values)
--   CK_booking_decisions_decision          — decision values (2 values)
--   CK_booking_decisions_rejection_reason  — rejection reason required when rejected
--   CK_usage_sessions_completion           — paired null for check-out fields
--   CK_usage_sessions_end_time             — end > start when provided
--   CK_maintenance_records_problem_category — category whitelist (6 values)
--   CK_maintenance_records_status          — status whitelist (5 values)
--   CK_maintenance_records_completion_time — completion > start when provided
--
-- DEFAULT constraints: 7
--   user_accounts.account_status     = 'Active'
--   spaces.current_status            = 'Available'
--   space_facilities.quantity        = 1
--   bookings.status                  = 'Pending'
--   booking_decisions.decision_time  = GETDATE()
--   maintenance_records.status       = 'Reported'
--   created_at/updated_at on 4 tables = GETDATE()
--
-- INDEXES: 13 (all non-clustered, for lookup/filter performance)
--   IX_user_accounts_department_id
--   IX_spaces_current_status
--   IX_spaces_space_type
--   IX_bookings_requester_id
--   IX_bookings_space_id
--   IX_bookings_status
--   IX_bookings_time_range
--   IX_bookings_requester_status
--   IX_booking_decisions_booking_id
--   IX_usage_sessions_checked_in_by
--   IX_maintenance_records_space_id
--   IX_maintenance_records_status
--   IX_space_facilities_facility_id
--
-- TRIGGERS: 1
--   TR_bookings_PreventOverlapAndUnavailable
--     Enforces: (a) no overlapping approved bookings for same space,
--               (b) space is Available (not UnderMaintenance/Closed/Retired)
-- =============================================================================
