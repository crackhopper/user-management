# lib/bootstrap.sh — bin/<entry>.sh 通用引导
# -----------------------------------------------------------------------------
# 用法（在 bin/ 入口脚本顶部，紧跟 set -euo pipefail）：
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/lib/bootstrap.sh"
#   um_bootstrap "${BASH_SOURCE[0]}" config json_user_state ops/create_user
#
# 每个位置参数对应 lib/<arg>.sh，按顺序 source。
# 始终先 source lib/paths.sh 与 lib/config.sh，并设置 SCRIPT_DIR。
# -----------------------------------------------------------------------------

um_bootstrap() {
    local entry="$1"
    shift

    local _bin_here
    _bin_here="$(cd "$(dirname "$entry")" && pwd)"

    # shellcheck source=paths.sh
    source "$_bin_here/../lib/paths.sh"
    SCRIPT_DIR="$(um_project_root_from_bin_path "$entry")"

    # shellcheck source=config.sh
    source "$SCRIPT_DIR/lib/config.sh"

    local mod
    for mod in "$@"; do
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/${mod}.sh"
    done
}
