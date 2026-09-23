# Configure UFW Firewall on Ubuntu

UFW, or Uncomplicated Firewall, provides a simple method for managing firewall rules on Ubuntu.

Firewall configuration should be one of the first security steps performed after installing the operating system.

> Warning: Always allow SSH before enabling UFW on a remote server. Otherwise, you may lose access to the system.

## Example network

This procedure uses the following documentation network:

```text
192.0.2.0/24
```

Replace it with the management network used in your environment.

## 1. Install UFW

UFW is normally installed by default on Ubuntu.

Install it if necessary:

```bash
sudo apt update
sudo apt install -y ufw
```

Check the installed version:

```bash
sudo ufw version
```

## 2. Check the current status

```bash
sudo ufw status verbose
```

A new installation usually displays:

```text
Status: inactive
```

## 3. Check the SSH port

Before enabling the firewall, verify the SSH port:

```bash
sudo sshd -T | grep '^port '
```

The default SSH port is:

```text
port 22
```

If SSH uses another port, replace port `22` in the following rules.

## 4. Configure the default policies

Block incoming connections by default:

```bash
sudo ufw default deny incoming
```

Allow outgoing connections:

```bash
sudo ufw default allow outgoing
```

## 5. Allow SSH before enabling UFW

### Allow SSH from any network

Use this only when the administrator IP address is not fixed:

```bash
sudo ufw allow OpenSSH
```

Alternatively:

```bash
sudo ufw allow 22/tcp
```

### Recommended: allow SSH only from the management network

```bash
sudo ufw allow from 192.0.2.0/24 to any port 22 proto tcp
```

Do not add both unrestricted and restricted SSH rules unless they are required.

Verify the pending rules:

```bash
sudo ufw show added
```

## 6. Enable UFW

Keep the current SSH session open while enabling the firewall.

```bash
sudo ufw enable
```

Confirm the operation when requested.

Verify the firewall:

```bash
sudo ufw status verbose
```

Open a second terminal and test a new SSH connection before closing the original session:

```bash
ssh example-user@192.0.2.10
```

If the second connection succeeds, the SSH firewall rule is working.

## 7. Common firewall rules

Only add rules for services that are installed and required.

### HTTP

```bash
sudo ufw allow 80/tcp
```

### HTTPS

```bash
sudo ufw allow 443/tcp
```

Apache application profile:

```bash
sudo ufw allow "Apache Full"
```

Nginx application profile:

```bash
sudo ufw allow "Nginx Full"
```

### XRDP from the management network

```bash
sudo ufw allow from 192.0.2.0/24 to any port 3389 proto tcp
```

### Zabbix Agent from one monitoring server

```bash
sudo ufw allow from 192.0.2.10 to any port 10050 proto tcp
```

### MySQL from the management network

```bash
sudo ufw allow from 192.0.2.0/24 to any port 3306 proto tcp
```

Database ports should not be exposed directly to the Internet.

### Allow a TCP port range

```bash
sudo ufw allow 5000:5010/tcp
```

## 8. List application profiles

Packages can provide predefined UFW profiles.

List available profiles:

```bash
sudo ufw app list
```

Display information about a profile:

```bash
sudo ufw app info OpenSSH
```

## 9. Display active rules

Detailed status:

```bash
sudo ufw status verbose
```

Numbered rules:

```bash
sudo ufw status numbered
```

Example:

```text
[ 1] 22/tcp    ALLOW IN    192.0.2.0/24
[ 2] 443/tcp   ALLOW IN    Anywhere
```

## 10. Delete a firewall rule

Display the numbered rules:

```bash
sudo ufw status numbered
```

Delete a rule by its number:

```bash
sudo ufw delete 2
```

Rule numbers change after a rule is deleted. List them again before deleting another rule.

A rule can also be removed using its complete definition:

```bash
sudo ufw delete allow 443/tcp
```

## 11. Deny a specific address

```bash
sudo ufw deny from 192.0.2.25
```

Deny access from an address to a specific port:

```bash
sudo ufw deny from 192.0.2.25 to any port 22 proto tcp
```

Review rule order with:

```bash
sudo ufw status numbered
```

UFW evaluates rules in order, so a previous allow rule may affect the result.

## 12. Configure logging

Enable standard firewall logging:

```bash
sudo ufw logging on
```

For more detailed logging:

```bash
sudo ufw logging medium
```

View recent UFW events:

```bash
sudo journalctl -k | grep UFW
```

Depending on the system configuration, logs may also be available in:

```bash
sudo tail -f /var/log/ufw.log
```

Disable logging:

```bash
sudo ufw logging off
```

## 13. Check IPv6 support

Open the UFW defaults file:

```bash
sudo nano /etc/default/ufw
```

Verify that it contains:

```text
IPV6=yes
```

After modifying this setting, reload UFW:

```bash
sudo ufw reload
```

## 14. Reload the firewall

Most UFW commands apply immediately.

After manual configuration changes, reload the firewall:

```bash
sudo ufw reload
```

## 15. Disable UFW

To temporarily disable the firewall:

```bash
sudo ufw disable
```

Rules are preserved and can be activated again:

```bash
sudo ufw enable
```

## 16. Reset UFW

> Warning: This command deletes all custom firewall rules.

```bash
sudo ufw reset
```

After resetting, configure SSH access again before enabling UFW:

```bash
sudo ufw allow OpenSSH
sudo ufw enable
```

## Recommended initial configuration

For a server managed through SSH from `192.0.2.0/24`:

```bash
sudo apt install -y ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow from 192.0.2.0/24 to any port 22 proto tcp

sudo ufw enable
sudo ufw status verbose
```

Add other ports only when the server requires them.

## Troubleshooting

### SSH connection fails after enabling UFW

Use the local or virtual machine console and check the rules:

```bash
sudo ufw status numbered
```

Add the required SSH rule:

```bash
sudo ufw allow 22/tcp
```

Reload UFW:

```bash
sudo ufw reload
```

### A service is not reachable

Check whether the service is listening:

```bash
sudo ss -lntup
```

Check the firewall rules:

```bash
sudo ufw status numbered
```

Check whether another firewall exists outside the server, such as:

- a cloud security group;
- a Proxmox firewall;
- a router or network firewall;
- a corporate firewall.

### Check the UFW service

```bash
sudo systemctl status ufw --no-pager
```

## Security recommendations

- Allow only the ports required by the server.
- Restrict administration ports to the management network.
- Do not expose SSH, XRDP or database ports directly to the Internet.
- Test SSH access in a second terminal before closing the original connection.
- Review the rules periodically with `sudo ufw status numbered`.
- Use a VPN or SSH tunnel for administrative access when possible.

## Reference

- [How to Set Up UFW Firewall on Ubuntu](https://phoenixnap.com/kb/configure-firewall-with-ufw-on-ubuntu)