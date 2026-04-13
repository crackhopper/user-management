# 用户管理工具

统一管理 Linux 用户的一站式工具集：创建账号、SSH 公钥、`~/scripts` 模板、代理段写入 `.bashrc`，并在 `managed_users/` 中保存元数据。

## 快速开始

```bash
# 交互式主菜单（推荐）
./user-mgmt.sh

# 命令行：仅支持部分子命令（见下表）
./user-mgmt.sh add
./user-mgmt.sh help
```

无参数时进入交互菜单，包含：**新建用户**、**已管理用户**、**未管理用户** 三类入口。

### 命令行子命令

| 参数 | 说明 |
|------|------|
| *(无)* | 进入交互式主菜单 |
| `add` | 与菜单中「新建用户」相同，创建用户 |
| `help` / `--help` / `-h` | 打印帮助 |

> **说明：** 删除、列表、sudo、重新初始化等能力集中在交互菜单或 `manager_scripts/` 下的独立脚本中；当前入口脚本 **未** 将 `delete`、`list` 等映射为 `./user-mgmt.sh <command>` 形式（与仅含 `add` 的 CLI 一致即可）。

---

## 交互菜单概览

| 菜单项 | 作用 |
|--------|------|
| 新建用户 | 创建系统用户、SSH、`scripts`、proxy 段、写入 JSON |
| 已管理用户 | 选择用户后可：查看、删除、进入登录 shell、修改（同步 scripts/proxy、启用/禁用 sudo） |
| 未管理用户 | JSON 中 `managed: false` 的用户：查看、**纳入管理 (track)** |

---

## `manager_scripts/` 独立脚本

目录内为可单独执行的脚本（需在仓库根目录关注路径，见 [CODE_REVIEW.md](./CODE_REVIEW.md) 中的路径说明）：

| 脚本 | 说明 |
|------|------|
| `add-user.sh` | 创建用户（与菜单逻辑类似） |
| `delete-user.sh` | 删除用户 |
| `modify-user.sh` | 修改私钥文件名等 JSON 字段 |
| `list-user.sh` | 列出 `managed_users/*.json` |
| `show-user.sh` | 查看用户详情与 SSH Config 片段 |
| `enable-sudo.sh` | 写入 `/etc/sudoers.d/<用户>`（NOPASSWD；不加入 sudo 组） |
| `disable-sudo.sh` | 删除 sudoers drop-in，并将用户从 sudo 组移除 |
| `reinit-user.sh` | 覆盖 `~/scripts` 并刷新 `.bashrc` 中 proxy 段 |
| `update-user-scripts.sh` | 仅同步 `~/scripts` |

---

## 目录结构

```
user_management/
├── user-mgmt.sh              # 统一入口（交互 + CLI add/help）
├── manager_scripts/          # 独立功能脚本
├── user_scripts/             # 复制到用户 ~/scripts 的模板
│   ├── README.md
│   ├── proxy.sh
│   ├── setup-dev-env.sh
│   └── unset_proxy.sh
├── managed_users/            # 每用户一个 JSON
│   └── <username>.json
├── .env                      # 可选：HOSTNAME 等（见下）
└── README.md
```

---

## 环境变量 `.env`

仓库根目录下的 `.env`（可选）会在 `user-mgmt.sh` 及部分脚本中加载：

| 变量 | 说明 |
|------|------|
| `HOSTNAME` | 用于生成 SSH Config 的 `Host` 名：`<username>-<HOSTNAME>`（覆盖系统 `hostname` 时可显式设置） |

---

## 用户信息 JSON 格式

典型字段如下（实际文件可能含额外字段，如 `managed`、`last_synced`）：

```json
{
  "username": "testuser",
  "home": "/home/testuser",
  "sudo_group": false,
  "sudo_sudoers": true,
  "docker": false,
  "login_ips": ["192.168.1.100:22"],
  "key_type": "id_ed25519",
  "key_type_inferred": false,
  "authorized_keys": "ssh-ed25519 AAAA... comment",
  "created_at": "2026-04-12T10:00:00+08:00",
  "managed": true,
  "last_synced": "2026-04-13T12:00:00+08:00"
}
```

| 字段 | 说明 |
|------|------|
| `sudo_group` | 用户是否在系统 **sudo 组**（`id -nG` 含 `sudo`） |
| `sudo_sudoers` | 是否存在本工具管理的 **`/etc/sudoers.d/<用户名>`**（NOPASSWD 规则） |
| `login_ips` | 字符串数组，元素形如 `IP:端口`，用于生成 SSH 提示 |
| `managed` | 可选；为 `false` 时出现在「未管理用户」列表，纳入管理后改为 `true` |
| `last_synced` | 可选；在菜单中执行「Sync」同步后可能写入 |

**sudo 两种来源：** `sudo_group` 表示传统「加入 sudo 组」；`sudo_sudoers` 表示独立 drop-in 文件。本工具在**新建用户**与**启用 sudo** 时**只使用 sudoers 文件**（不自动加入 sudo 组）；**禁用 sudo** 会同时移除该文件并尝试将用户从 sudo 组移除。**Sync** 会从系统刷新两项记录。旧版仅含字段 `sudo` 的 JSON 会在同步或合并时迁移为上述两项（原 `sudo` 视为 `sudo_group`）。

---

## user_scripts 说明

部署到用户 `~/scripts/` 的模板。**详细步骤与可选环境变量见 [`user_scripts/README.md`](user_scripts/README.md)**（与 `setup-dev-env.sh` 中 8 步安装一致）。

| 脚本 | 说明 |
|------|------|
| `proxy.sh` | 设置 `http_proxy` / `https_proxy`（并可通过根 `user-mgmt.sh` 追加到 `.bashrc` 固定段） |
| `setup-dev-env.sh` | 开发环境一键安装（8 步：nvm、Node、OpenCode、Cursor CLI、pipx/uv、openspec、claude-code、everything-claude-code 等） |
| `unset_proxy.sh` | 清除代理相关环境变量 |

---

## SSH Config 使用

从「查看」或 `show-user.sh` 输出中复制片段到本机 `~/.ssh/config`，例如：

```ssh-config
Host testuser-hushine-4090
    HostName 192.168.1.100
    Port 22
    User testuser
    IdentityFile ~/.ssh/id_ed25519
```

连接：

```bash
ssh testuser-hushine-4090
```

---

## 权限要求

1. 执行创建/删除用户、改权限等操作的用户需要 **sudo**。
2. 对 `managed_users/` 需要写权限（创建/更新/删除 JSON）。
3. 对 `user_scripts/` 需要读权限（复制到用户 home）。
4. 交互菜单中的 **Sync（同步）** 与 **纳入管理 (track)** 会调用 **python3** 合并/更新 JSON，请确保系统已安装 `python3`。

---

## 相关文档

- [CODE_REVIEW.md](./CODE_REVIEW.md)：代码审查摘要、已知问题与改进建议
