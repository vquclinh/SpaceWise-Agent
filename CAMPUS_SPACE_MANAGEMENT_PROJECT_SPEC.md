# Campus Space Management System — Project Specification

> This document is a project-level requirement brief for building the **Campus Space Management System**.  
> It intentionally **excludes Phase 1 submission instructions and grading deliverables**.  
> Use this file as a stable source of truth for implementing the application, database, workflows, and business rules.

---

## 1. Project Overview

The School of Computer Science manages many shared physical spaces used for lectures, examinations, seminars, workshops, student projects, research activities, administrative meetings, and academic events.

Current space booking is handled manually through email, phone calls, in-person requests, spreadsheets, and shared calendars. This manual process becomes difficult as the number of classes, projects, events, and maintenance activities increases.

The goal of this project is to build a database-backed system that helps the School:

- Manage bookable campus spaces.
- Allow authorized users to request space bookings.
- Support approval or rejection of booking requests.
- Prevent overlapping bookings.
- Prevent booking unavailable spaces.
- Track actual usage sessions.
- Manage maintenance records and incidents.
- Preserve historical booking and maintenance data.
- Provide staff with useful operational views and reports.

---

## 2. Core Problem

The current process has several weaknesses:

1. **Manual availability checking**
   - Staff must check spreadsheets or calendars manually.
   - This increases the risk of mistakes and double bookings.

2. **Unclear approval workflow**
   - Booking decisions may be made through informal communication.
   - Decision history can be lost or hard to audit.

3. **No centralized space status**
   - A room may be under maintenance, temporarily closed, retired, or already in use.
   - Without a centralized database, users may request spaces that should not be available.

4. **Limited usage history**
   - It is difficult to know who used a space, when they used it, whether they checked in, and whether the space condition changed.

5. **Weak maintenance tracking**
   - Problems such as broken projectors, air-conditioning issues, network problems, or damaged furniture may be reported informally.
   - Staff need a structured way to track maintenance status and completion.

---

## 3. Target Users and Roles

Every user must have a university account. The system stores basic user profile information and assigns a role.

### 3.1 User Roles

| Role | Description |
|---|---|
| Student | Can request spaces for student activities, projects, or academic work if allowed by policy. |
| Lecturer | Can request rooms for lectures, seminars, workshops, examinations, and academic events. |
| Teaching Assistant | Can request or help manage spaces for classes, labs, or examinations. |
| Facility Staff | Can review bookings, approve/reject requests, check in sessions, complete sessions, and manage maintenance records. |
| Department Administrator | Can view operational data and possibly manage bookings for department-level events. |
| Facility Manager | Has high-level control over spaces, approvals, maintenance, reports, and system policies. |

### 3.2 User Account Attributes

Each user account should store:

- User ID
- Full name
- Email
- Phone number
- Role
- Department
- Account status

Recommended account statuses:

- Active
- Inactive
- Suspended
- Deleted / archived

---

## 4. Main System Modules

The application should be organized around the following modules.

### 4.1 User Management

Purpose:

- Store university user accounts.
- Track user role, department, and account status.
- Ensure only valid users can submit or manage bookings.

Key functions:

- Create user profile.
- Update user profile.
- View user list.
- Filter users by role, department, or status.
- Disable or reactivate user account.

Access control suggestions:

- Students, lecturers, and TAs can view and update limited personal information.
- Facility staff and managers can view requester information needed for booking operations.
- Facility managers or admins can manage account status.

---

### 4.2 Space Management

Purpose:

- Maintain a centralized list of all bookable and non-bookable campus spaces.

Each space should store:

- Unique space code
- Space name
- Space type
- Building
- Floor
- Room number
- Capacity
- Current status
- Usage policy

Recommended space types:

- Auditorium
- Classroom
- Computer laboratory
- Project laboratory
- Meeting room
- Student workspace

Recommended space statuses:

- Available
- In use
- Under maintenance
- Temporarily closed
- Retired

Key functions:

