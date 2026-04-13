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

> **说明：** 删除、列表、sudo、重新初始化等能力集中在交互菜单或 `bin/` 下的独立脚本中；当前入口脚本 **未** 将 `delete`、`list` 等映射为 `./user-mgmt.sh <command>` 形式（与仅含 `add` 的 CLI 一致即可）。

---

## 模块说明（`user-mgmt.sh`）

入口 **`user-mgmt.sh`** 仅负责加载模块并分发子命令；逻辑位于：

| 路径 | 职责 |
|------|------|
| `lib/config.sh` | 项目路径、`managed_users/`、`templates/`、proxy 段锚点、加载 `.env`、`HOST_NAME` |
| `lib/paths.sh` | `um_project_root_from_bin_path`：`bin/` 下脚本解析仓库根 |
| `lib/json_user_state.sh` | `_merge_json_sudo_from_system`：用 python3 将 JSON 与系统 sudo/docker 状态对齐 |
| `lib/user_json_parse.sh` | `_load_user_data`：从单用户 JSON 解析字段到 shell 变量 |
| `lib/stub_unmanaged_user.sh` | 列出本地 passwd 用户、为无 JSON 者生成 `managed: false` 占位文件 |
| `lib/ops/create_user.sh` | `um_create_managed_user`：非交互创建用户 |
| `lib/ops/delete_user.sh` | `um_delete_managed_user`：非交互删除用户 |
| `lib/interactive/cmd_add_user.sh` | `cmd_add`：交互创建用户 |
| `lib/interactive/menu_user_lists.sh` | `_list_managed_users` / `_list_other_users` |
| `lib/interactive/cmd_user_sync_and_sudo.sh` | `_sync_single_user`、`_enable_sudo`、`_disable_sudo`、`_track_user` |
| `lib/interactive/menu_user_actions.sh` | 单用户菜单：查看、删除、登录、修改 |
| `lib/interactive/menu_main.sh` | `interactive_menu`、`show_help` |

每个文件 ≤300 行，便于阅读与 AI 索引；文件头注释说明依赖与副作用。

---

## 交互菜单概览

| 菜单项 | 作用 |
|--------|------|
| 新建用户 | 创建系统用户、SSH、`scripts`、proxy 段、写入 JSON |
| 已管理用户 | 选择用户后可：查看、删除、进入登录 shell、修改（同步 scripts/proxy、启用/禁用 sudo） |
| 未管理用户 | JSON 中 `managed: false` 的用户，以及 **尚无** `managed_users/<名>.json` 的本地 UID 用户（`UID_MIN` 起、非 nologin/false shell）：查看、**纳入管理 (track)**；进入菜单时若无 JSON 会生成 `managed: false` 的占位记录 |

---

## `bin/` 独立脚本

从仓库根目录执行（脚本内通过 `lib/paths.sh` + `lib/config.sh` 解析项目根）：

| 脚本 | 说明 |
|------|------|
| `bin/create-managed-user.sh` | 创建用户（与菜单逻辑类似） |
| `bin/delete-managed-user.sh` | 删除用户 |
| `bin/modify-managed-user.sh` | 修改私钥文件名等 JSON 字段 |
| `bin/list-managed-users.sh` | 列出 `managed_users/*.json` |
| `bin/show-managed-user.sh` | 查看用户详情与 SSH Config 片段 |
| `bin/enable-user-sudo.sh` | 写入 `/etc/sudoers.d/<用户>`（NOPASSWD；不加入 sudo 组） |
| `bin/disable-user-sudo.sh` | 删除 sudoers drop-in，并将用户从 sudo 组移除 |
| `bin/reinit-user-environment.sh` | 覆盖 `~/scripts` 并刷新 `.bashrc` 中 proxy 段 |
| `bin/sync-user-scripts.sh` | 仅同步 `~/scripts` |

---

## 目录结构

```
user_management/
├── user-mgmt.sh              # 统一入口（source lib/ 与 lib/interactive/）
├── lib/
│   ├── config.sh             # 路径、.env、proxy 锚点
│   ├── paths.sh
│   ├── json_user_state.sh
│   ├── user_json_parse.sh
│   ├── ops/                  # 无交互创建/删除
│   └── interactive/          # 菜单与交互命令
├── bin/                      # 可单独执行的维护脚本（见上表）
├── templates/                # 复制到用户 ~/scripts 的模板
│   ├── README.md
│   ├── proxy.sh
│   ├── setup-dev-env.sh
│   └── unset_proxy.sh
├── managed_users/            # 每用户一个 JSON
│   └── <username>.json
├── tests/
│   ├── run.sh
│   └── integration/
│       └── test_user_lifecycle.sh
├── .env                      # 可选：HOSTNAME 等（见下）
└── README.md
```

---

## 环境变量 `.env`

仓库根目录下的 `.env`（可选）会在 `user-mgmt.sh` 及部分脚本中加载：

| 变量 | 说明 |
|------|------|
| `HOSTNAME` | 用于生成 SSH Config 的 `Host` 名：`<username>-<HOSTNAME>`（覆盖系统 `hostname` 时可显式设置） |
| `UM_HOME_PARENT` | 创建用户时默认 home 父目录（默认 `/home`）；默认 home 会变成 `${UM_HOME_PARENT}/<username>` |

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

## templates 说明

部署到用户 `~/scripts/` 的模板。**详细步骤与可选环境变量见 [`templates/README.md`](templates/README.md)**（与 `setup-dev-env.sh` 中 8 步安装一致）。

| 脚本 | 说明 |
|------|------|
| `proxy.sh` | 设置 `http_proxy` / `https_proxy`（并可通过根 `user-mgmt.sh` 追加到 `.bashrc` 固定段） |
| `setup-dev-env.sh` | 开发环境一键安装（8 步：nvm、Node、OpenCode、Cursor CLI、pipx/uv、openspec、claude-code、everything-claude-code 等） |
| `unset_proxy.sh` | 清除代理相关环境变量 |

---

## SSH Config 使用

从「查看」或 `bin/show-managed-user.sh` 输出中复制片段到本机 `~/.ssh/config`，例如：

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

## 集成测试

创建与删除测试用户的全流程（**需 root 或免密 sudo**，会真实创建系统用户）：

```bash
./tests/run.sh
```

仅 CI 或无权限环境可跳过：

```bash
UM_SKIP_INTEGRATION=1 ./tests/run.sh
```

---

## 权限要求

1. 执行创建/删除用户、改权限等操作的用户需要 **sudo**。
2. 对 `managed_users/` 需要写权限（创建/更新/删除 JSON）。
3. 对 `templates/` 需要读权限（复制到用户 home）。
4. 交互菜单中的 **Sync（同步）** 与 **纳入管理 (track)** 会调用 **python3** 合并/更新 JSON，请确保系统已安装 `python3`。
