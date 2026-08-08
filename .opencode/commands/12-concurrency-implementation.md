---
description: Generate ONLY Task 12 (Concurrency Implementation) for Phase 2.
---

# /12-generate-concurrency-implementation

This command executes only the Concurrency Implementation phase (Task 12) of the Phase 2 database pipeline.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined for Task 12 (e.g., `.opencode/skills/db-design-pipeline/12-concurrency-implementation/SKILL.md`).
2. **Read Inputs:**
   - `outputs/11-concurrency-design-G08.md` — specifically Section III (Proposed Concurrency Control Mechanism) and Section VI (Task 12 Implementation Contract).
   - `outputs/09-updated-erd-and-logical-design-G08.md` — for exact table, column, and constraint names.
   - `req/business-requirement-P2.md`
   - `CS486_Project_Phase02.pdf` — the official Phase 2 requirements, if readable.
   - `AGENTS.md` — repository-level rules.
3. **Generate Output:** Create or update ONLY `outputs/12-concurrency-implementation-G08.sql`.
4. **Self-Review:** After writing, review the output against:
   - The Task 12 Implementation Contract (C1–C7) defined in the Task 11 design document.
   - The strict requirement to use ONLY Microsoft SQL Server syntax (no PostgreSQL constructs).
   - The mandatory lock-acquisition ordering (`bookings` -> `maintenance_records` -> `booking_alerts`).
   If the self-review reveals a systemic weakness in the task skill (missing guidance, unclear rules), record it in the audit as **"Recommended skill improvement"**. Do NOT silently edit the skill file during a normal generation run unless the user explicitly asked for a skill-editing task.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite deliverables 08, 09, 10, 11, 13, 14, 15, or 16. Do not edit `AGENTS.md` or `.opencode/skills/db-design-pipeline/SKILL.md`.
6. **Audit Policy:** After generation or refinement, you MUST follow the repository audit policy (`AGENTS.md` section 7). Create a new audit log in `docs/audits/` using the `docs/audits/AUDIT_TEMPLATE.md` format. Record the Phase 2 step (Task 12) and the output file evaluated.