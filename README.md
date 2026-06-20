# SpaceWise Agent — CS486 Campus Space Management System

Bonjour ^^! this is our group repo for the CS486 database project. This README is the practical guide for how we work here. Read sections 2 and 9 at minimum before you touch anything.

- This is our **group agent repository** for CS486 (Introduction to Database System).
- The project is the **Campus Space Management System**: a database to manage booking, approval, usage, and maintenance of shared campus spaces.
- This repo is **not just the final answers.** It holds the whole working setup:
  - the OpenCode agent rules, commands, and skill (the "brain" that designs the database),
  - the requirement and spec inputs,
  - validation scripts,
  - audit history (our memory of what we did and why),
  - and `outputs/`, where the 7 final deliverables will go later.

So think of it as "the agent + its workflow + its paper trail," not just a folder of homework files.

> **Current setup scope (read this):** Right now the repo is only being **set up** — preparing the OpenCode workflow and team scaffold. Vo Quoc Linh's current task is **setup only**, not generating deliverables. The 7 Phase 1 files in `outputs/` will be **generated and refined later by the group**. No frontend, backend, or deployment is part of this setup. The detailed OpenCode skill lives at `.opencode/skills/db-design-pipeline/SKILL.md`.
> 
> The `outputs/` directory **must remain empty except `outputs/.gitkeep`** until the team explicitly begins Phase 1 deliverable generation.

## Group (G08)

| Member | Student ID |
|---|---|
| Truong Thi My Duyen | 24125028 |
| Huynh Le Bao Thi | 24125080 |
| Le Quoc Vi | 24125085 |
| Vo Quoc Linh | 24125065 |

- **Group number:** `G08` — used in every deliverable filename (e.g. `01-business-req-analysis-G08.md`).
- **Primary tool:** OpenCode (fixed).
- **Model/provider:** not fixed — each member may use a different one per OpenCode session. **Record the exact model/provider in every audit**, so the report can list all models we actually used.
- **DBMS:** Microsoft SQL Server.

## 2. Big rule for the team

Please follow these. They keep our grade and our history safe.

- **OpenCode + DeepSeek (or whatever you like, not just only DeepSeek) is the primary workflow.** The 7 deliverables should be generated through OpenCode, not hand-written or pasted from somewhere else.
- **Do not silently edit outputs by hand.** If you change something, record what changed and why (an audit, or at least a clear commit message).
- **Every meaningful AI-assisted work session must create an audit file in `audits/`.** See section 9.
- **The model is not fixed.** Each member may pick whatever provider/model works for them in OpenCode — but you **must record the exact provider/model in that session's audit**. The report lists every model the group actually used.
- Audits matter because the final report has to explain our **agent improvement process** — how we evaluated the agent at each step and how we improved it. The audits are the raw evidence for that.

## 3. Folder and file map

```text
.
├── .opencode/
│   ├── commands/
│   │   ├── audit-smoke-test.md          # /audit-smoke-test — the only setup-safe command
│   │   └── design-db.md                 # /design-db — generic example placeholder (adapt later)
│   └── skills/
│       └── db-design-pipeline/
│           ├── SKILL.md                 # the 7-step DB design pipeline (the real logic)
│           └── templates/               # optional output templates (.gitkeep keeps it tracked)
├── req/
│   └── business-requirement.md          # short business requirement (main input)
├── outputs/                             # the 7 deliverables go here LATER (now: just .gitkeep)
├── audits/                              # our memory: review + improvement records
├── scripts/
│   ├── check_required_files.sh          # checks scaffold / deliverables exist
│   └── validate_sql.sh                  # checks the SQL deliverables look valid
├── AGENT.md                             # course-facing manifest (group + model info)
├── AGENTS.md                            # OpenCode project rules (the agent reads this)
├── README.md                            # this guide
├── .gitignore
├── CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md  # detailed spec (source of truth for design)
├── CS486_Project.pdf                    # official assignment PDF
└── cs486-demo-share.zip                 # teacher's demo, reference only
```