- Create a new space.
- Update space information.
- Change space status.
- View all spaces.
- Filter spaces by type, building, capacity, status, or available facilities.
- View a space’s booking history.
- View a space’s maintenance history.

Business rules:

- A retired space should normally not be bookable.
- A temporarily closed space should not be bookable.
- A space under maintenance should not be bookable.
- A space in use should not be available for another overlapping approved booking.
- Capacity should be a positive integer.
- Space code must be unique.

---

### 4.3 Facility Inventory for Spaces

Purpose:

- Track facilities and equipment available in each space.

Examples of facilities:

- Projector
- Whiteboard
- Microphone
- Computer
- Livestreaming equipment
- Air conditioner
- Speaker
- Network connection
- Camera
- Power sockets

Recommended design:

- A facility can exist in many spaces.
- A space can have many facilities.
- Use a many-to-many relationship between `spaces` and `facilities`.

Optional attributes for the relationship:

- Quantity
- Condition
- Note
- Last checked date

---

### 4.4 Booking Request Management

Purpose:

- Allow users to submit booking requests for a selected space and time period.

Each booking request should store:

- Booking ID
- Requester
- Space
- Requested start time
- Requested end time
- Purpose of use
- Expected number of participants
- Booking type
- Booking status
- Created time
- Updated time

Recommended booking types:

- Lecture
- Examination
- Seminar
- Workshop
- Meeting
- Student activity
- Administrative event
- Research activity
- Project work

Recommended booking statuses:

- Pending
- Approved
- Rejected
- Cancelled
- Checked in
- Completed
- No-show

Key functions:

- Submit a booking request.
- View own booking requests.
- View booking request details.
- Cancel a pending or approved booking if allowed.
- Staff can view all pending requests.
- Staff can approve or reject requests.
- Staff can view upcoming bookings.
- Staff can view booking history.
- Staff can identify no-show bookings.

Business rules:

1. Requested end time must be later than requested start time.
2. Expected participants must be positive.
3. Expected participants should not exceed the capacity of the selected space.
4. A user must have an active university account to submit a booking request.
5. A space cannot be booked if its status is:
   - Under maintenance
   - Temporarily closed
   - Retired
6. The same space cannot have two approved bookings with overlapping requested time periods.
7. A booking request starts as `Pending` unless the system supports auto-approval for selected policies.
8. Only staff or managers should approve or reject booking requests.
9. A rejected booking must store a rejection reason or decision note.
10. A cancelled booking should remain in history instead of being deleted.

---

### 4.5 Approval and Rejection Workflow

Purpose:

- Record the decision process for booking requests.

When a booking is approved or rejected, the system should store:

- Booking ID
- Staff member or manager who made the decision
- Decision time
- Decision note
- Rejection reason, if rejected

Recommended workflow:

1. User submits a booking request.
2. System validates:
   - User account is active.
   - Space exists.
   - Space is bookable.
   - Time range is valid.
   - Capacity is sufficient.
   - No approved overlapping booking exists.
3. Booking status becomes `Pending`.
4. Facility staff or manager reviews the request.
5. Staff approves or rejects the request.
6. System records decision metadata.
7. If approved, the booking becomes visible in upcoming approved bookings.
8. If rejected, the requester can view the rejection reason.

Optional extension:

- Use a separate `booking_decisions` table if the system should preserve multiple decision events.
- If only one decision is allowed per booking, decision fields may be stored directly in the `bookings` table.

---

### 4.6 Check-in and Usage Session Tracking

Purpose:

- Track actual space usage, not only requested booking times.

When the requester arrives, facility staff can check in the booking.

Check-in should record:

- Actual start time
- Staff member who checked in the booking
- Initial condition of the space

When the session ends, facility staff can complete the booking.

Completion should record:

- Actual end time
- Final condition of the space
- Usage notes

Recommended workflow:

