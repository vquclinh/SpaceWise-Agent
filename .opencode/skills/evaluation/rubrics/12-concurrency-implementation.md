# Rubric: 12-concurrency-implementation-G<Group#>.sql

Phase 2 — specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions).

## Source of truth
Grade against:
- `11-concurrency-design-G<Group#>.md` — every mechanism, lock scope, and
  demonstration plan described there must be faithfully implemented here.
- `10-schema-migration-G<Group#>.sql` — the post-migration schema is the execution
  environment; all table/column names must match it exactly.
- Phase 2 requirement section 1.2 — the guarantee that must hold: two approved bookings
  cannot use the same space during overlapping periods, under any concurrent execution.

## Execution environment
This script runs against the fully migrated database (Phase 1 DDL + Phase 1 data +
task 10 migration). It must not re-create tables or re-run migration steps. If it does,
classify as blocker severity — the script is not self-aware of its execution context.

## How to grade (mechanical step first)
Concurrency scripts cannot be fully validated by reading alone. The grading process is:
1. Stand up the migrated database (tasks 05 + 06 + 10).
2. Run the "conflict demonstration" script (see criterion 2) — confirm the conflict
   occurs as described in task 11.
3. Apply the fix (criterion 3) — stored procedure, trigger update, isolation level change,
   or schema change as specified.
4. Run the "fix demonstration" script (criterion 4) — confirm the conflict no longer
   occurs or is correctly handled.
5. Document which steps you executed and what outcomes you observed.

If live execution is not possible, manually trace the scripts' logic against the schema and
state this limitation explicitly in the eval output.

---

## Criteria

### 1. Consistency with task 11 design (weight: high)
Every mechanism specified in task 11 must appear in the implementation:
- If task 11 specified `WITH (UPDLOCK, HOLDLOCK)` on the availability read — verify the
  exact hint appears on the correct SELECT statement inside a transaction.
- If task 11 specified `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` — verify it
  appears at the correct scope (session or transaction level) and is reset afterward.
- If task 11 specified optimistic locking with a `version` column — verify the
  read-version → compare-on-write pattern is implemented, and the mismatch case
  (retry or error) is handled.

Deviation from task 11 without an explanatory comment is a major inconsistency. If the
deviation is an improvement (e.g. the group realized the design needed refinement),
reward the improvement but flag the undocumented change.

### 2. Conflict demonstration script (weight: high)
Must include a script that provably demonstrates the conflict occurring **without** the
fix in place. Minimum requirements:
- Uses two explicit sessions or simulates interleaving via `WAITFOR DELAY` or a
  multi-step transaction sequence that clearly shows the read-before-write gap.
- Inserts or updates data such that the undesirable outcome (two approved bookings
  on the same space in the same time slot) is the result when the script completes.
- Ends with a SELECT that shows the conflicting rows — the output must make the
  conflict self-evident to a grader reading the results, not just inferrable.
- Includes comments labeling each step (e.g. `-- Session A: read availability`,
  `-- Session B: read availability`, `-- Session A: write booking`, `-- Session B:
  write booking -- conflict occurs here`).

Common shortcut to flag: a script that simply inserts two overlapping bookings directly
without simulating the read-check-then-write sequence — this does not demonstrate a
concurrency conflict, it demonstrates that the trigger can be bypassed, which is a
different (and Phase 1) problem.

### 3. Fix implementation (weight: high)
The fix must be implemented as one of:
- A stored procedure encapsulating the availability check and booking write in a single
  atomic unit with the appropriate lock hint or isolation level.
- An update to the Phase 1/Phase 2 trigger adding a locking mechanism around the
  conflict-prone read.
- A session-level or transaction-level isolation change applied consistently to all
  booking-approval code paths.

Verify:
- **Both booking paths covered**: the fix must apply to both instant-booking submission
  and staff-approval. If the stored procedure or trigger only wraps one path, the other
  remains vulnerable — classify as blocker severity since the requirement explicitly
  names both paths.
- **Lock acquired before the read, not after**: the lock hint or isolation level must be
  set before the availability SELECT executes. A lock acquired after the read is
  semantically too late.
- **Transaction boundary is explicit**: the fix must use a `BEGIN TRANSACTION` /
  `COMMIT TRANSACTION` (or `ROLLBACK`) block. An implicit transaction does not
  provide the correct scope.
- **Error handling**: if the fix detects a conflict (trigger fires, version mismatch, or
  deadlock), it must surface a meaningful error message and roll back cleanly. A silent
  rollback with no error is insufficient — the caller must know the booking failed and why.

### 4. Fix demonstration script (weight: high)
Must include a script that runs the same scenario as criterion 2 but with the fix in place,
and produces a different, correct outcome. Minimum requirements:
- Same space, same time slot, two concurrent sessions or interleaved steps.
- One booking succeeds; the second is blocked, rolled back, or rejected with an error.
- Ends with a SELECT showing only one approved booking for the time slot — the fix's
  correctness must be self-evident from the output.
