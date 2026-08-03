# Business Requirement — Campus Space Management System (Phase 2 Addendum)

## 1. File purpose

This file is the **condensed business-domain input for Phase 2**. It extends
`business-requirement.md` (Phase 1) and does not replace it — read both together.
It describes *what the business now needs, in addition to Phase 1*, sourced from
`CS486_Project_Phase02.pdf` §1. It is **not** a Phase 2 output itself; it feeds
`08-requirement-change-analysis-G08.md`, `09-updated-erd-and-logical-design-G08.md`,
and `10-schema-migration-G08.sql`.

Following the same discipline Phase 1 used: every rule below is tagged
**[CONFIRMED]** (stated in the Phase 2 PDF), **[EXTENSION]** (proposed by the
team, not required by the graded brief — flag with the TA before investing
build time), or **[OPEN]** (a genuine unresolved question, matching how Phase 1
handled "who may cancel, and until when"). Nothing untagged should be treated
as a settled requirement.

## 2. Background — pilot outcome [CONFIRMED]

- The Phase 1 system was piloted for one semester.
- Based on pilot experience, the Facility Manager requested one change to the
  maintenance rule and a set of new operating conditions. Phase 2 extends the
  Phase 1 system to support them — it does not replace the Phase 1 booking,
  approval, check-in, or maintenance model described in `business-requirement.md`.

## 3. Maintenance impact levels [CONFIRMED]

Phase 1's rule — "a space under maintenance cannot be booked" — is refined,
not removed.

- Maintenance now carries an **impact level**:
  - **out-of-service** — the space itself is unusable (e.g. electrical repair,
    floor replacement, AC replacement). No booking may overlap the
    maintenance period. This is exactly the Phase 1 rule, scoped to this level.
  - **advisory** — only part of the space's equipment or comfort is affected
    (e.g. one broken projector, one faulty AC unit among several, a damaged
    whiteboard). The space **remains bookable**, but:
    - the requester must be shown all currently active advisories on that
      space at booking time, and
    - the system must record that the requester was informed — an
      **acknowledgement stored against the booking**, per advisory.
- A space may have several active maintenance records at once, at different
  impact levels, simultaneously.
- Impact level may be **escalated** (advisory → out-of-service) or
  **downgraded** while the maintenance record is still open.
- **Escalation consequence:** if an advisory record is escalated to
  out-of-service, the system must be able to identify every already-approved
  booking whose time period overlaps the maintenance period, so staff can
  contact those requesters. This is a required lookup, not an automatic
  notification — see §7.4.

## 4. Concurrent booking and auto-approval [CONFIRMED]

- At the start of each semester, many users submit requests for overlapping
  time windows on popular spaces within a short interval.
- **Selected space types** may have requests **auto-approved at submission
  time** if the request satisfies that space's usage policy. All other
  requests continue through the existing manual staff-approval workflow from
  Phase 1.
- The core invariant carries forward unchanged and must now hold under
  concurrency: **the same space may never have two approved bookings with
  overlapping time periods** — regardless of whether either booking arrived
  through instant-booking or manual approval, and regardless of how many
  users or staff act on the same space at the same instant.
- This is a data-integrity requirement, not just a UI-timing one: two staff
  members approving different pending requests for the same slot at the same
  moment must not both succeed.

## 5. New reporting needs [CONFIRMED]

Staff/Facility Manager need, in addition to Phase 1's history views:

1. Total approved booking hours per space, for a given semester.
2. Count of approved bookings by weekday and hour, for a given semester.
3. Spaces available for a required capacity and required facility list,
   within a given time period (the "room finder").
4. Approved bookings affected when a maintenance record is escalated to
   out-of-service (the escalation lookup from §3).

## 6. Team-proposed extensions

These are architectural improvements the team is choosing to build on top of
the graded Phase 2 requirements. They make the system more realistic, but
**§2 of the Phase 2 PDF does not ask for them** — confirm with the TA/lecturer
whether to include them in the graded submission before spending migration
and testing effort on them, so the group doesn't misrepresent assignment scope.

### 6.1 Reserved Time vs. Actual Occupancy Time [EXTENSION]

- Phase 1 already distinguishes *requested* start/end time from *actual*
  start/end time (recorded at check-in/check-out). Phase 2 makes explicit use
  of that distinction: once a booking is checked out — even early — the
  remainder of its originally-reserved window becomes bookable immediately.
  No new data is required for this; it is a consequence of how "currently
  blocking" bookings are queried (see the technical spec, §4).
- Business rule: a user who checks out early has no claim on the remaining
  reserved time. If they need it back, they must submit a new request.

### 6.2 Asset-level facility tracking [EXTENSION]

- Move from Phase 1's "space has 2 projectors" (a quantity) to individually
  identifiable units ("Projector #001", "Projector #002") so that when one
  unit fails, only that unit is taken offline — the space and its other
  equipment stay usable.
- Business rationale: this is what makes "advisory" maintenance meaningful in
  practice — without unit-level tracking, "one of several AC units is down"
  is a sentence in a note field, not a trackable state.
- A maintenance record may now optionally point at a specific asset rather
  than only the space as a whole.
- Some facilities may be marked "required" for a space to be considered
  usable for its normal purpose (e.g. every computer in a computer lab). If
  the *last remaining working unit* of a required facility type goes down,
  the space should be blocked from booking even though no space-level
  out-of-service record exists. **This threshold ("required" facility,
  "last remaining unit") is a team design choice, not a stated business
  rule — flag for confirmation.**

