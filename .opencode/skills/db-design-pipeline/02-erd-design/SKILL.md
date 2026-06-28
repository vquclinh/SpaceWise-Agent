---
name: 02-erd-design
description: Transform the business requirement analysis into a conceptual Crow's Foot ERD diagram using Mermaid, with narrative explanation and design decisions.
compatibility: opencode
---

# Step 2: Conceptual ERD Design Skill

When executing this skill, the agent must derive the conceptual ERD from the current source of truth. This skill is an **evolving quality rubric and behaviour guide**, not a hard-coded ERD answer. The ERD content comes from reading `outputs/01-business-req-analysis-G08.md` — do not paste a fixed answer from the skill.

## 1. Purpose

Step 2 transforms the Step 1 Business Requirement Analysis into a conceptual Entity-Relationship Diagram. The output must show main entities, attributes, relationships, cardinalities, and participation constraints — as required by the official project specification.

This step is purely conceptual. It must NOT finalize a logical schema or SQL implementation.

## 2. Required Inputs

- `outputs/01-business-req-analysis-G08.md` — **primary authority** (immediate previous step output). All entities, attributes, relationships, and business rules defined there are binding input for the ERD.
- `AGENTS.md` — project-wide constraints: source-of-truth order (§2), Step Precedence Rule, Mermaid ERD rendering rules, Home ID vs. Visitor ID, Lifecycle & Optionality Rule (§3).
- `.opencode/skills/db-design-pipeline/SKILL.md` — shared pipeline rules and Step 2 quality checklist.

## 3. Required Output Structure

The output `outputs/02-erd-design-G08.md` should contain:

- **ERD Diagram** — a Mermaid `erDiagram` with Crow's Foot notation.
- **Narrative Explanation:**
  - Entity descriptions (purpose, Home ID, which links are via relationship lines).
  - Relationship/cardinality/participation table (one row per Mermaid line).
  - Design decisions.
  - Consistency notes with Output 01.
- **Diagram readability notes** if needed (label overlap, layout issues, workarounds).

## 4. Conceptual ERD Rules

- Use Mermaid `erDiagram` with Crow's Foot notation.
- Entity boxes should use a simple format.
- Use `attr` as the placeholder type for all attributes (required by Mermaid syntax).
- **No SQL Server data types** (`int`, `nvarchar`, `datetime2`, etc.).
- **No DDL, indexes, or physical implementation details.**
- **No PK or FK markers** in entity boxes.
- **No FK column names as relationship labels** in Step 2.
- Relationship labels should be short descriptive verbs or nouns (e.g., "has", "requests", "is for"), not FK column names. FK column name labels start only in Step 3.

## 5. Entity and Attribute Derivation Rules

Entities and attributes must be derived from `outputs/01-business-req-analysis-G08.md`. Do not paste a fixed ERD answer into the skill.

**Coverage checklist:** At minimum, verify the ERD covers the required conceptual entities identified in Output 01 — typically including:

- Department
- UserAccount
- Space
- Facility
- SpaceFacility (junction)
- Booking
- BookingDecision
- UsageSession
- MaintenanceRecord

This list is a coverage guide, not a static answer. The agent must read Output 01 and preserve its latest entity and attribute decisions.

**Attribute rules:**
- Include conceptual attributes exactly as listed in Output 01 for each entity.
- Core metadata such as `created_at` and `updated_at` should appear on core entities if Output 01 treats them as conceptual traceability metadata (UserAccount, Space, Booking, MaintenanceRecord).
- Attributes specific to this domain must be present: `booking_type`, `cancelled_at`, `cancel_reason` on Booking; `problem_category` on MaintenanceRecord; `note` on SpaceFacility.

## 6. Home ID vs. Visitor ID Rules

- **Home IDs** such as `user_id`, `space_id`, `booking_id`, `decision_id`, `session_id`, `maintenance_id`, `department_id`, `facility_id` are conceptual identifiers belonging ONLY inside their defining entity box.
- These Home IDs are NOT physical PK declarations in Step 2. Do not mark them as PK.
- **Visitor IDs** / FK-style linking attributes must NOT appear in Step 2 entity boxes. Relationship lines handle all connections.

**Forbidden Visitor ID placements:**

| Entity | Must NOT include |
|---|---|
| UserAccount | `department_id` |
| Booking | `requester_id`, `space_id` |
| BookingDecision | `booking_id`, `decided_by` |
| UsageSession | `booking_id`, `checked_in_by`, `completed_by` |
| MaintenanceRecord | `space_id`, `reporter_id`, `assigned_staff_id` |
| SpaceFacility | `space_id`, `facility_id` |

## 7. Relationship and Participation Rules

- All major relationships from Output 01 must be represented as Crow's Foot lines.
- Every relationship must have cardinality and participation constraints stated.
- Use lifecycle start-from-zero (`o{`, `o|`) for the "many" side unless Output 01 gives a strict business reason for mandatory participation.
- All "one" parent sides should use mandatory notation (`||`) unless there is a specific business reason otherwise.

