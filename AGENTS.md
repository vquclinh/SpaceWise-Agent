# AGENTS.md — SpaceWise Agent (CS486 Group G08)

This is the main agent-facing rulebook. OpenCode reads it as project-level rules. Follow it for all work in this repository.

## 1. Project scope and current phase

- **Project:** Campus Space Management System, CS486 Introduction to Database Systems, Group **G08**.
- **Current phase: Phase 1 — database design deliverables and validation.** The agent transforms the business requirement into the 7 Phase 1 outputs and validates them.
- **Setup stage now:** the repository is currently being prepared (OpenCode workflow + team scaffold). The 7 outputs in `outputs/` are generated/refined **later by the group**, not during setup. The detailed skill is `.opencode/skills/db-design-pipeline/SKILL.md`.
- **Out of scope for Phase 1:** frontend, backend, and deployment implementation. Do not create such code now (see section 10).

## 2. Source-of-truth order

When details conflict, prefer in this order:

1. `CS486_Project.pdf` — the official requirement (deliverable list, Query Design format).
2. `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` — the detailed specification (entities, attributes, relationships, business rules, validation logic, example queries).
3. `req/business-requirement.md` — the condensed business requirement.

Run `ls -la` to detect new files before assuming anything exists. Use paths relative to the repository root; do not assume any contributor's absolute machine path.

## 3. Editing rules

- Keep all authored repository files **English only**.
- **Do not invent** group, member, or model information. The group is `G08`; members and IDs are fixed in `AGENT.md`.
- **Prefer targeted edits** over regenerating all outputs.
- If changing one output can affect related outputs, **inspect upstream/downstream files** and keep the whole set consistent (pipeline order: `01 → 02 → 03 → 04 → 05 → 06 → 07`).
- Avoid unrelated rewrites; change only what the task requires.
- Step 1 must not include physical database details. For example: Foreign Keys (FK),...

## 4. SQL Server rules

- Target DBMS is **Microsoft SQL Server**. Files `05`, `06`, `07` use SQL Server syntax (e.g. `IDENTITY`, `DATETIME2`, `GETDATE()`, `TOP`, `NVARCHAR`).
- Use primary keys, foreign keys, `NOT NULL` where appropriate, `CHECK` constraints where appropriate, `DEFAULT` values where useful, and indexes for important lookup/filter paths.
- If a business rule cannot be enforced with a simple `CHECK` (e.g. no overlapping approved bookings), document a SQL Server-compatible strategy (trigger logic, transaction-level validation, or application-layer enforcement) and explain the tradeoff in the design validation document.
- Do **not** validate the final SQL on Supabase/PostgreSQL/MySQL. Use a SQL Server-compatible environment (local SQL Server, a SQL Server container, or Azure SQL).
- Core entities (Users, Spaces, Bookings, Maintenance) must include created_at and updated_at.

## 5. Phase 1 output rules

All outputs go to `outputs/` with these exact names (group number `G08`):

1. `outputs/01-business-req-analysis-G08.md`
2. `outputs/02-erd-design-G08.md`
3. `outputs/03-logical-design-G08.md`
4. `outputs/04-design-validation-G08.md`
5. `outputs/05-db-definition-G08.sql`
6. `outputs/06-sample-data-G08.sql`
7. `outputs/07-query-design-G08.sql`

Follow the 7-step pipeline in order; do not jump straight to DDL. The query file `07` must contain **at least 20 queries total**, **at least 5 per member**, each with Business question / Target user(s) / Why this query is useful / SQL statement. The detailed step requirements live in `.opencode/skills/db-design-pipeline/SKILL.md`.

## 6. Team workflow rules

- Standard loop: **generate → refine → validate**, each producing an audit.
- Commands (setup stage): `/audit-smoke-test` (the only setup-safe command) and `/design-db` (a generic example placeholder to adapt later). The Phase 1 production commands (generate/refine/validate/SQL-test) are **not** in the repo yet — the group will create or adapt them when Phase 1 work begins.
- Suggested split: Duyen → 01+02; Thi → 03+04; Vi → 05+06; Linh → integration + 07 + validation/report notes. Everyone reviews the whole set; `07` is shared (each member adds their ≥5 queries).

## 7. Audit policy

**Every meaningful AI-assisted repository change must create an audit Markdown file under `audits/`**, using `audits/AUDIT_TEMPLATE.md`, numbered with the next available number. Small manual typo-only edits do **not** need a separate audit unless they affect workflow, deliverables, SQL, or project instructions.

Future prompts may simply say: **"Follow the repository audit policy."** That means: do the work, then write an audit as specified here.

The audit policy applies to changes in:

- `AGENT.md`, `AGENTS.md`
- `.opencode/commands/`, `.opencode/skills/`
- `outputs/` and any SQL files
- `scripts/`
- `README.md` when workflow/project instructions change
- future `db/`, `backend/`, `frontend/`, `deploy/` folders if they are added later

Each audit must include:

- **Task goal**
- **Operator/member** (if known)
- **Tool used**
- **Provider/model/variant used**
- **OpenCode command used** (if any)
- **Files created/changed**
- **What was evaluated**
- **Issues found**
- **Changes made**
- **Improvement classification** (one or more): output refinement · AGENTS.md improvement · SKILL.md improvement · command improvement · validation/test improvement · documentation improvement · no agent/skill/command change needed
- **Validation commands and results**
- **Risks/caveats**
- **Git status summary**
- **Recommended next steps**

For generation/refinement/validation/test audits, also record **which Phase 1 step or output** was evaluated.

## 8. Validation policy

- **Setup stage (no deliverables yet):**
  - `find outputs -maxdepth 2 -type f | sort`
  - `bash scripts/check_required_files.sh --setup`
  - `bash scripts/validate_sql.sh --setup`
- **Final stage (after outputs exist):**
  - `bash scripts/check_required_files.sh --final G08`
  - `bash scripts/validate_sql.sh --final G08`
- Record the commands and their results in the audit. Final-mode failures are expected until the 7 outputs exist.

## 9. Git and safety rules

- Do **not** run `git add`, `git commit`, or `git push` unless the user explicitly asks.
- Never commit API keys, tokens, `.env`, or local OpenCode state.
- Review diffs before committing.
- Keep `outputs/` empty except `.gitkeep` until the team runs generation.

## 10. Future deployment policy

- Deployment, frontend, and backend may be **future** responsibilities, but **Phase 1 does not include them**.
- Do **not** generate frontend/backend/deployment code during Phase 1 unless the team explicitly requests it after the relevant requirements are clear.
- If such work starts later, it gets its own folders (`db/`, `backend/`, `frontend/`, `deploy/`) and is covered by the same audit policy (section 7).

## Critical business rules (must be enforced/represented)

1. The same space cannot have two **approved** bookings with overlapping time periods.
2. A space that is **under maintenance, temporarily closed, or retired** cannot be booked.
3. Booking **approval/rejection** stores the deciding staff member, decision time, and decision note — and a **rejection reason** when the booking is rejected.
4. **Check-in** records the actual start time, who checked it in (checked-in-by), and the initial condition of the space.
5. **Check-out / completion** records the actual end time, the final condition of the space, and usage notes.
6. **Maintenance records** include the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note.
7. **Historical booking and maintenance records must be preserved** (so staff can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings).
