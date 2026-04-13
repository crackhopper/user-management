#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGED_USERS_DIR="$SCRIPT_DIR/managed_users"
SCRIPTS_SRC="$SCRIPT_DIR/user_scripts"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi
HOST_NAME="${HOSTNAME:-$(hostname)}"

ESCAPE_KEY=$'\e'
BACK_ESCAPE=$'^[['

# mode: sync（写 last_synced）| refresh（仅按系统刷新 sudo 相关字段）| track（managed=true + 刷新）
_merge_json_sudo_from_system() {
    local json_file="$1"
    local username="$2"
    local mode="${3:-refresh}"

    if ! command -v python3 &>/dev/null; then
        echo "错误: 需要 python3 以更新 JSON。"
        return 1
    fi
    python3 -c "
import json
import os
import subprocess
import sys
from datetime import datetime

path = sys.argv[1]
username = sys.argv[2]
mode = sys.argv[3]

with open(path) as f:
    d = json.load(f)

if 'sudo' in d and 'sudo_group' not in d:
    v = d['sudo']
    if isinstance(v, bool):
        d['sudo_group'] = v
    else:
        d['sudo_group'] = str(v).strip() == 'true'
    d['sudo_sudoers'] = False
    del d['sudo']

r = subprocess.run(['id', '-nG', username], capture_output=True, text=True)
gs = (r.stdout or '').split()
d['sudo_group'] = 'sudo' in gs
d['sudo_sudoers'] = os.path.isfile(f'/etc/sudoers.d/{username}')
d['docker'] = 'docker' in gs

if mode == 'sync':
    d['last_synced'] = datetime.now().astimezone().isoformat(timespec='seconds')
elif mode == 'track':
    d['managed'] = True

with open(path, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$json_file" "$username" "$mode"
}

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

    default_home="/home/$username"
    read -p "home目录 [$default_home]: " home_dir
    [[ "$home_dir" == $'\e' ]] && return
    home_dir="${home_dir:-$default_home}"

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

    if [[ "$authorized_keys" == ssh-rsa* ]]; then
        default_key_type="id_rsa"
    elif [[ "$authorized_keys" == ssh-ed25519* ]]; then
        default_key_type="id_ed25519"
    else
        default_key_type="id_rsa"
    fi
    echo "私钥文件名 [默认 $default_key_type (推测)]:"
    read -p "> " key_type
    [[ "$key_type" == $'\e' ]] && return
    key_type="${key_type:-$default_key_type}"
    key_type_inferred=$([[ "$key_type" == "$default_key_type" ]] && echo "true" || echo "false")

    available_ips=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -5)
    echo "选择登录IP:"
    select ip in $available_ips; do
        if [[ -n "$ip" ]]; then
            selected_ip="$ip"
            break
        fi
    done 2>/dev/null || selected_ip="127.0.0.1"

    ssh_port=$(grep ^Port /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")

    if id "$username" &>/dev/null; then
        echo "用户 $username 已存在，退出"
        return
    fi

    echo
    echo "=========================================="
    echo "         开始创建用户..."
    echo "=========================================="

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
            echo "# BEGIN user_management proxy (user_scripts/proxy.sh)"
            cat "$SCRIPTS_SRC/proxy.sh"
            echo "# END user_management proxy"
        } | sudo tee -a "$home_dir/.bashrc" > /dev/null
    fi

    ssh_host_name="${username}-${HOST_NAME}"
    login_entry="Host $ssh_host_name
    HostName $selected_ip
    Port $ssh_port
    User $username
    IdentityFile ~/.ssh/$key_type
"

    echo
    echo "=========================================="
    echo "         创建完成"
    echo "=========================================="
    echo
    echo "--- SSH Config ---"
    echo "$login_entry"
    echo

    json_file="$MANAGED_USERS_DIR/${username}.json"
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

    echo "用户信息已保存: $json_file"
    echo
    read -p "按回车继续..." _
}

