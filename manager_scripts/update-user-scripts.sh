#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANAGED_USERS_DIR="$PROJECT_ROOT/managed_users"
SCRIPTS_SRC="$PROJECT_ROOT/user_scripts"

echo "=========================================="
echo "         更新用户 scripts"
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
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    printf "  %d) %s (%s)\n" "$i" "$username" "$home_dir"
    users+=("$username")
    ((i++))
done
echo

read -p "选择要更新的用户编号 (多个用空格分隔): " choices
read -p "确认更新？[y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

for choice in $choices; do
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
        echo "无效选择: $choice"
        continue
    fi
    
    username="${users[$((choice-1))]}"
    json_file="$MANAGED_USERS_DIR/${username}.json"
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    
    echo
    echo "更新 $username ..."

    sudo rm -rf "$home_dir/scripts"
    sudo cp -r "$SCRIPTS_SRC" "$home_dir/scripts"
    sudo chown -R "$username:$username" "$home_dir/scripts"
    
    echo "✅ $username 已更新"
done

echo
echo "完成"
