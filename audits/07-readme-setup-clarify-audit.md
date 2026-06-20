# Audit — README Setup-Only Clarification

> Date: 2026-06-20
> Operator/member: Vo Quoc Linh
> Tool: opencode
> Provider/model/variant: openrouter/deepseek/deepseek-v4-pro
> OpenCode command used: manual prompt

## Task goal

Add a minimal sentence to README.md clarifying that `outputs/` must remain empty except `.gitkeep` until Phase 1 deliverable generation begins.

## Files created / changed

- `README.md` — added one sentence after the "Current setup scope" block.
- `audits/07-readme-setup-clarify-audit.md` (this file, created)

## What was evaluated

- Setup validation scripts after the README edit.
- `outputs/` (confirmed unchanged — only `.gitkeep`).
- Project scaffold (all 8 files OK).

## Issues found

None.

## Changes made

Added the following sentence to README.md after the existing "Current setup scope" note:

> The `outputs/` directory **must remain empty except `outputs/.gitkeep`** until the team explicitly begins Phase 1 deliverable generation.

No other files were modified. `AGENT.md`, `AGENTS.md`, `.opencode/` skill/command files, and `outputs/` were left untouched.

## Improvement classification

- Documentation improvement

## Validation commands run

```bash
find outputs -maxdepth 2 -type f | sort
bash scripts/check_required_files.sh --setup
bash scripts/validate_sql.sh --setup
```

## Validation results

```
outputs/.gitkeep
SETUP PASS: scaffold present and outputs/ has no deliverables yet.
SETUP PASS (SQL): No SQL deliverables yet.
```

All three checks passed.

## Risks / caveats

None. Change is a single sentence with no impact on workflow, scripts, or deliverables.

## Git status summary

```
 M README.md
?? audits/06-audit-policy-smoke-test-audit.md
?? audits/07-readme-setup-clarify-audit.md
```

README.md modified; two untracked audit files pending. No `outputs/` changes.

## Recommended next steps

- Commit the README change and both audit files when ready.
- No further setup changes needed.