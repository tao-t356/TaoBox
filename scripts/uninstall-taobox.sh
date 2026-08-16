#!/usr/bin/env bash

# Remove the TaoBox menu and its launcher without touching services or data
# installed through the menu (Docker, Realm, NPM, VLESS, etc.).
set -u

DEFAULT_TARGET="${HOME:-/root}/ssh-key-menu.sh"
TARGET_PATH="${TAOBOX_TARGET:-${DEFAULT_TARGET}}"
SHORTCUT_NAME="${TAOBOX_SHORTCUT:-f}"
ASSUME_YES=0

usage() {
  cat <<'EOF'
用法:
  bash uninstall-taobox.sh [--target PATH] [--shortcut NAME] [--yes]

说明:
  只删除 TaoBox 菜单脚本、TaoBox 创建的快捷命令和 PATH 配置片段。
  不会删除 Docker、NPM、Realm、VLESS、证书、转发规则或其他业务数据。
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      TARGET_PATH="${2:-}"
      [ -n "${TARGET_PATH}" ] || { echo "--target 需要路径。" >&2; exit 1; }
      shift 2
      ;;
    --shortcut)
      SHORTCUT_NAME="${2:-}"
      [ -n "${SHORTCUT_NAME}" ] || { echo "--shortcut 需要名称。" >&2; exit 1; }
      shift 2
      ;;
    --yes|-y)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

is_taobox_file() {
  local file="$1"
  [ -f "${file}" ] || return 1
  grep -Fqs 'APP_NAME="TaoBox"' "${file}" && \
    grep -Fqs 'REPO_SLUG="tao-t356/TaoBox"' "${file}"
}

remove_file() {
  local file="$1"
  if [ ! -e "${file}" ]; then
    return 0
  fi
  if rm -f -- "${file}"; then
    printf '已删除: %s\n' "${file}"
  else
    printf '删除失败（请使用 root 或 sudo）: %s\n' "${file}" >&2
  fi
}

remove_path_entry() {
  local rc_file="$1"
  local temp_file=""
  local local_bin="${HOME:-/root}/.local/bin"
  [ -f "${rc_file}" ] || return 0
  grep -Fqs '# Added by TaoBox bootstrap' "${rc_file}" || return 0

  temp_file="${rc_file}.taobox-uninstall.$$"
  awk -v local_bin="${local_bin}" '
    /# Added by TaoBox bootstrap/ { skip=1; next }
    skip && $0 == "export PATH=\"" local_bin ":$PATH\"" { skip=0; next }
    skip && /^$/ { skip=0; next }
    { print }
  ' "${rc_file}" > "${temp_file}" || { rm -f -- "${temp_file}"; return 1; }
  if mv -- "${temp_file}" "${rc_file}"; then
    printf '已清理: %s 中的 TaoBox PATH 配置\n' "${rc_file}"
  else
    rm -f -- "${temp_file}"
    return 1
  fi
}

if [ "${ASSUME_YES}" -ne 1 ]; then
  printf '将卸载 TaoBox 菜单本身，但保留所有通过 TaoBox 安装的服务和数据。继续？[y/N]: '
  IFS= read -r answer || answer=""
  case "${answer}" in
    y|Y|yes|YES) ;;
    *) echo '已取消。'; exit 0 ;;
  esac
fi

if ! is_taobox_file "${TARGET_PATH}"; then
  echo "未找到受支持的 TaoBox 菜单脚本: ${TARGET_PATH}" >&2
  echo '为避免误删，未执行任何删除操作。可使用 --target 指定路径。' >&2
  exit 1
fi

shortcut_candidates=()
if [ "$(id -u)" -eq 0 ]; then
  shortcut_candidates+=("/usr/local/bin/${SHORTCUT_NAME}")
fi
shortcut_candidates+=("${HOME:-/root}/.local/bin/${SHORTCUT_NAME}")

for shortcut_path in "${shortcut_candidates[@]}"; do
  if [ -f "${shortcut_path}" ] && grep -Fqs '# Managed by TaoBox bootstrap' "${shortcut_path}" \
    && grep -Fqs "${TARGET_PATH}" "${shortcut_path}"; then
    remove_file "${shortcut_path}"
  fi
done

remove_path_entry "${HOME:-/root}/.bashrc" || \
  echo "清理 PATH 配置失败: ${HOME:-/root}/.bashrc" >&2
remove_file "${TARGET_PATH}"
echo 'TaoBox 卸载完成；已保留 Docker、NPM、Realm、VLESS、证书及其他业务数据。'
