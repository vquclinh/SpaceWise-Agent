---
description: Generate Task 09 (Updated Conceptual ERD + Logical Design) for Phase 2 — the official updated-design deliverable.
---

# /09-generate-updated-design

This command produces the **official Phase 2 deliverable** `outputs/09-updated-erd-and-logical-design-G08.md`. It is an **execution entrypoint** — it does not contain the schema answer; the design must be derived from the required inputs using the Task 09 skill and the shared pipeline rules.

## Goal

Generate `outputs/09-updated-erd-and-logical-design-G08.md` containing:

1. The **updated Conceptual ERD** (Mermaid, Crow's Foot, 2-column `attr` format) reflecting all Phase 2 entities and relationships layered on the Phase 1 ERD.
2. The **updated Logical Relational Schema** with a full Data Dictionary for all 9 Phase 2 affected tables, explicit PK/FK/UK/NOT NULL/CHECK key definitions, SQL Server-faithful data types, and a Mermaid logical diagram whose relationship lines are labeled with FK column names.
3. The **formal 1NF/2NF/3NF validation audit** of the extended schema (the 7 new + 2 modified tables identified in Output 08).

## Dependencies

The agent MUST read these inputs before generating, in this order of authority:

1. `outputs/08-requirement-change-analysis-G08.md` — **primary baseline (immediate previous-step authority, binding)**: §2 (new/modified tables and columns), §3 (relationship changes + Conceptual Notation + Home ID/Visitor ID bridge), §4 (new business rules), §5 (concurrency), §6 (traceability matrix).
2. `outputs/02-erd-design-G08.md` — **Phase 1 Conceptual ERD baseline** (primary authority for Step 2 relationships).
3. `outputs/03-logical-design-G08.md` — **Phase 1 Logical Schema baseline** (primary authority for Step 3 relations, keys, constraints).
4. `CS486_Project_Phase02.pdf` — the official Phase 2 requirement (business changes, deliverable list, report requirements).
5. `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` — supplementary reference for Phase 2 domain logic.
6. `AGENTS.md` — sections 2 (source-of-truth, Step Precedence Rule), 3 (Mermaid rendering rules, Home ID vs. Visitor ID, Relationship Labeling rule), 4 (SQL Server rules).

## Task Logic

Execute the steps in this order:

1. **Load the Task 09 Skill:** You MUST load and follow `.opencode/skills/db-design-pipeline/09-updated-design/SKILL.md`. Supplement it with the Phase 1 skills for Step 2 and Step 3 (`.opencode/skills/db-design-pipeline/02-erd-design/SKILL.md` and `03-logical-design/SKILL.md`) and the shared pipeline rules (`.opencode/skills/db-design-pipeline/SKILL.md`).
2. **Update the Conceptual ERD:** Copy the Phase 1 ERD shape from Output 02 unchanged; add the Phase 2 entities (`facility_assets`, `booking_advisory_acknowledgments`, `maintenance_impact_history`, `auto_approval_policies`, `policy_booking_types`, `space_facility_requirements`, `booking_alerts`) and their Crow's Foot relationships per Output 08 §3. Keep Step 2 conventions: conceptual purity, Home IDs only in their defining boxes, no Visitor ID/FK columns, no PK/FK markers, `attr` placeholder types.
3. **Generate the Detailed Logical Schema Diagram:** Produce the detailed Mermaid `erDiagram` (per Task 09 skill §3.4) — the full extended schema (Phase 1 + Phase 2 tables), every column in each table box, `PK`/`FK`/`UK` labels on every key, specific MS SQL Server data types (`int`, `nvarchar`, `datetime2`, …) in the boxes, and every relationship line labeled with the actual FK column name. Base the diagram on Output 03 extended additively with the 7 new + 2 modified tables.
4. **Update the Logical Data Dictionary:** Extend the Phase 1 logical design from Output 03 additively — new relations and new/modified columns for the 7 new + 2 modified tables with SQL Server types, explicit primary/foreign/candidate keys, constraints, index recommendations, and the derived-fact policy (`space_facility_summary` view; `is_early_checkout` never stored). The **Logical Relational Schema** section MUST be a complete deliverable on its own — see "Logical Design Completeness" below. Keep the Data Dictionary fully consistent with the diagram from step 3 (same columns, keys, and types).
5. **Perform 3NF Validation:** Run the formal 1NF/2NF/3NF audit per each of the 9 tables identified in Output 08, following the template in the Task 09 skill.

## Logical Design Completeness

The **Logical Relational Schema** section of the output MUST include:

- **Full Data Dictionary for all 9 Phase 2 affected tables** — the 7 new tables (`facility_assets`, `booking_advisory_acknowledgments`, `booking_alerts`, `maintenance_impact_history`, `auto_approval_policies`, `policy_booking_types`, `space_facility_requirements`) and the 2 modified tables (`maintenance_records`, `booking_decisions`), with **every column** of each table documented (Phase 1 columns on the modified tables restated, not omitted).
- **Key definitions per table, clearly marked:**
  - **PK** — primary key column(s).
  - **FK** — foreign key with the **target table and column** (e.g., `FK → spaces(space_id)`).
  - **UK** — unique key / candidate key (e.g., `serial_number`, `(booking_id, maintenance_id)`).
  - **NOT NULL** — explicit for every mandatory column.
  - **CHECK** — every enumeration/range/domain constraint explicitly stated.
- **SQL Server Fidelity:** every column MUST carry a specific MS SQL Server data type — `INT IDENTITY(1,1)` for surrogate keys, `NVARCHAR(n)` / `NVARCHAR(MAX)`, `DATETIME2`, `BIT`, `DATE` — with no generic/unspecified types.
- **Mermaid Logical Diagram:** the relationship lines in the logical diagram MUST be labeled with the actual **FK column names** for 100% traceability back to the Data Dictionary (e.g., `bookings ||--o{ booking_advisory_acknowledgments : "booking_id"`). No descriptive-verb labels are allowed in the logical diagram.

## Mandatory Constraints

- **Integrity:** The **Individual Asset Tracking** (`facility_assets` with `asset_id` + `serial_number`, connected via `space_facilities`) and **Advisory Acknowledgement** (`booking_advisory_acknowledgments`) tables must be integrated **without breaking any Phase 1 relationship**. Keep every Phase 1 table/column name verbatim; only add new relations/columns and adjust Phase 1 structures strictly as specified in Output 08.
- **No Phase 1 rewrites:** Do NOT modify or overwrite Outputs 01–08. Do not edit `AGENTS.md` or `.opencode/skills/db-design-pipeline/SKILL.md`.
- **No executable DDL in this deliverable:** the updated design is a design document; DDL belongs to Task 10.
- **Data Dictionary completeness:** the Logical Relational Schema section MUST document all 9 Phase 2 affected tables with every column, and MUST mark PK / FK (target table + column) / UK / NOT NULL / CHECK on each.
- **SQL Server fidelity:** every column in the Data Dictionary MUST have a specific MS SQL Server type (`INT IDENTITY`, `NVARCHAR(n)`/`NVARCHAR(MAX)`, `DATETIME2`, `BIT`, `DATE`); no generic types.
- **Logical diagram FK labeling:** every relationship line in the logical Mermaid diagram MUST be labeled with the actual FK column name; descriptive-verb labels are forbidden there (they belong only in the conceptual ERD).

## Self-Review

After writing, verify explicitly:

1. Does the updated ERD extend Output 02 without dropping or renaming any Phase 1 entity or relationship?
2. Are `facility_assets` (serial-number tracking) and `booking_advisory_acknowledgments` present and connected with correct cardinalities (M–N links resolved via the associative entities)?
3. Does the updated logical schema map every entity from the updated ERD to a relation, with explicit primary keys, foreign keys, and candidate keys?
4. Is the Data Dictionary complete for all 9 Phase 2 affected tables — every column present, with PK / FK (target table + column) / UK / NOT NULL / CHECK marked, and a specific MS SQL Server data type on every column?
5. Are all relationship lines in the logical Mermaid diagram labeled with the actual FK column names (100% traceability to the Data Dictionary)?
6. Are the three Phase 2 pillars represented — maintenance impact levels, advisory acknowledgements, and concurrency-safe booking (auto-approval, `decision_source`, filtered index `IX_bookings_space_status_time`)?
7. Is the 3NF audit complete for all 9 tables, with a verdict per relation?
8. Is the output still a design deliverable, not executable DDL?

If the self-review reveals a systemic weakness in the task skill (missing guidance, unclear rules), record it in the audit as **"Recommended skill improvement"**. Do NOT silently edit a skill file during a normal generation run unless the user explicitly asked for a skill-editing task.

## Safety Constraint

Do NOT generate, modify, or overwrite any other deliverable (01–08, 10–16). Do not edit `AGENTS.md` or `.opencode/skills/db-design-pipeline/SKILL.md`.

## Audit Policy

After generation or refinement, you MUST follow the repository audit policy (`AGENTS.md` section 8). Create a new audit log in `docs/audits/` using the `docs/audits/AUDIT_TEMPLATE.md` format. Record the Phase 2 task (Task 09) and the output file evaluated.
