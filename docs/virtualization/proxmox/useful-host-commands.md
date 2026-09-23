# Useful Proxmox VE Host Commands

This document contains frequently used commands for managing Proxmox VE virtual machines, cluster maintenance, GPU devices and RAID disks.

Some operations require root privileges.

## 1. View a VM or template configuration

Replace `VM_ID` with the numeric ID of the virtual machine or template:

```bash
qm config VM_ID
```

Example:

```bash
qm config 9000
```

Proxmox stores QEMU virtual machine configurations in:

```text
/etc/pve/qemu-server/VM_ID.conf
```

These files are stored in the Proxmox cluster filesystem and are visible throughout the cluster. :contentReference[oaicite:0]{index=0}

## 2. Edit a VM or template configuration

Stop the VM before manually changing its configuration:

```bash
qm stop VM_ID
```

Create a backup of the configuration:

```bash
cp \
    /etc/pve/qemu-server/VM_ID.conf \
    /root/VM_ID.conf.backup
```

Edit the configuration:

```bash
nano /etc/pve/qemu-server/VM_ID.conf
```

Verify the result:

```bash
qm config VM_ID
```

Start the VM:

```bash
qm start VM_ID
```

Whenever possible, use `qm set` instead of editing the configuration file directly.

Example:

```bash
qm set VM_ID --memory 8192
qm set VM_ID --cores 4
```

> Manual editing can make the VM configuration invalid. Do not edit the same configuration simultaneously from multiple cluster nodes.

## 3. Restore a VM from a Proxmox backup

The recommended method is `qmrestore`:

```bash
qmrestore \
    /path/to/vzdump-qemu-VM_ID.vma.zst \
    NEW_VM_ID \
    --storage STORAGE_ID
```

Example using documentation values:

```bash
qmrestore \
    /mnt/backup/dump/vzdump-qemu-200-YYYY_MM_DD.vma.zst \
    300 \
    --storage local-lvm
```

Verify the restored VM:

```bash
qm config 300
qm start 300
```

## 4. Advanced manual configuration recovery

Use this section only when a normal Proxmox backup is unavailable.

Verify that the target VM ID is not already used:

```bash
qm list
```

Restore a saved configuration:

```bash
cp \
    /path/to/backup/VM_ID.conf \
    /etc/pve/qemu-server/VM_ID.conf
```

Check the configuration:

```bash
qm config VM_ID
```

The storage volume names referenced inside the configuration must exist on the configured Proxmox storage.

Check the available storage:

```bash
pvesm status
```

Check for existing volumes:

```bash
pvesm list STORAGE_ID |
    grep "vm-VM_ID-"
```

Search for volumes that are not attached to the VM:

```bash
qm rescan --vmid VM_ID
qm config VM_ID
```

Do not copy virtual disk files directly into an arbitrary storage directory. The correct recovery method depends on the storage type:

- Directory storage
- ZFS
- LVM or LVM-thin
- Ceph RBD
- NFS
- iSCSI

For an external disk image, use the Proxmox import command:

```bash
qm importdisk \
    VM_ID \
    /path/to/virtual-disk.qcow2 \
    STORAGE_ID
```

After the import, inspect the VM configuration:

```bash
qm config VM_ID
```

The imported disk normally appears as an unused disk and can then be attached from the Proxmox web interface.

## 5. Display GPU devices on the Proxmox host

Display VGA-compatible devices:

```bash
lspci |
    grep -i vga
```

Display VGA, 3D and display controllers:

```bash
lspci |
    grep -Ei 'vga|3d|display'
```

Display device IDs and the active kernel driver:

```bash
lspci -nnk |
    grep -EA3 'VGA|3D|Display'
```

For PCI passthrough, record the device address and vendor/device IDs from this output.

## 6. Put a Proxmox node into HA maintenance mode

Before starting maintenance, check the cluster and HA status:

```bash
pvecm status
ha-manager status
```

Check the virtual machines and containers running on the node:

```bash
qm list
pct list
```

Enable maintenance mode:

```bash
ha-manager crm-command \
    node-maintenance enable proxmox-node
```

