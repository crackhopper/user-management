# lib/user_json_parse.sh — 从 JSON 文件解析字段到当前 shell 变量
# -----------------------------------------------------------------------------
# _load_user_data 将一条用户记录读入全局变量（与历史实现一致，供 UI 与各 cmd 使用）：
#   username, home_dir, sudo_group, sudo_sudoers, has_docker, authorized_keys,
#   key_type, key_type_inferred, managed, created_at, login_ip, login_port
# 无 jq：使用 grep/sed；含旧版仅有 "sudo" 时的兼容映射。
# -----------------------------------------------------------------------------

# _load_user_data /path/to/name.json
# 副作用：设置上述全局变量（不设 local，便于下游函数使用）。
_load_user_data() {
    local json_file="$1"
    username=$(basename "$json_file" .json)
    home_dir=$(grep '"home"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    sudo_group=$(grep '"sudo_group"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
    sudo_sudoers=$(grep '"sudo_sudoers"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
    has_sudo_legacy=$(grep '"sudo"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
    if [[ -z "$sudo_group" ]] && [[ -z "$sudo_sudoers" ]] && [[ -n "$has_sudo_legacy" ]]; then
        sudo_group="$has_sudo_legacy"
        sudo_sudoers="false"
    fi
    [[ -z "$sudo_group" ]] && sudo_group="false"
    [[ -z "$sudo_sudoers" ]] && sudo_sudoers="false"
    has_docker=$(grep '"docker"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/')
    authorized_keys=$(grep '"authorized_keys"' "$json_file" | sed 's/.*: *\"\([^\"]*\)\".*/\1/')
    key_type=$(grep '"key_type"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    key_type_inferred=$(grep '"key_type_inferred"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
    managed=$(grep '"managed"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
    created_at=$(grep '"created_at"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
    login_ip=$(grep '"login_ips"' "$json_file" | sed 's/.*: *\[\"\([^:]*\):[^"]*\"\].*/\1/')
    login_port=$(grep '"login_ips"' "$json_file" | sed 's/.*: *\[\"[^:]*:\([^"]*\)\"\].*/\1/')
    [[ -z "$login_ip" ]] && login_ip="127.0.0.1"
    [[ -z "$login_port" ]] && login_port="22"

    if [[ -z "$key_type" ]]; then
        if [[ "$authorized_keys" == ssh-rsa* ]]; then
            key_type="id_rsa"
        elif [[ "$authorized_keys" == ssh-ed25519* ]]; then
            key_type="id_ed25519"
        else
            key_type="id_rsa"
        fi
        key_type_inferred="true"
    fi
}
