---
description: Generate ONLY Step 5 (Database Definition) DDL SQL.
---
# /05-generate-db-definition

This command generates the SQL Data Definition Language (DDL) required to implement your database schema.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined in `.opencode/skills/db-design-pipeline/05-db-definition/SKILL.md`.
2. **Read Inputs:** Read `outputs/03-logical-design-G08.md` and `outputs/04-design-validation-G08.md`. Ensure you implement the constraints and index recommendations validated in the previous steps.
3. **Generate Output:** Create or update ONLY `outputs/05-db-definition-G08.sql`.
4. **Target DBMS:** Use Microsoft SQL Server syntax (e.g., `IDENTITY`, `DATETIME2`, `NVARCHAR`).
5. **Safety Constraint:** Do NOT generate, modify, or overwrite other deliverables.
6. **Audit Policy:** After generation, you MUST follow the repository audit policy (AGENTS.md section 7). Create a new audit log in `docs/audits/` using the `AUDIT_TEMPLATE.md` format.