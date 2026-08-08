# Audit — Output 08/09 Reconciliation Against the Tested Task 10 Migration (B1–B8)

> Date: 2026-08-08
> Operator/member: Trương Thị Mỹ Duyên (24125028), Senior Lead Database Architect & Concurrency Expert
> Tool: Claude Code
> Provider/model/variant: Claude Sonnet 5
> Command used: none (direct prompt, single continuous session; user-saved prompt preserved at `PROMPT-fix-task08-09-pass5.md`)

## Task goal

`outputs/10-schema-migration-G08.sql` has since been built and executed twice against a populated Phase 1 database (idempotency proven; rollback proven). That exercise surfaced eight defects that live in the **design documents**, not in the script — the script already works around all of them. This session reconciles `outputs/08-requirement-change-analysis-G08.md` and `outputs/09-updated-erd-and-logical-design-G08.md` with what the implementation proved, without touching the (correct, tested) migration script itself:

- **B1** — §5.14's `UNIQUE (space_id)` constraint on `auto_approval_policies` and its justifying comment asserted SQL Server treats multiple NULLs as *distinct*; this is inverted and is a functional bug, not a stylistic nit.
- **B2** — §5.16 used the same inverted NULL-semantics claim, in the opposite direction, to justify `booking_alerts`'s three filtered unique indexes.
- **B3** — §10 rows I3/I4 still used `NOT IN` inside filtered-index `WHERE` predicates, which SQL Server's filtered-index grammar does not support.
- **B4** — §10 row I8 duplicated an index SQL Server already creates implicitly for an existing `UNIQUE` constraint.
- **B5** — §7 rule R16 and §5.13's actor fallback chain contradicted each other on the `maintenance_impact_history` creation row, which as written would make it impossible for a non-staff user to ever report a fault.
- **B6** — neither document stated that dropping `space_facilities` requires first *expanding* its rows into `facility_assets` — undisclosed total data loss otherwise.
- **B7** — §8.9 (`booking_alerts`) was stale after an earlier `L11` fix added a third `alert_type`/index, and never named the table's XOR as a polymorphic association pattern.
- **B8** — most §7 rules referenced "a trigger in Task 10" without naming it, Output 08 §4.1 never stated the Phase 1 trigger must be *modified* (not just kept), and no standing note explained the `TRIGGER_NESTLEVEL(@@PROCID, ...)` re-entry-guard pattern used by all 14 Task 10 triggers.

## Files created / changed

- `outputs/08-requirement-change-analysis-G08.md` — new §2.3d subsection (space_facilities → facility_assets expansion, B6); a new bullet in §4.1 specifying the three required changes to the Phase 1 trigger (B8); new `### Pass 5` table in Appendix A (B6, B8 rows — the two defects with primary content in this document).
- `outputs/09-updated-erd-and-logical-design-G08.md` — §5.14 table row + design note rewritten to a filtered unique index with corrected NULL-semantics reasoning (B1); §8.7 3NF proof wording updated to match (B1); §5.16 design note rewritten with corrected reasoning (B2); §10 rows I3/I4 rewritten as `<>` conjuncts, row I8 re-marked implicit, row I17's note corrected, new standing note on filtered-index predicate grammar (B3); §13 index-count checklist restated as 18 §10 rows + 4 additional filtered unique indexes = 20 physical objects (B4); §7 rule R16 narrowed to escalation/downgrade rows, §5.13 design notes updated to match (B5); one-line cross-reference to Output 08 §2.3d added to §5.6 (B6); §8.9 updated to cover all three `alert_type` values/indexes plus a new polymorphic-association disclosure with the rejected supertype/subtype alternative (B7); new 14-row trigger-inventory table and `TRIGGER_NESTLEVEL` standing note added to §7, plus inline trigger names added to §5.11/§5.12's previously-unnamed invariant triggers (B8); new `### Pass 5` table in Appendix A covering all eight defects in full, preserving each superseded (inverted) claim as instructed.
- `docs/audits/61-output08-09-migration-reconciliation-audit.md` — this audit.
- Not modified: `outputs/10-schema-migration-G08.sql` (explicitly out of scope — confirmed correct and already tested; used only as the reference/ground truth for this reconciliation); `outputs/01`–`07`; `AGENTS.md`.

