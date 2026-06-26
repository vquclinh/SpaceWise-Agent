# Audit — Establish Step Precedence and Fix Narrative

> Date: 2026-06-25
> Operator/member: Trương Thị Mỹ Duyên and Huỳnh Lê Bảo Thi
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free (via OpenCode)
> OpenCode command used: `/refine-output outputs/02-erd-design-G08.md`

## Task goal

Formalise the Step Precedence Rule in AGENTS.md, add a narrative accuracy requirement to SKILL.md, then apply both rules to refine the conceptual ERD. Specifically:

1. Add **Step Precedence Rule** to AGENTS.md Section 2: the immediate previous-step output is the primary authority; Project Spec fills in domain details but must not contradict prior decisions.
2. Add a **narrative accuracy requirement** to SKILL.md Step 2: relationship explanations must match Mermaid diagram lines exactly (e.g., describe 1-N to a junction table, not the logical M-N between master entities).
3. Apply both rules to `02-erd-design-G08.md` — align attribute naming and structure with Output 01, and fix the relationship narrative to match the diagram lines.

## Files created / changed

- **Modified:** `AGENTS.md` — added Step Precedence Rule in Section 2.
- **Modified:** `.opencode/skills/db-design-pipeline/SKILL.md` — added narrative accuracy requirement to Step 2.
- **Modified:** `outputs/02-erd-design-G08.md` — refined ERD diagram and narrative.
- **Created:** `audits/13-establish-step-precedence-and-fix-narrative.md` (this file).

## What was evaluated

- Whether the Step Precedence Rule is correctly stated and placed in AGENTS.md.
- Whether the SKILL.md requirement correctly mandates narrative-to-diagram alignment.
- Whether the ERD diagram and narrative are consistent with Output 01 (the immediate previous step).
- Whether the narrative describes relationships as they appear in the Mermaid diagram lines (not as logical abstractions).

## Issues found

1. **AGENTS.md Section 2** had no rule about step precedence — the ERD could freely deviate from decisions made in Output 01.
2. **SKILL.md Step 2** had no requirement for narrative-to-diagram alignment — the narrative could describe logical M-N relationships while the diagram shows 1-N connections to a junction table.
3. **02-erd-design-G08.md** had two inconsistencies with Output 01:
   - `Department` used `department_code` instead of `department_id` as its identifying attribute (Output 01 uses `department_id`).
   - `UserAccount` included `attr department` as a direct attribute, contradicting Output 01's decision that Department is a separate entity with a relationship link.
4. The narrative's relationship table was already correct (describing 1-N to junction tables), but the entity descriptions and design decisions section were not explicitly checked against the diagram lines.

## Changes made

### AGENTS.md — Section 2 (Source-of-truth order)

- Added **Step Precedence Rule**: "When working on a new step, the output of the immediate previous step (e.g., Output 01 for Step 2) is the primary authority. Use the Project Spec to fill in domain details, but never contradict the decisions finalized in the previous step."

### SKILL.md — Step 2

- Added narrative accuracy requirement: "The relationship explanation in the narrative must strictly match the lines drawn in the Mermaid diagram. For example, if an entity is connected to a Junction Table, describe the relationship to that Junction Table (1-N), not the logical M-N connection between master entities."

### 02-erd-design-G08.md (refined)

- **Department attribute**: Changed `department_code` → `department_id` to match Output 01.
- **UserAccount**: Removed `attr department` — the Department-UserAccount relationship line in the diagram already represents this association, matching Output 01's "Linked to Department" specification.
- **Relationship table**: Replaced the old format (generic "Left Entity | Relationship | Right Entity") with a "Crow's Foot" column showing the exact notation (`--o{`, `--o|`) and descriptions that explicitly reference the diagram lines.
- **Entity descriptions**: Updated to reference specific diagram lines (e.g., "shown as `Booking ||--o{ BookingDecision`").
- **SpaceFacility narrative**: Changed from describing a logical M-N between Space and Facility to describing the two 1-N connections to the junction table as drawn in the diagram.
- **Design Decisions**: Added a new bullet documenting adherence to the Step Precedence Rule.

