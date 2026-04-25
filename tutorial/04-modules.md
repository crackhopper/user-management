# 04 · 预装模块管理

入口：主菜单 `4) 预装模块管理` → `_modules_menu`。
实现：`lib/interactive/menu_modules.sh`、`lib/install_steps.sh`、`lib/install_steps/<key>.sh`。

---

## 顶层

```
==========================================
         预装模块管理
==========================================

  1) authorized_keys      — 写入 ~/.ssh/authorized_keys（锚点段） [默认: true]
  2) docker_group         — 加入 docker 组 [默认: false]
  3) proxy_bashrc         — 在 ~/.bashrc 写入 proxy 段（templates/proxy.sh） [默认: false]
  4) scripts_dir          — 部署 ~/scripts（复制 templates/） [默认: true]
  5) sudoers              — /etc/sudoers.d/<user>（NOPASSWD: ALL） [默认: false]

  a) 如何添加新模块
  0) 返回
```

数字数据由 `UM_STEPS` 数组（每个 step 文件头部 `UM_STEPS+=(<key>)`）。
`label` / `default` 由各 step 的 `um_step_<key>_label` / `um_step_<key>_default` 函数。

按 `a` 打印添加新模块的步骤 → 跳 [05](05-add-module.md)。

按 `1..N` 进入模块动作菜单。

---

## 模块动作菜单

```
==========================================
         模块: <key>
         <label>
==========================================

  1) 探测某用户是否已安装
  2) 在某用户上安装 (apply)
  3) 在某用户上卸载 (remove)
  4) 全用户状态总览

  0) 返回
```

### 1) 探测 — `status`

调 `um_step_<key>_status user home`，输出 `true|false`。

### 2) 安装 — `apply`

调 `um_step_<key>_apply user home json_file`。
特殊：`authorized_keys` 走 apply 前注入 `UM_AUTHORIZED_KEYS=$authorized_keys`（来自 JSON）。
执行后调 `_merge_json_sudo_from_system ... refresh` 刷新 JSON。

### 3) 卸载 — `remove`

调 `um_step_<key>_remove user home json_file`。
所有 step 的 `remove` 必须幂等：用户没装也不报错。
执行后同样刷新 JSON。

### 4) 全用户状态总览 — `_module_overview`

遍历 `managed_users/*.json`，对每个用户调 `status`。例：

```
用户                状态
----------------------------------------
alice               true
bob                 false
charlie             (系统用户不存在)
```

---

## 已内置 10 个模块

| key | 文件 | 探测条件 |
|-----|------|----------|
| `nvm_node` | `lib/install_steps/0_nvm_node.sh` | 用户登录 shell 中 `command -v node && command -v npm`；apply 拉 nvm 安装脚本 + `nvm install --lts` |
| `pipx_runtime` | `lib/install_steps/0_pipx_runtime.sh` | 系统 `command -v pipx`；apply 走 apt/dnf/apk/pacman |
| `scripts_dir` | `lib/install_steps/scripts_dir.sh` | `<home>/scripts` 是目录 |
| `proxy_bashrc` | `lib/install_steps/proxy_bashrc.sh` | `<home>/.bashrc` 含 `# BEGIN user_management proxy_bashrc` |
| `authorized_keys` | `lib/install_steps/authorized_keys.sh` | `<home>/.ssh/authorized_keys` 含锚点 |
| `sudoers` | `lib/install_steps/sudoers.sh` | `/etc/sudoers.d/<user>` 存在；`um_step_sudoers_mode` 还能输出 nopasswd/password/none |
| `docker_group` | `lib/install_steps/docker_group.sh` | `id -nG <user>` 含 `docker` |
| `npm_dev_clis` | `lib/install_steps/npm_dev_clis.sh` | 用户 npm 全局列表含 `NPM_DEV_PACKAGES` 全部条目（默认：codex / opencode-ai / cursor-cli）；apply 缺 npm 时自动调 nvm 安装作 fallback |
| `pipx_mkdocs_material` | `lib/install_steps/pipx_mkdocs_material.sh` | 用户 `pipx list --short` 含 `mkdocs-material`；apply 时同时 `pipx inject` pillow + cairosvg；缺 pipx 时按系统包管理器装 |
| `uv` | `lib/install_steps/uv.sh` | 用户 `command -v uv`；apply 走 `pipx install uv`；依赖 `pipx_runtime` |

**依赖关系**：`npm_dev_clis` ← `nvm_node`；`pipx_mkdocs_material`、`uv` ← `pipx_runtime`。Apply 缺依赖时会自动调用对应依赖 step，再装包。

详见各文件源码。

---

## 想新增？

主菜单 → `4) 预装模块管理` → `a` 看提示，或直接读 [05 — 添加新预装模块](05-add-module.md)。

模块文件加到 `lib/install_steps/` 后**重启菜单或重新 `source user-mgmt.sh`** 即被自动加载。
