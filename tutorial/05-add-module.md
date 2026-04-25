# 05 · 添加新预装模块

加一个 `lib/install_steps/<your_key>.sh` 文件即可。无需改其他位置。

---

## 1. 拷贝模板

```bash
cp lib/install_steps/_template.sh.example lib/install_steps/my_npm_globals.sh
```

替换文件中的 `your_step_name` → `my_npm_globals`（必须与文件名一致，去 `.sh`）。

---

## 2. 必须实现的 5 个函数

| 函数 | 入参 | 输出 |
|------|------|------|
| `um_step_<key>_label` | — | echo 中文描述 |
| `um_step_<key>_default` | — | echo `true`/`false`（创建期默认开关） |
| `um_step_<key>_status` | `user home` | echo `true`/`false`（已部署？） |
| `um_step_<key>_apply` | `user home json_file` | 安装 |
| `um_step_<key>_remove` | `user home json_file` | 卸载（幂等） |

文件头部 `UM_STEPS+=(<key>)` 把自身注册进数组。

---

## 3. 范式

### 3.1 用户级 npm 全局包

```bash
UM_STEPS+=(my_npm_globals)

um_step_my_npm_globals_label()   { echo "全局 npm 包：claude-code, openspec"; }
um_step_my_npm_globals_default() { echo "false"; }

um_step_my_npm_globals_status() {
    local user="$1"
    sudo -u "$user" -i bash -lc 'npm list -g --depth=0 2>/dev/null | grep -q "@anthropic-ai/claude-code"' \
        && echo true || echo false
}

um_step_my_npm_globals_apply() {
    local user="$1"
    sudo -u "$user" -i bash -lc 'npm install -g @anthropic-ai/claude-code @fission-ai/openspec'
}

um_step_my_npm_globals_remove() {
    local user="$1"
    sudo -u "$user" -i bash -lc 'npm uninstall -g @anthropic-ai/claude-code @fission-ai/openspec' || true
}
```

### 3.2 用户级 pipx

```bash
UM_STEPS+=(my_pipx_uv)

um_step_my_pipx_uv_label()   { echo "pipx 安装 uv"; }
um_step_my_pipx_uv_default() { echo "false"; }

um_step_my_pipx_uv_status() {
    local user="$1"
    sudo -u "$user" -i bash -lc 'command -v uv' &>/dev/null && echo true || echo false
}

um_step_my_pipx_uv_apply() {
    local user="$1"
    sudo -u "$user" -i bash -lc 'pipx install uv --pip-args="--index-url https://pypi.tuna.tsinghua.edu.cn/simple"'
}

um_step_my_pipx_uv_remove() {
    local user="$1"
    sudo -u "$user" -i bash -lc 'pipx uninstall uv' || true
}
```

### 3.3 系统级 apt 包（影响所有用户）

```bash
UM_STEPS+=(my_apt_devtools)

um_step_my_apt_devtools_label()   { echo "apt: build-essential + git + tmux"; }
um_step_my_apt_devtools_default() { echo "false"; }

um_step_my_apt_devtools_status() {
    dpkg -s build-essential git tmux &>/dev/null && echo true || echo false
}

um_step_my_apt_devtools_apply() {
    sudo apt-get update
    sudo apt-get install -y build-essential git tmux
}

um_step_my_apt_devtools_remove() {
    sudo apt-get remove -y build-essential git tmux || true
}
```

> 注意：apt 包是系统级，单用户「卸载」会影响其他用户。建议 label 标注「系统级」。

### 3.4 写入 `~/.bashrc` 自定义片段（用锚点）

```bash
UM_STEPS+=(my_bash_aliases)

um_step_my_bash_aliases_label()   { echo "bashrc 别名：ll, gst, ..."; }
um_step_my_bash_aliases_default() { echo "false"; }

um_step_my_bash_aliases_status() {
    local home="$2"
    _um_anchor_present "$home/.bashrc" "my_bash_aliases"
}

um_step_my_bash_aliases_apply() {
    local user="$1" home="$2"
    cat <<'EOF' | _um_anchor_write "$home/.bashrc" "my_bash_aliases" "$user"
alias ll='ls -lah'
alias gst='git status'
alias gco='git checkout'
EOF
}

um_step_my_bash_aliases_remove() {
    local user="$1" home="$2"
    _um_anchor_strip "$home/.bashrc" "my_bash_aliases" "#" "$user"
}
```

### 3.5 主目录文件

```bash
UM_STEPS+=(my_gitconfig)

um_step_my_gitconfig_label()   { echo "用户级 .gitconfig（默认 user.email/name）"; }
um_step_my_gitconfig_default() { echo "false"; }

um_step_my_gitconfig_status() {
    local home="$2"
    sudo test -f "$home/.gitconfig" && echo true || echo false
}

um_step_my_gitconfig_apply() {
    local user="$1" home="$2"
    sudo -u "$user" -- git config --global user.email "$user@$(hostname)"
    sudo -u "$user" -- git config --global user.name  "$user"
}

um_step_my_gitconfig_remove() {
    local home="$2"
    sudo rm -f "$home/.gitconfig"
}
```

---

## 4. 验证

新模块加入后：

```bash
# 重新进入主菜单（自动 _um_steps_load）
./user-mgmt.sh

# 4) 预装模块管理 → 列表中应出现新模块
# 选择新模块 → 在某用户上 apply / 探测 / remove
```

或命令行验证函数注册：

```bash
source user-mgmt.sh; declare -F | grep um_step_my_npm_globals
```

---

## 5. 让模块也参与「创建期」

`cmd_add` 出于稳定性没有自动遍历 `UM_STEPS`。若希望新建用户时默认应用某模块：

**法一：直接在 `lib/ops/create_user.sh` 的 step apply 列表里追加：**

```bash
_um_step_call my_npm_globals apply "$username" "$home_dir" "$json_file"
```

**法二：改 `cmd_add` 在 docker 那段后加问答，把答案传进 `um_create_managed_user` 后用 `_um_step_call`。**

如果只在「重新配置预装项」与「模块管理」用，不必动创建路径。

---

## 6. 设计建议

- **幂等**：`apply` 多次安全；`remove` 用户没装也不报错。
- **status 准**：探测条件清晰。建议写文件的模块用锚点（[10](10-anchors.md)）；安装包的模块用 `dpkg -s` / `npm list -g` / `command -v` 等。
- **不破坏用户已有内容**：写文件优先 `_um_anchor_write`，不直接覆盖整文件。
- **跨发行版**：`apt` 范式仅 Debian/Ubuntu；多发行版加 `command -v apt-get` 检测。
- **错误处理**：apply 失败返回非 0；菜单会打印错误但不会回滚已成功的 step。
