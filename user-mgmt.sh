#!/bin/bash
# user-mgmt.sh — 用户管理统一入口（业务逻辑在 lib/ 与 lib/interactive/）
# -----------------------------------------------------------------------------
# 用法: ./user-mgmt.sh | ./user-mgmt.sh add | ./user-mgmt.sh help
# 加载顺序：config → JSON 合并 → 解析 → ops(create/delete) → lib/interactive（sync 须在 user 菜单前加载）
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/json_user_state.sh
source "$SCRIPT_DIR/lib/json_user_state.sh"
# shellcheck source=lib/user_json_parse.sh
source "$SCRIPT_DIR/lib/user_json_parse.sh"
# shellcheck source=lib/stub_unmanaged_user.sh
source "$SCRIPT_DIR/lib/stub_unmanaged_user.sh"
# shellcheck source=lib/ops/create_user.sh
source "$SCRIPT_DIR/lib/ops/create_user.sh"
# shellcheck source=lib/ops/delete_user.sh
source "$SCRIPT_DIR/lib/ops/delete_user.sh"
# shellcheck source=lib/interactive/cmd_add_user.sh
source "$SCRIPT_DIR/lib/interactive/cmd_add_user.sh"
# shellcheck source=lib/interactive/menu_user_lists.sh
source "$SCRIPT_DIR/lib/interactive/menu_user_lists.sh"
# shellcheck source=lib/interactive/cmd_user_sync_and_sudo.sh
source "$SCRIPT_DIR/lib/interactive/cmd_user_sync_and_sudo.sh"
# shellcheck source=lib/interactive/menu_user_actions.sh
source "$SCRIPT_DIR/lib/interactive/menu_user_actions.sh"
# shellcheck source=lib/interactive/menu_main.sh
source "$SCRIPT_DIR/lib/interactive/menu_main.sh"

mkdir -p "$MANAGED_USERS_DIR"

case "${1:-}" in
    add)            cmd_add ;;
    help|--help|-h) show_help ;;
    *)              interactive_menu ;;
esac
