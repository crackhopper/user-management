#!/bin/bash
# 集成测试：创建托管用户、校验文件与 JSON、删除（需 root 或免密 sudo）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ "${UM_SKIP_INTEGRATION:-}" == "1" ]]; then
    echo "SKIP: UM_SKIP_INTEGRATION=1"
    exit 0
fi

if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo "FAIL: 需要 root 或免密 sudo 才能运行集成测试"
    exit 1
fi

# shellcheck source=../../lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=../../lib/json_io.sh
source "$SCRIPT_DIR/lib/json_io.sh"
# shellcheck source=../../lib/anchors.sh
source "$SCRIPT_DIR/lib/anchors.sh"
# shellcheck source=../../lib/proxy_block.sh
source "$SCRIPT_DIR/lib/proxy_block.sh"
# shellcheck source=../../lib/group_ops.sh
source "$SCRIPT_DIR/lib/group_ops.sh"
# shellcheck source=../../lib/install_steps.sh
source "$SCRIPT_DIR/lib/install_steps.sh"
_um_steps_load
# shellcheck source=../../lib/ops/create_user.sh
source "$SCRIPT_DIR/lib/ops/create_user.sh"
# shellcheck source=../../lib/ops/delete_user.sh
source "$SCRIPT_DIR/lib/ops/delete_user.sh"

_fail() {
    echo "FAIL: $*"
    exit 1
}

_assert_file() {
    [[ -f "$1" ]] || _fail "missing file: $1"
}

# 其他用户 home 常为 700，非 root 无法直接 stat，须用 sudo 检查
_assert_dir() {
    sudo test -d "$1" || _fail "missing dir: $1"
}

TEST_USER="umtest_${RANDOM}_$$"
TEST_PASS="t$(openssl rand -hex 8)"
FAKE_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGintegration-test-dummy-key integration@test"
KEY_TYPE="id_ed25519"
KEY_INF="true"
SSH_PORT=$(grep ^Port /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
SELECTED_IP="127.0.0.1"
HOME_DIR="${UM_HOME_PARENT:-/home}/$TEST_USER"
HAS_SUDO="false"
HAS_DOCKER="false"
DEPLOY_SCRIPTS="true"
CONFIGURE_PROXY="false"
USER_COMMENT="integration-test"
LOGIN_SHELL="/bin/bash"
JUMP_TO_TARGETS="localhost"

cleanup() {
    if id "$TEST_USER" &>/dev/null; then
        um_delete_managed_user "$TEST_USER" "false" "$MANAGED_USERS_DIR/${TEST_USER}.json" 2>/dev/null || true
    fi
    rm -f "$MANAGED_USERS_DIR/${TEST_USER}.json" 2>/dev/null || true
}
trap cleanup EXIT

echo ">>> create $TEST_USER ..."
UM_STEPS_EXTRA="jump_to" \
UM_JUMP_TO_TARGETS="$JUMP_TO_TARGETS" \
UM_JUMP_TO_SKIP_REMOTE="true" \
    um_create_managed_user "$TEST_USER" "$TEST_PASS" "$HOME_DIR" "$HAS_SUDO" "$HAS_DOCKER" \
        "$FAKE_PUB" "$KEY_TYPE" "$KEY_INF" "$SELECTED_IP" "$SSH_PORT" "$DEPLOY_SCRIPTS" "$CONFIGURE_PROXY" \
        "$USER_COMMENT" "$LOGIN_SHELL"

[[ -n "$UM_CREATED_JSON_FILE" ]] || _fail "UM_CREATED_JSON_FILE empty"
[[ -f "$UM_CREATED_JSON_FILE" ]] || _fail "json not created: $UM_CREATED_JSON_FILE"

id "$TEST_USER" &>/dev/null || _fail "system user missing"
_assert_dir "$HOME_DIR/scripts"
sudo test -f "$HOME_DIR/.ssh/config" || _fail "missing file: $HOME_DIR/.ssh/config"
sudo grep -q "Host um-jump-localhost" "$HOME_DIR/.ssh/config" || _fail "jump-to ssh config"
sudo grep -q "alias jump-to='__um_jump_to'" "$HOME_DIR/.bashrc" || _fail "jump-to bashrc alias"
grep -q "\"username\": \"$TEST_USER\"" "$UM_CREATED_JSON_FILE" || _fail "username in json"
grep -q '"managed": true' "$UM_CREATED_JSON_FILE" || _fail "managed flag"
grep -q '"jump_to_sites": \[' "$UM_CREATED_JSON_FILE" || _fail "jump_to_sites field"

echo ">>> delete $TEST_USER ..."
trap - EXIT
um_delete_managed_user "$TEST_USER" "false" "$UM_CREATED_JSON_FILE"

id "$TEST_USER" &>/dev/null && _fail "user still exists"
[[ ! -f "$MANAGED_USERS_DIR/${TEST_USER}.json" ]] || _fail "json still present"

echo "OK: user lifecycle integration test passed"
