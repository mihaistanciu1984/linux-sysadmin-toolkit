#!/usr/bin/env bash

set -u

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
LOG_FILE="/var/log/logout-events.log"
MODE="${1:---dry-run}"

if [[ "${MODE}" != "--dry-run" && "${MODE}" != "--apply" ]]; then
    echo "Usage: $0 [--dry-run|--apply]"
    exit 2
fi

UID_MIN="$(awk '/^[[:space:]]*UID_MIN[[:space:]]/ {print $2}' /etc/login.defs)"
UID_MIN="${UID_MIN:-1000}"

get_logged_users() {
    loginctl list-users --no-legend |
        awk -v minimum="${UID_MIN}" '$1 >= minimum {print $2}' |
        sort -u
}

if [[ "${MODE}" == "--dry-run" ]]; then
    echo "Users that would be logged out:"
    get_logged_users
    exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Run the script as root."
    exit 1
fi

wall "ATTENTION: All logged-in users will be logged out in 1 minute for maintenance."

sleep 60

while read -r username; do
    [[ -z "${username}" ]] && continue

    echo "User ${username} logged out at $(date --iso-8601=seconds)" >> "${LOG_FILE}"
    loginctl terminate-user "${username}"
done < <(get_logged_users)