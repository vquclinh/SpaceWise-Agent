# Rubric: 10-schema-migration-G<Group#>.sql

Phase 2 — specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions).

## Source of truth
Grade against three inputs:
- `09-updated-erd-and-logical-design-G<Group#>.md` — every structural change described
  there must appear as a DDL statement here, and nothing more.
- Phase 1 `05-db-definition-G<Group#>.sql` — the baseline schema being migrated; every
  Phase 1 table must still exist and be intact after this script runs.
- Phase 2 requirement sections 1.1–1.2 — ground truth for the business rules that must
  be enforced by the new constraints and triggers.

## How to grade (mechanical step first)
This script must be run **on top of** the Phase 1 schema (task 05) and Phase 1 sample
data (task 06), not against a clean database. Before scoring anything else:
1. Stand up Phase 1 (run task 05 DDL + task 06 data).
2. Run this migration script.
3. Confirm no errors and that Phase 1 data is still intact and queryable.

If the script cannot run on top of Phase 1 without errors, that is a blocker regardless
of how well the individual statements are written. If you cannot execute, manually trace
the script's statements against the Phase 1 schema and flag this limitation.

## Criteria

### 1. Non-destructive migration (weight: high)
The script must not drop or truncate any Phase 1 table, column, or constraint unless the
change is explicitly required by Phase 2 and the dropped element is replaced. Verify:
- No `DROP TABLE` for Phase 1 tables.
- No `DROP COLUMN` for Phase 1 columns that are still needed.
- No silent rename of Phase 1 columns that breaks downstream Phase 1 queries.
- Existing Phase 1 data survives the migration — all rows that were present before the
  script runs are still present and correct after it runs.

If any destructive statement appears, check whether it is justified by the Phase 2
requirement. If not, classify as blocker severity.

### 2. Adding impact_level to MaintenanceRecord (weight: high)
Must appear as an `ALTER TABLE` statement (not a `DROP + CREATE`). Check:
- Column added with correct name, type (e.g. `VARCHAR` or `NVARCHAR`), and NOT NULL
  constraint.
- Because existing Phase 1 maintenance rows have no impact level yet, the `ALTER TABLE`
  must handle the NOT NULL constraint correctly — either:
  - Add as nullable first, backfill with a default value (e.g. `'advisory'` or
    `'out-of-service'`) via an `UPDATE`, then add the NOT NULL constraint, or
  - Add with a temporary `DEFAULT` then drop the default after backfill.
  - Alternatively, add as NOT NULL WITH DEFAULT and document the assumption.
- CHECK constraint added enforcing domain {out-of-service, advisory} — exact spelling
  and case must match what task 09 specified and what task 16's queries will filter on.
- If the group chose to model level change history as a separate table
  (`MaintenanceLevelHistory`), verify that table is created here with correct columns,
  PKs, and FKs before the `impact_level` column is added to the base table.

### 3. BookingAdvisory table (weight: high)
If task 09 specified a junction entity, a `CREATE TABLE BookingAdvisory` (or equivalent
name) must appear here. Verify:
- Composite PK on (`booking_id`, `maintenance_id`) or equivalent.
- FK to `Booking` table — correct column, matching type, referential action specified.
- FK to `MaintenanceRecord` table — same checks.
- `acknowledged_at` column: correct timestamp type, NOT NULL.
- `GO` batch separator before and after (SQL Server requirement, consistent with Phase 1
  trigger pattern from task 05).
- Table did not exist in Phase 1 — this must be a `CREATE TABLE`, not an `ALTER TABLE`.

If task 09 instead used a simpler column on `Booking`, verify `ALTER TABLE Booking ADD`
statement with appropriate column and nullability.

### 4. Instant-booking / approval_mode support (weight: medium)
If task 09 added a `booking_type` or `approval_mode` column to `Booking`, verify the
corresponding `ALTER TABLE Booking ADD` statement:
- Correct column name matching task 09.
- Domain constrained (CHECK or ENUM equivalent).
- Nullability appropriate — if all Phase 1 bookings are assumed to be staff-approval
  path, a default of `'staff'` on existing rows is sensible; flag if left NULL on all
  existing rows without explanation.

If task 09 did not add this column (i.e. instant-booking path handled at application level
or via status only), verify no orphaned column appears here.

### 5. Updated trigger(s) (weight: high)
Phase 2 changes two business rules that Phase 1 enforced via triggers:
- The overlap check is unchanged structurally, but must still hold for both booking paths
  (instant and staff). Verify the existing trigger is not accidentally broken by the migration.
- The availability check (space not under maintenance) must now be **conditioned on
  impact_level = 'out-of-service'** — advisory records must no longer block booking.

