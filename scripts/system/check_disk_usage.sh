#!/usr/bin/env bash

set -euo pipefail

THRESHOLD="${1:-80}"

if ! [[ "${THRESHOLD}" =~ ^[0-9]+$ ]] ||
   (( THRESHOLD < 1 || THRESHOLD > 100 )); then
    echo "Usage: $0 [threshold_percentage]"
    echo "Example: $0 80"
    exit 1
fi

echo "Disk usage report"
echo "Warning threshold: ${THRESHOLD}%"
echo

df -P -x tmpfs -x devtmpfs |
    awk -v threshold="${THRESHOLD}" '
        NR > 1 {
            usage = $5
            mount_point = $NF
            gsub("%", "", usage)

            if (usage >= threshold) {
                printf "[WARNING] %-30s %3s%% used\n",
                    mount_point, usage
            } else {
                printf "[OK]      %-30s %3s%% used\n",
                    mount_point, usage
            }
        }
    '