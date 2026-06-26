# OpenCode + DeepSeek Deep Review Audit: OpenCode + DeepSeek Project Setup

> Reviewer: OpenCode + Deepseek (review-only role). No project setup files were modified, created, moved, or deleted. The only file produced is this audit. No deliverables were generated and no Git operations were run.
> Review date: 2026-06-17
> This is a second, deeper pass that builds on `audits/01-review-opencode-setup-audit.md` and adds substantive findings (query-format enforcement, spec wiring, evaluation support) that the first pass did not raise.

## 1. Executive Summary

**Verdict: PASS WITH FIXES.**

Structurally the repository is clean, compliant, and well-organized: the three official artifacts (`AGENT.md`, `SKILL.md`, `outputs/`) exist, the seven deliverable filenames match `CS486_Project.pdf` **exactly**, no deliverables have been generated prematurely, and there is no Chinese/CJK or unintended non-English content in any authored repo file. It would "barely pass" as-is.

But by the stricter bar requested — clean, logical, maintainable, professional — there are **real substantive gaps that should be fixed before generating deliverables**, not just cosmetic ones:

1. **The pipeline skill does not enforce the official Query Design format.** The PDF requires *at least 5* queries, each with **Business question / Target user(s) / Short explanation / SQL statement**. Step 7 of the skill lists query *topics* only — it never states the 4-part structure or the minimum count. The generated `07-query-design` deliverable is therefore likely to be non-compliant. *(Major — this is the most important finding and is new in this pass.)*
2. **Neither the skill nor the `/design-db` command points to `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md`** — the richest requirement source (recommended entities, business rules, validation logic, 12 example queries). Only `AGENTS.md` references it, so a literal `/design-db req/business-requirement.md` run may design from the condensed requirement and miss the detail. *(Major.)*
3. **Hardcoded absolute machine paths** in `README.md` (×3) and `AGENTS.md` (×1) break portability for teammates. *(Major for a shared repo; carried over from audit 01, still open.)*
4. Weak validation scripts, empty untracked `templates/`, no evaluation/iteration scaffold to support the required "agent improvement process" report. *(Minor / Nice-to-have.)*

The repo is **not quite ready to commit** — it needs one more OpenCode fix pass (see §13–14) before generation.

## 2. Sources Reviewed

