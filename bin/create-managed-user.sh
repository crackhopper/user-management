#!/bin/bash
set -euo pipefail

_bin_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/paths.sh
source "$_bin_here/../lib/paths.sh"
SCRIPT_DIR="$(um_project_root_from_bin_path "${BASH_SOURCE[0]}")"
# shellcheck source=../lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=../lib/ops/create_user.sh
source "$SCRIPT_DIR/lib/ops/create_user.sh"

available_ips=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.')
ssh_port=$(grep ^Port /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")

echo "=========================================="
echo "         用户创建脚本"
echo "=========================================="
echo

read -p "用户名: " username
while [[ -z "$username" ]]; do
    echo "用户名不能为空"
    read -p "用户名: " username
done

read -p "初始密码: " password
while [[ -z "$password" ]]; do
    echo "密码不能为空"
    read -p "初始密码: " password
done

default_home="${UM_HOME_PARENT:-/home}/$username"
read -p "home目录 [$default_home]: " home_dir
home_dir="${home_dir:-$default_home}"

read -p "是否有sudo权限 [y/N]: " has_sudo
has_sudo_flag=false
if [[ "$has_sudo" =~ ^[Yy]$ ]]; then
    has_sudo_flag=true
fi

read -p "是否有docker权限 [y/N]: " has_docker
has_docker_flag=false
if [[ "$has_docker" =~ ^[Yy]$ ]]; then
    has_docker_flag=true
fi

echo "authorized_keys (单行公钥，输入完按回车):"
read -p "> " authorized_keys

default_key_type="$(_um_default_key_type_from_authorized_keys "$authorized_keys")"
echo "私钥文件名 [默认 $default_key_type (推测)]:"
read -p "> " key_type
key_type="${key_type:-$default_key_type}"
key_type_inferred=$([[ "$key_type" == "$default_key_type" ]] && echo "true" || echo "false")

echo "选择登录IP:"
select ip in $available_ips; do
    if [[ -n "$ip" ]]; then
        selected_ip="$ip"
        break
    fi
done

if id "$username" &>/dev/null; then
    echo "用户 $username 已存在，退出"
    exit 1
fi

um_create_managed_user "$username" "$password" "$home_dir" "$has_sudo_flag" "$has_docker_flag" \
    "$authorized_keys" "$key_type" "$key_type_inferred" "$selected_ip" "$ssh_port"

echo
echo "=========================================="
echo "         创建完成"
echo "=========================================="
echo
echo "--- SSH Config (复制到本地 ~/.ssh/config) ---"
echo "$UM_SSH_CONFIG_SNIPPET"
echo "------------------------------------------"
echo

echo "用户信息已保存: $UM_CREATED_JSON_FILE"
