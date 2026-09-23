# Share a Local USB Device with a Remote VM

This procedure explains how to share a USB device connected to a local Windows computer with a remote Windows virtual machine through a Linux jump host.

USB Network Gate performs the actual USB device sharing.

SSH creates the required network tunnels:

- A local SSH tunnel provides RDP access to the remote VM.
- A reverse SSH tunnel transports the USB Network Gate connection from the local computer to the jump host.
- `socat` forwards the USB connection from the jump host to the private network used by the VM.
- RDP provides graphical access to the remote Windows VM.

> RDP does not transport the USB device in this configuration. USB Network Gate performs the USB sharing.

## Connection overview

The complete connection uses two separate paths.

### Remote Desktop path

```text
Local Windows computer
    -> Local port 33389
    -> SSH local tunnel
    -> Linux jump host
    -> Remote Windows VM port 3389
```

### USB Network Gate path

```text
Local USB device
    -> USB Network Gate Server on the local computer
    -> Local port 3240
    -> SSH reverse tunnel
    -> Jump-host loopback port 3240
    -> socat port 3241
    -> Private network
    -> USB Network Gate Client on the remote VM
```

## Port mapping

| Port | Location | Purpose |
|---|---|---|
| `22` | Jump host | SSH connection |
| `33389` | Local Windows computer | Local endpoint for the RDP tunnel |
| `3389` | Remote Windows VM | Remote Desktop service |
| `3240` | Local computer | USB Network Gate server |
| `3240` | Jump-host loopback | Endpoint created by the SSH reverse tunnel |
| `3241` | Jump-host private interface | USB connection used by the remote VM |

## Example placeholders

This procedure uses the following placeholders:

```text
VM_PRIVATE_IP
JUMP_HOST
JUMP_PRIVATE_IP
example-user
```

Replace them with the correct values for your environment.

Example documentation addresses can use:

```text
VM_PRIVATE_IP=192.0.2.20
JUMP_PRIVATE_IP=192.0.2.10
JUMP_HOST=jump.example.com
example-user=example-user
```

## Requirements

### Local Windows computer

- Windows PowerShell
- OpenSSH client
- Remote Desktop client
- USB Network Gate Server
- The USB device that will be shared

### Linux jump host

- SSH server
- `firewalld`
- `socat`
- Network access to the remote VM

### Remote Windows VM

- Remote Desktop enabled
- USB Network Gate Client
- Network access to the private IP of the jump host

## 1. Verify the USB device locally

Connect the USB device to the local Windows computer.

Open PowerShell and check that Windows detects it:

```powershell
Get-PnpDevice -PresentOnly |
    Where-Object {
        $_.InstanceId -like "USB*"
    }
```

The device should appear without an error state.

## 2. Verify the SSH connection

From the local Windows computer, test the SSH connection to the jump host:

```powershell
ssh example-user@JUMP_HOST
```

Enter the SSH password when requested.

After confirming that the connection works, exit:

```bash
exit
```

## 3. Verify that the jump host can access the VM

Connect to the jump host:

```powershell
ssh example-user@JUMP_HOST
```

Test the RDP port of the remote VM:

```bash
nc -zv VM_PRIVATE_IP 3389
```

A successful result confirms that the jump host can reach the Windows VM.

If `nc` is not installed on a RHEL-based jump host:

```bash
sudo dnf install -y nmap-ncat
```

## 4. Install socat on the jump host

For Oracle Linux, Rocky Linux, AlmaLinux or another RHEL-based distribution:

```bash
sudo dnf install -y socat
```

Verify the installation:

```bash
socat -V
```

## 5. Configure the jump-host firewall

Check that `firewalld` is running:

```bash
sudo firewall-cmd --state
```

For a simple lab configuration, allow port `3241`:

```bash
sudo firewall-cmd \
    --permanent \
    --zone=public \
    --add-port=3241/tcp
```

Reload the firewall:

```bash
sudo firewall-cmd --reload
```

Verify the configured port:

```bash
sudo firewall-cmd \
    --zone=public \
    --list-ports
```

