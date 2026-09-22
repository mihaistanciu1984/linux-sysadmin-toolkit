#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Usage: $0 [normalized_load_threshold]"
    echo
    echo "The default threshold is 80 percent."
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
   (( THRESHOLD < 1 || THRESHOLD > 1000 )); then
    echo "[ERROR] Threshold must be a number between 1 and 1000."
    show_help
    exit 1
fi

CPU_COUNT="$(nproc)"
read -r LOAD_1 LOAD_5 LOAD_15 _ < /proc/loadavg

NORMALIZED_LOAD="$(
    awk -v load="${LOAD_1}" -v cpus="${CPU_COUNT}" \
        'BEGIN { printf "%.1f", (load / cpus) * 100 }'
)"

echo "CPU load report"
echo "Warning threshold: ${THRESHOLD}%"
echo
echo "Logical CPUs:             ${CPU_COUNT}"
echo "Load average (1 minute):  ${LOAD_1}"
echo "Load average (5 minutes): ${LOAD_5}"
echo "Load average (15 minutes): ${LOAD_15}"
echo "Normalized 1-minute load: ${NORMALIZED_LOAD}%"
echo

if awk -v load="${NORMALIZED_LOAD}" \
       -v threshold="${THRESHOLD}" \
       'BEGIN { exit !(load >= threshold) }'; then
    echo "[WARNING] Normalized CPU load is above the threshold."
    STATUS=1
else
    echo "[OK] Normalized CPU load is below the threshold."
    STATUS=0
fi

echo
echo "Top CPU-consuming processes:"
ps -eo pid,user,comm,%cpu \
    --sort=-%cpu |
    head -n 6

exit "${STATUS}"