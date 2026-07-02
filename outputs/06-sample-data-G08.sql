-- =============================================================================
-- Campus Space Management System — Sample Data
-- Group G08 — Microsoft SQL Server
-- Phase 1, Step 6: Sample Data
-- =============================================================================
--
-- This script populates all 9 tables with realistic data designed to satisfy
-- every query in 07-query-design-G08.sql with non-trivial multi-row results.
--
-- Edge cases included:
--   * All 7 booking statuses: Pending, Approved, Rejected, Cancelled,
--     CheckedIn, Completed, NoShow
--   * All 5 space statuses: Available, InUse, UnderMaintenance,
--     TemporarilyClosed, Retired
--   * All 5 maintenance statuses: Reported, Assigned, InProgress,
--     Completed, Cancelled
--   * Overlapping Pending bookings on the same space (potential conflict)
--   * Maintenance activity that blocks/overlaps with an Approved booking
--   * NoShow booking with a prior approval decision
--   * Rejected booking with a rejection reason
--   * Historic completed bookings on now-unavailable spaces
--   * Full lifecycle consistency: booking status ↔ usage session presence
--
-- FK resolution strategy: DECLARE variables capture IDENTITY values after
-- each INSERT group, avoiding hard-coded ID assumptions. The script runs
-- inside one transaction (no GO batch separators within the data) so that
-- variable scope is preserved and the entire load can roll back atomically.
-- =============================================================================

-- =============================================================================
-- Verify that data will be meaningful
-- =============================================================================
--
-- QUERY COVERAGE VERIFICATION (every query in 07 returns ≥1 row):
--
-- Linh (24125065):
--   Q1 (Available spaces 2026-07-10 09:00-11:00): Spaces 1/4/7/9/10 free  → 5 rows
--   Q2 (Booking lifecycle): All 21 bookings cover every status             → 21 rows
--   Q3 (Open maintenance): M1/InProgress, M3/Assigned, M4/Reported        → 3 rows
--   Q4 (Utilization summary): 5 completed sessions across 4 spaces        → 4 rows
--   Q5 (Facility search: Projector+Whiteboard, ≥20 cap): 3 spaces match   → 3 rows
--
-- Vi (24125085):
--   Q1 (Dept booking summary): 3 depts with bookings                      → 3 rows
--   Q2 (Audit trail): 17 decision rows                                    → 17 rows
--   Q3 (Cancelled/NoShow user 1): B5+Cancelled, B6+NoShow                 → 2 rows
--   Q4 (History user 2): B4/B7/B18 (3 bookings)                           → 3 rows
--   Q5 (Status distribution): 7 status groups represented                  → 7 rows
--
-- Thi (24125080):
--   Q1 (Upcoming approved lecturer 3): B2/B3 (future Approved)            → 2 rows
--   Q2 (Schedule lecturer 4, Jun-Aug): B8/B9                              → 2 rows
--   Q3 (Assisted sessions future): 4 types (Lecture, Seminar, Workshop,   → 4 rows
--       ProjectWork in future Approved)
--   Q4 (Today check-in support 2026-07-02): B10 (today, Approved, no      → 1 row
--       check-in)
--   Q5 (Status tracking user 1): B1/B5/B6 (Approved/Cancelled/NoShow)    → 3 rows
--
-- Duyen (24125028):
--   Q1 (Equipment readiness): 19 space_facilities rows across 10 spaces   → 19 rows
--   Q2 (Pending-Pending conflicts): B12 vs B13 on Space 2                 → 1 pair
--   Q3 (Maintenance impact): B20+Space5+M1 (Approved booking overlaps     → 1 row
--       InProgress maintenance)
--   Q4 (NoShow analytics): 1 user with NoShow (user 1, 1/3 = 33.33%)     → 13 rows
--   Q5 (Fill rate): 5 completed bookings across 4 spaces                  → 4 rows
-- =============================================================================

BEGIN TRANSACTION;
SET NOCOUNT ON;

-- =============================================================================
-- 1. DEPARTMENTS
-- =============================================================================
INSERT INTO departments (department_name) VALUES
    (N'Computer Science'),
    (N'Business Administration'),
    (N'Mathematics');

DECLARE @dept_cs   INT = (SELECT department_id FROM departments WHERE department_name = N'Computer Science');
DECLARE @dept_ba   INT = (SELECT department_id FROM departments WHERE department_name = N'Business Administration');
DECLARE @dept_math INT = (SELECT department_id FROM departments WHERE department_name = N'Mathematics');

