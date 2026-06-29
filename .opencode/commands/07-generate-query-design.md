---
description: Step 7 (Query Design) — generate/update one member's query section, or review the whole file. One member section per run; Student ID is the section key.
---

# /07-generate-query-design

Team base command for `outputs/07-query-design-G08.sql`. Two modes; derive queries from the live schema/data (never a fixed answer); no fixed member→role/category assignments.

**Roles:** this command owns the **workflow, arguments, and output format/requirements**; the task skill (`.opencode/skills/db-design-pipeline/07-query-design/SKILL.md`) owns the **query-quality rubric and query-pattern notes**. They do not repeat each other.

## Usage

```text
# Mode A — generate/update one member's section (target users derived from query types)
/07-generate-query-design Member: Vo Quoc Linh (24125065); Query types: space availability, booking lifecycle, maintenance monitoring, utilization summary, facility-based search

# Mode A — optional: constrain to specific target users
/07-generate-query-design Member: Vo Quoc Linh (24125065); Target users: Facility Staff, Facility Manager; Query types: space availability, booking lifecycle, maintenance monitoring, utilization summary, facility-based search

# Mode B — review the whole file
/07-generate-query-design Mode: review-all
```

## Arguments & interaction

**Arguments:**
- **Required (Mode A):** `Member: <Full Name> (<Student ID>)` · `Query types: <≥5 distinct>`
- **Optional:** `Target users: <canonical roles>` (a constraint/override — see §Query type to target-user resolution) · `Mode: review-all`
- Canonical roles: Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager. Members need **not** tag each query type with a role — the command resolves type → target user(s).

**Interaction (never silently invent):**
- Missing `Member` or `Student ID` → stop and ask.
- `Query types` missing, fewer than 5, or duplicated → stop and ask.
- `Target users` is **optional**: if omitted, derive the section's target user perspective from the resolved target users of the query types; if provided, treat it as a **constraint** — every resolved query target user must be a subset of the declared target users.
- A query type that can't be confidently mapped (from §Role-based query type mapping or Outputs 01–06) → **stop and ask**. Never invent a target user when ambiguous.
- `Mode: review-all` takes no member args and generates nothing.
- A section with the same **Student ID** → replace that section only; **preserve all other members' sections** (no renumber/reorder/delete).

## Inputs

- `outputs/05-db-definition-G08.sql` — **schema authority** (use only its tables/columns; exact enum spellings).
- `outputs/06-sample-data-G08.sql` — sample-data reference (queries should return meaningful rows).
- `outputs/01`–`04` — business context only · `AGENTS.md` + the task skill — repo rules, audit policy, query-pattern notes.

## Output format

Deliverable: **only** `outputs/07-query-design-G08.sql` (never modify Outputs 01–06). Audit: `docs/audits/<next-number>-...md`. **Student ID is the section key** — create/replace only that member's `BEGIN/END` block; never overwrite the whole file. The file-level header is written only when the file is new.

```sql
-- =====================================================================
-- Task 07 Query Design — Group G08
-- =====================================================================

-- =====================================================================
-- BEGIN MEMBER SECTION: <Student ID>
-- Member: <Full Name> (<Student ID>)
-- Target user perspective: <resolved role list>
-- Query type plan (resolved target user(s) per type):
--   1. [Facility Staff, Facility Manager] space availability
--   2. [Facility Staff] booking lifecycle
--   3. [Facility Staff] maintenance monitoring
--   4. [Facility Manager] utilization summary
--   5. [Facility Staff, Facility Manager] facility-based search
-- =====================================================================

-- Query N: <short title>
-- Query type: <one of this member's declared types>
-- Business question: <the real question it answers>
-- Target user(s): <must match the resolved mapping for this query type>
-- Why this query is useful: <one-line value>
DECLARE ... ;   -- only where useful
SELECT ... ;
GO

-- =====================================================================
-- END MEMBER SECTION: <Student ID>
-- =====================================================================
```

## Role-based query type mapping

Default mapping used to resolve **query type → target user(s)**. These are **not** fixed member assignments and **not** final SQL answers. Members may supply query types outside this list; the command then infers from Outputs 01–06 and asks if ambiguous.

