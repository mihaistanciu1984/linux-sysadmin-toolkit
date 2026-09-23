#!/usr/bin/env bash

set -Eeuo pipefail

# ---------------------------------------------------------
# PBS LOCAL DATASTORE COPY
#
# This script copies all accessible backup groups and
# snapshots from one local PBS datastore to another.
#
# It does NOT delete snapshots from the source datastore.
# Verify the destination before deleting source backups.
# ---------------------------------------------------------

SOURCE_DATASTORE="backup1"
DEST_DATASTORE="backup2"
SYNC_JOB_ID="copy-backup1-to-backup2"

# Set to false only after reviewing the configuration.
DRY_RUN=true

LOG_FILE="/var/log/pbs-datastore-copy.log"

log_message() {
    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$1" |
        tee -a "$LOG_FILE"
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Run this script as root or with sudo."
    exit 1
fi

if ! command -v proxmox-backup-manager >/dev/null 2>&1; then
    echo "[ERROR] proxmox-backup-manager is not installed."
    exit 1
fi

if [[ "$SOURCE_DATASTORE" == "$DEST_DATASTORE" ]]; then
    echo "[ERROR] Source and destination must be different."
    exit 1
fi

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log_message "Source datastore: ${SOURCE_DATASTORE}"
log_message "Destination datastore: ${DEST_DATASTORE}"
log_message "Sync job ID: ${SYNC_JOB_ID}"

echo
echo "Configured PBS datastores:"
proxmox-backup-manager datastore list

if [[ "$DRY_RUN" == true ]]; then
    echo
    log_message "[DRY RUN] No sync job was created."
    echo
    echo "The following commands would be executed:"
    echo
    printf '%q ' \
        proxmox-backup-manager sync-job create \
        "$SYNC_JOB_ID" \
        --remote-store "$SOURCE_DATASTORE" \
        --store "$DEST_DATASTORE" \
        --remove-vanished false
    echo
    printf '%q ' \
        proxmox-backup-manager sync-job run \
        "$SYNC_JOB_ID"
    echo
    exit 0
fi

if proxmox-backup-manager sync-job show \
    "$SYNC_JOB_ID" >/dev/null 2>&1; then
    log_message "[ERROR] Sync job ${SYNC_JOB_ID} already exists."
    log_message "Review it with: proxmox-backup-manager sync-job show ${SYNC_JOB_ID}"
    exit 1
fi

log_message "Creating the local sync job."

proxmox-backup-manager sync-job create \
    "$SYNC_JOB_ID" \
    --remote-store "$SOURCE_DATASTORE" \
    --store "$DEST_DATASTORE" \
    --remove-vanished false

log_message "Starting the datastore copy."

if proxmox-backup-manager sync-job run \
    "$SYNC_JOB_ID" 2>&1 |
    tee -a "$LOG_FILE"; then

    log_message "[OK] Datastore synchronization completed."
    log_message "Verify all snapshots on ${DEST_DATASTORE}."
    log_message "The source datastore was not modified."
else
    log_message "[ERROR] Datastore synchronization failed."
    log_message "The source snapshots were not deleted."
    exit 1
fi

echo
echo "Next steps:"
echo "1. Check the destination datastore in the PBS web interface."
echo "2. Run a verification job on ${DEST_DATASTORE}."
echo "3. Test restoring at least one backup."
echo "4. Delete source snapshots only after successful verification."