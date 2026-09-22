# OpenSSH Server Hardening

This procedure describes a safe approach for improving the security of an OpenSSH server.

Always maintain an existing administrative session and test a second SSH connection before closing the original session.

Official reference:

https://man.openbsd.org/sshd_config

## Back up the configuration

```bash
sudo cp \
    /etc/ssh/sshd_config \
    /etc/ssh/sshd_config.backup
```

On systems using configuration drop-ins:

```bash
sudo ls -la /etc/ssh/sshd_config.d/
```

## Configure SSH key authentication

Generate an Ed25519 key on the administration workstation:

```bash
ssh-keygen -t ed25519 -a 100
```

Copy the public key:

```bash
ssh-copy-id example-admin@192.0.2.10
```

Test the key before disabling password authentication:

```bash
ssh \
    -o PreferredAuthentications=publickey \
    example-admin@192.0.2.10
```

Keep the successful session open while applying configuration changes.

## Create a hardening drop-in

On Ubuntu and Debian:

```bash
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf
```

Recommended baseline:

```text
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
```

Optional access restriction:

```text
AllowUsers example-admin
```

Do not configure `AllowUsers` until all required administrative and automation accounts have been identified.

## Validate the configuration

Always validate before reloading:

```bash
sudo sshd -t
```

No output means that the syntax is valid.

Display effective settings:

```bash
sudo sshd -T |
    grep -E \
    'permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitemptypasswords|maxauthtries|logingracetime|x11forwarding'
```

## Apply the change safely

On Ubuntu or Debian:

```bash
sudo systemctl reload ssh.service
```

On some distributions:

```bash
sudo systemctl reload sshd.service
```

Keep the existing session open and test a second connection:

```bash
ssh example-admin@192.0.2.10
```

Only close the original session after confirming that the new connection works.

## Check file permissions

User SSH directory:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Verify ownership:

```bash
ls -ld ~/.ssh
ls -l ~/.ssh/authorized_keys
```

The files should belong to the expected user.

## Review listening sockets

```bash
sudo ss -lntp |
    grep ssh
```

Changing the default port can reduce automated log noise but is not a replacement for key authentication, firewall restrictions and access controls.

## Restrict network access

UFW example:

```bash
sudo ufw allow \
    from 192.0.2.0/24 \
    to any port 22 \
    proto tcp
```

Review the rules before enabling the firewall:

```bash
sudo ufw status verbose
```

Use the actual management network instead of the documentation address.

## Review authentication attempts

Ubuntu and Debian:

```bash
sudo journalctl \
    -u ssh.service \
    --since "1 hour ago"
```

Search failed authentication attempts:

```bash
sudo journalctl \
    -u ssh.service \
    --since today |
    grep -Ei \
    'failed password|invalid user|authentication failure'
```

Traditional authentication log:

```bash
sudo grep -Ei \
    'failed password|invalid user|authentication failure' \
    /var/log/auth.log
```

## Optional forwarding restrictions

If the server does not require SSH tunnels:

```text
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
```

Do not apply these restrictions when SSH forwarding is required for automation, administration, backups or application access.

## Recovery

If a configuration change prevents new SSH sessions, use an existing session or the server console.

Restore the backup:

```bash
sudo cp \
    /etc/ssh/sshd_config.backup \
    /etc/ssh/sshd_config
```

Remove or correct the hardening drop-in:

```bash
sudo rm \
    /etc/ssh/sshd_config.d/99-hardening.conf
```

Validate and reload:

```bash
sudo sshd -t
sudo systemctl reload ssh.service
```

## Security recommendations

* Prefer Ed25519 SSH keys.
* Protect private keys with a passphrase.
* Disable direct root login.
* Disable password authentication only after testing SSH keys.
* Restrict access using firewall rules.
* Review failed authentication attempts.
* Remove unused authorized keys.
* Avoid hardcoding private keys in automation.
* Do not commit private keys or real SSH configuration exports to Git.
* Keep OpenSSH packages updated.
