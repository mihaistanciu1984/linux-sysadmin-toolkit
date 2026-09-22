#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Usage: $0 <hostname-or-ip> [tcp-port]"
    echo
    echo "Examples:"
    echo "  $0 example.com"
    echo "  $0 example.com 443"
    echo "  $0 192.0.2.10 22"
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "[ERROR] A destination and optional TCP port are required."
    show_help
    exit 2
fi

TARGET="$1"
PORT="${2:-}"

if [[ -n "${PORT}" ]]; then
    if ! [[ "${PORT}" =~ ^[0-9]+$ ]] ||
       (( PORT < 1 || PORT > 65535 )); then
        echo "[ERROR] TCP port must be between 1 and 65535."
        exit 2
    fi
fi

if ! command -v getent >/dev/null 2>&1; then
    echo "[ERROR] getent is not available."
    exit 2
fi

echo "Network connectivity report"
echo
echo "Target: ${TARGET}"

DEFAULT_ROUTE="$(
    ip route show default 2>/dev/null |
        head -n 1 || true
)"

if [[ -n "${DEFAULT_ROUTE}" ]]; then
    echo "Default route: ${DEFAULT_ROUTE}"
else
    echo "[WARNING] No default route was detected."
fi

RESOLVED_IP="$(
    getent ahosts "${TARGET}" 2>/dev/null |
        awk 'NR == 1 {print $1}'
)"

if [[ -z "${RESOLVED_IP}" ]]; then
    echo "[CRITICAL] Unable to resolve destination: ${TARGET}"
    exit 1
fi

echo "Resolved address: ${RESOLVED_IP}"

ROUTE="$(
    ip route get "${RESOLVED_IP}" 2>/dev/null |
        head -n 1 || true
)"

if [[ -n "${ROUTE}" ]]; then
    echo "Selected route: ${ROUTE}"
else
    echo "[WARNING] Unable to determine the selected route."
fi

echo

if ping -c 1 -W 2 "${TARGET}" >/dev/null 2>&1; then
    echo "[OK] ICMP connectivity is available."
    PING_STATUS=0
else
    echo "[WARNING] ICMP connectivity failed or is blocked."
    PING_STATUS=1
fi

if [[ -n "${PORT}" ]]; then
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 5 "${TARGET}" "${PORT}" >/dev/null 2>&1; then
            echo "[OK] TCP port ${PORT} is reachable."
            exit 0
        fi
    elif command -v timeout >/dev/null 2>&1; then
        if timeout 5 bash -c \
            'exec 3<>"/dev/tcp/$1/$2"' \
            _ "${TARGET}" "${PORT}" 2>/dev/null; then
            echo "[OK] TCP port ${PORT} is reachable."
            exit 0
        fi
    else
        echo "[ERROR] Install netcat or timeout to test TCP ports."
        exit 2
    fi

    echo "[CRITICAL] TCP port ${PORT} is not reachable."
    exit 1
fi

if (( PING_STATUS == 0 )); then
    exit 0
fi

echo "[WARNING] Destination resolved, but ICMP connectivity failed."
exit 1