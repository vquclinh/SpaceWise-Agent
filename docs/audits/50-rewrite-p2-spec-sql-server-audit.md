# Audit — Rewrite Phase 2 Spec to Microsoft SQL Server Dialect

> Date: 2026-08-03
> Operator/member: Truong Thi My Duyen
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: none (direct prompt)

## Task goal

Rewrite `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` so that all SQL snippets, triggers,
and concurrency strategies target **Microsoft SQL Server** (the Phase 1 DBMS) instead of
PostgreSQL, propose a robust SQL Server alternative to PostgreSQL exclusion constraints for
preventing overlapping bookings under concurrent load, and keep all table/column names
strictly aligned with the snake_case conventions of Phase 1.

## Files created / changed

- `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` — fully rewritten (PostgreSQL → SQL Server)
- `docs/audits/50-rewrite-p2-spec-sql-server-audit.md` — this audit

## What was evaluated

- The Phase 2 spec's SQL dialect against the Phase 1 DDL (`outputs/05-db-definition-G08.sql`).
- The exclusion-constraint approach (§6.1 of the old file) and its feasibility on SQL Server.
- Naming consistency: Phase 1 tables (`user_accounts` not `users`), PascalCase enum values
  (`'Approved'`, `'CheckedIn'`, `'NoShow'`), snake_case columns, `PK_`/`FK_`/`CK_`/`UQ_`
  constraint naming, `TR_` trigger naming, `GO` batch separators.

## Issues found

1. Whole file assumed PostgreSQL: `tsrange`, `&&` overlap operator, `btree_gist` +
   `EXCLUDE USING gist`, `FILTER (WHERE ...)`, `text[]`, `'infinity'`, `SET LOCAL`,
   `plpgsql` functions, deferred constraint triggers (`DEFERRABLE INITIALLY DEFERRED`),
   `FOR UPDATE`, `:param` placeholders.
2. Concurrency section proposed an exclusion constraint — impossible on SQL Server; the
   "fallback" (`space_locks` sentinel table) was described as weaker and secondary, but on
   SQL Server it would actually be the only option.
3. Naming drift vs. Phase 1: SQL used lowercase statuses `'approved'`, `'checked_in'`
   (Phase 1: `'Approved'`, `'CheckedIn'`); entity list and FK targets said `users` (Phase 1
   table: `user_accounts`).
4. SQL Server has no `'infinity'` timestamp and no deferred triggers; `IF UPDATE(col)` is
   true on INSERTs, which changes trigger structure vs. the PostgreSQL `TG_OP` pattern.

## Changes made

- Header now states MS SQL Server is the target engine, consistent with Phase 1.
- All entity tables converted to SQL Server types: `NVARCHAR(20/30)` + named `CHECK`
  whitelists (PascalCase values), `BIT`, `DATE`, `DATETIME2 NOT NULL DEFAULT GETDATE()`,
  `INT IDENTITY(1,1)` PKs; `text[]` → junction table `policy_booking_types`; `ENUM(...)`
  → CHECK constraints; FK targets renamed `users` → `user_accounts`.
- §2.6 view rewritten from `count(*) FILTER (...)` to `SUM(CASE WHEN ... THEN 1 ELSE 0 END)`.
- §4 overlap logic rewritten without ranges: `s1 < e2 AND e1 > s2`; `FOR UPDATE` →
  `WITH (UPDLOCK, HOLDLOCK)` (pointer to §6); COALESCE interval fallback expressed as
  column pairs + `DATEDIFF` for utilization hours.
- §5 triggers rewritten in T-SQL: `AFTER INSERT, UPDATE` set-based triggers with
  `inserted`/`deleted`, `IF UPDATE(column)`, `RAISERROR` + `ROLLBACK TRANSACTION`;
  `current_setting(...)` → `SESSION_CONTEXT`/`sp_set_session_context`; `'infinity'` →
  `COALESCE(..., CAST('9999-12-31 23:59:59' AS DATETIME2))`.
