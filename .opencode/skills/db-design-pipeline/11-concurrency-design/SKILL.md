# Skill: Phase 2 Concurrency Design Generator (Task 11)

**Role:** Senior Lead Database Architect & Concurrency Expert  
**Target DBMS:** Microsoft SQL Server 2016 SP1+  
**Output File:** `11-concurrency-design-G08.md`

## 1. Objective
Generate a comprehensive, defensively written architectural document that defines how the Campus Space Management System prevents Time-Of-Check-To-Time-Of-Use (TOCTOU) / lost-update race conditions during high-load semester-start periods. The document must translate the business requirements of concurrent booking and auto-approval into concrete SQL Server transaction isolation mechanisms.

## 2. Context & Constraints
*   **The Invariant:** The same space may never have two `Approved` or `CheckedIn` bookings with overlapping time periods.
*   **The Flaw:** The Phase 1 `AFTER` trigger only validates state at the statement level. It does not serialize transactions, allowing concurrent operations to observe the same available slot and both successfully commit.
*   **The Rule:** Do not use PostgreSQL constructs (no `SERIALIZABLE DEFERRABLE`, no `EXCLUDE USING gist`). Rely exclusively on SQL Server locking primitives and isolation levels.

## 3. Required Document Structure
The generated Markdown file must strictly follow this outline:

### I. Introduction and Failure Mode Analysis
*   Define the concurrency requirement outlined in the Phase 2 specification[cite: 7].
*   Explain the "Check-Then-Act" (TOCTOU) failure mode inherent in the Phase 1 trigger-only design.
*   Clearly state that triggers are demoted to a validation backstop, while stored procedures will handle the actual serialization.

### II. Identified Race Conditions
Detail the exact step-by-step interleaving of transactions for the following three scenarios:
1.  **Double Approval (Manual vs. Manual):** Two staff members attempt to manually approve different pending requests for the same room and time slot simultaneously.
2.  **Instant vs. Manual Approval:** The system evaluates an auto-approval policy[cite: 7] at the exact millisecond a staff member manually approves a conflicting request.
3.  **Approval vs. Maintenance Escalation:** A booking is being approved while a facility staff member simultaneously escalates an overlapping `Advisory` maintenance record to `OutOfService`[cite: 7]. (Highlight the deadlock risk here).

### III. Proposed Concurrency Control Mechanism
Document the mandatory SQL Server mechanisms that will be implemented in Task 12:
*   **Transaction Isolation:** Mandate `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`.
*   **Key-Range Locking:** Explain the mandatory use of the `WITH (UPDLOCK, HOLDLOCK)` table hints on the overlap and impact-level `SELECT` queries to lock the specific time-window gap.
*   **Lock Acquisition Ordering:** Define the strict cross-table lock order (`bookings` -> `maintenance_records` -> `booking_alerts`) required to minimize deadlocks between the approval and escalation workflows.
*   **Error Handling (Bounded Retry):** Mandate `TRY...CATCH` blocks with bounded retry logic to gracefully handle SQL Server Error 1205 (Deadlock Victim) and Error 1222 (Lock Request Timeout).

### IV. Alternative Mechanisms Evaluated
*   Analyze the use of Application Locks (`sp_getapplock` with `@Resource = 'booking_space_{id}'`).
*   Provide a brief trade-off analysis: simpler mental model versus sacrificing concurrency by serializing *all* bookings for a space, even non-overlapping ones. State whether this will be used as a primary defense or a belt-and-braces addition.

## 4. Tone and Formatting Rules
*   Maintain a highly technical, objective, and academic tone suitable for a senior architecture review.
*   Use SQL code blocks to demonstrate the specific `SELECT ... WITH (UPDLOCK, HOLDLOCK)` queries.
*   Ensure all table names, column names, and isolation levels are formatted as `inline code`.
*   Do not include the actual DDL or full stored procedure bodies (that is strictly reserved for Task 12). Keep the focus purely on the *design* and *mechanisms*.