# Configure a Static IPv4 Address on Oracle Linux 8

This procedure configures a persistent static IPv4 address on Oracle Linux 8 using NetworkManager and `nmcli`.

Example addressing:

| Setting            | Example value   |
| ------------------ | --------------- |
| Interface          | `ens4f0`        |
| Connection profile | `ens4f0`        |
| IPv4 address       | `192.0.2.10/24` |
| Default gateway    | `192.0.2.1`     |
| DNS server         | `192.0.2.53`    |
| DNS test domain    | `example.com`   |

The addresses are documentation examples. Replace them with values appropriate for the target environment.

## Important remote-access warning

Activating a modified network connection can immediately interrupt SSH access.

Before changing the address:

* use a local or out-of-band console when possible;
* confirm the correct interface and connection profile;
* verify the gateway, prefix and DNS server;
* record the previous configuration;
* prepare a rollback procedure;
* ensure the new address does not conflict with another system.

Do not apply an unverified network configuration to a remote production server.

## NetworkManager requirement

Check NetworkManager:

```bash
systemctl is-active NetworkManager
systemctl is-enabled NetworkManager
```

If necessary:

```bash
sudo systemctl enable --now NetworkManager
```

## Step 1 — Identify the interface

Display devices:

```bash
nmcli device status
```

Display interfaces:

```bash
ip link show
```

Display IPv4 addresses:

```bash
ip -4 address show
```

In this example, the interface is:

```text
ens4f0
```

Do not assume that the interface name is the same on every system.

## Step 2 — Identify the connection profile

Display NetworkManager connection profiles:

```bash
nmcli \
    -f NAME,UUID,TYPE,DEVICE \
    connection show
```

Display active profiles:

```bash
nmcli \
    -f NAME,UUID,TYPE,DEVICE \
    connection show \
    --active
```

The connection name can be different from the interface name.

For example:

```text
Connection name: ens4f0
Interface name:  ens4f0
```

Store the names in shell variables:

```bash
CONNECTION_NAME="ens4f0"
INTERFACE_NAME="ens4f0"
```

## Step 3 — Record the existing configuration

Display the existing profile:

```bash
nmcli connection show "${CONNECTION_NAME}"
```

Save a reference copy:

```bash
nmcli connection show "${CONNECTION_NAME}" |
    sudo tee \
        "/root/${CONNECTION_NAME}-before-static-ip.txt" \
        >/dev/null
```

Display the current routes:

```bash
ip route
```

Display the existing resolver configuration:

```bash
cat /etc/resolv.conf
```

## Step 4 — Configure the static IPv4 address

Modify the existing connection:

```bash
sudo nmcli connection modify "${CONNECTION_NAME}" \
    ipv4.method manual \
    ipv4.addresses "192.0.2.10/24" \
    ipv4.gateway "192.0.2.1" \
    ipv4.dns "192.0.2.53" \
    connection.autoconnect yes
```

Keep IPv6 automatic configuration enabled:

```bash
sudo nmcli connection modify "${CONNECTION_NAME}" \
    ipv6.method auto
```

If IPv6 is not used in the environment, review the network requirements before disabling it.

## Step 5 — Review before activation

Display the proposed IPv4 configuration:

```bash
nmcli \
    -f connection.id,connection.interface-name,connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns \
    connection show "${CONNECTION_NAME}"
```

Confirm:

* the correct connection profile;
* the correct interface;
* the correct IP address and prefix;
* the correct gateway;
* the correct DNS server;
* automatic connection at boot.

## Step 6 — Activate the connection

Warning: this operation may disconnect the current SSH session.

Activate:

```bash
sudo nmcli connection up "${CONNECTION_NAME}"
```

If NetworkManager reports that the profile is active, continue with validation.

## Creating a new profile

If the interface does not already have a usable connection profile, create one:

```bash
sudo nmcli connection add \
    type ethernet \
    con-name "ens4f0" \
    ifname "ens4f0" \
    ipv4.method manual \
    ipv4.addresses "192.0.2.10/24" \
    ipv4.gateway "192.0.2.1" \
    ipv4.dns "192.0.2.53" \
    ipv6.method auto \
    connection.autoconnect yes
```

Activate it:

```bash
sudo nmcli connection up "ens4f0"
```

Do not create a second active profile for the same interface without reviewing profile priority and routing behavior.

## Step 7 — Verify the address

Display the interface:

```bash
ip -4 address show dev "${INTERFACE_NAME}"
```

Display the NetworkManager device information:

