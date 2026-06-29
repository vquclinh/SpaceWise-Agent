# Audit — Task 7 Final Polish + Query-Pattern Learning Mechanism

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 7 — Query Design (command + skill + pattern notes only)

## Task goal

Final Task 07 framework polish before running `/07-generate-query-design`: add a lightweight, evolving query-pattern learning file, wire the command to consult it, use canonical role names, clarify output-vs-audit scope, soften the sample-data rows rule, and fix future-member wording. Keep the skill concise; hard-code no final SQL. Do not generate `outputs/07-query-design-G08.sql`.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `.opencode/skills/db-design-pipeline/07-query-design/QUERY_PATTERNS.md` | Created | Compact, evolving query-pattern guardrails (no final SQL). Seeded with 7 notes: interval overlap, completed-session/utilization duration, right-now/`GETDATE()`, anti-join/`NOT EXISTS` with nullables, no unexplained magic identity IDs, intentional zero-row queries, SQL Server CTE `;WITH` safety. Each note uses the Applies-to / Common pitfall / Guardrail / Review-check format. |
| `.opencode/commands/07-generate-query-design.md` | Edited | Reads `QUERY_PATTERNS.md` in Mode A (apply only relevant notes; not as final SQL) and self-reviews against it; Mode B reviews the file against relevant notes and reports **reusable → add a pattern note** vs **one-off → output-only fix**. Canonical role names + example (`Target users: Facility Staff, Facility Manager`). Output-vs-audit scope reworded ("Deliverable edit: create/update only `outputs/07-…sql`; also create the required audit in `docs/audits/`"). Sample-data rows rule softened (intentional zero-row queries must carry a short comment). Future-member wording softened (reuse as-is; extend only for a recurring issue). |
| `.opencode/skills/db-design-pipeline/07-query-design/SKILL.md` | Edited | Softened future-member wording; added one compact bullet to consult `QUERY_PATTERNS.md` and add short notes for reusable issues (never a full query). Stayed concise. |
| `docs/audits/38-task7-query-patterns-and-polish-audit.md` | Created | This audit. |

**Not done:** `outputs/07-query-design-G08.sql` was NOT generated. No Outputs 01–06, schema, or data changed. All prior behavior retained (Mode A/B, student-ID section key, BEGIN/END markers, role-based suggestions, distinct types, `GO`, `DECLARE`, no `SELECT *`, read-only, 05 authority / 06 reference, preserve other sections).

## Improvement classification

- Command improvement
- SKILL.md improvement
- Documentation improvement (new pattern-notes file)

## Validation commands run

```bash
ls outputs/07-query-design-G08.sql            # confirm not created
git status --short .opencode/commands/07-generate-query-design.md \
                   .opencode/skills/db-design-pipeline/07-query-design/
grep -cE 'SELECT .* FROM|CREATE TABLE|INSERT INTO' .../07-query-design/QUERY_PATTERNS.md
grep -cE 'QUERY_PATTERNS' .../commands/07-generate-query-design.md
grep -nE 'facility staff, manager|department admin' .../commands/07-generate-query-design.md
```

## Validation results

- `outputs/07-query-design-G08.sql` is **absent** (correct).
- Changed/created this turn: command 07, skill 07, and the new `QUERY_PATTERNS.md` (only).
- `QUERY_PATTERNS.md` contains **no final SQL** (0 `SELECT … FROM` / `CREATE TABLE` / `INSERT INTO` lines).
- Command references `QUERY_PATTERNS` in 4 places (read, self-review, Mode B, and via guidance).
- No loose role terms (`facility staff, manager` / `department admin`) remain — canonical names used.

## Risks / caveats

- Static authoring only; no SQL executed, no output produced.
- The pattern notes are guidance the generating/reviewing model must actually apply; they reduce, not eliminate, recurring mistakes.
- `QUERY_PATTERNS.md` should stay note-only — reviewers must resist pasting full corrected queries into it.

## Git status summary

```
 M .opencode/commands/07-generate-query-design.md
 M .opencode/skills/db-design-pipeline/07-query-design/SKILL.md
?? .opencode/skills/db-design-pipeline/07-query-design/QUERY_PATTERNS.md
?? docs/audits/38-task7-query-patterns-and-polish-audit.md
```

## Recommended next steps

1. Run Mode A per member (canonical roles); the command will consult `QUERY_PATTERNS.md` and self-review against it, then write a generation audit.
2. After all four sections exist, run `Mode: review-all` (which also checks against the pattern notes and flags reusable vs one-off issues), then `bash scripts/validate_sql.sh --final G08`, and execute `05` → `06` → `07` on a SQL Server instance.
3. As reviews surface reusable query mistakes, append short notes to `QUERY_PATTERNS.md` (never full queries).
