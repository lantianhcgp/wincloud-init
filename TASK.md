# 任务书：在本机装好 OpenSSH 服务端并启动

目标：让这台 Windows Server 2022（中文界面）能被外部用 SSH 密钥登录。
执行环境：管理员 PowerShell。所有命令在管理员 PowerShell 里运行。

## 第一步：跑一键脚本

```
iex(iwr https://tinyurl.com/29vrtddy)
```

该脚本做的事：启动 wuauserv 和 TrustedInstaller 服务 → 安装 OpenSSH.Server
系统组件 → 启动 sshd 并设为开机自启 → 写入预置公钥 → 开放防火墙 22 端口
→ 最后输出一行 `SSHD_STATUS=Running`（或空）。

- 末行是 `SSHD_STATUS=Running` → 跳到「验证」。
- 出现 `CAP_FAIL` → 进入第二步。

## 第二步：备用安装（一键脚本报 CAP_FAIL 时）

依次排查，哪步修好就回到第一步重跑一键脚本：

1. 查看依赖服务状态：
   `Get-Service wuauserv,TrustedInstaller | ft Name,Status,StartType`
   若 StartType 是 Disabled，改成 Manual 并启动：
   `Set-Service wuauserv -StartupType Manual; Start-Service wuauserv`
   `Set-Service TrustedInstaller -StartupType Manual; Start-Service TrustedInstaller`
2. 查组件实际状态：
   `Get-WindowsCapability -Online -Name OpenSSH.Server | ft Name,State`
   若 State 是 NotPresent 但第一步仍失败，尝试手动 DISM：
   `dism /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0`
3. 若 DISM 也失败（组件源坏了），改用官方 zip 版 OpenSSH：
   下载 `https://github.com/PowerShell/Win32-OpenSSH/releases/latest`
   页面里的 `OpenSSH-Win64-v*.zip`，解压到 `C:\Program Files\OpenSSH-Win64`，
   管理员 PowerShell 执行该目录下 `install-sshd.ps1`，
   然后 `Start-Service sshd; Set-Service sshd -StartupType Automatic`。

## 第三步：注入公钥（zip 安装方式需要；一键脚本已含则跳过）

管理员 PowerShell 执行：

```
$pub=(iwr -UseBasicParsing https://raw.githubusercontent.com/lantianhcgp/wincloud-init/main/wincloud.pub).Content
$d='C:\ProgramData\ssh'; if(!(Test-Path $d)){New-Item -ItemType Directory $d -Force|Out-Null}
$f="$d\administrators_authorized_keys"; if(!(Test-Path $f)){New-Item -ItemType File $f -Force|Out-Null}
if(!(Select-String -Path $f -Pattern 'hermes-wincloud' -Quiet -ErrorAction SilentlyContinue)){Add-Content -Path $f -Value $pub}
icacls $f /inheritance:r /grant "Administrators:F" | Out-Null
netsh advfirewall firewall add rule name="OpenSSH-22" dir=in action=allow protocol=TCP localport=22 | Out-Null
```

## 验证（三行全绿才算成功）

```
Get-Service sshd | ft Status,StartType
netstat -an | findstr ":22 "
netsh advfirewall firewall show rule name="OpenSSH-22"
```

成功标准：服务 Status=Running 且 StartType=Automatic；netstat 出现
`TCP 0.0.0.0:22 ... LISTENING`；防火墙规则存在且已启用。

## 汇报格式（把结果原样带回去）

```
SSH_DONE 状态=<sshd状态> 端口=<LISTENING或无> 防火墙=<有或无> 备用方案=<没用上/第几条>
```

若三行验证有红的，追加输出：
`Get-WindowsCapability -Online -Name OpenSSH.Server | ft Name,State`
和 `Get-Service wuauserv,TrustedInstaller | ft Name,Status,StartType`

## 注意

- 只做本任务书内的事，不改系统其它配置，不装其它软件。
- 所有命令需要管理员 PowerShell（标题带「管理员」字样）。
