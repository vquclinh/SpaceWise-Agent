# AGENT.md — SpaceWise Agent (CS486 Group G08)

Course-facing description of the group agent setup.

## Project

| Field | Value |
|---|---|
| Project | Campus Space Management System |
| Course | CS486 — Introduction to Database Systems |
| Group | G08 |
| DBMS | Microsoft SQL Server |

## Members

| Member | Student ID |
|---|---|
| Truong Thi My Duyen | 24125028 |
| Huynh Le Bao Thi | 24125080 |
| Le Quoc Vi | 24125085 |
| Vo Quoc Linh | 24125065 |

## Tool and model policy

- **Primary tool:** OpenCode (fixed).
- **Model policy:** the provider/model/variant is **selected per session** and **must be recorded in each audit**. We deliberately do **not** hardcode a single global model — members may use different providers/models. The final report lists every model actually used.
- Other agents (e.g. Claude Code) are **auxiliary** only (review/fixes recorded under `docs/audits/`); they do not generate deliverables.

## Current status: Phase 2 system extension

Phase 1 is complete: outputs `01` through `07` exist in `outputs/` and form the
migration baseline. Phase 2 extends that baseline with maintenance impact
levels, SQL Server concurrency control, asset-level facility tracking, large
data generation, indexing analysis, and analytical reports.

Current Phase 2 deliverables in this repository:

- Outputs `08`, `09`, and `10` define and migrate the Phase 2 schema.
- Outputs `11`, `12`, and `13` document and test concurrency control.
- Outputs `14`, `15`, and `16` provide the volume data generator, index tuning
  report, and analytical reporting SQL.

The OpenCode workflow now uses task-specific command and skill files under
`.opencode/commands/` and `.opencode/skills/db-design-pipeline/`. Tasks 14,
15, and 16 each have their own command and skill:

- `/14-generate-data-generator` with
  `.opencode/skills/db-design-pipeline/14-data-generator/SKILL.md`
- `/15-generate-index-tuning-report` with
  `.opencode/skills/db-design-pipeline/15-index-tuning-report/SKILL.md`
- `/16-generate-analytical-queries` with
  `.opencode/skills/db-design-pipeline/16-analytical-queries/SKILL.md`

No frontend, backend, or deployment work is part of Phase 1 or Phase 2.

## Phase workflow

For every generated, refined, or validated deliverable:

1. Read the official project PDF and the immediate previous output first.
2. Generate or refine only the target deliverable.
3. Validate with SQL Server-compatible tooling when SQL execution is required.
4. Record an audit under `docs/audits/` for every meaningful repository change.

## Locations

- **Outputs:** `outputs/` (Phase 1 deliverables `01`–`07` and Phase 2 deliverables `08`–`16`, named with `G08`).
- **Audits:** `docs/audits/` (one per meaningful AI-assisted change, following `docs/audits/AUDIT_TEMPLATE.md`).

## Why audits matter

Audits are the **evidence source** for the final report's **agent improvement process**: they record what was evaluated at each step, what issues were found, what was changed, and which provider/model was used. See `AGENTS.md` for the full audit policy and `.opencode/skills/db-design-pipeline/SKILL.md` for the detailed design skill.
