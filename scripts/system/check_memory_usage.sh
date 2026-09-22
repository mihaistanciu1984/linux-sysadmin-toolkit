#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Usage: $0 [threshold_percentage]"
    echo
    echo "Example:"
    echo "  $0 80"
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

THRESHOLD="${1:-80}"

if ! [[ "${THRESHOLD}" =~ ^[0-9]+$ ]] ||
   (( THRESHOLD < 1 || THRESHOLD > 100 )); then
    echo "[ERROR] Threshold must be a number between 1 and 100."
    show_help
    exit 1
fi

MEM_TOTAL_KB="$(
    awk '/^MemTotal:/ {print $2}' /proc/meminfo
)"

MEM_AVAILABLE_KB="$(
    awk '/^MemAvailable:/ {print $2}' /proc/meminfo
)"

SWAP_TOTAL_KB="$(
    awk '/^SwapTotal:/ {print $2}' /proc/meminfo
)"

SWAP_FREE_KB="$(
    awk '/^SwapFree:/ {print $2}' /proc/meminfo
)"

if [[ -z "${MEM_TOTAL_KB}" ||
      -z "${MEM_AVAILABLE_KB}" ||
      "${MEM_TOTAL_KB}" -eq 0 ]]; then
    echo "[ERROR] Unable to read memory information."
    exit 1
fi

MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAILABLE_KB))
MEM_USED_PERCENT=$(
    awk -v used="${MEM_USED_KB}" -v total="${MEM_TOTAL_KB}" \
        'BEGIN { printf "%.1f", (used / total) * 100 }'
)

MEM_TOTAL_MIB=$(
    awk -v value="${MEM_TOTAL_KB}" \
        'BEGIN { printf "%.1f", value / 1024 }'
)

MEM_USED_MIB=$(
    awk -v value="${MEM_USED_KB}" \
        'BEGIN { printf "%.1f", value / 1024 }'
)

MEM_AVAILABLE_MIB=$(
    awk -v value="${MEM_AVAILABLE_KB}" \
        'BEGIN { printf "%.1f", value / 1024 }'
)

echo "Memory usage report"
echo "Warning threshold: ${THRESHOLD}%"
echo
echo "Total:     ${MEM_TOTAL_MIB} MiB"
echo "Used:      ${MEM_USED_MIB} MiB"
echo "Available: ${MEM_AVAILABLE_MIB} MiB"
echo "Usage:     ${MEM_USED_PERCENT}%"

if awk -v usage="${MEM_USED_PERCENT}" \
       -v threshold="${THRESHOLD}" \
       'BEGIN { exit !(usage >= threshold) }'; then
    echo "[WARNING] Memory usage is above the configured threshold."
    STATUS=1
else
    echo "[OK] Memory usage is below the configured threshold."
    STATUS=0
fi

if (( SWAP_TOTAL_KB > 0 )); then
    SWAP_USED_KB=$((SWAP_TOTAL_KB - SWAP_FREE_KB))
    SWAP_USED_PERCENT=$(
        awk -v used="${SWAP_USED_KB}" -v total="${SWAP_TOTAL_KB}" \
            'BEGIN { printf "%.1f", (used / total) * 100 }'
    )

    echo
    echo "Swap usage: ${SWAP_USED_PERCENT}%"
else
    echo
    echo "Swap: not configured"
fi

exit "${STATUS}"