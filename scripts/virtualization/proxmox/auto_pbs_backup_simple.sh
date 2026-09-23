# Simple Proxmox Backup Client Backup

## Purpose

Create an automatic filesystem backup using Proxmox Backup Client and Proxmox Backup Server.

This is a simplified procedure intended for beginners.

## Requirements

- Proxmox Backup Client installed
- Access to a Proxmox Backup Server
- PBS API token
- Root or sudo permissions
- The `auto_pbs_backup_simple.sh` script

## 1. Configure the repository

Open the backup script:

```bash
nano auto_pbs_backup_simple.sh
```

Modify the repository value:

```bash
export PBS_REPOSITORY="backup-user@pbs!backup-token@192.0.2.20:8007:backup-store"
```

Repository format:

```text
user@realm!token@server:port:datastore
```

Replace the example values with your environment values.

Do not write the API token secret directly in the script.

## 2. Create the token secret file

Create a protected file:

```bash
sudo install -m 600 /dev/null /root/.pbs-token-secret
```

Open the file:

```bash
sudo nano /root/.pbs-token-secret
```

Enter only the API token secret on the first line.

Save the file and verify its permissions:

```bash
sudo chmod 600 /root/.pbs-token-secret
```

```bash
sudo ls -l /root/.pbs-token-secret
```

Expected permissions:

```text
-rw------- 1 root root
```

Never add this file to Git.

## 3. Install the backup script

Copy the script to `/usr/local/sbin`:

```bash
sudo install -m 750 auto_pbs_backup_simple.sh /usr/local/sbin/auto_pbs_backup_simple.sh
```

Verify the installed file:

```bash
sudo ls -l /usr/local/sbin/auto_pbs_backup_simple.sh
```

## 4. Test the backup manually

Run:

```bash
sudo /usr/local/sbin/auto_pbs_backup_simple.sh
```

A successful backup displays:

```text
SUCCESS: The backup was completed.
```

Verify the new snapshot in the Proxmox Backup Server web interface.

Do not configure automatic execution before the manual test succeeds.

## 5. Schedule the backup

Open the root crontab:

```bash
sudo crontab -e
```

Add the following line to run the backup every day at 02:30:

```cron
30 2 * * * /usr/local/sbin/auto_pbs_backup_simple.sh >> /var/log/pbs-simple-backup.log 2>&1
```

Save and close the file.

## 6. Verify the scheduled job

Display the root crontab:

```bash
sudo crontab -l
```

Check the backup log:

```bash
sudo tail -n 50 /var/log/pbs-simple-backup.log
```

Follow the log during a backup:

```bash
sudo tail -f /var/log/pbs-simple-backup.log
```

Press `Ctrl+C` to stop following the log.

## Remove the scheduled backup

Open the root crontab:

```bash
sudo crontab -e
```

Delete the line containing:

```text
auto_pbs_backup_simple.sh
```

This removes the schedule but does not delete existing backups from Proxmox Backup Server.

## Security notes

- Never store the API token secret inside the script.
- Never commit `/root/.pbs-token-secret` to Git.
- Use a dedicated API token with only the required backup permissions.
- Test the restore process regularly.