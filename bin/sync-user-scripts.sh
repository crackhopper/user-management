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
    echo "  无参数：交互式选择用户，将 templates/ 覆盖复制到其 ~/scripts/"
    echo "  复制后会按系统状态刷新该用户 JSON（sudo / docker、last_synced 等）。"
    echo
    echo "选项:"
    echo "  --all --yes    对全部已管理用户执行（非交互，需同时指定 --yes）"
    echo "  -h, --help     显示本说明"
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
echo "         更新用户 scripts"
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

sync_scripts_for_user() {
    local username="$1"
    local json_file="$2"
    local home_dir="$3"

    if ! id "$username" &>/dev/null; then
        echo "跳过: 系统用户不存在: $username"
        return 0
    fi

    echo
    echo "更新 $username ..."

    sudo rm -rf "$home_dir/scripts"
    sudo cp -r "$SCRIPTS_SRC" "$home_dir/scripts"
    sudo chown -R "$username:$username" "$home_dir/scripts"

    _merge_json_sudo_from_system "$json_file" "$username" sync

    echo "✅ $username 已更新并已刷新 JSON"
}

if [[ "$DO_ALL" == true ]]; then
    for username in "${users[@]}"; do
        json_file="$MANAGED_USERS_DIR/${username}.json"
        home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
        sync_scripts_for_user "$username" "$json_file" "$home_dir"
    done
    echo
    echo "完成"
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

    username="${users[$((choice - 1))]}"
    json_file="$MANAGED_USERS_DIR/${username}.json"
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')

    sync_scripts_for_user "$username" "$json_file" "$home_dir"
done

echo
echo "完成"
