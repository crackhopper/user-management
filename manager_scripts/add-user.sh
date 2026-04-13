#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_SRC="$PROJECT_DIR/user_scripts"
MANAGED_USERS_DIR="$PROJECT_DIR/managed_users"

if [[ -f "$PROJECT_DIR/.env" ]]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi
HOST_NAME="${HOSTNAME:-$(hostname)}"

available_ips=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.')
ssh_port=$(grep ^Port /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")

echo "=========================================="
echo "         用户创建脚本"
echo "=========================================="
echo

read -p "用户名: " username
while [[ -z "$username" ]]; do
    echo "用户名不能为空"
    read -p "用户名: " username
done

read -p "初始密码: " password
while [[ -z "$password" ]]; do
    echo "密码不能为空"
    read -p "初始密码: " password
done

default_home="/home/$username"
read -p "home目录 [$default_home]: " home_dir
home_dir="${home_dir:-$default_home}"

read -p "是否有sudo权限 [y/N]: " has_sudo
has_sudo_flag=false
if [[ "$has_sudo" =~ ^[Yy]$ ]]; then
    has_sudo_flag=true
fi

read -p "是否有docker权限 [y/N]: " has_docker
has_docker_flag=false
if [[ "$has_docker" =~ ^[Yy]$ ]]; then
    has_docker_flag=true
fi

echo "authorized_keys (单行公钥，输入完按回车):"
read -p "> " authorized_keys

if [[ "$authorized_keys" == ssh-rsa* ]]; then
    default_key_type="id_rsa"
elif [[ "$authorized_keys" == ssh-ed25519* ]]; then
    default_key_type="id_ed25519"
else
    default_key_type="id_rsa"
fi
echo "私钥文件名 [默认 $default_key_type (推测)]:"
read -p "> " key_type
key_type="${key_type:-$default_key_type}"
key_type_inferred=$([[ "$key_type" == "$default_key_type" ]] && echo "true" || echo "false")

echo "选择登录IP:"
select ip in $available_ips; do
    if [[ -n "$ip" ]]; then
        selected_ip="$ip"
        break
    fi
done

if id "$username" &>/dev/null; then
    echo "用户 $username 已存在，退出"
    exit 1
fi

echo
echo "=========================================="
echo "         开始创建用户..."
echo "=========================================="

sudo useradd -m -d "$home_dir" -s /bin/bash "$username"
echo "$username:$password" | sudo chpasswd

if [[ "$has_sudo_flag" == "true" ]]; then
    sudo usermod -aG sudo "$username"
fi

if [[ "$has_docker_flag" == "true" ]]; then
    sudo usermod -aG docker "$username"
fi

sudo mkdir -p "$home_dir/.ssh"
echo "$authorized_keys" | sudo tee "$home_dir/.ssh/authorized_keys" > /dev/null
sudo chmod 600 "$home_dir/.ssh/authorized_keys"
sudo chown -R "$username:$username" "$home_dir/.ssh"

sudo cp -r "$SCRIPTS_SRC" "$home_dir/scripts"
sudo chown -R "$username:$username" "$home_dir/scripts"

if [[ -f "$SCRIPTS_SRC/proxy.sh" ]]; then
    {
        echo ""
        echo "# BEGIN user_management proxy (user_scripts/proxy.sh)"
        cat "$SCRIPTS_SRC/proxy.sh"
        echo "# END user_management proxy"
    } | sudo tee -a "$home_dir/.bashrc" > /dev/null
fi

ssh_host_name="${username}-${HOST_NAME}"
login_entry="Host $ssh_host_name
    HostName $selected_ip
    Port $ssh_port
    User $username
    # 私钥路径，需与填写的公钥配对
    IdentityFile ~/.ssh/$key_type
"

echo
echo "=========================================="
echo "         创建完成"
echo "=========================================="
echo
echo "--- SSH Config (复制到本地 ~/.ssh/config) ---"
echo "$login_entry"
echo "------------------------------------------"
echo

json_file="$MANAGED_USERS_DIR/${username}.json"
cat > "$json_file" << EOF
{
  "username": "$username",
  "home": "$home_dir",
  "sudo": $has_sudo_flag,
  "docker": $has_docker_flag,
  "login_ips": ["${selected_ip}:${ssh_port}"],
  "key_type": "$key_type",
  "key_type_inferred": $key_type_inferred,
  "authorized_keys": "$authorized_keys",
  "created_at": "$(date -Iseconds)"
}
EOF

echo "用户信息已保存: $json_file"
