# Audit — Task 1 Role Separation and Quality Fix

> Date: 2026-06-28
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 1 — Business Requirement Analysis

## Task goal

Refactor and polish Task 1 so that the command, task-specific skill, and output each serve the correct role. The command file should be a concise execution entrypoint. The skill file should be a quality rubric and behaviour guide, not a static answer. The output should be a reviewer-ready deliverable satisfying the official Step 1 requirement. No Step 2–7 files were touched.

## Files changed

| File | Action | Description |
|---|---|---|
| `.opencode/commands/01-generate-business-req.md` | Replaced | Added self-review requirement and audit guidance (25 lines) |
| `.opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md` | Replaced | Refactored as quality rubric: softer wording, process sub-sections, rule classification, fixed Visitor ID list (177 lines) |
| `outputs/01-business-req-analysis-G08.md` | Targeted edits | Demoted capacity rule, softened active-account wording, added missing relationships, added classification matrix (111 lines, +3/-3 net) |

No files in `outputs/02-*`, `outputs/03-*`, other command/skill files, `AGENTS.md`, shared `SKILL.md`, `req/`, or scripts were modified.

## What was evaluated

- The three Task 1 files (command, skill, output) were evaluated for role clarity.
- The official business requirement (`req/business-requirement.md`) was cross-referenced to verify which rules are explicit vs. inferred.
- The `AGENTS.md` Home ID vs. Visitor ID rules were reviewed against the skill's Common Mistakes section.
- The shared SKILL.md Step 1 instructions were cross-referenced for consistency.

## Issues found

1. **Command lacked self-review:** The command file was a clean execution entrypoint but did not include a self-review step against the official PDF and skill guidance.
2. **Skill used rigid wording:** Phrases like "Identify exactly these nine entities" and "Must include exactly these six roles" sounded like a fixed template rather than a quality rubric.
3. **Skill missing process sub-sections:** No explicit guidance for Booking Request Lifecycle, Approval Workflow, Usage Session / Check-in & Check-out, or Maintenance Management.
4. **Capacity rule presented as explicit business rule:** The official requirement (`req/business-requirement.md` §15) explicitly lists participant-vs-capacity checking as an open question. Output 01 listed it as a firm rule.
5. **Active-account wording too strong:** The requirement says users have a university account with account_status. Output 01 said "must have an active university account." Active-only is an access-control assumption.
6. **Missing relationships in Output 01:** UserAccount → BookingDecision, UserAccount → UsageSession check-in, and UserAccount → UsageSession completion relationships were documented in the entity attribute list but not in the relationships section.
7. **Common Mistakes section was incomplete:** The skill's "Common Mistakes" listed only a few generic Visitor ID leaks. It did not explicitly list all FORBIDDEN Visitor ID placements per entity.
8. **No rule classification:** Neither the skill nor the output classified rules as Explicit / Inferred / Assumption / Design Convention.

## Changes made

### Command 01
- Added step 4: Self-Review requirement against the official PDF and task skill.
- Added guidance: if a systemic skill weakness is found, record it in the audit as "Recommended skill improvement" — do not silently edit the skill.
- Renumbered safety constraint and audit policy to steps 5 and 6.

### Skill 01

- **Wording softened:** "Exactly these nine entities" → "Cover at least these required conceptual entities when supported by the source requirements." "Must include exactly these six roles" → "Must cover these six roles."
- **Added disclaimer:** "This skill is a quality rubric and behaviour guide, not a fixed answer."
- **Added process-oriented sub-sections:** Booking Request Lifecycle, Approval Workflow, Usage Session / Check-in & Check-out, Maintenance Management.
- **Added rule classification requirement:** Explicit, Inferred, Assumption, Design Convention.
- **Added classification matrix example** showing how to format the traceability table.
- **Fixed Common Mistakes section:** Added exhaustive, per-entity FORBIDDEN Visitor ID list:
  - Do NOT include `department_id` in UserAccount
  - Do NOT include `requester_id` or `space_id` in Booking
  - Do NOT include `booking_id` or `decided_by` in BookingDecision
  - Do NOT include `booking_id`, `checked_in_by`, or `completed_by` in UsageSession
  - Do NOT include `space_id`, `reporter_id`, or `assigned_staff_id` in MaintenanceRecord
  - Do NOT include `space_id` or `facility_id` in SpaceFacility
