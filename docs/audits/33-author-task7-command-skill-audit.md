# Audit — Author Task 7 Command + Skill (Vo Quoc Linh's 5 queries)

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 7 — Query Design (command + skill only)

## Task goal

Author the Step 7 command and task skill so the user can run `/07-generate-query-design` in OpenCode later to build `outputs/07-query-design-G08.sql`. Scope this run to **Vo Quoc Linh (24125065)'s 5 queries** only. Do **not** generate the output now.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `.opencode/commands/07-generate-query-design.md` | Authored (was empty) | Execution entrypoint: reads 05 (schema authority) + 06 (data) + 01–04 context; generates only `outputs/07-query-design-G08.sql`, a labelled **Vo Quoc Linh (24125065)** section with ≥5 queries; mandates the 4-part per-query format; SQL Server; self-review + audit; must not delete other members' sections. |
| `.opencode/skills/db-design-pipeline/07-query-design/SKILL.md` | Authored (was empty) | Quality rubric: purpose, inputs, mandatory 4-line per-query format, quality bar (≥5 varied queries, SQL Server, schema-valid, returns rows vs. sample data), candidate business-question prompts (not hard-coded SQL), consistency rules, validation checklist, common mistakes. |
| `docs/audits/33-author-task7-command-skill-audit.md` | Created | This audit. |

**Not done:** `outputs/07-query-design-G08.sql` was NOT created (the user will run the command in OpenCode). No other outputs/skills/commands changed.

## What was evaluated

The empty Task 7 command/skill placeholders, the PDF Step 7 requirement (≥5 queries per student, each with Business question / Target user(s) / Why useful / SQL), and the actual schema/data sources (Outputs 05/06) the queries must target.

## Changes made

- Command 07 scoped to a single member's ≥5-query section, with explicit inputs, the mandatory 4-part format, SQL Server + schema-validity requirements, a self-review step, and the audit requirement.
- Skill 07 written as a reusable rubric (no hard-coded SQL): it lists candidate business questions as prompts and enforces the format/quality/consistency bar.

## Improvement classification

- Command improvement
- SKILL.md improvement

## Validation commands run

```bash
ls outputs/07-query-design-G08.sql      # confirm not created
git status --short .opencode/commands/07-generate-query-design.md \
                   .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
```

## Validation results

- `outputs/07-query-design-G08.sql` is **absent** (correct — to be generated later).
- Only the command 07 and skill 07 files are modified this turn.

## Risks / caveats

- The deliverable ultimately needs **≥20 queries (≥5 per member)**; this command builds only Vo Quoc Linh's 5. The command is written to not overwrite other members' sections, but the team must still aggregate all four sections to meet the 20-query total.
- The skill is a rubric — query quality depends on the model run; after generation, review against the Output 05 schema and Output 06 data (the command includes a self-review and the skill a checklist for this).
- Static authoring only; no SQL executed.

## Git status summary

```
 M .opencode/commands/07-generate-query-design.md
 M .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
?? docs/audits/33-author-task7-command-skill-audit.md
```

## Recommended next steps

1. In OpenCode, run `/07-generate-query-design` to build the Vo Quoc Linh section of `outputs/07-query-design-G08.sql`; then review it against Output 05/06 and write the generation audit.
2. Have the other three members generate their ≥5-query sections to reach ≥20 total.
3. Run `bash scripts/validate_sql.sh --final G08` once `07` exists.
