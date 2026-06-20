---
description: Safe check that OpenCode follows the repository audit policy (no deliverables generated)
---

# Audit Smoke Test — Group G08

A safe, read-only command to verify that OpenCode follows the repository audit policy. It must **not** generate deliverables or modify `outputs/`.

## What to do

1. **Do not modify `outputs/`.** Do not generate any of the 7 deliverables.
2. Run or recommend the setup-stage validation:
   ```bash
   find outputs -maxdepth 2 -type f | sort
   bash scripts/check_required_files.sh --setup
   bash scripts/validate_sql.sh --setup
   ```
3. **Follow the repository audit policy** (`AGENTS.md` section 7) and create an audit using `audits/AUDIT_TEMPLATE.md`.
   - Name it with the **next available audit number** and the slug `audit-policy-smoke-test-audit` (e.g. `audits/NN-audit-policy-smoke-test-audit.md`). Do not backfill earlier missing audit numbers.
   - Record the exact **provider/model/variant** used in this session.
   - Classify the change as **"validation/test improvement"** or **"no agent/skill/command change needed"**.
   - Include the validation commands and their results, git status, and a confirmation that `outputs/` was not modified.

## Purpose

This command exists so the team (and graders) can confirm the audit habit works end to end without touching deliverables — a cheap rehearsal of the generate → refine → validate audit loop.
