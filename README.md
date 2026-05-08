# Windows SSH Setup Automation

Automated passwordless SSH configuration for a Windows machine via Cloudflare tunnel, with CMD set as the default shell.

---

## Quick Reference: Which Script to Use When

| Situation | Script | Copy-Paste Command |
|-----------|--------|-------------------|
| **First-time setup** — configure a fresh Windows machine with your SSH key, default shell, admin policies, and a secondary admin user | `setup_win_ssh.sh` | `./setup_win_ssh.sh` |
| **Daily SSH login** — connect to an already-configured machine | `ssh_remote.sh` | `./ssh_remote.sh` |
| **Manual reconfiguration** — run PowerShell directly on the Windows host (rarely needed) | `setup_remote.ps1` | `powershell -ExecutionPolicy Bypass -File setup_remote.ps1 "<your-pubkey>"` |

---

## Prerequisites

- `expect` installed on your local machine
- `cloudflared` installed on your local machine
- SSH access to the Windows machine (password known for first run)

---

## 1. First-Time Setup (`setup_win_ssh.sh`)

Run this **once per machine** to:
- Copy your public SSH key to the remote Windows host
- Set strict ACLs on `administrators_authorized_keys`
- Set CMD as the default OpenSSH shell
- Enable `LocalAccountTokenFilterPolicy` for full admin access over SSH
- Create a secondary admin user `j` / password `j`
- Hide user `m` from the Windows login screen
- Restart the SSH service

### Steps

1. Edit `setup_win_ssh.sh` to match your target:
   ```bash
   REMOTE_TARGET="j@j.mrme0.store"
   REMOTE_PASS="j"
   PUBKEY_PATH="$HOME/.ssh/id_ed25519.pub"
   ```

2. Run the setup:
   ```bash
   ./setup_win_ssh.sh
   ```

---

## 2. Daily Connection (`ssh_remote.sh`)

Run this **every time you want to SSH in** after setup is complete.

```bash
./ssh_remote.sh
```

Or connect directly without the helper:
```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname %h" j@j.mrme0.store
```

### Recommended: Add to `~/.ssh/config`

```text
Host j.mrme0.store
    ProxyCommand cloudflared access ssh --hostname %h
```

Then simply run:
```bash
ssh j@j.mrme0.store
```

---

## 3. Manual PowerShell Reconfiguration (`setup_remote.ps1`)

Only needed if you want to **run the remote configuration manually on the Windows host itself** (e.g., debugging or the expect script fails).

```powershell
powershell -ExecutionPolicy Bypass -File setup_remote.ps1 "ssh-ed25519 AAAAC3... your@email.com"
```

What it does:
- Writes the provided public key to `C:\ProgramData\ssh\administrators_authorized_keys`
- Locks down file ACLs to SYSTEM and Administrators only
- Sets CMD as the default OpenSSH shell
- Restarts the `sshd` service

---

## File Overview

| File | Purpose | When to Use |
|------|---------|-------------|
| `setup_win_ssh.sh` | Main entry point — local orchestration script | **First run only** |
| `automate_win_ssh.expect` | Expect script that automates the initial password-based SSH login and runs remote commands | Called automatically by `setup_win_ssh.sh` |
| `setup_remote.ps1` | PowerShell script that performs the actual Windows-side configuration | Manual reconfiguration on the Windows host |
| `ssh_remote.sh` | Convenience wrapper for daily SSH connections | **Every day after setup** |

---

## Troubleshooting

- **"Public key not found"** — The setup script will auto-generate an Ed25519 keypair if missing.
- **Permission denied** — Ensure the Windows user has admin rights and the password in `setup_win_ssh.sh` is correct.
- **Cloudflare tunnel issues** — Verify `cloudflared` is installed and the tunnel is active on the Windows side.
