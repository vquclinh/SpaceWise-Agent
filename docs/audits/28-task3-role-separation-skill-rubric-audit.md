# Audit — Task 3 Role Separation and Skill Rubric Refactor

> Date: 2026-06-28
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 3 — Logical Database Design

## Task goal

Refactor ONLY Task 03 so the command and the task-specific skill have correct, separated roles:

- **Command 03** = execution entrypoint (which skill, which sources, single output, safety, self-review, audit) — not the schema answer.
- **Skill 03** = an evolving logical-design **quality rubric**, not a hard-coded schema answer.

No regeneration or modification of `outputs/03-logical-design-G08.md` (or any `outputs/` file) was performed. Reference: official PDF Step 3 — convert the ERD into a relational schema with relations, attributes, primary keys, foreign keys, **candidate keys**, and key constraints.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `.opencode/commands/03-generate-logical-design.md` | Edited | Stated entrypoint role; added a 7-point Self-Review (PDF Step 3 satisfied; Output 02 → relations; PK/FK/**candidate keys**/key constraints explicit; every relationship → FK/junction; enforcement traceable to Output 01; logical design not executable DDL; Mermaid labels readable). Kept inputs, single-output rule, safety, and audit policy. |
| `.opencode/skills/db-design-pipeline/03-logical-design/SKILL.md` | Rewritten | Converted from a hard-coded schema answer into a reusable rubric with 13 sections (Purpose; Required inputs; Required output structure; ERD-to-relational mapping; Key rules; Constraint rules; SQL Server-oriented guidance; Logical schema diagram rules; Business-rule enforcement strategy; Index recommendation rules; Normalization/justification; Validation checklist; Common mistakes). |
| `docs/audits/28-task3-role-separation-skill-rubric-audit.md` | Created | This audit. |

No `outputs/` file was modified. No Step 1/2 or Step 4–7 files were modified by this task. (`AGENTS.md` and the shared `SKILL.md` were read only.)

## What was evaluated

- The official `CS486_Project.pdf` Step 3 requirement (relations, attributes, PK, FK, candidate keys, key constraints).
- `AGENTS.md` (source-of-truth order, Step Precedence, Relationship Labeling rule for Step 3, SQL Server rules) and the shared pipeline skill.
- Upstream outputs `01` and `02` (to ensure the rubric derives from Output 02 and traces rules to Output 01) and the current `outputs/03-logical-design-G08.md` (read only, for context).
- The previous command 03 and skill 03 for role clarity.

## Issues found

1. **Skill 03 hard-coded the final answer.** The previous skill embedded the complete schema: a fixed 9-table list, full table-by-table column definitions (with `INT IDENTITY(1,1)`, `NVARCHAR(...)`, etc.), the full logical Mermaid relationship block, and complete SQL trigger/query bodies (`RAISERROR`, overlap-check `IF EXISTS`). That makes the skill a copy-the-answer template rather than an evolving rubric, and it conflicts with deriving the schema from Output 02.
2. **Command 03 lacked a self-review.** It was a clean entrypoint but did not require checking the output against the PDF Step 3 items (especially candidate keys) or the logical-vs-DDL boundary.
3. **Candidate keys were only implicit.** Both the PDF wording and prior reviews call out candidate keys; the old skill captured them only as UNIQUE constraints, never as an explicit "candidate / alternate keys" requirement.
4. **Logical-vs-physical boundary blurred.** The old skill presented executable DDL-level detail (IDENTITY seeds, full CREATE-style columns, trigger bodies) inside Step 3, which the PDF reserves for Step 5 (Database Implementation).

## Changes made

### Command 03 (entrypoint)
- Declared it an execution entrypoint that does not contain the schema answer.
- Added the 7-point **Self-Review** block listed above; kept "derive from Output 02, use Output 01 for traceability," single-output rule, safety constraints, and the `docs/audits/` audit requirement.

