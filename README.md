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

## 2. Big rule for the team

Please follow these. They keep our grade and our history safe.

- **OpenCode + DeepSeek (or whatever you like, not just only DeepSeek) is the primary workflow.** The 7 deliverables should be generated through OpenCode, not hand-written or pasted from somewhere else.
- **Do not silently edit outputs by hand.** If you change something, record what changed and why (an audit, or at least a clear commit message).
- **Every meaningful AI-assisted work session must create an audit file in `audits/`.** See section 9.
- Audits matter because the final report has to explain our **agent improvement process** — how we evaluated the agent at each step and how we improved it. The audits are the raw evidence for that.

## 3. Folder and file map

```text
.
├── .opencode/
│   ├── commands/
│   │   └── design-db.md                 # the /design-db command
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
├── AGENT.md                             # official CS486 manifest (group + model info)
├── AGENTS.md                            # OpenCode project rules (the agent reads this)
├── SKILL.md                             # official CS486 skill manifest
├── README.md                            # this guide
├── .gitignore
├── CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md  # detailed spec (source of truth for design)
├── CS486_Project.pdf                    # official assignment PDF
└── cs486-demo-share.zip                 # teacher's demo, reference only
```

Quick "what is this for" list:

| File / folder | What it's for |
|---|---|
| `AGENT.md` | Official CS486 manifest. Group number, members, and which LLM model we used. **You must fill the real values here before submission.** |
| `AGENTS.md` | The project rules OpenCode reads automatically: workflow order, output names, DBMS, design rules, critical business rules. |
| `SKILL.md` | Official CS486 skill manifest. A short list pointing to our pipeline skill. |
| `.opencode/commands/design-db.md` | Defines the `/design-db` command — the one command that runs the whole pipeline. |
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

The main command:

```text
/design-db req/business-requirement.md
```

(Open OpenCode in the repo root first — see section 8.)

## 5. What the 7 deliverables are

These go in `outputs/`. Replace `G<Group number>` with our real group number later (for example `G01`):

```text
01-business-req-analysis-G<Group number>.md
02-erd-design-G<Group number>.md
03-logical-design-G<Group number>.md
04-design-validation-G<Group number>.md
05-db-definition-G<Group number>.sql
06-sample-data-G<Group number>.sql
07-query-design-G<Group number>.sql
```

Important notes:

- **Do not generate these until the team is ready.** Right now `outputs/` should only contain `.gitkeep`.
- Use the **exact** filenames above. The group number replaces `G<Group number>` (e.g. `01-business-req-analysis-G01.md`).
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

Once the 7 outputs exist, validate them for our group (replace `G<NN>` with e.g. `G01`):

```bash
bash scripts/check_required_files.sh --final G<NN>
bash scripts/validate_sql.sh --final G<NN>
```

What to expect:

- These **pass only after all 7 outputs exist** and the SQL files have real content.
- **Before generation, final mode is *supposed* to fail** — the deliverables are intentionally missing during setup, so a FAIL there is normal, not a bug.
- `validate_sql.sh --final` checks that `05` has `CREATE TABLE` + key/constraint evidence, `06` has `INSERT` statements, and `07` has at least 5 queries.

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
6. **Run validation scripts** (`--setup` now, `--final G<NN>` after generation).
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
- `SKILL.md` (manifest)
- `.opencode/commands/design-db.md` (the command)
- `.opencode/skills/db-design-pipeline/SKILL.md` (the pipeline)

If yes, **improve the instruction/skill first**, then rerun or regenerate the affected file. *That* is the real agent improvement process.

Example:

- **Problem:** the query file has SQL but no business questions.
- **Fix:** strengthen Step 7 in the pipeline skill so every query must include the 4 parts.
- **Rerun:** regenerate `07-query-design-G<NN>.sql`.
- **Audit:** record the issue, the refinement, and the result.

(This exact pattern already happened during setup — see the audits — so it's a real, reportable example.)

## 11. Cost and safety notes

- **Don't use max reasoning for every small task.** Use medium/high for normal work; save max for hard reviews or tricky validation.
- **Never paste API keys** into files or audits. Keep secrets out of Git entirely.
- **Don't commit `.env` or local OpenCode state** (the `.gitignore` already covers these, but stay careful).
- **Review diffs before commit** — don't blind-commit agent output.
- **Don't let the agent invent the group number or student names.** Those stay as `GXX` placeholders until a human fills them in.
- Prefer regenerating **one file** over redoing everything — cheaper and easier to review.

## 12. Before submission checklist

- [ ] Fill the real **group number** and **member names** in `AGENT.md`.
- [ ] Confirm the **model/provider** we actually used is correct in `AGENT.md`.
- [ ] Run final validation:
      `bash scripts/check_required_files.sh --final G<NN>` and `bash scripts/validate_sql.sh --final G<NN>`.
- [ ] Make sure `outputs/` has **exactly the 7 required deliverables** (correct names, real content).
- [ ] Make sure the **report PDF** includes member info, the LLM model(s) used, and the agent improvement process.
- [ ] Make sure `audits/` has **enough history** to support the report's improvement section.
- [ ] Check `git status` is **clean** before final submission.

---

Happy designing. When in doubt: run through OpenCode, validate, and write an audit. 🚀
