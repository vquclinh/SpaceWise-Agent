# Rubric: 03-logical-design-G<Group#>.md

Specific to this task only. Use together with the common evaluation skill at
`.opencode/skills/evaluation/SKILL_COMMON_EVAL.md` (scoring scale, report format, general dimensions)
— do not repeat those here.

## Source of truth
Grade against `02-erd-design-G<Group#>.md` as the primary source — this task's job is a
mechanical-but-careful translation of the ERD into relations. Cross-check against task 1
and the PDF only when the ERD itself is ambiguous or silent on something. If the logical
design deviates from the ERD without explanation, that's an internal-consistency issue,
not necessarily a wrong design — note both: does it deviate, and is the deviation itself
defensible.

## Criteria

### 1. Entity-to-relation mapping (weight: high)
Every strong entity from the ERD becomes a relation with all its attributes. Weak entities
(e.g. Facility, if modeled weak) carry the owning entity's key as part of their own key.
Check nothing was dropped or silently merged during translation.

### 2. Relationship-to-relation mapping (weight: high)
- 1:N relationships: foreign key placed on the "many" side, not the "one" side
  (e.g. `space_id` FK on Booking, not the reverse).
- N:N relationships (if any emerged from the ERD): resolved into a junction/associative
  table with both FKs forming the table's key (or its own surrogate key if it needs
  additional attributes).
- 1:1 relationships, if any: FK placement justified (which side is optional vs. mandatory).
- Multiple distinct relationships between the same two entities (this is the case for
  User↔Booking: submitter, decision-maker, check-in staff, completer) must each produce
  a **separate, distinctly named** foreign key column on Booking — e.g. `requester_id`,
  `decided_by`, `checked_in_by`, `completed_by` — not one ambiguous `user_id`. Same for
  User↔Maintenance Record: `reporter_id` and `assigned_to` must be separate columns.
  This is the single most common place groups lose information in translation — check it
  carefully against the ERD's relationship list.

### 3. Primary keys (weight: high)
- Every relation has a primary key declared.
- Surrogate keys (e.g. auto-increment ID) vs. natural keys (e.g. space_code) — either is
  fine, but check consistency: if the ERD specified a natural identifying attribute (like
  space code or user ID format), the logical design shouldn't silently replace it with an
  unrelated surrogate without note, since downstream sample data and queries will need
  to know which is authoritative.
- Composite keys correctly identified for weak entities / junction tables.

### 4. Foreign keys (weight: high)
- Every relationship from the ERD produces the correct FK(s) in the correct relation(s),
  matching the data type of the referenced primary key.
- FK columns are named clearly enough to disambiguate multiple FKs to the same table
  (see criterion 2's User↔Booking example).
- Nullability of each FK matches the ERD's participation constraints (e.g. `decided_by`
  should be nullable since pending bookings have no decision yet; `requester_id` should
  be NOT NULL).

### 5. Candidate keys (weight: medium)
Beyond the chosen primary key, are other unique-identifying attribute sets noted as
candidate keys where they exist? E.g. Space's `space_code` if the PK is a surrogate ID;
User's `email`. Should be explicitly listed, not just implied.

### 6. Normalization (weight: high)
- Relations should be in at least 3NF (or BCNF if achievable without losing functional
  dependencies) — check for:
  - Repeating groups (e.g. storing multiple facilities as a comma-separated list inside
    Space instead of a separate Facility relation) → violates 1NF, major deduction.
  - Partial dependencies on a composite key (2NF violations) — relevant if any
    junction/weak-entity tables exist.
  - Transitive dependencies (3NF violations) — e.g. storing a user's department name
    redundantly on Booking when it's derivable via the requester's User record.
- If the group intentionally denormalizes anything (e.g. storing a snapshot of space
  capacity on Booking at time of request), that's acceptable **only if explicitly justified**
  — flag undocumented denormalization as an issue, not a feature.

### 7. Domain / status attributes (weight: medium)
For attributes with a fixed value set (Booking status, Space status, Maintenance status,
User role), check the logical design notes the domain (even if full CHECK constraint
syntax is deferred to task 5). At minimum the candidate value list should be written down
here so task 5 has something concrete to implement against.

### 8. Coverage of business rules from task 1 (weight: medium)
Rules that depend on relational structure (not just a single CHECK constraint) should be
visibly supported by the schema as designed — e.g. the no-overlapping-bookings rule
requires `space_id`, `start_time`, `end_time`, and `status` all to live on the same
Booking relation so a trigger/constraint in task 5 can actually reference them together.
Flag if the schema as drawn would make a known business rule awkward or impossible to
enforce later.

## Scoring guidance for this task
- Weight relationship-to-relation mapping and foreign keys (criteria 2 & 4) as the
  load-bearing section, ~35% combined — this is where the User-role ambiguity problem
  either gets fixed or propagates forward into broken SQL.
- Primary/candidate keys (3 & 5) ~20% combined.
- Normalization (6) ~20%.
- Entity mapping (1), domain attributes (7), and business-rule coverage (8) ~25% combined.

## Common failure patterns to watch for
- Single `user_id` FK on Booking trying to serve as both requester and approver — check
  this explicitly, since it's the most likely inherited or newly-introduced error at this
  stage.
- Facility stored as a free-text or array column on Space instead of its own relation —
  works for the ERD's weak-entity intent only if Facility was deliberately modeled as a
  simple attribute, but if the ERD showed it as an entity, collapsing it here is a mapping
  error.
- Missing the separate `reporter_id` / `assigned_to` distinction on Maintenance Record.
- No candidate key noted for Space (`space_code`) or User (`email`) even though both are
  clearly unique identifiers per the requirement text.
- Declaring all FKs as NOT NULL by default, including ones that should be nullable until a
  later lifecycle stage (decided_by, checked_in_by, completed_by, maintenance
  completion_time).