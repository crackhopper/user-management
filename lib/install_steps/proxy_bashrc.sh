# lib/install_steps/proxy_bashrc.sh — ~/.bashrc 中 proxy 段（templates/proxy.sh）
# 依赖：SCRIPTS_SRC、UM_CONFIGURE_PROXY_DEFAULT、_um_anchor_*
# 锚点名：proxy_bashrc
# 兼容旧锚点：含 "(templates/proxy.sh)" 后缀，strip 时一并清理
# -----------------------------------------------------------------------------

UM_STEPS+=(proxy_bashrc)

um_step_proxy_bashrc_label()   { echo "在 ~/.bashrc 写入 proxy 段（templates/proxy.sh）"; }
um_step_proxy_bashrc_default() { echo "${UM_CONFIGURE_PROXY_DEFAULT:-false}"; }

um_step_proxy_bashrc_status() {
    local home="$2"
    _um_anchor_present "$home/.bashrc" "proxy_bashrc"
}

_um_step_proxy_bashrc_strip_legacy() {
    local home="$1" user="$2"
    sudo test -f "$home/.bashrc" || return 0
    sudo sed -i '\|# BEGIN user_management proxy (templates/proxy.sh)|,|# END user_management proxy|d' "$home/.bashrc"
    sudo chown "$user:$user" "$home/.bashrc"
}

um_step_proxy_bashrc_apply() {
    local user="$1" home="$2"
    [[ -f "$SCRIPTS_SRC/proxy.sh" ]] || { echo "跳过：找不到 $SCRIPTS_SRC/proxy.sh" >&2; return 0; }
    _um_step_proxy_bashrc_strip_legacy "$home" "$user"
    cat "$SCRIPTS_SRC/proxy.sh" | _um_anchor_write "$home/.bashrc" "proxy_bashrc" "$user"
}

um_step_proxy_bashrc_remove() {
    local user="$1" home="$2"
    _um_step_proxy_bashrc_strip_legacy "$home" "$user"
    _um_anchor_strip "$home/.bashrc" "proxy_bashrc" "#" "$user"
}