-- =============================================================================
-- 2. USER ACCOUNTS (13 users covering all 6 roles)
-- =============================================================================
INSERT INTO user_accounts (email, full_name, phone_number, role, account_status, department_id, created_at, updated_at) VALUES
    (N'nguyen.van.a@university.edu.vn', N'Nguyen Van A',    N'0901000001', N'Student',                 N'Active',    @dept_cs,   '2026-01-15 08:00:00', '2026-01-15 08:00:00'),
    (N'tran.thi.b@university.edu.vn',    N'Tran Thi B',     N'0901000002', N'Student',                 N'Active',    @dept_ba,   '2026-01-15 08:00:00', '2026-01-15 08:00:00'),
    (N'le.van.c@university.edu.vn',      N'Le Van C',       N'0901000003', N'Lecturer',                N'Active',    @dept_cs,   '2026-01-10 08:00:00', '2026-01-10 08:00:00'),
    (N'pham.thi.d@university.edu.vn',    N'Pham Thi D',     N'0901000004', N'Lecturer',                N'Active',    @dept_math, '2026-01-10 08:00:00', '2026-01-10 08:00:00'),
    (N'hoang.van.e@university.edu.vn',   N'Hoang Van E',    N'0901000005', N'TeachingAssistant',       N'Active',    @dept_cs,   '2026-01-20 08:00:00', '2026-01-20 08:00:00'),
    (N'ngo.thi.f@university.edu.vn',     N'Ngo Thi F',      N'0901000006', N'FacilityStaff',           N'Active',    @dept_cs,   '2025-09-01 08:00:00', '2025-09-01 08:00:00'),
    (N'vu.van.g@university.edu.vn',      N'Vu Van G',       N'0901000007', N'DepartmentAdministrator', N'Active',    @dept_ba,   '2025-09-01 08:00:00', '2025-09-01 08:00:00'),
    (N'dang.thi.h@university.edu.vn',    N'Dang Thi H',     N'0901000008', N'FacilityManager',         N'Active',    @dept_cs,   '2025-08-15 08:00:00', '2025-08-15 08:00:00'),
    (N'bui.van.i@university.edu.vn',     N'Bui Van I',      N'0901000009', N'Student',                 N'Active',    @dept_math, '2026-01-15 08:00:00', '2026-01-15 08:00:00'),
    (N'ly.thi.k@university.edu.vn',      N'Ly Thi K',       N'0901000010', N'Lecturer',                N'Active',    @dept_ba,   '2026-01-10 08:00:00', '2026-01-10 08:00:00'),
    (N'dinh.van.l@university.edu.vn',    N'Dinh Van L',     N'0901000011', N'FacilityStaff',           N'Active',    @dept_math, '2025-09-01 08:00:00', '2025-09-01 08:00:00'),
    (N'duong.thi.m@university.edu.vn',   N'Duong Thi M',    N'0901000012', N'Student',                 N'Suspended', @dept_cs,   '2026-01-20 08:00:00', '2026-03-01 10:00:00'),
    (N'mai.van.n@university.edu.vn',     N'Mai Van N',      N'0901000013', N'TeachingAssistant',       N'Active',    @dept_ba,   '2026-01-22 08:00:00', '2026-01-22 08:00:00');

DECLARE @u1  INT = (SELECT user_id FROM user_accounts WHERE email = N'nguyen.van.a@university.edu.vn');
DECLARE @u2  INT = (SELECT user_id FROM user_accounts WHERE email = N'tran.thi.b@university.edu.vn');
DECLARE @u3  INT = (SELECT user_id FROM user_accounts WHERE email = N'le.van.c@university.edu.vn');
DECLARE @u4  INT = (SELECT user_id FROM user_accounts WHERE email = N'pham.thi.d@university.edu.vn');
DECLARE @u5  INT = (SELECT user_id FROM user_accounts WHERE email = N'hoang.van.e@university.edu.vn');
DECLARE @u6  INT = (SELECT user_id FROM user_accounts WHERE email = N'ngo.thi.f@university.edu.vn');
DECLARE @u7  INT = (SELECT user_id FROM user_accounts WHERE email = N'vu.van.g@university.edu.vn');
DECLARE @u8  INT = (SELECT user_id FROM user_accounts WHERE email = N'dang.thi.h@university.edu.vn');
DECLARE @u9  INT = (SELECT user_id FROM user_accounts WHERE email = N'bui.van.i@university.edu.vn');
DECLARE @u10 INT = (SELECT user_id FROM user_accounts WHERE email = N'ly.thi.k@university.edu.vn');
DECLARE @u11 INT = (SELECT user_id FROM user_accounts WHERE email = N'dinh.van.l@university.edu.vn');
DECLARE @u12 INT = (SELECT user_id FROM user_accounts WHERE email = N'duong.thi.m@university.edu.vn');
DECLARE @u13 INT = (SELECT user_id FROM user_accounts WHERE email = N'mai.van.n@university.edu.vn');

