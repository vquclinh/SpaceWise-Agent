# SKILL: Evaluate Project Output (Common)

Used by the eval command for every one of the 7 task outputs. This file defines what is
shared across all evaluations. For task-specific checks, load the matching rubric file from
`.opencode/skills/evaluation/rubrics/0X-*.md` alongside this one — both apply together, this file does not replace them.

## How to use this skill
For each output file being graded:
1. Load this common skill.
2. Load the matching task-specific rubric (`.opencode/skills/evaluation/rubrics/0X-*.md`).
3. Load the original requirement document (CS486_Project.pdf) and any prior task
   outputs the current one depends on (see "Dependency chain" below).
4. Evaluate using the dimensions below + the task-specific criteria.
5. Emit one result block in the standard format (see "Output format").

## Dependency chain
Later tasks must stay consistent with earlier ones — flag drift, not just absolute quality:
1. business-req-analysis — source: requirement PDF only
2. erd-design — must trace to (1)
3. logical-design — must trace to (2)
4. design-validation — must check (3) against (2) and the business rules from (1)
5. db-definition (SQL DDL) — must implement (3) faithfully
6. sample-data — must respect constraints defined in (5), and exercise both normal and
   exceptional cases mentioned in the requirement (e.g. rejected bookings, overlapping
   attempts, maintenance blocking a booking, no-show)
7. query-design — must run validly against (5)+(6), and answer real business questions
   from the requirement

When grading task N, always re-check it against task N-1's actual content, not against
what task N-1 *should* have said. If task N-1 itself had an error, don't penalize task N
for faithfully propagating it — note it as an inherited issue and trace it back instead.

## Scoring scale
Use a 0–5 scale per criterion, and an overall 0–5 per task:

- **5 — Excellent**: fully correct, complete, well-justified, nothing to add.
- **4 — Good**: correct and complete, minor polish issues only (wording, formatting).
- **3 — Adequate**: meets the requirement but has a gap, omission, or unclear point that
  a reader would need to ask about.
- **2 — Weak**: significant gaps or errors; usable but needs rework before downstream
  tasks can rely on it.
- **1 — Poor**: mostly missing, incorrect, or not usable as-is.
- **0 — Absent**: criterion not addressed at all.

Overall task score = weighted average of criteria per that task's rubric (weights are
specified in each rubric file). Round to one decimal.

## General dimensions (apply to every task, in addition to task-specific criteria)

### Completeness vs. source
Does the output cover everything the original requirement (or prior task) asks for, with
nothing silently dropped?

### Internal consistency
Do names, types, and constraints match across this output and the ones it depends on?
(e.g. a column named `status` in logical design must match the ERD attribute it derives
from, and its allowed values must match the business rules.)

### Correctness
For SQL outputs: does it parse/run, are types and constraints right. For design docs: are
the modeling choices (keys, cardinalities, normalization) defensible.

### Clarity
Could someone unfamiliar with the project follow the document/file without needing to
ask clarifying questions?

### Justification
Where a non-obvious choice is made (e.g. a weak entity, a many-to-many resolved into a
junction table, a denormalization), is there a brief rationale?

## Output format
For each task, emit:

```
## Task <N>: <task name>
Overall score: X.X / 5

| Criterion | Score | Notes |
|---|---|---|
| <criterion 1> | X | ... |
| <criterion 2> | X | ... |
...

Strengths:
- ...

Issues found:
- [severity: blocker|major|minor] ...

Inherited issues from earlier tasks (if any):
- ...

Suggested fixes:
- ...
```

After all 7 tasks are scored, emit a final summary:

```
## Overall Summary
| Task | Score |
|---|---|
| 1. business-req-analysis | X.X |
| 2. erd-design | X.X |
| 3. logical-design | X.X |
| 4. design-validation | X.X |
| 5. db-definition | X.X |
| 6. sample-data | X.X |
| 7. query-design | X.X |
| **Average** | **X.X** |

Cross-task consistency issues:
- ...

Top 3 priorities to fix before submission:
1. ...
2. ...
3. ...
```

This final summary is what should feed the "agent improvement process" section of the
group report — each round of evaluation + fixes should be logged as one iteration.

## Severity definitions (use consistently across all tasks)
- **blocker**: would cause a downstream task to fail or a grader to consider the
  requirement unmet (e.g. missing primary key, SQL that doesn't run, overlapping-booking
  rule not enforced anywhere).
- **major**: meaningfully reduces correctness or completeness but doesn't break
  downstream work (e.g. a missing attribute that's easy to add later).
- **minor**: polish, naming, formatting, or style issues.

## What this skill does NOT cover
Task-specific pass/fail criteria, required entities/columns/queries, and weighting between
criteria — all of that lives in the per-task rubric files. Do not duplicate it here; if a
common pattern starts appearing in multiple rubric files, that's a signal to promote it
into this file instead.