Replace `proxmox-node` with the exact cluster node name.

Monitor the HA resources:

```bash
watch -n 2 ha-manager status
```

Wait until the HA-managed workloads have migrated or reached their expected state before shutting down or rebooting the node.

The maintenance command applies to HA-managed services. Check non-HA virtual machines and containers separately.

Proxmox documents this command as the supported method for requesting node maintenance through the HA manager. :contentReference[oaicite:1]{index=1}

After completing maintenance, disable maintenance mode:

```bash
ha-manager crm-command \
    node-maintenance disable proxmox-node
```

Verify the cluster:

```bash
pvecm status
ha-manager status
```

## 7. Display RAID controllers with StorCLI

Check whether StorCLI is installed:

```bash
command -v storcli
command -v storcli64
```

List all detected RAID controllers:

```bash
storcli show
```

Alternative command:

```bash
storcli /call show
```

## 8. Display all physical RAID disks

Display all disks connected to controller `0`:

```bash
storcli /c0/eall/sall show
```

This displays summary information for all enclosures and physical disks connected to controller `0`. :contentReference[oaicite:2]{index=2}

Display detailed information:

```bash
storcli /c0/eall/sall show all
```

If the executable is named `storcli64`, use:

```bash
storcli64 /c0/eall/sall show
```

## 9. Display virtual RAID drives

```bash
storcli /c0/vall show
```

Display controller details:

```bash
storcli /c0 show all
```

Check the controller and disk states for values such as:

```text
Optl
Onln
UGood
Dgrd
Offln
Failed
```

Common meanings:

- `Optl` — RAID virtual drive is optimal.
- `Onln` — physical disk is online.
- `UGood` — unconfigured good disk.
- `Dgrd` — RAID virtual drive is degraded.
- `Offln` — disk or virtual drive is offline.
- `Failed` — device failure detected.

> The displayed commands are read-only. Do not use StorCLI commands that modify disk states unless the RAID recovery procedure has been approved and the correct enclosure and slot have been identified.

## 10. Check Proxmox storage usage

Display all configured Proxmox storage:

```bash
pvesm status
```

Display the storage configuration:

```bash
cat /etc/pve/storage.cfg
```

Display mounted filesystems and their usage:

```bash
df -hT
```

## 11. Find large directories on `local`

The default Proxmox `local` storage normally uses:

```text
/var/lib/vz
```

Check its filesystem usage:

```bash
df -hT /var/lib/vz
```

Display the size of its main directories:

```bash
du -xhd1 /var/lib/vz |
    sort -h
```

Display the largest directories recursively:

```bash
du -xhd2 /var/lib/vz |
    sort -h |
    tail -20
```

The `-x` option prevents `du` from entering other mounted filesystems.

Common Proxmox directories include:

```text
/var/lib/vz/dump
/var/lib/vz/images
/var/lib/vz/template
```

Check them individually:

```bash
du -sh /var/lib/vz/dump 2>/dev/null
du -sh /var/lib/vz/images 2>/dev/null
du -sh /var/lib/vz/template 2>/dev/null
```

## 12. Find large files on `local`

Display files larger than 1 GB:

```bash
find /var/lib/vz \
    -xdev \
    -type f \
    -size +1G \
    -printf '%s %p\n' |
    sort -nr |
    numfmt --field=1 --to=iec |
    head -20
```

Typical large files can include:

- VM backups
- ISO images
- Container templates
- VM disk images on directory storage

Do not delete a file until you have identified which VM, backup or template uses it.

## 13. Check `local-lvm` usage

`local-lvm` normally uses LVM-thin and does not contain normal directories.

Display physical volumes:

```bash
pvs
```

Display volume groups:

```bash
vgs
```

Display logical volumes and thin-pool usage:

```bash
lvs -a \
    -o vg_name,lv_name,lv_size,pool_lv,data_percent,metadata_percent
```

A common Proxmox thin pool appears as:

```text
pve/data
```

Important fields:

- `LV Size` — provisioned logical volume size.
- `Data%` — percentage of data space in use.
- `Meta%` — percentage of thin-pool metadata in use.
- `Pool` — thin pool containing the VM volume.

