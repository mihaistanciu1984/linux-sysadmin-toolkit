# Install Proxmox Backup Client on Linux

This procedure describes how to install Proxmox Backup Client using the repository installer included in this project.

The installation script is located at:

```text
scripts/virtualization/proxmox/install_pbs_client.sh
```

The installer performs a dry-run by default and does not configure PBS credentials, API tokens or backup jobs.

## Supported systems

| Operating system   | Architecture | Installation mode                     |
| ------------------ | ------------ | ------------------------------------- |
| Debian 12 Bookworm | `amd64`      | Official client-only repository       |
| Debian 13 Trixie   | `amd64`      | Official client-only repository       |
| Ubuntu 22.04 LTS   | `amd64`      | Compatibility mode with static client |
| Ubuntu 24.04 LTS   | `amd64`      | Compatibility mode with static client |

The Proxmox client-only repository is officially tested on the corresponding Debian releases.

Ubuntu installation uses the statically linked client package and must be explicitly enabled with `--allow-ubuntu`. Validate Ubuntu compatibility in a non-production environment before deployment.

## What the installer does

The script:

1. Detects the operating system version.
2. Validates the CPU architecture.
3. Selects the appropriate client repository suite.
4. Installs prerequisite packages.
5. Downloads the official Proxmox archive key.
6. Verifies the key using its published SHA-256 checksum.
7. Configures the PBS client-only APT repository.
8. Installs `proxmox-backup-client-static`.
9. Displays the installed client version.

The script does not:

* configure PBS credentials;
* create an API token;
* store a password;
* configure a backup source;
* schedule a cron job;
* configure retention;
* connect automatically to a PBS instance.

## Prerequisites

The target system requires:

* root or `sudo` access;
* an APT-based operating system;
* an `amd64` or `x86-64` processor;
* Internet access to the official Proxmox repositories;
* DNS resolution;
* a working Debian or Ubuntu package manager.

Display the operating system:

```bash
cat /etc/os-release
```

Display the architecture:

```bash
dpkg --print-architecture
```

Expected architecture:

```text
amd64
```

Test access to the Proxmox repository:

```bash
curl -I \
    http://download.proxmox.com/debian/pbs-client/
```

## Step 1 — Review the installer

Check the Bash syntax:

```bash
bash -n \
    scripts/virtualization/proxmox/install_pbs_client.sh
```

Display the available options:

```bash
bash \
    scripts/virtualization/proxmox/install_pbs_client.sh \
    --help
```

Review the script before running it:

```bash
less \
    scripts/virtualization/proxmox/install_pbs_client.sh
```

## Step 2 — Run the dry-run

The default mode does not modify the system:

```bash
bash \
    scripts/virtualization/proxmox/install_pbs_client.sh \
    --dry-run
```

The output should show:

* detected operating system;
* architecture;
* selected repository;
* package name;
* installation mode;
* operations that would be performed.

Do not continue if the detected operating system or repository is incorrect.

## Step 3 — Install on Debian 12 or Debian 13

Run:

```bash
sudo bash \
    scripts/virtualization/proxmox/install_pbs_client.sh \
    --apply
```

The script configures:

```text
/etc/apt/sources.list.d/pbs-client.sources
```

The Proxmox archive key is installed at:

```text
/usr/share/keyrings/proxmox-archive-keyring.gpg
```

## Step 4 — Install on Ubuntu 22.04 or Ubuntu 24.04

First run the dry-run:

```bash
bash \
    scripts/virtualization/proxmox/install_pbs_client.sh \
    --dry-run \
    --allow-ubuntu
```

Apply the installation:

```bash
sudo bash \
    scripts/virtualization/proxmox/install_pbs_client.sh \
    --apply \
    --allow-ubuntu
```

The installer displays a compatibility warning and requires the operator to type:

```text
APPLY
```

Ubuntu compatibility mode uses the Bookworm client-only repository and the statically linked package.

Test this combination before using it on a production server.

## Step 5 — Verify the package

Check the executable:

```bash
command -v proxmox-backup-client
```

Display the installed version:

```bash
proxmox-backup-client version
```

Inspect the installed package:

```bash
dpkg-query \
    -W \
    -f='${Package} ${Version} ${Status}\n' \
    proxmox-backup-client-static
```

Expected package status:

```text
install ok installed
```

## Step 6 — Verify the repository

Display the repository configuration:

```bash
cat /etc/apt/sources.list.d/pbs-client.sources
```

Display the package candidate:

```bash
apt-cache policy proxmox-backup-client-static
```

Verify that the candidate originates from:

```text
download.proxmox.com/debian/pbs-client
```

## Step 7 — Verify the release key

Display the SHA-256 checksum:

```bash
sha256sum \
    /usr/share/keyrings/proxmox-archive-keyring.gpg
```

Compare it with the checksum published in the current official Proxmox documentation.

If the installer reports a checksum mismatch:

1. Stop the installation.
2. Do not disable checksum verification.
3. Check whether Proxmox has published a new key.
4. Verify the new checksum using the official Proxmox website.
5. Update both the key URL and checksum in the script.
6. Review and test the change before committing it.

## Step 8 — Test access to the PBS server

The default PBS HTTPS port is `8007`.

Test DNS:

```bash
getent hosts pbs.example.com
```

Test TCP connectivity:

```bash
nc -zv -w 5 pbs.example.com 8007
```

Do not add real PBS hostnames or internal addresses to the public repository.

## Step 9 — Continue with backup configuration

After installing the client, continue with:

[Automated Linux Configuration Backup to Proxmox Backup Server](pbs-client-backup.md)

That procedure explains:

* creating a dedicated API token;
* storing the token secret outside Git;
* using `PBS_PASSWORD_FILE`;
* configuring the backup source;
* running a dry-run;
* scheduling the backup;
* configuring server-side retention;
* validating a restore.

## Troubleshooting

### Unsupported operating system

The installer stops when the detected operating system is not included in its supported matrix.

Check:

```bash
cat /etc/os-release
```

Do not bypass the check without reviewing package compatibility.

### Unsupported architecture

The installer supports only:

```text
amd64
```

Check:

```bash
dpkg --print-architecture
uname -m
```

The official static package may not be available for ARM systems.

### Repository update fails

Run:

```bash
sudo apt-get update
```

Inspect:

```bash
cat /etc/apt/sources.list.d/pbs-client.sources
ls -l /usr/share/keyrings/proxmox-archive-keyring.gpg
```

Check DNS and HTTP connectivity:

```bash
getent hosts download.proxmox.com
curl -I \
    http://download.proxmox.com/debian/pbs-client/
```

### Package conflict

The packages below provide the same executable and should not be installed together:

```text
proxmox-backup-client
proxmox-backup-client-static
```

Inspect installed packages:

```bash
dpkg-query -l |
    grep proxmox-backup-client
```

Review dependencies before removing or replacing an existing package.

### Client command is missing

Search for the executable:

```bash
command -v proxmox-backup-client
find /usr -type f \
    -name proxmox-backup-client \
    2>/dev/null
```

Inspect the package:

```bash
dpkg-query -L \
    proxmox-backup-client-static
```

## Security considerations

* Download repository keys only from the official Proxmox domain.
* Verify the published key checksum.
* Use a `Signed-By` repository configuration.
* Do not use `apt-key`.
* Do not place API tokens in the installer.
* Do not export `PBS_PASSWORD` in a public script.
* Do not publish internal PBS addresses or datastore names.
* Use a dedicated token with minimal permissions for each client.
* Keep backup credentials outside the Git repository.
* Test installer changes on a non-production system.

## Official documentation

* [Proxmox Backup Server installation](https://pbs.proxmox.com/docs/installation.html)
* [Proxmox Backup Client usage](https://pbs.proxmox.com/docs/backup-client.html)
* [proxmox-backup-client command reference](https://pbs.proxmox.com/docs/proxmox-backup-client/man1.html)
