# Campus Space Management System — Project Specification (Phase 2 Addendum)

> This document extends `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC.md` (Phase 1). It does not
> repeat entities, workflows, or rules that are unchanged — read both together. Everything
> here maps to a business need in `req/business-requirement-P2.md`; the `[CONFIRMED]` /
> `[EXTENSION]` / `[OPEN]` tags carry over from that file so this document stays traceable
> to what is actually required by `CS486_Project_Phase02.pdf` versus what the team is
> choosing to add. Target engine is **Microsoft SQL Server** — the same engine as Phase 1
> (see `outputs/05-db-definition-G08.sql`). All types, triggers, and locking strategies
> below are written in SQL Server syntax, and every Phase 1 table/column name is reused
> verbatim (snake_case columns, PascalCase enum values, named `PK_`/`FK_`/`CK_`/`UQ_`
> constraints) so this addendum drops in consistently on top of the existing schema.

---

## 1. What changed and why

The Phase 1 pilot surfaced three gaps: (1) maintenance was too blunt an on/off switch,
(2) approval no longer safely serializes under real concurrent load, (3) reporting needs
grew. Phase 2 addresses exactly these three — nothing about the Phase 1 entity set
(`user_accounts`, `spaces`, `facilities`, `space_facilities`, `bookings`,
`booking_decisions`, `usage_sessions`, `maintenance_records`) is removed. It is extended.

---

## 2. New and modified entities

### 2.1 `maintenance_records` — modified **[CONFIRMED]**

Add:

| Column | Type | Notes |
|---|---|---|
| `impact_level` | `NVARCHAR(20) NOT NULL` | Required. Not derived — set by the reporting/deciding staff member per the business rule that this is a judgment call. `CHECK (impact_level IN ('Advisory', 'OutOfService'))` — value casing follows the Phase 1 PascalCase enum convention. |
| `asset_id` | `INT NULL` | **[EXTENSION]** FK → `facility_assets(asset_id)`. NULL = space-level record (Phase 1 behavior). Non-null = scoped to one unit. |

Constraint: a space-level (`asset_id IS NULL`) record with `impact_level = 'OutOfService'`
blocks the whole space, unchanged from Phase 1. An asset-scoped record never blocks the
space by itself — it only affects booking through the "required facility" trigger in §5.4
**[EXTENSION]**, or through the impact level shown to the requester as an advisory.

### 2.2 `maintenance_impact_history` — new **[CONFIRMED]**

Audit trail for escalation/downgrade, since a single `impact_level` column on
`maintenance_records` only shows the current state.

| Column | Type |
|---|---|
| `history_id` | `INT NOT NULL IDENTITY(1,1)` — PK |
| `maintenance_id` | `INT NOT NULL` — FK → `maintenance_records(maintenance_id)` |
| `old_impact_level` | `NVARCHAR(20) NULL` — NULL on initial creation; `CHECK` in (`'Advisory'`, `'OutOfService'`) |
| `new_impact_level` | `NVARCHAR(20) NOT NULL` — `CHECK` in (`'Advisory'`, `'OutOfService'`) |
| `changed_by` | `INT NOT NULL` — FK → `user_accounts(user_id)` |
| `changed_at` | `DATETIME2 NOT NULL DEFAULT GETDATE()` |
| `change_reason` | `NVARCHAR(MAX) NULL` |

Populated by trigger — see §5.1.

### 2.3 `booking_advisory_acknowledgments` — new **[CONFIRMED]**

Records that a requester was shown, and confirmed, each active advisory at booking time.

| Column | Type |
|---|---|
| `ack_id` | `INT NOT NULL IDENTITY(1,1)` — PK |
| `booking_id` | `INT NOT NULL` — FK → `bookings(booking_id)` |
| `maintenance_id` | `INT NOT NULL` — FK → `maintenance_records(maintenance_id)` |
| `acknowledged_by` | `INT NOT NULL` — FK → `user_accounts(user_id)` |
| `acknowledged_at` | `DATETIME2 NOT NULL DEFAULT GETDATE()` |

Constraint: `UNIQUE (booking_id, maintenance_id)` — one acknowledgement per advisory per
booking.

### 2.4 `auto_approval_policies` — new **[CONFIRMED]**

Defines which space types (or specific spaces) are eligible for instant booking, and under
what conditions.

