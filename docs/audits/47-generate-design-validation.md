# Audit — Generate Design Validation (Output 04)

> Date: 2026-07-01
> Operator/member: Vi
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: `/04-generate-design-validation`

## Task goal

Generate `outputs/04-design-validation-G08.md` by validating the logical schema (Output 03) against the conceptual ERD (Output 02) and business rules (Output 01), following the skill defined in `.opencode/skills/db-design-pipeline/04-design-validation/SKILL.md`.

## Files created / changed

- Created: `outputs/04-design-validation-G08.md`
- Created: `docs/audits/46-generate-design-validation.md`

## What was evaluated

- All 9 conceptual entities map to physical tables (ERD → Relational mapping)
- All 14 Crow's Foot relationships materialize as FK columns
- All 20 business rules from Output 01 are addressed with enforcement mechanisms
- Normalization (1NF, 2NF, 3NF) compliance
- Overlap conflict prevention strategy matches Output 05 DDL (gated AFTER INSERT, UPDATE trigger)
- Status-based booking prevention via cross-reference to `spaces.current_status`
- Referential integrity (13 FKs, UNIQUE constraints, NO ACTION deletions)
- Design issues identified and resolved

## Issues found

- Output 03's Section 7 describes the trigger strategy as `AFTER INSERT, UPDATE` — confirmed to match Output 05's `TR_bookings_PreventOverlapAndUnavailable`
- Usage session completion constraint (`CK_usage_sessions_completion`) only pairs `completed_by` and `actual_end_time`; `final_condition` and `usage_notes` may remain NULL after completion
- Capacity enforcement remains an open question (no hard constraint between `expected_participants` and `capacity`)

## Changes made

Created the full design validation document with 7 sections matching the skill rubric:
1. ERD to Relational Schema Verification — verified 9/9 entities, 14/14 FK mappings
2. Business Rules Addressed — 20 rules each with enforcement mechanism
3. Normalization Check — confirmed 3NF compliance
4. Overlap Conflict Prevention Logic — documented gated AFTER INSERT, UPDATE trigger strategy matching Output 05
5. Status-Based Booking Prevention Validation — cross-reference flow + edge cases
6. Referential Integrity Validation — 13 FKs, UNIQUE on usage_sessions.booking_id, deletion restriction
7. Identified Design Issues & Resolutions — 6 issues logged

## Improvement classification

- Output refinement

## Validation commands run

```powershell
# Check that Output 04 exists
Test-Path -LiteralPath "outputs\04-design-validation-G08.md"

# Verify the 7 required headings are present
$content = Get-Content -Raw "outputs\04-design-validation-G08.md"
$required = @(
    'ERD to Relational Schema Verification',
    'Business Rules Addressed',
    'Normalization Check',
    'Overlap Conflict Prevention Logic',
    'Status-Based Booking Prevention Validation',
    'Referential Integrity Validation',
    'Identified Design Issues'
)
$missing = $required | Where-Object { $content -notmatch [regex]::Escape($_) }
if ($missing) { "Missing sections: $missing" } else { "All 7 sections present" }
```

## Validation results

```
All 7 sections present
```

## Risks / caveats

- The trigger strategy description must remain in sync with Output 05 — if the DDL trigger is modified, this validation should be updated
- Booking lifecycle state transitions (e.g., Pending → Completed directly) are not enforced at schema level — application-layer reliance is noted
- Capacity guideline is not enforced as a hard constraint — open question remains

## Git status summary

```
Untracked files:
  outputs/04-design-validation-G08.md
  docs/audits/46-generate-design-validation.md
```

## Recommended next steps

- Proceed to Step 5 (Database Definition) if not yet done
- Review the overlap prevention trigger in Output 05 to confirm alignment with this validation
- Resolve the capacity enforcement open question with the stakeholder
