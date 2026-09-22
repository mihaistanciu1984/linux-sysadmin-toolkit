#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_VERSION="2026-09-22-v1"

MODE="dry-run"
ACTIVATE=false
CONNECTION_NAME=""
INTERFACE_NAME=""
IPV4_ADDRESS=""
IPV4_GATEWAY=""
IPV4_DNS=""

show_help() {
    cat <<'EOF'
Usage:
  configure_static_ip.sh [OPTIONS]

Required options:
  --connection NAME    NetworkManager connection profile
  --interface NAME     Network interface name
  --address CIDR       Static IPv4 address with prefix
  --gateway ADDRESS    Default IPv4 gateway
  --dns ADDRESSES      Comma-separated IPv4 DNS servers

Execution options:
  --dry-run            Display changes without modifying the system
                       This is the default mode.
  --apply              Save the static configuration
  --activate           Activate the modified profile after saving it
                       Requires --apply and an additional confirmation.
  -h, --help           Display this help

Example dry-run:
  configure_static_ip.sh \
      --connection ens4f0 \
      --interface ens4f0 \
      --address 192.0.2.10/24 \
      --gateway 192.0.2.1 \
      --dns 192.0.2.53

Apply without activating:
  sudo configure_static_ip.sh \
      --connection ens4f0 \
      --interface ens4f0 \
      --address 192.0.2.10/24 \
      --gateway 192.0.2.1 \
      --dns 192.0.2.53 \
      --apply

Apply and activate:
  sudo configure_static_ip.sh \
      --connection ens4f0 \
      --interface ens4f0 \
      --address 192.0.2.10/24 \
      --gateway 192.0.2.1 \
      --dns 192.0.2.53 \
      --apply \
      --activate
EOF
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit "${2:-1}"
}

info() {
    printf '[INFO] %s\n' "$1"
}

valid_ipv4() {
    local address="$1"
    local octet
    local -a octets

    IFS='.' read -r -a octets <<< "${address}"

    if [[ ${#octets[@]} -ne 4 ]]; then
        return 1
    fi

    for octet in "${octets[@]}"; do
        if ! [[ "${octet}" =~ ^[0-9]{1,3}$ ]]; then
            return 1
        fi

        if (( 10#${octet} > 255 )); then
            return 1
        fi
    done

    return 0
}

valid_ipv4_cidr() {
    local cidr="$1"
    local address
    local prefix

    if [[ "${cidr}" != */* ]]; then
        return 1
    fi

    address="${cidr%/*}"
    prefix="${cidr##*/}"

    valid_ipv4 "${address}" || return 1

    if ! [[ "${prefix}" =~ ^[0-9]{1,2}$ ]]; then
        return 1
    fi

    if (( prefix < 1 || prefix > 32 )); then
        return 1
    fi

    return 0
}

validate_dns_servers() {
    local dns_list="$1"
    local dns_server
    local -a dns_servers

    IFS=',' read -r -a dns_servers <<< "${dns_list}"

    if [[ ${#dns_servers[@]} -eq 0 ]]; then
        return 1
    fi

    for dns_server in "${dns_servers[@]}"; do
        valid_ipv4 "${dns_server}" || return 1
    done

    return 0
}

require_option_value() {
    local option="$1"
    local value="${2:-}"

    if [[ -z "${value}" || "${value}" == --* ]]; then
        fail "${option} requires a value." 2
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --connection)
            require_option_value "$1" "${2:-}"
            CONNECTION_NAME="$2"
            shift 2
            ;;

        --interface)
            require_option_value "$1" "${2:-}"
            INTERFACE_NAME="$2"
            shift 2
            ;;

        --address)
            require_option_value "$1" "${2:-}"
            IPV4_ADDRESS="$2"
            shift 2
            ;;

        --gateway)
            require_option_value "$1" "${2:-}"
            IPV4_GATEWAY="$2"
            shift 2
            ;;

        --dns)
            require_option_value "$1" "${2:-}"
            IPV4_DNS="$2"
            shift 2
            ;;

        --dry-run)
            MODE="dry-run"
            shift
            ;;

        --apply)
            MODE="apply"
            shift
            ;;

        --activate)
            ACTIVATE=true
            shift
            ;;

        -h|--help)
            show_help
            exit 0
            ;;

        *)
            echo "[ERROR] Unknown option: $1" >&2
            echo
            show_help
            exit 2
            ;;
    esac
done

[[ -n "${CONNECTION_NAME}" ]] ||
    fail "--connection is required." 2

[[ -n "${INTERFACE_NAME}" ]] ||
    fail "--interface is required." 2

[[ -n "${IPV4_ADDRESS}" ]] ||
    fail "--address is required." 2

[[ -n "${IPV4_GATEWAY}" ]] ||
    fail "--gateway is required." 2

[[ -n "${IPV4_DNS}" ]] ||
    fail "--dns is required." 2

if [[ "${ACTIVATE}" == true && "${MODE}" != "apply" ]]; then
    fail "--activate requires --apply." 2
fi

