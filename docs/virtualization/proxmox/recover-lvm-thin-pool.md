# Recover a Proxmox LVM-Thin Pool

This procedure addresses the following Proxmox error:

```text
TASK ERROR: activating LV 'pve/data' failed:
Activation of logical volume pve/data is prohibited
while logical volume pve/data_tdata is active.
```

The default Proxmox `local-lvm` storage normally uses:

```text
Volume group: pve
Thin pool:    data
Data LV:      data_tdata
Metadata LV:  data_tmeta
```

The `_tdata` and `_tmeta` volumes are internal components of the thin pool and must not be used directly.

## Important warning

This procedure modifies the storage layer containing VM and container disks.

Before continuing:

- use the Proxmox local console;
- stop or migrate guests using `local-lvm`;
- disable or move HA resources from the affected node;
- verify that backups exist;
- do not delete `data_tdata` or `data_tmeta`;
- do not repeatedly run `lvconvert --repair` without checking the pool.

Do not perform this procedure while virtual machines are writing to the affected thin pool.

## 1. Check Proxmox storage status

```bash
pvesm status
```

Check the configured LVM-thin storage:

```bash
grep -A5 -B1 "lvmthin" /etc/pve/storage.cfg
```

The default configuration usually contains:

```text
lvmthin: local-lvm
        thinpool data
        vgname pve
        content rootdir,images
```

## 2. Check running guests

List virtual machines:

```bash
qm list
```

List containers:

```bash
pct list
```

Stop or migrate guests that use the affected storage before manipulating the pool.

## 3. Inspect the LVM-thin pool

```bash
lvs -a -o \
lv_name,vg_name,lv_attr,segtype,lv_size,data_percent,metadata_percent,devices
```

Check free space in the volume group:

```bash
vgs -o vg_name,vg_size,vg_free
```

Inspect active device-mapper volumes:

```bash
dmsetup ls --tree
```

Look for:

- `pve-data`;
- `pve-data_tdata`;
- `pve-data_tmeta`;
- high `Data%`;
- high `Meta%`;
- no free space in the `pve` volume group;
- thin volumes in a failed or read-only state.

## 4. Check the system logs

```bash
journalctl -b --no-pager |
    grep -Ei "lvm|thin|data_tdata|data_tmeta|device-mapper"
```

Check kernel messages:

```bash
dmesg -T |
    grep -Ei "device-mapper|thin|I/O error"
```

Save the output before attempting a repair.

## 5. Save the Proxmox and LVM configuration

Create a Proxmox configuration archive:

```bash
BACKUP_DATE="$(date +%Y%m%d-%H%M%S)"

tar -czf \
    "/root/pve-config-${BACKUP_DATE}.tar.gz" \
    /etc/pve
```

Save the LVM volume-group configuration:

```bash
vgcfgbackup \
    -f "/root/pve-vgcfg-${BACKUP_DATE}.backup" \
    pve
```

> `vgcfgbackup` saves the LVM volume-group configuration. It is not a backup of VM disks or thin-pool data.

## 6. Attempt a clean reactivation

Only continue after all guests using `local-lvm` are stopped or migrated.

Deactivate the thin pool:

```bash
lvchange -an pve/data
```

Deactivate any internal component left active:

```bash
lvchange -an pve/data_tdata
lvchange -an pve/data_tmeta
```

It is acceptable for a command to report that a component is already inactive.

Wait for device-manager operations to complete:

```bash
udevadm settle
```

Activate the complete thin pool, not the individual components:

```bash
lvchange -ay pve/data
```

Do not activate `data_tdata` or `data_tmeta` manually.

## 7. Verify the recovered pool

```bash
lvs -a -o \
lv_name,vg_name,lv_attr,segtype,lv_size,data_percent,metadata_percent
```

Scan the Proxmox thin pools:

```bash
pvesm scan lvmthin pve
```

Check the storage again:

```bash
pvesm status
```

Refresh the Proxmox storage status service if necessary:

```bash
systemctl restart pvestatd
```

## 8. Repair thin-pool metadata only if required

Run this section only if normal activation still fails and the logs indicate damaged thin-pool metadata.

