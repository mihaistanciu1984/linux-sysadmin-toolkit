# Linux System Administration Toolkit

A practical collection of Linux administration procedures, troubleshooting guides and reusable Bash tools.

The repository is intended as a reference for system administrators, infrastructure engineers and DevOps professionals working with Linux servers.

## Current content

| Category | Procedure | Tool |
|---|---|---|
| Storage | [Disk usage troubleshooting](docs/system/disk-usage.md) | [Disk usage checker](scripts/system/check_disk_usage.sh) |
| Monitoring | [Glances system monitoring](docs/monitoring/glances.md) | Planned |

| System | [Memory troubleshooting](docs/system/memory-troubleshooting.md) | [Memory usage checker](scripts/system/check_memory_usage.sh) |

| System | [CPU and load troubleshooting](docs/system/cpu-troubleshooting.md) | [CPU load checker](scripts/system/check_cpu_load.sh) |

| System | [Systemd service management](docs/system/systemd-services.md) | [Service status checker](scripts/system/check_service.sh) |
## Features

* Practical Linux troubleshooting procedures
* Reusable and documented Bash scripts
* Safe diagnostic commands
* Parameter validation
* Clear execution examples
* Security-focused recommendations
* Sanitized examples without production credentials or infrastructure data

## Repository structure

```text
.
├── docs/
│   ├── system/
│   ├── networking/
│   ├── storage/
│   ├── security/
│   ├── monitoring/
│   ├── backup/
│   └── troubleshooting/
├── scripts/
│   ├── system/
│   ├── networking/
│   ├── storage/
│   ├── security/
│   ├── monitoring/
│   └── backup/
├── .gitignore
└── README.md
```

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

