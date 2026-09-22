# Automated Linux Configuration Backup to Proxmox Backup Server

This procedure configures an automated backup of Linux configuration files to Proxmox Backup Server using `proxmox-backup-client`.

The repository includes:

```text
scripts/virtualization/proxmox/auto_pbs_backup.sh
scripts/virtualization/proxmox/pbs-backup.env.example
```

The public repository does not contain passwords, API token secrets, internal addresses or certificate fingerprints.

## Backup architecture

The backup workflow contains:

* a Linux client with `proxmox-backup-client`;
* a Proxmox Backup Server datastore;
* a dedicated PBS user and API token;
* a local token file readable only by root;
* a protected local configuration file;
* a root cron job;
* a server-side prune policy.

The example backs up `/etc` as an archive named `etc.pxar`.

## Security model

Use a dedicated API token instead of `root@pam`.

The token should have only the permissions required to create backups in the selected datastore or namespace.

Recommended principles:

* create a separate token for each protected host;
* assign the narrowest possible datastore or namespace permission;
* permit backup creation but not backup deletion;
* store the API token secret only on the protected client;
* configure pruning on Proxmox Backup Server;
* never commit the token secret or real configuration file to Git.

Keeping prune permissions away from the backup client helps protect existing backups if the client becomes compromised.

## Repository format

A PBS repository using an API token has the following format:

```text
user@realm!token@server:datastore
```

Example:

```text
backup-client@pbs!linux-host@pbs.example.com:datastore-example
```

Replace all example values with the values from your environment.

## Prerequisites

Before configuring the automation, verify that:

* Proxmox Backup Server is operational;
* the datastore exists;
* DNS resolves the PBS hostname;
* TCP port `8007` is reachable from the Linux client;
* `proxmox-backup-client` is installed;
* the API token has been created;
* the client has enough access to read the selected source directory;
* the system clock is synchronized.

Check DNS:

```bash
getent hosts pbs.example.com
```

Check TCP connectivity:

```bash
nc -zv -w 5 pbs.example.com 8007
```

Check the client:

```bash
proxmox-backup-client version
```

## Step 1 — Create a dedicated PBS identity

In the Proxmox Backup Server interface:

1. Open the access-control configuration.
2. Create a dedicated backup user.
3. Create a separate API token for the Linux host.
4. Save the generated token secret immediately.
5. Assign backup permissions only to the required datastore or namespace.
6. Do not grant backup deletion permissions to the client token.

The token secret is normally displayed only when it is created.

Do not place it in:

* shell scripts;
* Git repositories;
* Markdown documentation;
* shell history;
* unprotected environment files.

## Step 2 — Obtain the PBS certificate fingerprint

When PBS uses a certificate that cannot be validated by the operating system CA store, obtain and verify its SHA-256 fingerprint through a trusted channel.

The fingerprint will be stored in the local configuration as:

```bash
PBS_FINGERPRINT="REPLACE_WITH_VERIFIED_SHA256_FINGERPRINT"
```

If the PBS certificate is already trusted by the client operating system, leave the value empty:

```bash
PBS_FINGERPRINT=""
```

Do not accept an unverified fingerprint obtained from an untrusted network connection.

## Step 3 — Install the backup client

Install `proxmox-backup-client` using the repository appropriate for the Linux distribution.

Verify:

```bash
command -v proxmox-backup-client
proxmox-backup-client version
```

The script expects the executable at:

```text
/usr/bin/proxmox-backup-client
```

A different location can be provided using `PBS_CLIENT_BIN`.

## Step 4 — Install the automation script

From the cloned repository:

```bash
sudo install \
    -o root \
    -g root \
    -m 0750 \
    scripts/virtualization/proxmox/auto_pbs_backup.sh \
    /usr/local/sbin/auto_pbs_backup.sh
```

Verify:

```bash
sudo /usr/local/sbin/auto_pbs_backup.sh --help
```

## Step 5 — Create the protected configuration directory

```bash
sudo install \
    -d \
    -o root \
    -g root \
    -m 0700 \
    /etc/proxmox-backup-client
```

Copy the example:

