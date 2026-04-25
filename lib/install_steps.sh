# lib/install_steps.sh — 用户预装步骤注册表
# -----------------------------------------------------------------------------
# 每一种「预装内容」是一个独立 step 文件：lib/install_steps/<name>.sh
# 文件需向 UM_STEPS 追加自身 key，并定义：
#   um_step_<key>_label       中文描述
#   um_step_<key>_default     回显 true|false（默认开启，可读 .env）
#   um_step_<key>_status  user home -> 回显 true|false（是否已部署）
#   um_step_<key>_apply   user home json_file
#   um_step_<key>_remove  user home json_file
#
# 添加新预装内容只需在 lib/install_steps/ 加 .sh 文件，无需改其他文件。
# -----------------------------------------------------------------------------

UM_STEPS=()

# _um_steps_load — source 全部 lib/install_steps/*.sh
_um_steps_load() {
    local f
    [[ -d "$SCRIPT_DIR/lib/install_steps" ]] || return 0
    for f in "$SCRIPT_DIR/lib/install_steps"/*.sh; do
        [[ -e "$f" ]] || continue
        # shellcheck source=/dev/null
        source "$f"
    done
}

# _um_step_call <key> <verb> <args...>
# verb: label | default | status | apply | remove
_um_step_call() {
    local key="$1"
    local verb="$2"
    shift 2
    local fn="um_step_${key}_${verb}"
    if ! declare -F "$fn" &>/dev/null; then
        echo "错误: step $key 缺少 $verb 实现 ($fn)" >&2
        return 1
    fi
    "$fn" "$@"
}

# _um_step_known <key> -> 0/1
_um_step_known() {
    local key="$1" k
    for k in "${UM_STEPS[@]}"; do
        [[ "$k" == "$key" ]] && return 0
    done
    return 1
}

# _um_user_sh <user> <cmd>
# 在用户身份下跑命令。
# - bash --noprofile --norc：不读用户 .bash_profile / .bashrc（避免触发用户启动脚本里
#   的副作用，如 Claude Code shell snapshot 的 set -u + 未守卫 $ZSH_VERSION 致命退出）
# - env -u BASH_ENV：清除 BASH_ENV（否则非交互 bash 仍会 source 它指向的文件）
# - preamble：显式加 nvm + ~/.local/bin 到 PATH
# - printf | bash：走 stdin 传 cmd，多行不被 sudo -i 的参数 join 吞换行
_um_user_sh() {
    local user="$1" cmd="$2"
    local preamble='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"'
    printf '%s\n%s\n' "$preamble" "$cmd" \
        | sudo -u "$user" -H env -u BASH_ENV bash --noprofile --norc
}
