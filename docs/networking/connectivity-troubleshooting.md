# Linux Network Connectivity Troubleshooting

This procedure provides a structured approach for diagnosing Linux network connectivity problems.

Troubleshooting should progress from the local interface toward the remote service:

1. Interface
2. IP configuration
3. Routing
4. Gateway
5. DNS
6. Network path
7. Remote port
8. Local or remote firewall
9. Application service

## Check network interfaces

```bash
ip -brief link
ip -brief address
```

Detailed information:

```bash
ip address show
```

An interface should normally display the `UP` state and an expected IP address.

## Check physical link state

```bash
ip link show
```

For Ethernet interfaces:

```bash
sudo ethtool eth0
```

Look for:

```text
Link detected: yes
```

Replace `eth0` with the actual interface.

## Check routing

```bash
ip route
```

Display the default gateway:

```bash
ip route show default
```

Determine the route used for a destination:

```bash
ip route get 192.0.2.10
```

The result displays the gateway, interface and source address selected by Linux.

## Test the local network stack

```bash
ping -c 4 127.0.0.1
```

Test the local IP:

```bash
ping -c 4 192.0.2.20
```

Replace the example address with the local system address.

## Test the gateway

```bash
ping -c 4 192.0.2.1
```

A failed ping does not always prove the gateway is unavailable because ICMP may be blocked.

Check the neighbor table:

```bash
ip neighbor show
```

States such as `FAILED` or repeated `INCOMPLETE` entries can indicate a Layer 2 problem.

## Test DNS resolution

```bash
getent hosts example.com
```

For systems using `systemd-resolved`:

```bash
resolvectl status
resolvectl query example.com
```

If `dig` is installed:

```bash
dig example.com
dig example.com +short
```

Compare hostname and direct IP connectivity to distinguish DNS problems from network problems.

## Test the network path

```bash
tracepath example.com
```

Alternative:

```bash
traceroute example.com
```

Some network devices block or deprioritize traceroute traffic, so missing hops do not necessarily indicate a failure.

## Test a TCP port

Using Netcat:

```bash
nc -vz -w 5 192.0.2.10 22
```

Test HTTPS:

```bash
nc -vz -w 5 example.com 443
```

Using Curl:

```bash
curl -I --connect-timeout 5 https://example.com
```

## Check local listening ports

```bash
sudo ss -lntup
```

Check a specific port:

```bash
sudo ss -lntp |
    grep ':22 '
```

Confirm that the application is listening on the expected address.

For example, a service listening only on `127.0.0.1` cannot be accessed remotely.

## Check firewall configuration

Ubuntu UFW:

```bash
sudo ufw status verbose
```

Nftables:

```bash
sudo nft list ruleset
```

Legacy iptables:

```bash
sudo iptables -L -n -v
```

Do not flush firewall rules during troubleshooting. Review the rules and change only the required entries.

## Check NetworkManager

```bash
nmcli device status
nmcli connection show
```

Display device configuration:

```bash
nmcli device show
```

Review NetworkManager logs:

```bash
sudo journalctl \
    -u NetworkManager \
    --since "1 hour ago"
```

## Capture network traffic

Capture traffic for a specific host:

```bash
sudo tcpdump \
    -ni any \
    host 192.0.2.10
```

Capture a TCP port:

```bash
sudo tcpdump \
    -ni any \
    tcp port 443
```

Limit the packet count:

```bash
sudo tcpdump \
    -ni any \
    -c 100 \
    host 192.0.2.10
```

Packet captures can contain credentials, session data and internal addresses. Do not commit capture files to Git.

## Troubleshooting workflow

1. Confirm the interface is operational.
2. Verify the expected IP address and prefix.
3. Check the default route.
4. Test the local gateway.
5. Verify DNS resolution.
6. Determine the route toward the destination.
7. Test the required TCP or UDP port.
8. Check whether the application is listening.
9. Review local and remote firewall rules.
10. Capture traffic only when required.

A successful ping does not guarantee that an application port is available. A failed ping does not prove that a host is offline.
