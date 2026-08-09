---
description: Generate ONLY Task 14 (Phase 2 Data Generator).
---

# /14-generate-data-generator

This command executes only the Phase 2 Data Generator task (Task 14).

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use
   `.opencode/skills/db-design-pipeline/14-data-generator/SKILL.md`.
2. **Read Inputs:**
   - `CS486_Project.pdf`
   - `CS486_Project_Phase02.pdf`
   - `req/business-requirement-P2.md`
   - `AGENTS.md`
   - Phase 1 outputs `outputs/01-business-req-analysis-G08.md` through
     `outputs/07-query-design-G08.sql`
   - Phase 2 outputs:
     - `outputs/08-requirement-change-analysis-G08.md`
     - `outputs/09-updated-erd-and-logical-design-G08.md`
     - `outputs/10-schema-migration-G08.sql`
     - `outputs/11-concurrency-design-G08.md`
     - `outputs/12-concurrency-implementation-G08.sql`
     - `outputs/13-concurrency-tests-G08/`
3. **Generate Output:** Create or update ONLY:
   - `outputs/14-data-generator-G08/README.md`
   - `outputs/14-data-generator-G08/01-generate-phase2-volume-data-G08.sql`
   - `outputs/14-data-generator-G08/02-validate-phase2-volume-data-G08.sql`
4. **Self-Review:** Confirm the generator:
   - targets Microsoft SQL Server only;
   - requires the migrated Phase 2 schema;
   - generates at least three academic years and at least 100,000 bookings;
   - includes maintenance, cancellations, no-shows, advisory acknowledgements,
     System decisions, and escalation alerts;
   - is non-destructive and refuses partial generated workloads.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite outputs 01-13,
   15, or 16. Do not edit unrelated commands or skills.
6. **Audit Policy:** Follow `AGENTS.md` section 8. Create the next numbered
   audit in `docs/audits/` and record Phase 2 Task 14.

