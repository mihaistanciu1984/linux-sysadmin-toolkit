# Schedule User Logout on Oracle Linux

## Purpose

Automatically log out active users every Friday at 17:00 before scheduled maintenance.

> Warning: users can lose unsaved work. Test the procedure on a non-production system first.

## 1. Install the script

```bash
sudo install -m 750 \
  scripts/oracle-linux/system/logout_logged_users.sh \
  /usr/local/sbin/logout_logged_users.sh
```

## 2. Preview the affected users

```bash
sudo /usr/local/sbin/logout_logged_users.sh --dry-run
```

The command only lists the users and does not terminate any sessions.

## 3. Check the server time

```bash
timedatectl
```

Cron uses the server's configured time and time zone.

## 4. Schedule the logout

Open the root crontab:

```bash
sudo crontab -e
```

Add:

```cron
0 17 * * 5 /usr/local/sbin/logout_logged_users.sh --apply
```

This runs every Friday at 17:00.

## 5. Verify the cron job

```bash
sudo crontab -l
systemctl status crond
```

## 6. Check the logout log

```bash
sudo cat /var/log/logout-events.log
```

## Remove the schedule

Run:

```bash
sudo crontab -e
```

Delete the line containing `logout_logged_users.sh`.