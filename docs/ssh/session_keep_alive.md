# SSH Keepalive Configuration Guide
## Preventing "Broken pipe" Disconnections on a Cloud Server

**Environment**

- **Local Machine:** Ubuntu 24.04 LTS
- **Remote Server:** Cloud Server
- **Authentication:** SSH Key (Ed25519)
- **Purpose:** Keep SSH sessions alive during periods of inactivity.

---

# 1. Problem

While connected to the Cloud Server, the SSH session disconnects after a few minutes of inactivity.

Typical error:

```text
client_loop: send disconnect: Broken pipe
```

This generally occurs because an intermediate device (router, firewall, ISP, VPN, etc.) closes idle TCP connections before the SSH client sends any keepalive packets.

---

# 2. Understanding SSH Keepalive

Many users misunderstand these settings.

## ServerAliveInterval

This tells the SSH **client**:

> "Send a keepalive packet every X seconds."

Example:

```text
ServerAliveInterval 60
```

means

> Every 60 seconds send a small encrypted packet to the server.

---

## ServerAliveCountMax

This tells the SSH client:

> "If I don't receive a response for this many keepalive packets, disconnect."

Example:

```text
ServerAliveCountMax 30
```

means

```
1st minute -> no response
2nd minute -> no response
...
30th minute -> disconnect
```

Therefore

```
Maximum disconnect time

= Interval × CountMax

= 60 × 30

= 1800 seconds

= 30 minutes
```

---

## TCPKeepAlive

This enables operating-system-level TCP keepalive packets.

```text
TCPKeepAlive yes
```

Recommended:

```
Yes
```

---

# 3. Why the Current Configuration Doesn't Work

Current configuration:

```text
ServerAliveInterval 3600
ServerAliveCountMax 3
```

Timeline

```
0 min
|
|-------------------------------60 Minutes------------------------------|
                               First keepalive
```

If your router disconnects idle connections after

```
2 minutes
```

then

```
0 min ----2 min----X
                 Connection dropped
```

The SSH client never gets the opportunity to send the first keepalive packet.

---

# 4. Recommended Configuration

Open

```bash
nano ~/.ssh/config
```

Replace or modify your configuration.

```text
Host *
    IdentitiesOnly yes
    PreferredAuthentications publickey
    Compression yes

    # Send keepalive every minute
    ServerAliveInterval 60

    # Allow 30 missed replies
    ServerAliveCountMax 30

    TCPKeepAlive yes

    GSSAPIAuthentication no
    GSSAPIDelegateCredentials yes
```

---

# 5. What These Values Mean

| Setting | Value | Description |
|----------|------:|-------------|
| ServerAliveInterval | 60 | Send keepalive every minute |
| ServerAliveCountMax | 30 | Disconnect after 30 missed replies |
| TCPKeepAlive | yes | Enable TCP keepalive |

The client will tolerate approximately

```
60 × 30

= 1800 seconds

= 30 minutes
```

without receiving a reply.

---

# 6. Recommended Server Configuration

SSH into the Cloud Server.

Edit:

```bash
sudo nano /etc/ssh/sshd_config
```

Add or modify:

```text
ClientAliveInterval 60
ClientAliveCountMax 30
TCPKeepAlive yes
```

Restart SSH.

Ubuntu 24.04:

```bash
sudo systemctl restart ssh
```

Verify:

```bash
sudo systemctl status ssh
```

---

# 7. Verify Client Configuration

Run

```bash
ssh -G root@YOUR_DROPLET_IP | grep alive
```

Expected

```text
serveraliveinterval 60
serveralivecountmax 30
```

---

# 8. Verify Server Configuration

Run

```bash
sudo sshd -T | grep alive
```

Expected

```text
clientaliveinterval 60
clientalivecountmax 30
```

---

# 9. Testing

Connect to the server.

```bash
ssh root@YOUR_DROPLET_IP
```

Leave the terminal untouched for

```
30 minutes
```

The connection should remain active.

---

# 10. Debugging

If it still disconnects unexpectedly, use verbose logging.

```bash
ssh -vvv root@YOUR_DROPLET_IP
```

Observe the last lines before the disconnect.

---

# 11. Check SSH Logs on the Droplet

```bash
sudo journalctl -u ssh --since "30 minutes ago"
```

or

```bash
sudo journalctl -u ssh -f
```

Watch the logs while another client connects.

---

# 12. Common Causes of "Broken pipe"

| Cause | Description |
|--------|-------------|
| Home Router | Closes idle TCP sessions |
| Office Firewall | Enforces idle timeout |
| VPN | Drops inactive tunnels |
| Mobile Hotspot | Aggressive idle timeout |
| ISP NAT | Removes idle mappings |
| SSH Client | Keepalive interval too long |
| SSH Server | Idle timeout configured |
| Wi-Fi Sleep | Network interface sleeps |

---

# 13. Best Practices

- Use SSH key authentication.
- Keep `TCPKeepAlive yes`.
- Set `ServerAliveInterval` to **60 seconds** (or 30 seconds on unstable networks).
- Avoid very large intervals such as **3600 seconds**.
- Keep OpenSSH up to date.
- Monitor SSH logs when troubleshooting.

---

# 14. Recommended Configuration (Production)

### Client (`~/.ssh/config`)

```text
Host *
    IdentitiesOnly yes
    PreferredAuthentications publickey
    Compression yes

    ServerAliveInterval 60
    ServerAliveCountMax 30

    TCPKeepAlive yes

    GSSAPIAuthentication no
    GSSAPIDelegateCredentials yes
```

### Server (`/etc/ssh/sshd_config`)

```text
ClientAliveInterval 60
ClientAliveCountMax 30
TCPKeepAlive yes
```

Restart SSH after making server-side changes:

```bash
sudo systemctl restart ssh
```

---

# 15. Troubleshooting Checklist

- [ ] SSH client configuration updated.
- [ ] SSH server configuration updated.
- [ ] SSH service restarted.
- [ ] Client configuration verified with `ssh -G`.
- [ ] Server configuration verified with `sshd -T`.
- [ ] Verbose SSH logging checked (`ssh -vvv`).
- [ ] SSH server logs reviewed (`journalctl -u ssh`).
- [ ] Router/VPN/firewall idle timeout considered if disconnects persist.

---

# 16. Summary

For most users, the following configuration provides a reliable balance between responsiveness and stability:

**Client (`~/.ssh/config`):**

```text
ServerAliveInterval 60
ServerAliveCountMax 30
TCPKeepAlive yes
```

**Server (`/etc/ssh/sshd_config`):**

```text
ClientAliveInterval 60
ClientAliveCountMax 30
TCPKeepAlive yes
```

With these settings, the SSH client sends a keepalive every minute, helping prevent idle disconnections caused by intermediate network devices. If the network becomes unreachable, the client will wait for approximately **30 minutes** before giving up.