# Migrate Zabbix Server to a New Ubuntu Host

## Purpose

Migrate an existing Zabbix server with a MariaDB or MySQL database to a new Ubuntu host.

## Important

- Install the same Zabbix version on both servers.
- Do not run both Zabbix servers simultaneously.
- Do not combine the migration with a Zabbix upgrade.
- Keep the old server available until the migration is validated.
- Replace the example addresses with your environment values.

Example:

```text
Old Zabbix server: 192.0.2.10
New Zabbix server: 192.0.2.20
```

## 1. Check the old server

Check the Zabbix version:

```bash
zabbix_server -V
```

Check the operating system:

```bash
lsb_release -ds
```

Check the database version:

```bash
mysql --version
```

Record the database settings securely:

```bash
sudo grep -E '^(DBHost|DBName|DBUser|DBPort)=' /etc/zabbix/zabbix_server.conf
```

Do not copy database passwords into documentation or Git.

## 2. Prepare the new server

Install the same Zabbix version and database type used on the old server.

Example packages:

```bash
sudo apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent2
```

Stop Zabbix until the database is imported:

```bash
sudo systemctl stop zabbix-server
```

Verify that both servers have the same version:

```bash
zabbix_server -V
```

## 3. Create the database on the new server

Open MariaDB or MySQL:

```bash
sudo mysql
```

Create the database and user:

```sql
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;

CREATE USER 'zabbix'@'localhost'
IDENTIFIED BY 'REPLACE_WITH_A_STRONG_PASSWORD';

GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';

FLUSH PRIVILEGES;
EXIT;
```

Use the same password in `/etc/zabbix/zabbix_server.conf` on the new server.

## 4. Stop the old Zabbix server

Stop Zabbix to prevent database changes during the export:

```bash
sudo systemctl stop zabbix-server
```

Stop the web interface to prevent configuration changes:

```bash
sudo systemctl stop apache2
```

## 5. Export the old database

For MariaDB:

```bash
sudo mariadb-dump -u root -p --single-transaction --routines --triggers --events zabbix | gzip > /tmp/zabbix_database.sql.gz
```

For MySQL:

```bash
sudo mysqldump -u root -p --single-transaction --routines --triggers --events zabbix | gzip > /tmp/zabbix_database.sql.gz
```

Use only the command matching your database system.

Verify the backup:

```bash
ls -lh /tmp/zabbix_database.sql.gz
```

## 6. Back up the configuration

```bash
sudo tar -czf /tmp/zabbix_configuration.tar.gz -C / etc/zabbix
```

If custom alert or external scripts are used, back them up separately:

```bash
sudo tar -czf /tmp/zabbix_custom_scripts.tar.gz -C / usr/lib/zabbix
```

Create checksums:

```bash
cd /tmp
```

```bash
sha256sum zabbix_database.sql.gz zabbix_configuration.tar.gz > zabbix_migration.sha256
```

## 7. Transfer the files

Run these commands from the old server:

```bash
scp /tmp/zabbix_database.sql.gz user@192.0.2.20:/tmp/
```

```bash
scp /tmp/zabbix_configuration.tar.gz user@192.0.2.20:/tmp/
```

```bash
scp /tmp/zabbix_migration.sha256 user@192.0.2.20:/tmp/
```

Transfer the custom scripts archive if it was created:

```bash
scp /tmp/zabbix_custom_scripts.tar.gz user@192.0.2.20:/tmp/
```

## 8. Verify the transferred files

On the new server:

```bash
cd /tmp
```

```bash
sha256sum --check zabbix_migration.sha256
```

Expected result:

```text
zabbix_database.sql.gz: OK
zabbix_configuration.tar.gz: OK
```

## 9. Import the database

```bash
gzip -dc /tmp/zabbix_database.sql.gz | mysql -u zabbix -p zabbix
```

The import can take several minutes for a large database.

Verify that tables were imported:

```bash
mysql -u zabbix -p -e "USE zabbix; SHOW TABLES;" | head
```

## 10. Restore the configuration

Back up the new default configuration:

```bash
sudo cp -a /etc/zabbix /etc/zabbix.before-migration
```

Restore the old configuration:

```bash
sudo tar -xzf /tmp/zabbix_configuration.tar.gz -C /
```

Check the database settings:

```bash
sudo grep -E '^(DBHost|DBName|DBUser|DBPort)=' /etc/zabbix/zabbix_server.conf
```

Edit the database password if necessary:

```bash
sudo nano /etc/zabbix/zabbix_server.conf
```

Restore custom scripts if an archive was transferred:

```bash
sudo tar -xzf /tmp/zabbix_custom_scripts.tar.gz -C /
```

## 11. Start the new Zabbix server

```bash
sudo systemctl enable --now zabbix-server
```

```bash
sudo systemctl restart zabbix-agent2
```

```bash
sudo systemctl restart apache2
```

Check the services:

```bash
sudo systemctl status zabbix-server zabbix-agent2 apache2 --no-pager
```

Monitor the Zabbix server log:

```bash
sudo tail -f /var/log/zabbix/zabbix_server.log
```

Press `Ctrl+C` after confirming that the server started successfully.

## 12. Update the agents

For Zabbix Agent 2, edit:

```bash
sudo nano /etc/zabbix/zabbix_agent2.conf
```

For the classic Zabbix Agent, edit:

```bash
sudo nano /etc/zabbix/zabbix_agentd.conf
```

Update both parameters:

```ini
Server=192.0.2.20
ServerActive=192.0.2.20
```

Restart the installed agent:

```bash
sudo systemctl restart zabbix-agent2
```

Or:

```bash
sudo systemctl restart zabbix-agent
```

If agents use a DNS name or virtual IP that remains unchanged, agent configuration changes might not be necessary.

## 13. Verify the migration

Check the following:

- The Zabbix frontend opens correctly.
- Hosts report current data.
- Active and passive checks work.
- Graphs and historical data are available.
- Triggers and actions work.
- Email and webhook notifications work.
- Custom scripts are present.
- Zabbix proxies connect to the new server.
- Firewall rules permit the new server.

Check the server port:

```bash
sudo ss -lntp | grep ':10051'
```

## 14. Keep the old server stopped

Do not delete the old server immediately.

Keep its Zabbix and Apache services stopped:

```bash
sudo systemctl disable zabbix-server apache2
```

Retain the old server until the new installation has been validated.

## Rollback

If the migration fails:

Stop services on the new server:

```bash
sudo systemctl stop zabbix-server apache2
```

Start services on the old server:

```bash
sudo systemctl start zabbix-server apache2
```

Do not run both Zabbix servers at the same time.