| Column | Type |
|---|---|
| `policy_id` | `INT NOT NULL IDENTITY(1,1)` — PK |
| `space_type` | `NVARCHAR(30) NULL` — applies to all spaces of this type; `CHECK` matches the `CK_spaces_space_type` whitelist |
| `space_id` | `INT NULL` — FK → `spaces(space_id)`; overrides `space_type` for one specific space |
| `max_participants` | `INT NULL` — additional cap beyond space capacity, if any |
| `requires_advisory_ack` | `BIT NOT NULL DEFAULT 1` |
| `is_active` | `BIT NOT NULL DEFAULT 1` |
| `created_at` / `updated_at` | `DATETIME2 NOT NULL DEFAULT GETDATE()` |

Check: exactly one of `space_type`, `space_id` must be set:

```sql
CONSTRAINT CK_auto_approval_policies_scope CHECK (
    (space_type IS NULL AND space_id IS NOT NULL)
    OR (space_type IS NOT NULL AND space_id IS NULL)
)
```

SQL Server has no array type, so `allowed_booking_types` is stored in a junction table
`policy_booking_types`:

| Column | Type |
|---|---|
| `policy_id` | `INT NOT NULL` — FK → `auto_approval_policies(policy_id)` |
| `booking_type` | `NVARCHAR(30) NOT NULL` — `CHECK` matches the `CK_bookings_booking_type` whitelist |

Composite PK (`policy_id`, `booking_type`).

### 2.5 `booking_decisions` — modified **[CONFIRMED]**

Add:

| Column | Type | Notes |
|---|---|---|
| `decision_source` | `NVARCHAR(10) NOT NULL DEFAULT 'Staff'` | `CHECK` in (`'Staff'`, `'System'`); `'System'` for auto-approval. |
| `decided_by` | `INT NULL` — FK → `user_accounts(user_id)`, **now nullable** | NULL only permitted when `decision_source = 'System'`. |

Enforcement — same-table CHECK constraint (both columns live in `booking_decisions`):

```sql
CONSTRAINT CK_booking_decisions_decision_source CHECK (
    (decision_source = 'System' AND decided_by IS NULL)
    OR (decision_source = 'Staff' AND decided_by IS NOT NULL)
)
```

Rationale for nullable-FK-plus-enum over a sentinel "SYSTEM" user row: a sentinel user
would need fake `role`/`department`/`account_status` values that mean nothing and would
pollute `user_accounts` reporting (e.g. "bookings by department" queries). A nullable FK
with an explicit `decision_source` is one CHECK constraint away from being just as
enforceable and keeps `user_accounts` representing real people only.

### 2.6 `facility_assets` — new **[EXTENSION]**

| Column | Type |
|---|---|
| `asset_id` | `INT NOT NULL IDENTITY(1,1)` — PK |
| `facility_id` | `INT NOT NULL` — FK → `facilities(facility_id)` (the catalogue/type, e.g. "Projector") |
| `space_id` | `INT NOT NULL` — FK → `spaces(space_id)` (current location) |
| `serial_number` | `NVARCHAR(50) NOT NULL` — UNIQUE |
| `asset_status` | `NVARCHAR(20) NOT NULL` — `CHECK` in (`'Available'`, `'InUse'`, `'UnderMaintenance'`, `'Retired'`) |
| `condition` | `NVARCHAR(MAX) NULL` |
| `last_checked_date` | `DATE NULL` |
| `created_at` / `updated_at` | `DATETIME2 NOT NULL DEFAULT GETDATE()` |

`space_facilities.quantity` (Phase 1) and `facility_assets` can drift if maintained
separately. Recommendation: keep `space_facilities` as the Phase-1-compatible catalogue
table (facility *types* present in a space, used for the room-finder query), and treat unit
counts as a **view**, not a duplicated column:

```sql
CREATE VIEW space_facility_summary AS
SELECT fa.space_id,
       fa.facility_id,
       SUM(CASE WHEN fa.asset_status <> 'Retired' THEN 1 ELSE 0 END) AS total_units,
       SUM(CASE WHEN fa.asset_status = 'Available' THEN 1 ELSE 0 END) AS available_units
FROM facility_assets fa
GROUP BY fa.space_id, fa.facility_id;
```

