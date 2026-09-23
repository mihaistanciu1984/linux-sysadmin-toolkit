# Linux System Administration Toolkit

A practical collection of Linux administration procedures, troubleshooting guides and reusable Bash tools.

The repository is intended as a reference for system administrators, infrastructure engineers and DevOps professionals working with Linux servers.

 ## Current content

| Category | Procedure | Tool |
|---|---|---|
| Database | [Reset MySQL or MariaDB root password](docs/database/reset-mysql-mariadb-root-password.md) | Manual recovery procedure |
| HTCondor | [HTCondor cluster installation](docs/htcondor/cluster-installation.md) | [Role installer](scripts/htcondor/install_htcondor_role.sh) |
| HTCondor | [Role configuration and validation](docs/htcondor/role-configuration-validation.md) | [Pool checker](scripts/htcondor/check_htcondor_pool.sh) |
| Monitoring | [Glances system monitoring](docs/monitoring/glances.md) | Planned |
| Monitoring | [Migrate Zabbix Server to a new host](docs/monitoring/zabbix-server-migration.md) | Manual procedure |
| Monitoring | [Upgrade Zabbix Server 7.0 on Ubuntu](docs/monitoring/zabbix-server-upgrade-ubuntu.md) | [Upgrade preparation and backup](scripts/monitoring/prepare_zabbix_upgrade_ubuntu.sh) |
| Monitoring | [Zabbix Agent 2 on Ubuntu](docs/monitoring/zabbix-agent2-ubuntu.md) | [Ubuntu installer](scripts/monitoring/install_zabbix_agent2_ubuntu.sh) |
| Networking | [Connectivity troubleshooting](docs/networking/connectivity-troubleshooting.md) | [Connectivity checker](scripts/networking/check_connectivity.sh) |
| Networking | [DNS troubleshooting](docs/networking/dns-troubleshooting.md) | [DNS checker](scripts/networking/check_dns.sh) |
| Networking | [Samba installation and file sharing](docs/networking/samba-file-sharing.md) | Configuration commands |
| Networking | [Share a local USB device with a remote VM](docs/networking/usb-sharing-through-jump-host.md) | Manual procedure |
| Networking | [Mount remote directories with SSHFS](docs/networking/sshfs-mount.md) | SSHFS commands |
| Oracle Linux / Backup | [Install Proxmox Backup Client](docs/oracle-linux/backup/install-pbs-client.md) | [PBS client installer](scripts/oracle-linux/backup/install_pbs_client.sh) |
| Oracle Linux / Database | [Install Oracle Database XE 21c](docs/oracle-linux/database/install-oracle-database-xe.md) | Commands included |
| Oracle Linux / Networking | [Static IPv4 configuration](docs/oracle-linux/networking/static-ip.md) | [Static IP configuration tool](scripts/oracle-linux/networking/configure_static_ip.sh) |
| Oracle Linux / System | [Enable GNOME Desktop](docs/oracle-linux/system/enable-gui.md) | Commands included |
| Oracle Linux / System | [Scheduled user logout](docs/oracle-linux/system/scheduled-user-logout.md) | [User logout tool](scripts/oracle-linux/system/logout_logged_users.sh) |
| Remote Access | [XRDP on Ubuntu 24.04](docs/remote-access/xrdp-ubuntu-24.04.md) | [XRDP installer](scripts/remote-access/install_xrdp_ubuntu.sh) |
| Security | [OpenSSH server hardening](docs/security/ssh-hardening.md) | [SSH configuration audit](scripts/security/audit_ssh_config.sh) |
| Security | [UFW firewall on Ubuntu](docs/security/ufw-firewall-ubuntu.md) | Configuration commands |
| Storage | [Disk usage troubleshooting](docs/system/disk-usage.md) | [Disk usage checker](scripts/system/check_disk_usage.sh) |
| System | [CPU and load troubleshooting](docs/system/cpu-troubleshooting.md) | [CPU load checker](scripts/system/check_cpu_load.sh) |
| System | [Linux log analysis](docs/system/log-analysis.md) | [Recent error checker](scripts/system/check_recent_errors.sh) |
| System | [Memory troubleshooting](docs/system/memory-troubleshooting.md) | [Memory usage checker](scripts/system/check_memory_usage.sh) |
| System | [Systemd service management](docs/system/systemd-services.md) | [Service status checker](scripts/system/check_service.sh) |
| Virtualization / Proxmox | [Check Ceph cluster health](docs/virtualization/proxmox/check-ceph-cluster.md) | Diagnostic commands |
| Virtualization / Proxmox | [Copy PBS snapshots between datastores](docs/virtualization/proxmox/pbs-bulk-snapshot-move.md) | [PBS datastore copy script](scripts/virtualization/proxmox/pbs-copy-datastore.sh) |
| Virtualization / Proxmox | [Delete a ZFS pool](docs/virtualization/proxmox/delete-zfs-pool.md) | Destructive procedure |
| Virtualization / Proxmox | [Install Proxmox Backup Client](docs/virtualization/proxmox/pbs-client-installation.md) | [PBS client installer](scripts/virtualization/proxmox/install_pbs_client.sh) |
| Virtualization / Proxmox | [Linux backup to Proxmox Backup Server](docs/virtualization/proxmox/pbs-client-backup.md) | [PBS backup script](scripts/virtualization/proxmox/auto_pbs_backup.sh) |
| Virtualization / Proxmox | [Simple PBS filesystem backup](docs/virtualization/proxmox/pbs-simple-backup.md) | [Simple backup script](scripts/virtualization/proxmox/auto_pbs_backup_simple.sh) |
| Virtualization / Proxmox | [Useful Proxmox host commands](docs/virtualization/proxmox/useful-host-commands.md) | Command reference |
| Virtualization / Proxmox | [Recover an LVM-thin pool](docs/virtualization/proxmox/recover-lvm-thin-pool.md) | Storage recovery procedure |
## Repository structure
.
|-- docs/
|   |-- system/
|   |-- networking/
|   |-- storage/
|   |-- security/
|   |-- monitoring/
|   |-- backup/
|   |-- troubleshooting/
|   |-- htcondor/
|   |-- oracle-linux/
|   |   |-- backup/
|   |   |-- database/
|   |   |-- networking/
|   |   `-- system/
|   `-- virtualization/
|       `-- proxmox/
|-- scripts/
|   |-- system/
|   |-- networking/
|   |-- storage/
|   |-- security/
|   |-- monitoring/
|   |-- backup/
|   |-- htcondor/
|   |-- oracle-linux/
|   |   |-- backup/
|   |   |-- networking/
|   |   `-- system/
|   `-- virtualization/
|       `-- proxmox/
|-- .gitignore
`-- README.md

## Disk usage checker

The first included tool checks filesystem usage and reports filesystems that exceed a configurable threshold.

Run it with the default threshold of 80%:

```bash
bash scripts/system/check_disk_usage.sh
```

Specify a custom threshold:

```bash
bash scripts/system/check_disk_usage.sh 70
```

Example output:

```text
Disk usage report
Warning threshold: 70%

