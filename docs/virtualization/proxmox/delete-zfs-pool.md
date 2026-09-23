# Delete a ZFS Pool on Proxmox VE

This procedure explains how to permanently remove a ZFS pool from Proxmox VE and optionally prepare its disks for reuse.

> **WARNING:** This operation permanently removes the selected ZFS pool and its data. Verify the pool name, storage ID and disk devices before continuing.

## Example values

Replace these examples with the correct values for your environment:

```bash
TARGET_STORAGE="old-zfs-storage"
TARGET_POOL="old-zfs-pool"
```

Do not use this procedure for the Proxmox system pool, which is commonly named `rpool`.

## 1. List the available storage and ZFS pools

```bash
pvesm status
zpool list
zfs list
```

Verify the pool that you intend to remove:

```bash
zpool status -P "$TARGET_POOL"
zfs list -r "$TARGET_POOL"
```

The `-P` option displays the complete device paths.

## 2. Check whether the storage is still in use

List the volumes stored on the Proxmox storage:

```bash
pvesm list "$TARGET_STORAGE"
```

Search the virtual machine and container configurations for references:

```bash
grep -R "${TARGET_STORAGE}:" \
    /etc/pve/qemu-server \
    /etc/pve/lxc 2>/dev/null || true
```

Before continuing:

- Stop or migrate virtual machines and containers using this storage.
- Move or delete all required virtual disks.
- Verify that no backup, ISO or container template is needed.
- Confirm that the selected pool is not the Proxmox system pool.

## 3. Record the pool disk devices

```bash
zpool status -P "$TARGET_POOL"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
```

Write down every disk that belongs to the pool.

Prefer stable device paths such as:

```text
/dev/disk/by-id/ata-example-disk
```

Avoid relying only on names such as `/dev/sdb`, because they may change after a reboot.

## 4. Remove the storage from Proxmox VE

### Web interface method

1. Open the Proxmox VE web interface.
2. Navigate to **Datacenter > Storage**.
3. Select the ZFS storage.
4. Click **Remove**.
5. Confirm the removal.

This removes only the Proxmox storage configuration. It does not destroy the ZFS pool or delete its data.

### Command-line method

The equivalent command is:

```bash
pvesm remove "$TARGET_STORAGE"
```

Verify that the storage configuration was removed:

```bash
pvesm status
```

## 5. Verify the pool one final time

```bash
echo "Pool selected for deletion: $TARGET_POOL"
zpool status -P "$TARGET_POOL"
zfs list -r "$TARGET_POOL"
```

Stop here if the displayed pool or disks are not the expected ones.

## 6. Destroy the ZFS pool

```bash
zpool destroy "$TARGET_POOL"
```

Do not add `-f` unless you have investigated why the normal operation failed.

Verify that the pool no longer exists:

```bash
zpool list
zpool status
```

## 7. Inspect the released disks

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
```

Inspect the signatures on each released disk:

```bash
wipefs /dev/disk/by-id/DEVICE_ID
```

Replace `DEVICE_ID` with the exact disk identifier recorded earlier.

## 8. Optionally erase the old signatures

Only run this command when the disk is no longer part of the pool and you are certain that it is the correct disk:

```bash
wipefs --all /dev/disk/by-id/DEVICE_ID
```

Run it separately for every disk that you want to reuse.

`wipefs --all` removes filesystem, RAID and partition-table signatures. It is not a secure data-erasure operation.

## 9. Verify the disks

```bash
lsblk -f
wipefs /dev/disk/by-id/DEVICE_ID
```

If `wipefs` produces no output, no recognized signatures remain on that device.

The disk can now be reused through the Proxmox interface or prepared with a new partition table.

## Optional: create a new GPT partition table

Only perform this step if a new partition table is required:

```bash
fdisk /dev/disk/by-id/DEVICE_ID
```

Inside `fdisk`:

```text
g    Create a new GPT partition table
w    Write the changes and exit
```

Verify the result:

```bash
fdisk -l /dev/disk/by-id/DEVICE_ID
lsblk
```

## If you only want to disconnect or move the pool

Do not use `zpool destroy`.

Export the pool instead:

```bash
zpool export "$TARGET_POOL"
```

An exported pool can later be detected with:

```bash
zpool import
```

## Safety checklist

Before running `zpool destroy` or `wipefs --all`, confirm that:

- The correct Proxmox storage ID was selected.
- No VM or container uses the storage.
- All required data has been backed up.
- The selected pool is not `rpool`.
- The disk serial numbers match the intended disks.
- The pool is not shared with another node.