```bash
nmcli \
    -f GENERAL,IP4 \
    device show "${INTERFACE_NAME}"
```

Display the configured profile:

```bash
nmcli connection show "${CONNECTION_NAME}"
```

The interface should contain:

```text
192.0.2.10/24
```

## Step 8 — Verify routing

Display routes:

```bash
ip route
```

Expected default route:

```text
default via 192.0.2.1 dev ens4f0
```

Test the example gateway:

```bash
ping -c 3 192.0.2.1
```

Replace the documentation address with the actual gateway before running the test.

## Step 9 — Verify DNS

Display the effective DNS configuration:

```bash
nmcli \
    -f IP4.DNS \
    device show "${INTERFACE_NAME}"
```

Test name resolution:

```bash
getent hosts example.com
```

If `dig` is available:

```bash
dig example.com A
```

Test the configured DNS server:

```bash
dig @192.0.2.53 example.com A
```

## Step 10 — Verify persistence

Check automatic connection:

```bash
nmcli \
    -f connection.id,connection.autoconnect \
    connection show "${CONNECTION_NAME}"
```

Expected value:

```text
connection.autoconnect: yes
```

A reboot test should be performed only during an approved maintenance window:

```bash
sudo reboot
```

After reboot:

```bash
nmcli device status
ip -4 address show dev ens4f0
ip route
getent hosts example.com
```

## Roll back to DHCP

Use this only if the previous configuration used DHCP.

From a local or out-of-band console:

```bash
sudo nmcli connection modify "${CONNECTION_NAME}" \
    ipv4.method auto \
    ipv4.addresses "" \
    ipv4.gateway "" \
    ipv4.dns ""
```

Reactivate:

```bash
sudo nmcli connection up "${CONNECTION_NAME}"
```

Verify:

```bash
ip -4 address show dev "${INTERFACE_NAME}"
ip route
```

## Legacy `ifcfg` method

Oracle Linux 8 can still recognize legacy `ifcfg` profiles, but network scripts are deprecated. Prefer `nmcli` for new configurations.

A legacy example would use:

```text
/etc/sysconfig/network-scripts/ifcfg-ens4f0
```

Example content:

```ini
TYPE=Ethernet
NAME=ens4f0
DEVICE=ens4f0
ONBOOT=yes
BOOTPROTO=none
DEFROUTE=yes

IPADDR=192.0.2.10
PREFIX=24
GATEWAY=192.0.2.1
DNS1=192.0.2.53

IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
```

A manually invented UUID is not required. NetworkManager manages connection UUIDs.

After changing a legacy profile:

```bash
sudo nmcli connection reload
sudo nmcli connection up ens4f0
```

Use this method only when maintaining an existing legacy configuration.

## Troubleshooting

### Connection profile not found

List profiles:

```bash
nmcli connection show
```

Use the profile name from the `NAME` column, not automatically the interface name.

### Interface is disconnected

Check:

```bash
nmcli device status
ip link show dev ens4f0
```

Activate:

```bash
sudo nmcli connection up "${CONNECTION_NAME}"
```

### Address is configured but gateway is unreachable

Check:

```bash
ip -4 address show dev "${INTERFACE_NAME}"
ip route
ip neigh
```

Verify the prefix, VLAN, gateway and switch configuration.

### DNS does not work

Check:

```bash
nmcli \
    -f IP4.DNS \
    device show "${INTERFACE_NAME}"

cat /etc/resolv.conf
getent hosts example.com
```

### Configuration disappears after reboot

Check:

```bash
nmcli \
    -f connection.autoconnect \
    connection show "${CONNECTION_NAME}"
```

Set autoconnect:

```bash
sudo nmcli connection modify "${CONNECTION_NAME}" \
    connection.autoconnect yes
```

## Security and operational recommendations

* Use reserved example addresses in public documentation.
* Do not publish production addresses, routes or DNS servers.
* Confirm that the static address is reserved and unused.
* Use console access for remote network changes.
* Record the original configuration.
* Schedule production changes in a maintenance window.
* Test routing, DNS and service connectivity after the change.
* Avoid deprecated network scripts for new deployments.

## Official documentation

* [Oracle Linux 8 networking documentation](https://docs.oracle.com/en/operating-systems/oracle-linux/8/network/)
* [NetworkManager connection profiles](https://docs.oracle.com/en/operating-systems/oracle-linux/8/network/network-NetworkManagerProfiles.html)
* [Oracle Linux 8 deprecated networking features](https://docs.oracle.com/en/operating-systems/oracle-linux/8/relnotes8.10/ol8-deprecated-Networking.html)
