#!/bin/bash
set -euo pipefail

MANAGED_USERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/managed_users"

echo "=========================================="
echo "         删除用户"
echo "=========================================="
echo

if [[ ! -d "$MANAGED_USERS_DIR" ]] || [[ -z "$(ls -A "$MANAGED_USERS_DIR" 2>/dev/null)" ]]; then
    echo "暂无管理用户"
    exit 0
fi

echo "可删除的用户:"
echo
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

read -p "选择要删除的用户编号: " choice
if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
    echo "无效选择"
    exit 1
fi

username="${users[$((choice-1))]}"
json_file="$MANAGED_USERS_DIR/${username}.json"

echo
echo "用户信息:"
cat "$json_file"
echo

read -p "确认删除用户 $username ？[y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

read -p "是否保留 home 目录 [$home_dir]？[y/N]: " keep_home
if [[ "$keep_home" =~ ^[Yy]$ ]]; then
    sudo userdel "$username"
    echo "已删除用户，home 目录已保留"
else
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    sudo userdel -r "$username"
    echo "已删除用户及 home 目录"
fi

sudo rm -f "/etc/sudoers.d/$username"
rm -f "$json_file"

echo
echo "用户 $username 已删除"
