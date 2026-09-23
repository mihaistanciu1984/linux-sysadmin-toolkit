#!/usr/bin/env bash

# Zabbix upgrade preparation script for Ubuntu 22.04
#
# This script:
#   1. Verifies the operating system and installed Zabbix version.
#   2. Detects MariaDB or MySQL.
#   3. Stops Zabbix Server, Zabbix Agent 2 and Apache.
#   4. Creates a complete Zabbix database backup.
#   5. Backs up the Zabbix configuration and frontend files.
#   6. Verifies that the database backup is not empty.
#
# This script DOES NOT:
#   - change the Zabbix repository;
#   - install or upgrade any packages;
#   - modify the Zabbix database schema;
#   - restart the services after a successful backup.
#
# After the script completes successfully, continue with the manual
# upgrade procedure from the repository update section.
#
# Run with:
#   sudo bash prepare_zabbix_upgrade_ubuntu.sh

set -Eeuo pipefail

BACKUP_COMPLETED=false
SERVICES_STOPPED=()

restart_services_after_error() {
    local exit_code=$?

    if [[ "${BACKUP_COMPLETED}" != "true" ]] &&
       [[ ${#SERVICES_STOPPED[@]} -gt 0 ]]; then
        echo
        echo "[ERROR] The backup was not completed."
        echo "[INFO] Restarting previously active services..."

        for service_name in "${SERVICES_STOPPED[@]}"; do
            systemctl start "${service_name}" || true
        done
    fi

    return "${exit_code}"
}

trap restart_services_after_error EXIT

if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Run this script with sudo:"
    echo "sudo bash $0"
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "[ERROR] The operating system cannot be detected."
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "22.04" ]]; then
    echo "[ERROR] This script supports Ubuntu 22.04 only."
    echo "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

echo "============================================================"
echo "        ZABBIX UPGRADE BACKUP PREPARATION"
echo "============================================================"
echo
echo "This script will stop the Zabbix and Apache services and"
echo "create a database and configuration backup."
echo
echo "It will not upgrade Zabbix."
echo "The services will remain stopped after a successful backup."
echo

echo "Operating system:"
echo "  ${PRETTY_NAME}"

echo
echo "Installed Zabbix Server version:"

if command -v zabbix_server >/dev/null 2>&1; then
    zabbix_server -V | head -n 1
else
    echo "[ERROR] zabbix_server is not installed."
    exit 1
fi

if command -v mariadb-dump >/dev/null 2>&1; then
    DATABASE_TOOL="mariadb-dump"
    DATABASE_SERVICE="mariadb"
elif command -v mysqldump >/dev/null 2>&1; then
    DATABASE_TOOL="mysqldump"
    DATABASE_SERVICE="mysql"
else
    echo "[ERROR] MariaDB or MySQL dump utility was not found."
    exit 1
fi

if ! systemctl is-active --quiet "${DATABASE_SERVICE}"; then
    echo "[ERROR] Database service ${DATABASE_SERVICE} is not running."
    exit 1
fi

echo
echo "Database system:"
echo "  ${DATABASE_TOOL}"

read -rp "Database name [zabbix]: " DATABASE_NAME
DATABASE_NAME="${DATABASE_NAME:-zabbix}"

echo
read -rp "Type BACKUP to stop the services and create the backup: " CONFIRMATION

if [[ "${CONFIRMATION}" != "BACKUP" ]]; then
    echo "[INFO] Operation cancelled."
    exit 0
fi

BACKUP_DIR="/root/zabbix_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

echo
echo "[INFO] Backup directory: ${BACKUP_DIR}"

echo "[INFO] Recording installed package versions..."
dpkg-query -W 'zabbix*' > "${BACKUP_DIR}/installed_zabbix_packages.txt" 2>/dev/null || true
zabbix_server -V > "${BACKUP_DIR}/zabbix_server_version.txt" 2>&1

echo "[INFO] Stopping application services..."

for service_name in zabbix-server zabbix-agent2 apache2; do
    if systemctl is-active --quiet "${service_name}"; then
        systemctl stop "${service_name}"
        SERVICES_STOPPED+=("${service_name}")
        echo "  Stopped: ${service_name}"
    else
        echo "  Not active: ${service_name}"
    fi
done

echo
echo "[INFO] Creating database backup..."
echo "[INFO] Enter the database root password when requested."

"${DATABASE_TOOL}" \
    --user=root \
    --password \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    "${DATABASE_NAME}" \
    > "${BACKUP_DIR}/zabbix_database.sql"

if [[ ! -s "${BACKUP_DIR}/zabbix_database.sql" ]]; then
    echo "[ERROR] The database backup is empty."
    exit 1
fi

echo "[INFO] Backing up Zabbix files..."

if [[ -d /etc/zabbix ]]; then
    cp -a /etc/zabbix "${BACKUP_DIR}/"
fi

if [[ -d /usr/share/zabbix ]]; then
    cp -a /usr/share/zabbix "${BACKUP_DIR}/"
fi

if [[ -f /etc/apache2/conf-available/zabbix.conf ]]; then
    mkdir -p "${BACKUP_DIR}/apache2"
    cp -a \
        /etc/apache2/conf-available/zabbix.conf \
        "${BACKUP_DIR}/apache2/"
fi

sha256sum \
    "${BACKUP_DIR}/zabbix_database.sql" \
    > "${BACKUP_DIR}/SHA256SUMS"

BACKUP_COMPLETED=true

echo
echo "============================================================"
echo "             BACKUP COMPLETED SUCCESSFULLY"
echo "============================================================"
echo
echo "Backup directory:"
echo "  ${BACKUP_DIR}"
echo
echo "Backup contents:"
du -sh "${BACKUP_DIR}"
ls -lah "${BACKUP_DIR}"
echo
echo "The Zabbix and Apache services remain stopped."
echo "Continue with Step 7 of the manual upgrade procedure."
echo
echo "To cancel the upgrade and restart the services, run:"
echo "  systemctl start zabbix-server zabbix-agent2 apache2"