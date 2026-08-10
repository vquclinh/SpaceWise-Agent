# Audit — Phase 2 Output Consistency Review

> Date: 2026-08-10
> Operator/member: (session)
> Tool: OpenCode (edit + read + grep)
> Provider/model/variant: deepseek-v4-flash-free (opencode/deepseek-v4-flash-free)
> OpenCode command used: none (direct conversation task)

## Task goal

Review the current Phase 2 outputs against `CS486_Project_Phase02.pdf`, repository rules, and the cross-output design chain. Fix concrete defects that could make Outputs 08–16 inconsistent, logically wrong, or weaker as deliverables.

Phase 2 outputs evaluated: Outputs 08, 09, 10, 11, 12, 13, 14, 15, and 16.

## Files created / changed

- Created `docs/audits/67-phase2-output-consistency-review-audit.md`
- Changed `AGENT.md`
- Changed `AGENTS.md`
- Changed `outputs/08-requirement-change-analysis-G08.md`
- Changed `outputs/09-updated-erd-and-logical-design-G08.md`
- Changed `outputs/12-concurrency-implementation-G08.sql`
- Changed `outputs/13-concurrency-tests-G08/00-setup-test-data.sql`
- Changed `outputs/14-data-generator-G08/01-generate-phase2-volume-data-G08.sql`
- Changed `outputs/15-index-tuning-report-G08.md`

## What was evaluated

- Phase 2 PDF requirements: maintenance impact levels, concurrent booking and approval, Section 1.3 reports, generated sample data, indexing/tuning, and 3NF validation.
- Presence and naming of all required Phase 1 and Phase 2 deliverables in `outputs/`.
- Phase 2 SQL dialect discipline: SQL Server-only syntax in executable SQL outputs.
- Cross-output consistency from Output 08/09 design through Output 10 migration, Output 11/12 concurrency design/implementation, Output 13 tests, Output 14 generator, Output 15 tuning report, and Output 16 reports.
- Command and skill separation for Tasks 14, 15, and 16.

## Issues found

- Output 14 advisory-generation bug: `generated_seq % 500 = 0` selected only rows already classified as `Cancelled` by the status distribution, producing zero advisory candidates and therefore zero advisory acknowledgements.
- Output 14 realism issue: generated `System` approval decisions did not check the configured auto-approval participant caps (`MeetingRoom <= 24`, `StudentWorkspace <= 20`).
- Output 12 prerequisite comment referenced the stale index name `IX_maintenance_blk` instead of current `IX_maintenance_blocking`.
- Output 13 setup script contained a Vietnamese explanatory comment, violating the repository English-only rule.
- `AGENTS.md`, Output 08, and Output 09 still contained live guidance saying Output 10 was stale and had to be regenerated, even though the current migration implements the amendments and is consumed by later outputs.
- `AGENTS.md` still said only the shared skill and Task 08 skill existed, while task-specific skills now exist for Tasks 08–16 and command files exist for Tasks 11–16.
- `AGENT.md` described `outputs/` as only the seven Phase 1 deliverables.
- Output 15 described missing validation scripts as "deleted in the worktree"; in this checkout, the accurate statement is that the scripts are not present.

## Changes made

- Changed Output 14 advisory candidate selection from modulus `500` to modulus `7`, with a comment explaining why the prior divisor was invalid.
- Added auto-approval participant-cap checks to Output 14's generated `System` decision classification.
- Corrected Output 12's prerequisite index reference to `IX_maintenance_blocking`.
- Rewrote the Output 13 RCSI setup comment in English.
- Updated `AGENTS.md`, Output 08, and Output 09 to treat current Output 10 as the authoritative migration implementation, not stale pending work.
- Updated `AGENTS.md` command/skill status to reflect current Task 08–16 skills and Task 11–16 commands.
- Updated `AGENT.md` to describe both Phase 1 and Phase 2 deliverables in `outputs/`.
- Updated Output 15's execution-evidence caveat to say validation scripts were not present in this checkout.

## Improvement classification

- Output refinement
- AGENTS.md improvement
- Documentation improvement
- Validation/test improvement

## Validation commands run

