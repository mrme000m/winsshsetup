# Windows SSH Server - Complete Installation & Configuration Script
# Run as Administrator: powershell -ExecutionPolicy Bypass -File setup_remote.ps1 "ssh-ed25519 AAAA..."

param([Parameter(Mandatory=$true)][string]$PubKey)

# Verify Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Warning "Run as Administrator for best results" }

Write-Host "Windows SSH Server Setup" -ForegroundColor Cyan

# STEP 1: Install OpenSSH Server
Write-Host "[1] Installing OpenSSH Server..." -ForegroundColor Yellow
$sshd = Get-Command sshd -ErrorAction SilentlyContinue
if (-not $sshd) {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) { dism /Online /Enable-Feature /FeatureName:OpenSSH.Server /All /NoRestart }
}
$sshd = Get-Command sshd -ErrorAction SilentlyContinue
if (-not $sshd) { Write-Warning "Install failed"; exit 1 }
Write-Host "    OpenSSH installed" -ForegroundColor Green

# STEP 2: Create directories
Write-Host "[2] Creating SSH directories..." -ForegroundColor Yellow
$sshPath = "C:\ProgramData\ssh"; $null = New-Item -Path $sshPath -ItemType Directory -Force

# STEP 3: Write public key
Write-Host "[3] Writing authorized_keys..." -ForegroundColor Yellow
[System.IO.File]::WriteAllText("$sshPath\administrators_authorized_keys", $PubKey + "`n")

# STEP 4: Set ACLs (CRITICAL)
Write-Host "[4] Setting ACLs..." -ForegroundColor Yellow
$acl = Get-Acl "$sshPath\administrators_authorized_keys"
$acl.SetAccessRuleProtection($true, $false)
$admin = New-Object System.Security.Principal.NTAccount("Administrators")
$sys = New-Object System.Security.Principal.NTAccount("SYSTEM")
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($admin, "FullControl", "Allow")))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sys, "FullControl", "Allow")))
Set-Acl "$sshPath\administrators_authorized_keys" $acl

# STEP 5: Default shell = CMD
Write-Host "[5] Setting CMD as default shell..." -ForegroundColor Yellow
$null = New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" -Value "C:\Windows\System32\cmd.exe" -PropertyType String -Force | Out-Null

# STEP 6: Enable LocalAccountTokenFilterPolicy
Write-Host "[6] Enabling full admin tokens..." -ForegroundColor Yellow
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1 -PropertyType DWord -Force | Out-Null

# STEP 7: Firewall
Write-Host "[7] Configuring firewall..." -ForegroundColor Yellow
New-NetFirewallRule -Name "sshd" -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null

# STEP 8: Generate host keys if missing
Write-Host "[8] Generating host keys..." -ForegroundColor Yellow
if ((Get-ChildItem "C:\ProgramData\ssh\ssh_host_*_key" -ErrorAction SilentlyContinue).Count -eq 0) {
    & (Join-Path (Split-Path $sshd.Source) "ssh-keygen.exe") -A
}

# STEP 9: Start sshd service
Write-Host "[9] Starting sshd service..." -ForegroundColor Yellow
Set-Service -Name sshd -StartupType "Automatic"
Start-Service sshd -ErrorAction SilentlyContinue
Restart-Service sshd -Force -ErrorAction SilentlyContinue

# STEP 10: Verify
Write-Host "[10] Verification:" -ForegroundColor Yellow
Write-Host "  OpenSSH: $($sshd.Source)"
Write-Host "  Port 22: $((Test-NetConnection localhost -Port 22 -WarningAction SilentlyContinue).TcpTestSucceeded)"
Write-Host "  Service: $((Get-Service sshd).Status)"
Write-Host "Done! Machine accessible via SSH." -ForegroundColor Green

