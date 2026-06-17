cat > .opencode/skills/db-design-pipeline/SKILL.md <<'EOF'
---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, and DDL documents step by step.
compatibility: opencode
---

# Database Design Pipeline Skill

Use this skill when the user asks to transform business requirements into a database design.

## Important behavior

Before assuming anything, inspect the project:

1. Run `ls -la`.
2. Locate requirement files under `req/`, `docs/`, or files passed by the user.
3. Read the relevant requirement files fully before designing.
4. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.

## Required output files

Create or update the following files:

1. `docs/01-business-requirement-analysis.md`
2. `docs/02-conceptual-design-erd.md`

Do not skip any Markdown file.

---

# Step 1: Business Requirement Analysis

Save to:

`docs/01-business-requirement-analysis.md`

The document must include:

<!-- YOUR SKILL DESCRIPTION HERE -->
# Step 2: Conceptual Design / ERD

The ERD should be based on the document from the prior step: Step 1: Business Requirement Analysis.

Save to:

`docs/02-conceptual-design-erd.md`

The document must include:

<!-- YOUR SKILL DESCRIPTION HERE -->



<!-- SIMILARLY FOR FOLLOWING STEPS -->