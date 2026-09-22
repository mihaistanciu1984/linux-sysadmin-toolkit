# Linux CPU and Load Troubleshooting

This procedure describes how to investigate high CPU usage, elevated load average, I/O wait, CPU steal time and process-level CPU consumption.

## Display system load

```bash
uptime
```

Example:

```text
load average: 1.20, 0.95, 0.70
```

The three values represent the average system load over:

* 1 minute
* 5 minutes
* 15 minutes

Load average is not a CPU percentage. It includes runnable processes and tasks waiting in uninterruptible states, commonly because of storage I/O.

## Display available CPU cores

```bash
nproc
```

Detailed CPU information:

```bash
lscpu
```

A load average of `4.0` can indicate full utilization on a four-core system, but the same value may be normal on a system with sixteen cores.

## Interactive CPU analysis

```bash
top
```

Useful commands inside `top`:

* `P` — sort by CPU usage
* `1` — display individual CPU cores
* `H` — display threads
* `q` — exit

If available:

```bash
htop
```

## Find processes consuming CPU

```bash
ps -eo pid,ppid,user,comm,%cpu,%mem \
    --sort=-%cpu |
    head -n 16
```

Display process runtime:

```bash
ps -eo pid,user,etime,comm,%cpu \
    --sort=-%cpu |
    head -n 16
```

## Monitor CPU statistics

Install `sysstat` on Ubuntu or Debian:

```bash
sudo apt update
sudo apt install -y sysstat
```

Display statistics for every CPU:

```bash
mpstat -P ALL 1 10
```

Important values:

* `%usr` — user-space CPU usage
* `%sys` — kernel CPU usage
* `%iowait` — time waiting for I/O
* `%steal` — CPU time taken by the hypervisor
* `%idle` — unused CPU capacity

## Monitor processes continuously

```bash
pidstat -u 1 10
```

Monitor a specific process:

```bash
pidstat -u -p PID 1 10
```

Replace `PID` with the process identifier.

## Check CPU and I/O pressure

```bash
vmstat 1 10
```

Important columns:

* `r` — runnable processes
* `b` — processes blocked on I/O
* `us` — user CPU
* `sy` — system CPU
* `id` — idle CPU
* `wa` — I/O wait
* `st` — stolen CPU time in virtual machines

## Check Linux CPU pressure

```bash
cat /proc/pressure/cpu
```

Sustained values in `some` indicate that processes are waiting for CPU time.

## Analyze I/O wait

High load with high `%iowait` may indicate storage rather than CPU problems.

```bash
iostat -xz 1 10
```

Look for:

* high device utilization;
* increasing wait times;
* high queue depth;
* low throughput combined with high latency.

## Analyze a multithreaded process

```bash
top -H -p PID
```

Alternative:

```bash
ps -Lp PID -o pid,tid,psr,pcpu,stat,comm
```

## Check temperature and throttling

Install sensor utilities:

```bash
sudo apt install -y lm-sensors
sudo sensors-detect
```

Display temperatures:

```bash
sensors
```

Check kernel messages:

```bash
sudo journalctl -k |
    grep -Ei 'thermal|throttl|temperature'
```

## Virtual-machine considerations

High `%steal` indicates that the hypervisor is not providing the VM with all requested CPU time.

Investigate:

* host CPU overcommitment;
* competing virtual machines;
* CPU limits;
* CPU affinity;
* hypervisor scheduling;
* host power-management settings.

## Recommended actions

1. Compare load average with the available CPU count.
2. Identify the processes or threads consuming CPU.
3. Determine whether the load is CPU-bound or I/O-bound.
4. Review the affected application logs.
5. Check recent deployments or configuration changes.
6. Verify hypervisor CPU contention for virtual machines.
7. Check temperature and CPU throttling.
8. Apply resource limits only after understanding the workload.

Do not terminate a process before verifying its purpose and operational impact.
