# Start Here

Welcome to the Linux System Administration Toolkit.

This repository contains practical procedures and scripts for:

- Linux administration;
- troubleshooting;
- networking;
- security;
- monitoring;
- Proxmox and Ceph;
- Proxmox Backup Server;
- Oracle Linux;
- Cisco switches;
- HTCondor.

The documentation is written to help junior system administrators understand not only which command to run, but also why it is required and how to verify the result.

## Identify the command environment

Commands from different environments cannot always be used interchangeably.

| Prompt example | Environment |
|---|---|
| `PS C:\>` | Windows PowerShell |
| `user@server:~$` | Linux normal user |
| `root@server:~#` | Linux root user |
| `Switch>` | Cisco user EXEC mode |
| `Switch#` | Cisco privileged EXEC mode |
| `Switch(config)#` | Cisco configuration mode |

Do not type the prompt itself.

For example, if the documentation displays:

```text
root@server:~# ceph -s
```

run only:

```bash
ceph -s
```

### Windows and Linux path differences

Windows PowerShell normally uses paths such as:

```text
.\scripts\system\check_disk_usage.sh
```

Bash and WSL use:

```text
./scripts/system/check_disk_usage.sh
```

When running a Bash script through WSL from PowerShell, use:

```powershell
wsl bash ./scripts/system/check_disk_usage.sh
```

Do not pass a PowerShell path containing backslashes directly to Bash.

## Understand command symbols

