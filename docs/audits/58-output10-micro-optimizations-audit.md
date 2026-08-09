# Audit — Output 10 Micro-Optimizations (TempDB, Conversions, Dead Code)

> Date: 2026-08-05
> Operator/member: (session)
> Tool: OpenCode (edit + read + grep)
> Provider/model/variant: deepseek-v4-flash-free (opencode/deepseek-v4-flash-free)
> OpenCode command used: none (direct conversation task)

## Task goal

Apply three high-performance micro-optimizations to
`outputs/10-schema-migration-G08.sql` (Task 10 DDL) without changing
architecture or business logic:

1. **Eliminate TempDB contention (Trigger 2)** — replace the local temporary
   table `#mv_sync_affected` in `TR_maintenance_SyncAssetStatus` with a table
   variable (`@mv_sync_affected`).
2. **Fix implicit conversion risks (Triggers 3, 5, 6)** — replace hardcoded
   "infinite time" string literals with an explicit
   `CAST('9999-12-31' AS DATETIME2)`.
3. **Remove redundant dead code (Section 2.1)** — delete the explicit
   `UPDATE dbo.maintenance_records ... WHERE impact_level IS NULL` backfill,
   which a `NOT NULL ... DEFAULT` already performs inline during the ALTER.

Constraints: preserve all structural fixes (`CREATE OR ALTER`, XOR scope
checks, filtered unique indexes, `IF TRIGGER_NESTLEVEL() > 1 RETURN;`); 100%
MS SQL Server syntax + snake_case; no Skill file edits; no audit file created
at execution time (audit written on explicit later request).

## Files created / changed

- Changed: `outputs/10-schema-migration-G08.sql`
  - Section 2.1 comment (renumbered items, backfill step removed)
  - Trigger 2 body (table variable conversion)
  - Trigger 3 + Trigger 5 predicates (explicit `CAST` on max-date sentinel)
- Created: `docs/audits/58-output10-micro-optimizations-audit.md` (this audit)

## What was evaluated

- **Trigger 2** (`TR_maintenance_SyncAssetStatus`): temporary table lifecycle
  in a hot DML path. Local temp tables allocate from `tempdb`, participate in
  transaction logging and schema modification (`sp_reset_connection`), and can
  incur contention under concurrent inserts/updates; the affected set here is
  small and single-statement, so a table variable is the right, allocation-free
  choice.
- **Triggers 3 / 5 / 6** (`TR_maintenance_escalation`,
  `TR_bookings_AdvisoryAckRequired`, `TR_bookings_RequiredAssetCheck`):
  scanned for hardcoded "max time" string literals
  (`'9999-12-31 23:59:59.9999999'`). Only Triggers 3 and 5 contained them;
  Trigger 6 was audited and contains **no** date constant — nothing to fix.
  The string literal forces implicit type resolution (parser guess, precision
  mismatch risk) and can raise range errors if column datatype ever narrows;
  `CAST('9999-12-31' AS DATETIME2)` pins the type explicitly.
- **Section 2.1** — the `ADD impact_level NVARCHAR(20) NOT NULL DEFAULT
  N'OutOfService'` ALTER backfills all legacy rows inline via the default; the
  subsequent guarded `UPDATE ... WHERE impact_level IS NULL` is a provably
  no-op (column is `NOT NULL`) that still scans the full table under an
  update-optimization mask — pure migration overhead.
- **Structural integrity** — confirmed `CREATE OR ALTER TRIGGER` × 6,
  `IF TRIGGER_NESTLEVEL() > 1 RETURN;` guards, XOR scope CHECKs, and the four
  filtered unique indexes (`UQ_booking_alerts_maint`, `UQ_booking_alerts_asset`,
  `UQ_auto_approval_policies_space_id`, `UQ_auto_approval_policies_active_space_type`)
  all remain intact.

## Issues found

1. TempDB allocation/logging on every `TR_maintenance_SyncAssetStatus` fire
   from the `#mv_sync_affected` temp table (two `DROP TABLE` statements in the
   same batch — wasteful under concurrency).
2. Two implicit-conversion-prone string literals for the infinite-end sentinel
   in Triggers 3 and 5.