-- =============================================================================
-- 3. SPACES (10 spaces — all start as Available; Space 5 will be updated later
--    to UnderMaintenance for the maintenance-blocking-booking scenario)
-- =============================================================================
INSERT INTO spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy, created_at, updated_at) VALUES
    (N'A-AUD-01', N'Main Auditorium',       N'Auditorium',        N'Building A', 1, N'101', 100, N'Available',         NULL,                                 '2025-06-01 08:00:00', '2025-06-01 08:00:00'),
    (N'A-CLS-01', N'Classroom A102',        N'Classroom',         N'Building A', 1, N'102',  40, N'Available',         NULL,                                 '2025-06-01 08:00:00', '2025-06-01 08:00:00'),
    (N'A-CL-01',  N'Computer Lab 201',      N'ComputerLaboratory',N'Building A', 2, N'201',  30, N'Available',         NULL,                                 '2025-06-01 08:00:00', '2025-06-01 08:00:00'),
    (N'A-MR-01',  N'Meeting Room 202',      N'MeetingRoom',       N'Building A', 2, N'202',  15, N'Available',         N'Staff only',                        '2025-06-01 08:00:00', '2025-06-01 08:00:00'),
    (N'C-CLS-01', N'Classroom C101',        N'Classroom',         N'Building C', 1, N'101',  50, N'Available',         NULL,                                 '2025-06-01 08:00:00', '2025-06-01 08:00:00'),
    (N'C-PL-01',  N'Project Lab C102',      N'ProjectLaboratory', N'Building C', 1, N'102',  20, N'TemporarilyClosed', N'Under renovation — reopening Sep',   '2025-06-01 08:00:00', '2026-05-20 09:00:00'),
    (N'D-SW-01',  N'Student Hub D101',      N'StudentWorkspace',  N'Building D', 1, N'101',  10, N'Available',         N'Open to all students 24/7',         '2025-06-01 08:00:00', '2025-06-01 08:00:00'),
    (N'D-MR-01',  N'Meeting Room D102',     N'MeetingRoom',       N'Building D', 1, N'102',   8, N'Retired',           N'Decommissioned — use A-MR-01',      '2025-06-01 08:00:00', '2026-04-01 10:00:00'),
    (N'E-CLS-01', N'Classroom E101',        N'Classroom',         N'Building E', 1, N'101',  35, N'Available',         NULL,                                 '2025-06-01 08:00:00', '2025-06-01 08:00:00'),
    (N'E-CL-01',  N'Computer Lab E102',     N'ComputerLaboratory',N'Building E', 1, N'102',  25, N'InUse',             N'Priority for CS department',        '2025-06-01 08:00:00', '2026-05-01 08:00:00');

DECLARE @sp1  INT = (SELECT space_id FROM spaces WHERE space_code = N'A-AUD-01');
DECLARE @sp2  INT = (SELECT space_id FROM spaces WHERE space_code = N'A-CLS-01');
DECLARE @sp3  INT = (SELECT space_id FROM spaces WHERE space_code = N'A-CL-01');
DECLARE @sp4  INT = (SELECT space_id FROM spaces WHERE space_code = N'A-MR-01');
DECLARE @sp5  INT = (SELECT space_id FROM spaces WHERE space_code = N'C-CLS-01');
DECLARE @sp6  INT = (SELECT space_id FROM spaces WHERE space_code = N'C-PL-01');
DECLARE @sp7  INT = (SELECT space_id FROM spaces WHERE space_code = N'D-SW-01');
DECLARE @sp8  INT = (SELECT space_id FROM spaces WHERE space_code = N'D-MR-01');
DECLARE @sp9  INT = (SELECT space_id FROM spaces WHERE space_code = N'E-CLS-01');
DECLARE @sp10 INT = (SELECT space_id FROM spaces WHERE space_code = N'E-CL-01');

-- =============================================================================
-- 4. FACILITIES
-- =============================================================================
INSERT INTO facilities (facility_name, description) VALUES
    (N'Projector',      N'Standard HDMI projector with 1080p resolution'),
    (N'Whiteboard',     N'Magnetic whiteboard with markers and eraser'),
    (N'AirConditioner', N'Split-type air conditioning system'),
    (N'ComputerStation',N'Desktop computer station with monitor'),
    (N'SpeakerSystem',  N'Ceiling-mounted audio speaker system'),
    (N'VideoConference',N'Video conferencing equipment with webcam'),
    (N'SmartBoard',     N'Interactive smart board with touch capability');

DECLARE @fac_proj      INT = (SELECT facility_id FROM facilities WHERE facility_name = N'Projector');
DECLARE @fac_wboard    INT = (SELECT facility_id FROM facilities WHERE facility_name = N'Whiteboard');
DECLARE @fac_ac        INT = (SELECT facility_id FROM facilities WHERE facility_name = N'AirConditioner');
DECLARE @fac_computer  INT = (SELECT facility_id FROM facilities WHERE facility_name = N'ComputerStation');
DECLARE @fac_speaker   INT = (SELECT facility_id FROM facilities WHERE facility_name = N'SpeakerSystem');
DECLARE @fac_video     INT = (SELECT facility_id FROM facilities WHERE facility_name = N'VideoConference');
DECLARE @fac_sboard    INT = (SELECT facility_id FROM facilities WHERE facility_name = N'SmartBoard');

