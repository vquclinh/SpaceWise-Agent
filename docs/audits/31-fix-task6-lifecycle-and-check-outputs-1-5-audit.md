# Audit — Fix Task 6 Lifecycle Consistency + Cross-Check Outputs 01–05

> Date: 2026-06-28
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Step 6 — Sample Data (fix) + review of Steps 1–5

## Task goal

Fix the booking-status/usage-session lifecycle inconsistency in `outputs/06-sample-data-G08.sql`, add a consistency rule to skill 06 so it does not recur, and check Outputs 01–05 for similar logical errors.

## Files created / changed

| File | Action | Description |
|---|---|---|
| `outputs/06-sample-data-G08.sql` | Edited | Bookings #1 and #4 changed `Approved` → `Completed` (each has a completed usage session); fixed the mislabeled `booking_decisions` comment ("Booking #7" → "Booking #8"). |
| `.opencode/skills/db-design-pipeline/06-sample-data/SKILL.md` | Edited | Added section 2a (booking↔usage-session lifecycle consistency rules), an FK-lookup-over-literal-id note, and a section 7 self-review checklist. |
| `docs/audits/31-fix-task6-lifecycle-and-check-outputs-1-5-audit.md` | Created | This audit. |

No other outputs were modified. Outputs 01–05 were **reviewed only**, not changed.

## Changes made (Task 06)

- **Booking #1** (`Approved` → `Completed`): it has a completed usage session (`completed_by` + `actual_end_time` set) and an `Approved` decision row, so `Completed` is the correct lifecycle state.
- **Booking #4** (`Approved` → `Completed`): same reasoning.
- **Comment fix:** the `booking_decisions` row that approves `booking_id = 8` was commented "Booking #7 (A1-102, TA H)"; corrected to "Booking #8 (B1-102, Student B, CheckedIn)".
- All 7 booking statuses remain represented (`Approved` still via #2/#9/#12). The data still loads under the corrected Step 5 `AFTER` trigger (no two approved overlap; no booking on an unavailable space).

## Skill 06 hardening

- **Section 2a — Booking ↔ Usage-Session lifecycle consistency (MUST):** completed session ⇒ `Completed`; open session ⇒ `CheckedIn`; `Pending`/`Rejected`/`Cancelled`/`NoShow` ⇒ no session; `Rejected` needs a decision with `rejection_reason`; no booking placed on an unavailable space.
- **FK-lookup note:** prefer `SELECT`/`DECLARE` lookups over hard-coded identity numbers (the literal-id style caused the #7↔8 mislabel).
- **Section 7 self-review checklist** covering the above.

## Cross-check of Outputs 01–05 (review only — issues found, NOT changed)

**Output 02 (ERD):** consistent — no lifecycle/assertion errors.

**Output 05 (DDL):** already corrected in audits 29–30 (gated `AFTER` trigger, GO separators). OK.

**Output 03 (Logical design) & Output 04 (Design validation) — trigger-type mismatch with the corrected Output 05:**
- `03` §"Business Rule Enforcement" recommends implementing the rules via **`INSTEAD OF`** triggers (and mentions `AFTER` only as an option).
- `04` documents the enforcement as an **`INSTEAD OF INSERT, UPDATE`** trigger (rows in the business-rules table, the overlap section, and pseudocode including an "UPDATE branch handled … with INSTEAD OF logic").
- **`05` now implements an `AFTER INSERT, UPDATE` trigger** (changed in audit 29 to fix the batch/over-broad-logic bugs).
- → `03` and `04` are now **inconsistent with `05`**, and `04`'s pseudocode reflects the old over-broad logic. They should be updated to describe the gated `AFTER` trigger.

**Capacity rule treated inconsistently (01 & 04 vs 03/05 and the requirement):**
- `01` §5 "Other Key Business Rules" states **"Capacity: expected participants must not exceed the capacity"** as a firm rule (line 62).
- `04` claims capacity "**is enforced at the application level**" (line 62).
- But `05` implements **no** capacity enforcement (only `expected_participants > 0`), and the official requirement does **not** state a capacity rule (it was previously classified as inferred/open in audit 26).
- → `01`/`04` assert/validate a rule that `05` does not implement and the requirement does not establish. Either implement it for real (a cross-table check needs a trigger, not a simple `CHECK`) **or** soften `01`/`04` back to "inferred/open."

**Active-account over-assertion (01 line 56):** "All system users must have an **active** university account" — the requirement only says users have an `account_status`. (Same issue flagged in audit 26; reappeared because `01` was regenerated.)

> Note: `01` and `04` appear to have been regenerated after audit 26, which re-introduced the capacity and active-account assertions that audit had softened.

## Improvement classification

- Output refinement (Task 06)
- SKILL.md improvement (skill 06)
- (Outputs 01/03/04 issues: documented, awaiting a decision — not changed)

## Validation commands run

```bash
grep -nE "N'(Lecture|ProjectWork)', N'(Approved|Completed)'" outputs/06-sample-data-G08.sql
grep -n 'Booking #7' outputs/06-sample-data-G08.sql
bash scripts/validate_sql.sh --final G08
git status --short
```

## Validation results

- Bookings #1 and #4 now `Completed`; no `Booking #7` comment remains.
- `validate_sql.sh --final G08`: `06-sample-data-G08.sql` → INSERT statements found ✅. (Overall FAIL only because `07` is not generated yet.)
- 06 still loads under the corrected `AFTER` trigger (static reasoning; no live DB here).

## Risks / caveats

- Static review only — not executed on a live SQL Server.
- **Decision needed (not made here):** capacity — firm rule (then it must be implemented in `05`) or inferred/open (then soften `01`/`04`). I did not change `01`/`04` because that re-litigates a team choice.
- **`03`/`04` still say `INSTEAD OF`** while `05` uses `AFTER`. Recommend aligning them; not done here because the task scoped fixes to `06`.
- Sample data still hard-codes FK ids (works on a fresh DB; the skill now recommends lookups for future regenerations).
- Coverage gaps remain (no `InUse`/`Retired` spaces; all users `Active`) — optional.

## Git status summary

```
 M outputs/06-sample-data-G08.sql
 M .opencode/skills/db-design-pipeline/06-sample-data/SKILL.md
?? docs/audits/31-fix-task6-lifecycle-and-check-outputs-1-5-audit.md
```

## Recommended next steps

1. Decide the **capacity** question (firm vs inferred/open) and align `01`, `04`, and `05` accordingly.
2. Update `03` and `04` to describe the **`AFTER`** trigger (gated) instead of `INSTEAD OF`, so the validation/logical-design docs match `05`.
3. Re-soften the **active-account** wording in `01` (or confirm it as a deliberate assumption).
4. Execute `05` then `06` on a fresh SQL Server instance to confirm end-to-end.
