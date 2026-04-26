# lib/interactive/cmd_add_user.sh — 交互式创建系统用户并写入 managed_users JSON
# -----------------------------------------------------------------------------
# 依赖：MANAGED_USERS_DIR、SCRIPTS_SRC、HOST_NAME、HOST_IP、UM_*_DEFAULT
#       um_create_managed_user（lib/ops/create_user.sh）
#       _ask_*（lib/interactive/prompts.sh）
# 策略：sudo 仅 /etc/sudoers.d/<user>，不加入 sudo 组（sudo_group=false, sudo_sudoers=选择）
# -----------------------------------------------------------------------------

# _detect_default_ssh_port — 从 sshd_config 读 Port，缺省 22
_detect_default_ssh_port() {
    grep ^Port /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1 || true
}

# _detect_default_login_ip — 取首个非 127 的 IPv4，缺省 127.0.0.1
_detect_default_login_ip() {
    local ip
    ip=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
    echo "${ip:-127.0.0.1}"
}

# cmd_add — 创建用户主流程（无参数；ESC 任一步可返回）
cmd_add() {
    echo "=========================================="
    echo "         创建用户"
    echo "=========================================="
    echo "(任一步骤按 ESC 取消)"
    echo

    local username password user_comment home_dir login_shell
    local default_ssh_port ssh_port default_login_ip selected_ip
    local deploy_scripts_flag configure_proxy_flag has_sudo_flag has_docker_flag
    local authorized_keys default_key_type key_type key_type_inferred
    local jump_to_enabled jump_to_sites_input

    _ask_required "用户名" || return
    username="$ANSWER"

    while true; do
        _ask_required_secret "初始密码（≥8 字符）" || return
        password="$ANSWER"
        if [[ ${#password} -ge 8 ]]; then
            break
        fi
        echo "密码太短（PAM 要求 ≥ 8 字符），请重输"
    done

    _ask_default "用户备注 (GECOS，可空)" "" || return
    user_comment="$ANSWER"

    _ask_default "home 目录" "${UM_HOME_PARENT:-/home}/$username" || return
    home_dir="$ANSWER"

    _ask_default "登录 shell" "/bin/bash" || return
    login_shell="$ANSWER"

    default_ssh_port="$(_detect_default_ssh_port)"
    [[ -z "$default_ssh_port" ]] && default_ssh_port="22"
    _ask_default "SSH 端口" "$default_ssh_port" || return
    ssh_port="$ANSWER"

    if [[ -n "${HOST_IP:-}" ]]; then
        default_login_ip="$HOST_IP"
    else
        default_login_ip="$(_detect_default_login_ip)"
    fi
    _ask_default "登录 IP" "$default_login_ip" || return
    selected_ip="$ANSWER"

    _ask_yn "是否部署 scripts（复制 templates/ 到 ~/scripts）" "${UM_DEPLOY_SCRIPTS_DEFAULT:-true}" || return
    deploy_scripts_flag="$ANSWER"

    _ask_yn "是否在 ~/.bashrc 写入 proxy 段（templates/proxy.sh）" "${UM_CONFIGURE_PROXY_DEFAULT:-false}" || return
    configure_proxy_flag="$ANSWER"

    # sudo 三选一：1) NOPASSWD  2) 需密码  n) 不启用
    echo "Sudo 选项："
    echo "  1) NOPASSWD（无需密码）"
    echo "  2) 需要密码（标准 sudo）"
    echo "  n) 不启用"
    read -p "选择 [n]: " sudo_choice
    [[ "$sudo_choice" == $'\e' ]] && return
    case "$sudo_choice" in
        1) has_sudo_flag="nopasswd" ;;
        2) has_sudo_flag="password" ;;
        *) has_sudo_flag="none" ;;
    esac

    _ask_yn "是否加入 docker 组" "true" || return
    has_docker_flag="$ANSWER"

    local extra_steps=()

    _ask_yn "默认安装 nvm + Node LTS（用户级）" "true" || return
    [[ "$ANSWER" == "true" ]] && extra_steps+=(nvm_node)

    _ask_yn "默认安装 pipx 运行时（系统级，apt/dnf/...）" "true" || return
    [[ "$ANSWER" == "true" ]] && extra_steps+=(pipx_runtime)

    _ask_yn "默认安装 npm CLIs（codex / opencode / claude-code / openspec）" "true" || return
    [[ "$ANSWER" == "true" ]] && extra_steps+=(npm_dev_clis)

    _ask_yn "默认安装 Cursor CLI（cursor-agent；curl 安装）" "true" || return
    [[ "$ANSWER" == "true" ]] && extra_steps+=(cursor_agent)

    _ask_yn "默认安装 pipx mkdocs-material（含 pillow/cairosvg 依赖）" "true" || return
    [[ "$ANSWER" == "true" ]] && extra_steps+=(pipx_mkdocs_material)

    _ask_yn "默认安装 uv（pipx 装；清华源）" "true" || return
    [[ "$ANSWER" == "true" ]] && extra_steps+=(uv)

    _ask_yn "是否启用 jump-to 命令（扫描 ~/.ssh/config 并登录站点）" "false" || return
    jump_to_enabled="$ANSWER"
    if [[ "$jump_to_enabled" == "true" ]]; then
        _ask_default "jump-to 初始站点（逗号分隔 ssh config Host，如 xdg-sg2,xdg-us1；可空）" "" || return
        jump_to_sites_input="$ANSWER"
        extra_steps+=(jump_to)
    fi

    echo "authorized_keys (单行公钥，留空跳过；后续可在「模块管理 → authorized_keys」补)"
    _ask_default ">" "" || return
    authorized_keys="$ANSWER"

    default_key_type="$(_um_default_key_type_from_authorized_keys "$authorized_keys")"
    _ask_default "私钥文件名（推测：$default_key_type）" "$default_key_type" || return
    key_type="$ANSWER"
    if [[ "$key_type" == "$default_key_type" ]]; then
        key_type_inferred="true"
    else
        key_type_inferred="false"
    fi

    if id "$username" &>/dev/null; then
        echo "用户 $username 已存在，退出"
        return
    fi

    local extras_csv
    extras_csv="$(IFS=,; echo "${extra_steps[*]}")"

    UM_STEPS_EXTRA="$extras_csv" \
    UM_JUMP_TO_TARGETS="$jump_to_sites_input" \
        um_create_managed_user "$username" "$password" "$home_dir" "$has_sudo_flag" "$has_docker_flag" \
            "$authorized_keys" "$key_type" "$key_type_inferred" "$selected_ip" "$ssh_port" \
            "$deploy_scripts_flag" "$configure_proxy_flag" "$user_comment" "$login_shell"

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
