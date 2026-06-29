# Audit — Refactor Task 7 into a Reusable Per-Member Query-Design Framework

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 7 — Query Design (command + skill only)

## Task goal

Refactor the Step 7 command and skill from a single-member (Vo Quoc Linh) scope into a **reusable per-member framework** for the whole G08 team. Keep the skill concise and rubric-based (no hard-coded SQL). Do not generate `outputs/07-query-design-G08.sql`.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `.opencode/commands/07-generate-query-design.md` | Edited | Removed the permanent "Vo Quoc Linh's 5 queries / this run's scope" wording. Now reusable for any member: requires **member full name + student ID + ≥5 query types** in `$ARGUMENTS` (with an example invocation); stops/asks if any are missing (no silent invention); generates/updates one member section per run; preserves other members' sections; adds the member header block (with the 5-type plan) and the per-query format (Query type + Business question + Target user(s) + Why useful + SQL). |
| `.opencode/skills/db-design-pipeline/07-query-design/SKILL.md` | Edited | Rewritten as a compact, member-agnostic rubric: inputs (05 schema authority, 06 data), required header + per-query format, core rules (SQL Server, read-only SELECT, real identifiers, enum spellings, don't overwrite other sections), short example categories (illustrative only), and a quick checklist. No fixed SQL; trimmed verbose prose. |
| `docs/audits/34-refactor-task7-reusable-per-member-audit.md` | Created | This audit. |

**Not done:** `outputs/07-query-design-G08.sql` was NOT generated. No Outputs 01–06, schema, or data were modified.

## What was evaluated

The previous (single-member) command/skill 07 against the requirement for a shared team framework; the PDF Step 7 fields; and the need to keep skills concise and non-hard-coded.

## Changes made

- **Command 07** is now parameterized per run (member name, student ID, 5 query types), refuses to invent missing inputs, writes only one member's section, preserves others, and enforces the member header + per-query `Query type` + PDF fields.
- **Skill 07** is a short reusable rubric: schema/data authority, required structure, rules, example categories (clearly "illustrative only"), and a checklist — no final SQL pasted.

## Improvement classification

- Command improvement
- SKILL.md improvement

## Validation commands run

```bash
ls outputs/07-query-design-G08.sql            # confirm not created
git status --short .opencode/commands/07-generate-query-design.md \
                   .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
grep -niE "run's scope|Linh's 5|only.*Vo Quoc Linh" <the two 07 files>
```

## Validation results

- `outputs/07-query-design-G08.sql` is **absent** (correct — generated later, per member).
- Only the command 07 and skill 07 files changed this turn.
- No permanent single-member scope wording remains; "Vo Quoc Linh (24125065)" now appears only inside the **example invocation** (intended illustration), not as the fixed scope.

## Risks / caveats

- Static authoring only; no SQL executed and no output produced.
- The command relies on the user passing member name, ID, and 5 query types at invocation; it will stop and ask if they are missing.
- The deliverable still requires **all four members (≥20 queries total)**; each member runs the command once for their section. The command is written to preserve existing sections, but the team should review the merged file for duplicate titles/types.

## Git status summary

```
 M .opencode/commands/07-generate-query-design.md
 M .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
?? docs/audits/34-refactor-task7-reusable-per-member-audit.md
```

## Recommended next steps

1. Each member runs `/07-generate-query-design Member: <name> (<id>); Query types: <5 categories>` in OpenCode to add their section; the command writes its own generation audit each time.
2. After all four sections exist, review the merged `07` file and run `bash scripts/validate_sql.sh --final G08`.
