# Audit — Task 7 Open Base Framework (per-member generation + full-file review)

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 7 — Query Design (command + skill only)

## Task goal

Refine the Step 7 command and skill into an **open base framework** for the whole team: (A) generate/update one member's query section at a time, (B) review the full `outputs/07-query-design-G08.sql` for run-readiness, and keep it extensible with no hard-coded member roles, categories, or final SQL. Do not generate the output now.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `.opencode/commands/07-generate-query-design.md` | Rewritten | Two documented modes: **Mode A** (per-member generation; requires member name, student ID, **target user perspective(s)**, ≥5 distinct query types; stops/asks if missing/duplicated) and **Mode B** (`Mode: review-all` — reviews the whole file, generates nothing, reports if the file is absent). Added **BEGIN/END MEMBER SECTION markers keyed by student ID**, per-query executable blocks ending in **`GO`**, `DECLARE`-for-parameters guidance, full-file run guidance (`sqlcmd` example, generic server/db), no fixed member→role/category assignments, and dual audit behavior. |
| `.opencode/skills/db-design-pipeline/07-query-design/SKILL.md` | Rewritten (concise) | Added base-framework bullets (one section/run, file runnable after 05+06, `GO` per block, `DECLARE` for params, no hard-coded SQL, no fixed roles, 05 authority / 06 reference, review-all mode) while keeping existing guardrails (distinct types, target user perspective, BEGIN/END markers by student ID, preserve other sections, no `SELECT *`, read-only only, no unexplained magic IDs, SQL Server dialect, enum spellings). Stayed compact; short template snippet only. |
| `docs/audits/36-task7-open-base-framework-audit.md` | Created | This audit. |

**Not done:** `outputs/07-query-design-G08.sql` was NOT generated. No Outputs 01–06, schema, or data changed.

## What was evaluated

The tightened (audit 35) command/skill against the need for an open team framework: dual workflows, student-ID-keyed sections, whole-file executability (`GO`), and extensibility without locking roles/categories.

## Changes made

Rewrote command 07 with Modes A/B, target-user-perspective input, BEGIN/END markers, `GO`-terminated blocks, `DECLARE` guidance, run guidance, and per-mode audit fields. Rewrote skill 07 concisely with the base-framework additions plus all prior guardrails. No member-specific SQL, role assignments, or final answers were hard-coded.

## Improvement classification

- Command improvement
- SKILL.md improvement

## Validation commands run

```bash
ls outputs/07-query-design-G08.sql            # confirm not created
git status --short .opencode/commands/07-generate-query-design.md \
                   .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
grep -nE 'Mode A|Mode B|Mode: review-all|BEGIN MEMBER SECTION|END MEMBER SECTION|GO|sqlcmd' \
     .opencode/commands/07-generate-query-design.md
```

## Validation results

- `outputs/07-query-design-G08.sql` is **absent** (correct — generated later, per member).
- Only the command 07 and skill 07 files changed this turn.
- Mode A, Mode B (`Mode: review-all`), BEGIN/END student-ID markers, per-block `GO`, and the `sqlcmd` run guidance are all present in the command.
- No fixed member→role/category assignments; no final SQL answers in the skill.

## Risks / caveats

- Static authoring only; no SQL executed, no output produced.
- Mode B is a review/report mode — it relies on the generating model to actually check the file; it performs no destructive action.
- Guardrails are enforced at generation/review time by the model; a human should still sanity-check generated queries against Output 05/06.
- The framework is intentionally open: future members can extend the command/skill for their own section, so the team should periodically re-run Mode B to confirm overall consistency.

## Git status summary

```
 M .opencode/commands/07-generate-query-design.md
 M .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
?? docs/audits/36-task7-open-base-framework-audit.md
```

## Recommended next steps

1. Each member runs Mode A: `/07-generate-query-design Member: <name> (<id>); Target users: <roles>; Query types: <5 distinct categories>`.
2. Once all four sections exist, run Mode B: `/07-generate-query-design Mode: review-all`, then `bash scripts/validate_sql.sh --final G08`, and finally execute `05` → `06` → `07` on a SQL Server instance to confirm the whole file runs.
