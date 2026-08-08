# Audit — Task 13 Concurrency Tests Generation

> Date: 2026-08-09
> Operator/member: (task owner to confirm)
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: `/13-concurrency-tests`

## Task goal

Execute the **Concurrency Tests (Task 13)** phase of the Phase 2 database pipeline: generate `outputs/13-concurrency-tests-G08/` — a directory of dual-window SSMS scripts that demonstrate the Phase 1 concurrency flaw and its Phase 2 prevention — from the Task 13 skill (`.opencode/skills/db-design-pipeline/13-concurrency-tests/SKILL.md`), and record the run under the repository audit policy (AGENTS.md §7/§8).

## Files created / changed

- `outputs/13-concurrency-tests-G08/00-setup-test-data.sql` — **created** (idempotent seed: test dept/users/roles, two spaces, auto-approval policy + allowed types, Pending booking pairs, Race-C Advisory maintenance + ack).
- `outputs/13-concurrency-tests-G08/01-race-A-double-approval.sql` — **created** (manual vs. manual double approval; Part A trigger-only baseline, Part B `usp_ApproveBooking` prevention).
- `outputs/13-concurrency-tests-G08/02-race-B-instant-vs-manual.sql` — **created** (`usp_CreateBookingAutoApproved` instant path vs. manual approval; Part A raw baseline, Part B prevention).
- `outputs/13-concurrency-tests-G08/03-race-C-approval-vs-escalation.sql` — **created** (approval vs. `Advisory`→`OutOfService` escalation; Part A raw baseline, Part B lock-ordering prevention + `booking_alerts` check).
- `outputs/13-concurrency-tests-G08/04-early-checkout-verification.sql` — **created** (single-window self-driving: CheckedIn blocks window; `usp_CompleteBooking` releases the remainder immediately).
- `docs/audits/64-task13-concurrency-tests-generation-audit.md` — this audit.
- **Not modified:** `outputs/08`, `09`, `10`, `11`, `12`, `14`, `15`, `16`; `AGENTS.md`; `.opencode/skills/db-design-pipeline/SKILL.md`; `.opencode/skills/db-design-pipeline/13-concurrency-tests/SKILL.md` (read-only, per the safety constraint — skill improvements recorded as recommendations only).

## What was evaluated

- **Inputs read (per command spec):**
  - `.opencode/skills/db-design-pipeline/13-concurrency-tests/SKILL.md` — required files, dual-window methodology, self-review requirement.
  - `outputs/11-concurrency-design-G08.md` — §II (the four identified race conditions: double approval, instant-vs-manual, approval-vs-escalation, early check-out), §V (traceability), §VI (contracts C1-C7).
  - `outputs/12-concurrency-implementation-G08.sql` — the four procedures under test and their exact parameter signatures and error codes.
  - `outputs/10-schema-migration-G08.sql` — the trigger backstops (`TR_bookings_PreventOverlapAndUnavailable`, `TR_maintenance_escalation`, staff-role triggers R13-R16), the filtered index I1, and the Phase 2 tables the seed writes to.
  - `req/business-requirement-P2.md` — §4 concurrency invariant, §7 advisory acknowledgement.
  - `AGENTS.md` — §5 (Phase 2 technical rules), §7 (task placeholders not production-ready — confirm the 13 skill exists), §8 (audit policy).
- **Generation:** one seed file + four race/verification files, each drill's dual-window sections (Session A / Session B) with `WAITFOR DELAY` collision forcing, a baseline (trigger-only flaw) and a prevention (serialized contract) path, reset/verify blocks, self-contained variable declarations per batch, and per-file `HOW TO RUN` instructions.

## Issues found (generation time)

