# Concurrency Control Design — Task 11 (G08)

> **Phase:** Phase 2 (System Extension)
> **Task:** 11 — Concurrency & Race Condition Design
> **Output:** `outputs/11-concurrency-design-G08.md`
> **Target DBMS:** Microsoft SQL Server 2016 SP1+ (SQL Server only; no PostgreSQL constructs)
> **Primary sources:** `CS486_Project_Phase02.pdf`; `req/business-requirement-P2.md` §4; `outputs/08-requirement-change-analysis-G08.md` §5 (Concurrency & Race Condition Analysis); `outputs/09-updated-erd-and-logical-design-G08.md` §9 (Concurrency Control Design) and §10 (Indexing Strategy, index I1); `AGENTS.md` (repository rules, §5).
> **Immediate consumer:** Task 12 (`outputs/12-concurrency-implementation-G08.sql`) — this document defines the *mechanisms* and the *design contract*; Task 12 supplies the concrete stored-procedure and locking code.
> **Scope boundary:** this document specifies **what** serialization mechanisms will be used and **why**. It deliberately contains **no** stored-procedure bodies, `CREATE PROCEDURE` / `CREATE TRIGGER` DDL, or production code — the concrete implementation is the reserved deliverable of Task 12.

---

## I. Introduction and Failure Mode Analysis

### I.1 The concurrency requirement

Phase 2 (see `req/business-requirement-P2.md` §4) carries the Phase 1 core invariant forward unchanged **and upgrades it to hold under concurrency**:

> **The invariant:** the same space may never have two `Approved` or `CheckedIn` bookings with **overlapping** time periods — regardless of whether either booking arrived through instant-booking (auto-approval) or through the manual staff-approval workflow, and regardless of how many users or staff act on the same space at the same instant.

This is a **data-integrity** requirement, not a UI-timing one. Two staff members approving different pending requests for the same slot at the same moment must not both succeed; an auto-approval must not win the same slot that a staff member is simultaneously approving; and no number of simultaneous requests may double-book a space.

The requirement is **path-independent**: the conflict-check behaviour must be identical for the instant path and the manual path, because neither transaction can know, at the moment of its check, which path the concurrent one arrived through.

### I.2 Failure mode: check-then-act (TOCTOU)

The Phase 1 design enforces the overlap rule only with the `AFTER` trigger `TR_bookings_PreventOverlapAndUnavailable` (`outputs/05-db-definition-G08.sql`). A trigger is **statement-time validation**: it evaluates a predicate against the rows visible when the triggering statement runs and raises an error only if that visible state violates the rule. It does **not** serialize concurrent write transactions.

The failure is the textbook **check-then-act** race, also classified as time-of-check-to-time-of-use (**TOCTOU**) or a **lost-update** anomaly. Each transaction performs two separated steps:

1. **Check** — run the availability predicate ("are there any blocking `Approved`/`CheckedIn` bookings for this space and window?"). The predicate sees only the committed (or statement-level-visible) state.
2. **Act** — decide "slot free", insert/approve, and commit.

Under the default `READ COMMITTED` isolation, two transactions can both *check* the identical free slot, both *act*, and both *commit* — each transaction's trigger fires at a different statement moment and never observes the other's not-yet-committed (or not-yet-visible) row. The second write silently loses the guarantee the first write established. **Validation cannot repair this; only serialization can.** Phase 2 therefore does **not** rely on the trigger for correctness under contention.

> This is the formalisation of the analysis in `outputs/08-requirement-change-analysis-G08.md` §5.1 and `outputs/09-updated-erd-and-logical-design-G08.md` §9.1.

### I.3 Trigger = validation backstop, stored procedure = serialization

The trigger **stays** in the schema (a mandatory backstop for any path that bypasses the stored procedures — ad-hoc SQL, future APIs, migration scripts), but it is **demoted** to a validation layer:

| Concern | Mechanism | Role |
|---|---|---|
| Serialization (the invariant under simultaneity) | Stored procedures + `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)` range locking | **Primary defense** — closes the TOCTOU race |
| Statement-level validation on the committed state | `TR_bookings_PreventOverlapAndUnavailable` + the Phase 2 triggers (advisory acknowledgement, required-asset, escalation alerts) | **Backstop** — catches violations on the final committed state; it does not prevent them |

