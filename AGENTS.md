# AGENTS.md — SpaceWise Agent (CS486 Group G08)

This is the main agent-facing rulebook. OpenCode reads it as project-level rules. Follow it for all work in this repository.

## 1. Project scope and current phase

- **Project:** Campus Space Management System, CS486 Introduction to Database Systems, Group **G08**.
- **Current phase: Phase 2 — System Extension.** The agent extends the completed Phase 1 database (deliverables 01–07) to satisfy the Phase 2 requirements in `CS486_Project_Phase02.pdf`, focused on **maintenance impact levels** (advisory vs. out-of-service), **concurrency control** for simultaneous booking/approval, and **granular asset tracking** (individual units with serial numbers). Phase 2 produces Tasks 08–16 and updates `AGENT.md`/`SKILL.md` to document the improvements made.
- **Phase 1 is complete:** the seven Phase 1 outputs in `outputs/` exist and are the migration baseline for Phase 2. Phase 2 must preserve them — no renames or drops of Phase 1 tables, columns, or data.
- **Out of scope for Phase 2:** frontend, backend, and deployment implementation. Do not create such code now (see section 11).

## 2. Source-of-truth order

When details conflict, prefer in this order:

1. `CS486_Project_Phase02.pdf` — the official Phase 2 requirement (business changes, deliverable list, report requirements).
2. `req/business-requirement-P2.md` — primary Phase 2 business logic (condensed requirement addendum) — and `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` — supplementary reference for Phase 2 domain logic, SQL Server concurrency strategy, and trigger patterns.
3. Phase 1 outputs in `outputs/` (01–07) — the mandatory migration baseline for Phase 2; Phase 2 reuses Phase 1 tables, columns, and data verbatim and extends them.
4. Original Phase 1 requirements (`CS486_Project.pdf`, `req/business-requirement.md`, `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md`) — remain in force for everything Phase 2 does not explicitly change.

**Step Precedence Rule:** When working on a new step, the output of the immediate previous step (e.g., Output 08 for Output 09, or Output 01 for Step 2 in Phase 1) is the primary authority. Previous Step Outputs take precedence over the requirement documents and the Project Specs for design consistency. For Phase 2 tasks, the Phase 1 outputs (01–07) are the migration baseline and win over any Phase 2 document that would require renaming or dropping Phase 1 structures.

Run `ls -la` to detect new files before assuming anything exists. Use paths relative to the repository root; do not assume any contributor's absolute machine path.

## 3. Editing rules

- Keep all authored repository files **English only**.
- **Do not invent** group, member, or model information. The group is `G08`; members and IDs are fixed in `AGENT.md`.
- **Prefer targeted edits** over regenerating all outputs.
- If changing one output can affect related outputs, **inspect upstream/downstream files** and keep the whole set consistent (pipeline order: `01 → 02 → 03 → 04 → 05 → 06 → 07`).
- Avoid unrelated rewrites; change only what the task requires.
- **Naming Convention:** tables and columns use `snake_case` (e.g., `facility_assets`, `serial_number`); enum values use PascalCase (e.g., `'Advisory'`, `'OutOfService'`). Phase 2 must keep every Phase 1 table/column name verbatim when extending the schema.
- **Conceptual vs. Logical Boundary (pipeline order):** Steps 1 & 2 (Conceptual Design) must NEVER include physical implementation details such as Data Types (int, string, datetime), Foreign Keys (FK), or Indexes. These are reserved for Step 3 (Logical Design) onward.
- **Lifecycle & Optionality Rule:** Assume a lifecycle starting from zero. Use Optional notations (`0..n` or `0..1`) for relationships unless there is a specific, absolute business necessity for a Mandatory (`1..n`) relationship. For example, a new Department may have zero Users initially.
- **Notation Standard:** While using Mermaid Crow's Foot notation for technical convenience, the design logic must prioritize the Chen/Hybrid mindset. Always double-check that the "1" and "Many" sides match business reality, not just table-linking logic.
- **Mermaid ERD rendering (Step 2):** In Step 2 (Conceptual ERD), use a simple 2-column format for entity boxes. Due to Mermaid syntax, use `attr` as a generic placeholder type for all attributes, but do not use the `PK` or `FK` markers in the diagram. Conceptual identifiers should be clear from the narrative, not technical markers in the boxes.
- **Strict Conceptual Purity — Home ID vs. Visitor ID:**
  An identifier (e.g., user_id, space_id) belongs ONLY inside its defining entity box.
  It is strictly FORBIDDEN to appear in other entities as a linking field (Foreign Key) during Step 1 & 2.
  Relationship lines represent the connections; physical Foreign Key columns must only appear starting from Step 3 (Logical Design).
