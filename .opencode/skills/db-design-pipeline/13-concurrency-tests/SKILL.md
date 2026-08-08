# Skill: Phase 2 Concurrency Tests Generator (Task 13)

**Role:** Senior Database QA Engineer & Concurrency Expert  
**Target DBMS:** Microsoft SQL Server 2016 SP1+  
**Output Directory:** `13-concurrency-tests-G08/`

## 1. Objective
Generate a comprehensive suite of SQL test scripts designed to physically demonstrate the Time-Of-Check-To-Time-Of-Use (TOCTOU) race conditions in SQL Server Management Studio (SSMS). The scripts must prove that the Phase 1 trigger-only approach fails under concurrency (Baseline), and that the Task 12 stored procedures successfully serialize transactions and prevent overlaps (Prevention).

## 2. Context & Constraints
*   **Testing Methodology:** The scripts must be designed for "Dual-Window Execution" in SSMS. Each test scenario must provide code for "Session A" (Window 1) and "Session B" (Window 2).
*   **Forcing the Race:** Use `WAITFOR DELAY '00:00:05'` inside the transactions immediately after the conflict checks but before the `COMMIT`. This artificial delay guarantees that Session B will attempt its check while Session A is holding its locks (or failing to hold them in the baseline).
*   **Target DBMS:** 100% Microsoft SQL Server syntax.

## 3. Required Deliverables (File Structure)
The output must generate the following files within the `13-concurrency-tests-G08/` directory:

### `00-setup-test-data.sql`
*   Seeds the necessary pristine test data (users, a specific target space, auto-approval policies, facility assets) required for the subsequent tests.

### `01-race-A-double-approval.sql`
*   **Baseline:** Raw `INSERT/UPDATE` logic relying only on `TR_bookings_PreventOverlapAndUnavailable`. Demonstrates both staff members successfully booking the same room.
*   **Prevention:** Uses `usp_ApproveBooking`. Demonstrates Session A succeeding and Session B throwing Error 50001 (Overlap) or Error 1222/1205.

### `02-race-B-instant-vs-manual.sql`
*   **Baseline:** Raw logic demonstrating an auto-approval script and a manual approval script double-booking the space.
*   **Prevention:** Uses `usp_CreateBookingAutoApproved` (Session A) and `usp_ApproveBooking` (Session B). Demonstrates the shared locking mechanism rejecting the loser.

### `03-race-C-approval-vs-escalation.sql`
*   **Baseline:** Demonstrates a booking being approved simultaneously with an `Advisory` maintenance record escalating to `OutOfService`, bypassing the block.
*   **Prevention:** Uses `usp_ApproveBooking` (Session A) and `usp_EscalateMaintenance` (Session B). Demonstrates the `bookings` -> `maintenance_records` lock-ordering rule preventing a deadlock, forcing one transaction to wait and cleanly fail.

### `04-early-checkout-verification.sql`
*   A single-session script demonstrating that calling `usp_CompleteBooking` prior to the requested end time immediately allows a new booking to be approved for the remaining window without any overlapping errors.

## 4. Formatting and Instruction Rules
*   **Clear Human Instructions:** At the top of each `.sql` file, include a large comment block explaining exactly how the human tester should execute the script (e.g., "1. Open two SSMS query windows. 2. Paste Session A into Window 1. 3. Paste Session B into Window 2. 4. Execute A, then immediately execute B.").
*   **Transaction Isolation:** Ensure the baseline tests explicitly run under `READ COMMITTED` to simulate the Phase 1 flaw, while the prevention tests rely on the `SERIALIZABLE` isolation enforced within the Task 12 procedures.
*   **Self-Contained Executions:** Ensure `ROLLBACK` is cleanly handled if a test fails so the database state does not become corrupted between test runs.