**The trigger validates; it does not serialize.** Every path that creates or approves a booking (the manual-approval procedure, the instant-booking procedure) must run the serialized conflict check inside its transaction; the trigger is the safety net *under* the procedures, not a substitute for them.

> **Task 12 hand-off:** implement the stored procedures (`usp_ApproveBooking`, `usp_CreateBookingAutoApproved`, and the Task 12 escalation/move procedure) with the mechanisms specified in Section III.

---

## II. Identified Race Conditions

This section details the exact step-by-step interleavings of the **three** races the mechanism must close. All scenarios are shown under the default `READ COMMITTED` isolation first (the vulnerable behaviour), then the required serialized behaviour.

### II.1 Race A — Double Approval (Manual vs. Manual)

Two staff members simultaneously approve two **different** pending requests, bookings `X` and `Y`, for the **same space** and **overlapping requested windows**. Interleaving with no serialization:

1. **T1** (Staff 1, approving `X`) opens its transaction and runs its conflict check for `X`: reads `bookings`, sees only committed rows; `Y` is still `Pending` (not yet updated), so no conflict is found.
2. **T2** (Staff 2, approving `Y`) opens its transaction and runs its conflict check for `Y`: likewise sees no conflict — `X` is not yet `Approved`/committed.
3. **T1** updates `X` to `Approved` and commits; its `AFTER` trigger fires and sees no committed overlap at its statement time.
4. **T2** updates `Y` to `Approved` and commits; its trigger's statement snapshot does not include `X`'s commit, so it also passes.

**Result:** two overlapping `Approved` bookings for the same slot — the invariant is violated.

**Serialized behaviour:** both approval transactions must run the conflict check under `SERIALIZABLE` isolation with `WITH (UPDLOCK, HOLDLOCK)` hints on the `bookings` probe. T2's conflict check then **blocks on T1's key-range lock** until T1 commits; on wake-up it re-reads under `SERIALIZABLE`, sees `X` as `Approved`, and fails cleanly — instead of both succeeding.

### II.2 Race B — Instant vs. Manual (and instant vs. instant)

A staff member manually approves request `X` while the system auto-approves request `Y` for the same slot (or two instant requests race).

1. The instant path reads `auto_approval_policies` and the availability for `Y`; the manual path runs its availability check for `X` — both see an empty `Approved`/`CheckedIn` set for the window.
2. Both pass their checks and write: `X` becomes `Approved` with a `booking_decisions` row (`decision_source = 'Staff'`); `Y` becomes `Approved` with a `booking_decisions` row (`decision_source = 'System'`, `decided_by = NULL`).
3. Both commit; each trigger sees no committed overlap at its own statement time.

**Result:** the same invariant violation as II.1, now produced by two different code paths. Because the invariant is **path-independent**, both paths **must share the same concurrency-safe conflict check** (Section III). The multi-statement instant flow (read policy → decide → insert booking → insert acknowledgements → status `Approved`) must additionally be wrapped in **one** `SERIALIZABLE` transaction so that two concurrent instant requests cannot both read the same policy, decide they will both be first, and both commit.

### II.3 Race C — Approval vs. Maintenance Escalation (deadlock risk)

A booking `X` is being approved for `space S` while facility staff simultaneously escalate an overlapping `Advisory` maintenance record `M` to `OutOfService` for the same window. Without lock-acquisition discipline:

**Step 1 (approval):** reads/updates `bookings` (finds `X`, takes locks), then reads `maintenance_records` (the impact-level check in Section III.3).
**Step 2 (escalation):** reads/updates `maintenance_records` (escalates `M`), then — via the trigger `TR_maintenance_escalation` — reads `bookings` and inserts into `booking_alerts` (affected bookings).

The two workflows therefore acquire locks on shared tables in **opposite orders**:

```text
approval:   bookings  → 
10:47:46 AM
Started executing query at  ￼Line 34 maintenance_records
escalation: maintenance_records  →  bookings / booking_alerts
```