_list_managed_users() {
    echo "=========================================="
    echo "         已管理用户"
    echo "=========================================="
    echo "(按 ESC 返回主菜单)"
    echo

    users=()
    json_files=()

    for json_file in "$MANAGED_USERS_DIR"/*.json; do
        [[ -e "$json_file" ]] || continue
        username=$(basename "$json_file" .json)
        managed=$(grep '"managed"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
        if [[ "$managed" == "false" ]]; then
            continue
        fi
        users+=("$username")
        json_files+=("$json_file")
    done

    if [[ ${#users[@]} -eq 0 ]]; then
        echo "暂无已管理用户"
        echo
        read -p "按回车继续..." _
        return
    fi

    i=1
    for u in "${users[@]}"; do
        echo "  $i) $u"
        ((i++))
    done
    echo

    while true; do
        read -p "选择用户编号 (或 ESC 返回): " choice

        if [[ "$choice" == $'\e' ]]; then
            return
        fi

        if [[ -z "$choice" ]]; then
            continue
        fi

        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
            echo "无效选择"
            continue
        fi

        idx=$((choice - 1))
        _user_action_menu "${users[$idx]}" "${json_files[$idx]}"
        break
    done
}

_list_other_users() {
    echo "=========================================="
    echo "         未管理用户"
    echo "=========================================="
    echo "(按 ESC 返回主菜单)"
    echo

    users=()
    json_files=()

    for json_file in "$MANAGED_USERS_DIR"/*.json; do
        [[ -e "$json_file" ]] || continue
        username=$(basename "$json_file" .json)
        managed=$(grep '"managed"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
        if [[ "$managed" != "false" ]]; then
            continue
        fi
        users+=("$username")
        json_files+=("$json_file")
    done

    if [[ ${#users[@]} -eq 0 ]]; then
        echo "没有未管理用户"
        echo
        read -p "按回车继续..." _
        return
    fi

    i=1
    for u in "${users[@]}"; do
        echo "  $i) $u"
        ((i++))
    done
    echo

    while true; do
        read -p "选择用户编号 (或 ESC 返回): " choice

        if [[ "$choice" == $'\e' ]]; then
            return
        fi

        if [[ -z "$choice" ]]; then
            continue
        fi

        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
            echo "无效选择"
            continue
        fi

        idx=$((choice - 1))
        _other_user_menu "${users[$idx]}" "${json_files[$idx]}"
        break
    done
}

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
    if [[ "$keep_home" =~ ^[Yy]$ ]]; then
        sudo userdel "$username"
    else
        sudo userdel -r "$username"
    fi

    sudo rm -f "/etc/sudoers.d/$username"
    rm -f "$json_file"

    echo "用户 $username 已删除"
    echo
    read -p "按回车继续..." _

    return 0
}

_user_login() {
    local username="$1"
    echo "切换到用户 $username ..."
    exec sudo -u "$username" -i
}

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
            sudo sed -i '\|# BEGIN user_management proxy (user_scripts/proxy.sh)|,|# END user_management proxy|d' "$bashrc"
        fi
        {
            echo ""
            echo "# BEGIN user_management proxy (user_scripts/proxy.sh)"
            cat "$SCRIPTS_SRC/proxy.sh"
            echo "# END user_management proxy"
        } | sudo tee -a "$bashrc" > /dev/null
        sudo chown "$username:$username" "$bashrc"
    fi

    _merge_json_sudo_from_system "$json_file" "$username" sync

    echo "✅ $username 已同步"
    read -p "按回车继续..." _
}

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

interactive_menu() {
    while true; do
        echo
        echo "=========================================="
        echo "         用户管理"
        echo "=========================================="
        echo
        echo "  1) 新建用户"
        echo "  2) 已管理用户"
        echo "  3) 未管理用户"
        echo
        echo "  0) 退出"
        echo

        read -p "选择操作: " choice

        case "$choice" in
            1) cmd_add ;;
            2) _list_managed_users ;;
            3) _list_other_users ;;
            0) exit 0 ;;
            *) echo "无效选择" ;;
        esac
    done
}

mkdir -p "$MANAGED_USERS_DIR"

show_help() {
    cat << 'EOF'
用法: user-mgmt.sh [命令]

用户管理工具

命令:
  (无参数)   进入交互模式
  add        创建新用户
  help       显示帮助

示例:
  user-mgmt.sh
  user-mgmt.sh add
EOF
}

case "${1:-}" in
    add)            cmd_add ;;
    help|--help|-h) show_help ;;
    *)              interactive_menu ;;
esac
