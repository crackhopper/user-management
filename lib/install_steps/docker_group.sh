# lib/install_steps/docker_group.sh — usermod -aG docker
# 依赖：_um_group_remove_user（lib/group_ops.sh，可选）
# -----------------------------------------------------------------------------

UM_STEPS+=(docker_group)

um_step_docker_group_label()   { echo "加入 docker 组"; }
um_step_docker_group_default() { echo "true"; }

um_step_docker_group_status() {
    local user="$1"
    if id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
        echo true
    else
        echo false
    fi
}

um_step_docker_group_apply() {
    local user="$1"
    sudo usermod -aG docker "$user"
}

um_step_docker_group_remove() {
    local user="$1"
    if declare -F _um_group_remove_user &>/dev/null; then
        _um_group_remove_user "$user" docker
    fi
}
