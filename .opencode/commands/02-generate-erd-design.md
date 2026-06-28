---
description: Generate ONLY Step 2 (Conceptual ERD Design) for Phase 1.
---

# /02-generate-erd-design

This command executes only the Conceptual ERD Design phase of the database pipeline.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined in `.opencode/skills/db-design-pipeline/02-erd-design/SKILL.md`.
2. **Read Inputs:**
   - `outputs/01-business-req-analysis-G08.md` — **primary authority** (immediate previous step output). All entities, attributes, relationships, and business rules defined here are binding input.
   - `.opencode/skills/db-design-pipeline/SKILL.md` — shared pipeline rules.
   - `AGENTS.md` — sections 2 (source-of-truth, Step Precedence Rule), 3 (Mermaid ERD rendering rules, Home ID vs. Visitor ID, Lifecycle & Optionality Rule).
3. **Generate Output:** Create or update ONLY `outputs/02-erd-design-G08.md`.
4. **Self-Review:** After writing, review the output against:
   - The official PDF (`CS486_Project.pdf`) Step 2 requirement: main entities, attributes, relationships, cardinalities, and participation constraints.
   - `outputs/01-business-req-analysis-G08.md` — does the ERD faithfully derive from the analysis?
   - The task skill (`.opencode/skills/db-design-pipeline/02-erd-design/SKILL.md`) validation checklist.
   Specifically verify:
   1. Does the ERD include main entities, attributes, relationships, cardinalities, and participation constraints?
   2. Does it stay conceptual (no SQL types, no PK/FK markers, no Visitor IDs in entity boxes)?
   3. Does it match Output 01 (all entities, relationships, and attributes preserved)?
   4. Does the narrative relationship table match the Mermaid lines?
   5. Are relationship labels readable when rendered in Mermaid?
   If the self-review reveals a systemic weakness in the task skill (missing guidance, unclear rules), record it in the audit as **"Recommended skill improvement"**. Do NOT silently edit the skill file during a normal generation run unless the user explicitly asked for a skill-editing task.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite deliverables 01, 03, 04, 05, 06, or 07. Do not edit `AGENTS.md` or `.opencode/skills/db-design-pipeline/SKILL.md`.
6. **Audit Policy:** After generation or refinement, you MUST follow the repository audit policy (`AGENTS.md` section 7). Create a new audit log in `docs/audits/` using the `docs/audits/AUDIT_TEMPLATE.md` format. Record the Phase 1 step (Step 2) and the output file evaluated.