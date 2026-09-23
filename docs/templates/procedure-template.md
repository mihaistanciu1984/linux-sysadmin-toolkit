# Procedure Title

<!--
Replace "Procedure Title" with a short and clear name.

Examples:
- Configure a Static IP on Ubuntu
- Replace a Failed Ceph OSD
- Install Zabbix Agent 2
-->

## Procedure information

| Field | Value |
|---|---|
| Category | `<Linux / Networking / Proxmox / Ceph / Cisco>` |
| Risk level | `<LOW / MEDIUM / HIGH>` |
| Tested on | `<Operating system and version>` |
| Required access | `<Normal user / sudo / root / console>` |
| Expected downtime | `<None / Estimated duration>` |
| Last verified | `<YYYY-MM-DD>` |

### Risk levels

- `LOW` — read-only checks that do not modify the system.
- `MEDIUM` — service restarts or configuration changes.
- `HIGH` — storage, firewall, cluster or destructive operations.

## Purpose

<!-- Explain in 2-3 sentences what this procedure does. -->

This procedure explains how to `<describe the objective>`.

Use it when:

- `<first situation>`;
- `<second situation>`;
- `<third situation>`.

## Requirements

Before starting, verify that you have:

- `<required operating system or software version>`;
- `<required permissions>`;
- `<required network access>`;
- `<required packages or tools>`;
- a current backup, when applicable;
- console or out-of-band access for high-risk changes.

## Example values

This documentation uses the following example values:

| Setting | Example |
|---|---|
| Server IP | `192.0.2.10` |
| Network | `192.0.2.0/24` |
| Username | `example-user` |
| Hostname | `linux-lab-01` |
| Interface | `eth0` |

Replace all example values with the correct information for your environment.

Do not store passwords, tokens, private keys or production infrastructure information in this document.

## Before you begin

Confirm the current system:

```bash
hostname
whoami
pwd
```

Check the operating system:

```bash
cat /etc/os-release
```

Record the current configuration:

```bash
<COMMAND_USED_TO_DISPLAY_CURRENT_CONFIGURATION>
```

Save the output if it may be required for troubleshooting or rollback.

## Backup

<!-- Remove this section only when a backup is not applicable. -->

Create a backup before changing the configuration:

```bash
sudo cp \
    /path/to/configuration-file \
    /path/to/configuration-file.backup
```

Verify the backup:

```bash
ls -l /path/to/configuration-file.backup
```

For high-risk procedures, confirm that the backup can be restored before continuing.

## Procedure

### 1. First step

<!-- Explain what this step does before displaying the command. -->

```bash
<FIRST_COMMAND>
```

Expected result:

```text
<EXPECTED_OUTPUT>
```

### 2. Second step

```bash
<SECOND_COMMAND>
```

### 3. Apply the configuration

```bash
<APPLY_OR_RESTART_COMMAND>
```

Do not continue if the command returns an unexpected error.

## Verification

Verify that the service or configuration is working:

```bash
<STATUS_COMMAND>
```

Check relevant network ports when applicable:

```bash
sudo ss -lntup
```

Review recent logs:

```bash
sudo journalctl -n 50 --no-pager
```

The procedure is successful when:

- `<first success condition>`;
- `<second success condition>`;
- `<third success condition>`.

## Rollback

Use this section if the procedure causes a problem.

Stop the affected service when necessary:

```bash
<SERVICE_STOP_COMMAND>
```

Restore the original configuration:

```bash
sudo cp \
    /path/to/configuration-file.backup \
    /path/to/configuration-file
```

Restart the service:

```bash
<SERVICE_RESTART_COMMAND>
```

Verify that the previous configuration is restored:

```bash
<ROLLBACK_VERIFICATION_COMMAND>
```

## Troubleshooting

### The service does not start

```bash
sudo systemctl status <SERVICE> --no-pager
sudo journalctl -u <SERVICE> -n 50 --no-pager
```

### The network service is not reachable

```bash
sudo ss -lntup
ip address
ip route
```

Check:

- the service status;
- local firewall rules;
- external firewall rules;
- routing;
- DNS;
- the configured IP address and port.

### Permission denied

Check the file or directory permissions:

```bash
ls -ld /path/to/file-or-directory
```

Do not use `chmod 777` as a general solution.

### Unexpected error

Stop the procedure and record:

```text
Exact command:
Exact error:
Operating system:
Software version:
Recent changes:
Relevant logs:
```

Remove credentials and production information before sharing logs.

## Security considerations

- Use the minimum permissions required.
- Do not expose administrative ports directly to the Internet.
- Do not store credentials inside scripts or documentation.
- Restrict access by IP address or management network when possible.
- Review every command before running it as root.
- Test high-risk operations in a lab environment.

## References

- [Official product documentation](https://example.com/)
- [Additional reference](https://example.com/)

Use official vendor documentation as the primary technical reference.

## Change history

| Date | Change |
|---|---|
| `<YYYY-MM-DD>` | Initial procedure |

## Author checklist

Before committing this document, confirm:

- [ ] The title clearly describes the procedure.
- [ ] The risk level is specified.
- [ ] Requirements are documented.
- [ ] Example values do not contain production information.
- [ ] Commands were tested in a lab environment.
- [ ] Expected results are documented.
- [ ] Verification steps are included.
- [ ] A rollback procedure is included when applicable.
- [ ] Destructive commands have clear warnings.
- [ ] Passwords, tokens and private keys are not included.
- [ ] External links work.
- [ ] The document was reviewed for spelling and formatting.