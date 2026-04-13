#!/bin/bash
set -euo pipefail

_bin_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/paths.sh
source "$_bin_here/../lib/paths.sh"
SCRIPT_DIR="$(um_project_root_from_bin_path "${BASH_SOURCE[0]}")"
# shellcheck source=../lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

echo "=========================================="
echo "         用户列表"
echo "=========================================="
echo

if [[ ! -d "$MANAGED_USERS_DIR" ]] || [[ -z "$(ls -A "$MANAGED_USERS_DIR" 2>/dev/null)" ]]; then
    echo "暂无管理用户"
    exit 0
fi

printf "%-12s %-22s %-8s %-10s %-8s %s\n" "用户名" "home目录" "sudo组" "sudoers" "docker" "创建时间"
echo "----------------------------------------------------------------------------------"

for json_file in "$MANAGED_USERS_DIR"/*.json; do
    [[ -e "$json_file" ]] || continue
    username=$(basename "$json_file" .json)
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    sudo_group=$(grep '"sudo_group"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
    sudo_sudoers=$(grep '"sudo_sudoers"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
    if [[ -z "$sudo_group" ]] && [[ -z "$sudo_sudoers" ]]; then
        legacy=$(grep '"sudo"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
        if [[ -n "$legacy" ]]; then
            sudo_group="$legacy"
            sudo_sudoers="false"
        else
            sudo_group="false"
            sudo_sudoers="false"
        fi
    fi
    [[ -z "$sudo_group" ]] && sudo_group="false"
    [[ -z "$sudo_sudoers" ]] && sudo_sudoers="false"
    has_docker=$(grep '"docker"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/')
    created_at=$(grep '"created_at"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')

    printf "%-12s %-22s %-8s %-10s %-8s %s\n" "$username" "$home_dir" "$sudo_group" "$sudo_sudoers" "$has_docker" "$created_at"
done
