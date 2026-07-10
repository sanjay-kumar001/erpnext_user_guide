# Creating and Optimizing Swap Space on a DigitalOcean Droplet for ERPNext v16

**Version:** 1.0  
**Target Environment:**

- Ubuntu Server 24.04 LTS
- DigitalOcean Droplet
- 4 GB RAM
- 2 vCPU
- 40 GB SSD
- Frappe Framework v16
- ERPNext Production
- Nginx
- MariaDB
- Redis
- Supervisor

---

# Table of Contents

1. Overview
2. Why Swap is Important
3. Current Problem Analysis
4. Recommended Memory Layout
5. Create Swap Space
6. Configure Linux Memory Management
7. Verify Swap Configuration
8. Memory Optimization for ERPNext
9. MariaDB Optimization
10. Redis Optimization
11. Gunicorn & Workers Optimization
12. Monitoring Memory Usage
13. Troubleshooting
14. Best Practices
15. Production Checklist

---

# 1. Overview

ERPNext is a memory-intensive application.

During normal operation, memory usage remains moderate.

However, certain commands such as:

```bash
bench migrate
bench build
bench update
```

may temporarily consume nearly all available RAM because Node.js compiles JavaScript, SCSS, and frontend assets.

On a 4 GB DigitalOcean Droplet, memory spikes are expected.

Without swap, Linux may invoke the OOM (Out of Memory) Killer and terminate processes such as:

- Node
- MariaDB
- Gunicorn
- Redis

Adding swap significantly improves system stability.

---

# 2. Why Swap is Important

Swap is **not additional RAM**.

Instead, it acts as overflow storage when physical memory is exhausted.

Benefits include:

- Prevents OOM crashes
- Allows `bench build` to complete
- Protects MariaDB from unexpected termination
- Improves overall system stability

For ERPNext production servers, swap should be considered mandatory on systems with 4 GB RAM or less.

---

# 3. Current Problem Analysis

Observed during:

```bash
bench migrate
bench build
```

System status:

```
RAM Used : 3.58 GB / 3.82 GB
CPU      : 97%
Swap     : 0 GB
Load Avg : 9.26
```

Analysis:

- CPU utilization is expected.
- Memory usage is expected.
- No swap space exists.
- The system has almost no safety margin before the OOM Killer is triggered.

---

# 4. Recommended Memory Layout

| Component | Recommended |
|------------|------------:|
| Physical RAM | 4 GB |
| Swap | 4 GB |
| MariaDB Buffer Pool | 1 GB |
| Redis Cache | 256 MB |
| Redis Queue | 128 MB |
| Redis SocketIO | 64 MB |
| Gunicorn Workers | 2 |
| Background Workers | 2 |
| Scheduler | 1 |

---

# 5. Create Swap Space

## Step 1

Check current memory.

```bash
free -h
```

Expected:

```
Swap: 0B
```

---

## Step 2

Create a 4 GB swap file.

```bash
sudo fallocate -l 4G /swapfile
```

If `fallocate` is unavailable:

```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
```

---

## Step 3

Secure the swap file.

```bash
sudo chmod 600 /swapfile
```

Verify:

```bash
ls -lh /swapfile
```

Expected:

```
-rw------- 4.0G
```

---

## Step 4

Create the swap filesystem.

```bash
sudo mkswap /swapfile
```

---

## Step 5

Enable swap.

```bash
sudo swapon /swapfile
```

Verify:

```bash
swapon --show
```

Example:

```
NAME       TYPE SIZE USED PRIO
/swapfile  file 4G   0B   -2
```

---

## Step 6

Make swap permanent.

Edit:

```bash
sudo nano /etc/fstab
```

Add:

```
/swapfile none swap sw 0 0
```

---

# 6. Configure Linux Memory Management

## Swappiness

Default:

```
60
```

Recommended:

```
10
```

Temporary:

```bash
sudo sysctl vm.swappiness=10
```

Permanent:

Edit:

```bash
sudo nano /etc/sysctl.conf
```

Add:

```
vm.swappiness=10
```

---

## Cache Pressure

Default:

```
100
```

Recommended:

```
50
```

Add:

```
vm.vfs_cache_pressure=50
```

Reload:

```bash
sudo sysctl -p
```

---

# 7. Verify Swap

```bash
free -h
```

Example:

```
Mem : 3.8G
Swap: 4.0G
```

