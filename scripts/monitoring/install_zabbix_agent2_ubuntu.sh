#!/usr/bin/env bash

# Zabbix Agent 2 installation script for Ubuntu
# Supports Ubuntu 20.04, 22.04 and 24.04
# Run with sudo

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Run this script with sudo:"
    echo "sudo bash $0"
    exit 1
fi

source /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    echo "[ERROR] This script supports Ubuntu only."
    exit 1
fi

case "${VERSION_ID}" in
    20.04|22.04|24.04)
        ;;
    *)
        echo "[ERROR] Unsupported Ubuntu version: ${VERSION_ID}"
        exit 1
        ;;
esac

read -rp "Enter the Zabbix Server IP address: " ZABBIX_SERVER

DEFAULT_HOSTNAME="$(hostname -s)"
read -rp "Enter the agent hostname [${DEFAULT_HOSTNAME}]: " ZABBIX_HOSTNAME
ZABBIX_HOSTNAME="${ZABBIX_HOSTNAME:-${DEFAULT_HOSTNAME}}"

if [[ -z "${ZABBIX_SERVER}" ]]; then
    echo "[ERROR] The Zabbix Server address cannot be empty."
    exit 1
fi

echo "Installing required packages..."
apt-get update
apt-get install -y wget ca-certificates

REPOSITORY_PACKAGE="/tmp/zabbix-release.deb"
REPOSITORY_URL="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu${VERSION_ID}_all.deb"

echo "Installing the Zabbix 7.0 repository..."
wget "${REPOSITORY_URL}" -O "${REPOSITORY_PACKAGE}"
dpkg -i "${REPOSITORY_PACKAGE}"

apt-get update

echo "Installing Zabbix Agent 2..."
apt-get install -y zabbix-agent2

CONFIG_FILE="/etc/zabbix/zabbix_agent2.conf"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

echo "Backing up the configuration..."
cp "${CONFIG_FILE}" "${BACKUP_FILE}"

echo "Configuring Zabbix Agent 2..."
sed -i "s|^[#[:space:]]*Server=.*|Server=${ZABBIX_SERVER},127.0.0.1|" "${CONFIG_FILE}"
sed -i "s|^[#[:space:]]*ServerActive=.*|ServerActive=${ZABBIX_SERVER}|" "${CONFIG_FILE}"
sed -i "s|^[#[:space:]]*Hostname=.*|Hostname=${ZABBIX_HOSTNAME}|" "${CONFIG_FILE}"

echo "Starting Zabbix Agent 2..."
systemctl enable --now zabbix-agent2
systemctl restart zabbix-agent2

echo
echo "Installation completed."
echo "Zabbix Server : ${ZABBIX_SERVER}"
echo "Agent hostname: ${ZABBIX_HOSTNAME}"
echo
systemctl status zabbix-agent2 --no-pager