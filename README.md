# Windows SSH Setup Automation

Comprehensive automated setup for Windows SSH access via Cloudflare tunnel or LAN direct connection.

---

## Quick Reference

| Situation | Script | Usage |
|-----------|--------|-------|
| **First-time setup** from Mac/Linux | `setup_win_ssh.sh` | `./setup_win_ssh.sh` |
| **Windows with nothing installed** | `setup_remote.ps1` | Run locally on Windows |
| **Daily SSH login (Cloudflare)** | `ssh_remote.sh` | `./ssh_remote.sh` |
| **Direct LAN SSH** | `ssh_remote.sh` | `./ssh_remote.sh --lan -i 192.168.1.x` |

---

## Prerequisites

The `setup_win_ssh.sh` script auto-installs dependencies. For `setup_remote.ps1`, run as Administrator on Windows.

---

## Option 1: Setup from Mac/Linux (`setup_win_ssh.sh`)

Run this **once** to configure a Windows machine remotely:

```bash
./setup_win_ssh.sh
```

What it does:
- ✓ Auto-installs `expect`, `cloudflared`, `ssh` on your local machine
- ✓ Generates SSH key pair if missing
- ✓ Connects via Cloudflare tunnel to Windows
- ✓ Installs/configures OpenSSH Server on Windows
- ✓ Sets up `administrators_authorized_keys` with correct ACLs
- ✓ Sets CMD as default shell
- ✓ Enables `LocalAccountTokenFilterPolicy` for full admin access
- ✓ Configures firewall rules for port 22 (LAN + Cloudflare)
- ✓ Restarts sshd service

---

## Option 2: Run Directly on Windows (`setup_remote.ps1`)

**Use this when:**
- Windows has no SSH server installed
- You're physically at the Windows machine
- The automated setup failed

### Usage

1. **Open PowerShell as Administrator** (right-click → "Run as Administrator")

2. **Get your public SSH key** from your Mac/Linux:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   # or
   cat /Volumes/ExMac/code/winsshsetup/id_ed25519.pub
   ```

3. **Run the script** on Windows:
   ```powershell
   # Copy your public key, then run:
   powershell -ExecutionPolicy Bypass -File setup_remote.ps1 "ssh-ed25519 AAAA... user@hostname"
   ```

### What `setup_remote.ps1` Does

| Step | Action | Why |
|------|--------|-----|
| 1 | Install OpenSSH Server | Windows built-in SSH server |
| 2 | Create `C:\ProgramData\ssh` | SSH config directory |
| 3 | Write `administrators_authorized_keys` | Admin SSH access |
| 4 | Set ACLs (Admins + SYSTEM only) | **Critical** - SSH won't work without this |
| 5 | Set CMD as default shell | Better than PowerShell for admin tasks |
| 6 | Enable `LocalAccountTokenFilterPolicy` | Full admin tokens over network |
| 7 | Create firewall rule for port 22 | Allow SSH connections |
| 8 | Generate host keys | First-time SSH setup |
| 9 | Start sshd service | Enable SSH daemon |
| 10 | Verify configuration | Confirm everything works |

---

## Option 3: Daily Connection (`ssh_remote.sh`)

### Cloudflare Tunnel (remote access)
```bash
./ssh_remote.sh
```

### Direct LAN Access (faster, local network)
```bash
./ssh_remote.sh --lan -i 192.168.1.100
```

---

## SSH Config (Recommended)

Add to `~/.ssh/config`:

```text
# Cloudflare tunnel access
Host j.mrme0.store
    User m
    ProxyCommand cloudflared access ssh --hostname %h

# Direct LAN access (replace with Windows IP)
Host 192.168.1.100
    User m
```

Then simply: `ssh j.mrme0.store` or `ssh 192.168.1.100`

---

## File Overview

| File | Purpose |
|------|---------|
| `setup_win_ssh.sh` | Comprehensive remote setup from Mac/Linux |
| `setup_remote.ps1` | Standalone Windows PowerShell setup script |
| `ssh_remote.sh` | Daily SSH connection helper |
| `automate_win_ssh.expect` | Underlying automation (called by setup script) |

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| **"Permission denied"** | Verify password, ensure user is Administrator |
| **"OpenSSH not found"** | Windows Server? Use `dism` method or download from GitHub |
| **"ACLs error"** | SSH requires **only** Administrators + SYSTEM on `administrators_authorized_keys` |
| **"Connection refused"** | Check firewall: `Test-NetConnection localhost -Port 22` on Windows |
| **"Key not accepted"** | Verify `administrators_authorized_keys` ACLs - this is the #1 cause |

---

## Quick Windows IP Discovery

To find your Windows machine's LAN IP for direct access:
```powershell
ipconfig | findstr IPv4
```
Look for the IPv4 address on the local network adapter.
