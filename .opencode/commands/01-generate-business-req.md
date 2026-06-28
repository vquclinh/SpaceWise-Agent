---
description: Generate ONLY Step 1 (Business Requirement Analysis) for Phase 1.
---

# /01-generate-business-req

This command executes only the Business Requirement Analysis phase of the database pipeline.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined in `.opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md`.
2. **Read Inputs:**
   - `$ARGUMENTS` — the requirement file passed by the user; if empty, use `req/business-requirement.md`.
   - `CS486_Project.pdf` — the official requirement, if readable.
   - `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` — supplementary domain specification, if readable.
   - `.opencode/skills/db-design-pipeline/SKILL.md` — shared pipeline rules.
   - `AGENTS.md` — repository-level rules, especially sections 2 (source-of-truth), 3 (Conceptual vs. Logical boundary, Home ID vs. Visitor ID).
3. **Generate Output:** Create or update ONLY `outputs/01-business-req-analysis-G08.md`.
4. **Self-Review:** After writing, review the output against:
   - The official PDF (`CS486_Project.pdf`) Step 1 requirements.
   - The task skill (`.opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md`).
   - The shared pipeline skill rules (especially conceptual boundaries, Home ID vs. Visitor ID).
   If the self-review reveals a systemic weakness in the task skill (missing guidance, unclear rules), record it in the audit as **"Recommended skill improvement"**. Do NOT silently edit the skill file during a normal generation run unless the user explicitly asked for a skill-editing task.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite deliverables 02, 03, 04, 05, 06, or 07. Do not edit `AGENTS.md` or `.opencode/skills/db-design-pipeline/SKILL.md`.
6. **Audit Policy:** After generation or refinement, you MUST follow the repository audit policy (`AGENTS.md` section 7). Create a new audit log in `docs/audits/` using the `docs/audits/AUDIT_TEMPLATE.md` format. Record the Phase 1 step (Step 1) and the output file evaluated.