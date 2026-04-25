# lib/interactive/cmd_user_sync_and_sudo.sh — 同步用户环境、sudo、纳入管理（track）
# -----------------------------------------------------------------------------
# 依赖：_load_user_data、_merge_json_sudo_from_system、_um_proxy_block_write、_um_group_remove_user
#       MANAGED_USERS_DIR、SCRIPTS_SRC
# _sync_single_user：覆盖 ~/scripts、刷新 .bashrc proxy 段、merge JSON(mode=sync)
# _enable_sudo / _disable_sudo：改系统后 merge(mode=refresh)
# _track_user：按问答改 sudoers/docker 后 merge(mode=track)
# -----------------------------------------------------------------------------

# _sync_single_user 用户名 json路径
_sync_single_user() {
    local username="$1"
    local json_file="$2"

    _load_user_data "$json_file"

    if ! id "$username" &>/dev/null; then
        echo "用户 $username 不存在"
        return
    fi

    echo "同步 $username ($home_dir) ..."

    echo "  同步 scripts ..."
    sudo rm -rf "$home_dir/scripts"
    sudo cp -r "$SCRIPTS_SRC" "$home_dir/scripts"
    sudo chown -R "$username:$username" "$home_dir/scripts"

    echo "  更新 proxy 段 ..."
    _um_proxy_block_write "$home_dir/.bashrc" "$username"

    _merge_json_sudo_from_system "$json_file" "$username" sync

    echo "✅ $username 已同步"
    read -p "按回车继续..." _
}

# _enable_sudo 用户名 — 写 /etc/sudoers.d，支持 NOPASSWD/需要密码二选一
# 已启用 sudo 的用户重新跑此项 = 切换 sudo 模式（覆盖原 sudoers 文件）
_enable_sudo() {
    local username="$1"
    local json_file="$MANAGED_USERS_DIR/${username}.json"

    local current="none"
    if declare -F um_step_sudoers_mode &>/dev/null; then
        current="$(um_step_sudoers_mode "$username" 2>/dev/null || echo none)"
    fi
    echo "当前 sudo 模式：$current"

    echo "目标 sudo 模式："
    echo "  1) NOPASSWD（无需密码）"
    echo "  2) 需要密码（标准 sudo）"
    read -p "选择 [1]: " mode_choice
    local require_password="false"
    case "$mode_choice" in
        2) require_password="true" ;;
        *) require_password="false" ;;
    esac

    UM_SUDO_REQUIRE_PASSWORD="$require_password" \
        _um_step_call sudoers apply "$username" "" "$json_file"

    if [[ -f "$json_file" ]]; then
        _merge_json_sudo_from_system "$json_file" "$username" refresh
    fi

    if [[ "$require_password" == "true" ]]; then
        echo "已启用 $username 的 sudo（标准 sudo，需密码）"
    else
        echo "已启用 $username 的 sudo（NOPASSWD）"
    fi
    read -p "按回车继续..." _
}

# _disable_sudo 用户名 — 删除 sudoers 并尝试移出 sudo 组，再刷新 JSON
_disable_sudo() {
    local username="$1"
    local json_file="$MANAGED_USERS_DIR/${username}.json"
    sudo rm -f "/etc/sudoers.d/$username"
    _um_group_remove_user "$username" sudo
    if [[ -f "$json_file" ]]; then
        _merge_json_sudo_from_system "$json_file" "$username" refresh
    fi
    echo "已禁用 $username 的 sudo（已移除 sudoers 与 sudo 组）"
    read -p "按回车继续..." _
}