### Step Precedence audit of remaining content

All other attributes in the ERD were verified against Output 01:
| Entity | Output 01 attributes | ERD attributes | Status |
|---|---|---|---|
| Department | department_id, department_name | department_id, department_name | ✅ |
| UserAccount | user_id, full_name, email, phone_number, role, account_status, created_at, updated_at | user_id, email, full_name, phone_number, role, account_status, created_at, updated_at | ✅ (order differs, content matches) |
| Space | space_id, space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy, created_at, updated_at | space_id, space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy, created_at, updated_at | ✅ |
| Facility | facility_id, facility_name, description | facility_id, facility_name, description | ✅ |
| SpaceFacility | quantity, condition, note | quantity, condition, note + space_id, facility_id (from Spec §5) | ⚠️ Spec fill-in allowed |
| Booking | booking_id, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status, cancelled_at, cancel_reason, created_at, updated_at | booking_id, booking_code, requester_id, space_id + all Output 01 attributes | ⚠️ Spec fill-in allowed |
| BookingDecision | decision_id, decision, decision_time, decision_note, rejection_reason | decision_id, booking_id, decided_by, decision, decision_time, decision_note, rejection_reason | ⚠️ Spec fill-in allowed |
| UsageSession | session_id, actual_start_time, initial_condition, actual_end_time, final_condition, usage_notes | session_id, booking_id, checked_in_by, actual_start_time, initial_condition, completed_by, actual_end_time, final_condition, usage_notes | ⚠️ Spec fill-in allowed |
| MaintenanceRecord | maintenance_id, problem_description, problem_category, status, start_time, completion_time, result_note, created_at, updated_at | maintenance_id, maintenance_code, space_id, reporter_id, assigned_staff_id, problem_description, problem_category, status, start_time, completion_time, result_note, created_at, updated_at | ⚠️ Spec fill-in allowed |

The "Spec fill-in allowed" entries are additional attributes from Spec §5 that supplement (but do not contradict) Output 01, which is permitted by the Step Precedence Rule.

## Improvement classification

- AGENTS.md improvement
- SKILL.md improvement
- Output refinement

## Validation commands run

```
git status --porcelain
git diff --stat AGENTS.md .opencode/skills/db-design-pipeline/SKILL.md outputs/02-erd-design-G08.md
```

Manual consistency checks:
- ERD attribute names cross-referenced against Output 01 Section 3.
- Relationship table entries cross-referenced against Mermaid relationship lines.
- UserAccount checked for absence of `attr department`.
- Department checked for `department_id` (not `department_code`).
- Narrative checked for junction table descriptions (1-N to SpaceFacility, not M-N between Space and Facility).

## Validation results

All checks pass. The ERD is now consistent with Output 01 per the Step Precedence Rule, and the narrative accurately describes each diagram line.

## Risks / caveats

- Additional attributes from Spec §5 (e.g., `booking_code`, `requester_id`, `maintenance_code`, `space_id` in SpaceFacility) were added to supplement Output 01. While permitted by the rule, these were not explicitly validated against Output 01's attribute list. A future refinement of Output 01 could formalise these additions.
- The Step Precedence Rule applies forward (Output N controls Output N+1). If Output 01 is later revised, the ERD will need re-validation.

## Git status summary

```
 M .opencode/skills/db-design-pipeline/SKILL.md
 M AGENTS.md
 M outputs/02-erd-design-G08.md
```

## Recommended next steps

1. Proceed to Step 3 (Logical Database Design — `03-logical-design-G08.md`), using the refined ERD as primary input.
2. Consider updating Output 01 to formalise the Spec §5 attribute additions currently tracked only in the ERD.
3. After all 7 outputs exist, run the final validation scripts.
