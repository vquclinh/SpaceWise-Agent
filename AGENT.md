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
- Other agents (e.g. Claude Code) are **auxiliary** only (review/fixes recorded under `audits/`); they do not generate deliverables.

## Current status: setup-only

The repository is currently a **setup-only scaffold**. Vo Quoc Linh's current role is to set up the OpenCode repo workflow for the team — **not** to generate Phase 1 deliverables. `outputs/` stays empty except `.gitkeep`.

The only setup-safe command is `/audit-smoke-test` (rehearses the audit policy). `/design-db` is a generic example placeholder. No frontend/backend/deployment work is part of setup.

## Phase 1 workflow (later, by the group)

When the group starts Phase 1 (database design deliverables and validation), they will create/adapt the production commands and follow this workflow:

1. **Generate** the 7 Phase 1 outputs.
2. **Review / refine** outputs.
3. **Validate** the output set (`scripts/check_required_files.sh --final G08`, `scripts/validate_sql.sh --final G08`).
4. **Run SQL Server validation/testing** when the outputs exist, on a SQL Server-compatible environment.
5. **Record audits** for every meaningful change.

## Locations

- **Outputs:** `outputs/` (the 7 Phase 1 deliverables, named with `G08`).
- **Audits:** `audits/` (one per meaningful AI-assisted change, following `audits/AUDIT_TEMPLATE.md`).

## Why audits matter

Audits are the **evidence source** for the final report's **agent improvement process**: they record what was evaluated at each step, what issues were found, what was changed, and which provider/model was used. See `AGENTS.md` for the full audit policy and `.opencode/skills/db-design-pipeline/SKILL.md` for the detailed design skill.