This means either:
- The Phase 1 availability trigger is `ALTER`ed or replaced with a new version that
  adds the `impact_level = 'out-of-service'` filter, or
- The trigger is dropped and recreated with the updated logic.

Check the updated trigger body explicitly — this is the most operationally critical change
in the entire migration. A trigger that still blocks bookings for advisory maintenance
directly violates the Phase 2 requirement regardless of how correct the schema additions
are. Verify the gate condition reads something like:

```sql
-- Only block if there is an out-of-service maintenance record overlapping the booking
WHERE m.impact_level = 'out-of-service'
  AND m.space_id     = i.space_id
  AND m.start_time   < i.end_time
  AND m.end_time     > i.start_time
  AND m.status      <> 'Completed'
```

### 6. Escalation detection support (weight: medium)
The Phase 2 requirement states that when a maintenance record is escalated from advisory
to out-of-service, already-approved overlapping bookings must be identifiable. Check
whether the migration adds any mechanism to support this:
- If the group added a `level_changed_at` timestamp to `MaintenanceRecord`, verify the
  `ALTER TABLE` statement adding it (nullable — not all records will have a level change).
- If the group added a `MaintenanceLevelHistory` table, verify it is created correctly
  here (see criterion 2 for structure).
- If neither is added, flag as a major gap — the escalation reporting query (task 16)
  requires knowing when the level changed to distinguish bookings approved before vs.
  after escalation. Without it, the query cannot be written correctly.

### 7. Migration approach documented (weight: medium)
The requirement states: "Preserve existing data or document the migration approach."
The script must include comments explaining:
- What each block of statements does and why (e.g. "Step 1: add impact_level column as
  nullable, Step 2: backfill with default value, Step 3: enforce NOT NULL").
- The assumption made when backfilling existing maintenance rows with a default
  impact_level — this is a real business decision (are all existing maintenance records
  advisory or out-of-service?) and must be documented rather than silently defaulted.
- Whether any data loss is intentional and why (there should be none).

Flag if the script is undocumented SQL with no explanatory comments — a grader or future
developer cannot safely run an undocumented migration.

### 8. Idempotency / safety guards (weight: low)
Good practice for migration scripts:
- `IF NOT EXISTS` guards on new table creation (so the script can be re-run safely).
- `IF COL_EXISTS` or equivalent before `ALTER TABLE ADD COLUMN` (SQL Server:
  check `sys.columns` before adding).
- Wrapping each logical step in a transaction with a `ROLLBACK` on error.

Not required, but reward if present. Flag absence only as minor severity since the
requirement does not mandate it — but note it in the suggested fixes as a real-world
best practice.

### 9. Correct statement ordering (weight: medium)
SQL Server requires:
- New tables (`BookingAdvisory`, `MaintenanceLevelHistory` if used) created before any
  FK referencing them.
- Trigger modifications after the table alterations they depend on.
- `GO` batch separators between DDL statements and trigger definitions.
- `UPDATE` backfill before `NOT NULL` constraint enforcement.

Flag any ordering violation as major severity — it will cause the script to fail mid-run
and leave the database in a partially migrated state.

## Scoring guidance
- Non-destructive migration and updated trigger (criteria 1 & 5) ~35% combined — these
  are the safety-critical checks; a migration that corrupts Phase 1 data or breaks the
  advisory booking rule is a blocker regardless of everything else.
- impact_level column and BookingAdvisory table (criteria 2 & 3) ~30% combined —
  the two structural additions that are the core deliverable of this task.
- Escalation support, concurrency, and documentation (criteria 6, 7) ~20% combined.
- Instant-booking column, statement ordering, and idempotency (criteria 4, 8, 9)
  ~15% combined.

## Common failure patterns to watch for
- `DROP TABLE MaintenanceRecord; CREATE TABLE MaintenanceRecord (... impact_level ...)`
  instead of `ALTER TABLE` — destroys all Phase 1 maintenance data, blocker severity.
- `ALTER TABLE MaintenanceRecord ADD impact_level VARCHAR(20) NOT NULL` with no
  backfill step — will fail on SQL Server if existing rows are present (can't add NOT NULL
  column without a default when rows exist).
- Phase 1 availability trigger left unmodified — still blocks advisory-maintenance
  bookings, directly violating Phase 2 requirement; the single most likely critical miss.
- `acknowledged_at` on `BookingAdvisory` declared as nullable — defeats the purpose
  of the column (a row only exists when acknowledgement was given, so the timestamp
  is always known).
- No comment on what default impact_level was assigned to existing maintenance rows —
  this is a silent business assumption that must be surfaced.
- Statement ordering error: `BookingAdvisory` created after an FK index or trigger that
  references it.