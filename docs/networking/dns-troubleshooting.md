# DNS Troubleshooting on Linux

This procedure describes how to diagnose DNS resolution problems on Linux systems.

The repository includes the following helper script:

```text
scripts/networking/check_dns.sh
```

The script tests:

* name resolution through the system resolver;
* DNS queries using `dig`;
* queries against an optional DNS server;
* whether the requested hostname returns an IPv4 address.

## Requirements

The script requires:

* Bash;
* `getent`;
* optionally, `dig` for direct DNS queries.

Install `dig` on Debian or Ubuntu:

```bash
sudo apt update
sudo apt install dnsutils
```

Install it on RHEL, Rocky Linux, AlmaLinux or Fedora:

```bash
sudo dnf install bind-utils
```

## Script usage

Display help:

```bash
bash scripts/networking/check_dns.sh --help
```

Test a hostname using the system-configured resolver:

```bash
bash scripts/networking/check_dns.sh example.com
```

Test a hostname against a specific DNS server:

```bash
bash scripts/networking/check_dns.sh example.com 192.0.2.53
```

`192.0.2.53` is an example address and must be replaced with the DNS server used in your environment.

The script returns:

| Exit code | Meaning                                            |
| --------- | -------------------------------------------------- |
| `0`       | DNS resolution succeeded                           |
| `1`       | DNS resolution failed                              |
| `2`       | Invalid arguments or a required command is missing |

## Step 1 — Check basic network connectivity

Display the network interfaces:

```bash
ip address
```

Display the routing table:

```bash
ip route
```

Check connectivity to the default gateway:

```bash
ping -c 4 "$(ip route | awk '/default/ {print $3; exit}')"
```

Check connectivity to the DNS server:

```bash
ping -c 4 192.0.2.53
```

A DNS server may be configured not to answer ICMP requests. A failed ping does not always mean that the DNS service is unavailable.

## Step 2 — Inspect the configured DNS servers

Display `/etc/resolv.conf`:

```bash
cat /etc/resolv.conf
```

Check whether it is a regular file or a symbolic link:

```bash
ls -l /etc/resolv.conf
```

On systems using `systemd-resolved`, display the effective resolver configuration:

```bash
resolvectl status
```

Display DNS statistics:

```bash
resolvectl statistics
```

On systems using NetworkManager:

```bash
nmcli device show |
    grep -E 'GENERAL.DEVICE|IP4.DNS|IP6.DNS'
```

Do not edit `/etc/resolv.conf` directly when it is managed by `systemd-resolved`, NetworkManager, Netplan or another network-management service. Make the change in the corresponding network configuration.

## Step 3 — Test the system resolver

Use `getent` to test the same resolver path used by many Linux applications:

```bash
getent hosts example.com
```

Display all returned IPv4 addresses:

```bash
getent ahostsv4 example.com
```

Display IPv6 addresses:

```bash
getent ahostsv6 example.com
```

If `dig` succeeds but `getent` fails, inspect:

* `/etc/nsswitch.conf`;
* `/etc/resolv.conf`;
* `systemd-resolved`;
* NetworkManager or Netplan configuration;
* local hostname overrides in `/etc/hosts`.

Check the hosts resolution order:

```bash
grep '^hosts:' /etc/nsswitch.conf
```

Inspect local overrides:

```bash
grep -vE '^[[:space:]]*(#|$)' /etc/hosts
```

## Step 4 — Query DNS directly

Query an IPv4 address:

```bash
dig example.com A
```

Show only the returned result:

```bash
dig example.com A +short
```

Query an IPv6 address:

```bash
dig example.com AAAA +short
```

Query a specific DNS server:

```bash
dig @192.0.2.53 example.com A
```

Limit the query time:

```bash
dig @192.0.2.53 example.com A +time=3 +tries=1
```

Test DNS over TCP:

```bash
dig @192.0.2.53 example.com A +tcp
```

Query common record types:

```bash
dig example.com A
dig example.com AAAA
dig example.com CNAME
dig example.com MX
dig example.com NS
dig example.com SOA
dig example.com TXT
```

Perform a reverse lookup:

```bash
dig -x 192.0.2.10
```

## Step 5 — Compare multiple DNS servers

