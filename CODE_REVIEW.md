# 代码审查：用户管理项目

本文档基于对仓库内 Shell 脚本与数据文件的阅读整理，列出**问题**与**修改建议**，便于后续迭代。

---

## 审查更新说明（第二轮 · 2026-04-13）

本版在上一版文档基础上**重新通读**当前仓库，并对**相对上一版的变更**做了对照。结论如下。

### 仍存在的问题（代码未改或仍部分成立）

- 第 1–9 节描述的问题**多数仍然存在**（`manager_scripts` 路径、`return "back"`、`login_ips` 与 Sync 丢字段、`delete-user.sh` 的 `$home_dir`、grep 解析 JSON、`_track_user` 的 `sed` 等）。
- 根目录 `README.md` 已与 `user-mgmt.sh` 的 CLI 行为对齐（见原第 10 节），**该文档问题已缓解**。

### 新增发现（本次审查）

| 严重度 | 摘要 |
|--------|------|
| **阻塞级** | `sudoers` 内容写死为字面量 `username`，导致 NOPASSWD **不会**授予当前操作用户（见第 11 节）。 |
| 中 | `user_scripts/setup-dev-env.sh` 已扩展为 8 步安装，但同目录 `user_scripts/README.md` **未同步**，易误导使用者（第 12 节）。 |
| 低 | `setup-dev-env.sh` 使用 `set -eo pipefail`（未开 `-u`）、依赖网络与 `pipx`/全局工具，行为与运维预期需知悉（第 12 节）。 |

---

## 1. 严重：`manager_scripts/` 内路径解析错误

**现象：** 下列脚本将 `PROJECT_DIR` / 当前目录设为「脚本所在目录」：

- `add-user.sh`、`reinit-user.sh`：`PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` → 实际为 `.../manager_scripts`
- 其余脚本将 `MANAGED_USERS_DIR` 设为 `.../manager_scripts/managed_users`

而真实的 `user_scripts/` 与 `managed_users/` 位于**仓库根目录**，与 `manager_scripts/` 同级。

**后果：** `SCRIPTS_SRC`、`MANAGED_USERS_DIR` 指向不存在的子目录；单独运行 `add-user.sh` 等会失败或写到错误位置。

**状态（第二轮）：** 仍存在。

**建议：**