| Symbol | Meaning |
|---|---|
| `<VALUE>` | Replace with a real value |
| `\` | Command continues on the next line in Bash |
| `|` | Sends output from one command to another |
| `>` | Replaces the contents of a file |
| `>>` | Appends output to a file |
| `&&` | Runs the next command only if the first succeeds |
| `Ctrl+C` | Stops the currently running command |
| `q` | Exits tools such as `less`, `git diff` or some status viewers |

Example:

```bash
ssh <USERNAME>@<SERVER-IP>
```

Do not run it literally. Replace the placeholders:

```bash
ssh example-user@192.0.2.10
```

## Before running any command

Never copy and run a command without first checking:

1. Which server you are connected to.
2. Whether the command requires `sudo` or root access.
3. Whether the command changes or deletes data.
4. Whether a current backup exists.
5. Whether a rollback procedure is available.
6. Whether the command contains example values that must be replaced.

Verify the current system:

```bash
hostname
whoami
pwd
```

Check the operating system:

```bash
cat /etc/os-release
```

Check the current date and time:

```bash
date
timedatectl
```

## Understand the risk level

Procedures should be classified using the following levels:

| Risk | Meaning | Examples |
|---|---|---|
| `LOW` | Read-only checks | Displaying disk, service or network status |
| `MEDIUM` | Configuration or service changes | Restarting a service or modifying a firewall rule |
| `HIGH` | Storage, cluster or destructive changes | Removing disks, repairing LVM or changing Ceph configuration |

When a procedure has a `HIGH` risk:

- use a maintenance window;
- verify backups;
- use console or out-of-band access;
- record the original configuration;
- test the procedure in a lab first.

## Example values

Documentation examples use non-production values such as:

```text
Server IP:       192.0.2.10
Management net:  192.0.2.0/24
Username:        example-user
Hostname:        linux-lab-01
Proxmox node:    proxmox-node
```

Replace these values with the correct information for your environment.

Never commit:

- passwords;
- password hashes;
- API tokens;
- private SSH keys;
- internal production IP addresses;
- company hostnames;
- customer information.

## Recommended learning path

### Step 1: Learn basic Linux checks

Start with:

- [Disk usage troubleshooting](system/disk-usage.md)
- [Memory troubleshooting](system/memory-troubleshooting.md)
- [CPU and load troubleshooting](system/cpu-troubleshooting.md)
- [Systemd service management](system/systemd-services.md)
- [Linux log analysis](system/log-analysis.md)

These procedures teach the most common commands used when investigating a Linux server.

### Step 2: Learn network troubleshooting

Continue with:

- [Connectivity troubleshooting](networking/connectivity-troubleshooting.md)
- [DNS troubleshooting](networking/dns-troubleshooting.md)
- [Mount remote directories with SSHFS](networking/sshfs-mount.md)
- [Samba installation and file sharing](networking/samba-file-sharing.md)

Before changing network settings, always record:

```bash
ip address
ip route
cat /etc/resolv.conf
```

### Step 3: Secure remote access

Continue with:

- [OpenSSH server hardening](security/ssh-hardening.md)
- [UFW firewall on Ubuntu](security/ufw-firewall-ubuntu.md)
- [XRDP on Ubuntu 24.04](remote-access/xrdp-ubuntu-24.04.md)

When configuring a firewall remotely, allow SSH before enabling the firewall.

Keep the original SSH session open and test access using a second terminal.

### Step 4: Learn monitoring

Continue with:

- [Glances system monitoring](monitoring/glances.md)
- [Zabbix Agent 2 on Ubuntu](monitoring/zabbix-agent2-ubuntu.md)
- [Upgrade Zabbix Server on Ubuntu](monitoring/zabbix-server-upgrade-ubuntu.md)
- [Migrate Zabbix Server](monitoring/zabbix-server-migration.md)

Monitoring procedures should normally begin with read-only checks.

### Step 5: Learn Proxmox administration

Start with the safe reference documentation:

- [Useful Proxmox host commands](virtualization/proxmox/useful-host-commands.md)
- [Check Ceph cluster health](virtualization/proxmox/check-ceph-cluster.md)
- [Ceph cluster maintenance](virtualization/proxmox/ceph-cluster-maintenance.md)

Continue with backup procedures:

- [Install Proxmox Backup Client](virtualization/proxmox/pbs-client-installation.md)
- [Linux backup to Proxmox Backup Server](virtualization/proxmox/pbs-client-backup.md)
- [Simple PBS filesystem backup](virtualization/proxmox/pbs-simple-backup.md)
- [Copy PBS snapshots between datastores](virtualization/proxmox/pbs-bulk-snapshot-move.md)

Use recovery and destructive procedures only after understanding the storage layout:

- [Recover an LVM-thin pool](virtualization/proxmox/recover-lvm-thin-pool.md)
- [Delete a ZFS pool](virtualization/proxmox/delete-zfs-pool.md)
- [Upgrade PBS 3 to PBS 4](virtualization/proxmox/upgrade-pbs-3-to-4.md)

These procedures are high-risk and require verified backups.

### Step 6: Learn Oracle Linux

Oracle Linux procedures are kept separately from generic Linux procedures:

- Static IP configuration
- GNOME desktop installation
- Scheduled user logout
- Proxmox Backup Client installation
- Oracle Database XE installation

Browse them under:

```text
docs/oracle-linux/
```

### Step 7: Learn Cisco switch administration

Start with:

- [Connect two Cisco switches safely](cisco/connect-switches-safely.md)

Before modifying a switch:

```cisco
show running-config
show interfaces status
show vlan brief
show spanning-tree
```

Always save validated changes:

```cisco
copy running-config startup-config
```

### Step 8: Learn HTCondor

HTCondor documentation is available under:

```text
docs/htcondor/
```

Start with the cluster installation procedure, then continue with role configuration and pool validation.

## How to use a script safely

Read the script before running it:

```bash
less scripts/path/to/script.sh
```

Check its syntax:

```bash
bash -n scripts/path/to/script.sh
```

Display its help:

```bash
bash scripts/path/to/script.sh --help
```

Check whether it contains destructive commands:

```bash
grep -nE \
    'rm |lvremove|zpool destroy|wipefs|mkfs|shutdown|reboot' \
    scripts/path/to/script.sh
```

Make it executable only after reviewing it:

```bash
chmod +x scripts/path/to/script.sh
```

Run read-only scripts as a normal user when possible.

Use `sudo` only when the script explicitly requires administrative privileges.

## How to understand command prompts

Some commands open a pager and display:

```text
(END)
```

Press:

```text
q
```

to exit the viewer.

This applies to commands such as:

```bash
less
git diff
git diff --cached
journalctl
systemctl status
```

Pressing `q` only closes the viewer. It does not cancel or delete changes.

## Basic troubleshooting workflow

When a service or server has a problem, follow this order.

### 1. Identify the system

```bash
hostname
cat /etc/os-release
```

### 2. Check available resources

```bash
df -h
free -h
uptime
```

### 3. Check failed services

```bash
systemctl --failed
```

### 4. Check recent errors

```bash
journalctl -p warning -n 50 --no-pager
```

### 5. Check network configuration

```bash
ip address
ip route
ss -lntup
```

### 6. Record the original configuration

Before editing a file:

```bash
sudo cp \
    /path/to/configuration-file \
    /path/to/configuration-file.backup
