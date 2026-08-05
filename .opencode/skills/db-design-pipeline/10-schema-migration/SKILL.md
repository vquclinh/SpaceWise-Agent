---
name: 10-schema-migration
description: Execute a non-destructive T-SQL migration to upgrade the Phase 1 schema to Phase 2, ensuring data preservation and implementing complex business logic via triggers and views.
compatibility: opencode
---

# Step 10: Schema Migration Skill

This skill guides the agent to produce the physical implementation of the Phase 2 design. The output must be saved to `outputs/10-schema-migration-G08.sql`.

## Migration Requirements

### 1. Data Preservation Philosophy
- **Additive Only:** No Phase 1 tables or columns may be dropped or renamed.
- **Legacy Backfill:** When adding `NOT NULL` columns to existing tables (like `maintenance_records.impact_level`), use a 3-step pattern: 
    1. Add column as `NULL` (or with a `DEFAULT`).
    2. Update existing rows with a logical backfill value.
    3. Alter column to `NOT NULL`.

### 2. Implementation Scope (From Output 09)
- **Tables:** Create the 7 new tables (`facility_assets`, `space_facility_requirements`, `maintenance_impact_history`, `booking_advisory_acknowledgments`, `auto_approval_policies`, `policy_booking_types`, `booking_alerts`).
- **Modifications:** Alter `maintenance_records` and `booking_decisions` additively.
- **Views:** Implement `v_space_facility_summary`.
- **Indexes:** Create all 15+ indexes defined in Section 10 of Output 09, including filtered and unique indexes.

### 3. Trigger Logic (Business Rules R1-R12)
Implement the following triggers as defined in the architectural strategy:
- **TR_maintenance_impact_history:** Records every escalation/downgrade.
- **TR_maintenance_escalation:** Generates alerts when maintenance hits `OutOfService`.
- **TR_bookings_AdvisoryAckRequired:** Enforces acknowledgement before approval.
- **TR_facility_assets_RelocationAlert:** [EXTENSION] Generates alerts when required assets are moved.
- **TR_maintenance_SyncAssetStatus:** Keeps `asset_status` in sync with maintenance records.

**Cross-cutting trigger standards (apply to every trigger above):**
- **Trigger Defense:** Begin every trigger body with `IF TRIGGER_NESTLEVEL() > 1 RETURN;` so re-entrant firing (a trigger's own write-back to its target table, or a chained write through another trigger) exits immediately instead of recursing or stacking nested execution. Check against the trigger's own nesting depth — a nested call into the *same* trigger must return, not a merely deep session.
- **Logical Precision (Relocation Alert):** The `RequiredAssetRelocated` alert must fire **only when the moved asset was in a working state before the move** — the alert means a usable unit became unavailable to the space's bookings, not that a broken unit was shuffled. The condition must inspect the pre-move state from the `deleted` table (`asset_status = N'Available'`); moves of units already `UnderMaintenance`, `InUse`, or `Retired` must not raise the alert.

### 4. Technical Standards
- **SQL Server Syntax:** Use `IDENTITY(1,1)`, `DATETIME2`, `NVARCHAR`, `BIT`.
- **Modern Syntax:** Define Views, Stored Procedures, and Triggers with `CREATE OR ALTER` (SQL Server 2016 SP1+). `CREATE OR ALTER` preserves existing permissions and object options and makes re-runs idempotent; the `DROP ... CREATE` pattern is forbidden because it resets permissions and creates a window where dependent objects are unresolved.
- **Batch Separators:** Use `GO` after every `CREATE/ALTER` block and trigger definition.
- **Named Constraints:** Every constraint must have an explicit name (e.g., `CONSTRAINT PK_...`, `CONSTRAINT FK_...`).
- **Data Type Safety:** `SESSION_CONTEXT` returns `SQL_VARIANT`; never assign it to a typed column or variable without an explicit conversion. Use `CONVERT(NVARCHAR(MAX), SESSION_CONTEXT(N'...'))` for `NVARCHAR(MAX)` targets (e.g., `change_reason`) and `TRY_CONVERT(INT, ...)` for integer actors so an unset key degrades to the documented fallback chain instead of raising a conversion error.
- **UNIQUE NULL Handling:** A standard `UNIQUE` constraint on a nullable column is **forbidden** wherever business logic requires multiple NULLs (e.g., policy scopes where `space_id` is NULL for every type-wide policy). SQL Server's default `UNIQUE` treats NULLs as distinct, so it would silently allow duplicates instead of preventing them. Use **filtered unique indexes** (`CREATE UNIQUE INDEX ... WHERE ... IS NOT NULL`) instead: they enforce uniqueness only over the non-NULL key rows and permit any number of NULL-keyed rows — matching the business semantics exactly. Name them with the `UQ_` prefix and guard creation with `IF NOT EXISTS (SELECT 1 FROM sys.indexes ...)`.
- **Data Type Fidelity in Views:** Every derived boolean flag in a view (e.g., `is_required` computed with `CASE WHEN ... THEN 0 ELSE 1 END`) must be explicitly cast with `CAST(... AS BIT)` so the view's output type matches the physical schema's `BIT` columns. Without the cast, the expression yields `INT`, breaking type consistency for consumers, filters, and unioned/joined comparisons.
- **Policy Integrity:** Auto-approval policy scopes must be duplicate-proof at the schema level. Every policy scope — space-specific (`space_id`) **and** active type-wide (`space_type` when `is_active = 1`) — must be enforced by its own filtered unique index so overlapping configurations cannot exist (two policies claiming the same space, or two active policies for the same space type). Filtered unique indexes are the required mechanism because they coexist with NULLs and inactive rows; document each index's predicate against the scope semantics in Output 09 before writing DDL.

## Quality Checklist
- [ ] Does the script run on a populated Phase 1 database without errors?
- [ ] Is `decided_by` in `booking_decisions` properly changed to nullable while preserving the decision-actor XOR logic?
- [ ] Are the filtered unique indexes for `booking_alerts` (Section 5.16) implemented correctly to handle NULLs?
- [ ] Does the `impact_level` backfill to `'OutOfService'` for old records?