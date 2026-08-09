---
description: Generate ONLY Task 11 (Concurrency Design) for Phase 2.
---

# /11-generate-concurrency-design

This command executes only the Concurrency Design phase (Task 11) of the Phase 2 database pipeline.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined for Task 11 (e.g., `.opencode/skills/db-design-pipeline/11-concurrency-design/SKILL.md`).
2. **Read Inputs:**
   - `outputs/08-requirement-change-analysis-G08.md` — specifically Section 5 (Concurrency & Race Condition Analysis).
   - `outputs/09-updated-erd-and-logical-design-G08.md` — specifically Section 9 (Concurrency Control Design).
   - `req/business-requirement-P2.md`
   - `CS486_Project_Phase02.pdf` — the official Phase 2 requirements, if readable.
   - `AGENTS.md` — repository-level rules.
3. **Generate Output:** Create or update ONLY `outputs/11-concurrency-design-G08.md`.
4. **Self-Review:** After writing, review the output against:
   - The official Phase 2 PDF requirements for concurrent booking and approval.
   - The task skill.
   If the self-review reveals a systemic weakness in the task skill (missing guidance, unclear rules), record it in the audit as **"Recommended skill improvement"**. Do NOT silently edit the skill file during a normal generation run unless the user explicitly asked for a skill-editing task.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite deliverables 08, 09, 10, 12, 13, 14, 15, or 16. Do not edit `AGENTS.md` or `.opencode/skills/db-design-pipeline/SKILL.md`.
6. **Audit Policy:** After generation or refinement, you MUST follow the repository audit policy (`AGENTS.md` section 7). Create a new audit log in `docs/audits/` using the `docs/audits/AUDIT_TEMPLATE.md` format. Record the Phase 2 step (Task 11) and the output file evaluated.