This is a textbook **lock cycle**: T1 holds a `bookings` lock and wants a `maintenance_records` lock; T2 holds the `maintenance_records` lock and wants a `bookings` lock. SQL Server detects the cycle and picks a deadlock victim (error `1205`). Deadlock here is a **legitimate event under contention** (not a programming bug), so the design has two complementary answers:

1. **Lock-acquisition ordering** (Section III.5) — both workflows acquire locks in a single global order (`bookings` → `maintenance_records` → `booking_alerts`), removing the *guaranteed* cycle that opposite orderings create.
2. **Bounded deadlock recovery** (Section III.6) — deadlocks remain possible even with ordering; the application must recover from errors `1205` / `1222`, not abort.

Both are first-class mechanisms, not optional extras.

### II.4 The shared conflict predicate

Every race above resolves to the **same predicate** against the same blocking statuses:

```sql
SELECT 1
FROM dbo.bookings b WITH (UPDLOCK, HOLDLOCK)   -- serializing check, Section III.2
WHERE b.space_id = @space_id
  AND b.status IN (N'Approved', N'CheckedIn')
  AND b.requested_start_time < @new_end_time
  AND b.requested_end_time   > @new_start_time;
```

Overlap of the half-open intervals `[s1, e1)` / `[s2, e2)` is expressed directly as `s1 < e2 AND e1 > s2` (see `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` §4). The `status IN (N'Approved', N'CheckedIn')` filter is **load-bearing**: it encodes both the "blocks booking" rule (Phase 1) and the dynamic early-check-out release rule (Section III.8), and it is exactly the filter of the filtered index `IX_bookings_space_status_time` (I1 in `outputs/09-updated-erd-and-logical-design-G08.md` §10) that gives the range lock granularity.

> **Filtered-index grammar note (from Output 09 §10):** SQL Server filtered-index predicates accept `IN (...)` but **not** bare `OR` or `NOT IN`. I1 keeps the legal `IN` form exactly as written — do not "helpfully" rewrite it.

---

## III. Proposed Concurrency Control Mechanism (mandatory for Task 12)

### III.1 Transaction isolation: `SERIALIZABLE` is mandatory

Every booking-creation, booking-approval, and booking-escalation transaction **must** begin with:

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

`SERIALIZABLE` is the only isolation level that provides **phantom protection**: a transaction that has read a set of rows (and the range they occupy) is guaranteed to see the same read set on re-read, and a concurrent `INSERT` into that range cannot appear in it. Under `READ COMMITTED` or `REPEATABLE READ`, the key-range (gap) locking the conflict check relies on is not guaranteed, so a concurrent overlapping `INSERT` could slip into the gap between check and act — exactly the TOCTOU window described in Section I.2.

The surrounding multi-statement flows run under an explicit transaction with rollback on any error:

```sql
SET XACT_ABORT ON;                          -- any error rolls back the whole transaction
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
-- ... conflict check      (Section III.2)
-- ... impact-level check  (Section III.3)
-- ... business-rule checks (Section III.4)
-- ... insert / update     (Section III.4)
COMMIT TRANSACTION;
```

`SET XACT_ABORT ON` is mandatory: any error — including a deadlock (`1205`) — rolls back the entire transaction and releases every lock, so the unit of work is all-or-nothing and no partial-reservation state is left behind for a retry to collide with.

### III.2 Key-range locking — `WITH (UPDLOCK, HOLDLOCK)` on the conflict check

The concrete serialization primitive is a **conflict-check `SELECT` that takes update locks on range**:

```sql
SELECT 1
FROM dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
WHERE b.space_id = @space_id
  AND b.status IN (N'Approved', N'CheckedIn')
  AND b.requested_start_time < @new_end_time
  AND b.requested_end_time   > @new_start_time;
```

- **`UPDLOCK`** — takes **update (U) locks** on every matching `bookings` row, not shared read locks.
- **`HOLDLOCK`** — holds those locks, and under `SERIALIZABLE` adds **key-range locks** covering the **gap** where a new conflicting row could be inserted, until the transaction commits. A concurrent `INSERT` of an overlapping row into that range therefore **blocks** instead of silently coexisting.

Behaviour of a second, concurrent attempt on the same (space, window):