The displayed logical size of a thin-provisioned VM disk is not necessarily the amount of physical storage currently consumed.

## 14. List volumes stored on `local-lvm`

```bash
pvesm list local-lvm
```

Display only the volume identifier and configured size:

```bash
pvesm list local-lvm |
    awk 'NR == 1 || /vm-|subvol-/'
```

Typical volume names include:

```text
vm-200-disk-0
vm-200-disk-1
subvol-300-disk-0
```

The number after `vm-` or `subvol-` is normally the VM or container ID.

## 15. Identify which VM uses an LVM volume

List all virtual machines:

```bash
qm list
```

List all containers:

```bash
pct list
```

Check the disks attached to a VM:

```bash
qm config VM_ID |
    grep -E '^(ide|sata|scsi|virtio|efidisk|tpmstate|unused)[0-9]*:'
```

Check the storage attached to a container:

```bash
pct config CT_ID |
    grep -E '^(rootfs|mp[0-9]+):'
```

Search all VM configurations for a specific volume:

```bash
grep -R "vm-VM_ID-disk" \
    /etc/pve/qemu-server 2>/dev/null
```

Do not remove logical volumes directly with `lvremove` unless you have confirmed that they are no longer referenced by Proxmox.

## 16. Check the Proxmox node status

Display CPU, memory and load information:

```bash
uptime
free -h
lscpu
```

Display block devices:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
```

Display failed services:

```bash
systemctl --failed
```

Display important errors from the current boot:

```bash
journalctl -p err -b --no-pager
```

## 17. Check the cluster status

```bash
pvecm status
pvecm nodes
```

Verify:

- Quorum status
- Expected number of votes
- Online cluster nodes
- Node IDs and names

## 18. Check virtual machines and containers

List virtual machines:

```bash
qm list
```

Check a virtual machine:

```bash
qm status VM_ID
qm config VM_ID
```

List containers:

```bash
pct list
```

Check a container:

```bash
pct status CT_ID
pct config CT_ID
```

## 19. Check network configuration

Display interfaces and IP addresses:

```bash
ip -br address
```

Display routes:

```bash
ip route
```

Display Linux bridges:

```bash
bridge link
bridge vlan show
```

Display the persistent Proxmox network configuration:

```bash
cat /etc/network/interfaces
```

Do not modify the network configuration remotely without an alternative management connection.
## 20. Display hardware and system information

Display basic server manufacturer, model, serial number and UUID information:

```bash
sudo dmidecode -t 1
```

The command displays the SMBIOS **System Information** section.

Typical fields include:

```text
Manufacturer
Product Name
Version
Serial Number
UUID
SKU Number
Family
```

Display a short system summary:

```bash
sudo dmidecode -t 1 |
    grep -E 'Manufacturer|Product Name|Serial Number|UUID'
```

Display all available DMI/SMBIOS hardware information:

```bash
sudo dmidecode
```

Additional useful hardware queries:

```bash
sudo dmidecode -t system
sudo dmidecode -t baseboard
sudo dmidecode -t bios
sudo dmidecode -t processor
sudo dmidecode -t memory
```

Common numeric equivalents are:

```bash
sudo dmidecode -t 0    # BIOS information
sudo dmidecode -t 1    # System information
sudo dmidecode -t 2    # Baseboard information
sudo dmidecode -t 4    # Processor information
sudo dmidecode -t 17   # Memory device information
```

Display only installed memory modules:

```bash
sudo dmidecode -t 17 |
    grep -E 'Size:|Type:|Speed:|Manufacturer:|Serial Number:|Part Number:'
