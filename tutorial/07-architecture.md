# 07 · 架构与数据流

---

## 文件树

```
user-management/
├── user-mgmt.sh                    # 顶层入口
├── lib/
│   ├── bootstrap.sh                # bin/ 入口加载样板
│   ├── paths.sh                    # 路径推断
│   ├── config.sh                   # 全局变量、加载 .env
│   ├── anchors.sh                  # # BEGIN/END 块读写
│   ├── json_io.sh                  # python3 写 JSON
│   ├── json_user_state.sh          # python3 与系统 sudo/docker 合并
│   ├── user_json_parse.sh          # grep/sed 读 JSON 字段
│   ├── stub_unmanaged_user.sh      # 未管理用户占位 JSON
│   ├── proxy_block.sh              # proxy 段薄壳（→ proxy_bashrc step）
│   ├── group_ops.sh                # gpasswd/deluser 跨发行版
│   ├── install_steps.sh            # 步骤注册表 / _um_step_call
│   ├── install_steps/
│   │   ├── _template.sh.example    # 模板
│   │   ├── scripts_dir.sh
│   │   ├── proxy_bashrc.sh
│   │   ├── authorized_keys.sh
│   │   ├── sudoers.sh
│   │   └── docker_group.sh
│   ├── ops/
│   │   ├── create_user.sh          # um_create_managed_user
│   │   └── delete_user.sh          # um_delete_managed_user
│   └── interactive/
│       ├── prompts.sh              # _ask_required/_ask_default/_ask_yn
│       ├── cmd_add_user.sh         # cmd_add
│       ├── cmd_user_sync_and_sudo.sh   # _sync/_enable/_disable/_track/_reconfigure
│       ├── menu_user_lists.sh      # _list_managed_users / _list_other_users
│       ├── menu_user_actions.sh    # _user_action_menu / _user_modify_menu
│       ├── menu_modules.sh         # _modules_menu / _module_actions_menu / overview
│       └── menu_main.sh            # interactive_menu / show_help
├── bin/                            # 9 个入口（详见 06）
├── templates/                      # 部署到用户 ~/scripts
│   ├── proxy.sh
│   ├── unset_proxy.sh
│   ├── setup-dev-env.sh
│   └── README.md
├── managed_users/                  # 每用户一个 JSON（gitignore）
├── tests/
│   ├── run.sh
│   └── integration/test_user_lifecycle.sh
└── tutorial/                       # 本教程
```

---

## 加载顺序（user-mgmt.sh）

```
config
  └─ json_io
       └─ json_user_state
             └─ user_json_parse
                   └─ stub_unmanaged_user
                         └─ anchors
                               └─ proxy_block
                                     └─ group_ops
                                           └─ install_steps  + _um_steps_load → install_steps/*.sh
                                                 └─ ops/create_user, ops/delete_user
                                                       └─ interactive/prompts
                                                             └─ interactive/cmd_add_user
                                                                   └─ interactive/menu_user_lists
                                                                         └─ interactive/cmd_user_sync_and_sudo
                                                                               └─ interactive/menu_user_actions
                                                                                     └─ interactive/menu_modules
                                                                                           └─ interactive/menu_main
```

`bin/` 入口通过 `um_bootstrap` 按需 source 子集（不必加载 menu_*）。

---

## 主流程

### 创建用户

```
cmd_add (cmd_add_user.sh)
  ↓ 收 13 个交互答案
um_create_managed_user (ops/create_user.sh)
  ↓
useradd / chpasswd
  ↓
_um_step_call sudoers       apply (若开)
_um_step_call docker_group  apply (若开)
_um_step_call authorized_keys apply (始终, 用 UM_AUTHORIZED_KEYS env)
_um_step_call scripts_dir   apply (若开)
_um_step_call proxy_bashrc  apply (若开)
  ↓
_um_json_write_user → managed_users/<user>.json
```

### 重新配置预装项

```
_user_modify_menu → 4) → _reconfigure_user (cmd_user_sync_and_sudo.sh)
  ↓ for each key in UM_STEPS:
um_step_<key>_status   user home   → 当前
_ask_yn 保留 / 应用?
  ↓ 差异 → apply 或 remove
_merge_json_sudo_from_system ... sync
```

### 模块管理

```
_modules_menu (menu_modules.sh)
  → _module_actions_menu <key>
        → 1) status ：_um_step_call <key> status
        → 2) apply  ：_um_step_call <key> apply  + _merge_json refresh
        → 3) remove ：_um_step_call <key> remove + _merge_json refresh
        → 4) overview：遍历用户 + status
```

---

## 数据写入点

| 落点 | 写入者 | 触发 |
|------|--------|------|
| `/etc/sudoers.d/<user>` | sudoers step apply / `bin/enable-user-sudo` | 启用 sudo |
| `/etc/group` | docker_group / sudoers step / group_ops | apply / remove |
| `<home>/.ssh/authorized_keys` | authorized_keys step（锚点段） | 创建 / reconfigure / 模块菜单 |
| `<home>/scripts/` | scripts_dir step | 创建 / sync / reinit / reconfigure |
| `<home>/.bashrc` | proxy_bashrc step（锚点段） | 创建 / sync / reinit / reconfigure |
| `managed_users/<user>.json` | `_um_json_write_user`（创建）+ `_merge_json_sudo_from_system`（同步） | 创建 / sync / sudo 启停 |

---

## 全局可变变量约定

| 变量 | 谁设 | 谁读 |
|------|------|------|
| `SCRIPT_DIR` | 入口或 `um_bootstrap` | 各 lib |
| `MANAGED_USERS_DIR` | `lib/config.sh` | 全局 |
| `SCRIPTS_SRC` | `lib/config.sh` | scripts_dir / proxy_bashrc step |
| `UM_PROXY_BEGIN`/`END` | `lib/config.sh`（旧锚点） | `proxy_bashrc` step strip_legacy |
| `UM_STEPS` | 各 step 文件 push | `_modules_menu` / `_reconfigure_user` |
| `UM_AUTHORIZED_KEYS` | apply 调用方临时 export | `authorized_keys` step apply |
| `UM_CREATED_JSON_FILE` / `UM_SSH_CONFIG_SNIPPET` | `um_create_managed_user` 输出 | 调用方打印 |
| `ANSWER` | `_ask_*` 函数 | 调用方读 |
| `username/home_dir/...` | `_load_user_data` 全局赋值 | 各菜单/同步函数 |

`username` / `home_dir` 等是历史全局变量，不带 `local`。改成 local 会破坏现有调用链——保持现状即可，但小心同名变量在嵌套调用中互相覆盖（实际未发现冲突）。