The result should include:

```text
3241/tcp
```

For production environments, restrict port `3241` so that only the remote VM or its trusted network can connect.

Firewalld uses separate runtime and permanent configurations. The `--permanent` option followed by a reload makes the rule persistent. :contentReference[oaicite:0]{index=0}

## 6. Configure USB Network Gate on the local computer

Install USB Network Gate on the local Windows computer.

The local computer acts as the USB Network Gate Server.

Open USB Network Gate and:

1. Find the connected USB device.
2. Select the device.
3. Click **Share**.
4. Confirm that the device appears as shared.
5. Confirm that the USB Network Gate service is running.

The local USB Network Gate service normally uses port `3240` in this procedure.

Check the local port from PowerShell:

```powershell
Test-NetConnection 127.0.0.1 -Port 3240
```

Expected result:

```text
TcpTestSucceeded : True
```

Licensing and the number of USB devices that can be shared depend on the installed USB Network Gate version and license.

## 7. Start the socat relay on the jump host

Connect to the jump host:

```powershell
ssh example-user@JUMP_HOST
```

Start the relay:

```bash
sudo socat \
    TCP-LISTEN:3241,bind=JUMP_PRIVATE_IP,reuseaddr,fork \
    TCP:127.0.0.1:3240
```

Replace `JUMP_PRIVATE_IP` with the private IP address of the jump host.

The command performs the following forwarding:

```text
JUMP_PRIVATE_IP:3241
    -> 127.0.0.1:3240 on the jump host
```

The jump-host port `3240` will be connected to the local computer through the SSH reverse tunnel created in the next step.

Keep this terminal open while using the USB device.

Closing the terminal stops the `socat` relay.

## 8. Create the SSH tunnels

Open a new PowerShell window on the local Windows computer.

Run the following command on one line:

```powershell
ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 127.0.0.1:33389:VM_PRIVATE_IP:3389 -R 127.0.0.1:3240:127.0.0.1:3240 example-user@JUMP_HOST -N
```

The command creates two tunnels.

### Local RDP tunnel

```text
-L 127.0.0.1:33389:VM_PRIVATE_IP:3389
```

This provides the following path:

```text
Local computer port 33389
    -> SSH jump host
    -> Remote VM port 3389
```

### Reverse USB Network Gate tunnel

```text
-R 127.0.0.1:3240:127.0.0.1:3240
```

This provides the following path:

```text
Jump-host loopback port 3240
    -> SSH reverse tunnel
    -> Local computer port 3240
    -> USB Network Gate Server
```

Enter the SSH password when requested.

Keep this PowerShell window open.

Closing the window stops both the RDP and USB tunnels.

## 9. Verify the tunnels

Open another PowerShell window on the local computer.

Test the local RDP tunnel:

```powershell
Test-NetConnection 127.0.0.1 -Port 33389
```

Expected result:

```text
TcpTestSucceeded : True
```

On the jump host, check ports `3240` and `3241`:

```bash
sudo ss -lntp |
    grep -E '3240|3241'
```

Port `3240` should be created by SSH.

Port `3241` should be created by `socat`.

## 10. Connect to the remote VM through RDP

On the local Windows computer, press:

```text
Windows key + R
```

Enter:

```text
mstsc
```

In the Computer field, enter:

```text
127.0.0.1:33389
```

Select **Connect** and enter the Windows VM credentials.

RDP is transported through the SSH local tunnel.

The VM does not need to expose port `3389` directly to the local computer or the internet.

## 11. Configure USB Network Gate on the remote VM

Install USB Network Gate on the remote Windows VM.

The VM acts as the USB Network Gate Client.

Inside the VM:

1. Open USB Network Gate.
2. Add a remote USB server.
3. Enter the jump-host address and relay port:

   ```text
   JUMP_PRIVATE_IP:3241
   ```

4. Search for the shared USB device.
5. Select the device.
6. Click **Connect**.

The USB device should appear inside the VM as if it were connected locally.

## 12. Verify the USB connection

Inside the remote Windows VM, open Device Manager:

```text
devmgmt.msc
```