1. Booking must be `Approved` before check-in.
2. Facility staff checks in the booking when the requester arrives.
3. Booking status changes to `Checked in`.
4. Actual start time is stored.
5. Initial condition is recorded.
6. Staff completes the session after use.
7. Booking status changes to `Completed`.
8. Actual end time, final condition, and usage notes are stored.

Business rules:

- Only approved bookings can be checked in.
- Only checked-in bookings can be completed.
- Actual end time must be later than actual start time.
- A booking that was approved but not checked in may later be marked as `No-show`.
- Usage records should not be deleted because they are part of historical data.

---

### 4.7 Maintenance Management

Purpose:

- Track problems, repairs, and maintenance work for campus spaces.

Each maintenance record should store:

- Maintenance ID
- Related space
- Reporter
- Assigned staff member
- Problem description
- Start time
- Completion time
- Status
- Result note

Examples of maintenance problems:

- Broken projector
- Air-conditioning failure
- Damaged furniture
- Cleaning issue
- Network problem
- Audio or microphone issue
- Lighting problem
- Computer equipment failure

Recommended maintenance statuses:

- Reported
- Assigned
- In progress
- Completed
- Cancelled

Key functions:

- Report a maintenance issue.
- Assign staff to a maintenance record.
- Update maintenance status.
- Record completion time.
- Add result notes.
- View spaces currently under maintenance.
- View maintenance history by space.
- View active maintenance tasks by assigned staff member.

Business rules:

1. A maintenance record must be linked to a valid space.
2. A maintenance record must have a reporter.
3. A space with active maintenance should not be bookable.
4. If a maintenance record is active, the related space may be set to `Under maintenance`.
5. Completion time should only be set when the maintenance status is `Completed`.
6. Completion time must be later than start time.
7. Maintenance history should be preserved.

---

### 4.8 Staff Views and Reports

Staff should be able to view operational information such as:

- Booking history
- Upcoming bookings
- Pending booking requests
- Approved bookings
- Cancelled bookings
- Rejected bookings
- No-show bookings
- Spaces under maintenance
- Space utilization
- Maintenance history
- Frequent maintenance issues
- Most used spaces
- Bookings by department
- Bookings by user role
- Booking conflicts prevented by the system

Recommended report examples:

1. Upcoming approved bookings for the next 7 days.
2. Spaces that are currently under maintenance.
3. No-show bookings in the current semester.
4. Booking count by space type.
5. Utilization hours per space.
6. Maintenance issue count by problem category.
7. Booking requests pending approval.
8. Booking history for a selected requester.
9. Booking history for a selected space.
10. Spaces available for a given time range and participant count.

---

## 5. Recommended Database Entities

The following entities are recommended for the system.

### 5.1 `users`

Stores university account information.

Suggested fields:

- `user_id` primary key
- `full_name`
- `email`
- `phone_number`
- `role`
- `department`
- `account_status`
- `created_at`
- `updated_at`

Constraints:

- `email` should be unique.
- `role` should be restricted to valid user roles.
- `account_status` should be restricted to valid statuses.

---

### 5.2 `spaces`

Stores bookable and managed spaces.

Suggested fields:

- `space_id` primary key
- `space_code` unique
- `space_name`
- `space_type`
- `building`
- `floor`
- `room_number`
- `capacity`
- `current_status`
- `usage_policy`
- `created_at`
- `updated_at`

Constraints:

- `space_code` must be unique.
- `capacity > 0`.
- `space_type` should be restricted to valid types.
- `current_status` should be restricted to valid statuses.

---

### 5.3 `facilities`

Stores facility or equipment types.

Suggested fields:

- `facility_id` primary key
- `facility_name`
- `description`

Constraints:

- `facility_name` should be unique.

---

### 5.4 `space_facilities`

Junction table between spaces and facilities.

Suggested fields:

- `space_id` foreign key
- `facility_id` foreign key
- `quantity`
- `condition`
- `note`

Constraints:

- Composite primary key: (`space_id`, `facility_id`)
- `quantity >= 0`

---

### 5.5 `bookings`

