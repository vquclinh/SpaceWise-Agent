## Task 10: Schema Migration
Overall score: 4.6 / 5

### Mechanical execution (rubric mandatory first step)
Executed against a live **Microsoft SQL Server 2025** instance (`localhost\MSSQL2025`), the only permitted DBMS.

1. Stand up Phase 1 on a fresh database: `outputs/05-db-definition-G08.sql` then `outputs/06-sample-data-G08.sql` — both succeeded. Baseline = 9 Phase 1 tables; 3 departments, 13 user_accounts, 10 spaces, 7 facilities, 29 space_facilities rows, 20 bookings, 17 booking_decisions, 6 usage_sessions, 6 maintenance_records.
2. Run `outputs/10-schema-migration-G08.sql`.
3. **Outcome — partial success with one reproducible run error:**
   - With the script's own documented invocation (`sqlcmd -S <server> -d <db> -i ...`, i.e. session `QUOTED_IDENTIFIER` default **OFF**) → `Msg 1934` `CREATE INDEX ... incorrect settings: 'QUOTED_IDENTIFIER'` fired at section 9 (filtered/unique indexes exist, lines 1514–1545). The script's TRY/CATCH rolled back atomically — no damage, Phase 1 state fully intact: **the single-transaction design did its job exactly as documented.**
   - With `-I` (QUOTED_IDENTIFIER ON) → **MIGRATION COMMITTED SUCCESSFULLY.** All verification gates (10a–10f) passed, summary printed.
   - Re-run with `-I` (idempotency check) → **succeeds, changes nothing**.
   - Endpoint verified: exactly the 15 Phase 2 tables (7 retained + 8 new), plus 3 migration-artifact archive tables. Data reconciliation: `facility_assets`  94 units = SUM(quantity)=29 rows' 94 units; `user_roles` 13 rows (every Phase 1 role carried); books untouched, all phase-1 tables/columns intact.
   - Constraint/object inventory: 14 triggers, 1 view (`v_space_facility_summary`), all Phase 2 tables created with IF NOT EXISTS guards; referential integrity intact.

| Criterion | Weight | Score | Notes |
|---|---|---|---|
| 1. Non-destructive migration | high (~17.5%) | 4 | Only three destructive statements, each the explicitly documented AGENTS.md amendment (§1a/1b/1c): drop `facilities`, drop `space_facilities`, drop `user_accounts.role`. Data archived first (`mig_archive_*`), carried to `user_roles` and expanded into 94 `facilities` units with generated serials — no silent delete, no rename, rows/columns intact. Gap: script does not self-set `QUOTED_IDENTIFIER` (see blocker below). |
| 2. `impact_level` on MaintenanceRecord | high (~15%) | 5 | `ALTER TABLE maintenance_records ADD impact_level NVARCHAR(20) NOT NULL DEFAULT N'OutOfService'` (not DROP+CREATE), documented backfill assumption (all legacy rows = OutOfService, the safe conservative choice, §1 header + §6.1 comments), migration-only default dropped after backfill, domain CHECK `('Advisory','OutOfService')` matching task 09 spelling exactly. Level-history table `maintenance_impact_history` created *before* the column add. |
| 3. BookingAdvisory junction | high (~15%) | 4 | `booking_advisory_acknowledgments` created as `CREATE TABLE` (new, not ALTER). Correct FKs to bookings and maintenance_records, `acknowledged_at DATETIME2 NOT NULL DEFAULT GETDATE()`. Uses surrogate `ack_id` PK + `UQ(...booking_id, maintenance_id)` — the same deviation already flagged in task 09 (rubric asks composite PK); carried forward faithfully and documented. |
| 4. Instant-booking / approval_mode | medium (~5%) | 5 | no orphan `booking_type` column since task 09 handled instant-booking via `booking_decisions.decision_source` + auto-approval tables. Migration adds `decision_source` (backfill `'Staff'`) + CHECK + relaxation of `decided_by`, matching 09 exactly. `B-CK_booking_decisions_source_actor` enforces System=CONFIG. |
| 5. Updated trigger(s) | high (~17.5%) | 5 | `TR_bookings_PreventOverlapAndUnavailable` rebuilt as `CREATE OR ALTER`. Overlap gate now covers `Approved`/`CheckedIn`; maintenance gate is **conditioned on `m.impact_level = N'OutOfService'`** only — advisory no longer blocks. `UnderMaintenance` removed from the `current_status` check (display-only), TemporarilyClosed/Retired retained. Verified running and firing correctly post-migration. |
| 6. Escalation detection support | medium (~10%) | 5 | `maintenance_impact_history` (audit of every level change) + `TR_maintenance_impact_history` (INSERT+UPDATE log, creation row = old NULL) + `TR_impact_history_StaffRole` narrowing to staff-triggered changes + `TR_maintenance_escalation` raising `MaintenanceEscalated` alerts. Task 16's escalation-report has its timestamps. |
| 7. Migration approach documented | medium (~10%) | 5 | Textbook-documented: per-section purpose (out "Forced by dependencies — do not reorder" with 0–10 order), the backfill business assumption on `impact_level`, explicit "no data loss" claim verified, plus archive/recovery path discussion. |
| 8. Idempotency / safety guards | low (~5%) | 4 | `IF OBJECT_ID IS NULL` on every table, `COL_LENGTH` (or post-add existence check) before each ALTER, exhaustive TRY/CATCH + XACT_ABORT single transaction, projected NOT NULL gate. **Only gap: does not issue `SET QUOTED_IDENTIFIER ON` (or `SET ANSI_NULLS ON`) at session start, so its own documented `sqlcmd` run errors on the first filtered index.** |
| 9. Correct statement ordering | medium (~5%) | 5 | Strict dependency order (archive → new tables → additive columns → data migration → post-backfill constraints → retire → views → triggers → indexes → verify), validated by the successful committed run: all backfills precede constraint enforcement; tables precede FKs; triggers/views after shape changes. |

