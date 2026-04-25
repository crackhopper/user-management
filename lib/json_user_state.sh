# lib/json_user_state.sh — 用户 JSON 与系统状态对齐（Python）
# -----------------------------------------------------------------------------
# 依赖：MANAGED_USERS_DIR、SCRIPT_DIR 无关；需 python3。
# 将 managed_users 下 JSON 中的 sudo/docker 等与 id、/etc/sudoers.d 对齐，
# 并迁移旧字段 "sudo" -> sudo_group + sudo_sudoers。
# -----------------------------------------------------------------------------

# _merge_json_sudo_from_system json路径 用户名 mode
# mode:
#   sync    — 写 last_synced（完整「同步」后调用）
#   refresh — 仅按当前系统刷新 sudo_group / sudo_sudoers / docker（启用或禁用 sudo 后）
#   track   — managed=true 并刷新（纳入管理流程）
# 副作用：覆盖写入 json_file。
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
sudoers_path = f'/etc/sudoers.d/{username}'
d['sudo_sudoers'] = os.path.isfile(sudoers_path)
d['docker'] = 'docker' in gs

if d['sudo_sudoers']:
    try:
        with open(sudoers_path) as sf:
            content = sf.read()
        d['sudo_mode'] = 'nopasswd' if 'NOPASSWD' in content else 'password'
    except OSError:
        d['sudo_mode'] = 'unknown'
else:
    d['sudo_mode'] = 'none'

if mode == 'sync':
    d['last_synced'] = datetime.now().astimezone().isoformat(timespec='seconds')
    if 'managed' not in d:
        d['managed'] = True
elif mode == 'track':
    d['managed'] = True

with open(path, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$json_file" "$username" "$mode"
}
