# Reset the MySQL or MariaDB Root Password

Use this procedure only when the database root password has been lost.

> Warning: Safe mode temporarily disables normal authentication. Perform this procedure from the local console during a maintenance window.

## 1. Check whether a password reset is required

MariaDB installations may allow the Linux root user to connect through socket authentication:

```bash
sudo mariadb
```

For MySQL, try:

```bash
sudo mysql
```

If the connection succeeds, a password reset may not be necessary. Run `EXIT;` to close the database console.

## 2. Identify the database service

```bash
mysql --version
```

Check which service exists:

```bash
systemctl status mysql --no-pager
systemctl status mariadb --no-pager
```

Use only the commands corresponding to your installed database.

## 3. Stop the database service

For MySQL:

```bash
sudo systemctl stop mysql
```

For MariaDB:

```bash
sudo systemctl stop mariadb
```

## 4. Start the database without authentication

For MySQL:

```bash
sudo mysqld_safe --skip-grant-tables --skip-networking &
```

For MariaDB:

```bash
sudo mariadbd-safe --skip-grant-tables --skip-networking &
```

Wait several seconds:

```bash
sleep 8
```

The `--skip-networking` option prevents remote connections while authentication is disabled.

## 5. Connect to the database

For MySQL:

```bash
sudo mysql -u root
```

For MariaDB:

```bash
sudo mariadb -u root
```

## 6. Reset the root password

Run these commands inside the database console:

```sql
FLUSH PRIVILEGES;

ALTER USER 'root'@'localhost'
IDENTIFIED BY 'REPLACE_WITH_A_STRONG_PASSWORD';

EXIT;
```

Replace `REPLACE_WITH_A_STRONG_PASSWORD` with a strong password.

Do not store the real password in this repository, shell scripts or command history.

## 7. Stop the temporary database instance

For MySQL:

```bash
mysqladmin -u root -p shutdown
```

For MariaDB:

```bash
mariadb-admin -u root -p shutdown
```

Enter the new password when requested.

## 8. Start the normal service

For MySQL:

```bash
sudo systemctl start mysql
sudo systemctl status mysql --no-pager
```

For MariaDB:

```bash
sudo systemctl start mariadb
sudo systemctl status mariadb --no-pager
```

## 9. Test the new password

For MySQL:

```bash
mysql -u root -p
```

For MariaDB:

```bash
mariadb -u root -p
```

After connecting, verify access:

```sql
SHOW DATABASES;
EXIT;
```

## Troubleshooting

If safe mode reports that the runtime directory is missing, create it and retry:

```bash
sudo install -d -o mysql -g mysql -m 755 /run/mysqld
```

Check the database logs if the service does not start:

```bash
sudo journalctl -u mysql -n 50 --no-pager
sudo journalctl -u mariadb -n 50 --no-pager
```

Use only the command corresponding to the installed database service.