- **Relationship Labeling (Step 3):** In the Step 3 Logical Schema Diagram, Mermaid relationship lines between tables must be labeled with the actual Foreign Key column name used for the connection (e.g., `user_accounts ||--o{ bookings : "requester_id"`), instead of descriptive verbs. This makes the mapping between the relationship line and the FK column explicit at a glance.

## 4. SQL Server rules

- **Strict DBMS rule: Microsoft SQL Server is the only permitted DBMS.** PostgreSQL is forbidden — no `tsrange`, no `EXCLUDE USING gist`/`btree_gist`, no `DEFERRABLE`/deferred constraint triggers, no `GIN`/array indexes, no `'infinity'` timestamps, no `SET LOCAL`. Every Phase 2 SQL file (Tasks 08–16) must use SQL Server syntax only.
- Target DBMS is **Microsoft SQL Server**. Files `05`, `06`, `07` (Phase 1) and Tasks `10`, `12`, `13`, `14`, `16` (Phase 2) use SQL Server syntax (e.g. `IDENTITY`, `DATETIME2`, `GETDATE()`, `TOP`, `NVARCHAR`).
- Use primary keys, foreign keys, `NOT NULL` where appropriate, `CHECK` constraints where appropriate, `DEFAULT` values where useful, and indexes for important lookup/filter paths.
- If a business rule cannot be enforced with a simple `CHECK` (e.g. no overlapping approved bookings), document a SQL Server-compatible strategy (trigger logic, transaction-level validation, or application-layer enforcement) and explain the tradeoff in the design validation document.
- Do **not** validate the final SQL on Supabase/PostgreSQL/MySQL. Use a SQL Server-compatible environment (local SQL Server, a SQL Server container, or Azure SQL).
- Core entities (Users, Spaces, Bookings, Maintenance) must include created_at and updated_at.

## 5. Phase 2 technical rules (mandatory logic)

- **Concurrency Control:** All booking-creation and approval logic (instant-booking and manual approval) must be safe under simultaneous requests. Use SQL Server mechanisms only: `SERIALIZABLE` transactions with `WITH (UPDLOCK, HOLDLOCK)` range-locking on the conflict check (stored-procedure pattern), or `sp_getapplock` per-space locks. The Phase 1 overlap trigger is a validation backstop, not the concurrency mechanism. The invariant — no two `Approved`/`CheckedIn` bookings overlap on the same space — must hold under concurrency; the application retries on deadlock (1205) / lock timeout (1222).
- **Time Logic — Reserved vs. Actual Occupancy:** Distinguish **Reserved Time** (`bookings.requested_start_time` / `requested_end_time`) from **Actual Occupancy Time** (`usage_sessions.actual_start_time` / `actual_end_time`). The booking status drives which interval the conflict check uses: `Approved`/`CheckedIn` block with the reserved interval; `Completed` blocks nothing. Early check-out must release the remaining reserved window **immediately** — derive it from status + actual end time (no trigger, timer, or stored flag; keep the fact derived for 3NF).
- **Asset Tracking — individual units:** Track facilities as **individual assets with serial numbers** (`facility_assets` with `asset_id` + `serial_number`) instead of quantity counts. Phase 1 `space_facilities.quantity` stays as catalogue metadata; unit counts must be computed from asset rows (view), never stored in sync. Maintenance may target a specific asset (`maintenance_records.asset_id`), and a booking must be blocked when a facility marked **required** for the space has no available unit.

