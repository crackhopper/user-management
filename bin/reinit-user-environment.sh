#!/bin/bash
set -euo pipefail

_bin_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/paths.sh
source "$_bin_here/../lib/paths.sh"
SCRIPT_DIR="$(um_project_root_from_bin_path "${BASH_SOURCE[0]}")"
# shellcheck source=../lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=../lib/json_user_state.sh
source "$SCRIPT_DIR/lib/json_user_state.sh"

usage() {
    echo "用法: $0 [选项]"
    echo "  无参数：交互式从 managed_users 列出用户，选择编号后重新初始化："
    echo "  - 将 templates 同步到 ~/scripts（覆盖旧内容）"
    echo "  - 更新 ~/.bashrc 中 user_management proxy 段（与当前 proxy.sh 一致）"
    echo "  - 按系统状态刷新 JSON（sudo_group / sudo_sudoers / docker、last_synced 等）"
    echo
    echo "选项:"
    echo "  --all --yes    对全部已管理用户执行上述步骤（非交互，需同时指定 --yes）"
    echo "  -h, --help     显示本说明"
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
            sudo sed -i '\|# BEGIN user_management proxy (templates/proxy.sh)|,|# END user_management proxy|d' "$bashrc"
        else
            sudo touch "$bashrc"
            sudo chown "$username:$username" "$bashrc"
        fi
        {
            echo ""
            echo "# BEGIN user_management proxy (templates/proxy.sh)"
            cat "$SCRIPTS_SRC/proxy.sh"
            echo "# END user_management proxy"
        } | sudo tee -a "$bashrc" > /dev/null
        sudo chown "$username:$username" "$bashrc"
    else
        echo "跳过 proxy（未找到 $SCRIPTS_SRC/proxy.sh）"
    fi
}

DO_ALL=false
ASSUME_YES=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) DO_ALL=true; shift ;;
        --yes) ASSUME_YES=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "未知选项: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ "$DO_ALL" == true ]] && [[ "$ASSUME_YES" != true ]]; then
    echo "错误: --all 必须与 --yes 同时使用。" >&2
    exit 1
fi

echo "=========================================="
echo "         重新初始化用户环境"
echo "=========================================="
echo

if [[ ! -d "$MANAGED_USERS_DIR" ]] || [[ -z "$(ls -A "$MANAGED_USERS_DIR" 2>/dev/null)" ]]; then
    echo "暂无管理用户"
    exit 0
fi

users=()
for json_file in "$MANAGED_USERS_DIR"/*.json; do
    [[ -e "$json_file" ]] || continue
    users+=("$(basename "$json_file" .json)")
done

if [[ "$DO_ALL" == true ]]; then
    for username in "${users[@]}"; do
        json_file="$MANAGED_USERS_DIR/${username}.json"
        home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
        if ! id "$username" &>/dev/null; then
            echo "跳过: 系统用户不存在: $username"
            continue
        fi
        echo
        echo ">>> $username ($home_dir) ..."
        reinit_one "$username" "$home_dir"
        _merge_json_sudo_from_system "$json_file" "$username" sync
        echo "✅ $username 已重新初始化并已刷新 JSON"
    done
    echo
    echo "完成。"
    exit 0
fi

i=1
for username in "${users[@]}"; do
    json_file="$MANAGED_USERS_DIR/${username}.json"
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    printf "  %d) %s (%s)\n" "$i" "$username" "$home_dir"
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
    _merge_json_sudo_from_system "$json_file" "$username" sync
    echo "✅ $username 已重新初始化并已刷新 JSON"
done

echo
echo "完成。"
