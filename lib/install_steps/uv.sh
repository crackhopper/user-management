# lib/install_steps/uv.sh — pipx 装 uv（Python 包/项目管理）
# 依赖：pipx_runtime（系统 pipx）；缺时 apply 会先尝试 system 装 pipx
# -----------------------------------------------------------------------------

UM_STEPS+=(uv)

UV_PIPX_PIP_ARGS="--index-url https://pypi.tuna.tsinghua.edu.cn/simple"

um_step_uv_label()   { echo "pipx 装 uv（Python 包管理；清华源）"; }
um_step_uv_default() { echo "true"; }

_um_step_uv_user_sh() {
    _um_user_sh "$@"
}

um_step_uv_status() {
    local user="$1"
    _um_step_uv_user_sh "$user" 'command -v uv' &>/dev/null && echo true || echo false
}

um_step_uv_apply() {
    local user="$1"

    if ! _um_step_uv_user_sh "$user" 'command -v pipx' &>/dev/null; then
        echo "uv 依赖 pipx；尝试系统级安装 ..." >&2
        if declare -F um_step_pipx_runtime_apply &>/dev/null; then
            um_step_pipx_runtime_apply "$user" || true
        fi
    fi

    if ! _um_step_uv_user_sh "$user" 'command -v pipx' &>/dev/null; then
        echo "跳过 uv：仍找不到 pipx" >&2
        return 1
    fi

    _um_step_uv_user_sh "$user" "pipx install uv --pip-args=\"$UV_PIPX_PIP_ARGS\""
}

um_step_uv_remove() {
    local user="$1"
    _um_step_uv_user_sh "$user" 'command -v pipx' &>/dev/null || return 0
    _um_step_uv_user_sh "$user" 'pipx uninstall uv' || true
}
