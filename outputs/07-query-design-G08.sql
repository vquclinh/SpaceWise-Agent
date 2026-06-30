-- =====================================================================
-- Task 07 Query Design — Group G08
-- =====================================================================

-- =====================================================================
-- BEGIN MEMBER SECTION: 24125065
-- Member: Võ Quốc Linh (24125065)
-- Target user perspective: Facility Staff, Facility Manager
-- Query type plan (resolved target user(s) per type):
--   1. [Facility Staff, Facility Manager] space availability
--   2. [Facility Staff] booking lifecycle
--   3. [Facility Staff] maintenance monitoring
--   4. [Facility Manager] utilization summary
--   5. [Facility Staff, Facility Manager] facility-based search
-- =====================================================================

-- Query 1: Available Spaces for a Requested Time Slot
-- Query type: space availability
-- Business question: Which spaces are not under maintenance, closed, or retired, and have no overlapping approved bookings for a given time window?
-- Target user(s): Facility Staff, Facility Manager
-- Why this query is useful: Enables quick lookup of bookable spaces for any requested time slot without manually checking each room.
DECLARE @search_start DATETIME2 = '2026-07-10 09:00:00';
DECLARE @search_end   DATETIME2 = '2026-07-10 11:00:00';

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status
FROM spaces s
WHERE s.current_status NOT IN ('UnderMaintenance', 'TemporarilyClosed', 'Retired')
  AND NOT EXISTS (
      SELECT 1
      FROM bookings b
      WHERE b.space_id = s.space_id
        AND b.status = 'Approved'
        AND b.requested_start_time < @search_end
        AND b.requested_end_time   > @search_start
  )
ORDER BY s.building, s.room_number;
GO

-- Query 2: Booking Lifecycle Overview
-- Query type: booking lifecycle
-- Business question: What is the current state of every booking, including pending approvals, active sessions, decision history, and check-in/check-out records?
-- Target user(s): Facility Staff
-- Why this query is useful: Provides a single dashboard so staff can see which bookings need approval, which need check-out, and which require follow-up.
SELECT
    b.booking_id,
    u.full_name                                                       AS requester_name,
    u.role                                                            AS requester_role,
    s.space_code,
    b.requested_start_time,
    b.requested_end_time,
    b.status,
    bd.decision,
    bd.decision_time,
    bd.rejection_reason,
    us.actual_start_time,
    us.actual_end_time,
    us.checked_in_by,
    us.completed_by,
    CASE
        WHEN b.status = 'Pending'   THEN 'Needs approval decision'
        WHEN b.status = 'Approved'  THEN 'Waiting for check-in'
        WHEN b.status = 'CheckedIn' THEN 'In progress - needs check-out'
        WHEN b.status = 'Completed' THEN 'Session finished'
        WHEN b.status = 'Cancelled' THEN 'Cancelled by requester'
        WHEN b.status = 'Rejected'  THEN 'Rejected - see reason'
        WHEN b.status = 'NoShow'    THEN 'No show - follow up'
        ELSE b.status
    END                                                               AS staff_action
FROM bookings b
INNER JOIN user_accounts u   ON u.user_id = b.requester_id
INNER JOIN spaces s          ON s.space_id = b.space_id
LEFT JOIN booking_decisions bd ON bd.booking_id = b.booking_id
LEFT JOIN usage_sessions us    ON us.booking_id = b.booking_id
ORDER BY
    CASE b.status
        WHEN 'Pending'   THEN 1
        WHEN 'CheckedIn' THEN 2
        WHEN 'Approved'  THEN 3
        WHEN 'NoShow'    THEN 4
        ELSE 5
    END,
    b.requested_start_time;
GO

-- Query 3: Open Maintenance Records Requiring Action
-- Query type: maintenance monitoring
-- Business question: Which maintenance records are still open (Reported, Assigned, InProgress) and how many days have they been unresolved?
-- Target user(s): Facility Staff
-- Why this query is useful: Helps staff prioritise unresolved maintenance issues by their age, avoiding prolonged downtime of spaces.
DECLARE @open_statuses TABLE (status_name NVARCHAR(20));
INSERT INTO @open_statuses VALUES (N'Reported'), (N'Assigned'), (N'InProgress');

SELECT
    mr.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    u_reporter.full_name          AS reported_by,
    u_assigned.full_name          AS assigned_to,
    mr.problem_description,
    mr.problem_category,
    mr.status,
    mr.start_time,
    DATEDIFF(day, mr.start_time, GETDATE()) AS days_open
