# lib/proxy_block.sh — proxy 段读写薄壳（兼容老调用方）
# -----------------------------------------------------------------------------
# 实现位于 lib/install_steps/proxy_bashrc.sh，本壳仅转发。
# 依赖：lib/anchors.sh、lib/install_steps.sh + step 文件已 source
# -----------------------------------------------------------------------------

_um_proxy_block_strip() {
    local bashrc="$1"
    local username="${2:-}"
    local home
    home="$(dirname "$bashrc")"
    if declare -F um_step_proxy_bashrc_remove &>/dev/null; then
        um_step_proxy_bashrc_remove "$username" "$home"
    else
        _um_anchor_strip "$bashrc" "proxy_bashrc" "#" "$username"
    fi
}

_um_proxy_block_write() {
    local bashrc="$1"
    local username="$2"
    local home
    home="$(dirname "$bashrc")"
    if declare -F um_step_proxy_bashrc_apply &>/dev/null; then
        um_step_proxy_bashrc_apply "$username" "$home"
    else
        echo "错误: proxy_bashrc step 未加载" >&2
        return 1
    fi
}