1. It runs its own conflict check.
2. It **waits** while the first transaction holds the key-range lock.
3. When the first commits, the second **re-reads** under `SERIALIZABLE`, sees the committed conflict, and fails cleanly with a targeted error (or is chosen as a deadlock victim if a cycle formed instead).
4. The application retries on `1205`/`1222` (Section III.6); if the retried attempt then hits the overlap error, the slot is genuinely gone.

Requests for **different** spaces, or for **disjoint** windows on the same space, take disjoint locks — concurrency is sacrificed only where the invariant requires it.

**Index precondition (for granularity):** key-range locking stays granular only if an index matches the predicate. The filtered index `IX_bookings_space_status_time` on `(space_id, requested_start_time, requested_end_time)` — `WHERE status IN (N'Approved', N'CheckedIn')` (I1) — provides it. Without a matching index, SQL Server may escalate to a table lock: still **correct**, but far less concurrent. I1 is therefore **load-bearing for concurrency**, not merely performance.

### III.3 The impact-level check — same lock discipline on `maintenance_records`

The booking-creation/approval paths must also be serialized against **active `OutOfService` maintenance** — the space-level blocking fact that can be escalated concurrently (Race C). The same range-lock discipline is applied to `maintenance_records`:

```sql
SELECT 1
FROM dbo.maintenance_records m WITH (UPDLOCK, HOLDLOCK)
WHERE m.space_id = @space_id
  AND m.status NOT IN (N'Completed', N'Cancelled')
  AND m.impact_level = N'OutOfService'
  AND m.start_time < @new_end_time
  AND COALESCE(m.completion_time, '9999-12-31 23:59:59') > @new_start_time;
```

- `COALESCE(m.completion_time, '9999-12-31 23:59:59')` supplies the open-ended maintenance window (SQL Server has no `'infinity'` literal; this pattern plays that role, per the Phase 2 spec §4).
- `maintenance_records.space_id` is `NOT NULL` (Phase 1 baseline, immutable snapshot — Output 09 §5.11/§8.3), so this flat `WHERE space_id = @space_id` probe is **complete by construction**: no `JOIN` into `facility_assets` is needed, whether or not a row also names an `asset_id`.
- The filtered index `IX_maintenance_blocking` (I3, Output 09 §10) keeps the active blocking set small and the probe a seek.

Because the escalation workflow must first lock the `bookings` range under the ordering rule (Section III.5), an approval and a concurrent escalation for the same space/window **serialize on the same range locks** — an approval can never slip past, and win the slot, a concurrent escalation to block it.

### III.4 The multi-statement booking flows stay one transaction

The instant-booking path is a **multi-statement read-then-write sequence**:

1. Read `auto_approval_policies` (with the specific-space vs. type-wide precedence rule, Output 09 §9.6 / L8).
2. Evaluate eligibility (participant cap with the NULL-safe `max_participants IS NULL OR expected_participants <= max_participants` test, booking-type allow-list — Output 09 §9.6).
3. Run the conflict check (Section III.2) and the impact-level check (Section III.3).
4. Run the advisory-ack **completeness** check (set-based `NOT EXISTS`, not a `COUNT` comparison — Output 09 §9.5.3) and the required-asset availability check (Output 09 §9.5.4).
5. Insert the `bookings` row as `Pending`, insert the `booking_advisory_acknowledgments` rows, insert the System `booking_decisions` row (`decision_source = 'System'`, `decided_by = NULL`), and finally flip `status` to `Approved`.

All of steps 1–5 run **inside one `SERIALIZABLE` transaction** with the Section III.2/III.3 checks executed within it. This removes the second-tier race — two transactions both reading the same policy and both believing they will be the first to approve.

**Mandatory statement order:** the `Pending` → acknowledgement rows → `Approved` order is required by the advisory-ack trigger (`TR_bookings_AdvisoryAckRequired`), which fires on the status-change statement and therefore requires the acknowledgement rows to already be visible in the same transaction (see `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` §5.3 and Output 09 §9.5.3).

### III.5 Lock acquisition ordering (the anti-deadlock rule)

**Mandatory rule (Output 08 §5.5 / Output 09 §9.3/R L7):** any transaction that touches `bookings` *and* `maintenance_records` — directly, or transitively via `booking_alerts` — must acquire locks in the fixed order:

