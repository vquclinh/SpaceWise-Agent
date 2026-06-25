# Audit — Finalize Conceptual Attributes and Traceability

> Date: 2026-06-25
> Operator/member: Huỳnh Lê Bảo Thi and Trương Thị Mỹ Duyên
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free (via OpenCode)
> OpenCode command used: `/refine-output outputs/02-erd-design-G08.md`

## Task goal

Finalize the conceptual definitions for Steps 1 and 2 by:

1. Establishing the **Home ID vs. Visitor ID** rule in AGENTS.md (an identifier belongs only inside its defining entity box; forbidden as a linking field until Step 3).
2. Re-ordering the **Source-of-Truth hierarchy** (Previous Step Outputs moved to #2, ahead of the requirement document and the Project Spec).
3. Adding **Conceptual Attribute Filter**, **De-duplication Rule**, and **Metadata Requirement** to SKILL.md Steps 1 & 2.
4. Adding a **Linking Strategy** instruction to SKILL.md Step 3.
5. Applying all rules to purify `outputs/02-erd-design-G08.md` and bring it to final state.

## Files created / changed

- **Modified:** `AGENTS.md` — new Source-of-Truth hierarchy; new Home ID vs. Visitor ID rule in Section 3; updated Step Precedence Rule.
- **Modified:** `.opencode/skills/db-design-pipeline/SKILL.md` — Conceptual Attribute Filter, De-duplication Rule, Metadata Requirement, and Linking Strategy added.
- **Modified:** `outputs/02-erd-design-G08.md` — Visitor IDs purged, Home IDs kept, `created_at`/`updated_at` added to core entities, narrative and design decisions rewritten.
- **Created:** `audits/14-finalize-conceptual-attributes-and-traceability.md` (this file).

## What was evaluated

- Whether the Home ID vs. Visitor ID rule correctly distinguishes entity-owned identifiers from linking Foreign Keys.
- Whether the Source-of-Truth hierarchy correctly prioritizes Previous Step Outputs over the requirement doc and Project Spec.
- Whether the SKILL.md instructions for Steps 1, 2, and 3 correctly guide attribute filtering and linking strategy.
- Whether Output 02 contains only Home IDs and its own descriptive attributes, with no Visitor IDs.
- Whether core entities include `created_at` and `updated_at` per the Metadata Requirement.
- Whether the De-duplication Rule is satisfied (no redundant identifiers without descriptive value).

## Issues found

1. **AGENTS.md Section 2** had the old hierarchy (Project Spec at #2, requirement at #3) with no Previous Step Outputs listed. The Step Precedence Rule referenced "Use the Project Spec to fill in domain details" which encouraged ID leakage.
2. **AGENTS.md Section 3** lacked a rule clearly separating Home IDs from Visitor IDs — the previous "Strict Conceptual Purity" rule was ambiguous about whether identifiers could appear in their own entity.
3. **SKILL.md Step 2** included a contradictory rule: "you MUST include all attributes explicitly listed in the Project Specification (Spec §5), including identifiers like user_id, space_id, etc." This directly caused Visitor ID leakage (e.g., `requester_id`, `space_id` in Booking).
4. **Output 02** had extensive Visitor ID leakage: `requester_id` & `space_id` in Booking, `booking_id` & `decided_by` in BookingDecision, `booking_id` & `checked_in_by` & `completed_by` in UsageSession, `space_id` & `facility_id` in SpaceFacility, and `space_id` & `reporter_id` & `assigned_staff_id` in MaintenanceRecord.
5. **Output 02** lacked `created_at` and `updated_at` on core entities (removed in an earlier iteration that over-purged).
6. **SKILL.md Step 1 & 2** had no De-duplication Rule or Metadata Requirement to guide attribute selection.

## Changes made

### AGENTS.md — Section 2 (Source-of-truth order)

- Replaced the 3-item list with a 4-item hierarchy:
  1. `CS486_Project.pdf`
  2. **Previous Step Outputs** (mandatory consistency)
  3. `req/business-requirement.md`
  4. `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` (supplementary only)
- Updated Step Precedence Rule to state "Previous Step Outputs take precedence over the requirement document and the Project Spec."

### AGENTS.md — Section 3 (Editing rules)

- Added **Home ID vs. Visitor ID** rule: identifiers belong only inside their defining entity box; strictly forbidden as linking fields until Step 3; relationship lines represent connections; FK columns appear only from Step 3.

### SKILL.md — Step 1 & Step 2

- **Conceptual Attribute Filter**: Only include an ID if it's the Primary Identifier for that entity; exclude linking FKs.
- **De-duplication Rule**: Avoid redundant identifiers — if a system ID is used, exclude business codes unless they carry distinct descriptive value.
- **Metadata Requirement**: Core entities MUST include `created_at` and `updated_at` as descriptive attributes.

### SKILL.md — Step 3

- **Linking Strategy**: This is the stage to brainstorm and introduce linking attributes. Transform ERD relationship lines into physical FK columns based on the full Spec attribute lists.

### Output 02 — ERD Mermaid diagram

**Visitor IDs purged** (attributes removed from entity boxes):
| Entity | Removed attributes | Reason |
|---|---|---|
| Booking | `requester_id`, `space_id` | Visitor IDs (belong to UserAccount, Space) |
| BookingDecision | `booking_id`, `decided_by` | Visitor IDs (belong to Booking, UserAccount) |
| UsageSession | `booking_id`, `checked_in_by`, `completed_by` | Visitor IDs (belong to Booking, UserAccount) |
| SpaceFacility | `space_id`, `facility_id` | Visitor IDs (belong to Space, Facility) |
| MaintenanceRecord | `space_id`, `reporter_id`, `assigned_staff_id` | Visitor IDs (belong to Space, UserAccount) |

**Home IDs kept** in each entity's own box: `department_id`, `user_id`, `space_id`, `facility_id`, `booking_id`, `decision_id`, `session_id`, `maintenance_id`.

**Metadata added** (`created_at`, `updated_at`):
- UserAccount: `attr created_at`, `attr updated_at`
- Space: `attr created_at`, `attr updated_at`
- Booking: `attr created_at`, `attr updated_at`
- MaintenanceRecord: `attr created_at`, `attr updated_at`

**De-duplication verified**: Business codes (`booking_code`, `maintenance_code`, `space_code`, `email`) all carry distinct descriptive value and are retained alongside system IDs.

### Output 02 — Narrative

- All entity descriptions rewritten to explain the Home ID vs. Visitor ID rationale explicitly.
- SpaceFacility described as purely descriptive with linking handled by Crow's Foot lines.
- Each core entity mentions `created_at`/`updated_at` inclusion.
- Relationship table updated to describe 13 Crow's Foot lines exactly as drawn.
- Design Decisions section: 10 bullets covering all design choices (Home/Visitor, SpaceFacility, no physical details, Metadata Requirement, De-duplication, Consistency, Optionality, Junction, Booking-UsageSession, BookingDecision).

## Improvement classification

- AGENTS.md improvement
- SKILL.md improvement
- Output refinement

## Validation commands run

```
git status --porcelain
git diff --stat AGENTS.md .opencode/skills/db-design-pipeline/SKILL.md outputs/02-erd-design-G08.md
```

Manual validation of Output 02 against rules:

| Check | Result |
|---|---|
| No Visitor IDs inside Booking | ✅ (no `requester_id`, `space_id`) |
| No Visitor IDs inside BookingDecision | ✅ (no `booking_id`, `decided_by`) |
| No Visitor IDs inside UsageSession | ✅ (no `booking_id`, `checked_in_by`, `completed_by`) |
| No Visitor IDs inside SpaceFacility | ✅ (only `quantity`, `condition`, `note`) |
| No Visitor IDs inside MaintenanceRecord | ✅ (no `space_id`, `reporter_id`, `assigned_staff_id`) |
| Home IDs present in each entity | ✅ (all 8 Home IDs present) |
| `created_at`/`updated_at` on core entities | ✅ (UserAccount, Space, Booking, MaintenanceRecord) |
| Business codes with distinct value retained | ✅ (`booking_code`, `maintenance_code`, `space_code`, `email`) |
| No data types or PK/FK markers | ✅ (all `attr` placeholder) |
| Relationship lines match narrative | ✅ (13 lines, all described in table) |
| Consistency with Output 01 | ✅ (attribute names match, no `department` on UserAccount) |

## Validation results

All checks pass. Output 02 is in its final pure conceptual state.

## Risks / caveats

- The Metadata Requirement creates a tension with the "no physical data types" rule. `created_at` and `updated_at` are declared as `attr` descriptors (no `datetime` type), which follows the `attr` placeholder convention. They are treated as metadata concepts rather than physical columns.
- If Output 01 is later refined to add/remove attributes, Output 02 must be re-validated per the Step Precedence Rule.
- The De-duplication Rule is subjective — whether a business code "carries distinct descriptive value" may be interpreted differently by different team members. The current assessment is documented in the audit.

## Git status summary

```
 M .opencode/skills/db-design-pipeline/SKILL.md
 M AGENTS.md
 M outputs/02-erd-design-G08.md
```

## Recommended next steps

1. Proceed to Step 3 (Logical Database Design — `03-logical-design-G08.md`), where the full Spec §5 attribute lists are used to introduce Foreign Keys and Surrogate Keys.
2. Run the final validation scripts (`scripts/check_required_files.sh --final G08` and `scripts/validate_sql.sh --final G08`) once all 7 outputs exist.
3. Consider adding `01-business-req-analysis-G08.md` the `created_at`/`updated_at` attributes for consistency with the Metadata Requirement.
