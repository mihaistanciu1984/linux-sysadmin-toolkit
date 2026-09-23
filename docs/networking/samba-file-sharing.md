# Samba Installation and File Sharing

This procedure explains how to install Samba on Ubuntu and configure an authenticated file share.

Two configuration methods are included:

1. Standard configuration in `/etc/samba/smb.conf`
2. Separate configuration file for centrally managed systems

Use only the method appropriate for your system.

## 1. Install Samba

Update the package index:

```bash
sudo apt update
```

Install Samba and the SMB client utilities:

```bash
sudo apt install -y samba smbclient
```

Check the installation:

```bash
whereis samba
smbd --version
```

Enable and start the Samba service:

```bash
sudo systemctl enable --now smbd
```

Verify the service:

```bash
systemctl status smbd --no-pager
```

## 2. Create the shared directory

This example uses:

```text
/mnt/folder-to-share
```

Create the directory:

```bash
sudo mkdir -p /mnt/folder-to-share
```

Replace `example-user` with the Linux account that will access the share:

```bash
sudo chown -R example-user:example-user /mnt/folder-to-share
sudo chmod 750 /mnt/folder-to-share
```

Verify that the user exists:

```bash
id example-user
```

If the user does not exist, create it:

```bash
sudo adduser example-user
```

## 3. Method 1: Standard Samba configuration

Back up the existing configuration:

```bash
sudo cp \
    /etc/samba/smb.conf \
    /etc/samba/smb.conf.backup
```

Open the configuration:

```bash
sudo nano /etc/samba/smb.conf
```

Add the following section at the bottom:

```ini
[mnt]
    path = /mnt/folder-to-share
    browseable = yes
    read only = yes
    valid users = example-user
```

This configuration creates an authenticated read-only share.

### Optional read-write configuration

To allow the user to modify files, use:

```ini
[mnt]
    path = /mnt/folder-to-share
    browseable = yes
    read only = no
    valid users = example-user
    create mask = 0660
    directory mask = 0770
```

The Linux filesystem permissions must also allow the user to write to the directory.

## 4. Method 2: Separate configuration file

Use this method when the main `smb.conf` file is managed or regenerated automatically.

Create the configuration directory:

```bash
sudo install -d -m 755 /opt/user/etc
```

Create the separate configuration file:

```bash
sudo nano /opt/user/etc/smb_sharing.conf
```

Add:

```ini
[mnt]
    path = /mnt/folder-to-share
    browseable = yes
    read only = yes
    valid users = example-user
```

The separate file must be included by the main Samba configuration.

Open:

```bash
sudo nano /etc/samba/smb.conf
```

Add this line inside the `[global]` section:

```ini
include = /opt/user/etc/smb_sharing.conf
```

> If `/etc/samba/smb.conf` is managed by company automation, confirm that the external file is already included or request that the include directive be added to the managed configuration. Creating the external file alone is not sufficient.

## 5. Configure the Samba password

Samba maintains its own authentication database.

Add the Linux user to Samba:

```bash
sudo smbpasswd -a example-user
```

Enable the Samba account:

```bash
sudo smbpasswd -e example-user
```

The Samba password does not need to be identical to the Linux account password.

## 6. Validate the configuration

Always validate the configuration before restarting Samba:

```bash
sudo testparm -s
```

`testparm` checks the internal correctness of the Samba configuration. A successful validation does not guarantee that filesystem permissions or network access are correct. :contentReference[oaicite:0]{index=0}

Display the configured share:

```bash
sudo testparm -s |
    sed -n '/^\[mnt\]/,/^$/p'
```

Do not restart Samba if `testparm` reports an error.

## 7. Restart Samba

```bash
sudo systemctl restart smbd
```

Check the service:

```bash
systemctl status smbd --no-pager
```

## 8. Configure the firewall

Check whether UFW is active:

```bash
sudo ufw status
```

Allow the Samba application profile:

```bash
sudo ufw allow Samba
```

Verify the rules:

```bash
sudo ufw status
```

## 9. Test the share locally

List the available shares:

```bash
smbclient -L localhost -U example-user
```

Connect to the share:

```bash
smbclient //localhost/mnt -U example-user
```

Exit the SMB client with:

```text
exit
```

## 10. Connect from Windows

Open File Explorer and enter:

```text
\\SERVER_IP\mnt
```

For example, using a documentation address:

```text
\\192.0.2.10\mnt
```

Enter the Samba username and password when requested.

## Troubleshooting

### Check the service

```bash
systemctl status smbd --no-pager
```

### Check recent logs

```bash
journalctl -u smbd -n 100 --no-pager
```

### Check listening ports

```bash
sudo ss -lntup |
    grep -E ':139|:445'
```

### Check directory permissions

```bash
namei -l /mnt/folder-to-share
```

### Check the Samba user

```bash
sudo pdbedit -L
```

### Check the configuration

```bash
sudo testparm -s
```

## Security notes

- Do not configure `guest ok = yes` unless anonymous access is required.
- Restrict access with `valid users`.
- Use Linux permissions to protect the shared directory.
- Do not expose SMB ports directly to the internet.
- Use a firewall to restrict access to trusted networks.
- Back up `smb.conf` before changing it.