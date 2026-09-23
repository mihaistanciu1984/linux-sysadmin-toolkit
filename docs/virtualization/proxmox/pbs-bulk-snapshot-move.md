# Copy PBS Snapshots Between Local Datastores

This procedure copies backup groups and snapshots between two datastores located on the same Proxmox Backup Server.

The operation uses a local PBS Sync Job.

> PBS does not perform an atomic snapshot move. The safe workflow is: copy, verify and then manually delete the source snapshots.

## Requirements

- Proxmox Backup Server 3 or newer
- Two configured PBS datastores
- Enough free space on the destination datastore
- Root access to the PBS server
- The `proxmox-backup-manager` command

## 1. Configure the script

Edit:

```bash
nano pbs-copy-datastore.sh
```

Set the source and destination datastore names:

```bash
SOURCE_DATASTORE="backup1"
DEST_DATASTORE="backup2"
SYNC_JOB_ID="copy-backup1-to-backup2"
```

Keep dry-run mode enabled for the first execution:

```bash
DRY_RUN=true
```

## 2. Install the script

```bash
sudo install -m 750 \
    pbs-copy-datastore.sh \
    /usr/local/sbin/pbs-copy-datastore.sh
```

## 3. Run the dry-run test

```bash
sudo /usr/local/sbin/pbs-copy-datastore.sh
```

Dry-run mode only displays the commands. It does not create a sync job or copy data.

## 4. Start the datastore copy

Edit the installed script:

```bash
sudo nano /usr/local/sbin/pbs-copy-datastore.sh
```

Change:

```bash
DRY_RUN=false
```

Run it:

```bash
sudo /usr/local/sbin/pbs-copy-datastore.sh
```

Monitor the log:

```bash
sudo tail -f /var/log/pbs-datastore-copy.log
```

## 5. Verify the destination

After synchronization:

1. Open the PBS web interface.
2. Select the destination datastore.
3. Open **Content**.
4. Confirm that the expected backup groups and snapshots exist.
5. Run a verification job on the destination datastore.
6. Test restoring at least one backup.

Do not delete the source snapshots until these checks succeed.

## 6. Remove the temporary sync job

After the copy has completed:

```bash
sudo proxmox-backup-manager sync-job remove \
    copy-backup1-to-backup2
```

This removes only the sync-job configuration. It does not delete any snapshots.

## 7. Delete the source snapshots

Delete the source snapshots through the PBS web interface only after the destination has been verified.

Deleting snapshots does not necessarily release storage immediately because chunks may be shared by multiple snapshots. Garbage collection determines which chunks are no longer referenced.

Run garbage collection from:

```text
Source datastore > Prune & GC > Start Garbage Collection
```

## Important notes

- `--remove-vanished false` prevents the sync job from deleting destination backups that are absent from the source.
- It does not delete snapshots from the source datastore.
- Never copy PBS datastore directories with `cp`, `mv` or `rsync`.
- Never manually move directories inside the datastore.
- Do not delete the source before verifying the destination.
- Existing protected snapshots may require additional attention.