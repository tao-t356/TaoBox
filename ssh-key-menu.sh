#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_PATH="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)/$(basename "$0")"
APP_NAME="TaoBox"
REPO_SLUG="tao-t356/TaoBox"
TOOLBOX_VERSION="0.12.12"
DEFAULT_JSHOOK="123"
CURRENT_USER="$(id -un)"
CURRENT_HOME="${HOME:-/root}"
SSH_DIR="${CURRENT_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
MARK_BEGIN="# BEGIN VPS-SSH-KEY-MENU"
MARK_END="# END VPS-SSH-KEY-MENU"

if command -v tput >/dev/null 2>&1 && [ -n "${TERM:-}" ] && [ "${TERM}" != "dumb" ]; then
  C_CYAN="$(tput setaf 6)"
  C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"
  C_RED="$(tput setaf 1)"
  C_BOLD="$(tput bold)"
  C_RESET="$(tput sgr0)"
else
  C_CYAN=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
  C_BOLD=""
  C_RESET=""
fi

say() { printf '%s\n' "$*"; }
ok() { printf '%s%s%s\n' "${C_GREEN}" "$*" "${C_RESET}"; }
warn() { printf '%s%s%s\n' "${C_YELLOW}" "$*" "${C_RESET}"; }
err() { printf '%s%s%s\n' "${C_RED}" "$*" "${C_RESET}" >&2; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

get_effective_jshook() {
  printf '%s' "${JSHOOK:-${DEFAULT_JSHOOK}}"
}

repeat_char() {
  local char="$1"
  local count="$2"
  local out=""
  while [ "${count}" -gt 0 ]; do
    out="${out}${char}"
    count=$((count - 1))
  done
  printf '%s' "${out}"
}

get_primary_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

get_os_pretty_name() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf '%s' "${PRETTY_NAME:-Linux}"
  else
    uname -s
  fi
}

get_docker_summary() {
  if ! have_cmd docker; then
    printf 'not-installed'
    return 0
  fi

  if docker info >/dev/null 2>&1 || (have_cmd sudo && sudo docker info >/dev/null 2>&1); then
    printf 'ready'
  else
    printf 'installed'
  fi
}

get_xanmod_summary() {
  if uname -r 2>/dev/null | grep -qi xanmod; then
    printf 'xanmod'
  else
    printf 'stock'
  fi
}

get_bbr_summary() {
  if have_cmd sysctl; then
    sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown'
  else
    printf 'unknown'
  fi
}

print_divider() {
  say "------------------------------------------------------------"
}

print_section_title() {
  local title="$1"
  printf '%s%s%s\n' "${C_BOLD}" "${title}" "${C_RESET}"
}

menu_item() {
  local key="$1"
  local label="$2"
  printf '  %-3s %s\n' "${key}." "${label}"
}

menu_back_item() {
  printf '  %-3s %s\n' "0." "返回上一级"
}

menu_exit_item() {
  printf '  %-3s %s\n' "0." "退出"
}

print_logo() {
  local primary_ip=""
  local kernel=""
  local os_name=""
  local uptime_text=""
  local border=""
  local title_line=""
  local line=""
  local docker_state=""
  local kernel_state=""
  local bbr_state=""

  primary_ip="$(get_primary_ip)"
  kernel="$(uname -r 2>/dev/null || printf 'unknown')"
  os_name="$(get_os_pretty_name)"
  uptime_text="$(uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'unknown')"
  docker_state="$(get_docker_summary)"
  kernel_state="$(get_xanmod_summary)"
  bbr_state="$(get_bbr_summary)"
  border="$(repeat_char "═" 62)"
  title_line="${APP_NAME} | VPS Toolbox | v${TOOLBOX_VERSION}"

  say "${C_CYAN}╔${border}╗${C_RESET}"
  printf '%s\n' "${C_CYAN}║${C_RESET} ${C_BOLD}$(printf '%-60.60s' "${title_line}")${C_RESET} ${C_CYAN}║${C_RESET}"
  say "${C_CYAN}╠${border}╣${C_RESET}"

  line="Host   : $(hostname)    User   : ${CURRENT_USER}"
  printf '%s\n' "${C_CYAN}║${C_RESET} $(printf '%-60.60s' "${line}") ${C_CYAN}║${C_RESET}"

  line="IP     : ${primary_ip:-unknown}    Kernel : ${kernel}"
  printf '%s\n' "${C_CYAN}║${C_RESET} $(printf '%-60.60s' "${line}") ${C_CYAN}║${C_RESET}"

  line="OS     : ${os_name}"
  printf '%s\n' "${C_CYAN}║${C_RESET} $(printf '%-60.60s' "${line}") ${C_CYAN}║${C_RESET}"

  line="Uptime : ${uptime_text}"
  printf '%s\n' "${C_CYAN}║${C_RESET} $(printf '%-60.60s' "${line}") ${C_CYAN}║${C_RESET}"

  line="Status : docker=${docker_state}   kernel=${kernel_state}   tcp=${bbr_state}"
  printf '%s\n' "${C_CYAN}║${C_RESET} $(printf '%-60.60s' "${line}") ${C_CYAN}║${C_RESET}"

  say "${C_CYAN}╚${border}╝${C_RESET}"
}

run_docker() {
  if ! have_cmd docker; then
    err "当前系统未安装 Docker。"
    return 1
  fi

  if docker info >/dev/null 2>&1; then
    docker "$@"
  elif have_cmd sudo && sudo docker info >/dev/null 2>&1; then
    sudo docker "$@"
  else
    err "当前用户无法访问 Docker，请切换到 root 或加入 docker 组。"
    return 1
  fi
}

prompt_read() {
  if [ -r /dev/tty ]; then
    read -r "$@" < /dev/tty
  else
    read -r "$@"
  fi
}

prompt_secret() {
  if [ -r /dev/tty ]; then
    read -r -s "$@" < /dev/tty
  else
    read -r -s "$@"
  fi
}

run_with_tty() {
  if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    "$@" < /dev/tty > /dev/tty 2>&1
  else
    "$@"
  fi
}

pause() { printf '\n'; prompt_read -p "按回车继续..." _; }

require_cmd() {
  if ! have_cmd "$1"; then
    err "缺少命令: $1"
    return 1
  fi
}

ensure_ssh_dir() {
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
  touch "${AUTHORIZED_KEYS}"
  chmod 600 "${AUTHORIZED_KEYS}"
}

count_authorized_keys() {
  if [ -f "${AUTHORIZED_KEYS}" ]; then
    awk 'NF{n++} END{print n+0}' "${AUTHORIZED_KEYS}"
  else
    echo 0
  fi
}

default_editor() {
  if [ -n "${EDITOR:-}" ]; then
    printf '%s' "${EDITOR}"
  elif have_cmd nano; then
    printf 'nano'
  else
    printf 'vi'
  fi
}

sudo_prefix() {
  if [ "$(id -u)" -eq 0 ]; then
    printf ''
  elif have_cmd sudo; then
    printf 'sudo'
  else
    return 1
  fi
}

effective_sshd_status() {
  local field="$1"
  local sshd_bin=""
  if have_cmd sshd; then
    sshd_bin="$(command -v sshd)"
  elif [ -x /usr/sbin/sshd ]; then
    sshd_bin="/usr/sbin/sshd"
  fi

  if [ -n "${sshd_bin}" ]; then
    "${sshd_bin}" -T 2>/dev/null | awk -v key="${field}" '$1 == key {print $2; exit}'
    return 0
  fi

  printf 'unknown'
}

password_status_text() {
  local status
  status="$(effective_sshd_status passwordauthentication)"
  case "${status}" in
    yes) printf '已启用' ;;
    no) printf '未启用' ;;
    *) printf '未知' ;;
  esac
}

pubkey_status_text() {
  local status
  status="$(effective_sshd_status pubkeyauthentication)"
  case "${status}" in
    yes) printf '已启用' ;;
    no) printf '未启用' ;;
    *) printf '未知' ;;
  esac
}

print_ssh_menu() {
  clear 2>/dev/null || true
  print_logo
  print_section_title "SSH 登录管理"
  say "  密码登录 : $(password_status_text)"
  say "  公钥登录 : $(pubkey_status_text)"
  say "  公钥条数 : $(count_authorized_keys)"
  print_divider
  menu_item "1" "生成本机密钥对"
  menu_item "2" "手动输入一行公钥"
  menu_item "3" "GitHub 导入已有公钥"
  menu_item "4" "URL 导入已有公钥"
  menu_item "5" "编辑公钥文件"
  menu_item "6" "查看本机密钥"
  menu_item "7" "查看 authorized_keys"
  menu_item "8" "关闭密码登录"
  menu_item "9" "开启密码登录"
  menu_back_item
  print_divider
}

append_keys_text() {
  local payload="$1"
  local tmp_file

  ensure_ssh_dir

  tmp_file="$(mktemp)"
  {
    [ -f "${AUTHORIZED_KEYS}" ] && cat "${AUTHORIZED_KEYS}"
    printf '%s\n' "${payload}"
  } | awk 'NF && !seen[$0]++' > "${tmp_file}"

  mv "${tmp_file}" "${AUTHORIZED_KEYS}"
  chmod 600 "${AUTHORIZED_KEYS}"
}

validate_public_key_line() {
  case "$1" in
    ssh-*|ecdsa-*|sk-ssh-*|sk-ecdsa-*) return 0 ;;
    *) return 1 ;;
  esac
}

fetch_url_text() {
  local url="$1"
  local jshook="${2:-}"
  local effective_jshook=""

  if [ -z "${jshook}" ]; then
    effective_jshook="$(get_effective_jshook)"
  else
    effective_jshook="${jshook}"
  fi

  if have_cmd curl; then
    if [ -n "${effective_jshook}" ]; then
      curl -fsSL -H "jshook: ${effective_jshook}" "${url}"
    else
      curl -fsSL "${url}"
    fi
  elif have_cmd wget; then
    if [ -n "${effective_jshook}" ]; then
      wget -qO- --header="jshook: ${effective_jshook}" "${url}"
    else
      wget -qO- "${url}"
    fi
  else
    err "需要 curl 或 wget 其中一个命令。"
    return 1
  fi
}

option_generate_keypair() {
  require_cmd ssh-keygen || return 1
  ensure_ssh_dir

  local default_path="${SSH_DIR}/id_ed25519"
  local key_path=""
  local comment=""

  prompt_read -p "密钥保存路径 [${default_path}]: " key_path
  key_path="${key_path:-${default_path}}"

  if [ -e "${key_path}" ] || [ -e "${key_path}.pub" ]; then
    prompt_read -p "文件已存在，是否覆盖？[y/N]: " confirm
    case "${confirm}" in
      y|Y) ;;
      *) warn "已取消。"; return 0 ;;
    esac
  fi

  prompt_read -p "注释 [${CURRENT_USER}@$(hostname)]: " comment
  comment="${comment:-${CURRENT_USER}@$(hostname)}"

  run_with_tty ssh-keygen -t ed25519 -f "${key_path}" -C "${comment}"
  ok "已生成密钥：${key_path}"
  [ -f "${key_path}.pub" ] && say "公钥内容：" && cat "${key_path}.pub"
}