Check that the redirected USB device appears without errors.

You can also use PowerShell:

```powershell
Get-PnpDevice -PresentOnly |
    Where-Object {
        $_.InstanceId -like "USB*"
    }
```

If the USB device requires a vendor driver, install the appropriate driver inside the VM.

## Alternative ports

If ports `3240` and `3241` cannot be used, the alternative combination from the original procedure is:

```text
Local USB Network Gate port: 7575
Jump-host relay port:       7576
```

The USB Network Gate Server must first be configured to use port `7575`.

### Jump-host firewall

```bash
sudo firewall-cmd \
    --permanent \
    --zone=public \
    --add-port=7576/tcp

sudo firewall-cmd --reload
```

### socat relay

```bash
sudo socat \
    TCP-LISTEN:7576,bind=JUMP_PRIVATE_IP,reuseaddr,fork \
    TCP:127.0.0.1:7575
```

### SSH tunnels

```powershell
ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 127.0.0.1:33389:VM_PRIVATE_IP:3389 -R 127.0.0.1:7575:127.0.0.1:7575 example-user@JUMP_HOST -N
```

Inside USB Network Gate on the remote VM, connect to:

```text
JUMP_PRIVATE_IP:7576
```

Use only one USB port combination at a time.

## Troubleshooting

### The SSH tunnel closes immediately

Run SSH with verbose output:

```powershell
ssh -vvv -o ExitOnForwardFailure=yes -L 127.0.0.1:33389:VM_PRIVATE_IP:3389 -R 127.0.0.1:3240:127.0.0.1:3240 example-user@JUMP_HOST -N
```

Look for errors such as:

```text
remote port forwarding failed
address already in use
connection refused
```

### Local port 3240 is not available

Check whether USB Network Gate is running:

```powershell
Test-NetConnection 127.0.0.1 -Port 3240
```

List the process using the port:

```powershell
Get-NetTCPConnection -LocalPort 3240 -ErrorAction SilentlyContinue
```

### RDP does not connect

On the local computer:

```powershell
Test-NetConnection 127.0.0.1 -Port 33389
```

On the jump host:

```bash
nc -zv VM_PRIVATE_IP 3389
```

Inside the Windows VM, verify Remote Desktop Services:

```powershell
Get-Service TermService
```

### socat is not running

On the jump host:

```bash
pgrep -af socat
```

Check the relay port:

```bash
sudo ss -lntp |
    grep 3241
```

### The VM cannot reach the USB relay

Inside the remote VM:

```powershell
Test-NetConnection JUMP_PRIVATE_IP -Port 3241
```

If the test fails, verify:

- The jump-host firewall
- The `socat` process
- The jump-host private IP
- Network routing between the VM and jump host

### USB Network Gate does not display the device

Verify:

- The USB device is physically connected to the local computer.
- The device is shared in the local USB Network Gate application.
- USB Network Gate is installed on both systems.
- The SSH tunnel remains open.
- The `socat` relay remains active.
- The VM can reach `JUMP_PRIVATE_IP:3241`.
- The correct device drivers are installed inside the VM.
- The USB Network Gate license permits the required connection.

## Closing the connection

When the work is complete:

1. Disconnect the USB device from USB Network Gate inside the VM.
2. Close the RDP session.
3. Stop the SSH tunnel with `Ctrl+C`.
4. Stop `socat` with `Ctrl+C`.
5. Stop sharing the USB device on the local computer.

If the firewall port is no longer required, remove it:

```bash
sudo firewall-cmd \
    --permanent \
    --zone=public \
    --remove-port=3241/tcp

sudo firewall-cmd --reload
```

## Security notes

- USB Network Gate performs the USB device sharing.
- RDP is used only to access and operate the VM.
- SSH encrypts the RDP and USB Network Gate tunnel traffic.
- Do not expose the USB relay directly to the internet.
- Restrict the firewall rule to trusted systems when possible.
- Use SSH key authentication when possible.
- Share only trusted USB devices.
- Close the tunnels after completing the work.
- Follow the USB Network Gate licensing conditions.