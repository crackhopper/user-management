# lib/install_steps/0_pipx_runtime.sh — pipx 运行时（系统级）
# 文件名 0_ 前缀让其先于 pipx_mkdocs_material、uv 被询问
# step key：pipx_runtime
# -----------------------------------------------------------------------------

UM_STEPS+=(pipx_runtime)

um_step_pipx_runtime_label()   { echo "pipx 运行时（系统级 apt/dnf/apk/pacman）"; }
um_step_pipx_runtime_default() { echo "true"; }

um_step_pipx_runtime_status() {
    command -v pipx &>/dev/null && echo true || echo false
}

um_step_pipx_runtime_apply() {
    local user="$1"
    if command -v pipx &>/dev/null; then
        : # 已装
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y pipx
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y pipx
    elif command -v apk &>/dev/null; then
        sudo apk add py3-pipx
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm python-pipx
    else
        echo "未识别包管理器，跳过 pipx_runtime" >&2
        return 1
    fi
    _um_user_sh "$user" 'pipx ensurepath' || true
}

um_step_pipx_runtime_remove() {
    if command -v apt-get &>/dev/null; then
        sudo apt-get remove -y pipx || true
    elif command -v dnf &>/dev/null; then
        sudo dnf remove -y pipx || true
    elif command -v apk &>/dev/null; then
        sudo apk del py3-pipx || true
    elif command -v pacman &>/dev/null; then
        sudo pacman -Rns --noconfirm python-pipx || true
    fi
}
