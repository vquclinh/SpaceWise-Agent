---
description: Evaluates a Phase 1 deliverable using the common grading engine and a task-specific rubric.
---

# /evaluate-task

This command acts as the QA/Grading system to evaluate a specific Phase 1 deliverable.

## Usage
`/evaluate-task Task: 01`

## Instructions for the Agent
1. **Load the Master Engine:** Read the grading scales, dimensions, and output format from `.opencode/skills/evaluation/SKILL_COMMON_EVAL.md`.
2. **Load the Specific Rubric:** Identify and read the matching rubric file for the requested task (e.g., `.opencode/skills/evaluation/rubrics/01-business-req-analysis.md`).
3. **Load the Target Output:** Identify and read the target deliverable (e.g., `outputs/01-business-req-analysis-G08.md`).
4. **Evaluate:** Act strictly as a grader. Assess the target output against the universal dimensions and the specific checklist items. 
5. **Output:** Generate the evaluation report using the exact Markdown structure defined in `SKILL_COMMON_EVAL.md`. Save the result as a new file in `docs/evaluations/` (e.g., `docs/evaluations/task-01-evaluation.md`). Do not modify the original output file.