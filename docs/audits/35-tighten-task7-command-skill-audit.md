# Audit — Tighten Task 7 Command + Skill (guardrails before generation)

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 7 — Query Design (command + skill only)

## Task goal

Add small guardrails to the Step 7 command and skill before running `/07-generate-query-design`, without making the skill long or hard-coding final SQL. Do not generate `outputs/07-query-design-G08.sql`.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `.opencode/commands/07-generate-query-design.md` | Edited | (1) "≥5 **distinct** query types"; rejects/asks when types are missing, <5, or duplicated. (2) Each query's `Query type` must map to a declared type. (3) Safe section update: replace this member's own section in place (no duplicate); never renumber/rewrite/delete other members' sections. (4) Read-only precision: `SELECT`/CTE/`DECLARE` allowed; no INSERT/UPDATE/DELETE/MERGE/DROP/ALTER/CREATE/TRUNCATE. (5) No `SELECT *`; meaningful columns/aliases. (6) Minimum variety (≥1 JOIN, ≥1 aggregation, ≥1 status/lifecycle, ≥1 date/ordering). (7) Output 05 is schema authority; 01–04 context only. (8) Audit must record member name, ID, query-type plan, created-or-updated, and other-sections-preserved. Self-review updated. |
| `.opencode/skills/db-design-pipeline/07-query-design/SKILL.md` | Edited | Mirrored the same guardrails as compact bullets in Rules + checklist (distinct types, read-only precision, no `SELECT *`, source-of-truth, variety, section safety). Kept it short; no SQL pasted. |
| `docs/audits/35-tighten-task7-command-skill-audit.md` | Created | This audit. |

**Not done:** `outputs/07-query-design-G08.sql` was NOT generated. No Outputs 01–06, schema, or data changed.

## What was evaluated

The reusable Task 07 command/skill (from audit 34) against likely Step 7 mistakes: duplicate query types, `SELECT *`, accidental data-changing statements, columns not in the schema, weak/repetitive queries, and unsafe section overwrites.

## Changes made

Added the eight guardrails above to the command and mirrored the essential ones into the skill as concise bullets and checklist items. No final query SQL was added to either file; the skill remains a rubric.

## Improvement classification

- Command improvement
- SKILL.md improvement

## Validation commands run

```bash
ls outputs/07-query-design-G08.sql            # confirm not created
git status --short .opencode/commands/07-generate-query-design.md \
                   .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
grep -nE 'SELECT [A-Za-z]' .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
grep -ciE 'distinct' <the two 07 files>
```

## Validation results

- `outputs/07-query-design-G08.sql` is **absent** (correct — generated later, per member).
- Only the command 07 and skill 07 files changed this turn.
- The skill contains **no concrete SQL answer** — only the placeholder `SELECT ... ;` template and the word "SELECT" in prose; no real query was hard-coded.
- "distinct" guardrail present in both files.

## Risks / caveats

- Static authoring only; no SQL executed, no output produced.
- These are guardrails, not a guarantee: the generating model must still honor them — the command's self-review and the skill checklist exist to catch violations at generation time.
- "No `SELECT *`" and the variety minimums are quality rules; the human reviewer should still sanity-check the generated queries against Output 05/06.

## Git status summary

```
 M .opencode/commands/07-generate-query-design.md
 M .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
?? docs/audits/35-tighten-task7-command-skill-audit.md
```

## Recommended next steps

1. Run `/07-generate-query-design Member: <name> (<id>); Query types: <5 distinct categories>` in OpenCode to generate the member's section; it will write its own generation audit (member, ID, plan, created/updated, other sections preserved).
2. After all four members' sections exist, review the merged `07` file (distinct types, no `SELECT *`, variety) and run `bash scripts/validate_sql.sh --final G08`.
