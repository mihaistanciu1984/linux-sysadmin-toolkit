# Linux Memory Troubleshooting

This procedure describes how to analyze high memory usage, swap activity, memory pressure and Out-of-Memory events on Linux systems.

## Display memory usage

```bash
free -h
```

The most important value is `available`, not `free`.

Linux uses unused memory for filesystem cache and automatically releases it when applications require additional memory.

## Display detailed memory information

```bash
cat /proc/meminfo
```

Important fields include:

* `MemTotal`
* `MemAvailable`
* `Cached`
* `Buffers`
* `SwapTotal`
* `SwapFree`
* `Slab`
* `SReclaimable`

## Monitor memory activity

```bash
vmstat 1 10
```

Important columns:

* `free` — unused memory
* `buff` — buffer memory
* `cache` — filesystem cache
* `si` — memory read from swap
* `so` — memory written to swap
* `r` — processes waiting for CPU
* `wa` — CPU time waiting for I/O

Continuous non-zero values in `si` and `so` can indicate memory pressure.

## Find processes using the most memory

```bash
ps -eo pid,user,comm,%mem,rss \
    --sort=-rss |
    head -n 16
```

The `RSS` value is displayed in KiB.

Interactive analysis:

```bash
top
```

Inside `top`, press:

```text
Shift + M
```

to sort processes by memory usage.

If installed, `htop` provides an easier interactive interface:

```bash
htop
```

## Check swap usage

```bash
swapon --show
free -h
```

Display swap devices:

```bash
cat /proc/swaps
```

Swap usage alone does not always indicate a problem. Investigate whether swap usage is increasing continuously and whether the system is experiencing latency.

## Check memory pressure

On systems supporting Pressure Stall Information:

```bash
cat /proc/pressure/memory
```

Values in `some` indicate that some processes were delayed because of memory pressure.

Values in `full` indicate that all non-idle processes were stalled simultaneously.

## Check for Out-of-Memory events

```bash
sudo journalctl -k \
    --grep='Out of memory|Killed process|oom-killer'
```

Alternative command:

```bash
sudo dmesg -T |
    grep -Ei 'out of memory|killed process|oom-killer'
```

An OOM event means the kernel terminated one or more processes because sufficient memory could not be allocated.

## Check systemd control groups

```bash
systemd-cgtop
```

This can help identify services or containers consuming excessive memory.

Display the memory properties of a specific service:

```bash
systemctl show example.service |
    grep -E 'MemoryCurrent|MemoryPeak|MemoryMax'
```

Replace `example.service` with the required service.

## Check slab usage

```bash
sudo slabtop
```

Large slab usage can indicate kernel cache growth or a kernel-related resource issue.

## Recommended actions

1. Identify the process responsible for the memory growth.
2. Determine whether usage is expected for the workload.
3. Review application and service logs.
4. Check for application memory leaks.
5. Verify swap activity and storage latency.
6. Configure application or systemd memory limits where appropriate.
7. Add memory or swap only after identifying the root cause.
8. Restart a service only after understanding the operational impact.

## Commands to avoid during initial diagnosis

Do not clear filesystem caches as a first troubleshooting action:

```bash
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches
```

Clearing caches can reduce performance and hide the original issue without fixing it.

Do not terminate processes before verifying their purpose and business impact.
