# 06 · `bin/` 脚本逐个

九个独立入口。每个都先 `source lib/bootstrap.sh` 再 `um_bootstrap` 加载所需 lib，逻辑函数在 `lib/`。

---

## bin/create-managed-user.sh

简单转发到 `cmd_add`（即菜单的「新建用户」）。

```bash
./bin/create-managed-user.sh
```

实质：

```
source lib/bootstrap.sh
um_bootstrap "${BASH_SOURCE[0]}" json_io anchors proxy_block group_ops install_steps ops/create_user interactive/prompts interactive/cmd_add_user
_um_steps_load
mkdir -p "$MANAGED_USERS_DIR"
cmd_add
```

---

## bin/delete-managed-user.sh

交互选择 → 确认 → 是否保留 home → `um_delete_managed_user`。

```bash
./bin/delete-managed-user.sh
```

不支持命令行非交互模式。

---

## bin/list-managed-users.sh

打印 `managed_users/*.json` 表格：

```
用户名       home目录                sudo组   sudoers    docker    创建时间
----------------------------------------------------------------------------------
alice        /home/alice            false    true       false     2026-04-25T10:00:00+08:00
```

字段直接 grep+sed 解析 JSON（不依赖 python3）。

---

## bin/show-managed-user.sh

交互选择 → 打印基本信息 + SSH config 片段 + authorized_keys + 完整 JSON。

---

## bin/modify-managed-user.sh

仅修改 `key_type` 与 `key_type_inferred=false`。其他字段建议从菜单走。

---

## bin/enable-user-sudo.sh / disable-user-sudo.sh

| 脚本 | 系统操作 | JSON |
|------|----------|------|
| `enable-user-sudo.sh` | 写 `/etc/sudoers.d/<user>`（`<user> ALL=(ALL) NOPASSWD: ALL`，0440） | `_merge_json_sudo_from_system ... refresh` |
| `disable-user-sudo.sh` | 删 sudoers + `_um_group_remove_user <user> sudo` | 同上 |

---

## bin/sync-user-scripts.sh

`~/scripts` 同步（覆盖式 `cp -r`）+ JSON 刷新。

```bash
./bin/sync-user-scripts.sh                  # 交互选择多个用户
./bin/sync-user-scripts.sh --all --yes      # 全部用户，非交互
./bin/sync-user-scripts.sh -h               # 帮助
```

---

## bin/reinit-user-environment.sh

`~/scripts` 同步 + `~/.bashrc` proxy 段刷新 + JSON 刷新。

```bash
./bin/reinit-user-environment.sh
./bin/reinit-user-environment.sh --all --yes
```

`reinit_one` 内部用 `_um_proxy_block_write`（薄壳调 `proxy_bashrc` step apply）。

---

## 共同模式

所有 bin 脚本都用 bootstrap：

```bash
#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/lib/bootstrap.sh"
um_bootstrap "${BASH_SOURCE[0]}" <module1> <module2> ...
```

`um_bootstrap` 始终 source `lib/paths.sh` + `lib/config.sh` 并设置 `SCRIPT_DIR`。
后续位置参数对应 `lib/<arg>.sh`，按顺序 source。

---

## 加自己的 bin 脚本

```bash
#!/bin/bash
# bin/my-tool.sh
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/lib/bootstrap.sh"
um_bootstrap "${BASH_SOURCE[0]}" json_user_state install_steps user_json_parse
_um_steps_load   # 若用 step

# 你的逻辑
echo "已管理用户:"
for f in "$MANAGED_USERS_DIR"/*.json; do
    [[ -e "$f" ]] || continue
    _load_user_data "$f"
    echo "  $username -> $home_dir (sudo=$sudo_sudoers, docker=$has_docker)"
done
```