option_manual_key() {
  local key_line=""
  prompt_read -p "请粘贴一整行 SSH 公钥: " key_line

  if [ -z "${key_line}" ]; then
    warn "没有输入内容。"
    return 0
  fi

  if ! validate_public_key_line "${key_line}"; then
    err "这看起来不像标准 SSH 公钥。"
    return 1
  fi

  append_keys_text "${key_line}"
  ok "公钥已写入 ${AUTHORIZED_KEYS}"
}

option_import_github() {
  local gh_user=""
  local url=""
  local body=""

  prompt_read -p "GitHub 用户名: " gh_user
  if [ -z "${gh_user}" ]; then
    warn "GitHub 用户名不能为空。"
    return 0
  fi

  url="https://github.com/${gh_user}.keys"
  body="$(fetch_url_text "${url}")" || return 1

  if [ -z "${body}" ]; then
    err "没有拉取到任何公钥，请确认 ${gh_user} 账号下已经上传了公钥。"
    return 1
  fi

  append_keys_text "${body}"
  ok "已从 GitHub 导入公钥。"
}

option_import_url() {
  local url=""
  local body=""

  prompt_read -p "公钥 URL: " url
  if [ -z "${url}" ]; then
    warn "URL 不能为空。"
    return 0
  fi

  body="$(fetch_url_text "${url}")" || return 1

  if [ -z "${body}" ]; then
    err "URL 返回为空。"
    return 1
  fi

  append_keys_text "${body}"
  ok "已从 URL 导入公钥。"
}

option_edit_authorized_keys() {
  ensure_ssh_dir
  local editor
  editor="$(default_editor)"
  run_with_tty "${editor}" "${AUTHORIZED_KEYS}"
}

option_view_local_keys() {
  ensure_ssh_dir
  say "SSH 目录: ${SSH_DIR}"
  say "--------------------------------------------------"
  ls -la "${SSH_DIR}" 2>/dev/null || true
  say "--------------------------------------------------"
  if ls "${SSH_DIR}"/*.pub >/dev/null 2>&1; then
    for pub_file in "${SSH_DIR}"/*.pub; do
      say ">>> ${pub_file}"
      cat "${pub_file}"
      say ""
    done
  else
    warn "当前目录下还没有 .pub 公钥文件。"
  fi
}

option_view_authorized_keys() {
  ensure_ssh_dir
  if [ ! -s "${AUTHORIZED_KEYS}" ]; then
    warn "${AUTHORIZED_KEYS} 还是空的。"
    return 0
  fi

  say "文件: ${AUTHORIZED_KEYS}"
  say "--------------------------------------------------"
  nl -ba "${AUTHORIZED_KEYS}"
}

option_show_system_info() {
  local os_name="unknown"
  local local_ip="unknown"

  if [ -r /etc/os-release ]; then
    os_name="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-unknown}")"
  fi

  if have_cmd hostname; then
    local_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || printf 'unknown')"
  fi

  say "${C_BOLD}${C_CYAN}系统信息${C_RESET}"
  say "--------------------------------------------------"
  say "主机名: $(hostname)"
  say "当前用户: ${CURRENT_USER}"
  say "系统: ${os_name}"
  say "内核: $(uname -srmo 2>/dev/null || uname -a)"
  say "本机 IP: ${local_ip}"
  say "启动时间: $(uptime -p 2>/dev/null || uptime)"
  say "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  say "--------------------------------------------------"

  if have_cmd free; then
    say "[内存]"
    free -h
    say "--------------------------------------------------"
  fi

  if have_cmd df; then
    say "[磁盘]"
    df -h /
    say "--------------------------------------------------"
  fi

  if have_cmd ss; then
    say "[监听端口]"
    ss -tulpn 2>/dev/null | sed -n '1,12p'
  fi
}

option_taobox_speed_info() {
  say "${C_BOLD}${C_CYAN}TaoBox Speed${C_RESET}"
  say "--------------------------------------------------"
  say "仓库: https://github.com/tao-t356/TaoBox"
  say "用途: TCP 智能调优 + XanMod / BBRv3 + Argo VMess WebSocket 节点部署"
  say "要求: Debian / Ubuntu、root、Cloudflare / GitHub 出站正常"
  say "运行方式: 会从 GitHub 拉取 TaoBox 内置 scripts/taobox-speed.sh 并执行"
  say "功能: 完整流程、重启续跑、doctor、repair、speedtest、netcheck、订阅输出"
  say "--------------------------------------------------"
}

option_vless_project_info() {
  say "${C_BOLD}${C_CYAN}vless-xhttp-reality-self${C_RESET}"
  say "--------------------------------------------------"
  say "仓库: https://github.com/tao-t356/vless-xhttp-reality-self"
  say "用途: Debian / Ubuntu 上菜单式部署 VLESS + XHTTP + REALITY + Hysteria2"
  say "要求: root、域名已解析、80/443 可用"
  say "运行方式: 会从 GitHub 拉取 scripts/install.sh 并执行"
  say "--------------------------------------------------"
}

run_remote_installer() {
  local project_name="$1"
  local project_url="$2"
  local note="${3:-}"
  local script_arg="${4:-}"
  local jshook=""
  local tmp_file=""
  local download_url=""

  if [ "$(id -u)" -ne 0 ]; then
    err "${project_name} 建议使用 root 运行。"
    return 1
  fi

  jshook="$(get_effective_jshook)"
  download_url="${project_url}"

  case "${project_url}" in
    https://raw.githubusercontent.com/tao-t356/TaoBox/main/scripts/taobox-speed.sh)
      download_url="https://api.github.com/repos/tao-t356/TaoBox/contents/scripts/taobox-speed.sh?ref=main&ts=$(date +%s)"
      ;;
    https://raw.githubusercontent.com/tao-t356/vless-xhttp-reality-self/main/scripts/install.sh)
      download_url="https://api.github.com/repos/tao-t356/vless-xhttp-reality-self/contents/scripts/install.sh?ref=main&ts=$(date +%s)"
      ;;
    https://raw.githubusercontent.com/tao-t356/Docker-Nginx-Proxy-Manager/main/install.sh)
      download_url="https://api.github.com/repos/tao-t356/Docker-Nginx-Proxy-Manager/contents/install.sh?ref=main&ts=$(date +%s)"
      ;;
  esac

  tmp_file="$(mktemp)"
  if have_cmd curl; then
    if printf '%s' "${download_url}" | grep -q '^https://api.github.com/repos/'; then
      curl -fsSL -H "Accept: application/vnd.github.raw" -H "Cache-Control: no-cache" -H "jshook: ${jshook}" "${download_url}" -o "${tmp_file}"
    else
      curl -fsSL -H "Cache-Control: no-cache" -H "jshook: ${jshook}" "${download_url}" -o "${tmp_file}"
    fi
  elif have_cmd wget; then
    if printf '%s' "${download_url}" | grep -q '^https://api.github.com/repos/'; then
      wget -qO "${tmp_file}" --header="Accept: application/vnd.github.raw" --header="Cache-Control: no-cache" --header="jshook: ${jshook}" "${download_url}"
    else
      wget -qO "${tmp_file}" --header="Cache-Control: no-cache" --header="jshook: ${jshook}" "${download_url}"
    fi
  else
    err "需要 curl 或 wget 其中一个命令。"
    rm -f "${tmp_file}"
    return 1
  fi

  chmod +x "${tmp_file}"
  local rc=0
  if [ -n "${script_arg}" ]; then
    run_with_tty bash "${tmp_file}" "${script_arg}" || rc=$?
  else
    run_with_tty bash "${tmp_file}" || rc=$?
  fi
  rm -f "${tmp_file}"
  printf '\n'
  prompt_read -p "按回车返回工具箱..." _
  return "${rc}"
}

option_run_taobox_speed() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    case "${ID:-}" in
      debian|ubuntu) ;;
      *)
        warn "当前系统不是 Debian / Ubuntu，脚本可能不兼容。"
        ;;
    esac
  fi

  run_remote_installer \
    "TaoBox Speed" \
    "https://raw.githubusercontent.com/tao-t356/TaoBox/main/scripts/taobox-speed.sh" \
    "它会进入 TaoBox Speed 一体化流程：XanMod / BBRv3 / TCP 调优 + 节点部署。"
}

option_run_vless_project() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    case "${ID:-}" in
      debian|ubuntu) ;;
      *)
        warn "当前系统不是 Debian / Ubuntu，脚本可能不兼容。"
        ;;
    esac
  fi

  run_remote_installer \
    "vless-xhttp-reality-self" \
    "https://raw.githubusercontent.com/tao-t356/vless-xhttp-reality-self/main/scripts/install.sh" \
    "它会修改 Xray / Nginx / 证书等配置。"
}

option_npm_docker_info() {
  say "${C_BOLD}${C_CYAN}Docker + Nginx Proxy Manager${C_RESET}"
  say "--------------------------------------------------"
  say "仓库: https://github.com/tao-t356/Docker-Nginx-Proxy-Manager"
  say "用途: 一键安装 Docker 与 Nginx Proxy Manager"
  say "原始命令: wget -qO n https://raw.githubusercontent.com/tao-t356/Docker-Nginx-Proxy-Manager/main/install.sh && bash n"
  say "当前工具箱会改成 jshook 兼容方式下载后执行。"
  say "--------------------------------------------------"
}

option_run_npm_docker() {
  run_remote_installer \
    "Docker-Nginx-Proxy-Manager" \
    "https://raw.githubusercontent.com/tao-t356/Docker-Nginx-Proxy-Manager/main/install.sh" \
    "它会安装 Docker 与 Nginx Proxy Manager。"
}

option_nexttrace_info() {
  say "${C_BOLD}${C_CYAN}NextTrace${C_RESET}"
  say "--------------------------------------------------"
  say "官网: https://nxtrace.org"
  say "用途: 路由追踪 / 网络诊断"
  say "原始命令: curl -sL https://nxtrace.org/nt | bash"
  say "当前工具箱会改成 jshook 兼容方式下载后执行。"
  say "--------------------------------------------------"
}

option_run_nexttrace() {
  run_remote_installer \
    "NextTrace" \
    "https://nxtrace.org/nt" \
    "它会在线安装 NextTrace。"
}

option_xanmod_info() {
  local level="unknown"
  local package_name="unknown"
  local current_kernel=""
  local current_cc="unknown"
  local current_qdisc="unknown"

  level="$(detect_x86_64_psabi_level 2>/dev/null || printf 'unknown')"
  package_name="$(detect_xanmod_package 2>/dev/null || printf 'unknown')"
  current_kernel="$(uname -r 2>/dev/null || printf 'unknown')"
  if have_cmd sysctl; then
    current_cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown')"
    current_qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || printf 'unknown')"
  fi

  say "${C_BOLD}${C_CYAN}XanMod / BBRv3 状态${C_RESET}"
  say "--------------------------------------------------"
  say "当前内核: ${current_kernel}"
  if printf '%s' "${current_kernel}" | grep -qi xanmod; then
    say "XanMod 状态: 已安装"
  else
    say "XanMod 状态: 未检测到"
  fi
  say "CPU x86-64 psABI level: ${level}"
  say "推荐安装包: ${package_name}"
  say "当前拥塞控制算法: ${current_cc}"
  say "当前默认队列算法: ${current_qdisc}"
  say "说明: XanMod 官方当前标注内置并默认启用 Google's BBRv3 TCP congestion control（名称仍显示为 bbr）"
  say "--------------------------------------------------"
}

option_install_xanmod() {
  local root_cmd=""
  local jshook=""
  local package_name=""
  local codename=""
  local tmp_script=""

  if [ "$(uname -m 2>/dev/null)" != "x86_64" ]; then
    err "当前只为 x86_64 设计了 XanMod 安装流程。"
    return 1
  fi

  if [ -r /etc/os-release ]; then
    . /etc/os-release
    case "${ID:-}" in
      debian|ubuntu) ;;
      *)
        err "XanMod 安装流程当前只支持 Debian / Ubuntu。"
        return 1
        ;;
    esac
  fi

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能安装 XanMod。"
    return 1
  fi

  package_name="$(detect_xanmod_package 2>/dev/null || true)"
  codename="$(get_linux_codename 2>/dev/null || true)"
  if [ -z "${package_name}" ] || [ -z "${codename}" ]; then
    err "无法识别 CPU 等级或系统代号，已停止。"
    return 1
  fi

  say "即将安装 XanMod 内核。"
  say "系统代号: ${codename}"
  say "推荐安装包: ${package_name}"
  say "说明: XanMod 官方当前包含并默认启用 BBRv3（名称显示为 bbr）。"
  say "安装完成后通常需要重启服务器。"
  prompt_read -p "确认继续？[Y/n]: " confirm
  case "${confirm}" in
    ""|y|Y) ;;
    *)
      warn "已取消。"
      return 0
      ;;
  esac

  jshook="$(get_effective_jshook)"

  tmp_script="$(mktemp)"
  cat > "${tmp_script}" <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive

mkdir -p /etc/apt/keyrings

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ca-certificates curl wget gnupg lsb-release
fi

curl -fsSL -H "jshook: ${jshook}" https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org ${codename} main" > /etc/apt/sources.list.d/xanmod-release.list

apt-get update
apt-get install -y ${package_name}
EOF

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} bash "${tmp_script}"
  else
    bash "${tmp_script}"
  fi
  rm -f "${tmp_script}"

  ok "XanMod 安装命令已执行完成。"
  warn "请确认安装日志无报错。切换到 XanMod 新内核需要重启系统。"
  prompt_read -p "是否现在重启系统以切换到新内核？(回车默认重启) [Y/n]: " reboot_now
  case "${reboot_now}" in
    n|N)
      warn "已跳过重启。你可以稍后在“系统工具 -> 重启服务器”里手动重启。"
      ;;
    *)
      option_reboot_server
      ;;
  esac
}

option_bbr_info() {
  local cc="unknown"
  local qdisc="unknown"
  local available="unknown"

  if have_cmd sysctl; then
    cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown')"
    qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || printf 'unknown')"
    available="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || printf 'unknown')"
  fi

  say "${C_BOLD}${C_CYAN}BBR 状态${C_RESET}"
  say "--------------------------------------------------"
  say "当前拥塞控制算法: ${cc}"
  say "当前默认队列算法: ${qdisc}"
  say "内核支持的拥塞控制: ${available}"
  if printf '%s' "${available}" | grep -qw bbr; then
    say "BBR 支持状态: 支持"
  else
    say "BBR 支持状态: 可能不支持"
  fi
  if [ "${cc}" = "bbr" ]; then
    say "BBR 启用状态: 已启用"
  else
    say "BBR 启用状态: 未启用"
  fi
  say "--------------------------------------------------"
}

option_enable_bbr() {
  local root_cmd=""
  local tmp_script=""

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能启用 BBR。"
    return 1
  fi

  say "即将启用 BBR。"
  say "会写入:"
  say "- /etc/modules-load.d/bbr.conf"
  say "- /etc/sysctl.d/99-vps-toolbox-bbr.conf"
  prompt_read -p "确认继续？[y/N]: " confirm
  case "${confirm}" in
    y|Y) ;;
    *)
      warn "已取消。"
      return 0
      ;;
  esac

  tmp_script="$(mktemp)"
  cat > "${tmp_script}" <<'EOF'
set -e

mkdir -p /etc/modules-load.d /etc/sysctl.d

cat > /etc/modules-load.d/bbr.conf <<'CONF'
tcp_bbr
sch_fq
CONF

cat > /etc/sysctl.d/99-vps-toolbox-bbr.conf <<'CONF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
CONF

modprobe sch_fq 2>/dev/null || true
modprobe tcp_bbr 2>/dev/null || true

if command -v sysctl >/dev/null 2>&1; then
  sysctl --system >/dev/null
fi
EOF

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} bash "${tmp_script}"
  else
    bash "${tmp_script}"
  fi
  rm -f "${tmp_script}"

  option_bbr_info
}

option_system_cleanup() {
  local root_cmd=""
  local tmp_script=""

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能执行系统清理。"
    return 1
  fi

  say "即将执行系统清理："
  say "- apt / dnf / yum 缓存清理"
  say "- 无用依赖清理"
  say "- journal 日志保留最近 7 天"
  prompt_read -p "确认继续？[y/N]: " confirm
  case "${confirm}" in
    y|Y) ;;
    *)
      warn "已取消。"
      return 0
      ;;
  esac

  say "清理前磁盘使用："
  df -h /

  tmp_script="$(mktemp)"
  cat > "${tmp_script}" <<'EOF'
set -e

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || true
  apt-get autoremove -y
  apt-get autoclean -y
  apt-get clean -y
elif command -v dnf >/dev/null 2>&1; then
  dnf autoremove -y || true
  dnf clean all || true
elif command -v yum >/dev/null 2>&1; then
  yum autoremove -y || true
  yum clean all || true
fi

if command -v journalctl >/dev/null 2>&1; then
  journalctl --vacuum-time=7d || true
fi
EOF

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} bash "${tmp_script}"
  else
    bash "${tmp_script}"
  fi
  rm -f "${tmp_script}"

  say "清理后磁盘使用："
  df -h /
}

option_docker_status() {
  if ! have_cmd docker; then
    warn "当前系统未安装 Docker。"
    return 0
  fi

  say "${C_BOLD}${C_CYAN}Docker 状态${C_RESET}"
  say "--------------------------------------------------"
  docker --version 2>/dev/null || true
  run_docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>/dev/null || true
}

option_docker_list_all() {
  if ! have_cmd docker; then
    warn "当前系统未安装 Docker。"
    return 0
  fi

  run_docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}'
}

option_docker_start_all() {
  local ids=""
  ids="$(run_docker ps -aq 2>/dev/null || true)"
  if [ -z "${ids}" ]; then
    warn "当前没有容器。"
    return 0
  fi
  run_docker start ${ids}
}

option_docker_stop_all() {
  local ids=""
  ids="$(run_docker ps -aq 2>/dev/null || true)"
  if [ -z "${ids}" ]; then
    warn "当前没有容器。"
    return 0
  fi
  run_docker stop ${ids}
}

option_docker_restart_all() {
  local ids=""
  ids="$(run_docker ps -aq 2>/dev/null || true)"
  if [ -z "${ids}" ]; then
    warn "当前没有容器。"
    return 0
  fi
  run_docker restart ${ids}
}

option_docker_logs() {
  local container_name=""
  prompt_read -p "请输入容器名: " container_name
  if [ -z "${container_name}" ]; then
    warn "容器名不能为空。"
    return 0
  fi
  run_docker logs --tail 100 "${container_name}"
}

option_docker_prune() {
  prompt_read -p "确认执行 docker system prune -f ? [y/N]: " confirm
  case "${confirm}" in
    y|Y) run_docker system prune -f ;;
    *) warn "已取消。" ;;
  esac
}

normalize_domain_input() {
  local domain="$1"
  domain="$(printf '%s' "${domain}" | sed -E 's#^https?://##; s#/.*$##; s/[[:space:]]//g')"
  domain="${domain%.}"
  printf '%s' "${domain}"
}

is_valid_domain() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$'
}

is_valid_port() {
  local port="$1"
  case "${port}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "${port}" -ge 1 ] 2>/dev/null && [ "${port}" -le 65535 ] 2>/dev/null
}

sanitize_slug() {
  local slug="$1"
  slug="$(printf '%s' "${slug}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_.-' '-')"
  slug="$(printf '%s' "${slug}" | sed -E 's/^-+//; s/-+$//; s/-+/-/g')"
  printf '%s' "${slug:-app}"
}

run_web_gateway_register_proxy() {
  local app_slug="$1"
  local app_name="$2"
  local domain="$3"
  local upstream_host="$4"
  local upstream_port="$5"
  local result_file="${6:-}"
  local root_cmd=""
  local tmp_script=""
  local rc=0

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能配置 Web 网关。"
    return 1
  fi

  app_slug="$(sanitize_slug "${app_slug}")"

  tmp_script="$(mktemp)"
  cat > "${tmp_script}" <<'EOF'
set -euo pipefail

WEB_APP_SLUG="${1:?missing app slug}"
WEB_APP_NAME="${2:?missing app name}"
WEB_DOMAIN="${3:?missing domain}"
WEB_UPSTREAM_HOST="${4:?missing upstream host}"
WEB_UPSTREAM_PORT="${5:?missing upstream port}"
WEB_RESULT_FILE="${6:-}"
WEB_INTERNAL_HTTPS_PORT="8444"
SINGBOX_REALITY_LOCAL_PORT="10443"
SINGBOX_CONFIG="/etc/sing-box/config.json"
ACCESS_URL="http://${WEB_DOMAIN}"
APT_UPDATED=0

log() { printf '%s\n' "$*"; }
log_warn() { printf '警告: %s\n' "$*" >&2; }
log_err() { printf '错误: %s\n' "$*" >&2; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_update_once() {
  if [ "${APT_UPDATED}" -eq 0 ]; then
    apt-get update
    APT_UPDATED=1
  fi
}

port_in_use() {
  local port="$1"
  if ! have_cmd ss; then
    return 1
  fi
  ss -H -ltn "( sport = :${port} )" 2>/dev/null | grep -q .
}

port_owned_by() {
  local port="$1"
  local name="$2"
  if ! have_cmd ss; then
    return 1
  fi
  ss -H -ltnp "( sport = :${port} )" 2>/dev/null | grep -qi "${name}"
}

open_firewall_port() {
  local port="$1"
  local proto="${2:-tcp}"

  if have_cmd ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${port}/${proto}" >/dev/null 2>&1 || true
  fi

  if have_cmd firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --add-port="${port}/${proto}" --permanent >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
  fi
}

safe_domain_name() {
  printf '%s' "${WEB_DOMAIN}" | tr -c 'A-Za-z0-9_.-' '_'
}

install_gateway_dependencies() {
  apt_update_once
  apt-get install -y ca-certificates curl nginx python3 openssl
}

ensure_origin_cert() {
  local cert_dir="/etc/ssl/taobox-web"
  local safe_domain=""

  safe_domain="$(safe_domain_name)"
  WEB_ORIGIN_CERT="${cert_dir}/${safe_domain}.crt"
  WEB_ORIGIN_KEY="${cert_dir}/${safe_domain}.key"

  if [ -s "${WEB_ORIGIN_CERT}" ] && [ -s "${WEB_ORIGIN_KEY}" ]; then
    return 0
  fi

  mkdir -p "${cert_dir}"
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout "${WEB_ORIGIN_KEY}" \
    -out "${WEB_ORIGIN_CERT}" \
    -subj "/CN=${WEB_DOMAIN}" \
    -addext "subjectAltName=DNS:${WEB_DOMAIN}" >/dev/null 2>&1
  chmod 600 "${WEB_ORIGIN_KEY}"
}

install_nginx_stream_module() {
  if nginx -V 2>&1 | grep -q -- '--with-stream=dynamic'; then
    if [ ! -f /usr/lib/nginx/modules/ngx_stream_module.so ]; then
      apt_update_once
      apt-get install -y libnginx-mod-stream
    fi

    if [ -f /usr/lib/nginx/modules/ngx_stream_module.so ] && \
      ! grep -Rqs 'ngx_stream_module.so' /etc/nginx/modules-enabled 2>/dev/null; then
      mkdir -p /etc/nginx/modules-enabled
      printf '%s\n' 'load_module modules/ngx_stream_module.so;' > /etc/nginx/modules-enabled/50-mod-stream.conf
    fi
  fi
}

ensure_nginx_stream_include() {
  local include_line="include /etc/nginx/stream.d/*.conf;"

  mkdir -p /etc/nginx/stream.d
  if grep -Fq "${include_line}" /etc/nginx/nginx.conf; then
    return 0
  fi

  cp /etc/nginx/nginx.conf "/etc/nginx/nginx.conf.taobox-web-backup.$(date +%Y%m%d_%H%M%S)" || true
  python3 - <<'PY'
from pathlib import Path

path = Path("/etc/nginx/nginx.conf")
text = path.read_text()
include_line = "include /etc/nginx/stream.d/*.conf;"
if include_line not in text:
    marker = "\nhttp {"
    if marker in text:
        text = text.replace(marker, "\n" + include_line + "\n\nhttp {", 1)
    else:
        text = text.rstrip() + "\n" + include_line + "\n"
    path.write_text(text)
PY
}

move_singbox_reality_to_local() {
  if [ ! -f "${SINGBOX_CONFIG}" ] || ! have_cmd sing-box; then
    log_err "检测到 443 被 sing-box 占用，但未找到 sing-box 配置或命令，无法自动共用 443。"
    exit 1
  fi

  if port_in_use "${SINGBOX_REALITY_LOCAL_PORT}" && ! port_owned_by "${SINGBOX_REALITY_LOCAL_PORT}" sing-box; then
    log_err "本机 ${SINGBOX_REALITY_LOCAL_PORT} 已被占用，无法迁移 sing-box REALITY。"
    ss -ltnp "( sport = :${SINGBOX_REALITY_LOCAL_PORT} )" 2>/dev/null || true
    exit 1
  fi

  cp "${SINGBOX_CONFIG}" "${SINGBOX_CONFIG}.taobox-web-backup.$(date +%Y%m%d_%H%M%S)" || true
  python3 - "${SINGBOX_CONFIG}" "${SINGBOX_REALITY_LOCAL_PORT}" <<'PY'
import json
import sys

path, local_port = sys.argv[1], int(sys.argv[2])
with open(path, "r", encoding="utf-8") as fh:
    cfg = json.load(fh)

changed = False
found = False
for inbound in cfg.get("inbounds", []):
    tls = inbound.get("tls") or {}
    reality = tls.get("reality") or {}
    if inbound.get("type") == "vless" and inbound.get("listen_port") == 443 and reality.get("enabled"):
        inbound["listen"] = "127.0.0.1"
        inbound["listen_port"] = local_port
        changed = True
        found = True
    elif inbound.get("type") == "vless" and inbound.get("listen_port") == local_port and reality.get("enabled"):
        found = True

if not found:
    raise SystemExit("未找到 listen_port=443 的 sing-box REALITY vless 入站")

if changed:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
PY

  sing-box check -c "${SINGBOX_CONFIG}"
}

should_use_singbox_stream_share() {
  if port_in_use 443 && port_owned_by 443 sing-box; then
    return 0
  fi

  if port_in_use "${SINGBOX_REALITY_LOCAL_PORT}" && port_owned_by "${SINGBOX_REALITY_LOCAL_PORT}" sing-box && \
    [ -f /etc/nginx/stream.d/00-taobox-sni-router.conf ]; then
    return 0
  fi

  return 1
}

proxy_conf_file() {
  printf '/etc/nginx/conf.d/00-taobox-web-%s.conf' "$(safe_domain_name)"
}

write_http_proxy_config() {
  local conf_file=""

  conf_file="$(proxy_conf_file)"
  mkdir -p /etc/nginx/conf.d

  cat > "${conf_file}" <<NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name ${WEB_DOMAIN};

    location / {
        proxy_pass http://${WEB_UPSTREAM_HOST}:${WEB_UPSTREAM_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
NGINXEOF
}

append_internal_https_server() {
  local conf_file=""

  conf_file="$(proxy_conf_file)"
  ensure_origin_cert

  cat >> "${conf_file}" <<NGINXEOF

server {
    listen 127.0.0.1:${WEB_INTERNAL_HTTPS_PORT} ssl http2;
    server_name ${WEB_DOMAIN};

    ssl_certificate     ${WEB_ORIGIN_CERT};
    ssl_certificate_key ${WEB_ORIGIN_KEY};

    location / {
        proxy_pass http://${WEB_UPSTREAM_HOST}:${WEB_UPSTREAM_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
NGINXEOF
}

write_stream_router() {
  local safe_domain=""
  local map_file=""
  local migrated_map="/etc/nginx/stream-map.d/00-taobox-migrated.conf"

  safe_domain="$(safe_domain_name)"
  mkdir -p /etc/nginx/stream.d /etc/nginx/stream-map.d

  if [ -f /etc/nginx/stream.d/00-taobox-sni-router.conf ]; then
    awk '
      $1 !~ /^(include|default)$/ && $2 ~ /^taobox_(komari|web)_https;$/ {
        gsub(/;/, "", $1)
        print $1 " taobox_web_https;"
      }
    ' /etc/nginx/stream.d/00-taobox-sni-router.conf | sort -u > "${migrated_map}.tmp" || true
    if [ -s "${migrated_map}.tmp" ]; then
      mv "${migrated_map}.tmp" "${migrated_map}"
    else
      rm -f "${migrated_map}.tmp"
    fi
  fi

  map_file="/etc/nginx/stream-map.d/00-taobox-web-${safe_domain}.conf"
  printf '%s %s;\n' "${WEB_DOMAIN}" "taobox_web_https" > "${map_file}"

  cat > /etc/nginx/stream.d/00-taobox-sni-router.conf <<NGINXEOF
stream {
    map \$ssl_preread_server_name \$taobox_sni_backend {
        include /etc/nginx/stream-map.d/*.conf;
        default taobox_singbox_reality;
    }

    upstream taobox_singbox_reality {
        server 127.0.0.1:${SINGBOX_REALITY_LOCAL_PORT};
    }

    upstream taobox_web_https {
        server 127.0.0.1:${WEB_INTERNAL_HTTPS_PORT};
    }

    server {
        listen 443;
        listen [::]:443;
        proxy_pass \$taobox_sni_backend;
        ssl_preread on;
    }
}
NGINXEOF
}

configure_stream_share() {
  log "检测到 443 被 sing-box 占用，启用 Nginx stream SNI 分流。"
  install_nginx_stream_module
  ensure_nginx_stream_include
  move_singbox_reality_to_local
  append_internal_https_server
  write_stream_router
  nginx -t
  systemctl restart sing-box
  systemctl enable --now nginx >/dev/null 2>&1 || true
  systemctl restart nginx
  ACCESS_URL="https://${WEB_DOMAIN}"
  open_firewall_port 443 tcp
}

configure_direct_nginx() {
  if ! nginx -t; then
    log_err "Nginx 配置检测失败。"
    exit 1
  fi

  systemctl enable --now nginx >/dev/null 2>&1 || true
  systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx
  open_firewall_port 80 tcp

  if ! port_in_use 443 || port_owned_by 443 nginx; then
    apt-get install -y certbot python3-certbot-nginx >/dev/null 2>&1 || true
    if have_cmd certbot; then
      if certbot --nginx -d "${WEB_DOMAIN}" --non-interactive --agree-tos --register-unsafely-without-email --redirect; then
        ACCESS_URL="https://${WEB_DOMAIN}"
        open_firewall_port 443 tcp
      else
        log_warn "证书申请失败，HTTP 反代仍可使用。"
      fi
    fi
  elif port_in_use 443; then
    log_warn "443 被非 Nginx/sing-box 服务占用，本次只启用 HTTP 反代。"
    ss -ltnp "( sport = :443 )" 2>/dev/null || true
  fi
}

register_proxy() {
  if port_in_use 80 && ! port_owned_by 80 nginx; then
    log_err "端口 80 已被非 Nginx 服务占用，无法共用 Nginx。"
    ss -ltnp "( sport = :80 )" 2>/dev/null || true
    exit 1
  fi

  install_gateway_dependencies
  write_http_proxy_config

  if should_use_singbox_stream_share; then
    configure_stream_share
  else
    configure_direct_nginx
  fi
}

write_result_file() {
  [ -n "${WEB_RESULT_FILE}" ] || return 0
  printf 'WEB_ACCESS_URL=%q\n' "${ACCESS_URL}" >> "${WEB_RESULT_FILE}"
}

register_proxy
write_result_file

log "Web 网关已注册: ${WEB_DOMAIN} -> ${WEB_UPSTREAM_HOST}:${WEB_UPSTREAM_PORT}"
log "访问地址: ${ACCESS_URL}"
EOF

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} bash "${tmp_script}" "${app_slug}" "${app_name}" "${domain}" "${upstream_host}" "${upstream_port}" "${result_file}" || rc=$?
  else
    bash "${tmp_script}" "${app_slug}" "${app_name}" "${domain}" "${upstream_host}" "${upstream_port}" "${result_file}" || rc=$?
  fi
  rm -f "${tmp_script}"
  return "${rc}"
}

option_web_gateway_add_proxy() {
  local app_slug=""
  local domain=""
  local upstream_host=""
  local upstream_port=""
  local result_file=""
  local web_access_url=""

  prompt_read -p "项目名称 [app]: " app_slug
  app_slug="$(sanitize_slug "${app_slug:-app}")"

  prompt_read -p "请输入域名: " domain
  domain="$(normalize_domain_input "${domain}")"
  if ! is_valid_domain "${domain}"; then
    err "域名格式无效。示例: app.example.com"
    return 1
  fi

  prompt_read -p "上游地址 [127.0.0.1]: " upstream_host
  upstream_host="${upstream_host:-127.0.0.1}"

  prompt_read -p "上游端口: " upstream_port
  if ! is_valid_port "${upstream_port}"; then
    err "端口无效，应为 1-65535。"
    return 1
  fi

  result_file="$(mktemp)"
  if ! run_web_gateway_register_proxy "${app_slug}" "${app_slug}" "${domain}" "${upstream_host}" "${upstream_port}" "${result_file}"; then
    rm -f "${result_file}"
    err "Web 网关注册失败。"
    return 1
  fi

  if [ -r "${result_file}" ]; then
    # shellcheck disable=SC1090
    . "${result_file}"
    web_access_url="${WEB_ACCESS_URL:-}"
  fi
  rm -f "${result_file}"

  ok "Web 网关注册完成。"
  say "访问地址: ${web_access_url:-http://${domain}}"
}

option_web_gateway_status() {
  local root_cmd=""
  local tmp_script=""
  local rc=0

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能查看 Web 网关状态。"
    return 1
  fi

  tmp_script="$(mktemp)"
  cat > "${tmp_script}" <<'EOF'
set -e

section() { printf '\n===== %s =====\n' "$1"; }

section "监听端口"
ss -ltnp 2>/dev/null | grep -E ':(80|443|8444|10443)\b' || true

section "Nginx 配置检测"
nginx -t 2>&1 || true

section "TaoBox 反代站点"
ls -1 /etc/nginx/conf.d/00-taobox-web-*.conf 2>/dev/null || true

section "TaoBox SNI 分流"
ls -1 /etc/nginx/stream-map.d/*.conf 2>/dev/null || true
if [ -d /etc/nginx/stream-map.d ]; then
  grep -RIn . /etc/nginx/stream-map.d 2>/dev/null || true
fi

section "证书"
if command -v certbot >/dev/null 2>&1; then
  certbot certificates 2>&1 || true
else
  echo "certbot 未安装"
fi
EOF

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} bash "${tmp_script}" || rc=$?
  else
    bash "${tmp_script}" || rc=$?
  fi
  rm -f "${tmp_script}"
  return "${rc}"
}

option_install_komari_server() {
  local root_cmd=""
  local tmp_script=""
  local result_file=""
  local komari_domain=""
  local komari_access_url=""
  local komari_initial_password=""
  local rc=0

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能安装 Komari。"
    return 1
  fi

  if [ -r /etc/os-release ]; then
    . /etc/os-release
    case "${ID:-}" in
      debian|ubuntu) ;;
      *)
        err "Komari 原生安装当前只支持 Debian / Ubuntu。"
        return 1
        ;;
    esac
  else
    err "无法识别系统版本，已取消。"
    return 1
  fi

  prompt_read -p "请输入 Komari 域名: " komari_domain
  komari_domain="$(normalize_domain_input "${komari_domain}")"

  if ! is_valid_domain "${komari_domain}"; then
    err "域名格式无效。示例: monitor.example.com"
    return 1
  fi

  say "即将安装 Komari 服务器监控："
  say "- 安装方式: 官方原生二进制 + systemd"
  say "- 监听地址: 127.0.0.1:25774"
  say "- 反代方式: 共享宿主机 Nginx"
  say "- 安装目录: /opt/komari"

  tmp_script="$(mktemp)"
  result_file="$(mktemp)"
  cat > "${tmp_script}" <<'EOF'
set -euo pipefail

KOMARI_DOMAIN="${1:?missing domain}"
KOMARI_RESULT_FILE="${2:-}"
INSTALL_DIR="/opt/komari"
DATA_DIR="/opt/komari"
SERVICE_NAME="komari"
BINARY_PATH="${INSTALL_DIR}/komari"
LISTEN_HOST="127.0.0.1"
LISTEN_PORT="25774"
KOMARI_ADMIN_USERNAME="facker668"
KOMARI_ADMIN_PASSWORD="wohenshuai"
KOMARI_INTERNAL_HTTPS_PORT="8444"
SINGBOX_REALITY_LOCAL_PORT="10443"
SINGBOX_CONFIG="/etc/sing-box/config.json"
ACCESS_URL="http://${KOMARI_DOMAIN}"
INITIAL_PASSWORD=""
APT_UPDATED=0

log() { printf '%s\n' "$*"; }
log_warn() { printf '警告: %s\n' "$*" >&2; }
log_err() { printf '错误: %s\n' "$*" >&2; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_update_once() {
  if [ "${APT_UPDATED}" -eq 0 ]; then
    apt-get update
    APT_UPDATED=1
  fi
}

detect_arch() {
  local arch=""
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    i386|i686) printf '386' ;;
    riscv64) printf 'riscv64' ;;
    *)
      log_err "不支持的架构: ${arch}"
      exit 1
      ;;
  esac
}

port_in_use() {
  local port="$1"
  if ! have_cmd ss; then
    return 1
  fi
  ss -H -ltn "( sport = :${port} )" 2>/dev/null | grep -q .
}

port_owned_by() {
  local port="$1"
  local name="$2"
  if ! have_cmd ss; then
    return 1
  fi
  ss -H -ltnp "( sport = :${port} )" 2>/dev/null | grep -qi "${name}"
}

open_firewall_port() {
  local port="$1"
  local proto="${2:-tcp}"

  if have_cmd ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${port}/${proto}" >/dev/null 2>&1 || true
  fi

  if have_cmd firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --add-port="${port}/${proto}" --permanent >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
  fi
}

safe_domain_name() {
  printf '%s' "${KOMARI_DOMAIN}" | tr -c 'A-Za-z0-9_.-' '_'
}

cleanup_legacy_docker_komari() {
  if have_cmd docker && docker info >/dev/null 2>&1; then
    docker rm -f komari-caddy komari >/dev/null 2>&1 || true
  fi
}

install_dependencies() {
  apt_update_once
  apt-get install -y ca-certificates curl nginx python3
}

install_komari_binary() {
  local arch=""
  local file_name=""
  local download_url=""
  local tmp_binary=""

  arch="$(detect_arch)"
  file_name="komari-linux-${arch}"
  download_url="https://github.com/komari-monitor/komari/releases/latest/download/${file_name}"
  tmp_binary="$(mktemp)"

  log "下载 Komari 官方原生二进制: ${download_url}"
  if ! curl -fsSL -o "${tmp_binary}" "${download_url}"; then
    rm -f "${tmp_binary}"
    log_err "下载 Komari 二进制失败。"
    exit 1
  fi

  mkdir -p "${INSTALL_DIR}" "${DATA_DIR}"
  if [ -f "${BINARY_PATH}" ]; then
    cp "${BINARY_PATH}" "${BINARY_PATH}.backup.$(date +%Y%m%d_%H%M%S)" || true
  fi

  install -m 0755 "${tmp_binary}" "${BINARY_PATH}"
  rm -f "${tmp_binary}"
}

write_komari_service() {
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SERVICEEOF
[Unit]
Description=Komari Monitor Service
After=network.target

[Service]
Type=simple
ExecStart=${BINARY_PATH} server -l ${LISTEN_HOST}:${LISTEN_PORT}
WorkingDirectory=${DATA_DIR}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SERVICEEOF

  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}.service"
  sleep 5

  if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    log_err "Komari 服务启动失败，查看日志: journalctl -u ${SERVICE_NAME} -f"
    exit 1
  fi

  INITIAL_PASSWORD="$(journalctl -u "${SERVICE_NAME}" --since "2 minutes ago" 2>/dev/null | grep "admin account created." | tail -n 1 | sed -e 's/.*admin account created.//' || true)"
}

set_komari_admin_credentials() {
  if [ -z "${KOMARI_ADMIN_PASSWORD}" ]; then
    return 0
  fi

  if (cd "${DATA_DIR}" && "${BINARY_PATH}" chpasswd -p "${KOMARI_ADMIN_PASSWORD}"); then
    INITIAL_PASSWORD="Username: admin , Password: ${KOMARI_ADMIN_PASSWORD}"
  else
    log_warn "Komari 管理员密码设置失败，保留官方初始密码。"
    return 0
  fi

  if have_cmd python3; then
    if python3 - "${DATA_DIR}/data/komari.db" "${KOMARI_ADMIN_USERNAME}" <<'PY'
import sqlite3
import sys

db_path, username = sys.argv[1], sys.argv[2]
con = sqlite3.connect(db_path)
try:
    cur = con.cursor()
    cur.execute("SELECT uuid, username FROM users ORDER BY created_at ASC LIMIT 1")
    row = cur.fetchone()
    if row and row[1] != username:
        cur.execute("UPDATE users SET username = ?, updated_at = datetime('now') WHERE uuid = ?", (username, row[0]))
        con.commit()
finally:
    con.close()
PY
    then
      INITIAL_PASSWORD="Username: ${KOMARI_ADMIN_USERNAME} , Password: ${KOMARI_ADMIN_PASSWORD}"
    else
      log_warn "Komari 管理员用户名设置失败，用户名保持 admin。"
    fi
  fi

  (cd "${DATA_DIR}" && "${BINARY_PATH}" permit-login) >/dev/null 2>&1 || true
  systemctl restart "${SERVICE_NAME}.service"
}

ensure_komari_origin_cert() {
  local cert_dir="/etc/ssl/taobox-komari"
  local safe_domain=""

  safe_domain="$(safe_domain_name)"
  KOMARI_ORIGIN_CERT="${cert_dir}/${safe_domain}.crt"
  KOMARI_ORIGIN_KEY="${cert_dir}/${safe_domain}.key"

  if [ -s "${KOMARI_ORIGIN_CERT}" ] && [ -s "${KOMARI_ORIGIN_KEY}" ]; then
    return 0
  fi

  apt-get install -y openssl >/dev/null 2>&1 || true
  if ! have_cmd openssl; then
    log_err "缺少 openssl，无法为 Komari 生成 Nginx 内部 HTTPS 证书。"
    exit 1
  fi

  mkdir -p "${cert_dir}"
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout "${KOMARI_ORIGIN_KEY}" \
    -out "${KOMARI_ORIGIN_CERT}" \
    -subj "/CN=${KOMARI_DOMAIN}" \
    -addext "subjectAltName=DNS:${KOMARI_DOMAIN}" >/dev/null 2>&1
  chmod 600 "${KOMARI_ORIGIN_KEY}"
}

install_nginx_stream_module() {
  if nginx -V 2>&1 | grep -q -- '--with-stream=dynamic'; then
    if [ ! -f /usr/lib/nginx/modules/ngx_stream_module.so ]; then
      apt_update_once
      apt-get install -y libnginx-mod-stream
    fi

    if [ -f /usr/lib/nginx/modules/ngx_stream_module.so ] && \
      ! grep -Rqs 'ngx_stream_module.so' /etc/nginx/modules-enabled 2>/dev/null; then
      mkdir -p /etc/nginx/modules-enabled
      printf '%s\n' 'load_module modules/ngx_stream_module.so;' > /etc/nginx/modules-enabled/50-mod-stream.conf
    fi
  fi
}

ensure_nginx_stream_include() {
  local include_line="include /etc/nginx/stream.d/*.conf;"

  mkdir -p /etc/nginx/stream.d
  if grep -Fq "${include_line}" /etc/nginx/nginx.conf; then
    return 0
  fi

  cp /etc/nginx/nginx.conf "/etc/nginx/nginx.conf.taobox-komari-backup.$(date +%Y%m%d_%H%M%S)" || true
  python3 - <<'PY'
from pathlib import Path

path = Path("/etc/nginx/nginx.conf")
text = path.read_text()
include_line = "include /etc/nginx/stream.d/*.conf;"
if include_line not in text:
    marker = "\nhttp {"
    if marker in text:
        text = text.replace(marker, "\n" + include_line + "\n\nhttp {", 1)
    else:
        text = text.rstrip() + "\n" + include_line + "\n"
    path.write_text(text)
PY
}

move_singbox_reality_to_local() {
  if [ ! -f "${SINGBOX_CONFIG}" ] || ! have_cmd sing-box; then
    log_err "检测到 443 被 sing-box 占用，但未找到 sing-box 配置或命令，无法自动共用 443。"
    exit 1
  fi

  if port_in_use "${SINGBOX_REALITY_LOCAL_PORT}" && ! port_owned_by "${SINGBOX_REALITY_LOCAL_PORT}" sing-box; then
    log_err "本机 ${SINGBOX_REALITY_LOCAL_PORT} 已被占用，无法迁移 sing-box REALITY。"
    ss -ltnp "( sport = :${SINGBOX_REALITY_LOCAL_PORT} )" 2>/dev/null || true
    exit 1
  fi

  cp "${SINGBOX_CONFIG}" "${SINGBOX_CONFIG}.taobox-komari-backup.$(date +%Y%m%d_%H%M%S)" || true
  python3 - "${SINGBOX_CONFIG}" "${SINGBOX_REALITY_LOCAL_PORT}" <<'PY'
import json
import sys

path, local_port = sys.argv[1], int(sys.argv[2])
with open(path, "r", encoding="utf-8") as fh:
    cfg = json.load(fh)

changed = False
found = False
for inbound in cfg.get("inbounds", []):
    tls = inbound.get("tls") or {}
    reality = tls.get("reality") or {}
    if inbound.get("type") == "vless" and inbound.get("listen_port") == 443 and reality.get("enabled"):
        inbound["listen"] = "127.0.0.1"
        inbound["listen_port"] = local_port
        changed = True
        found = True
    elif inbound.get("type") == "vless" and inbound.get("listen_port") == local_port and reality.get("enabled"):
        found = True

if not found:
    raise SystemExit("未找到 listen_port=443 的 sing-box REALITY vless 入站")

if changed:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
PY

  sing-box check -c "${SINGBOX_CONFIG}"
}

append_komari_internal_https_server() {
  local conf_file="$1"

  ensure_komari_origin_cert
  if grep -q "listen 127.0.0.1:${KOMARI_INTERNAL_HTTPS_PORT} ssl" "${conf_file}"; then
    return 0
  fi

  if port_in_use "${KOMARI_INTERNAL_HTTPS_PORT}" && ! port_owned_by "${KOMARI_INTERNAL_HTTPS_PORT}" nginx; then
    log_err "本机 ${KOMARI_INTERNAL_HTTPS_PORT} 已被非 Nginx 服务占用，无法创建 Komari 内部 HTTPS 反代。"
    ss -ltnp "( sport = :${KOMARI_INTERNAL_HTTPS_PORT} )" 2>/dev/null || true
    exit 1
  fi

  cat >> "${conf_file}" <<NGINXEOF

server {
    listen 127.0.0.1:${KOMARI_INTERNAL_HTTPS_PORT} ssl http2;
    server_name ${KOMARI_DOMAIN};

    ssl_certificate     ${KOMARI_ORIGIN_CERT};
    ssl_certificate_key ${KOMARI_ORIGIN_KEY};

    location / {
        proxy_pass http://${LISTEN_HOST}:${LISTEN_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
NGINXEOF
}

configure_singbox_nginx_stream_share() {
  local conf_file="$1"

  log "检测到 443 被 sing-box 占用，自动配置 Nginx stream SNI 分流。"
  install_nginx_stream_module
  append_komari_internal_https_server "${conf_file}"
  ensure_nginx_stream_include
  move_singbox_reality_to_local

  cat > /etc/nginx/stream.d/00-taobox-sni-router.conf <<NGINXEOF
stream {
    map \$ssl_preread_server_name \$taobox_sni_backend {
        ${KOMARI_DOMAIN} taobox_komari_https;
        default taobox_singbox_reality;
    }

    upstream taobox_singbox_reality {
        server 127.0.0.1:${SINGBOX_REALITY_LOCAL_PORT};
    }

    upstream taobox_komari_https {
        server 127.0.0.1:${KOMARI_INTERNAL_HTTPS_PORT};
    }

    server {
        listen 443;
        listen [::]:443;
        proxy_pass \$taobox_sni_backend;
        ssl_preread on;
    }
}
NGINXEOF

  nginx -t
  systemctl restart sing-box
  systemctl enable --now nginx >/dev/null 2>&1 || true
  systemctl restart nginx
  ACCESS_URL="https://${KOMARI_DOMAIN}"
  open_firewall_port 443 tcp
}

should_use_singbox_stream_share() {
  if port_in_use 443 && port_owned_by 443 sing-box; then
    return 0
  fi

  if port_in_use "${SINGBOX_REALITY_LOCAL_PORT}" && port_owned_by "${SINGBOX_REALITY_LOCAL_PORT}" sing-box && \
    [ -f /etc/nginx/stream.d/00-taobox-sni-router.conf ]; then
    return 0
  fi

  return 1
}

write_nginx_proxy() {
  local safe_domain=""
  local conf_file=""

  if port_in_use 80 && ! port_owned_by 80 nginx; then
    log_err "端口 80 已被非 Nginx 服务占用，无法共用 Nginx。"
    ss -ltnp "( sport = :80 )" 2>/dev/null || true
    exit 1
  fi

  if port_in_use 443 && ! port_owned_by 443 nginx && ! port_owned_by 443 sing-box; then
    log_warn "端口 443 已被非 Nginx/sing-box 服务占用，本次只写入 Nginx HTTP 反代。"
    ss -ltnp "( sport = :443 )" 2>/dev/null || true
  fi

  safe_domain="$(safe_domain_name)"
  conf_file="/etc/nginx/conf.d/00-taobox-komari-${safe_domain}.conf"
  mkdir -p /etc/nginx/conf.d

  cat > "${conf_file}" <<NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name ${KOMARI_DOMAIN};

    location / {
        proxy_pass http://${LISTEN_HOST}:${LISTEN_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
NGINXEOF

  if should_use_singbox_stream_share; then
    configure_singbox_nginx_stream_share "${conf_file}"
    open_firewall_port 80 tcp
    return 0
  fi

  if ! nginx -t; then
    rm -f "${conf_file}"
    log_err "Nginx 配置检测失败，已回滚 Komari 反代配置。"
    exit 1
  fi

  systemctl enable --now nginx >/dev/null 2>&1 || true
  systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx
  open_firewall_port 80 tcp

  if ! port_in_use 443 || port_owned_by 443 nginx; then
    apt-get install -y certbot python3-certbot-nginx >/dev/null 2>&1 || true
    if have_cmd certbot; then
      if certbot --nginx -d "${KOMARI_DOMAIN}" --non-interactive --agree-tos --register-unsafely-without-email --redirect; then
        ACCESS_URL="https://${KOMARI_DOMAIN}"
        open_firewall_port 443 tcp
      else
        log_warn "证书申请失败，Nginx HTTP 反代仍可使用。"
      fi
    fi
  fi
}

install_update_timer() {
  cat > /usr/local/sbin/taobox-komari-update <<'UPDATEEOF'
#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/komari"
BINARY_PATH="${INSTALL_DIR}/komari"
SERVICE_NAME="komari"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

detect_arch() {
  case "$(uname -m)" in
    x86_64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    i386|i686) printf '386' ;;
    riscv64) printf 'riscv64' ;;
    *) log "不支持的架构: $(uname -m)"; exit 0 ;;
  esac
}

if ! command -v curl >/dev/null 2>&1; then
  log "缺少 curl，跳过 Komari 更新。"
  exit 0
fi

arch="$(detect_arch)"
download_url="https://github.com/komari-monitor/komari/releases/latest/download/komari-linux-${arch}"
tmp_binary="$(mktemp)"

if ! curl -fsSL -o "${tmp_binary}" "${download_url}"; then
  rm -f "${tmp_binary}"
  log "下载 Komari 最新版本失败，保留当前版本。"
  exit 0
fi

if [ -f "${BINARY_PATH}" ] && cmp -s "${tmp_binary}" "${BINARY_PATH}"; then
  rm -f "${tmp_binary}"
  log "Komari 已是最新版本。"
  exit 0
fi

mkdir -p "${INSTALL_DIR}"
if [ -f "${BINARY_PATH}" ]; then
  cp "${BINARY_PATH}" "${BINARY_PATH}.backup.$(date +%Y%m%d_%H%M%S)" || true
fi

systemctl stop "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
install -m 0755 "${tmp_binary}" "${BINARY_PATH}"
rm -f "${tmp_binary}"

if systemctl start "${SERVICE_NAME}.service" && systemctl is-active --quiet "${SERVICE_NAME}.service"; then
  log "Komari 已更新并重启。"
  exit 0
fi

log "Komari 更新后启动失败，请检查: journalctl -u ${SERVICE_NAME} -f"
exit 1
UPDATEEOF

  chmod +x /usr/local/sbin/taobox-komari-update

  cat > /etc/systemd/system/taobox-komari-update.service <<'SERVICEEOF'
[Unit]
Description=TaoBox Komari native binary update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/taobox-komari-update
SERVICEEOF

  cat > /etc/systemd/system/taobox-komari-update.timer <<'TIMEREOF'
[Unit]
Description=Run TaoBox Komari update weekly

[Timer]
OnCalendar=weekly
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
TIMEREOF

  systemctl daemon-reload
  systemctl enable --now taobox-komari-update.timer >/dev/null 2>&1 || true
}

write_result_file() {
  [ -n "${KOMARI_RESULT_FILE}" ] || return 0
  {
    printf 'KOMARI_ACCESS_URL=%q\n' "${ACCESS_URL}"
    printf 'KOMARI_INITIAL_PASSWORD=%q\n' "${INITIAL_PASSWORD}"
  } > "${KOMARI_RESULT_FILE}"
}

if [ ! -d /run/systemd/system ]; then
  log_err "当前环境未运行 systemd，无法使用 Komari 官方原生服务安装。"
  exit 1
fi

install_dependencies
cleanup_legacy_docker_komari
install_komari_binary
write_komari_service
set_komari_admin_credentials
install_update_timer
write_result_file

log "Komari 原生服务状态："
systemctl --no-pager --full status komari.service | sed -n '1,8p' || true
log "访问地址: ${ACCESS_URL}"
EOF

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} bash "${tmp_script}" "${komari_domain}" "${result_file}" || rc=$?
  else
    bash "${tmp_script}" "${komari_domain}" "${result_file}" || rc=$?
  fi
  rm -f "${tmp_script}"

  if [ "${rc}" -ne 0 ]; then
    rm -f "${result_file}"
    err "Komari 安装失败。"
    return "${rc}"
  fi

  if ! run_web_gateway_register_proxy "komari" "Komari" "${komari_domain}" "127.0.0.1" "25774" "${result_file}"; then
    rm -f "${result_file}"
    err "Komari 已安装，但 Web 网关反代配置失败。"
    return 1
  fi

  if [ -r "${result_file}" ]; then
    # shellcheck disable=SC1090
    . "${result_file}"
    komari_access_url="${WEB_ACCESS_URL:-${KOMARI_ACCESS_URL:-}}"
    komari_initial_password="${KOMARI_INITIAL_PASSWORD:-}"
  fi
  rm -f "${result_file}"

  ok "Komari 安装完成。"
  say "访问地址: ${komari_access_url:-http://${komari_domain}}"
  if [ -n "${komari_initial_password}" ]; then
    say "初始登录信息（仅显示一次）: ${komari_initial_password}"
  else
    warn "未获取到初始密码；如果是重装并保留数据，这是正常的。可查看: journalctl -u komari -n 80"
  fi
  say "服务管理: systemctl status komari"
  say "每周自动升级: systemctl list-timers taobox-komari-update.timer"
}

detect_firewall_backend() {
  if have_cmd ufw; then
    printf 'ufw'
    return 0
  fi
  if have_cmd firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    printf 'firewalld'
    return 0
  fi
  printf 'none'
}

option_firewall_status() {
  local backend=""
  backend="$(detect_firewall_backend)"
  say "${C_BOLD}${C_CYAN}防火墙状态${C_RESET}"
  say "--------------------------------------------------"
  case "${backend}" in
    ufw)
      ufw status verbose || true
      ;;
    firewalld)
      firewall-cmd --state
      firewall-cmd --list-all || true
      ;;
    *)
      warn "未检测到受支持的防火墙（ufw / firewalld）。"
      ;;
  esac
}

allow_firewall_port() {
  local port="$1"
  local proto="$2"
  local backend=""
  local root_cmd=""

  backend="$(detect_firewall_backend)"
  if [ "${backend}" = "none" ]; then
    warn "未检测到受支持的防火墙（ufw / firewalld）。"
    return 1
  fi

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能修改防火墙。"
    return 1
  fi

  case "${backend}" in
    ufw)
      if [ -n "${root_cmd}" ]; then
        ${root_cmd} ufw allow "${port}/${proto}"
      else
        ufw allow "${port}/${proto}"
      fi

      if ufw status 2>/dev/null | head -n 1 | grep -qi inactive; then
        prompt_read -p "UFW 当前未启用，是否立即启用？[y/N]: " enable_ufw
        case "${enable_ufw}" in
          y|Y)
            if [ -n "${root_cmd}" ]; then
              ${root_cmd} ufw --force enable
            else
              ufw --force enable
            fi
            ;;
        esac
      fi
      ;;
    firewalld)
      if [ -n "${root_cmd}" ]; then
        ${root_cmd} firewall-cmd --permanent --add-port="${port}/${proto}"
        ${root_cmd} firewall-cmd --reload
      else
        firewall-cmd --permanent --add-port="${port}/${proto}"
        firewall-cmd --reload
      fi
      ;;
  esac

  ok "已放行端口 ${port}/${proto}"
}

option_allow_common_ports() {
  allow_firewall_port 22 tcp
  allow_firewall_port 80 tcp
  allow_firewall_port 443 tcp
}

option_allow_custom_port() {
  local port=""
  local proto=""
  prompt_read -p "端口号: " port
  if [ -z "${port}" ]; then
    warn "端口号不能为空。"
    return 0
  fi
  prompt_read -p "协议 [tcp]: " proto
  proto="${proto:-tcp}"
  allow_firewall_port "${port}" "${proto}"
}

option_update_toolbox() {
  local jshook=""
  local tmp_script=""

  jshook="$(get_effective_jshook)"

  tmp_script="$(mktemp)"
  if have_cmd curl; then
    curl -fsSL \
      -H "Accept: application/vnd.github.raw" \
      -H "Cache-Control: no-cache" \
      -H "jshook: ${jshook}" \
      "https://api.github.com/repos/${REPO_SLUG}/contents/bootstrap-vps.sh?ref=main&ts=$(date +%s)" \
      -o "${tmp_script}"
  elif have_cmd wget; then
    wget -qO "${tmp_script}" \
      --header="Accept: application/vnd.github.raw" \
      --header="Cache-Control: no-cache" \
      --header="jshook: ${jshook}" \
      "https://api.github.com/repos/${REPO_SLUG}/contents/bootstrap-vps.sh?ref=main&ts=$(date +%s)"
  else
    err "需要 curl 或 wget 其中一个命令。"
    rm -f "${tmp_script}"
    return 1
  fi

  chmod +x "${tmp_script}"
  bash "${tmp_script}" --no-run --target "${SCRIPT_PATH}"
  rm -f "${tmp_script}"
  ok "工具箱已更新到最新版本。"

  prompt_read -p "是否立即重新打开工具箱？[Y/n]: " reopen
  case "${reopen}" in
    n|N) ;;
    *)
      exec bash "${SCRIPT_PATH}"
      ;;
  esac
}

detect_x86_64_psabi_level() {
  awk '
    BEGIN {
      level=0
      while (!/flags/) {
        if ((getline < "/proc/cpuinfo") != 1) exit 1
      }
      if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
      if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
      if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
      if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
      if (level > 0) {
        print level
        exit 0
      }
      exit 1
    }'
}

detect_xanmod_package() {
  local level=""
  level="$(detect_x86_64_psabi_level 2>/dev/null || printf '0')"
  case "${level}" in
    4|3) printf 'linux-xanmod-x64v3' ;;
    2) printf 'linux-xanmod-x64v2' ;;
    1) printf 'linux-xanmod-lts-x64v1' ;;
    *) return 1 ;;
  esac
}

get_linux_codename() {
  if have_cmd lsb_release; then
    lsb_release -sc 2>/dev/null && return 0
  fi
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    if [ -n "${VERSION_CODENAME:-}" ]; then
      printf '%s\n' "${VERSION_CODENAME}"
      return 0
    fi
  fi
  return 1
}

option_ping_test() {
  local target=""
  prompt_read -p "请输入目标域名或 IP: " target
  if [ -z "${target}" ]; then
    warn "目标不能为空。"
    return 0
  fi
  if have_cmd ping; then
    run_with_tty ping -c 4 "${target}"
  else
    err "当前系统没有 ping 命令。"
  fi
}

option_trace_test() {
  local target=""
  prompt_read -p "请输入目标域名或 IP: " target
  if [ -z "${target}" ]; then
    warn "目标不能为空。"
    return 0
  fi

  if have_cmd traceroute; then
    run_with_tty traceroute "${target}"
  elif have_cmd tracepath; then
    run_with_tty tracepath "${target}"
  else
    err "当前系统没有 traceroute / tracepath。"
  fi
}

option_show_ip_route() {
  if have_cmd ip; then
    ip route show
  elif have_cmd route; then
    route -n
  else
    err "当前系统没有 ip / route 命令。"
  fi
}

option_show_listening_ports() {
  if have_cmd ss; then
    ss -tulpn
  elif have_cmd netstat; then
    netstat -tulpn
  else
    err "当前系统没有 ss / netstat。"
  fi
}

option_show_top_processes() {
  say "[CPU TOP 10]"
  ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu | sed -n '1,11p'
  say "--------------------------------------------------"
  say "[MEM TOP 10]"
  ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%mem | sed -n '1,11p'
}

option_show_common_service_status() {
  local services="ssh sshd nginx docker xray hysteria-server hysteria"
  local svc=""

  if have_cmd systemctl; then
    for svc in ${services}; do
      if systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"; then
        printf '%-18s %s\n' "${svc}" "$(systemctl is-active "${svc}" 2>/dev/null || printf 'unknown')"
      fi
    done
  else
    warn "当前系统没有 systemctl，无法统一查询服务状态。"
  fi
}

option_restart_ssh_service() {
  local root_cmd=""
  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能重启 SSH 服务。"
    return 1
  fi

  prompt_read -p "确认重启 SSH 服务？[y/N]: " confirm
  case "${confirm}" in
    y|Y) ;;
    *)
      warn "已取消。"
      return 0
      ;;
  esac

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} systemctl restart sshd 2>/dev/null || \
    ${root_cmd} systemctl restart ssh 2>/dev/null || \
    ${root_cmd} service sshd restart 2>/dev/null || \
    ${root_cmd} service ssh restart 2>/dev/null
  else
    systemctl restart sshd 2>/dev/null || \
    systemctl restart ssh 2>/dev/null || \
    service sshd restart 2>/dev/null || \
    service ssh restart 2>/dev/null
  fi
  ok "SSH 服务已重启。"
}

option_recent_logins() {
  if have_cmd last; then
    last -a | sed -n '1,20p'
  else
    err "当前系统没有 last 命令。"
  fi
}

option_reboot_server() {
  local root_cmd=""
  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能重启服务器。"
    return 1
  fi

  warn "重启服务器会导致当前 SSH 会话断开。"
  prompt_read -p "确认重启服务器？[y/N]: " confirm
  case "${confirm}" in
    y|Y) ;;
    *)
      warn "已取消。"
      return 0
      ;;
  esac

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} reboot
  else
    reboot
  fi
}

run_dd_reinstall_system() {
  local root_cmd=""
  local jshook=""
  local distro="$1"
  local version="$2"
  local root_pass=""
  local tmp_file=""
  local dd_url="https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh"
  local distro_flag=""

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能执行 DD 重装。"
    return 1
  fi

  prompt_secret -p "新系统 root 密码: " root_pass
  printf '\n'
  if [ -z "${root_pass}" ]; then
    warn "密码不能为空。"
    return 0
  fi

  jshook="$(get_effective_jshook)"

  case "${distro}" in
    debian|ubuntu|centos|alma|rocky|almalinux|fedora)
      distro_flag="-${distro}"
      ;;
    *)
      err "暂不支持的系统类型: ${distro}"
      return 1
      ;;
  esac

  tmp_file="$(mktemp)"
  if have_cmd curl; then
    curl -fsSL -H "jshook: ${jshook}" "${dd_url}" -o "${tmp_file}"
  elif have_cmd wget; then
    wget --no-check-certificate -qO "${tmp_file}" --header="jshook: ${jshook}" "${dd_url}"
  else
    err "需要 curl 或 wget 其中一个命令。"
    rm -f "${tmp_file}"
    return 1
  fi

  chmod +x "${tmp_file}"
  warn "即将开始 DD 重装到 ${distro} ${version}，当前会话可能很快断开。"
  if [ -n "${root_cmd}" ]; then
    run_with_tty ${root_cmd} bash "${tmp_file}" "${distro_flag}" "${version}" -pwd "${root_pass}"
  else
    run_with_tty bash "${tmp_file}" "${distro_flag}" "${version}" -pwd "${root_pass}"
  fi
}

dd_reinstall_menu_loop() {
  local choice=""
  while true; do
    clear 2>/dev/null || true
    print_logo
    print_section_title "DD 重装系统（危险）"
    print_divider
    say "警告："
    say "- 会覆盖当前系统"
    say "- 会中断当前 SSH 会话"
    say "- 可能自动重启"
    say "- 当前数据可能不可恢复"
    print_divider
    menu_item "1" "Debian 12"
    menu_item "2" "Debian 13"
    menu_item "3" "Ubuntu 22.04"
    menu_item "4" "Ubuntu 24.04"
    menu_back_item
    print_divider
    prompt_read -p "请输入你的选择 [2]: " choice
    printf '\n'
    case "${choice:-2}" in
      1) run_dd_reinstall_system "debian" "12" ;;
      2) run_dd_reinstall_system "debian" "13" ;;
      3) run_dd_reinstall_system "ubuntu" "22.04" ;;
      4) run_dd_reinstall_system "ubuntu" "24.04" ;;
      0) return 0 ;;
      *) warn "无效选项，请重新输入。" ;;
    esac
    pause
  done
}

apply_password_mode() {
  local password_auth="$1"
  local kbd_auth="$2"
  local challenge_auth="$3"
  local permit_root="$4"
  local root_cmd=""
  local tmp_script=""

  if ! root_cmd="$(sudo_prefix)"; then
    err "需要 root 或 sudo 权限才能修改 SSH 服务配置。"
    return 1
  fi

  tmp_script="$(mktemp)"
  cat > "${tmp_script}" <<EOF
set -e
CONFIG="/etc/ssh/sshd_config"
MANAGED_FILE="/etc/ssh/sshd_config.d/99-vps-ssh-key-menu.conf"
USE_INCLUDE=0

if grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\\.d/\\*\\.conf' "\${CONFIG}" 2>/dev/null; then
  USE_INCLUDE=1
fi

backup_file() {
  if [ -f "\$1" ]; then
    cp "\$1" "\$1.bak.\$(date +%F-%H%M%S)"
  fi
}

if [ "\${USE_INCLUDE}" = "1" ]; then
  mkdir -p /etc/ssh/sshd_config.d
  backup_file "\${MANAGED_FILE}"
  cat > "\${MANAGED_FILE}" <<'CONF'
# Managed by ${SCRIPT_NAME}
PubkeyAuthentication yes
PasswordAuthentication ${password_auth}
KbdInteractiveAuthentication ${kbd_auth}
ChallengeResponseAuthentication ${challenge_auth}
PermitRootLogin ${permit_root}
CONF
else
  backup_file "\${CONFIG}"
  TMP="\$(mktemp)"
  awk '
    BEGIN {skip=0}
    \$0 == "${MARK_BEGIN}" {skip=1; next}
    \$0 == "${MARK_END}" {skip=0; next}
    !skip {print}
  ' "\${CONFIG}" > "\${TMP}"
  cat >> "\${TMP}" <<'CONF'
${MARK_BEGIN}
PubkeyAuthentication yes
PasswordAuthentication ${password_auth}
KbdInteractiveAuthentication ${kbd_auth}
ChallengeResponseAuthentication ${challenge_auth}
PermitRootLogin ${permit_root}
${MARK_END}
CONF
  mv "\${TMP}" "\${CONFIG}"
fi

if command -v sshd >/dev/null 2>&1; then
  sshd -t
elif [ -x /usr/sbin/sshd ]; then
  /usr/sbin/sshd -t
fi

systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || service sshd restart 2>/dev/null || service ssh restart 2>/dev/null
EOF

  if [ -n "${root_cmd}" ]; then
    ${root_cmd} bash "${tmp_script}"
  else
    bash "${tmp_script}"
  fi

  rm -f "${tmp_script}"
}

option_disable_password_login() {
  say "请先确保你已经在新终端里测试过公钥登录。"
  prompt_read -p "确认关闭密码登录？[y/N]: " confirm
  case "${confirm}" in
    y|Y)
      apply_password_mode "no" "no" "no" "prohibit-password"
      ok "密码登录已关闭。"
      ;;
    *)
      warn "已取消。"
      ;;
  esac
}

option_enable_password_login() {
  prompt_read -p "确认开启密码登录？[y/N]: " confirm
  case "${confirm}" in
    y|Y)
      apply_password_mode "yes" "yes" "yes" "yes"
      ok "密码登录已开启。"
      ;;
    *)
      warn "已取消。"
      ;;
  esac
}

print_toolbox_menu() {
  clear 2>/dev/null || true
  print_logo
  print_section_title "主菜单"
  say "  密码登录 : $(password_status_text)"
  say "  公钥条数 : $(count_authorized_keys)"
  print_divider
  menu_item "1" "SSH 登录管理"
  menu_item "2" "多协议节点一键搭建"
  menu_item "3" "Docker + NPM 安装 / 容器管理"
  menu_item "4" "Web 网关 / 域名反代"
  menu_item "5" "网络工具 / BBR"
  menu_item "6" "系统工具 / DD"
  menu_item "7" "更新工具箱"
  menu_exit_item
  print_divider
}

docker_npm_menu_loop() {
  local choice=""
  while true; do
    clear 2>/dev/null || true
    print_logo
    print_section_title "Docker + Nginx Proxy Manager"
    print_divider
    menu_item "1" "安装 / 重装 Docker + Nginx Proxy Manager"
    menu_item "2" "查看 Docker 状态"
    menu_item "3" "查看全部容器"
    menu_item "4" "启动全部容器"
    menu_item "5" "停止全部容器"
    menu_item "6" "重启全部容器"
    menu_item "7" "查看容器日志"
    menu_item "8" "Docker system prune"
    menu_back_item
    print_divider
    prompt_read -p "请输入你的选择: " choice
    printf '\n'
    case "${choice}" in
      1) option_run_npm_docker ;;
      2) option_docker_status ;;
      3) option_docker_list_all ;;
      4) option_docker_start_all ;;
      5) option_docker_stop_all ;;
      6) option_docker_restart_all ;;
      7) option_docker_logs ;;
      8) option_docker_prune ;;
      0) return 0 ;;
      *) warn "无效选项，请重新输入。" ;;
    esac
    pause
  done
}

docker_menu_loop() {
  local choice=""
  while true; do
    clear 2>/dev/null || true
    print_logo
    print_section_title "Docker 管理"
    print_divider
    menu_item "1" "查看 Docker 状态"
    menu_item "2" "查看全部容器"
    menu_item "3" "启动全部容器"
    menu_item "4" "停止全部容器"
    menu_item "5" "重启全部容器"
    menu_item "6" "查看容器日志"
    menu_item "7" "Docker system prune"
    menu_back_item
    print_divider
    prompt_read -p "请输入你的选择: " choice
    printf '\n'
    case "${choice}" in
      1) option_docker_status ;;
      2) option_docker_list_all ;;
      3) option_docker_start_all ;;
      4) option_docker_stop_all ;;
      5) option_docker_restart_all ;;
      6) option_docker_logs ;;
      7) option_docker_prune ;;
      0) return 0 ;;
      *) warn "无效选项，请重新输入。" ;;
    esac
    pause
  done
}

firewall_menu_loop() {
  local choice=""
  while true; do
    clear 2>/dev/null || true
    print_logo
    print_section_title "常用端口放行"
    print_divider
    menu_item "1" "放行 SSH (22/tcp)"
    menu_item "2" "放行 HTTP (80/tcp)"
    menu_item "3" "放行 HTTPS (443/tcp)"
    menu_item "4" "一次放行 22/80/443"
    menu_item "5" "放行自定义端口"
    menu_item "6" "查看防火墙状态"
    menu_back_item
    print_divider
    prompt_read -p "请输入你的选择: " choice
    printf '\n'
    case "${choice}" in
      1) allow_firewall_port 22 tcp ;;
      2) allow_firewall_port 80 tcp ;;
      3) allow_firewall_port 443 tcp ;;
      4) option_allow_common_ports ;;
      5) option_allow_custom_port ;;
      6) option_firewall_status ;;
      0) return 0 ;;
      *) warn "无效选项，请重新输入。" ;;
    esac
    pause
  done
}

web_gateway_menu_loop() {
  local choice=""
  while true; do
    clear 2>/dev/null || true
    print_logo
    print_section_title "Web 网关 / 域名反代"
    print_divider
    menu_item "1" "添加 / 更新反代"
    menu_item "2" "查看网关状态"
    menu_back_item
    print_divider
    prompt_read -p "请输入你的选择: " choice
    printf '\n'
    case "${choice}" in
      1) option_web_gateway_add_proxy ;;
      2) option_web_gateway_status ;;
      0) return 0 ;;
      *) warn "无效选项，请重新输入。" ;;
    esac
    pause
  done
}

network_menu_loop() {
  local choice=""
  while true; do
    clear 2>/dev/null || true
    print_logo
    print_section_title "网络工具"
    print_divider
    menu_item "1" "普通内核启用 BBR"
    menu_item "2" "普通内核查看 BBR 状态"
    menu_item "3" "安装 NextTrace"
    menu_item "4" "Ping 测试"
    menu_item "5" "Traceroute / Tracepath"
    menu_item "6" "查看本机路由"
    menu_back_item
    print_divider
    prompt_read -p "请输入你的选择: " choice
    printf '\n'
    case "${choice}" in
      1) option_enable_bbr ;;
      2) option_bbr_info ;;
      3) option_run_nexttrace ;;
      4) option_ping_test ;;
      5) option_trace_test ;;
      6) option_show_ip_route ;;
      0) return 0 ;;
      *) warn "无效选项，请重新输入。" ;;
    esac
    pause
  done
}

system_tools_menu_loop() {
  local choice=""
  while true; do
    clear 2>/dev/null || true
    print_logo
    print_section_title "系统工具"
    print_divider
    menu_item "1" "查看监听端口"
    menu_item "2" "查看高占用进程"
    menu_item "3" "查看常见服务状态"
    menu_item "4" "重启 SSH 服务"
    menu_item "5" "查看最近登录"
    menu_item "6" "重启服务器"
    menu_item "7" "安装 Komari 服务器监控"
    menu_item "8" "DD 重装系统（危险）"
    menu_back_item
    print_divider
    prompt_read -p "请输入你的选择: " choice
    printf '\n'
    case "${choice}" in
      1) option_show_listening_ports ;;
      2) option_show_top_processes ;;
      3) option_show_common_service_status ;;
      4) option_restart_ssh_service ;;
      5) option_recent_logins ;;
      6) option_reboot_server ;;
      7) option_install_komari_server ;;
      8) dd_reinstall_menu_loop ;;
      0) return 0 ;;
      *) warn "无效选项，请重新输入。" ;;
    esac
    pause
  done
}

ssh_menu_loop() {
  local choice=""
  while true; do
    print_ssh_menu
    prompt_read -p "请输入你的选择: " choice
    printf '\n'
    case "${choice}" in
      1) option_generate_keypair ;;
      2) option_manual_key ;;
      3) option_import_github ;;
      4) option_import_url ;;
      5) option_edit_authorized_keys ;;
      6) option_view_local_keys ;;
      7) option_view_authorized_keys ;;
      8) option_disable_password_login ;;
      9) option_enable_password_login ;;
      0) return 0 ;;
      *) warn "无效选项，请重新输入。" ;;
    esac
    pause
  done
}

main_loop() {
  local choice=""
  while true; do
    print_toolbox_menu
    prompt_read -p "请输入你的选择: " choice
    printf '\n'
    case "${choice}" in
      1) ssh_menu_loop ;;
      2) option_run_vless_project ;;
      3) docker_npm_menu_loop ;;
      4) web_gateway_menu_loop ;;
      5) network_menu_loop ;;
      6) system_tools_menu_loop ;;
      7) option_update_toolbox ;;
      0) exit 0 ;;
      *) warn "无效选项，请重新输入。"; pause ;;
    esac
  done
}

main_loop
