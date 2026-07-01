# Step 1: Business Requirement Analysis — G08

## 1. Business Purpose and Problem Statement

**Business Purpose:** The School of Computer Science wants to replace its manual space management process with a centralized database system. The system will manage space bookings, approvals, usage tracking, maintenance, and facility utilization for shared physical spaces such as auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces.

**Problem Statement:** Currently, requests to use campus spaces are handled manually — lecturers, teaching assistants, students, and staff contact the school office or facility staff by email, phone, or in person. Facility staff then check spreadsheets or shared calendars to determine availability, eligibility, equipment needs, and maintenance status. As the number of classes, student projects, workshops, seminars, and academic events increases, this manual process has become difficult to manage. It is inefficient, prone to errors such as double bookings, lacks a clear audit trail for approval decisions, and provides no centralized view of space availability or maintenance status.

**Goal:** Build a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization — ensuring fair scheduling, preventing conflicting bookings, blocking unavailable spaces, and preserving usage history.

## 2. Identified Actors / User Roles

| Role | Responsibilities |
|---|---|
| **Student** | Can request spaces for approved student activities and academic projects. |
| **Lecturer** | Can request spaces for lectures, seminars, workshops, and examinations. |
| **Teaching Assistant** | Can request or manage spaces for classes, labs, and tutorials. |
| **Facility Staff** | Reviews and approves/rejects booking requests; manages check-ins and check-outs; handles maintenance records. |
| **Department Administrator** | Can view operational data and manage bookings for department-level events. |
| **Facility Manager** | Has high-level administrative control over spaces, policies, approvals, maintenance workflows, and system-wide reports. |

## 3. Identified Entities and Attributes

All attributes listed below are conceptual descriptors only. No SQL data types, physical Foreign Key columns, or index declarations appear. Identifiers (Home IDs) belong only inside their defining entity. Links between entities are represented through relationships (Section 4), not through attribute duplication.

### Department
- `department_id` (Home ID)
- `department_name`

### UserAccount
- `user_id` (Home ID)
- `email`
- `full_name`
- `phone_number`
- `role`
- `account_status`
- `created_at`
- `updated_at`

### Space
- `space_id` (Home ID)
- `space_code` (business code, stable entity)
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

### Facility
- `facility_id` (Home ID)
- `facility_name`
- `description`

### SpaceFacility (Junction)
- `quantity`
- `condition`
- `note`

### Booking
- `booking_id` (Home ID)
- `requested_start_time`
- `requested_end_time`
- `purpose`
- `expected_participants`
- `booking_type`
- `status`
- `cancelled_at`
- `cancel_reason`
- `created_at`
- `updated_at`

### BookingDecision
- `decision_id` (Home ID)
- `decision`
- `decision_time`
- `decision_note`
- `rejection_reason`

### UsageSession
- `session_id` (Home ID)
- `actual_start_time`
- `initial_condition`
- `actual_end_time`
- `final_condition`
- `usage_notes`

### MaintenanceRecord
- `maintenance_id` (Home ID)
- `problem_description`
- `problem_category`
- `start_time`
- `completion_time`
- `status`
- `result_note`
- `created_at`
- `updated_at`

## 4. Identified Relationships

Each relationship is stated bidirectionally. No physical Foreign Key columns are listed — the relationship line represents the connection.

### UserAccount — Department
- **UserAccount → Department:** Many UserAccounts belong to one Department.
- **Department → UserAccount:** One Department has many UserAccounts.

### UserAccount — Booking (as requester)
- **UserAccount → Booking:** One UserAccount (as requester) makes many Bookings.
- **Booking → UserAccount:** Each Booking is requested by one UserAccount.

### UserAccount — BookingDecision (as deciding staff)
- **UserAccount → BookingDecision:** One UserAccount (as deciding staff member) makes many BookingDecisions.
- **BookingDecision → UserAccount:** Each BookingDecision is made by one UserAccount.

### UserAccount — UsageSession (checks in)
- **UserAccount → UsageSession:** One UserAccount (as checking-in staff) checks in many UsageSessions.
- **UsageSession → UserAccount:** Each UsageSession is checked in by one UserAccount.

### UserAccount — UsageSession (completes)
- **UserAccount → UsageSession:** One UserAccount (as completing staff) completes many UsageSessions.
- **UsageSession → UserAccount:** Each UsageSession is completed by one UserAccount.

### UserAccount — MaintenanceRecord (reports)
- **UserAccount → MaintenanceRecord:** One UserAccount (as reporter) reports many MaintenanceRecords.
- **MaintenanceRecord → UserAccount:** Each MaintenanceRecord is reported by one UserAccount.

### UserAccount — MaintenanceRecord (is assigned)
- **UserAccount → MaintenanceRecord:** One UserAccount (as assigned staff) is assigned to many MaintenanceRecords.
- **MaintenanceRecord → UserAccount:** Each MaintenanceRecord has one assigned UserAccount.

### Space — Booking
- **Space → Booking:** One Space is the subject of many Bookings over time.
- **Booking → Space:** Each Booking is for exactly one Space.