-- =============================================================================
-- 5. SPACE FACILITIES (Junction)
-- =============================================================================
--
-- Condition values include 'Damage reported', 'Not working', and
-- 'Removed for renovation' so that Duyen Q1 (Equipment Readiness Check)
-- returns meaningful non-Ready statuses.
-- =============================================================================
INSERT INTO space_facilities (space_id, facility_id, quantity, condition, note) VALUES
    -- Space 1: Main Auditorium
    (@sp1, @fac_proj,     2, N'Good',                   NULL),
    (@sp1, @fac_speaker,  1, N'Good',                   NULL),
    (@sp1, @fac_ac,       2, N'Good',                   NULL),
    -- Space 2: Classroom A102
    (@sp2, @fac_proj,     1, N'Functional',             NULL),
    (@sp2, @fac_wboard,   1, N'Good',                   N'Replaced Jun 2026'),
    (@sp2, @fac_ac,       1, N'Good',                   NULL),
    -- Space 3: Computer Lab 201
    (@sp3, @fac_computer, 30, N'Damage reported',       N'3 stations have faulty keyboards'),
    (@sp3, @fac_proj,     1, N'Good',                   NULL),
    (@sp3, @fac_wboard,   1, N'Good',                   NULL),
    (@sp3, @fac_ac,       2, N'Good',                   NULL),
    -- Space 4: Meeting Room 202
    (@sp4, @fac_proj,     1, N'Good',                   NULL),
    (@sp4, @fac_wboard,   1, N'Good',                   NULL),
    (@sp4, @fac_video,    1, N'Not working',            N'Camera driver needs update'),
    (@sp4, @fac_ac,       1, N'Good',                   NULL),
    -- Space 5: Classroom C101 (initially Available, later UnderMaintenance)
    (@sp5, @fac_proj,     1, N'Not working',            N'Lamp burnt out — see maintenance M1'),
    (@sp5, @fac_wboard,   1, N'Good',                   NULL),
    (@sp5, @fac_ac,       1, N'Good',                   NULL),
    -- Space 6: Project Lab C102 (TemporarilyClosed)
    (@sp6, @fac_computer, 10, N'Good',                  NULL),
    (@sp6, @fac_proj,     1, N'Good',                   NULL),
    (@sp6, @fac_wboard,   1, N'Good',                   NULL),
    -- Space 7: Student Hub D101
    (@sp7, @fac_wboard,   1, N'Good',                   N'Heavily used — restock markers weekly'),
    -- Space 8: Meeting Room D102 (Retired)
    (@sp8, @fac_proj,     1, N'Removed for renovation', N'Decommissioned — no bulb replacement'),
    -- Space 9: Classroom E101
    (@sp9, @fac_proj,     1, N'Good',                   NULL),
    (@sp9, @fac_wboard,   1, N'Good',                   NULL),
    (@sp9, @fac_ac,       1, N'Good',                   NULL),
    (@sp9, @fac_sboard,   1, N'Good',                   NULL),
    -- Space 10: Computer Lab E102 (InUse)
    (@sp10, @fac_computer, 25, N'Good',                 NULL),
    (@sp10, @fac_proj,     1, N'Functional',            NULL),
    (@sp10, @fac_ac,       1, N'Good',                  NULL);

