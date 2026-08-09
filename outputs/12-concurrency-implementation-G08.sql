/* ===========================================================================
   Step 12: Concurrency Implementation — G08 (Phase 2)
   File     : outputs/12-concurrency-implementation-G08.sql
   Target   : Microsoft SQL Server 2016 SP1+ (CREATE OR ALTER PROCEDURE,
              THROW, sp_set_session_context, SESSION_CONTEXT)
   Design   : outputs/11-concurrency-design-G08.md       (mechanisms, §III)
   Schema   : outputs/09-updated-erd-and-logical-design-G08.md  (names, §5)
   Triggers : outputs/10-schema-migration-G08.sql        (R1–R16 backstops)
   Contract : outputs/11-concurrency-design-G08.md §VI (C1–C7)
   Business : req/business-requirement-P2.md             (§4, §7)

   ---------------------------------------------------------------------------
   WHAT THIS FILE CONTAINS
   ---------------------------------------------------------------------------
   The four production stored procedures that make the Phase 2 core invariant
   survive simultaneous requests:

       no two Approved / CheckedIn bookings overlap on the same space,
       regardless of whether a booking arrived through instant booking
       (auto-approval) or the manual staff-approval workflow.

   Serialization primitive (Task 11, §III.2 / §III.3):

       SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
       SELECT ... FROM dbo.bookings b WITH (UPDLOCK, HOLDLOCK) WHERE ...;

   Under default READ COMMITTED a check-then-act window is open (TOCTOU):
   two transactions can both see an empty slot, both insert, both commit.
   UPDLOCK + HOLDLOCK under SERIALIZABLE takes key-range locks on the
   predicate — including the gap where a new conflicting row would land —
   closing that window. The Task 10 trigger TR_bookings_PreventOverlapAndUnavailable
   is a validation backstop (contract C6): it validates the committed state,
   it does NOT serialize. The stored procedures below ARE the serialization.

   MANDATORY LOCK-ACQUISITION ORDER (contract C4):
       bookings  ->  maintenance_records  ->  booking_alerts
   Every procedure that touches bookings AND maintenance_records (directly,
   or transitively via the escalation trigger that writes booking_alerts)
   acquires the bookings range lock BEFORE the maintenance_records lock. This
   single global order removes the deterministic deadlock that opposite
   orderings would create on the approval-vs-escalation collision
   (Task 11 §II.3 / §III.5).

   ERROR MODEL (contract C5)
   All procedures wrap their work in BEGIN TRY ... BEGIN CATCH with
   SET XACT_ABORT ON. They ROLLBACK and re-THROW the original error unchanged.
   Retry is owned by the CALLER (application layer), which inspects
   ERROR_NUMBER():
       1205  Deadlock victim .............................. RETRYABLE
       1222  Lock request timeout ......................... RETRYABLE
       5xxxx Business-rule violation (slot taken, policy miss,
             wrong state) ................................. TERMINAL
   Booking_alerts rows (escalation) and maintenance_impact_history audit rows
   are written by the Task 10 triggers as a side effect of the UPDATEs issued
   here (contract C6) — this file deliberately does NOT write them directly.

   ERROR CODES USED IN THIS FILE (numbers 50001–50099 are reserved for the
   booking-creation / approval / escalation procedures):
       50001 Overlap with an Approved/CheckedIn booking on the same space.
       50002 Active OutOfService maintenance overlaps the window.
       50003 Space temporarily closed or retired.
       50004 Booking not in Pending (approvable) state / policy not found.
       50005 Booking type ineligible under the auto-approval policy.
       50006 Expected participants exceed space capacity / policy cap.
       50007 Unacknowledged active advisories.
       50009 A facility marked required has no available unit.
       50010 Auto-approval flow fell unrecoverable (reserved).
       50011 Invalid time window (end <= start).
       50012 Non-positive participant count.
       50015 Space not found.
       50020 Maintenance record not found (escalation).
       50021 Escalation of a Completed/Cancelled maintenance record.
       50022 Escalation of a record that is not Advisory.
       50023 Escalation of an asset-scoped record (check CK constraint).
       50030 No usage session (completion).
       50031 Booking already completed / not found (completion).
       50032 Booking not in CheckedIn state (completion).

   REQUIRED PREREQUISITES (from Task 10):
      Schema ...... outputs/10-schema-migration-G08.sql
      Triggers ...  TR_bookings_PreventOverlapAndUnavailable,
                    TR_bookings_AdvisoryAckRequired,
                    TR_maintenance_escalation, TR_maintenance_impact_history,
                    TR_impact_history_StaffRole, TR_booking_decisions_StaffRole
      Indexes  .... IX_bookings_space_status_time (I1), IX_maintenance_blk
                    (I3). They keep the key-range locks used here granular
                    (contract C7). Absence degrades to table locks — still
                    correct, just less concurrent.
   =========================================================================== */


