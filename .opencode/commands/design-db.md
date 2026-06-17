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
- Later, generate exactly these 7 outputs in `outputs/` (replace `GXX` with the real group number):
  1. `outputs/01-business-req-analysis-GXX.md`
  2. `outputs/02-erd-design-GXX.md`
  3. `outputs/03-logical-design-GXX.md`
  4. `outputs/04-design-validation-GXX.md`
  5. `outputs/05-db-definition-GXX.sql`
  6. `outputs/06-sample-data-GXX.sql`
  7. `outputs/07-query-design-GXX.sql`

## Rules

- Do not invent the group number or student names. If the group number is unknown, keep `GXX` and tell the user to set it.
- Keep all generated content in English only.
- Prefer updating a single output file when the user asks for a fix, instead of regenerating everything.
- After a generation or validation run, record what happened in a new audit under `audits/` (steps run, evaluation, and any refinements) so the group's improvement process is documented.
