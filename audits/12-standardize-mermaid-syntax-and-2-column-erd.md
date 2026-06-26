# Audit — Standardize Mermaid Syntax and 2-Column ERD

> Date: 2026-06-25
> Operator/member: Trương Thị Mỹ Duyên and Huỳnh Lê Bảo Thi
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free (via OpenCode)
> OpenCode command used: `/refine-output outputs/02-erd-design-G08.md`

## Task goal

Update AGENTS.md and SKILL.md to adopt a new Mermaid rendering standard for the conceptual ERD, then regenerate the ERD to match. The standard requires:
- A simple 2-column format for entity boxes.
- `attr` as a generic placeholder type in Mermaid syntax (no real data types).
- No PK/FK markers in the diagram — identifying attributes described only in the narrative.
- Update the SKILL.md Step 2 requirements and quality checklist to enforce this standard.

## Files created / changed

- **Modified:** `AGENTS.md` — added new "Mermaid ERD rendering (Step 2)" rule in Section 3.
- **Modified:** `.opencode/skills/db-design-pipeline/SKILL.md` — updated Step 2 identifying attribute requirement and quality checklist.
- **Modified:** `outputs/02-erd-design-G08.md` — regenerated Mermaid diagram and narrative.
- **Created:** `audits/12-standardize-mermaid-syntax-and-2-column-erd.md` (this file).

## What was evaluated

- Whether the AGENTS.md rule correctly specifies the 2-column/`attr`/no-PK-FK standard.
- Whether SKILL.md Step 2 and its quality checklist enforce the new standard without contradiction.
- Whether the regenerated `02-erd-design-G08.md` uses `attr` placeholder types, omits all PK/FK markers, and describes identifiers in narrative only.
- Whether the Mermaid code is syntactically valid.

## Issues found

1. **AGENTS.md Section 3** had no rule governing Mermaid rendering format — entities previously used bare attribute names without a type, and PK markers were present, causing both a Mermaid parsing concern and a visual clutter issue.
2. **SKILL.md Step 2** still referenced "marked as PK for notation purposes only" which conflicted with the new no-PK-marker standard. The quality checklist also had an ambiguous item ("Confirm no technical keys (PK/FK), data types...") that didn't explicitly forbid PK markers in the boxes.
3. **02-erd-design-G08.md** used `attribute_name PK` format with no data type — valid conceptually but inconsistent with the new 2-column clean look and problematic for Mermaid rendering (missing required type field).

## Changes made

### AGENTS.md — Section 3

- Added rule: "In Step 2 (Conceptual ERD), use a simple 2-column format for entity boxes. Due to Mermaid syntax, use `attr` as a generic placeholder type for all attributes, but do not use the `PK` or `FK` markers in the diagram. Conceptual identifiers should be clear from the narrative, not technical markers in the boxes."

### SKILL.md — Step 2

- Changed identifying attribute requirement from `(marked as PK for notation purposes only)` to: "Attributes must be pure descriptors. Use the placeholder type `attr` for Mermaid syntax, but omit the PK marker to maintain a clean 2-column look in the diagram."
- Split the ambiguous quality checklist item into two explicit checks:
  - "Ensure no PK or FK markers appear inside entity boxes — only `attr` placeholder types for attributes."
  - "Confirm no data types or indexes appear anywhere in the conceptual design."

### 02-erd-design-G08.md (regenerated)

- Changed all attribute declarations from bare `attribute_name PK` / bare `attribute_name` to `attr attribute_name`.
- Removed all PK markers from entity boxes.
- Updated the introductory paragraph to describe the `attr` placeholder and 2-column standard.
- Updated the "Design Decisions" section with a new bullet explaining the no-PK/FK marker choice.
- Added `attr` to every attribute in every entity block (9 entities, ~45 attributes total).
- Narrative identifying attribute descriptions preserved and explicitly bolded as **Identifying attribute:**.

### Mermaid validation

All entity declarations now follow the valid syntax `attr attribute_name` where `attr` is a valid Mermaid type identifier. All relationship notations (`||--o{`, `||--o|`) use correct Crow's Foot syntax. No PK/FK constraint markers appear anywhere in the diagram.

## Improvement classification

- AGENTS.md improvement
- SKILL.md improvement
- Output refinement

## Validation commands run

```
git status --porcelain
git diff --stat AGENTS.md .opencode/skills/db-design-pipeline/SKILL.md outputs/02-erd-design-G08.md
```

Manual Mermaid syntax validation:
- All 9 entity blocks have valid `attr` type declarations.
- 0 PK markers present in any box.
- 0 FK markers present in any box.
- 13 relationship lines with valid Crow's Foot notation.
- All relationship labels are double-quoted strings.

## Validation results

All checks pass. The Mermaid code is syntactically valid and the 2-column clean look is achieved. No audit needed for subsequent cosmetic-only Mermaid changes.

## Risks / caveats

- The `attr` placeholder type will render as a literal column in Mermaid output; this is intentional and documented as the chosen convention.
- Remaining output files (01, 03–07) may still reference old conventions (e.g., attribute names with surrogate keys) — they will be aligned when regenerated in their respective pipeline steps.
- The "2-column format" refers to the `attr | attribute_name` layout Mermaid produces — not a true 2-column table. This is a practical compromise given Mermaid's rendering constraints.

## Git status summary

```
 M .opencode/skills/db-design-pipeline/SKILL.md
 M AGENTS.md
 M outputs/02-erd-design-G08.md
```

## Recommended next steps

1. Proceed to Step 3 (Logical Database Design — `03-logical-design-G08.md`), where physical data types, PKs, FKs, and surrogate keys are reintroduced.
2. Consider aligning `01-business-req-analysis-G08.md` attribute naming (currently uses `user_id`, `department_id` etc.) with the business identifiers used in the regenerated ERD.
3. After all 7 outputs exist, run the final validation scripts (`scripts/check_required_files.sh --final G08` and `scripts/validate_sql.sh --final G08`).
