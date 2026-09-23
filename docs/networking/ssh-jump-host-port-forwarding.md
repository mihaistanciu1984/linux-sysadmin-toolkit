# Access Private Services Through an SSH Jump Server

## Purpose

Use an SSH jump server to access services located in a private network.

The internal services do not need to be directly accessible from the internet.

## Example addresses

| System | Address |
|---|---|
| Jump server | `192.0.2.10` |
| Zabbix server | `192.0.2.20` |
| Proxmox server | `192.0.2.21` |
| TrueNAS server | `192.0.2.22` |
| Windows VM | `192.0.2.23` |

Replace these example addresses and `user` with your real values.

Keep the PowerShell or terminal window open while using the connection.

## Connect to Zabbix

Run:

```powershell
ssh -L 8080:192.0.2.20:80 user@192.0.2.10 -N
```

Open in a browser:

```text
http://localhost:8080
```

## Connect to Proxmox

Run:

```powershell
ssh -L 8088:192.0.2.21:8006 user@192.0.2.10 -N
```

Open:

```text
https://localhost:8088
```

The browser may show a certificate warning because the address is `localhost`.

## Connect to TrueNAS

Run:

```powershell
ssh -L 8090:192.0.2.22:443 user@192.0.2.10 -N
```

Open:

```text
https://localhost:8090
```

If TrueNAS uses HTTP instead of HTTPS, use:

```powershell
ssh -L 8090:192.0.2.22:80 user@192.0.2.10 -N
```

Then open:

```text
http://localhost:8090
```

## Connect with Remote Desktop

Run:

```powershell
ssh -L 33389:192.0.2.23:3389 user@192.0.2.10 -N
```

Open another PowerShell window and run:

```powershell
mstsc /v:localhost:33389
```

## How the command works

Example:

```text
ssh -L LOCAL_PORT:PRIVATE_IP:SERVICE_PORT user@JUMP_SERVER -N
```

- `LOCAL_PORT` is opened on your computer.
- `PRIVATE_IP` is the internal server.
- `SERVICE_PORT` is the port used by the internal service.
- `JUMP_SERVER` provides access to the private network.
- `-N` creates the tunnel without opening a remote terminal.

It is normal for the SSH command to display no output.

## Close the connection

Return to the window running SSH and press:

```text
Ctrl+C
```

## Quick verification

In another PowerShell window, test the required local port:

```powershell
Test-NetConnection localhost -Port 8080
```

A successful tunnel displays:

```text
TcpTestSucceeded : True
```

## Verify the local ports

In another PowerShell window:

```powershell
Test-NetConnection localhost -Port 8080
Test-NetConnection localhost -Port 8088
Test-NetConnection localhost -Port 8090
Test-NetConnection localhost -Port 33389
```


```



### Local port already in use

Check the port:

```powershell
Get-NetTCPConnection -LocalPort 8080
```

Select another unused local port if necessary.

### Connection refused

Verify that:

- the destination service is running;
- the destination port is correct;
- the jump host can reach the private system;
- a firewall is not blocking the connection.

# Opțiunile folosite în comandă:

-L create local port forwarding;
-N doesn't execute a command on the server;
-T don't open an interactive terminal;
ExitOnForwardFailure=yes stop the command if the tunnel can't be created;
ServerAliveInterval=60 keep the connection active.