# Evaluation Report: Task 6 — Sample Data

**Evaluator:** OpenCode AI (automated grading)
**Date:** 2026-07-01
**Target:** `outputs/06-sample-data-G08.sql`
**Schema reference:** `outputs/05-db-definition-G08.sql`

## Overall score: 4.8 / 5

| Criterion | Score | Notes |
|---|---|---|
| 1. Referential integrity | 5 | All FK references valid; insertion order respects dependency chain. No orphaned references. |
| 2. Coverage of all tables | 5 | All 9 tables from DDL populated (departments=5, users=8, spaces=8, facilities=6, space_facilities=24, bookings=13, booking_decisions=5, usage_sessions=4, maintenance_records=5). |
| 3. Coverage of all roles | 5 | All 6 roles present: Student (×2), Lecturer (×2), TeachingAssistant, FacilityStaff, FacilityManager, DepartmentAdministrator. |
| 4. Coverage of all status values | 4 | Booking: all 7 statuses covered. Space: Available, UnderMaintenance, TemporarilyClosed present; InUse and Retired missing. Maintenance: Reported, InProgress, Completed present; Assigned and Cancelled missing. |
| 5. Business rule compliance | 5 | No overlapping approved bookings on same space. No bookings against unavailable spaces. Rejected booking has rejection reason. CheckedIn/Completed bookings have session data; Pending/Rejected/Cancelled do not. Trigger constraints respected. |
| 6. Exceptional / edge cases | 4 | No-show (booking #7), rejected (#5), cancelled (#6), double-booking attempt (#12 vs #13 with inline comment) all present. Missing: demonstration of maintenance blocking a pre-existing approved booking (maintenance is on a space with zero bookings). |
| 7. Realism / narrative coherence | 5 | Vietnamese names, realistic emails, plausible room codes and building names, detailed purposes, sensible time ranges. Maintenance problems are realistic. |
| 8. Volume | 5 | Adequate row counts for meaningful aggregate queries. 13 bookings with varied statuses, 5 maintenance records, 24 space-facility assignments. |

### Strengths

- Excellent referential integrity — every FK chain is valid and insertion order is correct.
- All 7 booking status values appear at least once, including edge cases (NoShow, Cancelled, Rejected).
- The double-booking scenario (#12 vs #13) is clearly documented with inline comments explaining why #13 cannot become Approved.
- Highly realistic data with Vietnamese names, detailed purposes, and plausible campus scenarios.
- Good narrative flow: lecture sessions, cultural events, maintenance issues, renovation contexts all present.
- CheckedIn booking (#8) correctly has NULL completion fields in usage_sessions, demonstrating understanding of lifecycle.

### Issues found

- **[minor]** Space status `InUse` and `Retired` not represented in sample data; though `InUse` may be considered implicit via active bookings, no space is marked `Retired`.
- **[minor]** Maintenance statuses `Assigned` and `Cancelled` not represented; only `Reported`, `InProgress`, and `Completed` are used.
- **[minor]** NoShow booking (#7) lacks a corresponding `booking_decisions` record — logically a booking should be Approved before it can become NoShow, but no approval decision exists for it.
- **[minor]** No explicit demonstration of maintenance blocking an existing pre-approved booking (the rubric notes this as optional but a sign of thoroughness).

### Inherited issues from earlier tasks

None identified. The sample data faithfully implements the DDL from Task 5.

### Suggested fixes

1. Add a `booking_decisions` row for booking #7 (NoShow) showing it was approved before the no-show occurred.
2. Add one maintenance record with `Assigned` status, and optionally one with `Cancelled` status, to exercise those paths.
3. Consider adding a space with `Retired` status (e.g., an old classroom) and zero bookings against it, to complete space-status coverage.
4. (Optional) Add a scenario where a space's maintenance window causes an existing booking to be rejected or redirected, to demonstrate the "maintenance blocks booking" rule more explicitly.
