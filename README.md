# TaoBox

TaoBox 是一个面向 VPS 的一体化命令行工具箱，入口脚本会安装到服务器本地，并提供 SSH 登录管理、多协议脚本集成、Realm 端口转发、TCP/BBR 调优、Docker + Nginx Proxy Manager、网络诊断、系统工具和自更新能力。

当前主线更偏向「登录 VPS 后直接用菜单完成常用运维与节点部署」，仓库中仍保留早期的 Ansible / SSH 配置生成文件，适合需要批量管理多台 VPS 的场景。

## 当前版本

- TaoBox VPS Toolbox：`v0.16.4`
- TaoBox Speed：`v1.0.0-taobox.6`
- 默认安装路径：`~/ssh-key-menu.sh`
- 默认快捷命令：`f`

## 快速安装 / 更新

> 当前 CTF/受控网络环境访问 GitHub 时需要携带 `jshook` 请求头。下面命令默认使用 `JSHOOK` 环境变量；未设置时使用脚本默认值 `123`。

### 一键运行脚本

最简单的启动方式：

```bash
curl -fsSL -H "jshook: 123" https://raw.githubusercontent.com/tao-t356/TaoBox/main/bootstrap-vps.sh | bash
```

如果你的环境使用其他 `jshook` 值：

```bash
curl -fsSL -H "jshook: <YOUR_JSHOOK>" https://raw.githubusercontent.com/tao-t356/TaoBox/main/bootstrap-vps.sh | bash
```

### 防缓存安装方式

推荐使用 GitHub API + 时间戳安装，避免 `raw.githubusercontent.com` 缓存导致拉到旧版本：

```bash
tmp=$(mktemp)
curl -fsSL \
  -H "Accept: application/vnd.github.raw" \
  -H "Cache-Control: no-cache" \
  -H "jshook: ${JSHOOK:-123}" \
  "https://api.github.com/repos/tao-t356/TaoBox/contents/bootstrap-vps.sh?ref=main&ts=$(date +%s)" \
  -o "$tmp"
bash "$tmp"
```

如果你明确知道当前网络不受 raw 缓存影响，也可以使用：

```bash
curl -fsSL -H "jshook: ${JSHOOK:-123}" \
  https://raw.githubusercontent.com/tao-t356/TaoBox/main/bootstrap-vps.sh | bash
```

安装完成后，直接输入：

```bash
f
```

即可再次打开 TaoBox。

### 卸载 TaoBox

卸载菜单本身（不会删除通过 TaoBox 安装的服务和业务数据）：

```bash
curl -fsSL -H "jshook: ${JSHOOK:-123}" \
  https://raw.githubusercontent.com/tao-t356/TaoBox/main/scripts/uninstall-taobox.sh | bash
```

如需无交互卸载，可将参数传给管道中的 Bash：

```bash
curl -fsSL -H "jshook: ${JSHOOK:-123}" \
  https://raw.githubusercontent.com/tao-t356/TaoBox/main/scripts/uninstall-taobox.sh \
  | bash -s -- --yes
```

## 主菜单

```text
1. SSH 登录管理
2. 多协议脚本
3. Docker + NPM 安装 / 容器管理
4. 端口转发 / Realm
5. 网络工具 / BBR
6. 系统工具 / DD
7. 更新工具箱
8. 卸载 TaoBox（保留业务数据）
0. 退出
```

## 功能说明

### 1. SSH 登录管理

用于把 VPS 从密码登录逐步切换到公钥登录。

包含：

- 生成本机 SSH 密钥对
- 手动导入一行公钥
- 从 GitHub 用户名导入 `https://github.com/<user>.keys`
- 从 URL 导入公钥
- 编辑 `authorized_keys`
- 查看本机密钥和 `authorized_keys`
- 关闭 / 开启密码登录

建议流程：

1. 先导入公钥
2. 新开一个 SSH 会话确认公钥能登录
3. 再关闭密码登录

### 2. 多协议脚本

菜单 2 直接对接独立上游项目：

- 仓库：`https://github.com/tao-t356/vless-xhttp-reality-self`
- 上游入口：`https://raw.githubusercontent.com/tao-t356/vless-xhttp-reality-self/main/install.sh`
- 对接方式：每次选择菜单 2 都重新下载并执行上游 `main/install.sh`
- 下载方式：优先使用 GitHub Contents API + 时间戳防缓存并携带 `jshook`，失败时重试同一个上游 raw 地址

TaoBox 不再复制上游 `dist` 安装、sidecar 判断或固定版本回退逻辑。协议、安装方式和菜单内容全部以上游当前版本为准，因此上游更新后无需再同步修改 TaoBox 菜单 2。

