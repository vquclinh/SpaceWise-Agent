# Skill: Phase 2 Concurrency Implementation Generator (Task 12)

**Role:** Senior SQL Server Developer & Concurrency Implementer  
**Target DBMS:** Microsoft SQL Server 2016 SP1+  
**Output File:** `12-concurrency-implementation-G08.sql`

## 1. Objective
Generate the definitive T-SQL stored procedures that implement the concurrency control mechanisms designed in Task 11 (`11-concurrency-design-G08.md`). These procedures must prevent Time-Of-Check-To-Time-Of-Use (TOCTOU) race conditions under high concurrency using strict locking primitives and isolation levels, fulfilling the Task 12 Implementation Contract (C1–C7).

## 2. Context & Constraints
*   **Target File:** A single `.sql` script containing `CREATE OR ALTER PROCEDURE` statements.
*   **DBMS Restrictions:** 100% Microsoft SQL Server syntax. No PostgreSQL constructs (e.g., no `pg_sleep`, no `SERIALIZABLE DEFERRABLE`).
*   **Transactional Discipline:** Every booking-creation, approval, and escalation procedure must operate under `SET XACT_ABORT ON` and `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`.

## 3. Required Procedures
The script must generate the following four stored procedures:

### I. `usp_ApproveBooking` (Manual Staff Path)
*   **Inputs:** `@booking_id INT`, `@staff_id INT`, `@decision_note NVARCHAR(MAX)`.
*   **Logic:**
    *   Acquire key-range locks on `bookings` overlapping the target window using `WITH (UPDLOCK, HOLDLOCK)`.
    *   Acquire locks on `maintenance_records` for `OutOfService` overlaps using the same hints.
    *   Perform the set-based `NOT EXISTS` check for advisory acknowledgements and the required-asset availability check.
    *   If successful, update `status = N'Approved'` and insert the `booking_decisions` row (`decision_source = N'Staff'`).

### II. `usp_CreateBookingAutoApproved` (Instant Path)
*   **Inputs:** Target space, requested window, expected participants, booking type, purpose, requester ID.
*   **Logic (The Multi-Statement Flow):**
    *   Read `auto_approval_policies` (respecting the specific-space override precedence).
    *   Check capacity and policy limits (using NULL-safe checks for `max_participants`).
    *   Execute the identical concurrency-safe overlap and impact checks as the manual path.
    *   Execute the strict statement order: Insert `bookings` as `Pending` -> Insert `booking_advisory_acknowledgments` -> Insert `booking_decisions` (`decision_source = N'System'`, `decided_by = NULL`) -> Update `bookings.status = N'Approved'`.

### III. `usp_EscalateMaintenance` (Escalation Path)
*   **Inputs:** `@maintenance_id INT`, `@staff_id INT`, `@reason NVARCHAR(MAX)`.
*   **Logic (Strict Lock Ordering):**
    *   Must explicitly respect the `bookings` -> `maintenance_records` -> `booking_alerts` lock acquisition order to prevent deadlocks against approval workflows.
    *   Execute the update from `Advisory` to `OutOfService`. (The actual insertion into `booking_alerts` and `maintenance_impact_history` is handled by the Task 10 triggers, but the stored procedure manages the transaction envelope and locking order).

### IV. `usp_CompleteBooking` (Early Check-Out)
*   **Inputs:** `@booking_id INT`, `@staff_id INT`, `@final_condition NVARCHAR(MAX)`.
*   **Logic (Low Contention):**
    *   Intentionally bypasses the heavy `SERIALIZABLE` range checks, as releasing a space cannot cause an overlap.
    *   Update `usage_sessions` (`actual_end_time = GETDATE()`, `completed_by`) and flip `bookings.status = N'Completed'`.

## 4. Error Handling Contract (C5)
All procedures must be wrapped in standard `BEGIN TRY ... BEGIN CATCH` blocks. The `CATCH` block must cleanly separate SQL Server engine concurrency errors from application business rule violations:
*   Identify **Error 1205** (Deadlock Victim) and **Error 1222** (Lock Request Timeout) as retryable engine errors.
*   Identify the **50xxx** series errors (e.g., `THROW 51001`) as terminal business-logic failures (e.g., slot is genuinely taken).
*   *Note:* The actual bounded retry `WHILE` loop lives in the application layer caller. The stored procedure must simply `ROLLBACK` and cleanly `THROW` the exact error so the application knows whether to retry or abort.

## 5. Tone and Formatting Rules
*   Provide robust inline T-SQL comments explaining *why* specific hints (`UPDLOCK, HOLDLOCK`) and lock orderings are used, referencing the Task 11 design document.
*   Ensure all code is production-ready, cleanly indented, and safely executable in SSMS.
*   Use `N''` for all string literals.