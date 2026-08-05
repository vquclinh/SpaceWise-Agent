# Audit — Output 10 Schema Migration Final Refinement (Atomicity Guards + Space-Status Sync Trigger + Per-Space Verification)

> Date: 2026-08-06
> Operator/member: Huynh Le Bao Thi
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: none (direct prompt)

## Task goal

Final refinement of `outputs/10-schema-migration-G08.sql` (Task 10) with four required changes, applied **only** to Output 10. Output 09 (`09-updated-erd-and-logical-design-G08.md`) is the immutable Phase 2 architectural baseline and was deliberately NOT modified:

1. Confirm E2 (`TR_bookings_AdvisoryAckRequired`) already uses a robust `NOT EXISTS` (not a COUNT-vs-COUNT comparison) — verified present, no edit needed.
2. Wrap the B2 `facility_assets` backfill DML in `EXEC(N'...')` so it compiles after the same-batch `CREATE TABLE` of `facility_assets` (compile-safety without leaving the single transaction).
3. Add a hidden implementation trigger `TR_maintenance_SyncSpaceStatus` that keeps `spaces.current_status` consistent with maintenance impact levels, so the legacy Phase 1 overlap trigger treats Advisory rooms as bookable without modifying any Phase 1 code.
4. Enhance the verification section: report per-`space_id` (and per-`facility_id`) asset-count mismatches with an explicit `ERROR: Space [ID] count mismatch` message, instead of only a coarse aggregate warning.

Keep the existing max-safety atomicity guards throughout: single batch, `SET XACT_ABORT ON`, `BEGIN TRY`/`BEGIN CATCH` with `IF XACT_STATE() <> 0 ROLLBACK TRANSACTION`, `THROW`, and one `COMMIT TRANSACTION`.

## Files created / changed

- `outputs/10-schema-migration-G08.sql` — refined (B2 backfill block, new E8 trigger, verification parity block). 763 lines → 796 lines.
- `docs/audits/56-output10-refinement-space-status-sync-audit.md` — this audit.

## What was evaluated

- The four requested fixes in `outputs/10-schema-migration-G08.sql` against AGENTS.md §4 (SQL Server-only syntax) and §5 (Phase 2 technical rules: impact levels, concurrency, derived facts), and §8 (audit policy).
- E2 NOT EXISTS pattern (lines ~359–388) — confirmed already robust (not a COUNT comparison), documented in the file comment.
- Consistency of the new sync trigger with the Phase 1 sample data (`outputs/06-sample-data-G08.sql`: M1→Space 5 active, M2→Space 6 Completed, M3→Space 1 Assigned/future, M4→Space 10 Reported) and with the legacy Phase 1 trigger `TR_bookings_PreventOverlapAndUnavailable` (`outputs/05-db-definition-G08.sql`).
- Correctness of the `EXEC(N'...')` quote-escaping (`''` doubling) and of the OPEN/CLOSE/DEALLOCATE lifecycle of the new parity cursor.
- Preservation of Phase 1 data values at migration time: the sync trigger does **not** run an initial mass backfill of `current_status` (ALTER ADD with DEFAULT does not fire triggers), and it never overwrites non-maintenance states.

## Issues found

1. B2 backfill DML ran inline in the batch: it targets `facility_assets`, which is created by a `CREATE TABLE` earlier in the same batch. SQL Server compiles the whole batch before execution, so the DML referenced a table the compiler had not seen yet — a batch-compile resolution risk (the migration could fail before anything ran). Other DML/DDL in the file (D1 history backfill, all triggers, the view) already used `EXEC(N'...')`; B2 was the inconsistent outlier.
2. `spaces.current_status` was static after migration: the Phase 2 impact-level system is implemented via `maintenance_records.impact_level` (backfilled to `'OutOfService'` for all Phase 1 records), but `current_status` would never react to new maintenance, so the legacy Phase 1 trigger (which blocks bookings when `current_status IN ('UnderMaintenance','TemporarilyClosed','Retired')`) could not distinguish Advisory (bookable) from OutOfService (blocked) rooms going forward.
3. The verification block only compared total `COUNT(facility_assets)` vs `SUM(space_facilities.quantity)`. A compensating error (space A over-created, space B under-created) could pass the aggregate check, so it could not identify exactly which space had a parity problem.
4. A blind "release to Available" would be unsafe: if the sync trigger simply set `current_status = 'Available'` whenever no active OutOfService record exists, it would un-close a `TemporarilyClosed`/`Retired` space and re-open a space marked `InUse`, corrupting the Phase 1 baseline.

## Changes made

- **B2 backfill wrapped in EXEC (line 124):** the whole Numbers-table `INSERT INTO dbo.facility_assets` statement is now inside `EXEC(N'...')` with `''`-escaped literals (`N''SN-''`, `N''-''`, `N''0000''`, `N''Available''`), terminated by `WHERE sf.quantity > 0;');` — deferred compilation resolves the same-batch `CREATE TABLE` ordering while keeping the backfill inside the single transaction. A comment explains the rationale and that the serial scheme is globally unique.
- **New hidden trigger E8 `TR_maintenance_SyncSpaceStatus` (line 586):** `AFTER INSERT, UPDATE, DELETE` on `maintenance_records`. It collects the affected `space_id`s from `inserted`/`deleted`, then updates `spaces.current_status`:
  - any **active** record (`status NOT IN ('Completed','Cancelled')`) with `impact_level = 'OutOfService'` ⇒ `'UnderMaintenance'` (blocked);
  - otherwise, only maintenance-governed statuses (`UnderMaintenance`/`Available`) are released to `'Available'` ⇒ Advisory-only rooms become bookable, "tricking" the legacy Phase 1 trigger with no Phase 1 code change;
  - `TemporarilyClosed`/`Retired`/`InUse` are never overwritten (guard against issue 4). Sets `updated_at = GETDATE()`.