```bash
sudo install \
    -o root \
    -g root \
    -m 0600 \
    scripts/virtualization/proxmox/pbs-backup.env.example \
    /etc/proxmox-backup-client/backup.env
```

Edit it:

```bash
sudo nano /etc/proxmox-backup-client/backup.env
```

Configure:

```bash
PBS_REPOSITORY="backup-client@pbs!linux-host@pbs.example.com:datastore-example"
PBS_PASSWORD_FILE="/etc/proxmox-backup-client/token.secret"
PBS_FINGERPRINT=""

BACKUP_ID="linux-config-example"
SOURCE_DIR="/etc"
ARCHIVE_NAME="etc"

LOG_FILE="/var/log/proxmox-backup-client/config-backup.log"
LOCK_FILE="/run/lock/auto-pbs-backup.lock"
```

Verify its permissions:

```bash
sudo stat \
    -c '%U:%G %a %n' \
    /etc/proxmox-backup-client/backup.env
```

Expected result:

```text
root:root 600 /etc/proxmox-backup-client/backup.env
```

## Step 6 — Store the API token secret

Create the secret file:

```bash
sudo install \
    -o root \
    -g root \
    -m 0600 \
    /dev/null \
    /etc/proxmox-backup-client/token.secret
```

Edit it:

```bash
sudo nano /etc/proxmox-backup-client/token.secret
```

Place only the API token secret on the first line.

Verify permissions without displaying the secret:

```bash
sudo stat \
    -c '%U:%G %a %n' \
    /etc/proxmox-backup-client/token.secret
```

Expected result:

```text
root:root 600 /etc/proxmox-backup-client/token.secret
```

Do not use `cat` to display the token during demonstrations, terminal recordings or support sessions.

## Step 7 — Validate the configuration

Check script syntax:

```bash
bash -n /usr/local/sbin/auto_pbs_backup.sh
```

Check the source directory:

```bash
sudo test -d /etc &&
    echo "[OK] Source directory exists."
```

Check the protected files:

```bash
sudo find \
    /etc/proxmox-backup-client \
    -maxdepth 1 \
    -type f \
    -printf '%u:%g %m %p\n'
```

Both local files should be owned by `root:root` and use mode `600`.

## Step 8 — Run a dry-run

Run:

```bash
sudo /usr/local/sbin/auto_pbs_backup.sh --dry-run
```

The dry-run validates the operation without uploading backup data.

Inspect the log:

```bash
sudo tail -n 100 \
    /var/log/proxmox-backup-client/config-backup.log
```

Do not continue until the dry-run completes successfully.

## Step 9 — Run the first backup

Run:

```bash
sudo /usr/local/sbin/auto_pbs_backup.sh
```

Monitor the log:

```bash
sudo tail -f \
    /var/log/proxmox-backup-client/config-backup.log
```

The backup group should use the following structure:

```text
host/<BACKUP_ID>
```

The archive should appear as:

```text
etc.pxar
```

## Step 10 — Verify the backup

Load the protected configuration in a root shell:

```bash
sudo -i
```

Then run:

```bash
source /etc/proxmox-backup-client/backup.env
export PBS_REPOSITORY
export PBS_PASSWORD_FILE

if [[ -n "${PBS_FINGERPRINT:-}" ]]; then
    export PBS_FINGERPRINT
fi
```

List backup groups:

```bash
proxmox-backup-client list
```

List snapshots for the configured backup ID:

```bash
proxmox-backup-client snapshot list "host/${BACKUP_ID}"
```

Exit the root shell:

```bash
exit
```

The backup should also be visible in the PBS web interface.

## Step 11 — Test a restore

A backup is not considered validated until a restore has been tested.

Create a temporary restore location:

```bash
sudo install \
    -d \
    -o root \
    -g root \
    -m 0700 \
    /var/tmp/pbs-restore-test
```

List the snapshots and select one:

```bash
proxmox-backup-client snapshot list "host/${BACKUP_ID}"
```

Restore the `etc.pxar` archive using the exact snapshot identifier:

