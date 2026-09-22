# HTCondor Cluster Installation

This procedure describes how to install and configure a basic HTCondor pool on Linux.

The installation uses the official `get_htcondor` installer through the helper script:

```text
scripts/htcondor/install_htcondor_role.sh
```

## Architecture

A basic HTCondor pool contains three roles:

| Role            | Example hostname               | Purpose                                                             |
| --------------- | ------------------------------ | ------------------------------------------------------------------- |
| Central Manager | `condor-manager.example.com`   | Collects pool information and matches jobs with available resources |
| Submit Node     | `condor-submit.example.com`    | Accepts and manages submitted jobs                                  |
| Execute Node    | `condor-worker-01.example.com` | Provides CPU and memory resources for running jobs                  |

For a production environment, the roles should normally be installed on separate systems.

For a small laboratory environment, multiple roles may run on the same system.

## Installation order

Install the nodes in this order:

1. Central Manager
2. Submit Node
3. Execute Nodes

All nodes in the same pool must use the same HTCondor pool password.

> Never store the pool password in Git, scripts, documentation, shell history, or configuration examples.

## Example environment

The following values are examples only:

| System          | Hostname                       | Example IP   |
| --------------- | ------------------------------ | ------------ |
| Central Manager | `condor-manager.example.com`   | `192.0.2.10` |
| Submit Node     | `condor-submit.example.com`    | `192.0.2.20` |
| Execute Node 1  | `condor-worker-01.example.com` | `192.0.2.31` |
| Execute Node 2  | `condor-worker-02.example.com` | `192.0.2.32` |

Replace these values with the hostnames and addresses from your own environment.

## Prerequisites

Before starting, verify that:

* the systems use a supported Linux distribution;
* every node has a unique hostname;
* DNS or `/etc/hosts` resolves all HTCondor hostnames correctly;
* the systems have synchronized clocks;
* the nodes can communicate over the required network;
* TCP port `9618` is permitted between the HTCondor nodes;
* `curl` is installed;
* you have `sudo` or root access;
* the installer script has passed the Bash syntax check.

Check name resolution:

```bash
getent hosts condor-manager.example.com
getent hosts condor-submit.example.com
getent hosts condor-worker-01.example.com
```

Check the system time:

```bash
timedatectl status
```

Check the installation script:

```bash
bash -n scripts/htcondor/install_htcondor_role.sh
```

Display its available options:

```bash
bash scripts/htcondor/install_htcondor_role.sh --help
```

## Firewall configuration

By default, the HTCondor Collector uses TCP port `9618`.

Restrict access to the systems participating in the pool. Do not expose this port directly to the Internet.

Example using UFW:

```bash
sudo ufw allow from 192.0.2.0/24 to any port 9618 proto tcp
sudo ufw status
```

If the environment uses additional custom HTCondor networking settings, verify whether other ports or a shared-port configuration are required.

## Step 1 — Install the Central Manager

Run the dry-run first:

```bash
bash scripts/htcondor/install_htcondor_role.sh \
    central-manager \
    condor-manager.example.com \
    --dry-run
```

Review all commands displayed by the installer.

If the dry-run is correct, apply the installation:

```bash
sudo bash scripts/htcondor/install_htcondor_role.sh \
    central-manager \
    condor-manager.example.com \
    --apply
```

Enter the pool password when prompted.

Keep this password available temporarily because the exact same password must be entered when installing the Submit and Execute nodes.

Verify the service:

```bash
systemctl status condor --no-pager
condor_version
condor_config_val CONDOR_HOST
condor_config_val DAEMON_LIST
```

The value returned by `CONDOR_HOST` should reference:

```text
condor-manager.example.com
```

## Step 2 — Install the Submit Node

Copy or clone the repository onto the Submit node.

Run the dry-run:

```bash
bash scripts/htcondor/install_htcondor_role.sh \
    submit \
    condor-manager.example.com \
    --dry-run
```

Apply the installation:

```bash
sudo bash scripts/htcondor/install_htcondor_role.sh \
    submit \
    condor-manager.example.com \
    --apply
```

Enter the same pool password used on the Central Manager.

Verify the configuration:

```bash
systemctl status condor --no-pager
condor_config_val CONDOR_HOST
condor_config_val DAEMON_LIST
condor_q
```

## Step 3 — Install an Execute Node

Run the dry-run on the first Execute node:

```bash
bash scripts/htcondor/install_htcondor_role.sh \
    execute \
    condor-manager.example.com \
    --dry-run
```

Apply the installation:

```bash
sudo bash scripts/htcondor/install_htcondor_role.sh \
    execute \
    condor-manager.example.com \
    --apply
```

Enter the same pool password used on the other HTCondor nodes.

Verify the service:

```bash
systemctl status condor --no-pager
condor_config_val CONDOR_HOST
condor_config_val DAEMON_LIST
```

Repeat this step for every additional Execute node.

## Verify the complete pool

Run the following commands from the Submit node or Central Manager:

```bash
condor_status
```

Display the registered HTCondor daemons:

```bash
condor_status -master
```

Display the names of the registered machines:

```bash
condor_status -master -af Name
```