```text
bookings  →  maintenance_records  →  booking_alerts
```

Even though the escalation workflow *logically* reads `maintenance_records` first (it escalates `M`), it must first acquire the relevant `bookings` range lock, then the `maintenance_records` lock, then `booking_alerts`. This makes the approval and escalation workflows take locks in **the same order**, eliminating the guaranteed deadlock that opposite orderings would otherwise produce on every collision (Race C).

SQL Server does **not** enforce lock ordering automatically; ordering is a discipline the stored procedures must apply. Deadlocks remain possible even under this rule (ordering reduces frequency, not probability), which is exactly why bounded retry (§III.6) is mandated on every path.

### III.6 Error handling: bounded retry on `1205` / `1222`

Deadlocks and lock waits are **expected behaviour** under the concurrency pressure Phase 2 targets (semester start, many simultaneous requests for a few popular spaces) — not "failures". The design mandates:

| Error | SQL Server meaning | Handling |
|---|---|---|
| `1205` | Deadlock victim — the lock manager chose one transaction of a cycle as the sacrifice | Roll back the whole unit of work, wait a short randomized backoff, and **retry from scratch** |
| `1222` | Lock request timeout — the lock could not be acquired within the timeout budget | Same — **bounded retry with backoff** |
| Business overlap error (e.g. `THROW 50001, N'Overlapping approved booking exists for this space.', 1;` — the same error number family used in Output 08 §5.5) | The slot is genuinely taken; retrying **cannot** succeed | Terminate with a clean conflict result; the caller decides whether to auto-reject or re-queue as `Pending` (open question, Appendix A) |

Retry policy is **bounded**: a fixed maximum count (e.g. 5) with exponential backoff plus jitter, after which the caller receives the last error. The application must **not** retry endlessly, and must **not** retry a business-rule overlap error.

**Programming contract for Task 12:** each procedure is written as `BEGIN TRY ... BEGIN CATCH` with `SET XACT_ABORT ON` and a rollback-on-catch; the retry loop lives in the **caller** (application layer), not per statement; the catch block must clearly separate `1205`/`1222` (retryable) from the 50xxx-series overlap error (terminal).

### III.7 Trigger backstop (defense-in-depth)

`TR_bookings_PreventOverlapAndUnavailable` remains in the schema, alongside the Phase 2 triggers (advisory acknowledgement, required-asset, escalation alerts). These triggers operate on the **final committed state** — they can reject a statement that leaves a violation, but they do not *prevent* the interleaving. Both layers coexist: procedures prevent the race; triggers catch violations of the non-concurrency business rules (e.g. R3 advisory-ack, R8 required-asset, R5 escalation alerts) and any bypass path.

### III.8 Status-driven interval selection (release-on-check-out)

The conflict-check filter `status IN (N'Approved', N'CheckedIn')` (Section III.2) **is** the dynamic-release mechanism. There is no trigger, timer, or stored flag for early check-out:

| Booking status | Blocks new bookings? | Interval the conflict check uses |
|---|---|---|
| `Pending` | No | — |
| `Approved` | **Yes** | reserved `[requested_start_time, requested_end_time)` |
| `CheckedIn` | **Yes** | reserved `[requested_start_time, requested_end_time)` (early end not yet known) |
| `Completed` | **No** | historical only — actual `[actual_start_time, actual_end_time)` |
| `Rejected` / `Cancelled` / `NoShow` | No | — |

The instant a check-out writes `actual_end_time` and flips the booking `CheckedIn → Completed`, the row drops out of the blocking filter — the remaining reserved window is released **immediately** (Output 09 §9.4). This falls out of the predicate; no extra mechanism is needed.

**Concurrency implication:** the check-out transaction does **not** need the concurrency machinery at all. Releasing a slot can never create an overlap, so check-out runs a small transaction that locks only the target `bookings` row and its `usage_sessions` row (Output 09 §9.5 — `usp_CompleteBooking` runs none of the five checks). This is deliberate: locking `bookings`/`maintenance_records` on check-out would add contention exactly at the semester-start peaks the design exists to survive.

---

## IV. Alternative Mechanisms Evaluated