This avoids a normalization violation (a stored `quantity` that must be kept in sync with
the asset rows would be a functional-dependency duplicate — relevant to the Phase 2
3NF validation task).

### 2.7 `space_facility_requirements` — new **[EXTENSION]**

Marks which facility types must have at least one available unit for a space to be
considered usable for its normal purpose.

| Column | Type |
|---|---|
| `space_id` | `INT NOT NULL` — FK → `spaces(space_id)` |
| `facility_id` | `INT NOT NULL` — FK → `facilities(facility_id)` |
| `is_required` | `BIT NOT NULL DEFAULT 0` |

Composite PK (`space_id`, `facility_id`). Empty by default — a space with no rows here has
no "critical asset" concept applied to it, matching current Phase 1 behavior.

### 2.8 `booking_alerts` — new **[EXTENSION]**

Persists the "these bookings are affected by an escalation" result so it survives past the
moment the report is first run, and gives staff a place to mark it handled. Explicitly not
a delivery mechanism — no email/SMS integration, consistent with Phase 1 §17.

| Column | Type |
|---|---|
| `alert_id` | `INT NOT NULL IDENTITY(1,1)` — PK |
| `maintenance_id` | `INT NOT NULL` — FK → `maintenance_records(maintenance_id)` |
| `booking_id` | `INT NOT NULL` — FK → `bookings(booking_id)` |
| `alert_type` | `NVARCHAR(30) NOT NULL` — `CHECK` in (`'MaintenanceEscalated'`) |
| `created_at` | `DATETIME2 NOT NULL DEFAULT GETDATE()` |
| `acknowledged_by_staff_id` | `INT NULL` — FK → `user_accounts(user_id)` |
| `acknowledged_at` | `DATETIME2 NULL` |

### 2.9 `usage_sessions` — no schema change, semantics clarified **[CONFIRMED]**

No new column is needed for early check-out. `is_early_checkout` is a **derived** fact
(`actual_end_time < bookings.requested_end_time`), computed at query time rather than
stored, to avoid a redundant column that could go stale relative to the two timestamps it
would summarize (again, a 3NF concern).

---

## 3. Updated ER relationships (additions only)

- `maintenance_records (1) → maintenance_impact_history (many)`
- `maintenance_records (1) → booking_alerts (many)`
- `bookings (1) → booking_advisory_acknowledgments (many)`, `maintenance_records (1) → booking_advisory_acknowledgments (many)`
- `facilities (1) → facility_assets (many)`, `spaces (1) → facility_assets (many)` **[EXTENSION]**
- `spaces (1) ↔ facilities (many)` via `space_facility_requirements`, in addition to the existing `space_facilities` **[EXTENSION]**
- `auto_approval_policies (1) → policy_booking_types (many)`, `auto_approval_policies` relates to `spaces` (nullable) and implicitly to `space_type` (Phase 1 enum, no FK)

---

## 4. Time-overlap logic: Reserved vs. Actual

Phase 1 already stores both `bookings.requested_start_time/requested_end_time` and
`usage_sessions.actual_start_time/actual_end_time`. Phase 2 does not add columns for this —
it changes **which interval the conflict-check query uses, driven by booking status**.
Status names below are the exact Phase 1 values from `CK_bookings_status` in
`outputs/05-db-definition-G08.sql`:

| Status | Blocks new bookings? | Interval used |
|---|---|---|
| `Pending` | No | — |
| `Approved` | Yes | `[requested_start_time, requested_end_time)` |
| `CheckedIn` | Yes | `[requested_start_time, requested_end_time)` — upper bound stays the reserved end; we don't know an early end until it happens |
| `Completed` | **No** | historical only: `[actual_start_time, actual_end_time)` |
| `Cancelled` / `Rejected` / `NoShow` | No | — |

This is the entire mechanism for "dynamic slot release": the moment staff perform
check-out (`Completed`), the row drops out of the `('Approved', 'CheckedIn')` filter that
every conflict-check and availability query must use. No trigger, timer, or extra column is
required — it falls directly out of modeling the predicate against **current status**
rather than the original static reservation. The only requirement is that the check-out
action and the next availability check happen inside normal transactional visibility (i.e.
no caching of "space busy" state outside the database).

