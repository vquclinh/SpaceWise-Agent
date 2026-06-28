---
name: 03-logical-design
description: Quality rubric and behaviour guide for transforming the conceptual ERD into a SQL Server-oriented logical relational schema with explicit keys, candidate keys, constraints, and business-rule enforcement strategies.
compatibility: opencode
---

# Step 3: Logical Database Design Skill

This skill is an **evolving quality rubric and behaviour guide**, not a hard-coded schema answer. The logical schema content must be **derived from `outputs/02-erd-design-G08.md`** (with business-rule traceability from `outputs/01-business-req-analysis-G08.md`) — do not paste a fixed table list, fixed column definitions, a fixed Mermaid block, or fixed SQL bodies from this skill. Tiny snippets below illustrate *notation only*, never the project answer.

## 1. Purpose

- Step 3 transforms the conceptual ERD from Output 02 into a **logical relational schema**: relations, attributes, primary keys, foreign keys, candidate keys, and key constraints (per the official PDF Step 3).
- Step 3 **bridges** conceptual design (Step 2) and executable SQL DDL (Step 5).
- Step 3 **may** document SQL Server-oriented logical choices (types, constraint intent) because the project target DBMS is Microsoft SQL Server.
- Step 3 is **not** the final executable DDL. Executable `CREATE TABLE`/`CREATE INDEX`/trigger implementation belongs to **Step 5**.

## 2. Required inputs

- `outputs/02-erd-design-G08.md` — the **immediate previous-step authority**; relations, attributes, and relationships are derived from it.
- `outputs/01-business-req-analysis-G08.md` — provides **business-rule traceability** (which rules the schema must support).
- `AGENTS.md` and `.opencode/skills/db-design-pipeline/SKILL.md` — repository-wide rules (source-of-truth order, Step Precedence, Relationship Labeling rule for Step 3, SQL Server rules).

## 3. Required output structure

The output `outputs/03-logical-design-G08.md` should contain:

- **Logical design overview** — what the schema covers and how it maps from Output 02.
- **Logical schema diagram** — a Mermaid `erDiagram` (or equivalent) for the logical model.
- **Table/relation definitions** — per relation: columns, types, key role, constraints, brief description.
- **Relationship-to-foreign-key mapping** — one row per Output 02 relationship line → its FK column(s) / junction.
- **Candidate / alternate keys** — explicitly listed per relation.
- **Constraint summary** — PK, FK, UNIQUE, CHECK, NOT NULL, DEFAULT.
- **Index recommendations** — justified.
- **Business-rule enforcement strategy** — how the design supports Output 01 rules.
- **Normalization notes / design justification** — at least a 3NF rationale.
- **Deviations from Output 02, if any** — with justification.

## 4. ERD-to-relational mapping rules

- Derive **tables from conceptual entities** in Output 02.
- Derive **columns from conceptual attributes** in Output 02.
- Transform **relationship lines** from Output 02 into **foreign-key columns** (child side) or **junction tables** (M-N).
- Do **not** invent new entities, tables, or columns unless required by relational mapping (e.g., resolving M-N) or explicitly justified in the Deviations section.
- If a junction entity already exists in Output 02 (e.g. a Space–Facility junction), **preserve it** as a logical table.
- **Distinct-role relationships map to distinct FK columns.** Notation-only example: a "checked in by" relationship and a "completed by" relationship must become two separate user FK columns, not one generic user FK.

## 5. Key rules

- Every relation **must have a primary key**.
- **Foreign keys must be explicit** (named, with the referenced relation/column).
- **Candidate / alternate keys must be explicitly listed**, not only implied through UNIQUE constraints. Name them as candidate keys per relation.
- Candidate keys should come from **natural identifiers or uniqueness rules** supported by Output 01/02 (e.g. a business code or an email, if Output 02 treats it as uniquely identifying).
- If a uniqueness rule is **inferred** rather than explicit, label it **inferred / team-confirm**.
- **Composite keys** are allowed for junction relations where appropriate.

## 6. Constraint rules

