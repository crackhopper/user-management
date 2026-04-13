# lib/ops/create_user.sh — 创建托管用户（无交互；依赖已 source 的 lib/config.sh）
# -----------------------------------------------------------------------------
# um_create_managed_user：执行 useradd、sudoers、docker、SSH、templates、JSON
# 输出：UM_CREATED_JSON_FILE、UM_SSH_CONFIG_SNIPPET
# 标记与 sed 锚点使用 config 中的 UM_PROXY_BEGIN / UM_PROXY_END
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

    UM_CREATED_JSON_FILE=""
    UM_SSH_CONFIG_SNIPPET=""

    echo
    echo "=========================================="
    echo "         开始创建用户..."
    echo "=========================================="

    local home_parent
    home_parent="$(dirname "$home_dir")"
    sudo mkdir -p "$home_parent"

    sudo useradd -m -d "$home_dir" -s /bin/bash "$username"
    echo "$username:$password" | sudo chpasswd

    if [[ "$has_sudo_flag" == "true" ]]; then
        echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$username" > /dev/null
        sudo chmod 440 "/etc/sudoers.d/$username"
    fi

    if [[ "$has_docker_flag" == "true" ]]; then
        sudo usermod -aG docker "$username"
    fi

    sudo mkdir -p "$home_dir/.ssh"
    echo "$authorized_keys" | sudo tee "$home_dir/.ssh/authorized_keys" > /dev/null
    sudo chmod 600 "$home_dir/.ssh/authorized_keys"
    sudo chown -R "$username:$username" "$home_dir/.ssh"

    sudo cp -r "$SCRIPTS_SRC" "$home_dir/scripts"
    sudo chown -R "$username:$username" "$home_dir/scripts"

    if [[ -f "$SCRIPTS_SRC/proxy.sh" ]]; then
        {
            echo ""
            echo "$UM_PROXY_BEGIN"
            cat "$SCRIPTS_SRC/proxy.sh"
            echo "$UM_PROXY_END"
        } | sudo tee -a "$home_dir/.bashrc" > /dev/null
    fi

    local ssh_host_name="${username}-${HOST_NAME}"
    UM_SSH_CONFIG_SNIPPET="Host $ssh_host_name
    HostName $selected_ip
    Port $ssh_port
    User $username
    IdentityFile ~/.ssh/$key_type
"

    local json_file="$MANAGED_USERS_DIR/${username}.json"
    cat > "$json_file" << EOF
{
  "username": "$username",
  "home": "$home_dir",
  "sudo_group": false,
  "sudo_sudoers": $has_sudo_flag,
  "docker": $has_docker_flag,
  "login_ips": ["${selected_ip}:${ssh_port}"],
  "key_type": "$key_type",
  "key_type_inferred": $key_type_inferred,
  "authorized_keys": "$authorized_keys",
  "created_at": "$(date -Iseconds)",
  "managed": true
}
EOF
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
