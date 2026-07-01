---
name: 01-business-req-analysis
description: Analyse business requirements into a structured conceptual analysis covering actors, entities, relationships, business rules, assumptions, open questions, and traceability.
compatibility: opencode
---

# Step 1: Business Requirement Analysis Skill

When executing this skill, generate the analysis document with the following structure and quality bar. This skill is a **quality rubric and behaviour guide**, not a fixed answer. The output should be derived from the source requirements, guided by these rules.

## Output Structure

The document `outputs/01-business-req-analysis-G08.md` should contain these sections:

### 1. Business Purpose and Problem Statement

- Explain that the School of Computer Science wants to replace its manual space management process with a centralized database system.
- Describe the current manual process (emails, phone calls, spreadsheets) and its problems.
- State the goal: manage space bookings, approvals, usage tracking, maintenance, and facility utilization.

### 2. Identified Actors / User Roles

Must cover these six roles, each with their responsibilities as described in the official requirement:

- **Student** — request spaces for approved student activities and academic projects.
- **Lecturer** — request spaces for lectures, seminars, workshops, and examinations.
- **Teaching Assistant** — request or manage spaces for classes, labs, and tutorials.
- **Facility Staff** — review and approve/reject booking requests; manage check-ins and check-outs; handle maintenance records.
- **Department Administrator** — view operational data and manage bookings for department-level events.
- **Facility Manager** — high-level administrative control over spaces, policies, approvals, maintenance workflows, and system-wide reports.

### 3. Identified Entities and Attributes

Cover at least these required conceptual entities when supported by the source requirements. List conceptual attributes only — **no SQL types, no indexes, no physical FK columns**.

- **Department:** a normalized, first-class entity. Attributes: Home ID, department name.
- **UserAccount:** stores user profile data. Attributes: Home ID, email, full name, phone number, role, account status, created_at, updated_at. Link to Department via relationship, not by attribute.
- **Space:** represents a bookable room. Attributes: Home ID, space code, space name, space type, building, floor, room number, capacity, current status, usage policy, created_at, updated_at.
- **Facility:** master catalogue of equipment. Attributes: Home ID, facility name, description.
- **SpaceFacility (Junction):** resolves M-N between Space and Facility. Attributes: quantity, condition, note.
- **Booking:** the core transactional entity. Attributes: Home ID, requested start/end time, purpose, expected participants, booking type, status, cancelled_at, cancel_reason, created_at, updated_at. Links to UserAccount and Space via relationships.
- **BookingDecision:** records an approval or rejection event. Attributes: Home ID, decision, decision time, decision note, rejection reason. Must be 1-N with Booking to preserve full audit/decision history. Links to Booking and UserAccount via relationships.
- **UsageSession:** tracks actual use of a space. Attributes: Home ID, actual start time, initial condition, actual end time, final condition, usage notes. Links to Booking and UserAccount via relationships.
- **MaintenanceRecord:** documents a maintenance issue. Attributes: Home ID, problem description, problem category, start time, completion time, status, result note, created_at, updated_at. Links to Space and UserAccount via relationships.

**Mandatory attribute coverage:**
- Core entities (UserAccount, Space, Booking, MaintenanceRecord) must include `created_at` and `updated_at` as traceability metadata.
- Booking must cover `booking_type`, `cancelled_at`, `cancel_reason`.
- MaintenanceRecord must cover `problem_category`.
- SpaceFacility must cover `note`.

**Conceptual purity rules:**
- **Home IDs:** Identifiers such as `user_id`, `space_id`, `booking_id`, `decision_id`, `session_id`, `maintenance_id`, `department_id`, `facility_id` are conceptual Home IDs belonging only inside their defining entity. They are NOT physical PK declarations — that comes in Step 3.
- **Home ID vs. Visitor ID:** Identifiers belong ONLY inside their defining entity box. Relationship lines represent connections; FK columns start only in Step 3.
- **Contextual Identifier Rule:** Stable entities (Space) keep both system ID and business code. Transactional entities (Booking, MaintenanceRecord) keep only system ID.
- **Conceptual Attribute Filter:** Only include an ID if it is the Home ID for that entity. IDs used to link to other entities (Visitor IDs / future FKs) are EXCLUDED.

### 4. Identified Relationships

