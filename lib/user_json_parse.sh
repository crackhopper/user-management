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

    # python3 兜底：login_ips、authorized_keys 在 JSON 多行 list 格式下 grep+sed 拿不到正确值
    if command -v python3 &>/dev/null; then
        local _vals _ip _port _rest _ak
        _vals="$(UM_JSON="$json_file" python3 - <<'PY'
import json, os, sys
with open(os.environ["UM_JSON"]) as f:
    d = json.load(f)
li = d.get("login_ips", [])
ip = ""; port = ""
if isinstance(li, list) and li:
    s = li[0]
    if isinstance(s, str) and ":" in s:
        ip, _, port = s.rpartition(":")
ak = d.get("authorized_keys", "")
if isinstance(ak, list):
    ak = "\n".join(k for k in ak if isinstance(k, str) and k.strip())
elif not isinstance(ak, str):
    ak = ""
sys.stdout.write(ip + "\x1f" + port + "\x1f" + ak)
PY
)"
        _ip="${_vals%%$'\x1f'*}"
        _rest="${_vals#*$'\x1f'}"
        _port="${_rest%%$'\x1f'*}"
        _ak="${_rest#*$'\x1f'}"
        [[ -n "$_ip" ]] && login_ip="$_ip"
        [[ -n "$_port" ]] && login_port="$_port"
        [[ -n "$_ak" ]] && authorized_keys="$_ak"
    fi
}
