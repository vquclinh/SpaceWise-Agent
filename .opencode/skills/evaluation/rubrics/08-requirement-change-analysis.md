# Rubric: 08-requirement-change-analysis-G<Group#>.md

Phase 2 — specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions).

## Source of truth
Grade against the Phase 2 requirement document (CS486_Project_Phase02.pdf, sections
1.1–1.3) and the group's finalized Phase 1 outputs (tasks 01–05). This task's job is to
identify *what changes*, *what is added*, and *what conflicts arise* — not to redesign
anything yet (that is task 09). If the document starts proposing schema or DDL changes,
flag as scope creep and redirect those observations to task 09.

## Criteria

### 1. Maintenance impact level change (weight: high)
Must identify that Phase 1's blanket "no booking under maintenance" rule is replaced by
a two-level system:
- **out-of-service**: space cannot be booked for any overlapping period — same behaviour
  as Phase 1.
- **advisory**: space can still be booked; system must notify the requester of all active
  advisories and record an acknowledgement with the booking.

Check that the analysis captures all additional rules from section 1.1:
- A space may have several active maintenance records simultaneously with different
  impact levels.
- Impact level may be escalated (advisory → out-of-service) or downgraded while open.
- On escalation to out-of-service, already-approved overlapping bookings must be
  identifiable so staff can contact requesters.

Missing any of these sub-rules is a deduction proportional to its downstream importance
(escalation/downgrade detection is especially critical — it drives a new query requirement
and a schema change).

### 2. Affected entities and attributes (weight: high)
Must identify every Phase 1 entity that needs to change and every new entity/attribute
that needs to be added:
- `MaintenanceRecord` (Phase 1): needs a new `impact_level` attribute with domain
  {out-of-service, advisory}, and must support level changes over time (flag whether the
  group identifies this as a simple column update or as a history/audit trail requirement —
  the requirement says "may be escalated or downgraded while open", implying the current
  level must be queryable, but a full history is not explicitly required; either interpretation
  is acceptable if justified).
- New concept: **advisory acknowledgement** — must be identified as a new entity or
  attribute attached to `Booking`, recording that the requester was informed of active
  advisories at booking time. Flag if the group misses this entirely or folds it into an
  existing field without noting it is a new structural addition.
- `Booking` (Phase 1): needs to support the acknowledgement linkage and potentially a
  new status or flag for instant-booking path.
- No other Phase 1 entities need structural changes beyond these — flag if the group
  over-extends the change surface without justification.

### 3. Affected relationships (weight: medium)
Must identify:
- New relationship: `Booking` — acknowledges → `MaintenanceRecord` (or equivalent
  junction capturing which advisory records were active and acknowledged at booking
  time). Cardinality: one booking may acknowledge zero or many advisories (M:N via a
  junction, or 1:N if acknowledgement is stored per advisory on the booking).
- Modified relationship: the Phase 1 rule "a space under maintenance cannot be booked"
  now conditionally applies only to out-of-service records — the analysis should note
  that the booking-space-maintenance constraint logic changes, not just the attribute.
- Escalation impact: the analysis should note that escalation creates a reverse-lookup
  need: from a `MaintenanceRecord` to all `Booking` rows that overlap its period — this
  relationship already exists via `space_id` + time range in Phase 1, but the query
  support requirement makes it worth explicitly calling out here.

### 4. Concurrency conflict identification (weight: high)
Section 1.2 requires identifying at least one concurrency conflict. The analysis must:
- Name the specific conflict type: **lost update / write-write conflict** on the booking
  approval step — two staff members (or two instant-booking requests) read the space as
  available for the same time slot, both decide to approve, and both write without seeing
  the other's write, resulting in two approved overlapping bookings.
- Describe the sequence of operations that causes the conflict (e.g. read availability →
  decision → write approval, interleaved across two concurrent sessions).
- Distinguish between the two booking paths mentioned in section 1.2: instant-booking
  (auto-approved at submission) and staff-approval workflow — both must be identified
  as sources of the conflict, not just one.