Display available execution slots:

```bash
condor_status -af Name State Activity
```

Check the job queue:

```bash
condor_q
```

A healthy pool should show:

* the Central Manager;
* the Submit node;
* every registered Execute node;
* the execution slots provided by the Execute nodes.

## Submit a test job

On the Submit node, create a working directory:

```bash
mkdir -p ~/htcondor-test
cd ~/htcondor-test
```

Create a test script:

```bash
cat > test-job.sh <<'EOF'
#!/usr/bin/env bash

echo "HTCondor test job"
echo "Hostname: $(hostname)"
echo "Date: $(date --iso-8601=seconds)"
echo "User: $(id -un)"
EOF
```

Make it executable:

```bash
chmod +x test-job.sh
```

Create the submission file:

```bash
cat > test-job.sub <<'EOF'
universe   = vanilla
executable = test-job.sh
output     = test-job.out
error      = test-job.err
log        = test-job.log
request_cpus   = 1
request_memory = 128MB
queue
EOF
```

Submit the job:

```bash
condor_submit test-job.sub
```

Monitor the queue:

```bash
condor_q
```

After the job finishes, inspect the results:

```bash
cat test-job.out
cat test-job.err
cat test-job.log
```

The hostname in `test-job.out` should normally be the name of an Execute node.

## Configuration management

Identify the HTCondor local configuration directory:

```bash
condor_config_val LOCAL_CONFIG_DIR
```

Inspect the effective Central Manager setting:

```bash
condor_config_val CONDOR_HOST
```

Inspect the active daemon list:

```bash
condor_config_val DAEMON_LIST
```

Add custom configuration in separate files inside `LOCAL_CONFIG_DIR`.

Use descriptive filenames, for example:

```text
90-local-network.config
91-resource-limits.config
92-security-policy.config
```

Avoid modifying installer-managed files unless necessary.

After changing the configuration, validate the values and reload HTCondor:

```bash
condor_reconfig
```

If a restart is required:

```bash
sudo systemctl restart condor
sudo systemctl status condor --no-pager
```

## Logs and troubleshooting

Check the service log:

```bash
sudo journalctl -u condor --since "30 minutes ago" --no-pager
```

Find the configured HTCondor log directory:

```bash
condor_config_val LOG
```

List the log files:

```bash
sudo ls -lah "$(condor_config_val LOG)"
```

Common role-specific logs include:

| Role            | Relevant logs                                |
| --------------- | -------------------------------------------- |
| Central Manager | `CollectorLog`, `NegotiatorLog`, `MasterLog` |
| Submit Node     | `SchedLog`, `MasterLog`                      |
| Execute Node    | `StartLog`, `StarterLog`, `MasterLog`        |

Follow the main daemon log:

```bash
sudo tail -f "$(condor_config_val LOG)/MasterLog"
```

### Node does not appear in `condor_status`

Verify DNS:

```bash
getent hosts condor-manager.example.com
```

Verify the Central Manager configuration:

```bash
condor_config_val CONDOR_HOST
```

Verify TCP connectivity:

```bash
nc -zv condor-manager.example.com 9618
```

Verify the local service:

```bash
systemctl is-active condor
sudo journalctl -u condor -n 100 --no-pager
```

### Authentication problems

Authentication failures are commonly caused by:

* different pool passwords on different nodes;
* incorrect file permissions;
* incorrect time synchronization;
* hostname resolution problems;
* firewall restrictions;
* a node configured for the wrong Central Manager.

Do not display or commit authentication secrets while investigating the problem.

### Configuration problems

Display the effective configuration:

```bash
condor_config_val -summary
```

Check important values individually:

```bash
condor_config_val CONDOR_HOST
condor_config_val DAEMON_LIST
condor_config_val LOCAL_CONFIG_DIR
condor_config_val LOG
```

## Security recommendations

* Use the same strong pool password on all nodes.
* Never commit the pool password to Git.
* Do not pass the password directly as a visible command-line argument.
* Restrict TCP port `9618` to trusted HTCondor networks.
* Use DNS names or controlled `/etc/hosts` entries.
* Keep system time synchronized.
* Apply operating-system and HTCondor security updates.
* Limit SSH and administrative access to authorized users.
* Review custom files placed in `LOCAL_CONFIG_DIR`.
* Back up configuration files, but exclude credentials and tokens from Git.

## Removing sensitive shell variables

If the password was stored temporarily in an environment variable, remove it after installation:

```bash
unset GET_HTCONDOR_PASSWORD
```

Verify that it is no longer present:

```bash
env | grep GET_HTCONDOR_PASSWORD
```

The second command should return no output.

## Official documentation

* [Downloading and Installing HTCondor](https://htcondor.readthedocs.io/en/latest/getting-htcondor/)
* [Administrative Quick Start Guide](https://htcondor.readthedocs.io/en/lts/getting-htcondor/admin-quick-start.html)
* [get_htcondor command reference](https://htcondor.readthedocs.io/en/lts/man-pages/get_htcondor.html)
* [HTCondor networking and port usage](https://htcondor.readthedocs.io/en/latest/admin-manual/networking.html)
