# Upgrade Proxmox Backup Server 3 to 4

This procedure describes an in-place upgrade from:

```text
Proxmox Backup Server 3.4
Debian 12 Bookworm
```

to:

```text
Proxmox Backup Server 4
Debian 13 Trixie
```

> Warning: This is a major operating-system upgrade. Plan a maintenance window and verify that current off-site backups exist before starting.

## Important requirements

Before starting, ensure that:

- PBS is running version `3.4.2-1` or newer;
- at least 10 GB is available on the root filesystem;
- important backups have an off-site copy;
- PBS configuration has been backed up;
- physical console, IPMI or iKVM access is available;
- third-party packages support Debian 13;
- all warnings reported by `pbs3to4` have been reviewed;
- no backup, restore, sync, prune or garbage-collection task is running.

Do not perform the upgrade through the Proxmox web console.

Use SSH inside `tmux`, or use a physical/IPMI console.

## 1. Start a persistent terminal

Install `tmux`:

```bash
apt update
apt install -y tmux
```

Start a session:

```bash
tmux new -s pbs-upgrade
```

If the SSH connection is interrupted, reconnect and restore the session:

```bash
tmux attach -t pbs-upgrade
```

## 2. Check the current version

```bash
proxmox-backup-manager versions
```

Check the Debian version:

```bash
cat /etc/os-release
```

The system should currently report Debian 12 Bookworm and PBS 3.4.

## 3. Check the system before upgrading

Check root filesystem space:

```bash
df -h /
```

At least 10 GB should be available.

Check for failed services:

```bash
systemctl --failed
```

Check for incomplete package operations:

```bash
dpkg --audit
```

Check packages placed on hold:

```bash
apt-mark showhold
```

Check datastores:

```bash
proxmox-backup-manager datastore list
```

If the system uses ZFS:

```bash
zpool status
zpool list
```

Resolve storage, disk, ZFS or package problems before continuing.

## 4. Update PBS 3.4 completely

While the Bookworm repositories are still configured:

```bash
apt update
apt dist-upgrade
```

Check the version again:

```bash
proxmox-backup-manager versions
```

The reported version must be at least:

```text
proxmox-backup-server 3.4.2-1
```

A reboot before the major upgrade is recommended:

```bash
systemctl reboot
```

Reconnect and recreate the `tmux` session:

```bash
tmux new -s pbs-upgrade
```

## 5. Back up the PBS configuration

Create a working directory:

```bash
BACKUP_DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/pbs3-upgrade-${BACKUP_DATE}"

mkdir -p "${BACKUP_DIR}"
```

Back up the PBS configuration:

```bash
tar -czf \
    "${BACKUP_DIR}/proxmox-backup-config.tar.gz" \
    -C /etc \
    proxmox-backup
```

Back up network and host configuration:

```bash
cp -a /etc/network/interfaces "${BACKUP_DIR}/"
cp -a /etc/hosts "${BACKUP_DIR}/"
cp -a /etc/hostname "${BACKUP_DIR}/"
```

Back up the APT configuration:

```bash
cp -a /etc/apt "${BACKUP_DIR}/apt"
```

Save the installed package list:

```bash
dpkg-query -W \
    -f='${binary:Package}\t${Version}\n' \
    > "${BACKUP_DIR}/installed-packages.txt"
```

Save the storage and disk layout:

```bash
lsblk -f > "${BACKUP_DIR}/lsblk.txt"
findmnt > "${BACKUP_DIR}/findmnt.txt"
```

If the system uses ZFS:

```bash
zpool status > "${BACKUP_DIR}/zpool-status.txt"
zfs list > "${BACKUP_DIR}/zfs-list.txt"
```

Copy this configuration backup to another system before continuing.

The configuration archive is not a backup of the datastore contents.

## 6. Run the official upgrade checker

Run the complete checklist:

```bash
pbs3to4 --full
```

Review every result.

The checker does not automatically repair reported problems.

After correcting a problem, run it again:

```bash
pbs3to4 --full
```

Do not continue while the checker reports unresolved failures.

## 7. Check the bootloader

Check the configured bootloader:

```bash
proxmox-boot-tool status
```

Check systemd-boot packages:

```bash
dpkg -l |
    grep -E "systemd-boot|proxmox-boot"
```

Some PBS 3 installations contain the `systemd-boot` meta-package, which can cause problems during the upgrade.

Remove it only if `pbs3to4` explicitly recommends this and the system was not manually configured to use systemd-boot:

```bash
apt remove systemd-boot
```

Do not remove bootloader packages without reviewing the `pbs3to4` output and the existing boot configuration.

## 8. Enable datastore maintenance mode

List the datastores:

```bash
proxmox-backup-manager datastore list
```

Enable read-only maintenance mode for every datastore:

```bash
proxmox-backup-manager datastore update DATASTORE-ID \
    --maintenance-mode read-only
```

Replace `DATASTORE-ID` with the real datastore name.

Repeat the command for every datastore.

This prevents new backups from starting while keeping existing backups readable.

## 9. Check the Proxmox archive keyring

```bash
test -r /usr/share/keyrings/proxmox-archive-keyring.gpg &&
    echo "[OK] Proxmox archive keyring exists."
```

If the keyring is missing, install it before changing repositories:

```bash
apt update
apt install -y proxmox-archive-keyring
```

## 10. Disable third-party repositories

List all configured repositories:

```bash
grep -R --line-number --no-messages \
    -E "^(deb|deb-src|URIs:|Suites:)" \
    /etc/apt/sources.list \
    /etc/apt/sources.list.d/
```

Disable third-party repositories until their Debian 13 compatibility has been confirmed.

Do not automatically replace `bookworm` with `trixie` inside third-party repository files.

## 11. Change Debian repositories to Trixie

