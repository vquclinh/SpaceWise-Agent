# Audit — Task 01 Skill: Add Bidirectional Relationship Requirement and Check-In Business Rule

> Date: 2026-07-01
> Operator/member: AI (OpenCode)
> Tool: OpenCode edit
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: /evaluate-task (for evaluation), then manual edits based on findings

## Task goal

Read the evaluation report for Task 01 (business requirement analysis), identify specific issues found, and update the task generation skill (`.opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md`) to prevent those issues from recurring in future generations. Then create an audit documenting the change.

## Files created / changed

- **Changed:** `.opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md`
- **Created:** `docs/audits/45-task01-skill-add-bi-directional-relationships-and-checkin-rule-audit.md`

## What was evaluated

The evaluation report `docs/evaluations/task-01-evaluation.md` (score: 4.8/5) identified two minor issues in the Task 01 output:

1. **Issue A — Relationship cardinality gap in §4:** The relationship between BookingDecision and the deciding User (staff role) was implicit in the entity descriptions but not explicitly stated in the Identified Relationships section.
2. **Issue B — Missing explicit business rule:** "Who checked in" was captured by the Usage Session ↔ User entity link but not called out as a standalone business rule in §5 (now §6).

## Issues found

| # | Issue | Severity | Root cause in SKILL.md |
|---|---|---|---|
| 1 | §4 listed "UserAccount makes BookingDecision: 1-N" but the output did not state the inverse direction ("A Booking Decision is made by one User…"). The SKILL.md did not require bidirectional statements for each relationship. | Minor — downstream tasks (ERD) could miss the decision → user link if the analysis is vague. | §4 listed relationships as single-directional phrases, allowing the agent to output only one direction. |
| 2 | §6 (Business Rules) did not include "Check-in records who checked in" as an explicit mandatory rule. The process section (§5C) described it, but the business rules section had no requirement to restate it as a standalone rule. | Minor — could be lost when translating to logical design. | §6 did not enumerate which additional business rules beyond the two critical ones must be included. |

## Changes made

### Change 1 — §4 Identified Relationships: Bidirectional requirement

**Before:** Each relationship was listed as a single-directional phrase (e.g., "UserAccount makes BookingDecision: 1-N").

**After:** Added an introductory instruction: *"Each relationship must be stated bidirectionally — both directions (parent-to-child and child-to-parent) must be explicitly described, not just one side."* All relationship entries were rewritten to show both directions explicitly (e.g., "UserAccount ↔ BookingDecision: 1:N (a User acting as staff makes many Booking Decisions; each Booking Decision is made by one User)").

### Change 2 — §6 Business Rules: Additional mandatory business rules enumerated

**Before:** §6 only required the two critical rules verbatim and a generic "document additional business rules" instruction.

**After:** Added five explicitly numbered additional business rules that must be stated, including:
- Rule 3: Booking Lifecycle (Pending → Approved/Rejected → Checked In → Completed/No-show)
- Rule 4: Approval Documentation / Decision Audit Trail
- Rule 5: **Check-in Tracking** (actual start time, who checked it in, initial condition)
- Rule 6: Check-out / Completion Tracking
- Rule 7: Data Preservation

### Change 3 — Validation Checklist: New verification items

Added three new checklist items:
- "UserAccount makes BookingDecision relationship is documented, **stated bidirectionally**"
- "Every relationship in §4 is stated **bidirectionally**"
- "Check-in tracking is documented as an explicit business rule in §6"

## Improvement classification

SKILL.md improvement — added explicit bidirectional relationship requirement and explicit check-in business rule to prevent the two identified gaps.

## Validation commands run

None — this is a documentation/skill change only (no code or SQL affected).

## Validation results

N/A — no executable outputs were modified.

## Risks / caveats

- Bidirectional requirement may make §4 slightly longer, but this is a worthwhile trade-off for clarity.
- The five additional business rules are the minimum explicit set; agents should still document other rules as supported by the source requirement.
- These changes only affect future generations of Task 01 output; existing outputs (like the current `01-business-req-analysis-G08.md`) are not retroactively modified.

## Git status summary

Changed: `.opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md`
New: `docs/audits/45-task01-skill-add-bi-directional-relationships-and-checkin-rule-audit.md`

## Recommended next steps

1. Run `/evaluate-task Task: 01` on a fresh generation to verify the skill updates prevent the two gaps.
2. Consider whether similar bidirectional requirements should be added to the downstream skill files (02-erd-design, 03-logical-design) as a consistency improvement.