### Space — Facility (via SpaceFacility junction)
- **Space → SpaceFacility:** One Space has many SpaceFacility entries.
- **Facility → SpaceFacility:** One Facility appears in many SpaceFacility entries.
- **SpaceFacility → Space:** Each SpaceFacility entry belongs to exactly one Space.
- **SpaceFacility → Facility:** Each SpaceFacility entry references exactly one Facility.

### Booking — BookingDecision
- **Booking → BookingDecision:** One Booking has many BookingDecisions (preserving full audit/decision history).
- **BookingDecision → Booking:** Each BookingDecision belongs to exactly one Booking.

### Booking — UsageSession
- **Booking → UsageSession:** One Booking may have at most one UsageSession (0 or 1).
- **UsageSession → Booking:** Each UsageSession belongs to exactly one Booking.

### Space — MaintenanceRecord
- **Space → MaintenanceRecord:** One Space undergoes many MaintenanceRecords.
- **MaintenanceRecord → Space:** Each MaintenanceRecord is for exactly one Space.

## 5. Process-Oriented Sub-Sections

### A. Booking Request Lifecycle
A booking request follows a distinct lifecycle: a newly submitted request starts as **Pending**. A staff member or manager may then **Approved** or **Rejected** it. An approved booking progresses to **Checked In** when the requester arrives and facility staff perform check-in. After use, the booking is **Completed** (checked out). An approved booking that is never checked in may be marked as **No-show**. The requester may cancel a pending or approved booking, which stores the cancellation timestamp and reason.

### B. Approval Workflow
When a booking request is reviewed, the system records the deciding staff member (or manager), the decision time, a decision note, and — in case of rejection — a rejection reason. A booking may accumulate multiple decision records over its lifecycle (1-N relationship) to preserve a complete audit trail of who decided what and when.

### C. Usage Session / Check-in & Check-out
When the requester arrives, facility staff check in the booking. The check-in records the actual start time, the staff member who performed the check-in, and the initial condition of the space.

When the session ends, facility staff complete (check out) the booking. The completion records the actual end time, the final condition of the space, and any usage notes.

### D. Maintenance Management
A space may have maintenance records documenting issues such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems. Each maintenance record identifies the related space, the reporter, the assigned staff member, a problem description, a problem category, a start time, a completion time, a status, and a result note. A space with active maintenance becomes unavailable for booking (its status changes to Under Maintenance, and the system must prevent new bookings for that space).

## 6. Identified Business Rules and Constraints

### Critical Business Rules (Explicit)

1. **No Overlapping Approved Bookings:** The same space cannot have two **approved** bookings with overlapping time periods.
2. **No Booking Unavailable Spaces:** A space that is **under maintenance, temporarily closed, or retired** cannot be booked.

### Booking Lifecycle and Status Rules

3. **Booking Lifecycle:** Bookings follow a distinct lifecycle: Pending → Approved/Rejected; Approved → Checked In → Completed or No-show. Cancelled bookings store a timestamp and reason. (Explicit)
4. **Validity of Time Range:** Requested end time must be later than requested start time. (Explicit)
5. **Positive Participants:** Expected participants must be a positive number. (Explicit)

### Approval and Decision Rules

6. **Approval Documentation (Decision Audit Trail):** Every booking approval or rejection stores the deciding staff member, decision time, decision note, and a rejection reason when the booking is rejected. (Explicit)
7. **Only Staff Can Decide:** Only facility staff or facility managers may approve or reject booking requests. (Explicit)

### Check-in and Check-out Rules

8. **Check-in Tracking:** Check-in records the actual start time, the staff member who checked it in, and the initial condition of the space. (Explicit)
9. **Check-out / Completion Tracking:** Check-out records the actual end time, the final condition of the space, and usage notes. (Explicit)
10. **Only Approved Bookings Can Be Checked In:** Only bookings with Approved status can be checked in. (Explicit)
11. **Only Checked-in Bookings Can Be Completed:** Only bookings with Checked In status can be completed. (Explicit)
12. **Actual End Time After Start Time:** Actual end time must be later than actual start time. (Explicit)

### Maintenance Rules

13. **Active Maintenance Blocks Booking:** A space with active maintenance (status other than Completed/Cancelled) should not be bookable. (Explicit)
14. **Maintenance Must Reference a Space:** Every maintenance record must be linked to a valid space. (Explicit)

### Data Preservation Rules

15. **Historical Record Preservation:** Historical booking and maintenance records must be preserved — staff can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings. (Explicit)

### Inferred / Assumption-Based Rules

16. **Capacity Guideline:** The expected number of participants should not exceed the capacity of the selected space. The requirement stores both values but does not state whether this is a hard rule or a guideline; it is recorded as an **inferred** design concern and an **open question**. (Inferred / Open Question)
17. **Active Account Access Control:** Users have an `account_status` attribute. Whether only active accounts may submit bookings is an **assumption** about access control; the requirement does not explicitly state this rule. (Assumption)
18. **Overlap Definition:** Overlapping time periods are defined as two time ranges (start1, end1) and (start2, end2) where start1 < end2 AND start2 < end1. (Assumption / Design Convention)
19. **Booking Refers to One Space:** A booking refers to exactly one space. (Assumption)
20. **created_at / updated_at Metadata:** Core entities (UserAccount, Space, Booking, MaintenanceRecord) include `created_at` and `updated_at` as metadata attributes. (Design Convention)