# _reconfigure_user 用户名 json路径 — 遍历 UM_STEPS 逐项 apply/remove
# 与 cmd_add 一对一对应：每个预装项都可独立切换；BEGIN/END 锚点保证可干净移除
_reconfigure_user() {
    local username="$1"
    local json_file="$2"

    _load_user_data "$json_file"

    if ! id "$username" &>/dev/null; then
        echo "用户 $username 不存在"
        return
    fi

    if [[ ${#UM_STEPS[@]} -eq 0 ]]; then
        echo "未发现可用步骤（lib/install_steps/）"
        return
    fi

    echo
    echo "重新配置 $username（$home_dir）"
    echo "对每个预装项选择：是否启用（y=apply，n=remove，回车=保持）"
    echo

    local key label status want
    for key in "${UM_STEPS[@]}"; do
        label="$(_um_step_call "$key" label)"
        status="$(_um_step_call "$key" status "$username" "$home_dir" 2>/dev/null || echo unknown)"
        echo "[$key] $label"
        echo "  当前状态: $status"

        if [[ "$status" == "true" ]]; then
            _ask_yn "  保留此预装项" "true" || return
        else
            _ask_yn "  应用此预装项" "false" || return
        fi
        want="$ANSWER"

        if [[ "$want" == "true" && "$status" != "true" ]]; then
            if [[ "$key" == "authorized_keys" && -n "${authorized_keys:-}" ]]; then
                UM_AUTHORIZED_KEYS="$authorized_keys" \
                    _um_step_call "$key" apply "$username" "$home_dir" "$json_file"
                unset UM_AUTHORIZED_KEYS
            else
                _um_step_call "$key" apply "$username" "$home_dir" "$json_file"
            fi
            echo "  ✅ 已应用 $key"
        elif [[ "$want" != "true" && "$status" == "true" ]]; then
            _um_step_call "$key" remove "$username" "$home_dir" "$json_file"
            echo "  ✅ 已移除 $key"
        else
            echo "  保持不变"
        fi
        echo
    done

    _merge_json_sudo_from_system "$json_file" "$username" sync

    echo "✅ $username 重新配置完成"
    read -p "按回车继续..." _
}

# 公钥管理 helpers --------------------------------------------------------

# _keys_load_array <json_file> -> 输出全局 KEYS_ARR
# 兼容 JSON 中 authorized_keys 为 list 或 string；空也安全
_keys_load_array() {
    local json_file="$1"
    KEYS_ARR=()
    [[ -f "$json_file" ]] || return 0
    command -v python3 &>/dev/null || { echo "需要 python3" >&2; return 1; }
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        KEYS_ARR+=("$line")
    done < <(UM_JSON="$json_file" python3 - <<'PY'
import json, os
with open(os.environ["UM_JSON"]) as f:
    d = json.load(f)
v = d.get("authorized_keys", "")
if isinstance(v, list):
    for k in v:
        if isinstance(k, str) and k.strip():
            print(k)
elif isinstance(v, str):
    if v.strip():
        print(v)
PY
)
}

# _keys_save_array <json_file> — 把 KEYS_ARR 写回 JSON 的 authorized_keys（list）
_keys_save_array() {
    local json_file="$1"
    command -v python3 &>/dev/null || { echo "需要 python3" >&2; return 1; }
    local joined=""
    if [[ ${#KEYS_ARR[@]} -gt 0 ]]; then
        joined="$(printf '%s\n' "${KEYS_ARR[@]}")"
    fi
    UM_JSON="$json_file" UM_KEYS_NL="$joined" python3 - <<'PY'
import json, os
keys = [k for k in os.environ.get("UM_KEYS_NL", "").split("\n") if k.strip()]
path = os.environ["UM_JSON"]
with open(path) as f:
    d = json.load(f)
d["authorized_keys"] = keys
with open(path, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
}

# _keys_apply <username> <json_file> — 把 KEYS_ARR 写入 ~/.ssh/authorized_keys 锚点段
_keys_apply() {
    local username="$1" json_file="$2"
    _load_user_data "$json_file"
    local content=""
    if [[ ${#KEYS_ARR[@]} -gt 0 ]]; then
        content="$(printf '%s\n' "${KEYS_ARR[@]}")"
    fi
    UM_AUTHORIZED_KEYS="$content" \
        _um_step_call authorized_keys apply "$username" "$home_dir" "$json_file"
}

# _user_keys_menu <username> <json_file>
_user_keys_menu() {
    local username="$1" json_file="$2"

    while true; do
        _keys_load_array "$json_file"
        echo
        echo "=========================================="
        echo "         公钥管理: $username"
        echo "=========================================="
        if [[ ${#KEYS_ARR[@]} -eq 0 ]]; then
            echo "  （无公钥）"
        else
            local i=1 k
            for k in "${KEYS_ARR[@]}"; do
                printf "  %d) %s\n" "$i" "$k"
                ((i++))
            done
        fi
        echo
        echo "  a) 添加公钥"
        echo "  d) 删除公钥（按编号）"
        echo "  s) 重新写入 ~/.ssh/authorized_keys（同步当前列表）"
        echo "  0) 返回"
        echo

        read -p "选择: " choice
        case "$choice" in
            a|A)
                echo "新公钥（单行）:"
                _ask_required ">" || continue
                KEYS_ARR+=("$ANSWER")
                _keys_save_array "$json_file"
                _keys_apply "$username" "$json_file"
                echo "✅ 已添加并写入"
                ;;
            d|D)
                if [[ ${#KEYS_ARR[@]} -eq 0 ]]; then
                    echo "无可删除"
                    continue
                fi
                read -p "删除哪一项编号: " idx
                if [[ ! "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#KEYS_ARR[@]} )); then
                    echo "无效编号"
                    continue
                fi
                local new_arr=() i=0
                for k in "${KEYS_ARR[@]}"; do
                    ((i++))
                    if (( i != idx )); then
                        new_arr+=("$k")
                    fi
                done
                KEYS_ARR=("${new_arr[@]}")
                _keys_save_array "$json_file"
                _keys_apply "$username" "$json_file"
                echo "✅ 已删除并重写"
                ;;
            s|S)
                _keys_apply "$username" "$json_file"
                echo "✅ 已重新写入"
                ;;
            0) return ;;
            *) echo "无效选择" ;;
        esac
    done
}

# _track_user 用户名 json路径 — 「未管理」用户纳入管理：问答并应用 sudo/docker，再 merge(track)
_track_user() {
    local username="$1"
    local json_file="$2"

    echo
    echo "纳入管理: $username"
    echo

    local sudo_flag docker_flag

    _ask_yn "设置 sudo（/etc/sudoers.d，NOPASSWD）" "false" || return
    sudo_flag="$ANSWER"

    _ask_yn "加入 docker 组" "false" || return
    docker_flag="$ANSWER"

    if [[ "$sudo_flag" == "true" ]]; then
        echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$username" > /dev/null
        sudo chmod 440 "/etc/sudoers.d/$username"
    else
        sudo rm -f "/etc/sudoers.d/$username"
        _um_group_remove_user "$username" sudo
    fi

    if [[ "$docker_flag" == "true" ]]; then
        sudo usermod -aG docker "$username"
    else
        _um_group_remove_user "$username" docker
    fi

    _merge_json_sudo_from_system "$json_file" "$username" track

    echo "✅ $username 已纳入管理"
    read -p "按回车继续..." _
}