Stores booking requests and their lifecycle status.

Suggested fields:

- `booking_id` primary key
- `requester_id` foreign key to `users`
- `space_id` foreign key to `spaces`
- `requested_start_time`
- `requested_end_time`
- `purpose`
- `expected_participants`
- `booking_type`
- `status`
- `created_at`
- `updated_at`
- `cancelled_at`
- `cancel_reason`

Constraints:

- `requested_end_time > requested_start_time`
- `expected_participants > 0`
- `booking_type` should be restricted to valid booking types.
- `status` should be restricted to valid booking statuses.

Important database-level rule:

- Prevent overlapping approved bookings for the same space.
- If using PostgreSQL, consider an exclusion constraint with a timestamp range.
- If using a database that does not support exclusion constraints, enforce this rule with transactions, triggers, or application-level checks.

---

### 5.6 `booking_decisions`

Stores approval or rejection decision metadata.

Suggested fields:

- `decision_id` primary key
- `booking_id` foreign key to `bookings`
- `decided_by` foreign key to `users`
- `decision` approved/rejected
- `decision_time`
- `decision_note`
- `rejection_reason`

Constraints:

- `decision` must be either `approved` or `rejected`.
- `rejection_reason` should be required when decision is `rejected`.
- `decided_by` should reference a staff or manager user.

Alternative design:

- If the system only needs one decision per booking, these fields can be embedded into `bookings`.
- A separate table is more flexible and better for audit history.

---

### 5.7 `usage_sessions`

Stores actual check-in and completion information.

Suggested fields:

- `session_id` primary key
- `booking_id` foreign key to `bookings`
- `checked_in_by` foreign key to `users`
- `actual_start_time`
- `initial_condition`
- `completed_by` foreign key to `users`
- `actual_end_time`
- `final_condition`
- `usage_notes`

Constraints:

- One booking should normally have at most one usage session.
- `actual_end_time > actual_start_time` if both are present.
- `checked_in_by` and `completed_by` should reference staff users.

---

### 5.8 `maintenance_records`

Stores maintenance and incident tracking.

Suggested fields:

- `maintenance_id` primary key
- `space_id` foreign key to `spaces`
- `reporter_id` foreign key to `users`
- `assigned_staff_id` foreign key to `users`
- `problem_description`
- `problem_category`
- `start_time`
- `completion_time`
- `status`
- `result_note`
- `created_at`
- `updated_at`

Constraints:

- `status` should be restricted to valid maintenance statuses.
- `completion_time > start_time` if completion time is present.
- `assigned_staff_id` may be nullable before assignment.
- `result_note` may be required when status is `Completed`.

---

## 6. Important Relationships

Recommended cardinalities:

1. **User → Booking**
   - One user can submit many bookings.
   - Each booking has exactly one requester.

2. **Space → Booking**
   - One space can have many bookings over time.
   - Each booking is for exactly one space.

3. **Space ↔ Facility**
   - One space can have many facilities.
   - One facility can appear in many spaces.
   - Use `space_facilities` as the junction table.

4. **Booking → Booking Decision**
   - One booking can have zero or one final decision in the basic design.
   - A decision is made by one staff member or manager.
   - If audit history is required, one booking can have many decision events.

5. **Booking → Usage Session**
   - One approved booking can have zero or one usage session.
   - A usage session belongs to exactly one booking.

6. **Space → Maintenance Record**
   - One space can have many maintenance records.
   - Each maintenance record belongs to exactly one space.

7. **User → Maintenance Record**
   - One user can report many maintenance records.
   - One staff member can be assigned to many maintenance records.

---

## 7. Core Business Rules

The implementation should enforce these rules as much as possible at the database level, and also validate them in the application layer.

### 7.1 Booking Rules