## What was evaluated

- Each of B1–B8 against the actual tested migration script (`outputs/10-schema-migration-G08.sql`) as ground truth, including reading the full text of every `CREATE OR ALTER TRIGGER` statement (14 triggers) and the `space_facilities → facility_assets` expansion block (§4b of the script).
- SQL Server NULL-semantics claims throughout both documents via a targeted grep sweep for `NULLs? as distinct` / `NULLs? are distinct` — this surfaced **two additional, previously unflagged instances** of the same inverted claim beyond the two locations named in the request (§5.14's "Determinism (L8)" bullet and §10's I17 row, both describing `UQ_auto_approval_policies_active_type`). Fixed under the same B1 root cause, since the verification sweep the task itself specifies ("zero occurrences outside Appendix A") would otherwise fail.
- Filtered-index predicate grammar (SQL Server's `<conjunct> [AND <conjunct>]` grammar, where a conjunct is `IN (...)` or a comparison operator — `NOT IN` and bare `OR` are both illegal) across all 18 rows of §10, confirming I1/I2 correctly retain `IN (...)` and no predicate anywhere uses `OR`.
- §10/§13 index-count arithmetic against the actual objects the migration script creates (`sys.indexes`/`CONSTRAINT` clauses), reconciling 16 explicitly-created + 2 implicit (I8, I16) = 18 §10 rows, plus 4 filtered unique indexes defined outside §10 (§5.14, §5.16) = 20 physical objects.
- Every trigger name introduced into Output 09 §7's new inventory table, checked character-for-character against the 14 `CREATE OR ALTER TRIGGER dbo.<name>` statements in the migration script.
- The Phase 1 `space_facilities` schema's actual column shape, checked against `outputs/05-db-definition-G08.sql` directly (not just Output 09's own description of it), to confirm the new B6 expansion subsection's `facility_id → facility_name` resolution matches the real Phase 1 DDL and the migration script's actual `JOIN dbo.facilities AS f ON f.facility_id = sf.facility_id` logic.
- A full regression sweep of every item the task locked as "do not change": absence of `CK_maintenance_records_target_xor`, `maintenance_records.space_id NOT NULL`, §8 spanning 8.1–8.11 (11 relations), the "15 tables / 7 retained / 3 modified / 8 new / 11 relations" counts, the `bookings → maintenance_records → booking_alerts` lock-ordering rule, `usp_CompleteBooking`'s exclusion from the §9.5 shared-checks list, and the NULL-safe `max_participants` eligibility test.
- Markdown structural integrity (code-fence balance, table formatting) after all edits.

## Issues found