/* ===========================================================================
   PROCEDURE 1: usp_ApproveBooking (MANUAL STAFF PATH)
   ---------------------------------------------------------------------------
   Approves a Pending booking under concurrency, using exactly the same
   serialization primitives as the auto-approval path so that manual approval
   and instant booking cannot both win the same slot (Task 11 / §II.2).

   Parameters:
       @booking_id       the booking to approve
       @staff_id         the staff user making the decision
       @decision_note    free-text decision note (optional)

   Terminal errors: 50001 (overlap), 50002 (OutOfService),
                     50003 (space closed), 50004 (wrong state), 50007, 50009.
   =========================================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_ApproveBooking
    @booking_id     INT,
    @staff_id       INT,
    @decision_note  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    DECLARE @space_id        INT;
    DECLARE @req_start_time  DATETIME2;
    DECLARE @req_end_time    DATETIME2;
    DECLARE @current_status  NVARCHAR(20);

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---- 1. Lock the target row and read the decision context ---------
           UPDLOCK + HOLDLOCK on the bookings row makes this transaction the
           only transaction able to modify this booking row until COMMIT, so
           two staff members approving the SAME pending request serialize too. */
        SELECT @space_id       = b.space_id,
               @req_start_time = b.requested_start_time,
               @req_end_time   = b.requested_end_time,
               @current_status = b.status
        FROM   dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
        WHERE  b.booking_id = @booking_id;

        IF @space_id IS NULL
            THROW 50004, N'Booking not found.', 1;

        /* Only Pending bookings are approvable. */
        IF @current_status <> N'Pending'
            THROW 50004, N'Booking is not in a Pending (approvable) state.', 1;

        /* ---- 2. Serialized conflict check (the range that blocks both paths)
           SAME predicate the auto-approval path uses, with the SAME
           (UPDLOCK, HOLDLOCK) hints under SERIALIZABLE. A concurrent approval
           of an overlapping window blocks on this key-range lock until this
           commit; a retry then sees the winner and fails cleanly.  */

        IF EXISTS (
            SELECT 1
            FROM   dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
            WHERE  b.space_id = @space_id
              AND  b.booking_id <> @booking_id
              AND  b.status IN (N'Approved', N'CheckedIn')
              AND  b.requested_start_time < @req_end_time
              AND  b.requested_end_time   > @req_start_time
        )
            THROW 50001, N'Overlapping Approved/CheckedIn booking exists for this space.', 1;

        /* ---- 3. Impact-level check (maintenance) with the same discipline -
           This lock is acquired AFTER the bookings range lock above, satisfying
           the mandatory order bookings -> maintenance_records (C4).          */
        IF EXISTS (
            SELECT 1
            FROM   dbo.maintenance_records m WITH (UPDLOCK, HOLDLOCK)
            WHERE  m.space_id = @space_id
              AND  m.status NOT IN (N'Completed', N'Cancelled')
              AND  m.impact_level = N'OutOfService'
              AND  m.start_time < @req_end_time
              AND  COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2))
                    > @req_start_time
        )
            THROW 50002, N'Space has active OutOfService maintenance overlapping the requested window.', 1;

        /* ---- 4. Advisory acknowledgement completeness (R3) ------------------
           Set-based NOT EXISTS, never a COUNT comparison (counting is not
           set containment). Every currently active advisory on the space must
           have an acknowledgment row for THIS booking.                        */
        IF EXISTS (
            SELECT 1
            FROM   dbo.maintenance_records m WITH (UPDLOCK, HOLDLOCK)
            WHERE  m.space_id = @space_id
              AND  m.impact_level = N'Advisory'
              AND  m.status NOT IN (N'Completed', N'Cancelled')
              AND  m.start_time < @req_end_time
              AND  COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2))
                    > @req_start_time
              AND  NOT EXISTS (
                        SELECT 1
                        FROM   dbo.booking_advisory_acknowledgments a
                        WHERE  a.booking_id  = @booking_id
                          AND  a.maintenance_id = m.maintenance_id
                    )
        )
            THROW 50007, N'Booking has unacknowledged active advisories for this space.', 1;

        /* ---- 5. Required-asset availability (R8) ----------------------------
           Blocks when a facility type marked REQUIRED for the space has no
           available unit, independent of any space-level record.            */
        IF EXISTS (
            SELECT 1
            FROM   dbo.space_facility_requirements r
            WHERE  r.space_id = @space_id
              AND  NOT EXISTS (
                        SELECT 1
                        FROM   dbo.facility_assets fa
                        WHERE  fa.space_id      = r.space_id
                          AND  fa.facility_name = r.facility_name
                          AND  fa.asset_status  = N'Available'
                    )
        )
            THROW 50009, N'A facility marked required for this space has no available unit.', 1;

        /* ---- 6. Current space closure check (non-maintenance) --------------- */
        DECLARE @space_status NVARCHAR(20);
        SELECT @space_status = s.current_status
        FROM   dbo.spaces s
        WHERE  s.space_id = @space_id;

        IF @space_status IN (N'TemporarilyClosed', N'Retired')
            THROW 50003, N'Space is temporarily closed or retired.', 1;

        /* ---- 7. Make the decision ---------------------------------------
           The status flip is the publication point. TR_bookings_PreventOverlap:
           the backstop trigger RUNS here on the UPDATE, but the AUTHORITATIVE
           serialization already happened at step 2.                       */
        UPDATE dbo.bookings
        SET    status = N'Approved'
        WHERE  booking_id = @booking_id;

        INSERT INTO dbo.booking_decisions
              (booking_id, decided_by, decision, decision_time,
               decision_note, rejection_reason, decision_source)
        VALUES (@booking_id, @staff_id, N'Approved', GETDATE(),
                @decision_note, NULL, N'Staff');
        /* TR_booking_decisions_StaffRole (Task 10) validates the staff role. */

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        -- Re-throw UNCHANGED. Caller inspects ERROR_NUMBER(): 1205/1222 =>
        -- retry with backoff; 5xxxx => terminal.
        THROW;
    END CATCH