3. Redundant full-table `UPDATE` backfill in Section 2.1 that is provably a
   no-op on a `NOT NULL DEFAULT` column (extra table scan during migration).

## Changes made

1. **Trigger 2 (TempDB contention)** —
   `DECLARE @mv_sync_affected TABLE (asset_id INT NOT NULL);` +
   `INSERT INTO @mv_sync_affected (asset_id) SELECT DISTINCT asset_id ...`
   (UNION ALL of `inserted`/`deleted`); both `INNER JOIN #mv_sync_affected x`
   references renamed to `@mv_sync_affected`; both `DROP TABLE #mv_sync_affected;`
   statements removed (the `IF NOT EXISTS` early-exit now just `RETURN`s; table
   variables auto-deallocate at batch end).
2. **Triggers 3 & 5 (implicit conversion)** —
   `'9999-12-31 23:59:59.9999999'` → `CAST('9999-12-31' AS DATETIME2)` in the
   `COALESCE(m.completion_time, ...)` predicates. Behavior equivalent (the
   sentinel remains the DATETIME2 max date; overlap semantics unchanged).
3. **Section 2.1 (dead code)** — deleted the entire
   `UPDATE dbo.maintenance_records SET impact_level = N'OutOfService'
   WHERE impact_level IS NULL;` block and its `GO`; the transient default is
   still dropped right after the ALTER, so future inserts must state the level.
   Section comment renumbered (5 → 4 items) and the backfill mention replaced
   with "backfilled inline by the DEFAULT during the ALTER".

## Phase 2 step / output evaluated

- Task 10 (schema migration) — `outputs/10-schema-migration-G08.sql`.

## Improvement classification

* Output refinement

## Validation commands run

- `grep` on `outputs/10-schema-migration-G08.sql`:
  `#mv_sync_affected|9999-12-31 23|backfill|Backfill`
- `grep`: `CREATE OR ALTER TRIGGER|TRIGGER_NESTLEVEL|CAST('9999-12-31' AS DATETIME2)`
- Read-back of Trigger 2 body (lines ~755–804) and Section 2.1.
- No SQL execution against a live instance in this task (per AGENTS.md §9 SQL
  deliverables must be validated on SQL Server only).

## Validation results

- No `#mv_sync_affected` references remain; both `DROP TABLE` calls removed.
- `CAST('9999-12-31' AS DATETIME2)` present at both predicates (Triggers 3
  and 5); Trigger 6 verified to need no change.
- Backfill `UPDATE` block removed; remaining "backfill" text is documentation
  only, accurate to the inline-default behavior.
- All 6 `CREATE OR ALTER TRIGGER` + recursion guards, XOR scope checks, and
  filtered unique indexes intact — grep confirmed.

## Risks / caveats

- Table variables do not have statistics and pre-2022 versions may get fixed
  cardinality estimates; here the set is bounded by the rows in `inserted` ∩
  `deleted` (small, per-statement), so the tradeoff is acceptable and strictly
  less TempDB-risky than the temp table. If the maintenance-records batch size
  ever becomes very large, re-evaluate.
- The changed file still needs a SQL Server-compatible smoke run (per AGENTS.md
  §9/§5) — e.g. on the scratch `G08_MigrationTest` (`localhost\MSSQL2025`):
  replay the full `10`, then fire an asset-scoped maintenance insert/update to
  confirm the sync trigger and the relocation/escalation paths still behave.

## Git status summary

- Untracked: `.opencode/skills/db-design-pipeline/10-schema-migration/`,
  `outputs/10-schema-migration-G08.sql`, `docs/audits/56-...`, `docs/audits/57-...`,
  `docs/audits/58-output10-micro-optimizations-audit.md` (this audit).
- No commits made (per repo policy, no commit unless asked).

## Recommended next steps

1. Run the migration script against the scratch SQL Server DB and re-run the
   functional trigger tests (asset-sync flip/release, escalation idempotency,
   advisory-ack gate, required-asset gate).
2. Optionally fold the "prefer table variables for tiny per-row DML sets" and
   "pin max-date sentinels with explicit `CAST`" notes into
   `10-schema-migration/SKILL.md` section 4 for future tasks.