#!/usr/bin/env bash

set -euo pipefail

INSTALLER_URL="https://get.htcondor.org"
INSTALLER_FILE=""

show_help() {
    cat <<'EOF'
Usage:
  install_htcondor_role.sh <role> <central-manager> [mode]

Roles:
  central-manager
  submit
  execute

Modes:
  --dry-run    Download and inspect the proposed installation
               without applying changes. This is the default.
  --apply      Install and configure HTCondor.

Examples:
  ./install_htcondor_role.sh \
      central-manager \
      condor-manager.example.com \
      --dry-run

  sudo ./install_htcondor_role.sh \
      central-manager \
      condor-manager.example.com \
      --apply

  sudo ./install_htcondor_role.sh \
      submit \
      condor-manager.example.com \
      --apply

  sudo ./install_htcondor_role.sh \
      execute \
      condor-manager.example.com \
      --apply
EOF
}

cleanup() {
    unset GET_HTCONDOR_PASSWORD 2>/dev/null || true
    unset POOL_PASSWORD 2>/dev/null || true

    if [[ -n "${INSTALLER_FILE}" &&
          -f "${INSTALLER_FILE}" ]]; then
        rm -f "${INSTALLER_FILE}"
    fi
}

trap cleanup EXIT

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "[ERROR] Invalid number of arguments."
    show_help
    exit 2
fi

ROLE="$1"
CENTRAL_MANAGER="$2"
MODE="${3:---dry-run}"

case "${ROLE}" in
    central-manager)
        ROLE_OPTION="--central-manager"
        ;;
    submit)
        ROLE_OPTION="--submit"
        ;;
    execute)
        ROLE_OPTION="--execute"
        ;;
    *)
        echo "[ERROR] Invalid HTCondor role: ${ROLE}"
        show_help
        exit 2
        ;;
esac

case "${MODE}" in
    --dry-run|--apply)
        ;;
    *)
        echo "[ERROR] Invalid mode: ${MODE}"
        show_help
        exit 2
        ;;
esac

if ! [[ "${CENTRAL_MANAGER}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
    echo "[ERROR] Invalid central manager address."
    exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "[ERROR] curl is required."
    echo "Install it with: sudo apt install curl"
    exit 2
fi

if ! command -v getent >/dev/null 2>&1; then
    echo "[ERROR] getent is required."
    exit 2
fi

if ! getent hosts "${CENTRAL_MANAGER}" >/dev/null 2>&1; then
    echo "[ERROR] Central manager cannot be resolved:"
    echo "        ${CENTRAL_MANAGER}"
    echo
    echo "Configure DNS or /etc/hosts before continuing."
    exit 1
fi

if [[ "${MODE}" == "--apply" && "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Apply mode requires root privileges."
    echo
    echo "Run:"
    echo "  sudo $0 ${ROLE} ${CENTRAL_MANAGER} --apply"
    exit 2
fi

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release

    echo "Detected operating system:"
    echo "  ${PRETTY_NAME:-unknown}"
    echo
else
    echo "[WARNING] Unable to identify the operating system."
fi

POOL_PASSWORD="${GET_HTCONDOR_PASSWORD:-}"

if [[ -z "${POOL_PASSWORD}" ]]; then
    if [[ ! -t 0 ]]; then
        echo "[ERROR] Interactive terminal required for pool password."
        exit 2
    fi

    read -r -s -p "HTCondor pool password: " POOL_PASSWORD
    echo

    read -r -s -p "Confirm pool password: " POOL_PASSWORD_CONFIRM
    echo

    if [[ "${POOL_PASSWORD}" != "${POOL_PASSWORD_CONFIRM}" ]]; then
        echo "[ERROR] Passwords do not match."
        unset POOL_PASSWORD_CONFIRM
        exit 2
    fi

    unset POOL_PASSWORD_CONFIRM
fi

if (( ${#POOL_PASSWORD} < 12 )); then
    echo "[ERROR] Pool password must contain at least 12 characters."
    exit 2
fi

INSTALLER_FILE="$(mktemp)"

echo
echo "Downloading the official HTCondor installer..."

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --proto '=https' \
    --tlsv1.2 \
    "${INSTALLER_URL}" \
    --output "${INSTALLER_FILE}"

chmod 700 "${INSTALLER_FILE}"

echo
echo "Installer SHA-256:"
sha256sum "${INSTALLER_FILE}"

echo
echo "Requested configuration:"
echo "  Role:            ${ROLE}"
echo "  Central manager: ${CENTRAL_MANAGER}"
echo "  Mode:            ${MODE}"
echo

export GET_HTCONDOR_PASSWORD="${POOL_PASSWORD}"

if [[ "${MODE}" == "--dry-run" ]]; then
    echo "[INFO] Running the official installer in dry-run mode."
    echo

    /bin/bash \
        "${INSTALLER_FILE}" \
        "${ROLE_OPTION}" \
        "${CENTRAL_MANAGER}"

    echo
    echo "[OK] Dry-run completed."
    echo "Review the output before using --apply."
    exit 0
fi

read -r -p "Type APPLY to continue: " CONFIRMATION

if [[ "${CONFIRMATION}" != "APPLY" ]]; then
    echo "[INFO] Installation cancelled."
    exit 0
fi

echo
echo "[INFO] Installing HTCondor role: ${ROLE}"

 /bin/bash \
    "${INSTALLER_FILE}" \
    --no-dry-run \
    "${ROLE_OPTION}" \
    "${CENTRAL_MANAGER}"

echo
echo "[INFO] Verifying the HTCondor service..."

if systemctl is-active --quiet condor.service; then
    echo "[OK] condor.service is active."
else
    echo "[WARNING] condor.service is not active."
    systemctl status condor.service \
        --no-pager \
        --lines=20 || true
    exit 1
fi

if command -v condor_config_val >/dev/null 2>&1; then
    echo
    echo "Configured central manager:"
    condor_config_val CONDOR_HOST
fi

echo
echo "[OK] HTCondor role installation completed."
echo
echo "Verify that TCP port 9618 is permitted between"
echo "the required HTCondor pool members."