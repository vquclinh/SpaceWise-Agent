---
name: 09-updated-erd-and-logical-design
description: Design a high-performance, 3NF-compliant ERD and Logical Schema for Phase 2, resolving all Phase 1 flaws and integrating complex Phase 2 extensions.
compatibility: opencode
---

# Step 09: Updated ERD and Logical Design Skill

This skill guides the agent to create the final architectural blueprint of the system. The output must be saved to `outputs/09-updated-erd-and-logical-design-G08.md`.

## Architectural Mandates

### 1. Conceptual ERD (Mermaid)
- **Granular Asset Tracking:** Move from generic facility counts to individual `facility_assets` (Serial Numbers). Each asset must be uniquely identifiable.
- **Maintenance Impact Logic:** Model `maintenance_records` with an `impact_level`. Link it to `facility_assets` (optional) and `spaces`.
- **Acknowledgement Tracking:** Create a dedicated junction entity (`booking_advisory_acknowledgments`) between `bookings` and `maintenance_records` to record proof of user consent for advisories.
- **Concurrency & Decision Source:** Update `booking_decisions` to handle both `Staff` and `System` (Auto-approval) sources.

### 2. Logical Schema Design (MS SQL Server)
- **Refined Data Types:** Use precise types (`INT`, `DATETIME2`, `NVARCHAR`, `BIT`).
- **Dynamic Slot Release:** Design the schema so that `bookings` and `usage_sessions` timestamps, combined with `status`, allow for immediate release of unused time windows.
- **Constraint Strategy:** Implement complex `CHECK` constraints and `UNIQUE` indexes to prevent logic errors.
- **Naming:** Strictly follow `snake_case` for all physical identifiers.

### 3. Concurrency-Safe Indexing
- Propose specific indexes to optimize:
  - Overlap checks (`space_id`, `requested_start_time`, `requested_end_time` where status is active).
  - Room finder (Capacity + Facilities).
  - Maintenance impact lookups.

### 4. Normalization Validation (3NF)
- For every modified or new table, provide a formal 3NF proof:
  - **1NF:** Atomic columns.
  - **2NF:** Full functional dependency on the PK.
  - **3NF:** No transitive dependencies.

## Quality Checklist
- [ ] Does the schema handle "Early Return" by distinguishing between Reserved and Actual times?
- [ ] Is there a clear distinction between a Maintenance record blocking a space vs. just being an Advisory?
- [ ] Does the `facility_assets` table allow tracking a specific broken projector without closing the whole room?
- [ ] Are all relationships labeled with Crow's Foot notation and clear verb phrases?
- [ ] Is the SQL Server syntax 100% accurate (No Postgres types)?