END;
GO


/* ===========================================================================
   PROCEDURE 2: usp_CreateBookingAutoApproved (INSTANT / AUTO-APPROVAL PATH)
   ---------------------------------------------------------------------------
   Evaluates the auto-approval policy for a submission and, when all
   conditions pass, performs the multi-statement flow inside ONE serializable
   transaction (Task 11 / §II.2 + §III.4). The mandatory statement order is:

        INSERT bookings (Pending)
          -> INSERT booking_advisory_acknowledgments (system on requester's
             behalf, req-business-P2 §7.3)
        -> INSERT booking_decisions (System, decided_by = NULL)
        -> UPDATE bookings.status = 'Approved'

   The Pending -> acks -> Approved order is load-bearing: the advisory-ack
   trigger (TR_bookings_AdvisoryAckRequired) fires on the status-change
   statement and therefore requires the acknowledgment rows to already be
   visible inside the same (uncommitted) transaction.

   When the request is NOT eligible (policy ineligible / capacity exceeded),
   the procedure raises a TERMINAL 5xxxx error. The caller decides the
   fall-through to the Phase 1 manual-pending workflow (the DB contract only
   guarantees the loser fails cleanly, Task 3 / Appendix A). Practical
   fall-through to 'Pending' is a caller responsibility.

   Parameters:
       @space_id            target space
       @requester_id        submitting user (who consent to advisories)
       @requested_start_time  reserved window start
       @requested_end_time    reserved window end
       @expected_participants capacity/limit evaluation
       @booking_type        bookings.booking_type
       @purpose              purpose text
       @booking_id           OUTPUT created booking id
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_CreateBookingAutoApproved
    @space_id              INT,
    @requester_id          INT,
    @requested_start_time  DATETIME2,
    @requested_end_time    DATETIME2,
    @expected_participants INT,
    @booking_type          NVARCHAR(30),
    @purpose               NVARCHAR(MAX),
    @booking_id            INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    DECLARE @policy_id       INT;
    DECLARE @policy_max      INT;
    DECLARE @space_capacity  INT;
    DECLARE @space_status    NVARCHAR(20);
    DECLARE @space_type      NVARCHAR(30);

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---------- 0. Input validation (terminal) ------------------------- */
        IF @requested_end_time <= @requested_start_time
            THROW 50011, N'Requested end time must be after start time.', 1;
        IF @expected_participants <= 0
            THROW 50012, N'Expected participants must be positive.', 1;

        /* ---------- 1. Space context (type, capacity, status) -------------- */
        SELECT @space_capacity = s.capacity,
               @space_status   = s.current_status,
               @space_type     = s.space_type
        FROM   dbo.spaces s
        WHERE  s.space_id = @space_id;

        IF @space_type IS NULL
            THROW 50015, N'Space not found.', 1;

        IF @space_status IN (N'TemporarilyClosed', N'Retired')
            THROW 50003, N'Space is temporarily closed or retired.', 1;

        /* ---------- 2. Effective auto-approval policy (override precedence) -
           A specific-space policy always wins; the type-wide policy applies
           only when no space-specific one exists (L8 precedence rule).   */
        SELECT @policy_id  = p.policy_id,
               @policy_max = p.max_participants
        FROM   dbo.auto_approval_policies p
        WHERE  p.space_id = @space_id
          AND  p.is_active = 1;

        IF @policy_id IS NULL
        BEGIN
            SELECT @policy_id  = p.policy_id,
                   @policy_max = p.max_participants
            FROM   dbo.auto_approval_policies p
            INNER  JOIN dbo.spaces s2 ON s2.space_type = p.space_type
            WHERE  p.space_id IS NULL
              AND  p.is_active = 1
              AND  s2.space_id = @space_id;
        END

        IF @policy_id IS NULL
            THROW 50004, N'No active auto-approval policy applies to this space.', 1;

        /* ---------- 3. Booking type allow-list ----------------------------- */
        IF NOT EXISTS (
            SELECT 1
            FROM   dbo.policy_booking_types pbt
            WHERE  pbt.policy_id  = @policy_id
              AND  pbt.booking_type = @booking_type
        )
            THROW 50005, N'This booking type is not eligible for auto-approval under the policy.', 1;

        /* ---------- 4. Capacity / policy cap, NULL-safe max (S2) ------------ */
        IF @expected_participants > @space_capacity
            THROW 50006, N'Expected participants exceed the space capacity.', 1;

        IF @policy_max IS NOT NULL AND @expected_participants > @policy_max
            THROW 50006, N'Expected participants exceed the auto-approval policy limit.', 1;

        /* ---------- 5. THE SAME serialized checks as the manual path ----------
           (a) Overlap check — first lock of the transaction on bookings,
               key-range lock via I1 (contracts C1, C7). Page-level conflict. */
        IF EXISTS (
            SELECT 1
            FROM   dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
            WHERE  b.space_id = @space_id
              AND  b.status IN (N'Approved', N'CheckedIn')
              AND  b.requested_start_time < @requested_end_time
              AND  b.requested_end_time   > @requested_start_time
        )
            THROW 50001, N'Overlapping Approved/CheckedIn booking exists for this space.', 1;

        /* (b) impact-level check — bookings -> maintenance_records ORDER. */
        IF EXISTS (
            SELECT 1
            FROM   dbo.maintenance_records m WITH (UPDLOCK, HOLDLOCK)
            WHERE  m.space_id = @space_id
              AND  m.status NOT IN (N'Completed', N'Cancelled')
              AND  m.impact_level = N'OutOfService'
              AND  m.start_time < @requested_end_time
              AND  COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2))
                    > @requested_start_time
        )
            THROW 50002, N'Space has active OutOfService maintenance overlapping the requested window.', 1;

        /* (c) Required-asset availability (R8) */
        IF EXISTS (
            SELECT 1
            FROM   dbo.space_facility_requirements r
            WHERE  r.space_id = @space_id
              AND  NOT EXISTS (
                        SELECT 1
                        FROM   dbo.facility_assets fa
                        WHERE  fa.space_id      = r.space_id
                          AND  fa.facility_name = r.facility_name
                          AND  fa.asset_status  = N'Available'
                    )
        )
            THROW 50009, N'A facility marked required for this space has no available unit.', 1;

        /* ---------- 6. THE EXACT MULTI-STATEMENT ORDER (contract C3) --------- */
        /* 6a. CREATE the booking as Pending FIRST.                               */
        INSERT INTO dbo.bookings
              (requester_id, space_id, requested_start_time, requested_end_time,
               purpose, expected_participants, booking_type, status)
        VALUES
              (@requester_id, @space_id, @requested_start_time, @requested_end_time,
               @purpose, @expected_participants, @booking_type, N'Pending');

        SET @booking_id = SCOPE_IDENTITY();

        /* 6b. Insert one advisory-acknowledgment per ACTIVE Advisory for the
             requester (business-req-P2 §7.3: system acknowledges on behalf
             of the user).                                    */
        INSERT INTO dbo.booking_advisory_acknowledgments
              (booking_id, maintenance_id, acknowledged_by, acknowledged_at)
        SELECT @booking_id, m.maintenance_id, @requester_id, GETDATE()
        FROM   dbo.maintenance_records m
        WHERE  m.space_id = @space_id
          AND  m.impact_level = N'Advisory'
          AND  m.status NOT IN (N'Completed', N'Cancelled')
          AND  m.start_time < @requested_end_time
          AND  COALESCE(m.completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2))
                > @requested_start_time;

        /* 6c. System decision row (decided_by = NULL paired with
             decision_source = 'System' via CK_booking_decisions_source_actor). */
        INSERT INTO dbo.booking_decisions
              (booking_id, decided_by, decision, decision_time,
               decision_note, rejection_reason, decision_source)
        VALUES
              (@booking_id, NULL, N'Approved', GETDATE(),
               NULL, NULL, N'System');

        /* 6d. Flip the booking to Approved LAST. The backstop triggers
             (advisory ack + overlap) run on this statement and see the acks;
             the AUTHORITATIVE conflict check already ran at step §5. */
        UPDATE dbo.bookings
        SET    status = N'Approved'
        WHERE  booking_id = @booking_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        -- Re-throw unchanged (caller decides retry vs terminal).
        THROW;
    END CATCH
