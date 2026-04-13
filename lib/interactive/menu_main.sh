# lib/interactive/menu_main.sh — 顶层交互循环与 CLI help
# -----------------------------------------------------------------------------
# 依赖：cmd_add、_list_managed_users、_list_other_users
# interactive_menu：主循环；无参数时由 user-mgmt.sh 调用
# -----------------------------------------------------------------------------

# interactive_menu — 主菜单（新建 / 已管理 / 未管理）
interactive_menu() {
    while true; do
        echo
        echo "=========================================="
        echo "         用户管理"
        echo "=========================================="
        echo
        echo "  1) 新建用户"
        echo "  2) 已管理用户"
        echo "  3) 未管理用户"
        echo
        echo "  0) 退出"
        echo

        read -p "选择操作: " choice

        case "$choice" in
            1) cmd_add ;;
            2) _list_managed_users ;;
            3) _list_other_users ;;
            0) exit 0 ;;
            *) echo "无效选择" ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
用法: user-mgmt.sh [命令]

用户管理工具

命令:
  (无参数)   进入交互模式
  add        创建新用户
  help       显示帮助

示例:
  user-mgmt.sh
  user-mgmt.sh add
EOF
}
