---
description: Generate ONLY Task 16 (Analytical Queries).
---

# /16-generate-analytical-queries

This command executes only the Phase 2 Analytical Queries task (Task 16).

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use
   `.opencode/skills/db-design-pipeline/16-analytical-queries/SKILL.md`.
2. **Read Inputs:**
   - `CS486_Project_Phase02.pdf`
   - `req/business-requirement-P2.md`
   - `AGENTS.md`
   - `outputs/09-updated-erd-and-logical-design-G08.md`
   - `outputs/10-schema-migration-G08.sql`
   - `outputs/14-data-generator-G08/`
   - `outputs/15-index-tuning-report-G08.md` if it already exists
3. **Generate Output:** Create or update ONLY:
   - `outputs/16-analytical-queries-G08.sql`
4. **Self-Review:** Confirm the SQL file implements all reports from
   `CS486_Project_Phase02.pdf` section 1.3:
   - total approved booking hours of each space for a given semester;
   - approved bookings by weekday and hour for a given semester;
   - available spaces satisfying required capacity and facility list within a
     given time period;
   - approved bookings affected when maintenance escalates to `OutOfService`.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite outputs 01-15.
   Do not edit unrelated commands or skills.
6. **Audit Policy:** Follow `AGENTS.md` section 8. Create the next numbered
   audit in `docs/audits/` and record Phase 2 Task 16.