FROM maintenance_records mr
INNER JOIN spaces s              ON s.space_id = mr.space_id
INNER JOIN user_accounts u_reporter ON u_reporter.user_id = mr.reporter_id
LEFT JOIN user_accounts u_assigned   ON u_assigned.user_id = mr.assigned_staff_id
INNER JOIN @open_statuses os     ON os.status_name = mr.status
ORDER BY mr.start_time;
GO

-- Query 4: Space Utilization Summary from Completed Sessions
-- Query type: utilization summary
-- Business question: How many completed usage sessions has each space hosted, what is the total usage time, and what is the average session duration?
-- Target user(s): Facility Manager
-- Why this query is useful: Enables evidence-based decisions about space allocation, underutilised spaces, and capacity planning.
SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.capacity,
    COUNT(us.session_id)                                           AS completed_sessions,
    SUM(DATEDIFF(MINUTE, us.actual_start_time, us.actual_end_time))
        / 60.0                                                     AS total_usage_hours,
    AVG(DATEDIFF(MINUTE, us.actual_start_time, us.actual_end_time) * 1.0)
        / 60.0                                                     AS avg_duration_hours
FROM usage_sessions us
INNER JOIN bookings b ON b.booking_id = us.booking_id
INNER JOIN spaces s   ON s.space_id = b.space_id
WHERE us.actual_end_time IS NOT NULL
GROUP BY s.space_code, s.space_name, s.space_type, s.building, s.capacity
ORDER BY total_usage_hours DESC;
GO

-- Query 5: Facility-Based Space Search
-- Query type: facility-based search
-- Business question: Which available spaces have both a Projector and a Whiteboard and can accommodate at least the desired number of participants?
-- Target user(s): Facility Staff, Facility Manager
-- Why this query is useful: Lets users find spaces meeting combined facility and capacity requirements without inspecting each room individually.
DECLARE @min_capacity INT = 20;
DECLARE @required_facilities TABLE (facility_name NVARCHAR(100));
INSERT INTO @required_facilities VALUES (N'Projector'), (N'Whiteboard');

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status,
    COUNT(DISTINCT sf.facility_id) AS matching_facilities
FROM spaces s
INNER JOIN space_facilities sf ON sf.space_id = s.space_id
INNER JOIN facilities f         ON f.facility_id = sf.facility_id
INNER JOIN @required_facilities rf ON rf.facility_name = f.facility_name
WHERE s.capacity >= @min_capacity
  AND s.current_status NOT IN ('UnderMaintenance', 'TemporarilyClosed', 'Retired')
GROUP BY s.space_code, s.space_name, s.space_type, s.building, s.floor, s.room_number, s.capacity, s.current_status
HAVING COUNT(DISTINCT sf.facility_id) = (SELECT COUNT(*) FROM @required_facilities)
ORDER BY s.building, s.room_number;
GO

-- =====================================================================
-- END MEMBER SECTION: 24125065
-- =====================================================================

-- =====================================================================
-- BEGIN MEMBER SECTION: 24125085
-- Member: Lê Quốc Vĩ (24125085)
-- Target user perspective: Department Administrator, Student, Facility Manager
-- Query type plan (resolved target user(s) per type):
--   1. [Department Administrator] department booking summary
--   2. [Department Administrator] approval/rejection audit trail
--   3. [Student] cancelled/no-show bookings
--   4. [Student] personal booking history
--   5. [Facility Manager] booking status distribution
-- =====================================================================

-- Query 1: Department Booking Summary
-- Query type: department booking summary
-- Business question: How many bookings does each department have, broken down by status and total expected participants?
-- Target user(s): Department Administrator
-- Why this query is useful: Enables department-level oversight of booking activity and workload across the university.
SELECT
    d.department_id,
    d.department_name,
    COUNT(b.booking_id)                                                    AS total_bookings,
    SUM(CASE WHEN b.status = 'Pending'   THEN 1 ELSE 0 END)               AS pending_count,
    SUM(CASE WHEN b.status = 'Approved'  THEN 1 ELSE 0 END)               AS approved_count,
    SUM(CASE WHEN b.status = 'Completed' THEN 1 ELSE 0 END)               AS completed_count,
    SUM(CASE WHEN b.status = 'Rejected'  THEN 1 ELSE 0 END)               AS rejected_count,
    SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END)               AS cancelled_count,
    SUM(CASE WHEN b.status = 'NoShow'    THEN 1 ELSE 0 END)               AS noshow_count,
    SUM(b.expected_participants)                                           AS total_participants
