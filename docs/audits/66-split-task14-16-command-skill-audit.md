# Audit - Split Task 14-16 Command and Skill Files

> Date: 2026-08-10  
> Operator/member: (session)
> Tool: OpenCode (edit + read + grep)
> Provider/model/variant: deepseek-v4-flash-free (opencode/deepseek-v4-flash-free)
> OpenCode command used: none (direct conversation task)

## Task goal

Correct the Phase 2 workflow setup so Tasks 14, 15, and 16 each have their own
command and skill file instead of one combined `14-16` command/skill pair.

Phase 2 steps evaluated: Tasks 14, 15, and 16 command/skill structure.

## Files created / changed

Created:

- `.opencode/commands/14-data-generator.md`
- `.opencode/commands/15-index-tuning-report.md`
- `.opencode/commands/16-analytical-queries.md`
- `.opencode/skills/db-design-pipeline/14-data-generator/SKILL.md`
- `.opencode/skills/db-design-pipeline/15-index-tuning-report/SKILL.md`
- `.opencode/skills/db-design-pipeline/16-analytical-queries/SKILL.md`
- `docs/audits/66-split-task14-16-command-skill-audit.md`

Deleted:

- `.opencode/commands/14-16-generate-data-tuning-analytics.md`
- `.opencode/skills/db-design-pipeline/14-16-data-tuning-analytics/SKILL.md`

Changed:

- `AGENT.md`
- `.opencode/skills/db-design-pipeline/SKILL.md`

## What was evaluated

- User correction: "the command and skill is for each task, don't combine them
  into only 1 file"
- Existing Phase 2 command naming style for Tasks 11, 12, and 13
- Existing shared pipeline skill section for Phase 2 task skills
- Current AGENT status section

## Issues found

- The previous implementation incorrectly combined Tasks 14, 15, and 16 into
  one command and one skill file.
- `AGENT.md` and the shared pipeline skill also pointed to the combined
  `14-16` workflow.

## Changes made

- Replaced the combined command/skill with three task-specific command files and
  three task-specific skill directories.
- Updated `AGENT.md` to list:
  - `/14-generate-data-generator`
  - `/15-generate-index-tuning-report`
  - `/16-generate-analytical-queries`
- Updated `.opencode/skills/db-design-pipeline/SKILL.md` to list separate
  `14-data-generator`, `15-index-tuning-report`, and `16-analytical-queries`
  skills.
- Removed the empty combined skill directory after deleting its `SKILL.md`.

## Improvement classification

- Command improvement
- SKILL.md improvement
- Documentation improvement

## Validation commands run

```bash
git diff --check
rg -n "14-16|generate-data-tuning-analytics|data-tuning-analytics" AGENT.md .opencode/commands .opencode/skills/db-design-pipeline/SKILL.md .opencode/skills/db-design-pipeline/14-data-generator .opencode/skills/db-design-pipeline/15-index-tuning-report .opencode/skills/db-design-pipeline/16-analytical-queries
find .opencode/commands -maxdepth 1 -type f | sort | rg '14|15|16'
find .opencode/skills/db-design-pipeline -maxdepth 2 -type f | sort | rg '14|15|16'
git status --short
```

## Validation results

- `git diff --check` passed.
- Active command/skill files contain no remaining combined `14-16` workflow
  references.
- Command listing now shows one command file each for Tasks 14, 15, and 16.
- Skill listing now shows one skill file each for Tasks 14, 15, and 16.
- Historical references remain only in audit `65`, which records the superseded
  earlier change.

## Risks / caveats

- Outputs 14, 15, and 16 were not changed in this correction.
- SQL Server execution was not part of this command/skill split.
- The worktree still contains unrelated pre-existing changes: one old audit is
  modified and the repository validation scripts are deleted.

## Git status summary

Relevant changes from this task:

- modified `AGENT.md`
- modified `.opencode/skills/db-design-pipeline/SKILL.md`
- added three Task 14-16 command files
- added three Task 14-16 skill files
- deleted the combined Task 14-16 command/skill files
- added this audit

Unrelated pre-existing status:

- modified `docs/audits/18-move-audits-and-improve-project-requirement-docs-audit.md`
- deleted `scripts/check_required_files.sh`
- deleted `scripts/validate_sql.sh`

## Recommended next steps

Use the separate commands going forward:

1. `/14-generate-data-generator`
2. `/15-generate-index-tuning-report`
3. `/16-generate-analytical-queries`

