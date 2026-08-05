# Audit — Output 09 Ultimate Refinement + Required Asset Relocation Extension

> Date: 2026-08-05
> Operator/member: Truong Thi My Duyen
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: none (direct prompt)

## Task goal

Two high-precision refinement runs on `outputs/09-updated-erd-and-logical-design-G08.md` (the Phase 2 final architectural baseline), with zero changes to the 16-table inventory, the `CONSTRAINT [Name] [Type]` naming convention, or the valid T-SQL XOR logic in Section 5.14:

1. **Run 1 — architectural hardening (previous session):**
   - Harden asset maintenance logic: add `CONSTRAINT CK_maintenance_records_asset_scope_level CHECK (asset_id IS NULL OR impact_level = N'Advisory')` so only space-level records can be `OutOfService` (an asset-scoped record can never block the space; the Section 9.5.2 blocking query becomes safe by construction).
   - Define the reporting time policy: reports (a) total approved booking hours and (b) weekday/hour counts use **Reserved Time** (`requested_start_time`/`requested_end_time`); actual occupancy (`usage_sessions`) is reserved for Utilization Efficiency reports only; I2 stays focused on `requested_start_time`.
   - Simplify `space_facility_requirements`: remove the redundant `is_required` column (presence of a row means required) — pure junction table with composite PK `(space_id, facility_id)`; update the 3NF proof accordingly.
   - Terminology cleanup: "14 Phase 1 relationships" → "13" (verified against Output 02, which contains exactly 13 relationship lines); 8.7 `space_id` re-termed from "candidate key" to "supplementary UNIQUE constraint" (candidate keys cannot be nullable); `%%` comment clarifying the composite Unique Key in the Section 4 diagram.