- Propose at least one solution mechanism. Accept any of: pessimistic locking
  (`SELECT ... WITH (UPDLOCK, HOLDLOCK)` or equivalent), optimistic locking
  (version/timestamp column with conflict detection on write), serializable isolation
  level, or application-level advisory locks. The proposal does not need to be fully
  implemented here (that is task 12) — but it must be specific enough to be
  implementable. "Use transactions" alone is not sufficient; the isolation level or lock
  hint must be named.

### 5. Business rules updated (weight: high)
Must produce an explicit, numbered or bulleted list of updated/new business rules,
clearly distinguishing which Phase 1 rules are replaced, which are preserved unchanged,
and which are new. At minimum:

**Replaced rules:**
- Phase 1: "A space under maintenance cannot be booked." →
  Phase 2: "A space with an out-of-service maintenance record cannot be booked for any
  overlapping period. A space with only advisory records can be booked with
  acknowledgement."

**New rules:**
- A booking against a space with active advisory records must store an acknowledgement
  per advisory record.
- Escalating a maintenance record from advisory to out-of-service requires identifying all
  approved bookings that overlap the maintenance period.
- Two approved bookings cannot use the same space during overlapping periods,
  regardless of the approval path (instant or staff).

Flag if the group lists new rules without explicitly retiring the Phase 1 rule they replace —
this matters because task 09 will need to know exactly which constraints to update.

### 6. Reporting needs analysis (weight: medium)
Must enumerate all four queries from section 1.3 and briefly note what data each requires
to be present in the schema:
- Total approved booking hours per space per semester → needs `actual_start_time`,
  `actual_end_time` (or `start_time`/`end_time`), `status = 'Approved'`, and a semester
  date range.
- Approved bookings by weekday and hour per semester → needs timestamp with
  extractable weekday/hour components.
- Available spaces by capacity and facility list within a time period → needs `Space`,
  `Facility`/`SpaceFacility`, and the absence of out-of-service maintenance or approved
  booking conflicts in the window.
- Approved bookings affected by escalation → needs `MaintenanceRecord.impact_level`,
  `space_id`, and time-range overlap between booking and maintenance period.

Also note that the requirement asks for indexing on: booking conflict check, room finder,
and one additional reporting query — the analysis should identify which attributes are the
candidates for indexing (e.g. `space_id`, `status`, `start_time`, `end_time` on `Booking`).

### 7. Traceability to Phase 1 (weight: medium)
For each identified change, the analysis should reference the specific Phase 1 task output
it modifies (e.g. "this changes the `MaintenanceRecord` entity defined in task 01 and
expanded in task 03"). A grader should be able to open task 09 directly from this
document and know exactly which parts of the Phase 1 ERD and schema need updating.

### 8. Scope discipline (weight: low)
This is an analysis document, not a design document. Flag (minor severity) if the output:
- Proposes specific column names, SQL DDL, or trigger code (belongs in tasks 09–12).
- Redesigns entities beyond what the requirement explicitly changes.
- Omits analysis in favour of jumping straight to solutions.

## Scoring guidance
- Maintenance impact level change and concurrency conflict identification (criteria 1 & 4)
  ~40% combined — these are the two headline changes in Phase 2 and the most
  likely to be under-analysed.
- Affected entities/attributes and business rules (criteria 2 & 5) ~35% combined.
- Relationships, reporting needs, and traceability (criteria 3, 6, 7) ~20% combined.
- Scope discipline (8) ~5%.

## Common failure patterns to watch for
- Describing impact levels without noting the escalation/downgrade sub-rule — escalation
  is the most operationally complex change and drives the most downstream work.
- Identifying the acknowledgement requirement but not recognizing it as a new structural
  entity/junction (it's easy to treat it as just a boolean flag on `Booking`, which loses the
  ability to record *which* advisories were acknowledged).
- Concurrency analysis limited to one booking path (instant or staff) — both must be
  covered since the conflict can arise in either.
- Proposing "use a transaction" as the concurrency solution without specifying isolation
  level or lock strategy — too vague to implement in task 12.
- Listing the four reporting queries without noting what schema support each requires —
  this is the most common way groups miss that the room-finder query is the most
  structurally demanding (it needs facility matching, time-range exclusion, and
  maintenance-level filtering all in one query).