## 6. Phase 1 and Phase 2 output rules

All outputs go to `outputs/` with these exact names (group number `G08`):

1. `outputs/01-business-req-analysis-G08.md`
2. `outputs/02-erd-design-G08.md`
3. `outputs/03-logical-design-G08.md`
4. `outputs/04-design-validation-G08.md`
5. `outputs/05-db-definition-G08.sql`
6. `outputs/06-sample-data-G08.sql`
7. `outputs/07-query-design-G08.sql`

Follow the 7-step pipeline in order; do not jump straight to DDL. The query file `07` must contain **at least 20 queries total**, **at least 5 per member**, each with Business question / Target user(s) / Why this query is useful / SQL statement. The detailed step requirements live in `.opencode/skills/db-design-pipeline/SKILL.md`.

**Phase 2 outputs (Tasks 08–16)** — exact names, group `G08`:

8. `outputs/08-requirement-change-analysis-G08.md`
9. `outputs/09-updated-erd-and-logical-design-G08.md`
10. `outputs/10-schema-migration-G08.sql`
11. `outputs/11-concurrency-design-G08.md`
12. `outputs/12-concurrency-implementation-G08.sql`
13. `outputs/13-concurrency-tests-G08/` (conflict demonstration + prevention scripts and results)
14. `outputs/14-data-generator-G08/` (data generation scripts)
15. `outputs/15-index-tuning-report-G08.md`
16. `outputs/16-analytical-queries-G08.sql`

Phase 2 constraints: `14` must generate **at least 3 academic years** of realistic data with **at least 100,000 booking records** (up to 500,000 if needed to demonstrate indexing), including maintenance, cancellations, no-shows, and advisory acknowledgements; `16` must implement all reports listed in `CS486_Project_Phase02.pdf` §1.3; `15` must tune the booking conflict check, the room-finder query, and **two other reporting queries** with before/after execution plans and timings; `13` must demonstrate a concurrency conflict and its prevention; `10` (schema migration) must preserve existing Phase 1 data and document the migration approach.

## 7. Team workflow rules

- Standard loop: **generate → refine → validate**, each producing an audit.
- **Working commands now:** `/audit-smoke-test` (safe rehearsal) and the completed Phase 1 generation commands `/01-generate-business-req` … `/07-generate-query-design`.
- **Phase 2 task placeholders (NOT production-ready yet):** only the shared skill and the Task 08 skill exist so far. Per-task commands and task skills for Tasks 08–16 must be authored by their assigned owners before use — **until a task command/skill exists, do not use it to generate that Phase 2 output.** When a task owner fills one in, they must follow the repository audit policy (section 8).
- The **shared skill** `.opencode/skills/db-design-pipeline/SKILL.md` remains the common contract for database design rules (Phase 1 and Phase 2).
- **Outputs discipline:** `outputs/` holds only team-generated deliverables — the completed Phase 1 set (01–07) and the Phase 2 set (08–16) as it is produced — plus `.gitkeep`. Phase 2 extends the Phase 1 outputs through migration and the new Task 08–16 files; do not regenerate Phase 1 outputs from scratch unless the Phase 2 task explicitly requires it.
- Suggested split (Phase 1, completed): Duyen → 01+02; Thi → 03+04; Vi → 05+06; Linh → integration + 07 + validation/report notes. Everyone reviews the whole set; `07` is shared (each member adds their ≥5 queries). The Phase 2 task split is to be agreed by the team when Phase 2 tasks start.

## 8. Audit policy

**Every meaningful AI-assisted repository change must create an audit Markdown file under `docs/audits/`**, using `docs/audits/AUDIT_TEMPLATE.md`, numbered with the next available number. Small manual typo-only edits do **not** need a separate audit unless they affect workflow, deliverables, SQL, or project instructions.

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

For generation/refinement/validation/test audits, also record **which Phase 1 or Phase 2 step or output** was evaluated.