```bash
ls -la
find outputs -maxdepth 2 -type f | sort
pdftotext CS486_Project_Phase02.pdf - | sed -n '1,220p'
rg -n "\btsrange\b|EXCLUDE USING|btree_gist|\bDEFERRABLE\b|\bGIN\b|SET LOCAL|ON CONFLICT|\bRETURNING\b|AUTO_INCREMENT|\bLIMIT\b|\bSERIAL\b|NOW\(\)" outputs/10-schema-migration-G08.sql outputs/12-concurrency-implementation-G08.sql outputs/13-concurrency-tests-G08/*.sql outputs/14-data-generator-G08/*.sql outputs/16-analytical-queries-G08.sql
rg -n "Output 10.*stale|10-schema-migration-G08\.sql.*stale|must be regenerated before Task 11|only the shared skill and the Task 08 skill|space_facilities\.quantity stays|generated_seq % 500|IX_maintenance_blk|Bật RCSI|Lệnh này|the 7 Phase 1 deliverables" AGENT.md AGENTS.md outputs/08-requirement-change-analysis-G08.md outputs/09-updated-erd-and-logical-design-G08.md outputs/12-concurrency-implementation-G08.sql outputs/13-concurrency-tests-G08/00-setup-test-data.sql outputs/14-data-generator-G08/01-generate-phase2-volume-data-G08.sql outputs/15-index-tuning-report-G08.md
awk 'BEGIN { target=120000; adv=0; syscnt=0; for (i=1; i<=target; i++) { status="Completed"; if (i%20==0) status="Cancelled"; else if (i%25==0) status="NoShow"; else if (i%13==0) status="Rejected"; else if (i%17==0) status="Pending"; else if (i%23==0) status="CheckedIn"; else if (i%29==0) status="Approved"; approvedlike=(status=="Approved" || status=="CheckedIn" || status=="Completed" || status=="NoShow"); if (i%7==0 && approvedlike) adv++; space=((i-1)%72)+1; typeidx=(space-1)%6; if (typeidx==2) { stype="MeetingRoom"; cap=12+(space%18); } else if (typeidx==5) { stype="StudentWorkspace"; cap=40+(space%40); } else { stype="Other"; cap=40; } participants=(cap<=5 ? cap : 5+(i%(cap-4))); bmod=i%9; eligible=(bmod==3 || bmod==4 || bmod==5 || bmod==8); capok=((stype=="MeetingRoom" && participants<=24) || (stype=="StudentWorkspace" && participants<=20)); if (approvedlike && capok && eligible && i%3==0) syscnt++; } print "advisory_candidates=" adv; print "capped_advisory_rows=" (adv<240 ? adv : 240); print "system_decisions=" syscnt; }'
command -v sqlcmd
command -v sqlservr
find scripts -maxdepth 2 -type f
git diff --check
git status --short
```

## Validation results

- Required Phase 2 output files 08–16 are present, including Output 13 scripts/results/images and Output 14 generator/validation files.
- Phase 2 PDF requirement extraction confirmed the required reports, concurrency demonstration, large generated workload, query tuning, and 3NF validation scope.
- SQL dialect scan returned no forbidden PostgreSQL/MySQL constructs in executable Phase 2 SQL files.
- Stale-reference scan returned no matches for the corrected issues.
- Static workload count after the Output 14 fix:
  - `advisory_candidates=14214`
  - `capped_advisory_rows=240`
  - `system_decisions=7597`
- `git diff --check` passed with no whitespace errors.
- `sqlcmd` and `sqlservr` were not available in this environment.
- `scripts/` is not present in this checkout, so repository shell validation scripts could not be run.

## Risks / caveats

- Actual SQL Server execution was not available here, so the migration, procedures, generator, concurrency scripts, and analytical queries were reviewed statically rather than executed against SQL Server.
- Output 15 still needs real before/after execution-plan screenshots, logical reads, CPU time, and elapsed time captured in SSMS or Azure Data Studio before final PDF submission. The report already states this rather than fabricating timings.
- The Phase 2 design deliberately uses synchronized `CHECK` whitelists for facility names after dropping the catalogue tables; future facility-type additions require a migration touching both whitelists.

## Git status summary

At audit creation time, the working tree contains modifications to:

- `AGENT.md`
- `AGENTS.md`
- `outputs/08-requirement-change-analysis-G08.md`
- `outputs/09-updated-erd-and-logical-design-G08.md`
- `outputs/12-concurrency-implementation-G08.sql`
- `outputs/13-concurrency-tests-G08/00-setup-test-data.sql`
- `outputs/14-data-generator-G08/01-generate-phase2-volume-data-G08.sql`
- `outputs/15-index-tuning-report-G08.md`
- `docs/audits/67-phase2-output-consistency-review-audit.md`

## Recommended next steps

- Run Outputs 05, 06, 10, 12, 13, 14, and 16 in a SQL Server-compatible environment.
- Capture Output 15 before/after execution plans, `STATISTICS IO`, and `STATISTICS TIME` results for the four tuned query surfaces.
- Add or restore repository validation scripts if the team wants repeatable non-SSMS checks.
