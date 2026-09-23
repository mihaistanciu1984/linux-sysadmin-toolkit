# Install Zabbix Agent 2 on Ubuntu

## Purpose

Install and configure Zabbix Agent 2 from the official Zabbix 7.0 repository.

## Requirements

- Ubuntu 20.04, 22.04 or 24.04
- Root or sudo permissions
- Network access to the Zabbix server

Example configuration:

```text
Zabbix server: 192.0.2.10
Agent hostname: ubuntu-agent-01
Agent port: 10050
```

Replace the example values with your environment values.

## 1. Check the Ubuntu version

```bash
cat /etc/os-release
```

## 2. Install the Zabbix repository

```bash
. /etc/os-release
```

```bash
wget "https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu${VERSION_ID}_all.deb" -O /tmp/zabbix-release.deb
```

```bash
sudo dpkg -i /tmp/zabbix-release.deb
```

```bash
sudo apt update
```

## 3. Install Zabbix Agent 2

```bash
sudo apt install -y zabbix-agent2
```

## 4. Back up the configuration

```bash
sudo cp /etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf.backup
```

## 5. Configure the agent

Open the configuration file:

```bash
sudo nano /etc/zabbix/zabbix_agent2.conf
```

Find and configure the following settings:

```ini
# Zabbix server used for passive checks
Server=192.0.2.10,127.0.0.1

# Zabbix server used for active checks
ServerActive=192.0.2.10

# Hostname must match the host name configured in the Zabbix frontend
Hostname=ubuntu-agent-01
```

Save the file with `Ctrl+O`, press `Enter`, and exit with `Ctrl+X`.

## 6. Create the persistent buffer directory

```bash
sudo mkdir -p /var/spool/zabbix
```

```bash
sudo chown zabbix:zabbix /var/spool/zabbix
```

## 7. Start the agent

```bash
sudo systemctl enable --now zabbix-agent2
```

## 8. Verify the agent

```bash
sudo systemctl status zabbix-agent2 --no-pager
```

Check the recent logs:

```bash
sudo journalctl -u zabbix-agent2 -n 30 --no-pager
```

Test the agent locally:

```bash
sudo zabbix_agent2 -t agent.ping
```

Expected result:

```text
agent.ping [s|1]
```

## Optional: Configure UFW

This step is required only for passive checks when UFW is active.

```bash
sudo ufw allow from 192.0.2.10 to any port 10050 proto tcp
```

Check the firewall:

```bash
sudo ufw status
```

## Final step

Add the Ubuntu system to the Zabbix frontend using exactly the same hostname configured in:

```ini
Hostname=ubuntu-agent-01
```