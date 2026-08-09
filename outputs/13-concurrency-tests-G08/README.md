# Task 13 — Concurrency Test Suite (G08)

This folder proves the Phase 2 **concurrency invariant** — *no two
`Approved`/`CheckedIn` bookings may overlap on the same space, regardless of
the path (instant or manual) and regardless of how many users/staff act at
once* — and the Phase 2 **early check-out** / **escalation** behaviours. For
every race (A, B, C) the scripts run BOTH a **Part A baseline**, which
reproduces the Phase 1 trigger-only flaw (both sides win the same slot), and a
**Part B prevention**, which drives the collision through the Task 12 stored
procedures (`SERIALIZABLE` + `UPDLOCK`/`HOLDLOCK`) and shows the invariant
holding. File `04` verifies early check-out, and file `99` restores the
database for the next task.

Design contract: `outputs/11-concurrency-design-G08.md` (§II races, §VI
contracts C1–C7); procedures under test: `outputs/12-concurrency-implementation-G08.sql`.

---

## File index

- **`00-setup-test-data.sql`** — Idempotent seed: test department, six
  `t13.*` users + `user_roles`, two test spaces (`T13-T-AUD`, `T13-T-CLS`),
  the auto-approval policy + allowed booking types, four `Pending` seed
  bookings, and the Race-C Advisory maintenance record + its acknowledgement.
  Run once in a single window before any race file.
- **`01-race-A-double-approval.sql`** — Race A (manual vs. manual): two staff
  approve two overlapping `Pending` bookings on the same space. Part A shows
  the double-book; Part B shows `usp_ApproveBooking` serializing them so only
  one wins.
- **`02-race-B-instant-vs-manual.sql`** — Race B (instant vs. manual): the
  auto-approval path
  (`usp_CreateBookingAutoApproved`) races a staff approval
  (`usp_ApproveBooking`) for overlapping windows. Proves path-independence of
  the invariant.
- **`03-race-C-approval-vs-escalation.sql`** — Race C (approval vs.
  escalation): a booking approval races an `Advisory`→`OutOfService`
  escalation. Proves the Task 12 lock-ordering rule removes the deadlock cycle
  and that no approval slips past an escalated window.
- **`04-early-checkout-verification.sql`** — Single-window, self-driving
  verification of the reserved-vs-actual-time rule: a `CheckedIn` booking
  blocks its full reserved window, and `usp_CompleteBooking` (early
  check-out) releases the remainder **immediately**. Fully date-independent —
  all windows are derived from `GETDATE()` with `DATEADD`.
- **`99-cleanup.sql`** — Global cleanup. Deletes every harness row
  (seed + race-generated, all tagged `T13-`) in FK-safe order and restores the
  database to its pristine post-migration state. **Run before Task 14.**

---

## Prerequisites (run first, in this order)

1. **`outputs/05-db-definition-G08.sql`** — Phase 1 schema (base tables,
   constraints, indexes).
2. **`outputs/06-sample-data-G08.sql`** — Phase 1 sample data.
3. **`outputs/10-schema-migration-G08.sql`** — Phase 2 migration: new tables,
   the `TR_*` backstop triggers, filtered index `I1`
   (`IX_bookings_space_status_time`) that gives the procedures their
   key-range locking.
4. **`outputs/12-concurrency-implementation-G08.sql`** — the four stored
   procedures under test: `usp_ApproveBooking`,
   `usp_CreateBookingAutoApproved`, `usp_EscalateMaintenance`,
   `usp_CompleteBooking`.
5. **Then `00-setup-test-data.sql`** — once, in a single SSMS window.
   Idempotent; re-run it any time a pristine seed is needed (it also undoes
   the RESET-cancelled rows of earlier race runs).

Target: Microsoft SQL Server 2016 SP1+ (or Azure SQL). Do **not** run any of
these files against PostgreSQL / MySQL / Supabase.

---

## Methodology — dual-window SSMS (files `01`, `02`, `03`)

The three race files rely on two concurrent transactions that cannot be
produced from one query window. Use **two SSMS query windows** connected to
the **same** database:

|                      | Window 1 (Session A)                 | Window 2 (Session B)                          |
| -------------------- | ------------------------------------ | --------------------------------------------- |
| **Part A (baseline)**| Raw statements, holds ~**5 s** delay | Raw statements, run **during** A's delay      |
| **Part B (prevention)** | Stored procedure, holds ~**6 s**   | Stored procedure, launched while A waits      |
| **After both commit**| VERIFY block (either window)         | VERIFY block (either window)                  |
| **Between parts**    | RESET block(s) restore Pending state | —                                             |

