#!/bin/bash
set -euo pipefail

MANAGED_USERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/managed_users"

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/.env" ]]; then
    set -a
    source "$(dirname "${BASH_SOURCE[0]}")/.env"
    set +a
fi
HOST_NAME="${HOSTNAME:-$(hostname)}"

echo "=========================================="
echo "         用户信息查看"
echo "=========================================="
echo

if [[ ! -d "$MANAGED_USERS_DIR" ]] || [[ -z "$(ls -A "$MANAGED_USERS_DIR" 2>/dev/null)" ]]; then
    echo "暂无管理用户"
    exit 0
fi

echo "可查看的用户:"
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

read -p "选择要查看的用户编号: " choice
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

ssh_host_name="${username}-${HOST_NAME}"
login_ip=$(grep '"login_ips"' "$json_file" | sed 's/.*: *\[\"\([^:]*\):[^"]*\"\].*/\1/')
login_port=$(grep '"login_ips"' "$json_file" | sed 's/.*: *\[\"[^:]*:\([^"]*\)\"\].*/\1/')
authorized_keys=$(grep '"authorized_keys"' "$json_file" | sed 's/.*: *\"\([^\"]*\)\".*/\1/')

key_type=$(grep '"key_type"' "$json_file" | sed 's/.*: *"\([^"]*\)".*/\1/')
key_type_inferred=$(grep '"key_type_inferred"' "$json_file" | sed 's/.*: *\([^,]*\).*/\1/')

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

inferred_mark=""
if [[ "$key_type_inferred" == "true" ]]; then
    inferred_mark=" (推测)"
fi

echo
echo "--- SSH 登录信息 ---"
echo "Host:       $ssh_host_name"
echo "HostName:   $login_ip"
echo "Port:       $login_port"
echo "User:       $username"
echo "Key:        ~/.ssh/$key_type$inferred_mark"
echo
echo "--- SSH Config ---"
cat << EOF
Host $ssh_host_name
    HostName $login_ip
    Port $login_port
    User $username
    # 私钥路径，需与填写的公钥配对
    IdentityFile ~/.ssh/$key_type
EOF
echo
echo "--- authorized_keys ---"
echo "$authorized_keys"
echo
echo "--- 完整 JSON ---"
cat "$json_file"
