# SKILL.md — SpaceWise Agent

## Available Skills

### db-design-pipeline

- **Location:** `.opencode/skills/db-design-pipeline/SKILL.md`
- **Description:** Transforms business requirements into database design artifacts through a 7-step pipeline.
- **Steps:**
  1. Business Requirement Analysis
  2. Conceptual ERD Design (Crow's Foot notation)
  3. Logical Database Design
  4. Design Validation
  5. Database Definition (DDL)
  6. Sample Data Preparation
  7. Query Design — at least 5 queries, each with Business question, Target user(s), Why it is useful, and the SQL statement
- **DBMS:** Microsoft SQL Server (configurable)
- **Invocation:** `/design-db req/business-requirement.md`

### Prerequisites

- OpenCode installed and connected to an LLM provider.
- Business requirement file present in `req/`.
- `.opencode/` commands and skills directories configured.

### Outputs

All generated artifacts are placed in `outputs/` with the naming convention `NN-artifact-name-G<GroupNumber>.md` or `.sql`.