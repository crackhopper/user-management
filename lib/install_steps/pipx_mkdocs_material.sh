# lib/install_steps/pipx_mkdocs_material.sh — pipx 装 mkdocs-material（含依赖）
# mkdocs-material 自身是 library（无 CLI entry）。用 --include-deps 暴露
# 依赖包（mkdocs、ghp-import、pybabel 等）的 CLI entry。
# inject pillow + cairosvg 提供社交卡片所需图像处理。
# 依赖：用户登录 shell 中可用 pipx（缺则 apply 时 system 装）
# -----------------------------------------------------------------------------

UM_STEPS+=(pipx_mkdocs_material)

# 主包（带 --include-deps）
PIPX_MK_PRIMARY="mkdocs-material"
# inject 进同 venv 的图像依赖
PIPX_MK_INJECTS=(pillow cairosvg)

um_step_pipx_mkdocs_material_label()   { echo "pipx：mkdocs-material --include-deps（含 pillow/cairosvg 图像依赖）"; }
um_step_pipx_mkdocs_material_default() { echo "true"; }

_um_step_pipx_mk_user_sh() {
    _um_user_sh "$@"
}

um_step_pipx_mkdocs_material_status() {
    local user="$1"
    if ! _um_step_pipx_mk_user_sh "$user" 'command -v pipx' &>/dev/null; then
        echo false; return 0
    fi
    # 检查 inject 后的列表是否含 mkdocs-material
    local listing
    listing="$(_um_step_pipx_mk_user_sh "$user" 'pipx list --include-injected 2>/dev/null' || true)"
    grep -qF -- "mkdocs-material" <<<"$listing" && echo true || echo false
}

um_step_pipx_mkdocs_material_apply() {
    local user="$1"

    # 1. pipx 缺时按系统包管理器装
    if ! _um_step_pipx_mk_user_sh "$user" 'command -v pipx' &>/dev/null; then
        echo "pipx 不可用，尝试系统级安装 ..." >&2
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y pipx
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y pipx
        elif command -v apk &>/dev/null; then
            sudo apk add py3-pipx
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm python-pipx
        else
            echo "未识别包管理器，跳过 pipx_mkdocs_material（请手工装 pipx）" >&2
            return 1
        fi
        _um_step_pipx_mk_user_sh "$user" 'pipx ensurepath' || true
    fi

    # 2. 重新探测
    if ! _um_step_pipx_mk_user_sh "$user" 'command -v pipx' &>/dev/null; then
        echo "跳过 pipx_mkdocs_material：$user 仍找不到 pipx" >&2
        return 1
    fi

    # 3. 装主包（带 --include-deps 暴露依赖包的 CLI），inject 图像依赖
    # --force：若上次没带 --include-deps 装过，强制重装以暴露 CLI
    _um_step_pipx_mk_user_sh "$user" "pipx install --force --include-deps '$PIPX_MK_PRIMARY'" || true
    local injects="${PIPX_MK_INJECTS[*]}"
    _um_step_pipx_mk_user_sh "$user" "pipx inject '$PIPX_MK_PRIMARY' $injects" || true
}

um_step_pipx_mkdocs_material_remove() {
    local user="$1"
    _um_step_pipx_mk_user_sh "$user" 'command -v pipx' &>/dev/null || return 0
    # 卸载 mkdocs venv 即同时清掉所有 inject 的 library
    _um_step_pipx_mk_user_sh "$user" "pipx uninstall '$PIPX_MK_PRIMARY'" || true
}