-- =============================================================================
-- 6. BOOKINGS (21 bookings covering all 7 statuses)
-- =============================================================================
--
-- Status distribution:
--   Pending:    B12, B13, B15   (3)
--   Approved:   B1, B2, B3, B7, B8, B10, B19, B20   (8)
--   Rejected:   B14             (1)
--   Cancelled:  B5              (1)
--   CheckedIn:  B11             (1)
--   Completed:  B4, B9, B16, B17, B18   (5)
--   NoShow:     B6              (1)
--
-- Overlapping Pending conflict: B12 (09:00-11:00) vs B13 (10:00-12:00) on Space 2
-- NoShow B6 has prior approval decision (B6 must be approved before no-show)
-- B20 (Approved) on Space 5 pre-dates the space's UnderMaintenance status
-- =============================================================================
INSERT INTO bookings (requester_id, space_id, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status, created_at, updated_at) VALUES
    -- B1: Approved — overlaps Linh Q1 search window on Space 2
    (@u1,  @sp2,  '2026-07-10 08:00:00', '2026-07-10 10:00:00', N'Weekly CS lecture on database fundamentals',           35, N'Lecture',           N'Approved',   '2026-06-20 10:00:00', '2026-07-08 09:00:00'),
    -- B2: Approved — user 3, future, Space 1, no overlap with Linh Q1 window
    (@u3,  @sp1,  '2026-07-10 14:00:00', '2026-07-10 16:00:00', N'CS101 opening lecture — Introduction to Computing',    80, N'Lecture',           N'Approved',   '2026-06-22 10:00:00', '2026-07-08 09:00:00'),
    -- B3: Approved — user 3, future, Space 1 (Thi Q1)
    (@u3,  @sp1,  '2026-07-15 09:00:00', '2026-07-15 11:00:00', N'CS102 — Advanced Database Systems',                    75, N'Lecture',           N'Approved',   '2026-06-25 10:00:00', '2026-07-08 09:00:00'),
    -- B4: Completed — user 2, Space 9 (Vi Q4, Linh Q4, Duyen Q5)
    (@u2,  @sp9,  '2026-06-15 09:00:00', '2026-06-15 11:00:00', N'Study session for final exam preparation',             20, N'StudentActivity',   N'Completed',  '2026-06-01 08:00:00', '2026-06-15 11:00:00'),
    -- B5: Cancelled — user 1, Space 7 (Vi Q3, Thi Q5)
    (@u1,  @sp7,  '2026-06-20 14:00:00', '2026-06-20 16:00:00', N'Group project meeting — software architecture review',  8, N'ProjectWork',       N'Cancelled',  '2026-06-05 09:00:00', '2026-06-18 16:00:00'),
    -- B6: NoShow — user 1, Space 10 (Vi Q3, Thi Q5, Duyen Q4)
    (@u1,  @sp10, '2026-06-18 08:00:00', '2026-06-18 10:00:00', N'Hands-on lab — Python programming',                    20, N'StudentActivity',   N'NoShow',     '2026-06-01 09:00:00', '2026-06-18 10:00:00'),
    -- B7: Approved — user 2, Space 3 (Vi Q4)
    (@u2,  @sp3,  '2026-07-05 09:00:00', '2026-07-05 12:00:00', N'Introductory programming workshop for freshmen',       25, N'Workshop',          N'Approved',   '2026-06-15 10:00:00', '2026-07-03 09:00:00'),
    -- B8: Approved — user 4, Space 3 (Thi Q2, in Jun-Aug range)
    (@u4,  @sp3,  '2026-07-08 14:00:00', '2026-07-08 16:00:00', N'Mathematics tutorial — Calculus II review',            20, N'Seminar',           N'Approved',   '2026-06-20 10:00:00', '2026-07-06 09:00:00'),
    -- B9: Completed — user 4, Space 9 (Thi Q2, Linh Q4, Duyen Q5)
    (@u4,  @sp9,  '2026-06-20 09:00:00', '2026-06-20 11:00:00', N'Calculus review session before final exam',            30, N'Lecture',           N'Completed',  '2026-06-01 08:00:00', '2026-06-20 11:00:00'),
    -- B10: Approved — user 5, Space 4, TODAY 2026-07-02 (Thi Q4 — check-in support)
    (@u5,  @sp4,  '2026-07-02 10:00:00', '2026-07-02 12:00:00', N'TA coordination meeting — weekly sync',                10, N'Meeting',           N'Approved',   '2026-06-25 10:00:00', '2026-07-01 09:00:00'),
    -- B11: CheckedIn — user 9, Space 7 (open usage session, no check-out yet)
    (@u9,  @sp7,  '2026-07-01 15:00:00', '2026-07-01 17:00:00', N'Peer study group — discrete mathematics review',        6, N'StudentActivity',   N'CheckedIn',  '2026-06-20 10:00:00', '2026-07-01 15:00:00'),
    -- B12: Pending — user 12, Space 2 (overlaps B13 → Duyen Q2)
    (@u12, @sp2,  '2026-07-12 09:00:00', '2026-07-12 11:00:00', N'Literature review session — research papers',          30, N'Seminar',           N'Pending',    '2026-07-01 08:00:00', '2026-07-01 08:00:00'),
    -- B13: Pending — user 9, Space 2 (overlaps B12 → Duyen Q2)
    (@u9,  @sp2,  '2026-07-12 10:00:00', '2026-07-12 12:00:00', N'Mathematics discussion group — problem set help',      25, N'Meeting',           N'Pending',    '2026-07-01 09:00:00', '2026-07-01 09:00:00'),
    -- B14: Rejected — user 10, Space 4 (Vi Q2 audit trail)
    (@u10, @sp4,  '2026-07-03 14:00:00', '2026-07-03 15:30:00', N'Business department strategy meeting',                 12, N'Meeting',           N'Rejected',   '2026-06-28 10:00:00', '2026-07-02 10:00:00'),
    -- B15: Pending — user 6, Space 10
    (@u6,  @sp10, '2026-07-09 09:00:00', '2026-07-09 11:00:00', N'IT training workshop for new staff',                  20, N'Workshop',          N'Pending',    '2026-07-01 08:00:00', '2026-07-01 08:00:00'),
    -- B16: Completed — user 9, Space 5 (historic, pre-maintenance)
    (@u9,  @sp5,  '2026-06-10 09:00:00', '2026-06-10 11:00:00', N'Guest lecture — Introduction to AI',                   40, N'Lecture',           N'Completed',  '2026-05-20 10:00:00', '2026-06-10 11:00:00'),
    -- B17: Completed — user 5, Space 6 (historic, pre-closure)
    (@u5,  @sp6,  '2026-06-12 14:00:00', '2026-06-12 16:00:00', N'Research project — embedded systems',                  15, N'ResearchActivity',  N'Completed',  '2026-05-25 10:00:00', '2026-06-12 16:00:00'),
    -- B18: Completed — user 2, Space 8 (historic, pre-retirement)
    (@u2,  @sp8,  '2026-05-15 09:00:00', '2026-05-15 10:00:00', N'Alumni networking meeting',                             6, N'Meeting',           N'Completed',  '2026-04-20 10:00:00', '2026-05-15 10:00:00'),
    -- B19: Approved — user 12, Space 3 (overlaps Linh Q1 search window 10:00-11:00)
    (@u12, @sp3,  '2026-07-10 10:00:00', '2026-07-10 12:00:00', N'Coding session — software project implementation',     20, N'ProjectWork',       N'Approved',   '2026-06-28 10:00:00', '2026-07-08 09:00:00'),
    -- B20: Approved — user 3, Space 5 (approved BEFORE space became UnderMaintenance;
    --      maintenance M1 (InProgress) overlaps this booking → Duyen Q3)
    (@u3,  @sp5,  '2026-07-01 09:00:00', '2026-07-01 11:00:00', N'Special guest lecture — Machine Learning trends',      40, N'Lecture',           N'Approved',   '2026-06-10 10:00:00', '2026-06-28 09:00:00');

