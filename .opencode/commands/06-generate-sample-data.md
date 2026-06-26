---
description: Generate ONLY Step 6 (Sample Data) for the database.
---
# /06-generate-sample-data

This command generates a SQL script to populate your database with realistic sample data.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined in `.opencode/skills/db-design-pipeline/06-sample-data/SKILL.md`.
2. **Read Inputs:** Read `outputs/03-logical-design-G08.md` and `outputs/05-db-definition-G08.sql` to understand the table schema and constraints. 
3. **Generate Output:** Create or update ONLY `outputs/06-sample-data-G08.sql`.
4. **Data Quality:** The data must be realistic, cover all entity types, and—most importantly—include edge cases (like rejected bookings, no-shows, and spaces under maintenance) so that your team's queries in Step 7 have interesting data to return.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite other deliverables.
6. **Audit Policy:** After generation, you MUST follow the repository audit policy (AGENTS.md section 7). Create a new audit log in `docs/audits/` using the `AUDIT_TEMPLATE.md` format.