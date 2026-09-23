#!/bin/bash
# =============================================
# Zabbix Agent 2 Installation Script for Oracle Linux 8/9
# Works for Zabbix 7.0 (LTS)
# Run as root
# =============================================

set -e  # Exit on any error

# ── Check root ────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root!"
    exit 1
fi

echo "=== Zabbix Agent 2 Installer for Oracle Linux ==="

# ── Detect Oracle Linux version ───────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_VERSION=${VERSION_ID%%.*}  # Get major version (8 or 9)
else
    echo "Error: Cannot detect OS version!"
    exit 1
fi

if [[ "$OS_VERSION" != "8" && "$OS_VERSION" != "9" ]]; then
    echo "This script supports Oracle Linux 8 and 9 only. Detected: $OS_VERSION"
    exit 1
fi

echo "Detected Oracle Linux $OS_VERSION"

# ── 1. Install Zabbix repository ──────────────
# Oracle Linux is 100% RHEL compatible — using RHEL repo
echo "Adding Zabbix 7.0 repository (RHEL-compatible)..."
rpm -Uvh --replacepkgs https://repo.zabbix.com/zabbix/7.0/rhel/${OS_VERSION}/x86_64/zabbix-release-latest-7.0.el${OS_VERSION}.noarch.rpm || true

# Verify repo was added
if ! dnf repolist | grep -qi zabbix; then
    echo "Error: Zabbix repository was not added correctly!"
    exit 1
fi

echo "Zabbix repository added successfully."

# Clean cache
dnf clean all

# ── 2. Install Zabbix Agent 2 ─────────────────
echo "Installing zabbix-agent2..."
dnf install -y zabbix-agent2

# ── 3. Backup original configuration ──────────
echo "Backing up configuration..."
if [ -f /etc/zabbix/zabbix_agent2.conf ]; then
    cp /etc/zabbix/zabbix_agent2.conf \
       /etc/zabbix/zabbix_agent2.conf.bak.$(date +%Y%m%d-%H%M)
fi

# ── 4. Prompt for Zabbix server IP and hostname ──
read -rp "Enter Zabbix Server IP: " ZABBIX_SERVER
read -rp "Enter Hostname for this host (as it will appear in Zabbix): " ZABBIX_HOSTNAME

if [[ -z "$ZABBIX_SERVER" || -z "$ZABBIX_HOSTNAME" ]]; then
    echo "Error: Zabbix Server IP and Hostname cannot be empty!"
    exit 1
fi

# ── 5. Create configuration file ──────────────
echo "Configuring /etc/zabbix/zabbix_agent2.conf..."
cat > /etc/zabbix/zabbix_agent2.conf << EOF
# Zabbix Agent 2 Configuration for Oracle Linux
PidFile=/run/zabbix/zabbix_agent2.pid
LogType=file
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
DebugLevel=3

# Server (passive checks)
Server=${ZABBIX_SERVER},127.0.0.1

# Listen port
ListenPort=10050

# Active checks
ServerActive=${ZABBIX_SERVER}

# Hostname (must match exactly what you add in Zabbix frontend)
Hostname=${ZABBIX_HOSTNAME}

RefreshActiveChecks=120
BufferSend=600
BufferSize=1000
EnablePersistentBuffer=1
PersistentBufferPeriod=1h
PersistentBufferFile=/var/spool/zabbix/agent.db
Timeout=30
Include=/etc/zabbix/zabbix_agent2.d/*.conf
UnsafeUserParameters=1
ControlSocket=/tmp/agent.sock
EOF

echo "Configuration file created."

# ── 6. Create persistent buffer directory ─────
echo "Creating persistent buffer directory..."
mkdir -p /var/spool/zabbix
chown zabbix:zabbix /var/spool/zabbix
chmod 755 /var/spool/zabbix

# ── 7. Configure firewall ─────────────────────
echo "Opening firewall port 10050..."
if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=10050/tcp
    firewall-cmd --reload
    echo "Firewall port 10050 opened."
else
    echo "Warning: firewall-cmd not found, skipping firewall configuration."
fi

# ── 8. SELinux check ──────────────────────────
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "SELinux status: $SELINUX_STATUS"
    if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
        echo "Warning: SELinux is Enforcing — if agent fails, run:"
        echo "   setsebool -P zabbix_can_network on"
    fi
fi

# ── 9. Enable and start the service ───────────
echo "Enabling and starting zabbix-agent2..."
systemctl daemon-reload
systemctl enable --now zabbix-agent2
systemctl status zabbix-agent2 --no-pager

# ── 10. Final summary ─────────────────────────
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=== Installation completed! ==="
echo ""
echo "Configuration:"
echo "   Zabbix Server : ${ZABBIX_SERVER}"
echo "   Hostname      : ${ZABBIX_HOSTNAME}"
echo "   Host IP       : ${HOST_IP}"
echo ""
echo "Check logs:"
echo "   tail -f /var/log/zabbix/zabbix_agent2.log"
echo ""
echo "Test connection from Zabbix server:"
echo "   zabbix_get -s ${HOST_IP} -k agent.ping"
echo ""
echo "Don't forget to add the host in the Zabbix frontend with Hostname: ${ZABBIX_HOSTNAME}"