**Required relationships to represent:**
- Department ||--o{ UserAccount
- UserAccount ||--o{ Booking
- UserAccount ||--o{ BookingDecision
- Space ||--o{ Booking
- Booking ||--o{ BookingDecision (1-N for audit history)
- Booking ||--o| UsageSession (1-to-0..1)
- UserAccount ||--o{ UsageSession (checks in)
- UserAccount ||--o{ UsageSession (completes)
- Space ||--o{ SpaceFacility
- Facility ||--o{ SpaceFacility
- Space ||--o{ MaintenanceRecord
- UserAccount ||--o{ MaintenanceRecord (reports)
- UserAccount ||--o{ MaintenanceRecord (is assigned)

**Double-role relationships:** When the same entity pair has multiple distinct roles (e.g., UserAccount ↔ UsageSession for both checking in and completing), draw two separate relationship lines with distinct labels.

**Junction handling:** Space and Facility must connect through the SpaceFacility junction — do not draw a direct M-N line between Space and Facility.

## 8. Narrative Consistency Rules

- The relationship table must have exactly the same number of rows as the Mermaid diagram has relationship lines.
- Each Crow's Foot line must have a corresponding explanation in the relationship table.
- For junction entities: describe the relationship as 1-N between the master entity and the junction table, not as a logical M-N between master entities. The conceptual M-N can be acknowledged in narrative text.
- Do not describe a relationship that contradicts what the diagram shows (e.g., do not describe M-N if the diagram uses two 1-N lines to a junction).

## 9. Diagram Readability Rules

Mermaid `erDiagram` can produce layout where relationship labels overlap, become hidden, or are truncated.

**If a relationship label becomes unreadable in the rendered output:**
- Prefer shorter labels in the diagram (e.g., `"session"` instead of `"results in"`).
- Put the full semantic explanation in the relationship table/narrative.
- If the full diagram becomes too dense, consider a small focused detail diagram for the most complex subgraph.
- Do NOT change the schema logic (entities, cardinalities, participation) just to fix a diagram rendering issue.

**Known label issue — Booking-to-UsageSession:** The label `"results in"` or `"session"` on the `Booking ||--o| UsageSession` line may be hidden or overlapped by Mermaid's default layout. A short label such as `"session"` is acceptable in Step 2, as long as the relationship table clearly explains "one booking may result in zero or one usage session."

## 10. Validation Checklist

After writing the ERD, verify:
- [ ] All main entities from Output 01 are represented in the diagram.
- [ ] All conceptual attributes from Output 01 are included in their entity boxes.
- [ ] No SQL Server data types (`int`, `nvarchar`, `datetime2`, etc.) anywhere.
- [ ] No PK or FK markers in entity boxes.
- [ ] No Visitor ID attributes in any entity box (see forbidden list in section 6).
- [ ] All major relationships from Output 01 are represented as Crow's Foot lines.
- [ ] Cardinalities are stated for every relationship.
- [ ] Participation constraints are stated (all "many" sides use optional; all "one" sides use mandatory).
- [ ] BookingDecision is 1-N with Booking (`||--o{`, not `||--||`).
- [ ] Booking-to-UsageSession is 1-to-0..1 (`||--o|`).
- [ ] Space and Facility connect through SpaceFacility junction (not a direct M-N line).
- [ ] The narrative relationship table has exactly as many rows as the diagram has lines.
- [ ] `created_at` and `updated_at` appear on UserAccount, Space, Booking, MaintenanceRecord.
- [ ] `booking_type`, `cancelled_at`, `cancel_reason` appear in Booking.
- [ ] `problem_category` appears in MaintenanceRecord.
- [ ] `note` appears in SpaceFacility.
- [ ] Relationship labels are readable in the rendered diagram, or a readability workaround is documented.

## 11. Common Mistakes to Avoid

- **Pasting a fixed Mermaid diagram** without reading Output 01 — the skill is a rubric, the ERD answer comes from the source of truth.
- **Adding FK columns** as attributes in Step 2 entity boxes (e.g., `requester_id` in Booking, `department_id` in UserAccount).
- **Using SQL Server data types** (`int`, `nvarchar`, `datetime2`) anywhere in the conceptual ERD.
- **Marking PK or FK** on attributes inside entity boxes.
- **Drawing a direct M-N line** between Space and Facility instead of going through SpaceFacility.
- **Forgetting participation constraints** — every relationship needs both cardinality and participation.
- **Modelling BookingDecision as 1-1** with Booking — must be 1-N for audit history.
- **Silently changing decisions** from Output 01 (entity names, attributes, relationships).
- **Ignoring Mermaid readability issues** — if labels overlap or are hidden, document the workaround.
- **Using `||--||` (mandatory both sides)** or `|o--o|` (optional on parent)** — violates lifecycle start-from-zero and parent-child integrity.
- **Having fewer or more rows in the narrative relationship table** than there are lines in the Mermaid diagram.