---

# 8. Memory Optimization for ERPNext

During `bench build`, Node.js is usually the largest memory consumer.

To identify memory usage:

```bash
ps aux --sort=-%mem | head -20
```

or

```bash
htop
```

Typical high-memory processes include:

- node
- vite
- esbuild
- yarn

---

## Reduce Node.js Heap (Optional)

```bash
export NODE_OPTIONS="--max-old-space-size=1024"
```

Then run:

```bash
bench build
```

If build fails due to heap exhaustion:

```bash
export NODE_OPTIONS="--max-old-space-size=1536"
```

---

## Stop Frappe Services Before Build

During maintenance:

```bash
sudo supervisorctl stop all
```

Run:

```bash
bench build
```

Restart:

```bash
sudo supervisorctl start all
```

This frees several hundred MB of RAM during asset compilation.

---

# 9. MariaDB Optimization

Edit:

```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```

Recommended:

```ini
[mysqld]

innodb_buffer_pool_size=1G
innodb_log_file_size=256M
innodb_flush_method=O_DIRECT

max_connections=100

tmp_table_size=64M
max_heap_table_size=64M

thread_cache_size=50
table_open_cache=1024

skip-name-resolve
```

Restart:

```bash
sudo systemctl restart mariadb
```

---

# 10. Redis Optimization

Redis Cache

```
maxmemory 256mb
maxmemory-policy allkeys-lru
```

Redis Queue

```
maxmemory 128mb
```

Redis SocketIO

```
maxmemory 64mb
```

Restart Redis or Supervisor afterward.

---

# 11. Gunicorn & Background Workers

Recommended for:

- 2 vCPU
- 4 GB RAM

Gunicorn:

```
Workers = 2
```

Background Workers:

```
default = 1

short = 1

long = 1
```

Avoid excessive workers, as each consumes additional RAM.

---

# 12. Monitoring Memory

Install monitoring tools.

```bash
sudo apt install htop iotop -y
```

Useful commands:

```bash
free -h
```

```bash
htop
```

```bash
watch free -h
```

```bash
ps aux --sort=-rss | head -20
```

---

## Detect OOM Events

```bash
journalctl -k | grep -i oom
```

or

```bash
dmesg | grep -i oom
```

---

# 13. Troubleshooting

## Swap Not Enabled

Check:

```bash
swapon --show
```

If empty:

```bash
sudo swapon /swapfile
```

---

## Build Still Fails

Increase Node.js heap:

```bash
export NODE_OPTIONS="--max-old-space-size=1536"
```

---

## OOM Killer

Inspect:

```bash
journalctl -k | grep -i killed
```

---

## Excessive Swap Usage

Example:

```
RAM  : 3.9 GB

Swap : 3.5 GB
```

This indicates the server needs:

- More RAM
- Fewer workers
- Smaller MariaDB buffer pool
- Investigation into application memory usage

---

# 14. Best Practices

✔ Create swap before deploying ERPNext.

✔ Keep `vm.swappiness=10`.

✔ Use `vm.vfs_cache_pressure=50`.

✔ Restart workers only if necessary.

✔ Avoid unnecessary `bench build`.

✔ Build only after frontend changes.

✔ Monitor RAM periodically.

✔ Keep MariaDB buffer pool around 25% of total RAM.

✔ Keep Redis memory limited.

✔ Regularly inspect logs for OOM events.

---

# 15. Production Checklist

- [ ] 4 GB Swap Created
- [ ] `/etc/fstab` Updated
- [ ] `vm.swappiness=10`
- [ ] `vm.vfs_cache_pressure=50`
- [ ] MariaDB Buffer Pool = 1 GB
- [ ] Redis Memory Limits Configured
- [ ] Gunicorn Workers = 2
- [ ] Background Workers Optimized
- [ ] `htop` Installed
- [ ] `iotop` Installed
- [ ] OOM Monitoring Verified
- [ ] Swap Verified After Reboot

---

# Conclusion

For a **DigitalOcean Droplet with 4 GB RAM**, a **4 GB swap file** combined with conservative memory tuning provides a stable environment for ERPNext v16. While `bench build` and `bench migrate` can temporarily consume nearly all available RAM, proper swap configuration, Linux VM tuning, and optimized MariaDB, Redis, and Gunicorn settings help prevent out-of-memory crashes and improve overall reliability.