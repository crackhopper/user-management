# lib/interactive/cmd_user_sync_and_sudo.sh — 同步用户环境、sudo、纳入管理（track）
# -----------------------------------------------------------------------------
# 依赖：_load_user_data、_merge_json_sudo_from_system、MANAGED_USERS_DIR、SCRIPTS_SRC
# _sync_single_user：覆盖 ~/scripts、刷新 .bashrc proxy 段、merge JSON(mode=sync)
# _enable_sudo / _disable_sudo：改系统后 merge(mode=refresh)
# _track_user：按问答改 sudoers/docker 后 merge(mode=track)
# -----------------------------------------------------------------------------

# _sync_single_user 用户名 json路径 — 同步 scripts 与 proxy，并刷新 JSON 中 sudo/docker/last_synced
_sync_single_user() {
    local username="$1"
    local json_file="$2"

    _load_user_data "$json_file"

    if ! id "$username" &>/dev/null; then
        echo "用户 $username 不存在"
        return
    fi

    echo "同步 $username ($home_dir) ..."

    echo "  同步 scripts ..."
    sudo rm -rf "$home_dir/scripts"
    sudo cp -r "$SCRIPTS_SRC" "$home_dir/scripts"
    sudo chown -R "$username:$username" "$home_dir/scripts"

    bashrc="$home_dir/.bashrc"
    if [[ -f "$SCRIPTS_SRC/proxy.sh" ]]; then
        echo "  更新 proxy 段 ..."
        if [[ -f "$bashrc" ]]; then
            sudo sed -i '\|# BEGIN user_management proxy (templates/proxy.sh)|,|# END user_management proxy|d' "$bashrc"
        fi
        {
            echo ""
            echo "# BEGIN user_management proxy (templates/proxy.sh)"
            cat "$SCRIPTS_SRC/proxy.sh"
            echo "# END user_management proxy"
        } | sudo tee -a "$bashrc" > /dev/null
        sudo chown "$username:$username" "$bashrc"
    fi

    _merge_json_sudo_from_system "$json_file" "$username" sync

    echo "✅ $username 已同步"
    read -p "按回车继续..." _
}

# _enable_sudo 用户名 — 仅写入 /etc/sudoers.d（NOPASSWD），不加入 sudo 组
_enable_sudo() {
    local username="$1"
    local json_file="$MANAGED_USERS_DIR/${username}.json"
    echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$username" > /dev/null
    sudo chmod 440 "/etc/sudoers.d/$username"
    if [[ -f "$json_file" ]]; then
        _merge_json_sudo_from_system "$json_file" "$username" refresh
    fi
    echo "已启用 $username 的 sudo（NOPASSWD：/etc/sudoers.d/$username；未使用 sudo 组）"
    read -p "按回车继续..." _
}

# _disable_sudo 用户名 — 删除 sudoers 并尝试移出 sudo 组，再刷新 JSON
_disable_sudo() {
    local username="$1"
    local json_file="$MANAGED_USERS_DIR/${username}.json"
    sudo rm -f "/etc/sudoers.d/$username"
    sudo deluser "$username" sudo 2>/dev/null || true
    if [[ -f "$json_file" ]]; then
        _merge_json_sudo_from_system "$json_file" "$username" refresh
    fi
    echo "已禁用 $username 的 sudo（已移除 sudoers 与 sudo 组）"
    read -p "按回车继续..." _
}

# _track_user 用户名 json路径 — 「未管理」用户纳入管理：问答并应用 sudo/docker，再 merge(track)
_track_user() {
    local username="$1"
    local json_file="$2"

    echo
    echo "纳入管理: $username"
    echo

    read -p "设置 sudo（/etc/sudoers.d，NOPASSWD） [y/N]: " has_sudo
    sudo_flag=false
    if [[ "$has_sudo" =~ ^[Yy]$ ]]; then
        sudo_flag=true
    fi

    read -p "设置 docker 权限 [y/N]: " has_docker
    docker_flag=false
    if [[ "$has_docker" =~ ^[Yy]$ ]]; then
        docker_flag=true
    fi

    if [[ "$sudo_flag" == "true" ]]; then
        echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$username" > /dev/null
        sudo chmod 440 "/etc/sudoers.d/$username"
    else
        sudo rm -f "/etc/sudoers.d/$username"
        sudo deluser "$username" sudo 2>/dev/null || true
    fi

    if [[ "$docker_flag" == "true" ]]; then
        sudo usermod -aG docker "$username"
    else
        sudo deluser "$username" docker 2>/dev/null || true
    fi

    _merge_json_sudo_from_system "$json_file" "$username" track

    echo "✅ $username 已纳入管理"
    read -p "按回车继续..." _
}
