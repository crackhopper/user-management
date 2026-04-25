# 03 · 管理已有用户

入口：主菜单 `2) 已管理用户` → 选用户 → 单用户菜单。
实现：`lib/interactive/menu_user_lists.sh::_list_managed_users`、
`lib/interactive/menu_user_actions.sh::_user_action_menu`、
`lib/interactive/cmd_user_sync_and_sudo.sh`。

---

## 单用户菜单

```
1) 查看
2) 删除
3) 进入 (登录)
4) 修改
0) 返回
```

### 1) 查看 — `_user_view`

打印基本信息 + SSH config 片段 + authorized_keys（首条）。
数据来自 `_load_user_data`（`lib/user_json_parse.sh`）。

### 2) 删除 — `_user_delete`

询问「保留 home？」y/N，然后 `um_delete_managed_user`：
- `sudo userdel [-r] <user>`
- `sudo rm -f /etc/sudoers.d/<user>`
- `rm -f managed_users/<user>.json`

注意：本工具不显式 strip 用户 home 中的锚点段（用 `userdel -r` 直接删整个 home；保留 home 时锚点也保留在原文件中）。

### 3) 进入 — `_user_login`

`exec sudo -u <user> -i`。退出 shell 后回到原 shell（不返回菜单，因为 `exec`）。

### 4) 修改 — `_user_modify_menu`

```
1) Sync (同步状态和 scripts)
2) 启用 sudo（sudoers.d / NOPASSWD）
3) 禁用 sudo（移除 sudoers 与 sudo 组）
4) 重新配置预装项（逐项 apply/remove）
0) 返回
```

#### 4.1 — Sync（`_sync_single_user`）

- 重新部署 `~/scripts`（先 `rm -rf` 再 `cp -r`，覆盖任何用户改动）
- 走 `proxy_bashrc` step 重写 proxy 锚点段
- `_merge_json_sudo_from_system <json> <user> sync` 刷新 `sudo_group/sudo_sudoers/docker`，写 `last_synced`

适合「我改了 templates，把所有用户也对齐」。
（更通用一点的批量入口是 `bin/reinit-user-environment.sh --all --yes`。）

#### 4.2 — 启用 sudo（`_enable_sudo`）

- 询问 sudo 模式：`1) NOPASSWD` / `2) 需要密码`
- 调 `sudoers` step apply（按 `UM_SUDO_REQUIRE_PASSWORD` 写不同 rule）
- `_merge_json_sudo_from_system ... refresh` 刷新 JSON 的 `sudo_sudoers` 与 `sudo_mode`

#### 4.3 — 禁用 sudo（`_disable_sudo`）

- `sudo rm -f /etc/sudoers.d/<user>`
- `_um_group_remove_user <user> sudo`（`gpasswd -d` 优先，`deluser` fallback）
- 刷新 JSON

#### 4.4 — 重新配置预装项（`_reconfigure_user`） ★

逐 step 显示当前状态、询问保留/应用/移除：

```
[scripts_dir] 部署 ~/scripts（复制 templates/）
  当前状态: true
  保留此预装项 [Y/n]:

[proxy_bashrc] 在 ~/.bashrc 写入 proxy 段（templates/proxy.sh）
  当前状态: false
  应用此预装项 [y/N]:
...
```

逻辑：
- `status=true && want=true` → 保持
- `status=false && want=true` → `apply`
- `status=true && want=false` → `remove`
- `status=false && want=false` → 保持

特殊处理：`authorized_keys` 在 apply 前会临时把 JSON 中存的 `authorized_keys` 注入到 `UM_AUTHORIZED_KEYS` 环境变量，写入锚点段。

完成后调 `_merge_json_sudo_from_system ... sync`。

---

## 「未管理用户」入口

主菜单 `3) 未管理用户`。两类来源：
1. JSON 中 `managed: false` 的记录
2. 本地 passwd 中 UID ≥ `UID_MIN` 且 shell 非 nologin/false 的用户，且 **尚无** `managed_users/<名>.json`

进入子菜单时若无 JSON，会调 `_um_ensure_stub_unmanaged_json` 生成 `managed: false` 的占位（含从系统读到的 sudo/docker/auth_keys 首条）。

子菜单：

```
1) 查看
2) 纳入管理 (track)
0) 返回
```

`_track_user`：问 sudo/docker → 应用对应 step → `_merge_json_sudo_from_system ... track`，并把 `managed` 改为 `true`。

---

## 「Sync」与「Reinit」的区别

| 命令 | 范围 |
|------|------|
| 菜单 → 修改 → 1) Sync | 单个用户：scripts + proxy + JSON 刷新 |
| `bin/sync-user-scripts.sh` | 单/多/全部用户的 `~/scripts` 同步 + JSON 刷新（不动 proxy） |
| `bin/reinit-user-environment.sh` | 单/多/全部用户的 scripts + proxy + JSON 刷新 |

详见 [06](06-bin-scripts.md)。
