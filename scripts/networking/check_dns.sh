#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Usage: $0 <hostname> [dns-server]"
    echo
    echo "Examples:"
    echo "  $0 example.com"
    echo "  $0 example.com 192.0.2.53"
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "[ERROR] A hostname and optional DNS server are required."
    show_help
    exit 2
fi

HOSTNAME_TO_CHECK="$1"
DNS_SERVER="${2:-}"

if ! [[ "${HOSTNAME_TO_CHECK}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "[ERROR] Invalid hostname: ${HOSTNAME_TO_CHECK}"
    exit 2
fi

if ! command -v getent >/dev/null 2>&1; then
    echo "[ERROR] getent is not available."
    exit 2
fi

echo "DNS resolution report"
echo
echo "Hostname: ${HOSTNAME_TO_CHECK}"

SYSTEM_RESULT="$(
    getent ahosts "${HOSTNAME_TO_CHECK}" 2>/dev/null |
        awk '{print $1}' |
        sort -u || true
)"

if [[ -n "${SYSTEM_RESULT}" ]]; then
    echo
    echo "System resolver:"
    printf '%s\n' "${SYSTEM_RESULT}"
    SYSTEM_STATUS=0
else
    echo
    echo "[WARNING] System resolver returned no addresses."
    SYSTEM_STATUS=1
fi

DIG_STATUS=1

if command -v dig >/dev/null 2>&1; then
    if [[ -n "${DNS_SERVER}" ]]; then
        echo
        echo "DNS server: ${DNS_SERVER}"

        DIG_RESULT="$(
            dig \
                @"${DNS_SERVER}" \
                "${HOSTNAME_TO_CHECK}" \
                A \
                +short \
                +time=3 \
                +tries=1 2>/dev/null || true
        )"
    else
        DIG_RESULT="$(
            dig \
                "${HOSTNAME_TO_CHECK}" \
                A \
                +short \
                +time=3 \
                +tries=1 2>/dev/null || true
        )"
    fi

    if [[ -n "${DIG_RESULT}" ]]; then
        echo
        echo "DNS query result:"
        printf '%s\n' "${DIG_RESULT}"
        DIG_STATUS=0
    else
        echo
        echo "[WARNING] DNS query returned no A records."
    fi
elif [[ -n "${DNS_SERVER}" ]]; then
    echo
    echo "[ERROR] dig is required to query a specific DNS server."
    echo "Install it with: sudo apt install dnsutils"
    exit 2
else
    echo
    echo "[INFO] dig is not installed; only the system resolver was tested."
fi

if (( SYSTEM_STATUS == 0 || DIG_STATUS == 0 )); then
    echo
    echo "[OK] DNS resolution succeeded."
    exit 0
fi

echo
echo "[CRITICAL] DNS resolution failed."
exit 1