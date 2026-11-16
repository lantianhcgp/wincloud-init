Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null
$k='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKlO+f0asEjIz8FvN2bR1ddXODZu4zsrdouOdoyZ8l+a hermes-wincloud'
$f='C:\ProgramData\ssh\administrators_authorized_keys'
if (!(Select-String -Path $f -Pattern 'hermes-wincloud' -Quiet -ErrorAction SilentlyContinue)) { Add-Content -Path $f -Value $k }
icacls $f /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F' | Out-Null
Restart-Service sshd
"SSHD_STATUS=" + (Get-Service sshd).Status
