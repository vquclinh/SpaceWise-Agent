# Audit — Standardize Agent / Skill / Commands / Audit Policy

> Date: 2026-06-17
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode (auxiliary setup support; OpenCode remains the primary project workflow)
> Provider/model/variant: DeepSeek V4 Pro (1M context)
> OpenCode command used: none (auxiliary setup edits)

## Task goal

Standardize the repository agent instructions, database-design skill, OpenCode commands, and audit policy so future work can be evaluated and summarized as the group's "agent improvement process." Phase 1 only — no deliverables generated.

## Files created / changed

| File | Change |
|---|---|
| `audits/AUDIT_TEMPLATE.md` | **Created.** Canonical audit structure referenced by AGENTS.md and all commands. |
| `AGENT.md` | **Rewritten** as a concise course-facing manifest: project, group G08, members/IDs, OpenCode-primary + per-session model policy, SQL Server, Phase 1 workflow summary, output/audit locations, audits-as-evidence note. |
| `AGENTS.md` | **Rewritten** as the agent-facing rulebook with the 10 required sections (scope/phase, source-of-truth order, editing rules, SQL Server rules, Phase 1 output rules, team workflow, audit policy, validation policy, git/safety, future deployment) plus the full audit-policy checklist and critical business rules. |
| `SKILL.md` (root) | **Re-created** (it had been deleted in commit `d52d6eb`). Concise manifest pointing to the detailed skill, summarizing the 7-step pipeline, SQL Server target, and the audit requirement. Re-creating it also restores the official CS486-required file and makes `check_required_files.sh --setup` pass. |
| `.opencode/skills/db-design-pipeline/SKILL.md` | **Enhanced:** per-step quality checklists (Steps 5 & 7), a SQL Server Requirements section (PK/FK/NOT NULL/CHECK/DEFAULT/indexes + the trigger/transaction/app-layer strategy for rules a simple CHECK can't enforce), the explicit domain rules list, Step 7 raised to ≥20 queries total / ≥5 per member with the 4 members, and a Phase 1 Audit Requirements section. |
| `.opencode/commands/generate-phase1.md` | **Created.** Generates the 7 G08 outputs immediately on invocation; follows the audit policy. |
| `.opencode/commands/refine-output.md` | **Created.** Refines one output (or small related group) from `$ARGUMENTS`; preserves consistency; follows the audit policy. |
| `.opencode/commands/validate-phase1.md` | **Created.** Reviews the whole Phase 1 set (presence, consistency, dialect, business rules, query rules), runs/recommends the scripts, follows the audit policy. |
| `.opencode/commands/audit-smoke-test.md` | **Created.** Safe read-only rehearsal of the audit policy; does not touch `outputs/`; suggests audit `09-audit-policy-smoke-test-audit.md`. |
| `.opencode/commands/test-phase1-db.md` | **Created** as a future (do-not-run-now) SQL Server execution-testing command; no deployment code. |
| `README.md` | Updated folder map and files table for all commands; added a "Which file is which" explanation (AGENT vs AGENTS, SKILL vs pipeline skill), a short audit-policy section (including "Follow the repository audit policy" and audits-as-evidence), and a Phase 1 scope note (no frontend/backend/deploy). |
| `audits/08-standardize-agent-skill-commands-audit.md` | **Created** (this audit). |

`.opencode/commands/design-db.md` was left as the generic lower-level command (unchanged).

## What was evaluated

The full workflow foundation: AGENT.md, AGENTS.md, root SKILL.md, the detailed pipeline skill, the command set, and the audit policy — against the task spec and the official CS486 requirements (AGENT.md, SKILL.md, outputs/, the 7 deliverable names, and the per-student ≥5-query rule).

## Issues found

- Root `SKILL.md` was missing (deleted in `d52d6eb`), which both breaks the official requirement and fails `check_required_files.sh --setup`.
- The command set had been reduced to only `design-db.md` (earlier `generate-phase1`/`refine-output`/`validate-phase1` work was uncommitted and reverted).
- No canonical audit template existed, and the audit policy was informal (only narrative guidance in the README).
- The pipeline skill's Step 7 required only ≥5 queries (not the group's ≥20 total / ≥5 per member), and the SQL Server constraint-enforcement strategy for non-CHECK-able rules was not spelled out.

## Changes made

Re-created root SKILL.md and the four/five commands; added the audit template; rewrote AGENT.md and AGENTS.md to the standardized structure; strengthened the pipeline skill (quality checklists, SQL Server requirements + enforcement-strategy guidance, ≥20/≥5-per-member queries, Phase 1 audit requirements); updated the README. No `outputs/` changes.

## Improvement classification

- AGENTS.md improvement
- SKILL.md improvement
- Command improvement
- Documentation improvement

(No output refinement — no deliverables exist yet. This sets up future output refinement and validation/test improvements.)

## Validation commands run

```bash
git status --short
find outputs -maxdepth 2 -type f | sort
bash scripts/check_required_files.sh --setup
bash scripts/validate_sql.sh --setup
grep -rlP '[CJK ranges]' --include='*.md' --include='*.sh' .   # language check
```

## Validation results

- `find outputs -maxdepth 2 -type f` → `outputs/.gitkeep` only.
- `check_required_files.sh --setup` → **SETUP PASS** (exit 0) — `SKILL.md` now present again.
- `validate_sql.sh --setup` → **SETUP PASS** (exit 0).
- Language check → no CJK; authored files are English-only.

## Risks / caveats

- **Audit numbering gap:** audits `05`–`07` from earlier sessions were uncommitted and reverted, so the sequence here jumps `00–04` → `08`. The numbers `08` (this audit) and `09` (smoke-test) follow the task's explicit suggestions and keep the command files' documented targets consistent. If the team prefers a gap-free sequence, renumber this to `05` and update `audit-smoke-test.md` accordingly.
- The commands describe behavior for OpenCode to execute later; they were not run, so no deliverables were produced.
- `test-phase1-db.md` is intentionally inert until the 7 outputs exist and a SQL Server-compatible environment is available (not Supabase/PostgreSQL).

## Git status summary

```
 M .opencode/skills/db-design-pipeline/SKILL.md
 M AGENT.md
 M AGENTS.md
 M README.md
?? .opencode/commands/audit-smoke-test.md
?? .opencode/commands/generate-phase1.md
?? .opencode/commands/refine-output.md
?? .opencode/commands/test-phase1-db.md
?? .opencode/commands/validate-phase1.md
?? SKILL.md
?? audits/AUDIT_TEMPLATE.md
```

(Plus this new untracked audit. No `outputs/` changes.)

## Recommended next steps

1. (Optional) Commit — suggested message: `setup: standardize AGENT/AGENTS/SKILL, commands, and audit policy (G08)`. Committing/pushing is left to the team.
2. Run `/audit-smoke-test` once in OpenCode to confirm the audit habit works end to end (it will write `audits/09-audit-policy-smoke-test-audit.md`).
3. When ready, run `/generate-phase1` to produce the 7 G08 deliverables, then `/validate-phase1`, then `bash scripts/check_required_files.sh --final G08` and `bash scripts/validate_sql.sh --final G08`.
4. Keep recording the exact provider/model per session in each audit so the report can list all models used.
