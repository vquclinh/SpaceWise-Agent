# OpenCode Fix Audit: Clean OpenCode Setup Baseline

> Author: OpenCode (auxiliary setup reviewer/fixer). OpenCode + DeepSeek remains the primary project agent for deliverable generation. No deliverable was generated, and no Git/destructive command was run.
> Date: 2026-06-17

## 1. Executive Summary

**Verdict: PASS.**

All Major and Minor issues from `audits/01` and `audits/02` have been fixed. The repository is now clean, portable, and logically consistent: no hardcoded machine paths remain in authored files, the OpenCode pipeline skill enforces the official Query Design format (≥5 queries × {Business question, Target user(s), Why useful, SQL}) and the full Campus Space Management domain, the `/design-db` command now points at all three sources of truth, and the validation scripts have proper `--setup`/`--final` modes with stronger SQL checks. `outputs/` still contains only `.gitkeep` — no deliverables were generated. The repo is ready to commit.

## 2. Sources Read

- `CS486_Project.pdf` — full text (Phase-1 steps, Query Design 4-part format, §3 Required Documents). Confirmed deliverable names and query requirements.
- `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` — section map (§5 recommended entities, §7 business rules, §11 validation logic, §13 example queries) used to drive domain coverage in the skill.
- `cs486-demo-share.zip` — extracted and compared; treated as a reference pattern only.
- Previous audits: `audits/00-setup-project-audit.md`, `audits/01-review-opencode-setup-audit.md`, `audits/02-deep-review-opencode-setup-audit.md`.

## 3. Files Changed

| File | Change | Reason |
|---|---|---|
| `README.md` | Replaced 3 hardcoded `cd /mnt/vquclinh/...` lines with `cd <your-project-folder>`; added an "Agent roles" note (OpenCode+DeepSeek primary, OpenCode auxiliary); rewrote §7 to document `--setup`/`--final` script modes. | Portability for teammates; accurate agent roles; usable validation docs. |
| `AGENTS.md` | Replaced hardcoded root path with a relative description; added detail/official source pointers + English-only rule; added query-format and no-invention design rules; added an "Agent Tooling Note". | Portability; consistency with the skill; clarify primary vs. auxiliary agent. |
| `AGENT.md` | Added a note to update group/members/model before submission; added an "Auxiliary Tooling" section. | Keep the official manifest accurate; preserve evidence that OpenCode+DeepSeek is primary and OpenCode is auxiliary. |
| `SKILL.md` (root) | Step 7 line now states the ≥5 + 4-part query requirement. | Keep the official manifest consistent with the executable skill. |
| `.opencode/commands/design-db.md` | Rewrote to read the requirement arg + spec + PDF (with conflict precedence), follow the 7-step pipeline, list the exact 7 outputs, forbid inventing group/names, require an audit after runs, English-only. | Make the command a complete, reusable workflow entry point. |
| `.opencode/skills/db-design-pipeline/SKILL.md` | Added Sources-of-Truth + Domain-Coverage sections; strengthened Step 5 (approval/usage/maintenance metadata columns) and Step 4 (ERD↔schema mapping); rewrote Step 7 to require ≥5 queries each with Business question / Target user(s) / Why useful / SQL; added candidate keys and participation constraints to Steps 2–3. | Make the skill strict enough that future generation is CS486-compliant. |
| `scripts/check_required_files.sh` | Added `--setup` (scaffold present + no deliverables, exit 0) and `--final <GROUP>` (7 deliverables) modes; kept bare-group backward compatibility. | Remove the misleading setup-stage FAIL; support real final validation. |
| `scripts/validate_sql.sh` | Added `--setup`/`--final` modes; final mode checks 05 for `CREATE TABLE` + key/constraint evidence, 06 for `INSERT`, 07 for ≥5 `SELECT` and the Business-question annotation count. | Stronger, mode-aware validation that still needs no DB. |
| `.opencode/skills/db-design-pipeline/templates/.gitkeep` | Created. | Track the previously-empty `templates/` folder so README/audit references resolve in a clone. |
| `audits/00-setup-project-audit.md` | Set `Date` from `YYYY-MM-DD` to `2026-06-17`. | Remove the placeholder. |
| `audits/03-fix-clean-setup-audit.md` | Created. | This audit (required evidence for the fix session). |

## 4. Files Intentionally Not Changed

- **The 7 `outputs/` deliverables were NOT generated.** `outputs/` still contains only `.gitkeep`.
- Group number (`GXX`) and student names left as placeholders by design — not invented.
- `req/business-requirement.md`, the spec, the PDF, and the demo zip were left in place (moving sources was judged riskier than the small root-tidiness gain; provenance is useful for the report).
- `.gitignore` left as-is (already good).

## 5. Repository Structure After Fix

```text
spacewise-agent/
├── .opencode/
│   ├── commands/design-db.md
│   └── skills/db-design-pipeline/
│       ├── SKILL.md
│       └── templates/.gitkeep          # now tracked
├── req/business-requirement.md
├── outputs/.gitkeep                     # no deliverables (correct)
├── audits/
│   ├── .gitkeep
│   ├── 00-setup-project-audit.md
│   ├── 01-review-opencode-setup-audit.md
│   ├── 02-deep-review-opencode-setup-audit.md
│   └── 03-fix-clean-setup-audit.md   # this audit
├── scripts/{check_required_files.sh, validate_sql.sh}
├── AGENT.md
├── AGENTS.md
├── SKILL.md
├── README.md
├── .gitignore
├── CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md
├── CS486_Project.pdf
└── cs486-demo-share.zip
```

## 6. Official CS486 Compliance After Fix

