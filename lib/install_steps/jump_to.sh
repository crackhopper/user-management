# lib/install_steps/jump_to.sh — jump-to 命令、本地 SSH config、远程同名账号开通
# 依赖：_um_anchor_*、_um_user_sh、python3、ssh、ssh-keygen
# -----------------------------------------------------------------------------

UM_STEPS+=(jump_to)

um_step_jump_to_label()   { echo "启用 jump-to 命令并管理远程同名账户登录"; }
um_step_jump_to_default() { echo "false"; }

um_step_jump_to_status() {
    local home="$2"
    local bashrc_ok sshcfg_ok
    bashrc_ok="$(_um_anchor_present "$home/.bashrc" "jump_to_bashrc")"
    sshcfg_ok="$(_um_anchor_present "$home/.ssh/config" "jump_to_ssh_config")"
    if [[ "$bashrc_ok" == "true" && "$sshcfg_ok" == "true" ]]; then
        echo true
    else
        echo false
    fi
}

_um_jump_to_sites_load() {
    local json_file="$1"
    JUMP_TO_SITES=()

    if [[ -n "${UM_JUMP_TO_TARGETS:-}" ]]; then
        local item
        IFS=',' read -ra _jump_to_env_arr <<< "$UM_JUMP_TO_TARGETS"
        for item in "${_jump_to_env_arr[@]}"; do
            item="${item#"${item%%[![:space:]]*}"}"
            item="${item%"${item##*[![:space:]]}"}"
            [[ -n "$item" ]] && JUMP_TO_SITES+=("$item")
        done
        return 0
    fi

    [[ -f "$json_file" ]] || return 0
    command -v python3 &>/dev/null || { echo "需要 python3 读取 jump_to_sites" >&2; return 1; }
    while IFS= read -r line; do
        [[ -n "$line" ]] && JUMP_TO_SITES+=("$line")
    done < <(UM_JSON="$json_file" python3 - <<'PY'
import json, os
with open(os.environ["UM_JSON"], encoding="utf-8") as f:
    data = json.load(f)
for item in data.get("jump_to_sites", []):
    if isinstance(item, str) and item.strip():
        print(item.strip())
PY
)
}

_um_jump_to_sites_save() {
    local json_file="$1"
    command -v python3 &>/dev/null || { echo "需要 python3 写入 jump_to_sites" >&2; return 1; }

    local joined=""
    if [[ ${#JUMP_TO_SITES[@]} -gt 0 ]]; then
        joined="$(printf '%s\n' "${JUMP_TO_SITES[@]}")"
    fi

    UM_JSON="$json_file" UM_JUMP_TO_SITES_NL="$joined" python3 - <<'PY'
import json, os
path = os.environ["UM_JSON"]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
sites = [s.strip() for s in os.environ.get("UM_JUMP_TO_SITES_NL", "").split("\n") if s.strip()]
data["jump_to_sites"] = sites
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
}

_um_jump_to_site_present() {
    local needle="$1" item
    for item in "${JUMP_TO_SITES[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

_um_jump_to_alias() {
    local site="$1"
    printf 'um-jump-%s' "$site"
}

_um_jump_to_key_name() {
    echo "id_ed25519_jump_to"
}

_um_jump_to_ensure_local_key() {
    local user="$1"
    local key_name
    local pubkey

    key_name="$(_um_jump_to_key_name)"
    pubkey="$(_um_user_sh "$user" '
umask 077
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
key_name='"$key_name"'
key_path="$HOME/.ssh/$key_name"
if [[ -f "$key_path.pub" && ! -f "$key_path" ]]; then
    echo "jump-to 私钥缺失: $key_path" >&2
    exit 1
fi
if [[ ! -f "$key_path" ]]; then
    ssh-keygen -q -t ed25519 -N "" -f "$key_path" -C "$USER@jump-to"
fi
if [[ ! -f "$key_path.pub" ]]; then
    ssh-keygen -y -f "$key_path" > "$key_path.pub"
fi
chmod 600 "$key_path"
chmod 644 "$key_path.pub"
cat "$key_path.pub"
')"
    [[ -n "$pubkey" ]] || { echo "生成或读取 $user 的 ~/.ssh/$key_name(.pub) 失败" >&2; return 1; }
    UM_JUMP_TO_PUBLIC_KEY="$pubkey"
}

_um_jump_to_ssh_g_value() {
    local site="$1" key="$2"
    ssh -G "$site" 2>/dev/null | awk -v want="$key" '
        $1 == want {
            $1 = ""
            sub(/^ /, "")
            print
            exit
        }
    '
}

_um_jump_to_render_ssh_config() {
    local user="$1"
    local key_name
    local site alias host_name port proxy_jump proxy_command host_key_alias strict_host_key_checking
    local rendered=""

    key_name="$(_um_jump_to_key_name)"
    for site in "${JUMP_TO_SITES[@]}"; do
        host_name="$(_um_jump_to_ssh_g_value "$site" hostname)"
        port="$(_um_jump_to_ssh_g_value "$site" port)"
        proxy_jump="$(_um_jump_to_ssh_g_value "$site" proxyjump)"
        proxy_command="$(_um_jump_to_ssh_g_value "$site" proxycommand)"
        host_key_alias="$(_um_jump_to_ssh_g_value "$site" hostkeyalias)"
        strict_host_key_checking="$(_um_jump_to_ssh_g_value "$site" stricthostkeychecking)"

        [[ -n "$host_name" ]] || { echo "无法从本机 ~/.ssh/config 解析站点: $site" >&2; return 1; }
        [[ -n "$port" ]] || port="22"
        alias="$(_um_jump_to_alias "$site")"

        rendered+="# site: $site"$'\n'
        rendered+="Host $alias"$'\n'
        rendered+="    HostName $host_name"$'\n'
        rendered+="    Port $port"$'\n'
        rendered+="    User $user"$'\n'
        rendered+="    IdentityFile ~/.ssh/$key_name"$'\n'
        rendered+="    IdentitiesOnly yes"$'\n'
        [[ -n "$proxy_jump" && "$proxy_jump" != "none" ]] && rendered+="    ProxyJump $proxy_jump"$'\n'
        [[ -n "$proxy_command" && "$proxy_command" != "none" ]] && rendered+="    ProxyCommand $proxy_command"$'\n'
        [[ -n "$host_key_alias" && "$host_key_alias" != "none" ]] && rendered+="    HostKeyAlias $host_key_alias"$'\n'
        [[ -n "$strict_host_key_checking" && "$strict_host_key_checking" != "none" ]] && rendered+="    StrictHostKeyChecking $strict_host_key_checking"$'\n'
        rendered+=$'\n'
    done

    printf '%s' "$rendered"
}

_um_jump_to_remote_root_sh() {
    local site="$1" cmd="$2"
    printf '%s\n' "$cmd" \
        | ssh -o BatchMode=yes "$site" 'sudo -n env -u BASH_ENV bash --noprofile --norc'
}

_um_jump_to_prepare_remote_site() {
    local user="$1" site="$2" pubkey="$3"
    local q_user q_pubkey remote_cmd
    printf -v q_user '%q' "$user"
    printf -v q_pubkey '%q' "$pubkey"

remote_cmd="target_user=$q_user
pubkey=$q_pubkey
if ! id \"\$target_user\" >/dev/null 2>&1; then
    home_parent=\$(awk -F= '/^HOME=/{print \$2; exit}' /etc/default/useradd 2>/dev/null)
    [[ -n \"\$home_parent\" ]] || home_parent=/home
    home_parent=\${home_parent%/}
    useradd -m -U -d \"\$home_parent/\$target_user\" -s /bin/bash -c \"jump-to user\" \"\$target_user\"
fi
home_dir=\$(getent passwd \"\$target_user\" | cut -d: -f6)
[[ -n \"\$home_dir\" ]] || { echo \"远程用户 \$target_user 缺少 home\" >&2; exit 1; }
install -d -m 700 -o \"\$target_user\" -g \"\$target_user\" \"\$home_dir/.ssh\"
auth_file=\"\$home_dir/.ssh/authorized_keys\"
touch \"\$auth_file\"
chown \"\$target_user:\$target_user\" \"\$auth_file\"
chmod 600 \"\$auth_file\"
if ! grep -qxF -- \"\$pubkey\" \"\$auth_file\"; then
    printf '%s\n' \"\$pubkey\" >> \"\$auth_file\"
fi"

    _um_jump_to_remote_root_sh "$site" "$remote_cmd"
}

_um_jump_to_bashrc_snippet() {
    cat <<'EOF'
__um_jump_to() {
    local config_file="$HOME/.ssh/config"
    local site alias choice
    local -a sites=()

    [[ -f "$config_file" ]] || {
        echo "jump-to: $config_file 不存在"
        return 1
    }

    while IFS= read -r line; do
        site="${line#Host um-jump-}"
        [[ -n "$site" ]] && sites+=("$site")
    done < <(grep -E '^Host um-jump-' "$config_file" 2>/dev/null)

    if [[ ${#sites[@]} -eq 0 ]]; then
        echo "jump-to: 当前没有可用站点"
        return 1
    fi

    if [[ $# -ge 1 && -n "${1:-}" ]]; then
        site="$1"
    else
        echo "可用站点："
        local i=1
        for site in "${sites[@]}"; do
            printf '  %d) %s\n' "$i" "$site"
            ((i++))
        done
        read -r -p "选择站点 [1]: " choice
        [[ -z "$choice" ]] && choice="1"
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#sites[@]} )); then
            echo "jump-to: 无效选择"
            return 1
        fi
        site="${sites[choice-1]}"
    fi

    alias="um-jump-$site"
    if ! ssh -G "$alias" >/dev/null 2>&1; then
        echo "jump-to: 找不到站点 $site 的 SSH 配置 ($alias)"
        return 1
    fi

    ssh "$alias"
}

alias jump-to='__um_jump_to'
EOF
}

_um_jump_to_apply_local_artifacts() {
    local user="$1" home="$2"
    local ssh_config_content

    sudo mkdir -p "$home/.ssh"
    sudo chown "$user:$user" "$home/.ssh"
    sudo chmod 700 "$home/.ssh"

    _um_jump_to_bashrc_snippet | _um_anchor_write "$home/.bashrc" "jump_to_bashrc" "$user"

    ssh_config_content="$(_um_jump_to_render_ssh_config "$user")" || return 1
    printf '%s\n' "$ssh_config_content" | _um_anchor_write "$home/.ssh/config" "jump_to_ssh_config" "$user"
    sudo chmod 600 "$home/.ssh/config"
}

_um_jump_to_add_site_for_user() {
    local username="$1" json_file="$2" site="$3"
    local home
    [[ -n "$site" ]] || { echo "jump-to 站点不能为空" >&2; return 1; }
    [[ -f "$json_file" ]] || { echo "JSON 不存在: $json_file" >&2; return 1; }

    _load_user_data "$json_file"
    home="$home_dir"
    _um_jump_to_sites_load "$json_file"

    if ! _um_jump_to_site_present "$site"; then
        JUMP_TO_SITES+=("$site")
        _um_jump_to_sites_save "$json_file"
    fi

    UM_JUMP_TO_TARGETS="$(IFS=,; echo "${JUMP_TO_SITES[*]}")" \
        _um_step_call jump_to apply "$username" "$home" "$json_file"
}

_jump_to_user_menu() {
    local username="$1" json_file="$2"
    local choice site

    while true; do
        _um_jump_to_sites_load "$json_file"
        echo
        echo "=========================================="
        echo "         jump-to 管理: $username"
        echo "=========================================="
        if [[ ${#JUMP_TO_SITES[@]} -eq 0 ]]; then
            echo "  （当前无站点）"
        else
            local item
            for item in "${JUMP_TO_SITES[@]}"; do
                echo "  - $item"
            done
        fi
        echo
        echo "  1) 启用 jump-to 命令（仅本地能力）"
        echo "  2) 为某站点开通/刷新 jump-to"
        echo "  3) 重新写入本地 jump-to 配置（按 JSON 全量）"
        echo "  4) 从本地移除一个站点"
        echo "  0) 返回"
        echo

        read -r -p "选择: " choice
        case "$choice" in
            1)
                _load_user_data "$json_file"
                _um_step_call jump_to apply "$username" "$home_dir" "$json_file"
                echo "✅ 已启用 jump-to 命令"
                ;;
            2)
                read -r -p "站点 Host（按管理员 ~/.ssh/config，如 xdg-sg2）: " site
                [[ -n "$site" ]] || { echo "站点不能为空"; continue; }
                _um_jump_to_add_site_for_user "$username" "$json_file" "$site"
                echo "✅ 已为 $username 开通站点 $site"
                ;;
            3)
                _load_user_data "$json_file"
                _um_step_call jump_to apply "$username" "$home_dir" "$json_file"
                echo "✅ 已按 JSON 重写 jump-to 配置"
                ;;
            4)
                if [[ ${#JUMP_TO_SITES[@]} -eq 0 ]]; then
                    echo "无可移除站点"
                    continue
                fi
                read -r -p "移除站点 Host: " site
                [[ -n "$site" ]] || { echo "站点不能为空"; continue; }
                local new_sites=() item found="false"
                for item in "${JUMP_TO_SITES[@]}"; do
                    if [[ "$item" == "$site" ]]; then
                        found="true"
                        continue
                    fi
                    new_sites+=("$item")
                done
                [[ "$found" == "true" ]] || { echo "站点不存在: $site"; continue; }
                JUMP_TO_SITES=("${new_sites[@]}")
                _um_jump_to_sites_save "$json_file"
                _load_user_data "$json_file"
                _um_step_call jump_to apply "$username" "$home_dir" "$json_file"
                echo "✅ 已移除站点 $site"
                ;;
            0) return ;;
            *) echo "无效选择" ;;
        esac
    done
}

um_step_jump_to_apply() {
    local user="$1" home="$2" json_file="${3:-}"
    local site

    _um_jump_to_sites_load "$json_file"
    _um_jump_to_ensure_local_key "$user"

    if [[ "${UM_JUMP_TO_SKIP_REMOTE:-false}" != "true" ]]; then
        for site in "${JUMP_TO_SITES[@]}"; do
            _um_jump_to_prepare_remote_site "$user" "$site" "$UM_JUMP_TO_PUBLIC_KEY"
        done
    fi

    _um_jump_to_apply_local_artifacts "$user" "$home"
}

um_step_jump_to_remove() {
    local user="$1" home="$2"
    _um_anchor_strip "$home/.bashrc" "jump_to_bashrc" "#" "$user"
    _um_anchor_strip "$home/.ssh/config" "jump_to_ssh_config" "#" "$user"
}
