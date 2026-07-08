Here is the complete, compiled guide for building your local Certificate Authority, configuring Nginx with Frappe, and establishing trusted HTTPS across your local network using Avahi (mDNS) and `.local` domains.

---

# Complete Setup: Local PKI, Nginx, and HTTPS for Frappe Bench

This architecture uses a centralized Local Root CA on your Ubuntu server. Your `.local` domains rely on Avahi for local network discovery, eliminating the need for a dedicated DNS server like Pi-hole.

## Phase 1: Initialize the Local Root CA

You will act as your own Certificate Authority. The Root CA will be valid for 10 years and will be used to sign all your local development certificates.

**1. Create the secure directory:**

```bash
sudo mkdir -p /etc/ssl/ca
cd /etc/ssl/ca

```

**2. Generate the Root CA Private Key:**
Keep this file secure. Anyone with this key can issue trusted certificates for your network.

```bash
sudo openssl genrsa -out ca.key 4096

```

**3. Generate the Root CA Certificate (Valid for 3650 days):**

```bash
sudo openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/C=IN/ST=Madhya Pradesh/L=Jabalpur/O=Avian Network/CN=Avian Root CA"

```

---

## Phase 2: Issue Server Certificates with SANs

Modern browsers require Subject Alternative Names (SANs). We will create a configuration file specifically for your `.local` domains.

**1. Create the SAN configuration file:**

```bash
sudo nano san.cnf

```

**2. Add the following configuration:**

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
CN = avian.local

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = avian.local
DNS.2 = develop.local
DNS.3 = test.local
DNS.4 = web.local

```

**3. Generate the Server Key, CSR, and Certificate:**
*Note: The server certificate is valid for 398 days to comply with Apple's strict maximum validity requirements for iOS/macOS.*

```bash
# Generate the private key
sudo openssl genrsa -out avian.key 2048

# Create the Certificate Signing Request (CSR)
sudo openssl req -new -key avian.key -out avian.csr -config san.cnf

# Sign the certificate using your Root CA
sudo openssl x509 -req -in avian.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out avian.crt -days 398 -sha256 -extfile san.cnf -extensions req_ext

```

---

## Phase 3: System-Level Host Routing

For your Ubuntu server to resolve the domains internally (so Nginx and Frappe can communicate), update the local hosts file.

**1. Edit the hosts file:**

```bash
sudo nano /etc/hosts

```

**2. Add your `.local` domains to the local loopback:**
Ensure this line exists near the top of the file:

```text
127.0.1.1 avian.local develop.local test.local web.local avian

```

---

## Phase 4: Configure Nginx for Frappe Bench

Nginx will handle SSL termination and proxy all traffic to your Frappe Bench running on port 8005.

**1. Create or edit your Nginx site configuration:**

```bash
sudo nano /etc/nginx/conf.d/frappe.conf

```

**2. Paste the production-ready configuration:**
*(This includes the correct `http2` syntax for modern Nginx versions).*

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name avian.local develop.local test.local web.local;
    return 301 https://$host$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name avian.local develop.local test.local web.local;

    # SSL Configuration
    ssl_certificate /etc/ssl/ca/avian.crt;
    ssl_certificate_key /etc/ssl/ca/avian.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Proxy to Frappe Bench
    location / {
        proxy_pass http://127.0.0.1:8005;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support for Frappe
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

```

**3. Test and reload Nginx:**

```bash
sudo nginx -t
sudo systemctl reload nginx

```

---

## Phase 5: Establish Trust (Install the Root CA)

To stop browsers from throwing `NET::ERR_CERT_AUTHORITY_INVALID` errors, you must install **only the `ca.crt` file** on every device connecting to the server. Never transfer the `ca.key`.

### Ubuntu (Chrome/Edge/Brave Manual Import)

1. Open your browser and navigate to `chrome://certificate-manager/localcerts/usercerts` (or the equivalent settings page for Certificates).
2. Under the **Trusted Certificates** section, click **Import**.
3. Select your `ca.crt` file.
4. Check the box for **"Trust this certificate for identifying websites"** and confirm.
5. Restart the browser.

### Windows

1. Transfer `ca.crt` to your Windows machine.
2. Double-click `ca.crt` and click **Install Certificate**.
3. Select **Local Machine** > Next.
4. Choose **Place all certificates in the following store** > **Browse**.
5. Select **Trusted Root Certification Authorities** > OK > Next > Finish.
6. Restart your browser.

### Android

1. Transfer `ca.crt` to the phone's internal storage.
2. Go to **Settings > Security** (or Biometrics and Security).
3. Tap **Other Security Settings > Install from device storage** (or "Credential storage").
4. Select **CA certificate** and select the `ca.crt` file to install it.

### iPhone / iOS

1. Email or AirDrop `ca.crt` to your iPhone and open it.
2. Go to **Settings > Profile Downloaded** and tap **Install**.
3. Navigate to **Settings > General > About > Certificate Trust Settings** (at the very bottom).
4. Toggle the switch **ON** for "Avian Root CA" to enable full trust.

---

## Phase 6: Testing the Setup

**Test from the Host Server:**
Run this command to verify SSL termination and Frappe connectivity:

```bash
curl -vI https://avian.local

```

*Look for `SSL certificate verify ok` and a `200 OK` response.*

**Test from LAN Devices:**
Ensure your device is on the exact same Wi-Fi network as the server. Open a browser and navigate to `[https://avian.local](https://avian.local)`. Avahi will route the request, and the browser will show a secure lock icon.

---

## Phase 7: Certificate Renewal Procedure

Because Apple devices enforce a 398-day limit on server certificates, your `avian.crt` will eventually expire. You do **not** need to touch the clients, the Root CA, or Nginx configurations when this happens.

Simply regenerate the server certificate on your Ubuntu machine using the existing CSR:

```bash
cd /etc/ssl/ca
sudo openssl x509 -req -in avian.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out avian.crt -days 398 -sha256 -extfile san.cnf -extensions req_ext
sudo systemctl reload nginx

```