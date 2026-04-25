# lib/install_steps/sudoers.sh — /etc/sudoers.d/<user>
# 默认 NOPASSWD；调用方 export UM_SUDO_REQUIRE_PASSWORD=true 时改为「需密码」
# 依赖：_um_group_remove_user（lib/group_ops.sh，可选；缺失时 remove 仅删文件）
# 不加入系统 sudo 组；只管理 drop-in 文件。
# -----------------------------------------------------------------------------

UM_STEPS+=(sudoers)

um_step_sudoers_label()   { echo "/etc/sudoers.d/<user>（NOPASSWD 或 require password）"; }
um_step_sudoers_default() { echo "false"; }

um_step_sudoers_status() {
    local user="$1"
    sudo test -f "/etc/sudoers.d/$user" && echo true || echo false
}

um_step_sudoers_apply() {
    local user="$1"
    local rule
    if [[ "${UM_SUDO_REQUIRE_PASSWORD:-false}" == "true" ]]; then
        rule="$user ALL=(ALL) ALL"
    else
        rule="$user ALL=(ALL) NOPASSWD: ALL"
    fi
    echo "$rule" | sudo tee "/etc/sudoers.d/$user" > /dev/null
    sudo chmod 440 "/etc/sudoers.d/$user"
}

um_step_sudoers_remove() {
    local user="$1"
    sudo rm -f "/etc/sudoers.d/$user"
    if declare -F _um_group_remove_user &>/dev/null; then
        _um_group_remove_user "$user" sudo
    fi
}

# _um_step_sudoers_mode <user> -> nopasswd | password | none
um_step_sudoers_mode() {
    local user="$1"
    local f="/etc/sudoers.d/$user"
    if ! sudo test -f "$f"; then
        echo none; return 0
    fi
    if sudo grep -q 'NOPASSWD' "$f"; then
        echo nopasswd
    else
        echo password
    fi
}
