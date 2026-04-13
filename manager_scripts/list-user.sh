#!/bin/bash
set -euo pipefail

MANAGED_USERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/managed_users"

echo "=========================================="
echo "         用户列表"
echo "=========================================="
echo

if [[ ! -d "$MANAGED_USERS_DIR" ]] || [[ -z "$(ls -A "$MANAGED_USERS_DIR" 2>/dev/null)" ]]; then
    echo "暂无管理用户"
    exit 0
fi

printf "%-15s %-25s %-10s %-10s %s\n" "用户名" "home目录" "sudo" "docker" "创建时间"
echo "---------------------------------------------------------------"

for json_file in "$MANAGED_USERS_DIR"/*.json; do
    [[ -e "$json_file" ]] || continue
    username=$(basename "$json_file" .json)
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    has_sudo=$(grep '"sudo"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/')
    has_docker=$(grep '"docker"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/')
    created_at=$(grep '"created_at"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    
    printf "%-15s %-25s %-10s %-10s %s\n" "$username" "$home_dir" "$has_sudo" "$has_docker" "$created_at"
done
