# Rubric: 09-updated-erd-and-logical-design-G<Group#>.md

Phase 2 — specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions).

## Source of truth
Grade against three inputs simultaneously:
- `08-requirement-change-analysis-G<Group#>.md` — the identified changes this task must
  implement into the design.
- Phase 1 task 02 ERD and task 03 logical schema — the baseline being updated; changes
  should be surgical, not a full redraw.
- Phase 2 requirement (CS486_Project_Phase02.pdf, sections 1.1–1.3) — ground truth for
  any gap between task 08's analysis and the actual requirement.

This task produces two artifacts in one document: an **updated ERD** and an **updated
relational schema**. Grade both separately — a correct ERD with a mismatched schema
(or vice versa) is still a partial failure.

## Part A: Updated ERD

### A1. Minimal and surgical change (weight: medium)
The ERD update should touch only what Phase 2 requires. Flag if:
- Entire Phase 1 ERD is redrawn from scratch without showing what changed (diff
  visibility matters — a grader should be able to see old vs. new at a glance, e.g. via
  annotations, a changelog section, or highlighted additions).
- Phase 1 entities are silently renamed or restructured beyond what the requirement asks.

### A2. impact_level on MaintenanceRecord (weight: high)
`MaintenanceRecord` must show a new `impact_level` attribute with domain
{out-of-service, advisory}. Check:
- Attribute is present and labeled (domain notation or legend entry acceptable at
  conceptual level — exact CHECK syntax belongs in task 10).
- If the group models impact level change history as a separate entity
  (e.g. `MaintenanceLevelHistory`) rather than a mutable column, that is acceptable and
  should be noted as a stronger design choice — flag only if no rationale is given.

### A3. Advisory acknowledgement entity (weight: high)
The acknowledgement requirement ("record that the requester was informed") must appear
as a structural addition to the ERD, not just a note. Accept either:
- A new **junction entity** `BookingAdvisory` (or equivalent name) linking `Booking` to
  `MaintenanceRecord` with an `acknowledged_at` timestamp — this is the preferred
  pattern since it records exactly which advisories were active and acknowledged per
  booking, supporting the "notify of all active advisories" requirement.
- An acknowledgement attribute directly on `Booking` — acceptable only if the group
  explicitly acknowledges this cannot record per-advisory detail and justifies the
  simplification; flag as a design limitation.

Verify cardinality on the junction if used:
- One `Booking` may acknowledge zero or many `MaintenanceRecord` advisories (0..N).
- One `MaintenanceRecord` advisory may be acknowledged by zero or many `Booking`
  rows (0..N).
- The junction itself is mandatory on both sides once a row exists (a junction row without
  a booking or without a maintenance record is meaningless).

### A4. Instant-booking path (weight: medium)
Section 1.2 introduces auto-approval at submission for selected space types. The ERD
should reflect this — either:
- A new `booking_type` or `approval_mode` attribute on `Booking` distinguishing
  instant vs. staff-approval paths, or
- A note/annotation on the `Booking` entity that the status transition
  `pending → approved` can be immediate for certain space types.

Flag if the concept is entirely absent, since task 11 (concurrency design) will need to
reference it and task 12 will need to implement locking around it.

### A5. Escalation support (weight: medium)
The ERD does not need a new entity for escalation (it is an update to an existing record),
but must show that `MaintenanceRecord` supports the escalation workflow. Accept:
- A `level_changed_at` or `updated_at` timestamp attribute on `MaintenanceRecord`
  (minimal, but sufficient for querying when the level changed).
- A separate `MaintenanceLevelHistory` entity if the group wants a full audit trail.

What must not happen: the ERD shows `impact_level` as a static immutable attribute with
no indication that it can change — flag this as a major gap since the escalation query
(reporting requirement 4) depends on being able to find bookings approved *before* an
escalation occurred.

### A6. No unintended Phase 1 breakage (weight: high)
Verify that Phase 1 entities, relationships, and cardinalities that are not in scope for
Phase 2 remain unchanged. Common accidental breakage:
- Removing or renaming the Phase 1 `status` attribute on `Booking` while adding new
  fields.
- Collapsing the Phase 1 `reporter_id` / `assigned_to` distinction on `MaintenanceRecord`
  during the rewrite.
- Changing cardinalities on Phase 1 relationships that are not touched by Phase 2.

---

## Part B: Updated Relational Schema

### B1. impact_level column on maintenance relation (weight: high)
The maintenance table must add `impact_level` as a NOT NULL column with a constrained
domain ({out-of-service, advisory}). Verify:
- Column present with correct nullability (NOT NULL — every maintenance record must
  have a level; no default to advisory without explicit justification).
- Domain noted (CHECK constraint syntax deferred to task 10, but the value set must be
  stated here).

