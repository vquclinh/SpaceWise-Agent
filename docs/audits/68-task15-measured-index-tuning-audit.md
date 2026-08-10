# Audit - Task 15 Measured Index Tuning Report

> Date: 2026-08-10
> Operator/member: (session)
> Tool: OpenCode (edit + read + grep)
> Provider/model/variant: deepseek-v4-flash-free (opencode/deepseek-v4-flash-free)
> OpenCode command used: none (direct conversation task)

## Task goal

Revise Phase 2 Output 15 so it fully addresses the Task 15 requirement from
`CS486_Project_Phase02.pdf`: tune the booking conflict check, room finder, and
two selected reporting queries, then compare execution plans and execution
times before and after indexing.

Phase 2 step evaluated: Task 15 / Output 15.

## Files created / changed

- Changed `outputs/15-index-tuning-report-G08.md`
- Created `docs/audits/68-task15-measured-index-tuning-audit.md`

## What was evaluated

- `CS486_Project_Phase02.pdf` Section 1.3 and Phase 2 Task 15 requirement.
- `.opencode/skills/db-design-pipeline/15-index-tuning-report/SKILL.md`
- `outputs/10-schema-migration-G08.sql`
- `outputs/14-data-generator-G08/01-generate-phase2-volume-data-G08.sql`
- `outputs/14-data-generator-G08/02-validate-phase2-volume-data-G08.sql`
- `outputs/15-index-tuning-report-G08.md`
- `outputs/16-analytical-queries-G08.sql`

## Issues found

- Output 15 still contained placeholder measurement rows saying the workloads
  were not executed.
- The report described expected plan changes but did not yet provide measured
  before/after logical reads or elapsed times.
- SQL Server filtered-index creation failed under the default `sqlcmd` session
  because `QUOTED_IDENTIFIER` was not enabled. Rerunning `sqlcmd` with `-I`
  resolved this and matches the required SQL Server filtered-index setting.

## Changes made

- Rewrote Output 15 with measured SQL Server benchmark evidence.
- Added benchmark setup details, including the SQL Server Docker image and
  script load order.
- Added Output 14 validation evidence for the generated 120,000-booking
  workload.
- Added a before/after measurement table for all four Task 15 workloads:
  booking conflict check, room finder, total approved hours, and weekday/hour
  heatmap.
- Added per-workload plan comparisons and index tradeoff analysis.

## Improvement classification

- Output refinement
- Validation/test improvement
- Documentation improvement

## Validation commands run

```bash
pdftotext CS486_Project_Phase02.pdf /tmp/phase02-task15.txt
sed -n '1,320p' outputs/15-index-tuning-report-G08.md
command -v sqlcmd
command -v sqlservr
docker images --format '{{.Repository}}:{{.Tag}}'
docker run --name spacewise-task15-sql -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD=<temporary-sa-password> -p 14339:1433 -d mcr.microsoft.com/mssql/server:2022-latest
docker cp outputs spacewise-task15-sql:/tmp/outputs
docker exec spacewise-task15-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P <temporary-sa-password> -C -Q "CREATE DATABASE SpaceWiseTask15;"
docker exec spacewise-task15-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P <temporary-sa-password> -C -I -d SpaceWiseTask15 -b -i /tmp/outputs/05-db-definition-G08.sql
docker exec spacewise-task15-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P <temporary-sa-password> -C -I -d SpaceWiseTask15 -b -i /tmp/outputs/06-sample-data-G08.sql
docker exec spacewise-task15-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P <temporary-sa-password> -C -I -d SpaceWiseTask15 -b -i /tmp/outputs/10-schema-migration-G08.sql
docker exec spacewise-task15-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P <temporary-sa-password> -C -I -d SpaceWiseTask15 -b -i /tmp/outputs/14-data-generator-G08/01-generate-phase2-volume-data-G08.sql
docker exec spacewise-task15-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P <temporary-sa-password> -C -I -d SpaceWiseTask15 -b -i /tmp/outputs/14-data-generator-G08/02-validate-phase2-volume-data-G08.sql
docker exec -i spacewise-task15-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P <temporary-sa-password> -C -I -d SpaceWiseTask15 -b -W -w 220
docker stop spacewise-task15-sql
docker rm spacewise-task15-sql
rg -n "Not executed|must be captured|not available|EXPLAIN|PostgreSQL|MySQL|Supabase" outputs/15-index-tuning-report-G08.md
rg -n "Booking conflict check|Room finder|Total approved hours|Weekday/hour heatmap|avg logical reads|Elapsed speedup|SQL Server 2022" outputs/15-index-tuning-report-G08.md
git diff --check
git status --short
```

## Validation results

- Phase 2 PDF extraction confirmed that Task 15 requires before/after execution
  plan and execution-time comparison.
- Local host did not have `sqlcmd` or `sqlservr`, but Docker had a local
  `mcr.microsoft.com/mssql/server:2022-latest` image.
- SQL Server 2022 Developer Edition started successfully in a temporary Docker
  container.
- Outputs 05, 06, 10, and 14 loaded successfully with `sqlcmd -I`.
- Output 14 validation passed:
  - Generated bookings: 120,000
  - Generated span days: 1,095
  - Cancelled generated bookings: 6,000
  - No-show generated bookings: 3,600
  - Generated advisory acknowledgements: 240
  - Generated maintenance records: 720
  - Generated escalation alerts: 120
- Task 15 benchmark summary recorded in Output 15:
  - Booking conflict check: 287.33 -> 6.00 average logical reads; 2.56 ms ->
    0.59 ms average elapsed.
  - Room finder: 339,395.33 -> 479.67 average logical reads; 3,814.45 ms ->
    845.42 ms average elapsed.
  - Total approved hours: 9,245.00 -> 7,114.00 average logical reads; 82.98 ms
    -> 40.50 ms average elapsed.
  - Weekday/hour heatmap: 3,306.00 -> 2,579.00 average logical reads; 50.09 ms
    -> 31.46 ms average elapsed.
- `rg` found no remaining "Not executed" placeholder language or PostgreSQL
  `EXPLAIN` references in Output 15.
- `git diff --check` passed after removing trailing whitespace.
- Temporary SQL Server container was stopped and removed.

## Risks / caveats

- Timings are environment-specific because they were captured in a local Docker
  container. The read counts and plan access paths are more stable than the
  absolute millisecond values.
- The report summarizes execution-plan access paths from SQL Server cached
  execution plans. If the final PDF needs screenshots, the team should still
  capture the same before/after plans in SSMS or Azure Data Studio.
- The benchmark initially revealed that `sqlcmd` should be run with `-I` for
  scripts that create filtered indexes.

## Git status summary

Changed files after this task:

- `outputs/15-index-tuning-report-G08.md`
- `docs/audits/68-task15-measured-index-tuning-audit.md`

## Recommended next steps

- Use the updated Output 15 measurement table in the Phase 2 report.
- If required by the instructor, capture visual actual-execution-plan
  screenshots in SSMS or Azure Data Studio using the same before/after index
  setup.
