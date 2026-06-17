# AGENT.md — SpaceWise Agent

## Group Information

| Field | Value |
|---|---|
| Project | Campus Space Management System |
| Course | CS486 — Introduction to Database Systems |
| Group Number | GXX |
| Members | STUDENT_NAME_1, STUDENT_NAME_2, ... |

## LLM Configuration

| Field | Value |
|---|---|
| Tool | OpenCode |
| Provider | DeepSeek |
| Model | DeepSeek V4 Pro |

> The values above are the configuration the group reports as its primary agent. Update `Group Number`, `Members`, and the LLM `Model` to match what the group actually uses before submission.

## Auxiliary Tooling

OpenCode + DeepSeek is the **primary** agent that generates the 7 deliverables. Other agents (e.g. Claude Code) were used only for **auxiliary setup review and fixes** recorded under `audits/`, and not for generating any deliverable.

## Agent Instructions

See `AGENTS.md` for detailed project-level agent rules and workflow instructions.

## Skill Reference

See `SKILL.md` for the skill manifest and `.opencode/skills/db-design-pipeline/SKILL.md` for the full pipeline definition.