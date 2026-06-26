# Business Requirement — Campus Space Management System

## 1. File purpose

This file is the **condensed business-domain input** for the CS486 Group G08 Phase 1 database design tasks. It describes *what the business needs*, not the database design itself. Phase 1 commands and skills read this file (together with `CS486_Project.pdf` and `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md`) to produce the design deliverables in `outputs/`. It is **not** a Phase 1 output and must not be turned into one.

## 2. Background

- The School of Computer Science manages several shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events.
- These spaces include auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces.

## 3. Current manual process

- Requests to use these spaces are handled **manually**: lecturers, teaching assistants, students, and staff contact the school office or facility staff by email, phone, or in person.
- Facility staff then check spreadsheets or shared calendars to determine whether a room is available, whether the requester is allowed to use it, whether special equipment is needed, and whether the room is under maintenance.

## 4. Problem statement

- As the number of classes, student projects, workshops, seminars, and academic events increases, the manual process has become difficult to manage.
- The School wants to build a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization.

## 5. System goal

- Develop a system to manage the booking and usage of shared campus spaces such as classrooms, computer laboratories, meeting rooms, and auditoriums.
- The main goal is to help the School manage shared campus spaces fairly, avoid overlapping bookings, prevent the use of unavailable spaces, and preserve usage history.

## 6. Stakeholders and user roles

- Each user must have a university account.
- The system stores basic user information: user ID, full name, email, phone number, role, department, and account status.
- A user may be a:
  - student
  - lecturer
  - teaching assistant
  - facility staff
  - department administrator
  - facility manager

## 7. Managed spaces

- The School manages many bookable spaces.
- For each space, the system stores: a unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy.
- A space status may be:
  - available
  - in use
  - under maintenance
  - temporarily closed
  - retired

## 8. Facilities and equipment

- Each space may have several facilities, such as: a projector, whiteboard, microphone, computer, livestreaming equipment, or air conditioner.
- The system should store the list of facilities available in each space.

## 9. Booking request lifecycle

- Users can submit booking requests by selecting: a space, requested start time, requested end time, purpose of use, and expected number of participants.
- A booking may be for a: lecture, examination, seminar, workshop, meeting, student activity, or administrative event.
- Each booking request has a status, such as:
  - pending
  - approved
  - rejected
  - cancelled
  - checked in
  - completed
  - no-show

## 10. Approval and rejection workflow

- A booking request may require approval from a facility staff member or manager.
- When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note.
- If the booking is rejected, the rejection reason should be stored.

## 11. Check-in and check-out usage session

- When the requester arrives, facility staff can **check in** the booking. The system records the actual start time, the person who checked in the booking, and the initial condition of the space.
- When the session ends, facility staff can **complete** (check out) the booking by recording the actual end time, the final condition of the space, and any usage notes.

## 12. Maintenance management

- The system supports basic maintenance management.
- A space may have maintenance records for problems such as: broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems.
- Each maintenance record stores: the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note.

## 13. History and reporting needs

- The system should keep historical records of bookings and maintenance activities.
- Staff should be able to view: booking history, upcoming bookings, spaces under maintenance, and no-show bookings.

## 14. Critical business rules

1. The system must prevent conflicting bookings: the same space cannot have two **approved** bookings with overlapping time periods.
2. A space that is under maintenance, temporarily closed, or retired cannot be booked. (In particular, a space under maintenance cannot be booked.)

## 15. Assumptions and open questions

Conservative notes implied by the requirement above — recorded for the design team, **not** new business rules. Confirm or refine during Phase 1.

**Assumptions:**

- A booking refers to exactly one space (the requester "selects a space").
- Requested and actual start/end times are full date-and-time values (so overlap can be evaluated).
- Facilities are a shared catalogue that can be associated with many spaces (e.g. multiple rooms can each have "projector").
- Account status indicates whether a user is currently allowed to use the system (the exact effect is left to the design team).

**Open questions:**

- Are recurring/repeating bookings (e.g. a weekly lecture) required, or only single-occurrence bookings? The requirement describes single bookings only.
- Should "expected number of participants" be checked against a space's capacity? Both values are stored, but no rule is stated — do not assume one without confirmation.
- Who may cancel a booking, and until when? The "cancelled" status exists, but the actor and timing are not specified.