### IV.1 Application locks — `sp_getapplock`

SQL Server's application-lock facility offers a per-space, application-defined serialization primitive:

```sql
EXEC sp_getapplock
     @Resource    = CONCAT(N'booking_space_', @space_id),
     @LockMode    = N'Exclusive',
     @LockOwner   = N'Transaction',
     @LockTimeout = 10000;   -- ms; returns 0 on success, -1 on timeout
```

Once the application lock is held, only one transaction per space runs the check-then-act sequence at a time, and a plain conflict `SELECT` (no hints) is sufficient inside that critical section.

**Evaluated trade-off:**

*Pro:*
- Simpler mental model — the developer sees "the space is locked" and the conflict check becomes a plain read.
- Guaranteed single-writer semantics per space, independent of index/range-lock mechanics.

*Con (why it is rejected as the primary mechanism):*
1. **Serializes non-conflicting bookings.** It blocks *all* bookings on a space, including disjoint windows on different rooms in the same space, whereas range locks only block genuinely conflicting ranges. Under semester-start, a per-space serialization bottleneck is exactly the wrong failure mode — it converts a wide, spread-out burst of non-conflicting requests into a queue for one space.
2. **No schema enforcement.** The lock is application-defined; every code path must remember it. A forgotten path (ad-hoc SQL, future API) silently skips it and the trigger-only race returns with no warning. Section III embeds the serialization inside the locking `SELECT` of the shared procedures, so every path that uses the procedures inherits it.
3. **Still needs ordering.** The escalation workflow also needs the per-space lock, so the same ordering rule (Section III.5) is still required between the application lock and the table locks.

**Verdict:** the **primary defense** is `SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)` range locking on the conflict and impact checks (Section III), with bounded retry on `1205`/`1222`. `sp_getapplock` is **rejected as primary** but may be used as an optional **belt-and-braces** addition in the Task 12 implementation (e.g. to guard the multi-statement instant flow), provided the ordering rule still holds and the range locks are still taken. This matches Output 09 §9.2, which sanctions the combination.

### IV.2 Optimistic concurrency (row-version / snapshot) — evaluated and rejected

A `rowversion` column + optimistic retry, or `SNAPSHOT` isolation, was evaluated. It is **rejected as the primary mechanism**: two transactions could still *check* availability, both commit, then both try to increment the version — one wins and the other gets a version mismatch. That does serialize writes, but it adds a `rowversion` column (schema change) and an extra `UPDATE` per booking, and validation happens only at write time. The pessimistic range-lock (Section III.2) is preferred because it works directly on the scheduling range that is the natural unit of the invariant and requires no extra column or update.

> Trigger-only (`AFTER`) validation was also already discounted in Section II: it validates the committed state but cannot serialize concurrent writers. It remains a backstop, not the mechanism.

---

## V. Traceability and Assurance

| P2 requirement (from `req/business-requirement-P2.md`) | This document | Task 12 / 13 evidence |
|---|---|---|
| `[CONFIRMED] §4` — invariant holds independent of path (manual or auto) | Sections II.1–II.2, III.2 (shared mechanism, both paths) | Concurrency tests (Task 13) exercising both paths |
| `[CONFIRMED] §4` — invariant holds under concurrency | Sections III.1–III.6 | Task 13 conflict-prevention script |
| `[CONFIRMED] §4` — escalation identifies pre-approved bookings | Section II.3, III.5 (ordering) + escalation lookup | Task 13 escalation test; `booking_alerts` report |
| `[CONFIRMED] §4` — auto-approval decision stored, `decision_source` distinguishes | Section III.4 (System decision row) | Task 12 procedure + Task 13 verification |
| `[CONFIRMED] §4` — SQL Server only (no PostgreSQL) | Sections III.1–III.6 (locking primitives) | Task 12/13 executed on SQL Server-compatible environment |
| `[EXTENSION]` — early check-out releases reserved window immediately | Section III.8 (status filter) | Task 13 release test |

**Validation to run in Task 13:** for each of the three races (II.1, II.2, II.3) execute both (a) a **no-prevention baseline** demonstrating that under `READ COMMITTED` the race produces the violation, and (b) a **prevention run** demonstrating the invariant holds under `SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK`. Additional verifications: bounded retry distinguishes `1205`/`1222` from the terminal overlap error; early check-out releases the window; and the escalation lookup surfaces every affected `Approved`/`CheckedIn` booking.

