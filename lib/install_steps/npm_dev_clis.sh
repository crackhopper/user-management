# lib/install_steps/npm_dev_clis.sh — npm 全局 dev CLI 集合
# 默认包：codex / opencode / cursor-cli
# 包名易变；如需调整修改 NPM_DEV_PACKAGES 数组即可
# 依赖：用户登录 shell 中可访问 npm（建议先装 nvm+node，例如 templates/setup-dev-env.sh）
# -----------------------------------------------------------------------------

UM_STEPS+=(npm_dev_clis)

NPM_DEV_PACKAGES=(
    "@openai/codex"
    "opencode-ai"
    "@anthropic-ai/claude-code"
    "@fission-ai/openspec"
)

um_step_npm_dev_clis_label()   { echo "npm 全局 CLI：${NPM_DEV_PACKAGES[*]}"; }
um_step_npm_dev_clis_default() { echo "true"; }

# 用户登录 shell 中执行（继承 nvm/node PATH）
_um_step_npm_dev_clis_user_sh() {
    _um_user_sh "$@"
}

um_step_npm_dev_clis_status() {
    local user="$1"
    if ! _um_step_npm_dev_clis_user_sh "$user" 'command -v npm' &>/dev/null; then
        echo false; return 0
    fi
    local listing pkg
    listing="$(_um_step_npm_dev_clis_user_sh "$user" 'npm list -g --depth=0 2>/dev/null' || true)"
    for pkg in "${NPM_DEV_PACKAGES[@]}"; do
        grep -qF -- "$pkg" <<<"$listing" || { echo false; return 0; }
    done
    echo true
}

um_step_npm_dev_clis_apply() {
    local user="$1"

    # 1. 探测；npm 缺则自动装 nvm + Node LTS
    if ! _um_step_npm_dev_clis_user_sh "$user" 'command -v npm' &>/dev/null; then
        echo "npm 不可用，自动安装 nvm + Node LTS ..." >&2
        _um_step_npm_dev_clis_user_sh "$user" '
            set -e
            unset NVM_DIR
            if [ ! -d "$HOME/.nvm" ]; then
                curl -fsSL -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
            fi
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
            if ! command -v node >/dev/null 2>&1; then
                nvm install --lts
                nvm use --lts
                nvm alias default node
            fi
        ' || true
    fi

    # 2. 重新探测
    if ! _um_step_npm_dev_clis_user_sh "$user" 'command -v npm' &>/dev/null; then
        echo "跳过 npm_dev_clis：$user 仍找不到 npm（请手工跑 ~/scripts/setup-dev-env.sh）" >&2
        return 1
    fi

    # 3. 装包
    local pkgs="${NPM_DEV_PACKAGES[*]}"
    _um_step_npm_dev_clis_user_sh "$user" "npm install -g $pkgs"
}

um_step_npm_dev_clis_remove() {
    local user="$1"
    _um_step_npm_dev_clis_user_sh "$user" 'command -v npm' &>/dev/null || return 0
    local pkgs="${NPM_DEV_PACKAGES[*]}"
    _um_step_npm_dev_clis_user_sh "$user" "npm uninstall -g $pkgs" || true
}
