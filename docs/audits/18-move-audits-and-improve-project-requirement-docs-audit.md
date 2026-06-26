# Audit — Move Audits and Improve Project/Requirement Docs

> Date: 2026-06-20
> Operator/member: Vo Quoc Linh (24125065) — setup/documentation only
> Tool: Claude Code (auxiliary setup/documentation support; OpenCode remains the primary project workflow)
> Provider/model/variant: Claude Opus 4.8 (1M context) — claude-opus-4-8[1m]
> OpenCode command used: none (auxiliary documentation edits)

## Task goal

Improve project clarity before Phase 1 continues: move audits from `audits/` to `docs/audits/`, update all active audit-path references, add `docs/project-overview.md`, and refactor `req/business-requirement.md` into a clearer 15-section business-domain input — without filling placeholders or generating outputs.

## Files moved / created / changed

**Moved (`git mv`, history preserved) — `audits/` → `docs/audits/`:**
- All numbered audits `00`–`16`, `AUDIT_TEMPLATE.md`, and `.gitkeep` (18 tracked files).
- Untracked `17-restructure-business-requirement-audit.md` moved with plain `mv`.
- The now-empty `audits/` directory was removed.

**Created:**
- `docs/project-overview.md` — concise CS486/G08 project + Phase 1 overview, required outputs, target DBMS, current repo status (placeholders not production-ready), key paths, and the role of `docs/audits/`.
- `docs/audits/18-move-audits-and-improve-project-requirement-docs-audit.md` (this audit).

**Changed (audit-path references `audits/` → `docs/audits/`):**
- `AGENT.md`, `AGENTS.md` (incl. audit policy section), `README.md`, `.opencode/commands/design-db.md`, `.opencode/commands/audit-smoke-test.md`, `.opencode/skills/db-design-pipeline/SKILL.md`, `scripts/check_required_files.sh` (setup scaffold now requires `docs/audits/AUDIT_TEMPLATE.md`).
- `README.md` also: folder tree now shows a `docs/` node (`project-overview.md` + `audits/`), and a `docs/project-overview.md` "Start here" row was added to the files table.

**Refactored:**
- `req/business-requirement.md` — expanded to 15 sections (File purpose; Background; Current manual process; Problem statement; System goal; Stakeholders and user roles; Managed spaces; Facilities and equipment; Booking request lifecycle; Approval and rejection workflow; Check-in and check-out usage session; Maintenance management; History and reporting needs; Critical business rules; Assumptions and open questions). Added a "File purpose" header and a conservative, clearly-labelled Assumptions/Open-questions section. No new business rules invented; meaning preserved; "temporarily closed" kept consistent.

**Not changed:** the empty per-task command/skill placeholders (not filled).

## What was evaluated

The audit folder (tracked vs. untracked), every `audits/` reference in active files, the readability of `req/business-requirement.md`, and whether a project-overview doc existed.

## Issues found

- Audits lived at top-level `audits/`; the team wants them under `docs/audits/`, and active files/scripts referenced the old path.
- No `docs/project-overview.md` existed.
- `req/business-requirement.md` lacked a stated file purpose and an assumptions/open-questions section.

## Changes made

Performed the move with history-preserving `git mv`; repointed all active references to `docs/audits/`; created `docs/project-overview.md`; refactored the requirement file into 15 sections with conservative assumptions/open questions; updated the README tree/table.

## Improvement classification

- Documentation improvement
- AGENTS.md improvement
- Validation/test improvement (setup scaffold path)

## Confirmation: no Phase 1 outputs generated

No Phase 1 output was generated or modified. `outputs/` still contains only the group's previously-generated `01`/`02`/`03` G08 files plus `.gitkeep` — untouched by this task.

## Confirmation: no logs/memory/trajectory/eval folders added

No `logs/`, `memory/`, `trajectory/`, `eval/`, or registry files were created. The only new directory is `docs/` (holding `project-overview.md` and the moved `audits/`).

## Validation commands and results

| Command | Result |
|---|---|
| `find outputs -maxdepth 2 -type f` | `.gitkeep` + pre-existing `01`/`02`/`03` (unchanged). |
| `bash scripts/check_required_files.sh --setup` | **SETUP PASS** (exit 0); requires `docs/audits/AUDIT_TEMPLATE.md`; `[NOTE]` lists existing deliverables. |
| `bash scripts/validate_sql.sh --setup` | **SETUP PASS** (exit 0). |
| `find docs/audits -maxdepth 1 -type f` | 18 numbered audits + `AUDIT_TEMPLATE.md` + `.gitkeep` (this audit makes 19 numbered once saved). |
| `grep -R "audits/" (active, excl docs/audits)` | Only hit is the README tree's `audits/` node nested under `docs/` — structurally correct, not a stale path. |

## Risks / caveats

- **Historical audit text** still says `audits/` inside older audit files; per instruction this history was not rewritten.
- **Git rename heuristic** paired the old `audits/.gitkeep` with an empty command placeholder (both 0 bytes) in `git status`; purely cosmetic — file contents are correct.
- README's user-authored callout still says `outputs/` "must remain empty"; the group has in fact already generated `01`–`03`. Left as the team's wording; flagged previously.
- The official-PDF-vs-demo question about a root `SKILL.md` is unrelated and unaffected.

## Git status summary

```
R  audits/* -> docs/audits/*            (00–16 + AUDIT_TEMPLATE.md + .gitkeep, renamed)
?? docs/audits/17-restructure-business-requirement-audit.md   (moved untracked file)
?? docs/project-overview.md
 M AGENT.md  AGENTS.md  README.md  req/business-requirement.md
 M scripts/check_required_files.sh
 M .opencode/commands/audit-smoke-test.md  .opencode/commands/design-db.md
 M .opencode/skills/db-design-pipeline/SKILL.md
A  .opencode/commands/0{1..7}-generate-*.md  + 7 task-skill placeholders (carryover, untouched)
```

(Plus this new untracked audit. No `outputs/` changes.)

## Recommended next steps

1. (Optional) Commit — suggested message: `docs: move audits to docs/audits, add project-overview, restructure requirement`. Committing/pushing left to the team.
2. Reconcile the README "outputs must remain empty" callout with the actual state (Steps 1–3 already generated).
3. Task owners continue filling their per-task command/skill placeholders, writing each new audit under `docs/audits/` via `docs/audits/AUDIT_TEMPLATE.md`.