```bash
proxmox-backup-client restore \
    "host/<BACKUP_ID>/<SNAPSHOT_TIMESTAMP>" \
    etc.pxar \
    /var/tmp/pbs-restore-test
```

Do not restore directly over the live `/etc` directory.

Inspect a sample of the restored files:

```bash
sudo find /var/tmp/pbs-restore-test \
    -maxdepth 2 \
    -type f |
    head
```

Remove the temporary restore directory only after validation:

```bash
sudo rm -rf -- /var/tmp/pbs-restore-test
```

Verify the exact path before executing the removal command.

## Step 12 — Configure the cron schedule

Edit the root crontab:

```bash
sudo crontab -e
```

Run the backup every day at 02:30:

```cron
30 2 * * * /usr/local/sbin/auto_pbs_backup.sh >> /var/log/proxmox-backup-client/cron.log 2>&1
```

Verify:

```bash
sudo crontab -l
```

Check the cron service:

```bash
systemctl status cron --no-pager
```

On distributions using `crond`:

```bash
systemctl status crond --no-pager
```

## Step 13 — Configure retention on PBS

Do not run automatic pruning from the protected Linux client.

Configure a prune job directly on Proxmox Backup Server.

Example retention policy:

| Retention type | Value |
| -------------- | ----: |
| Keep daily     |     7 |
| Keep weekly    |     4 |
| Keep monthly   |     6 |

Adapt the policy to business, legal and storage requirements.

Also configure:

* scheduled backup verification;
* datastore garbage collection;
* failure notifications;
* an off-site or secondary copy;
* periodic restore testing.

## Log locations

Main backup log:

```text
/var/log/proxmox-backup-client/config-backup.log
```

Cron output:

```text
/var/log/proxmox-backup-client/cron.log
```

Inspect recent activity:

```bash
sudo tail -n 100 \
    /var/log/proxmox-backup-client/config-backup.log
```

Search for failures:

```bash
sudo grep -Ei \
    'error|failed|critical' \
    /var/log/proxmox-backup-client/config-backup.log
```

## Troubleshooting

### Authentication failed

Check:

* repository format;
* PBS username, realm and token name;
* token secret;
* token expiration;
* datastore permissions;
* token-specific ACL permissions;
* ownership of the backup group.

Do not print the token secret while troubleshooting.

### Certificate fingerprint error

Verify that:

* the fingerprint belongs to the expected PBS server;
* the complete fingerprint was copied;
* no unsupported characters were added;
* the PBS certificate has not been replaced;
* the client trusts the correct CA when the fingerprint is omitted.

### Permission denied while reading files

The backup of `/etc` should normally run as root.

Check:

```bash
sudo test -r /etc/passwd &&
    echo "[OK] Source is readable."
```

### Another backup is already running

The script uses `flock` to prevent overlapping runs.

Inspect the processes:

```bash
pgrep -af auto_pbs_backup
pgrep -af proxmox-backup-client
```

Do not remove the lock while a valid backup process is running.

### Backup does not contain another mounted filesystem

`proxmox-backup-client` does not automatically include separate mount points.

Create a separate archive specification or use the appropriate client option after reviewing the mount point and restore requirements.

## Security checklist

* [ ] Dedicated PBS user and API token
* [ ] Different token for each protected host
* [ ] Minimal datastore or namespace permissions
* [ ] No delete permission for the client token
* [ ] Token secret stored outside Git
* [ ] Configuration owned by `root:root`
* [ ] Configuration mode set to `600`
* [ ] Token file mode set to `600`
* [ ] PBS fingerprint verified through a trusted channel
* [ ] Pruning configured on PBS
* [ ] Verification job configured on PBS
* [ ] Restore tested regularly
* [ ] Off-site copy configured where required

## Official documentation

* [Proxmox Backup Client Usage](https://pbs.proxmox.com/docs/backup-client.html)
* [proxmox-backup-client command reference](https://pbs.proxmox.com/docs/proxmox-backup-client/man1.html)
* [Proxmox Backup Server storage and ransomware protection](https://pbs.proxmox.com/docs/storage.html)
* [Proxmox Backup Server maintenance tasks](https://pbs.proxmox.com/docs/maintenance.html)
