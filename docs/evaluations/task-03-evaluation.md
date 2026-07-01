# Evaluation: Task 3 — Logical Design

## Overall score: 4.7 / 5

| Criterion | Score | Notes |
|---|---|---|
| 1. Entity-to-relation mapping | 5 | All 9 conceptual entities mapped to relations with all attributes preserved. Nothing dropped or silently merged. |
| 2. Relationship-to-relation mapping | 5 | All 13 relationship lines correctly translated. 1:N → FK on many side. N:N (Space↔Facility) → junction table. 1:0..1 (Booking↔UsageSession) → UNIQUE FK. The critical multiple-role pattern (User↔Booking, User↔MaintenanceRecord) uses separate, distinctly-named FK columns: `requester_id`, `decided_by`, `checked_in_by`, `completed_by`, `reporter_id`, `assigned_staff_id` — no ambiguous single `user_id`. |
| 3. Primary keys | 5 | Every relation has a declared PK. Surrogate IDENTITY keys for strong entities, composite (space_id, facility_id) for the junction table. |
| 4. Foreign keys | 4 | All FKs correctly placed, named, and typed. Nullability matches lifecycle semantics. Minor: `assigned_staff_id` on `maintenance_records` is NULL, deviating from ERD narrative ("each record has exactly one assigned staff member"); deviation is defensible (no assignee at report time) but not explicitly justified in the document. |
| 5. Candidate keys | 4 | `email` (user_accounts), `space_code` (spaces), `facility_name` (facilities) listed as unique constraints. Adequately covered but not explicitly labeled as candidate keys per rubric expectation. |
| 6. Normalization | 5 | All relations in at least 3NF. No repeating groups, partial dependencies, or transitive dependencies. No undocumented denormalization. |
| 7. Domain / status attributes | 5 | Every status/type attribute has an enumerated CHECK-restricted value set, fully documented. Domains are complete and consistent with the business requirements (e.g., Booking status includes all lifecycle states: Pending, Approved, Rejected, Cancelled, CheckedIn, Completed, NoShow). |
| 8. Coverage of business rules | 5 | Schema supports all 8 business rules from task 1. The no-overlap rule and unavailable-space rule both have documented enforcement strategies (trigger/application logic). All necessary columns for enforcement live on the correct tables. |

## Strengths

- Excellent handling of the multiple-role UserAccount pattern — the single most common failure point in this task is handled correctly with 6 distinct FK columns.
- Relationship-to-FK mapping table (Section 4) traces each Crow's Foot line to its physical column, making the translation fully auditable.
- Business rule enforcement section (Section 7) acknowledges CHECK limitations and proposes concrete trigger/app-layer strategies for the two critical rules that cannot be enforced declaratively.
- Index recommendations are well-reasoned and cover FKs plus filter paths (status, time-range overlap).

## Issues found

- [minor] `maintenance_records.assigned_staff_id` is nullable, but the ERD narrative (Step 2, §2) states "each record has exactly one assigned staff member" — deviating without explicit justification (deviation is defensible, just undocumented).
- [minor] Candidate keys (`email`, `space_code`, `facility_name`) are listed as UNIQUE constraints rather than explicitly named as candidate keys in a dedicated section, making it slightly harder to assess.

## Inherited issues from earlier tasks

None. The ERD (Task 2) was clean and all 9 entities with their relationships trace correctly into this logical design.

## Suggested fixes

1. Add a short note in Section 3.9 (or a footnote) justifying nullable `assigned_staff_id` — e.g., "Assigned staff may be null when a maintenance issue is first reported before assignment."
2. Add a "Candidate Keys" subsection in Section 5 alongside Primary Keys, explicitly listing `email`, `space_code`, and `facility_name`.
