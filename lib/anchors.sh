# lib/anchors.sh — 通用 BEGIN/END 注释锚点块读写
# -----------------------------------------------------------------------------
# 锚点格式（mark 默认 "#"，可改成 "//" 等）：
#   <mark> BEGIN user_management <name>
#   ...内容...
#   <mark> END user_management <name>
# 所有写操作走 sudo（目标可能是 /home/<other>/.bashrc）
# -----------------------------------------------------------------------------

_um_anchor_begin() { local name="$1" mark="${2:-#}"; printf '%s BEGIN user_management %s' "$mark" "$name"; }
_um_anchor_end()   { local name="$1" mark="${2:-#}"; printf '%s END user_management %s' "$mark" "$name"; }

# _um_anchor_strip <file> <name> [mark] [chown_user]
_um_anchor_strip() {
    local file="$1"
    local name="${2:-}"
    local mark="${3:-#}"
    local owner="${4:-}"
    [[ -n "$name" ]] || { echo "_um_anchor_strip: name 必填" >&2; return 1; }

    sudo test -f "$file" || return 0

    local b e
    b="$(_um_anchor_begin "$name" "$mark")"
    e="$(_um_anchor_end "$name" "$mark")"

    sudo sed -i "\|^${b}\$|,\|^${e}\$|d" "$file"
    [[ -n "$owner" ]] && sudo chown "$owner:$owner" "$file"
    return 0
}

# _um_anchor_present <file> <name> [mark] -> echo true|false
_um_anchor_present() {
    local file="$1"
    local name="${2:-}"
    local mark="${3:-#}"
    [[ -n "$name" ]] || { echo false; return 0; }

    if ! sudo test -f "$file"; then
        echo false
        return 0
    fi
    local b
    b="$(_um_anchor_begin "$name" "$mark")"
    if sudo grep -qF -- "$b" "$file"; then
        echo true
    else
        echo false
    fi
}

# _um_anchor_write <file> <name> <chown_user> [mark]
# 从 stdin 读内容；先 strip 再追加；前后空行；文件不存在则创建并 chown
_um_anchor_write() {
    local file="$1"
    local name="${2:-}"
    local owner="${3:-}"
    local mark="${4:-#}"
    [[ -n "$name" ]] || { echo "_um_anchor_write: name 必填" >&2; return 1; }
    [[ -n "$owner" ]] || { echo "_um_anchor_write: owner 必填" >&2; return 1; }

    if ! sudo test -f "$file"; then
        sudo touch "$file"
        sudo chown "$owner:$owner" "$file"
    fi

    _um_anchor_strip "$file" "$name" "$mark" "$owner"

    local b e
    b="$(_um_anchor_begin "$name" "$mark")"
    e="$(_um_anchor_end "$name" "$mark")"

    {
        echo ""
        echo "$b"
        echo ""
        cat
        echo ""
        echo "$e"
    } | sudo tee -a "$file" > /dev/null

    sudo chown "$owner:$owner" "$file"
}