FROM departments d
INNER JOIN user_accounts u ON u.department_id = d.department_id
INNER JOIN bookings b      ON b.requester_id = u.user_id
GROUP BY d.department_id, d.department_name
ORDER BY d.department_name;
GO

-- Query 2: Approval / Rejection Audit Trail
-- Query type: approval/rejection audit trail
-- Business question: Who decided what on each booking, when was the decision made, and what was the reason (including rejection reason)?
-- Target user(s): Department Administrator
-- Why this query is useful: Provides a traceable, chronological audit trail of every approval and rejection for accountability and review.
SELECT
    b.booking_id,
    u_req.full_name                                                        AS requester_name,
    u_req.department_id,
    s.space_code,
    s.space_name,
    b.requested_start_time,
    b.requested_end_time,
    bd.decision,
    bd.decision_time,
    bd.decision_note,
    bd.rejection_reason,
    u_dec.full_name                                                        AS decided_by_name,
    u_dec.role                                                             AS decider_role
FROM booking_decisions bd
INNER JOIN bookings b       ON b.booking_id = bd.booking_id
INNER JOIN user_accounts u_req ON u_req.user_id = b.requester_id
INNER JOIN user_accounts u_dec ON u_dec.user_id = bd.decided_by
INNER JOIN spaces s         ON s.space_id = b.space_id
ORDER BY bd.decision_time DESC;
GO

-- Query 3: Cancelled and No-Show Bookings for a Student
-- Query type: cancelled/no-show bookings
-- Business question: Which bookings did this student cancel or fail to show up for, and what reasons were provided?
-- Target user(s): Student
-- Why this query is useful: Helps students track their own booking compliance and identify recurring cancellation patterns.
DECLARE @student_id_3 INT = 1;

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    b.requested_start_time,
    b.requested_end_time,
    b.status,
    b.cancelled_at,
    b.cancel_reason,
    b.booking_type,
    b.purpose
FROM bookings b
INNER JOIN spaces s ON s.space_id = b.space_id
WHERE b.requester_id = @student_id_3
  AND b.status IN ('Cancelled', 'NoShow')
ORDER BY b.requested_start_time DESC;
GO

-- Query 4: Personal Booking History for a Student
-- Query type: personal booking history
-- Business question: What is the complete booking timeline for this student, including status, purpose, and scheduling details?
-- Target user(s): Student
-- Why this query is useful: Gives students a full chronological view of their past and upcoming bookings for personal planning.
DECLARE @student_id_4 INT = 2;

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    b.requested_start_time,
    b.requested_end_time,
    b.status,
    b.booking_type,
    b.purpose,
    b.expected_participants,
    b.created_at,
    DATEDIFF(day, b.created_at, b.requested_start_time)                    AS days_advance_booked
FROM bookings b
INNER JOIN spaces s ON s.space_id = b.space_id
WHERE b.requester_id = @student_id_4
ORDER BY b.requested_start_time DESC;
GO

-- Query 5: Booking Status Distribution
-- Query type: booking status distribution
-- Business question: What is the overall breakdown of bookings by status, and what percentage does each status represent?
-- Target user(s): Facility Manager
-- Why this query is useful: Provides a high-level health check of the booking system — highlights bottlenecks, no-shows, and cancellation trends.
SELECT
    b.status,
    COUNT(*)                                         AS booking_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()         AS percentage
FROM bookings b
GROUP BY b.status
ORDER BY booking_count DESC;
GO

-- =====================================================================
-- END MEMBER SECTION: 24125085
-- =====================================================================

-- =====================================================================
-- BEGIN MEMBER SECTION: 24125080
-- Member: Huỳnh Lê Bảo Thi (24125080)
-- Target user perspective: Lecturer, Teaching Assistant, Student
-- Query type plan (resolved target user(s) per type):
--   1. [Lecturer] upcoming approved bookings
--   2. [Lecturer] schedule by date range
--   3. [Teaching Assistant] assisted session schedule
--   4. [Teaching Assistant] check-in support list
--   5. [Student] booking status tracking
-- =====================================================================

-- Query 1: Upcoming Approved Bookings for a Lecturer
-- Query type: upcoming approved bookings
-- Business question: What future approved bookings does a specific lecturer have, with space and scheduling details?
-- Target user(s): Lecturer
-- Why this query is useful: Gives lecturers a clear view of their confirmed upcoming sessions for planning and preparation.
DECLARE @lecturer_id INT = 3;

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    b.requested_start_time,
    b.requested_end_time,
    b.booking_type,
    b.purpose,
    b.expected_participants
FROM bookings b
INNER JOIN spaces s ON s.space_id = b.space_id
WHERE b.requester_id = @lecturer_id
  AND b.status = 'Approved'
  AND b.requested_start_time > GETDATE()
