---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, validation, DDL, sample data, and query design step by step.
compatibility: opencode
---

# Database Design Pipeline Skill

Use this skill when the user asks to transform business requirements into a database design.

## Important Behavior

Before assuming anything, inspect the project:

1. Run `ls -la`.
2. Locate requirement files under `req/`, or files passed by the user.
3. Read the relevant requirement files fully before designing.
4. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.

## Sources of Truth

Read these and prefer them in this order when details conflict:

1. `CS486_Project.pdf` — official requirement (deliverable list and Query Design format), if readable.
2. `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` — detailed specification (entities, attributes, relationships, business rules, validation logic, example queries).
3. The requirement file passed by the user (usually `req/business-requirement.md`).

Write all content in English only. Do not invent the group number or student names; keep `GXX` until the group sets it.

## Required Output Files

Create or update the following files in `outputs/`:

1. `outputs/01-business-req-analysis-GXX.md`
2. `outputs/02-erd-design-GXX.md`
3. `outputs/03-logical-design-GXX.md`
4. `outputs/04-design-validation-GXX.md`
5. `outputs/05-db-definition-GXX.sql`
6. `outputs/06-sample-data-GXX.sql`
7. `outputs/07-query-design-GXX.sql`

Replace `GXX` with the group number (e.g., `G01`).

Do not skip any file.

## Domain Coverage (applies to all steps)

The design must explicitly handle the Campus Space Management System domain. Across the deliverables, ensure the following are represented:

- **Users and university accounts**: user ID, full name, email, phone, role, department, account status. Every user has a university account.
- **User roles and account status**: student, lecturer, teaching assistant, facility staff, department administrator, facility manager; account status (e.g. active/inactive).
- **Spaces and space statuses**: space code, name, type, building, floor, room number, capacity, usage policy; status of available, in use, under maintenance, temporarily closed, or retired.
- **Facilities per space**: many-to-many between spaces and facilities (e.g. projector, whiteboard, microphone, computer, livestreaming equipment, air conditioner).
- **Booking request lifecycle**: space, requested start/end time, purpose, expected participants; status of pending, approved, rejected, cancelled, checked in, completed, or no-show.
- **Approval/rejection metadata**: deciding staff member, decision time, decision note; and a **rejection reason** when the booking is rejected.
- **Check-in/check-out actual usage sessions**: actual start time, actual end time, checked-in-by staff, initial condition, final condition, and usage notes.
- **Maintenance records**: related space, reporter, assigned staff member, problem description, start time, completion time, status, result note.
- **Historical records**: preserve booking and maintenance history so staff can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings.

Critical business rules that the design MUST enforce:

1. The same space cannot have two **approved** bookings with overlapping time periods.
2. A space that is **under maintenance, temporarily closed, or retired** cannot be booked.

---

## Step 1: Business Requirement Analysis

Save to:

`outputs/01-business-req-analysis-GXX.md`

The document must include:

- The business purpose and problem statement.
- Identified actors / user roles and their responsibilities.
- Identified entities with attributes.
- Identified relationships and their cardinalities.
- Identified business rules and constraints (including the two critical booking rules above).
- Explicitly recorded assumptions.
- Explicitly recorded open questions.
- Traceability notes linking requirements to entities.

---

## Step 2: Conceptual ERD Design

The ERD must be based on Step 1.

Save to:

`outputs/02-erd-design-GXX.md`

The document must include:

- A Mermaid `erDiagram` diagram using Crow's Foot notation.
- Entity definitions with attributes and primary keys.
- Relationship definitions with cardinality (one-to-one, one-to-many, many-to-many).
- Participation constraints (mandatory vs. optional).
- Foreign key indications.
- A narrative explanation of key design decisions.

---

## Step 3: Logical Database Design

The logical design must be based on Step 2.

Save to:

`outputs/03-logical-design-GXX.md`

The document must include:

- A table-by-table mapping from ERD entities into a relational schema.
- Column names, data types, nullability, and default values.
- Primary keys, candidate keys, and unique constraints.
- Foreign key definitions referencing parent tables.
- Key constraints and check constraints.
- Index recommendations.

---

## Step 4: Design Validation

The validation must be based on Step 3.

Save to:

`outputs/04-design-validation-GXX.md`

The document must include:

- Verification that the relational schema correctly represents the ERD.
- Verification that all business rules from Step 1 are addressed.
- Normalization check (at least 3NF).
- Overlap conflict prevention logic validation (no two approved overlapping bookings for the same space).
- Status-based booking prevention validation (cannot book under-maintenance / closed / retired spaces).
- Referential integrity validation.
- Any identified design issues and their resolutions.

---

## Step 5: Database Definition (DDL)

The DDL must be based on Step 3.

Save to:

`outputs/05-db-definition-GXX.sql`

The file must include:

- `CREATE TABLE` statements for all tables.
- All primary key, foreign key, unique, check, and default constraints.
- Columns capturing approval/rejection metadata (deciding staff, decision time, decision note, rejection reason).
- Columns capturing usage sessions (actual start/end time, checked-in-by staff, initial/final condition, usage notes).
- Columns capturing maintenance records (reporter, assigned staff, problem description, start/completion time, status, result note).
- Constraints/mechanisms that support the two critical booking rules.
- `CREATE INDEX` statements for recommended indexes.
- Comments explaining non-obvious constraints.

Use Microsoft SQL Server syntax unless the user specifies another DBMS.

---

## Step 6: Sample Data

The sample data must be based on the DDL from Step 5.

Save to:

`outputs/06-sample-data-GXX.sql`

The file must include `INSERT INTO` statements covering normal and exceptional cases:

- Users with all roles and varied account statuses.
- Spaces with all statuses.
- Facilities and space-facility mappings.
- Bookings with various statuses (pending, approved, rejected, cancelled, checked in, completed, no-show).
- Overlapping booking scenarios (for testing the conflict rule).
- Approvals/rejections with decision metadata and rejection reasons.
- Usage sessions with actual times and condition notes.
- Maintenance records with various statuses.
- Enough data to run all queries from Step 7.

---

## Step 7: Query Design

The query design must be based on the DDL and sample data from prior steps.

Save to:

`outputs/07-query-design-GXX.sql`

This file must contain **at least 5** meaningful SQL queries that are valid for the database and useful for answering business questions in this context.

**For EACH query, include exactly these four sections (as SQL comments above the statement), in this order:**

1. `-- Business question:` — the business question the query answers.
2. `-- Target user(s):` — who would use this query (e.g. facility staff, manager, department admin).
3. `-- Why this query is useful:` — a short explanation of its value.
4. The SQL statement itself.

The queries should support real operational needs for staff/manager use, for example: upcoming approved bookings, pending approvals, overlapping-booking detection, spaces under maintenance, no-show bookings, space utilization summary, maintenance summary by space, booking history for a user, and spaces with specific facilities. Add any additional queries relevant to the business requirements.

---

## DBMS

Use Microsoft SQL Server syntax unless the user specifies another DBMS.

## Design Rules

- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement -> entity -> relationship -> table -> constraint.
- Use Mermaid `erDiagram` for ERD.
- Do not silently invent business rules.
- Do not invent the group number or student names.
- Keep all content English only.
