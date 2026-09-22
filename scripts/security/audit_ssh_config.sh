#!/usr/bin/env bash

set -euo pipefail

show_help() {
    echo "Usage: $0"
    echo
    echo "Audits the effective OpenSSH server configuration."
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

if [[ $# -ne 0 ]]; then
    show_help
    exit 2
fi

SSHD_BIN="$(command -v sshd || true)"

if [[ -z "${SSHD_BIN}" ]]; then
    echo "[ERROR] OpenSSH server is not installed."
    exit 2
fi

EFFECTIVE_CONFIG="$(
    "${SSHD_BIN}" -T 2>/dev/null || true
)"

if [[ -z "${EFFECTIVE_CONFIG}" ]]; then
    echo "[ERROR] Unable to read the effective SSH configuration."
    echo "Try running the script with sudo."
    exit 2
fi

WARNINGS=0
FAILURES=0

get_value() {
    local directive="$1"

    awk -v key="${directive}" '
        $1 == key {
            print $2
            exit
        }
    ' <<< "${EFFECTIVE_CONFIG}"
}

check_required() {
    local directive="$1"
    local expected="$2"
    local actual

    actual="$(get_value "${directive}")"

    if [[ "${actual}" == "${expected}" ]]; then
        echo "[OK] ${directive} = ${actual}"
    else
        echo "[FAIL] ${directive} = ${actual:-not-set}; expected ${expected}"
        FAILURES=$((FAILURES + 1))
    fi
}

echo "OpenSSH configuration audit"
echo

check_required "pubkeyauthentication" "yes"
check_required "passwordauthentication" "no"
check_required "kbdinteractiveauthentication" "no"
check_required "permitemptypasswords" "no"

ROOT_LOGIN="$(get_value "permitrootlogin")"

if [[ "${ROOT_LOGIN}" == "no" ]]; then
    echo "[OK] permitrootlogin = no"
else
    echo "[WARNING] permitrootlogin = ${ROOT_LOGIN:-not-set}"
    WARNINGS=$((WARNINGS + 1))
fi

MAX_AUTH_TRIES="$(get_value "maxauthtries")"

if [[ "${MAX_AUTH_TRIES}" =~ ^[0-9]+$ ]] &&
   (( MAX_AUTH_TRIES <= 4 )); then
    echo "[OK] maxauthtries = ${MAX_AUTH_TRIES}"
else
    echo "[WARNING] maxauthtries = ${MAX_AUTH_TRIES:-not-set}"
    WARNINGS=$((WARNINGS + 1))
fi

X11_FORWARDING="$(get_value "x11forwarding")"

if [[ "${X11_FORWARDING}" == "no" ]]; then
    echo "[OK] x11forwarding = no"
else
    echo "[WARNING] x11forwarding = ${X11_FORWARDING:-not-set}"
    WARNINGS=$((WARNINGS + 1))
fi

TCP_FORWARDING="$(get_value "allowtcpforwarding")"

if [[ "${TCP_FORWARDING}" == "no" ]]; then
    echo "[OK] allowtcpforwarding = no"
else
    echo "[INFO] allowtcpforwarding = ${TCP_FORWARDING:-not-set}"
fi

echo
echo "Failures: ${FAILURES}"
echo "Warnings: ${WARNINGS}"

if (( FAILURES > 0 )); then
    exit 2
fi

if (( WARNINGS > 0 )); then
    exit 1
fi

echo "[OK] SSH configuration passed the baseline audit."
exit 0