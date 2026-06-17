#!/usr/bin/env bash
set -euo pipefail

# Validate the SQL deliverables.
#
# Usage:
#   validate_sql.sh                  # setup mode (default)
#   validate_sql.sh --setup          # setup mode
#   validate_sql.sh --final <GROUP>  # final mode, e.g. --final G01
#
# Setup mode : confirm no SQL deliverables exist yet (expected at setup stage).
# Final mode : run content checks on the 3 SQL deliverables for the given group.
#
# Checks are heuristic and case-insensitive. The script is read-only; it does NOT
# require a live database, Docker, or any network access.

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
    MODE="final"
    GROUP_NUMBER="$1"
    ;;
  *)
    echo "ERROR: unknown argument '$1'"
    echo "Usage: $0 [--setup | --final <GROUP>]"
    exit 2
    ;;
esac

DDL_FILE="outputs/05-db-definition-${GROUP_NUMBER}.sql"
DATA_FILE="outputs/06-sample-data-${GROUP_NUMBER}.sql"
QUERY_FILE="outputs/07-query-design-${GROUP_NUMBER}.sql"

if [[ "$MODE" == "setup" ]]; then
  echo "Setup-mode SQL check: confirming no SQL deliverables exist yet..."
  echo ""
  FOUND=$(find outputs -maxdepth 1 -type f -name '0[567]-*-G*.sql' 2>/dev/null | sort || true)
  if [[ -n "$FOUND" ]]; then
    echo "  [WARN]  SQL deliverables already present (unexpected at setup):"
    echo "$FOUND" | sed 's/^/            /'
    echo ""
    echo "SETUP NOTE: run final mode to validate them: $0 --final <GROUP>"
    exit 1
  fi
  echo "  [OK]    No SQL deliverables yet (expected at setup)."
  echo ""
  echo "SETUP PASS."
  exit 0
fi

echo "Final-mode SQL validation for group ${GROUP_NUMBER}..."
echo ""

FAIL_COUNT=0

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "  [MISS]  $f"
    return 1
  fi
  if [[ ! -s "$f" ]]; then
    echo "  [FAIL]  $f — file is empty"
    return 1
  fi
  return 0
}

# --- 05: DDL ---
if require_file "$DDL_FILE"; then
  if grep -qiE 'CREATE[[:space:]]+TABLE' "$DDL_FILE"; then
    echo "  [OK]    $DDL_FILE — CREATE TABLE found"
  else
    echo "  [FAIL]  $DDL_FILE — no CREATE TABLE statement"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  if grep -qiE 'PRIMARY[[:space:]]+KEY|FOREIGN[[:space:]]+KEY|REFERENCES|CHECK[[:space:]]*\(|UNIQUE' "$DDL_FILE"; then
    echo "  [OK]    $DDL_FILE — key/constraint evidence found"
  else
    echo "  [FAIL]  $DDL_FILE — no key/constraint evidence (PK/FK/CHECK/UNIQUE)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- 06: Sample data ---
if require_file "$DATA_FILE"; then
  if grep -qiE 'INSERT[[:space:]]+INTO' "$DATA_FILE"; then
    echo "  [OK]    $DATA_FILE — INSERT statements found"
  else
    echo "  [FAIL]  $DATA_FILE — no INSERT INTO statement"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- 07: Query design ---
if require_file "$QUERY_FILE"; then
  SELECT_COUNT=$(grep -ciE 'SELECT' "$QUERY_FILE" || true)
  QUESTION_COUNT=$(grep -ciE 'Business question' "$QUERY_FILE" || true)
  if (( SELECT_COUNT >= 5 )); then
    echo "  [OK]    $QUERY_FILE — ${SELECT_COUNT} SELECT statement(s) (>= 5)"
  else
    echo "  [FAIL]  $QUERY_FILE — only ${SELECT_COUNT} SELECT statement(s), need >= 5"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  if (( QUESTION_COUNT >= 5 )); then
    echo "  [OK]    $QUERY_FILE — ${QUESTION_COUNT} 'Business question' annotation(s) (>= 5)"
  else
    echo "  [WARN]  $QUERY_FILE — ${QUESTION_COUNT} 'Business question' annotation(s); each query should document Business question / Target user(s) / Why useful / SQL"
  fi
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
if (( FAIL_COUNT > 0 )); then
  echo "FAIL: ${FAIL_COUNT} SQL check(s) failed."
  exit 1
else
  echo "PASS: All SQL files validated."
fi
