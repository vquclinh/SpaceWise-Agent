# Rubric: 11-concurrency-design-G<Group#>.md

Phase 2 — specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions).

## Source of truth
Grade against:
- `08-requirement-change-analysis-G<Group#>.md` — the concurrency conflict(s) identified
  there must be the starting point of this document, not re-identified from scratch.
- Phase 2 requirement section 1.2 — the ground truth for what the system must guarantee
  ("two approved bookings cannot use the same space during overlapping time periods,
  regardless of whether the bookings are created through instant-booking or staff
  approval, even when multiple users or staff perform operations simultaneously").
- `09-updated-erd-and-logical-design-G<Group#>.md` — if a schema-level concurrency
  mechanism (e.g. `version` column for optimistic locking) was introduced there, this
  document must be consistent with it.

This is a **design document**, not an implementation. It must describe the conflict,
justify the chosen solution, and specify it precisely enough that task 12 can implement
it without ambiguity. Flag any document that jumps to code without showing the reasoning.

---

## Criteria

### 1. Conflict scenario description (weight: high)
Must describe at least one concrete concurrency conflict scenario with a step-by-step
interleaving of operations, not just a high-level statement like "two users book at the
same time." A valid description includes:

- Named actors (e.g. Session A / Session B, or User1 / Staff1).
- The exact sequence of reads and writes, e.g.:
  1. Session A reads space availability → available.
  2. Session B reads space availability → available.
  3. Session A writes approved booking for 09:00–11:00.
  4. Session B writes approved booking for 09:00–11:00 → conflict undetected.
- The conflict type named explicitly: **lost update** (both sessions read before either
  writes) or **write skew** (each session reads a consistent snapshot but writes based
  on a now-stale read) — both apply here; accept either or both.
- Both booking paths covered: instant-booking (auto-approved at submission) and
  staff-approval workflow — the conflict can arise in either and between them (e.g.
  Session A is an instant-booking, Session B is a staff approving a pending request for
  the same slot). Flag if only one path is analyzed.

### 2. Conflict breadth — beyond the obvious (weight: medium)
Section 1.2 asks groups to "identify at least one concurrency conflict." Full credit
requires identifying the primary conflict (overlapping booking approval) plus at least
one secondary conflict from:
- **Escalation race**: a staff member escalates a maintenance record from advisory to
  out-of-service while another session is simultaneously approving a booking for the
  same space and overlapping period — the booking approval reads no out-of-service
  maintenance and proceeds, but the escalation commits first, leaving an approved
  booking on an out-of-service space.
- **Double-acknowledgement race**: two sessions submit bookings for the same advisory
  space simultaneously; both read the same active advisories and write acknowledgement
  rows — if the junction PK is not enforced properly, duplicate acknowledgement rows
  may be inserted.
- **Check-in / completion race**: two staff members attempt to check in or complete the
  same booking simultaneously.

Identifying only the primary conflict earns adequate (3/5) for this criterion; identifying
one secondary conflict earns good (4/5); identifying two or more earns excellent (5/5).

### 3. Chosen solution and justification (weight: high)
For each identified conflict, the document must:
- Name the specific mechanism chosen (see acceptable options below).
- Explain *why* this mechanism is appropriate for this conflict — not just what it does.
- Note any trade-offs (e.g. pessimistic locking reduces throughput under high
  contention; serializable isolation increases deadlock risk).

**Acceptable mechanisms** (any one is sufficient for the primary conflict):

| Mechanism | What to check in the justification |
|---|---|
| Pessimistic locking (`WITH (UPDLOCK, HOLDLOCK)` on availability read) | Must explain that UPDLOCK prevents other sessions from acquiring update locks on the same rows until the transaction commits, and HOLDLOCK extends the lock to end of transaction |
| Serializable isolation level (`SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`) | Must explain that this prevents phantom reads — a new booking row inserted by another session will block until the current transaction commits |
| Optimistic locking (version/rowversion column + conflict detection on write) | Must explain the read-version → write-with-version-check pattern and what happens on version mismatch (retry or error) |
| Application-level advisory locks | Must explain the lock scope, granularity (per space? per time slot?), and release strategy |

**Not acceptable** as a complete solution:
- "Use a transaction" without naming isolation level or lock hint — a default READ
  COMMITTED transaction does not prevent the lost update described in criterion 1.
- "Add a UNIQUE constraint on (space_id, start_time)" — a UNIQUE constraint cannot
  express range overlap; it only prevents exact duplicate start times.
- Relying solely on the Phase 1 trigger — a trigger fires after the write, which is too
  late to prevent two concurrent sessions from both passing the availability check
  before either writes (trigger-based enforcement catches the conflict but may produce
  an error rather than a controlled resolution).

### 4. Deadlock analysis (weight: medium)
Any locking solution introduces deadlock risk. The document must:
- Acknowledge that deadlocks are possible (e.g. Session A locks Space X then Space Y;
  Session B locks Space Y then Space X).
- Describe a mitigation strategy: consistent lock ordering (always lock by space_id
  ascending), short transactions, or deadlock retry logic at the application layer.
- For serializable isolation specifically: note that SQL Server's deadlock detector will
  resolve deadlocks automatically but the application must handle the 1205 error with
  a retry.

Flag absence of deadlock discussion as a major gap — any production concurrency design
that ignores deadlocks is incomplete regardless of how correct the primary solution is.

### 5. Scope of locking (weight: medium)
The design must specify the exact granularity of the lock:
- **What is locked**: the space row, the booking rows for the space, or the availability
  check query result set.
- **When the lock is acquired**: at the start of the availability check read, not after.
- **When the lock is released**: at transaction commit/rollback, not after the read.
- **What operations are covered**: both instant-booking submission and staff approval
  must pass through the same locking point — if the lock only wraps the staff-approval
  path, instant-booking can still race past it.

Flag if the lock scope description is vague (e.g. "lock the relevant rows") without
specifying which rows, which statement, and in which transaction boundary.

### 6. Consistency with task 09 schema (weight: medium)
If task 09 introduced a schema mechanism for concurrency (e.g. a `version` column for
optimistic locking, or a note about serializable isolation), this document must use the
same mechanism. Inconsistency between task 09 and task 11 must be flagged and
explained — either task 09 was updated (document that here) or the design diverged
without justification.

If task 09 made no schema provision for concurrency (which is acceptable), this document
should note that no schema change is needed for the chosen mechanism (true for
pessimistic locking and serializable isolation) or propose the schema addition (true for
optimistic locking) and flag that task 09 needs a corresponding update.

### 7. Demonstration plan (weight: medium)
The document must outline how task 12 will demonstrate both the conflict and its
prevention. Specifically:
- A script showing the conflict occurring (before the fix) — what two sessions do, what
  the undesirable outcome is.
- A script showing the fix preventing the conflict — same scenario, same interleaving,
  different outcome because the lock/isolation is in place.
- The observable evidence that the fix worked (e.g. second session blocks until first
  commits, then receives an error or retries; or version mismatch is detected).

This is a plan, not the implementation — but it must be specific enough that task 12's
scripts can be written directly from it. A vague plan ("we will show a conflict and then
show the fix") earns minimal credit here.

### 8. Clarity and standalone readability (weight: low)
A grader unfamiliar with the codebase should be able to read this document and
understand: what the conflict is, why the chosen solution prevents it, and what task 12
will implement. Flag if the document assumes detailed knowledge of the schema without
referencing it, or if the interleaving sequences (criterion 1) are described in prose
without a step-by-step format.

---

## Scoring guidance
- Conflict scenario and chosen solution (criteria 1 & 3) ~45% combined — the core of
  the document; a design that doesn't describe the conflict precisely or justifies the
  solution with "it works" earns at most 2/5 overall.
- Deadlock analysis and lock scope (criteria 4 & 5) ~25% combined — the details that
  distinguish a production-quality design from a textbook answer.
- Conflict breadth, task-09 consistency, and demonstration plan (criteria 2, 6, 7)
  ~25% combined.
- Clarity (8) ~5%.

## Common failure patterns to watch for
- "We use transactions to prevent conflicts" with no isolation level — the single most
  common failure; default READ COMMITTED does not prevent the lost update described.
- Conflict scenario described in one sentence ("two users book the same room") without
  an interleaving sequence — the marker cannot verify the student understands *why*
  the conflict occurs.
- Only the staff-approval path analyzed; instant-booking path treated as safe because
  "it auto-approves" — auto-approval is exactly the path most vulnerable to the race
  since it writes without a human review step.
- Deadlock risk not mentioned at all — almost certain with any pessimistic locking
  strategy and a common exam point.
- Demonstration plan says "run script A then script B" without explaining what observable
  outcome proves the fix worked — task 12 will then produce scripts with no clear
  pass/fail criterion.
- Lock scope described as "lock the booking table" — table-level locking is correct but
  unnecessarily broad; flag as a design choice worth noting even if technically valid,
  since it serializes all booking operations across all spaces.