ORDER BY b.requested_start_time;
GO

-- Query 2: Lecturer Schedule by Date Range
-- Query type: schedule by date range
-- Business question: What is a lecturer's complete booking schedule within a specific date range, across all booking statuses?
-- Target user(s): Lecturer
-- Why this query is useful: Enables lecturers to review all their bookings within a semester window for planning across a term.
DECLARE @lecturer_id_2 INT = 4;
DECLARE @start_date DATETIME2 = '2026-06-01 00:00:00';
DECLARE @end_date   DATETIME2 = '2026-08-31 00:00:00';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    b.requested_start_time,
    b.requested_end_time,
    b.status,
    b.booking_type,
    b.purpose
FROM bookings b
INNER JOIN spaces s ON s.space_id = b.space_id
WHERE b.requester_id = @lecturer_id_2
  AND b.requested_start_time >= @start_date
  AND b.requested_start_time  < @end_date
ORDER BY b.requested_start_time;
GO

-- Query 3: Upcoming Assisted Session Schedule Summary
-- Query type: assisted session schedule
-- Business question: How many upcoming approved sessions of each booking type are available for TA assistance, grouped by type with participant totals and date ranges?
-- Target user(s): Teaching Assistant
-- Why this query is useful: Helps TAs identify which upcoming sessions need assistance and prioritise workload by session type.
SELECT
    b.booking_type,
    COUNT(*)                                           AS session_count,
    SUM(b.expected_participants)                       AS total_participants,
    MIN(b.requested_start_time)                        AS earliest_session,
    MAX(b.requested_start_time)                        AS latest_session
FROM bookings b
INNER JOIN spaces s ON s.space_id = b.space_id
WHERE b.status = 'Approved'
  AND b.requested_start_time > GETDATE()
  AND b.booking_type IN ('Lecture', 'Seminar', 'Workshop', 'ProjectWork')
GROUP BY b.booking_type
ORDER BY b.booking_type;
GO

-- Query 4: Today's Check-In Support Candidates
-- Query type: check-in support list
-- Business question: Which approved bookings scheduled for today have not yet been checked in and need someone to start the session?
-- Target user(s): Teaching Assistant
-- Why this query is useful: Lists today's sessions requiring check-in support so TAs can assist staff. May return zero rows when all today's approved bookings are already checked in.
SELECT
    b.booking_id,
    u.full_name                                        AS requester_name,
    u.role                                             AS requester_role,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    b.requested_start_time,
    b.requested_end_time,
    b.booking_type,
    b.expected_participants
FROM bookings b
INNER JOIN user_accounts u ON u.user_id = b.requester_id
INNER JOIN spaces s        ON s.space_id = b.space_id
WHERE b.status = 'Approved'
  AND CAST(b.requested_start_time AS DATE) = CAST(GETDATE() AS DATE)
  AND NOT EXISTS (
      SELECT 1
      FROM usage_sessions us
      WHERE us.booking_id = b.booking_id
  )
ORDER BY b.requested_start_time;
GO

-- Query 5: Booking Status Tracking for a Student
-- Query type: booking status tracking
-- Business question: What is the current status and decision history of bookings made by a specific student?
-- Target user(s): Student
-- Why this query is useful: Enables students to track their booking compliance, understand outcomes, and identify follow-up actions needed.
DECLARE @student_id INT = 1;

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    b.requested_start_time,
    b.requested_end_time,
    b.status,
    b.booking_type,
    bd.decision,
    bd.rejection_reason,
    CASE
        WHEN b.status = 'Pending'   THEN 'Awaiting staff approval'
        WHEN b.status = 'Approved'  THEN 'Confirmed — check in when session starts'
        WHEN b.status = 'Rejected'  THEN 'Not approved — see reason'
        WHEN b.status = 'Cancelled' THEN 'Cancelled — no further action'
        WHEN b.status = 'CheckedIn' THEN 'Session in progress now'
        WHEN b.status = 'Completed' THEN 'Session finished successfully'
        WHEN b.status = 'NoShow'    THEN 'Missed — may affect future bookings'
        ELSE b.status
    END                                                  AS action_needed
FROM bookings b
INNER JOIN spaces s ON s.space_id = b.space_id
LEFT JOIN booking_decisions bd ON bd.booking_id = b.booking_id
WHERE b.requester_id = @student_id
ORDER BY b.requested_start_time DESC;
GO

-- =====================================================================
-- END MEMBER SECTION: 24125080
-- =====================================================================