### 6.3 No-show automatic release [OPEN — proposed, unconfirmed]

- Proposal: if a user does not check in within 15 minutes of the requested
  start time, the system automatically marks the booking `No-show` and
  releases the space.
- This is **not stated** in either the Phase 1 or Phase 2 PDF. Phase 1's own
  `business-requirement.md` (§15) explicitly left "who may cancel a booking,
  and until when" as an open question rather than assuming an answer. This
  extension makes the same kind of assumption for no-show timing and should
  receive the same treatment: confirm the 15-minute figure (and whether
  auto-release should exist at all, versus staff manually marking no-show as
  in Phase 1) before building it as a hard rule.

## 7. Updated workflows (business level)

### 7.1 Instant-booking / auto-approval [CONFIRMED]

1. User submits a request for a space whose type is eligible for
   auto-approval.
2. System checks the request against that space type's usage policy
   (capacity, booking type, no overlapping approved/checked-in booking, space
   not out-of-service).
3. If all conditions hold, the booking is approved immediately, with the
   system itself recorded as the decision-maker instead of a staff member.
4. If the space currently has active advisory maintenance, the requester
   must acknowledge each advisory before the booking is finalized — same
   requirement as the manual path (§7.3).
5. If the request does not meet the auto-approval policy, it falls through to
   the existing Phase 1 manual approval workflow unchanged.

### 7.2 Check-in and early check-out [CONFIRMED + EXTENSION]

1. Phase 1's check-in/check-out steps are unchanged.
2. New: when check-out (`Complete`) is recorded before the requested end
   time, the remaining reserved window is available to other requesters
   immediately — no separate release step is needed by staff.

### 7.3 Advisory acknowledgement at booking time [CONFIRMED]

1. At the moment a user selects a space with one or more active advisory
   maintenance records, the system shows all of them.
2. The user (or, for auto-approval, the system on the user's behalf) must
   acknowledge each active advisory.
3. The booking cannot be finalized as `Approved` without one acknowledgement
   per currently-active advisory on that space.

### 7.4 Escalation workflow [CONFIRMED]

1. Facility staff or manager escalates a maintenance record from advisory to
   out-of-service.
2. The system identifies every `Approved` or `Checked-in` booking on that
   space overlapping the maintenance period and surfaces them to staff as an
   action list (contact the requester, arrange relocation/cancellation).
3. Actually notifying the requester (email, SMS) remains staff's manual
   action — automated delivery is out of scope, consistent with Phase 1's
   spec (§17: "Email notification service" listed as out of scope).

### 7.5 Asset-level maintenance reporting [EXTENSION]

1. A reporter (or staff) may file a maintenance record against a specific
   asset rather than the whole space.
2. The impact level is still a Facility Manager judgment call, not
   automatically derived from "how many units are down" — though the system
   should surface that count to help make the call.

## 8. Business rules — Phase 2 additions

1. **[CONFIRMED]** A space may have zero, one, or many active maintenance
   records simultaneously, at independent impact levels.
2. **[CONFIRMED]** An out-of-service maintenance record blocks booking for
   any overlapping time period, exactly as Phase 1's blanket maintenance rule
   did.
3. **[CONFIRMED]** An advisory maintenance record does not block booking, but
   every active advisory on the space must be acknowledged for that specific
   booking before the booking can be approved.
4. **[CONFIRMED]** The same space may never have two `Approved`/`Checked-in`
   bookings with overlapping time periods, regardless of the path
   (auto-approval or manual) that produced either booking, and this must
   hold under concurrent submission/approval.
5. **[CONFIRMED]** Escalating a maintenance record to out-of-service must not
   silently orphan already-approved overlapping bookings — they must be
   identifiable by staff.
6. **[EXTENSION]** A booking may be blocked even without a space-level
   out-of-service record, if a facility type marked "required" for that space
   has no remaining available unit.
7. **[OPEN]** Whether/when a booking is auto-marked `No-show` without staff
   action.

## 9. Assumptions and open questions (Phase 2)

**Assumptions carried forward from Phase 1** (`business-requirement.md` §15)
still hold — recurring bookings remain out of scope, participant count vs.
capacity is stored but not necessarily enforced, etc. — unless noted below.

**New assumptions:**

- Auto-approval eligibility is configured per space type (not per individual
  space), unless a specific space needs an override — to be confirmed with
  the Facility Manager persona/TA.
- "Requester was informed" for an advisory is satisfied by an in-system
  acknowledgement at booking time; it does not imply any external
  notification channel.
- An auto-approval decision is still stored using the same decision record
  shape as a staff decision (§7.1), distinguished only by who/what made it.

**New open questions:**

- If two instant-booking requests race for the same slot, should the losing
  request be auto-rejected, or automatically re-queued as `Pending` for
  manual review? Not stated in either PDF — needs a product decision.
- What exactly makes a facility "required" for a space (§6.2)? This is a
  team-invented concept, not a stated rule — needs confirmation before it's
  treated as gradeable scope.
- The 15-minute no-show window (§6.3) is an unconfirmed number, not a stated
  policy.
- Who may downgrade an out-of-service record back to advisory, and does that
  automatically re-open the space for booking, or does staff need to also
  update the space status separately? Not addressed by the PDF.
