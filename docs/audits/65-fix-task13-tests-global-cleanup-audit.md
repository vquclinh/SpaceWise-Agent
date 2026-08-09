# Audit — Fix Task 13 Test Suite: Date-Dependency + Cleanup + README

> Date: 2026-08-09
> Operator/member: (task owner to confirm)
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: none (manual prompt)

## Task goal

Fix the three structural/date-dependency defects flagged in the recent Task 13
evaluation of `outputs/13-concurrency-tests-G08/`:

1. **`04-early-checkout-verification.sql`** — remove the hard-coded
   `'2026-08-10'` dates. `usp_CompleteBooking` writes
   `actual_end_time = GETDATE()`, and `CK_usage_sessions_end_time` requires
   `actual_end_time > actual_start_time`, so all windows must be derived from
   `GETDATE()` (`actual_start_time < GETDATE()` always true).
2. **Create `99-cleanup.sql`** — global, FK-safe cleanup restoring the
   pristine post-migration state (deletes all `T13-`-tagged seed + race data,
   children before parents).
3. **Create `README.md`** — mandatory index (files `00`–`99`), prerequisites
   (Tasks 05/06/10/12), the dual-window SSMS methodology with the 5–6 s
   `WAITFOR DELAY` calibration, an "Expected outputs" section (Error 1205 /
   Error 50001), and the final `99-cleanup` step before Task 14.

## Files created / changed

- `outputs/13-concurrency-tests-G08/04-early-checkout-verification.sql` — **rewritten** (date-independent windows).
- `outputs/13-concurrency-tests-G08/99-cleanup.sql` — **created**.
- `outputs/13-concurrency-tests-G08/README.md` — **created**.
- `docs/audits/65-fix-task13-tests-global-cleanup-audit.md` — this audit.
- **Not modified:** `00`–`03` race/seed files, `outputs/08`–`12`, `AGENTS.md`,
  `.opencode/skills/*` (read-only for this task).

## What was evaluated

- The three flagged defects against the actual scripts: the hard-coded dates in
  `04`; the absence of a global cleanup; the absence of a README.
- The schema side-effects that make dates load-bearing:
  - `usp_CompleteBooking` (`outputs/12`) writes `actual_end_time = GETDATE()`;
    `CK_usage_sessions_end_time` (Phase 1 `outputs/05`) requires
    `actual_end_time > actual_start_time`.
  - The conflict filter is status-driven: only `Approved`/`CheckedIn` block
    (`OUTPUTs 12` procs), so `Completed` releases instantly.
- The full FK graph in `outputs/10-schema-migration-G08.sql` and
  `outputs/05-db-definition-G08.sql` to build a correct child-before-parent
  delete order (bookings children: `booking_decisions`, `usage_sessions`,
  `booking_alerts`, `booking_advisory_acknowledgments`; maintenance children:
  `booking_alerts`, `booking_advisory_acknowledgments`,
  `maintenance_impact_history`; spaces children: bookings, maintenance,
  policies, `facility_assets`, `space_facility_requirements`; users children:
  `user_roles` and every booking/maintenance/decision/session/alert/ack row).
- The `T13-` marker convention actually used by `00`–`04` (purpose prefix,
  `t13.*` emails, `T13-T-*` space codes, `'T13 Race C advisory'`
  problem_description) to pick non-colliding delete keys.

## Issues found

1. **`04` hard-coded `'2026-08-10 ...'` literals.** Once that anchor passes (or
   before it), the demo's `actual_start_time` is not guaranteed `< GETDATE()`;
   since `usp_CompleteBooking` stamps `actual_end = GETDATE()`, a future
   `actual_start_time` would violate `CK_usage_sessions_end_time` at check-out.
2. **No global cleanup script.** After the races, `T13-*` rows (including
   `booking_alerts`/`maintenance_impact_history` written by the escalation
   triggers, and `booking_decisions` written by the procedures) would pollute
   Task 14's data generation.
3. **No README** to lock the mandatory run order / methodology / expected
   outcomes for reviewers and the demo.

## Changes made

- **`04`**: replaced all `'2026-08-10 ...'` literals with a single
  `@now = GETDATE()` anchor and `DATEADD`-derived windows: primary reservation
  `GETDATE()-1h → GETDATE()+2h`, check-in `GETDATE()-30min`, leftover probe
  `GETDATE()-20min → GETDATE()+30min` (strictly inside the reserved window).
  PRINT steps now echo the derived times; the Step 2/4 proc calls pass the
  derived variables instead of literals. All other logic (pre-flight cleanup,
  5 steps, summary query) unchanged.
