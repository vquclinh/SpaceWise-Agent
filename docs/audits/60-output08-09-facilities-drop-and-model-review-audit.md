# Audit — Output 08/09 Multi-Pass Correction and Model Review (Facilities Restructure, D-1..D-3/L1-L20/R1-R8 Defect Fixes, T-0..T-5 Model Changes)

> Date: 2026-08-08
> Operator/member: Truong Thi My Duyen (24125028), Senior Lead Database Architect
> Tool: Claude Code
> Provider/model/variant: Claude Sonnet 5
> Command used: none (five sequential direct prompts in one continuous session)

## Task goal

Five sequential passes over `outputs/08-requirement-change-analysis-G08.md` and `outputs/09-updated-erd-and-logical-design-G08.md`, two of which also required amending `AGENTS.md`:

1. **Architectural override (facilities drop):** drop the Phase 1 `facilities` catalogue table, absorb `facility_name` into `space_facilities` (composite PK `(space_id, facility_name)`), restructure `facility_assets` around a composite FK to the new catalogue key, restate the maintenance-targeting XOR logic. Explicitly authorized "no audits" for this pass; required amending `AGENTS.md` first (new §1a) because it conflicts with the baseline-preservation rule.
2. **34-defect audit-fix pass:** three locked decisions (D-1: refute the `maintenance_records.space_id`/`asset_id` transitive-dependency argument and remove the XOR constraint via an FD counterexample; D-2: correct the `space_facility_requirements` 3NF justification; D-3: disclose `CK_maintenance_records_asset_scope_level` as a team [EXTENSION]) plus twenty lettered defects (L1–L20: wrong constraint names, an incorrect `COUNT(DISTINCT...)` ack check, a missing 3NF proof, mislabeled normalization claims, ERD notation errors, etc.).
3. **8-defect second audit pass (R1–R8):** filtered-index grammar violation (`NOT IN`), an ambiguous standing-vs-migration-only `DEFAULT`, a non-selective index key, twelve dangling cross-section references, a stale index count, one leftover ERD cardinality, a mislabeled 3NF/denormalization checklist claim, and one index whose stated purpose didn't match the query it actually serves.
4. **Structural pass (Appendix A):** three more substantive defects (S1: `usp_CompleteBooking` wrongly included in the shared concurrency-check list; S2: a `max_participants IS NULL` three-valued-logic trap in the auto-approval eligibility test; S3: stale "Task 10 does not exist yet" claims) plus a full restructuring — relocating roughly forty inline "an earlier draft said X, now Y" correction narratives out of the body and into a new **Appendix A — Revision Notes** in both documents, rewriting both quality checklists into present-tense achievement statements with no revision-history clutter.
5. **Model-change pass (T-0–T-5):** real schema changes from a design review, not corrections — drop `space_facilities` entirely (its key pair is a stored projection of `facility_assets`, not a normal-form matter), replace `user_accounts.role` with a `user_roles(user_id, role)` junction (a cardinality correction, not a normalization fix), strengthen the D-1 justification with semantic framing and a rejected two-table alternative, replace the `space_facility_requirements` (D-2) rationale with the real reason (a required-facility policy must be expressible at zero units), and recompute every table/relation/index count from scratch. Required two more `AGENTS.md` amendments (§1b, §1c).

## Files created / changed

- `AGENTS.md` — added §1a (pass 1: `facilities` drop), §1b and §1c (pass 5: `space_facilities` drop, `user_accounts.role` drop); updated §1 and §3 wording from "the one documented exception" to "the documented exceptions below (§1a–§1c)".
- `outputs/08-requirement-change-analysis-G08.md` — rewritten across all five passes (§1.2–1.6, §2 and all subsections including new §2.3c, §3, §4.1–4.6, §6 traceability matrix, §7 open questions, §8 checklist); gained a new **Appendix A — Revision Notes** with four review-pass tables (D-1..D-3/L1-L20 relevant subset, R2/R4/R7, S1-S3/T-0..T-5).
- `outputs/09-updated-erd-and-logical-design-G08.md` — rewritten across all five passes (§1–§13 essentially in full: executive summary, both conceptual ERDs, the logical schema diagram, the full table-by-table schema, the derived view, the business-rule table, the formal 3NF validation, concurrency notes, indexing strategy, edge-case table, traceability, checklist); gained the parallel **Appendix A — Revision Notes** covering all D-/L-/R-/T- IDs relevant to this document, plus new §2.3-equivalent content: §5.4 (facilities removal notice), new §5.5 (space_facilities removal notice, replacing its former table definition), new §5.17 (`user_roles`), new §8.10/§8.11 (3NF proofs for `user_accounts`/`user_roles`, replacing the former `space_facilities` proof).
- `docs/audits/60-output08-09-facilities-drop-and-model-review-audit.md` — this audit.
- Not modified: `outputs/01`–`07` (Phase 1 baseline, untouched throughout); `outputs/10-schema-migration-G08.sql` (explicitly out of scope for every pass — see Risks/caveats, this file does not currently exist on disk); no skill/command/code files.