- Only active users can submit booking requests.
- Requested start time must be before requested end time.
- Expected participants must be greater than zero.
- Expected participants should not exceed the selected space capacity.
- A booking cannot be approved if the space is unavailable.
- A booking cannot be approved if it overlaps another approved booking for the same space.
- Bookings for spaces under maintenance, temporarily closed, or retired must be blocked.
- Pending bookings can be approved, rejected, or cancelled.
- Approved bookings can be checked in, cancelled, completed through a session, or marked no-show.
- Rejected, completed, cancelled, and no-show bookings should remain in history.

### 7.2 Space Rules

- Each space must have a unique space code.
- A space may be available, in use, under maintenance, temporarily closed, or retired.
- A space under maintenance cannot be booked.
- A retired space should remain in history but should not accept new bookings.
- Space status should be updated carefully based on booking and maintenance lifecycle.

### 7.3 Approval Rules

- Only facility staff or facility managers can approve or reject requests.
- Decision time must be recorded.
- Decision note should be stored.
- Rejection reason should be stored when a booking is rejected.
- Approval should only be allowed if no conflict exists at the time of approval.

### 7.4 Usage Session Rules

- Only approved bookings can be checked in.
- Check-in records actual start time and initial condition.
- Completion records actual end time, final condition, and usage notes.
- Actual end time must be later than actual start time.
- Bookings that are approved but not used can be marked as no-show.

### 7.5 Maintenance Rules

- Active maintenance should make a space unavailable for booking.
- A maintenance record must include the space, reporter, problem description, start time, and status.
- Assigned staff may be added later.
- Completed maintenance should store completion time and result note.
- Maintenance history should be preserved for reporting.

---

## 8. Recommended Application Workflows

### 8.1 Submit Booking Request

1. User logs in.
2. User searches or filters available spaces.
3. User selects a space.
4. User enters:
   - Requested start time
   - Requested end time
   - Purpose
   - Expected participants
   - Booking type
5. System validates:
   - User is active.
   - Space is not retired, closed, or under maintenance.
   - Time range is valid.
   - Capacity is sufficient.
   - No approved overlapping booking exists.
6. System creates booking with status `Pending`.
7. Staff can review it later.

---

### 8.2 Approve Booking

1. Staff opens pending booking list.
2. Staff reviews booking details.
3. System re-checks conflict and space availability.
4. Staff approves the booking.
5. System records:
   - Deciding staff
   - Decision time
   - Decision note
6. Booking status becomes `Approved`.

---

### 8.3 Reject Booking

1. Staff opens pending booking list.
2. Staff reviews booking details.
3. Staff enters rejection reason.
4. System records:
   - Deciding staff
   - Decision time
   - Decision note
   - Rejection reason
5. Booking status becomes `Rejected`.

---

### 8.4 Check In Booking

1. Requester arrives.
2. Facility staff finds the approved booking.
3. Staff records actual start time.
4. Staff records initial condition of the space.
5. Booking status becomes `Checked in`.
6. Usage session is created.

---

### 8.5 Complete Booking

1. Session ends.
2. Facility staff records actual end time.
3. Staff records final condition.
4. Staff adds usage notes if needed.
5. Booking status becomes `Completed`.

---

### 8.6 Mark No-show

1. Approved booking time passes.
2. Requester does not arrive.
3. Staff marks the booking as `No-show`.
4. The record remains in booking history.

---

### 8.7 Report Maintenance Issue

1. User or staff reports a problem with a space.
2. System creates a maintenance record.
3. Facility staff or manager assigns responsible staff.
4. Space may be set to `Under maintenance`.
5. Booking for this space should be blocked while maintenance is active.
6. Staff completes the maintenance record after the issue is resolved.
7. Space may be returned to `Available` if appropriate.

---

## 9. Suggested Pages or API Features

The project can be implemented as a web application, admin dashboard, or database-focused system. The following features are recommended.

### 9.1 Public or General User Pages

- Login page
- Space list page
- Space detail page
- Booking request form
- My bookings page
- Booking detail page
- Cancel booking action

### 9.2 Staff Pages