## 9. Validation policy

- **Phase 1 final stage (outputs 01–07 exist):**
  - `bash scripts/check_required_files.sh --final G08`
  - `bash scripts/validate_sql.sh --final G08`
- **Phase 2 stage (as outputs 08–16 are created):** extend the scripts as needed to cover the Phase 2 deliverables. SQL deliverables (`10`, `12`, `13`, `14`, `16`) must be validated on a **SQL Server-compatible environment only** (local SQL Server, a SQL Server container, or Azure SQL) — never PostgreSQL, MySQL, or Supabase.
- Record the commands and their results in the audit. Phase 1 final-mode failures are no longer expected; if a Phase 2 task deliberately changes a Phase 1 output (e.g., the updated ERD in `09`), note the deviation and the regeneration plan in the audit.

## 10. Git and safety rules

- Do **not** run `git add`, `git commit`, or `git push` unless the user explicitly asks.
- Never commit API keys, tokens, `.env`, or local OpenCode state.
- Review diffs before committing.
- Keep `outputs/` limited to team-generated deliverables (Phase 1 01–07 and Phase 2 08–16) plus `.gitkeep`; no stray or intermediate files.

## 11. Future deployment policy

- Deployment, frontend, and backend may be **future** responsibilities, but **Phases 1 and 2 do not include them**.
- Do **not** generate frontend/backend/deployment code during Phases 1 and 2 unless the team explicitly requests it after the relevant requirements are clear.
- If such work starts later, it gets its own folders (`db/`, `backend/`, `frontend/`, `deploy/`) and is covered by the same audit policy (section 8).

## 12. Critical business rules (must be enforced/represented)

1. The same space cannot have two **approved** bookings with overlapping time periods.
2. A space that is **under maintenance, temporarily closed, or retired** cannot be booked.
3. Booking **approval/rejection** stores the deciding staff member, decision time, and decision note — and a **rejection reason** when the booking is rejected.
4. **Check-in** records the actual start time, who checked it in (checked-in-by), and the initial condition of the space.
5. **Check-out / completion** records the actual end time, the final condition of the space, and usage notes.
6. **Maintenance records** include the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note.
7. **Historical booking and maintenance records must be preserved** (so staff can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings).

**Phase 2 additions** (tags follow `req/business-requirement-P2.md`):

8. **[CONFIRMED]** **Maintenance impact levels:** maintenance records carry an `impact_level` — `OutOfService` blocks booking for any overlapping period (the Phase 1 rule, scoped to this level); `Advisory` does not block booking, but every active advisory on the space must be **acknowledged per booking** before the booking can be approved. A space may have several active maintenance records at different impact levels simultaneously.
9. **[CONFIRMED]** **Escalation/downgrade:** an impact level may change while the record is open; escalating to `OutOfService` must make every already-`Approved`/`CheckedIn` overlapping booking identifiable to staff (escalation lookup) — notifying requesters stays a manual staff action.
10. **[CONFIRMED]** **Concurrency invariant:** the same space may never have two `Approved`/`CheckedIn` bookings with overlapping time periods, regardless of path (instant or manual) and regardless of how many users/staff act simultaneously — enforced with SQL Server concurrency control (`SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK`, or `sp_getapplock`), not by a trigger alone.
11. **[EXTENSION]** **Reserved vs. actual time:** conflict checks use the reserved interval for `Approved`/`CheckedIn` bookings; early check-out (`Completed`) **immediately releases** the remaining reserved window — an early-checked-out user has no claim on it and must submit a new request.
12. **[EXTENSION]** **Asset-level tracking:** facilities are tracked as individual units with serial numbers (not quantity counts); a booking must be blocked when a facility marked **required** for that space has no available unit, even without a space-level out-of-service record.
13. **[CONFIRMED]** **Auto-approval:** selected space types may auto-approve eligible requests at submission time; the decision is stored in the same decision-record shape as a staff decision, distinguished by `decision_source` (`'System'` vs. `'Staff'`).