---

## VI. Task 12 Implementation Contract (handoff)

This document deliberately stops short of code; the Task 12 T-SQL must deliver:

| Contract | Requirement (mandatory) | Design reference |
|---|---|---|
| C1 | Every booking-creation / approval path (manual + instant) runs the conflict check with `WITH (UPDLOCK, HOLDLOCK)` on a `SERIALIZABLE` transaction | Sections III.1–III.3 |
| C2 | Same paths run the impact-level `OutOfService` check with the same lock discipline | Section III.3 |
| C3 | The instant (multi-statement) flow is **one** serializable transaction with the exact statement order `Pending` → acknowledgement rows → `Approved` | Section III.4 |
| C4 | Lock acquisition ordering `bookings → maintenance_records → booking_alerts` respected by approval *and* escalation procedures | Section III.5 |
| C5 | `SET NOCOUNT ON`, `SET XACT_ABORT ON`, `BEGIN TRY ... BEGIN CATCH` with bounded-retry contract separating `1205`/`1222` (retryable) from the 50xxx overlap error (terminal) | Section III.6 |
| C6 | Phase 1 `TR_bookings_PreventOverlapAndUnavailable` and all Phase 2 triggers retained as backstops (not removed) | Section III.7 |
| C7 | Granular key-range locking backed by filtered index I1 (bookings conflict) and I3/I4 (maintenance) | Section III.2–III.3, Output 09 §10 |

---

## Appendix A — Assumptions and Open Questions

- **A.1 — Losing request disposition [OPEN].** When an instant request loses to a concurrent winner, the application must decide whether the losing request is **auto-rejected** or **re-queued as `Pending`** for manual review. Not stated in either PDF (business-requirement §9). The DB contract only guarantees the loser fails *cleanly* (Section III.6); the product decision stays in the application layer.
- **A.2 — Escalation "identify, not rewrite".** Escalation must make affected bookings *identifiable to staff* (a lookup), not automatically cancel or rewrite them. Section II.3 + Section III.5 ensure a booking cannot be **created** overlapping an `OutOfService` window; an escalation that lands on an already-`Approved` booking is legitimate and is handled by `TR_maintenance_escalation` writing `booking_alerts` rows, not by the concurrency layer.
- **A.3 — Mechanism mixing.** `sp_getapplock` may be layered on top as belt-and-braces, but no layout frees any procedure from the mandatory conflict check (C1) or the lock-ordering rule (C4).
- **A.4 — Trigger backstop limitation (restated for the record).** The Phase 1 trigger remains a validation backstop; it is documented as *not* the concurrency mechanism. This is a deliberate, allowed design: the graded Phase 2 requirements (business-req §4) demand the invariant hold under concurrency, which only the procedural serialization (Section III) provides.

---

## Task 11 quality checklist

- [x] Concurrency requirement stated (invariant, path-independent, data-integrity).
- [x] Failure mode is check-then-act / TOCTOU / lost-update, explained with the concrete interleavings.
- [x] Triggers restated as a validation backstop; stored procedures as the serialization mechanism.
- [x] Three races detailed step-by-step (double approval; manual-vs-auto; approval-vs-escalation) including the deadlock risk.
- [x] Mandatory mechanisms: `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`; `WITH (UPDLOCK, HOLDLOCK)` on conflict and impact checks; lock ordering `bookings → maintenance_records → booking_alerts`; `TRY...CATCH` with bounded retry on `1205`/`1222`.
- [x] Alternative `sp_getapplock` evaluated with a trade-off analysis and an explicit verdict (belt-and-braces only).
- [x] T-SQL code blocks demonstrate the actual `SELECT ... WITH (UPDLOCK, HOLDLOCK)` queries.
- [x] All table/column names and isolation levels appear as inline code.
- [x] No DDL / stored-procedure bodies — those are reserved for Task 12.
- [x] Consistent with Output 08 §5 and Output 09 §9/§10; SQL Server-only (no PostgreSQL constructs).