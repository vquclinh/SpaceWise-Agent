# Audit — Output 10 Fail-Fast Fix (RAISERROR before NOEXEC)

> Date: 2026-08-07
> Operator/member: (session)
> Tool: OpenCode (edit + read + grep)
> Provider/model/variant: deepseek-v4-flash-free (opencode/deepseek-v4-flash-free)
> OpenCode command used: none (direct conversation task)

## Task goal

Fix the silent-failure bug in the fail-fast mechanism of
`outputs/10-schema-migration-G08.sql` (Task 10). Previously the Stage 1
`CATCH` block did `SET NOEXEC ON` **before** signaling (first with `THROW`,
then with `RAISERROR`). Because `SET NOEXEC ON` makes the session parse-but-not
-execute, the subsequent `THROW`/`RAISERROR` never ran, so client tools / CI-CD
(`sqlcmd -b`, pipelines) saw exit code 0 despite the migration rollback —
a rolled-back failure masked as success.

Required refactor (per-user sketch):

1. Capture `ERROR_MESSAGE()`, `ERROR_SEVERITY()`, `ERROR_STATE()` into
   variables.
2. `IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;`
3. Print error details (`PRINT`).
4. `RAISERROR(@ErrMsg, @ErrSeverity, @ErrState);` **before** NOEXEC is engaged.
5. `SET NOEXEC ON` integrity — must still skip Stage 2 (triggers + view) on
   failure, restartable/idempotent, with `SET NOEXEC OFF` resetting the session
   at script end.

## Files created / changed

- Changed: `outputs/10-schema-migration-G08.sql`
  - Stage 1 `CATCH` block: full error-capture → rollback → print →
    `#migration_failed` marker → `RAISERROR` flow
  - New dedicated FAIL-FAST SAFETY LOCK batch (right after `END CATCH; GO`)
    that consumes the marker and enables `SET NOEXEC ON`
  - Marker cleanup (`DROP TABLE #migration_failed`) before `BEGIN TRY`
  - Header comment + changelog updated; FAIL-FAST RESET comment updated
- Created: `docs/audits/59-output10-fail-fast-RAISERROR-audit.md` (this audit)

## What was evaluated

- **Why `THROW`/`SET NOEXEC` order matters:** `SET NOEXEC ON` takes effect for
  the *rest of the batch/session and does not itself raise an error. A
  subsequent `THROW` is parsed but **not executed**, so sqlcmd returns 0 —
  silent rollback. The fix must let the error reach the client **before** the
  session enters NOEXEC mode.
- **Batch-abort reality:** `RAISERROR` with severity ≥ 11 aborts the current
  batch. Therefore a `SET NOEXEC ON` placed after `RAISERROR` in the same batch
  would *also* never run — so the ordering must be: signal failure in the CATCH
  batch (via `RAISERROR`), then enable NOEXEC in a **later batch**.
- **State persistence across batches:** a local variable does not survive a
  `GO` boundary. The failure marker must persist — chosen `#migration_failed`
  (session temp table) instead of a variable, consumed by the safety-lock batch.
- Idempotency/restartability preserved: marker dropped before `BEGIN TRY`.
- Existing structural invariants (from previous passes) re-verified:
  `CREATE OR ALTER TRIGGER` × 6, `CREATE OR ALTER VIEW` × 1, `IF
  TRIGGER_NESTLEVEL() > 1 RETURN;` × 6, `IF NOT EXISTS` × 31, `OBJECT_ID(...,
  'U') IS NULL` guards, `COL_LENGTH` guard checks, `CAST('9999-12-31' AS
  DATETIME2)` sentinels, quote balance, 10 `GO` batches, `SET NOEXEC OFF;` last
  line.

## Issues found

1. `SET NOEXEC ON` executed before the failure signal meant the raise never
   ran → exit code 0 on failure (the reported bug).
2. `####%` escape: `RAISERROR` formats its message with `printf`, so a real
   error message containing `%` (e.g. conversion errors, `50% off`) would
   produce a secondary 10360-style "bad/ missing format" error masking the
   original — mitigated with `REPLACE(@ErrMsg,N'%',N'%%')`.
3. Any `SET NOEXEC ON` after `RAISERROR` in the same batch is unreachable
   (batch abort) — the safe placement is a dedicated subsequent batch.

## Changes made

1. **CATCH block** (`BEGIN CATCH` … `END CATCH.`):
   - `DECLARE @ErrMsg/ErrSeverity/@ErrState` from `ERROR_*()`.
   - `REPLACE(@ErrMsg,N'%',N'%%')` → `@ErrMsgRaise`.
   - `IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;`
   - Two `PRINT` diagnostics.
   - `CREATE TABLE #migration_failed (error_message NVARCHAR(4000) NOT NULL);`
     + `INSERT` of `@ErrMsg` — persists across the `GO` boundary.
   - `RAISERROR(@ErrMsgRaise, @ErrSeverity, @ErrState);` — hard failure signal
     first; the LAST statement of the batch (aborts it as intended).
