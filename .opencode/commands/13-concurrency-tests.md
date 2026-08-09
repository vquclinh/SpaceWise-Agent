---
description: Generate ONLY Task 13 (Concurrency Tests) for Phase 2.
---

# /13-generate-concurrency-tests

This command executes only the Concurrency Tests phase (Task 13) of the Phase 2 database pipeline.

## Instructions for the Agent

1. **Use the Task-Specific Skill:** You MUST use the skill defined for Task 13 (e.g., `.opencode/skills/db-design-pipeline/13-concurrency-tests/SKILL.md`).
2. **Read Inputs:**
   - `outputs/11-concurrency-design-G08.md` — specifically Section II (Identified Race Conditions) and Section V (Traceability and Assurance).
   - `outputs/12-concurrency-implementation-G08.sql` — to understand the exact stored procedures being tested (`usp_ApproveBooking`, `usp_CreateBookingAutoApproved`, `usp_EscalateMaintenance`, `usp_CompleteBooking`).
   - `req/business-requirement-P2.md`
   - `CS486_Project_Phase02.pdf`
   - `AGENTS.md` — repository-level rules.
3. **Generate Output:** Create the directory `outputs/13-concurrency-tests-G08/` and populate it EXACTLY with the following files:
   - `00-setup-test-data.sql`
   - `01-race-A-double-approval.sql`
   - `02-race-B-instant-vs-manual.sql`
   - `03-race-C-approval-vs-escalation.sql`
   - `04-early-checkout-verification.sql`
4. **Self-Review:** After writing, review the output against:
   - The dual-window (Session A / Session B) testing methodology required for SSMS.
   - The inclusion of `WAITFOR DELAY` commands to reliably force transaction collisions.
   - If the self-review reveals a systemic weakness in the task skill, record it in the audit as **"Recommended skill improvement"**. Do NOT silently edit the skill file during a normal generation run unless the user explicitly asked for a skill-editing task.
5. **Safety Constraint:** Do NOT generate, modify, or overwrite deliverables 08, 09, 10, 11, 12, 14, 15, or 16. Do not edit `AGENTS.md` or `.opencode/skills/db-design-pipeline/SKILL.md`.
6. **Audit Policy:** After generation or refinement, you MUST follow the repository audit policy (`AGENTS.md` section 7). Create a new audit log in `docs/audits/` using the `docs/audits/AUDIT_TEMPLATE.md` format. Record the Phase 2 step (Task 13) and the output directory evaluated.