Ensure the required repair utilities exist:

```bash
apt update
apt install -y thin-provisioning-tools
```

Confirm that the pool and its internal components are inactive:

```bash
lvchange -an pve/data
lvchange -an pve/data_tdata
lvchange -an pve/data_tmeta
udevadm settle
```

Confirm that the volume group has free space:

```bash
vgs -o vg_name,vg_size,vg_free
```

Repair the thin pool:

```bash
lvconvert --repair pve/data
```

Activate the repaired pool:

```bash
lvchange -ay pve/data
```

Verify it:

```bash
lvs -a -o \
lv_name,lv_attr,segtype,lv_size,data_percent,metadata_percent
```

The repair operation may preserve the old metadata under a name such as:

```text
data_meta0
```

Do not delete old metadata volumes until:

- the pool activates successfully;
- Proxmox detects the storage;
- VM disks are visible;
- important guests have been tested;
- a current backup exists.

## 9. Remove a remaining VM lock

An interrupted storage operation may leave a VM locked.

Check the VM configuration:

```bash
qm config 100 | grep lock
```

Unlock it only after the storage is healthy:

```bash
qm unlock 100
```

For a container:

```bash
pct unlock 100
```

Unlocking a VM does not repair the LVM-thin pool.

## 10. Start and test one guest

Start one non-critical virtual machine:

```bash
qm start 100
```

Check its status:

```bash
qm status 100
```

Review the system log:

```bash
journalctl -b -p warning --no-pager
```

Do not start every guest simultaneously until the storage has been verified.

## If the thin pool is full

Check usage:

```bash
lvs pve/data -o \
lv_name,lv_size,data_percent,metadata_percent
```

Check free volume-group space:

```bash
vgs pve -o vg_name,vg_size,vg_free
```

If `Data%` or `Meta%` is close to `100%`:

1. Do not create more VM disks or snapshots.
2. Back up critical guests.
3. Add physical capacity or migrate disks to another storage.
4. Remove only known, unused VM disks or snapshots through Proxmox.
5. Do not delete `data_tdata` or `data_tmeta`.
6. Extend the pool only after confirming the available physical space and correct LVM layout.

A full thin pool can return I/O errors to all guests using it and can cause filesystem corruption.

## About discard and TRIM

Enabling discard helps reclaim blocks after files are deleted inside a guest, but only when every storage layer supports discard.

For a Proxmox VM disk, discard can be enabled with:

```text
discard=on
```

Linux guests can request block reclamation with:

```bash
sudo fstrim -av
```

Discard does not:

- repair damaged thin-pool metadata;
- deactivate a stuck `data_tdata` volume;
- fix an activation conflict;
- create physical space when the volume group is already full;
- protect the pool from excessive thin provisioning.

## Common mistakes

Do not run:

```bash
lvremove pve/data_tdata
lvremove pve/data_tmeta
```

Do not recreate the pool with:

```bash
lvconvert --type thin-pool pve/data
```

Do not format any `/dev/pve/` device.

Do not activate only the internal data component:

```bash
lvchange -ay pve/data_tdata
```

Do not force-start all guests before verifying storage integrity.

## Quick recovery summary

Use this section only after reading the warnings and stopping affected guests:

```bash
lvs -a -o \
lv_name,lv_attr,segtype,lv_size,data_percent,metadata_percent

vgs -o vg_name,vg_size,vg_free

lvchange -an pve/data
lvchange -an pve/data_tdata
lvchange -an pve/data_tmeta

udevadm settle

lvchange -ay pve/data

pvesm scan lvmthin pve
pvesm status
```

If activation still fails and logs confirm metadata problems:

```bash
lvchange -an pve/data
lvconvert --repair pve/data
lvchange -ay pve/data

pvesm status
```

## References

- [Proxmox VE Administration Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.pdf)
- [LVM thin provisioning manual](https://man7.org/linux/man-pages/man7/lvmthin.7.html)
- [LVM lvconvert manual](https://man7.org/linux/man-pages/man8/lvconvert.8.html)
- [Red Hat LVM troubleshooting](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/troubleshooting-lvm_configuring-and-managing-logical-volumes)