- 上游安装脚本下载成功后，TaoBox 会先检查文件非空并执行 `bash -n` 语法检查
- 执行时保留真实 TTY，安装完成后可直接进入上游交互菜单
- 上游脚本退出后返回 TaoBox，不会替换或终止工具箱进程
- 仍会刷新旧的 `/usr/local/bin/vless-xhttp-reality-self.sh` 兼容入口

当前上游安装器要求 root、Linux amd64；以后若上游调整支持范围，菜单 2 会自动跟随。

### 3. Docker + NPM 安装 / 容器管理

第 3 项已升级为分层管理界面，首页会直接显示 Docker 容器数量与 NPM 运行状态：

```text
1. 安装 / 卸载 Docker 与 NPM（上游管理器）
2. Docker + NPM 状态总览
3. NPM 专项管理
4. Docker 容器管理
5. Docker 镜像 / 空间清理
0. 返回
```

NPM 专项管理支持状态与面板地址检查、启动、停止、重启、最近日志、拉取最新镜像更新，以及备份 `/opt/npm` 下的配置、SQLite 数据和证书。备份文件保存到当前用户的 `~/taobox-backups/`，为保证数据一致性，备份期间会短暂停止 NPM 并在完成后自动启动。

Docker 容器管理会为全部容器生成编号，可按编号、名称或容器 ID 选择，支持单容器启停、重启、最近/实时日志、资源占用、详情和安全删除；同时保留全部容器的批量启动，以及运行中容器的批量停止和重启。

镜像与空间清理拆分为磁盘占用、镜像列表、已停止容器、悬空镜像、构建缓存、常规 prune 和深度 prune。所有内置清理操作均不会自动删除 Docker 数据卷。

Nginx Proxy Manager 安装脚本来自：

- `https://github.com/tao-t356/Docker-Nginx-Proxy-Manager`

同样通过 GitHub API + 时间戳拉取，避免 raw 缓存。

### 4. 端口转发 / Realm

