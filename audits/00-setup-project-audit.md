# Setup Project Audit — 00-setup-project-audit.md

## Audit Metadata

| Field | Value |
|---|---|
| Date | 2026-06-17 |
| Phase | Setup |
| Agent | OpenCode + DeepSeek V4 Pro |
| Repository | spacewise-agent |

## Purpose

This audit records the initial project setup process, including all files created, configuration decisions, and the rationale for the chosen repository structure.

## Setup Actions Performed

### 1. Directory Structure Created

| Directory | Purpose |
|---|---|
| `req/` | Input business requirements |
| `outputs/` | Generated database design artifacts |
| `audits/` | Agent improvement and evaluation records |
| `scripts/` | Validation and utility scripts |
| `.opencode/commands/` | Custom OpenCode commands |
| `.opencode/skills/db-design-pipeline/` | Pipeline skill definition |
| `.opencode/skills/db-design-pipeline/templates/` | Templates for consistent output |

### 2. Files Extracted from Teacher Demo (`cs486-demo-share.zip`)

| File | Source Path | Destination | Modifications |
|---|---|---|---|
| `req/business-requirement.md` | `cs486-demo-share/req/business-requirement.md` | `req/business-requirement.md` | None |
| `AGENTS.md` | `cs486-demo-share/AGENTS.md` | `AGENTS.md` | Rewritten for this project with full 7-step pipeline, `outputs/` path, critical business rules, and input file references |
| `.opencode/commands/design-db.md` | `cs486-demo-share/.opencode/commands/design-db.md` | `.opencode/commands/design-db.md` | Added reference to `outputs/` |
| `.opencode/skills/db-design-pipeline/SKILL.md` | `cs486-demo-share/.opencode/skills/db-design-pipeline/SKILL.md` | `.opencode/skills/db-design-pipeline/SKILL.md` | Fully rewritten: removed all placeholders, defined all 7 steps with detailed content requirements |

### 3. New Files Created

| File | Purpose |
|---|---|
| `AGENT.md` | Official CS486 agent manifest with group info and LLM configuration |
| `SKILL.md` | Official CS486 skill manifest listing available skills |
| `.gitignore` | Excludes API keys, OS files, IDE config, and other unwanted files |
| `README.md` | Complete project documentation with setup, usage, and validation instructions |
| `scripts/check_required_files.sh` | Validates all 7 required output files exist |
| `scripts/validate_sql.sh` | Runs basic SQL keyword and file-size validation |
| `outputs/.gitkeep` | Keeps outputs directory in Git while empty |
| `audits/.gitkeep` | Keeps audits directory in Git while empty |
| `audits/00-setup-project-audit.md` | This audit file |

### 4. File Modifications

| File | Original (from demo) | Changes Made |
|---|---|---|
| `AGENTS.md` | Referenced `docs/` for outputs, only had 2 pipeline steps | Updated to reference `outputs/`, expanded to full 7-step pipeline, added critical business rules, added input file references |
| `.opencode/skills/db-design-pipeline/SKILL.md` | Placeholder template with empty steps | Defined all 7 steps with detailed content requirements for each output file |
| `.opencode/commands/design-db.md` | Referenced generic output | Added reference to `outputs/` |
| `README.md` | Only had `# spacewise-agent` | Complete rewrite with setup instructions, project structure, usage guide, validation scripts, cost control notes, and academic integrity statement |

## Design Decisions

### AGENT.md vs AGENTS.md

- `AGENT.md` (singular): Official CS486 required file. Contains group metadata, LLM configuration, and references to detailed instructions.
- `AGENTS.md` (plural): Teacher demo convention. Contains the full project-level agent rules, workflow order, output requirements, DBMS choice, and design rules.

### SKILL.md (top-level) vs .opencode/skills/db-design-pipeline/SKILL.md

- `SKILL.md` (top-level): Official CS486 required file. Acts as a skill manifest listing all available skills and their locations.
- `.opencode/skills/db-design-pipeline/SKILL.md`: The actual OpenCode skill definition with the complete 7-step pipeline and content requirements for each deliverable.

### Output Path

Changed from demo convention (`docs/`) to `outputs/` with `G<GroupNumber>` naming per CS486 official requirements.

### MS SQL Server

Retained from the teacher demo as the default DBMS. The AGENTS.md and SKILL.md both note it is configurable.

## Next Steps

1. Fill in group number, student names in `AGENT.md`.
2. Run `/design-db req/business-requirement.md` to generate the 7 deliverables.
3. Review and improve each generated artifact.
4. Record improvement iterations in `audits/`.
5. Validate outputs with `scripts/check_required_files.sh` and `scripts/validate_sql.sh`.

## Open Questions

- None identified during setup.