- **B1:** §5.14 enforced "at most one specific-space override" with a table `CONSTRAINT UQ_auto_approval_policies_space_id UNIQUE (space_id)`, justified as "SQL Server treats multiple NULLs as distinct, which is exactly right for type-wide rows." This is backwards: SQL Server is the exception to the ANSI rule and treats NULLs as **equal** in a `UNIQUE` constraint, permitting only one NULL row. As written, the constraint would accept the *first* type-wide policy (`space_id = NULL`) and reject every subsequent one as a duplicate NULL — a silent, hard-to-diagnose production failure that breaks auto-approval configuration for every space type after the first.
- **B2:** §5.16 argued a single `UNIQUE (maintenance_id, booking_id, alert_type)` "can no longer be used... SQL Server treats NULLs as distinct, so it could never deduplicate asset-caused rows" — the same false claim, applied in the opposite direction. The actual failure mode of a single `UNIQUE (maintenance_id, booking_id)` here is **over**-constraining: two distinct asset-caused relocation alerts sharing a `booking_id` (both `maintenance_id IS NULL`) would collide as duplicate NULLs and the second insert would be rejected.
- **B3:** §10 rows I3 (`IX_maintenance_blocking`) and I4 (`IX_maintenance_advisory`) still read `status NOT IN (N'Completed', N'Cancelled')` inside a filtered-index `WHERE` clause. `NOT IN` is outside SQL Server's filtered-index predicate grammar (proven at runtime while building Task 10); the earlier `R1` fix (audit 60) corrected only I13 and missed these two.
- **B4:** §10 row I8 (`IX_ack_booking` on `booking_advisory_acknowledgments (booking_id, maintenance_id)`) is identical in key and column order to the index SQL Server already creates implicitly for `UQ_booking_advisory_acknowledgments_booking_maintenance` — a second, redundant B-tree. §13's index-count sentence also predated this fix and did not separately account for the 4 filtered unique indexes defined outside the §10 table (§5.14, §5.16).
- **B5:** §7 rule R16 required the resolved `maintenance_impact_history.changed_by` to hold a staff-type role on **every** row, while §5.13 defines the actor fallback chain as `COALESCE(SESSION_CONTEXT, assigned_staff_id, reporter_id)` — with `reporter_id` as the terminal fallback on the creation row. A Student may legitimately report a broken projector with no session context and no staff assigned yet; enforcing R16 unconditionally would make the audit-trail insert trigger reject the very report it is supposed to record, rolling back the maintenance report itself. (`outputs/10-schema-migration-G08.sql` already implements the correct, narrowed behavior with an inline comment explaining exactly this contradiction — the design documents had not caught up.)
- **B6:** grepping both documents for `expand`/`SUM(quantity)` returned zero matches before this session. Sections 2.3a–2.3c describe `space_facilities` as a stored projection of `facility_assets` in the *final* schema, but never state that at *migration time* the dependency runs the other way: `space_facilities` holds the only record of a space's equipment inventory, and `facility_assets` starts empty. Dropping the table without an expansion step first is undocumented total data loss.
- **B7:** §8.9's FD bullet and candidate-key description referenced only two filtered unique indexes and two `alert_type` values (`MaintenanceEscalated`, `RequiredAssetRelocated`), stale since an earlier `L11` fix (audit 60) added a third value (`AdvisoryAddedAfterApproval`) and its index (`UQ_booking_alerts_advisory_added`), both of which the migration script already implements. Separately, §8.9 noted the `maintenance_id`/`asset_id` mutual exclusivity "is enforced by a CHECK constraint, not a functional dependency" but never named the modeling pattern (a polymorphic/"arc" association) or explained why it is legitimate here despite the near-identical-looking `maintenance_records` XOR having been removed by D-1 as a modeling defect.
- **B8:** most rules in §7 (R3, R5, R8, R9, R12–R16, plus the L10/L11/D-1 invariants in §5.11/§5.12/§5.16) referenced their Task 10 trigger only obliquely ("a trigger in Task 10," "Task 10 trigger") without a name, so the design could not be traced to the implementation. Output 08 §4.1 stated the Phase 1 trigger "stays" as a backstop without stating it must be **modified** — three concrete changes are required (drop `UnderMaintenance` from the `current_status` check, extend the overlap check to include `CheckedIn`, add the direct `OutOfService` check) and were undocumented. No standing note existed anywhere explaining why all 14 Task 10 triggers guard re-entry with the `@@PROCID`-scoped `TRIGGER_NESTLEVEL` form rather than the bare form (the bare form would silently disable a trigger legitimately fired by another trigger, e.g. `TR_impact_history_StaffRole` validating a row `TR_maintenance_impact_history` just wrote).
- **Not in the original request, found during verification:** the §5.14 "Determinism (L8)" bullet and §10's I17 row both restated the same inverted NULL-distinctness claim to explain why `UQ_auto_approval_policies_active_type` (a filtered index) leaves specific-space override rows untouched. The claim is doubly wrong there — SQL Server's NULL-equality behavior in a table `UNIQUE` constraint has nothing to do with why a *filtered* index's `WHERE space_type IS NOT NULL` predicate excludes those rows; the filter predicate itself is the reason. Fixed under the B1 root cause.

## Changes made

