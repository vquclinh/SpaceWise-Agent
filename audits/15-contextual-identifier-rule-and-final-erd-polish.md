# Audit — Contextual Identifier Rule and Final ERD Polish

> Date: 2026-06-25
> Operator/member: Huỳnh Lê Bảo Thi and Trương Thị Mỹ Duyên
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free (via OpenCode)
> OpenCode command used: `/refine-output outputs/02-erd-design-G08.md`

## Task goal

Replace the absolute De-duplication Rule with a nuanced Contextual Identifier Rule that distinguishes between Stable Entities (keep both system ID and business code) and Transactional/Event Entities (purge redundant codes, keep only system ID). Then apply the rule to finalize Output 02.

## Files created / changed

- **Modified:** `.opencode/skills/db-design-pipeline/SKILL.md` — replaced De-duplication Rule with Contextual Identifier Rule in Steps 1 & 2; Metadata Requirement re-affirmed.
- **Modified:** `outputs/02-erd-design-G08.md` — removed `booking_code` from Booking and `maintenance_code` from MaintenanceRecord; updated narrative and Design Decisions.
- **Created:** `audits/16-contextual-identifier-rule-and-final-erd-polish.md` (this file).

## What was evaluated

- Whether the Contextual Identifier Rule correctly categorizes entities as Stable vs. Transactional.
- Whether the ERD follows the rule: Space retains `space_code`; Booking and MaintenanceRecord drop their business codes.
- Whether the Metadata Requirement remains intact for core entities.
- Whether narrative explanations correctly reference the new rule.

## Issues found

1. **SKILL.md De-duplication Rule** was an absolute "purge all redundant codes" statement that did not distinguish between entity types. Space's `space_code` is valuable for user recognition; Booking's `booking_code` is redundant with `booking_id` since booking identity is purely internal.
2. **Output 02** still contained `booking_code` in Booking and `maintenance_code` in MaintenanceRecord — these are transactional entities where business codes add no conceptual value.

## Changes made

### SKILL.md — Step 1 & Step 2

- Replaced "De-duplication Rule: Avoid redundant identifiers..." with **Contextual Identifier Rule:**
  - **Stable Entities** (e.g., Space) — keep both system ID (`space_id`) and business code (`space_code`) for user recognition.
  - **Transactional/Event Entities** (e.g., Booking, MaintenanceRecord) — purge redundant codes; keep only system ID (`booking_id`, `maintenance_id`).
- Metadata Requirement left unchanged (already present and correct).

### Output 02 — Mermaid diagram

| Entity | Before | After | Reason |
|---|---|---|---|
| Booking | `booking_id`, `booking_code` | `booking_id` only | Transactional — purge redundant code |
| MaintenanceRecord | `maintenance_id`, `maintenance_code` | `maintenance_id` only | Transactional — purge redundant code |
| Space | `space_id`, `space_code` | `space_id`, `space_code` | Stable — keep both ✅ |

### Output 02 — Narrative

- Booking description: added note that `booking_code` is excluded per the Contextual Identifier Rule.
- MaintenanceRecord description: added note that `maintenance_code` is excluded per the Contextual Identifier Rule.
- Design Decisions: replaced "De-duplication Rule applied" bullet with "Contextual Identifier Rule applied" explaining the stable-vs-transactional distinction.

### Verification of other entities

| Entity | Classification | Business code | Decision |
|---|---|---|---|
| Department | Stable | `department_name` (not a code, descriptive) | Keep ✅ |
| UserAccount | Stable | `email` (natural identifier, not a redundant code) | Keep ✅ |
| Facility | Stable | `facility_name` (descriptive, not a code) | Keep ✅ |
| SpaceFacility | Junction | — | N/A |
| BookingDecision | Transactional | — | N/A |
| UsageSession | Transactional | — | N/A |

## Improvement classification

- SKILL.md improvement
- Output refinement

## Validation commands run

```
git status --porcelain
git diff --stat .opencode/skills/db-design-pipeline/SKILL.md outputs/02-erd-design-G08.md
```

Manual checks:
- ✅ `booking_code` removed from Booking in Mermaid and narrative
- ✅ `maintenance_code` removed from MaintenanceRecord in Mermaid and narrative
- ✅ `space_code` retained in Space
- ✅ `email` retained in UserAccount
- ✅ `created_at`/`updated_at` present on all 4 core entities
- ✅ Narrative references Contextual Identifier Rule
- ✅ Design Decisions updated

## Validation results

All checks pass. The ERD now reflects the nuanced stable-vs-transactional distinction.

## Risks / caveats

- `UserAccount.email` could be considered redundant with `user_id` from a strict identification standpoint, but `email` carries distinct descriptive value (it is the actual email address used for communication). The Contextual Identifier Rule's "user recognition" rationale applies here as well.
- The classification of entities as Stable vs. Transactional is a design judgment. Future steps may refine this distinction as more domain knowledge emerges.

## Git status summary

```
 M .opencode/skills/db-design-pipeline/SKILL.md
 M AGENTS.md
 M outputs/02-erd-design-G08.md
?? audits/14-finalize-conceptual-attributes-and-traceability.md
?? audits/15-contextual-identifier-rule-and-final-erd-polish.md
```

## Recommended next steps

1. Proceed to Step 3 (Logical Database Design — `03-logical-design-G08.md`), where Foreign Keys, Surrogate Keys, and data types are introduced.
2. Run full validation scripts once all 7 outputs exist.
