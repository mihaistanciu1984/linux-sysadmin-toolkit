# Linux Log Analysis

This procedure describes how to inspect system logs, service events, kernel messages, boot problems and recent errors on Linux systems using `journalctl` and traditional log files.

## Display recent system events

```bash
sudo journalctl -n 100
```

Display events in reverse order:

```bash
sudo journalctl -r
```

Follow new events in real time:

```bash
sudo journalctl -f
```

Press `Ctrl+C` to stop following the log.

## Filter by time

Display events from the last hour:

```bash
sudo journalctl --since "1 hour ago"
```

Display events from the current day:

```bash
sudo journalctl --since today
```

Specify a time interval:

```bash
sudo journalctl \
    --since "2026-01-15 08:00:00" \
    --until "2026-01-15 10:00:00"
```

## Filter by priority

Display errors and more critical events:

```bash
sudo journalctl -p err
```

Display warnings and more critical events:

```bash
sudo journalctl -p warning
```

Systemd priorities are:

| Number | Priority |
| -----: | -------- |
|      0 | emerg    |
|      1 | alert    |
|      2 | crit     |
|      3 | err      |
|      4 | warning  |
|      5 | notice   |
|      6 | info     |
|      7 | debug    |

## Analyze service logs

Display logs for a service:

```bash
sudo journalctl -u ssh.service
```

Display events from the current boot:

```bash
sudo journalctl \
    -u ssh.service \
    -b
```

Follow service logs:

```bash
sudo journalctl \
    -u ssh.service \
    -f
```

Display recent service errors:

```bash
sudo journalctl \
    -u ssh.service \
    -p err \
    --since "1 hour ago"
```

## Analyze boot events

List available boots:

```bash
journalctl --list-boots
```

Display the current boot:

```bash
sudo journalctl -b 0
```

Display the previous boot:

```bash
sudo journalctl -b -1
```

Display errors from the current boot:

```bash
sudo journalctl \
    -b \
    -p err
```

## Analyze kernel events

```bash
sudo journalctl -k
```

Current boot kernel errors:

```bash
sudo journalctl \
    -k \
    -b \
    -p err
```

Alternative command:

```bash
sudo dmesg -T
```

Search for common hardware or resource problems:

```bash
sudo journalctl -k |
    grep -Ei \
    'error|failed|timeout|oom|thermal|I/O error|reset'
```

## Traditional log files

List available logs:

```bash
sudo ls -lah /var/log
```

Common files include:

```text
/var/log/auth.log
/var/log/syslog
/var/log/kern.log
/var/log/dpkg.log
/var/log/apt/
/var/log/nginx/
/var/log/apache2/
```

Availability depends on the Linux distribution and installed services.

Follow a text log:

```bash
sudo tail -f /var/log/syslog
```

Search case-insensitively:

```bash
sudo grep -Ei \
    'error|failed|critical|timeout' \
    /var/log/syslog
```

Search rotated and compressed logs:

```bash
sudo zgrep -Ei \
    'error|failed|critical|timeout' \
    /var/log/syslog*.gz
```

## Check journal disk usage

```bash
sudo journalctl --disk-usage
```

Display the journald configuration:

```bash
systemd-analyze cat-config systemd/journald.conf
```

Remove archived logs older than 30 days:

```bash
sudo journalctl --vacuum-time=30d
```

This command deletes archived journal data. Verify retention and compliance requirements before using it.

## Export logs

Export logs in text format:

```bash
sudo journalctl \
    --since "1 hour ago" \
    --no-pager \
    > system-events.txt
```

Export a service log:

```bash
sudo journalctl \
    -u example.service \
    --since today \
    --no-pager \
    > example-service.log
```

Review and sanitize exported files before sharing or committing them to Git.

## Troubleshooting workflow

1. Confirm the system time and timezone:

   ```bash
   timedatectl
   ```

2. Check failed services:

   ```bash
   systemctl --failed
   ```

3. Review errors from the current boot:

   ```bash
   sudo journalctl -b -p err
   ```

4. Review the affected service:

   ```bash
   sudo journalctl -u example.service -n 100
   ```

5. Check kernel events:

   ```bash
   sudo journalctl -k -p err
   ```

6. Correlate timestamps between system, application and infrastructure logs.

7. Verify recent configuration, package and deployment changes.

## Security precautions

Logs can contain:

* usernames;
* internal IP addresses;
* hostnames;
* file paths;
* session identifiers;
* tokens;
* application data;
* customer information.

Always sanitize log files before sharing or committing them to Git.
