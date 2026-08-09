# Audit — Task 11 Concurrency Design Generation

> Date: 2026-08-09
> Operator/member: (task owner to confirm — assumed Senior Lead Database Architect & Concurrency Expert per Task 11 role)
> Tool: OpenCode
> Provider/model/variant: opencode/deepseek-v4-flash-free
> OpenCode command used: `/11-generate-concurrency-design`

## Task goal

Execute only the **Concurrency Design (Task 11)** phase of the Phase 2 database pipeline: generate `outputs/11-concurrency-design-G08.md` from the Task 11 skill (`.opencode/skills/db-design-pipeline/11-concurrency-design/SKILL.md`), the concurrency analysis in outputs 08/09, and the Phase 2 requirements — and record the run under the repository audit policy (AGENTS.md §7/§8).

## Files created / changed

- `outputs/11-concurrency-design-G08.md` — **created** (the only output touched; the Task 11 deliverable).
- `docs/audits/62-task11-concurrency-design-generation-audit.md` — this audit.
- **Not modified:** `outputs/08`, `09`, `10`, `12`, `13`, `14`, `15`, `16`; `AGENTS.md`; `.opencode/skills/db-design-pipeline/SKILL.md`; `.opencode/skills/db-design-pipeline/11-concurrency-design/SKILL.md` (read-only, per the command's safety constraint — skill improvements are recorded as recommendations only).

## What was evaluated

- **Inputs read (per command spec):**
  - `outputs/08-requirement-change-analysis-G08.md` §5 (Concurrency & Race Condition Analysis) — full section including §5.1–§5.5.
  - `outputs/09-updated-erd-and-logical-design-G08.md` §9 (Concurrency Control Design), §10 (Indexing Strategy, esp. I1/I3/I4), §11 (Edge-Case Resilience), §7 (R2/R3/R5/R8), and Appendix A (D/L/R/S/T pass records) — read at sufficient depth for consistency.
  - `req/business-requirement-P2.md` — full read (§4 concurrency, §7 workflows, §8/§9 rules and assumptions).
  - `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md` (supplementary reference; §4 overlap logic, §5 triggers, §6 concurrency strategy).
  - `AGENTS.md` (repository rules), the shared `db-design-pipeline/SKILL.md`, and Audit 61 for cross-file consistency conventions.
  - `CS486_Project_Phase02.pdf` — **could not be read directly** (the executing model does not accept PDF input); the Phase 2 requirements were instead cross-checked from `req/business-requirement-P2.md` and the P2 spec, which the repository treats as the condensed/authoritative transcriptions of that PDF (source-of-truth order §2.2/§2.4).

- **Generation:** home of the four required skill sections (I–IV) plus supporting hand-off/traceability/appendix sections, all kept within the "design-level, no DDL/procedure bodies" boundary the skill mandates.

## Issues found

1. **First-draft prose artifacts.** The initial write contained several garbled/placeholder fragments (e.g. "wide-out spread", "schema ex", duplicated section numbers III returning into the old 5.x numbering, a `FROM dbo.bookings_`/`dbo._bookings` typo in the SQL demos, "the A intends", stale cross-references, and a `THROW 50,` example that is not valid T-SQL). All fixed in the subsequent self-review pass.
2. **Skill-level weakness (recorded as a recommendation, not edited):** the Task 11 skill mandates the outline but does not specify an expectations for (a) a hidden "sources/missed" reading of Output 08 §5 and Output 09 §9/§10, and (b) a statement that `TR_bookings_PreventOverlapAndUnavailable` plus the Phase 2 triggers remain as backstops. These were already documented elsewhere but the skill provides no "mandatory components" checklist for the three required SQL snippets. See "Recommended skill improvements" below.

## Changes made

- Created `outputs/11-concurrency-design-G08.md` strictly following the skill's required structure:
  - **I. Introduction and Failure Mode Analysis** — concurrency requirement; check-then-act (TOCTOU) formalisation; trigger demotion to validation backstop with stored procedures responsible for serialization.
  - **II. Identified Race Conditions** — the three mandated races (double approval; instant vs. manual and instant vs. instant; approval vs. maintenance escalation incl. the deadlock risk), each with step-by-step interleavings and the serialized outcome, plus the shared conflict predicate.
  - **III. Proposed Concurrency Control Mechanism** — `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`; `WITH (UPDLOCK, HOLDLOCK)` on the overlap and impact-level checks with actual T-SQL demos; the mandatory lock order `bookings → maintenance_records → booking_alerts`; `TRY...CATCH` with bounded retry on `1205`/`1222` vs. terminal overlap errors; trigger backstop; status-driven interval selection (early check-out release).
  - **IV. Alternative Mechanisms Evaluated** — `sp_getapplock` trade-offs with the verdict (belt-and-braces only, not primary), plus a brief assessment of optimistic/row-version being rejected.
  - Additional hand-off sections (Task 12 implementation contract C1–C7, traceability to requirements, assumptions/open questions, quality checklist) consistent with the Outline and the "no implementation code" boundary.
- Cross-referenced Output 08 §5/§5.5 and Output 09 §9/§10/I1/I3 discipline (key-range locking depends on filtered index I1), and left the "escalation identifies bookings, does not rewrite them" semantics consistent with the escalation lookup requirement (R5) and `'9999-12-31'`'s maintenance-window coalesce pattern.
- Self-review pass over Draft 1 fixed all the issue-1 items (typos, section numbering, invalid `THROW` example, cross-reference currency).

## Improvement classification

- Output refinement
- No agent/skill/command change needed (no skill/command file was edited; improvement recommendation recorded below instead)

## Validation commands run

- `Test-Path`/glob to confirm `outputs/11-concurrency-design-G08.md` did not exist before generation and exists after.
- Grep for heading structure (`^#{1,4}`) — Section III numbering and 5/6/7 stale-number residue fully removed.
- Grep for cross-reference staleness: `Section III.8`, `Section III.7`, `Section III.6` targets vs. actual heading set verified aligned after fixes.
- Grep for `bookings_`/`_bookings` table-name typos, `50xxx` vs. actual error code.
- Count of markdown fences (even count, balanced).
- `git status --short` for the final file-set.

## Validation results

- Heading tree confirmed as: I, II, III (with III.1–III.8), IV, V, VI, Appendix A, quality checklist — numbering consistent end to end.
- All cross-references point to existing sections; no stale `III.7`/`III.6` mapping remains for the early-check-out/backstop rows.
- Table/column/isolation identifiers are inline-code formatted as required (e.g. `bookings`, `maintenance_records`, `booking_alerts`, `SERIALIZABLE`, `READ COMMITTED`, `1205`, `1222`).
- No DDL or stored-procedure bodies present; SQL blocks are the conflict-check/impact-check `SELECT ... WITH (UPDLOCK, HOLDLOCK)` and `SET TRANSACTION ISOLATION LEVEL` statements only, exactly as the skill requires.
- Balanced code fences; no placeholder/lorem/odd artifact strings remaining.

## Risks / caveats

- **PDF not personally parsed.** `CS486_Project_Phase02.pdf` was not readable by the executing model. The concurrency requirements were sourced from the repo's own transcriptions (`req/business-requirement-P2.md`, `CAMPUS_SPACE_MANAGEMENT_PROJECT_SPEC_P2.md`), which AGENTS.md treats as the authoritative condensed versions — but if the PDF's §4 wording differs in any nuance, that PDF must be re-checked against this output in review.
- **Procedure names provisional.** The document names the procedures generically (`usp_ApproveBooking`, `usp_CreateBookingAutoApproved`) matching the existing unpushed references in Output 09 §9; Task 12 may alias/pf the actual DDL names — the contract clauses (C1–C7) are name-agnostic on purpose.
- **Skill improvement not written back** (as the generation command requires): the recommended skill additions are logged here only; a user-requested skill-editing task would be needed to apply them.

## Recommended skill improvements (Task 11 skill)

1. Add a **"Mandatory snippets" check-against** (must demonstrate the conflict-check `SELECT ... WITH (UPDLOCK, HOLDLOCK)`, the `maintenance_records` impact-level `SELECT ... WITH (UPDLOCK, HOLDLOCK)`, and `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`) so the generator cannot pass with prose-only or with a $ token that misses the exact snippets the self-review rubric should check.
2. Add an explicit instruction that **Per-space range indexes (`IX_bookings_space_status_time`) are necessary for granular key-core locking** (i.e. how the overlap check interacts with index I1 from Output 09 §10) — the current skill mentions indexes only obliquely.
3. Add a rule that the escalation/deadlock section must both (a) state that lock ordering *reduces* deadlock frequency rather than eliminating it and (b) carry the retry-on-1205/1222 duty, so "deadlocks remain possible" is never treated as a design gap (aligns with Output 08/09's L7 resolution).

## Recommended next steps

- Team review of the Task 11 deliverable against Output 09 and the launcher spec before Task 12 consumes it (owner: Senior lead per role in audit 61; reviewers per AGENTS.md §7).
- Apply the three "Recommended Skill improvement" items above in a separate skill-editing task so future concurrency generations are safer.
- Start Task 12 (`outputs/12-concurrency-implementation-G08.sql`) against the contract clauses C1–C6; Execution progress should include output-15/16 relevance (index feedback etc.) only where it concerns the concurrency index I1.

## Git status summary

```
?? .opencode/commands/11-concurrency-design.md
?? .opencode/skills/db-design-pipeline/11-concurrency-design/
?? docs/audits/62-task11-concurrency-design-generation-audit.md
?? outputs/11-concurrency-design-G08.md
```

- All four paths shown as `??` are untracked. The command file and the skill folder predate this session (they were present before this run); the skill/command were **read-only** during this generation and were not modified.
- Two new paths were created by this run: the Task 11 output and this audit.
- `outputs/08`–`16` (other than the new Task 11 output), `AGENTS.md`, `.opencode/skills/db-design-pipeline/SKILL.md` were not modified, per the command's safety constraint.
- No commit requested; nothing committed.