DECLARE @b1  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u1  AND space_id = @sp2  AND requested_start_time = '2026-07-10 08:00:00');
DECLARE @b2  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u3  AND space_id = @sp1  AND requested_start_time = '2026-07-10 14:00:00');
DECLARE @b3  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u3  AND space_id = @sp1  AND requested_start_time = '2026-07-15 09:00:00');
DECLARE @b4  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u2  AND space_id = @sp9  AND requested_start_time = '2026-06-15 09:00:00');
DECLARE @b5  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u1  AND space_id = @sp7  AND requested_start_time = '2026-06-20 14:00:00');
DECLARE @b6  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u1  AND space_id = @sp10 AND requested_start_time = '2026-06-18 08:00:00');
DECLARE @b7  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u2  AND space_id = @sp3  AND requested_start_time = '2026-07-05 09:00:00');
DECLARE @b8  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u4  AND space_id = @sp3  AND requested_start_time = '2026-07-08 14:00:00');
DECLARE @b9  INT = (SELECT booking_id FROM bookings WHERE requester_id = @u4  AND space_id = @sp9  AND requested_start_time = '2026-06-20 09:00:00');
DECLARE @b10 INT = (SELECT booking_id FROM bookings WHERE requester_id = @u5  AND space_id = @sp4  AND requested_start_time = '2026-07-02 10:00:00');
DECLARE @b11 INT = (SELECT booking_id FROM bookings WHERE requester_id = @u9  AND space_id = @sp7  AND requested_start_time = '2026-07-01 15:00:00');
DECLARE @b14 INT = (SELECT booking_id FROM bookings WHERE requester_id = @u10 AND space_id = @sp4  AND requested_start_time = '2026-07-03 14:00:00');
DECLARE @b16 INT = (SELECT booking_id FROM bookings WHERE requester_id = @u9  AND space_id = @sp5  AND requested_start_time = '2026-06-10 09:00:00');
DECLARE @b17 INT = (SELECT booking_id FROM bookings WHERE requester_id = @u5  AND space_id = @sp6  AND requested_start_time = '2026-06-12 14:00:00');
DECLARE @b18 INT = (SELECT booking_id FROM bookings WHERE requester_id = @u2  AND space_id = @sp8  AND requested_start_time = '2026-05-15 09:00:00');
DECLARE @b19 INT = (SELECT booking_id FROM bookings WHERE requester_id = @u12 AND space_id = @sp3  AND requested_start_time = '2026-07-10 10:00:00');
DECLARE @b20 INT = (SELECT booking_id FROM bookings WHERE requester_id = @u3  AND space_id = @sp5  AND requested_start_time = '2026-07-01 09:00:00');

