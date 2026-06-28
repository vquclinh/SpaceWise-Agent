# Audit — Task 02 Role Separation and Skill-Rubric Refactor

> Date: 2026-06-28
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 2 — Conceptual ERD Design

## Task goal

Refactor Task 02 so that the command file is a concise execution entrypoint and the task-specific skill file is an evolving quality rubric, not a hard-coded ERD answer. The previous skill file pasted the full project-specific Mermaid diagram (the exact final answer from Output 02), making it a static answer template rather than a reusable guide. The intended workflow is: run command → review output → audit → improve skill → re-run.

No output files were regenerated. No Step 1, Step 3–7 files were modified.

## Files changed

| File | Action | Description |
|---|---|---|
| `.opencode/commands/02-generate-erd-design.md` | Replaced | Added self-review step with 5 specific verification points; expanded from 18 to 29 lines |
| `.opencode/skills/db-design-pipeline/02-erd-design/SKILL.md` | Replaced | Removed hard-coded full Mermaid diagram; restructured as 11-section evolving quality rubric (164 lines, down from 211) |

No files in `outputs/`, other command/skill files, `AGENTS.md`, shared `SKILL.md`, or scripts were modified.

## What was evaluated

- The previous Task 02 skill file (211 lines) was evaluated for role correctness.
- The previous Task 02 command file (18 lines) was evaluated for completeness (missing self-review).
- Outputs 01 and 02 were read for context to ensure the refactored skill rubric accurately describes the expected output.

## Issues found

1. **Skill contained a hard-coded final answer:** The previous skill included a 102-line complete Mermaid diagram (lines 26–127) that was identical to the current Output 02 ERD. This made the skill a static answer template rather than a reusable guide. The intended workflow is for the agent to derive the ERD from Output 01 guided by the skill rubric, not to copy-paste from the skill.
2. **Command lacked self-review:** The command file did not include a self-review step against the official PDF Step 2 requirement or Output 01 consistency. Command 01 had this; Command 02 did not.
3. **No diagram readability guidance:** Neither the skill nor the command addressed the known Mermaid rendering issue where relationship labels (especially on the Booking-to-UsageSession line) can become hidden or overlapped.
4. **Missing explicit "do not paste fixed answer" guidance:** The skill opened with "When executing this skill, generate the ERD document with the following exact structure and quality bar" followed immediately by the full answer Mermaid — effectively encouraging the agent to paste rather than derive.

## Changes made

### Command 02 (29 lines)

- **Added self-review step (step 4):** Five specific verification points:
  1. ERD includes main entities, attributes, relationships, cardinalities, participation constraints.
  2. Stays conceptual (no SQL types, no PK/FK, no Visitor IDs).
  3. Matches Output 01 faithfully.
  4. Narrative relationship table matches Mermaid lines.
  5. Relationship labels are readable when rendered.
- **Added skill-improvement guidance:** If self-review finds a systemic skill weakness, record it in the audit as "Recommended skill improvement"; do not silently edit the skill.
- **Explicitly named `outputs/01-business-req-analysis-G08.md`** as the primary authority and binding input.
- Renumbered safety constraint and audit policy to steps 5 and 6.

### Skill 02 (164 lines, down from 211)

- **Removed the hard-coded full Mermaid diagram** (102 lines of pre-baked answer). Replaced with a coverage checklist listing the required entities, with the instruction to derive actual ERD content from Output 01.
- **Added purpose and input sections** (sections 1–2): clarifies Step 2's role and the binding inputs.
- **Restructured output requirements as guidance** (section 3): describes what sections the output should contain without pasting the answer.
- **Added entity derivation rules** (section 5): instructs the agent to derive entities and attributes from Output 01, not from a fixed list. Includes a coverage checklist (the 9 needed entities) clearly marked as a guide, not an answer.
- **Added diagram readability rules** (section 9): explicit guidance on Mermaid label overlap issues including the known Booking-to-UsageSession label problem, with acceptable workarounds (short labels, narrative table).
- **Preserved all critical rules:**
  - Conceptual purity (no SQL types, no PK/FK, `attr` placeholder).
  - Home ID vs. Visitor ID with exhaustive per-entity FORBIDDEN Visitor ID table.
  - Relationship and participation rules with full relationship list as requirements, not a pasted answer.
  - Narrative consistency rules.
  - Validation checklist (18 items, expanded from 17).
  - Common mistakes to avoid (11 items, expanded from 8).
