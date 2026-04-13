# lib/stub_unmanaged_user.sh — 无 JSON 的本地系统用户纳入「未管理」列表与 stub 记录
# -----------------------------------------------------------------------------
# 依赖：MANAGED_USERS_DIR；需 python3（与 json_user_state 一致）
# _um_uid_min：/etc/login.defs 的 UID_MIN，缺省 1000
# _um_passwd_local_usernames：可登录的本地 UID 用户（逐行输出用户名）
# _um_ensure_stub_unmanaged_json：若不存在则写入 managed: false 的最小 JSON
# -----------------------------------------------------------------------------

_um_uid_min() {
    local m
    m=$(grep -E '^UID_MIN' /etc/login.defs 2>/dev/null | awk '{print $2}')
    if [[ -n "$m" ]] && [[ "$m" =~ ^[0-9]+$ ]]; then
        echo "$m"
    else
        echo 1000
    fi
}

_um_passwd_local_usernames() {
    local uid_min name uid home shell
    uid_min="$(_um_uid_min)"
    while IFS=: read -r name _ uid _ home shell _; do
        [[ "$uid" =~ ^[0-9]+$ ]] || continue
        if (( uid < uid_min )); then
            continue
        fi
        case "$shell" in
            /usr/sbin/nologin | /sbin/nologin | /bin/false | /usr/bin/false | /nonexistent) continue ;;
        esac
        [[ -n "$name" ]] || continue
        printf '%s\n' "$name"
    done < /etc/passwd
}

# _um_ensure_stub_unmanaged_json 用户名 — 无对应 JSON 时创建 managed:false 记录
_um_ensure_stub_unmanaged_json() {
    local username="$1"
    local json_file="$MANAGED_USERS_DIR/${username}.json"

    [[ -f "$json_file" ]] && return 0
    id "$username" &>/dev/null || return 1
    if ! command -v python3 &>/dev/null; then
        echo "错误: 需要 python3 以为 $username 生成未纳管记录。"
        return 1
    fi

    local home ssh_port selected_ip tmp_auth
    home=$(getent passwd "$username" | cut -d: -f6)
    ssh_port=$(grep ^Port /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
    if [[ -n "${HOST_IP:-}" ]]; then
        selected_ip="$HOST_IP"
    else
        selected_ip=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
        selected_ip="${selected_ip:-127.0.0.1}"
    fi

    tmp_auth=$(mktemp)
    if sudo test -f "$home/.ssh/authorized_keys"; then
        sudo head -1 "$home/.ssh/authorized_keys" > "$tmp_auth" 2>/dev/null || : > "$tmp_auth"
    else
        : > "$tmp_auth"
    fi

    python3 - "$username" "$json_file" "$tmp_auth" "$selected_ip" "$ssh_port" <<'PY'
import json
import os
import pwd
import subprocess
import sys
from datetime import datetime

username, out_path, auth_path, login_ip, login_port = sys.argv[1:6]

pw = pwd.getpwnam(username)
home = pw.pw_dir

auth = ""
try:
    with open(auth_path, encoding="utf-8", errors="replace") as f:
        auth = f.readline().strip()
except OSError:
    pass

r = subprocess.run(["id", "-nG", username], capture_output=True, text=True)
gs = (r.stdout or "").split()
sudo_group = "sudo" in gs
sudo_sudoers = os.path.isfile(f"/etc/sudoers.d/{username}")
docker = "docker" in gs

if auth.startswith("ssh-ed25519"):
    kt, kinf = "id_ed25519", True
elif auth.startswith("ssh-rsa"):
    kt, kinf = "id_rsa", True
else:
    kt, kinf = "id_rsa", True

d = {
    "username": username,
    "home": home,
    "sudo_group": sudo_group,
    "sudo_sudoers": sudo_sudoers,
    "docker": docker,
    "login_ips": [f"{login_ip}:{login_port}"],
    "key_type": kt,
    "key_type_inferred": kinf,
    "authorized_keys": auth,
    "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
    "managed": False,
}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
    rm -f "$tmp_auth"
}
