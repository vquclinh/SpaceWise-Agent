# AGENT.md — SpaceWise Agent

## Group Information

| Field | Value |
|---|---|
| Project | Campus Space Management System |
| Course | CS486 — Introduction to Database Systems |
| Group Number | G08 |
| Members | Truong Thi My Duyen — 24125028<br>Huynh Le Bao Thi — 24125080<br>Le Quoc Vi — 24125085<br>Vo Quoc Linh — 24125065 |

## LLM Configuration

| Field | Value |
|---|---|
| Tool | OpenCode (fixed primary tool) |
| Provider / Model | Not fixed globally — each member may use a different provider/model through OpenCode |
| Per-session record | Every audit in `audits/` must record the exact provider/model used in that session |
| DBMS | Microsoft SQL Server |

> OpenCode is the fixed primary tool. We deliberately do **not** pin one global model: members may pick whatever provider/model works best per OpenCode session. The rule that keeps this honest is that each audit records the exact model/provider used, and the final report lists **all** models actually used across the group.

## Auxiliary Tooling

OpenCode is the **primary** tool that generates the 7 deliverables. Other agents (e.g. Claude Code) may be used only for **auxiliary review and fixes** recorded under `audits/`, and not for generating any deliverable.

## Agent Instructions

See `AGENTS.md` for detailed project-level agent rules and workflow instructions.

## Skill Reference

See `SKILL.md` for the skill manifest and `.opencode/skills/db-design-pipeline/SKILL.md` for the full pipeline definition.