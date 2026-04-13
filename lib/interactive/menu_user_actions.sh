# lib/interactive/menu_user_actions.sh — 单用户子菜单：查看/删除/登录/修改（sync 与 sudo）
# -----------------------------------------------------------------------------
# 依赖：_load_user_data、cmd 中的 sync/sudo/track、HOST_NAME
# -----------------------------------------------------------------------------

_user_action_menu() {
    local username="$1"
    local json_file="$2"

    _load_user_data "$json_file"

    while true; do
        echo
        echo "=========================================="
        echo "         用户: $username"
        echo "=========================================="
        echo
        echo "  1) 查看"
        echo "  2) 删除"
        echo "  3) 进入 (登录)"
        echo "  4) 修改"
        echo
        echo "  0) 返回"
        echo

        read -p "选择操作: " choice

        case "$choice" in
            1) _user_view "$username" "$json_file" ;;
            2) _user_delete "$username" "$json_file" ;;
            3) _user_login "$username" ;;
            4) _user_modify_menu "$username" "$json_file" ;;
            0) return ;;
            *) echo "无效选择" ;;
        esac
    done
}

_other_user_menu() {
    local username="$1"
    local json_file="$2"

    if [[ ! -f "$json_file" ]]; then
        if ! _um_ensure_stub_unmanaged_json "$username"; then
            read -p "按回车继续..." _
            return
        fi
        json_file="$MANAGED_USERS_DIR/${username}.json"
    fi

    _load_user_data "$json_file"

    while true; do
        echo
        echo "=========================================="
        echo "         用户: $username (未管理)"
        echo "=========================================="
        echo
        echo "  1) 查看"
        echo "  2) 纳入管理 (track)"
        echo
        echo "  0) 返回"
        echo

        read -p "选择操作: " choice

        case "$choice" in
            1) _user_view "$username" "$json_file" ;;
            2) _track_user "$username" "$json_file" ;;
            0) return ;;
            *) echo "无效选择" ;;
        esac
    done
}

# _user_view — 打印基本信息与 SSH Config 片段（数据来自 _load_user_data）
_user_view() {
    local username="$1"
    local json_file="$2"

    _load_user_data "$json_file"

    echo
    echo "--- 基本信息 ---"
    echo "用户名:       $username"
    echo "Home目录:    $home_dir"
    echo "Sudo组:      $sudo_group"
    echo "sudoers文件: $sudo_sudoers  (/etc/sudoers.d/$username)"
    echo "Docker:      $has_docker"
    echo "管理状态:    $managed"
    echo "创建时间:    $created_at"
    echo

    ssh_host_name="${username}-${HOST_NAME}"
    echo "--- SSH 登录信息 ---"
    echo "Host:       $ssh_host_name"
    echo "Key:        ~/.ssh/$key_type"
    if [[ "$key_type_inferred" == "true" ]]; then
        echo "Key类型:    (推测)"
    fi
    echo
    echo "--- SSH Config ---"
    cat << EOF
Host $ssh_host_name
    HostName $login_ip
    Port $login_port
    User $username
    IdentityFile ~/.ssh/$key_type
EOF
    echo
    echo "--- authorized_keys ---"
    echo "${authorized_keys:-无}"
    echo
    read -p "按回车继续..." _
}

# _user_delete — userdel、删 sudoers 与 JSON 记录
_user_delete() {
    local username="$1"
    local json_file="$2"

    echo
    echo "确认删除用户 $username？"
    read -p "确认 [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消"
        return
    fi

    read -p "是否保留 home 目录？[y/N]: " keep_home
    local keep_home_flag=false
    if [[ "$keep_home" =~ ^[Yy]$ ]]; then
        keep_home_flag=true
    fi

    um_delete_managed_user "$username" "$keep_home_flag" "$json_file"

    echo "用户 $username 已删除"
    echo
    read -p "按回车继续..." _

    return 0
}

# _user_login — 以目标用户登录 shell（exec，不返回）
_user_login() {
    local username="$1"
    echo "切换到用户 $username ..."
    exec sudo -u "$username" -i
}

# _user_modify_menu — Sync / 启用 sudo / 禁用 sudo
_user_modify_menu() {
    local username="$1"
    local json_file="$2"

    while true; do
        echo
        echo "=========================================="
        echo "         修改: $username"
        echo "=========================================="
        echo
        echo "  1) Sync (同步状态和 scripts)"
        echo "  2) 启用 sudo（sudoers.d / NOPASSWD）"
        echo "  3) 禁用 sudo（移除 sudoers 与 sudo 组）"
        echo
        echo "  0) 返回"
        echo

        read -p "选择操作: " choice

        case "$choice" in
            1) _sync_single_user "$username" "$json_file" ;;
            2) _enable_sudo "$username" ;;
            3) _disable_sudo "$username" ;;
            0) return ;;
            *) echo "无效选择" ;;
        esac
    done
}
