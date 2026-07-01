## Task 4: design-validation
Overall score: 4.6 / 5

| Criterion | Score | Notes |
|---|---|---|
| 1. ERD-to-schema traceability check | 5 | Systematic table mapping all 9 entities (9/9) and all 13 relationship lines to FK columns. Complete walkthrough, not just general impressions. |
| 2. Key correctness check | 4 | Confirms all PKs, all FKs mapped, candidate keys identified (UNIQUE on email/space_code/facility_name). User-role disambiguation adequately covered in FK mapping and Issue 6. One minor error: claims "14 Crow's Foot relationship lines" and "14/14" but the ERD contains 13 lines. |
| 3. Normalization check | 5 | Independently re-verifies 1NF, 2NF, 3NF with table-by-table reasoning. Shows work per relation rather than merely asserting compliance. |
| 4. Business rule coverage check | 5 | All 20 rules mapped to specific enforcement mechanisms (CHECK, FK, UNIQUE, trigger, application layer) with table/column locations. Honest about gaps (Rules 7, 10, 11, 16, 17). |
| 5. Issues found vs. issues that exist | 4 | Validation identified 6 real issues (rejection reason mandatory, completion field pairing, overlap detection, lifecycle transitions, capacity open question, role ambiguity). Independent check confirms these are genuine. However, one discrepancy missed: the ERD implies `assigned_staff_id` should be NOT NULL ("Each record has exactly one assigned staff member" per ERD narrative), but the logical schema makes it NULL — not flagged. Minor counting error (14 vs 13 relationships). |
| 6. Proposed fixes / revisions | 5 | Every issue has a concrete resolution or documented tradeoff. Issue 4 transparently explains the known limitation on state transitions. |
| 7. Documentation quality | 5 | Clear structure with 7 labelled sections, readable tables, well-organized. Standalone readability for someone unfamiliar with prior outputs. |

Strengths:
- Comprehensive business rule coverage table with precise enforcement mappings — this is the core value of a design validation and it is done well.
- Independent normalization walkthrough with per-relation analysis, not a blanket assertion.
- Honest documentation of issues (6 issues found, including a documented open question on capacity) rather than rubber-stamping.
- Proposed fixes are concrete and actionable, with accepted/rejected alternatives explained.

Issues found:
- [minor] Counting error: validation claims "14 Crow's Foot relationship lines" and "14/14" relationship-to-FK completeness, but the ERD (Output 02) contains exactly 13 relationship lines. The FK mapping table itself lists 13 entries. The number should be 13.
- [minor] `assigned_staff_id` NULL vs. NOT NULL discrepancy not flagged: The ERD narrative (Output 02, line 152) states "Each record has exactly one assigned staff member," which implies a mandatory FK (`NOT NULL`), but the logical schema (Output 03, line 251) makes `assigned_staff_id` `NULL`. This practical relaxation (a record can be reported before assignment) was not noted as a deviation from the conceptual model.
- [minor] Overlap trigger edge case not discussed: The `AFTER INSERT, UPDATE` trigger in Output 05 only checks `inserted` rows against existing rows in `bookings`. If a multi-row INSERT creates two Approved bookings for the same space with overlapping times in a single statement, neither row would exist in the table yet, so the overlap check would not catch them. Practical impact is near-zero for single-row application patterns but should be documented.

Inherited issues from earlier tasks (if any):
- The 14 vs. 13 relationship count error may originate from misreading the ERD in Output 02 (which correctly has 13 lines) — the validation inflates it. Not an inherited error, a new counting mistake in this document.
- The `assigned_staff_id` NULL discrepancy traces back to Output 03's logical design, where the column was made NULLable without documenting the rationale. The validation should have caught this.

Suggested fixes:
1. Correct "14" to "13" in the relationship/FK counts throughout Section 1.
2. Add an Issue 7 (or a note in Issue 6) documenting the `assigned_staff_id` NULL vs. NOT NULL discrepancy, explaining the practical rationale (a maintenance record can be reported before a staff member is assigned) and whether the ERD should be updated to reflect that `assigned_staff_id` is optional.
3. Add a brief note in Section 4 or Issue 3 acknowledging the multi-row edge case for the overlap trigger and confirming it is acceptable for the intended single-row application pattern.