SQL Server has no range type, so overlap of the half-open intervals `[s1, e1)` and
`[s2, e2)` is expressed directly as `s1 < e2 AND e1 > s2`. Conflict-check predicate (used
by both manual approval and instant-booking):

```sql
SELECT 1
FROM bookings b WITH (UPDLOCK, HOLDLOCK)   -- see §6 — locks held until end of transaction
WHERE b.space_id = @space_id
  AND b.status IN ('Approved', 'CheckedIn')
  AND b.requested_start_time < @new_end
  AND b.requested_end_time   > @new_start;
```

For historical reporting (utilization hours, weekday/hour counts — §5 of the business
requirement), use the *actual* interval where a usage session exists, falling back to the
requested interval for bookings that were approved but never checked in:

```sql
SELECT b.booking_id,
       COALESCE(us.actual_start_time, b.requested_start_time) AS effective_start_time,
       COALESCE(us.actual_end_time,   b.requested_end_time)   AS effective_end_time,
       DATEDIFF(MINUTE,
                COALESCE(us.actual_start_time, b.requested_start_time),
                COALESCE(us.actual_end_time,   b.requested_end_time)) / 60.0 AS usage_hours
FROM bookings b
LEFT JOIN usage_sessions us ON us.booking_id = b.booking_id
WHERE b.status = 'Completed';
```

---

## 5. Trigger and constraint logic

Note on T-SQL triggers: SQL Server triggers fire **when the DML statement runs**, not at
commit — there is no PostgreSQL-style deferred/`DEFERRABLE` constraint trigger. Every
trigger below is a set-based `AFTER` trigger that raises an error and rolls back the
statement on violation. Triggers must be the first statement in their batch, so a `GO`
separator precedes and follows each one, exactly as in `05-db-definition-G08.sql`.

### 5.1 Maintenance impact-level history **[CONFIRMED]**

```sql
CREATE TRIGGER TR_maintenance_impact_history
ON maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT: record the initial impact level (old_impact_level = NULL)
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO maintenance_impact_history
            (maintenance_id, old_impact_level, new_impact_level, changed_by, changed_at)
        SELECT i.maintenance_id, NULL, i.impact_level, i.reporter_id, GETDATE()
        FROM inserted i;
    END

    -- UPDATE: record only when impact_level actually changed
    IF UPDATE(impact_level) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO maintenance_impact_history
            (maintenance_id, old_impact_level, new_impact_level, changed_by, changed_at)
        SELECT i.maintenance_id, d.impact_level, i.impact_level,
               CONVERT(INT, SESSION_CONTEXT(N'current_user_id')), GETDATE()
        FROM inserted i
        INNER JOIN deleted d ON d.maintenance_id = i.maintenance_id
        WHERE i.impact_level <> d.impact_level;
    END
END;
GO
```

Implementation note: a trigger has no notion of "which application user issued this
statement" beyond the DB role. `changed_by` on an UPDATE relies on the application setting
`EXEC sp_set_session_context N'current_user_id', @staff_id;` at the start of the session —
SQL Server's replacement for PostgreSQL's `SET LOCAL app.current_user_id`, supported in
SQL Server 2016 and later. This needs to be part of the connection-handling code, not just
the schema.

### 5.2 Escalation → affected-bookings lookup **[CONFIRMED]**

```sql
CREATE TRIGGER TR_maintenance_escalation
ON maintenance_records
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(impact_level)
    BEGIN
        INSERT INTO booking_alerts (maintenance_id, booking_id, alert_type, created_at)
        SELECT i.maintenance_id, b.booking_id, 'MaintenanceEscalated', GETDATE()
        FROM inserted i
        INNER JOIN deleted d ON d.maintenance_id = i.maintenance_id
        INNER JOIN bookings b ON b.space_id = i.space_id
        WHERE d.impact_level = 'Advisory'
          AND i.impact_level = 'OutOfService'
          AND b.status IN ('Approved', 'CheckedIn')
          AND b.requested_start_time < COALESCE(i.completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2))
          AND b.requested_end_time   > i.start_time;
    END
END;
GO
```

`COALESCE(i.completion_time, CAST('9999-12-31 23:59:59' AS DATETIME2))` plays the role of
PostgreSQL's `'infinity'` — an open-ended maintenance period conflicts with every booking
that starts before it ends (and, with no completion time, all future bookings).