```

> `dmidecode` reports information supplied by the system firmware. Some fields may be empty or contain generic manufacturer values, especially on virtual machines.
## 21. Copy files with SCP

`scp` securely copies files between computers using SSH.

General format:

```bash
scp SOURCE DESTINATION
```

A remote location has this format:

```text
USER@REMOTE_HOST:/PATH
```

## Copy a file to another computer

```bash
scp report.txt example-user@192.0.2.10:/tmp/
```

Command explanation:

| Part | Meaning |
|---|---|
| `scp` | Secure copy command |
| `report.txt` | File being copied |
| `example-user` | User on the remote computer |
| `192.0.2.10` | Remote computer IP address |
| `/tmp/` | Destination folder |

The colon `:` indicates that `/tmp/` is located on the remote computer.

## Copy a file from another computer

```bash
scp example-user@192.0.2.10:/tmp/report.txt .
```

The dot `.` means the current local directory.

## Copy an entire folder

Use `-r` to copy a directory and its contents:

```bash
scp -r \
    reports \
    example-user@192.0.2.10:/tmp/
```

## Use a different SSH port

Use uppercase `-P`:

```bash
scp -P 2222 \
    report.txt \
    example-user@192.0.2.10:/tmp/
```

## Use an SSH key

```bash
scp \
    -i /path/to/private-key \
    report.txt \
    example-user@192.0.2.10:/tmp/
```

## Windows PowerShell examples

Copy a Windows file to a Linux server:

```powershell
scp "C:\Users\example-user\Documents\report.txt" example-user@192.0.2.10:/tmp/
```

Copy a file from Linux to Windows:

```powershell
scp example-user@192.0.2.10:/tmp/report.txt "C:\Users\example-user\Downloads\"
```
## Copy to a protected directory

A normal user usually cannot copy files directly into protected directories such as:

```text
/etc/
/opt/
/usr/local/
/root/
```

For example, this command may return `Permission denied`:

```bash
scp report.txt example-user@192.0.2.10:/opt/
```

Copy the file to `/tmp` first:

```bash
scp report.txt example-user@192.0.2.10:/tmp/
```

Connect to the remote computer:

```bash
ssh example-user@192.0.2.10
```

Move the file to the protected directory using `sudo`:

```bash
sudo mv /tmp/report.txt /opt/
```

Set the required owner and permissions:

```bash
sudo chown root:root /opt/report.txt
sudo chmod 644 /opt/report.txt
```

For an executable script:

```bash
sudo chown root:root /opt/script.sh
sudo chmod 750 /opt/script.sh
```

Verify the result:

```bash
ls -l /opt/report.txt
```
## 22. VM and container configuration locations

Proxmox stores QEMU virtual machine configuration files in:

```text
/etc/pve/qemu-server/
```

Each VM has a configuration file based on its VM ID:

```text
/etc/pve/qemu-server/<VMID>.conf
```

Example:

```text
/etc/pve/qemu-server/100.conf
```

List all VM configuration files:

```bash
ls -lh /etc/pve/qemu-server/
```

Display a VM configuration:

```bash
qm config 100
```

Proxmox stores LXC container configuration files in:

```text
/etc/pve/lxc/
```

Each container has a configuration file based on its container ID:

```text
/etc/pve/lxc/<CTID>.conf
```

Example:

```text
/etc/pve/lxc/200.conf
```

List all container configuration files:

```bash
ls -lh /etc/pve/lxc/
```

Display a container configuration:

```bash
pct config 200
```

> These directories contain configuration files, not VM or container disk data.

The actual disk location depends on the configured Proxmox storage.

Display the disk volumes assigned to a VM:

```bash
qm config 100 |
    grep -E '^(ide|sata|scsi|virtio|efidisk|tpmstate)[0-9]+:'
```

Display the physical path of a volume when supported by the storage backend:

```bash
pvesm path <STORAGE-ID:VOLUME-ID>
```

Example:

```bash
pvesm path local-lvm:vm-100-disk-0
```

View the configured Proxmox storage:

```bash
pvesm status
```

The `/etc/pve` directory is managed by the Proxmox cluster filesystem. Avoid editing or copying configuration files while the corresponding VM or container is running.

## Important notes

- SCP normally uses SSH port `22`.
- The SSH service must be running on the remote computer.
- Use `-r` when copying folders.
- Use uppercase `-P` for a different SSH port.
- The remote user must have permission to access the destination folder.
- If the user cannot write to the destination, copy the file to `/tmp` and move it with `sudo`.
- Do not use `chmod 777` to solve permission problems.