[OK]      /                               42% used
[WARNING] /mnt/data                       85% used
```



The script validates that the supplied threshold is a number between `1` and `100`.

## Installation

Clone the repository:

```bash
git clone https://github.com/mihaistanciu1984/linux-sysadmin-toolkit.git
```

Enter the project directory:

```bash
cd linux-sysadmin-toolkit
```

Make the scripts executable:

```bash
find scripts -type f -name "*.sh" -exec chmod +x {} \;
```

Run a tool:

```bash
./scripts/system/check_disk_usage.sh 80
```

## Requirements

Most procedures and tools require:

* Bash
* Standard GNU/Linux command-line utilities
* Administrative privileges for commands that access protected system information
* A supported Linux distribution such as Ubuntu, Debian, Rocky Linux or AlmaLinux

Some procedures may require additional utilities, including:

```text
lsof
rsync
curl
jq
netcat
dnsutils
```

Each procedure should document its individual dependencies.

## Planned procedures

### System administration

* CPU troubleshooting
* Memory troubleshooting
* Systemd service management
* Log analysis with Journalctl
* User and permission management
* Package management

### Networking

* Connectivity troubleshooting
* DNS troubleshooting
* Port validation
* Routing diagnostics
* Network interface analysis

### Storage

* LVM administration
* RAID diagnostics
* ZFS health checks
* Mount and filesystem troubleshooting
* NFS troubleshooting

### Security

* SSH hardening
* Failed login analysis
* Firewall verification
* File permission auditing
* Security update validation

### Monitoring and backup

* Zabbix Agent verification
* Resource monitoring
* Rsync backup procedures
* Backup validation
* Log and service health checks

## Security

Never store the following information in this repository:

* Passwords or password hashes
* API tokens
* SSH private keys
* Internal IP addresses
* Production hostnames
* Company domains
* Customer information
* Unmodified production configuration files

Use documentation addresses and names in examples:

```text
192.0.2.10
198.51.100.20
linux-lab-01
example.com
example-user
```

Review every file before committing it:

```bash
git diff --cached
```

Search for common private information:

```bash
git grep -n -I -E \
  '192\.168\.|BEGIN OPENSSH PRIVATE KEY|BEGIN RSA PRIVATE KEY'
```

## Contributing

When adding a procedure:

1. Place documentation under the appropriate `docs/` category.
2. Place executable tools under the corresponding `scripts/` category.
3. Include prerequisites and usage examples.
4. Validate commands in a non-production environment.
5. Avoid destructive commands unless clearly documented.
6. Never commit credentials or production infrastructure data.
7. Update the content table in this README.

## Disclaimer

The commands and scripts in this repository are provided for educational and administrative reference purposes.

Always review and test commands in a non-production environment before using them on critical systems.

