# Glances System Monitoring

Glances is a cross-platform monitoring tool that displays CPU, memory, load, processes, network, storage, sensors, containers and other system information.

Official documentation:

https://glances.readthedocs.io/en/latest/

## Installation on Ubuntu and Debian

Install the distribution package:

```bash
sudo apt update
sudo apt install -y glances
```

Verify the installation:

```bash
glances --version
```

The distribution repository may provide an older version than PyPI.

## Install the latest version in a Python virtual environment

Install the prerequisites:

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip
```

Create an isolated environment:

```bash
python3 -m venv ~/.local/share/glances-venv
```

Install Glances with optional components:

```bash
~/.local/share/glances-venv/bin/pip install --upgrade pip
~/.local/share/glances-venv/bin/pip install "glances[all]"
```

Run it:

```bash
~/.local/share/glances-venv/bin/glances
```

## Standalone mode

Monitor the local machine:

```bash
glances
```

Press `q` or `Esc` to exit.

## Client/server mode

Start Glances on the monitored server:

```bash
glances -s
```

The default client/server port is:

```text
61209/TCP
```

Connect from another system:

```bash
glances -c 192.0.2.10
```

Replace `192.0.2.10` with the address of the monitored server.

Bind the server to a specific management address:

```bash
glances -s -B 192.0.2.10
```

Verify the listening port:

```bash
ss -lntp | grep 61209
```

## Web interface

Start the Web UI locally:

```bash
glances -w -B 127.0.0.1
```

Open:

```text
http://127.0.0.1:61208
```

To expose it on a management network:

```bash
glances -w -B 192.0.2.10
```

Open:

```text
http://192.0.2.10:61208
```

The default Web UI port is:

```text
61208/TCP
```

Verify the port:

```bash
ss -lntp | grep 61208
```

## Authentication

Start the Web UI with password authentication:

```bash
glances -w --password
```

Glances will request a password interactively.

Do not commit generated password files or clear-text passwords to Git.

## Firewall example

Allow Web UI access only from the management network:

```bash
sudo ufw allow from 192.0.2.0/24 to any port 61208 proto tcp
```

Allow client/server access:

```bash
sudo ufw allow from 192.0.2.0/24 to any port 61209 proto tcp
```

Replace the documentation network with the actual management network.

## XML-RPC host validation

When client/server mode listens on a non-loopback interface, configure the allowed hosts to mitigate DNS rebinding attacks.

Create or edit:

```text
~/.config/glances/glances.conf
```

Add:

```ini
[outputs]
xmlrpc_allowed_hosts=localhost,127.0.0.1,linux-lab-01.example.com
```

Use only the hostnames required in your environment.

## Security recommendations

* Do not expose Glances directly to the Internet.
* Bind it to `127.0.0.1` or a dedicated management interface.
* Restrict ports `61208` and `61209` using a firewall.
* Enable authentication for remote access.
* Use a reverse proxy with HTTPS for long-term Web UI deployments.
* Do not store passwords in Git.
* Keep Glances and its dependencies updated.
* Configure `xmlrpc_allowed_hosts` for client/server deployments.

## Useful commands

Display selected metrics:

```bash
glances --stdout cpu.user,mem.used,load
```

Display CPU and memory statistics as JSON:

```bash
glances --stdout-json cpu,mem
```

Show command-line options:

```bash
glances --help
```

## Troubleshooting

Check the installed version:

```bash
glances --version
```

Locate the executable:

```bash
command -v glances
```

Check whether Glances is running:

```bash
pgrep -a glances
```

Check listening ports:

```bash
sudo ss -lntp | grep -E '61208|61209'
```

Check firewall status:

```bash
sudo ufw status verbose
```
