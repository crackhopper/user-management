#!/bin/bash
# bin/purge-user.sh — 暴力清理失败/残留用户
# 处理范围：系统用户、同名组、home、sudoers drop-in、JSON、mail spool、活跃进程
# 与 bin/delete-managed-user.sh 区别：不要求 JSON 存在；任意残留状态都能清干净
# -----------------------------------------------------------------------------
# 不开 set -e：让每一步独立尝试，部分失败也继续清下一项
set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/lib/bootstrap.sh"
um_bootstrap "${BASH_SOURCE[0]}"

usage() {
    cat <<EOF
用法: $0 <username> [--yes]

暴力清理用户残留：
  - 系统用户 (userdel -rf)
  - 同名组 (groupdel)
  - home 目录 (/home/<user> 与 \$UM_HOME_PARENT/<user>)
  - /etc/sudoers.d/<user>
  - managed_users/<user>.json
  - /var/mail/<user>、/var/spool/mail/<user>
  - 该用户的活跃进程 (pkill -KILL)

选项:
  --yes  跳过交互确认（CI 用）
EOF
    exit 1
}

user="${1:-}"
[[ -z "$user" ]] && usage

assume_yes=false
[[ "${2:-}" == "--yes" ]] && assume_yes=true

[[ "$user" =~ ^[a-z][a-z0-9_-]*$ ]] || { echo "用户名格式异常: $user" >&2; exit 1; }
[[ "$user" == "root" ]] && { echo "拒绝清理 root" >&2; exit 1; }

echo "=========================================="
echo "         残留检查 [$user]"
echo "=========================================="
id "$user" &>/dev/null && echo "  系统用户：存在 (uid=$(id -u "$user"))" || echo "  系统用户：无"
getent group "$user" &>/dev/null && echo "  系统组：存在" || echo "  系统组：无"
[[ -d "/home/$user" ]] && echo "  /home/$user：存在" || echo "  /home/$user：无"
if [[ -n "${UM_HOME_PARENT:-}" && "$UM_HOME_PARENT" != "/home" ]]; then
    [[ -d "$UM_HOME_PARENT/$user" ]] && echo "  $UM_HOME_PARENT/$user：存在" || echo "  $UM_HOME_PARENT/$user：无"
fi
sudo test -f "/etc/sudoers.d/$user" && echo "  /etc/sudoers.d/$user：存在" || echo "  /etc/sudoers.d/$user：无"
[[ -f "$MANAGED_USERS_DIR/$user.json" ]] && echo "  managed_users/$user.json：存在" || echo "  managed_users/$user.json：无"
echo

if [[ "$assume_yes" != "true" ]]; then
    read -p "确认彻底清理 $user？[y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }
fi

echo
echo "=========================================="
echo "         清理中..."
echo "=========================================="

# 1. 杀该用户进程
if id "$user" &>/dev/null; then
    sudo pkill -KILL -u "$user" 2>/dev/null || true
    sleep 1
fi

# 2. userdel
if id "$user" &>/dev/null; then
    sudo userdel -rf "$user" 2>/dev/null || sudo userdel -f "$user" 2>/dev/null || true
fi

# 3. 同名组残留
if getent group "$user" &>/dev/null; then
    sudo groupdel "$user" 2>/dev/null || true
fi

# 4. home 残留（userdel -r 失败时兜底）
sudo rm -rf "/home/$user" 2>/dev/null || true
if [[ -n "${UM_HOME_PARENT:-}" && "$UM_HOME_PARENT" != "/home" ]]; then
    sudo rm -rf "$UM_HOME_PARENT/$user" 2>/dev/null || true
fi

# 5. sudoers
sudo rm -f "/etc/sudoers.d/$user" 2>/dev/null || true

# 6. JSON
rm -f "$MANAGED_USERS_DIR/$user.json" 2>/dev/null || true

# 7. mail spool
sudo rm -f "/var/mail/$user" "/var/spool/mail/$user" 2>/dev/null || true

echo
echo "=========================================="
echo "         复检"
echo "=========================================="
miss=0
id "$user" &>/dev/null            && { echo "  系统用户：仍在 ⚠"; miss=1; } || echo "  系统用户：✓ 已清"
getent group "$user" &>/dev/null  && { echo "  系统组：仍在 ⚠";   miss=1; } || echo "  系统组：✓ 已清"
[[ -d "/home/$user" ]]            && { echo "  /home/$user：仍在 ⚠"; miss=1; } || echo "  /home/$user：✓ 已清"
sudo test -f "/etc/sudoers.d/$user" && { echo "  sudoers：仍在 ⚠";   miss=1; } || echo "  sudoers：✓ 已清"
[[ -f "$MANAGED_USERS_DIR/$user.json" ]] && { echo "  JSON：仍在 ⚠"; miss=1; } || echo "  JSON：✓ 已清"

echo
if [[ $miss -eq 0 ]]; then
    echo "✅ $user 已彻底清理"
else
    echo "⚠ 仍有残留；可能是用户在登录中或文件被占用，重试或手工清理"
    exit 1
fi
