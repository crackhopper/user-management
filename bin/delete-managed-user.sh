#!/bin/bash
# bin/delete-managed-user.sh — 交互式选择并删除托管用户
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/lib/bootstrap.sh"
um_bootstrap "${BASH_SOURCE[0]}" ops/delete_user

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

home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')

read -p "确认删除用户 $username ？[y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

read -p "是否保留 home 目录 [$home_dir]？[y/N]: " keep_home
keep_home_flag=false
if [[ "$keep_home" =~ ^[Yy]$ ]]; then
    keep_home_flag=true
    echo "将删除用户，home 目录已保留"
else
    echo "将删除用户及 home 目录"
fi

um_delete_managed_user "$username" "$keep_home_flag" "$json_file"

echo
echo "用户 $username 已删除"
