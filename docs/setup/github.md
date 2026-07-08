# GitHub SSH Setup Guide for DigitalOcean Droplet
**Environment:** Ubuntu 24.04 LTS + DigitalOcean Droplet + GitHub + Frappe/ERPNext

> **Objective**
>
> Securely configure SSH authentication between your DigitalOcean droplet and GitHub so that you can clone, pull, and push private repositories without entering your GitHub username/password.

---

# Table of Contents

1. Why use a separate SSH key?
2. Architecture
3. Generate SSH Key
4. Verify Generated Keys
5. Configure SSH Agent
6. Add Public Key to GitHub
7. Configure SSH Client
8. Test GitHub Authentication
9. Clone Private Repository
10. Existing Repository Migration
11. Using Multiple GitHub Accounts
12. SSH Configuration Explained
13. File Permissions
14. Common Mistakes
15. Troubleshooting
16. Security Best Practices
17. Revoking a Compromised Key
18. Useful Commands
19. Final Production Checklist

---

# 1. Why use a Separate SSH Key?

Although you **can** copy your laptop's SSH key to the DigitalOcean server, it is **not recommended**.

### ❌ Bad Practice

```
Laptop
    │
    ├── id_ed25519
    │
Copy Same Key
    │
DigitalOcean
    │
    └── id_ed25519
```

If either machine is compromised, the attacker gains access to GitHub from both systems.

---

### ✅ Recommended

Each machine should have its own SSH key.

```
Laptop
    │
    └── github_ed25519

Desktop
    │
    └── github_ed25519

DigitalOcean
    │
    └── github_ed25519

GitHub
    │
    ├── Laptop Key
    ├── Desktop Key
    └── DigitalOcean Key
```

Benefits

- Independent revocation
- Better auditing
- Better security
- Industry standard

---

# 2. Architecture

```
                   GitHub

         +-----------------------+
         |  SSH Public Keys      |
         |-----------------------|
         | Laptop                |
         | Desktop               |
         | DigitalOcean          |
         +-----------------------+

                 ▲

                 │ SSH

                 │

      +----------------------+
      | DigitalOcean Droplet |
      +----------------------+

      ~/.ssh/

      github_ed25519
      github_ed25519.pub
      config
```

---

# 3. Generate SSH Key

Connect to the droplet.

Run

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

Generate a new ED25519 key.

```bash
ssh-keygen -t ed25519 -C "github" -f ~/.ssh/github_ed25519
```

Explanation

| Option | Description |
|---------|-------------|
| -t ed25519 | Recommended algorithm |
| -C | Comment |
| -f | File name |

---

When asked

```
Enter passphrase:
```

Production recommendation

Choose a passphrase.

If the server performs unattended deployment, you may leave it blank.

---

Generated files

```
~/.ssh/

github_ed25519
github_ed25519.pub
```

---

# 4. Verify Generated Keys

Private key

```
~/.ssh/github_ed25519
```

Public key

```
~/.ssh/github_ed25519.pub
```

Display the public key

```bash
cat ~/.ssh/github_ed25519.pub
```

Example output

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBY.... github
```

Notice it begins with

```
ssh-ed25519
```

This is exactly what GitHub expects.

---

Never display or upload

```bash
cat ~/.ssh/github_ed25519
```

It starts with

```
-----BEGIN OPENSSH PRIVATE KEY-----
```

Never upload this file.

---

# 5. Configure SSH Agent

Start agent

```bash
eval "$(ssh-agent -s)"
```

Add key

```bash
ssh-add ~/.ssh/github_ed25519
```

Verify

```bash
ssh-add -l
```

Expected

```
256 SHA256:....
```

---

# 6. Add Public Key to GitHub

Display the public key

```bash
cat ~/.ssh/github_ed25519.pub
```

Copy the **entire line**.

Open GitHub

```
Settings

↓

SSH and GPG Keys

↓

New SSH Key
```

Fill

Title

```
DigitalOcean - Avian Production
```

Key Type

```
Authentication Key
```

Key

Paste the output of

```bash
cat ~/.ssh/github_ed25519.pub
```

Click

```
Add SSH Key
```

---

# 7. Configure SSH Client

Create configuration

```bash
nano ~/.ssh/config
```

Add

```text
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_ed25519
    IdentitiesOnly yes
```

Save.

Permissions

```bash
chmod 600 ~/.ssh/config
```

---

# 8. Test Authentication

Run

```bash
ssh -T git@github.com
```

First connection

```
The authenticity of host 'github.com' can't be established.
```

Type

```
yes
```

Expected

```
Hi <username>!