- Include the **key constraints required by PDF Step 3**.
- Include **nullability, unique, check, and default** values **where justified** by business rules or logical design.
- For each non-trivial constraint, **classify** it as one of: **Explicit requirement** · **Inferred logical rule** · **Team design convention** · **Deferred implementation detail**.
- Do **not** silently promote **open questions** from Output 01 into hard constraints.
- **Capacity validation** (expected participants vs. space capacity) must remain **inferred / open** unless the team has explicitly decided to enforce it.

## 7. SQL Server-oriented guidance

- SQL Server-compatible **types may be documented** for consistency with Step 5 (e.g. `INT`, `NVARCHAR`, `DATETIME2`, `BIT` where appropriate).
- Do **not** treat this step as final executable DDL.
- Do **not** include full `CREATE TABLE` statements in Step 3.
- Avoid SQL Server-specific implementation mechanisms (triggers, IDENTITY seeds, etc.) **as code**; reference them only as *design strategies* to be implemented in Step 5.

## 8. Logical schema diagram rules

- Include a Mermaid `erDiagram` (or equivalent) for the logical model.
- Unlike Step 2, the Step 3 diagram **may show data types and key markers** (`PK`, `FK`, `UK`) if useful.
- **Relationship labels in the Step 3 diagram should use actual FK column names**, not descriptive verbs. Notation-only example: `parent ||--o{ child : "parent_id"`.
- If the diagram is too dense or labels overlap, add a smaller focused detail diagram or shorten the presentation **while preserving FK traceability**. Document any readability workaround.

## 9. Business-rule enforcement strategy

- Discuss how the logical design **supports the major business rules** from Output 01.
- For rules that **cannot** be enforced by simple row-level constraints, document implementation **options conceptually** (do not hard-code a full trigger body as the answer).
- It is acceptable to state that **overlap checking** (no two approved bookings overlap for a space) may require application logic, a stored procedure, a trigger, or exclusion-style validation, because it needs **cross-row comparison**.
- It is acceptable to state that **preventing bookings of unavailable spaces** may require checking the space's current status during booking/approval.
- Explain **tradeoffs** without forcing one implementation unless the team has decided it.

## 10. Index recommendation rules

- Recommend indexes based on **FK lookups, frequent filters, and business queries**.
- Each index recommendation must be **justified** (its use case), not copied blindly.
- Avoid excessive indexes with no use case.

## 11. Normalization / design justification

- Explain why the logical schema is **at least reasonable** relationally; include **1NF / 2NF / 3NF** notes if useful.
- Do **not overclaim** normalization when an inferred design choice is still unresolved.

## 12. Validation checklist

After writing, verify:
- [ ] All main entities from Output 02 are represented as relations/tables.
- [ ] All conceptual attributes are mapped, or intentionally deferred **with justification**.
- [ ] Every Output 02 relationship is mapped (FK column or junction table).
- [ ] Primary keys are explicit for every relation.
- [ ] Foreign keys are explicit (named + referenced relation).
- [ ] **Candidate keys are explicitly listed** (not only implied by UNIQUE).
- [ ] Key constraints are summarized.
- [ ] The relationship-to-FK mapping is complete (one row per Output 02 relationship line).
- [ ] Business rules are traced to constraints or enforcement strategies.
- [ ] SQL Server-oriented design choices are documented but **not** executable DDL.
- [ ] No unsupported requirements (e.g. capacity check) are promoted into hard constraints.
- [ ] Diagram relationship labels use **FK column names**.
- [ ] Diagram labels are readable, or a readability workaround is documented.

## 13. Common mistakes to avoid

- **Hard-coding a fixed schema** in the skill (this skill is a rubric, not the answer).
- Copying a table list **without reading Output 02**.
- **Omitting candidate keys**, or treating UNIQUE constraints as enough without naming candidate keys.
- Inventing constraints **not supported** by Output 01/02.
- Turning **capacity validation** into a firm constraint without a team decision.
- Using **descriptive relationship labels** in the logical diagram instead of FK names.
- Forgetting **double-role relationships** (collapsing two roles into one FK).
- Forgetting **junction-table mapping** for M-N.
- Writing **executable DDL** in Step 3 (belongs to Step 5).
- Recommending a **CHECK constraint for cross-row overlap rules** as if it were sufficient.
