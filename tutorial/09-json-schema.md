# 09 · JSON 数据结构

`managed_users/<username>.json` —— 每用户一个文件。

---

## 完整字段表

```json
{
  "username": "alice",
  "home": "/home/alice",
  "sudo_group": false,
  "sudo_sudoers": true,
  "sudo_mode": "nopasswd",
  "docker": false,
  "login_ips": ["192.168.1.100:22"],
  "key_type": "id_ed25519",
  "key_type_inferred": false,
  "authorized_keys": "ssh-ed25519 AAAAC3... alice@laptop",
  "comment": "Alice Example",
  "shell": "/bin/bash",
  "created_at": "2026-04-25T10:00:00+08:00",
  "managed": true,
  "last_synced": "2026-04-25T12:00:00+08:00"
}
```

| 字段 | 类型 | 写入者 | 含义 |
|------|------|--------|------|
| `username` | string | 创建 | 系统 username |
| `home` | string | 创建 | home 绝对路径 |
| `sudo_group` | bool | merge | 是否在系统 sudo 组（`id -nG` 含 `sudo`） |
| `sudo_sudoers` | bool | merge | `/etc/sudoers.d/<user>` 是否存在 |
| `sudo_mode` | string | merge | `nopasswd`/`password`/`none`/`unknown`（按 sudoers 文件内容判断） |
| `docker` | bool | merge | `id -nG` 含 `docker` |
| `login_ips` | string[] | 创建 | `IP:Port`（仅取首条用于 SSH config 片段；多元素仅展示） |
| `key_type` | string | 创建 / `bin/modify` | 私钥文件名（`id_rsa` / `id_ed25519` / 自定义） |
| `key_type_inferred` | bool | 创建 / `bin/modify` | 私钥名是否为推测 |
| `authorized_keys` | string | 创建 | 单行公钥；用于回写锚点段 |
| `comment` | string | 创建（新增） | useradd `-c` GECOS |
| `shell` | string | 创建（新增） | useradd `-s` 登录 shell |
| `created_at` | string | 创建 | ISO 8601（`date -Iseconds`） |
| `managed` | bool | 创建 / track | `false` = 仅占位，`true` = 已纳管 |
| `last_synced` | string | merge `mode=sync` | ISO 8601；最近同步时间 |

---

## 三种写入模式（`_merge_json_sudo_from_system <json> <user> <mode>`）

| mode | 触发场景 | 行为 |
|------|----------|------|
| `refresh` | 启用/禁用 sudo / 模块菜单 apply&remove 后 | 仅刷新 `sudo_group`/`sudo_sudoers`/`docker` |
| `sync` | 菜单 → 修改 → Sync / `sync-user-scripts.sh` / `reinit-user-environment.sh` / `_reconfigure_user` | 同 refresh + 写 `last_synced`（若无 `managed` 则补 true） |
| `track` | 「未管理」用户纳入管理 | 同 refresh + 强制 `managed=true` |

---

## 旧字段迁移

旧版本只有 `sudo`（bool）。`json_user_state.sh` 中 python 段：

```python
if 'sudo' in d and 'sudo_group' not in d:
    v = d['sudo']
    if isinstance(v, bool):
        d['sudo_group'] = v
    else:
        d['sudo_group'] = str(v).strip() == 'true'
    d['sudo_sudoers'] = False
    del d['sudo']
```

任何一次 sync/refresh/track 都会自动把旧 `sudo` 拆成 `sudo_group=旧值` + `sudo_sudoers=false`。

`comment` / `shell` 字段在第二次结构化时新增；旧 JSON 不会自动补。下次 sync 不会主动写它们（因为 `_merge_json_sudo_from_system` 只动 sudo/docker/managed/last_synced）。可手工补。

---

## 读 JSON 的两条路径

| 路径 | 实现 | 用于 |
|------|------|------|
| python3 | `lib/json_user_state.sh`（merge） | 与系统状态对齐时；安全转义 |
| grep+sed | `lib/user_json_parse.sh::_load_user_data`、`bin/list/show/modify` | 快速读取单个字段；不依赖 python3 |

`grep+sed` 路径假定 JSON 单行字段格式（`_um_json_write_user` 用 `indent=2` 写出，单字段独占一行）。**不**保证支持多行字符串、嵌套对象。

---

## SSH Config 片段（运行时生成，不存盘）

```
Host <username>-<HOST_NAME>
    HostName <login_ip>
    Port <login_port>
    User <username>
    IdentityFile ~/.ssh/<key_type>
```

`HOST_NAME` 来自 `lib/config.sh`（环境 / `.env` / `hostname`）。