- **B1:** §5.14's `space_id` row no longer carries `UNIQUE (space_id)`; the constraint is replaced with filtered unique index `UQ_auto_approval_policies_space_id ON auto_approval_policies (space_id) WHERE space_id IS NOT NULL`, moved out of the table's constraint column into the design notes (it is an index, not a table constraint) with the corrected NULL-equality explanation and a runnable `CREATE UNIQUE INDEX` snippet. §8.7's 3NF proof updated to call it a "supplementary filtered unique index," not a "supplementary UNIQUE constraint."
- **B2:** §5.16's "Per-scope duplicate prevention" bullet rewritten with the corrected over-constraining failure mode and the real reason for scoping per `alert_type` (a `MaintenanceEscalated` row must not block a later, distinct `AdvisoryAddedAfterApproval` row for the same pair).
- **B3:** I3/I4 rewritten as `status <> N'Completed' AND status <> N'Cancelled'`; a new standing note added to §10 stating the full filtered-index grammar and both traps in it (`IN` is legal/`OR` is not; `NOT IN` is illegal/`<>` conjuncts are the fix), cross-referencing I1/I2 (correctly `IN`) and I3/I4/I13 (correctly `<>`).
- **B4:** I8 re-marked as the implicit index of `UQ_booking_advisory_acknowledgments_booking_maintenance` (same treatment as I16), with a note stating a distinct `IX_ack_booking` would be a redundant B-tree. §13 restated: 16 explicit (I1–I7, I9–I15, I17, I18) + I8/I16 implicit = 18 §10 rows, + 4 filtered unique indexes from §5.14/§5.16 = 20 physical index objects.
- **B5:** §7 R16 narrowed to `old_impact_level IS NOT NULL` (escalation/downgrade rows only), naming trigger `TR_impact_history_StaffRole`; §5.13 design notes gained a matching bullet explaining the creation-row exemption and why enforcing R16 unconditionally would break fault reporting for non-staff.
- **B6:** New Output 08 §2.3d specifies the expansion rule (each `(space_id, facility_id, quantity)` row → `quantity` `facility_assets` rows, resolving `facility_id → facility_name` through `facilities` while it still exists), the `serial_number` generation scheme (L12), `condition`/`note` carry-over, the `asset_status` seeding rule (decision A1, `UnderMaintenance` only where `quantity = 1`, else `Available` with condition preserved), and the Task 10 (data preservation) vs. Task 14 (data generation) scope boundary. Output 09 §5.6 gained a one-line cross-reference.
- **B7:** §8.9 FD bullet and candidate-key description updated to all three `alert_type` values and three filtered unique indexes; new disclosure paragraph names `booking_alerts` as a polymorphic ("arc") association, states the distinguishing test against `maintenance_records`' XOR (does any legal row need both columns — no here, yes there), and records the rejected supertype/subtype-split alternative as `[EXTENSION]`.
- **B8:** New 14-row trigger-inventory table added to §7 (rule/defect → trigger name), cross-checked against the migration script; new standing note on the `TRIGGER_NESTLEVEL(@@PROCID, 'AFTER', 'DML')` re-entry guard; §5.11/§5.12's previously-unnamed invariant triggers (`TR_maintenance_TargetInvariant`, `TR_ack_AdvisoryOnly`) named inline; Output 08 §4.1 gained a new bullet specifying the three required Phase 1 trigger changes and restating that it remains a validation backstop only (Task 12 stays the concurrency mechanism).
- **Both documents:** a `### Pass 5` section appended to Appendix A — Output 09's covers all eight defects in full (including the two additional NULL-claim instances found during verification, folded into the B1 row); Output 08's covers only B6 and B8, the two with primary content in that document, with a note pointing to Output 09's Appendix A for the other six.

## Improvement classification

- Output refinement
- Validation/test improvement — the NULL-semantics and filtered-index-grammar corrections close defects that are reachable at runtime (proven by actually building and executing `outputs/10-schema-migration-G08.sql` against a populated database, not by inspection alone)
- Documentation improvement — new trigger-inventory table and `TRIGGER_NESTLEVEL` standing note make the design traceable to the implementation; new §2.3d closes an undocumented data-loss gap

