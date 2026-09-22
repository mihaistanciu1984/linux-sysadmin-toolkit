# Install Proxmox Backup Client on Oracle Linux 8

## Purpose

Install Proxmox Backup Client 4.2.0-1 on Oracle Linux 8.

The procedure uses the official statically linked client. The Debian package is extracted, not installed with APT or converted to RPM.

## Requirements

- Oracle Linux 8
- x86-64 architecture
- Internet access
- Root or sudo permissions

## 1. Copy the installation script

Copy `install_pbs_client.sh` to the Oracle Linux server.

Make it executable:

```bash
chmod +x install_pbs_client.sh
```

## 2. Run the installation

```bash
sudo bash install_pbs_client.sh
```

The client is installed in:

```text
/usr/local/bin/proxmox-backup-client
```

## 3. Verify the installation

```bash
proxmox-backup-client version
```

Display the available commands:

```bash
proxmox-backup-client help
```

## Removal

```bash
sudo rm /usr/local/bin/proxmox-backup-client
```

## Upgrade

Change the `VERSION` value in the installation script and run it again.

The client is installed as a standalone executable and is not automatically updated by DNF.