## What was evaluated

- Every pass against `AGENTS.md`'s baseline-preservation rule (§1), documented-exception mechanism, and the mandatory-audit policy (§8) — pass 1 and passes 2–5 explicitly waived per-pass audits at the user's direction; this audit records the cumulative session as a single retrospective entry per the template's intent.
- Internal consistency of every table/relation/index/entity count across both documents after each schema change (`facilities` drop → `space_facilities` restructure → `space_facilities` drop entirely → `user_roles` addition), since two earlier passes in this same session (L3, R5) had already once let a count drift silently.
- Whether every "3NF" / "normalization" claim in the documents actually describes a normal-form argument, versus denormalization, redundancy-removal, or cardinality corrections mislabeled as normalization (the recurring L13/D-2/T-1/T-4 class of defect this session kept finding).
- Whether corrected reasoning (refuted-FD proofs, the space-level/asset-level boundary, the required-facility policy rationale) was preserved in full after the Appendix A relocation, versus merely summarized away.
- SQL Server-only syntax throughout (filtered index predicate grammar, no PostgreSQL constructs) and structural soundness of every CHECK/FK/trigger-invariant introduced or removed.
- Whether the two-table `facility_assets`/`space_facility_requirements` link and the `user_roles` staff-check invariants correctly identify what can and cannot be a `CHECK` constraint (cross-table conditions cannot; several were newly identified in pass 5 as needing Task 10 triggers instead).

## Issues found

**Pass 1 (facilities override):** none beyond the user's own request — the user's original spec attempted to remove `space_id` from `facility_assets` while still requiring a composite FK on `(space_id, facility_name)`, which is physically impossible (a SQL Server composite FK constrains columns that must exist in the child table); `space_id` was kept.

