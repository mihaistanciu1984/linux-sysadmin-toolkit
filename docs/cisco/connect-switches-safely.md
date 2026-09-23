# Connect an Older Cisco Switch to an Existing Switch

This procedure explains how to connect two Cisco switches without causing the uplink port to enter the `err-disabled` state.

It also includes basic commands for:

- configuring a switch uplink;
- checking Spanning Tree;
- recovering an err-disabled port;
- assigning a management IP address;
- saving the configuration.

> Warning: A switch-to-switch connection can create a network loop. Connect only one cable until Spanning Tree has been verified.

## Important Spanning Tree information

Do not configure this command on a switch-to-switch connection:

```text
spanning-tree bpdufilter enable
```

BPDU Filter prevents the port from correctly exchanging Spanning Tree information and can allow a network loop.

PortFast and BPDU Guard are normally intended for ports connected to end devices such as computers, printers and servers.

A port connected to another switch should operate as a normal Spanning Tree port.

## Example configuration

This procedure uses:

```text
Uplink port:       GigabitEthernet1/0/24
Management VLAN:   10
Switch IP address: 192.0.2.2/24
Default gateway:   192.0.2.1
Allowed VLANs:     10,20
```

Replace these values with the correct configuration for your network.

## 1. Enter privileged and configuration mode

```cisco
enable
configure terminal
```

## 2. Check the port before changing it

```cisco
do show running-config interface GigabitEthernet1/0/24
do show interfaces GigabitEthernet1/0/24 status
```

Verify that the selected port is not already used by another device.

## 3. Check Spanning Tree and err-disabled ports

```cisco
do show spanning-tree interface GigabitEthernet1/0/24 detail
do show interfaces status err-disabled
```

If the port is err-disabled, identify and correct the cause before enabling it again.

## 4. Configure a trunk between the switches

Use a trunk when multiple VLANs must pass between switches:

```cisco
interface GigabitEthernet1/0/24
 description UPLINK-TO-OLD-SWITCH
 switchport mode trunk
 switchport trunk allowed vlan 10,20
 no spanning-tree portfast
 spanning-tree bpduguard disable
 no shutdown
 exit
```

Do not enable BPDU Filter on this port.

CDP can remain enabled because it helps identify the connected Cisco switch.

If company security policy requires CDP to be disabled:

```cisco
interface GigabitEthernet1/0/24
 no cdp enable
 exit
```

## 5. Alternative: configure a single-VLAN access connection

Use this configuration only when one VLAN must pass between the switches:

```cisco
interface GigabitEthernet1/0/24
 description ACCESS-LINK-TO-OLD-SWITCH
 switchport mode access
 switchport access vlan 10
 no spanning-tree portfast
 spanning-tree bpduguard disable
 no shutdown
 exit
```

Do not configure both the trunk and access examples on the same port.

## 6. Recover an err-disabled port

After correcting the BPDU Guard, loop or cabling problem:

```cisco
interface GigabitEthernet1/0/24
 shutdown
 no shutdown
 exit
```

Verify it:

```cisco
do show interfaces GigabitEthernet1/0/24 status
```

Repeatedly enabling a port without correcting the cause can create a network loop.

## 7. Configure the management IP address

A Layer 2 switch normally receives its management IP on a VLAN interface, also called an SVI.

```cisco
vlan 10
 name MANAGEMENT
 exit
interface vlan 10
 ip address 192.0.2.2 255.255.255.0
 no shutdown
 exit
```

Do not normally configure the management IP directly on a physical Layer 2 switch port.

For the VLAN interface to become active, VLAN 10 must exist on at least one active port or trunk.

## 8. Configure the default gateway

For a Layer 2 switch:

```cisco
ip default-gateway 192.0.2.1
```

The gateway must be reachable through the management VLAN.

## 9. Verify the configuration

```cisco
do show ip interface brief
do show interfaces trunk
do show vlan brief
do show spanning-tree
do ping 192.0.2.1
```

Verify that:

- the uplink is `connected`;
- the management SVI is `up/up`;
- the required VLANs are allowed;
- Spanning Tree has not detected a loop;
- the default gateway responds.

## 10. Save the configuration

Exit configuration mode:

```cisco
end
```

Review the active configuration:

```cisco
show running-config
```

Save it:

```cisco
copy running-config startup-config
```

Press `Enter` to accept the default destination filename.

Verify that the startup configuration exists:

```cisco
show startup-config
```

## Quick recommended uplink configuration

For a normal switch-to-switch trunk:

```cisco
enable
configure terminal

interface GigabitEthernet1/0/24
 description UPLINK-TO-OLD-SWITCH
 switchport mode trunk
 switchport trunk allowed vlan 10,20
 no spanning-tree portfast
 spanning-tree bpduguard disable
 no shutdown
 exit

end
copy running-config startup-config
```

## Commands that should not be used on the uplink

```cisco
spanning-tree portfast
spanning-tree bpdufilter enable
spanning-tree bpduguard enable
```

These commands are intended for specific edge-port scenarios and can either disable the port or hide a Layer 2 loop when used incorrectly.

## References

- [Cisco PortFast and BPDU Guard documentation](https://www.cisco.com/c/en/us/support/docs/lan-switching/spanning-tree-protocol/10586-65.html)
- [Cisco VLAN configuration guide](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst1000/software/releases/15_2_7_e/configuration_guides/vlan/b_1527e_vlan_c1000_cg/configuring_vlan.html)