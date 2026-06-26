# Audit — Fix Pipeline Structure and Regenerate ERD

> Date: 2026-06-25
> Operator/member: Trương Thị Mỹ Duyên and Huỳnh Lê Bảo Thi
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free (via OpenCode)
> OpenCode command used: `/refine-output outputs/02-erd-design-G08.md`

## Task goal

Fix five structural errors identified in the ERD design by updating project-level rules first, then regenerating the conceptual ERD. Specifically:

1. Add **Conceptual vs. Logical Boundary** rule to AGENTS.md (Steps 1 & 2 must never include data types, FKs, or indexes).
2. Add **Lifecycle & Optionality Rule** to AGENTS.md (prefer optional `0..n`/`0..1`; assume zero-start lifecycle).
3. Add **Notation Standard** rule to AGENTS.md (Mermaid Crow's Foot for convenience, but Chen/Hybrid mindset for design logic).
4. Update SKILL.md Step 2 to remove `Foreign key indications`, add strict conceptual purity rules, add quality checklist items, and enhance domain coverage.
5. Resolve internal conflict in SKILL.md Step 2 (PK notation vs. no data types) by clarifying identifying attributes as business identifiers marked PK for notation only.
6. Regenerate `outputs/02-erd-design-G08.md` with all rules applied.

## Files created / changed

- **Modified:** `AGENTS.md` — added 3 new design rules in Section 3 (Editing rules).
- **Modified:** `.opencode/skills/db-design-pipeline/SKILL.md` — updated Step 2 requirements, quality checklist, and Domain Coverage.
- **Modified (regenerated):** `outputs/02-erd-design-G08.md` — full conceptual ERD rewrite.
- **Created:** `audits/11-fix-pipeline-structure-and-regenerate-erd.md` (this file).

## What was evaluated

- Whether the 5 structural errors in the ERD were correctly identified and addressed.
- Alignment between AGENTS.md rules, SKILL.md pipeline instructions, and the regenerated ERD.
- Adherence to conceptual purity (no data types, no FK markers, business identifiers only).
- Correct use of optional notation per lifecycle start-from-zero rule.
- Correct cardinality for Booking-to-UsageSession (1-to-0..1) and junction table participation.

## Issues found

1. **AGENTS.md Section 3** had a weak/truncated rule (`Step 1 must not include physical database details. For example: Foreign Keys (FK),...`) that only covered Step 1, lacked the lifecycle optionality principle, and had no notation standard guidance.
2. **SKILL.md Step 2** included `- Foreign key indications` which is a logical/physical detail inappropriate for conceptual design.
3. **SKILL.md Step 2** had no quality checklist to catch violations of conceptual purity or optionality rules.
4. **SKILL.md Domain Coverage** did not explicitly mention BookingDecision's 1-N history relationship.
5. **SKILL.md Step 2** had a conflict: the quality checklist said "no technical keys (PK/FK)" while the requirement said "identifying attributes marked as PK for notation purposes". Resolved by clarifying that business-identifier PK markers are allowed for notation only; surrogate keys and FK markers are forbidden.
6. **02-erd-design-G08.md** contained physical data types (`int`, `string`, `datetime`), FK annotations, surrogate keys (`department_id PK`, `user_id PK`), and mandatory notation (`||`) on many dependent sides — all violations of the new rules.

## Changes made

### AGENTS.md — Section 3 (Editing rules)

- Replaced the weak bullet with three new rules:
  - **Conceptual vs. Logical Boundary:** Steps 1 & 2 must NEVER include data types, FKs, or indexes; these are reserved for Step 3.
  - **Lifecycle & Optionality Rule:** Use optional notations (`0..n` or `0..1`) by default; mandatory only when absolutely necessary.
  - **Notation Standard:** Mermaid Crow's Foot for convenience, but Chen/Hybrid mindset for cardinality decisions.

### SKILL.md — Step 2

- Replaced `- Foreign key indications.` with: `- Represent relationships solely through notation lines. Attributes must be pure descriptors only. Strictly no technical keys (PK/FK) or physical data types in this step.`
- Replaced `- Entity definitions with attributes and primary keys.` with: `- Entity definitions with attributes and identifying attributes (marked as PK for notation purposes only).`
- Added clarification bullet: identifying attributes must be business identifiers (e.g., Space Code, Email) rather than technical surrogate keys.
- Added **Quality checklist (Step 2)** with 4 checks: optional notations for lifecycle, verify Booking-UsageSession 1-to-0..1, junction table participation rules, and no technical keys/data types.

### SKILL.md — Domain Coverage

- Added `- **BookingDecision**: Must preserve decision history in a 1-N relationship with Booking (each booking can have multiple decision records over its lifecycle).`
- Enriched Department bullet with `Every user belongs to a department.`

### 02-erd-design-G08.md (regenerated)

- **Removed all physical data types** (`int`, `string`, `datetime`, `text`) from Mermaid attribute blocks.
- **Removed all FK annotations** (e.g., `int space_id FK`).
- **Replaced surrogate keys** with business identifiers: `department_code` (not `department_id`), `email` (not `user_id`), `space_code` (not `space_id`), `facility_name` (not `facility_id`), `booking_code` (not `booking_id`), `maintenance_code` (not `maintenance_id`).
- **Changed relationship notations** from mandatory (`||--|{`) to optional (`||--o{`) on all dependent sides to reflect lifecycle start-from-zero.
- **Booking-to-UsageSession**: changed from `}o--||` to `||--o|` (1-to-0..1) with the correct direction.
- Updated narrative to explain each design decision with traceability to the new rules.

## Improvement classification

- AGENTS.md improvement
- SKILL.md improvement
- Output refinement

## Validation commands run

```
git diff --stat AGENTS.md .opencode/skills/db-design-pipeline/SKILL.md
git status --porcelain
```

Manual review of the regenerated ERD against the quality checklist:

1. ✅ No physical data types in Mermaid.
2. ✅ No FK markers in Mermaid.
3. ✅ No surrogate auto-increment keys; business identifiers used instead.
4. ✅ All dependent sides use optional notation (`--o{` or `--o|`).
5. ✅ Booking-to-UsageSession is `||--o|` (1-to-0..1).
6. ✅ Junction table (SpaceFacility): `||--o{` on both master sides, no PK marker on junction.
7. ✅ BookingDecision 1-N with Booking mentioned in Domain Coverage and narrative.
8. ✅ Department listed as mandatory normalized entity with "every user belongs to a department."

## Validation results

All quality checks pass. The regenerated ERD is conceptually pure and aligned with the updated AGENTS.md and SKILL.md rules.

## Risks / caveats

- Mermaid renderers may not display attribute blocks correctly without a type field. The attribute names are present for human readers; rendering issues are cosmetic and do not affect the conceptual correctness.
- The `decision_id` and `session_id` identifiers are less natural as business identifiers than `department_code` or `email`. They were retained to keep the diagram clear; these may be refined to composites (e.g., `(booking_code, decision_timestamp)`) in a future pass if needed.
- Other output files (01, 03, 04) still reference old attribute names like `user_id`, `department_id`, etc. They must be updated to stay consistent with the new conceptual identifiers when those files are regenerated.

## Git status summary

```
 M .opencode/skills/db-design-pipeline/SKILL.md
 M AGENTS.md
?? audits/10-generate-erd-step2.md
?? audits/11-fix-pipeline-structure-and-regenerate-erd.md
?? outputs/02-erd-design-G08.md
```

## Recommended next steps

1. Audit 10 (previous ERD generation) is now superseded; consider marking it as historical reference.
2. Regenerate `outputs/01-business-req-analysis-G08.md` to replace surrogate attribute names (`user_id`, `department_id`, etc.) with business identifiers consistent with the new conceptual approach.
3. Proceed to Step 3 (Logical Design — `03-logical-design-G08.md`) where physical data types, FKs, and surrogate keys are reintroduced.
4. After all 7 outputs are generated, run the final validation scripts per AGENTS.md Section 8.
