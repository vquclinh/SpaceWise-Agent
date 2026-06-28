-- =============================================================================
-- Campus Space Management System — Sample Data
-- Group G08 — Microsoft SQL Server
-- Phase 1, Step 6: Sample Data Preparation
-- =============================================================================
--
-- This script populates all 9 tables with realistic sample data covering:
--   - All entity types and roles
--   - All booking statuses (Pending, Approved, Rejected, Cancelled,
--     CheckedIn, Completed, NoShow)
--   - Overlapping booking scenario (Booking #12 vs #13)
--   - Spaces under maintenance (B2-201) and temporarily closed (C1-101)
--   - Completed, in-progress, and reported maintenance records
--   - Checked-in, completed, and no-show usage sessions
--
-- Run AFTER executing 05-db-definition-G08.sql on a fresh database.
-- =============================================================================

-- =============================================================================
-- 1. DEPARTMENTS
-- =============================================================================
INSERT INTO departments (department_name) VALUES
    (N'Computer Science'),
    (N'Business Administration'),
    (N'Mathematics & Statistics'),
    (N'Electrical Engineering'),
    (N'Foreign Languages');

-- =============================================================================
-- 2. USER ACCOUNTS
-- =============================================================================
INSERT INTO user_accounts (email, full_name, phone_number, role, account_status, department_id)
VALUES
    -- 1: Student in Computer Science
    (N'nguyen.van.a@university.edu.vn',  N'Nguyễn Văn A',   N'0901234567', N'Student',                N'Active',  1),
    -- 2: Student in Computer Science
    (N'tran.thi.b@university.edu.vn',     N'Trần Thị B',     N'0902345678', N'Student',                N'Active',  1),
    -- 3: Lecturer in Mathematics & Statistics
    (N'le.van.c@university.edu.vn',       N'Lê Văn C',       N'0903456789', N'Lecturer',               N'Active',  3),
    -- 4: Lecturer in Business Administration
    (N'pham.thi.d@university.edu.vn',     N'Phạm Thị D',     N'0904567890', N'Lecturer',               N'Active',  2),
    -- 5: Facility Staff in Computer Science
    (N'hoang.van.e@university.edu.vn',    N'Hoàng Văn E',    N'0905678901', N'FacilityStaff',          N'Active',  1),
    -- 6: Facility Manager in Computer Science
    (N'vu.thi.f@university.edu.vn',       N'Vũ Thị F',       N'0906789012', N'FacilityManager',        N'Active',  1),
    -- 7: Department Administrator in Business Administration
    (N'dang.van.g@university.edu.vn',     N'Đặng Văn G',     N'0907890123', N'DepartmentAdministrator', N'Active',  2),
    -- 8: Teaching Assistant in Computer Science
    (N'bui.thi.h@university.edu.vn',      N'Bùi Thị H',      N'0908901234', N'TeachingAssistant',       N'Active',  1);

-- =============================================================================
-- 3. SPACES
-- =============================================================================
INSERT INTO spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES
    (N'A1-101', N'Lecture Hall A',               N'Auditorium',         N'Building A', 1, N'101', 200, N'Available',        N'Lectures and large events only. No food or drinks.'),
    (N'A1-102', N'Computer Lab 1',               N'ComputerLaboratory', N'Building A', 1, N'102', 40,  N'Available',        N'Booking requires IT staff approval. No food or drinks.'),
    (N'A2-201', N'Meeting Room 201',             N'MeetingRoom',        N'Building A', 2, N'201', 20,  N'Available',        N'Standard meeting room. Maximum 4-hour booking.'),
    (N'B1-101', N'Physics Project Laboratory',   N'ProjectLaboratory',  N'Building B', 1, N'101', 30,  N'Available',        N'Authorized personnel only. Safety gear required.'),
    (N'B1-102', N'Classroom B102',               N'Classroom',          N'Building B', 1, N'102', 50,  N'Available',        N'Standard classroom booking policy applies.'),
    (N'B2-201', N'Student Collaboration Hub',    N'StudentWorkspace',   N'Building B', 2, N'201', 15,  N'UnderMaintenance', N'Currently under maintenance — not available.'),
    (N'C1-101', N'Seminar Room C',               N'MeetingRoom',        N'Building C', 1, N'101', 25,  N'TemporarilyClosed', N'Room closed for renovation until further notice.'),
    (N'C1-102', N'Grand Auditorium C',           N'Auditorium',         N'Building C', 1, N'102', 300, N'Available',        N'Large events only. Reservation required 7 days in advance.');

-- =============================================================================
-- 4. FACILITIES
-- =============================================================================
INSERT INTO facilities (facility_name, description) VALUES
    (N'Projector',       N'Full HD projector with HDMI and VGA input'),
    (N'Whiteboard',      N'Large whiteboard with markers and eraser'),
    (N'AirConditioner',  N'Ceiling-mounted air conditioning system'),
    (N'DesktopComputer', N'Dell OptiPlex desktop workstation with 24" monitor'),
    (N'WiFiRouter',      N'High-speed wireless internet router'),
    (N'SpeakerSystem',   N'Surround sound speaker system with microphone');

-- =============================================================================
-- 5. SPACE-FACILITY ASSIGNMENTS
-- =============================================================================
INSERT INTO space_facilities (space_id, facility_id, quantity, condition, note) VALUES
    -- A1-101: Lecture Hall A
    (1, 1, 1, N'Good',          N'HD projector installed'),
    (1, 2, 1, N'Good',          N'Large whiteboard at front'),
    (1, 6, 1, N'Good',          N'Speaker system with 4 microphones'),
    (1, 3, 2, N'Good',          N'Two AC units'),
    -- A1-102: Computer Lab 1
    (2, 1, 1, N'Good',          N'Projector at front'),
    (2, 4, 20, N'Fair',         N'20 workstations, some keyboards need replacement'),
    (2, 3, 2, N'Good',          N'Two AC units'),
    (2, 5, 1, N'Good',          N'WiFi 6 router'),
    -- A2-201: Meeting Room 201
    (3, 1, 1, N'Good',          N'Portable projector'),
    (3, 2, 1, N'Good',          N'Whiteboard on side wall'),
    (3, 5, 1, N'Good',          N'WiFi router in room'),
    -- B1-101: Physics Project Laboratory
    (4, 1, 1, N'Good',          N'Projector for demonstrations'),
    (4, 4, 5, N'Good',          N'5 data analysis workstations'),
    (4, 2, 1, N'Good',          N'Whiteboard with grid lines'),
    -- B1-102: Classroom B102
    (5, 1, 1, N'Good',          N'Standard projector'),
    (5, 2, 1, N'Good',          N'Large whiteboard'),
    (5, 3, 2, N'Good',          N'Two AC units'),
    -- B2-201: Student Collaboration Hub (under maintenance)
    (6, 2, 1, N'Damage reported', N'Whiteboard surface scratched'),
    (6, 5, 1, N'Not working',   N'WiFi router damaged — reason for maintenance'),
    -- C1-101: Seminar Room C (temporarily closed)
    (7, 1, 1, N'Removed for renovation', N'Projector removed during renovation'),
    (7, 2, 1, N'Removed for renovation', N'Whiteboard removed'),
    (7, 6, 1, N'Removed for renovation', N'Speaker system removed'),
    -- C1-102: Grand Auditorium C
    (8, 1, 2, N'Good',          N'Two projectors for wide stage'),
    (8, 6, 2, N'Good',          N'Main and backup speaker systems'),
    (8, 3, 4, N'Good',          N'Four AC units for large hall'),
    (8, 2, 1, N'Good',          N'Extra-large whiteboard');

-- =============================================================================
-- 6. BOOKINGS
-- =============================================================================
--
-- Booking status legend:  Pending | Approved | Rejected | Cancelled
--                         CheckedIn | Completed | NoShow
--
-- Dates reference: current date during data preparation is 2026-06-26.
-- Timestamps use DATEADD for readability.

INSERT INTO bookings (requester_id, space_id, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status, cancelled_at, cancel_reason)
VALUES
    -- 1: Student A → A1-101 (Auditorium) — Approved, past, completed session exists
    (1, 1,
     DATEADD(day, -11, DATEADD(hour, 8,  GETDATE())),   -- 2026-06-15 08:00
     DATEADD(day, -11, DATEADD(hour, 10, GETDATE())),   -- 2026-06-15 10:00
     N'Database lecture for second-year CS students covering normalization and indexing.',
     150, N'Lecture', N'Approved', NULL, NULL),

    -- 2: Student A → A1-102 (Computer Lab) — Approved, future
    (1, 2,
     DATEADD(day, 14, DATEADD(hour, 14, GETDATE())),    -- 2026-07-10 14:00
     DATEADD(day, 14, DATEADD(hour, 16, GETDATE())),    -- 2026-07-10 16:00
     N'Python programming workshop for beginners. Hands-on coding exercises.',
     35, N'Workshop', N'Approved', NULL, NULL),

    -- 3: Student B → A2-201 (Meeting Room) — Pending
    (2, 3,
     DATEADD(day, 9,  DATEADD(hour, 9,  GETDATE())),    -- 2026-07-05 09:00
     DATEADD(day, 9,  DATEADD(hour, 11, GETDATE())),    -- 2026-07-05 11:00
     N'Group study session for final exam preparation. Need whiteboard for problem solving.',
     8, N'Meeting', N'Pending', NULL, NULL),

    -- 4: Lecturer C → B1-101 (Physics Lab) — Approved, past, completed session exists
    (3, 4,
     DATEADD(day, -14, DATEADD(hour, 13, GETDATE())),   -- 2026-06-12 13:00
     DATEADD(day, -14, DATEADD(hour, 15, GETDATE())),   -- 2026-06-12 15:00
     N'Physics experiment on electromagnetism. Requires lab equipment and workstations.',
     25, N'ProjectWork', N'Approved', NULL, NULL),

    -- 5: Lecturer D → B1-102 (Classroom) — Rejected
    (4, 5,
     DATEADD(day, -6,  DATEADD(hour, 8,  GETDATE())),   -- 2026-06-20 08:00
     DATEADD(day, -6,  DATEADD(hour, 10, GETDATE())),   -- 2026-06-20 10:00
     N'Guest lecture by industry professional on business analytics trends.',
     40, N'Seminar', N'Rejected', NULL, NULL),

    -- 6: Student A → A2-201 (Meeting Room) — Cancelled
    (1, 3,
     DATEADD(day, -8,  DATEADD(hour, 10, GETDATE())),   -- 2026-06-18 10:00
     DATEADD(day, -8,  DATEADD(hour, 12, GETDATE())),   -- 2026-06-18 12:00
     N'Team meeting for group project on mobile app development.',
     5, N'Meeting', N'Cancelled',
     DATEADD(day, -9, DATEADD(hour, 16, GETDATE())),    -- cancelled 2026-06-17
     N'Team conflict — rescheduling to a later date.'),

    -- 7: TA H → A1-102 (Computer Lab) — Approved, past, NO-SHOW (no session)
    (8, 2,
     DATEADD(day, -12, DATEADD(hour, 9,  GETDATE())),   -- 2026-06-14 09:00
     DATEADD(day, -12, DATEADD(hour, 11, GETDATE())),   -- 2026-06-14 11:00
     N'Coding practice session for first-year students on basic algorithms.',
     20, N'StudentActivity', N'NoShow', NULL, NULL),

    -- 8: Student B → B1-102 (Classroom) — CheckedIn (ongoing today)
    (2, 5,
     DATEADD(day, 0,  DATEADD(hour, 8,  GETDATE())),    -- 2026-06-26 08:00
     DATEADD(day, 0,  DATEADD(hour, 10, GETDATE())),    -- 2026-06-26 10:00
     N'Mathematics revision class — advanced calculus review session.',
     30, N'Lecture', N'CheckedIn', NULL, NULL),

    -- 9: Lecturer C → C1-102 (Grand Auditorium C) — Approved, future
    (3, 8,
     DATEADD(day, 24, DATEADD(hour, 7,  GETDATE())),    -- 2026-07-20 07:00
     DATEADD(day, 24, DATEADD(hour, 9,  GETDATE())),    -- 2026-07-20 09:00
     N'Annual Computer Science conference — keynote speeches and paper presentations.',
     250, N'Seminar', N'Approved', NULL, NULL),

    -- 10: Student A → B1-101 (Physics Lab) — Pending
    (1, 4,
     DATEADD(day, 19, DATEADD(hour, 8,  GETDATE())),    -- 2026-07-15 08:00
     DATEADD(day, 19, DATEADD(hour, 10, GETDATE())),    -- 2026-07-15 10:00
     N'Research project meeting with advisor on quantum computing simulation.',
     8, N'ResearchActivity', N'Pending', NULL, NULL),

    -- 11: Student B → A1-101 (Auditorium) — Completed, past
    (2, 1,
     DATEADD(day, -16, DATEADD(hour, 9,  GETDATE())),   -- 2026-06-10 09:00
     DATEADD(day, -16, DATEADD(hour, 11, GETDATE())),   -- 2026-06-10 11:00
     N'End-of-year cultural event featuring student performances and exhibitions.',
     100, N'AdministrativeEvent', N'Completed', NULL, NULL),

    -- 12: Lecturer C → B1-102 (Classroom B102) — Approved, future
    --      This booking overlaps with Booking #13 to demonstrate the overlap scenario.
    (3, 5,
     DATEADD(day, 14, DATEADD(hour, 8,  GETDATE())),    -- 2026-07-10 08:00
     DATEADD(day, 14, DATEADD(hour, 10, GETDATE())),    -- 2026-07-10 10:00
     N'Advanced mathematics seminar on differential equations.',
     30, N'Seminar', N'Approved', NULL, NULL),

    -- 13: Student B → B1-102 (Classroom B102) — Pending (overlaps with #12)
    --      This booking cannot become Approved because it overlaps with the
    --      Approved Booking #12 for the same space (B1-102, 2026-07-10 08:00-10:00).
    --      Overlap: #13 is 09:00-11:00, #12 is 08:00-10:00 → overlap from 09:00-10:00.
    (2, 5,
     DATEADD(day, 14, DATEADD(hour, 9,  GETDATE())),    -- 2026-07-10 09:00
     DATEADD(day, 14, DATEADD(hour, 11, GETDATE())),    -- 2026-07-10 11:00
     N'Peer tutoring session for first-year calculus students.',
     15, N'StudentActivity', N'Pending', NULL, NULL);

-- =============================================================================
-- 7. BOOKING DECISIONS
-- =============================================================================
INSERT INTO booking_decisions (booking_id, decided_by, decision, decision_time, decision_note, rejection_reason)
VALUES
    -- Booking #1 (A1-101, Student A) → Approved by Facility Manager F
    (1, 6, N'Approved',
     DATEADD(day, -12, DATEADD(hour, 14, GETDATE())),   -- 2026-06-14 14:00
     N'Approved for academic lecture. Space is available.',
     NULL),

    -- Booking #4 (B1-101, Lecturer C) → Approved by Facility Manager F
    (4, 6, N'Approved',
     DATEADD(day, -15, DATEADD(hour, 10, GETDATE())),   -- 2026-06-11 10:00
     N'Approved. Lab equipment will be prepared.',
     NULL),

    -- Booking #5 (B1-102, Lecturer D) → Rejected by Facility Manager F
    (5, 6, N'Rejected',
     DATEADD(day, -7, DATEADD(hour, 9, GETDATE())),     -- 2026-06-19 09:00
     N'Cannot accommodate guest lecture at this time.',
     N'B1-102 is already reserved for departmental examination preparation on that date.'),

    -- Booking #7 (A1-102, TA H) → Approved by Facility Manager F
    (8, 6, N'Approved',
     DATEADD(day, -13, DATEADD(hour, 11, GETDATE())),   -- 2026-06-13 11:00
     N'Approved for student activity.',
     NULL),

    -- Booking #11 (A1-101, Student B) → Approved by Facility Manager F
    (11, 6, N'Approved',
     DATEADD(day, -17, DATEADD(hour, 15, GETDATE())),   -- 2026-06-09 15:00
     N'Approved for cultural event.',
     NULL);

-- =============================================================================
-- 8. USAGE SESSIONS
-- =============================================================================
INSERT INTO usage_sessions (booking_id, checked_in_by, actual_start_time, initial_condition, completed_by, actual_end_time, final_condition, usage_notes)
VALUES
    -- Session for Booking #1 (A1-101, Lecture Hall A — Student A)
    -- Checked in by Facility Staff E, completed by same staff
    (1, 5,
     DATEADD(day, -11, DATEADD(hour, 8,  GETDATE())),   -- check-in 2026-06-15 08:05
     N'Clean and tidy. All seats arranged. Projector and microphone working.',
     5,
     DATEADD(day, -11, DATEADD(hour, 10, GETDATE())),   -- check-out 2026-06-15 10:00
     N'Good condition. Whiteboard cleaned. No damages found.',
     N'Lecture ended on time. Students were orderly.'),

    -- Session for Booking #4 (B1-101, Physics Lab — Lecturer C)
    -- Checked in by Facility Staff E, completed by same staff
    (4, 5,
     DATEADD(day, -14, DATEADD(hour, 13, GETDATE())),   -- check-in 2026-06-12 13:00
     N'Lab equipment set up. Workstations operational. Safety gear available.',
     5,
     DATEADD(day, -14, DATEADD(hour, 15, GETDATE())),   -- check-out 2026-06-12 15:10
     N'Equipment returned. Workstations shut down properly. Minor spill on desk cleaned.',
     N'Experiment completed successfully. One workstation had slow performance.'),

    -- Session for Booking #8 (B1-102, Classroom — Student B, ongoing)
    -- Checked in but not yet completed (CheckedIn status)
    (8, 5,
     DATEADD(day, 0, DATEADD(hour, 8, GETDATE())),      -- check-in 2026-06-26 08:00
     N'Classroom clean and ready. Projector working. AC operational.',
     NULL, NULL, NULL, NULL),

    -- Session for Booking #11 (A1-101, Auditorium — Student B, completed)
    (11, 5,
     DATEADD(day, -16, DATEADD(hour, 9, GETDATE())),    -- check-in 2026-06-10 09:00
     N'Clean. Stage set up. Sound system tested and working.',
     5,
     DATEADD(day, -16, DATEADD(hour, 11, GETDATE())),   -- check-out 2026-06-10 11:00
     N'Venue tidy. Equipment returned. No issues reported.',
     N'Cultural event was well-organized. All 100 attendees accounted for.');

-- =============================================================================
-- 9. MAINTENANCE RECORDS
-- =============================================================================
INSERT INTO maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, problem_category, status, start_time, completion_time, result_note)
VALUES
    -- B2-201 (Student Collaboration Hub) — ongoing maintenance (InProgress)
    -- Reported by Facility Staff E, assigned to same staff
    (6, 5, 5,
     N'WiFi router is not functioning. Whiteboard surface has deep scratches affecting usability. Several power outlets are loose.',
     N'NetworkProblem',
     N'InProgress',
     DATEADD(day, -3, DATEADD(hour, 9, GETDATE())),     -- started 2026-06-23
     NULL,
     NULL),

    -- A1-101 (Lecture Hall A) — past completed maintenance
    (1, 7, 5,
     N'Projector bulb is dim and flickering. Replacement needed urgently for upcoming lectures.',
     N'BrokenProjector',
     N'Completed',
     DATEADD(day, -30, DATEADD(hour, 8, GETDATE())),    -- started 2026-05-27
     DATEADD(day, -28, DATEADD(hour, 14, GETDATE())),   -- completed 2026-05-29
     N'Projector bulb replaced. Image quality restored. Tested and working properly.'),

    -- B1-102 (Classroom B102) — newly reported, not yet assigned
    (5, 8, NULL,
     N'Three desk chairs have broken legs. Students reported instability during class.',
     N'DamagedFurniture',
     N'Reported',
     DATEADD(day, -1, DATEADD(hour, 15, GETDATE())),    -- started 2026-06-25
     NULL,
     NULL),

    -- B2-201 (Student Collaboration Hub) — past completed maintenance (AC issue)
    (6, 5, 5,
     N'Air conditioning unit in Student Collaboration Hub is not cooling. Temperature reached 35°C.',
     N'ACFailure',
     N'Completed',
     DATEADD(day, -60, DATEADD(hour, 10, GETDATE())),   -- started 2026-04-27
     DATEADD(day, -58, DATEADD(hour, 16, GETDATE())),   -- completed 2026-04-29
     N'AC compressor repaired and refrigerant refilled. Cooling restored to normal levels.'),

    -- C1-101 (Seminar Room C) — completed maintenance (network)
    (7, 5, 5,
     N'Intermittent network connectivity in Seminar Room C. WiFi drops every 10-15 minutes.',
     N'NetworkProblem',
     N'Completed',
     DATEADD(day, -45, DATEADD(hour, 8, GETDATE())),    -- started 2026-05-12
     DATEADD(day, -43, DATEADD(hour, 17, GETDATE())),   -- completed 2026-05-14
     N'Router firmware updated and access point repositioned. Network stability restored.');

-- =============================================================================
-- END OF SAMPLE DATA
-- =============================================================================