1. **First-draft prose artifacts** in all five files — garbled fragments (stray `de-`/`de-` in the Session A commented COMMIT, an odd `stet|item` summary alias in the seed, leftover `usp_ApproovalBooking` free text in initial versions of file 01, stray `orders/hold` tokens). All cleaned by targeted edits.
2. **Scope mismatch in seed vs. Race C data.** First version of the setup inserted the audit/maintenance rows without the `impact_level = N'Advisory'` and `asset_id = NULL` columns (only the problem_description/status fields were originally slotted against the post-migration named columns), and before that draft tailor the seed book used the role phrase on `user_accounts`. Accepted: `00-setup` inserts into `user_roles` (removed by §1c) and the maintenance insert is fully qualified to the Phase 2 `maintenance_records` column set.
3. **Enum spelling / table name typos** in file 02 — `Purchase`→`ProjectWork` (booking_type), `ORDERs BY`→`ORDER BY`; eliminated.
4. **Garbled fragments in file 04 first draft** — `DECL @b2 INT`/`@req_b`/`@staff_fm` mismatches and a half-baked `T13-ECO-POSTE` scenario; rewrote from scratch.
5. **Prevention text mismatch with the escalation contract.** Earlier file 03 comment claimed the escalation "THROWs 50002" — wrong: the design id-rewrites-not-rewrites (Task 11 A.2); the escalation path succeeds and the trigger writes `booking_alerts` rows, while `50002` is thrown on the approval side when an existing OutOfService window blocks. Comments corrected to reflect both legal branches.

## Issues found (self-review pass)

6. **T-SQL variable scoping across `GO`.** Files 02 and 03 declared look-up variables at the top, then used them in later batches after a `GO` — SQL Server raises "must declare the scalar variable" because local variables live only until the batch's `GO`. Each batch was made self-contained (its own `DECLARE`s directly before the code that uses them, one set per VERIFY/RESET/PREVENTION block).
7. **`usp_ForceEscalateMaintenance` typo** in file 03's Part B header comment (the real name is `usp_EscalateMaintenance`).
8. **Race-A baseline timing.** The first raw-approval draft held the `WAITFOR DELAY` before the `UPDATE`, so the trigger's second-side probe might see the other session's committed row and the double-booking would not reproduce. Moved the delay to *after* the UPDATE (the transaction holds its uncommitted `Approved` row for ~5 s, giving the other window a wide beam to "win" the same slot) — matches the intended READ COMMITTED race making the second approval see nothing.
9. **File 02 RESET wrong target.** The first RESET cancelled *both* rows including `T13-B-BOOKING-MANUAL`, which Part B needs in `Pending` (usp_ApproveBooking rejects non-Pending). Split: instant raw row retired to Cancelled, manual booking restored to Pending.

## Changes made

- Created the five deliverables (see Files created) with:
  - `00-setup-test-data.sql` — guarded/idempotent INSERTs inside one transaction; users via `user_roles` (not a dropped role column); auto-approval policy + allowed booking types incl. `ProjectWork`; seed bookings all `Pending`, tags `T13-*`; Advisory maintenance with acknowledgement for Race C; final summary SELECT.
  - `01-race-A-double-approval.sql` — Session A/B baseline with AFTER the post-delay raw UPDATE; PREVENTION via `usp_ApproveBooking` in a test-harness outer transaction keeping the proc's range lock alive; TRAP/VERIFY/RESET blocks; error 50001/1205/1222 expectations documented.
  - `02-race-B-instant-vs-manual.sql` — raw auto path (Pending→System decision→Approved) vs. raw manual approval for the seeded manual booking; RESET logic fixes; prevention via `usp_CreateBookingAutoApproved` + `usp_ApproveBooking` under the outer-harness lock.
  - `03-race-C-approval-vs-escalation.sql` — raw escalation baseline; PART B via `usp_ApproveBooking` and `usp_EscalateMaintenance` (correct order `bookings` range first); alert-row verification; corrected expected-result comment (both legal branches: 50002-on-approval or `booking_alerts` on escalation).
  - `04-early-checkout-verification.sql` — pre-flight cleanup of its own run-time `T13-ECO-%` rows, Step 1 create/approve/checkin, Step 2 blocked request, Step 3 `usp_CompleteBooking`, Step 4 the released window re-approves, Step 5 summary.

## Improvement classification

- **Output refinement** (the deliverables themselves)
- **Validation/test improvement** (seed, RESET and timing design so the tests are deterministic/re-runnable)
- **SKILL.md improvement** (recommendation only — see Risks: make each race file self-contained per batch and put the raw `WAITFOR DELAY` after the first UPDATE in the baseline)

