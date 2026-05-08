#!/bin/bash

# ==============================================================================
# Windows SSH Setup Automation - Comprehensive Script
# ==============================================================================
# This script:
# 1. Installs/verifies all local dependencies (expect, cloudflared, ssh)
# 2. Generates SSH key pair if missing
# 3. Configures Windows OpenSSH server via remote automation
# 4. Sets up CMD as default shell
# 5. Enables LAN accessibility with proper firewall rules
# 6. Tests the SSH connection
# ==============================================================================

set -e

# -------------------------- Configuration -----------------------------
REMOTE_HOST="${REMOTE_HOST:-j.mrme0.store}"
REMOTE_USER="${REMOTE_USER:-j}"
REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
REMOTE_PASS="${REMOTE_PASS:-j}"
PUBKEY_PATH="${PUBKEY_PATH:-$(dirname "$0")/id_ed25519.pub}"
KEY_PATH="${KEY_PATH:-${PUBKEY_PATH%.pub}}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# -------------------------- Dependency Installation -----------------------------

install_dependencies() {
    log_info "Checking and installing local dependencies..."
    
    local deps_ok=true
    
    # macOS: Use brew for dependencies
    if command -v brew &>/dev/null; then
        # Check for expect
        if ! command -v expect &>/dev/null; then
            log_info "Installing expect via Homebrew..."
            brew install expect || deps_ok=false
        else
            log_success "expect is installed"
        fi
        
        # Check for cloudflared
        if ! command -v cloudflared &>/dev/null; then
            log_info "Installing cloudflared via Homebrew..."
            brew install cloudflare/cloudflare/cloudflared || deps_ok=false
        else
            log_success "cloudflared is installed"
        fi
        
        # Check for ssh (should be available by default on macOS)
        if ! command -v ssh &>/dev/null; then
            log_error "ssh client not found. macOS should have it by default."
            deps_ok=false
        else
            log_success "ssh client is available"
        fi
        
    # Linux: Use apt/dnf/pacman
    elif command -v apt-get &>/dev/null; then
        log_info "Detected apt-based system (Debian/Ubuntu)..."
        sudo apt-get update
        sudo apt-get install -y expect cloudflared openssh-client || deps_ok=false
        
    elif command -v dnf &>/dev/null; then
        log_info "Detected dnf-based system (Fedora/RHEL)..."
        sudo dnf install -y expect cloudflared openssh-clients || deps_ok=false
        
    elif command -v pacman &>/dev/null; then
        log_info "Detected pacman-based system (Arch)..."
        sudo pacman -S --noconfirm expect cloudflared openssh || deps_ok=false
        
    else
        log_warn "Unknown package manager. Please manually install: expect, cloudflared, openssh-client"
    fi
    
    if [ "$deps_ok" = true ]; then
        log_success "All dependencies installed/verified"
    else
        log_error "Some dependencies failed to install. Please check manually."
        exit 1
    fi
}

# -------------------------- SSH Key Setup -----------------------------

setup_ssh_key() {
    log_info "Setting up SSH key pair..."
    
    # Generate key if public key doesn't exist
    if [ ! -f "$PUBKEY_PATH" ]; then
        log_info "Generating new Ed25519 SSH key pair..."
        ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "windows-ssh-setup@$(date +%Y-%m-%d)"
        log_success "SSH key pair generated at $KEY_PATH"
    else
        log_success "SSH public key found at $PUBKEY_PATH"
    fi
    
    # Verify key permissions
    chmod 600 "$KEY_PATH" 2>/dev/null || true
    chmod 644 "$PUBKEY_PATH" 2>/dev/null || true
}

# -------------------------- Expect Script Update -----------------------------

