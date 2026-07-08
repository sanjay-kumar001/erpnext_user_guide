# ERPNext LAN Production Deployment Guide

## Secure ERPNext Access on Local Network with SSL, NGINX, Firewall, and Performance Tuning

---

## Table of Contents

1. [System Information](#1-system-information)  
2. [Objective](#2-objective)  
3. [Network Setup (LAN Accessibility)](#3-network-setup-lan-accessibility)  
   - 3.1 [Check Current IP and Interface](#31-check-current-ip-and-interface)  
   - 3.2 [Identify Gateway](#32-identify-gateway)  
   - 3.3 [Choose a Static IP](#33-choose-a-static-ip)  
   - 3.4 [Configure Static IP with Netplan](#34-configure-static-ip-with-netplan)  
   - 3.5 [Apply and Verify](#35-apply-and-verify)  
4. [Local Domain Setup (Avahi & Hosts)](#4-local-domain-setup-avahi--hosts)  
   - 4.1 [Install and Configure Avahi (mDNS) for Automatic Resolution](#41-install-and-configure-avahi-mdns-for-automatic-resolution)  
   - 4.2 [Hosts File Fallback (Optional)](#42-hosts-file-fallback-optional)  
5. [SSL/TLS Certificate Setup](#5-ssltls-certificate-setup)  
   - 5.1 [Create a Local Root Certificate Authority](#51-create-a-local-root-certificate-authority)  
   - 5.2 [Generate Server Certificate with SAN](#52-generate-server-certificate-with-san)  
   - 5.3 [Trust the Root CA on Client Devices](#53-trust-the-root-ca-on-client-devices)  
   - 5.4 [Alternative: Use `mkcert` for Simplified SSL](#54-alternative-use-mkcert-for-simplified-ssl)  
6. [ERPNext Production Setup](#6-erpnext-production-setup)  
   - 6.1 [Install Dependencies](#61-install-dependencies)  
   - 6.2 [Set Up Bench in Production Mode](#62-set-up-bench-in-production-mode)  
   - 6.3 [Enable Scheduler](#63-enable-scheduler)  
7. [NGINX Configuration](#7-nginx-configuration)  
   - 7.1 [Create Site Configuration](#71-create-site-configuration)  
   - 7.2 [Enable Site and Reload](#72-enable-site-and-reload)  
8. [Firewall Configuration (UFW)](#8-firewall-configuration-ufw)  
   - 8.1 [Allow SSH and Web Ports](#81-allow-ssh-and-web-ports)  
   - 8.2 [Restrict to Local Network](#82-restrict-to-local-network)  
   - 8.3 [Enable UFW](#83-enable-ufw)  
9. [Database Tuning (MariaDB)](#9-database-tuning-mariadb)  
10. [Redis Optimization](#10-redis-optimization)  
11. [Backup Automation](#11-backup-automation)  
    - 11.1 [Create Backup Script](#111-create-backup-script)  
    - 11.2 [Schedule with Cron](#112-schedule-with-cron)  
12. [Additional Security](#12-additional-security)  
    - 12.1 [Fail2Ban](#121-fail2ban)  
13. [Remote Access Options](#13-remote-access-options)  
    - 13.1 [Tailscale (Recommended for Admin Access)](#131-tailscale-recommended-for-admin-access)  
    - 13.2 [Cloudflare Tunnel (For Public Exposure)](#132-cloudflare-tunnel-for-public-exposure)  
14. [Testing and Troubleshooting](#14-testing-and-troubleshooting)  
    - 14.1 [Common Netplan Errors](#141-common-netplan-errors)  
    - 14.2 [Verify Services](#142-verify-services)  
15. [Conclusion and Recommendations](#15-conclusion-and-recommendations)  

---

## 1. System Information

| Component | Details |
|-----------|---------|
| Laptop | Dell (2024 Model) |
| OS | Ubuntu 24.04 |
| RAM | 8GB DDR4 |
| CPU | Intel 8 Cores |
| GPU | Nvidia |
| VRAM | 4GB |
| Storage | 500GB HDD |

---

## 2. Objective

Configure an ERPNext site (named `erpnext.local`) running on a laptop so that it can be **securely accessed** from:

- Devices connected to the same WiFi
- Devices connected via LAN cable
- Using **HTTPS/SSL** encryption
- With a **production-ready** stack (NGINX, Supervisor, Gunicorn)
- With firewall hardening, database tuning, and automated backups

---

## 3. Network Setup (LAN Accessibility)

This section ensures your laptop has a **static IP** address on the local network, so it can be consistently reached by other devices.

### 3.1 Check Current IP and Interface

```bash
ip a | grep inet
```

Note the active interface name (e.g., `wlp2s0` for WiFi, `enp3s0` for Ethernet) and current IP address (e.g., `192.168.1.10/24`).

### 3.2 Identify Gateway

```bash
ip route show default
```

Example output:
```
default via 192.168.1.1 dev wlp2s0 proto dhcp src 192.168.1.10 metric 600
```

The gateway is `192.168.1.1`.

### 3.3 Choose a Static IP

- Pick an IP **outside** your router’s DHCP pool to avoid conflicts (common ranges: 100–200 or 2–100).  
- Example: `192.168.1.250/24`.  
- Ensure the subnet mask (`/24`) matches your network.

### 3.4 Configure Static IP with Netplan

Netplan configuration files are in `/etc/netplan/`. First, list existing files:

```bash
ls -la /etc/netplan/
```

You may see files like:
- `01-network-manager-all.yaml` (user‑created)
- `50-cloud-init.yaml` (present on some cloud‑image installations)

> **Important:** Netplan **does not merge** interface definitions across multiple files. If `50-cloud-init.yaml` already defines your interface (e.g., `wlp2s0`), **edit that file directly** instead of creating a second one.

#### For WiFi Interface (e.g., `wlp2s0`)

**Option A (recommended with `wifis:` and SSID/password):**

Edit the appropriate file:

```bash
sudo nano /etc/netplan/01-network-manager-all.yaml   # or 50-cloud-init.yaml
```

Example configuration:

```yaml
network:
  version: 2
  renderer: NetworkManager
  wifis:
    wlp2s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.1.250/24          # your chosen static IP
      routes:
        - to: default
          via: 192.168.1.1          # your gateway
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
      access-points:
        "Your_SSID":
          password: "Your_Password"
```

**Option B (if you prefer not to hardcode credentials, with `ethernets:` and `NetworkManager`):**

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    wlp2s0:
      dhcp4: false
      addresses:
        - 192.168.1.250/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

> **Note:** If you already have a `wifis:` section, do not add a separate `ethernets:` section for the same interface. Edit the existing block instead.

#### For Ethernet Interface (e.g., `enp3s0`)

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp3s0:
      dhcp4: false
      addresses:
        - 192.168.1.250/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

#### Secure File Permissions

```bash
sudo chmod 600 /etc/netplan/your-file.yaml
```

### 3.5 Apply and Verify

```bash
sudo netplan apply
```

Check the new IP:

```bash
ip a | grep wlp2s0      # or your interface
```

Test connectivity:

```bash
ping -c 4 192.168.1.1
ping -c 4 google.com
```

If both succeed, the static IP is correctly configured.

---

## 4. Local Domain Setup (Avahi & Hosts)

To access your ERPNext site using a human‑friendly name like `https://erpnext.local`, you have two options:

- **Avahi (mDNS)** – automatic resolution for all devices on the same network (recommended).
- **Hosts file** – manual entry on each client (fallback).

### 4.1 Install and Configure Avahi (mDNS) for Automatic Resolution

Avahi implements the zero‑configuration mDNS/DNS‑SD protocol, allowing devices to resolve `.local` hostnames without a DNS server. Most modern operating systems support mDNS out‑of‑the‑box (Linux with Avahi, macOS with Bonjour, Windows 10/11 with a built‑in mDNS responder).

On the **server** (your Ubuntu laptop), install and enable Avahi:

```bash
sudo apt update
sudo apt install avahi-daemon avahi-utils
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon
```

Now, set your server’s hostname to `erpnext` (the `.local` is implied by mDNS). Edit `/etc/hostname`:

```bash
sudo nano /etc/hostname
```

Replace the existing name with:
```
erpnext
```

Also, edit `/etc/hosts` so that the hostname resolves locally:

```bash
sudo nano /etc/hosts
```

Ensure the line starting with `127.0.1.1` matches your new hostname:

```
127.0.1.1       erpnext.local erpnext
```

Restart Avahi:

```bash
sudo systemctl restart avahi-daemon
```

Verify that the server announces its `.local` name:

```bash
avahi-browse -a
```

You should see `erpnext.local` with your IP address.

**On client devices**, ensure mDNS is enabled:

- **Linux**: Install `avahi-daemon` and `libnss-mdns` so that `.local` names resolve.
- **macOS**: Bonjour is enabled by default; no extra steps.
- **Windows**: Windows 10/11 includes a native mDNS responder; otherwise, install Bonjour (from Apple) or enable the service.

Now, any device on the same LAN can simply visit:

```
https://erpnext.local
```

— no hosts file editing needed.

### 4.2 Hosts File Fallback (Optional)

If some clients do not support mDNS (e.g., older systems), you can still add a static entry:

#### Linux / macOS

```bash
sudo nano /etc/hosts
```

Add:

```
192.168.1.250   erpnext.local
```

#### Windows (as Administrator)

Edit `C:\Windows\System32\drivers\etc\hosts` and add the same line.

---

## 5. SSL/TLS Certificate Setup

Modern browsers reject self-signed certificates unless they are issued by a trusted root CA and contain Subject Alternative Names (SAN). We will create our own Root CA, sign a server certificate for `erpnext.local`, and install the Root CA on all client devices.

### 5.1 Create a Local Root Certificate Authority

```bash
sudo mkdir -p /etc/ssl/ca
cd /etc/ssl/ca
```

Generate Root CA private key (keep this secure!):

```bash
sudo openssl genrsa -out rootCA.key 2048
```

Generate Root CA certificate (valid for 10 years):

```bash
sudo openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.pem \
  -subj "/C=IN/ST=Madhya Pradesh/L=Jabalpur/O=Avian Network/CN=Avian Root CA"
```

### 5.2 Generate Server Certificate with SAN

Create a SAN configuration file:

```bash
sudo nano /etc/ssl/ca/san.cnf
```

Contents:

```ini
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = IN
ST = Madhya Pradesh
L = Jabalpur
O = Avian Services
CN = erpnext.local

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = erpnext.local
```

Generate server key and CSR:

```bash
sudo openssl genrsa -out erpnext.local.key 2048
sudo openssl req -new -key erpnext.local.key -out erpnext.local.csr -config san.cnf
```

Sign the certificate with the Root CA (valid for 398 days – Apple’s maximum for server certs):

```bash
sudo openssl x509 -req -in erpnext.local.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial \
  -out erpnext.local.crt -days 398 -sha256 -extfile san.cnf -extensions req_ext
```

Now you have:
- `rootCA.pem` (to be installed on clients)
- `rootCA.key` (keep secret, never share)
- `erpnext.local.crt` and `erpnext.local.key` (to be used by NGINX)

### 5.3 Trust the Root CA on Client Devices

Install only the `rootCA.pem` certificate on every device that will access `erpnext.local`. **Never share the private key (`rootCA.key`).**

#### Ubuntu (Client or Server itself)

```bash
sudo cp rootCA.pem /usr/local/share/ca-certificates/rootCA.crt
sudo update-ca-certificates
```

#### Windows

1. Transfer `rootCA.pem` to the Windows machine.
2. Double-click the file and click **Install Certificate**.
3. Select **Local Machine** > Next.
4. Choose **Place all certificates in the following store** > **Browse**.
5. Select **Trusted Root Certification Authorities** > OK > Next > Finish.

#### macOS

1. Open `rootCA.pem` with Keychain Access.
2. Add it to the **System** keychain.
3. Double-click the certificate, expand **Trust**, and select **Always Trust** for SSL.

#### Android

1. Copy `rootCA.pem` to the device.
2. Go to **Settings > Security > Encryption & credentials > Install from storage** (or similar).
3. Select **CA certificate** and choose the file.

#### iOS / iPadOS

1. Email or AirDrop `rootCA.pem` to the device and open it.
2. Go to **Settings > Profile Downloaded** and tap **Install**.
3. Navigate to **Settings > General > About > Certificate Trust Settings**.
4. Enable full trust for your Root CA.

### 5.4 Alternative: Use `mkcert` for Simplified SSL

If you prefer a simpler tool that automatically creates locally trusted certificates:

```bash
sudo apt install libnss3-tools
curl -LO https://dl.filippo.io/mkcert/latest?for=linux/amd64
chmod +x mkcert
sudo mv mkcert /usr/local/bin/
```

Then:

```bash
mkcert -install
mkcert erpnext.local
```

This generates `erpnext.local.pem` and `erpnext.local-key.pem` which are already trusted by your system.

---

## 6. ERPNext Production Setup

### 6.1 Install Dependencies

```bash
sudo apt update
sudo apt install nginx supervisor redis-server mariadb-server -y
```

### 6.2 Set Up Bench in Production Mode

Assuming you have an existing Frappe bench in `~/frappe-bench`:

```bash
cd ~/frappe-bench
sudo bench setup production $USER
```

This configures:
- Nginx (supervised)
- Supervisor processes (web, worker, scheduler)
- Gunicorn

### 6.3 Enable Scheduler

```bash
bench enable-scheduler
```

Make sure your default site is set correctly:

```bash
bench use erpnext.local
```

---

## 7. NGINX Configuration

### 7.1 Create Site Configuration

Edit the Nginx config file for your site (usually `/etc/nginx/sites-available/frappe-bench` or create a new one):

```bash
sudo nano /etc/nginx/sites-available/erpnext
```

Paste the following configuration:

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name erpnext.local;
    return 301 https://$host$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name erpnext.local;

    ssl_certificate /etc/ssl/ca/erpnext.local.crt;
    ssl_certificate_key /etc/ssl/ca/erpnext.local.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Proxy to Frappe Bench (Gunicorn on port 8000 by default)
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support for real-time updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

> **Note:** If you used `mkcert`, adjust the certificate paths to point to those files.

### 7.2 Enable Site and Reload

```bash
sudo ln -s /etc/nginx/sites-available/erpnext /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 8. Firewall Configuration (UFW)

### 8.1 Allow SSH and Web Ports

```bash
sudo ufw allow 22/tcp    # SSH (adjust if using a different port)
sudo ufw allow 80/tcp    # HTTP (for redirect)
sudo ufw allow 443/tcp   # HTTPS
```

### 8.2 Restrict to Local Network

To limit access to your local subnet only (e.g., `192.168.1.0/24`):

```bash
sudo ufw allow from 192.168.1.0/24 to any port 80
sudo ufw allow from 192.168.1.0/24 to any port 443
```

### 8.3 Enable UFW

```bash
sudo ufw enable
```

Check status:

```bash
sudo ufw status
```

---

## 9. Database Tuning (MariaDB)

Create a custom MariaDB configuration file for better performance:

```bash
sudo nano /etc/mysql/mariadb.conf.d/99-erpnext.cnf
```

Add the following (adjust values based on your system RAM):

```ini
[mysqld]

# InnoDB settings
innodb_buffer_pool_size = 4G       # ~50-70% of total RAM (e.g., 4GB for 8GB RAM)
innodb_log_file_size = 512M
innodb_flush_method = O_DIRECT

# Connections
max_connections = 150

# Query cache (disable in modern MariaDB)
query_cache_type = 0
query_cache_size = 0

# Temp tables
tmp_table_size = 256M
max_heap_table_size = 256M

# Table cache
table_open_cache = 4000

# I/O threads
innodb_io_capacity = 1000
innodb_read_io_threads = 4
innodb_write_io_threads = 4

# Slow query log (for troubleshooting)
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
```

Restart MariaDB:

```bash
sudo systemctl restart mariadb
```

---

## 10. Redis Optimization

Edit the Redis configuration:

```bash
sudo nano /etc/redis/redis.conf
```

Set memory limit (adjust as needed):

```ini
maxmemory 1gb
maxmemory-policy allkeys-lru
```

Restart Redis:

```bash
sudo systemctl restart redis
```

---

## 11. Backup Automation

### 11.1 Create Backup Script

Create a script to back up your site and files:

```bash
nano ~/erpnext-backup.sh
```

Contents:

```bash
#!/bin/bash

SITE="erpnext.local"
BACKUP_DIR="/home/$USER/backups"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$BACKUP_DIR/backup.log"

mkdir -p $BACKUP_DIR

echo "[$(date)] Starting backup..." >> $LOG_FILE

cd ~/frappe-bench

bench --site $SITE backup --with-files

mv sites/$SITE/private/backups/* $BACKUP_DIR/

# Remove backups older than 7 days
find $BACKUP_DIR -type f -mtime +7 -delete

echo "[$(date)] Backup completed." >> $LOG_FILE
```

Make it executable:

```bash
chmod +x ~/erpnext-backup.sh
```

### 11.2 Schedule with Cron

Add a cron job to run the backup daily at 2 AM:

```bash
crontab -e
```

Add:

```
0 2 * * * /home/your-user/erpnext-backup.sh
```

Replace `your-user` with your actual username.

---

## 12. Additional Security

### 12.1 Fail2Ban

Install and enable Fail2Ban to protect against brute-force attacks:

```bash
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

By default, it monitors SSH. You can add custom jails for your ERPNext login endpoint if needed.

---

## 13. Remote Access Options

For accessing your ERPNext instance from outside your local network, we recommend secure tunnel solutions instead of opening router ports.

### 13.1 Tailscale (Recommended for Admin Access)

Tailscale creates a private WireGuard VPN, offering end-to-end encryption with no port forwarding.

**Install Tailscale:**

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**Get your Tailscale IP:**

```bash
tailscale ip -4
```

Example: `100.64.12.34`

**Access ERPNext via Tailscale:**

Once Tailscale is running on both server and client devices, you can access:

```
https://100.64.12.34   (or https://erpnext.local if DNS resolution is set)
```

**Restrict NGINX to Tailscale subnet** (optional):

Add to your NGINX server block (inside the HTTPS server):

```nginx
allow 100.64.0.0/10;
deny all;
```

### 13.2 Cloudflare Tunnel (For Public Exposure)

If you need to share your ERPNext with external clients via a public URL, Cloudflare Tunnel is a secure alternative.

**Install `cloudflared`:**

```bash
sudo apt install cloudflared
```

**Login and create a tunnel:**

```bash
cloudflared tunnel login
cloudflared tunnel create erpnext
```

**Create configuration `~/.cloudflared/config.yml`:**

```yaml
tunnel: erpnext
credentials-file: /home/user/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: erp.yourdomain.com
    service: https://erpnext.local
  - service: http_status:404
```

**Run the tunnel:**

```bash
cloudflared tunnel run erpnext
```

Then access via `https://erp.yourdomain.com`.

---

## 14. Testing and Troubleshooting

### 14.1 Common Netplan Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Permissions for ... are too open` | File is world‑readable. | `sudo chmod 600 /etc/netplan/...` |
| `gateway4 has been deprecated` | Using old syntax. | Replace `gateway4` with `routes` as shown. |
| `changes device type` | Same interface defined in two files with different types (e.g., `wifis` vs `ethernets`). | Keep only **one** file that defines that interface. Edit the existing one. |
| `No access points defined` | Using `wifis:` without `access-points`. | Either add `access-points` or switch to `ethernets:` if using NetworkManager. |

### 14.2 Verify Services

**Check NGINX:**

```bash
sudo nginx -t
sudo systemctl status nginx
```

**Check Supervisor processes:**

```bash
sudo supervisorctl status
```

**Check listening ports:**

```bash
ss -tulnp | grep 8000
```

Expected: `0.0.0.0:8000` (Gunicorn) and `0.0.0.0:443` (NGINX).

**Test SSL with curl:**

```bash
curl -vI https://erpnext.local
```

Look for `SSL certificate verify ok` and a `200 OK` response.

**Test mDNS resolution** from a client:

```bash
ping erpnext.local
```

Should resolve to your server's IP.

---

## 15. Conclusion and Recommendations

You now have a secure, production-ready ERPNext instance accessible on your local network via HTTPS using a friendly `.local` name (thanks to Avahi). The setup includes:

- Static IP configuration
- Automatic name resolution via Avahi (mDNS) – no hosts file editing on modern clients
- Trusted SSL certificates
- NGINX as reverse proxy with HTTP→HTTPS redirect
- Firewall restricted to LAN
- Performance tuning for MariaDB and Redis
- Automated daily backups
- Optional secure remote access via Tailscale or Cloudflare Tunnel


---

*This guide consolidates best practices from system administration and network engineering to provide a robust local ERPNext deployment.*