**Pass 2 (D-1..D-3, L1-L20):** an XOR constraint (`CK_maintenance_records_target_xor`) had been added on a false transitive-dependency premise; a fabricated constraint name (`DF_space_facilities_quantity`) was asserted where the real Phase 1 DDL left the default unnamed; an advisory-ack completeness check used `COUNT(DISTINCT...)` instead of set containment (a counterexample: ack'd advisory #1 completed while advisory #2 is newly unacknowledged still passes `1=1`); the `facilities`-flattening decision was mislabeled "3NF-driven" when it is BCNF-to-BCNF denormalization; a `space_facilities` 3NF proof was missing entirely from the formal validation section despite being counted in the executive summary; six ERD notation errors drew nullable FK relationships as mandatory.

**Pass 3 (R1-R8):** a filtered-index predicate used `NOT IN`, which SQL Server's filtered-index grammar does not support; an index keyed on a column that held the same value (`NULL`) in every row of its own filtered set, giving it zero selectivity; twelve cross-references to a section the L13 split had already divided in two; a checklist index count that predated a later index addition; one lingering ERD notation inconsistency; a checklist item crediting a denormalization to "3NF"; one index's documented purpose was served by a different index entirely.

**Pass 4 (structural):** `usp_CompleteBooking` was listed among the procedures required to run the full overlap/impact-level/advisory-ack/required-asset check set — running the required-asset check on check-out could block a user from ending their own session because an unrelated unit broke elsewhere; the auto-approval eligibility test compared `expected_participants <= max_participants` without a NULL guard, so SQL Server's three-valued logic (`x <= NULL` → `UNKNOWN`) would silently disable every uncapped policy instead of treating `NULL` as "no cap"; three passages asserted Task 10's migration script "does not exist yet," when it is (or was, at the time) present in the repository and simply stale; roughly forty inline correction narratives had accumulated across two audit passes, burying the design under "an earlier draft said X" framing.

**Pass 5 (T-0..T-5):** `space_facilities`'s key pair `(space_id, facility_name)` is exactly the distinct projection of `facility_assets` — a stored-derivable fact kept in a second place where it can drift, the same category of redundancy `quantity` removal had already targeted; a naive re-base of `v_space_facility_summary` onto `facility_assets` alone (without `space_facility_requirements`) would silently drop the `total_units = 0, is_required = 1` row that rule R8 exists to detect; `user_accounts.role` being single-valued could not represent a person legitimately holding more than one role; the D-2 rationale for `space_facility_requirements` (sparsity/presence-as-semantics/separable permissions) did not survive scrutiny under any of its three stated reasons; every table/relation/index count needed re-derivation after the second table drop and the `user_roles` addition — one such recomputation (`7 retained + 8 new − 2 dropped`) was itself briefly miscalculated (literally evaluates to 13, not 15, since the 7 already excludes the 2 drops) and caught during this session's own verification sweep before being reported.

## Changes made

**Pass 1:** `facilities` dropped (`AGENTS.md` §1a, authorized); `facility_name` absorbed into `space_facilities`, PK changed to `(space_id, facility_name)`; `facility_assets` linked via composite FK; maintenance XOR logic restated. AGENTS.md §1a added first, per explicit user direction, before the schema edits.

**Pass 2:** `CK_maintenance_records_target_xor` removed and replaced with a refuted-FD 3NF argument (relocated-projector counterexample: the same `asset_id` filed against two different `space_id`s over time refutes `asset_id → space_id`); D-2/D-3 disclosed as [EXTENSION] design decisions with trade-offs rather than implied requirements; the advisory-ack check rewritten as a set-based `NOT EXISTS`; the `facilities` flattening split into new §2.3a (genuine 3NF: `quantity` removal) and §2.3b (denormalization: `facilities` drop) in Output 08; a full `space_facilities` 3NF proof added as new §8.10 in Output 09; L1/L9/L11/L12/L15 and the remaining lettered defects corrected in place; six ERD relationship lines and their cardinality-table rows corrected to nullable notation.

**Pass 3:** I13's filter rewritten from `NOT IN` to two `<>` conjuncts; I11 re-keyed from `(acknowledged_at)` to `(alert_type, created_at)`; twelve `Section 2.3` references repointed to `§2.3a`/`§2.3b`; the index-count checklist line corrected; the last ERD notation fix applied; the 3NF/denormalization checklist item split to match the body; I5's Purpose cell rewritten to the query it actually serves, with an explicit note that the booking-side lookup is a different index's job.

**Pass 4:** `usp_CompleteBooking` removed from the shared-checks procedure list in §9.5, with a new paragraph specifying it runs none of the five checks and why (the core invariant constrains adding overlapping reservations, not removing one); the auto-approval eligibility test rewritten NULL-safe (`max_participants IS NULL OR expected_participants <= max_participants`) in both documents; all "not yet generated" claims replaced with an accurate "exists but is stale, must be regenerated" statement; **Appendix A — Revision Notes** added to both documents, structured as one table per review pass; roughly forty body passages rewritten from "an earlier draft said X, now Y" into present-tense design statements with bare `(Appendix A, ID)` pointers; both quality checklists rewritten to state only what the current design achieves, with the two catch-all "Audit corrections applied" bullets removed (content preserved in the appendix, not deleted).

**Pass 5:** `space_facilities` dropped entirely (`AGENTS.md` §1b) — `facility_assets.space_id` and `space_facility_requirements.space_id` become plain `FK → spaces(space_id)`; `facility_name` becomes an independently `CHECK`-constrained column on each (a stated, accepted maintenance cost: two whitelists to keep in sync manually); `v_space_facility_summary` rebased onto a `UNION` of `facility_assets` and `space_facility_requirements` so the zero-units-but-required row survives; Output 09 §8.1/§8.2 referential-tightness proofs reframed as honestly weaker than the composite FK they replace. `user_accounts.role` dropped, replaced by `user_roles(user_id, role)` (`AGENTS.md` §1c) — new §5.17 in Output 09 (placed at the end of §5 rather than renumbering §5.3–§5.16, which are cross-referenced extensively throughout both documents); four new business rules R13–R16 recording that staff-role checks are now trigger-enforced cross-table invariants, not `CHECK` constraints; new index I18 for the reverse role lookup; new §8.10/§8.11 3NF proofs. D-1 strengthened with semantic framing (an invoice's `shipping_address`-vs-`address` analogy) and a documented, rejected two-table-split alternative. D-2 rationale fully replaced with the real reason (the required-facility policy must be expressible at zero units) and its dependency on rule R8 — itself an unconfirmed team [EXTENSION] — made explicit in Output 08 §7. Every table/relation/index/entity count recomputed and cross-checked: 15 tables (7 retained: 3 modified/4 unchanged, + 8 new), 11 relations in the formal 3NF validation, 18 index rows (17 new + 1 implicit), 15 ERD entities (`SpaceFacility` removed, `UserRole` added). A `### Pass 4 — model changes (T-0–T-5)` section appended to both Appendix A tables, preserving the superseded D-2 rationale, L4's condition-disambiguation text, and L15's composite-FK explanation as historical record rather than deleting them.

## Improvement classification

- Output refinement
- AGENTS.md improvement (three documented baseline-exception amendments: §1a, §1b, §1c)
- Documentation improvement (Appendix A relocation separates revision history from current design; both checklists now state outcomes, not corrections)
- Validation/test improvement (recomputed counts; NULL-safe eligibility test closes a real three-valued-logic defect; filtered-index grammar fix closes a real T-SQL syntax defect)

## Validation commands run

- Repeated grep sweeps (ripgrep) after each pass for: `earlier draft`, `corrected from`, `an earlier version`, `was wrong`/`is wrong` (target: zero outside Appendix A); `[EXTENSION]` occurrence counts (target: unchanged by the Appendix A relocation, since these are substantive disclosures, not revision history); `space_facilities`, `user_accounts.role`, `CK_user_accounts_role`, `FK_facility_assets_space_facility`, `FK_space_facility_requirements_space_facility` (target: no live schema reference survives pass 5, only removal notices / `AGENTS.md` citations / Appendix A rows); `CK_maintenance_records_target_xor`, the lock-ordering rule text, `usp_CompleteBooking`, the NULL-safe `max_participants` form, I13's `<>` predicate, and I11's `(alert_type, created_at)` key (regression checks after every subsequent pass).
- Manual recount of every "N tables / N relations / N indexes" sentence in both documents against the actual table inventories, §8 subsection list, and §10 index table, after pass 5's two schema drops and one addition.
- `git status --short` and `git log --oneline` at the end of the session (see Git status summary).
- `ls` / direct file check confirming whether `outputs/10-schema-migration-G08.sql` is physically present (it is not — see Risks/caveats).

## Validation results

- Zero occurrences of the four forbidden revision-history phrases outside Appendix A in either document.
- `[EXTENSION]` counts unchanged by the Appendix A relocation (26 in Output 08, 22 in Output 09) — confirmed none of the substantive disclosures were accidentally moved out of the body.
- No live schema reference to `space_facilities`, `user_accounts.role`, or either superseded composite-FK name remains in either document's body; all surviving occurrences are removal notices, `AGENTS.md` citations, or Appendix A history.
- All D-1/D-3 regression markers (no XOR constraint, `space_id NOT NULL`, the refuted-FD proof, the lock-ordering rule) and pass-3/pass-4 fixes (`usp_CompleteBooking` exclusion, NULL-safe eligibility test, I13's `<>` predicate, I11's re-keying) remain intact through to the end of pass 5.
- Recomputed counts agree across every section that states them in both documents: 15 tables, 7 retained (3 modified, 4 unchanged), 8 new, 2 dropped, 11 validated relations, 18 index rows, 15 ERD entities.
- The one arithmetic slip introduced during pass 5's own count recomputation (`7 + 8 − 2` literally = 13) was caught by this session's own verification sweep and corrected before the pass was reported complete.

## Risks / caveats

- **`outputs/10-schema-migration-G08.sql` does not currently exist on disk.** `git status` shows it as an unstaged deletion relative to HEAD (last touched in commit `5096cc3`, "fix something in task 9_10"); this predates every pass in this session (confirmed present in the very first `git status` snapshot taken before any edit in this conversation) and was not caused by this work. However, both Output 08 and Output 09 now state throughout — including in dedicated S3 fixes from pass 4 — that the file "exists in the repository but is stale." That claim is currently false in the literal, on-disk sense (true only of the git history / the last commit). Recommend either restoring the file (`git checkout` from `22828e1` or `5096cc3`) so the documents' wording matches reality, or softening the wording to "was previously generated and is stale/superseded" before this is treated as settled. Flagging rather than silently fixing, since restoring a deleted file is a decision for the user, not something to do unilaterally.
- `space_facility_requirements`'s entire existence (and rule R12 with it) is now explicitly downstream of rule R8, which remains an unconfirmed, team-invented [EXTENSION] (Output 08 §7, open question 2). If the TA/lecturer does not confirm R8 as in-scope, this table and R12 should be dropped together — the dependency is now visible rather than buried, but it is not yet resolved.
- The `space_facilities` drop trades a structural guarantee (composite FK) for two independently-maintained `CHECK` whitelists on `facility_assets` and `space_facility_requirements`; nothing enforces that a future facility-type addition updates both. This is disclosed in both documents but is a real, ongoing maintenance burden for whoever writes Task 10's DDL and any later migration.
- Four new staff-role invariants (R13–R16) cannot be `CHECK` constraints and depend entirely on Task 10 implementing the corresponding triggers correctly; until then, the schema does not actually enforce what Output 09 §7 claims.
- No SQL Server execution was run in any pass — these are design documents; all constraint/index/trigger syntax was validated by inspection against SQL Server semantics only, not by executing DDL.
- Two `AGENTS.md` amendments (§1b, §1c) followed the same "authorized by the Senior Lead Architect" pattern as §1a without a separate team sign-off step recorded anywhere outside this document set; if the team wants amendments of this weight (dropping a second Phase 1-adjacent table, dropping a Phase 1 column) to require broader review, that process should be added to §1's amendment mechanism itself.

## Git status summary

```
 M AGENTS.md
 M outputs/08-requirement-change-analysis-G08.md
 M outputs/09-updated-erd-and-logical-design-G08.md
 D outputs/10-schema-migration-G08.sql
?? PROMPT-fix-task08-09-pass2.md
?? PROMPT-fix-task08-09-pass3.md
?? PROMPT-fix-task08-09-pass4.md
?? PROMPT-fix-task08-09.md
```

- The `outputs/10-schema-migration-G08.sql` deletion predates this session (see Risks/caveats) and was not made by this work.
- The four untracked `PROMPT-fix-task08-09*.md` files appear to be the user's saved prompt text for each pass; not created or modified by this audit.
- No commit requested; nothing committed. `git log` shows the most recent commits as `5096cc3` (fix something in task 9_10) and `22828e1` (Task 10 schema migration implementation) — i.e., Task 10 work was committed *before* this session's Output 08/09 corrections, which is exactly why it is now stale.

## Recommended next steps

- Resolve the `outputs/10-schema-migration-G08.sql` discrepancy (restore vs. reword) before anyone reads Output 08/09's S3 claims at face value.
- Regenerate Task 10's migration script from Output 08/09 as they now stand — it must additionally reflect the pass-5 model changes (`space_facilities` drop, `user_roles` addition, the four new trigger-enforced staff-role invariants) on top of everything the pre-existing script already needed to catch up on.
- Get the R8 ("required" facility semantics) confirmation from the TA/lecturer (Output 08 §7, open question 2) — this now gates two tables and one business rule, not a peripheral detail.
- Team review of both documents (owner: Lead Architect; reviewers per `AGENTS.md` §7) before Task 10 implementation begins, given the volume of change across five passes in one session.
- Consider whether `AGENTS.md`'s amendment mechanism (§1a–§1c) needs an explicit team-sign-off step for future baseline exceptions, given two more were added in this session alone.