## Validation commands run

- `grep -n "NULLs? as distinct\|NULLs? are distinct"` across both documents, before and after edits, to confirm zero occurrences remain outside Appendix A.
- `grep -n "NOT IN"` across Output 09 to confirm no filtered-index predicate (I1–I18) uses it, and that ordinary `WHERE`/trigger-body uses elsewhere are unaffected.
- `grep -n "WHERE.*\bOR\b"` to confirm no filtered-index predicate uses bare `OR`.
- `grep -n "18 rows|20 physical|20 created"` to confirm §13's restated counts landed in the right places.
- `grep -n "TR_bookings_PreventOverlapAndUnavailable\|TR_bookings_AdvisoryAckRequired\|TR_maintenance_escalation\|TR_bookings_RequiredAssetCheck\|TR_maintenance_impact_history\|TR_facility_assets_RelocationAlert\|TR_booking_decisions_StaffRole\|TR_maintenance_StaffRole\|TR_booking_alerts_StaffRole\|TR_impact_history_StaffRole\|TR_ack_AdvisoryOnly\|TR_maintenance_AdvisoryAddedAlert\|TR_maintenance_TargetInvariant\|TR_maintenance_SyncAssetStatus"` against Output 09 and cross-referenced against `grep -n "CREATE OR ALTER TRIGGER"` in the migration script, name by name.
- `grep -n "^### 8\.\d+ "` to confirm §8 still spans 8.1–8.11.
- `grep -n "CK_maintenance_records_target_xor"`, `"usp_CompleteBooking"`, `"bookings → maintenance_records → booking_alerts"`, `"max_participants IS NULL OR expected_participants"`, and the `space_id NOT NULL (Phase 1 baseline...)` row — all regression checks against items the task locked as unchanged.
- `grep -n "space_facilities|facility_id|facility_name"` against `outputs/05-db-definition-G08.sql` directly, to confirm the real Phase 1 column is `facility_id` (not `facility_name`) before writing the B6 expansion rule.
- `grep -n "space_facilities|facility_id|facility_name"` (targeted, §4b) against `outputs/10-schema-migration-G08.sql` to confirm the script's actual expansion logic (`JOIN dbo.facilities AS f ON f.facility_id = sf.facility_id`, the `condition`/`note` `CONCAT`, and the quantity/condition-text `asset_status` seeding `CASE`) before describing it in §2.3d.
- `grep -c '```'` on both documents to confirm balanced (even) code-fence counts after all edits.
- `wc -l` before/after on both documents as a gross sanity check.

## Validation results

- Zero occurrences of the inverted "NULLs as distinct" claim remain outside Appendix A in either document (two additional instances found and fixed beyond the two named in the request).
- Zero `NOT IN` and zero bare `OR` inside any filtered-index predicate in §10; I1/I2 confirmed still using `IN (...)`; I3/I4/I13 confirmed using `<>` conjuncts.
- §10 and §13 agree: 16 explicit + I8/I16 implicit = 18 rows; +4 filtered unique indexes = 20 physical objects.
- §8.9 confirmed mentioning all three `alert_type` values and all three filtered unique indexes.
- §7's new trigger-inventory table's 14 names match `outputs/10-schema-migration-G08.sql`'s 14 `CREATE OR ALTER TRIGGER` statements exactly, character-for-character.
- Output 08 §2.3d confirmed present and covering expansion, serial generation, condition/note carry-over, and the A1 `quantity = 1` rule.
- Full regression sweep clean: no `CK_maintenance_records_target_xor`; `maintenance_records.space_id` still `NOT NULL`; §8 still spans 8.1–8.11 (11 relations); counts still "15 tables / 7 retained / 3 modified / 8 new / 11 relations"; lock-ordering rule intact; `usp_CompleteBooking` still excluded from §9.5; NULL-safe `max_participants` test intact.
- Code-fence counts even in both documents (6 in Output 08, 22 in Output 09) after all edits — no unclosed fences introduced.
- `outputs/10-schema-migration-G08.sql` confirmed unmodified throughout the session (read-only reference use only).

