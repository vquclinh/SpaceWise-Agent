# Step 2: Conceptual ERD Design for G08

This document presents the conceptual Entity-Relationship Diagram (ERD) for the Campus Space Management System. The design is based on entities, attributes, and relationships identified in `01-business-req-analysis-G08.md`. Per the project rules, this step is purely conceptual: attributes are descriptors only, no physical data types or foreign keys appear, and identifying attributes use business identifiers (not surrogate keys).

## 1. ERD Diagram

The following diagram uses Mermaid syntax with Crow's Foot notation. Identifying attributes are marked with `PK` for notation purposes only; they represent business identifiers, not physical primary keys.

```mermaid
erDiagram
    Department {
        department_code PK
        department_name
    }

    UserAccount {
        email PK
        full_name
        phone_number
        role
        account_status
    }

    Space {
        space_code PK
        space_name
        space_type
        building
        floor
        room_number
        capacity
        current_status
        usage_policy
    }

    Facility {
        facility_name PK
        description
    }

    SpaceFacility {
        quantity
        condition
        note
    }

    Booking {
        booking_code PK
        requested_start_time
        requested_end_time
        purpose
        expected_participants
        booking_type
        status
        cancelled_at
        cancel_reason
    }

    BookingDecision {
        decision_id PK
        decision
        decision_time
        decision_note
        rejection_reason
    }

    UsageSession {
        session_id PK
        actual_start_time
        initial_condition
        actual_end_time
        final_condition
        usage_notes
    }

    MaintenanceRecord {
        maintenance_code PK
        problem_description
        problem_category
        status
        start_time
        completion_time
        result_note
    }

    Department ||--o{ UserAccount : "has"
    UserAccount ||--o{ Booking : "requests"
    Space ||--o{ Booking : "is for"
    Booking ||--o{ BookingDecision : "has"
    UserAccount ||--o{ BookingDecision : "makes"
    Booking ||--o| UsageSession : "results in"
    UserAccount ||--o{ UsageSession : "checks in"
    UserAccount ||--o{ UsageSession : "completes"
    Space ||--o{ SpaceFacility : "is junction for"
    Facility ||--o{ SpaceFacility : "is junction for"
    Space ||--o{ MaintenanceRecord : "undergoes"
    UserAccount ||--o{ MaintenanceRecord : "reports"
    UserAccount ||--o{ MaintenanceRecord : "is assigned"
```

## 2. Narrative Explanation

### Entities

- **Department**: Represents a university department. It is modeled as a mandatory, normalized entity. A department may initially have zero users (lifecycle start-from-zero). Identifying attribute: `department_code` (e.g., "CS", "EE").

- **UserAccount**: Stores information about a system user. Every user belongs to a department and has a university account. Identifying attribute: `email` (a natural business identifier, not a surrogate user_id).

- **Space**: Represents a physical bookable room or area on campus. Identifying attribute: `space_code` (e.g., "B1-101"), not a surrogate space_id.

- **Facility**: A master list of available equipment types or features. Identifying attribute: `facility_name` (e.g., "Projector", "Whiteboard").

- **SpaceFacility**: A junction entity resolving the many-to-many relationship between Space and Facility. It carries descriptive attributes (quantity, condition, note) but no identifying attribute of its own — its identity is derived from the two connected entities. In the Mermaid diagram, the junction side (`SpaceFacility`) is mandatory while the master entity sides are optional, reflecting that a junction record always requires both a space and a facility.

- **Booking**: The core entity representing a request to use a space. It captures all request details, timing, purpose, status, and cancellation metadata. Identifying attribute: `booking_code` (a reference number assigned to each booking request).

- **BookingDecision**: Records an approval or rejection event for a Booking. The 1-N relationship with Booking preserves a full audit trail (a booking may be rejected then re-evaluated). Identifying attribute: `decision_id`, which is semantically a decision sequence number within the booking context.

- **UsageSession**: Tracks the actual use of a space for a Booking, from check-in to completion. It has a 1-to-0..1 relationship with Booking — a booking may never result in a session (e.g., if cancelled or a no-show), but a session cannot exist without a booking. Identifying attribute: `session_id`.

- **MaintenanceRecord**: Documents a maintenance issue for a specific Space. Identifying attribute: `maintenance_code` (a maintenance ticket reference number).

### Relationships (with Cardinality and Participation)

All relationships use **optional notation for the "many" side** per the lifecycle start-from-zero rule: entities start with zero dependent records.

| Left Entity | Relationship | Right Entity | Explanation |
|---|---|---|---|
| Department | 1 -- 0..N | UserAccount | A department exists independently and may have zero users initially. |
| UserAccount | 1 -- 0..N | Booking | A user may request zero or many bookings over time. |
| Space | 1 -- 0..N | Booking | A space may have zero bookings (e.g., newly created space). |
| Booking | 1 -- 0..N | BookingDecision | A booking may have zero decisions (still pending) or multiple decisions (audit trail). |
| UserAccount | 1 -- 0..N | BookingDecision | A staff member may make zero or many booking decisions. |
| Booking | 1 -- 0..1 | UsageSession | A booking may never produce a usage session (cancelled/no-show). Mandatory on the UsageSession side: each session belongs to exactly one booking. |
| UserAccount | 1 -- 0..N | UsageSession | A user may check in (or complete) zero or many sessions. |
| Space | 1 -- 0..N | SpaceFacility | A space may have zero or many facility entries. |
| Facility | 1 -- 0..N | SpaceFacility | A facility may be listed in zero or many spaces. |
| Space | 1 -- 0..N | MaintenanceRecord | A space may have zero or many maintenance records over time. |
| UserAccount | 1 -- 0..N | MaintenanceRecord | A user may report zero or many maintenance issues and be assigned to zero or many records. |

### Design Decisions

- **Business identifiers over surrogate keys**: At the conceptual level, entities are identified by meaningful business fields (e.g., `department_code`, `email`, `space_code`, `facility_name`, `booking_code`). Surrogate auto-increment IDs belong in Step 3 (Logical Design) and are intentionally absent here.

- **No foreign key markers**: Relationships are represented solely through notation lines. Foreign key columns (e.g., `department_id` in UserAccount) are a logical/physical implementation detail and do not appear at this stage.

- **No physical data types**: Attribute names are listed as pure descriptors (e.g., `full_name`, `capacity`, `status`) without `int`, `string`, `datetime`, or similar type annotations.

- **Optionality for lifecycle start-from-zero**: All "one" sides use mandatory notation (`||`) because those entities exist independently; all "many" and "zero-or-one" sides use optional notation (`o{` or `o|`) to reflect that dependent records accumulate over time and may start at zero.

- **Junction entity participation**: The `SpaceFacility` junction is treated as mandatory on the junction side (a junction record always requires both participating entities) but optional on the master entity sides (a space may have no facilities listed; a facility may not yet be installed in any space).

- **Booking-to-UsageSession as 1-to-0..1**: A booking produces at most one actual usage session, and a session cannot exist without a booking. This models the real-world constraint that check-in/check-out data is optional (a booking may be cancelled or result in a no-show).

- **BookingDecision 1-N for history**: Booking decision history is preserved via a one-to-many relationship, allowing a booking to be rejected and later approved, with each decision timestamped and attributed.