使用 [Realm](https://github.com/zhboner/realm) 管理 VPS 的 TCP / UDP 端口中转，适合入口机转发到落地机。进入后包含：

```text
1. 安装 / 更新 Realm
2. 添加转发规则
3. 查看转发规则
4. 启用 / 停用规则
5. 删除转发规则
6. 查看 Realm 状态
7. 查看最近日志
8. 卸载 Realm
0. 返回
```

- 支持 TCP、UDP、TCP+UDP，以及 IPv4 / IPv6 监听和目标地址。
- 新建规则默认选择 TCP+UDP；规则列表使用适合窄终端的多行布局，避免中文宽字符和长地址造成错位。
- Realm 状态页会高亮显示服务和开机启动状态，并强制启用 systemd 状态颜色。
- Realm 使用官方最新 Linux musl 二进制，当前支持 x86_64、aarch64、armv7 和 arm。
- 规则保存在 `/etc/realm/taobox-rules.tsv`，运行配置生成到 `/etc/realm/config.toml`。
- 每次增删或启停规则都会原子写入配置；Realm 重启失败时会自动回滚修改前的规则。
- 如果 UFW 或 firewalld 已启用，添加或重新启用规则时会自动放行对应端口；云厂商安全组仍需自行确认。
- 删除规则或卸载 Realm 时不会自动删除防火墙放行项，避免误伤共用相同端口的其他服务。
- 检测到非 TaoBox 管理的 `/etc/systemd/system/realm.service` 或未标记的现有 Realm 二进制时，不会强制覆盖。

### 5. 网络工具 / BBR

包含：

- 普通内核启用 BBR
- 查看 BBR 状态
- BBR 直连/落地优化（智能带宽检测，对接 Eric86777/vps-tcp-tune 菜单 3 的本地内置函数；TaoBox 入口默认全自动执行）
- 安装 NextTrace
- Ping 测试
- Traceroute / Tracepath
- 查看本机路由
- Cloudflare WARP（补齐双栈 IPv4/IPv6、全局出站、socks5 分流、WARP+）
- 安装 XanMod 内核（内置并默认启用 BBRv3，需 x86_64 + Debian/Ubuntu，装完需重启）
- 查看 XanMod / BBRv3 状态（内核、CPU psABI 等级、拥塞控制算法）
- NodeQuality 综合测评（运行 `bash <(curl -sL https://run.NodeQuality.com)`）

XanMod APT 源使用官方系统代号 suite。安装前会清理旧的 `/etc/apt/sources.list.d/xanmod-release.list` 并自动覆盖旧 keyring，再检查 `https://deb.xanmod.org/dists/<codename>/Release` 是否存在；如果当前系统代号（例如 Ubuntu 22.04 的 `jammy`）已不在 XanMod APT 仓库中，会给出明确提示而不是留下坏源导致 `apt update` 失败。

WARP 通过委托上游 fscarmen WARP 菜单实现，进入后由该菜单选择双栈 / 全局 / socks5 等模式。默认下载来源：

- `https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh`

下载沿用 TaoBox 的 `jshook` 兼容方式。由于 `jshook` 主要用于访问 GitHub，如果当前受控网络拉不到默认的 gitlab 源，可用环境变量指向 GitHub 镜像后重试：

```bash
export WARP_INSTALLER_URL=<GitHub 镜像 menu.sh 地址>
f
```

### 6. 系统工具 / DD

包含：

- 查看监听端口
- 查看高占用进程
- 查看常见服务状态
- 重启 SSH 服务
- 查看最近登录
- 重启服务器
- DD 重装系统入口
- Komari 服务器监控
- VPS 到期关机

「VPS 到期关机」使用 systemd timer 管理一次性关机任务，支持设置到期时间、增加 1 个月、修改到期日期、查看剩余时间和取消自动关机。时间格式为 `YYYY-MM-DD HH:MM`，例如 `2026-09-30 23:59`。到期时间会保存到 `/etc/taobox-auto-shutdown/expiry`；启用 `Persistent=true` 后，如果 VPS 在到期时离线，重新启动后会立即执行关机。

Komari 入口位于「系统工具 / DD」。进入后可选择安装 / 重装、升级或卸载。升级会立即检查并下载 Komari 官方最新原生二进制，保留数据并自动重启服务；安装时输入域名后，会按官方原生二进制方式安装 Komari，监听 `127.0.0.1:25774`，再自动注册到 TaoBox 共享 Nginx 网关，共用证书与 443 分流逻辑。卸载会移除 `komari.service`、自动更新定时器、`/opt/komari` 和对应 TaoBox Nginx 反代配置。

DD 重装入口当前提供：

- Debian 12
- Debian 13
- Ubuntu 22.04
- Ubuntu 24.04

> DD 重装属于危险操作，请确认服务商支持、备份数据并确保你知道 root 密码。

### 7. 更新工具箱

会重新下载 `bootstrap-vps.sh` 并覆盖本地 `~/ssh-key-menu.sh`。当前更新逻辑也使用 GitHub API + 时间戳，避免缓存旧版本。

## jshook 说明

本项目在当前 CTF/受控环境中访问真实域名时统一支持 `jshook` 请求头。

默认值：

```bash
JSHOOK=123
```

临时指定：

```bash
export JSHOOK=facker
f
```

或单次运行：

```bash
JSHOOK=facker bash bootstrap-vps.sh
```

涉及 GitHub、XanMod、DD 脚本、远程安装器等下载动作时，脚本会尽量自动携带该请求头。

## 文件结构

```text
bootstrap-vps.sh              # 自包含安装器，会写入 ~/ssh-key-menu.sh
ssh-key-menu.sh               # 已展开的菜单脚本版本
scripts/taobox-speed.sh       # TaoBox Speed 一体化脚本
scripts/uninstall-taobox.sh   # 卸载 TaoBox 菜单本身，保留业务服务和数据
scripts/tcp-one-click-optimize.sh
scripts/lib/tcp-core.sh       # TCP 调优兼容库
inventory/                    # 早期 Ansible 批量管理示例
playbooks/                    # 早期 Ansible playbook
scripts/render_ssh_config.py  # 根据 inventory 生成 SSH config
quick-start.ps1               # Windows 快速辅助脚本
```

## Windows + GitHub 公钥登录建议

在 Windows PowerShell 生成密钥：

```powershell
ssh-keygen -t ed25519 -C "your-name@windows"
```

复制公钥：

```powershell
Get-Content $HOME\.ssh\id_ed25519.pub | Set-Clipboard
```

上传到 GitHub 账号 SSH keys 页面：

```text
https://github.com/settings/keys
```

然后在 VPS 的 TaoBox 中选择：

```text
1. SSH 登录管理
3. GitHub 导入已有公钥
```

确认新会话可以用密钥登录后，再关闭密码登录。

## Ansible / 批量 SSH 管理

仓库仍保留早期批量管理能力：

```bash
pip install -r requirements.txt
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap_public_key.yml --ask-pass
python scripts/render_ssh_config.py --inventory inventory/hosts.yml --output generated/ssh_config
```

相关示例见：

- `inventory/hosts.example.yml`
- `playbooks/bootstrap_public_key.yml`
- `playbooks/harden_ssh.yml`

## 安全提醒

- 私钥文件，例如 `id_ed25519`，不要上传 GitHub，不要发给别人。
- `.pub` 公钥可以导入 VPS 和 GitHub。
- 关闭密码登录前，务必先新开终端验证公钥登录成功。
- DD 重装、Docker prune、覆盖 Xray/Nginx 配置等操作具有破坏性，请提前备份。

## License

见 `LICENSE`。
