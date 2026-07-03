# TaoBox

TaoBox 是一个面向 VPS 的一体化命令行工具箱，入口脚本会安装到服务器本地，并提供 SSH 登录管理、多协议脚本集成、TCP/BBR 调优、Docker + Nginx Proxy Manager、网络诊断、系统工具和自更新能力。

当前主线更偏向「登录 VPS 后直接用菜单完成常用运维与节点部署」，仓库中仍保留早期的 Ansible / SSH 配置生成文件，适合需要批量管理多台 VPS 的场景。

## 当前版本

- TaoBox VPS Toolbox：`v0.13.3`
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

## 主菜单

```text
1. SSH 登录管理
2. 多协议脚本
3. Docker + NPM 安装 / 容器管理
4. 网络工具 / BBR
5. 系统工具 / DD
6. 更新工具箱
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

多协议脚本会下载并执行独立项目：

- 仓库：`https://github.com/tao-t356/vless-xhttp-reality-self`
- 安装入口：`install.sh`
- 当前最新 Release：`v0.19.24`

支持：

- VLESS-XHTTP-REALITY
- Hysteria2
- 同时安装 / 重装 VLESS + Hysteria2
- 证书申请 / 续签
- 查看节点 URL / 二维码
- 服务状态、日志、重启
- 参数重置、备份恢复、卸载

TaoBox 下载根目录 `install.sh` 时使用 GitHub API + 时间戳，并携带 `jshook`，避免缓存旧脚本。
该安装器会安装 / 更新 `/usr/local/bin/vless-xhttp-reality-self` 二进制，并进入项目菜单。进入该菜单后，TaoBox 也会把旧的 `/usr/local/bin/vless-xhttp-reality-self.sh` 刷新成兼容入口，避免误跑旧脚本时仍停留在旧版本。

从 TaoBox 进入多协议脚本时，会先安装 / 更新上游最新 Release，然后打开上游项目菜单；域名、证书和协议选择由该项目菜单处理。

### 3. Docker + NPM 安装 / 容器管理

第 3 项已整合原来的「Docker 容器管理」。进入后包含：

```text
1. 安装 / 重装 Docker + Nginx Proxy Manager
2. 查看 Docker 状态
3. 查看全部容器
4. 启动全部容器
5. 停止全部容器
6. 重启全部容器
7. 查看容器日志
8. Docker system prune
0. 返回
```

Nginx Proxy Manager 安装脚本来自：

- `https://github.com/tao-t356/Docker-Nginx-Proxy-Manager`

同样通过 GitHub API + 时间戳拉取，避免 raw 缓存。

### 4. 网络工具 / BBR

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

WARP 通过委托上游 fscarmen WARP 菜单实现，进入后由该菜单选择双栈 / 全局 / socks5 等模式。默认下载来源：

- `https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh`

下载沿用 TaoBox 的 `jshook` 兼容方式。由于 `jshook` 主要用于访问 GitHub，如果当前受控网络拉不到默认的 gitlab 源，可用环境变量指向 GitHub 镜像后重试：

```bash
export WARP_INSTALLER_URL=<GitHub 镜像 menu.sh 地址>
f
```

### 5. 系统工具 / DD

包含：

- 查看监听端口
- 查看高占用进程
- 查看常见服务状态
- 重启 SSH 服务
- 查看最近登录
- 重启服务器
- DD 重装系统入口
- Komari 服务器监控

Komari 入口位于「系统工具 / DD」。进入后可选择安装 / 重装或卸载。安装时输入域名后，会按官方原生二进制方式安装 Komari，监听 `127.0.0.1:25774`，再自动注册到 TaoBox 共享 Nginx 网关，共用证书与 443 分流逻辑。卸载会移除 `komari.service`、自动更新定时器、`/opt/komari` 和对应 TaoBox Nginx 反代配置。

DD 重装入口当前提供：

- Debian 12
- Debian 13
- Ubuntu 22.04
- Ubuntu 24.04

> DD 重装属于危险操作，请确认服务商支持、备份数据并确保你知道 root 密码。

### 6. 更新工具箱

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
