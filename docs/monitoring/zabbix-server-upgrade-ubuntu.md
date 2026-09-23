# Upgrade Zabbix Server 7.0 on Ubuntu 22.04

## Purpose

Upgrade an existing Zabbix installation to the latest Zabbix 7.0 release on Ubuntu 22.04 with MariaDB or MySQL.

This procedure applies to:

- Zabbix 6.4 to Zabbix 7.0
- An existing Zabbix 7.0 installation to a newer 7.0 release

For older major versions, review the official upgrade path before continuing.

## 1. Check the current versions

```bash
zabbix_server -V
```

```bash
lsb_release -ds
```

```bash
mysql --version
```

## 2. Open a root session

```bash
sudo -i
```

The following commands are run from this root session.

## 3. Stop the services

```bash
systemctl stop zabbix-server
```

```bash
systemctl stop zabbix-agent2
```

```bash
systemctl stop apache2
```

## 4. Create the backup directory

```bash
BACKUP_DIR="/root/zabbix_backup_$(date +%Y%m%d_%H%M%S)"
```

```bash
mkdir -p "$BACKUP_DIR"
```

Verify the backup location:

```bash
echo "$BACKUP_DIR"
```

## 5. Back up the database

For MariaDB:

```bash
mariadb-dump -u root -p --single-transaction zabbix > "$BACKUP_DIR/zabbix_database.sql"
```

For MySQL:

```bash
mysqldump -u root -p --single-transaction zabbix > "$BACKUP_DIR/zabbix_database.sql"
```

Use only the command matching your database system.

Enter the MariaDB or MySQL root password when requested.

Verify that the backup is not empty:

```bash
ls -lh "$BACKUP_DIR/zabbix_database.sql"
```

## 6. Back up the Zabbix files

```bash
cp -a /etc/zabbix "$BACKUP_DIR/"
```

```bash
cp -a /usr/share/zabbix "$BACKUP_DIR/"
```

If the Apache Zabbix configuration exists, back it up:

```bash
cp -a /etc/apache2/conf-available/zabbix.conf "$BACKUP_DIR/" 2>/dev/null || true
```

Display the backup contents:

```bash
ls -lah "$BACKUP_DIR"
```

Do not continue unless the database and configuration backups exist.

## 7. Install the Zabbix 7.0 repository

```bash
cd /tmp
```

```bash
wget "https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu22.04_all.deb" -O zabbix-release.deb
```

```bash
dpkg -i zabbix-release.deb
```

```bash
apt update
```

## 8. Review the available upgrade

```bash
apt list --upgradable 2>/dev/null | grep zabbix
```

Check that the packages come from the Zabbix 7.0 repository.

## 9. Upgrade the Zabbix packages

```bash
apt install --only-upgrade 'zabbix*'
```

Review the proposed changes before confirming the installation.

If asked about an existing configuration file, compare the versions before replacing your current configuration.

## 10. Start the services

```bash
systemctl start mariadb
```

If MySQL is used instead of MariaDB:

```bash
systemctl start mysql
```

Start the Zabbix services:

```bash
systemctl start zabbix-server
```

```bash
systemctl restart zabbix-agent2
```

```bash
systemctl start apache2
```

## 11. Monitor the database upgrade

```bash
tail -f /var/log/zabbix/zabbix_server.log
```

During the first startup, Zabbix can automatically upgrade the database schema.

Press `Ctrl+C` after the server starts successfully.

## 12. Verify the services

```bash
systemctl status zabbix-server --no-pager
```

```bash
systemctl status zabbix-agent2 --no-pager
```

```bash
systemctl status apache2 --no-pager
```

Check the installed version:

```bash
zabbix_server -V
```

Check the listening ports:

```bash
ss -lntp | grep -E ':10050|:10051|:80|:443'
```

## 13. Exit the root session

```bash
exit
```

## Important notes

- Do not delete the backup until the upgraded system has been fully tested.
- A virtual machine snapshot is useful, but it does not replace the database backup.
- Check the Zabbix server log before opening the web interface.
- Test dashboards, hosts, triggers, actions and notifications after the upgrade.