2. **Run 2 — Required Asset Relocation [EXTENSION] in the alerting system (this session):**
   - Conceptual: `MaintenanceRecord |o--o{ BookingAlert` (nullable) + new `FacilityAsset ||--o{ BookingAlert : "may cause [EXTENSION]"`; relationship table rows updated (`0..1 -- 0..N`, new FacilityAsset row).
   - Logical: `booking_alerts` gains nullable `asset_id FK` (plain FK, no `FK*` syntax); nullability flagged per `alert_type` in diagram comments; new `facility_assets ||--o{ booking_alerts : "asset_id"` line.
   - Schema (5.16): `maintenance_id` → NULL; `asset_id` INT NULL FK to `facility_assets`; `alert_type` CHECK extended to `IN (N'MaintenanceEscalated', N'RequiredAssetRelocated')`; new XOR `CONSTRAINT CK_booking_alerts_source_scope`; old UNIQUE replaced by two SQL Server filtered unique indexes (`UQ_booking_alerts_maint`, `UQ_booking_alerts_asset`).
   - Rules/proofs: new R12 (required-asset relocation triggers alert); 8.9 updated with the "mutual exclusivity is a CHECK, not a functional dependency" note; new Section 11 edge-case row.
   - Fix the `requ`ester` typo (stray backtick inside "requester").

## Files created / changed

- `outputs/09-updated-erd-and-logical-design-G08.md` — refined (Sections 2, 3.1–3.5, 4, 5.7, 5.10, 5.11, 5.16, 6, 7, 8.2, 8.7, 8.9, 9.5.2, 10, 11, 12, 13).
- `docs/audits/55-output09-refinement-relocation-extension-audit.md` — this audit.

## What was evaluated

- Output 09 against AGENTS.md §3 (editing rules, naming conventions, conceptual/logical boundary), §4 (SQL Server-only syntax), §5 (Phase 2 technical rules: asset tracking, impact levels, concurrency, derived facts), and §8 (audit policy).
- Internal consistency of every `is_required` reference across the ERD (3.1/3.2), narrative (3.3), logical diagram (4), table schema (5.7), view (6), rule R8, 3NF proof (8.2), and traceability (12) after column removal.
- Cardinality accuracy of the new alert relationships in both conceptual diagrams and the relationship table, and their reflection in the logical diagram FK labels.
- Preservation of the 16-table inventory, `CONSTRAINT [Name] [Type]` naming, and the 5.14 XOR scope CHECK.
- Absence of PostgreSQL constructs and of `FK*` diagram syntax.
- The Phase 1 relationship count claim against `outputs/02-erd-design-G08.md` (13 lines confirmed, lines 97–109).

## Issues found

1. `space_facility_requirements.is_required` was redundant: the sparse-list semantics ("presence of a row means required") were already stated, so the column + its CHECK were an attribute that could only hold one value — the table was not a pure junction and the 3NF proof in 8.2 hinged on a single-value column.
2. Section 3.4 claimed "14 Phase 1 relationships" but Output 02 contains exactly 13; the count was inaccurate for a defense baseline.
3. Section 8.7 called the nullable `auto_approval_policies.space_id` a candidate key, which conflicts with entity integrity (candidate keys cannot contain NULL).
4. An asset-level record could in principle carry `impact_level = 'OutOfService'` (only a narrative statement prevented it), letting a single broken unit — e.g. one microphone — close a whole room through the Section 9.5.2 blocking query; the blocking query relied on discipline, not structure.
5. Reports (a)/(b) had no explicit time-source policy, leaving room for a reviewer to read them against `usage_sessions.actual_*` instead of the reserved interval required by "approved booking hours".
6. `booking_alerts` could not represent the Required Asset Relocation extension: a single NOT NULL `maintenance_id` forced every alert to have a maintenance source, and the UNIQUE `(maintenance_id, booking_id, alert_type)` could never deduplicate NULL-source (asset-caused) rows (SQL Server treats NULLs as distinct).
7. A stray backtick corrupted the word "requester" in the executive summary.

## Changes made

**Run 1:**
- **5.11:** added table-level `CONSTRAINT CK_maintenance_records_asset_scope_level CHECK (asset_id IS NULL OR impact_level = N'Advisory')`; the asset-scoping bullet now states the blocking query is safe by construction — a single broken microphone can never close a room. **R2** (Section 7) and **9.5.2** carry the same rationale; Section 11 edge case rewritten: asset-level `OutOfService` is now structurally impossible.
- **5.10:** new "Reporting time policy" statement (Reserved Time for reports (a)/(b); actual occupancy for Utilization Efficiency only). **Section 10:** same policy restated in the indexing notes with I2 explicitly kept on `requested_start_time`.
- **5.7:** `is_required` column (and its DF/CK) removed; table is now only `(space_id, facility_id)` composite PK; design note rewritten (no attribute left to say `is_required = 0`). Cascaded removals: 3.1/3.2 ERD attribute (replaced by `%%` comment), 3.3 narrative, 4 logical diagram (`bit is_required` dropped, `%%` comment added), Section 6 view (`r.is_required` → derived `CASE WHEN r.facility_id IS NULL THEN 0 ELSE 1 END AS is_required`, GROUP BY updated), 8.2 rewritten as a vacuous-3NF pure junction proof, R8 wording, traceability §2.1 row.
- **3.4:** "The 13 Phase 1 relationships (Output 02) are unchanged" (count verified). **8.7:** `space_id` re-termed "supplementary UNIQUE constraint" (candidate keys cannot be nullable). **Section 4:** `%%` comment above `booking_advisory_acknowledgments` clarifying that `(booking_id, maintenance_id)` is ONE composite Unique Key, not two individual UNIQUEs.

**Run 2:**
- **3.1/3.2:** `MaintenanceRecord |o--o{ BookingAlert : "triggers (nullable — see FacilityAsset alt.)"` and new `FacilityAsset ||--o{ BookingAlert : "may cause [EXTENSION]"` in both diagrams.
- **3.3:** BookingAlert narrative rewritten with the two source scopes (escalation-result + relocation-result, `maintenance_id` XOR `asset_id`). **3.4:** MaintenanceRecord↔BookingAlert row → `0..1 -- 0..N`; new row `| FacilityAsset | 1 -- 0..N | BookingAlert | [EXTENSION] One asset may cause zero or many relocation alerts. |`. **3.5:** `booking_alerts.asset_id` added to the `asset_id` visitor mapping.
- **Section 4:** top comment block flags `booking_alerts.maintenance_id / asset_id` as NULL per source scope; `%%` XOR comment above the box; box gains `int asset_id FK` (plain FK); new relationship line `facility_assets ||--o{ booking_alerts : "asset_id"`; maintenance line updated to `|o--o{`.
- **5.16:** `maintenance_id` → NULL; `asset_id` INT NULL FK added; `alert_type` CHECK → `IN (N'MaintenanceEscalated', N'RequiredAssetRelocated')`; new `CONSTRAINT CK_booking_alerts_source_scope CHECK ((alert_type = N'MaintenanceEscalated' AND maintenance_id IS NOT NULL AND asset_id IS NULL) OR (alert_type = N'RequiredAssetRelocated' AND asset_id IS NOT NULL AND maintenance_id IS NULL))`; old UNIQUE constraint replaced by filtered unique indexes `UQ_booking_alerts_maint` / `UQ_booking_alerts_asset` (with the NULL-distinct rationale); design notes document `TR_facility_assets_RelocationAlert`.
- **Section 7:** new **R12 [EXTENSION]** — relocating a required asset out of a space with `Approved`/`CheckedIn` bookings triggers a relocation alert. **8.9:** attributes/FDs/candidate keys updated; "mutual exclusivity is enforced by a CHECK constraint, not a functional dependency" noted; per-scope natural keys named. **Section 11:** new edge-case row "Required asset relocated after approval [EXTENSION]".
- **Consistency:** executive summary row 7, traceability §4.6 row (`R8 + R12`), Section 10 note (filtered unique indexes double as per-source lookups), quality checklist items (maintenance blocking guard, SQL Server syntax incl. filtered unique indexes, edge cases).
- **Typo:** `requ`ester` → `requester` (executive summary row 4).

## Improvement classification

- Output refinement
- Validation/test improvement (structural CHECK replaces narrative-only guarantee; count claim verified against Output 02)
- No agent/skill/command change needed

## Validation commands run

- `git status --short` — only `outputs/09-updated-erd-and-logical-design-G08.md` (untracked) and the Task 09 skill folder present.
- Grep (ripgrep) for stale references: `is_required`, `14 Phase 1`, `requ`ester`, `UQ_booking_alerts_maintenance_booking_type`, `FK*` — remaining hits are only the intentional design-note explanation, the derived `CASE ... AS is_required` in the view, and the explanatory "Mermaid does not support FK* markers" comment.
- Grep for new structures: `|o--o{ BookingAlert`, `FacilityAsset ||--o{ BookingAlert`, `CK_booking_alerts_source_scope`, `UQ_booking_alerts_maint`/`_asset`, `asset_id FK` — all present in both conceptual diagrams (3.1/3.2), the relationship table (3.4), the logical diagram (4), schema (5.16), R12, and 8.9.
- Read-back of all edited regions (2, 3.1–3.5, 4, 5.7, 5.10, 5.11, 5.16, 6, 7, 8.2/8.7/8.9, 9.5.2, 10, 11, 12, 13) plus targeted full-file reads.

## Validation results

- `CK_maintenance_records_asset_scope_level` present in 5.11, referenced consistently in R2, 9.5.2, and Section 11; valid T-SQL CHECK over two columns of the same table.
- `CK_booking_alerts_source_scope` is well-formed T-SQL XOR (parenthesized OR of two exhaustive, mutually exclusive branches); the two filtered unique indexes are SQL Server-only syntax (2008+) — no PostgreSQL constructs introduced anywhere.
- 16-table inventory unchanged; every Phase 1 table/column name verbatim; 5.14 XOR scope CHECK untouched.
- No `FK*` syntax introduced (plain `FK` markers only); Mermaid tokens `|o--o{` and `||--o{` valid crow's foot.
- All `is_required` column references removed; the view now derives the flag via `CASE`, consistent with the derived-facts policy (3NF).
- Phase 1 outputs 01–07 and Output 08 untouched; no audit files were created during the two refinement prompts themselves (per explicit constraints) — this single audit records the whole session.

## Risks / caveats

- `space_facility_requirements` change is a design-schema simplification: Task 10 must drop the `is_required` column from its planned DDL (no migration needed — the table is new in Phase 2, no Phase 1 data), and Task 14 (data generator) must not insert the removed column. Output 08 still documents `is_required BIT NOT NULL DEFAULT 1`; a later output-08 alignment pass (or a traceability note in Task 10) should reconcile the wording if the team wants strict cross-document parity.
- The alert-source XOR relies on triggers (`TR_maintenance_escalation`, `TR_facility_assets_RelocationAlert`) populating the correct source column; the CHECK rejects any mis-populated row, so the invariant is structural, but Task 10 must implement both triggers.
- `FacilityAsset ||--o{ BookingAlert` reads as "one asset per relocation alert" in the conceptual diagram; the physical XOR keeps the FK nullable for escalation-caused rows — the diagram comment and 5.16 note make this explicit.
- No SQL Server execution was run (this is a design document; physical DDL belongs to Task 10). Constraint syntax validated by inspection against SQL Server semantics only.

## Git status summary

- New (untracked): `outputs/09-updated-erd-and-logical-design-G08.md` (refined in this session), `docs/audits/55-output09-refinement-relocation-extension-audit.md` (this audit).
- Pre-existing untracked: `.opencode/skills/db-design-pipeline/09-updated-erd-and-logical-design/`.
- No commit requested; nothing committed.

## Recommended next steps

- Task 10 (schema migration): implement the DDL without `space_facility_requirements.is_required`; add `CK_maintenance_records_asset_scope_level`, `CK_booking_alerts_source_scope`, both filtered unique indexes, and triggers `TR_maintenance_escalation` + `TR_facility_assets_RelocationAlert`; reconcile the Output 08 `is_required` wording in the migration traceability.
- Tasks 11/12: confirm the escalation workflow shares the per-space serialization resource with approval procedures (Section 9.5.2) and that relocation alerts (R12) do not need locking (insert-only, no invariant races).
- Task 16: include the relocation alert list in report (d) family queries; Task 14: seed `RequiredAssetRelocated` alert rows in the data generator.
- Team review of Output 09 (owner: Lead Architect; reviewers per AGENTS.md §7) before Task 10 starts.