- **Per-space parity verification (lines 738–769):** new `@parity` CURSOR over `space_facilities` grouped by `(space_id, facility_id)` with `HAVING SUM(quantity) <> (COUNT of facility_assets rows)`; each mismatch prints `ERROR: Space <id> count mismatch` plus `(facility_id <id>: expected <n>, actual <m>)`; ends with a mismatch-pair total. The aggregate `@v_assets <> @v_sumqty` check is retained as a coarse gate; history-count and Phase 1 data-preservation spot checks unchanged.

## Improvement classification

- Output refinement
- Validation/test improvement (per-space verification catches compensating errors; structural sync replaces a narrative-only "status will be kept up to date" claim)
- No agent/skill/command change needed

## Validation commands run

- PowerShell static-analysis script over `outputs/10-schema-migration-G08.sql`:
  - counts of `EXEC(N'` opens vs `');` terminators,
  - counts of `CREATE TRIGGER` / `CREATE VIEW` / `BEGIN TRY` / `COMMIT TRANSACTION` / `ROLLBACK TRANSACTION`,
  - forbidden-token scan: `tsrange`, `EXCLUDE`, `FORMAT(`, `gist`, `infinity`.
- Grep (ripgrep) for `EXEC(N'` to list every wrapped statement, and for `CREATE TRIGGER|CREATE VIEW|ROLLBACK TRANSACTION` to reconcile trigger/view counts against comments and trigger bodies.
- Read-back of every edited region (B2 block, E8 trigger, verification cursor) and of the surrounding Phase boundaries.

## Validation results

- 10 real `EXEC(N'...')` statements: B2 backfill, D1 history backfill, 8 triggers (E1–E8), 1 view — all with proper terminators; the remaining `');` matches are legitimate DEFAULT constraints / string literals inside trigger bodies.
- 8 `EXEC(N'CREATE TRIGGER ...')` (E1–E8 incl. the new `TR_maintenance_SyncSpaceStatus`), 1 `EXEC(N'CREATE VIEW ...')`.
- Single transaction preserved: 1 `BEGIN TRY`, 1 `COMMIT TRANSACTION`; `ROLLBACK TRANSACTION` hits are the 3 trigger-body violation rollbacks plus the CATCH `XACT_STATE` rollback — all legitimate.
- Forbidden PostgreSQL tokens all 0 (`tsrange`, `EXCLUDE`, `FORMAT(`, `gist`, `infinity`) — SQL Server-only syntax confirmed.
- Quote-escaping in the new `EXEC(N'...')` bodies verified (`''` doubling), cursor lifecycle `OPEN`/`FETCH`/`CLOSE`/`DEALLOCATE` balanced, variable names consistent.

## Risks / caveats

- **No SQL Server execution performed** (no SQL Server container/Azure SQL was available in this session). Syntax validated by static inspection only; the actual migration must be run against a SQL Server-compatible environment (AGENTS.md §4/§9) before sign-off.
- The sync trigger only governs **future** maintenance changes. Phase 1 `current_status` values are preserved verbatim at migration time (ALTER ADD DEFAULT does not fire triggers, and no mass UPDATE is issued). This is intended: space 5 stays `UnderMaintenance`, space 1 stays `Available` despite its future-dated M3 record — Task 12's impact-level checks, not `current_status`, enforce blocking post-migration.
- Design tension recorded: after migration every Phase 1 maintenance record is backfilled to `impact_level = 'OutOfService'`, so any *future* edit to a legacy record (or its space) will make the sync trigger set that space `UnderMaintenance` even if the original Phase 1 `current_status` was `InUse`/`Available` — correct Phase 2 semantics, but a visible behavior change. The `TemporarilyClosed`/`Retired`/`InUse` guard is not applied to the `OutOfService → UnderMaintenance` branch (per the explicit requirement that an active OutOfService record always blocks); confirm this is acceptable at review.
- Cursor is small (per space/facility pair) and runs once inside the transaction; acceptable verification cost.

## Git status summary

- New (untracked): `outputs/10-schema-migration-G08.sql` (refined in this session), `docs/audits/56-output10-refinement-space-status-sync-audit.md` (this audit).
- No commit requested; nothing committed.

## Recommended next steps

- Run `outputs/10-schema-migration-G08.sql` on a SQL Server-compatible environment (local SQL Server, SQL Server container, or Azure SQL) and confirm: success messages, per-space parity prints all `OK`, E8 present in `sys.triggers`, and `spaces.current_status` reacts correctly to INSERT/UPDATE/DELETE on `maintenance_records` (test: advisory-only ⇒ bookable; OutOfService ⇒ `UnderMaintenance`).
- Confirm the `OutOfService ⇒ UnderMaintenance` precedence overrides `InUse`/`TemporarilyClosed` is acceptable per the team's reading of `req/business-requirement-P2.md` tag [CONFIRMED] item 8.
- Tasks 11/12: ensure the concurrency procedures (instant + manual approval) serialize on a resource shared with the maintenance escalation path, and that E8's `spaces` UPDATE cannot deadlock with booking-approval lock ordering.
- Team review of Task 10 before moving to Tasks 11–16.