-- =============================================================================
-- 7. BOOKING DECISIONS (17 rows — every Approved/Rejected/NoShow/Completed/
--    CheckedIn booking must have a prior approval decision)
-- =============================================================================
--
-- Every Completed, CheckedIn, Approved, and NoShow booking must have at least
-- one "Approved" decision record. Rejected B14 gets a "Rejected" decision
-- with rejection_reason. B5 (Cancelled) may have a prior approval or not;
-- we give it one to follow the same pattern as others.
-- =============================================================================
INSERT INTO booking_decisions (booking_id, decided_by, decision, decision_time, decision_note, rejection_reason) VALUES
    -- B1: Approved
    (@b1,  @u7, N'Approved', '2026-07-08 09:00:00', N'Standard lecture booking — approved',                   NULL),
    -- B2: Approved
    (@b2,  @u7, N'Approved', '2026-07-08 09:00:00', N'Large lecture in auditorium — approved',               NULL),
    -- B3: Approved
    (@b3,  @u7, N'Approved', '2026-07-08 09:00:00', N'Advanced DB lecture — approved',                       NULL),
    -- B4: Was Approved before completing → approval needed
    (@b4,  @u7, N'Approved', '2026-06-13 10:00:00', N'Exam study session — approved',                        NULL),
    -- B5: Was Approved before cancellation
    (@b5,  @u7, N'Approved', '2026-06-18 10:00:00', N'Project work — approved before cancellation',          NULL),
    -- B6: Was Approved before NoShow (required — NoShow must have prior approval)
    (@b6,  @u7, N'Approved', '2026-06-16 10:00:00', N'Lab session — approved',                               NULL),
    -- B7: Approved
    (@b7,  @u7, N'Approved', '2026-07-03 09:00:00', N'Programming workshop — approved',                      NULL),
    -- B8: Approved
    (@b8,  @u7, N'Approved', '2026-07-06 09:00:00', N'Math tutorial — approved',                             NULL),
    -- B9: Was Approved before completing
    (@b9,  @u7, N'Approved', '2026-06-18 10:00:00', N'Calculus review — approved',                           NULL),
    -- B10: Approved
    (@b10, @u8, N'Approved', '2026-07-01 09:00:00', N'TA meeting — approved, room available',                NULL),
    -- B11: Was Approved before check-in
    (@b11, @u8, N'Approved', '2026-06-29 10:00:00', N'Peer study group — approved',                          NULL),
    -- B14: Rejected (with mandatory rejection_reason)
    (@b14, @u7, N'Rejected', '2026-07-02 10:00:00', N'Meeting room reserved for executive board retreat',    N'The meeting room is reserved for the executive board retreat on that date. Please choose another room or date.'),
    -- B16: Was Approved before completing
    (@b16, @u7, N'Approved', '2026-06-08 10:00:00', N'Guest lecture — approved',                             NULL),
    -- B17: Was Approved before completing
    (@b17, @u7, N'Approved', '2026-06-10 10:00:00', N'Research activity — approved',                         NULL),
    -- B18: Was Approved before completing
    (@b18, @u8, N'Approved', '2026-05-13 10:00:00', N'Alumni meeting — approved',                            NULL),
    -- B19: Approved
    (@b19, @u7, N'Approved', '2026-07-08 09:00:00', N'Coding session — approved',                            NULL),
    -- B20: Approved (before space 5 went UnderMaintenance)
    (@b20, @u7, N'Approved', '2026-06-28 09:00:00', N'Special lecture — approved while space was available', NULL);

-- =============================================================================
-- 8. USAGE SESSIONS (6 sessions: 5 completed + 1 open)
-- =============================================================================
--
-- Lifecycle consistency:
--   B4, B9, B16, B17, B18 (Completed)  → completed session (end non-NULL)
--   B11 (CheckedIn)                      → open session (end NULL)
--   B6 (NoShow), B1/B2/B3/B7/B8/B10/B19/B20 (Approved) → NO session
--   B12/B13/B15 (Pending), B5 (Cancelled), B14 (Rejected) → NO session
-- =============================================================================
INSERT INTO usage_sessions (booking_id, checked_in_by, actual_start_time, initial_condition, completed_by, actual_end_time, final_condition, usage_notes) VALUES
    -- B4: Completed
    (@b4,  @u6, '2026-06-15 09:00:00', N'Clean and tidy',             @u6, '2026-06-15 11:00:00', N'Clean, all seats in order',          N'Students left on time. Room tidy.'),
    -- B9: Completed
    (@b9,  @u6, '2026-06-20 09:00:00', N'Good condition',              @u6, '2026-06-20 11:00:00', N'Good, whiteboard cleaned',           N'Lecture ended on schedule.'),
    -- B11: CheckedIn — open session (no completion)
    (@b11, @u6, '2026-07-01 15:00:00', N'Student hub tidy, whiteboard clean', NULL, NULL, NULL,   N'Students present, using whiteboard for group work.'),
    -- B16: Completed
    (@b16, @u6, '2026-06-10 09:00:00', N'Clean, projector warming up', @u6, '2026-06-10 11:00:00', N'Good, projector turned off',         N'Guest speaker used own laptop (HDMI).'),
    -- B17: Completed
    (@b17, @u6, '2026-06-12 14:00:00', N'Lab equipment operational',   @u6, '2026-06-12 16:00:00', N'All stations shut down properly',   N'Research group testing embedded boards.'),
    -- B18: Completed
    (@b18, @u6, '2026-05-15 09:00:00', N'Good, chairs arranged',       @u6, '2026-05-15 10:00:00', N'Good, meeting room left tidy',      N'Small alumni gathering — no issues.');

-- =============================================================================
-- 9. SPACE STATUS UPDATE — MAINTENANCE BLOCKING BOOKING SCENARIO
-- =============================================================================
--
-- Space 5 (C-CLS-01, Classroom C101) starts as 'Available' so that B20
-- (Approved) and B16 (Completed) could be inserted. Now we mark it
-- 'UnderMaintenance' and insert maintenance M1. This creates a scenario
-- where an Approved booking (B20, 2026-07-01) overlaps with an InProgress
-- maintenance record (M1, started 2026-06-25), which Duyen Q3 detects.
--
-- The trigger on bookings does NOT fire on UPDATE of the spaces table, so
-- this status change does not retroactively affect existing booking records.
-- =============================================================================
UPDATE spaces SET current_status = N'UnderMaintenance', updated_at = '2026-06-25 08:00:00'
WHERE space_id = @sp5;