## Risks / caveats

- **Two defects fixed beyond the original B1–B8 scope.** The §5.14 "Determinism" bullet and §10's I17 row both carried the same inverted NULL-semantics claim as B1/B2, in a third location not named in the request. Fixing them was necessary for the task's own verification sweep to pass ("zero occurrences outside Appendix A") — flagging here rather than silently expanding scope without note.
- **A pre-existing, out-of-scope inconsistency was found but not fixed.** Output 09 §5.5 describes `space_facilities` as holding a `facility_name` column, but the real Phase 1 DDL (`outputs/05-db-definition-G08.sql`) and the migration script both use `facility_id` with a join to `facilities.facility_name`. This predates this session and is not one of B1–B8; it was deliberately left untouched per the "targeted, in-place edits" instruction, but a reader comparing §5.5 to the actual schema will notice the mismatch.
- **The A1 seeding-rule description is a simplification of the script's actual logic**, per the request's own wording ("seeded `UnderMaintenance` only where `quantity = 1`"). The migration script's real `CASE` expression also treats `quantity = 1` rows with `NULL`/`'Good%'`/`'Functional%'` condition text as `Available`, not `UnderMaintenance` — `quantity = 1` is necessary but not sufficient in the script. Output 08 §2.3d states the rule as requested; a reader diffing line-by-line against the script should be aware the script is slightly more permissive.
- No SQL Server execution was run in this session — accuracy of trigger names, index definitions, and the expansion logic was verified by direct text comparison against `outputs/10-schema-migration-G08.sql`, not by executing DDL. The idempotency/rollback proof referenced in the task description was performed prior to this session, not re-verified here.
- `outputs/10-schema-migration-G08.sql` was correct going in and required no changes — this session brought the design documents up to what the script already does, not the other way around. No regeneration of the script is needed as a result of this audit.

## Git status summary

```
 M .opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md
 M AGENTS.md
 M outputs/08-requirement-change-analysis-G08.md
 M outputs/09-updated-erd-and-logical-design-G08.md
 M outputs/10-schema-migration-G08.sql
?? PROMPT-fix-task08-09-pass2.md
?? PROMPT-fix-task08-09-pass3.md
?? PROMPT-fix-task08-09-pass4.md
?? PROMPT-fix-task08-09-pass5.md
?? PROMPT-fix-task08-09.md
?? docs/audits/60-output08-09-facilities-drop-and-model-review-audit.md
?? docs/audits/61-output08-09-migration-reconciliation-audit.md
```

- `.opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md` and `AGENTS.md` show as modified from a prior session; neither was touched in this session (this session's edits were confined to `outputs/08` and `outputs/09`, per the task's explicit file-scope restriction).
- `outputs/10-schema-migration-G08.sql` shows as modified from a prior session (not deleted, unlike the state audit 60 recorded); not touched in this session — used strictly as a read-only reference.
- `PROMPT-fix-task08-09-pass5.md` is the user's saved prompt text for this session; not created or modified by this audit.
- No commit requested; nothing committed.

## Recommended next steps

- Decide whether to correct Output 09 §5.5's `facility_name`-vs-`facility_id` description of `space_facilities` (flagged above as out-of-scope for this session) so it matches the real Phase 1 DDL and the migration script's actual join logic.
- No migration-script regeneration is required from this audit — `outputs/10-schema-migration-G08.sql` already implements everything the corrected documents now describe; this pass brought the documentation into agreement with tested, working code, not the reverse.
- Team review of the trigger-inventory table (§7) and the B6 expansion rule (Output 08 §2.3d) before Task 11/12/14 consume these documents, since both are newly load-bearing for downstream tasks (concurrency procedures need the trigger names; the data generator needs the expansion/seeding rule to avoid re-deriving it independently).
- Consider clearing the now-superseded `PROMPT-fix-task08-09*.md` scratch files from the repository root once their content is fully captured in this audit and in Appendix A, if the team does not want saved prompts committed long-term.
