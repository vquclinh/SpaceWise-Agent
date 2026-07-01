# Rubric: 02-erd-design-G<Group#>.md

Specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions)
— do not repeat those here.

## Source of truth
Grade against two things together: the original requirement (CS486_Project.pdf, section 1)
and `01-business-req-analysis-G<Group#>.md`. The ERD should be a faithful, more formal
restatement of task 1's entities/relationships/rules — not a fresh reinterpretation of the
PDF. If the ERD introduces an entity or relationship absent from task 1, check whether it's
genuinely implied by the source (acceptable, but should be flagged as an addition) or just
inconsistent (penalize under internal consistency).

## Criteria

### 1. Entity set completeness (weight: high)
Expected entities (names may vary):
- User (with role distinguishing student/lecturer/TA/staff/admin/manager — either as an
  attribute or, if justified, as a subtype/specialization)
- Space
- Facility (equipment in a space)
- Booking
- Maintenance Record
- Optionally: Decision/Approval as its own entity if the group chose not to fold it into
  Booking — acceptable either way, but must be consistent with task 1's choice unless a
  rationale for changing it is given.

Deduct for missing entities. Flag (don't necessarily deduct) for extra entities not in task 1.

### 2. Attributes per entity (weight: high)
This is a conceptual ERD — attributes are listed by name only, no data types, no PK/FK
markers. Grade accordingly:
- All attributes named in task 1 and the PDF must be present on the correct entity.
  Do not deduct for absence of data types or PK/FK notation — those belong in task 3.
- Primary identifying attribute should be visually distinguished (underlined in Crow's Foot
  convention) — flag if nothing is marked as the identifying attribute, but do not require
  a formal "PRIMARY KEY" declaration.
- Composite/derived attributes, if introduced, should be noted as such (e.g. a derived
  age or calculated duration) — flag if silently added without indication.
- Status-type attributes (Space status, Booking status, Maintenance status, User role):
  the attribute name must appear on the entity. **Domain value lists are not required at
  this stage** — they belong in the logical design (task 3). However, if the group does
  annotate domain values in a legend or note alongside the diagram, reward this as good
  practice (bonus observation, not a penalizable omission if absent).
- Booking carries both *requested* fields (start/end time, purpose, participants) and
  *actual* fields (actual start/end time, check-in person, conditions, usage notes) — these
  are easy to conflate or drop entirely; check both groups of attributes are present on the
  Booking entity.

### 3. Relationships (weight: high)
Must show, at minimum:
- User —submits— Booking
- Booking —for— Space
- Space —has— Facility (either direct 1:N, or via a SpaceFacility associative entity if
  Facility is designed as a type catalog — see criterion 5 for acceptable Facility patterns)
- User (staff role) —decides— Booking (approve/reject)
- User (staff role) —checks in/completes— Booking (may be same or different
  relationship from decision — check it's not silently merged with "submits")
- Space —has— Maintenance Record
- User —reports— Maintenance Record
- User (staff role) —assigned to— Maintenance Record

Pay particular attention to the User entity: it plays multiple roles relative to Booking and
Maintenance Record (requester, decision-maker, check-in staff, reporter, assignee). Check
whether the ERD distinguishes these with separate, clearly labeled relationship lines (good
practice) or collapses them ambiguously (flag as major issue — this is a common student
mistake that breaks the logical design downstream).

### 4. Cardinalities & participation constraints (weight: high)
Verify each relationship has min/max cardinality (or crow's foot equivalent) matching the
source:
- User to Booking (submits): 1:N, User side optional (0 or 1..), Booking side mandatory
  (exactly one submitter).
- Booking to Space: N:1, mandatory both sides (a booking always names exactly one
  space; a space can have zero or many bookings).
- Space to Facility: depends on chosen pattern (see criterion 5):
  - Weak-entity pattern: Space —has— Facility, 1:N, Space side optional (a space may
    have zero facilities).
  - Type-catalog pattern: Space —has— SpaceFacility, Facility —stocked in— SpaceFacility,
    both 1:N; SpaceFacility carries a `quantity` attribute; Space and Facility sides are
    both optional (a facility type may not be in any space yet; a space may have no
    facilities yet). Check cardinalities on both legs of the association are present.
- Space to Maintenance Record: 1:N.
- User to Maintenance Record (reporter / assignee): two separate 1:N relationships.
- Decision/check-in staff relationships: should be optional (0..1) since not all bookings
  reach those states yet (e.g. pending bookings have no decision).

Flag any relationship missing cardinality notation entirely, and any cardinality that
contradicts task 1 without explanation.

### 5. Facility modeling pattern (weight: medium)
Three valid patterns exist — do not penalize any of them as long as it is internally
consistent and carried forward correctly into task 3:

**Pattern A — Weak entity** (simple, adequate):
Facility is a weak entity dependent on Space, identified by facility type within that space.
Space —has— Facility with a double-diamond or dashed identifying relationship in Crow's
Foot. Acceptable but limited: doesn't allow the same facility type (e.g. projector) to be
referenced across spaces without duplication, and can't easily store quantity per space.

**Pattern B — Strong entity type catalog + SpaceFacility associative entity** (preferred):
Facility is a strong entity representing a *type* of equipment (projector, whiteboard, AC,
etc.) with its own identity. A SpaceFacility associative entity (or relationship with
attributes) links Space to Facility and carries a `quantity` attribute (how many of that
type are in that space). This is the richer, more extensible design — it avoids duplicating
facility-type data across spaces and makes queries like "how many projectors does each
space have" or "which spaces have a microphone" natural. **Reward this pattern as a
stronger design choice.** Verify SpaceFacility is shown as an associative entity with its
own attributes (at minimum: quantity) in the ERD.

**Pattern C — Simple attribute list** (minimal, acceptable only if justified):
Facility stored as a multi-valued or text attribute directly on Space. Only acceptable if
the group explicitly notes this is a simplification and that they are aware it limits
queryability. Flag as a design choice to revisit in task 3 if present without comment.

For any pattern chosen: check that it is consistent with what task 1 described, and that
criterion 3's relationship list is adjusted accordingly (Pattern B needs two relationship
lines; Pattern A needs one).

### 6. Business rules represented or noted (weight: high)
Rules that are structural (cardinality/constraint-expressible) should appear directly in the
ERD's constraints; rules that are not directly expressible in a basic ER diagram (e.g. "no
two approved bookings on the same space may overlap in time") should be explicitly
called out as a business rule annotation/note, since they will become CHECK constraints,
triggers, or application logic in later tasks. Deduct if such non-structural rules are simply
absent with no annotation — losing them here means losing them in implementation.

### 7. Diagram clarity & notation consistency (weight: medium)
- One consistent notation used throughout (Chen, Crow's Foot, UML, etc.) — flag if mixed.
- Legend/key present if non-standard symbols are used.
- Diagram is legible as a standalone artifact (a reader shouldn't need task 1 open
  side-by-side to understand it, though task 1 should still agree with it).

## Scoring guidance for this task
- Weight relationships + cardinalities (criteria 3 & 4) as the load-bearing section, ~40%
  combined — this is where most downstream logical-design errors originate.
- Entities + attributes (1 & 2) ~30% combined.
- Business rules representation (6) ~15%.
- Weak entity justification (5) and diagram clarity (7) ~15% combined.

## Common failure patterns to watch for
- Single generic "decides/handles" relationship between User and Booking that conflates
  submitter, approver, check-in staff, and completer into one undifferentiated link.
- Missing cardinality on the Maintenance Record relationships (reporter vs. assignee are
  easy to merge into one relationship by mistake).
- Treating Booking status values as if they were separate entities or relationships instead
  of a single attribute with a domain — the status is one attribute, not a relationship.
- Dropping the requested-vs-actual time/condition distinction on Booking, collapsing it
  into a single start/end time pair.
- No annotation anywhere for the no-overlap booking rule — it's structural to the business
  but not expressible as a simple ER cardinality, so it's easy to lose entirely at this stage.
- Pattern B (Facility + SpaceFacility) shown in the diagram but SpaceFacility missing its
  `quantity` attribute — without it the pattern loses its main advantage over Pattern A.
- Penalizing the group for not listing data types or domain values — these are explicitly
  out of scope for a conceptual ERD; redirect those checks to task 3.