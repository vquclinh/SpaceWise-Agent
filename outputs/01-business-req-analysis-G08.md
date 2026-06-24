# Step 1: Business Requirement Analysis for G08 (Revised)

This document outlines the business requirements for the Campus Space Management System, revised based on updated repository rules and a deeper analysis of the project specification.

## 1. Business Purpose and Problem Statement

**Business Purpose:** The School of Computer Science aims to replace its manual space management process with a centralized database system. The new system will manage space bookings, approvals, usage tracking, maintenance, and facility utilization for its shared physical spaces (e.g., auditoriums, classrooms, labs, meeting rooms).

**Problem Statement:** The current manual process, relying on emails, phone calls, and spreadsheets, is inefficient and prone to errors like double bookings. It lacks a clear audit trail for approvals, a centralized view of space availability (including maintenance statuses), and a structured history of space usage. As the number of users and events grows, the manual system has become unmanageable. The new system is intended to solve these problems by providing a fair, efficient, and transparent platform for managing campus spaces.

## 2. Identified Actors / User Roles

Based on the project specification, the system will have the following user roles:

| Role                      | Responsibilities                                                                                                        |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Student**               | Can request spaces for approved student activities and academic projects.                                               |
| **Lecturer**              | Can request spaces for lectures, seminars, workshops, and examinations.                                                 |
| **Teaching Assistant**    | Can request or manage spaces for classes, labs, and tutorials.                                                          |
| **Facility Staff**        | Reviews and approves/rejects booking requests, manages check-ins and check-outs, and handles maintenance records.         |
| **Department Administrator**| Can view operational data and manage bookings for department-level events.                                              |
| **Facility Manager**      | Has high-level administrative control over spaces, policies, approvals, maintenance workflows, and system-wide reports.   |

## 3. Identified Entities and Attributes

The following core entities and their key attributes have been identified, adhering to conceptual-only details for Step 1.

-   **User Account:** `user_id`, `full_name`, `email`, `phone_number`, `role`, `account_status`, `created_at`, `updated_at`. (Linked to Department)
-   **Department:** `department_id`, `department_name`.
-   **Space:** `space_id`, `space_code`, `space_name`, `space_type`, `building`, `floor`, `room_number`, `capacity`, `current_status` (e.g., Available, Under Maintenance, Retired), `usage_policy`, `created_at`, `updated_at`.
-   **Facility:** `facility_id`, `facility_name`, `description`.
-   **Space Facility (Junction):** `quantity`, `condition`, `note`. (Links Space and Facility)
-   **Booking:** `booking_id`, `requested_start_time`, `requested_end_time`, `purpose`, `expected_participants`, `booking_type`, `status` (e.g., Pending, Approved, Rejected, Cancelled), `cancelled_at`, `cancel_reason`, `created_at`, `updated_at`. (Linked to User and Space)
-   **Booking Decision:** `decision_id`, `decision` (Approved/Rejected), `decision_time`, `decision_note`, `rejection_reason`. (Linked to Booking and User)
-   **Usage Session:** `session_id`, `actual_start_time`, `initial_condition`, `actual_end_time`, `final_condition`, `usage_notes`. (Linked to Booking and User)
-   **Maintenance Record:** `maintenance_id`, `problem_description`, `problem_category`, `status` (e.g., Reported, In Progress, Completed), `start_time`, `completion_time`, `result_note`, `created_at`, `updated_at`. (Linked to Space and User)

## 4. Identified Relationships

