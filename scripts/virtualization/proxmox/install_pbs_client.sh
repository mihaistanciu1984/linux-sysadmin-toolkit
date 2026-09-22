#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_VERSION="2026-09-22-v1"
readonly KEY_URL="https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg"
readonly KEY_SHA256="136673be77aba35dcce385b28737689ad64fd785a797e57897589aed08db6e45"
readonly KEYRING_PATH="/usr/share/keyrings/proxmox-archive-keyring.gpg"
readonly REPOSITORY_FILE="/etc/apt/sources.list.d/pbs-client.sources"
readonly PACKAGE_NAME="proxmox-backup-client-static"

MODE="dry-run"
ALLOW_UBUNTU=false

show_help() {
    cat <<'EOF'
Usage:
  install_pbs_client.sh [OPTIONS]

Options:
  --dry-run          Display the planned installation without changes
                     This is the default mode.
  --apply            Configure the repository and install the client
  --allow-ubuntu     Allow compatibility installation on Ubuntu 22.04/24.04
  -h, --help         Display this help

Supported configurations:
  Debian 12 amd64    Official Bookworm client repository
  Debian 13 amd64    Official Trixie client repository
  Ubuntu 22.04 amd64 Compatibility mode using the static client package
  Ubuntu 24.04 amd64 Compatibility mode using the static client package
EOF
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

info() {
    printf '[INFO] %s\n' "$1"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            MODE="dry-run"
            shift
            ;;

        --apply)
            MODE="apply"
            shift
            ;;

        --allow-ubuntu)
            ALLOW_UBUNTU=true
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

if [[ ! -r /etc/os-release ]]; then
    fail "/etc/os-release could not be read."
fi

# shellcheck source=/dev/null
source /etc/os-release

OS_ID="${ID:-unknown}"
OS_VERSION="${VERSION_ID:-unknown}"

if command -v dpkg >/dev/null 2>&1; then
    ARCHITECTURE="$(dpkg --print-architecture)"
else
    ARCHITECTURE="$(uname -m)"

    if [[ "${ARCHITECTURE}" == "x86_64" ]]; then
        ARCHITECTURE="amd64"
    fi
fi

if [[ "${ARCHITECTURE}" != "amd64" ]]; then
    fail "Only amd64/x86-64 is supported by this installer."
fi

case "${OS_ID}:${OS_VERSION}" in
    debian:12)
        REPOSITORY_SUITE="bookworm"
        INSTALLATION_STATUS="official Debian repository"
        ;;

    debian:13)
        REPOSITORY_SUITE="trixie"
        INSTALLATION_STATUS="official Debian repository"
        ;;

    ubuntu:22.04|ubuntu:24.04)
        if [[ "${ALLOW_UBUNTU}" != true ]]; then
            fail \
                "Ubuntu requires the explicit --allow-ubuntu option."
        fi

        REPOSITORY_SUITE="bookworm"
        INSTALLATION_STATUS="Ubuntu compatibility mode"
        ;;

    *)
        fail \
            "Unsupported operating system: ${OS_ID} ${OS_VERSION}"
        ;;
esac

echo "============================================================"
echo "       PROXMOX BACKUP CLIENT INSTALLATION"
echo "============================================================"
echo " Version     : ${SCRIPT_VERSION}"
echo " OS          : ${PRETTY_NAME:-${OS_ID}}"
echo " Architecture: ${ARCHITECTURE}"
echo " Repository  : ${REPOSITORY_SUITE}"
echo " Package     : ${PACKAGE_NAME}"
echo " Mode        : ${MODE}"
echo " Support mode: ${INSTALLATION_STATUS}"
echo "============================================================"

if command -v proxmox-backup-client >/dev/null 2>&1; then
    info "proxmox-backup-client is already installed."
    proxmox-backup-client version
    exit 0
fi

if [[ "${MODE}" == "dry-run" ]]; then
    echo
    info "No changes were made."
    echo
    echo "The apply operation will:"
    echo "  1. Install curl and CA certificates."
    echo "  2. Download and verify the Proxmox release key."
    echo "  3. Configure the ${REPOSITORY_SUITE} client-only repository."
    echo "  4. Install ${PACKAGE_NAME}."
    echo "  5. Display the installed client version."
    echo
    echo "Apply with:"

    if [[ "${OS_ID}" == "ubuntu" ]]; then
        echo \
            "  sudo bash $0 --apply --allow-ubuntu"
    else
        echo \
            "  sudo bash $0 --apply"
    fi

    exit 0
fi

if (( EUID != 0 )); then
    fail "Run apply mode as root."
fi

if [[ "${OS_ID}" == "ubuntu" ]]; then
    echo
    echo "[WARNING] Ubuntu compatibility mode is not the same as"
    echo "          an officially tested Debian installation."
    echo "          Validate this procedure in a non-production system."
    echo
    read -r -p "Type APPLY to continue: " confirmation

    if [[ "${confirmation}" != "APPLY" ]]; then
        fail "Installation cancelled."
    fi
fi

export DEBIAN_FRONTEND=noninteractive

info "Installing prerequisite packages."

apt-get update
apt-get install -y ca-certificates curl

temporary_key="$(mktemp)"
trap 'rm -f -- "${temporary_key:-}"' EXIT

info "Downloading the Proxmox release key."

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "${KEY_URL}" \
    --output "${temporary_key}"

actual_checksum="$(
    sha256sum "${temporary_key}" |
        awk '{print $1}'
)"

if [[ "${actual_checksum}" != "${KEY_SHA256}" ]]; then
    fail "The Proxmox release key checksum does not match."
fi

info "Release key checksum verified."

install \
    -o root \
    -g root \
    -m 0644 \
    "${temporary_key}" \
    "${KEYRING_PATH}"

info "Configuring the Proxmox Backup client-only repository."

install \
    -o root \
    -g root \
    -m 0644 \
    /dev/null \
    "${REPOSITORY_FILE}"

printf '%s\n' \
    "Types: deb" \
    "URIs: http://download.proxmox.com/debian/pbs-client" \
    "Suites: ${REPOSITORY_SUITE}" \
    "Components: main" \
    "Signed-By: ${KEYRING_PATH}" \
    > "${REPOSITORY_FILE}"

info "Updating the APT package index."

apt-get update

info "Installing ${PACKAGE_NAME}."

apt-get install -y "${PACKAGE_NAME}"

if ! command -v proxmox-backup-client >/dev/null 2>&1; then
    fail "Installation completed but the client command is unavailable."
fi

echo
echo "[OK] Proxmox Backup Client installation completed."
proxmox-backup-client version