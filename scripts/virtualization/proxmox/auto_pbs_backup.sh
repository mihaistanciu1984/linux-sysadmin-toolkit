#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_VERSION="2026-09-22-v1"
readonly DEFAULT_CONFIG_FILE="/etc/proxmox-backup-client/backup.env"
readonly CONFIG_FILE="${PBS_BACKUP_CONFIG:-${DEFAULT_CONFIG_FILE}}"
readonly PBS_CLIENT="${PBS_CLIENT_BIN:-/usr/bin/proxmox-backup-client}"

DRY_RUN=false

show_help() {
    cat <<'EOF'
Usage:
  auto_pbs_backup.sh [--dry-run]

Options:
  --dry-run    Validate the backup operation without uploading data
  -h, --help   Display this help

Configuration:
  /etc/proxmox-backup-client/backup.env

Override configuration path:
  PBS_BACKUP_CONFIG=/path/to/backup.env auto_pbs_backup.sh
EOF
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

log() {
    printf '[%s] %s\n' \
        "$(date --iso-8601=seconds)" \
        "$1"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;

        -h|--help)
            show_help
            exit 0
            ;;

        *)
            echo "[ERROR] Unknown option: $1" >&2
            show_help
            exit 2
            ;;
    esac
done

if (( EUID != 0 )); then
    fail "Run this script as root."
fi

if [[ ! -x "${PBS_CLIENT}" ]]; then
    fail "proxmox-backup-client was not found at ${PBS_CLIENT}."
fi

if ! command -v flock >/dev/null 2>&1; then
    fail "flock is required. Install the util-linux package."
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
    fail "Configuration file not found: ${CONFIG_FILE}"
fi

if find "${CONFIG_FILE}" -prune -perm /077 -print -quit |
    grep -q .; then
    fail "Configuration file permissions are too open: ${CONFIG_FILE}"
fi

# The configuration file must be owned by root and have mode 0600.
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

required_variables=(
    PBS_REPOSITORY
    PBS_PASSWORD_FILE
    BACKUP_ID
    SOURCE_DIR
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        fail "Required variable is missing: ${variable_name}"
    fi
done

ARCHIVE_NAME="${ARCHIVE_NAME:-etc}"
LOG_FILE="${LOG_FILE:-/var/log/proxmox-backup-client/config-backup.log}"
LOCK_FILE="${LOCK_FILE:-/run/lock/auto-pbs-backup.lock}"

if [[ ! "${ARCHIVE_NAME}" =~ ^[A-Za-z0-9_-]+$ ]]; then
    fail "ARCHIVE_NAME contains unsupported characters."
fi

if [[ ! "${BACKUP_ID}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    fail "BACKUP_ID contains unsupported characters."
fi

if [[ ! -d "${SOURCE_DIR}" ]]; then
    fail "Source directory does not exist: ${SOURCE_DIR}"
fi

if [[ ! -f "${PBS_PASSWORD_FILE}" ]]; then
    fail "PBS password/token file does not exist: ${PBS_PASSWORD_FILE}"
fi

if find "${PBS_PASSWORD_FILE}" -prune -perm /077 -print -quit |
    grep -q .; then
    fail "PBS password/token file permissions must be 0600."
fi

export PBS_REPOSITORY
export PBS_PASSWORD_FILE

if [[ -n "${PBS_FINGERPRINT:-}" ]]; then
    export PBS_FINGERPRINT
fi

install -d \
    -o root \
    -g root \
    -m 0750 \
    "$(dirname "${LOG_FILE}")"

touch "${LOG_FILE}"
chmod 0600 "${LOG_FILE}"

exec >>"${LOG_FILE}" 2>&1

exec 9>"${LOCK_FILE}"

if ! flock -n 9; then
    log "Another backup process is already running."
    exit 1
fi

on_exit() {
    local exit_code=$?

    if (( exit_code == 0 )); then
        log "Backup process finished successfully."
    else
        log "Backup process failed with exit code ${exit_code}."
    fi
}

trap on_exit EXIT

log "Starting PBS backup."
log "Script version: ${SCRIPT_VERSION}"
log "Backup ID: ${BACKUP_ID}"
log "Archive: ${ARCHIVE_NAME}.pxar"
log "Source: ${SOURCE_DIR}"
log "Dry run: ${DRY_RUN}"

backup_command=(
    "${PBS_CLIENT}"
    backup
    "${ARCHIVE_NAME}.pxar:${SOURCE_DIR}"
    --backup-type host
    --backup-id "${BACKUP_ID}"
)

if [[ "${DRY_RUN}" == true ]]; then
    backup_command+=(--dry-run)
fi

"${backup_command[@]}"