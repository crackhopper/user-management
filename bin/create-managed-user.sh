#!/bin/bash
# bin/create-managed-user.sh — 入口脚本：复用 lib/interactive/cmd_add_user.sh::cmd_add
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/lib/bootstrap.sh"
um_bootstrap "${BASH_SOURCE[0]}" \
    json_io \
    anchors \
    proxy_block \
    group_ops \
    install_steps \
    ops/create_user \
    interactive/prompts \
    interactive/cmd_add_user

_um_steps_load
mkdir -p "$MANAGED_USERS_DIR"
cmd_add
