# lib/ops/create_user.sh — 创建托管用户（无交互）
# -----------------------------------------------------------------------------
# 依赖（已 source）：lib/config.sh、lib/json_io.sh、lib/anchors.sh、
#                  lib/install_steps.sh + lib/install_steps/*.sh
# um_create_managed_user：useradd → 走 install steps → 写 JSON
# 输出：UM_CREATED_JSON_FILE、UM_SSH_CONFIG_SNIPPET
# -----------------------------------------------------------------------------

um_create_managed_user() {
    local username="$1"
    local password="$2"
    local home_dir="$3"
    local has_sudo_flag="$4"
    local has_docker_flag="$5"
    local authorized_keys="$6"
    local key_type="$7"
    local key_type_inferred="$8"
    local selected_ip="$9"
    local ssh_port="${10}"
    local deploy_scripts="${11:-true}"
    local configure_proxy="${12:-false}"
    local user_comment="${13:-}"
    local login_shell="${14:-/bin/bash}"

    UM_CREATED_JSON_FILE=""
    UM_SSH_CONFIG_SNIPPET=""

    echo
    echo "=========================================="
    echo "         开始创建用户..."
    echo "=========================================="

    local home_parent
    home_parent="$(dirname "$home_dir")"
    sudo mkdir -p "$home_parent"

    sudo useradd -m -U -d "$home_dir" -s "$login_shell" -c "$user_comment" "$username"
    echo "$username:$password" | sudo chpasswd

    local json_file="$MANAGED_USERS_DIR/${username}.json"

    # 解释 has_sudo_flag 三态：
    #   true | nopasswd  → sudoers apply（NOPASSWD）
    #   password         → sudoers apply（要密码）
    #   false | none | 空 → 不写 sudoers
    local _sudo_mode="none"
    case "$has_sudo_flag" in
        true|nopasswd)
            _sudo_mode="nopasswd"
            UM_SUDO_REQUIRE_PASSWORD=false \
                _um_step_call sudoers apply "$username" "$home_dir" "$json_file"
            ;;
        password)
            _sudo_mode="password"
            UM_SUDO_REQUIRE_PASSWORD=true \
                _um_step_call sudoers apply "$username" "$home_dir" "$json_file"
            ;;
        *) ;;
    esac

    if [[ "$has_docker_flag" == "true" ]]; then
        _um_step_call docker_group apply "$username" "$home_dir" "$json_file"
    fi

    UM_AUTHORIZED_KEYS="$authorized_keys" \
        _um_step_call authorized_keys apply "$username" "$home_dir" "$json_file"
    unset UM_AUTHORIZED_KEYS

    if [[ "$deploy_scripts" == "true" ]]; then
        _um_step_call scripts_dir apply "$username" "$home_dir" "$json_file"
    fi

    if [[ "$configure_proxy" == "true" ]]; then
        _um_step_call proxy_bashrc apply "$username" "$home_dir" "$json_file"
    fi

    # 额外 steps：UM_STEPS_EXTRA 是逗号分隔 step key 列表（由 cmd_add 等设置）
    if [[ -n "${UM_STEPS_EXTRA:-}" ]]; then
        local _extra_arr _extra_key
        IFS=',' read -ra _extra_arr <<< "$UM_STEPS_EXTRA"
        for _extra_key in "${_extra_arr[@]}"; do
            [[ -z "$_extra_key" ]] && continue
            _um_step_call "$_extra_key" apply "$username" "$home_dir" "$json_file" || true
        done
    fi

    local ssh_host_name="${username}-${HOST_NAME}"
    UM_SSH_CONFIG_SNIPPET="Host $ssh_host_name
    HostName $selected_ip
    Port $ssh_port
    User $username
    IdentityFile ~/.ssh/$key_type
"

    # sudo_sudoers 字段：是否实际写了 sudoers 文件（none 时为 false）
    local _sudo_sudoers_flag="false"
    [[ "$_sudo_mode" != "none" ]] && _sudo_sudoers_flag="true"

    _um_json_write_user "$json_file" "$username" "$home_dir" "$_sudo_sudoers_flag" "$has_docker_flag" \
        "${selected_ip}:${ssh_port}" "$key_type" "$key_type_inferred" "$authorized_keys" \
        "$user_comment" "$login_shell" "$_sudo_mode"
    UM_CREATED_JSON_FILE="$json_file"
}

# _um_default_key_type_from_authorized_keys — 根据公钥前缀推测私钥文件名
_um_default_key_type_from_authorized_keys() {
    local ak="$1"
    if [[ "$ak" == ssh-rsa* ]]; then
        echo "id_rsa"
    elif [[ "$ak" == ssh-ed25519* ]]; then
        echo "id_ed25519"
    else
        echo "id_rsa"
    fi
}
