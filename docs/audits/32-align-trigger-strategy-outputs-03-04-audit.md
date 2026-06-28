# Audit — Align Trigger Strategy Across Outputs 03/04 with Output 05

> Date: 2026-06-29
> Operator/member: Vo Quoc Linh (24125065)
> Tool: OpenCode CLI
> Provider/model/variant: deepseek/deepseek-v4-pro
> OpenCode command used: (none — custom task prompt)
> Phase 1 step evaluated: Steps 3 & 4 (design/validation) vs Step 5 (DDL)

## Task goal

Targeted **trigger-strategy consistency fix**: align Outputs 03 and 04 with the accepted gated `AFTER INSERT, UPDATE` trigger strategy implemented in Output 05, and add only *general* cross-step consistency guidance to skills (no hard-coded trigger answer). Scope excludes capacity and active-account wording (separate task).

## Files created / changed

| File | Action | Description |
|---|---|---|
| `outputs/03-logical-design-G08.md` | Edited | "Tradeoff Note" → "Selected Strategy": the gated `AFTER INSERT, UPDATE` trigger is now the accepted strategy (with gating logic described); `INSTEAD OF` kept only as an alternative. |
| `outputs/04-design-validation-G08.md` | Edited | Business-rule table row 1, §4 Strategy + pseudocode, and §5 availability block rewritten to the gated `AFTER` trigger; removed the manual re-INSERT / "UPDATE branch handled … with INSTEAD OF logic" pseudocode; SQL blocks relabeled as **validation pseudocode (not final DDL)**. |
| `.opencode/skills/db-design-pipeline/SKILL.md` | Edited | Added a general **"Cross-Step Output Consistency"** section (synchronize earlier docs when an accepted downstream output changes a strategy; don't hard-code trigger type/name/body in skills). |
| `.opencode/skills/db-design-pipeline/04-design-validation/SKILL.md` | Edited | Generalized the overlap-enforcement line so it no longer leads with `INSTEAD OF`; now requires the documented strategy to **match the accepted Output 05 DDL**, with `INSTEAD OF` as an alternative only. |
| `docs/audits/32-align-trigger-strategy-outputs-03-04-audit.md` | Created | This audit. |

**Not changed:** `outputs/05-db-definition-G08.sql` (untouched), sample data (`06`), Outputs 01/02/07, and **skill 03** (its enforcement guidance was already general — it lists trigger/stored-procedure/application options without mandating `INSTEAD OF`, so it was left unchanged).

## What was evaluated

The trigger-strategy wording in Outputs 03 and 04 versus the implemented trigger in Output 05; and whether skills 03/04 and the shared skill contained guidance that would re-create the mismatch.

## Issues found

- **03** "Tradeoff Note" recommended implementing both rules via **`INSTEAD OF`** triggers (contradicting `05`'s `AFTER` trigger).
- **04** documented the enforcement as an **`INSTEAD OF INSERT, UPDATE`** trigger, with pseudocode that manually re-inserted rows and a comment "UPDATE branch handled similarly with INSTEAD OF logic" — reflecting the old, superseded approach.
- **skill 04** led its overlap-rule guidance with "`INSTEAD OF` or `AFTER`", which could regenerate the `INSTEAD OF` wording.
- **shared skill** had no general cross-step consistency rule to prevent design/validation docs drifting from the accepted DDL.

## Changes made

- **Outputs 03/04** now describe the **gated `AFTER INSERT, UPDATE`** trigger as the selected/current strategy: overlap check applies only to rows that are/become `Approved`; availability check applies only to active placements (`Pending`/`Approved`); lifecycle updates (`Completed`/`Cancelled`/`NoShow`) are not blocked; violations `ROLLBACK` + `RAISERROR`. `INSTEAD OF` remains only as a noted alternative tradeoff.
- **04** SQL blocks are explicitly labeled as validation pseudocode / strategy summaries pointing to Output 05 for the executable trigger — no `CREATE TRIGGER` / final DDL is presented as the answer.
- **skill 04** and the **shared skill** received general guidance only; no trigger name or trigger body was hard-coded.

## Improvement classification

- Output refinement (03, 04)
- SKILL.md improvement (shared skill + skill 04)

## Validation commands run

```bash
grep -niE 'INSTEAD OF' outputs/03-logical-design-G08.md outputs/04-design-validation-G08.md
grep -ciE 'AFTER INSERT, UPDATE|gated AFTER' outputs/03-logical-design-G08.md outputs/04-design-validation-G08.md
git status --short outputs/05-db-definition-G08.sql
git status --short
git diff --stat -- <the 4 changed files>
```

## Validation results

- In 03/04, `INSTEAD OF` now appears **only** in "alternative tradeoff" sentences; the selected strategy everywhere is the gated `AFTER` trigger.
- `outputs/05-db-definition-G08.sql` shows **no modification** (unchanged).
- Changed files: `outputs/03-…md`, `outputs/04-…md`, shared `SKILL.md`, `04-design-validation/SKILL.md` (+ this audit). Skill 03 unchanged.
- The 04 pseudocode now matches 05's gated logic (overlap gated on `i.status = 'Approved'`; availability gated on `Pending`/`Approved`) and is labeled non-executable.

## Risks / caveats

- Documentation/static alignment only — no SQL executed.
- The pseudocode in 03/04 intentionally mirrors but is **not** identical to Output 05's executable trigger (no trigger name, no `CREATE TRIGGER`, no `updated_at` refresh) — they are design/validation summaries, with 05 as the source of truth.
- **Out of scope (still open):** capacity treatment (01/04 assert/enforce a rule 05 doesn't implement) and the active-account over-assertion in 01. These remain for a separate targeted consistency task.

## Git status summary

```
 M outputs/03-logical-design-G08.md
 M outputs/04-design-validation-G08.md
 M .opencode/skills/db-design-pipeline/SKILL.md
 M .opencode/skills/db-design-pipeline/04-design-validation/SKILL.md
?? docs/audits/32-align-trigger-strategy-outputs-03-04-audit.md
```

(Output 05 is intentionally absent from the changed set.)

## Recommended next steps

1. Separate targeted task: resolve **capacity** (firm rule → implement in 05, or inferred/open → soften 01/04) and re-soften the **active-account** wording in 01.
2. Execute `05` then `06` on a fresh SQL Server instance to confirm the documented strategy matches runtime behaviour.
3. Commit the accumulated Phase 1 consistency fixes (audits 29–32) when ready.
