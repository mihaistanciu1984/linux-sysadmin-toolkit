# HTCondor Role Configuration and Service Validation

This procedure explains how to validate HTCondor node roles, start the required services and confirm that the pool is operational.

It does not guarantee a specific uptime level and does not configure Central Manager high availability.

## HTCondor roles

| Role                                | Required daemons                        | Purpose                                                   |
| ----------------------------------- | --------------------------------------- | --------------------------------------------------------- |
| Central Manager                     | `MASTER, COLLECTOR, NEGOTIATOR`         | Collects pool information and matches jobs with resources |
| Submit Node                         | `MASTER, SCHEDD`                        | Accepts and manages jobs                                  |
| Execute Node                        | `MASTER, STARTD`                        | Provides execution slots                                  |
| Combined Central Manager and Submit | `MASTER, COLLECTOR, NEGOTIATOR, SCHEDD` | Suitable only for smaller environments                    |

A dedicated Central Manager normally does not require `SCHEDD`.

## Important: installer-managed configuration

If the node was configured using:

```text
scripts/htcondor/install_htcondor_role.sh
```

do not immediately create a manual `DAEMON_LIST`.

The official role installer uses HTCondor role metaknobs and may already have generated the required configuration.

Inspect the effective configuration first:

```bash
condor_config_val CONDOR_HOST
condor_config_val DAEMON_LIST
condor_config_val LOCAL_CONFIG_DIR
condor_config_val -summary
```

Inspect the local configuration files:

```bash
sudo find \
    "$(condor_config_val LOCAL_CONFIG_DIR)" \
    -maxdepth 1 \
    -type f \
    -print \
    -exec sed -n '1,120p' {} \;
```

If the effective values are correct, keep the installer-managed configuration.

## Configuration directory

Do not assume that the local configuration directory is always:

```text
/etc/condor/config.d
```

Determine it with:

```bash
condor_config_val LOCAL_CONFIG_DIR
```

On many package-based installations it is:

```text
/etc/condor/config.d
```

Local configuration files should use a `.config` extension, for example:

```text
50-main.config
```

Avoid using:

```text
50-main.conf
```

## Central Manager configuration

Use this only for a manually configured, dedicated Central Manager.

Create or edit:

```bash
sudo nano /etc/condor/config.d/50-main.config
```

Add:

```text
CONDOR_HOST = condor-manager.example.com
DAEMON_LIST = MASTER, COLLECTOR, NEGOTIATOR
```

Prefer a stable, resolvable hostname for `CONDOR_HOST`.

Verify DNS:

```bash
getent hosts condor-manager.example.com
```

If the Central Manager must also accept job submissions, use:

```text
CONDOR_HOST = condor-manager.example.com
DAEMON_LIST = MASTER, COLLECTOR, NEGOTIATOR, SCHEDD
```

A combined role is normally appropriate only for a small pool or laboratory environment.

## Submit Node configuration

Create or edit:

```bash
sudo nano /etc/condor/config.d/50-main.config
```

Add:

```text
CONDOR_HOST = condor-manager.example.com
DAEMON_LIST = MASTER, SCHEDD
```

The `CONDOR_HOST` value must point to the same Central Manager used by all nodes in the pool.

## Execute Node configuration

Create or edit:

```bash
sudo nano /etc/condor/config.d/50-main.config
```

Add:

```text
CONDOR_HOST = condor-manager.example.com
DAEMON_LIST = MASTER, STARTD
```

An Execute node does not normally require `COLLECTOR`, `NEGOTIATOR` or `SCHEDD`.

## Validate the effective configuration

Run on every node:

```bash
condor_config_val CONDOR_HOST
condor_config_val DAEMON_LIST
condor_config_val LOCAL_CONFIG_DIR
```

Display a configuration summary:

```bash
condor_config_val -summary
```

The expected daemon list depends on the node role.

### Central Manager

```text
MASTER, COLLECTOR, NEGOTIATOR
```

### Submit Node

```text
MASTER, SCHEDD
```

### Execute Node

```text
MASTER, STARTD
```

Resolve the Central Manager:

```bash
getent hosts "$(condor_config_val CONDOR_HOST)"
```

Check TCP port `9618`:

```bash
nc -zv \
    -w 5 \
    "$(condor_config_val CONDOR_HOST)" \
    9618
```

## Enable and start HTCondor

Run on every node:

```bash
sudo systemctl enable --now condor
```

Verify:

```bash
systemctl is-enabled condor
systemctl is-active condor
systemctl status condor --no-pager
```

Expected results:

```text
enabled
active
```

After changing a role or daemon list, restart HTCondor:

```bash
sudo systemctl restart condor
```

Check again:

```bash
systemctl status condor --no-pager
```

For non-role configuration changes, HTCondor can normally be instructed to reload its configuration:

```bash
sudo condor_reconfig
```

## Validate the pool

Run from the Central Manager or Submit node.

Display registered machines:

```bash
condor_status
```

Display registered HTCondor masters:

```bash
condor_status -master
```

Display machine names and slot states:

```bash
condor_status -af Name State Activity
```

Display Submit daemons:

```bash
condor_status -schedd
```

Display the job queue:

```bash
condor_q
```

An available Execute slot normally appears with:

```text
State    = Unclaimed
Activity = Idle
```

`Unclaimed` means that the slot is not currently assigned to a job. Confirm the `Activity` field as well; the state alone is not a complete health check.

## Use the repository health checker

Run:

```bash
bash scripts/htcondor/check_htcondor_pool.sh \
    --manager condor-manager.example.com \
    --min-slots 1
```

The checker validates:

* `condor.service`;
* effective configuration;
* Central Manager DNS resolution;
* TCP port `9618`;
* registered masters;
* execution slots;
* access to the job queue.

## Validate individual roles

### Central Manager

Check the expected processes:

```bash
pgrep -af \
    'condor_(master|collector|negotiator)'
```

Check the pool:

```bash
condor_status -master
```

### Submit Node

Check:

```bash
pgrep -af \
    'condor_(master|schedd)'
```

Check the queue:

```bash
condor_q
```

### Execute Node

Check:

```bash
pgrep -af \
    'condor_(master|startd)'
```

Check the local slot advertisement:

```bash
condor_status \
    -constraint 'Machine == "'$(hostname -f)'"' \
    -af Name State Activity
```

If the system advertises a different hostname, identify it using:

```bash
condor_status -af Machine
```

## Logs

Find the configured log directory:

```bash
condor_config_val LOG
```

Inspect the service journal:

```bash
sudo journalctl \
    -u condor \
    --since "30 minutes ago" \
    --no-pager
```

Common logs include:

| Role            | Logs                            |
| --------------- | ------------------------------- |
| All nodes       | `MasterLog`                     |
| Central Manager | `CollectorLog`, `NegotiatorLog` |
| Submit Node     | `SchedLog`                      |
| Execute Node    | `StartLog`, `StarterLog`        |

Follow the master log:

```bash
sudo tail -f \
    "$(condor_config_val LOG)/MasterLog"
```

## Troubleshooting

### Execute node does not appear

On the Execute node, check:

```bash
systemctl is-active condor
condor_config_val CONDOR_HOST
condor_config_val DAEMON_LIST
getent hosts "$(condor_config_val CONDOR_HOST)"
```

Check connectivity:

```bash
nc -zv \
    -w 5 \
    "$(condor_config_val CONDOR_HOST)" \
    9618
```

Review:

```bash
sudo journalctl \
    -u condor \
    -n 100 \
    --no-pager
```

### Incorrect daemon list

Find where `DAEMON_LIST` is defined:

```bash
condor_config_val \
    -verbose \
    DAEMON_LIST
```

Do not create multiple conflicting definitions without understanding the configuration precedence.

### Pool is visible but has no available slots

Check:

```bash
condor_status -af Name State Activity
```

On Execute nodes, inspect:

```bash
condor_config_val DAEMON_LIST
systemctl status condor --no-pager
sudo tail -n 100 \
    "$(condor_config_val LOG)/StartLog"
```

### Submit node cannot submit jobs

Check:

```bash
condor_config_val DAEMON_LIST
condor_status -schedd
condor_q
```

Confirm that `SCHEDD` is present on the Submit node.

## Availability considerations

These service settings improve operational consistency but do not guarantee `99%` uptime.

A single Central Manager is a point of failure for scheduling and pool queries.

Higher availability also requires:

* Central Manager high-availability design;
* configuration backups;
* monitoring and alerting;
* redundant DNS and networking;
* time synchronization;
* controlled package updates;
* capacity monitoring;
* tested recovery procedures;
* regular submission and execution tests.

Consult the official HTCondor high-availability documentation before implementing redundant Central Managers.

## Official documentation

* [HTCondor Administrative Quick Start Guide](https://htcondor.readthedocs.io/en/lts/getting-htcondor/admin-quick-start.html)
* [HTCondor configuration introduction](https://htcondor.readthedocs.io/en/lts/admin-manual/introduction-to-configuration.html)
* [HTCondor networking](https://htcondor.readthedocs.io/en/lts/admin-manual/networking.html)