- **Clarified Home IDs:** Identifiers like `user_id`, `space_id` etc. are conceptual Home IDs, not physical PK declarations.
- **Added validation checklist items:** classification matrix requirement, capacity rule classified as inferred, active-account wording softened.
- **Added "Other mistakes":** capacity as firm rule, active-only as explicit requirement.

### Output 01

- **Demoted capacity rule:** Removed from "Other Key Business Rules" (§5) and added as an open question in §6.
- **Softened active-account wording:** "All system users must have an active university account" → "All system users must have a university account with an `account_status` and be associated with a department. Whether only users with an active account may submit bookings is an access-control assumption to be confirmed during design validation."
- **Added missing relationships:**
  - "User and Booking Decision: A User (staff member) can make many Booking Decisions. Each Booking Decision is made by one User." (1-N)
  - "User and Usage Session: A User (facility staff) can check in many Usage Sessions. A User can complete many Usage Sessions." (1-N, two distinct roles)
  - Maintenance Record relationships clarified as "two distinct roles" for consistency.
- **Added Rule Classification Matrix** in Section 7: an 18-row table classifying all major rules as Explicit / Inferred / Assumption / Design Convention with source references.

## Improvement classification

- Output refinement
- SKILL.md improvement
- Command improvement
- Documentation improvement

## Validation commands run

```bash
git diff --stat -- .opencode/commands/01-generate-business-req.md .opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md outputs/01-business-req-analysis-G08.md
```

Result: 3 files changed, 232 insertions(+), 3 deletions(-).

```bash
git status --short
```

Result: Only the three targeted Task 1 files modified. Outputs 02 and 03 untouched. Other modified files (02, 03 commands/skills) are from prior tasks (audit 24, 25) and not part of this task.

## Validation results

- Output 01 now correctly classifies capacity as an open question (matching `req/business-requirement.md` §15).
- Active-account wording is accurate — users have `account_status`; active-only behaviour is an assumption.
- All three UserAccount-to-child relationships are documented in the relationships section (BookingDecision maker, UsageSession check-in, UsageSession completion).
- The classification matrix provides clear traceability from rules back to the official requirement.
- Skill file includes exhaustive per-entity FORBIDDEN Visitor ID list.
- Command file includes self-review requirement.

## Risks / caveats

- **Commands not yet run.** The command file has been updated but not tested by executing the pipeline.
- **No Step 2–7 files were inspected** for downstream consistency impact of the Output 01 changes. The added relationships (UserAccount making BookingDecision, UserAccount checking in/completing UsageSession) were already present in Output 02 and 03, so no downstream breakage is expected. The demoted capacity rule and softened active-account wording are upward refinements that do not change entity structures.
- **Classification matrix may need expansion.** The matrix covers 18 rules; additional inferred or design-convention rules discovered later should be added.
- **Historical prompt record incomplete.** `prompt.md` does not exist in the repository. The edits were guided by `req/business-requirement.md` and the AGENTS.md rules.

## Git status summary

```
 M .opencode/commands/01-generate-business-req.md
 M .opencode/skills/db-design-pipeline/01-business-req-analysis/SKILL.md
 M outputs/01-business-req-analysis-G08.md
?? docs/audits/24-reconstruct-commands-01-02-03-audit.md (from prior task)
?? docs/audits/25-separate-command-skill-files-01-02-03-audit.md (from prior task)
```

Only the three allowed Task 1 files were modified.

## Recommended next steps

1. Review Output 02 and 03 to confirm the new relationships (UserAccount → BookingDecision, UserAccount → UsageSession) are consistent — they were already present, so no breakage is expected.
2. Optionally run `/01-generate-business-req` to verify the command produces equivalent output.
3. Consider running the downstream pipeline (`/02-generate-erd-design`, `/03-generate-logical-design`) to verify the refined Output 01 does not cause inconsistencies in later steps.
4. Apply a similar role-separation and quality-fix pass to Steps 2 and 3 if needed.