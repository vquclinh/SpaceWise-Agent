---
description: Generate ONLY Step 3 (Logical Database Design) for Phase 1.
---

# /03-generate-logical-design

This command executes only the Logical Database Design phase of the database pipeline. It is an **execution entrypoint** — it does not contain the schema answer. The logical schema must be derived from Output 02 using the task skill.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined in `.opencode/skills/db-design-pipeline/03-logical-design/SKILL.md`. The skill is a rubric/guardrail; derive the actual schema from the inputs, do not copy a fixed answer.
2. **Read Inputs:**
   - `outputs/02-erd-design-G08.md` — **immediate previous-step authority**. The relations, attributes, and relationships come from here.
   - `outputs/01-business-req-analysis-G08.md` — secondary reference for **business-rule traceability**.
   - `.opencode/skills/db-design-pipeline/SKILL.md` — shared pipeline rules.
   - `AGENTS.md` — sections 2 (source-of-truth, Step Precedence Rule), 3 (Relationship Labeling rule for Step 3), and 4 (SQL Server rules).
3. **Generate Output:** Create or update ONLY `outputs/03-logical-design-G08.md`.
4. **Self-Review:** After generation/refinement, review the output and answer each of these explicitly:
   1. Does the output satisfy the official PDF Step 3 requirement (relations, attributes, primary keys, foreign keys, **candidate keys**, key constraints)?
   2. Does it convert Output 02 into relations/tables (every conceptual entity becomes a relation)?
   3. Are attributes, primary keys, foreign keys, **candidate keys**, and key constraints all explicit (candidate keys listed, not only implied by UNIQUE)?
   4. Does every relationship from Output 02 map to an FK column or a junction-table strategy?
   5. Are business-rule enforcement strategies traceable to Output 01?
   6. Is the output still a **logical design deliverable**, not executable DDL (no full `CREATE TABLE` scripts — those belong to Step 5)?
   7. Are the Mermaid relationship labels readable after rendering (or is a readability workaround documented)?
   If the self-review reveals a systemic weakness in the task skill (missing guidance, unclear rules), record it in the audit as **"Recommended skill improvement"**. Do NOT silently edit the skill file during a normal generation run unless the user explicitly asked for a skill-editing task.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite deliverables 01, 02, 04, 05, 06, or 07. Do not edit `AGENTS.md` or `.opencode/skills/db-design-pipeline/SKILL.md`.
6. **Audit Policy:** After generation or refinement, you MUST follow the repository audit policy (`AGENTS.md` section 7). Create a new audit log in `docs/audits/` using the `docs/audits/AUDIT_TEMPLATE.md` format. Record the Phase 1 step (Step 3) and the output file evaluated.