Document all relationships conceptually — no FK columns. The following must be covered. **Each relationship must be stated bidirectionally** — both directions (parent-to-child and child-to-parent) must be explicitly described, not just one side.

The following are the minimum required relationships. State each bidirectionally:

- UserAccount ↔ Department: N:1 (a User belongs to one Department; a Department has many Users)
- UserAccount ↔ Booking: 1:N (a User requests many Bookings; each Booking is requested by one User)
- UserAccount ↔ BookingDecision: 1:N (a User acting as staff makes many Booking Decisions; each Booking Decision is made by one User)
- Space ↔ Booking: 1:N (a Space is for many Bookings; each Booking is for one Space)
- Space ↔ Facility (via SpaceFacility junction): M:N
- Booking ↔ BookingDecision: 1:N (preserves full audit/decision history)
- Booking ↔ UsageSession: 1-to-0..1 (a Booking may result in at most one Usage Session)
- UserAccount ↔ UsageSession (checks in): 1:N (a User checks in many Usage Sessions; each Usage Session is checked in by one User)
- UserAccount ↔ UsageSession (completes): 1:N (a User completes many Usage Sessions; each Usage Session is completed by one User)
- Space ↔ MaintenanceRecord: 1:N (a Space undergoes many Maintenance Records; each Maintenance Record is for one Space)
- UserAccount ↔ MaintenanceRecord (reports): 1:N (a User reports many Maintenance Records; each Maintenance Record is reported by one User)
- UserAccount ↔ MaintenanceRecord (is assigned): 1:N (a User is assigned to many Maintenance Records; each Maintenance Record has one assigned User)

### 5. Process-Oriented Sub-Sections

Consider including sub-sections that explain each business process:

**A. Booking Request Lifecycle**
- Describe the lifecycle: Pending → Approved/Rejected; Approved → Checked In → Completed or No-show.
- Mention that cancelled bookings store a timestamp and reason.

**B. Approval Workflow**
- Describe that booking approval/rejection stores the deciding staff member, decision time, decision note, and rejection reason.
- Note that a booking may have multiple decisions over its lifecycle (1-N audit trail).

**C. Usage Session / Check-in & Check-out**
- Describe check-in: records actual start time, checked-in-by staff, and initial condition.
- Describe check-out/completion: records actual end time, final condition, and usage notes.

**D. Maintenance Management**
- Describe that a space may have maintenance records.
- Note the attributes: space, reporter, assigned staff, problem description, problem category, start/completion time, status, result note.
- Note that a space with active maintenance becomes unavailable for booking.

### 6. Identified Business Rules and Constraints

Must include the two critical business rules verbatim:

1. **No Overlapping Approved Bookings:** The same space cannot have two **approved** bookings with overlapping time periods.
2. **No Booking Unavailable Spaces:** A space that is **under maintenance, temporarily closed, or retired** cannot be booked.

Additional business rules beyond the two critical ones must be documented as supported by the requirement. **At minimum, the following must be stated explicitly:**

3. **Booking Lifecycle:** Bookings follow a distinct lifecycle (Pending → Approved/Rejected; Approved → Checked In → Completed or No-show). Cancelled bookings store a timestamp and reason.
4. **Approval Documentation (Decision Audit Trail):** Every booking approval or rejection stores the deciding staff member, decision time, decision note, and a rejection reason when the booking is rejected.
5. **Check-in Tracking:** Check-in records the actual start time, the staff member who checked it in, and the initial condition of the space.
6. **Check-out / Completion Tracking:** Check-out records the actual end time, the final condition of the space, and usage notes.
7. **Data Preservation:** Historical booking and maintenance records must be preserved (staff can view history, upcoming bookings, spaces under maintenance, and no-show bookings).

For each rule (including the two critical ones), **classify** it in a traceability matrix as one of:

- **Explicit** — stated verbatim in the official requirement.
- **Inferred** — strongly implied by the domain logic but not stated explicitly.
- **Assumption** — a conservative design choice made by the team.
- **Design Convention** — a metadata or structural convention adopted for consistency (e.g., timestamp columns on core entities).

### 7. Assumptions and Open Questions

