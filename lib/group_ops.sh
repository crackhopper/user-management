# lib/group_ops.sh — 跨发行版组操作
# -----------------------------------------------------------------------------
# Debian/Ubuntu：deluser/usermod
# RHEL/CentOS/Alpine：gpasswd -d
# 优先 gpasswd（util-linux 一般都有），fallback deluser
# -----------------------------------------------------------------------------

# _um_group_remove_user <username> <group>
# 用户不在组里也不报错
_um_group_remove_user() {
    local username="$1"
    local group="$2"
    if command -v gpasswd &>/dev/null; then
        sudo gpasswd -d "$username" "$group" 2>/dev/null || true
    elif command -v deluser &>/dev/null; then
        sudo deluser "$username" "$group" 2>/dev/null || true
    else
        return 0
    fi
}
