#!/usr/bin/env bash

set -uo pipefail

SCRIPT_VERSION="2026-09-22-v1"
MANAGER=""
MIN_SLOTS=0
CONDOR_PORT=9618
FAILURES=0
WARNINGS=0

show_help() {
    cat <<'EOF'
Usage:
  check_htcondor_pool.sh [OPTIONS]

Options:
  --manager HOST       Expected HTCondor Central Manager hostname
  --min-slots NUMBER   Minimum number of execution slots required
                       Default: 0
  --port PORT          Central Manager TCP port
                       Default: 9618
  -h, --help           Display this help

Examples:
  check_htcondor_pool.sh

  check_htcondor_pool.sh \
      --manager condor-manager.example.com

  check_htcondor_pool.sh \
      --manager condor-manager.example.com \
      --min-slots 2
EOF
}

print_ok() {
    printf '[OK] %s\n' "$1"
}

print_warning() {
    printf '[WARNING] %s\n' "$1"
    WARNINGS=$((WARNINGS + 1))
}

print_failure() {
    printf '[FAIL] %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        print_failure "Required command not found: ${command_name}"
        return 1
    fi

    return 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manager)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                echo "[ERROR] --manager requires a hostname."
                exit 2
            fi

            MANAGER="$2"
            shift 2
            ;;

        --min-slots)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                echo "[ERROR] --min-slots requires a number."
                exit 2
            fi

            MIN_SLOTS="$2"
            shift 2
            ;;

        --port)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                echo "[ERROR] --port requires a number."
                exit 2
            fi

            CONDOR_PORT="$2"
            shift 2
            ;;

        -h|--help)
            show_help
            exit 0
            ;;

        *)
            echo "[ERROR] Unknown option: $1"
            echo
            show_help
            exit 2
            ;;
    esac
done

if ! [[ "${MIN_SLOTS}" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] --min-slots must contain a non-negative integer."
    exit 2
fi

if ! [[ "${CONDOR_PORT}" =~ ^[0-9]+$ ]] ||
    (( CONDOR_PORT < 1 || CONDOR_PORT > 65535 )); then
    echo "[ERROR] --port must be between 1 and 65535."
    exit 2
fi

echo "============================================================"
echo "                 HTCONDOR POOL CHECK"
echo "============================================================"
echo " Version       : ${SCRIPT_VERSION}"
echo " Expected CM   : ${MANAGER:-not specified}"
echo " Minimum slots : ${MIN_SLOTS}"
echo " TCP port      : ${CONDOR_PORT}"
echo "============================================================"
echo

REQUIRED_COMMANDS=(
    systemctl
    timeout
    getent
    condor_version
    condor_config_val
    condor_status
    condor_q
)

for required_command in "${REQUIRED_COMMANDS[@]}"; do
    require_command "${required_command}"
done

if (( FAILURES > 0 )); then
    echo
    echo "[ERROR] Required commands are missing."
    echo "[INFO] Run this script on a system with HTCondor installed."
    exit 2
fi

echo
echo "[1/6] Checking HTCondor service"
echo "------------------------------------------------------------"

if systemctl is-active --quiet condor.service; then
    print_ok "condor.service is active."
else
    print_failure "condor.service is not active."
    echo "[INFO] Inspect it with:"
    echo "       sudo systemctl status condor --no-pager"
    echo "       sudo journalctl -u condor -n 100 --no-pager"
fi

echo
echo "[2/6] Checking installed version"
echo "------------------------------------------------------------"

if VERSION_OUTPUT="$(condor_version 2>&1)"; then
    print_ok "HTCondor is installed."
    printf '%s\n' "${VERSION_OUTPUT}" | sed -n '1,2p'
else
    print_failure "Unable to obtain the HTCondor version."
    printf '%s\n' "${VERSION_OUTPUT}"
fi

echo
echo "[3/6] Checking effective configuration"
echo "------------------------------------------------------------"

CONFIGURED_MANAGER="$(
    condor_config_val CONDOR_HOST 2>/dev/null |
        tr -d '\r' |
        xargs
)"

DAEMON_LIST="$(
    condor_config_val DAEMON_LIST 2>/dev/null |
        tr -d '\r' |
        xargs
)"

LOCAL_CONFIG_DIR="$(
    condor_config_val LOCAL_CONFIG_DIR 2>/dev/null |
        tr -d '\r' |
        xargs
)"

if [[ -n "${CONFIGURED_MANAGER}" ]]; then
    print_ok "CONDOR_HOST=${CONFIGURED_MANAGER}"
else
    print_failure "CONDOR_HOST is empty or unavailable."
fi

