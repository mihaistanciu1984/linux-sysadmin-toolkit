# Install XRDP on Ubuntu 24.04

XRDP provides graphical remote access to an Ubuntu system using the Remote Desktop Protocol.

This procedure installs:

- XFCE desktop environment
- XRDP server
- Xorg XRDP backend
- An XFCE session for the selected Linux user

## Requirements

Before starting, verify that you have:

- Ubuntu 24.04
- A user with `sudo` privileges
- An existing Linux user for the RDP connection
- A password configured for that Linux user
- Network access to TCP port `3389`, or an SSH tunnel

XRDP uses the Linux username and password. SSH key authentication cannot replace the password at the XRDP login screen.

## Automated installation

Run the script from the repository root:

```bash
sudo bash scripts/remote-access/install_xrdp_ubuntu.sh example-user
```

To create a firewall rule for a specific network:

```bash
sudo bash scripts/remote-access/install_xrdp_ubuntu.sh \
    example-user \
    192.0.2.0/24
```

Replace:

- `example-user` with the existing Linux username;
- `192.0.2.0/24` with the authorized management network.

The script does not enable UFW automatically.

## Set the Linux account password

If the user does not have a password or the account is locked, set a password:

```bash
sudo passwd example-user
```

Do not store the password in the script or repository.

## Manual installation

Update the package index:

```bash
sudo apt update
```

Install XFCE, XRDP and the Xorg backend:

```bash
sudo apt install -y xfce4 xfce4-goodies xrdp xorgxrdp
```

Allow XRDP to read the system TLS certificate:

```bash
sudo usermod -aG ssl-cert xrdp
```

Configure XFCE for the user who will connect through RDP:

```bash
echo "startxfce4" > ~/.xsession
chmod 644 ~/.xsession
```

Enable and restart XRDP:

```bash
sudo systemctl enable xrdp
sudo systemctl restart xrdp
```

## Firewall configuration

Do not expose TCP port `3389` directly to the Internet.

If UFW is active, allow only the management network:

```bash
sudo ufw allow from 192.0.2.0/24 to any port 3389 proto tcp
```

Verify the firewall:

```bash
sudo ufw status
```

## Verify XRDP

Check the service:

```bash
sudo systemctl status xrdp --no-pager
```

Verify that port `3389` is listening:

```bash
sudo ss -lntp | grep 3389
```

Check the server IP address:

```bash
hostname -I
```

## Connect from Windows

1. Press `Windows + R`.
2. Enter:

```text
mstsc
```

3. Enter the Ubuntu server IP address.
4. Select the `Xorg` session if the XRDP login screen requests a session.
5. Enter the Linux username and password.

Log out from any active local graphical session before connecting with XRDP using the same user.

## Connect through an SSH tunnel

An SSH tunnel is safer than exposing port `3389`.

Run this command from the client:

```bash
ssh -L 13389:127.0.0.1:3389 example-user@192.0.2.10 -N
```

Keep the SSH terminal open.

Open Remote Desktop Connection and connect to:

```text
127.0.0.1:13389
```

## Troubleshooting

### XRDP is not running

```bash
sudo systemctl restart xrdp
sudo systemctl status xrdp --no-pager
```

### Black or blue screen

Verify the user session file:

```bash
cat ~/.xsession
```

It should contain:

```text
startxfce4
```

Log out from active graphical sessions and restart XRDP:

```bash
sudo systemctl restart xrdp
```

### Certificate permission error

Verify that `xrdp` belongs to the `ssl-cert` group:

```bash
getent group ssl-cert
```

Add it if necessary:

```bash
sudo usermod -aG ssl-cert xrdp
sudo systemctl restart xrdp
```

### Login fails immediately

Verify that the Linux user has a password:

```bash
sudo passwd -S example-user
```

Set a new password if required:

```bash
sudo passwd example-user
```

### Check XRDP logs

```bash
sudo journalctl -u xrdp -n 50 --no-pager
```

```bash
sudo tail -n 50 /var/log/xrdp.log
```

```bash
sudo tail -n 50 /var/log/xrdp-sesman.log
```

## Uninstall XRDP

```bash
sudo systemctl disable --now xrdp
sudo apt remove -y xrdp xorgxrdp
```

Removing XFCE is optional because it may also be used locally.

## References

- [XRDP project](https://github.com/neutrinolabs/xrdp)
- [Ubuntu xorgxrdp package](https://packages.ubuntu.com/noble/xorgxrdp)
- [Linux Genie XRDP guide](https://linuxgenie.net/install-remote-desktop-xrdp-ubuntu-24-04/)