## 7. Assumptions and Open Questions

### Assumptions

- **Pre-registered Users:** All users are pre-registered in the university's account system. This system manages roles and permissions related to space booking, not account creation.
- **Department as Normalized Entity:** Department is managed externally but is represented as a normalized, first-class entity within this system. Every user belongs to one department.
- **Single-Space Booking:** A booking refers to exactly one space. The requirement states the requester selects a space.
- **Full DateTime Values:** Requested and actual start/end times are full date-and-time values, enabling precise overlap evaluation.
- **Shared Facility Catalogue:** Facilities are a shared catalogue that can be associated with many spaces (e.g., multiple rooms can each have a "projector").
- **Account Status Semantics:** The `account_status` field exists, but its exact effect (e.g., whether only active users may submit bookings) is left to the design team to determine.
- **No Auto-Approval:** All booking requests start as Pending and require manual approval/rejection by a staff member or manager.

### Open Questions

- **Recurring Bookings:** Are recurring/repeating bookings (e.g., a weekly lecture series) required, or only single-occurrence bookings? The requirement describes single bookings only.
- **Capacity Enforcement:** Should the expected number of participants be checked against a space's capacity as a hard rule or a soft guideline? Both values are stored, but no enforcement rule is stated.
- **Cancellation Policy:** Who may cancel a booking, and until when? The Cancelled status exists, but the actor and timing are not specified.
- **No-show Policy:** What is the exact policy for marking a booking as No-show? Is it automatic after a grace period past the start time, or a manual action by staff?
- **Auto-Approval Rules:** Are there any auto-approval policies for certain user roles, space types, or time ranges?

## 8. Traceability Notes and Classification Matrix

### Traceability Matrix

| Rule | Source | Classification |
|---|---|---|
| No overlapping approved bookings | req/business-requirement.md §14 (Critical business rules) | Explicit |
| Space under maintenance/closed/retired cannot be booked | req/business-requirement.md §14 (Critical business rules) | Explicit |
| Booking lifecycle (Pending → Approved/Rejected → Checked In → Completed/No-show) | req/business-requirement.md §9 (Booking request lifecycle) | Explicit |
| Requested end time after requested start time | CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md §4.4 (Business rules) | Explicit |
| Expected participants must be positive | CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md §4.4 (Business rules) | Explicit |
| Approval stores deciding staff, decision time, decision note, rejection reason | req/business-requirement.md §10 (Approval and rejection workflow) | Explicit |
| Only staff or managers may approve/reject | CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md §4.4 (Business rules) | Explicit |
| Check-in records actual start time, checked-in-by, initial condition | req/business-requirement.md §11 (Check-in and check-out) | Explicit |
| Check-out records actual end time, final condition, usage notes | req/business-requirement.md §11 (Check-in and check-out) | Explicit |
| Only approved bookings can be checked in | CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md §4.6 (Business rules) | Explicit |
| Only checked-in bookings can be completed | CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md §4.6 (Business rules) | Explicit |
| Actual end time after actual start time | CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md §4.6 (Business rules) | Explicit |
| Maintenance records preserved; space with active maintenance blocked | req/business-requirement.md §12 (Maintenance management) | Explicit |
| Historical records must be preserved | req/business-requirement.md §13 (History and reporting) | Explicit |
| Capacity guideline (expected participants vs. capacity) | CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md §4.4 (Business rules) | Inferred / Open Question |
| Active-account access control | Team design decision | Assumption |
| Overlap definition (start1 < end2 AND start2 < end1) | Standard interval logic | Assumption |
| Booking refers to one space | req/business-requirement.md §15 (Assumptions) | Assumption |
| created_at/updated_at on core entities | SKILL.md metadata rule / AGENTS.md §4 | Design Convention |
| Department is a normalized entity | SKILL.md domain requirement | Design Convention |
| BookingDecision is 1-N with Booking | SKILL.md domain requirement | Design Convention |
| All booking requests start as Pending | CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md §4.4 (Business rules) | Explicit |

### Key Design Traceability Notes

- **UserAccount and Department:** Stored as separate normalized entities, linked by relationship. Department is not an attribute of UserAccount.
- **Space and Facility:** Connected through the SpaceFacility junction entity to resolve the M-N relationship. The `note` attribute on SpaceFacility accommodates per-instance remarks.
- **Booking Workflow:** The full lifecycle is captured across Booking, BookingDecision (1-N for audit trail), and UsageSession (1-to-0..1). Booking includes `booking_type`, `cancelled_at`, and `cancel_reason` as required.
- **Maintenance Workflow:** MaintenanceRecord includes `problem_category` for structured reporting. Relationships to UserAccount handle both the reporter and the assigned staff member.
- **Conceptual Purity:** No SQL data types, Foreign Key columns, or index references appear in this analysis. All cross-entity links are described as relationships, not as duplicated ID attributes.