| Item | Status | Note |
|---|---|---|
| `AGENT.md` | ✅ | Manifest; model/group fields flagged to update before submission. |
| `SKILL.md` | ✅ | Manifest; Step 7 query rule now stated. |
| `outputs/` | ✅ | Only `.gitkeep`; no premature deliverables. |
| 7 deliverable filename patterns | ✅ Exact | Match `CS486_Project.pdf` §3.2 verbatim; enforced in command + skill + scripts. |
| Query Design format (≥5, 4-part) | ✅ | Enforced in the skill and checked by `validate_sql.sh --final`. |
| No premature generation | ✅ | Confirmed via `find outputs`. |

## 7. OpenCode Workflow After Fix

- **`AGENT.md`** — official course-facing manifest: group info, primary LLM config (OpenCode + DeepSeek), auxiliary-tooling note, pointers to `AGENTS.md`/`SKILL.md`.
- **`AGENTS.md`** — OpenCode project rules: portable context, 7-step order, required outputs, DBMS, design rules (incl. no-invention + query format), and the two critical booking rules.
- **`.opencode/commands/design-db.md`** — the reusable entry point: reads requirement arg + spec + PDF, runs the 7-step pipeline, names the exact outputs, and requires a post-run audit.
- **`.opencode/skills/db-design-pipeline/SKILL.md`** — the executable pipeline: sources of truth, domain coverage, and strict per-step requirements (ERD → logical → validation → DDL → sample data → ≥5 documented queries).
- **`SKILL.md` (root)** — thin official manifest pointing to the pipeline skill and `/design-db`.

Together: `/design-db req/business-requirement.md` is the single primary workflow; the skill enforces compliance; `audits/` + the scripts provide repeatable evaluation evidence for the improvement report.

## 8. Validation Scripts After Fix

Both scripts default to `--setup` and accept `--final <GROUP>`; both are read-only bash and need no DB/Docker/network.

- `check_required_files.sh --setup` → verifies scaffold files exist and `outputs/` has no deliverables; exit 0.
- `check_required_files.sh --final G01` → verifies the 7 deliverables; exit 1 if any missing.
- `validate_sql.sh --setup` → confirms no SQL deliverables yet; exit 0.
- `validate_sql.sh --final G01` → 05 must have `CREATE TABLE` + key/constraint evidence; 06 must have `INSERT`; 07 must have ≥5 `SELECT` (and warns if fewer than 5 "Business question" annotations).

## 9. Validation Commands Run

| Command | Result |
|---|---|
| `git status --short` | Only `README.md` modified + untracked setup folders/files; no deliverables. |
| `find outputs -maxdepth 2 -type f` | `outputs/.gitkeep` only. |
| `grep -rn "/mnt/vquclinh" --include=*.md --include=*.sh .` (excl. audits) | `(none)` — no hardcoded paths remain in authored files. |
| `bash scripts/check_required_files.sh --setup` | `SETUP PASS` — exit 0. |
| `bash scripts/check_required_files.sh --final G01` | `FAIL: 7 file(s) missing` — exit 1 (expected at setup). |
| `bash scripts/validate_sql.sh --setup` | `SETUP PASS` — exit 0. |
| `bash scripts/validate_sql.sh --final G01` | `FAIL: 3 SQL check(s) failed` (all missing) — exit 1 (expected at setup). |
| `bash -n` on both scripts | `syntax OK`. |
| CJK scan (`grep -P` ranges) over `*.md`/`*.sh` | No matches — repo authored files are English-only. |

(Earlier `audits/01`/`02` recorded the original behavior; the prior audits' pre-fix exit codes are superseded by the mode-aware behavior above. The Vietnamese staff names remain only inside the binary `CS486_Project.pdf`, an official source document, not an authored repo file.)

## 10. Remaining Risks or Caveats

- **Placeholders by design:** `GXX` and `STUDENT_NAME_*` remain in `AGENT.md`/`AGENTS.md`/command/skill. These are intentional templates; the group must set the real group number and names before submission. The skill/command explicitly forbid the agent from inventing them.
- **Script heuristics:** `validate_sql.sh --final` uses keyword/count heuristics (e.g. counts `SELECT`, looks for `CREATE TABLE`). It is a sanity gate, not a SQL parser or a live-DB execution; it cannot guarantee the SQL runs on MS SQL Server.
- **PDF readability at generation time:** the command asks the agent to read `CS486_Project.pdf` "if readable" — in some headless environments PDF text extraction may be unavailable, in which case the spec markdown is the fallback source of truth (already wired in).
- **Root still holds source files:** the demo zip and PDF remain at the repo root by deliberate choice; if the group prefers a tidier root they can relocate them into a `reference/` folder later (documented as optional).

## 11. Recommended Next Steps

The repository **is ready to commit** as a clean setup baseline.

1. (Optional) Set the real group number and member names in `AGENT.md`, and confirm the `Model` matches the provider connected via `/connect` + `/models`.
2. Commit on a branch and push per the group's process — **the user should run these; this reviewer does not commit.** Do not commit API keys/tokens (already gitignored).
3. Later, generate the deliverables with OpenCode + DeepSeek:
   ```text
   /design-db req/business-requirement.md
   ```
   Prefer single-file regeneration prompts for fixes, and record each evaluation/refinement in a new `audits/NN-...md` to feed the required group report.
4. Validate the results:
   ```bash
   bash scripts/check_required_files.sh --final G<NN>
   bash scripts/validate_sql.sh --final G<NN>
   ```

## Final note

Verdict: **PASS** — ready to commit now; no further OpenCode fix pass is required before generation.