- **Added meta-guidance** in the opening: "This skill is an evolving quality rubric and behaviour guide, not a hard-coded ERD answer."

### Key contrasts with previous version:

| Aspect | Previous skill | Refactored skill |
|---|---|---|
| Opening | "generate the ERD document with the following exact structure" | "This skill is an evolving quality rubric … not a hard-coded ERD answer" |
| Entity definitions | Full Mermaid diagram with all 9 entities and attributes | Coverage checklist; "The agent must read Output 01 and preserve its latest entity and attribute decisions" |
| Relationship lines | All 13 Crow's Foot lines pasted | Required relationship list as a coverage guide |
| Diagram readability | Not addressed | Section 9 with specific guidance on label overlap and the Booking-to-UsageSession issue |
| Common mistakes | 8 generic items | 11 items including "Pasting a fixed Mermaid diagram without reading Output 01" |

## Improvement classification

- Command improvement
- SKILL.md improvement
- Documentation improvement

## Validation commands run

```bash
git status --short -- .opencode/commands/02-generate-erd-design.md .opencode/skills/db-design-pipeline/02-erd-design/SKILL.md
```

Result:
```
 M .opencode/commands/02-generate-erd-design.md
 M .opencode/skills/db-design-pipeline/02-erd-design/SKILL.md
```

```bash
git diff --stat -- .opencode/commands/02-generate-erd-design.md .opencode/skills/db-design-pipeline/02-erd-design/SKILL.md
```

Result: 2 files changed, 193 insertions(+).

```bash
git diff -- .opencode/commands/02-generate-erd-design.md .opencode/skills/db-design-pipeline/02-erd-design/SKILL.md
```

Result: Clean diff confirmed — command adds self-review, skill replaces hard-coded answer with rubric sections 1–11.

## Validation results

- Only the two allowed Task 02 files were modified. Outputs 01 and 02 untouched.
- Command file now has the same self-review pattern as Command 01.
- Skill file no longer pastes the final answer — it is a reusable rubric.
- All critical rules (conceptual purity, Home ID vs. Visitor ID, lifecycle optionality, BookingDecision 1-N, Booking-to-UsageSession 1-to-0..1, junction handling) are preserved as guidance.
- Diagram readability guidance added (previously absent).

## Risks / caveats

- **Commands not yet run.** The refactored command and skill have not been tested by executing `/02-generate-erd-design`.
- **Skill may be less prescriptive than before.** The previous skill guaranteed a specific ERD output because it pasted the answer. The refactored skill trusts the agent to derive the correct ERD from Output 01 using the rubric rules. This is the intended design but introduces the risk that a future agent run might produce a slightly different (though still valid) ERD.
- **Output 02 was not regenerated.** If the command were run today against Output 01, it should produce something equivalent to the current Output 02, but this has not been verified.
- **No Step 1 or Step 3 files were modified** — downstream consistency is preserved.
- **G08's stronger conceptual-purity and safety rules are preserved.** The refactor did not adopt any G05-style approaches (PK markers, conceptual data types, etc.).

## Git status summary

Modified (Task 02 only):
```
 M .opencode/commands/02-generate-erd-design.md
 M .opencode/skills/db-design-pipeline/02-erd-design/SKILL.md
```

No output files, no Step 1/3–7 files, and no rule files were modified.

## Recommended next steps

1. Optionally run `/02-generate-erd-design` to verify the refactored command and skill produce an ERD equivalent to the current Output 02.
2. After any future regression or refinement of Output 02, run the self-review and audit cycle to capture skill improvements.
3. Apply the same role-separation refactor to Command/Skill 03 (the logical design skill currently also contains a hard-coded answer with full per-table constraint specs).
4. Continue the generate → review → audit → improve-skill workflow for remaining steps.