if ! [[ "${INTERFACE_NAME}" =~ ^[A-Za-z0-9_.:-]+$ ]]; then
    fail "Invalid interface name: ${INTERFACE_NAME}" 2
fi

valid_ipv4_cidr "${IPV4_ADDRESS}" ||
    fail "Invalid IPv4 CIDR address: ${IPV4_ADDRESS}" 2

valid_ipv4 "${IPV4_GATEWAY}" ||
    fail "Invalid IPv4 gateway: ${IPV4_GATEWAY}" 2

validate_dns_servers "${IPV4_DNS}" ||
    fail "Invalid DNS server list: ${IPV4_DNS}" 2

if [[ ! -r /etc/os-release ]]; then
    fail "/etc/os-release could not be read."
fi

# shellcheck source=/dev/null
source /etc/os-release

OS_ID="${ID:-unknown}"
OS_MAJOR="${VERSION_ID%%.*}"

if [[ "${OS_ID}" != "ol" || "${OS_MAJOR}" != "8" ]]; then
    fail \
        "This script supports Oracle Linux 8; detected ${PRETTY_NAME:-unknown}."
fi

if ! command -v nmcli >/dev/null 2>&1; then
    fail "nmcli is not installed."
fi

if ! systemctl is-active --quiet NetworkManager; then
    fail "NetworkManager is not active."
fi

if [[ ! -e "/sys/class/net/${INTERFACE_NAME}" ]]; then
    fail "Interface does not exist: ${INTERFACE_NAME}"
fi

if ! nmcli connection show "${CONNECTION_NAME}" \
    >/dev/null 2>&1; then
    fail "Connection profile does not exist: ${CONNECTION_NAME}"
fi

echo "============================================================"
echo "       ORACLE LINUX STATIC IP CONFIGURATION"
echo "============================================================"
echo " Version    : ${SCRIPT_VERSION}"
echo " OS         : ${PRETTY_NAME}"
echo " Connection : ${CONNECTION_NAME}"
echo " Interface  : ${INTERFACE_NAME}"
echo " Address    : ${IPV4_ADDRESS}"
echo " Gateway    : ${IPV4_GATEWAY}"
echo " DNS        : ${IPV4_DNS}"
echo " Mode       : ${MODE}"
echo " Activate   : ${ACTIVATE}"
echo "============================================================"

echo
echo "Current connection configuration:"
echo "------------------------------------------------------------"

nmcli \
    -f connection.id,connection.interface-name,connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns \
    connection show "${CONNECTION_NAME}"

modify_command=(
    nmcli
    connection
    modify
    "${CONNECTION_NAME}"
    connection.interface-name
    "${INTERFACE_NAME}"
    connection.autoconnect
    yes
    ipv4.method
    manual
    ipv4.addresses
    "${IPV4_ADDRESS}"
    ipv4.gateway
    "${IPV4_GATEWAY}"
    ipv4.dns
    "${IPV4_DNS}"
)

echo
echo "Planned command:"
printf ' %q' "${modify_command[@]}"
printf '\n'

if [[ "${MODE}" == "dry-run" ]]; then
    echo
    info "Dry-run completed. No changes were made."

    if [[ "${ACTIVATE}" == false ]]; then
        info "The connection would not be activated automatically."
    fi

    exit 0
fi

if (( EUID != 0 )); then
    fail "Apply mode must run as root."
fi

BACKUP_DIRECTORY="/root/networkmanager-backups"
SAFE_CONNECTION_NAME="$(
    printf '%s' "${CONNECTION_NAME}" |
        tr -c 'A-Za-z0-9._-' '_'
)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="${BACKUP_DIRECTORY}/${SAFE_CONNECTION_NAME}-${TIMESTAMP}.txt"

install \
    -d \
    -o root \
    -g root \
    -m 0700 \
    "${BACKUP_DIRECTORY}"

nmcli connection show "${CONNECTION_NAME}" \
    > "${BACKUP_FILE}"

chmod 0600 "${BACKUP_FILE}"

info "Existing configuration recorded in ${BACKUP_FILE}."

echo
read -r -p "Type APPLY to save the static configuration: " confirmation

if [[ "${confirmation}" != "APPLY" ]]; then
    fail "Operation cancelled."
fi

"${modify_command[@]}"

echo
info "Static configuration saved."

nmcli \
    -f connection.id,connection.interface-name,connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns \
    connection show "${CONNECTION_NAME}"

if [[ "${ACTIVATE}" != true ]]; then
    echo
    info "The profile was not activated."
    info "Activate it later using:"
    echo "sudo nmcli connection up \"${CONNECTION_NAME}\""
    exit 0
fi

echo
echo "[WARNING] Activating the profile can immediately disconnect SSH."
echo "[WARNING] Ensure that console or out-of-band access is available."
echo

read -r -p "Type APPLY again to activate the connection: " activation_confirmation

if [[ "${activation_confirmation}" != "APPLY" ]]; then
    info "Activation cancelled; saved configuration was retained."
    exit 0
fi

nmcli \
    --wait 30 \
    connection up "${CONNECTION_NAME}"

echo
info "Connection activated."

ip -4 address show dev "${INTERFACE_NAME}"
ip route