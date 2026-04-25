# lib/install_steps/cursor_agent.sh — Cursor CLI（cursor-agent）
# Cursor 不发 npm 包；用官方 curl 安装：https://cursor.com/install
# 二进制名：cursor-agent（旧别名 agent）
# -----------------------------------------------------------------------------

UM_STEPS+=(cursor_agent)

um_step_cursor_agent_label()   { echo "Cursor CLI（cursor-agent；curl 官方脚本安装）"; }
um_step_cursor_agent_default() { echo "true"; }

um_step_cursor_agent_status() {
    local user="$1"
    _um_user_sh "$user" 'command -v cursor-agent >/dev/null 2>&1 || command -v agent >/dev/null 2>&1' \
        && echo true || echo false
}

um_step_cursor_agent_apply() {
    local user="$1"
    _um_user_sh "$user" 'curl -fsSL https://cursor.com/install | bash'
}

um_step_cursor_agent_remove() {
    local user="$1"
    _um_user_sh "$user" 'rm -rf "$HOME/.cursor" "$HOME/.local/bin/cursor-agent" "$HOME/.local/bin/agent"' || true
    echo "已删 ~/.cursor 与 ~/.local/bin/{cursor-agent,agent}；.bashrc 中 PATH 行需手工清理" >&2
}
