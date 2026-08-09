---
description: Generate ONLY Task 15 (Index Tuning Report).
---

# /15-generate-index-tuning-report

This command executes only the Phase 2 Index Tuning Report task (Task 15).

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use
   `.opencode/skills/db-design-pipeline/15-index-tuning-report/SKILL.md`.
2. **Read Inputs:**
   - `CS486_Project_Phase02.pdf`
   - `req/business-requirement-P2.md`
   - `AGENTS.md`
   - `outputs/09-updated-erd-and-logical-design-G08.md`
   - `outputs/10-schema-migration-G08.sql`
   - `outputs/11-concurrency-design-G08.md`
   - `outputs/12-concurrency-implementation-G08.sql`
   - `outputs/14-data-generator-G08/`
   - `outputs/16-analytical-queries-G08.sql` if it already exists
3. **Generate Output:** Create or update ONLY:
   - `outputs/15-index-tuning-report-G08.md`
4. **Self-Review:** Confirm the report tunes:
   - booking conflict check;
   - room finder query;
   - two reporting queries other than the room finder.
5. **Measurement Honesty:** If SQL Server execution is unavailable, do not
   fabricate timings. Document the measurement gap and provide exact benchmark
   steps for SQL Server.
6. **Safety Constraint:** Do NOT generate, modify, or overwrite outputs 01-14
   or 16. Do not edit unrelated commands or skills.
7. **Audit Policy:** Follow `AGENTS.md` section 8. Create the next numbered
   audit in `docs/audits/` and record Phase 2 Task 15.