- §5.3 deferred constraint trigger → plain `AFTER` trigger with a documented mandatory
  statement order (Pending → ack rows → status update), including the tradeoff analysis
  required by AGENTS.md §4 for rules that cannot be a simple CHECK.
- §6 rewritten as a three-layer SQL Server concurrency strategy:
  - §6.1 primary: stored procedure (`usp_CreateBooking`) with `SERIALIZABLE` +
    `UPDLOCK/HOLDLOCK` range locking on the conflict check; explains why the Phase 1
    trigger alone cannot stop the race, how range locks close it, and the 1205 deadlock
    retry behavior.
  - §6.2 alternative: per-space `sp_getapplock` application lock.
  - §6.3 defense-in-depth: Phase 1 trigger retained as backstop.
  - §6.4 multi-statement flows wrapped in `SERIALIZABLE`; retry on 1205/1222 (vs.
    PostgreSQL 40001).
- §7 indexing: GiST → filtered index `IX_bookings_space_status_time` on
  `(space_id, requested_start_time, requested_end_time) WHERE status IN ('Approved','CheckedIn')`
  (also feeds granular key-range locking); GIN mention removed (junction table join instead).
- §8 migration updated: `impact_level` backfill with `DEFAULT 'OutOfService'`;
  `decision_source` with `DEFAULT 'Staff'`; overlap pre-check before deploying procedure/index.

## Improvement classification

- Documentation improvement
- No agent/skill/command change needed (Phase 2 skills/commands do not exist yet)

## Validation commands run

- `git status --short` / `git log --oneline -3`
- Grep of the rewritten file for leftover PostgreSQL constructs:
  `tsrange|plpgsql|gist|EXCLUDE|FILTER (WHERE|text\[\]|'infinity'|FOR UPDATE|checked_in|users(`
- Cross-check of table/column names against `outputs/05-db-definition-G08.sql`

## Validation results

- All remaining "PostgreSQL" mentions in the file are intentional explanatory contrasts
  ("no PostgreSQL-style deferred trigger", "SQL Server has no equivalent of PostgreSQL's
  exclusion constraints", etc.) — no PostgreSQL syntax remains.
- Every referenced Phase 1 table/column (`user_accounts`, `bookings`, `requested_start_time`,
  `requested_end_time`, `maintenance_records`, `start_time`, `completion_time`, `reporter_id`,
  `usage_sessions`, `actual_start_time`, `actual_end_time`, `space_facilities`, etc.) matches
  the Phase 1 DDL verbatim; status literals use Phase 1 PascalCase (`'Approved'`, `'CheckedIn'`).
- Repo validation scripts were not run: this change touches no `outputs/` files and no SQL
  deliverable (Phase 2 outputs do not exist yet); the scripts are Phase 1-output oriented.

## Risks / caveats

- `sp_set_session_context` / `SESSION_CONTEXT` require SQL Server 2016+; assume modern SQL
  Server / Azure SQL (consistent with AGENTS.md §4).
- The §6.1 lock pattern depends on the filtered index for granular key-range locking;
  without it SQL Server may take table locks (still correct, less concurrent). Documented
  in the file.
- The §5.3 ordering requirement (acks before status update) is trigger-enforced but must be
  followed by all future code paths; noted in the file for the design-validation step.
- Triggers/procedure are illustrative SQL Server patterns; they must be validated on a real
  SQL Server environment when Phase 2 implementation starts.

## Git status summary

- `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` and `req/business-requirement-P2.md` are
  untracked (created by the previous Phase 2 session; not committed — no commit requested).
- This audit file is new and untracked.

## Recommended next steps

- Confirm with the team that the Phase 1 spec's line 577 ("If using PostgreSQL, consider an
  exclusion constraint…") should also be cleaned up to SQL Server wording (out of scope for
  this task; suggested as a follow-up edit).
- When Phase 2 outputs start, generate `08`/`09`/`10` using this spec and validate on a
  SQL Server-compatible environment.