- Staff dashboard
- Pending booking requests
- Booking approval/rejection page
- Upcoming bookings
- Check-in page
- Complete session page
- No-show management page
- Maintenance list
- Maintenance detail page
- Space management page

### 9.3 Manager/Admin Pages

- User management
- Space management
- Facility management
- Booking reports
- Space utilization reports
- Maintenance reports
- Audit/history views

---

## 10. Suggested API Endpoints

These endpoints are examples only. Adjust names based on the chosen framework.

### Users

- `GET /users`
- `GET /users/:id`
- `POST /users`
- `PATCH /users/:id`
- `PATCH /users/:id/status`

### Spaces

- `GET /spaces`
- `GET /spaces/:id`
- `POST /spaces`
- `PATCH /spaces/:id`
- `GET /spaces/:id/bookings`
- `GET /spaces/:id/maintenance`

### Facilities

- `GET /facilities`
- `POST /facilities`
- `PATCH /facilities/:id`
- `POST /spaces/:id/facilities`
- `DELETE /spaces/:id/facilities/:facilityId`

### Bookings

- `GET /bookings`
- `GET /bookings/:id`
- `POST /bookings`
- `PATCH /bookings/:id/cancel`
- `PATCH /bookings/:id/approve`
- `PATCH /bookings/:id/reject`
- `PATCH /bookings/:id/check-in`
- `PATCH /bookings/:id/complete`
- `PATCH /bookings/:id/no-show`

### Maintenance

- `GET /maintenance`
- `GET /maintenance/:id`
- `POST /maintenance`
- `PATCH /maintenance/:id/assign`
- `PATCH /maintenance/:id/status`
- `PATCH /maintenance/:id/complete`

### Reports

- `GET /reports/upcoming-bookings`
- `GET /reports/no-shows`
- `GET /reports/spaces-under-maintenance`
- `GET /reports/space-utilization`
- `GET /reports/maintenance-summary`

---

## 11. Recommended Validation Logic

The application should perform validation before writing data.

### Booking Creation Validation

Check:

- Requester exists.
- Requester account is active.
- Space exists.
- Space status is bookable.
- Start time is before end time.
- Expected participants is positive.
- Expected participants does not exceed capacity.
- No conflicting approved booking exists.

### Booking Approval Validation

Check again at approval time:

- Booking is currently pending.
- Space still exists.
- Space is still bookable.
- No approved overlapping booking exists.
- Deciding user has staff or manager role.

### Check-in Validation

Check:

- Booking exists.
- Booking status is approved.
- Staff user has permission.
- Actual start time is valid.
- Initial condition is provided.

### Completion Validation

Check:

- Booking exists.
- Booking status is checked in.
- Usage session exists.
- Actual end time is after actual start time.
- Final condition is provided.
- Completing user has permission.

### Maintenance Validation

Check:

- Space exists.
- Reporter exists.
- Problem description is not empty.
- Start time is valid.
- Completion time is after start time if provided.
- Assigned staff has staff or manager role if assigned.

---

## 12. Data Integrity and Constraints

The database should use constraints wherever possible.

Recommended constraints:

- Primary keys for all main tables.
- Foreign keys for all relationships.
- Unique constraint for user email.
- Unique constraint for space code.
- Unique constraint for facility name.
- Check constraints for enum-like statuses.
- Check constraints for positive capacity and participant count.
- Check constraints for valid time ranges.
- Transaction-safe conflict checking for booking approval.
- Historical records should not be hard deleted unless explicitly required.

Important note:

- The most important rule is preventing overlapping approved bookings for the same space.
- This should be enforced robustly because it is the core purpose of the system.

---

## 13. Example SQL Business Queries

The system should support queries like:

1. Which spaces are available for a given time range and participant count?
2. Which booking requests are still pending approval?
3. What are the upcoming approved bookings for the next 7 days?
4. Which spaces are currently under maintenance?
5. Which bookings were marked as no-show this month?
6. How many bookings did each department make this semester?
7. Which spaces are used most frequently?
8. What is the utilization rate of each space?
9. Which facilities are available in a selected space?
10. What maintenance issues happened for a selected space?
11. Which users have the most cancelled or no-show bookings?
12. Which maintenance records are assigned to each staff member?