This directly implements the reporting need in `business-requirement-P2.md` §5.4 and
answers Hard Case 3. It creates the list; contacting the requester stays a manual staff
action against `booking_alerts`.

### 5.3 Advisory acknowledgement enforcement **[CONFIRMED]**

PostgreSQL's original design used a *deferred* constraint trigger so the check ran at
commit, after the booking row and its acknowledgement rows both existed. SQL Server has no
deferred triggers; the equivalent outcome is achieved with a plain `AFTER` trigger **plus a
required statement order inside the transaction**: insert the booking as `Pending`, insert
the acknowledgement rows, then run the statement that moves the booking to `Approved`. The
trigger fires on that statement, at which point the acknowledgement rows are already
visible in the same transaction:

```sql
CREATE TRIGGER TR_bookings_AdvisoryAckRequired
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(status)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted i
            WHERE i.status IN ('Approved', 'CheckedIn')
              AND EXISTS (
                  SELECT 1
                  FROM maintenance_records m
                  WHERE m.space_id = i.space_id
                    AND m.impact_level = 'Advisory'
                    AND m.status NOT IN ('Completed', 'Cancelled')
                    AND m.start_time <= i.requested_end_time
                    AND (m.completion_time IS NULL OR m.completion_time >= i.requested_start_time)
              )
              AND (
                  SELECT COUNT(DISTINCT m.maintenance_id)
                  FROM maintenance_records m
                  WHERE m.space_id = i.space_id
                    AND m.impact_level = 'Advisory'
                    AND m.status NOT IN ('Completed', 'Cancelled')
                    AND m.start_time <= i.requested_end_time
                    AND (m.completion_time IS NULL OR m.completion_time >= i.requested_start_time)
              ) >
              (
                  SELECT COUNT(DISTINCT a.maintenance_id)
                  FROM booking_advisory_acknowledgments a
                  WHERE a.booking_id = i.booking_id
              )
        )
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('Booking cannot be approved: every active advisory on this space must be acknowledged.', 16, 1);
            RETURN;
        END
    END
END;
GO
```

Application flow: insert the booking as `Pending`, insert the acknowledgement rows, then
update status to `Approved` — all in one transaction. Because the trigger fires when the
status-change statement runs (not at commit), the acknowledgement inserts must physically
precede the status update. This is the only workable order: an attempt to insert
acknowledgements after the status update (in the same or a later transaction) is rejected
by the trigger, since no acknowledgements exist yet when it fires.

Tradeoff vs. the PostgreSQL design: the check is no longer "schema-enforced at commit" but
"trigger-enforced with a documented statement order". The guarantee itself is the same —
the trigger makes the ordering the *only* way to get a booking to `Approved` while
advisories are active — and the constraint is documented here so all three booking paths
(manual, instant, migration scripts) follow it.

### 5.4 Critical-asset booking block **[EXTENSION]**

```sql
CREATE TRIGGER TR_bookings_RequiredAssetCheck
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN space_facility_requirements sfr
            ON sfr.space_id = i.space_id
           AND sfr.is_required = 1
        WHERE i.status IN ('Approved', 'CheckedIn')
          AND NOT EXISTS (
              SELECT 1
              FROM facility_assets fa
              WHERE fa.space_id = sfr.space_id
                AND fa.facility_id = sfr.facility_id
                AND fa.asset_status = 'Available'
          )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Cannot book space: a required facility has no available unit.', 16, 1);
        RETURN;
    END
END;
GO
```

This answers Hard Case 2's actual booking-time consequence: a space isn't blocked because
"a maintenance record exists," it's blocked because a facility marked required for that
space has zero available units — which a maintenance record on the last remaining unit
happens to cause.

---

## 6. Concurrency strategy **[CONFIRMED]** — answers Hard Case 5

SQL Server has no equivalent of PostgreSQL's exclusion constraints (`EXCLUDE USING gist`).
The Phase 1 `AFTER` trigger `TR_bookings_PreventOverlapAndUnavailable` prevents an overlap
from *surviving*, but it cannot prevent one from *happening*: two concurrent transactions
can each run the conflict check, each see only committed (non-conflicting) data, and both
insert — their triggers see no conflict and both commit. The trigger validates, it does not
serialize. Phase 2 therefore adds an explicit serialization strategy in three layers.

