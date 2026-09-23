#!/usr/bin/env bash

set -euo pipefail

show_help() {
    cat <<'EOF'
Install XRDP with the XFCE desktop on Ubuntu 24.04.

Usage:
  sudo ./install_xrdp_ubuntu.sh <linux-user> [allowed-network]

Examples:
  sudo ./install_xrdp_ubuntu.sh example-user
  sudo ./install_xrdp_ubuntu.sh example-user 192.0.2.0/24

Arguments:
  linux-user       Existing Linux user used for the RDP connection.
  allowed-network  Optional IP address or network allowed through UFW.

The script does not enable UFW automatically.
If no network is provided, no firewall rule is created.
EOF
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Run this script with sudo."
    exit 1
fi

TARGET_USER="${1:-}"
ALLOWED_NETWORK="${2:-}"

if [[ -z "${TARGET_USER}" ]]; then
    echo "[ERROR] A Linux username is required."
    echo
    show_help
    exit 2
fi

if ! id "${TARGET_USER}" >/dev/null 2>&1; then
    echo "[ERROR] Linux user does not exist: ${TARGET_USER}"
    exit 2
fi

if [[ ! -f /etc/os-release ]]; then
    echo "[ERROR] Cannot identify the operating system."
    exit 2
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "[ERROR] This script supports Ubuntu only."
    exit 2
fi

if [[ "${VERSION_ID:-}" != "24.04" ]]; then
    echo "[WARNING] This script was designed for Ubuntu 24.04."
    read -r -p "Continue on Ubuntu ${VERSION_ID:-unknown}? [y/N]: " CONFIRMATION

    if [[ ! "${CONFIRMATION}" =~ ^[Yy]$ ]]; then
        echo "[INFO] Installation cancelled."
        exit 0
    fi
fi

TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"

if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
    echo "[ERROR] Home directory not found for ${TARGET_USER}."
    exit 2
fi

echo "============================================================"
echo "             XRDP INSTALLATION"
echo "============================================================"
echo "Ubuntu version : ${VERSION_ID:-unknown}"
echo "RDP user       : ${TARGET_USER}"
echo "Home directory : ${TARGET_HOME}"
echo "Allowed network: ${ALLOWED_NETWORK:-not configured}"
echo "============================================================"

echo
echo "[INFO] Updating the package index..."
apt-get update

echo
echo "[INFO] Installing XFCE, XRDP and the Xorg backend..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 \
    xfce4-goodies \
    xrdp \
    xorgxrdp

echo
echo "[INFO] Granting XRDP access to the system TLS certificate..."
usermod -aG ssl-cert xrdp

SESSION_FILE="${TARGET_HOME}/.xsession"

if [[ -f "${SESSION_FILE}" ]]; then
    SESSION_BACKUP="${SESSION_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "${SESSION_FILE}" "${SESSION_BACKUP}"
    chown "${TARGET_USER}:${TARGET_USER}" "${SESSION_BACKUP}"

    echo "[INFO] Existing .xsession backed up to:"
    echo "       ${SESSION_BACKUP}"
fi

echo "startxfce4" > "${SESSION_FILE}"
chown "${TARGET_USER}:${TARGET_USER}" "${SESSION_FILE}"
chmod 644 "${SESSION_FILE}"

echo
echo "[INFO] Enabling and restarting XRDP..."
systemctl enable xrdp
systemctl restart xrdp

if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS="$(ufw status | head -n 1 || true)"

    if [[ "${UFW_STATUS}" == *"active"* ]]; then
        if [[ -n "${ALLOWED_NETWORK}" ]]; then
            echo
            echo "[INFO] Allowing RDP from ${ALLOWED_NETWORK}..."
            ufw allow from "${ALLOWED_NETWORK}" to any port 3389 proto tcp
        else
            echo
            echo "[WARNING] UFW is active, but no allowed network was provided."
            echo "[INFO] Port 3389 was not opened."
        fi
    else
        echo
        echo "[INFO] UFW is installed but inactive."
        echo "[INFO] The script will not enable it automatically."
    fi
else
    echo
    echo "[INFO] UFW is not installed. No firewall changes were made."
fi

echo
echo "[INFO] Checking the XRDP service..."

if ! systemctl is-active --quiet xrdp; then
    echo "[ERROR] XRDP is not running."
    systemctl status xrdp --no-pager || true
    exit 1
fi

if ss -lnt | grep -qE '(^|[[:space:]])[^[:space:]]*:3389[[:space:]]'; then
    echo "[OK] XRDP is listening on TCP port 3389."
else
    echo "[WARNING] XRDP is running, but port 3389 was not detected."
fi

PASSWORD_STATUS="$(passwd -S "${TARGET_USER}" 2>/dev/null | awk '{print $2}' || true)"

if [[ "${PASSWORD_STATUS}" == "L" ]]; then
    echo
    echo "[WARNING] The account ${TARGET_USER} appears to be locked."
    echo "Set a password before using XRDP:"
    echo "  sudo passwd ${TARGET_USER}"
fi

echo
echo "============================================================"
echo "XRDP installation completed."
echo
echo "Connect with:"
echo "  Server   : $(hostname -I | awk '{print $1}')"
echo "  Port     : 3389"
echo "  Username : ${TARGET_USER}"
echo "  Session  : Xorg"
echo
echo "Use the Linux account password for authentication."
echo "============================================================"