if [[ -n "${DAEMON_LIST}" ]]; then
    print_ok "DAEMON_LIST=${DAEMON_LIST}"
else
    print_failure "DAEMON_LIST is empty or unavailable."
fi

if [[ -n "${LOCAL_CONFIG_DIR}" ]]; then
    print_ok "LOCAL_CONFIG_DIR=${LOCAL_CONFIG_DIR}"
else
    print_warning "LOCAL_CONFIG_DIR could not be determined."
fi

if [[ -n "${MANAGER}" ]] &&
    [[ "${CONFIGURED_MANAGER}" != *"${MANAGER}"* ]]; then
    print_warning \
        "Configured Central Manager does not match ${MANAGER}."
fi

echo
echo "[4/6] Checking DNS and TCP connectivity"
echo "------------------------------------------------------------"

if [[ -n "${MANAGER}" ]]; then
    if getent hosts "${MANAGER}" >/dev/null 2>&1; then
        RESOLVED_ADDRESS="$(
            getent ahostsv4 "${MANAGER}" |
                awk 'NR == 1 {print $1}'
        )"

        print_ok \
            "${MANAGER} resolves to ${RESOLVED_ADDRESS:-an address}."
    else
        print_failure "Unable to resolve ${MANAGER}."
    fi

    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 5 "${MANAGER}" "${CONDOR_PORT}" \
            >/dev/null 2>&1; then
            print_ok \
                "${MANAGER}:${CONDOR_PORT} is reachable."
        else
            print_failure \
                "${MANAGER}:${CONDOR_PORT} is not reachable."
        fi
    else
        if timeout 5 bash -c \
            'cat < /dev/null > /dev/tcp/"$1"/"$2"' \
            _ "${MANAGER}" "${CONDOR_PORT}" \
            >/dev/null 2>&1; then
            print_ok \
                "${MANAGER}:${CONDOR_PORT} is reachable."
        else
            print_failure \
                "${MANAGER}:${CONDOR_PORT} is not reachable."
        fi
    fi
else
    print_warning \
        "Direct DNS/TCP test skipped; use --manager HOST to enable it."
fi

echo
echo "[5/6] Checking registered HTCondor masters"
echo "------------------------------------------------------------"

if MASTER_OUTPUT="$(
    timeout 15 condor_status -master -af Name 2>&1
)"; then
    MASTER_COUNT="$(
        printf '%s\n' "${MASTER_OUTPUT}" |
            sed '/^[[:space:]]*$/d' |
            wc -l |
            tr -d ' '
    )"

    if (( MASTER_COUNT > 0 )); then
        print_ok "${MASTER_COUNT} HTCondor master(s) registered."
        printf '%s\n' "${MASTER_OUTPUT}" |
            sed '/^[[:space:]]*$/d' |
            sed 's/^/       - /'
    else
        print_failure "No HTCondor masters are registered."
    fi
else
    print_failure "condor_status could not contact the pool."
    printf '%s\n' "${MASTER_OUTPUT}"
fi

echo
echo "[6/6] Checking execution slots and job queue"
echo "------------------------------------------------------------"

if SLOT_OUTPUT="$(
    timeout 15 condor_status -af Name State Activity 2>&1
)"; then
    SLOT_COUNT="$(
        printf '%s\n' "${SLOT_OUTPUT}" |
            sed '/^[[:space:]]*$/d' |
            wc -l |
            tr -d ' '
    )"

    if (( SLOT_COUNT >= MIN_SLOTS )); then
        print_ok \
            "${SLOT_COUNT} slot(s) found; required minimum is ${MIN_SLOTS}."
    else
        print_failure \
            "${SLOT_COUNT} slot(s) found; required minimum is ${MIN_SLOTS}."
    fi

    if (( SLOT_COUNT > 0 )); then
        echo
        echo "Execution slots:"
        printf '%s\n' "${SLOT_OUTPUT}" |
            sed '/^[[:space:]]*$/d' |
            sed 's/^/  /'
    fi
else
    print_failure "Unable to retrieve the execution slots."
    printf '%s\n' "${SLOT_OUTPUT}"
fi

echo
echo "Job queue:"
if ! timeout 15 condor_q; then
    print_failure "Unable to query the HTCondor job queue."
fi

echo
echo "============================================================"
echo "                       RESULT"
echo "============================================================"
echo " Failures : ${FAILURES}"
echo " Warnings : ${WARNINGS}"
echo "============================================================"

if (( FAILURES > 0 )); then
    echo "[FAIL] The HTCondor pool did not pass all checks."
    exit 1
fi

echo "[OK] The HTCondor pool passed all required checks."
exit 0