Each file's header has the exact per-session blocks; execute the blocks
marked for your window, in order.

### The 5–6 second `WAITFOR DELAY` timing

This is deliberately calibrated:

- **Part A baseline** holds the uncommitted winner row for **~5 seconds**
  (`WAITFOR DELAY '00:00:05'` placed *after* the first state-mutating
  statement). Under READ COMMITTED the delayed transaction's uncommitted row is
  invisible to the other session, so Session B's conflict probe sees an
  "empty slot" and also wins — reproducing the Phase 1 double-booking.
- **Part B prevention** holds the procedure's key-range locks for **~6 seconds**
  (`WAITFOR DELAY '00:00:06'` inside the harness `BEGIN TRANSACTION` that keeps
  the procedure's locks alive). The second session *blocks* on that range and,
  once Session A commits, re-reads and fails cleanly.

Practical timing: keep the two windows ready, start Window 1, then launch
Window 2 **within the 5–6 second window** the moment Window 1 prints its
"holding lock / committed" prompt. A human with both scripts open in SSMS has
ample time; you may re-run a part if the second session misses the gap.

File `04` does **not** need two windows — it is fully self-driving in one
window.

---

## Expected outputs — how to verify the invariant held

### Race A / Race B — Part A (baseline, the Phase 1 flaw)

- **Expected:** the VERIFY `SELECT` shows **both** bookings `Approved` with
  overlapping windows. That is the flaw being demonstrated; it must look this
  way in Part A — then Part B must not.

### Race A / Race B — Part B (prevention)

- **Expected:** the VERIFY `SELECT` shows **exactly one** `Approved` row; the
  loser stays `Pending`.
- The losing session prints a FAILURE — either:
  - **Error 50001** — *"Overlapping Approved/CheckedIn booking exists for this
    space."* Terminal: the slot was taken; the invariant held. This is the
    clean, expected outcome.
  - **Error 1205** (deadlock victim) or **Error 1222** (lock request timeout) —
    retryable per contract C5. The application would retry and then observe
    Error 50001; for the demo, seeing the losing session fail with any of
    `50001 / 1205 / 1222` while the VERIFY shows a single `Approved` row is a
    pass.
- **A FAIL is:** the losing session reports *SUCCESS* (no error) and the
  VERIFY shows two `Approved` rows — the invariant was lost.

### Race C — Part B (prevention)

- **Expected — no deadlock and no approved-vs-OutOfService slip.** Both legal
  branches end with one side losing cleanly:
  - If Session B (escalation) wins the range first, Session A's approval fails
    with **Error 50002** (*"Space has active OutOfService maintenance
    overlapping the requested window."*) — approval blocked.
  - If Session A (approval) publishes first, Session B's escalation **succeeds**
    and the escalation trigger writes **one `booking_alerts` row**
    (`MaintenanceEscalated`) for the now-`Approved` booking — identify, not
    rewrite.
  - A **Error 1205** here is the C5 bounded-retry case: re-run the losing side.
- **A FAIL is:** both sides succeed **and** the booking ended up `Approved`
  overlapping an *already-committed* `OutOfService` window.

### File `04` — early check-out (single window)

- **Step 2** prints `OK (expected): rejected — ... 50001` while the primary
  booking is `CheckedIn`.
- **Step 4** prints `SUCCESS: leftover window released + re-approved` with the
  new `T13-ECO-POST` booking.
- The final summary shows `T13-ECO-PRIMARY` = `Completed` and
  `T13-ECO-POST` = `Approved`. Both prints above are the invariant checks.
- **A FAIL is:** Step 2 approves (no error) or Step 4 is rejected.

---

## Final step — run `99-cleanup.sql` before Task 14

- Run **`99-cleanup.sql`** once in a single SSMS window **after** the demo.
- It deletes every T13-tagged row seeded by `00` or created during the races
  (`bookings`, `usage_sessions`, `booking_decisions`,
  `booking_advisory_acknowledgments`, `booking_alerts`,
  `maintenance_impact_history`, `maintenance_records`, policies, spaces,
  users, department) in FK-safe order and prints a marker count.
- The final verification `SELECT` returns **0** for every `marker` — the
  database is back to its pristine post-migration state.
- **Why it matters:** Task 14 (`outputs/14-data-generator-G08.sql`) must seed
  at least 3 academic years and 100,000+ bookings against a clean Phase 2
  schema; leftover `T13` bookings, alerts, or advisory records would pollute
  its histograms, conflict checks, and index-tuning timings.
- `99-cleanup.sql` is re-runnable; running it twice is a harmless no-op on the
  second pass.