update_expect_script() {
    local expect_script="$SCRIPT_DIR/automate_win_ssh.expect"
    
    log_info "Updating expect script with comprehensive Windows configuration..."
    
    cat > "$expect_script" << 'EXPECT_EOF'
#!/usr/bin/expect -f
# ==============================================================================
# Windows SSH Automation Script
# Comprehensively configures Windows OpenSSH for LAN and Cloudflare access
# ==============================================================================

set timeout 120
set target [lindex $argv 0]
set password [lindex $argv 1]
set pubkey [lindex $argv 2]

if {$target == "" || $password == "" || $pubkey == ""} {
    puts "Usage: ./automate_win_ssh.expect [user@host] [password] \"[pubkey]\""
    exit 1
}

# Escape single quotes in pubkey for PowerShell
set escaped_pubkey [string map {' '\\''} $pubkey]

# Comprehensive PowerShell configuration script
# This does EVERYTHING needed for SSH access on Windows

set ps_cmd [subst {
powershell -ExecutionPolicy Bypass -NoProfile -Command "
# Ensure running as Administrator
`$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not `$isAdmin) { Write-Warning 'Not running as Administrator - some operations may fail' }

# ============================================
# STEP 1: Install/Verify OpenSSH Server
# ============================================
Write-Host 'Checking OpenSSH Server installation...' -ForegroundColor Cyan

# Check if OpenSSH is installed
`$sshdPath = Get-Command sshd -ErrorAction SilentlyContinue
if (-not `$sshdPath) {
    Write-Host 'Installing OpenSSH Server...' -ForegroundColor Yellow
    # Try Windows capability method first (Windows 10/11)
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
}

# Verify installation
`$sshdPath = Get-Command sshd -ErrorAction SilentlyContinue
if (`$sshdPath) {
    Write-Host 'OpenSSH Server is available' -ForegroundColor Green
} else {
    Write-Warning 'OpenSSH Server not found - manual installation may be required'
}

# ============================================
# STEP 2: Create SSH directory structure
# ============================================
Write-Host 'Setting up SSH directories...' -ForegroundColor Cyan

