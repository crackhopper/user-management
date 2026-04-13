# lib/interactive/cmd_add_user.sh — 交互式创建系统用户并写入 managed_users JSON
# -----------------------------------------------------------------------------
# 依赖：MANAGED_USERS_DIR、SCRIPTS_SRC、HOST_NAME、um_create_managed_user（lib/ops/create_user.sh）
# cmd_add：问答 -> um_create_managed_user
# sudo 策略：仅 /etc/sudoers.d/<user>，不加入 sudo 组（sudo_group=false, sudo_sudoers=选择）
# -----------------------------------------------------------------------------

# cmd_add — 创建用户主流程（无参数；依赖全局路径变量）
cmd_add() {
    echo "=========================================="
    echo "         创建用户"
    echo "=========================================="
    echo "(按 ESC 返回主菜单)"
    echo

    read -p "用户名: " username
    [[ "$username" == $'\e' ]] && return
    while [[ -z "$username" ]]; do
        echo "用户名不能为空"
        read -p "用户名: " username
        [[ "$username" == $'\e' ]] && return
    done

    read -p "初始密码: " password
    [[ "$password" == $'\e' ]] && return
    while [[ -z "$password" ]]; do
        echo "密码不能为空"
        read -p "初始密码: " password
        [[ "$password" == $'\e' ]] && return
    done

    default_home="${UM_HOME_PARENT:-/home}/$username"
    read -p "home目录 [$default_home]: " home_dir
    [[ "$home_dir" == $'\e' ]] && return
    home_dir="${home_dir:-$default_home}"

    local deploy_scripts_default="y"
    if [[ "${UM_DEPLOY_SCRIPTS_DEFAULT:-true}" != "true" ]]; then
        deploy_scripts_default="N"
    fi
    read -p "是否部署 scripts（复制 templates/ 并写入 proxy 段） [y/${deploy_scripts_default}]: " deploy_scripts_in
    [[ "$deploy_scripts_in" == $'\e' ]] && return
    local deploy_scripts_flag="${UM_DEPLOY_SCRIPTS_DEFAULT:-true}"
    if [[ "$deploy_scripts_in" =~ ^[Yy]$ ]]; then
        deploy_scripts_flag=true
    elif [[ "$deploy_scripts_in" =~ ^[Nn]$ ]]; then
        deploy_scripts_flag=false
    fi

    read -p "是否启用 sudo（NOPASSWD，/etc/sudoers.d，非 sudo 组） [y/N]: " has_sudo
    [[ "$has_sudo" == $'\e' ]] && return
    has_sudo_flag=false
    if [[ "$has_sudo" =~ ^[Yy]$ ]]; then
        has_sudo_flag=true
    fi

    read -p "是否有docker权限 [y/N]: " has_docker
    [[ "$has_docker" == $'\e' ]] && return
    has_docker_flag=false
    if [[ "$has_docker" =~ ^[Yy]$ ]]; then
        has_docker_flag=true
    fi

    echo "authorized_keys (单行公钥):"
    read -p "> " authorized_keys
    [[ "$authorized_keys" == $'\e' ]] && return

    default_key_type="$(_um_default_key_type_from_authorized_keys "$authorized_keys")"
    echo "私钥文件名 [默认 $default_key_type (推测)]:"
    read -p "> " key_type
    [[ "$key_type" == $'\e' ]] && return
    key_type="${key_type:-$default_key_type}"
    key_type_inferred=$([[ "$key_type" == "$default_key_type" ]] && echo "true" || echo "false")

    if [[ -n "${HOST_IP:-}" ]]; then
        selected_ip="$HOST_IP"
    else
        available_ips=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -5)
        echo "选择登录IP:"
        select ip in $available_ips; do
            if [[ -n "$ip" ]]; then
                selected_ip="$ip"
                break
            fi
        done 2>/dev/null || selected_ip="127.0.0.1"
    fi

    ssh_port=$(grep ^Port /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")

    if id "$username" &>/dev/null; then
        echo "用户 $username 已存在，退出"
        return
    fi

    um_create_managed_user "$username" "$password" "$home_dir" "$has_sudo_flag" "$has_docker_flag" \
        "$authorized_keys" "$key_type" "$key_type_inferred" "$selected_ip" "$ssh_port" "$deploy_scripts_flag"

    echo
    echo "=========================================="
    echo "         创建完成"
    echo "=========================================="
    echo
    echo "--- SSH Config ---"
    echo "$UM_SSH_CONFIG_SNIPPET"
    echo

    echo "用户信息已保存: $UM_CREATED_JSON_FILE"
    echo
    read -p "按回车继续..." _
}
