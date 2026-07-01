## Task 5: db-definition (DDL)
Overall score: 5.0 / 5

| Criterion | Score | Notes |
|---|---|---|
| 1. Faithfulness to Logical Design (Task 3) | 5 | All 9 tables mapped correctly. 100% column/type/constraint match against Output 03 Table Definitions (sections 3.1–3.9). No missing or extra columns. SpaceFacility composite PK correctly implemented. |
| 2. SQL Server Syntax Correctness | 5 | Uses IDENTITY(1,1), DATETIME2, NVARCHAR, GETDATE(), GO batch separators, named constraints. CREATE TRIGGER placed in its own batch with GO before/after (required). RAISERROR with severity 16 for trigger rollback. All syntax is valid SQL Server. |
| 3. Primary Key Completeness | 5 | 9 PKs — one per table. All surrogate (IDENTITY) except space_facilities (composite natural PK). Properly named as PK_<table>. |
| 4. Foreign Key Completeness | 5 | All 13 FKs from the logical design relationship mapping (section 4) are implemented. Self-referencing FK pattern handled via multiple FKs on user_accounts where needed (checked_in_by, completed_by, reporter_id, assigned_staff_id, decided_by). |
| 5. UNIQUE & CHECK Constraint Completeness | 5 | 4 UNIQUE constraints (email, space_code, facility_name, usage_sessions.booking_id) — all present. 17 CHECK constraints — every whitelist, range, and conditional rule from the logical design is encoded. Rejection-reason conditional check (CK_booking_decisions_rejection_reason) and completion-field paired-null check (CK_usage_sessions_completion) correctly use multi-column table-level constraints. |
| 6. DEFAULT & Lifecycle Columns | 5 | 7 DEFAULT constraints match the logical design exactly. All core entities (user_accounts, spaces, bookings, maintenance_records) include created_at and updated_at with DEFAULT GETDATE(). |
| 7. Business Rule Enforcement (Trigger) | 5 | Single AFTER INSERT, UPDATE trigger TR_bookings_PreventOverlapAndUnavailable enforces both critical business rules: (a) no overlapping Approved bookings for same space, (b) no booking for UnderMaintenance/TemporarilyClosed/Retired spaces. Overlap logic uses correct half-open interval check (s1 < e2 AND e1 > s2). Rule 2 correctly only blocks active statuses (Pending, Approved), not lifecycle updates. updated_at auto-update on UPDATE included. Proper ROLLBACK + RAISERROR + RETURN pattern. |
| 8. Index Implementation | 5 | All 13 indexes from the logical design (section 6) are implemented exactly as specified. Index for IX_space_facilities_facility_id correctly noted as complement to the composite PK. IX_bookings_time_range covers both requested_start_time and requested_end_time for overlap queries. |
| 9. Code Quality & Documentation | 5 | Well-structured with section headers, GO separators after each table, a comprehensive CONSTRAINT SUMMARY at the end (lines 362–443) cataloguing every PK, FK, UNIQUE, CHECK, DEFAULT, index, and trigger with counts. Block comments explain trigger design rationale and batch requirements. |

Strengths:
- Perfect traceability from logical design to DDL — every table, column, type, and constraint from Output 03 is faithfully reproduced.
- Comprehensive constraint coverage: 9 PKs + 13 FKs + 4 UNIQUEs + 17 CHECKs + 7 DEFAULTs = 50 constraints, all correctly specified.
- Trigger implementation is production-quality: handles both critical business rules, uses correct overlap interval logic, properly distinguishes INSERT vs UPDATE, and includes updated_at auto-maintenance.
- Constraint summary at end of file is excellent for reviewer/grader audit — counts each constraint type and lists every constraint by name.
- GO batch separators placed correctly for SQL Server (IDENTITY, CREATE TRIGGER, etc.).
- Rejection-reason conditional CHECK and completion-field paired-null CHECK are implemented as table-level constraints (correct approach for multi-column checks).

Issues found:
- [minor] The trigger's updated_at update does not check RECURSIVE_TRIGGERS setting explicitly; the comment states it is OFF by default, which is correct for most SQL Server configurations. If a deployment enables RECURSIVE_TRIGGERS, the self-update would recursively re-fire the trigger. This is a documentation-level clarification rather than a code defect.

Inherited issues from earlier tasks (if any):
- None. Output 03 (logical design) provided a clean specification with no errors or ambiguities that the DDL needed to resolve.

Suggested fixes:
1. (Optional) Add a comment or SET statement in the deployment notes to explicitly set RECURSIVE_TRIGGERS OFF before the trigger definition, ensuring the trigger behavior is deterministic regardless of server-level settings.

Summary: This DDL is a model implementation — complete, correct, and well-documented. It faithfully implements all 9 tables, 50 constraints, 13 indexes, and 1 trigger exactly as specified in the logical design, with no errors or omissions.