### Strengths:
- **The safety design is not cosmetic — it works in practice.** The one failure mode elicited (missing QUOTED_IDENTIFIER) triggered an exact, complete rollback leaving the Phase 1 database byte-for-byte usable; the verification gate (10a–10f) and data-integrity checks passed on the successful run.
- **Data preservation is real and verified, not claimed.** `facility_assets` is expanded from `space_facilities.quantity` (29→94 rows with per-unit serial numbers), `user_roles` seeded 1:1 from `user_accounts.role` (13/13), all three archives hold the pre-drop rows.
- **Business-rule migration is correct and complete:** advisory maintenance no longer blocks booking; the OutOfService gate queries `maintenance_records` directly (NOT NULL `space_id`, no join) — matches task 09's by-construction argument (D-1); early check-out semantics (status set covers CheckedIn) in the conflict predicate.
- **Re-runnable**, verified by a second successful run.
- **Escalation timing is persisted** both via the history table AND the alerts tables, giving task 16 everything it needs to distinguish before/after-es escalation.

### Issues found:
- [blocker] The script does not execute under its own documented "HOW TO RUN" (`sqlcmd -S <server> -d <db> -i 10-...sql`, lines 113–114) because a fresh sqlcmd connection defaults `QUOTED_IDENTIFIER OFF`, and section 9 creates filtered indexes (lines 1514–1545) which require `ON`. One-line fix: `SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;` at session start (line 120 area), or an `-I` flag note in the header. The rollback path is clean, so this is a documentation/safety-hygiene defect, not data corruption — but a docfollower would see a red error on their first run.
- [minor] `facility_assets.condition` carries the multi-unit aggregate text from Phase 1 (`'Damage reported'`, `'3 stations have faulty keyboards'`) onto each generated unit (Review B output) — acceptable as a conservative carry-forward, but the narrative in the header notes this tradeoff, not the data itself being cleaned.
- [minor] The `meta-` composite-PK deviation on `booking_advisory_acknowledgments` (surrogate `ack_id` + natural unique) is inherited from task 09's documented choice; a strict grader per rubric (composite PK) will flag it — same flagged note as in the task-09 evaluation.
- [minor] archive tables (`mig_archive_*`) remain as extra objects; the script documents manual drop, a fine tradeoff, but leaves 18 tables visible after "exactly the 15 Phase 2 tables" claim unless dropped.

### Inherited issues from earlier tasks (if any):
- Composite-PK-on-router deviation carried over from Output 09 (surrogate `ack_id`), as consistently flagged in the task-09 evaluation.
- None else: `impact_level` spelling/casing matches 09; `decided_by` NULL relaxation matches 09; all values consistent with existing CHECKs.

### Suggested fixes:
1. Add `SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;` as the first statements (must be in its own batch) so planned `sqlcmd` invocation works without `-I`; re-run to confirm.
2. (Optional) After sign-off, consider a cleanup block dropping `mig_archive_*` and would-be re-cert in the same header so "15 tables" becomes literal, not just documented.
3. No other content rework needed — mechanical gate passes once the SET-option fix is in.

(SQL Server 2025, single session context; all Phase 2 DDL/migration objects verified — the plan is safe for Task 11 onwards.)