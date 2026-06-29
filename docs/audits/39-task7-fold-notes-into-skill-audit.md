# Audit — Task 7: Fold Query Notes into Skill (no separate pattern/catalog file)

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 7 — Query Design (command + skill only)

## Task goal

Adapt the other team's Task 07 approach to G08's decision: **no separate `QUERY_PATTERNS.md`**. Keep role-based query distribution suggestions in the command and put compact query-pattern/category notes in the skill. Members must still pass their 5 distinct query types explicitly; the command must not silently choose them. Do not generate `outputs/07-query-design-G08.sql`.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `.opencode/skills/db-design-pipeline/07-query-design/QUERY_PATTERNS.md` | **Deleted** | Removed the separate pattern file created in the prior turn, per the G08 "no separate file" decision (it was untracked/uncommitted). |
| `.opencode/skills/db-design-pipeline/07-query-design/SKILL.md` | Edited | Removed the `QUERY_PATTERNS.md` bullet; added a compact **"Query category notes"** section (availability/overlap, current-state `GETDATE()`, maintenance monitoring, utilization/duration, audit/decision trail, no-show/lifecycle, facility matching, anti-join `NOT EXISTS`, parameterized `DECLARE` filters, intentional zero-row checks, SQL Server `;WITH` CTE safety). No final SQL. Kept all core rules + checklist concise. |
| `.opencode/commands/07-generate-query-design.md` | Edited | Replaced all `QUERY_PATTERNS.md` references with "apply the skill's **Query category notes**" (read-inputs, self-review, Mode B consistency check, and reusable-vs-one-off reporting). Renamed the suggestions heading to **"Role-based query distribution suggestions"** with the requested intro wording. |
| `docs/audits/39-task7-fold-notes-into-skill-audit.md` | Created | This audit. |

**Not done:** `outputs/07-query-design-G08.sql` was NOT generated. No `QUERY_PATTERNS.md`/`QUERY_CATALOG.md` exists. No Outputs 01–06, schema, or data changed. All prior behavior retained (Mode A/B, student-ID section key, BEGIN/END markers, ≥5 distinct types, per-query format + `GO`, `DECLARE`, no `SELECT *`, read-only, 05 authority / 06 reference, preserve other sections, full-file run guidance).

## What was evaluated

The Task 07 command/skill after the prior turn introduced a separate `QUERY_PATTERNS.md`, against G08's decision to keep suggestions in the command and notes in the skill, with explicit member-supplied query types.

## Changes made

Deleted the separate notes file; moved its guardrails into the skill as a compact "Query category notes" section; re-pointed every command reference to that section; renamed/clarified the role-based distribution suggestions. The command still **requires** the member's 5 distinct query types and refuses to silently choose them (suggest-and-confirm when missing/<5/duplicated).

## Improvement classification

- Command improvement
- SKILL.md improvement

## Validation commands run

```bash
ls outputs/07-query-design-G08.sql            # confirm not created
ls .opencode/skills/db-design-pipeline/07-query-design/
find . -name 'QUERY_PATTERNS.md' -o -name 'QUERY_CATALOG.md'   # excl .git
grep -rnE 'QUERY_PATTERNS|QUERY_CATALOG' <command 07> <skill 07>
grep -cE 'Query category notes' <skill 07>
grep -cE 'SELECT .* FROM|CREATE TABLE|INSERT INTO' <skill 07>
git status --short .opencode/commands/07-generate-query-design.md .opencode/skills/db-design-pipeline/07-query-design/
```

## Validation results

- `outputs/07-query-design-G08.sql` is **absent** (correct).
- The `07-query-design/` folder now contains only `SKILL.md`; **no** `QUERY_PATTERNS.md`/`QUERY_CATALOG.md` anywhere.
- **No** `QUERY_PATTERNS`/`QUERY_CATALOG` references remain in the command or skill.
- Skill has the "Query category notes" section and **0** final-SQL lines.
- Changed this turn: command 07 + skill 07 (the deleted file was untracked, so it does not appear as a git deletion).

## Risks / caveats

- Static authoring only; no SQL executed, no output produced.
- The category notes are guidance the generating/reviewing model must apply; they reduce, not eliminate, recurring mistakes.
- The skill grew by one notes section but remains a compact rubric (no full queries).

## Git status summary

```
 M .opencode/commands/07-generate-query-design.md
 M .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
?? docs/audits/39-task7-fold-notes-into-skill-audit.md
```

(The prior turn's untracked `QUERY_PATTERNS.md` was deleted and therefore does not appear here.)

## Recommended next steps

1. Run Mode A per member with explicit args: `/07-generate-query-design Member: <name> (<id>); Target users: <canonical roles>; Query types: <5 distinct>` — the command consults the skill's Query category notes and self-reviews against them.
2. After all four sections exist, run `Mode: review-all`, then `bash scripts/validate_sql.sh --final G08`, and execute `05` → `06` → `07` on a SQL Server instance.