Quick "what is this for" list:

| File / folder | What it's for |
|---|---|
| `AGENT.md` | Official CS486 **course-facing** manifest: project, group `G08`, members/IDs, tool/model policy, DBMS, Phase 1 workflow summary, output/audit locations. |
| `AGENTS.md` | The **agent-facing rulebook** OpenCode reads automatically: scope, source-of-truth order, editing/SQL/output rules, team workflow, **audit policy**, validation policy, git/safety, future deployment policy. |
| `.opencode/commands/` | Setup-stage OpenCode commands: `/audit-smoke-test` (the only setup-safe command) and `/design-db` (a generic example placeholder to adapt later). Phase 1 production commands will be added by the group when they start Phase 1. |
| `.opencode/skills/db-design-pipeline/SKILL.md` | The actual brain: the detailed 7-step pipeline and what each output must contain. |
| `.opencode/skills/db-design-pipeline/templates/` | Optional place for output templates so files look consistent. Empty for now, but tracked. |
| `req/business-requirement.md` | The condensed business requirement. Usual input to `/design-db`. |
| `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` | The detailed spec (entities, rules, example queries). The agent uses this as the detailed source of truth. |
| `CS486_Project.pdf` | The official assignment. Final word if anything conflicts. |
| `outputs/` | Where the 7 deliverables live later. Right now it must stay empty except `.gitkeep`. |
| `audits/` | Our improvement/evaluation history. One audit per meaningful session. |
| `scripts/check_required_files.sh` | Confirms the scaffold (setup) or all 7 deliverables (final) exist. |
| `scripts/validate_sql.sh` | Confirms the SQL files have real content (CREATE TABLE / INSERT / ≥5 queries). |
| `cs486-demo-share.zip` | The teacher's example layout. Reference only — we don't copy it blindly. |
| `README.md` | This file. |

## 4. How the OpenCode workflow works

Here's the chain, start to finish:

1. **OpenCode reads `AGENTS.md`** on its own — that's the project-level rule book (workflow order, output names, business rules).
2. **You run `/design-db`**, which is defined in `.opencode/commands/design-db.md`.
3. **That command loads the skill** at `.opencode/skills/db-design-pipeline/SKILL.md`.
4. **The skill defines the 7-step database design pipeline** and exactly what each output file must contain.
5. The command tells the agent to **read `req/business-requirement.md` plus the spec and the PDF** as sources of truth.
6. The agent then **generates the 7 files in `outputs/`** — but **later, when the team is ready**, not during setup.
7. After it generates or fixes anything, the agent should **create an audit** in `audits/`.

### The commands (setup stage)

The repo is in **setup-only** mode, so there are just two commands right now:

```text
/audit-smoke-test                      # safe rehearsal: checks the audit policy, no outputs touched
/design-db req/business-requirement.md # generic example placeholder — for the team to adapt later
```

- **`/audit-smoke-test`** — the only **setup-safe** command. A read-only rehearsal of the audit habit; it does not touch `outputs/`. Use it to confirm audit creation works.
- **`/design-db`** — a generic example placeholder entry point. It does **not** generate the 7 outputs now; it points to the detailed skill so the team can adapt it later.

**Phase 1 production commands** (to generate / refine / validate / SQL-test the deliverables) are intentionally **not** in the repo yet. The group will create or adapt them when they actually start Phase 1 work — that is not part of the current setup task.

### Which file is which

- **`AGENT.md` vs `AGENTS.md`** — `AGENT.md` is the short **course-facing** manifest (who we are, tool/model policy, workflow summary). `AGENTS.md` is the **agent-facing rulebook** OpenCode actually follows (detailed rules + audit/validation/deployment policy).
- **The detailed OpenCode skill** is `.opencode/skills/db-design-pipeline/SKILL.md` — the **detailed, executable** 7-step pipeline with per-step quality checklists. (We follow the teacher demo layout, which keeps the skill here and does not use a root `SKILL.md`.)

