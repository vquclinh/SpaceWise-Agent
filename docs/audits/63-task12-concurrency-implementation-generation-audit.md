# Audit — Task 12 Concurrency Implementation Generation

> Date: 2026-08-09
> Operator/member: (task owner to confirm — assumed Senior Lead Database Architect & Concurrency Expert per Task 11 role)
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: `/12-concurrency-implementation`

## Task goal

Execute the **Concurrency Implementation (Task 12)** phase of the Phase 2 database pipeline: generate `outputs/12-concurrency-implementation-G08.sql` from the Task 12 skill (`.opencode/skills/db-design-pipeline/12-concurrency-implementation/SKILL.md`), the Task 11 concurrency design C1-C7 contract (`outputs/11-concurrency-design-G08.md`), and the Phase 2 requirements — and record the run under the repository audit policy (AGENTS.md §7/§8).

## Files created / changed

- `outputs/12-concurrency-implementation-G08.sql` — **created** (the only output touched; the Task 12 deliverable).
- `docs/audits/63-task12-concurrency-implementation-generation-audit.md` — this audit.
- **Not modified:** `outputs/08`, `09`, `10`, `11`, `13`, `14`, `15`, `16`; `AGENTS.md`; `.opencode/skills/db-design-pipeline/SKILL.md`; `.opencode/skills/db-design-pipeline/12-concurrency-implementation/SKILL.md` (read-only, per the task's safety constraint — skill improvements are recorded as recommendations only).

## What was evaluated

- **Inputs read (per command spec):**
  - `.opencode/skills/db-design-pipeline/12-concurrency-implementation/SKILL.md` — required procedures and implementation rules.
  - `outputs/11-concurrency-design-G08.md` — §III (SERIALIZABLE + `WITH (UPDLOCK, HOLDLOCK)` key-range locking as the primary mechanism) and §VI (implementation contract C1-C7, incl. the mandatory lock order `bookings -> maintenance_records -> booking_alerts` and the retry-on-1205/1222 model).
  - `outputs/09-updated-erd-and-logical-design-G08.md` — §5 column definitions, enum values, index I1, and the early-check-out interval rule.
  - `outputs/10-schema-migration-G08.sql` — the Task 10 triggers that fire on the procedure UPDATEs as validation backstops.
  - `outputs/05-db-definition-G08.sql` — Phase 1 baseline column names.
  - `req/business-requirement-P2.md` — §4 concurrency invariant, §7 advisory acknowledgements.
- **Generation:** the four required procedures — `usp_ApproveBooking` (manual staff path), `usp_CreateBookingAutoApproved` (instant/auto path), `usp_EscalateMaintenance` (advisory -> OutOfService), `usp_CompleteBooking` (early check-out, low-contention).

## Issues found

1. **First-draft prose artifacts.** The first write contained garbled fragments (a broken `@m_*` suffix, `main_entertainment_id` typo in the escalation UPDATE WHERE clause, duplicated `FROM` tokens, and a stray interleaved comment). All fixed in the clean rewrite and subsequent fixes.
2. **Enum spelling mismatch.** Output 09's maintenance status enum is `('Reported','Assigned','InProgress','Completed','Cancelled')` (British spelling). Draft used `N'Canceled'` in two spots; both corrected to `N'Cancelled'`, consistent with the rest of the file and Outputs 10/11.
3. **Lock-ordering violation in the escalation draft (contract C4).** The first escalation design read the maintenance record inside the SERIALIZABLE transaction BEFORE acquiring the bookings range lock — exactly the opposite steady-state order (`maintenance -> bookings`) the contract forbids. Fixed by restructuring:
   - Step 0: the one-row maintenance lookup runs **outside the transaction** (READ COMMITTED) so it holds nothing.
   - Step 1 (first in-transaction lock): the bookings `WITH (UPDLOCK, HOLDLOCK)` key-range.
   - Step 2: re-read + re-validate maintenance under SERIALIZABLE.
   - Step 3: the UPDATE (fires the Task 10 triggers, whose alert inserts are the LAST resource).
4. **Missing `UPDLOCK` on the low-contention path.** `usp_CompleteBooking` initially read the usage session and bookings rows without any lock hint, so two concurrent check-outs of the same booking could both pass the `actual_end IS NULL` / `CheckedIn` checks. Added `WITH (UPDLOCK)` to both single-row reads to make the "locks only its target rows" design claim true.
5. **Status validation ordering.** The non-instant Approval flow now hard-enforces that only `Pending` bookings are approvable (50004) before the conflict checks, closing a state re-check gap.

## Changes made

- Created `outputs/12-concurrency-implementation-G08.sql` implementing:
  - **`usp_ApproveBooking`** — locks the target booking row (PK, UPDLOCK HOLDLOCK), then the conflict checks under SERIALIZABLE: overlap (50001), OutOfService (50002), advisory-ack completeness (50007), required-asset availability (50009), space closure (50003); records the decision row (`decision_source = 'Staff'`); `UPDATE bookings SET status = 'Approved'` is the publication point.
  - **`usp_CreateBookingAutoApproved`** — policy lookup (space-specific first, then type-wide; 50004 if none), booking-type allow-list (50005), capacity/policy-max (50006), the same three serialized checks, then the C3 statement order: `INSERT bookings (Pending)` -> `INSERT booking_advisory_acknowledgments` (system on the requester's behalf) -> `INSERT booking_decisions` (`decision_source = 'System'`, `decided_by = NULL`) -> `UPDATE bookings SET status = 'Approved'`; returns `@booking_id` OUTPUT.
  - **`usp_EscalateMaintenance`** — the C4-safe order above (context read -> bookings range lock -> maintenance UPDATE); uses `sp_set_session_context` for the trigger actor/reason; error codes 50020-50023.
  - **`usp_CompleteBooking`** — small transaction (50030/50031/50032), `UPDATE usage_sessions` (`actual_end_time`, `final_condition`, `completed_by`) + `UPDATE bookings SET status = 'Completed'`; the interval filter drops the row, releasing the remaining reserved window with no flag/timer.
- Header documents the invariant, the serialization primitive, the mandatory lock order, the error model (1205/1222 retryable vs 5xxxx terminal), the error code table (50001-50032), and prerequisites from Task 10.

## Improvement classification

- **Output refinement** (the deliverable itself)
- **SKILL.md improvement** (a documented requirement for the escalation context read; see below — recorded as a recommendation, not edited)

## Validation commands run

- Regex `rg` over the deliverable for `tsrange|EXCLUDE|btree_gist|GIN|DEFERRABLE|SET LOCAL|'infinity'` — zero PostgreSQL constructs.
- `rg -c` counts: 4 procedure create blocks; SERIALIZABLE where intended; `UPDLOCK` on every bookings/maintenance check; 2 `sp_set_context` calls.
- `rg -n "Canceled|Cancelled|main_entertainment"` — no `Canceled`/`main_entertainment` typo remains; all enumerate values match Output 09's enum table.
- Grep against Output 09/05 for every referenced column name (`requested_start_time`, `requested_end_time`, `expected_participants`, `booking_type`, `asset_status`, `completion_time`, `impact_level`, `decision_source`, `actual_time`, `completed_by`, `final_condition`, `max_participants`, `is_active`, etc.).
- Balanced code fences and headers check across the whole file.

## Validation results

- All four procedures present, `CREATE OR ALTER PROCEDURE` on SQL Server 2016 SP1+ features only (THROW, sp_set_context, DATETIME2, no array types).
- SERIALIZABLE + `WITH (UPDLOCK, HOLDLOCK)` is present on the conflict/impact checks exactly as §III requires, and the escalation now acquires the bookings range before any maintenance lock (C4 satisfied).
- Advisory acknowledgements are inserted before the status flip, so the Task 10 ack trigger sees the rows when it fires on the UPDATE.
- Statements enumerated 50001-50032 all defined in the header table and used consistently.

## Risks / caveats

- **Not executed against a live SQL Server.** This is the T-SQL deliverable; the actual lock-granularity/deadlock behaviour can only be demonstrated by Task 13 (`outputs/13-concurrency-tests-G08/`), which is out of scope here.
- **Index prerequisite.** The key-range granularity of the bookings conflict check depends on `IX_bookings_space_status_time` (I1) created in Task 10; without it, the UPDLOCK/HOLDLOCK still serializes but may escalate to a table lock.
- **Isolation persists per session.** Once set, `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` stays for the connection; the callers should not rely on it being reset, and this is documented in the header.
- **Concurrent late-comers to `Approved` after escalation.** Because bookings lock before maintenance, a booking that overlaps the window and is approved before escalation commits will be picked up by the trigger's `booking_alerts`; one approved after consideration is blocked by the new OutOfService state. Both covered by 500-; the "notify requesters" part stays a manual staff action (per the escalation requirement).

## Recommended next steps

- Team review of Task probe vs. 11 contract C1-C7 (owner: lead; reviewers per AGENTS.md §7).
- Apply the skill improvement: add a rule in the 12-skill that the escalation procedure must take the bookings UPDLOCK range lock inside the transaction BEFORE any maintenance read/update; and that any maintenance locality read needed to build the bookings window must be done before `BEGIN TRANSACTION`.
- Proceed to Task 13: concurrency tests validating (a) the conflict is demonstrated under `READ SNAPSHOT` and prevented under `SERIALIZABLE`, (b) early check-out releases the window, (c) escalation surfaces every affected booking.

## Git status summary

```
?? .opencode/commands/11-concurrency-design.md
?? .opencode/commands/12-concurrency-implementation.md
?? .opencode/skills/db-design-pipeline/11-concurrency-design/
?? .opencode/skills/db-design-pipeline/12-concurrency-implementation/
?? docs/audits/62-task11-concurrency-design-generation-audit.md
?? docs/audits/63-task12-concurrency-implementation-generation-audit.md
?? outputs/11-concurrency-design-G08.md
?? outputs/12-concurrency-implementation-G08.sql
```

- `outputs/12-concurrency-implementation-G08.sql` and this audit are the two new paths created by this run (untracked).
- The command/skill files were present before this session (`11` code/12 folders) and were read-only during the run; no commits requested or made.