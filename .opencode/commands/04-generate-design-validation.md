---
description: Generate ONLY Step 4 (Design Validation) for Phase 1.
---
# /04-generate-design-validation

This command executes only the Design Validation phase of the database pipeline.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined in `.opencode/skills/db-design-pipeline/04-design-validation/SKILL.md`.
2. **Read Inputs:** Read `outputs/01-business-req-analysis-G08.md`, `outputs/02-erd-design-G08.md`, and `outputs/03-logical-design-G08.md` to understand the domain and the logical schema that needs validating.
3. **Generate Output:** Create or update ONLY `outputs/04-design-validation-G08.md`.
4. **Safety Constraint:** Do NOT generate, modify, or overwrite deliverables 01, 02, 03, 05, 06, or 07.
5. **Audit Policy:** After generation, you MUST follow the repository audit policy (AGENTS.md section 7). Create a new audit log in `docs/audits/` using the `docs/audits/AUDIT_TEMPLATE.md` format.