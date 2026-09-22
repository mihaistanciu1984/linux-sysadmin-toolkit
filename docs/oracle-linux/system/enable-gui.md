# Enable GNOME Desktop on Oracle Linux

## Purpose

Install the GNOME graphical desktop on Oracle Linux 8 or 9.

## Requirements

- Oracle Linux 8 or 9
- Internet access
- Root or sudo permissions
- At least 2 GB of available RAM

## 1. Check the operating system

```bash
cat /etc/oracle-release
```

## 2. Update the system

This step is recommended but optional.

```bash
sudo dnf upgrade -y
```

## 3. Check the available GUI group

```bash
sudo dnf group list
sudo dnf group info "Server with GUI"
```

## 4. Install GNOME Desktop

```bash
sudo dnf group install "Server with GUI" -y
```

The installation can take several minutes and may download many packages.

## 5. Enable graphical startup

```bash
sudo systemctl set-default graphical.target
```

Verify the default startup mode:

```bash
systemctl get-default
```

Expected result:

```text
graphical.target
```

## 6. Restart the system

```bash
sudo reboot
```

After the restart, the GNOME graphical login screen should appear on the local or virtual console.

## Verification

```bash
systemctl status gdm
```

The GDM service should show:

```text
active (running)
```

## Return to command-line startup

To disable automatic graphical startup:

```bash
sudo systemctl set-default multi-user.target
sudo reboot
```

## Remote access note

Installing GNOME does not automatically provide remote graphical access.

For a server without a physical or virtual console, configure a remote access service separately, such as:

- GNOME Remote Desktop
- VNC
- X11 forwarding over SSH

## Recommendation

Avoid installing a graphical desktop on production servers unless it is required. A GUI consumes additional memory and CPU resources and increases the number of installed packages.