## Validation commands run

- Grep across the deliverable for forbidden PostgreSQL constructs (`tsrange|EXCLUDE|btree_gist|GIN|DEFERRABLE|SET LOCAL|'infinity'`) — none.
- Grep for procedure/parameter names matching Task 12 (`usp_ApproveBooking`, `usp_CreateBookingAutoApproved`, `usp_EscalateMaintenance`, `usp_CompleteBooking`, their signature parameters, error numbers 50001/50002/50009/50030-50032).
- Grep for leftover artifacts (`de-|Purchase|ORDERs|@booking_auto_out|UXsp_ForceEscalate|stet`) — none remain.
- Grep for `DECLARE ... = (SELECT` check that every variable is declared in the same batch as its use (manually reviewed `GO` boundaries in each file).
- Grep the seed enum values vs the schema constraints (`booking_type`, `problem_category`, status values, `impact_level`, `decision_source`) against Outputs 05/09/10.
- `Get-ChildItem` size/name check — exactly the 5 required files exist in `outputs/13-concurrency-tests-G08/`.

## Validation results

- All five files present with the exact required names.
- No `PostgreSQL`-only constructs; everything is SQL Server 2016 SP1+ T-SQL.
- Every batch is now self-contained; no cross-`GO` variable references remain.
- The procedure calls match the Task 12 signatures and error model; the seed writes only to post-migration Phase 2 columns.
- Baseline vs Prevention separation per file is structurally present (Part A raw / Part B via the stored procedures), and Run/Verify/Reset order is documented in each header.
- No live DB execution — validated by static review only (no SQL Server available in this session).

## Risks / caveats

- **Not executed against a live SQL Server.** These runs can only be proven on the team's SQL Server 2016 SP1+ (or Azure SQL) — the actual locking/deadlock/timing behavior (1205 vs 50001 vs both-success) depends on engine behavior and is the point of the test. The scripts print outcomes; manual interpretation of the expected branch is documented in each header.
- **Timing sensitivity of the baseline parts.** The raw-approval and raw-escalation baseline paths are only as deterministic as the 5-6 s windows; a very fast second session can occasionally slip first. This is inherent to the "demonstrate the race" design and the docs say so.
- **Index prerequisite.** The full key-range semantics require I1 (`IX_bookings_space_status_time`) from Task 10; the seed script documents that prerequisite.
- **Role/seed dependency.** The seed must run once before the race files; the race files also tolerate being re-run after their own RESET blocks.
- **AGENTS.md §7 placeholder caveat:** Task 13 command/skill exist; their correctness for this run is part of the audit, and no attempt to regenerate the stale Task 10 was made (out of scope).

## Git status summary

```
?? outputs/13-concurrency-tests-G08/
?? docs/audits/64-task13-concurrency-tests-generation-audit.md
```

- The directory `outputs/13-concurrency-tests-G08/` (the 5 SQL files) and this audit are the new artifacts from this run (untracked).
- Pre-existing untracked items from the Task 11/12 phase remain: `.opencode/commands/11-…`, `12-…`, `13-…`; skills 11/12/13 folders; audits 62/63; outputs 11/12.
- No commits requested or made.

## Recommended next steps

- Team review of the five files against Task 11 §II/§VI contracts (owner: lead; reviewers per AGENTS.md §7).
- Apply the skill improvements (recommendation): keep every batch self-contained (its own `DECLARE`s before use); put the baseline `WAITFOR DELAY` after the `UPDATE` so the opposing window sees nothing committed; mirror the exact Task 12 procedure names (`usp_EscalateMaintenance`, not a fabricated `ForceEscalate` variant) in the skill templates.
- Run the scripts against the team SQL Server during Task 13's demonstration, capture the actual 1205/1222/50001/50002/booking_alerts results into a results file (per the `outputs/13-concurrency-tests-G08/` requirement).
- Proceed with Task 14 (data generator) once the seed/test harness is confirmed on the server.