Update the main Debian repository file:

```bash
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
```

If `/etc/apt/sources.list.d/debian.sources` exists:

```bash
sed -i \
    's/bookworm/trixie/g' \
    /etc/apt/sources.list.d/debian.sources
```

Search for remaining Bookworm entries:

```bash
grep -R --line-number "bookworm" \
    /etc/apt/sources.list \
    /etc/apt/sources.list.d/ || true
```

Review every remaining result manually.

## 12. Configure the PBS 4 repository

Use either the enterprise repository or the no-subscription repository. Do not enable both.

### Enterprise repository

Use this repository only with a valid subscription:

```bash
cat > /etc/apt/sources.list.d/pbs-enterprise.sources <<'EOF'
Types: deb
URIs: https://enterprise.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

### No-subscription repository

For laboratory or non-subscription installations:

```bash
cat > /etc/apt/sources.list.d/proxmox.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

Disable or remove the old PBS 3 repository file.

For example:

```bash
grep -R --line-number "pbs" /etc/apt/sources.list.d/
```

Rename an old repository instead of deleting it immediately:

```bash
mv \
    /etc/apt/sources.list.d/pbs-enterprise.list \
    /etc/apt/sources.list.d/pbs-enterprise.list.disabled
```

Adjust the filename according to the actual repository configuration.

## 13. Validate the repositories

Refresh package information:

```bash
apt update
```

This command must finish without repository errors.

Review configured package sources:

```bash
apt policy
```

Check again for Bookworm repositories:

```bash
grep -R --line-number "bookworm" \
    /etc/apt/sources.list \
    /etc/apt/sources.list.d/ || true
```

Run the upgrade checker again:

```bash
pbs3to4 --full
```

Do not continue if repository errors or critical checklist failures remain.

## 14. Upgrade to PBS 4

Start the major upgrade:

```bash
apt dist-upgrade
```

During the upgrade:

- read every prompt;
- press `q` to exit the `apt-listchanges` viewer;
- keep customized configuration files when necessary;
- inspect differences before replacing configuration files;
- pay special attention to `/etc/default/grub`;
- do not interrupt the upgrade;
- do not close the `tmux` session.

For `/etc/issue`, keeping the installed version is normally safe.

For `/etc/ssh/sshd_config`, inspect the differences before deciding.

For `/etc/default/grub`, keep the existing version if it contains custom kernel or boot parameters that are still required.

## 15. Check package status before rebooting

```bash
dpkg --audit
```

```bash
apt --fix-broken install
```

```bash
systemctl --failed
```

Run the upgrade checker:

```bash
pbs3to4 --full
```

Review any remaining warnings.

## 16. Reboot the server

Ensure physical, IPMI or iKVM console access is available.

```bash
systemctl reboot
```

Wait for the server to return and reconnect.

## 17. Verify the upgraded system

Check Debian:

```bash
cat /etc/os-release
```

It should report Debian 13 Trixie.

Check the kernel:

```bash
uname -r
```

Check PBS:

```bash
proxmox-backup-manager versions
```

Check the main services:

```bash
systemctl status \
    proxmox-backup.service \
    proxmox-backup-proxy.service \
    --no-pager
```

Check for failed services:

```bash
systemctl --failed
```

Run the checker again:

```bash
pbs3to4 --full
```

## 18. Verify storage and datastores

```bash
proxmox-backup-manager datastore list
```

Check mounted filesystems:

```bash
findmnt
df -h
```

For ZFS systems:

```bash
zpool status
zfs list
```

In the PBS web interface, verify that:

- all datastores are visible;
- existing snapshots can be browsed;
- datastore usage is displayed correctly;
- users and API tokens exist;
- sync, verify, prune and garbage-collection jobs exist;
- remote configurations are present.

Force-reload the browser interface with:

```text
CTRL + SHIFT + R
```

## 19. Disable maintenance mode

After verifying the system, remove read-only maintenance mode:

```bash
proxmox-backup-manager datastore update DATASTORE-ID \
    --delete maintenance-mode
```

Repeat for every datastore.

## 20. Perform functional tests

After the upgrade:

1. Run a small test backup.
2. Verify that the backup finishes successfully.
3. Browse the new snapshot.
4. Run a verification task.
5. Test restoring a small file.
6. Check scheduled jobs.
7. Check notifications.
8. Check remote synchronization.
9. Check tape configuration, if used.
10. Monitor the system logs.

Check recent PBS errors:

```bash
journalctl -b -p warning --no-pager
```

## 21. Clean old packages carefully

List packages that are no longer required:

```bash
apt autoremove --dry-run
```

Review the list carefully.

Remove them only after the PBS server has been tested:

```bash
apt autoremove
```

Do not remove kernels or bootloader packages without confirming that the server boots correctly.

## Rollback considerations

There is no simple or supported APT downgrade from PBS 4 to PBS 3.

A rollback may require:

- reinstalling PBS 3;
- restoring `/etc/proxmox-backup`;
- restoring network configuration;
- reconnecting existing datastores;
- recovering the system from an image-level backup.

This is why console access, configuration backups and off-site backup copies are required before the upgrade.

## References

- [Official Proxmox upgrade guide](https://pbs.proxmox.com/wiki/Upgrade_from_3_to_4)
- [Proxmox Backup Server roadmap](https://pbs.proxmox.com/wiki/Roadmap)
- [Proxmox Backup Server documentation](https://pbs.proxmox.com/docs/)
- [Debian 13 release information](https://www.debian.org/releases/trixie/)
- [VE Labs step-by-step guide](https://velabs.co/Upgrade%20Proxmox%20Backup%20Server%203%20to%204%20%E2%80%94%20Full%20Step-by-Step%20Guide%20%28PBS%203.4%20to%204.0%29.html)