END;
GO


/* ===========================================================================
   PROCEDURE 3: usp_EscalateMaintenance (ESCALATION PATH)
   ---------------------------------------------------------------------------
   Escalates a maintenance record from 'Advisory' to 'OutOfService'. The
   booking_alerts and maintenance_impact_history rows are written by the
   Task 10 triggers (TR_maintenance_escalation and TR_maintenance_impact_history)
   as a side effect of the UPDATE; this procedure owns the transaction
   envelope and — decisively — the LOCK ORDERING.

   CRITICAL ORDERING (contract C4): although escalation LOGICALLY reads the
   maintenance record first, it must ACQUIRE THE OVERLAPPING-BOOKINGS RANGE
   LOCK BEFORE any write to maintenance_records. Task 11 §III.5:
       approval    : bookings -> maintenance
       escalation  : maintenance -> bookings/alerts     (opposite -> deadlock)
   Implementation: the one-row maintenance lookup that gives us the window is
   done under READ COMMITTED, BEFORE the transaction opens, so it holds
   nothing. Then, INSIDE the serializable transaction, the first lock is the
   bookings (UPDLOCK, HOLDLOCK) range; only after that does the procedure
   re-validate and UPDATE maintenance_records. So the steady-state ordering is
   bookings -> maintenance_records -> booking_alerts (the R5 alert insert runs
   on the AFTER UPDATE trigger, as the LAST resource).
   By taking the bookings UPDLOCK range first, both workflows contend on the
   SAME bookings range first — the deterministic lock cycle disappears.
   Also NOTE: a record carrying asset_id cannot be escalated because
   CK_maintenance_records_asset_scope_level requires asset-scoped records to
   stay Advisory. Such a call is a terminal error.

   Parameters:
       @maintenance_id  the record to escalate
       @staff_id        staff who performs the escalation (audit actor)
       @reason          free text stored in the audit trail
   ========================================================================
   Error codes: 50020 not found, 50021 Completed/Cancelled, 50022 not
   Advisory, 50023 asset-scoped escalation attempt.
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_EscalateMaintenance
    @maintenance_id INT,
    @staff_id       INT,
    @reason         NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @m_space_id        INT;
    DECLARE @m_start_time      DATETIME2;
    DECLARE @m_completion_time DATETIME2;
    DECLARE @m_impact          NVARCHAR(20);
    DECLARE @m_status          NVARCHAR(20);
    DECLARE @m_asset_id        INT;

    /* ---- 0. PRE-TRANSACTION context read (READ COMMITTED) -----------
       We need the maintenance record's space + window to build the
       bookings-range lock of step 2. Read it NOW, outside any
       transaction and before the isolation level is raised, so this
       read holds no meaningful lock (it is a single-row PK seek). This
       preserves the documented steady-state lock order bookings ->
       maintenance_records -> booking_alerts (contract C4); the read
       itself is not part of the locking schedule.                 */
    SELECT @m_space_id        = m.space_id,
           @m_start_time      = m.start_time,
           @m_completion_time = m.completion_time,
           @m_impact          = m.impact_level,
           @m_status          = m.status,
           @m_asset_id        = m.asset_id
    FROM   dbo.maintenance_records m
    WHERE  m.maintenance_id = @maintenance_id;

    IF @m_space_id IS NULL
        THROW 50020, N'Maintenance record not found.', 1;

    IF @m_status IN (N'Completed', N'Cancelled')
        THROW 50021, N'Cannot escalate a Completed or Cancelled maintenance record.', 1;

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;

    BEGIN TRY
        /* ---- 1. FIRST significant lock: the bookings range (C4) -----------
           Lock EVERY Approved/CheckedIn booking on this space that overlaps
           the maintenance window with (UPDLOCK, HOLDLOCK). This is the SAME
           range an approval would lock, acquired FIRST. It serializes against
           any concurrent approval that would try to win the slot and serves
           as the gateway that TR_maintenance_escalation will walk to write
           alerts (alerts are the LAST resource, written by the trigger).    */
        SELECT b.booking_id
        FROM   dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
        WHERE  b.space_id = @m_space_id
          AND  b.status IN (N'Approved', N'CheckedIn')
          AND  b.requested_start_time <
                COALESCE(@m_completion_time, CAST(N'9999-12-31 23:59:59' AS DATETIME2))
          AND  b.requested_end_time   > @m_start_time;

        /* ---- 2. Re-validate the record under SERIALIZABLE ---------------
           The pre-transaction read is a snapshot; between that read and this
           point a concurrent escalation could have already moved the record
           to OutOfService (or a cancel/complete could have landed). SERIALIZABLE
           guarantees we see the latest committed state; if the record is no
           longer a valid escalation target we fail cleanly.              */
        SELECT @m_impact   = m.impact_level,
               @m_status   = m.status,
               @m_asset_id = m.asset_id
        FROM   dbo.maintenance_records m WITH (UPDLOCK, HOLDLOCK)
        WHERE  m.maintenance_id = @maintenance_id;

        IF @m_status IN (N'Completed', N'Cancelled')
            THROW 50021, N'Cannot escalate a Completed or Cancelled maintenance record.', 1;

        IF @m_impact <> N'Advisory'
            THROW 50022, N'The record is not Advisory — escalation is not applicable.', 1;

        IF @m_asset_id IS NOT NULL
            THROW 50023, N'Asset-scoped maintenance stays Advisory and cannot be escalated.', 1;

        /* ---- 3. Persist the escalation. The UPDATE fires the triggers: ----
           TR_maintenance_impact_history  -> audit row with actor/reason
           TR_maintenance_escalation  -> booking_alerts rows (LAST resource)
           TR_impact_history_StaffRole   -> staff role validation
           sp_set_session_context gives the triggers the actor and reason now. */
        DECLARE @bounded_reason NVARCHAR(128) = CAST(@reason AS NVARCHAR(128));
        EXEC sys.sp_set_session_context @key = N'current_user_id', @value = @staff_id;
        EXEC sys.sp_set_session_context @key = N'change_reason',   @value = @bounded_reason;

        UPDATE dbo.maintenance_records
        SET    impact_level = N'OutOfService', updated_at = GETDATE()
        WHERE  maintenance_id = @maintenance_id;

        COMMIT TRANSACTION;

        /* Clear the session context so later statements don't inherit a stale
           actor/reason pair (e.g. a conditioned student report on the same
           connection). */
        EXEC sys.sp_set_session_context @key = N'current_user_id', @value = NULL;
        EXEC sys.sp_set_session_context @key = N'change_reason',   @value = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC sys.sp_set_session_context @key = N'current_user_id', @value = NULL;
        EXEC sys.sp_set_session_context @key = N'change_reason',   @value = NULL;
        THROW;
    END CATCH
