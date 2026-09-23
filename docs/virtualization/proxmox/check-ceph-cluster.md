# Check Ceph Cluster Health on Proxmox

This procedure contains basic commands for checking the health of a Ceph cluster running on Proxmox VE.

> Do not stop all Ceph services during a routine health check. Restart only the specific failed daemon after identifying the problem.

## Quick health check

Run these commands from any Proxmox cluster node:

```bash
pvecm status
ceph status
ceph health detail
ceph osd tree
ceph df
```

A healthy cluster should normally report:

```text
HEALTH_OK
```

Possible health states:

- `HEALTH_OK` — the cluster is healthy.
- `HEALTH_WARN` — the cluster is operational, but requires attention.
- `HEALTH_ERR` — the cluster has a serious problem.

## Check Proxmox cluster quorum

```bash
pvecm status
```

Verify that:

- All expected Proxmox nodes are listed.
- The cluster is quorate.
- There are no missing or offline nodes.

## Check Ceph monitors

```bash
ceph mon stat
ceph quorum_status --format json-pretty
```

All expected monitor nodes should be members of the Ceph quorum.

## Check Ceph OSDs

```bash
ceph osd stat
ceph osd tree
ceph osd df tree
```

Each active OSD should normally appear as:

```text
up
in
```

An OSD marked `down` or `out` requires investigation.

## Check placement groups

```bash
ceph pg stat
ceph pg dump_stuck
```

Healthy placement groups normally appear as:

```text
active+clean
```

States such as `degraded`, `undersized`, `inactive` or `stale` require investigation.

## Check storage usage

```bash
ceph df
```

Check:

- Total cluster capacity
- Available capacity
- Pool usage
- Near-full or full conditions

## Check Ceph Manager and versions

```bash
ceph mgr stat
ceph versions
```

The manager command shows the active and standby manager daemons.

## Check Ceph services

List the Ceph services detected on the current node:

```bash
systemctl list-units 'ceph-mon@*' 'ceph-mgr@*' 'ceph-osd@*'
```

Check for failed systemd services:

```bash
systemctl --failed
```

## Check Ceph logs

First identify the exact service name:

```bash
systemctl list-units 'ceph-mon@*' 'ceph-mgr@*' 'ceph-osd@*'
```

Check a monitor log:

```bash
journalctl -u ceph-mon@MON_ID -n 100 --no-pager
```

Check a manager log:

```bash
journalctl -u ceph-mgr@MGR_ID -n 100 --no-pager
```

Check a specific OSD log:

```bash
journalctl -u ceph-osd@OSD_ID -n 100 --no-pager
```

Replace `MON_ID`, `MGR_ID` and `OSD_ID` with the real service identifiers.

## Check time synchronization

Accurate time synchronization is important for every Proxmox and Ceph node.

Run on every node:

```bash
timedatectl status
chronyc tracking
chronyc sources -v
```

Check the Chrony service:

```bash
systemctl status chrony --no-pager
```

If Chrony reports that a clock correction is required:

```bash
sudo chronyc makestep
```

Do not stop all Ceph services and do not manually change the system clock during a routine check.

## Restart a specific failed Ceph daemon

Restart only the daemon that was identified as failed.

Monitor example:

```bash
sudo systemctl restart ceph-mon@MON_ID
ceph status
```

Manager example:

```bash
sudo systemctl restart ceph-mgr@MGR_ID
ceph status
```

OSD example:

```bash
sudo systemctl restart ceph-osd@OSD_ID
ceph status
```

Restart one daemon at a time and check the cluster health after every operation.

## Important safety notes

- Do not stop all monitors simultaneously.
- Do not stop all OSDs simultaneously.
- Do not restart every Ceph node at the same time.
- Investigate quorum loss before restarting services.
- Confirm that the remaining replicas are healthy before taking an OSD or node offline.
- Perform recovery operations during an approved maintenance window.