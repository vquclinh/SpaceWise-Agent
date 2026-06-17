---
description: Run the database design pipeline from a business requirement file
---

Use the database design pipeline skill in:

`.opencode/skills/db-design-pipeline/SKILL.md`

## Sources to read first

Read these before designing, in this order of authority:

1. The requirement file passed as the argument (usually `req/business-requirement.md`):

   `$ARGUMENTS`

2. `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` — the detailed source of truth, when present. Use it for entities, attributes, relationships, business rules, validation logic, and example queries.

3. `CS486_Project.pdf` — the official requirement, if it is readable in your environment. The official deliverable list and the Query Design format come from here.

If a detail conflicts, prefer the official `CS486_Project.pdf`, then `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md`, then the requirement argument.

## What to do

- Follow the 7-step Phase 1 pipeline defined in the skill, in order. Do not jump straight to DDL.
- Later, generate exactly these 7 outputs in `outputs/` (the group number is `G08`):
  1. `outputs/01-business-req-analysis-G08.md`
  2. `outputs/02-erd-design-G08.md`
  3. `outputs/03-logical-design-G08.md`
  4. `outputs/04-design-validation-G08.md`
  5. `outputs/05-db-definition-G08.sql`
  6. `outputs/06-sample-data-G08.sql`
  7. `outputs/07-query-design-G08.sql`

## Rules

- Do not invent student names. The group number is `G08`; use it in all output filenames.
- Keep all generated content in English only.
- Prefer updating a single output file when the user asks for a fix, instead of regenerating everything.
- After a generation or validation run, record what happened in a new audit under `audits/` (steps run, evaluation, and any refinements) so the group's improvement process is documented.
