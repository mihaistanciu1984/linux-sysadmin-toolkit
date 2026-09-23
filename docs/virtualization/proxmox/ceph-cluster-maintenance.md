# Proxmox Ceph Cluster Maintenance

This procedure contains basic commands for maintaining and monitoring a Proxmox Ceph cluster.

It covers:

- Proxmox HA node maintenance mode;
- Ceph cluster health;
- OSD status and utilization;
- placement group recovery;
- temporary recovery performance tuning;
- hardware RAID disk status.

> Warning: Run maintenance operations from a healthy cluster with working quorum. Do not continue if Ceph reports unresolved critical errors.

## 1. Check the Proxmox cluster

Check quorum:

```bash
pvecm status
```

Check Proxmox HA resources:

```bash
ha-manager status
```

Before maintenance, verify that:

- the cluster has quorum;
- all expected nodes are online;
- HA resources are running;
- sufficient resources exist on the remaining nodes.

## 2. Check Ceph health

Display the general cluster status:

```bash
ceph -s
```

Display detailed health warnings:

```bash
ceph health detail
```

A healthy cluster should normally report:

```text
HEALTH_OK
```

Placement groups should normally be:

```text
active+clean
```

Do not start planned maintenance if the cluster already has failed or degraded OSDs unless the maintenance is intended to repair that problem.

## 3. Display OSD status

Display OSDs organized by node:

```bash
ceph osd tree
```

Important states:

- `up` means the OSD process is running;
- `down` means the OSD process is unavailable;
- `in` means the OSD participates in data placement;
- `out` means Ceph no longer places data on that OSD.

Display an OSD summary:

```bash
ceph osd stat
```

Display OSD usage and available space:

```bash
ceph osd df tree
```

Display OSD commit and apply latency:

```bash
ceph osd perf
```

Large latency values may indicate:

- a slow or failing disk;
- high recovery activity;
- network problems;
- an overloaded storage controller.

## 4. Display placement group status

```bash
ceph pg stat
```

Common PG states include:

| State | Meaning |
|---|---|
| `active+clean` | Healthy |
| `degraded` | Some replicas are unavailable |
| `recovering` | Missing replicas are being restored |
| `backfilling` | Data is being redistributed |
| `peering` | OSDs are determining the current PG state |
| `inactive` | PG cannot currently serve I/O |

Display active recovery operations:

```bash
ceph progress
```

## 5. Continuously monitor Ceph

```bash
watch -n 5 'ceph -s'
```

Press `Ctrl+C` to stop monitoring.

For a more detailed display:

```bash
watch -n 5 'ceph osd stat; echo; ceph pg stat'
```

## 6. Enable Proxmox node maintenance mode

Replace `proxmox-node` with the real node name:

```bash
ha-manager crm-command node-maintenance enable proxmox-node
```

Monitor HA while the command is processed:

```bash
watch -n 5 'ha-manager status'
```

Maintenance mode affects resources managed by Proxmox HA. Always verify the migration or stopping behavior of the configured HA services.

It does not automatically make the Ceph cluster healthy or stop every non-HA VM.

## 7. Optional: prevent automatic OSD removal

For a short, planned Ceph node reboot, an administrator may temporarily set the `noout` flag:

```bash
ceph osd set noout
```

Verify the flag:

```bash
ceph osd dump | grep flags
```

This prevents Ceph from marking unavailable OSDs as `out` and starting unnecessary data redistribution during a short outage.

> Do not leave `noout` enabled after maintenance. It can prevent Ceph from recovering correctly after a real OSD failure.

After the node and all OSDs have returned:

```bash
ceph osd unset noout
```

Verify:

```bash
ceph osd dump | grep flags
```

Use `noout` only for a planned, short interruption.

## 8. Check disks attached to local OSDs

On a Ceph node, display the local OSD and device mapping:

```bash
ceph-volume lvm list
```

Display block devices:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
```

Check disk health when SMART is supported:

```bash
smartctl -a /dev/sdX
```

Replace `/dev/sdX` with the correct physical disk.

Do not run repair or destructive SMART operations without identifying the correct disk.

## 9. Check hardware RAID disks with StorCLI

Use these commands only if the server contains a supported Broadcom/LSI hardware RAID controller.

Display the controller summary:

```bash
storcli /c0 show
```

Display all enclosures and physical disks:

```bash
storcli /c0 /eall /sall show
```

Display virtual drives:

```bash
storcli /c0 /vall show
```

Review disks with states such as:

```text
Failed
Offline
Degraded
Predictive Failure
```

Ceph installations commonly use direct disks, HBA or JBOD mode. StorCLI is relevant only when a supported hardware controller is present.

## 10. Check the current Ceph recovery profile

Before changing the profile, record its current value:

```bash
ceph config get osd osd_mclock_profile
```

The common default profile is:

```text
balanced
```

Do not assume that every cluster uses the default. Record the result so it can be restored after recovery.

## 11. Temporarily accelerate PG recovery

During a maintenance window or low client activity, use:

```bash
ceph config set osd osd_mclock_profile high_recovery_ops
```

This profile gives more resources to background recovery operations.

Monitor the cluster:

```bash
watch -n 5 'ceph -s'
```

Also monitor OSD latency:

```bash
watch -n 5 'ceph osd perf'
```

> `high_recovery_ops` can reduce storage performance for running VMs and containers. Use it temporarily and monitor client latency.

## 12. Return the recovery profile to normal

If the previous profile was `balanced`, restore it with:

```bash
ceph config set osd osd_mclock_profile balanced
```

Verify the value:

```bash
ceph config get osd osd_mclock_profile
```

If the cluster previously used another profile, restore that original value instead.

## 13. Finish node maintenance

Verify that every expected OSD is `up` and `in`:

```bash
ceph osd tree
```

Verify that Ceph is healthy:

```bash
ceph -s
```

If `noout` was enabled, remove it:

```bash
ceph osd unset noout
```

Disable Proxmox node maintenance mode:

```bash
ha-manager crm-command node-maintenance disable proxmox-node
```

Verify HA:

```bash
ha-manager status
```

Continue monitoring until:

- the node is online;
- all expected OSDs are `up` and `in`;
- all PGs are `active+clean`;
- Ceph reports `HEALTH_OK`;
- HA resources are in their expected state.

## Quick command reference

```bash
# Proxmox cluster and HA
pvecm status
ha-manager status

# Ceph health
ceph -s
ceph health detail

# OSD information
ceph osd tree
ceph osd stat
ceph osd df tree
ceph osd perf

# Placement groups
ceph pg stat
ceph progress

# Continuous monitoring
watch -n 5 'ceph -s'

# Hardware RAID disks
storcli /c0 /eall /sall show
```

## References

- [Proxmox HA Manager](https://pve.proxmox.com/pve-docs/ha-manager.1.html)
- [Ceph cluster monitoring](https://docs.ceph.com/en/reef/rados/operations/monitoring/)
- [Ceph OSD and PG monitoring](https://docs.ceph.com/en/reef/rados/operations/monitoring-osd-pg/)
- [Ceph mClock configuration](https://docs.ceph.com/en/latest/rados/configuration/mclock-config-ref/)
- [Ceph OSD troubleshooting](https://docs.ceph.com/en/latest/rados/troubleshooting/troubleshooting-osd/)