```

### 7. Make one change at a time

Do not apply several unrelated changes simultaneously.

### 8. Verify the result

Check:

- service status;
- logs;
- network ports;
- application functionality;
- access from another computer.

### 9. Roll back if necessary

Restore the configuration backup if the change fails.

### 10. Document the solution

Record:

- the problem;
- the root cause;
- the commands used;
- the verification result;
- the rollback procedure.

## Documentation versus scripts

Use documentation when:

- human decisions are required;
- the operation is destructive;
- storage or cluster configuration is modified;
- credentials or environment-specific values are required;
- different systems require different commands.

Use a script when:

- the steps are repeatable;
- input can be validated;
- the operation can be safely stopped;
- the script can clearly report success or failure;
- no production credentials are stored inside it.

Prefer read-only diagnostic scripts before configuration-changing scripts.
When creating new documentation, start with the [procedure template](templates/procedure-template.md).

Copy the template to the appropriate category, replace the title and the `<...>` placeholders, remove sections that do not apply, test the commands and update `README.md`.

## Quick navigation

Use this table when you already know what type of problem you have.

| I need to... | Start with |
|---|---|
| Check disk space | [Disk usage troubleshooting](system/disk-usage.md) |
| Investigate high CPU | [CPU troubleshooting](system/cpu-troubleshooting.md) |
| Investigate high memory | [Memory troubleshooting](system/memory-troubleshooting.md) |
| Troubleshoot a service | [Systemd service management](system/systemd-services.md) |
| Check system logs | [Linux log analysis](system/log-analysis.md) |
| Troubleshoot network access | [Connectivity troubleshooting](networking/connectivity-troubleshooting.md) |
| Troubleshoot DNS | [DNS troubleshooting](networking/dns-troubleshooting.md) |
| Configure a firewall | [UFW firewall on Ubuntu](security/ufw-firewall-ubuntu.md) |
| Configure graphical remote access | [XRDP on Ubuntu](remote-access/xrdp-ubuntu-24.04.md) |
| Check a Proxmox host | [Useful Proxmox commands](virtualization/proxmox/useful-host-commands.md) |
| Check a Ceph cluster | [Check Ceph cluster health](virtualization/proxmox/check-ceph-cluster.md) |
| Perform Ceph maintenance | [Ceph cluster maintenance](virtualization/proxmox/ceph-cluster-maintenance.md) |
| Configure PBS backups | [PBS client backup](virtualization/proxmox/pbs-client-backup.md) |
| Work with Oracle Linux | [Oracle Linux procedures](oracle-linux/) |
| Configure a Cisco switch | [Cisco switch connection](cisco/connect-switches-safely.md) |
| Work with HTCondor | [HTCondor procedures](htcondor/) |

## Recommended production workflow

Before applying a procedure to production:

1. Read the entire procedure.
2. Confirm the operating system and software version.
3. Replace all example values.
4. Create and verify a backup.
5. Test in a lab environment.
6. Schedule a maintenance window.
7. Inform affected users.
8. Record the original configuration.
9. Apply one change at a time.
10. Verify and document the final result.

## Getting help

When reporting a problem, include:

```text
Operating system:
Software version:
Hostname:
Exact error:
Command executed:
Expected result:
Actual result:
Relevant logs:
Recent changes:
```

Remove passwords, tokens, internal addresses and customer information before publishing logs.

## Stop before continuing when

Stop the procedure and request assistance when:

- the target server, disk, interface or VM is unclear;
- the displayed disk names differ from the documentation;
- a current backup does not exist;
- the cluster has lost quorum;
- Ceph already reports failed OSDs or inactive PGs;
- the command would interrupt your only remote connection;
- an unexpected error appears;
- the proposed rollback procedure is unclear;
- production data may be deleted.

Commands requiring additional attention include:

```text
rm
lvremove
vgremove
pvremove
zpool destroy
wipefs
mkfs
dd
qm destroy
pct destroy
terraform destroy

## Disclaimer

The procedures and scripts in this repository are provided for educational and administrative reference.

Always review and test commands in a non-production environment before using them on critical systems.