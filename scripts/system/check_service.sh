#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Usage: $0 <service-name>"
    echo
    echo "Examples:"
    echo "  $0 ssh"
    echo "  $0 ssh.service"
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

if [[ $# -ne 1 ]]; then
    echo "[ERROR] Exactly one service name is required."
    show_help
    exit 2
fi

SERVICE="$1"

if ! [[ "${SERVICE}" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
    echo "[ERROR] Invalid service name: ${SERVICE}"
    exit 2
fi

if [[ "${SERVICE}" != *.* ]]; then
    SERVICE="${SERVICE}.service"
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "[ERROR] systemctl is not available."
    exit 2
fi

LOAD_STATE="$(
    systemctl show "${SERVICE}" \
        --property=LoadState \
        --value 2>/dev/null || true
)"

if [[ -z "${LOAD_STATE}" || "${LOAD_STATE}" == "not-found" ]]; then
    echo "[ERROR] Service not found: ${SERVICE}"
    exit 2
fi

ACTIVE_STATE="$(
    systemctl show "${SERVICE}" \
        --property=ActiveState \
        --value
)"

SUB_STATE="$(
    systemctl show "${SERVICE}" \
        --property=SubState \
        --value
)"

UNIT_FILE_STATE="$(
    systemctl show "${SERVICE}" \
        --property=UnitFileState \
        --value
)"

MAIN_PID="$(
    systemctl show "${SERVICE}" \
        --property=MainPID \
        --value
)"

EXEC_STATUS="$(
    systemctl show "${SERVICE}" \
        --property=ExecMainStatus \
        --value
)"

echo "Systemd service report"
echo
echo "Service:          ${SERVICE}"
echo "Load state:       ${LOAD_STATE}"
echo "Active state:     ${ACTIVE_STATE}"
echo "Sub state:        ${SUB_STATE}"
echo "Startup state:    ${UNIT_FILE_STATE:-unknown}"
echo "Main PID:         ${MAIN_PID:-0}"
echo "Last exit status: ${EXEC_STATUS:-unknown}"
echo

if systemctl is-active --quiet "${SERVICE}"; then
    echo "[OK] ${SERVICE} is active."
    exit 0
fi

echo "[WARNING] ${SERVICE} is not active."
echo
echo "Recent status:"
systemctl status "${SERVICE}" \
    --no-pager \
    --lines=10 || true

exit 1