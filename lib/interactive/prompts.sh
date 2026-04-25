# lib/interactive/prompts.sh — 交互输入 helper
# -----------------------------------------------------------------------------
# 统一处理：必填 / 默认值 / y/N / ESC 返回。
# 返回值：成功 0；ESC 返回 2（调用方据此 return）。
# 输出全局 ANSWER（避免 subshell 丢值）。
# -----------------------------------------------------------------------------

# _ask_required <prompt>
_ask_required() {
    local prompt="$1"
    while true; do
        read -p "$prompt: " ANSWER
        [[ "$ANSWER" == $'\e' ]] && return 2
        [[ -n "$ANSWER" ]] && return 0
        echo "不能为空"
    done
}

# _ask_required_secret <prompt> — 隐藏输入
_ask_required_secret() {
    local prompt="$1"
    while true; do
        read -srp "$prompt: " ANSWER
        echo
        [[ "$ANSWER" == $'\e' ]] && return 2
        [[ -n "$ANSWER" ]] && return 0
        echo "不能为空"
    done
}

# _ask_default <prompt> <default>
_ask_default() {
    local prompt="$1"
    local default="$2"
    read -p "${prompt} [${default}]: " ANSWER
    [[ "$ANSWER" == $'\e' ]] && return 2
    [[ -z "$ANSWER" ]] && ANSWER="$default"
    return 0
}

# _ask_yn <prompt> <default_bool>
# default_bool: true|false。ANSWER=true|false。
_ask_yn() {
    local prompt="$1"
    local default_bool="$2"
    local hint
    if [[ "$default_bool" == "true" ]]; then
        hint="Y/n"
    else
        hint="y/N"
    fi
    read -p "${prompt} [${hint}]: " in
    [[ "$in" == $'\e' ]] && return 2
    if [[ -z "$in" ]]; then
        ANSWER="$default_bool"
    elif [[ "$in" =~ ^[Yy]$ ]]; then
        ANSWER=true
    elif [[ "$in" =~ ^[Nn]$ ]]; then
        ANSWER=false
    else
        ANSWER="$default_bool"
    fi
    return 0
}