`$sshPath = 'C:\ProgramData\ssh'
`$pubKeyPath = Join-Path `$sshPath 'administrators_authorized_keys'

# Create directory if it doesn't exist
if (-not (Test-Path `$sshPath)) {
    New-Item -Path `$sshPath -ItemType Directory -Force | Out-Null
}

# ============================================
# STEP 3: Configure administrators_authorized_keys
# ============================================
Write-Host 'Configuring authorized keys...' -ForegroundColor Cyan

# Write public key to administrators_authorized_keys
`$keyLine = '$escaped_pubkey'
[System.IO.File]::WriteAllText(`$pubKeyPath, `$keyLine + \"`n\")

# Set strict ACLs - CRITICAL for SSH to work
`$acl = Get-Acl `$pubKeyPath
`$acl.SetAccessRuleProtection(`$true, `$false)  # Protect from inheritance, don't preserve existing
`$administrators = New-Object System.Security.Principal.NTAccount('Administrators')
`$system = New-Object System.Security.Principal.NTAccount('SYSTEM')
`$fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
`$allow = [System.Security.AccessControl.AccessControlType]::Allow
`$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(`$administrators, `$fullControl, `$allow)))
`$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(`$system, `$fullControl, `$allow)))
Set-Acl `$pubKeyPath `$acl
Write-Host 'ACLs set correctly on administrators_authorized_keys' -ForegroundColor Green

# ============================================
# STEP 4: Set CMD as default shell
# ============================================
Write-Host 'Setting CMD as default shell...' -ForegroundColor Cyan

`$openSshPath = 'HKLM:\SOFTWARE\OpenSSH'
if (-not (Test-Path `$openSshPath)) {
    New-Item -Path `$openSshPath -Force | Out-Null
}
New-ItemProperty -Path `$openSshPath -Name 'DefaultShell' -Value 'C:\Windows\System32\cmd.exe' -PropertyType String -Force | Out-Null
Write-Host 'Default shell set to CMD' -ForegroundColor Green

# ============================================
# STEP 5: Enable LocalAccountTokenFilterPolicy
# ============================================
Write-Host 'Configuring LocalAccountTokenFilterPolicy...' -ForegroundColor Cyan

`$policyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
New-ItemProperty -Path `$policyPath -Name 'LocalAccountTokenFilterPolicy' -Value 1 -PropertyType DWord -Force | Out-Null
Write-Host 'LocalAccountTokenFilterPolicy enabled for full admin access' -ForegroundColor Green

# ============================================
# STEP 6: Configure Windows Firewall
# ============================================
Write-Host 'Configuring Windows Firewall...' -ForegroundColor Cyan

# Check if SSH firewall rule exists, if not create it
`$sshRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue
if (-not `$sshRule) {
    New-NetFirewallRule -Name 'sshd' -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Write-Host 'Created firewall rule for SSH (port 22)' -ForegroundColor Green
} else {
    Write-Host 'Firewall rule already exists' -ForegroundColor Green
}

# Allow LAN access explicitly
New-NetFirewallRule -Name 'sshd-LAN' -DisplayName 'OpenSSH Server LAN' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Profile Private,Domain | Out-Null

# ============================================
# STEP 7: Ensure sshd service is configured and running
# ============================================
Write-Host 'Configuring sshd service...' -ForegroundColor Cyan

# Set service to start automatically
Set-Service -Name sshd -StartupType 'Automatic' -ErrorAction SilentlyContinue
Start-Service sshd -ErrorAction SilentlyContinue

# First time setup: generate host keys if missing
`$hostkeysPath = Join-Path `$env:ProgramData 'ssh\ssh_host_*_key'
`$hostKeyFiles = Get-ChildItem 'C:\ProgramData\ssh\ssh_host_*_key' -ErrorAction SilentlyContinue
if (`$hostKeyFiles.Count -eq 0) {
    Write-Host 'Generating SSH host keys...' -ForegroundColor Yellow
    & 'C:\Windows\System32\OpenSSH\ssh-keygen.exe' -A 2>&1 | Out-Null
}

# ============================================
# STEP 8: Create user-specific authorized_keys (redundancy)
# ============================================
Write-Host 'Creating user-specific authorized_keys...' -ForegroundColor Cyan

`$userSshPath = 'C:\Users\$env:USERNAME\.ssh'
if (-not (Test-Path `$userSshPath)) {
    New-Item -Path `$userSshPath -ItemType Directory -Force | Out-Null
}
$userAuthKeys = Join-Path `$userSshPath 'authorized_keys'
if (-not (Test-Path `$userAuthKeys)) {
    [System.IO.File]::WriteAllText(`$userAuthKeys, `$keyLine + \"`n\")
    Write-Host 'Created user authorized_keys' -ForegroundColor Green
}

# ============================================
# STEP 9: Verify configuration
# ============================================
Write-Host 'Verifying configuration...' -ForegroundColor Cyan

`$verifyResults = @()
`$verifyResults += \"OpenSSH path: `$(Get-Command sshd -ErrorAction SilentlyContinue)`\"
`$verifyResults += \"SSH port 22 listening: `$(Test-NetConnection -ComputerName localhost -Port 22 -WarningAction SilentlyContinue).TcpTestSucceeded\"\"
`$verifyResults += \"sshd service running: `$(Get-Service sshd -ErrorAction SilentlyContinue).Status\"
Write-Host (`$verifyResults -join \"`n\") -ForegroundColor Cyan

# ============================================
# STEP 10: Final restart of sshd
# ============================================
Write-Host 'Restarting sshd service...' -ForegroundColor Cyan
Restart-Service sshd -Force -ErrorAction SilentlyContinue
Write-Host 'SSHD service restarted' -ForegroundColor Green

Write-Host ''
Write-Host '========================================' -ForegroundColor Green
Write-Host 'Windows SSH Configuration Complete!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host 'The machine is now accessible via:' -ForegroundColor Cyan
Write-Host '  - Cloudflare tunnel: ssh j@j.mrme0.store' -ForegroundColor White
Write-Host '  - LAN (direct IP): ssh j@<windows-ip>' -ForegroundColor White
Write-Host '========================================' -ForegroundColor Green
"
}

# Main connection logic
puts "Configuring $target via SSH..."

# Use cloudflared as ProxyCommand for SSH if it's a j.mrme0.store host
if {[string match "*j.mrme0.store" $target]} {
    log_info "Using Cloudflare tunnel for connection..."
    spawn ssh -o StrictHostKeyChecking=no -o ProxyCommand="cloudflared access ssh --hostname %h" $target $ps_cmd
} else {
    spawn ssh -o StrictHostKeyChecking=no $target $ps_cmd
}

expect {
    "*assword:*" {
        send "$password\r"
        exp_continue
    }
    "*yes/no*" {
        send "yes\r"
        exp_continue
    }
    eof
}

puts "\nSetup complete!"
EXPECT_EOF

    chmod +x "$expect_script"
    log_success "Expect script updated at $expect_script"
}

# -------------------------- PowerShell Script Update -----------------------------

update_powershell_script() {
    local ps_script="$SCRIPT_DIR/setup_remote.ps1"
    
    log_info "Updating PowerShell script..."
    
    cat > "$ps_script" << 'PS_EOF'
# ==============================================================================
# Windows SSH Configuration PowerShell Script
# Run this manually on the Windows host if automation fails
# ============================================================================== comb
# Usage: powershell -ExecutionPolicy Bypass -File setup_remote.ps1 "<pubkey>"
# ==============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$PubKey
)

# Ensure running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Recommended to run as Administrator for full functionality"
}

Write-Host "Starting Windows SSH Configuration..." -ForegroundColor Cyan

# STEP 1: Install OpenSSH Server if not present
Write-Host "Checking OpenSSH Server..." -ForegroundColor Cyan
$sshd = Get-Command sshd -ErrorAction SilentlyContinue
if (-not $sshd) {
    Write-Host "Installing OpenSSH Server..." -ForegroundColor Yellow
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Start-Sleep -Seconds 5
    } catch {
        Write-Warning "Could not install via Add-WindowsCapability. Manual installation may be required."
    }
}

# STEP 2: Setup administrators_authorized_keys
$sshPath = 'C:\ProgramData\ssh'
$pubKeyPath = Join-Path $sshPath 'administrators_authorized_keys'

if (-not (Test-Path $sshPath)) {
    New-Item -Path $sshPath -ItemType Directory -Force | Out-Null
}

[System.IO.File]::WriteAllText($pubKeyPath, $PubKey + "`n")

# STEP 3: Set correct ACLs (CRITICAL)
$acl = Get-Acl $pubKeyPath
$acl.SetAccessRuleProtection($true, $false)
$administrators = New-Object System.Security.Principal.NTAccount('Administrators')
$system = New-Object System.Security.Principal.NTAccount('SYSTEM')
$fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
$allow = [System.Security.AccessControl.AccessControlType]::Allow
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($administrators, $fullControl, $allow)))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($system, $fullControl, $allow)))
Set-Acl $pubKeyPath $acl

