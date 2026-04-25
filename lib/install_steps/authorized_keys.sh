# lib/install_steps/authorized_keys.sh — ~/.ssh/authorized_keys 锚点段
# 依赖：_um_anchor_*
# 输入：UM_AUTHORIZED_KEYS（环境变量，apply 前由调用方设置；多行公钥）
# 锚点名：authorized_keys
# 不破坏用户已有的非托管公钥：仅写入并删除自己锚定的段。
# -----------------------------------------------------------------------------

UM_STEPS+=(authorized_keys)

um_step_authorized_keys_label()   { echo "写入 ~/.ssh/authorized_keys（锚点段）"; }
um_step_authorized_keys_default() { echo "true"; }

um_step_authorized_keys_status() {
    local home="$2"
    _um_anchor_present "$home/.ssh/authorized_keys" "authorized_keys"
}

um_step_authorized_keys_apply() {
    local user="$1" home="$2" json_file="${3:-}"

    sudo mkdir -p "$home/.ssh"
    sudo chown "$user:$user" "$home/.ssh"
    sudo chmod 700 "$home/.ssh"

    if ! sudo test -f "$home/.ssh/authorized_keys"; then
        sudo touch "$home/.ssh/authorized_keys"
        sudo chown "$user:$user" "$home/.ssh/authorized_keys"
    fi

    # 内容来源优先级：UM_AUTHORIZED_KEYS env（且像 ssh-* 公钥）→ JSON 字段（list 或 string）
    local content="${UM_AUTHORIZED_KEYS:-}"
    if [[ -n "$content" && ! "$content" =~ ^ssh- ]]; then
        content=""
    fi
    if [[ -z "$content" && -n "$json_file" && -f "$json_file" ]] && command -v python3 &>/dev/null; then
        content="$(UM_JSON="$json_file" python3 - <<'PY'
import json, os
with open(os.environ["UM_JSON"]) as f:
    d = json.load(f)
v = d.get("authorized_keys", "")
out = []
if isinstance(v, list):
    out = [k for k in v if isinstance(k, str) and k.strip()]
elif isinstance(v, str):
    if v.strip():
        out = [v]
print("\n".join(out))
PY
)"
    fi

    if [[ -z "$content" ]]; then
        echo "跳过 authorized_keys：env 与 JSON 中均无公钥" >&2
    else
        printf '%s\n' "$content" | _um_anchor_write "$home/.ssh/authorized_keys" "authorized_keys" "$user"
    fi

    sudo chmod 600 "$home/.ssh/authorized_keys"
}

um_step_authorized_keys_remove() {
    local user="$1" home="$2"
    _um_anchor_strip "$home/.ssh/authorized_keys" "authorized_keys" "#" "$user"
}
