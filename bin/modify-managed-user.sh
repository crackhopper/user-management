#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/lib/bootstrap.sh"
um_bootstrap "${BASH_SOURCE[0]}"

echo "=========================================="
echo "         修改用户"
echo "=========================================="
echo

if [[ ! -d "$MANAGED_USERS_DIR" ]] || [[ -z "$(ls -A "$MANAGED_USERS_DIR" 2>/dev/null)" ]]; then
    echo "暂无管理用户"
    exit 0
fi

echo "可修改的用户:"
echo
i=1
users=()
for json_file in "$MANAGED_USERS_DIR"/*.json; do
    [[ -e "$json_file" ]] || continue
    username=$(basename "$json_file" .json)
    printf "  %d) %s\n" "$i" "$username"
    users+=("$username")
    ((i++))
done
echo

read -p "选择要修改的用户编号: " choice
if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#users[@]}" ]]; then
    echo "无效选择"
    exit 1
fi

username="${users[$((choice-1))]}"
json_file="$MANAGED_USERS_DIR/${username}.json"

echo
echo "=========================================="
echo "         用户: $username"
echo "=========================================="

key_type=$(grep '"key_type"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
key_type_inferred=$(grep '"key_type_inferred"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/')
authorized_keys=$(grep '"authorized_keys"' "$json_file" | sed 's/.*: *\"\([^\"]*\)\".*/\1/')

if [[ -z "$key_type" ]]; then
    if [[ "$authorized_keys" == ssh-rsa* ]]; then
        key_type="id_rsa"
    elif [[ "$authorized_keys" == ssh-ed25519* ]]; then
        key_type="id_ed25519"
    else
        key_type="id_rsa"
    fi
    key_type_inferred="true"
fi

echo
echo "当前私钥文件名: $key_type"
echo "是否由公钥推测: $key_type_inferred"
echo
read -p "新的私钥文件名 [留空保持不变]: " new_key_type

if [[ -n "$new_key_type" ]]; then
    key_type="$new_key_type"
    key_type_inferred="false"
    
    sed -i "s/\"key_type\": \"[^\"]*\"/\"key_type\": \"$key_type\"/" "$json_file"
    sed -i "s/\"key_type_inferred\": [^,]*/\"key_type_inferred\": false/" "$json_file"
    
    echo "已更新私钥文件名为: $key_type"
    echo "已标记为用户指定（非推测）"
else
    echo "保持不变"
fi
