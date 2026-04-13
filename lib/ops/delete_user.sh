# lib/ops/delete_user.sh — 删除托管用户（无交互；依赖已 source 的 lib/config.sh）
# -----------------------------------------------------------------------------
# um_delete_managed_user username keep_home [json_file]
# keep_home: true 保留 home（仅 userdel），false 删除 home（userdel -r）
# -----------------------------------------------------------------------------

um_delete_managed_user() {
    local username="$1"
    local keep_home="${2:-false}"
    local json_file="${3:-$MANAGED_USERS_DIR/${username}.json}"

    if [[ "$keep_home" == "true" ]]; then
        sudo userdel "$username"
    else
        sudo userdel -r "$username"
    fi

    sudo rm -f "/etc/sudoers.d/$username"
    rm -f "$json_file"
}
