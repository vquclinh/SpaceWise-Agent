#!/usr/bin/env bash
set -euo pipefail

# Verify the required project files.
#
# Usage:
#   check_required_files.sh                  # setup mode (default)
#   check_required_files.sh --setup          # setup mode
#   check_required_files.sh --final <GROUP>  # final mode, e.g. --final G01
#
# Setup mode : confirm the scaffold exists and outputs/ has NO final deliverables yet.
# Final mode : confirm all 7 deliverables exist for the given group number.
#
# The script is read-only and safe to run at any stage.

MODE="setup"
GROUP_NUMBER=""

case "${1:-}" in
  --setup|"") MODE="setup" ;;
  --final)
    MODE="final"
    GROUP_NUMBER="${2:-}"
    if [[ -z "$GROUP_NUMBER" ]]; then
      echo "ERROR: --final requires a group number, e.g. --final G01"
      exit 2
    fi
    ;;
  G[0-9]*)
    # Backward compatibility: a bare group number means final mode.
    MODE="final"
    GROUP_NUMBER="$1"
    ;;
  *)
    echo "ERROR: unknown argument '$1'"
    echo "Usage: $0 [--setup | --final <GROUP>]"
    exit 2
    ;;
esac

deliverables_for() {
  local g="$1"
  echo "outputs/01-business-req-analysis-${g}.md"
  echo "outputs/02-erd-design-${g}.md"
  echo "outputs/03-logical-design-${g}.md"
  echo "outputs/04-design-validation-${g}.md"
  echo "outputs/05-db-definition-${g}.sql"
  echo "outputs/06-sample-data-${g}.sql"
  echo "outputs/07-query-design-${g}.sql"
}

if [[ "$MODE" == "setup" ]]; then
  echo "Setup-mode check: verifying scaffold and that no deliverables exist yet..."
  echo ""

  SCAFFOLD=(
    "AGENT.md"
    "AGENTS.md"
    "README.md"
    "req/business-requirement.md"
    "outputs/.gitkeep"
    ".opencode/skills/db-design-pipeline/SKILL.md"
    ".opencode/commands/audit-smoke-test.md"
    "audits/AUDIT_TEMPLATE.md"
  )

  PROBLEMS=0
  for FILE in "${SCAFFOLD[@]}"; do
    if [[ -f "$FILE" ]]; then
      echo "  [OK]    $FILE"
    else
      echo "  [MISS]  $FILE"
      PROBLEMS=$((PROBLEMS + 1))
    fi
  done

  echo ""
  # Any deliverable-looking file in outputs/ at setup stage is a problem.
  FOUND_DELIVERABLES=$(find outputs -maxdepth 1 -type f \
    -name '0[1-7]-*-G*.md' -o -name '0[1-7]-*-G*.sql' 2>/dev/null | sort || true)
  if [[ -n "$FOUND_DELIVERABLES" ]]; then
    echo "  [WARN]  Deliverables already present (should be empty at setup):"
    echo "$FOUND_DELIVERABLES" | sed 's/^/            /'
    PROBLEMS=$((PROBLEMS + 1))
  else
    echo "  [OK]    outputs/ contains no final deliverables yet (expected at setup)."
  fi

  echo ""
  if (( PROBLEMS > 0 )); then
    echo "SETUP FAIL: ${PROBLEMS} problem(s) found."
    exit 1
  else
    echo "SETUP PASS: scaffold present and outputs/ has no deliverables yet."
  fi
  exit 0
fi

# Final mode
echo "Final-mode check: verifying 7 deliverables for group ${GROUP_NUMBER}..."
echo ""

MISSING_COUNT=0
while IFS= read -r FILE; do
  if [[ -f "$FILE" ]]; then
    SIZE=$(wc -c < "$FILE" | tr -d ' ')
    echo "  [OK]    $FILE (${SIZE} bytes)"
  else
    echo "  [MISS]  $FILE"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
done < <(deliverables_for "$GROUP_NUMBER")

echo ""
if (( MISSING_COUNT > 0 )); then
  echo "FAIL: ${MISSING_COUNT} file(s) missing."
  exit 1
else
  echo "PASS: All 7 required output files present."
fi
