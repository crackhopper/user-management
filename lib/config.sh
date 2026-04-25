# lib/config.sh — 路径与全局环境
# -----------------------------------------------------------------------------
# 由 user-mgmt.sh 在设置好 SCRIPT_DIR 之后 source。
# 导出：MANAGED_USERS_DIR、SCRIPTS_SRC、UM_PROXY_*、HOST_NAME、ESCAPE_KEY 等。
# 依赖：调用方必须先设置 SCRIPT_DIR 为项目根目录。
# -----------------------------------------------------------------------------

MANAGED_USERS_DIR="$SCRIPT_DIR/managed_users"
SCRIPTS_SRC="$SCRIPT_DIR/templates"

# .bashrc 中 proxy 段锚点（须与 sed / tee 一致）
UM_PROXY_BEGIN='# BEGIN user_management proxy (templates/proxy.sh)'
UM_PROXY_END='# END user_management proxy'

if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/.env"
    set +a
fi
HOST_NAME="${HOSTNAME:-$(hostname)}"
HOST_IP="${HOST_IP:-}"

# 新建用户默认 home 父目录（例如 /home 或 /data/home）
UM_HOME_PARENT="${UM_HOME_PARENT:-/home}"
UM_HOME_PARENT="${UM_HOME_PARENT%/}"

# 新建用户默认是否部署 ~/scripts（仅复制 templates/，不再隐含写入 proxy 段）
UM_DEPLOY_SCRIPTS_DEFAULT="${UM_DEPLOY_SCRIPTS_DEFAULT:-false}"

# 新建用户默认是否在 ~/.bashrc 写入 proxy 段（独立于 scripts 部署）
UM_CONFIGURE_PROXY_DEFAULT="${UM_CONFIGURE_PROXY_DEFAULT:-false}"

ESCAPE_KEY=$'\e'
BACK_ESCAPE=$'^[['