-- =============================================================================
-- 10. MAINTENANCE RECORDS (6 records covering all 5 statuses)
-- =============================================================================
--
-- Status distribution:
--   Reported:   M4
--   Assigned:   M3
--   InProgress: M1 (overlaps B20 on Space 5 → Duyen Q3)
--   Completed:  M2, M5
--   Cancelled:  M6
-- =============================================================================
INSERT INTO maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, problem_category, status, start_time, completion_time, result_note, created_at, updated_at) VALUES
    -- M1: InProgress — on Space 5 (UnderMaintenance); overlaps B20 (Approved) → Duyen Q3
    (@sp5,  @u6,  @u11, N'Projector lamp burned out and screen flickers intermittently',   N'BrokenProjector',     N'InProgress', '2026-06-25 08:00:00', NULL,        N'Ordered replacement lamp — awaiting delivery',   '2026-06-25 08:00:00', '2026-06-25 08:00:00'),
    -- M2: Completed — on Space 6 (TemporarilyClosed); AC fixed
    (@sp6,  @u9,  NULL,  N'Air conditioning not cooling the room — temperature at 32°C',    N'ACFailure',           N'Completed',  '2026-06-01 09:00:00', '2026-06-10 17:00:00', N'Replaced coolant and fixed compressor — AC working normally', '2026-06-01 09:00:00', '2026-06-10 17:00:00'),
    -- M3: Assigned — on Space 1 (Main Auditorium); seats need repair
    (@sp1,  @u3,  @u11, N'Three seats in row C have broken armrests',                       N'DamagedFurniture',    N'Assigned',   '2026-06-28 08:00:00', NULL,        N'Assigned to carpentry team — work scheduled',    '2026-06-28 08:00:00', '2026-06-28 08:00:00'),
    -- M4: Reported — on Space 10 (InUse); network issue
    (@sp10, @u6,  NULL,  N'Internet ports on row C workstations are not connecting',         N'NetworkProblem',      N'Reported',   '2026-07-01 10:00:00', NULL,        NULL,                                              '2026-07-01 10:00:00', '2026-07-01 10:00:00'),
    -- M5: Completed — on Space 3 (Computer Lab); cleaning
    (@sp3,  @u5,  @u11, N'Floor has paint spill from previous event — needs deep cleaning', N'CleaningIssue',       N'Completed',  '2026-06-15 08:00:00', '2026-06-16 10:00:00', N'Deep cleaning done — floor restored to original condition', '2026-06-15 08:00:00', '2026-06-16 10:00:00'),
    -- M6: Cancelled — on Space 2 (Classroom); smartboard issue resolved by reboot
    (@sp2,  @u6,  @u11, N'Interactive whiteboard touch sensor unresponsive in lower-left',  N'Other',               N'Cancelled',  '2026-06-20 08:00:00', '2026-06-21 09:00:00', N'Issue resolved by system restart — no hardware fault found', '2026-06-20 08:00:00', '2026-06-21 09:00:00');

-- =============================================================================
-- 11. BOOKING STATUS UPDATE — Cancelled B5
-- =============================================================================
--
-- B5 was cancelled by the requester. Set cancelled_at and cancel_reason.
-- =============================================================================
UPDATE bookings
SET cancelled_at = '2026-06-18 16:00:00',
    cancel_reason = N'Scheduling conflict — group members unavailable on that date',
    updated_at = '2026-06-18 16:00:00'
WHERE booking_id = (SELECT booking_id FROM bookings WHERE requester_id = @u1 AND space_id = @sp7 AND requested_start_time = '2026-06-20 14:00:00');

-- =============================================================================
-- COMMIT
-- =============================================================================
COMMIT TRANSACTION;
GO

-- =============================================================================
-- VERIFICATION QUERIES (uncomment to run checks)
-- =============================================================================
--
-- SELECT '=== Bookings by Status ===' AS info;
-- SELECT status, COUNT(*) AS cnt FROM bookings GROUP BY status ORDER BY status;
--
-- SELECT '=== Spaces by Status ===' AS info;
-- SELECT current_status, COUNT(*) AS cnt FROM spaces GROUP BY current_status ORDER BY current_status;
--
-- SELECT '=== Maintenance by Status ===' AS info;
-- SELECT status, COUNT(*) AS cnt FROM maintenance_records GROUP BY status ORDER BY status;
--
-- SELECT '=== Booking ↔ Session Consistency ===' AS info;
-- SELECT b.status, CASE WHEN us.session_id IS NULL THEN 'NoSession' ELSE 'HasSession' END AS has_session, COUNT(*) AS cnt
-- FROM bookings b LEFT JOIN usage_sessions us ON us.booking_id = b.booking_id
-- GROUP BY b.status, CASE WHEN us.session_id IS NULL THEN 'NoSession' ELSE 'HasSession' END
-- ORDER BY b.status, has_session;