- **Student:** personal booking history · available space search · booking status tracking · cancelled/no-show bookings · suitable space by capacity/facility
- **Lecturer:** teaching/seminar room availability · upcoming approved bookings · past completed bookings · required facility matching · schedule by date range
- **Teaching Assistant:** tutorial/lab space availability · assisted session schedule · check-in support list · facility readiness · booking follow-up
- **Facility Staff:** pending approvals · check-in candidates · active usage sessions · session completion reports · maintenance monitoring · no-show candidates · booking lifecycle · space availability · facility-based search
- **Department Administrator:** department booking summary · department user activity · upcoming department events · approval/rejection audit trail · facility demand by department · department utilization comparison
- **Facility Manager:** utilization summary · no-show analysis · maintenance backlog · unavailable spaces report · booking status distribution · space usage ranking · space availability · facility-based search

## Query type to target-user resolution

Members supply query types; the command resolves the target user(s) for each. `Target users` is optional and acts only as a constraint. Resolve each query type in this order:

1. Match the query type against the **Role-based query type mapping** above.
2. If it appears under exactly one role → map it to that role.
3. If it appears under multiple roles **and `Target users` was provided** → keep only the matching declared roles where reasonable.
4. If it appears under multiple roles **and `Target users` was omitted** → map it to all reasonable matching roles.
5. If it is custom / not listed → infer the most suitable target user(s) from Outputs 01–06.
6. If still ambiguous → **stop and ask** before generating.

The section-level **`Target user perspective`** is the **union** of all resolved query target users — unless `Target users` was provided, which constrains it (every resolved user must be a subset of the declared users). Record the resolved mapping in the section header's Query type plan, and make each query's `-- Target user(s):` line match the resolved user(s) for its query type:

```sql
-- Query type plan:
--   1. [<resolved target user(s)>] <query type 1>
--   ... (one line per query type)
```

## Requirements

- **≥5** meaningful **SQL Server** queries per member; the full file needs all four members (**≥20 total**).
- Each query has Query type (maps to one declared, **distinct** type) + Business question + Target user(s) (fits the perspective) + Why useful + SQL, and **ends with `GO`**.
- **Read-only w.r.t. the database:** `SELECT` / CTE (`WITH`) / `DECLARE` — including a local `DECLARE @t TABLE` populated via `INSERT INTO @t` (or a `VALUES`/CTE list) to parameterize a multi-value filter. **No** statements that change persistent data or schema (no INSERT/UPDATE/DELETE/MERGE into base tables, no DROP/ALTER/CREATE/TRUNCATE).
- **No `SELECT *`** (meaningful columns + aliases); use Output 05 identifiers + enum spellings; `DECLARE` reusable filters/dates/statuses/thresholds where useful.
- **Variety** across the 5: ≥1 JOIN, ≥1 aggregation (`GROUP BY`/`COUNT`/`SUM`), ≥1 status/lifecycle, ≥1 date/time or ordering.
- A query that intentionally checks absence/violations and may return zero rows must say so in a comment. English only; group `G08`.

## Modes

**Mode A — per-member generation (default):**
1. Validate arguments per §Arguments & interaction.
2. Read §Inputs and apply the skill's relevant **Query category notes** (don't copy them as final SQL).
3. Write the member's section per §Output format and §Requirements — keyed by Student ID, preserving all other sections.
4. **Self-review** against §Output format, §Requirements, and the skill's notes.

**Mode B — `Mode: review-all` (review only, generate nothing):** if the file is missing, report that member sections must be generated first. Otherwise verify: matching `BEGIN/END MEMBER SECTION: <Student ID>` markers; no duplicate Student IDs; each section has name/ID/perspective + ≥5 distinct types + ≥5 queries (**≥20 total** once all four present); every query has the four fields + SQL + `GO`; no `SELECT *`; read-only; identifiers exist in Output 05; consistent with the skill's notes. Also check the **query type → target-user mapping**: the section has a resolved `Target user perspective`; the Query type plan records resolved target user(s); every query's `Target user(s)` matches the resolved mapping for its `Query type`; any custom query type's mapping is explainable from Outputs 01–06. If `Target users` was omitted at generation time, that is acceptable as long as the section records the resolved target users. Report **reusable** issues as a proposed new skill note, **one-off** issues as output-only fixes.

## After generation & audit

- The whole file must run after `05` then `06` on the **same** SQL Server database. Generic check only (no hard-coded names, no log files):
  ```text
  sqlcmd -S <server> -d <database> -i outputs/07-query-design-G08.sql
  ```
  Record verification results in the audit; if SQL Server is unavailable, note the review was **static only**.
- Follow the repository audit policy (`AGENTS.md` §7): create `docs/audits/<next-number>-...md` recording the provider/model/variant used and —
  **Mode A:** member, Student ID, target user perspective, query-type plan, section created or updated, other sections preserved.
  **Mode B:** sections found, total query count, missing/duplicate sections, whether the file is runnable as a whole, checks run.