### Audit policy (short version)

Every meaningful AI-assisted change writes an audit in `audits/` using `audits/AUDIT_TEMPLATE.md`. You don't have to retype the format — a prompt can simply say **"Follow the repository audit policy."** (full policy in `AGENTS.md` section 7). Small typo-only edits don't need an audit unless they affect workflow, deliverables, SQL, or project instructions. **These audits are the evidence source for the final report's agent improvement process.**

### Phase 1 scope

Phase 1 is database design + validation only. **Do not implement frontend, backend, or deployment in Phase 1** unless future requirements explicitly ask for it (see `AGENTS.md` section 10).

(Open OpenCode in the repo root first — see section 8.)

## 5. What the 7 deliverables are

These go in `outputs/`. Our group number is `G08`, so the files are:

```text
01-business-req-analysis-G08.md
02-erd-design-G08.md
03-logical-design-G08.md
04-design-validation-G08.md
05-db-definition-G08.sql
06-sample-data-G08.sql
07-query-design-G08.sql
```

Important notes:

- **Do not generate these until the team is ready.** Right now `outputs/` should only contain `.gitkeep`.
- Use the **exact** filenames above with our group number `G08`.
- The query design file (`07-...`) must contain **at least 5 meaningful SQL queries**.
- **Each query must include all four parts:**
  - **Business question** — what real question it answers.
  - **Target user(s)** — who would use it (e.g. facility staff, manager).
  - **Why this query is useful** — a short reason.
  - **SQL statement** — the actual SQL.

## 6. How to run setup validation now

At this stage, just confirm the scaffold is correct and no deliverables exist yet:

```bash
bash scripts/check_required_files.sh --setup
bash scripts/validate_sql.sh --setup
```

Expected result right now:

- Both should **PASS**.
- `outputs/` should contain **only `.gitkeep`** (no deliverable files yet).

If setup mode fails, something in the scaffold is missing or a deliverable was created too early — check the script output.

## 7. How to validate final deliverables later

Once the 7 outputs exist, validate them for our group (`G08`):

```bash
bash scripts/check_required_files.sh --final G08
bash scripts/validate_sql.sh --final G08
```

What to expect:

- These **pass only after all 7 outputs exist** and the SQL files have real content.
- **Before generation, final mode is *supposed* to fail** — the deliverables are intentionally missing during setup, so a FAIL there is normal, not a bug.
- `validate_sql.sh --final` checks that `05` has `CREATE TABLE` + key/constraint evidence, `06` has `INSERT` statements, and `07` has at least 5 queries.

### Database environment note (SQL Server)

Our DBMS is **Microsoft SQL Server**. The DDL (`05`), sample data (`06`), and queries (`07`) use SQL Server syntax (e.g. `IDENTITY`, `DATETIME2`, `GETDATE()`, `TOP`).

> ⚠️ **Supabase is PostgreSQL-based.** Do **not** use Supabase (or any plain PostgreSQL/MySQL) as the final environment to validate our SQL — syntax and types differ and our scripts may silently behave differently. If you want to actually run the SQL, use a SQL Server-compatible environment, for example:
> - a local SQL Server instance, or
> - a SQL Server container (e.g. the official `mcr.microsoft.com/mssql/server` Docker image), or
> - a cloud SQL Server service such as **Azure SQL Database**.
>
> Postgres tools are fine for casual experimenting, but the deliverables must target SQL Server.

## 8. How the team should work from now on

A simple loop for any work session:

