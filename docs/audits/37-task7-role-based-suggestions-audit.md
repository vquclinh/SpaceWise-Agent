# Audit — Task 7 Role-Based Query-Type Suggestions (planning aid)

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 7 — Query Design (command + skill only)

## Task goal

Add a compact **role-based query-type suggestion** section to the Task 07 command as a planning aid — non-hard-coded, not member assignments, not final SQL — and refine the missing-query-types behavior so the command suggests candidates and asks for confirmation instead of silently generating. Keep skill 07 concise. Do not generate `outputs/07-query-design-G08.sql`.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `.opencode/commands/07-generate-query-design.md` | Edited | Added a **"Role-based query type suggestions"** section listing the 6 canonical G08 roles (Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager) with concise candidate categories, explicitly labelled optional planning suggestions (not assignments, not final SQL). Refined input handling: missing name/ID → ask; member-provided types that are 5+/distinct/role-fitting → use as given; target perspective present but types missing/<5/duplicated → **propose ≥5 candidates from the suggestions and ask to confirm/edit before generating**; never choose types silently and generate. |
| `.opencode/skills/db-design-pipeline/07-query-design/SKILL.md` | Edited | Added one compact bullet: query types may come from the command's role-based suggestions or the member's own choices, but must fit the declared target user perspective. Did **not** copy the full role list; no SQL added. (Skill still 50 lines.) |
| `docs/audits/37-task7-role-based-suggestions-audit.md` | Created | This audit. |

**Not done:** `outputs/07-query-design-G08.sql` was NOT generated. No Outputs 01–06, schema, or data changed. Mode A/Mode B behavior, BEGIN/END markers, `GO`, schema/data authority, and section preservation are all retained.

## What was evaluated

The open base framework (audit 36) against the need for a role→category planning aid, ensuring it stays a suggestion (no fixed member→role mapping) and that missing types trigger a confirm step rather than silent invention.

## Changes made

Inserted the role-based suggestions block and the refined input-handling rules into the command; added the single linking bullet to the skill. The suggestions are illustrative; the member still provides or confirms the final 5 distinct query types.

## Improvement classification

- Command improvement
- SKILL.md improvement

## Validation commands run

```bash
ls outputs/07-query-design-G08.sql            # confirm not created
git status --short .opencode/commands/07-generate-query-design.md \
                   .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
grep -cE 'Role-based query type suggestions|Student:|Lecturer:|Teaching Assistant:|Facility Staff:|Department Administrator:|Facility Manager:' \
     .opencode/commands/07-generate-query-design.md
wc -l .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
```

## Validation results

- `outputs/07-query-design-G08.sql` is **absent** (correct).
- Only the command 07 and skill 07 files changed this turn.
- The role-suggestions heading and all 6 canonical roles are present in the command (7 matches).
- Skill 07 remains concise (50 lines); only one bullet added; no role list or SQL copied in.

## Risks / caveats

- Static authoring only; no SQL executed, no output produced.
- The suggestions are a planning aid; the member must still confirm/provide the final 5 distinct query types — the command requires a confirmation step when types are missing, but the generating model must honor it.
- No member→role assignment is implied; any member may pick any role perspective(s) and categories that fit.

## Git status summary

```
 M .opencode/commands/07-generate-query-design.md
 M .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
?? docs/audits/37-task7-role-based-suggestions-audit.md
```

## Recommended next steps

1. Run Mode A per member: `/07-generate-query-design Member: <name> (<id>); Target users: <roles>; Query types: <5 distinct>` — or omit types to get role-based candidates to confirm.
2. After all four sections exist, run `Mode: review-all`, then `bash scripts/validate_sql.sh --final G08`, and execute `05` → `06` → `07` on a SQL Server instance.
