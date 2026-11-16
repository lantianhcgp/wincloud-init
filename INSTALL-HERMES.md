# 任务书2：在本机装好 Hermes Agent（执行者：WorkBuddy）

## 目标
`hermes --version` 输出版本号。用官方安装器完成完整安装（Python 运行时 + pm + 依赖）。

## 已完成的排障（直接用结论，勿重复踩坑）
1. **git 已装好**：`%LOCALAPPDATA%\hermes\tools\git-2.56.1+1-win32-x64\cmd\git.exe`
   （官方安装器会检测到并跳过 git 下载这步）。
2. **上次安装卡死的根因**：本机到 github.com 的**大对象传输会零字节挂死**
   （小请求正常：ls-remote / api.github.com 均 1-2 秒回；codeload 只有 0.3Mbps 慢爬）。
   卡死的安装进程树（PID 3044）已全部杀掉；残留目录
   `%LOCALAPPDATA%\hermes\.hermes-clone-*` 可直接删。
3. **公共 GitHub 加速镜像全部不可用**（实测 ghfast.top=403、gh-proxy.com=超时、
   gitclone.com=502），不要再试镜像路线。
4. **Microsoft Defender 无查杀记录**（事件日志已查），不是它的锅。
5. 安装器通过管道输出时 stdout 会**假冻结**（缓冲），判断进度请看
   进程列表 / `%LOCALAPPDATA%\hermes` 目录变化，别只盯日志。

## 主路线：本地 bundle（绕开 github 传输掐流）

我方（外部助手）会把官方仓库最新代码打成 bundle 传到本机：
**`C:\Windows\Temp\hermes-agent.bundle`**（含全部历史与标签）。

若该文件存在（先 `Test-Path` 确认）：

```powershell
$H = "$env:LOCALAPPDATA\hermes"
git clone --branch main C:\Windows\Temp\hermes-agent.bundle "$H\hermes-agent"
git -C "$H\hermes-agent" remote set-url origin https://github.com/NousResearch/hermes-agent.git
git -C "$H\hermes-agent" status   # 应在 main、工作区干净
```

然后跑官方安装器（它检测到已有仓库会走"更新"分支，origin/main 已是最新，
fetch 只做协商、零对象传输，不会触发掐流）：

```powershell
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
```

## 备用路线（bundle 不在/损坏时才用）

先配 git 低速中止，让挂死尽快失败重试：

```powershell
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 30
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
```

## 依赖下载若再遇 github 挂死（Python 运行时/包）

安装器自带的 git、uv 工件下载有官方镜像 fallback（无需处理）；需要时可加：

```powershell
$env:UV_PYTHON_INSTALL_MIRROR = "https://registry.npmmirror.com/-/binary/python-build-standalone"
$env:UV_DEFAULT_INDEX = "https://mirrors.aliyun.com/pypi/simple/"
```

（npm 包 `hermes-agent` 与 PyPI 源均可用国内镜像，npmmirror 实测 200。）

## 成功标准与红线

- `hermes --version` 有版本号输出 = 成功。
- **不要启动 gateway**（等用户验收后配置）。
- 不改系统其它配置；凭据不回显、不写进任何仓库。

## 汇报格式

```
HERMES_DONE 版本=<ver> 路线=<bundle直装/重试自愈> 依赖=<官方镜像/国内源>
```

失败则带回：卡住的进程名+PID、最后日志行、卡点目录的字节增量（10 秒采样）。