Query the system-configured resolver:

```bash
dig example.com A
```

Query a specific internal resolver:

```bash
dig @192.0.2.53 example.com A
```

Query a second approved resolver:

```bash
dig @198.51.100.53 example.com A
```

Different results may indicate:

* DNS replication delay;
* split DNS;
* incorrect forwarding;
* stale cache;
* different internal and external DNS views;
* a missing record on one server.

Only query DNS servers authorized for use in your environment.

## Step 6 — Interpret common errors

### NXDOMAIN

`NXDOMAIN` means the requested DNS name does not exist from the perspective of the queried server.

Check:

* spelling of the hostname;
* DNS suffix;
* whether the record exists in the correct zone;
* whether the correct DNS server was queried;
* internal versus external DNS views.

Example:

```bash
dig @192.0.2.53 missing-host.example.com A
```

### SERVFAIL

`SERVFAIL` means the DNS server could not complete the query.

Possible causes include:

* upstream DNS failure;
* DNSSEC validation failure;
* broken delegation;
* zone loading error;
* communication failure between DNS servers.

Inspect the full response:

```bash
dig @192.0.2.53 example.com A +comments
```

Inspect the zone authority:

```bash
dig @192.0.2.53 example.com SOA
```

### Timeout

A timeout can indicate:

* unreachable DNS server;
* blocked UDP or TCP port 53;
* incorrect routing;
* firewall restrictions;
* DNS service unavailable;
* incorrect server address.

Test TCP port 53:

```bash
nc -zv -w 5 192.0.2.53 53
```

Test DNS explicitly over TCP:

```bash
dig @192.0.2.53 example.com A +tcp +time=3 +tries=1
```

### Correct IP but application still fails

If DNS returns the expected address but the application still fails, check:

* application proxy settings;
* TLS certificate name;
* firewall rules;
* destination service port;
* stale application cache;
* `/etc/hosts` overrides;
* IPv4 versus IPv6 selection.

## Step 7 — Inspect `systemd-resolved`

Check the service:

```bash
systemctl status systemd-resolved --no-pager
```

Review recent logs:

```bash
sudo journalctl \
    -u systemd-resolved \
    --since "30 minutes ago" \
    --no-pager
```

Query a name through `systemd-resolved`:

```bash
resolvectl query example.com
```

Flush its DNS cache:

```bash
sudo resolvectl flush-caches
```

Check the statistics again:

```bash
resolvectl statistics
```

Restart the service only when necessary:

```bash
sudo systemctl restart systemd-resolved
```

Then verify:

```bash
systemctl is-active systemd-resolved
resolvectl status
```

## Step 8 — Capture DNS traffic

When additional investigation is required, capture DNS traffic:

```bash
sudo tcpdump -ni any port 53
```

Filter for a specific DNS server:

```bash
sudo tcpdump -ni any host 192.0.2.53 and port 53
```

Capture packets to a file:

```bash
sudo tcpdump \
    -ni any \
    port 53 \
    -w dns-troubleshooting.pcap
```

Packet captures may contain internal hostnames, addresses and DNS queries. Store and share them securely.

## Validation checklist

After applying a correction, verify:

```bash
getent hosts example.com
dig example.com A +short
resolvectl query example.com
```

Then run the repository script:

```bash
bash scripts/networking/check_dns.sh example.com
```

For a specific resolver:

```bash
bash scripts/networking/check_dns.sh \
    example.com \
    192.0.2.53
```

Confirm that the script returns exit code `0`:

```bash
echo $?
```

## Security considerations

* Do not publish internal DNS server addresses.
* Do not publish internal domain names or hostnames.
* Do not commit packet captures to Git.
* Do not include TSIG keys or DNS API tokens in commands or documentation.
* Replace infrastructure details with reserved example addresses.
* Restrict DNS queries and zone transfers to authorized systems.

## Official documentation

* [BIND 9 manual pages](https://bind9.readthedocs.io/en/stable/manpages.html)
* [BIND 9 troubleshooting](https://bind9.readthedocs.io/en/stable/chapter9.html)
* [systemd-resolved documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.service.html)
* [resolvectl documentation](https://www.freedesktop.org/software/systemd/man/latest/resolvectl.html)