END;
GO


/* ===========================================================================
   PROCEDURE 4: usp_CompleteBooking (EARLY CHECK-OUT / LOW CONTENTION)
   ---------------------------------------------------------------------------
   Implements the Phase 2 "early check-out" behaviour: writing the actual
   occupancy end time and moving the booking to 'Completed' immediately
   releases the remaining window of its reserved slot (Output 09 §9.4).
   Because the conflict interval is driven by status (only Approved /CheckedIn
   block), the moment status becomes Completed the row exits the blocking
   filter — no trigger, timer, or stored flag (contract C and §III.8).

   DESIGN: this procedure DELIBERATELY performs NONE of the serialized checks
   of the booking-creation pathway (Output 09 §9.5 - S1). Releasing a slot
   can never create an overlap, so the check-in/out change cannot violate the
   invariant, and locking the bookings/maintenance ranges on check-out would
   add contention at the exact semester-start peaks. It runs a small
   transaction that locks only the target bookings row and its usage_sessions
   row (by UQ_usage_sessions_booking_id).

   Parameters:
       @booking_id      the CheckedIn booking to complete
       @staff_id        the student staff performing check-out (outer)
       @final_condition free-text condition of the space
   ===========================================================================
   Terminal errors: 50030 no session, 50031 already completed / not found,
   50032 not CheckedIn.
   ========================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_CompleteBooking
    @booking_id       INT,
    @staff_id         INT,
    @final_condition  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- INTENTIONALLY NO SERIALIZABLE (low-contention path, see header).

    DECLARE @session_id     INT;
    DECLARE @booking_status NVARCHAR(20);
    DECLARE @actual_end     DATETIME2;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---- 1. Lock the single usage-session row (unique-by-booking) ------ */
        SELECT @session_id = us.session_id,
               @actual_end = us.actual_end_time
        FROM   dbo.usage_sessions us WITH (UPDLOCK)
        WHERE  us.booking_id = @booking_id;

        IF @session_id IS NULL
            THROW 50030, N'No usage session exists for this booking — it has not been checked in.', 1;

        IF @actual_end IS NOT NULL
            THROW 50031, N'Booking usage session is already completed.', 1;

        /* ---- 2. Confirm the booking is CheckedIn ---------------------------- */
        SELECT @booking_status = b.status
        FROM   dbo.bookings b WITH (UPDLOCK)
        WHERE  b.booking_id = @booking_id;

        IF @booking_status IS NULL
            THROW 50031, N'Booking not found.', 1;

        IF @booking_status <> N'CheckedIn'
            THROW 50032, N'Booking is not in CheckedIn state — cannot complete.', 1;

        /* ---- 3. Two small writes; the second flips the interval filter.   */
        UPDATE dbo.usage_sessions
        SET    actual_end_time = GETDATE(),
               completed_by    = @staff_id,
               final_condition = @final_condition
        WHERE  session_id = @session_id;

        UPDATE dbo.bookings
        SET    status = N'Completed'
        WHERE  booking_id = @booking_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO