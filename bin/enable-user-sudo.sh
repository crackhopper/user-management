#!/bin/bash
set -euo pipefail

_bin_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/paths.sh
source "$_bin_here/../lib/paths.sh"
SCRIPT_DIR="$(um_project_root_from_bin_path "${BASH_SOURCE[0]}")"
# shellcheck source=../lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

echo "=========================================="
echo "         启用 sudo 权限"
echo "=========================================="
echo

if [[ ! -d "$MANAGED_USERS_DIR" ]] || [[ -z "$(ls -A "$MANAGED_USERS_DIR" 2>/dev/null)" ]]; then
    echo "暂无管理用户"
    exit 0
fi

i=1
users=()
for json_file in "$MANAGED_USERS_DIR"/*.json; do
    [[ -e "$json_file" ]] || continue
    username=$(basename "$json_file" .json)
    printf "  %d) %s\n" "$i" "$username"
    users+=("$username")
    ((i++))
done
echo

read -p "选择要启用 sudo 的用户编号: " choice
if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
    echo "无效选择"
    exit 1
fi

username="${users[$((choice-1))]}"

echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$username" > /dev/null
sudo chmod 440 "/etc/sudoers.d/$username"

echo "已启用用户 $username 的 sudo（NOPASSWD：/etc/sudoers.d/$username；未加入 sudo 组）"