- 统一增加根目录变量，例如：

  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  MANAGED_USERS_DIR="$PROJECT_ROOT/managed_users"
  SCRIPTS_SRC="$PROJECT_ROOT/user_scripts"
  ```

- 或在文档中明确「必须通过 `user-mgmt.sh` 使用」，并修复脚本后再推荐独立运行。

---

## 2. 严重：`user-mgmt.sh` 中 `return "back"` 非法

**位置：** `_user_delete` 末尾：`return "back"`。

**说明：** Bash 的 `return` 只接受 `0–255` 的退出码；传入非数字会报错。在 `set -e` 下可能导致**脚本异常退出**，交互菜单中断。

**状态（第二轮）：** 仍存在。

**建议：** 改为 `return 0`，或使用标志变量 / `break` 控制上层循环，不要用字符串作为 `return` 参数。

---

## 3. 功能缺陷：`_load_user_data` 未解析 `login_ips`

**现象：** `_user_view` 中 SSH 片段使用 `HostName ${login_ips:-127.0.0.1}`，但 `_load_user_data` **从未赋值** `login_ips`，结果往往固定为 `127.0.0.1`，与 JSON 中 `login_ips` 不一致；同时片段中**缺少 `Port` 行**（与 `show-user.sh` 不一致）。

**状态（第二轮）：** 仍存在。

**建议：** 在 `_load_user_data` 中从 JSON 解析 `login_ips`（至少第一个元素的 host 与 port），与 `show-user.sh` 对齐；`_user_view` 中补全 `Port` 行。

---

## 4. 功能缺陷：`_sync_single_user` 重写 JSON 时丢失字段

**现象：** 同步后写入的 JSON **未包含** `login_ips`，若曾存在会被覆盖丢失；也可能丢失 `managed` 等扩展字段。

**状态（第二轮）：** 仍存在。

**建议：** 同步时**合并**更新：只更新 `sudo`/`docker`/`last_synced` 等需要刷新的字段，或先用 `jq` 读旧文件再写回；至少保留 `login_ips` 与 `managed`。

---

## 5. `delete-user.sh` 中未定义变量

**位置：** 提示「是否保留 home」时使用 `[$home_dir]`，但此前未从 JSON 读取 `home_dir`（仅在删除分支里读取）。

**状态（第二轮）：** 仍存在。

**建议：** 在提示前从 `json_file` 解析 `home`，或改为不显示路径、仅文字确认。

---

## 6. `enable-sudo.sh` / `disable-sudo.sh` 与系统组不一致

**现象：**

- `enable-sudo.sh` 仅创建 `/etc/sudoers.d/<user>`，**未** `usermod -aG sudo`。
- `disable-sudo.sh` 仅删除 sudoers 文件，**未**将用户从 `sudo` 组移除。

而 `user-mgmt.sh` 中 `_enable_sudo` / `_disable_sudo` 会同时改组与 sudoers（行为更完整）。

**状态（第二轮）：** 仍存在（且与第 11 节 sudoers **内容错误**叠加时，独立脚本路径问题更严重）。

**建议：** 独立脚本与主脚本行为对齐：启用时 `usermod -aG sudo` + sudoers；禁用时 `gpasswd`/`deluser` 去组 + 删文件；或文档中明确差异并提示仅用其中一种路径。

---

## 7. `_track_user` 使用固定 `sed` 替换不可靠

**现象：**

```bash
sed -i 's/"managed": false/"managed": true/' "$json_file"
sed -i "s/\"sudo\": false/\"sudo\": $sudo_flag/" "$json_file"
sed -i "s/\"docker\": false/\"docker\": $docker_flag/" "$json_file"
```

若当前 JSON 中 `sudo`/`docker` 已为 `true`，替换无效；新建用户 JSON 甚至没有 `managed` 字段，与「未管理」逻辑依赖的字段可能不一致。

**状态（第二轮）：** 仍存在。

**建议：** 用 `jq` 修改字段，或统一规范「每条记录必含 `managed`」并在创建时写入。

---

## 8. 解析 JSON 的方式脆弱

**现象：** 广泛使用 `grep` + `sed` 取 JSON 字段。当 `authorized_keys` 或其它字段含引号、换行或特殊字符时，容易解析错误。

**状态（第二轮）：** 仍存在。

**建议：** 依赖 `jq`（若环境可接受）或专用解析；至少对写入 JSON 的字符串做转义（`jq -n` 生成）。

---

## 9. 安全与运维注意点（非缺陷，建议知晓）

- 交互式密码以明文传入 `chpasswd`，终端历史/录屏可能泄露；生产环境可考虑强制首次登录改密或 `chpasswd` 从受限管道读入。
- `sudoers` 使用 `NOPASSWD: ALL` 权限很大，需配合文件权限与审计策略。
- `managed_users/*.json` 含公钥与主机信息，注意仓库权限与是否纳入版本控制。
- 仓库已存在 **`.git`**：提交前请确认 `.env`、公钥等敏感信息未被跟踪（建议使用 `.gitignore`）。

---

## 10. 文档与实现（README）

根目录 `README.md` 已说明：入口 `./user-mgmt.sh` 的 CLI 主要为 `add` / `help`，交互菜单职责与 `manager_scripts/` 的关系也已写明，**与当前实现一致**。

**残留：** `manager_scripts` 路径问题仍依赖读者阅读本文档第 1 节，若仅看根 README 可能仍误以为「在任意目录执行子脚本即可」。

---

## 11. 严重：`sudoers` drop-in 内容写死为字面量 `username`

**位置：**

- `user-mgmt.sh` → `_enable_sudo`：`echo "username ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$username"`
- `manager_scripts/enable-sudo.sh`：同上。

**说明：** 文件名是 `/etc/sudoers.d/<实际用户名>`，但**文件正文**为 `username ALL=(ALL) NOPASSWD: ALL`（字面量登录名 `username`），不是 `$username`。因此除账号名**恰好**为 `username` 的用户外，**不会**从该文件获得 NOPASSWD sudo；与「已启用某用户的 sudo」的预期不符。

**建议：** 改为：

```bash
echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$username" > /dev/null
```

并复查 `visudo -c` / `sudoers` 语法。此为**应优先修复**的缺陷。

**状态（第二轮）：** 新发现，仍存在。

---

## 12. `user_scripts/README.md` 与 `setup-dev-env.sh` 实现脱节（新增变更）

**现象：** `setup-dev-env.sh` 已包含约 **8 步**（nvm、Node、OpenCode、Cursor CLI、pipx/uv、openspec、claude-code、everything-claude-code 及可选 `MINIMAX_COM_KEY`），而 `user_scripts/README.md` 仍只描述较早的 5 类组件，**未**提及 openspec、claude-code、everything-claude-code 及环境变量。

**其它注意：**

- 脚本使用 `set -eo pipefail`（未启用 `-u`），与仓库内其它脚本的 `set -euo pipefail` 风格不一致。
- `uv` 依赖系统已安装 `pipx`；未安装时仅打印跳过。
- 克隆 `everything-claude-code` 需要网络与 `git`，失败时行为依赖错误处理。
- 根目录 `README.md` 对开发环境脚本的描述仍偏概括，若需与实现一致，可同步更新或指向 `user_scripts/README.md`。

**建议：** 更新 `user_scripts/README.md`（及必要时根 `README.md`）与当前脚本一致；或在脚本头部用注释维护「安装清单」单一事实来源。

**状态（第二轮）：** 新增变更相关审查结论。

---

## 小结（优先级）

| 优先级 | 项 |
|--------|-----|
| **最高** | 第 11 节：sudoers 正文使用 `$username`，勿写死字面量 `username` |
| 高 | 第 1 节：`manager_scripts` 的 `PROJECT_ROOT`；第 2 节：`return "back"`；第 3–4 节：`login_ips` 与 Sync 合并 JSON |
| 中 | 第 5 节：`delete-user.sh` 提示变量；第 6 节：sudo 脚本与组一致；第 7 节：`_track_user` |
| 低 | 第 8 节：引入 `jq`；第 9 节：运维与安全；第 12 节：文档与 `setup-dev-env.sh` 同步 |

如需，可在后续补丁中按上表逐项落地修改。
