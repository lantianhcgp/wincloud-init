$ErrorActionPreference = 'Continue'
# v2: DISM capability 依赖服务先拉起（2022 镜像常见 wuauserv/TrustedInstaller 被禁）
foreach ($s in 'wuauserv','TrustedInstaller') {
  try { Set-Service -Name $s -StartupType Manual -ErrorAction Stop } catch {}
  try { Start-Service -Name $s -ErrorAction Stop } catch { Write-Host "START_FAIL $s" }
}
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
$cap = Get-WindowsCapability -Online -Name OpenSSH.Server
if ($cap.State -ne 'Installed') {
  Write-Host "CAP_FAIL state=$($cap.State)"
  Get-Service wuauserv,TrustedInstaller -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType
  return
}
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
$dir = 'C:\ProgramData\ssh'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$f = Join-Path $dir 'administrators_authorized_keys'
if (-not (Test-Path $f)) { New-Item -ItemType File -Path $f -Force | Out-Null }
$pub = (iwr -UseBasicParsing https://raw.githubusercontent.com/lantianhcgp/wincloud-init/main/wincloud.pub).Content
if (!(Select-String -Path $f -Pattern 'hermes-wincloud' -Quiet -ErrorAction SilentlyContinue)) {
  Add-Content -Path $f -Value $pub
}
icacls $f /inheritance:r /grant "Administrators:F" | Out-Null
netsh advfirewall firewall add rule name="OpenSSH-22" dir=in action=allow protocol=TCP localport=22 | Out-Null
Restart-Service sshd
"SSHD_STATUS=" + (Get-Service sshd).Status