Document conservative assumptions and open questions drawn from the source requirements. Examples:
- Assumptions: all users pre-registered; Department externally managed but normalized; overlapping defined as start1 < end2 AND start2 < end1; a booking refers to one space; facilities are a shared catalogue.
- Open questions: no-show policy, auto-approval policies, recurring bookings, capacity checking rule, cancellation actors.

### 8. Traceability Notes and Classification Matrix

Provide a concise traceability matrix linking major rules to their source and classification. Example format:

| Rule | Source | Classification |
|---|---|---|
| No overlapping approved bookings | Critical business rule | Explicit |
| Space under maintenance cannot be booked | Critical business rule | Explicit |
| Users have university accounts with account_status | Stakeholders section | Explicit |
| Only active users may submit bookings | (inferred) | Assumption / Access-control |
| Expected participants vs capacity check | Open question in requirement | Inferred / Open question |
| created_at/updated_at on core entities | SKILL.md metadata rule | Design Convention |

## Domain Requirements

- The entire analysis must stay conceptual / business-level.
- No SQL Server data types, `IDENTITY`, `FK`, `PK`, index, or DDL references.
- No physical FK columns as attributes — linking is described via relationships.
- Department must be a normalized, first-class entity (not an attribute of UserAccount).
- BookingDecision must be 1-N with Booking to preserve decision history.
- Avoid presenting inferred/assumed rules as if they came verbatim from the requirement.

## Validation Checklist

After writing, verify:
- [ ] All six roles appear with responsibilities.
- [ ] All required entities appear with conceptual attributes only.
- [ ] No SQL data types or FK/PK markers anywhere.
- [ ] The two critical business rules are stated verbatim.
- [ ] BookingDecision is 1-N with Booking.
- [ ] Booking-to-UsageSession is 1-to-0..1.
- [ ] All three UserAccount-to-Session relationships are documented (checks in, completes, reports/assigned for maintenance).
- [ ] UserAccount makes BookingDecision relationship is documented, **stated bidirectionally**: A User makes many Booking Decisions, AND each Booking Decision is made by one User.
- [ ] Every relationship in §4 is stated **bidirectionally** (both directions for each pair).
- [ ] Check-in tracking is documented as an explicit business rule in §6 (actual start time, who checked in, initial condition).
- [ ] `created_at` and `updated_at` appear on UserAccount, Space, Booking, MaintenanceRecord.
- [ ] `booking_type`, `cancelled_at`, `cancel_reason` are covered in Booking.
- [ ] `problem_category` is covered in MaintenanceRecord.
- [ ] `note` is covered in SpaceFacility.
- [ ] Department is a separate normalized entity.
- [ ] Assumptions and open questions are recorded.
- [ ] Traceability notes are present.
- [ ] Classification of rules (Explicit / Inferred / Assumption / Design Convention) is provided.
- [ ] No inferred/assumed rules are presented as if they were explicit requirements.
- [ ] Capacity rule is classified as inferred/open question, not a firm business rule.
- [ ] Active-account wording is softened — requirement states account_status exists, not that only active users may act.

## Common Mistakes to Avoid

**Visitor ID leaks (FORBIDDEN in Step 1):**
- Do NOT include `department_id` as an attribute of UserAccount (handled by relationship line).
- Do NOT include `requester_id` or `space_id` as attributes of Booking (handled by relationship lines).
- Do NOT include `booking_id` or `decided_by` as attributes of BookingDecision (handled by relationship lines).
- Do NOT include `booking_id`, `checked_in_by`, or `completed_by` as attributes of UsageSession (handled by relationship lines).
- Do NOT include `space_id`, `reporter_id`, or `assigned_staff_id` as attributes of MaintenanceRecord (handled by relationship lines).
- Do NOT include `space_id` or `facility_id` as attributes of SpaceFacility (handled by relationship lines).

**Other mistakes:**
- Using SQL data type names in attribute lists.
- Treating Department as a simple field on UserAccount instead of a normalized entity.
- Modelling BookingDecision as 1-1 with Booking (must be 1-N for audit trail).
- Forgetting `created_at`/`updated_at` on core entities.
- Presenting "expected participants must not exceed capacity" as an explicit business rule (it is an open question in the requirement).
- Presenting "all users must be active" as an explicit requirement (the requirement says users have account_status; active-only behaviour is an access-control assumption).