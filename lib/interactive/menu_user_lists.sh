# lib/interactive/menu_user_lists.sh — 列出「已管理 / 未管理」用户并进入子菜单
# -----------------------------------------------------------------------------
# 依赖：MANAGED_USERS_DIR、_um_passwd_local_usernames；会调用 _user_action_menu / _other_user_menu
# 未管理 = JSON 中 managed:false，或尚无 JSON 的本地 UID 用户（见 lib/stub_unmanaged_user.sh）
# -----------------------------------------------------------------------------

_list_managed_users() {
    echo "=========================================="
    echo "         已管理用户"
    echo "=========================================="
    echo "(按 ESC 返回主菜单)"
    echo

    users=()
    json_files=()

    for json_file in "$MANAGED_USERS_DIR"/*.json; do
        [[ -e "$json_file" ]] || continue
        username=$(basename "$json_file" .json)
        managed=$(grep '"managed"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
        if [[ "$managed" == "false" ]]; then
            continue
        fi
        users+=("$username")
        json_files+=("$json_file")
    done

    if [[ ${#users[@]} -eq 0 ]]; then
        echo "暂无已管理用户"
        echo
        read -p "按回车继续..." _
        return
    fi

    i=1
    for u in "${users[@]}"; do
        echo "  $i) $u"
        ((i++))
    done
    echo

    while true; do
        read -p "选择用户编号 (或 ESC 返回): " choice

        if [[ "$choice" == $'\e' ]]; then
            return
        fi

        if [[ -z "$choice" ]]; then
            continue
        fi

        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
            echo "无效选择"
            continue
        fi

        idx=$((choice - 1))
        _user_action_menu "${users[$idx]}" "${json_files[$idx]}"
        break
    done
}

_list_other_users() {
    echo "=========================================="
    echo "         未管理用户"
    echo "=========================================="
    echo "(按 ESC 返回主菜单)"
    echo

    users=()
    json_files=()

    for json_file in "$MANAGED_USERS_DIR"/*.json; do
        [[ -e "$json_file" ]] || continue
        username=$(basename "$json_file" .json)
        managed=$(grep '"managed"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/' || true)
        if [[ "$managed" != "false" ]]; then
            continue
        fi
        users+=("$username")
        json_files+=("$json_file")
    done

    while IFS= read -r pname; do
        [[ -z "$pname" ]] && continue
        if [[ -f "$MANAGED_USERS_DIR/${pname}.json" ]]; then
            continue
        fi
        users+=("$pname")
        json_files+=("$MANAGED_USERS_DIR/${pname}.json")
    done < <(_um_passwd_local_usernames | sort -u)

    if [[ ${#users[@]} -eq 0 ]]; then
        echo "没有未管理用户"
        echo
        read -p "按回车继续..." _
        return
    fi

    i=1
    for u in "${users[@]}"; do
        echo "  $i) $u"
        ((i++))
    done
    echo

    while true; do
        read -p "选择用户编号 (或 ESC 返回): " choice

        if [[ "$choice" == $'\e' ]]; then
            return
        fi

        if [[ -z "$choice" ]]; then
            continue
        fi

        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
            echo "无效选择"
            continue
        fi

        idx=$((choice - 1))
        _other_user_menu "${users[$idx]}" "${json_files[$idx]}"
        break
    done
}