- **`99` (new)**: wrapped in one transaction with TRY/CATCH+ROLLBACK; deletes
  in FK-safe order:
  1) `booking_alerts`, `booking_advisory_acknowledgments` (by T13 booking_id
     OR T13 maintenance_id) → 2) `usage_sessions`, `booking_decisions` →
  3) `maintenance_impact_history` → 4) `policy_booking_types` →
  5) `auto_approval_policies` → 6) `bookings` → 7) `maintenance_records` →
  8) `facility_assets`, `space_facility_requirements` → 9) `user_roles` →
  10) `spaces` → 11) `user_accounts` → 12) `departments`.
  Deletion keys are the stable `T13-` markers only (purpose, space_code,
  `t13.`/`T13.` email, `'T13 …'` problem_description, exactly
  `'T13 Test dept'`), so Phase 1/06 data is untouched. Ends with a marker-count
  verification `SELECT` (all zeros) and prints per-table `@@ROWCOUNT`.
- **`README` (new)**: file index (`00`–`99`), prerequisites ordered
  (05 → 06 → 10 → 12 → 00), dual-window methodology table for `01`/`02`/`03`,
  WAITFOR DELAY calibration note (~5 s baseline / ~6 s prevention), expected
  outputs per part (both-Approved flaw in Part A; single Approved + `50001`
  or retryable `1205`/`1222` in Part B; Race C `50002` or `booking_alerts`
  branch; `04` Step 2 rejected / Step 4 approved), and the mandatory
  `99-cleanup.sql` step before Task 14.

## Improvement classification

- **Output refinement**
- **Validation/test improvement** (date-independent, re-runnable assertions;
  deterministic cleanup; documented expected outputs)

## Validation commands run

- Grep for forbidden PostgreSQL constructs (`tsrange`, `EXCLUDE USING`,
  `btree_gist`, `GIN`, `DEFERRABLE`, `SET LOCAL`, `'infinity'`) across
  `00`–`99` + README — **no matches** (the `GIN`/`BEGIN` false positive was
  re-checked with a word-boundary scan).
- Grep for residual `2026-` literals in `04` — **none remain**.
- Grep that every purpose/space_code/email key used by `99` matches the
  marker shapes actually inserted by `00`–`04`.
- Manual FK-order review of each `99` DELETE against the constraint list in
  `outputs/10` and `outputs/05`.
- `Get-ChildItem` on the folder — now exactly 7 files (`00`–`04`,
  `99-cleanup.sql`, `README.md`); expected names present.

## Validation results

- `04` is now fully date-independent; `actual_start = GETDATE()-30min < now`
  holds on any run, so `CK_usage_sessions_end_time` (actual_end > actual_start)
  is guaranteed when `usp_CompleteBooking` stamps actual_end with a later
  `GETDATE()`.
- `99` delete parents last; a failure anywhere rolls back cleanly and rethrows.
  Idempotent (second run is a no-op).
- `README` covers all three evaluation requirements (index, prerequisites,
  dual-window methodology + timing, expected outputs, final cleanup step).
- **No live DB execution** — verified by static review only (no SQL Server
  available in this session).

## Risks / caveats

- Still **not executed against a live SQL Server**; the 5–6 s race windows and
  actual lock/deadlock outcomes (1205 vs 50001 vs both-Approved baseline) must
  be confirmed on the team's SQL Server 2016 SP1+/Azure SQL instance.
- `99` deletes the seeded `'T13 Race C advisory'` record by
  `problem_description LIKE N'T13 %'` (the seed shape) plus any maintenance row
  whose `space_id` is a `T13-T-*` space — intentionally broadened so a manually
  added T13 maintenance row cannot block the `spaces` delete; no Phase 1/06
  record matches either predicate.
- If a tester manually attached non-T13 users or rows to the `'T13 Test dept'`,
  the department `DELETE` would fail and roll back (safe, loud) rather than
  silently delete real data.

## Git status summary

```
?? outputs/13-concurrency-tests-G08/  (00–04 + new 99-cleanup.sql + README.md)
?? docs/audits/65-fix-task13-tests-global-cleanup-audit.md
```

- No commits requested or made.

## Recommended next steps

- Confirm `04` and `99` on the team SQL Server during the Task 13 demo capture
  (capture the actual error numbers / row counts into the results note per the
  `outputs/13-concurrency-tests-G08/` deliverable).
- Run `99-cleanup.sql` and verify the 0-remaining marker `SELECT` before
  starting Task 14 (`outputs/14-data-generator-G08.sql`).
- Consider a follow-up skill note (future task): every Task 13 verification
  script that touches `GETDATE()`-dependent procedures should anchor its
  windows with `DATEADD` from a single `GETDATE()` snapshot, and a `99-*`
  cleanup + README should be mandatory in any multi-script test deliverable.