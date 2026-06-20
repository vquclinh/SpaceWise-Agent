---
description: (Example) Generic entry point for the database design pipeline — for the team to adapt later
---

# /design-db — generic example command

This is a **generic, demo-compatible placeholder** entry point for the database design pipeline. It is **not** the current setup task and it does **not** generate the 7 Phase 1 outputs now.

The repository is currently in **setup-only** mode (see `README.md` and `AGENTS.md`). The group will create or adapt the real Phase 1 generation/refinement/validation commands later, when they actually begin Phase 1 work.

## What it is for

A future/example starting point the team can adapt. When the group is ready to design the database, they can run this against a business requirement file:

```text
/design-db req/business-requirement.md
```

- The detailed database-design skill is `.opencode/skills/db-design-pipeline/SKILL.md` — read it for the full 7-step pipeline, SQL Server requirements, and quality checklists.
- Sources of truth (prefer in this order if details conflict): `CS486_Project.pdf` → `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` → the requirement file passed as `$ARGUMENTS`.

## Rules if this command is ever used

- Do **not** modify `outputs/` during the current setup stage.
- Keep all generated content English only; group number is `G08`; do not invent student names.
- **Follow the repository audit policy** (`AGENTS.md` section 7), writing an audit with `audits/AUDIT_TEMPLATE.md` and the next available number.