1. **Pull latest:** `git pull`
2. **Check status/branch:** `git status --short` (know what's changed and where you are).
3. **Open OpenCode in the repo root:**
   ```bash
   cd <your-project-folder>
   opencode
   ```
4. **Do the work** with `/design-db` or a targeted prompt (e.g. "regenerate only `outputs/03-...`").
5. **Ask the agent to create an audit** for the change (see section 9).
6. **Run validation scripts** (`--setup` now, `--final G08` after generation).
7. **Review the diff** before committing — actually read what changed.
8. **Commit with a clear message.**
9. **Push.**

Example commit messages:

```text
setup: improve OpenCode workflow docs
agent: refine db design pipeline rules
outputs: generate initial CS486 deliverables
validation: fix SQL sample data issues
audit: record generation review
```

## 9. Audit rule — very important

**`audits/` is our memory. Do not skip it.**

After *every* OpenCode / Claude / ChatGPT-assisted change, create an audit file in `audits/` (next number in sequence, e.g. `audits/05-...md`).

The audit should clearly say:

- **What task** was done.
- **Which tool/model** was used (e.g. OpenCode + DeepSeek, or Claude for review).
- **What files changed.**
- **What validation** was run (and the result).
- **What issues** were found.
- **What got improved.**
- **What is still risky** or unfinished.
- **Next steps.**
- A short **git status summary**.

Why we care: these audits become the raw material for the report's **"agent improvement process"** section. If we skip them, we'll have nothing concrete to write about how we evaluated and improved the agent.

Reusable snippet — paste this into OpenCode/Claude at the end of a task:

```text
After completing the task, create an audit Markdown file in audits/.
The audit must summarize: task goal, tool/model used, files changed, validation run,
issues found, improvements made, risks/caveats, git status, and recommended next steps.
Do not generate unrelated files.
```

## 10. How to improve the agent/skill later

When an output is bad, **don't just hand-patch the final file.** That hides the real problem and we learn nothing for the report.

Instead, first ask: *was this caused by weak rules somewhere?*

- `AGENTS.md` (project rules)
- `.opencode/commands/design-db.md` (the command)
- `.opencode/skills/db-design-pipeline/SKILL.md` (the pipeline)

If yes, **improve the instruction/skill first**, then rerun or regenerate the affected file. *That* is the real agent improvement process.

Example:

- **Problem:** the query file has SQL but no business questions.
- **Fix:** strengthen Step 7 in the pipeline skill so every query must include the 4 parts.
- **Rerun:** regenerate `07-query-design-G08.sql`.
- **Audit:** record the issue, the refinement, and the result.

(This exact pattern already happened during setup — see the audits — so it's a real, reportable example.)

## 11. Cost and safety notes

- **Don't use max reasoning for every small task.** Use medium/high for normal work; save max for hard reviews or tricky validation.
- **Never paste API keys** into files or audits. Keep secrets out of Git entirely.
- **Don't commit `.env` or local OpenCode state** (the `.gitignore` already covers these, but stay careful).
- **Review diffs before commit** — don't blind-commit agent output.
- **Don't let the agent invent student names.** The group number is fixed (`G08`); names are already set in `AGENT.md` — don't let the agent make up new ones.
- Prefer regenerating **one file** over redoing everything — cheaper and easier to review.

## 12. Before submission checklist

- [x] **Group number** (`G08`) and **member names/IDs** filled in `AGENT.md`.
- [ ] Confirm the **model(s)/provider(s)** actually used are listed (gathered from the audits) for the report.
- [ ] Run final validation:
      `bash scripts/check_required_files.sh --final G08` and `bash scripts/validate_sql.sh --final G08`.
- [ ] Make sure `outputs/` has **exactly the 7 required deliverables** (correct `G08` names, real content).
- [ ] Make sure the **report PDF** includes member info, **all** LLM model(s) used, and the agent improvement process.
- [ ] Make sure `audits/` has **enough history** to support the report's improvement section.
- [ ] Check `git status` is **clean** before final submission.

---

Happy designing. When in doubt: run through OpenCode, validate, and write an audit. 🚀
