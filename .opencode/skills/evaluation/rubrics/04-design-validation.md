# Rubric: 04-design-validation-G<Group#>.md

Specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions)
— do not repeat those here.

## Source of truth
This task is itself an evaluation — the group is validating `03-logical-design-G<Group#>.md`
against `02-erd-design-G<Group#>.md` and the business rules captured in
`01-business-req-analysis-G<Group#>.md` / the PDF. So grading this output is meta:
you are checking whether the group's own validation is thorough and honest, not just
whether the schema is good (that was already graded in task 3's rubric). A validation
document that rubber-stamps everything as correct without finding any real issues should
be treated with suspicion, not rewarded — re-check the schema yourself and compare.

## Criteria

### 1. ERD-to-schema traceability check (weight: high)
Does the validation walk through each entity and relationship from the ERD and confirm
(or deny) it is correctly represented in the schema? A spot-check or partial walkthrough
should be penalized — this needs to be systematic (e.g. a table mapping each ERD element
to its schema counterpart), not a paragraph of general impressions.

### 2. Key correctness check (weight: high)
Does the validation explicitly verify:
- Every relation has a primary key.
- Every relationship from the ERD has a corresponding, correctly-placed foreign key.
- Candidate keys are identified where applicable.
- The User-role disambiguation problem (separate FKs for requester/decider/check-in/
  completer on Booking, reporter/assignee on Maintenance Record) is specifically checked,
  not glossed over — this is the highest-risk area inherited from tasks 2–3.

### 3. Normalization check (weight: high)
Does the validation re-verify normal form (at least 3NF) independently, rather than just
asserting "the schema is in 3NF" without showing the reasoning (e.g. checking for
repeating groups, partial dependencies, transitive dependencies)? Accept either a formal
functional-dependency analysis or a clear informal walkthrough per relation — but it must
show work, not just conclude.

### 4. Business rule coverage check (weight: high)
For each business rule listed in task 1 (no overlapping approved bookings, no booking on
unavailable spaces, rejection reason required, check-in/completion fields, etc.), does the
validation state explicitly:
- whether the rule is enforceable via schema constraints alone (PK/FK/UNIQUE/CHECK),
- whether it requires a trigger or application-level logic instead, and
- where in the schema (which table/column) that enforcement will attach.

A rule with no enforcement mechanism identified at all should be flagged as a finding in
the validation, not silently passed over. If the group's validation does this, that's a strong
positive signal; if it doesn't, deduct here regardless of whether the underlying schema is
actually fine.

### 5. Issues found vs. issues that exist (weight: high — this is the integrity check)
Independently re-examine the task 3 schema yourself (the grader) against the ERD and
business rules. Compare your own findings to what the group's validation document
reports:
- If the group found real issues and proposed fixes: full credit, regardless of how many
  issues existed — a thorough validation that surfaces problems is the goal of this task.
- If the schema actually has issues but the validation reports "no issues found" or only
  cosmetic ones: significant deduction — this is the core failure mode for task 4 and
  should be flagged as a blocker-severity issue in your eval output, since it means the
  group will carry schema bugs into SQL implementation undetected.
- If the schema is genuinely clean and the validation correctly reports no major issues
  with clear supporting evidence: full credit — don't penalize for "not finding problems"
  when there genuinely aren't any, only penalize for not looking carefully.

### 6. Proposed fixes / revisions (weight: medium)
Where issues are found, does the validation propose a concrete fix (revised FK placement,
added constraint, additional table, etc.) rather than just naming the problem? Check
whether the group then actually applied the fix in `03-logical-design` (if revisions were
made in place) or documents it as a known limitation carried into task 5 — either is
acceptable as long as it's explicit, but silently fixing without noting it in this document is
a documentation gap.

### 7. Documentation quality (weight: low)
Clear structure (e.g. one section per check category above), readable by someone who
hasn't seen tasks 1–3, supports the "design validation" section of the group report.

## Scoring guidance for this task
- Criterion 5 (issues found vs. issues that exist) is the single most important check —
  weight it ~30% on its own, since it's the only criterion that catches a validation that
  technically "covers all the checklist items" but does so superficially.
- Key correctness (2), normalization (3), and business rule coverage (4) ~45% combined —
  these are the substantive technical checks the task exists to perform.
- ERD traceability (1) and proposed fixes (6) ~20% combined.
- Documentation quality (7) ~5%.

## Common failure patterns to watch for
- A validation document that just re-describes the schema (restating tables/columns)
  without actually comparing it against anything — this produces no findings because it
  never checks for mismatches in the first place.
- "No issues found" as the conclusion for every section, especially when task 3 is known
  (from your own check) to have the User-role FK ambiguity or a missing candidate key.
- Business rule coverage section that lists the rules but doesn't map each one to a
  specific enforcement mechanism or table/column.
- Treating this task as a second copy of task 3's documentation rather than a critique of it.