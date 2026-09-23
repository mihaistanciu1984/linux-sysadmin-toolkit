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