# STEP 4: Set CMD as default shell
$openSshPath = 'HKLM:\SOFTWARE\OpenSSH'
if (-not (Test-Path $openSshPath)) { New-Item -Path $openSshPath -Force | Out-Null }
New-ItemProperty -Path $openSshPath -Name 'DefaultShell' -Value 'C:\Windows\System32\cmd.exe' -PropertyType String -Force | Out-Null

# STEP 5: Enable LocalAccountTokenFilterPolicy
$policyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
New-ItemProperty -Path $policyPath -Name 'LocalAccountTokenFilterPolicy' -Value 1 -PropertyType DWord -Force | Out-Null

# STEP 6: Firewall rules
$sshRule = Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue
if (-not $sshRule) {
    New-NetFirewallRule -Name 'sshd' -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}
New-NetFirewallRule -Name 'sshd-LAN' -DisplayName 'OpenSSH Server LAN' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Profile Private,Domain | Out-Null

# STEP 7: Configure and start sshd service
Set-Service -Name sshd -StartupType 'Automatic' -ErrorAction SilentlyContinue
Start-Service sshd -ErrorAction SilentlyContinue
Restart-Service sshd -Force -ErrorAction SilentlyContinue

# STEP 8: Generate host keys if needed
$hostKeyFiles = Get-ChildItem 'C:\ProgramData\ssh\ssh_host_*_key' -ErrorAction SilentlyContinue
if ($hostKeyFiles.Count -eq 0) {
    & 'C:\Windows\System32\OpenSSH\ssh-keygen.exe' -A 2>&1 | Out-Null
}

Write-Host "Configuration complete!" -ForegroundColor Green
PS_EOF

    log_success "PowerShell script updated at $ps_script"
}

# -------------------------- Run Automation -----------------------------

run_automation() {
    local expect_script="$SCRIPT_DIR/automate_win_ssh.expect"
    
    log_info "Reading public key content..."
    local pubkey_content
    pubkey_content=$(cat "$PUBKEY_PATH" | tr -d '\n' | tr -s ' ')
    
    log_info "Running SSH automation script..."
    log_info "Target: $REMOTE_TARGET"
    
    # Make expect script executable
    chmod +x "$expect_script"
    
    # Run the automation
    "$expect_script" "$REMOTE_TARGET" "$REMOTE_PASS" "$pubkey_content"
}

# -------------------------- Test Connection -----------------------------

test_connection() {
    log_info "Testing SSH connection..."
    
    # Try to connect and run a simple command
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no \
            -o ProxyCommand="cloudflared access ssh --hostname %h" \
            "$REMOTE_TARGET" "echo 'SSH connection successful'" 2>/dev/null; then
        log_success "SSH connection test passed!"
    else
        log_warn "SSH connection test failed. The machine may need a manual check."
    fi
}

# -------------------------- Main Execution -----------------------------

main() {
    echo ""
    echo "========================================"
    echo " Windows SSH Setup Automation"
    echo "========================================"
    echo ""
    
    # Step 1: Install dependencies
    install_dependencies
    
    # Step 2: Setup SSH key
    setup_ssh_key
    
    # Step 3: Update expect script
    update_expect_script
    
    # Step 4: Update PowerShell script
    update_powershell_script
    
    # Step 5: Run automation
    run_automation
    
    # Step 6: Test connection (optional, may fail if not ready)
    sleep 2
    test_connection
    
    echo ""
    echo "========================================"
    log_success "Setup script completed!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "  - Daily SSH: ./ssh_remote.sh"
    echo "  - Or directly: ssh $REMOTE_TARGET"
    echo ""
}

# Run main
main "$@"