-   **User and Department:** A `User` belongs to one `Department`. A `Department` has many `Users`. (One-to-Many)
-   **User and Booking:** A `User` can make many `Bookings`. Each `Booking` is requested by one `User`. (One-to-Many)
-   **Space and Booking:** A `Space` can have many `Bookings` over time. Each `Booking` pertains to exactly one `Space`. (One-to-Many)
-   **Space and Facility:** A `Space` can have many `Facilities`, and a `Facility` can be in many `Spaces`. This is a many-to-many relationship managed through the `Space Facility` junction entity. (Many-to-Many)
-   **Booking and Booking Decision:** A `Booking` can have many `Booking Decisions` to preserve a full audit history of approvals and rejections. Each `Booking Decision` is associated with exactly one `Booking`. (One-to-Many)
-   **Booking and Usage Session:** An approved `Booking` can have at most one `Usage Session`. (One-to-One, Optional)
-   **Space and Maintenance Record:** A `Space` can have many `Maintenance Records`. Each `Maintenance Record` is for one `Space`. (One-to-Many)
-   **User and Maintenance Record:** A `User` can report many `Maintenance Records`. A `User` (as staff) can be assigned to many `Maintenance Records`. A `Maintenance Record` has one reporter and one assigned staff member. (One-to-Many)

## 5. Identified Business Rules and Constraints

### Critical Business Rules
1.  **No Overlapping Approved Bookings:** The same space cannot have two **approved** bookings with overlapping time periods. The system must strictly enforce this to prevent conflicts.
2.  **No Booking Unavailable Spaces:** A space that is currently **under maintenance, temporarily closed, or retired** cannot be booked.

### Other Key Business Rules
-   **User Management:** All system users must have an active university account and be associated with a department.
-   **Booking Lifecycle:** Bookings follow a distinct lifecycle (`Pending` -> `Approved`/`Rejected`, `Approved` -> `Checked In` -> `Completed` or `No-show`). Cancelled bookings store a timestamp and reason.
-   **Approval Workflow:** All booking decisions must be documented, including the deciding staff member, decision time, and a reason for rejection, creating an auditable trail.
-   **Usage Tracking:** Actual usage is tracked via check-in and check-out, recording actual times and space conditions.
-   **Maintenance:** A space with an active maintenance record becomes unavailable for booking. Maintenance records include a problem category.
-   **Data Preservation:** Historical records for bookings, usage sessions, and maintenance must be preserved for auditing and reporting. Core entities include creation and update timestamps.
-   **Capacity:** The number of expected participants in a booking request must not exceed the capacity of the selected space.

## 6. Assumptions and Open Questions

### Assumptions
-   All users are pre-registered in the university's account system. This system's role is to manage their roles and permissions related to space booking, not to create university-wide accounts.
-   `Department` data is managed externally but must be represented as a normalized entity within this system.
-   "Overlapping time periods" is defined as two time ranges `(start1, end1)` and `(start2, end2)` where `start1 < end2` and `start2 < end1`.

### Open Questions
-   What is the exact policy for a booking to be marked as a "No-show"? Is it automatic after a certain time past the start time, or is it a manual action by staff?
-   Are there any auto-approval policies for certain users or space types? The current requirement implies all requests are `Pending` first.
-   How should recurring bookings be handled? The current specification focuses on single-event bookings (Marked as out-of-scope for now).

## 7. Traceability Notes

-   **User & Department Data:** The requirement to store user and department information is traced to the normalized `User Account` and `Department` entities. This separation ensures data integrity.
-   **Space & Facility Management:** The need to manage spaces and their equipment is traced to the `Space`, `Facility`, and `Space Facility` entities. The `note` attribute in `Space Facility` fulfills the requirement for more detailed tracking.
-   **Booking Workflow:** The entire booking lifecycle requirement (request, approve, use, cancel) is traced to the `Booking`, `Booking Decision`, and `Usage Session` entities. The inclusion of `booking_type`, `cancelled_at`, and `cancel_reason` in `Booking` and the 1-N relationship for `Booking Decision` ensures full auditability as per the updated skill.
-   **Maintenance Workflow:** The requirement to track space issues is traced to the `Maintenance Record` entity, which now includes `problem_category` for better reporting.
-   **Conflict Prevention:** The two critical business rules are central design constraints that will be enforced on the `Booking` and `Space` entities.
-   **Timestamps:** The requirement for `created_at` and `updated_at` on core entities is reflected in the attribute lists for `User Account`, `Space`, `Booking`, and `Maintenance Record`.
-   **Conceptual Purity:** In line with the updated `AGENTS.md` rule, this analysis avoids physical database terms like "Foreign Key," focusing purely on the conceptual model.
