#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_SRC="$PROJECT_ROOT/user_scripts"
MANAGED_USERS_DIR="$PROJECT_ROOT/managed_users"

if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

usage() {
    echo "用法: $0"
    echo "  从 managed_users 列出用户，选择编号后重新初始化："
    echo "  - 将 user_scripts 同步到 ~/scripts（覆盖旧内容）"
    echo "  - 更新 ~/.bashrc 中 user_management proxy 段（与当前 proxy.sh 一致）"
}

reinit_one() {
    local username="$1"
    local home_dir="$2"

    echo "同步 $SCRIPTS_SRC -> $home_dir/scripts ..."
    sudo rm -rf "$home_dir/scripts"
    sudo cp -r "$SCRIPTS_SRC" "$home_dir/scripts"
    sudo chown -R "$username:$username" "$home_dir/scripts"

    local bashrc="$home_dir/.bashrc"
    if [[ -f "$SCRIPTS_SRC/proxy.sh" ]]; then
        echo "更新 $bashrc 中的 proxy 段 ..."
        if [[ -f "$bashrc" ]]; then
            sudo sed -i '\|# BEGIN user_management proxy (user_scripts/proxy.sh)|,|# END user_management proxy|d' "$bashrc"
        else
            sudo touch "$bashrc"
            sudo chown "$username:$username" "$bashrc"
        fi
        {
            echo ""
            echo "# BEGIN user_management proxy (user_scripts/proxy.sh)"
            cat "$SCRIPTS_SRC/proxy.sh"
            echo "# END user_management proxy"
        } | sudo tee -a "$bashrc" > /dev/null
        sudo chown "$username:$username" "$bashrc"
    else
        echo "跳过 proxy（未找到 $SCRIPTS_SRC/proxy.sh）"
    fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

echo "=========================================="
echo "         重新初始化用户环境"
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

read -p "选择要重新初始化的用户编号 (多个用空格分隔): " choices
read -p "确认执行？[y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

for choice in $choices; do
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
        echo "无效选择: $choice"
        continue
    fi

    username="${users[$((choice - 1))]}"
    json_file="$MANAGED_USERS_DIR/${username}.json"
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')

    if ! id "$username" &>/dev/null; then
        echo "跳过: 系统用户不存在: $username"
        continue
    fi

    echo
    echo ">>> $username ($home_dir) ..."
    reinit_one "$username" "$home_dir"
    echo "✅ $username 已重新初始化"
done

echo
echo "完成。"
