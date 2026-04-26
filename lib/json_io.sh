# lib/json_io.sh — managed_users JSON 写入 helper
# -----------------------------------------------------------------------------
# 通过 python3 安全转义；避免 heredoc 拼字符串导致非法 JSON。
# 依赖：python3
# -----------------------------------------------------------------------------

# _um_json_write_user <out_path> <username> <home> <sudo_sudoers> <docker> \
#                     <login_ips_csv> <key_type> <key_type_inferred> \
#                     <authorized_keys> <comment> <shell> [sudo_mode]
# login_ips_csv: 逗号分隔 "ip:port" 列表
# sudo_mode: nopasswd | password | none（缺省按 sudo_sudoers 推断）
# 额外可选 env：
#   UM_JSON_JUMP_TO_SITES=逗号分隔站点列表（如 xdg-sg2,xdg-us1）
# 字段：上述 + jump_to_sites + sudo_group=false（创建期 sudoers 走独立路径）+ created_at + managed=true
_um_json_write_user() {
    local out_path="$1"
    local username="$2"
    local home="$3"
    local sudo_sudoers="$4"
    local docker_flag="$5"
    local login_ips_csv="$6"
    local key_type="$7"
    local key_type_inferred="$8"
    local authorized_keys="$9"
    local user_comment="${10:-}"
    local login_shell="${11:-/bin/bash}"
    local sudo_mode="${12:-}"

    if ! command -v python3 &>/dev/null; then
        echo "错误: 需要 python3 写入 JSON。" >&2
        return 1
    fi

    UM_JSON_OUT_PATH="$out_path" \
    UM_JSON_USERNAME="$username" \
    UM_JSON_HOME="$home" \
    UM_JSON_SUDO_SUDOERS="$sudo_sudoers" \
    UM_JSON_SUDO_MODE="$sudo_mode" \
    UM_JSON_DOCKER="$docker_flag" \
    UM_JSON_LOGIN_IPS="$login_ips_csv" \
    UM_JSON_KEY_TYPE="$key_type" \
    UM_JSON_KEY_INFERRED="$key_type_inferred" \
    UM_JSON_AUTH_KEYS="$authorized_keys" \
    UM_JSON_COMMENT="$user_comment" \
    UM_JSON_SHELL="$login_shell" \
    UM_JSON_JUMP_TO_SITES="${UM_JSON_JUMP_TO_SITES:-}" \
    python3 - <<'PY'
import json
import os
from datetime import datetime

def asbool(v):
    return str(v).strip().lower() == "true"

login_ips_csv = os.environ.get("UM_JSON_LOGIN_IPS", "")
login_ips = [s for s in (item.strip() for item in login_ips_csv.split(",")) if s]
jump_to_sites_csv = os.environ.get("UM_JSON_JUMP_TO_SITES", "")
jump_to_sites = [s for s in (item.strip() for item in jump_to_sites_csv.split(",")) if s]

sudo_sudoers_v = asbool(os.environ.get("UM_JSON_SUDO_SUDOERS", "false"))
sudo_mode_v = os.environ.get("UM_JSON_SUDO_MODE", "")
if not sudo_mode_v:
    sudo_mode_v = "nopasswd" if sudo_sudoers_v else "none"

d = {
    "username": os.environ["UM_JSON_USERNAME"],
    "home": os.environ["UM_JSON_HOME"],
    "sudo_group": False,
    "sudo_sudoers": sudo_sudoers_v,
    "sudo_mode": sudo_mode_v,
    "docker": asbool(os.environ.get("UM_JSON_DOCKER", "false")),
    "login_ips": login_ips,
    "key_type": os.environ.get("UM_JSON_KEY_TYPE", "id_rsa"),
    "key_type_inferred": asbool(os.environ.get("UM_JSON_KEY_INFERRED", "false")),
    "authorized_keys": os.environ.get("UM_JSON_AUTH_KEYS", ""),
    "comment": os.environ.get("UM_JSON_COMMENT", ""),
    "shell": os.environ.get("UM_JSON_SHELL", "/bin/bash"),
    "jump_to_sites": jump_to_sites,
    "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
    "managed": True,
}

with open(os.environ["UM_JSON_OUT_PATH"], "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
}