You've successfully authenticated...
```

---

# 9. Clone Private Repository

Example

```bash
git clone git@github.com:username/private-repo.git
```

Example

```bash
git clone git@github.com:sanjay-kumar001/avian.git
```

---

# 10. Existing Repository

If already cloned using HTTPS

Check remote

```bash
git remote -v
```

Example

```
https://github.com/user/project.git
```

Change to SSH

```bash
git remote set-url origin git@github.com:user/project.git
```

Verify

```bash
git remote -v
```

Should become

```
git@github.com:user/project.git
```

---

# 11. Multiple GitHub Accounts

Example

```
~/.ssh/

github_personal
github_work
github_client
```

SSH config

```text
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_personal

Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_work
```

Clone

```
git@github-work:company/project.git
```

---

# 12. SSH Configuration Explained

```
Host github.com
```

Alias.

---

```
HostName github.com
```

Real server.

---

```
User git
```

GitHub always uses

```
git
```

Never your GitHub username.

---

```
IdentityFile
```

Private key.

---

```
IdentitiesOnly yes
```

Forces SSH to use only this key.

Recommended.

---

# 13. File Permissions

```
chmod 700 ~/.ssh
```

```
chmod 600 ~/.ssh/github_ed25519
```

```
chmod 644 ~/.ssh/github_ed25519.pub
```

```
chmod 600 ~/.ssh/config
```

Verify

```bash
ls -la ~/.ssh
```

Example

```
drwx------ .ssh
-rw------- github_ed25519
-rw-r--r-- github_ed25519.pub
-rw------- config
```

---

# 14. Common Mistakes

## Uploading the private key

Wrong

```
-----BEGIN OPENSSH PRIVATE KEY-----
```

Correct

```
ssh-ed25519 AAAA....
```

---

## Forgetting to add SSH key

```
ssh-add ~/.ssh/github_ed25519
```

---

## Wrong permissions

```
chmod 600
```

---

## Wrong remote URL

Wrong

```
https://github.com/...
```

Correct

```
git@github.com:...
```

---

## Wrong username

Always

```
git
```

Never

```
sanjay
```

---

# 15. Troubleshooting

## Permission denied

```
Permission denied (publickey)
```

Check

```bash
ssh-add -l
```

---

Check

```bash
cat ~/.ssh/config
```

---

Verbose debugging

```bash
ssh -vT git@github.com
```

Very verbose

```bash
ssh -vvvT git@github.com
```

---

Check remote

```bash
git remote -v
```

---

# 16. Security Best Practices

✔ One key per machine

✔ Never share private keys

✔ Backup private key securely

✔ Use ED25519

✔ Use descriptive filenames

✔ Revoke unused keys

✔ Use SSH instead of HTTPS

✔ Restrict permissions

✔ Regularly audit GitHub SSH keys

---

# 17. Revoking a Compromised Key

GitHub

```
Settings

↓

SSH and GPG Keys

↓

Delete
```

Delete only the compromised key.

Laptop continues working.

---

# 18. Useful Commands

Generate

```bash
ssh-keygen -t ed25519 -C "github" -f ~/.ssh/github_ed25519
```

View public key

```bash
cat ~/.ssh/github_ed25519.pub
```

Start agent

```bash
eval "$(ssh-agent -s)"
```

Add key

```bash
ssh-add ~/.ssh/github_ed25519
```

List keys

```bash
ssh-add -l
```

Test GitHub

```bash
ssh -T git@github.com
```

Verbose test

```bash
ssh -vvvT git@github.com
```

Clone

```bash
git clone git@github.com:username/repository.git
```

Current remote

```bash
git remote -v
```

Switch HTTPS to SSH

```bash
git remote set-url origin git@github.com:user/repository.git
```

---

# 19. Final Production Checklist

- Ubuntu updated
- `.ssh` directory exists
- ED25519 key generated
- Public key uploaded to GitHub
- Private key remains only on the droplet
- SSH agent running
- SSH config created
- Correct permissions applied
- `ssh -T git@github.com` succeeds
- Repository uses SSH remote URL
- Clone, pull, and push operations verified

---

# Summary

For a production DigitalOcean server hosting your Frappe/ERPNext applications:

- Generate a **new ED25519 SSH key** on the droplet.
- Use a descriptive filename such as `~/.ssh/github_ed25519`.
- Upload **only** the contents of `github_ed25519.pub` to GitHub as an **Authentication Key**.
- Configure `~/.ssh/config` to use this key for `github.com`.
- Verify with `ssh -T git@github.com`.
- Use SSH URLs (`git@github.com:owner/repo.git`) for cloning and repository remotes.
- Keep the droplet's SSH key separate from your laptop's key so access can be revoked independently if the server is ever compromised.