# AGENTS.md — SpaceWise Agent

CS486 Introduction to Database Systems project. This agent transforms business requirements into database design artifacts for the Campus Space Management System.

## Recurring Context

- Root directory: the repository root (the folder containing this `AGENTS.md`). Use paths relative to it; do not assume any one contributor's absolute machine path.
- This is a CS486 course project.
- Run `ls -la` to detect new files before assuming anything exists.
- The primary business requirement is in `req/business-requirement.md`.
- The detailed source of truth is `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md`; the official requirement is `CS486_Project.pdf`.
- Read all content in English only and write all generated content in English only.

## Database Design Agent Rules

This project transforms business requirements into database design artifacts.

## Workflow Order

Always follow this order:

1. Analyze business requirements.
2. Produce conceptual ERD using Crow's Foot notation.
3. Produce logical database design (tables, columns, types, keys, constraints).
4. Validate the design against business rules.
5. Generate DDL scripts.
6. Generate sample data.
7. Generate query design.

Do not jump directly to DDL. The documents from the prior steps should be followed in the later steps.

## Required Outputs

All outputs go to the `outputs/` directory with the naming convention `NN-artifact-name-G<GroupNumber>.ext`:

1. `outputs/01-business-req-analysis-GXX.md`
2. `outputs/02-erd-design-GXX.md`
3. `outputs/03-logical-design-GXX.md`
4. `outputs/04-design-validation-GXX.md`
5. `outputs/05-db-definition-GXX.sql`
6. `outputs/06-sample-data-GXX.sql`
7. `outputs/07-query-design-GXX.sql`

## DBMS

Use Microsoft SQL Server unless the user specifies another DBMS.

## Design Rules

- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement -> entity -> relationship -> table -> constraint.
- Use Mermaid `erDiagram` for ERD.
- Do not silently invent business rules.
- Do not invent the group number or student names. Leave `GXX` as a placeholder until the group fills it in.
- Step 7 (Query Design) must contain at least 5 queries, and each query must include: Business question, Target user(s), Why this query is useful, and the SQL statement.
- Write all generated content in English only.

## Agent Tooling Note

The primary project agent is OpenCode with DeepSeek. Other agents (e.g. Claude Code) may be used only for auxiliary setup review and fixes, not for generating the 7 deliverables.

## Critical Business Rules

1. The same space cannot have two approved bookings with overlapping time periods.
2. Spaces under maintenance, temporarily closed, or retired cannot be booked.

## Input Files

- `req/business-requirement.md` — condensed business requirement.
- `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` — full project specification with additional detail.