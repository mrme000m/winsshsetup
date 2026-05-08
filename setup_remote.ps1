# PowerShell script for remote Windows SSH configuration
# This script should be run on the remote machine as an administrator

$pubkey = $args[0]
if (-not $pubkey) {
    Write-Error "Public key must be provided as the first argument."
    exit 1
}

$path = 'C:\ProgramData\ssh\administrators_authorized_keys'
[System.IO.File]::WriteAllText($path, $pubkey + "`n")

# Set the correct ACLs
$acl = Get-Acl $path
$acl.SetAccessRuleProtection($true, $false)
$administrators = New-Object System.Security.Principal.NTAccount('Administrators')
$system = New-Object System.Security.Principal.NTAccount('SYSTEM')
$fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
$allow = [System.Security.AccessControl.AccessControlType]::Allow
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($administrators, $fullControl, $allow)))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($system, $fullControl, $allow)))
Set-Acl $path $acl

# Set default shell to cmd
if (!(Test-Path 'HKLM:\SOFTWARE\OpenSSH')) { New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force }
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' -Value 'C:\Windows\System32\cmd.exe' -PropertyType String -Force

# Restart SSH service
Restart-Service sshd
