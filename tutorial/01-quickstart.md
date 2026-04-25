# 01 · 快速开始

## 1. 依赖

| 工具 | 必需？ | 用途 |
|------|--------|------|
| bash 4+ | 必需 | 全部脚本宿主 |
| sudo | 必需 | useradd / chpasswd / sudoers.d / chown |
| python3 | 必需 | 写 JSON、合并系统状态 |
| ip / awk / grep / sed | 必需 | 解析 sshd_config、IPv4 |
| gpasswd 或 deluser | 二选一 | 从组中移除用户（跨发行版） |

## 2. 克隆 + 初次创建

```bash
git clone <repo-url> user-management
cd user-management
./user-mgmt.sh             # 进交互菜单
```

主菜单：

```
1) 新建用户
2) 已管理用户
3) 未管理用户
4) 预装模块管理
0) 退出
```

选 `1`，按提示填问题。详见 [02 — 创建用户](02-create-user.md)。

## 3. `.env`（可选）

仓库根新建 `.env`（已在 `.gitignore`）：

```bash
# 自定义主机名（写入 SSH config 的 Host 名后缀）
HOSTNAME=xdy-sg-3080

# 默认登录 IP（设置后跳过自动检测）
HOST_IP=192.168.66.12

# 默认 home 父目录（默认 /home）
UM_HOME_PARENT=/home

# 默认是否部署 ~/scripts（默认 true）
UM_DEPLOY_SCRIPTS_DEFAULT=true

# 默认是否写 .bashrc proxy 段（默认 false）
UM_CONFIGURE_PROXY_DEFAULT=false
```

## 4. 命令行用法

| 形式 | 说明 |
|------|------|
| `./user-mgmt.sh` | 主菜单 |
| `./user-mgmt.sh add` | 直接走交互创建 |
| `./user-mgmt.sh help` | 打印帮助 |
| `./bin/<name>.sh` | 入口脚本（详见 [06](06-bin-scripts.md)） |

## 5. 第一个用户后

打开 `managed_users/<username>.json` 看落库的字段（[09](09-json-schema.md)）；
本机 `~/.ssh/config` 粘贴 `_user_view` 里给的 SSH config 片段，即可 `ssh <username>-<HOSTNAME>` 登录。

## 6. 集成测试（会真创建/删除测试用户）

```bash
./tests/run.sh                    # 需要 root 或免密 sudo
UM_SKIP_INTEGRATION=1 ./tests/run.sh   # 跳过
```

## 下一步

- 想了解每个问题：[02](02-create-user.md)
- 想给已有用户加功能：[03](03-manage-users.md)
- 想添加自己的预装项（npm 包等）：[05](05-add-module.md)
