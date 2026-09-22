# Install Oracle Database XE 21c on Oracle Linux 8

## Purpose

Install and configure Oracle Database Express Edition 21c on Oracle Linux 8.

## Requirements

- Oracle Linux 8 x86-64
- Root or sudo access
- Minimum 1 GB RAM; 2 GB recommended
- Minimum 10 GB free disk space
- Minimum 2 GB swap, or twice the RAM size, whichever is smaller
- Internet access

Check the available resources:

```bash
free -h
df -h /opt
swapon --show
uname -m
```

## 1. Update the system

```bash
sudo dnf upgrade -y
```

Reboot if the kernel was updated:

```bash
sudo reboot
```

## 2. Install Oracle Database prerequisites

```bash
sudo dnf install -y oracle-database-preinstall-21c
```

This package installs the required dependencies, creates the Oracle user and configures the required kernel parameters.

## 3. Download Oracle Database XE

Download the Oracle Linux 8 RPM from:

https://www.oracle.com/database/technologies/xe-downloads.html

File name:

```text
oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm
```

Verify the downloaded file:

```bash
sha256sum oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm
```

Expected SHA256:

```text
f8357b432de33478549a76557e8c5220ec243710ed86115c65b0c2bc00a848db
```

## 4. Install Oracle Database XE

Navigate to the download directory and run:

```bash
sudo dnf localinstall -y \
  oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm
```

## 5. Configure the database

```bash
sudo /etc/init.d/oracle-xe-21c configure
```

Enter a strong password when requested.

The same password is configured for:

- SYS
- SYSTEM
- PDBADMIN

The default configuration creates:

- Container database: `XE`
- Pluggable database: `XEPDB1`
- Listener port: `1521`
- EM Express port: `5500`

## 6. Enable automatic startup

```bash
sudo systemctl daemon-reload
sudo systemctl enable oracle-xe-21c
```

## 7. Verify the service

```bash
sudo systemctl status oracle-xe-21c
sudo /etc/init.d/oracle-xe-21c status
```

Verify the listening ports:

```bash
sudo ss -lntp | grep -E ':1521|:5500'
```

## 8. Connect with SQL*Plus

Switch to the Oracle account:

```bash
sudo -iu oracle
```

Configure the environment:

```bash
export ORACLE_SID=XE
export ORAENV_ASK=NO
. /opt/oracle/product/21c/dbhomeXE/bin/oraenv
```

Connect to the database:

```bash
sqlplus / as sysdba
```

Check the pluggable database:

```sql
SELECT name, open_mode FROM v$pdbs;
```

Exit SQL*Plus:

```sql
EXIT;
```

## Service management

Start Oracle XE:

```bash
sudo systemctl start oracle-xe-21c
```

Stop Oracle XE:

```bash
sudo systemctl stop oracle-xe-21c
```

Restart Oracle XE:

```bash
sudo systemctl restart oracle-xe-21c
```

## Important locations

| Location | Purpose |
|---|---|
| `/opt/oracle` | Oracle base directory |
| `/opt/oracle/product/21c/dbhomeXE` | Oracle home |
| `/opt/oracle/oradata/XE` | Database files |
| `/opt/oracle/diag` | Diagnostic logs |
| `/etc/sysconfig/oracle-xe-21c.conf` | XE configuration |