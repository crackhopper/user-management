# lib/interactive/menu_modules.sh — 预装模块管理菜单
# -----------------------------------------------------------------------------
# 提供：
#   1) 列出所有模块
#   2) 选择模块后查看说明 + 在指定用户上 探测/安装/卸载 + 全用户状态总览
#   3) 提示如何添加新模块（lib/install_steps/_template.sh.example）
# 依赖：UM_STEPS、_um_step_call、_load_user_data、MANAGED_USERS_DIR、
#       _merge_json_sudo_from_system（可选）
# -----------------------------------------------------------------------------

_modules_menu() {
    while true; do
        echo
        echo "=========================================="
        echo "         预装模块管理"
        echo "=========================================="
        echo
        if [[ ${#UM_STEPS[@]} -eq 0 ]]; then
            echo "(无)"
            echo "添加新模块：复制 lib/install_steps/_template.sh.example 为 lib/install_steps/<key>.sh"
            echo
            read -p "按回车返回..." _
            return
        fi

        local i key label default
        i=1
        for key in "${UM_STEPS[@]}"; do
            label="$(_um_step_call "$key" label 2>/dev/null || echo "$key")"
            default="$(_um_step_call "$key" default 2>/dev/null || echo "?")"
            printf "  %d) %-20s — %s [默认: %s]\n" "$i" "$key" "$label" "$default"
            ((i++))
        done
        echo
        echo "  a) 如何添加新模块"
        echo "  0) 返回"
        echo

        read -p "选择: " choice
        case "$choice" in
            a|A) _modules_help_add ;;
            0) return ;;
            "") continue ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#UM_STEPS[@]} ]]; then
                    _module_actions_menu "${UM_STEPS[$((choice-1))]}"
                else
                    echo "无效选择"
                fi
                ;;
        esac
    done
}

_modules_help_add() {
    cat <<'EOF'

==========================================
         如何添加新预装模块
==========================================

1. 复制模板：
     cp lib/install_steps/_template.sh.example lib/install_steps/<your_key>.sh

2. 替换文件中的 your_step_name 为 <your_key>。

3. 实现 5 个函数：label / default / status / apply / remove。
   - apply / remove 必须可重复执行（幂等）
   - status 必须输出 "true" 或 "false"
   - 写用户文件时建议用 _um_anchor_write/_um_anchor_strip，便于 remove 只清理本模块

4. 重新进入主菜单（或重新 source user-mgmt.sh）即被自动加载。

参考 lib/install_steps/_template.sh.example 中的 npm/pipx/apt/bashrc 范式。
==========================================
EOF
    read -p "按回车继续..." _
}

_module_actions_menu() {
    local key="$1"
    local label
    label="$(_um_step_call "$key" label 2>/dev/null || echo "$key")"

    while true; do
        echo
        echo "=========================================="
        echo "         模块: $key"
        echo "         $label"
        echo "=========================================="
        echo
        echo "  1) 探测某用户是否已安装"
        echo "  2) 在某用户上安装 (apply)"
        echo "  3) 在某用户上卸载 (remove)"
        echo "  4) 全用户状态总览"
        echo
        echo "  0) 返回"
        echo

        read -p "选择: " choice
        case "$choice" in
            1) _module_run_on_user "$key" status ;;
            2) _module_run_on_user "$key" apply ;;
            3) _module_run_on_user "$key" remove ;;
            4) _module_overview "$key" ;;
            0) return ;;
            *) echo "无效选择" ;;
        esac
    done
}

# _module_run_on_user <key> <verb>
_module_run_on_user() {
    local key="$1"
    local verb="$2"

    local users=()
    local f
    for f in "$MANAGED_USERS_DIR"/*.json; do
        [[ -e "$f" ]] || continue
        users+=("$(basename "$f" .json)")
    done

    if [[ ${#users[@]} -eq 0 ]]; then
        echo "暂无管理用户"
        read -p "按回车继续..." _
        return
    fi

    local i=1 u
    for u in "${users[@]}"; do
        printf "  %d) %s\n" "$i" "$u"
        ((i++))
    done
    echo
    read -p "选择用户编号: " idx
    [[ "$idx" =~ ^[0-9]+$ ]] && [[ "$idx" -ge 1 ]] && [[ "$idx" -le ${#users[@]} ]] || { echo "无效选择"; return; }

    local username="${users[$((idx-1))]}"
    local json_file="$MANAGED_USERS_DIR/${username}.json"
    _load_user_data "$json_file"

    case "$verb" in
        status)
            local s
            s="$(_um_step_call "$key" status "$username" "$home_dir" 2>/dev/null || echo unknown)"
            echo "$key on $username: $s"
            ;;
        apply)
            if [[ "$key" == "authorized_keys" ]]; then
                UM_AUTHORIZED_KEYS="$authorized_keys" \
                    _um_step_call "$key" apply "$username" "$home_dir" "$json_file"
                unset UM_AUTHORIZED_KEYS
            else
                _um_step_call "$key" apply "$username" "$home_dir" "$json_file"
            fi
            echo "✅ 已 apply $key on $username"
            if declare -F _merge_json_sudo_from_system &>/dev/null; then
                _merge_json_sudo_from_system "$json_file" "$username" refresh
            fi
            ;;
        remove)
            _um_step_call "$key" remove "$username" "$home_dir" "$json_file"
            echo "✅ 已 remove $key on $username"
            if declare -F _merge_json_sudo_from_system &>/dev/null; then
                _merge_json_sudo_from_system "$json_file" "$username" refresh
            fi
            ;;
    esac
    read -p "按回车继续..." _
}

# _module_overview <key>
_module_overview() {
    local key="$1"
    echo
    printf "%-20s %s\n" "用户" "状态"
    echo "----------------------------------------"
    local f username s
    for f in "$MANAGED_USERS_DIR"/*.json; do
        [[ -e "$f" ]] || continue
        username="$(basename "$f" .json)"
        _load_user_data "$f"
        if id "$username" &>/dev/null; then
            s="$(_um_step_call "$key" status "$username" "$home_dir" 2>/dev/null || echo unknown)"
        else
            s="(系统用户不存在)"
        fi
        printf "%-20s %s\n" "$username" "$s"
    done
    echo
    read -p "按回车继续..." _
}