### 6.1 Primary defense: stored procedure with SERIALIZABLE + `UPDLOCK`/`HOLDLOCK`

The standard SQL Server pattern: run the conflict check as a `SELECT` that takes **update
locks on range** — `WITH (UPDLOCK, HOLDLOCK)` under `SERIALIZABLE` isolation. `UPDLOCK`
takes update locks on every matching row; `HOLDLOCK` keeps them, together with the
key-range locks that block a concurrent insert into the same range, until the transaction
commits. A concurrent booking attempt on the same space therefore *waits* at its own
conflict check instead of slipping past it; when the first transaction commits, the second
re-reads, sees the committed conflict, and fails cleanly.

```sql
CREATE PROCEDURE usp_CreateBooking
    @requester_id           INT,
    @space_id               INT,
    @requested_start_time   DATETIME2,
    @requested_end_time     DATETIME2,
    @purpose                NVARCHAR(MAX),
    @expected_participants  INT,
    @booking_type           NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Serialize on the space: lock every currently-conflicting row and the
        --    key-range where a conflicting insert could land (UPDLOCK + HOLDLOCK
        --    under SERIALIZABLE), holding both until this transaction commits.
        IF EXISTS (
            SELECT 1
            FROM bookings b WITH (UPDLOCK, HOLDLOCK)
            WHERE b.space_id = @space_id
              AND b.status IN ('Approved', 'CheckedIn')
              AND b.requested_start_time < @requested_end_time
              AND b.requested_end_time   > @requested_start_time
        )
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50001, 'Overlapping approved booking exists for this space.', 1;
        END

        -- 2. Insert the booking as 'Pending' so the advisory-acknowledgement rule
        --    (§5.3) can be satisfied by the application flow:
        --      INSERT booking ('Pending') -> SCOPE_IDENTITY() -> INSERT the required
        --      acknowledgement rows -> UPDATE status to 'Approved'.
        --    The instant-booking path additionally evaluates auto_approval_policies
        --    here and records the decision with decision_source = 'System' (§2.5).

        INSERT INTO bookings
            (requester_id, space_id, requested_start_time, requested_end_time,
             purpose, expected_participants, booking_type, status)
        VALUES
            (@requester_id, @space_id, @requested_start_time, @requested_end_time,
             @purpose, @expected_participants, @booking_type, 'Pending');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;   -- deadlock (1205) or any other failure: caller decides retry
    END CATCH
END;
GO
```

Why this closes the race:

- The conflict `SELECT` takes update locks (`UPDLOCK`) on matching rows and, under
  `SERIALIZABLE`, key-range locks (`HOLDLOCK`) that cover the predicate range *including
  the gap* where a new overlapping row would land — so a concurrent insert of an
  overlapping booking blocks, exactly as an exclusion constraint would.
- Locks are held until `COMMIT`, so the check-then-insert is atomic per space/window.
- When the first transaction commits, a waiting second transaction re-reads under
  `SERIALIZABLE`, sees the now-committed conflict, and fails with the same error. If the
  two transactions interleave such that SQL Server detects a lock cycle, one becomes a
  deadlock victim (error 1205) and the application retries (see §6.4).
- Requests for *different* spaces, or disjoint windows on the same space, take disjoint
  locks — concurrency is sacrificed only where the invariant requires it.

Caveats (to carry into the design-validation document): (a) granular key-range locking
requires an index matching the predicate — the filtered index from §7
(`space_id, requested_start_time, requested_end_time WHERE status IN ('Approved','CheckedIn')`)
provides it; without it SQL Server may escalate to a table lock, which is still correct but
reduces concurrency. (b) Under heavy contention, lock waits and deadlock retries are
expected behavior, not failures. (c) Every code path that creates or approves bookings
(manual approval procedure, instant-booking procedure, any future API) must run the
conflict check with these hints inside a serializable transaction — this application
discipline is what replaces the exclusion constraint.

### 6.2 Alternative: per-space application lock (`sp_getapplock`)

If the team prefers a simpler mental model over range-lock mechanics, `sp_getapplock`
serializes booking creation per space without relying on `SERIALIZABLE` key-range locking:

