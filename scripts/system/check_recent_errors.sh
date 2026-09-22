#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Usage: $0 [minutes] [maximum_allowed_errors]"
    echo
    echo "Defaults:"
    echo "  minutes:                15"
    echo "  maximum_allowed_errors: 0"
    echo
    echo "Example:"
    echo "  $0 30 5"
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

MINUTES="${1:-15}"
MAX_ERRORS="${2:-0}"

if ! [[ "${MINUTES}" =~ ^[0-9]+$ ]] ||
   (( MINUTES < 1 || MINUTES > 10080 )); then
    echo "[ERROR] Minutes must be between 1 and 10080."
    exit 2
fi

if ! [[ "${MAX_ERRORS}" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] Maximum allowed errors must be zero or greater."
    exit 2
fi

if ! command -v journalctl >/dev/null 2>&1; then
    echo "[ERROR] journalctl is not available."
    exit 2
fi

LOG_OUTPUT="$(
    journalctl \
        --quiet \
        --no-pager \
        --priority=err \
        --since "-${MINUTES} minutes" \
        --output=short-iso 2>/dev/null || true
)"

ERROR_COUNT="$(
    printf '%s\n' "${LOG_OUTPUT}" |
        awk 'NF {count++} END {print count + 0}'
)"

echo "Recent system error report"
echo
echo "Interval:               last ${MINUTES} minutes"
echo "Errors found:           ${ERROR_COUNT}"
echo "Maximum allowed errors: ${MAX_ERRORS}"
echo

if (( ERROR_COUNT > MAX_ERRORS )); then
    echo "[WARNING] Error count exceeds the configured limit."
    echo
    echo "Most recent errors:"
    printf '%s\n' "${LOG_OUTPUT}" |
        tail -n 20

    exit 1
fi

echo "[OK] Error count is within the configured limit."
exit 0