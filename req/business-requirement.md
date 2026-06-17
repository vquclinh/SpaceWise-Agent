## Business requirement description
The School of Computer Science manages several shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. These spaces include auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces.

Currently, requests to use these spaces are handled manually. Lecturers, teaching assistants, students, and staff usually contact the school office or facility staff by email, phone, or in person. Facility staff then check spreadsheets or shared calendars to determine whether a room is available, whether the requester is allowed to use it, whether special equipment is needed, and whether the room is under maintenance.

As the number of classes, student projects, workshops, seminars, and academic events increases, the manual process has become difficult to manage. The School wants to build a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization.

The Facility Manager provides the following requirement summary:
The School wants to develop a system to manage the booking and usage of shared campus spaces such as classrooms, computer laboratories, meeting rooms, and auditoriums.
Each user must have a university account. The system stores basic user information, including user ID, full name, email, phone number, role, department, and account status. A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager.
The School manages many bookable spaces. For each space, the system stores a unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy. A space may be available, in use, under maintenance, temporarily closed, or retired.
Each space may have several facilities, such as a projector, whiteboard, microphone, computer, livestreaming equipment, or air conditioner. The system should store the list of facilities available in each space.
Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants. A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event.
Each booking request has a status, such as pending, approved, rejected, cancelled, checked in, completed, or no-show. The system must prevent conflicting bookings. The same space cannot have two approved bookings with overlapping time periods. A space that is under maintenance, closed, or retired cannot be booked.
A booking request may require approval from a facility staff member or manager. When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note. If the booking is rejected, the rejection reason should be stored.
When the requester arrives, facility staff can check in the booking. The system records the actual start time, the person who checked in the booking, and the initial condition of the space. When the session ends, facility staff can complete the booking by recording the actual end time, the final condition of the space, and any usage notes.
The system also supports basic maintenance management. A space may have maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems. Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note. A space under maintenance cannot be booked.
The system should keep historical records of bookings and maintenance activities. Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings.
The main goal of the system is to help the School manage shared campus spaces fairly, avoid overlapping bookings, prevent the use of unavailable spaces, and preserve usage history.