- If the fix causes the second session to block (pessimistic) rather than immediately
  fail (optimistic), the script must show the blocking behavior and then show the result
  after the first session commits (second session either proceeds with a clean slot or
  receives an error).

### 5. Escalation race (weight: medium)
If task 11 identified the escalation race (advisory → out-of-service while a booking is
being approved for the same space and period), the implementation must include:
- A demonstration of the race scenario.
- A fix — either the maintenance-escalation write acquires the same lock as the
  booking-approval write (ensuring they serialize), or the booking trigger re-checks
  maintenance impact level after acquiring its lock, so an escalation that commits
  before the booking write is caught.

If task 11 did not identify the escalation race, this criterion is not penalized — but note
its absence as an inherited gap from task 11.

### 6. Deadlock handling (weight: medium)
If task 11 identified deadlock risk (as it should), the implementation must include:
- Consistent lock ordering across all stored procedures / code paths that acquire
  multiple locks (e.g. always lock by `space_id` ascending when booking multiple
  spaces).
- A deadlock retry block or error handler for SQL Server error 1205:
  ```sql
  IF ERROR_NUMBER() = 1205  -- deadlock victim
      -- retry logic or informative error to caller
  ```
- A comment explaining the deadlock scenario and why the ordering/retry prevents it.

If task 11 did not discuss deadlocks, flag the absence here as an inherited gap and
deduct under this criterion regardless — implementation-stage discovery of a deadlock
risk is better than not discovering it at all, but it should have been in the design.

### 7. Transaction isolation correctness (weight: high)
Regardless of the mechanism chosen, verify that the transaction isolation level used is
both necessary and sufficient:
- **READ COMMITTED** (SQL Server default): insufficient — does not prevent lost updates
  or phantom reads in the booking conflict scenario. Flag as blocker if this is the only
  isolation applied.
- **REPEATABLE READ**: prevents lost updates (another session cannot update a row
  you have read) but does not prevent phantom inserts (a new booking row inserted by
  another session is not locked). Marginally insufficient for the booking conflict since
  the conflict involves inserting new rows, not updating existing ones.
- **SERIALIZABLE**: correct for this scenario — prevents phantom reads/inserts by
  range-locking the result set of the availability check. Flag if the group claims
  REPEATABLE READ is sufficient without explaining the phantom-insert risk.
- **SNAPSHOT isolation**: acceptable alternative — readers don't block writers and vice
  versa; conflicts detected at write time via version checking. Valid but must be enabled
  at the database level (`ALTER DATABASE ... SET ALLOW_SNAPSHOT_ISOLATION ON`);
  verify this enablement statement is present if snapshot is chosen.
- **Lock hints (`WITH (UPDLOCK, HOLDLOCK)`)**: effectively equivalent to serializable
  for the locked rows — correct if applied before the availability read.

### 8. Code quality and comments (weight: low)
- Every non-obvious statement is commented, especially lock hints and isolation level
  settings (a future developer must understand why these are here).
- Scripts are divided into clearly labeled sections: setup, conflict demo, fix
  implementation, fix demo, cleanup.
- Cleanup section (or comment) explains how to reset the database to a known state
  after running the demo scripts — important since the scripts insert test data that
  would otherwise pollute the Phase 2 sample dataset.
- `GO` batch separators used correctly throughout (consistent with Phase 1 and
  task 10 conventions).

---

## Scoring guidance
- Conflict demo, fix implementation, and fix demo (criteria 2, 3, 4) ~50% combined —
  these are the core deliverables; a submission missing any one of them earns at most
  2/5 overall regardless of design quality.
- Transaction isolation correctness and task-11 consistency (criteria 7 & 1) ~25%
  combined — the most technically demanding checks; READ COMMITTED as the only
  isolation mechanism is a blocker.
- Escalation race and deadlock handling (criteria 5 & 6) ~15% combined — secondary
  but meaningful; their absence should be traced back to whether task 11 identified them.
- Code quality (8) ~10%.

## Common failure patterns to watch for
- Conflict demo inserts two overlapping rows directly without simulating the
  read-check-then-write race — demonstrates INSERT without trigger enforcement, not a
  concurrency conflict.
- Fix wraps only the instant-booking path; staff-approval path left unprotected — the
  requirement explicitly requires both paths to be safe.
- `BEGIN TRANSACTION` used without specifying isolation level, defaulting to READ
  COMMITTED — does not prevent the conflict; blocker severity.
- Fix demo shows the second booking is rejected but does not show a SELECT confirming
  only one approved booking remains — incomplete proof of correctness.
- No cleanup section — subsequent tasks (data generation, query design) run against a
  database polluted with test conflict data.
- `WAITFOR DELAY` used to simulate concurrency but the delay is so short (e.g. 1ms)
  that the demo is not reliably reproducible — flag as a minor issue affecting
  reproducibility of the test.
- Deadlock error 1205 not handled — if the fix uses pessimistic locking, deadlock is
  possible and the script will crash ungracefully without a handler.