### B2. BookingAdvisory junction table (weight: high)
If the ERD uses a junction entity (recommended), the schema must show the corresponding
relation:

`BookingAdvisory(booking_id FK→Booking, maintenance_id FK→MaintenanceRecord,
acknowledged_at TIMESTAMP NOT NULL)`

Check:
- Composite PK on (booking_id, maintenance_id) — a booking acknowledges each
  advisory at most once.
- Both FKs present, referencing correct tables.
- `acknowledged_at` is NOT NULL (the record exists only when acknowledgement was
  given; its timestamp is mandatory).
- If the group chose a simpler attribute on `Booking` instead, check it is noted as a
  limitation and that the column is sufficient for the queries in section 1.3.

### B3. Booking relation additions (weight: medium)
Depending on the group's ERD choice for instant-booking path and acknowledgement:
- If `booking_type` / `approval_mode` was added to the ERD, a corresponding column
  must appear in the schema with a domain noted.
- No other changes to `Booking` should be present beyond what the ERD specified —
  flag unannounced column additions.

### B4. Escalation queryability (weight: medium)
The schema must support the Phase 2 reporting query: "approved bookings affected when
a maintenance record is escalated to out-of-service." This requires:
- `MaintenanceRecord` has `space_id`, `start_time`, `end_time`, and `impact_level` on
  the same relation — verify all four are present (they should be from Phase 1, but
  confirm `impact_level` joined them correctly).
- `Booking` has `space_id`, `start_time`, `end_time`, and `status` — same check.
- The schema as written would allow a JOIN on `space_id` with a time-range overlap
  filter and a status = 'Approved' filter — trace this manually and flag if any required
  column is missing or on the wrong table.

### B5. Concurrency support (weight: medium)
Section 1.2 requires concurrency control. The schema should reflect the chosen mechanism
from task 08's analysis:
- If optimistic locking: a `version` or `row_version` column on `Booking` must appear
  in the schema here (it will be used in task 12's implementation).
- If pessimistic locking (lock hints at query time): no schema change needed, but the
  schema note should state that the booking conflict check will use `WITH (UPDLOCK,
  HOLDLOCK)` or equivalent, so task 12 knows where to apply it.
- If serializable isolation: no schema change needed, but note it here.

Flag if concurrency control is entirely absent from both the schema and any accompanying
note — it means task 11 and 12 will have no design anchor to implement against.

### B6. Normalization check for new additions (weight: high)
New relations and columns must satisfy 3NF:
- `BookingAdvisory` — verify no transitive dependency: the only non-key attribute is
  `acknowledged_at`, which depends on the full composite key (booking + advisory
  record), not on either FK alone. Correct.
- `impact_level` on `MaintenanceRecord` — depends on the maintenance record's PK
  only. Correct.
- If `MaintenanceLevelHistory` is added: verify its FD structure (PK → space, old level,
  new level, changed_at, changed_by).
- Flag any denormalization introduced without justification (e.g. copying
  `impact_level` onto `Booking` as a snapshot — acceptable if justified as a performance
  denormalization for the escalation query, but must be noted).

### B7. Candidate keys and FK nullability (weight: low)
- `BookingAdvisory` has no natural surrogate key needed; composite (booking_id,
  maintenance_id) is the PK.
- `acknowledged_at` NOT NULL (as per B2).
- Any new FKs introduced are nullable only where the ERD's participation constraints
  allow it.

---

## Scoring guidance
- A2, A3, B1, B2, B6 (impact level, acknowledgement, normalization) ~50% combined —
  these are the structural heart of Phase 2's design change.
- A4, A5, B4, B5 (instant-booking path, escalation, query support, concurrency anchor)
  ~30% combined.
- A1, A6, B3, B7 (change discipline, no breakage, minor columns, keys) ~20% combined.

## Common failure patterns to watch for
- Acknowledgement modeled as a boolean `advisory_acknowledged BOOLEAN` on
  `Booking` — loses per-advisory detail; flag as major if task 08 correctly identified the
  junction requirement.
- `impact_level` added to schema but left nullable — every maintenance record must have
  a level; NULL here means unknown impact, which is operationally dangerous.
- No change to the ERD at all for instant-booking path, leaving task 11/12 with no
  design reference for where to apply locking.
- Escalation queryability broken because `start_time`/`end_time` on `MaintenanceRecord`
  was accidentally removed or renamed during the Phase 2 rewrite.
- Phase 1 `reporter_id` / `assigned_to` FK distinction silently collapsed back into a
  single `user_id` during the ERD update — a regression from the Phase 1 fix.
- Normalization check performed only on new additions without re-verifying that the
  additions don't create transitive dependencies with existing Phase 1 columns.