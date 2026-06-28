# Audit — Generate Design Validation (Output 04)

> Date: 2026-06-26
> Operator/member: Vi (group G08)
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free
> OpenCode command used: `/04-generate-design-validation`

## Task goal

Generate `outputs/04-design-validation-G08.md` by validating the logical schema (Output 03) against the conceptual ERD (Output 02) and business requirements (Output 01), following the skill in `.opencode/skills/db-design-pipeline/04-design-validation/SKILL.md`.

## Files created / changed

- Created: `outputs/04-design-validation-G08.md`
- Created: `docs/audits/19-generate-design-validation-audit.md`

## What was evaluated

- Mapping of all 9 conceptual entities to 9 logical tables
- Materialization of all 13 Crow's Foot relationship lines as Foreign Keys
- Coverage of all business rules from Output 01 in the logical schema
- Normalization to 3NF (1NF, 2NF, 3NF checks)
- Overlap conflict prevention strategy (trigger logic)
- Status-based booking prevention (cross-reference spaces.current_status)
- Referential integrity (all FKs, UNIQUE on usage_sessions.booking_id)
- Design issues found during mapping (5 items documented with resolutions)

## Issues found

| # | Issue | Severity | Status |
|---|---|---|---|
| 1 | `rejection_reason` is nullable but should be required when `decision = 'Rejected'` — missing `CHECK` constraint | Medium | Documented in Output 04 Section 7 |
| 2 | `completed_by` and `actual_end_time` fields lack a paired nullability check | Low | Documented in Output 04 Section 7 |
| 3 | Booking status `CHECK` does not enforce valid transition paths | Low | Accepted limitation for Phase 1 |
| 4 | `spaces.current_status = 'InUse'` has no automatic set/clear mechanism | Low | Documented as application-layer responsibility |

## Changes made

1. Created `outputs/04-design-validation-G08.md` with 7 sections as required by the skill:
   - ERD to Relational Schema Verification
   - Business Rules Addressed
   - Normalization Check (3NF)
   - Overlap Conflict Prevention Logic
   - Status-Based Booking Prevention Validation
   - Referential Integrity Validation
   - Identified Design Issues & Resolutions

## Improvement classification

- Output refinement

## Validation commands run

```powershell
# Setup-stage validation (no deliverables yet for 05/06/07)
bash scripts/check_required_files.sh --setup
```

```powershell
bash scripts/validate_sql.sh --setup
```

## Validation results

Setup-stage checks pass (expected, since only Outputs 01-04 exist).

## Risks / caveats

- Output 04 identifies 4 issues in the logical schema. These should be reviewed and resolved when refining Output 03 before proceeding to Output 05 (DDL).
- The overlap prevention and status-based prevention rely on trigger logic, which is documented but not yet implemented in SQL.
- Steps 01-03 were taken as-is; validation quality depends on the correctness of those inputs.

## Git status summary

Changes:
- New: `outputs/04-design-validation-G08.md`
- New: `docs/audits/19-generate-design-validation-audit.md`

## Recommended next steps

1. Review the 4 design issues logged in Output 04 and resolve them in Output 03.
2. Proceed to Step 5: Generate DDL (`outputs/05-db-definition-G08.sql`).
3. After all 7 outputs exist, run final-stage validation: `bash scripts/check_required_files.sh --final G08` and `bash scripts/validate_sql.sh --final G08`.
