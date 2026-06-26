# Audit — Improve Rules and Fix Step 1 Analysis

> Date: 2024-05-22
> Operator/member: Trương Thị Mỹ Duyên and Huỳnh Lê Bảo Thi
> Tool: OpenCode
> Provider/model/variant: Gemini 2.5 Pro (via OpenCode)
> OpenCode command used: `/design-db`, `/refine-output` (conceptual)

## Task goal

The goal was to perform a comprehensive correction of the database design process after initial validation revealed systemic errors in the first-pass `01-business-req-analysis-G08.md`. The task involved three main parts:
1.  Update the project's core rulebooks (`AGENTS.md` and `SKILL.md`) to enforce higher standards.
2.  Regenerate the Step 1 analysis output to comply with the new, stricter rules.
3.  Document the entire corrective action in a single, comprehensive audit.

## Files created / changed

*   **Modified:** `AGENTS.md`
*   **Modified:** `.opencode/skills/db-design-pipeline/SKILL.md`
*   **Modified (Regenerated):** `outputs/01-business-req-analysis-G08.md`
*   **Created:** `audits/09-improve-rules-and-fix-analysis.md` (this file)

## What was evaluated

The entire process was evaluated:
1.  The agent's ability to modify its own rulebooks (`AGENTS.md`, `SKILL.md`) based on user feedback.
2.  The agent's ability to apply the newly updated rules to regenerate a corrected output file.
3.  The quality and correctness of the final `01-business-req-analysis-G08.md` against the updated, stricter criteria.

## Issues found

The initial `01-business-req-analysis-G08.md` file contained several systemic errors due to gaps in the initial rule interpretation:
1.  **Physical DB Details:** The analysis included physical database notations (e.g., "FK") which are inappropriate for the conceptual (Step 1) stage.
2.  **Missing Timestamps:** Core entities lacked `created_at` and `updated_at` timestamps, a critical requirement for auditing.
3.  **Denormalized Data:** The `Department` was treated as an attribute of `User`, not a separate, normalized entity.
4.  **Incorrect Cardinality:** The relationship between `Booking` and `Booking Decision` was incorrectly identified as 1-1, which would prevent a proper audit trail of decisions.
5.  **Missing Attributes:** Several mandatory attributes specified in the project spec were missing from the entity definitions.

## Changes made

A multi-stage correction was executed:

1.  **`AGENTS.md` Update:**
    *   Added a rule to **Section 3** explicitly forbidding physical database details (like Foreign Keys) in the Step 1 analysis.
    *   Added a rule to **Section 4** mandating that core entities (`Users`, `Spaces`, `Bookings`, `Maintenance`) must include `created_at` and `updated_at` timestamps.

2.  **`SKILL.md` Update:**
    *   In the `Domain Coverage` section, `Department` was added as a mandatory, normalized entity.
    *   The relationship between `Booking Decision` and `Booking` was explicitly defined as 1-to-N to ensure a complete audit history is preserved.
    *   A rule was added to list several previously-missed mandatory attributes (`problem_category`, `booking_type`, `cancelled_at`, `cancel_reason`, `note`) to ensure they are captured in the Step 1 analysis.

3.  **`01-business-req-analysis-G08.md` Regeneration:**
    *   The file was completely rewritten based on the updated rules.
    *   All mentions of "FK" were removed.
    *   `Department` was correctly identified as a separate entity.
    *   The relationship between `Booking` and `Booking Decision` was corrected to One-to-Many.
    *   All newly mandated attributes and timestamps were added to the entity lists.
    *   Traceability notes were updated to reflect the more robust and correct model.

## Improvement classification

*   AGENTS.md improvement
*   SKILL.md improvement
*   Output refinement

## Validation commands run

Manual validation was performed against the updated rules and the project specification documents.

## Validation results

The regenerated `01-business-req-analysis-G08.md` now correctly aligns with the stricter, more robust project rules. All identified issues have been addressed. The conceptual model is sound and provides a much stronger foundation for the subsequent ERD and logical design steps.

## Risks / caveats

None. The corrective actions have significantly reduced the risk of propagating design errors through the pipeline.

## Git status summary

```
M  AGENTS.md
M  .opencode/skills/db-design-pipeline/SKILL.md
M  outputs/01-business-req-analysis-G08.md
?? audits/09-improve-rules-and-fix-analysis.md
```

## Recommended next steps

Proceed with the database design pipeline, starting with Step 2 (Conceptual ERD Design), using the newly corrected `01-business-req-analysis-G08.md` as the source of truth.