- **Official PDF:** `CS486_Project.pdf` — extracted full text via `pdftotext` (business requirement, Phase-1 steps, Query Design format, §3 Required Documents).
- **Official spec:** `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` — section map (14 sections incl. §5 recommended entities, §7 business rules, §11 validation logic, §13 example SQL queries).
- **Teacher demo:** `cs486-demo-share.zip` — extracted to `/tmp` and compared (`README.md`, `AGENTS.md`, `req/`, `.opencode/commands/design-db.md`, `.opencode/skills/db-design-pipeline/SKILL.md`).
- **Repo files:** `README.md`, `AGENT.md`, `AGENTS.md`, `SKILL.md`, `req/business-requirement.md`, `outputs/`, `.opencode/commands/design-db.md`, `.opencode/skills/db-design-pipeline/SKILL.md`, `scripts/*.sh`, `.gitignore`.
- **Prior audit:** `audits/00-setup-project-audit.md` (OpenCode's setup record) and `audits/01-review-opencode-setup-audit.md` (first review pass).

## 3. Current Repository Tree

```text
spacewise-agent/
├── .opencode/
│   ├── commands/design-db.md
│   └── skills/db-design-pipeline/
│       ├── SKILL.md
│       └── templates/                 # empty, untracked (no .gitkeep)
├── req/business-requirement.md
├── outputs/.gitkeep                    # no deliverables (correct)
├── audits/
│   ├── .gitkeep
│   ├── 00-setup-project-audit.md
│   ├── 01-review-opencode-setup-audit.md
│   └── 02-deep-review-opencode-setup-audit.md   # this review
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

## 4. Official CS486 Compliance

| Requirement | Status | Notes |
|---|---|---|
| `AGENT.md` | ✅ | Group + LLM-config manifest. |
| `SKILL.md` | ✅ | Top-level skill manifest. |
| `outputs/` | ✅ | Only `.gitkeep`; no premature deliverables. |
| 7 deliverable filename patterns | ✅ Exact | Verbatim match to PDF §3.2. |
| No premature deliverable generation | ✅ | `find outputs` → `.gitkeep` only. |
| Report: LLM model(s) used | ⚠️ Partial | `AGENT.md` records "DeepSeek V4 Pro" — good. The *report* is out of repo scope, but the repo should make the model and history easy to cite. |
| Report: agent improvement / evaluation process | ⚠️ Weak | `audits/` exists, but there is no template or convention for recording per-step evaluation and refinement, which the report explicitly requires. |

**New compliance gap (Query Design, PDF Phase-1 step 7):** the PDF mandates *"at least 5 meaningful SQL queries… Each query must include: Business question; Target user(s); Short explanation of why the query is useful; SQL statement."* The skill's Step 7 enumerates query topics but does **not** require this 4-part structure or the ≥5 minimum. As written, the agent can satisfy the skill while failing the official deliverable. This must be fixed in the skill before generation.

## 5. Teacher Demo Comparison

**Adapted well:**
- Kept the demo's command/skill topology (`.opencode/commands/design-db.md` + `db-design-pipeline/SKILL.md`) and the `/design-db req/business-requirement.md` entry point.
- Expanded the demo's 2-step stub workflow into the full 7-step pipeline.
- Cleaned up the demo skill's broken artifact: the demo `SKILL.md` literally begins with a stray `cat > … <<'EOF'` heredoc wrapper and `<!-- YOUR SKILL DESCRIPTION HERE -->` placeholders. The repo version is a proper, filled-in skill. Good.
- Carried `req/business-requirement.md` over unchanged.

**Intentionally (and justifiably) differs:**
- `docs/` → `outputs/` with `G<Group number>` naming. The demo README itself says *"The demo Git repository include the following files and folders, your group could adapt it"* and *"If your group uses a different command name, update this README."* So this is the demo inviting adaptation, and the official PDF mandates `outputs/`. Correct call.
- Added `AGENT.md`, top-level `SKILL.md`, `scripts/`, `audits/` — required by CS486 or useful support. Justified.

**Useful demo idea partially missing:**
- The demo highlights `templates/` for "consistent outputs." The repo keeps the empty folder and references it but never populates it and does not track it. Either deliver on the idea (add starter templates or at least a `.gitkeep`) or drop the reference — currently it is a dangling promise.

## 6. OpenCode Workflow Quality

- **`AGENTS.md` clarity:** Strong. Clear recurring context, explicit 7-step order, "do not jump to DDL," required outputs, MS SQL Server default, design rules, and the two critical booking rules. The single defect is the hardcoded root path.
- **Root `SKILL.md` purpose:** Reasonable as the official manifest — it lists the one skill, its steps, DBMS, and invocation. It is essentially a pointer; acceptable, though it duplicates step names already in the pipeline skill (low maintenance risk).
- **`.opencode/commands/` design:** A single `/design-db` command. For this project scope, one command is appropriate — not too few. However it is *coarse*: it always runs the whole pipeline. The README's own cost-control advice ("generate only file 03", "update only one section") is not matched by any command surface, so users must hand-write prompts. A thin per-step or "resume from step N" capability would make the workflow genuinely repeatable and cheaper (see §7).
- **Pipeline skill quality:** Good structure with per-step "based on the prior step" traceability. Gaps: no spec-file reference, and the Query Design step under-specifies the official format (§4).
- **Is `/design-db req/business-requirement.md` the right main workflow?** Yes as the *entry* workflow. But it should also load the spec, and there should be a documented way to regenerate a single deliverable without re-running everything (the README preaches this but nothing enforces it).
- **Repeatable agent improvement:** Only partially supported. `audits/` is a folder, not a process. There is no evaluation rubric, no per-step "what failed / what we changed" template, and the validation scripts are too shallow to function as an objective evaluation signal.

## 7. Command and Skill Review

| File | Purpose | Status | Critique → Recommended improvement |
|---|---|---|---|
| `.opencode/commands/design-db.md` | `/design-db` entry; delegates to skill, reads `$ARGUMENTS` | Needs Fix (minor) | Only passes the condensed requirement; never mentions the spec. → Have it (or the skill) also read `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md`. Consider documenting a single-step invocation for cheap regeneration. |
| `.opencode/skills/db-design-pipeline/SKILL.md` | Full 7-step pipeline | Needs Fix (major) | (a) Step 7 omits the official 4-part query format and ≥5 minimum; (b) does not reference the spec; (c) Step 5 DDL does not explicitly require approval/check-in metadata columns the spec lists. → Rewrite Step 7 to mandate ≥5 queries each with Business question / Target user(s) / Explanation / SQL; add a "read the spec" instruction; cross-link entities from spec §5. |
| `SKILL.md` (root) | Official skill manifest | OK | Accurate. Minor: duplicates step list from the pipeline skill — keep them in sync or have it link rather than restate. |
| `AGENTS.md` | Project rules + workflow | Needs Fix (minor) | Hardcoded root path; otherwise excellent. → Use a generic placeholder; optionally add a one-line pointer that the spec is the authoritative detail source. |
| `AGENT.md` | Official manifest (group, LLM) | OK | `GXX`/`STUDENT_NAME_*` are expected placeholders. Keep `Model` accurate vs. the provider actually connected. |

## 8. Validation Script Review

Both scripts use `#!/usr/bin/env bash` + `set -euo pipefail` and only `wc`/`grep`/`tr` — portable on any machine with bash; they require bash specifically (arrays, `[[ ]]`), and the README correctly invokes them with `bash`.

- **Safe at setup stage?** Yes. They read-only check file existence/size; they never create or require deliverables to run.
- **Fail gracefully before deliverables exist?** They exit 1 with clear `[MISS]` output. *Functionally* correct, but **semantically misleading at setup**: a fresh teammate running them now sees "FAIL," which looks like something is broken when the absence is expected.
- **Support final validation later?** Yes for existence (`check_required_files.sh`) and shallow SQL sanity (`validate_sql.sh`).
- **Validate enough?** No — too weak. `validate_sql.sh` only greps for any SQL keyword and non-zero size. It does not check that `05` has `CREATE TABLE` + PK/FK/CHECK, that `07` contains ≥5 queries in the required 4-part format, or that markdown deliverables contain a Mermaid `erDiagram` (file 02) or a 3NF/validation section (file 04).
- **Setup/final modes?** Recommended. A `--setup` mode that reports "0/7 present — expected at setup" and exits 0, vs. the current `--final` behavior, would remove the false-alarm and let the script double as an objective evaluation signal for the improvement report.

## 9. Repository Cleanliness and Portability

- **Hardcoded absolute paths:** Confirmed — `README.md` lines 14, 36, 136 and `AGENTS.md` line 7 all hardcode `/mnt/vquclinh/PROJECT-CMAKE/SPACEWISE-AGENT/spacewise-agent`. The demo used `cd path/to/your/project`. This is the biggest cleanliness defect for a shared repo.
- **Machine-specific assumptions:** Only the paths above; no OS-specific tooling beyond `pdftotext` (used by reviewers, not the workflow).
- **Duplicate/conflicting requirement files:** `req/business-requirement.md` (condensed) and `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` (detailed) coexist and are *complementary*, not conflicting. Acceptable, but the workflow must point at the detailed one (§6–7).
- **Untracked empty folder:** `.opencode/skills/db-design-pipeline/templates/` exists but is empty and has no `.gitkeep`, so it will not appear in the clone. README + audit 00 reference it → dangling.
- **Unnecessary files / zip + PDF placement:** `cs486-demo-share.zip` (44 KB) and `CS486_Project.pdf` (133 KB) sit at repo root and will be committed. For a submission repo this is arguably fine (provenance), but the demo zip in particular is scaffolding, not a deliverable — consider a `reference/` or `docs/source/` subfolder, or gitignoring the zip, to keep the root clean.
- **`.gitignore` quality:** Good — covers env/keys, OS files (`.DS_Store`, `__MACOSX/`), IDE, Node, Python, build, logs, and OpenCode local state. Appropriate for this repo.
- **README clarity:** Clear and thorough overall (install, connect, run, validate, cost control, integrity). Hurt only by the hardcoded paths and the `templates/` reference.
- **Clone-and-use:** A teammate can clone and follow the README, but the `cd /mnt/vquclinh/...` lines will not exist on their machine — a friction point that reads as carelessness in review.

## 10. Language and Consistency Check

- **No Chinese / unintended non-English content** in any authored repo file (`*.md`, `*.sh`). A targeted CJK/Hiragana/Katakana/Hangul scan returned nothing; the only non-ASCII glyphs are typographic (`— ’ → ↔`) and box-drawing characters. (Vietnamese staff names appear inside the binary `CS486_Project.pdf` only — an official source document, not an authored repo file — so this is not a repo-language issue.)
- **Terminology consistency:** "OpenCode," "DeepSeek," "Campus Space Management System," and `outputs/` are used consistently across README/AGENT/AGENTS/SKILL.
- **DBMS consistency:** Microsoft SQL Server stated consistently in `AGENTS.md`, the pipeline skill, and root `SKILL.md`, all noting it is configurable. Consistent.
- **Group placeholder:** `GXX` used consistently in AGENT/AGENTS/skill/scripts; README uses both `G<Group number>` and the `G01` example. Consistent and clear.

## 11. Database-Design Readiness

Mapping the critical rules against what the skill/command will *force*:

| Concern | Forced by skill? | Notes |
|---|---|---|
| Users & university accounts | ✅ | Step 1 roles; sample data "users with all roles." |
| Spaces & space statuses | ✅ | Sample data "spaces with all statuses." |
| Facilities per space | ✅ | Sample data "facilities and space-facility mappings" (maps to spec `space_facilities`). |
| Booking request lifecycle | ✅ | Statuses listed; sample data "bookings with various statuses." |
| Approval/rejection metadata | ⚠️ Partial | Present in requirement + Step 1 analysis, but Step 5 DDL does not *explicitly* require decision-maker/decision-time/decision-note/rejection-reason columns (spec `booking_decisions`). Risk of omission. |
| Check-in / check-out usage | ⚠️ Partial | Sample data covers "usage sessions"; DDL step doesn't explicitly call out actual start/end, checked-in-by, condition fields (spec `usage_sessions`). |
| Maintenance records | ✅ | Sample data "maintenance records with various statuses." |
| No overlapping approved bookings | ✅ | AGENTS critical rule 1 + Step 4 "overlap conflict prevention logic validation." Strong. |
| Cannot book maintenance/closed/retired | ✅ | AGENTS critical rule 2 + Step 4 "status-based booking prevention validation." Strong. |
| Historical records | ✅ | Step 7 "booking history," "no-show," "maintenance summary." |
| Useful SQL queries w/ business question, target user, explanation, SQL | ❌ | **Not enforced** — Step 7 lists topics only. This directly contradicts the PDF's mandatory query format. |

Net: business-rule coverage is strong (especially the two critical booking constraints), but (a) the query deliverable format is not enforced, and (b) DDL-level capture of approval/usage metadata is implicit rather than required. Both should be tightened in the skill so the generated artifacts map cleanly onto spec §5 entities and PDF §step-7.

## 12. Problems and Risks

**Critical (must fix before commit):**
- None that block a commit outright — the repo is structurally compliant. (Nothing here risks data loss or breaks the official file contract.)

**Major (should fix before running deliverable generation):**
1. Skill Step 7 does not enforce the official query format (≥5 queries × {business question, target user, explanation, SQL}). Will produce a non-compliant `07-query-design`.
2. Skill and `/design-db` command do not reference `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md`; the agent may design from the condensed requirement and miss entities/rules.
3. Hardcoded absolute paths in `README.md` (×3) and `AGENTS.md` (×1) — portability defect for a shared/submitted repo.

**Minor (can fix later):**
4. DDL step (Step 5) should explicitly require approval (`booking_decisions`) and usage-session (`usage_sessions`) metadata columns.
5. `validate_sql.sh` / `check_required_files.sh` are too shallow and emit a misleading "FAIL" at setup — add a setup mode and stronger final checks.
6. Empty untracked `templates/` referenced by README + audit 00 — add `.gitkeep`/starter templates or remove references.
7. `audits/00-setup-project-audit.md` still has `Date: YYYY-MM-DD`.

**Nice-to-have (optional polish):**
8. Add an evaluation/iteration audit template to operationalize the report's required "agent improvement process."
9. Move `cs486-demo-share.zip` (and possibly the PDF) into a `reference/` folder or gitignore the zip to keep the root clean.
10. Consider a single-step/resume invocation so the README's cost-control advice is actually executable.

## 13. Recommended Fixes Before Commit

Concrete checklist (to be applied by OpenCode + DeepSeek — **not** by this reviewer):

1. **[Major]** Rewrite Step 7 of `.opencode/skills/db-design-pipeline/SKILL.md` to require **at least 5** queries, each documented with **Business question / Target user(s) / Short explanation / SQL statement** (keep the topic list as suggestions). Mirror the requirement in root `SKILL.md` if it restates steps.
2. **[Major]** Add an explicit instruction in the skill (and a line in `design-db.md`) to read `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` as the authoritative detail source, and to align tables with spec §5 entities.
3. **[Major]** Replace the hardcoded `/mnt/vquclinh/...` path in `README.md` (3 places) and `AGENTS.md` (Recurring Context) with a generic placeholder such as `cd <your-project-folder>`.
4. **[Minor]** In Step 5 (DDL), explicitly require columns for approval/rejection metadata and check-in/check-out usage sessions per spec `booking_decisions` and `usage_sessions`.
5. **[Minor]** Add a `--setup`/`--final` mode (or a clear "0/7 expected at setup" message with exit 0) to the two scripts, and strengthen `validate_sql.sh` (check `CREATE TABLE`+PK/FK in 05; ≥5 query blocks in 07).
6. **[Minor]** Resolve `templates/`: add `.gitkeep` (or starter templates) or remove the references in `README.md` and `audits/00-setup-project-audit.md`.
7. **[Minor]** Set the real date in `audits/00-setup-project-audit.md` (`2026-06-17`).
8. **[Optional]** Add `audits/`-based evaluation template; relocate/ignore `cs486-demo-share.zip`.

Do **not** generate any of the 7 deliverables while applying these fixes.

## 14. Recommended OpenCode Prompt to Apply Fixes

```text
You are the primary project agent (OpenCode + DeepSeek). Apply ONLY setup fixes.
Do NOT generate any of the 7 deliverables. Keep outputs/ empty except .gitkeep.
Keep every repository file English-only.

Fix these:
1. In .opencode/skills/db-design-pipeline/SKILL.md, rewrite Step 7 (Query Design) to
   require AT LEAST 5 SQL queries, and require each query to include: Business
   question, Target user(s), Short explanation of why it is useful, and the SQL
   statement. Keep the existing query topics as suggestions only.
2. In .opencode/skills/db-design-pipeline/SKILL.md and .opencode/commands/design-db.md,
   instruct the agent to also read CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md as the
   authoritative detail source and to align tables with its recommended entities
   (users, spaces, facilities, space_facilities, bookings, booking_decisions,
   usage_sessions, maintenance_records).
3. In README.md (3 places) and AGENTS.md (Recurring Context), replace the hardcoded
   path /mnt/vquclinh/PROJECT-CMAKE/SPACEWISE-AGENT/spacewise-agent with a portable
   placeholder such as `cd <your-project-folder>`.
4. In Step 5 (DDL) of the skill, explicitly require approval/rejection metadata and
   check-in/check-out usage-session columns.
5. Resolve the templates/ inconsistency: either add
   .opencode/skills/db-design-pipeline/templates/.gitkeep or remove all references to
   templates/ from README.md and audits/00-setup-project-audit.md.
6. Set the real date 2026-06-17 in audits/00-setup-project-audit.md.

Do not change the 7 deliverable filenames, the outputs/ naming convention, or the
7-step order. Do not run git commit/push.

After applying the fixes, write a NEW audit at
audits/03-opencode-postfix-deep-setup-audit.md that: lists exactly what changed,
shows `git status --short`, confirms outputs/ still has no deliverables, and confirms
no hardcoded paths remain (grep for /mnt/vquclinh).
```

## 15. Recommended Next Workflow After Fixes

1. **Re-review / self-check (OpenCode):** confirm fixes via `grep -rn /mnt/vquclinh .` (expect none in README/AGENTS) and `find outputs -type f` (expect `.gitkeep` only).
2. **Validate setup:** `bash scripts/check_required_files.sh` and `bash scripts/validate_sql.sh` — at setup these still report missing files (expected; ideally now via a setup-mode message).
3. **Fill identity:** set the real group number and member names in `AGENT.md` once assigned.
4. **Commit (only when the user asks):** create a branch off `main`, stage the setup files, and commit — do **not** commit API keys or the local OpenCode state (already gitignored).
5. **Push to GitHub:** push the branch / open a PR per the group's process.
6. **Generate deliverables later:** run `/design-db req/business-requirement.md` (now spec-aware) to produce `outputs/01..07-...-G<NN>`. Prefer single-file regeneration prompts (per README cost-control) over full reruns, and record each evaluation/refinement iteration in a new `audits/NN-...md` to feed the required group report.

## 16. Final Verdict

**PASS WITH FIXES.** The repository is structurally compliant and clean enough to pass, but it is **not ready to commit as-is** — it needs one more OpenCode fix pass to enforce the official query format, wire the skill to the detailed spec, and remove the hardcoded paths before generating any deliverables.
