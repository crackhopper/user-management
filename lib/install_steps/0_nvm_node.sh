# lib/install_steps/0_nvm_node.sh — nvm + Node LTS（用户级）
# 文件名 0_ 前缀让其先于 npm_dev_clis 被询问
# step key 仍为 nvm_node
# -----------------------------------------------------------------------------

UM_STEPS+=(nvm_node)

NVM_VERSION="v0.40.3"

um_step_nvm_node_label()   { echo "nvm + Node LTS（用户级）"; }
um_step_nvm_node_default() { echo "true"; }

_um_step_nvm_user_sh() {
    _um_user_sh "$@"
}

um_step_nvm_node_status() {
    local user="$1"
    _um_step_nvm_user_sh "$user" '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
    ' &>/dev/null && echo true || echo false
}

um_step_nvm_node_apply() {
    local user="$1"
    _um_step_nvm_user_sh "$user" "
        set -e
        unset NVM_DIR
        if [ ! -d \"\$HOME/.nvm\" ]; then
            curl -fsSL -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
        fi
        export NVM_DIR=\"\$HOME/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        if ! command -v node >/dev/null 2>&1; then
            nvm install --lts
            nvm use --lts
            nvm alias default node
        fi
    "
}

um_step_nvm_node_remove() {
    local user="$1"
    sudo -u "$user" -- bash -c 'rm -rf "$HOME/.nvm"' || true
    echo "已删除 ~/.nvm；.bashrc 中 NVM 加载行需手工清理（搜索 NVM_DIR）" >&2
}