---

## 14. Non-Functional Requirements

### 14.1 Reliability

- The system must avoid double booking.
- Booking approval should be transaction-safe.
- Historical data should be preserved.

### 14.2 Usability

- Users should be able to find suitable spaces easily.
- Staff should be able to approve or reject requests quickly.
- Space status should be clear and visible.

### 14.3 Auditability

- Booking decisions should record who made the decision and when.
- Check-in and completion actions should record responsible staff.
- Maintenance updates should preserve status and result notes.

### 14.4 Security

- Role-based access control should be used.
- Users should only perform actions allowed by their role.
- Staff-only operations should be protected.

### 14.5 Maintainability

- Use clear database schema names.
- Keep business rules centralized.
- Separate user-facing actions from staff/admin actions.
- Avoid hard deletion of important historical records.

---

## 15. Suggested Implementation Priority

This is not a submission phase list. It is only a practical build order.

### Priority 1 — Core Database

- Create users, spaces, facilities, space facilities, bookings, decisions, sessions, and maintenance tables.
- Add primary keys, foreign keys, unique constraints, check constraints, and timestamps.
- Add sample data.

### Priority 2 — Booking Conflict Prevention

- Implement conflict checking for approved bookings.
- Block booking unavailable spaces.
- Validate capacity and time ranges.

### Priority 3 — Booking Workflow

- Submit booking request.
- Approve booking.
- Reject booking.
- Cancel booking.
- View booking history and upcoming bookings.

### Priority 4 — Usage Session Workflow

- Check in approved booking.
- Record actual start time and initial condition.
- Complete booking.
- Record actual end time, final condition, and usage notes.
- Mark no-show bookings.

### Priority 5 — Maintenance Workflow

- Report maintenance issue.
- Assign staff.
- Update maintenance status.
- Complete maintenance.
- Block booking while maintenance is active.

### Priority 6 — Reports and Views

- Upcoming bookings.
- Pending approvals.
- Spaces under maintenance.
- No-show bookings.
- Space utilization.
- Maintenance summaries.

---

## 16. Acceptance Criteria

The project can be considered functionally complete when:

- Users can submit booking requests.
- Staff can approve and reject booking requests.
- The system prevents overlapping approved bookings.
- The system prevents booking unavailable spaces.
- Booking decisions are recorded with staff, time, and notes.
- Staff can check in approved bookings.
- Staff can complete checked-in bookings.
- The system stores actual usage session data.
- Maintenance records can be created, assigned, updated, and completed.
- Spaces under active maintenance cannot be booked.
- Historical booking and maintenance records are preserved.
- Staff can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings.
- The database schema clearly represents users, spaces, facilities, bookings, decisions, usage sessions, and maintenance records.

---

## 17. Out of Scope for This Specification

The following items are not required by the source project brief and should only be added if there is extra time:

- Payment system
- Real-time room access control hardware
- QR code scanning
- Calendar integration
- Email notification service
- Complex recurring bookings
- Mobile app
- AI recommendation system
- Full university SSO integration
- Advanced analytics dashboard

---

## 18. Notes for Claude Code

When building this project:

1. Treat this document as the main product specification.
2. Do not implement based on Phase 1 submission instructions.
3. Focus on the actual system requirements and business rules.
4. Prioritize database correctness before UI polish.
5. The most critical business rule is:  
   **the same space cannot have two approved bookings with overlapping time periods.**
6. The second most critical rule is:  
   **spaces under maintenance, temporarily closed, or retired cannot be booked.**
7. Preserve historical records instead of deleting important data.
8. Use role-based access control for staff-only operations.
9. Keep booking lifecycle and maintenance lifecycle explicit and easy to test.
10. Add realistic seed data that covers normal cases and edge cases.

