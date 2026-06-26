# README Team Guide Audit

> Author: OpenCode + DeepSeek (auxiliary README writer/editor). OpenCode + DeepSeek remains the primary project agent for deliverable generation. No deliverable was generated; no Git/destructive command was run.
> Date: 2026-06-17

## Summary

Rewrote `README.md` from a fairly formal setup doc into a friendly, practical **team guide** so every group member can understand the repo, the OpenCode workflow, and the audit habit needed for the report's "agent improvement process." The previous README's useful content (install/connect steps, deliverable names, validation commands, cost notes, integrity notes) was preserved but reorganized into clearer, teammate-readable sections, and several new how-we-work sections were added.

Before editing, I read the current `README.md`, `AGENT.md`, `AGENTS.md`, `SKILL.md`, `.opencode/commands/design-db.md`, `.opencode/skills/db-design-pipeline/SKILL.md`, both scripts, and `audits/03-fix-clean-setup-audit.md`, and confirmed `outputs/` contains only `.gitkeep`.

## Files Changed

| File | Change |
|---|---|
| `README.md` | Rewritten as a 12-section team guide (friendly, simple English). |
| `audits/04-readme-team-guide-audit.md` | Created (this audit). |

No other files were touched.

## Important README Sections Added

1. **What this repo is** — repo is the agent + workflow + paper trail, not just answers.
2. **Big rule for the team** — OpenCode + DeepSeek is primary; Claude/ChatGPT only for support/review; no silent output edits; audit every session.
3. **Folder and file map** — compact tree plus a plain-language "what is this for" table.
4. **How the OpenCode workflow works** — the chain AGENTS.md → `/design-db` → skill → 7 steps → outputs → audit, with the main command.
5. **What the 7 deliverables are** — exact filenames, the ≥5 query rule, and the required 4 parts per query.
6. **Run setup validation now** — `--setup` commands and expected PASS / `.gitkeep`-only result.
7. **Validate final deliverables later** — `--final G<NN>` commands and the note that final mode is *supposed* to fail before generation.
8. **How the team should work from now on** — 9-step loop plus example commit messages.
9. **Audit rule — very important** — what each audit must contain, why, and a reusable paste-in snippet.
10. **How to improve the agent/skill later** — fix the rules/skill first, then regenerate; with the Step 7 query example.
11. **Cost and safety notes** — reasoning effort, no secrets, no `.env`, review diffs, no invented group/names.
12. **Before submission checklist** — fill group/members, confirm model, run final validation, exact 7 outputs, report contents, audit history, clean git.

Style kept friendly and copy-paste-friendly; filenames kept exact; no large official text pasted (pointed to source files instead); the false claim "Claude is the main agent" was avoided — OpenCode + DeepSeek is stated as the main workflow throughout.

## Validation Run

| Command | Result |
|---|---|
| `git status --short` | ` M README.md` only (plus this new untracked audit). |
| `find outputs -maxdepth 2 -type f` | `outputs/.gitkeep` only. |
| `bash scripts/check_required_files.sh --setup` | `SETUP PASS` — exit 0. |
| `bash scripts/validate_sql.sh --setup` | `SETUP PASS` — exit 0. |
| `grep -rn "/mnt/vquclinh" --include=*.md --include=*.sh .` (excl. audits) | `(none)` — no hardcoded machine paths. |

## Deliverables Status

`outputs/` still contains only `.gitkeep`. **No final deliverables were generated.** The README documents the 7 deliverables and the query format but does not create them.

## Risks / Notes

- Placeholders remain by design: `GXX` / `STUDENT_NAME_*` in `AGENT.md`/`AGENTS.md`/command/skill, and `G<Group number>` / `G<NN>` in the README. The team must fill the real group number, member names, and confirm the model before submission.
- README is English-only and friendly per request; no academic-prose rewrite needed elsewhere.
- `git status` shows the scaffold is already tracked (only `README.md` modified now), so the README change is a clean, isolated diff.

## Next Steps

The repo is **ready to commit** (README guide + this audit). Suggested message: `setup: improve OpenCode workflow docs` (or `docs: rewrite README as team guide`). Committing/pushing is left to the team — not done here. When ready to build deliverables later, run `/design-db req/business-requirement.md` via OpenCode + DeepSeek, then validate with `--final G<NN>` and write the next audit.
