# Systemd Service Management and Troubleshooting

This procedure describes how to inspect, manage and troubleshoot services controlled by `systemd`.

## Check service status

```bash
systemctl status ssh.service
```

Display status without opening the pager:

```bash
systemctl status ssh.service --no-pager
```

Check only whether the service is active:

```bash
systemctl is-active ssh.service
```

Check whether it starts automatically:

```bash
systemctl is-enabled ssh.service
```

## Start and stop a service

Start:

```bash
sudo systemctl start ssh.service
```

Stop:

```bash
sudo systemctl stop ssh.service
```

Restart:

```bash
sudo systemctl restart ssh.service
```

Reload configuration without completely restarting the service:

```bash
sudo systemctl reload ssh.service
```

Not every service supports `reload`.

Verify the operational impact before stopping or restarting a production service.

## Enable or disable automatic startup

Enable:

```bash
sudo systemctl enable ssh.service
```

Enable and start immediately:

```bash
sudo systemctl enable --now ssh.service
```

Disable:

```bash
sudo systemctl disable ssh.service
```

Disable and stop immediately:

```bash
sudo systemctl disable --now ssh.service
```

## List failed services

```bash
systemctl --failed
```

List all running services:

```bash
systemctl list-units \
    --type=service \
    --state=running
```

List installed service unit files:

```bash
systemctl list-unit-files --type=service
```

## Review service logs

Display logs for the current boot:

```bash
sudo journalctl -u ssh.service -b
```

Display the last 100 entries:

```bash
sudo journalctl -u ssh.service -n 100
```

Follow logs in real time:

```bash
sudo journalctl -u ssh.service -f
```

Display logs from the last hour:

```bash
sudo journalctl \
    -u ssh.service \
    --since "1 hour ago"
```

Display only warnings and errors:

```bash
sudo journalctl \
    -u ssh.service \
    -p warning
```

## Inspect the service definition

```bash
systemctl cat ssh.service
```

Display important service properties:

```bash
systemctl show ssh.service \
    --property=LoadState,ActiveState,SubState,UnitFileState,MainPID,ExecMainStatus
```

Display service dependencies:

```bash
systemctl list-dependencies ssh.service
```

Display reverse dependencies:

```bash
systemctl list-dependencies \
    --reverse \
    ssh.service
```

## Create a safe override

Do not modify vendor unit files directly.

Create an override:

```bash
sudo systemctl edit example.service
```

Example:

```ini
[Service]
Restart=on-failure
RestartSec=5s
```

Apply the change:

```bash
sudo systemctl daemon-reload
sudo systemctl restart example.service
```

Display the merged configuration:

```bash
systemctl cat example.service
```

## Remove an override

```bash
sudo systemctl revert example.service
sudo systemctl daemon-reload
```

Review the configuration before restarting the service.

## Investigate startup performance

```bash
systemd-analyze
```

Display services ordered by initialization time:

```bash
systemd-analyze blame
```

Display the critical boot chain:

```bash
systemd-analyze critical-chain
```

## Troubleshooting workflow

1. Check the service state:

   ```bash
   systemctl status example.service --no-pager
   ```

2. Review recent logs:

   ```bash
   sudo journalctl -u example.service -n 100
   ```

3. Inspect the unit file:

   ```bash
   systemctl cat example.service
   ```

4. Check the configured executable and environment:

   ```bash
   systemctl show example.service \
       --property=ExecStart,Environment,EnvironmentFiles
   ```

5. Verify permissions, configuration files, ports and dependencies.

6. Test the application configuration using its native validation command.

7. Restart the service only after correcting the underlying problem.

## Important precautions

* Do not restart an unknown production service.
* Do not edit files under `/usr/lib/systemd/system` directly.
* Use `systemctl edit` for local overrides.
* Validate application configuration before restarting.
* Review dependent services and operational impact.
* Keep a copy of custom overrides in configuration management.
