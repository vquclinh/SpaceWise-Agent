# Audit — Standardize Logical Diagram and Skill Mapping

> Date: 2026-06-25
> Operator/member: Trương Thị Mỹ Duyên and Huỳnh Lê Bảo Thi
> Tool: OpenCode
> Provider/model/variant: deepseek-v4-flash-free (via OpenCode)
> OpenCode command used: `/refine-output outputs/03-logical-design-G08.md`

## Task goal

1. Apply the updated SKILL.md Step 3 requirement by adding a Logical Schema Diagram (Mermaid `erDiagram` with physical SQL Server data types and PK/FK/UK constraint markers) to `outputs/03-logical-design-G08.md`.
2. Renumber all sections after inserting the new diagram section.
3. Ensure the logical design conforms to the SKILL.md mapping rules (Home ID → PK, Visitor ID → FK, constraint markers, physical types).

## Files created / changed

- **Modified:** `outputs/03-logical-design-G08.md` — added Section 2: Logical Schema Diagram (Mermaid erDiagram); renumbered Sections 3–7.
- **Created:** `audits/16-standardize-logical-diagram-and-skill-mapping.md` (this file).

## What was evaluated

- Step 3 output / `outputs/03-logical-design-G08.md`.
- Whether the SKILL.md Step 3 "Logical Schema Diagram" requirement is satisfied.
- Section numbering correctness after inserting the new diagram.

## Issues found

1. **Missing Logical Schema Diagram** — SKILL.md Step 3 requires a Mermaid `erDiagram` with physical details (SQL Server data types and PK/FK/UK markers), but Output 03 only had separate table-definition tables and a relationship-to-FK mapping table, with no visual diagram interconnecting all tables.
2. **Section numbering out of date** — Existing sections (2–6) needed to shift to (3–7) after inserting the diagram as Section 2.

## Changes made

### Output 03 — Section 2: Logical Schema Diagram

Added a full Mermaid `erDiagram` with:

| Element | Detail |
|---|---|
| Entity boxes | All 9 tables (`departments`, `user_accounts`, `spaces`, `facilities`, `space_facilities`, `bookings`, `booking_decisions`, `usage_sessions`, `maintenance_records`) |
| Physical types | SQL Server types shown per column: `int`, `nvarchar`, `datetime2` |
| PK markers | `PK` on every primary key column (including composite `space_id PK, FK` and `facility_id PK, FK` in `space_facilities`) |
| FK markers | `FK` on all 13 foreign key columns (e.g. `user_accounts.department_id FK`, `bookings.requester_id FK`, `bookings.space_id FK`, `booking_decisions.booking_id FK`, `booking_decisions.decided_by FK`, `usage_sessions.booking_id FK, UK`, `usage_sessions.checked_in_by FK`, `usage_sessions.completed_by FK`, `space_facilities.space_id PK, FK`, `space_facilities.facility_id PK, FK`, `maintenance_records.space_id FK`, `maintenance_records.reporter_id FK`, `maintenance_records.assigned_staff_id FK`) |
| UK markers | `UK` on unique columns (`email`, `space_code`, `facility_name`, `booking_id` in `usage_sessions`) |
| Relationship lines | 13 lines matching the conceptual ERD Crow's Foot notation exactly |

This differs from the conceptual ERD in `02-erd-design-G08.md` by exposing physical data types, Foreign Key columns (Visitor IDs), and constraint markers — precisely fulfilling the conceptual-to-logical transition.

### Output 03 — Section renumbering

| Old heading | New heading |
|---|---|
| `## 2. Table Definitions` | `## 3. Table Definitions` |
| `### 2.1` – `### 2.9` | `### 3.1` – `### 3.9` |
| `## 3. Relationship-to-Foreign-Key Mapping` | `## 4.` |
| `## 4. Constraint Summary` | `## 5.` |
| `## 5. Index Recommendations` | `## 6.` |
| `## 6. Business Rule Enforcement Strategy` | `## 7.` |

## Improvement classification

- Output refinement
- No agent/skill/command change needed

## Validation commands run

```powershell
Select-String -Pattern "^## [1-7]" -Path outputs\03-logical-design-G08.md
```

Manual verification:
- ✅ Logical Schema Diagram shows all 9 tables with `int`/`nvarchar`/`datetime2` types
- ✅ All 13 FK columns from Section 4 (Relationship-to-Foreign-Key Mapping) appear in the diagram
- ✅ PK markers on all primary key columns; FK markers on all foreign key columns; UK markers on unique columns
- ✅ Relationship lines match the conceptual ERD (1-to-Many, 1-to-0..1)
- ✅ Section numbering is sequential (1–7) with no gaps or duplicates

## Validation results

All checks pass. Output 03 now conforms to the SKILL.md Step 3 requirement for a Logical Schema Diagram. The diagram visually documents all table interconnections with physical SQL Server details, bridging the gap between the conceptual ERD (Step 2) and the upcoming DDL (Step 5).

## Risks / caveats

- The Mermaid `erDiagram` uses `nvarchar` without length specifiers (e.g. `nvarchar(100)`) for readability in the diagram. The full length specifications remain in the Section 3 table-definition tables. This is a visual simplification, not a data loss.
- Mermaid does not support a native `UK` constraint marker keyword. The `UK` annotations render as plain-text comments beside the column name — visually correct for documentation, but not parsed as a formal constraint by Mermaid.

## Git status summary

```
 M outputs/03-logical-design-G08.md
?? audits/16-standardize-logical-diagram-and-skill-mapping.md
```

## Recommended next steps

1. Proceed to Step 4: Design Validation (`outputs/04-design-validation-G08.md`) — verify the logical schema against the conceptual ERD, business rules, normalization, referential integrity, and business rule enforcement strategies.
2. Proceed to Step 5: DDL generation (`outputs/05-db-definition-G08.sql`) — convert the logical schema into `CREATE TABLE` and `CREATE INDEX` statements.
3. Run full validation scripts `scripts/check_required_files.sh --final G08` and `scripts/validate_sql.sh --final G08` after all 7 outputs exist.
