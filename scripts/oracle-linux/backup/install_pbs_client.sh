#!/usr/bin/env bash

set -euo pipefail

VERSION="4.2.0-1"
PACKAGE="proxmox-backup-client-static_${VERSION}_amd64.deb"
DOWNLOAD_URL="https://download.proxmox.com/debian/pbs-client/dists/trixie/main/binary-amd64/${PACKAGE}"
INSTALL_PATH="/usr/local/bin/proxmox-backup-client"

if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Run the script with sudo:"
    echo "sudo bash $0"
    exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "[ERROR] The static client requires x86-64."
    exit 1
fi

if [[ -r /etc/os-release ]]; then
    source /etc/os-release

    if [[ "${ID:-}" != "ol" || "${VERSION_ID%%.*}" != "8" ]]; then
        echo "[ERROR] This procedure is intended for Oracle Linux 8."
        exit 1
    fi
fi

echo "### Installing required packages ###"
dnf install -y curl binutils tar zstd

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "### Downloading Proxmox Backup Client ${VERSION} ###"
curl --fail --location --retry 3 \
    "${DOWNLOAD_URL}" \
    --output "${WORK_DIR}/${PACKAGE}"

echo "### Extracting the Debian package ###"
cd "${WORK_DIR}"
ar x "${PACKAGE}"

if [[ ! -f data.tar.zst ]]; then
    echo "[ERROR] data.tar.zst was not found in the package."
    exit 1
fi

mkdir extracted
zstd --decompress --stdout data.tar.zst |
    tar -xf - -C extracted

CLIENT_BINARY="$(
    find extracted \
        -type f \
        -name proxmox-backup-client \
        -print \
        -quit
)"

if [[ -z "${CLIENT_BINARY}" ]]; then
    echo "[ERROR] proxmox-backup-client was not found."
    exit 1
fi

echo "### Installing the client ###"
install -m 0755 "${CLIENT_BINARY}" "${INSTALL_PATH}"

echo "### Checking the installed version ###"
"${INSTALL_PATH}" version

echo "### Installation completed successfully ###"