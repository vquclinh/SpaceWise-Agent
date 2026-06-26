# Project Overview — CS486 G08

## Course / project

- **Course:** CS486 — Introduction to Database Systems.
- **Project:** Campus Space Management System.
- **Group:** G08.

## Project purpose

Design a database-backed system for shared campus space **booking, approval, usage sessions, maintenance, and history** — so the School can manage shared spaces fairly, avoid overlapping bookings, prevent the use of unavailable spaces, and preserve usage history.

## Phase 1 purpose

Phase 1 transforms the business requirement into **database design deliverables** (analysis → ERD → logical design → validation → DDL → sample data → queries). No application/frontend/backend/deployment work is part of Phase 1.

## Required Phase 1 outputs

1. `outputs/01-business-req-analysis-G08.md`
2. `outputs/02-erd-design-G08.md`
3. `outputs/03-logical-design-G08.md`
4. `outputs/04-design-validation-G08.md`
5. `outputs/05-db-definition-G08.sql`
6. `outputs/06-sample-data-G08.sql`
7. `outputs/07-query-design-G08.sql`

**Target DBMS:** Microsoft SQL Server.

## Current repository status

- An **OpenCode scaffold** exists (shared rules, shared skill, setup-safe commands, validation scripts).
- **Per-task command and skill files exist as placeholders** (`.opencode/commands/0{1..7}-generate-*.md` and `.opencode/skills/db-design-pipeline/<NN>-*/SKILL.md`).
- These placeholders are **not production-ready** until the assigned task owner completes them.
- **Outputs must only be created when the team explicitly starts Phase 1 generation** — setup/documentation tasks do not add or modify deliverables.

## Key paths

| Path | What it is |
|---|---|
| `req/business-requirement.md` | Condensed business-domain input for Phase 1. |
| `AGENT.md` | Course-facing manifest (group, tool/model policy, DBMS, status). |
| `AGENTS.md` | Agent-facing rulebook (rules, source-of-truth order, audit/validation policy). |
| `.opencode/commands/` | OpenCode commands (2 ready + 7 per-task placeholders). |
| `.opencode/skills/db-design-pipeline/` | Shared skill (common contract) + 7 task-specific skill placeholders. |
| `docs/audits/` | Audit history (+ `AUDIT_TEMPLATE.md`). |
| `outputs/` | The 7 Phase 1 deliverables (created by the group during Phase 1). |
| `scripts/` | `check_required_files.sh`, `validate_sql.sh` (setup/final validation). |

## Why `docs/audits/` matters

`docs/audits/` is the **evidence source for the final report's agent improvement process**: each audit records what was evaluated, the issues found, the changes made, and the exact provider/model used per session. Every meaningful AI-assisted change must add an audit there (template: `docs/audits/AUDIT_TEMPLATE.md`).