2. **FAIL-FAST SAFETY LOCK batch** (immediately after `END CATCH; GO`):
   `IF OBJECT_ID(N'tempdb..#migration_failed') IS NOT NULL` → `PRINT` +
   `SET NOEXEC ON;` So every Stage 2 batch after is parsed but **not executed**.
3. **Idempotency guard:** `DROP TABLE #migration_failed` added right before
   `BEGIN TRY` (a leftover marker from a prior failed run in the same session
   would be recreated by CATCH — must re-drop; harmless since CATCH handles
   absence).
4. **Fail-fast determinism:** `SET NOEXEC ON` is now the ONLY `SET NOEXEC` in
   the script besides the final reset; `SET NOEXEC OFF;` verified as the
   literal last line (line 1192 at the time of writing) so the session always
   returns to normal mode.

## Phase 2 step / output evaluated

- Task 10 (schema migration) — `outputs/10-schema-migration-G08.sql`, Stage 1
  error handling.

## Improvement classification

* Output refinement
* Validation/test improvement (failure path now observable by CI)

## Validation commands run

- Read-back of CATCH block, SAFETY LOCK batch, marker create/drop lines.
- Powershell static scans of `outputs/10-schema-migration-G08.sql`:
  - `#migration_failed` references (7 total), `SET NOEXEC ON` occurrences (the
    single SAFETY-LOCK), `SET NOEXEC OFF;` occurrences (last line), `THROW;`
    (removed, 0), `RAISERROR(@ErrMsgRaise,...)` count (1), `END CATCH; GO`
    boundary, GO batch count (10),
  - `COL_LENGTH` (count), `OBJECT_ID` 'U' guards (7), `IF NOT EXISTS` (31),
    `IF TRIGGER_NESTLEVEL() > 1 RETURN;` (6), `CREATE OR ALTER TRIGGER` (6),
    `CREATE OR ALTER VIEW` (1),
  - quote-balance scan (0 odd open/close in non-comment lines).
- No SQL execution against a live instance in this task (per AGENTS.md §9 SQL
  deliverables must be validated on SQL Server only).

## Validation results

- Only one `SET NOEXEC ON` remains, inside the FAIL-FAST SAFETY LOCK batch —
  the reachable placement after `RAISERROR`.
- `RAISERROR(@ErrMsgRaise,@ErrSeverity,@ErrState)` present in CATCH
  (`raise before NOEXEC` met), `SET NOEXEC OFF;` is literally the last line.
- `#migration_failed` refs: cleaned up at start (DROP), created + inserted in
  CATCH, checked in SAFETY-LOCK — 4 flow refs + header/comments.
- All structural invariants (triggers × 6, view, back-fill defaults,
  `TRIGGER_NESTLEVEL`, index guards, quote balance) unchanged.
- Verified .sql parses as balanced batches; sqlcmd/SSMS re-run on a
  SQL-Server-compatible instance is the remaining live validation (below).

## Risks / caveats

- **sqlcmd `-b` requirement:** `RAISERROR` returns a nonzero exit only with
  `sqlcmd -b` (or equivalent `:ON` batch-abort); with plain `sqlcmd` SSMS keeps
  going past the raised error message. The NOEXEC SAFETY LOCK is client-
  independent though: it guarantees Stage 2 never applies even if the client
  continues. Document in the script header (done).
- **Retry on a re-run:** a leftover `#migration_failed` from a previous failed
  session is dropped at script start — restart is safe.
- **Temp table in CATCH** only allocates when failing — negligible, no
  persistent main-db objects.
- No data on the failure path were committed; Stage-1 rollback retains Phase 1
  baseline.

## Git status summary

- Modified: `outputs/10-schema-migration-G08.sql` (this task's fix).
- Modified (from prior session): `outputs/09-updated-erd-and-logical-design-G08.md`
  — not touched here.
- Created: `docs/audits/59-fix-output10-fail-fast-raiseerror-audit.md` (this audit).
- No commits made (per repo policy).

## Recommended next steps

1. Re-run the full `10` migration on the scratch SQL Server-compatible
   instance (`localhost\MSSQL2025`, database `G08_MigrationTest`): expect
   clean commit, 6 triggers + 1 view applied, `SET NOEXEC OFF` no-op.
2. Deliberately fail Stage 1 (e.g. rename an existing object to force a guard
   mismatch) and confirm: rolled back, error 50XXX printed, exit code ≠ 0 with
   `-b`, Stage 2 batches skipped, API response rolls back.
3. Optionally fold the “`SET NOEXEC ON` placement after `RAISERROR` must be
   a later batch; `%`-escape” note into `10-schema-migration/SKILL.md` §4 for
   future tasks.