```sql
EXEC sp_getapplock
    @Resource   = CONCAT('booking_space_', @space_id),
    @LockMode   = 'Exclusive',
    @LockOwner  = 'Transaction',
    @LockTimeout = 10000;   -- ms; returns 0 on success, -1 on timeout

-- overlap check (plain SELECT is enough — this transaction is now the only
-- one allowed to create bookings for this space), then insert the booking,
-- acknowledgement rows, and the status update, in the same transaction.
```

- Guarantees at most one transaction inside the check-then-insert sequence per space at a
  time — the same effect as §6.1 with less machinery.
- Tradeoffs: the lock is application-defined, not schema-enforced — every code path must
  remember to take it; and it serializes *all* bookings on a space, including
  non-conflicting windows, whereas §6.1's range locks only block genuinely conflicting
  ranges.
- Can be combined with §6.1 (take the application lock first, then the hinted conflict
  check becomes belt-and-braces).

### 6.3 Defense-in-depth: Phase 1 trigger remains

`TR_bookings_PreventOverlapAndUnavailable` stays in place as a backstop for any path that
bypasses the stored procedures. It cannot, by itself, prevent the race (see §6 lead-in), so
it is a validation layer, not the concurrency mechanism.

### 6.4 Transaction isolation for multi-statement flows

The surrounding logic — read `auto_approval_policies`, decide, insert booking, insert
acknowledgement rows — is a multi-statement read-then-write sequence with its own race
potential (e.g. two instant requests both read the same policy and both believe they'll be
first). Wrap it in a serializable transaction:

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
-- evaluate policy, check advisories, insert booking + acknowledgements
COMMIT TRANSACTION;
```

Where PostgreSQL signals a serialization failure (SQLSTATE 40001), SQL Server instead
raises a **deadlock error (1205)** or a lock timeout (1222). The application retries on
1205/1222 with a bounded retry count and backoff. If the retried attempt then hits the
overlap error from §6.1 instead, the slot was genuinely taken by a concurrent commit — see
the open question in `business-requirement-P2.md` §9 for what should happen to the losing
request.

---

## 7. Indexing implications (summary — full analysis in `15-index-tuning-report-G08.md`)

- The conflict-check predicate in §4 and the range-lock pattern in §6.1 need a **filtered
  index** over the exact predicate, so SQL Server can seek efficiently and take granular
  key-range locks:

```sql
CREATE INDEX IX_bookings_space_status_time
ON bookings (space_id, requested_start_time, requested_end_time)
WHERE status IN ('Approved', 'CheckedIn');
```

- Room-finder query (`business-requirement-P2.md` §5, item 3) needs a composite index on
  `spaces (space_type, capacity, current_status)` plus a join against
  `space_facility_summary` (§2.6). Facilities remain in a relational junction table, so no
  PostgreSQL-style `GIN`/array index is needed in SQL Server.
- The two other reporting queries selected by the team for detailed tuning should each get
  their own before/after comparison (actual execution plan plus `SET STATISTICS TIME, IO`)
  in the index-tuning report — not duplicated here.

---

## 8. Migration approach (summary — full script in `10-schema-migration-G08.sql`)

- All new tables are additive; no existing Phase 1 table is dropped or renamed. Create the
  FK target tables first (`facility_assets` before `maintenance_records.asset_id`).
- `maintenance_records.impact_level` is a new `NOT NULL` column on an existing table with
  existing rows — add it with `DEFAULT 'OutOfService'` to backfill existing rows, since
  that was the only impact level Phase 1's model supported (every Phase 1 maintenance
  record already fully blocked its space), then drop the default if it should not persist.
- `booking_decisions.decided_by` changes from `NOT NULL` to nullable — existing rows are
  unaffected since they all have a real staff `decided_by` already; add `decision_source`
  with `DEFAULT 'Staff'`.
- The §6.1 procedure and the §7 filtered index should be deployed only after confirming no
  existing data already violates the overlap rule — run the conflict-check `SELECT` as a
  plain read first, not blindly against production data (the Phase 1 trigger should already
  guarantee this, but verify).

---

## 9. Out of scope (carried over from Phase 1 §17, unchanged)

Payment, real-time access-control hardware, QR scanning, calendar integration, **email
notification delivery**, recurring bookings, mobile app, AI recommendations, full SSO,
advanced analytics dashboard. Phase 2's escalation alerts (§5.2) and advisory
acknowledgements (§5.3) are in-app records only — none of them require adding an email or
SMS integration.