### Skill 03 (rubric)
- **Removed:** the fixed table list as the required answer; full fixed table-by-table column definitions; the full fixed Mermaid relationship block; hard-coded SQL trigger/query bodies; and any wording forcing the output to copy the current schema rather than derive it.
- **Added/kept as general rules:** ERD-to-relational mapping rules (entities→tables, attributes→columns, relationships→FK/junction, distinct-role→distinct FK columns, preserve existing junctions); explicit **candidate/alternate key** requirement (named, not just UNIQUE; natural identifiers; label inferred vs. team-confirmed); constraint classification (Explicit / Inferred / Team convention / Deferred); **capacity validation kept inferred/open** unless the team decides; SQL Server-oriented guidance that **forbids full CREATE TABLE and trigger code in Step 3** (deferred to Step 5); logical-diagram rules requiring **FK column names as relationship labels** plus a readability workaround; conceptual business-rule enforcement *options* (overlap needs cross-row logic; unavailable-space needs status check) **without** hard-coding a trigger; index justification; normalization notes; a full validation checklist and common-mistakes list.
- Tiny notation-only snippets are used to illustrate format, never to provide the project answer.

### G05-style comparison (applied conceptually)
- Kept G08's stronger source-of-truth, audit, and safety workflow.
- Kept SQL Server orientation (G08 targets SQL Server).
- Did **not** adopt G05 behaviours that update extra docs (`docs/schema-registry.md`, `docs/entity-registry.md`) — this repo does not require them.
- Adopted the good idea that the skill should **guide mapping and validation rather than paste the final schema**.

## Improvement classification

- Command improvement
- SKILL.md improvement
- Documentation improvement

## Validation commands run

```bash
git status --short
git diff --stat -- .opencode/commands/03-generate-logical-design.md .opencode/skills/db-design-pipeline/03-logical-design/SKILL.md
git diff -- .opencode/commands/03-generate-logical-design.md
grep -c "IDENTITY(1,1)\|RAISERROR\|INT IDENTITY" .opencode/skills/db-design-pipeline/03-logical-design/SKILL.md
git status --short outputs/03-logical-design-G08.md
```

## Validation results

- `git diff --stat`: 2 files changed (command +28, skill rewritten ~+126), no other source files touched by this task.
- Hard-coded answer patterns now **absent** from skill 03: `IDENTITY(1,1)` = 0, `INT IDENTITY` = 0, `RAISERROR` = 0, the full fixed Mermaid relationship line = 0. The only `CREATE TABLE` occurrences (2) are **guidance forbidding** executable DDL in Step 3 — not schema content.
- `outputs/03-logical-design-G08.md` is **unmodified** (not in the modified set); no `/03-generate-logical-design` run was performed.
- Command 03 now contains the 7-point self-review and explicit candidate-key wording.

## Risks / caveats

- **Pre-existing working-tree changes are unrelated to this task.** `git status` shows `outputs/01-business-req-analysis-G08.md` and the 01/02 command/skill files as modified — those are carryover from earlier Task-1/Task-2 sessions (audits 24–27), not from this Task-03 refactor. This task changed only the two Task-03 files (+ this audit).
- **Existing Output 03 was generated under the old hard-coded skill.** It is left untouched per instructions. If the team re-runs `/03-generate-logical-design` under the new rubric, the output should be re-reviewed — in particular, confirm **candidate keys are now explicitly listed** (the prior output relied on UNIQUE constraints) and that no full DDL crept in.
- The rubric intentionally leaves design decisions (e.g. capacity enforcement) open; the team must resolve them in Step 4 rather than letting the skill force them.
- Commands were not executed; this was a documentation/role-separation refactor only.

## Git status summary

```
 M .opencode/commands/03-generate-logical-design.md      <- this task
 M .opencode/skills/db-design-pipeline/03-logical-design/SKILL.md   <- this task
 M .opencode/commands/01-generate-business-req.md         (carryover, untouched here)
 M .opencode/commands/02-generate-erd-design.md           (carryover, untouched here)
 M .opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md  (carryover)
 M .opencode/skills/db-design-pipeline/02-erd-design/SKILL.md             (carryover)
 M outputs/01-business-req-analysis-G08.md                (carryover, NOT this task)
?? docs/audits/24-…, 25-…, 26-…, 27-… (prior tasks)
?? docs/audits/28-task3-role-separation-skill-rubric-audit.md (this audit)
```

`outputs/03-logical-design-G08.md` is NOT in the list — confirmed untouched.

## Recommended next steps

1. When ready, re-run `/03-generate-logical-design` under the new rubric and **review the regenerated Output 03** against the command's 7-point self-review — especially that **candidate keys are explicitly listed** and the document stays logical (no executable DDL).
2. Carry the still-open capacity question into Step 4 (Design Validation) for an explicit decision before it becomes a constraint.
3. If a systemic gap surfaces during that review, improve skill 03 (the rubric) and audit again — the intended generate → review → improve-skill → re-run → audit loop.
