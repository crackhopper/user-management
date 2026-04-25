# AGENTS.md — 本仓库踩过的坑（必读）

> 文件位置：仓库根。Claude Code / Codex 等 agent 启动时自动加载。
> 修改本仓库前，先扫一眼下面 lessons。

---

## 跨用户 shell 跑命令（核心坑，反复栽）

### 1. `sudo -u $user -i bash -lc "<多行>"` 把 `\n` 吃掉
sudo `-i` 把后续多个 args 用空格 join 后传给目标 login shell，多行 heredoc 里所有换行被空格替换 → `if/then/fi` 全挤一行 → 语法错。

### 2. `bash -lc` 不读 `.bashrc`
login shell 只读 `.bash_profile`/`.profile`/`.bash_login`。nvm 安装脚本把 loader 写在 `.bashrc` 里 → `bash -lc 'command -v npm'` 找不到 npm。

### 3. `BASH_ENV` / 用户启动文件副作用
非交互 bash 仍会 source `BASH_ENV` 指向的文件；用户 `.bashrc` 可能含 `set -u` + 未守卫变量（如 Claude Code 的 shell snapshot 含未守卫 `$ZSH_VERSION`）→ 致命退出。

### 一锤子方案（已落到 `lib/install_steps.sh::_um_user_sh`）
```bash
_um_user_sh() {
    local user="$1" cmd="$2"
    local preamble='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"'
    printf '%s\n%s\n' "$preamble" "$cmd" \
        | sudo -u "$user" -H env -u BASH_ENV bash --noprofile --norc
}
```

要点：
- `bash --noprofile --norc`：跳过用户启动文件
- `env -u BASH_ENV`：清非交互 bash 的 env-file 入口
- `-H` 而非 `-i`：仅设 HOME，不重排参数
- `printf | bash` 走 stdin：多行 cmd 不被 sudo 吞换行
- preamble 显式注入 nvm + `~/.local/bin` 到 PATH，跨发行版生效

新加 step 一律走 `_um_user_sh`，别另起炉灶。

---

## 4. `set -u` + 漏传位置参数 = 致命退出

helper 内 `local name="$2"` 在 `$2` 未传时触发 `unbound variable` fatal。子 shell 触发后绕过 `||` 兜底（`set -u` 走 `_exit()`），父 shell 的 `set -e` 让外层函数提前 return，菜单回到上级，**无报错回显**（stderr 被 `2>/dev/null` 吞）。

**Lesson**：
- 任何可选位置参数：`local x="${2:-}"` + 必填检查 `[[ -n "$x" ]] || { echo ...; return 1; }`
- 永远不要赤裸 `local x="$N"`（N≥2）
- `2>/dev/null || fallback` 救不了 `set -u` 致命退出

---

## 5. 静态 `bash -n` ≠ 运行时 OK

只跑 `bash -n` 静态语法 + `status` 子命令（单行）就交付，没跑过 `apply`（多行 heredoc + sudo），用户先发现一层层 bug。

**Lesson**：
- 改「跨进程命令传递」的代码（`sudo`/`ssh`/`su`/heredoc）必须真跑一次最小等价 invocation
- 改菜单流程跑：`printf '4\n0\n0\n' | ./user-mgmt.sh` 验证导航
- 改 step apply：用 root 或 self 自做用户跑一次 apply（幂等）
- 多行 cmd 通过 sudo：用 `printf 'cmd1\ncmd2\n' | sudo ... bash` 模式验证

---

## 6. JSON 由 heredoc 拼字符串生成 = 注入

公钥含 `"` 或 `\` 时 JSON 直接坏。

**Lesson**：JSON 写入走 python3（`lib/json_io.sh::_um_json_write_user`，env 传值给 inline python，json.dump 自动转义）；不要 heredoc 拼。

---

## 7. JSON 字段读 grep+sed 易脆

多行格式、IPv6、最后字段无逗号都会挂。

**Lesson**：
- 读 JSON 优先 python3
- grep+sed 仅限 `_load_user_data` / `bin/list/show/modify` 等不依赖 python3 的快路径，且依赖 `_um_json_write_user` 输出的 `indent=2` 单字段独行格式

---

## 8. `||` 接在不会失败的语句后

`select ... done 2>/dev/null || fallback`：`select` 不会因输入失败返回非零，`||` 永远不触发。

**Lesson**：`||` 只对真会非零退出的命令有意义；显式预判用 `if`。

---

## 9. 密码 / 秘钥用 `read -p` 明文回显

**Lesson**：`password`/`token`/`key`/`secret` 字段必走 `read -srp "prompt: " var; echo`。`_ask_required_secret` 已封装。

---

## 10. 改系统状态后忘刷 JSON

任何改 `/etc/sudoers.d`、`/etc/group`、用户 home 文件的入口，最后必须：
```bash
_merge_json_sudo_from_system "$json_file" "$username" refresh
```

---

## 11. 注释紧贴变量赋值

注释与赋值之间空一行；锚点 BEGIN/END 与内容之间空一行。`_um_anchor_write` 已自动加空行；新代码用它即可。

---

## 12. `useradd` 不显式带 `-U -c -s`

```bash
useradd -m -U -d <home> -s <shell> -c <comment> <user>
```
默认值因发行版差异跑出意外；显式带全。

---

## 13. `deluser` 仅 Debian 系

系统组操作走 `lib/group_ops.sh::_um_group_remove_user`（gpasswd 优先，deluser fallback）。包管理用 `command -v apt-get|dnf|apk|pacman` 分支。

---

## 14. 自定义 env 变量与 shell 内置同名

`HOSTNAME` 与 bash 内置同名，要靠 `set -a; source .env; set +a` 才能可靠覆盖。

**Lesson**：自定义环境变量加 `UM_` 前缀，永不和系统/shell 内置撞名。已有的 `HOSTNAME` 是历史债。

---

## 15. 函数签名变了，调用点没全改

**Lesson**：函数签名变更后立刻：
```bash
grep -rln '<fn_name>' --include='*.sh'
```
列所有调用点，逐个更新；用 task list 跟踪。

---

## 16. 新建 lib/ 文件忘了 source

每加一个 `lib/<name>.sh`，立即检查：
- `user-mgmt.sh` 顶层 source 列表
- `bin/<entry>.sh` 的 `um_bootstrap` 模块列表（按需）
- `tests/integration/test_user_lifecycle.sh` 的 source 列表（按需）

---

## 17. fact-forcing hook 必走流程

仓库装了 fact-forcing PreToolUse hook。每次 `Edit` / `Write` 前主动列：
1. 调用方文件:行（`grep -rln`）
2. glob 确认无重名（`find -iname`）
3. 数据字段结构（合成示例）
4. 用户原话 verbatim

**Lesson**：一次到位免被 hook 反复打回。

---

## 18. 改交互菜单后没冒烟

```bash
printf '4\n0\n0\n' | ./user-mgmt.sh 2>&1 | head -40
```
确认菜单项正确、可返回。

---

## 19. JSON 跨字段类型不一致

`key_type_inferred` 上游可能传 `True`/`yes`/`1`。

**Lesson**：写 JSON 字段入口处归一：`asbool(v) → True/False`。`_um_json_write_user` 已封装。

---

## 20. 跨发行版默认 home 父目录

`/home` 不一定是默认（如 `/data/home`）。`UM_HOME_PARENT` 优先，默认 `/home`，去掉尾部 `/`。

---

## 21. `set -e` + 命令替换的赋值

`var=$(failing_cmd)` 在 modern bash 通常不触发 `set -e` 退出（赋值豁免）；但 `set -u` 在 cmd-subst 子 shell 内触发的 fatal 会让父 shell 也跟着退出（即使有 `||`）。

**Lesson**：`set -u` 的 unbound variable 是 fatal；用 `${var:-}` 永远兜底，不要依赖 `||` 救场。

---

## 22. 创建用户每项独立询问，遍历 step 注册表

新加的 step 在 `cmd_add` 加 `_ask_yn`；答案 push 到 `extra_steps` 数组；最后通过 `UM_STEPS_EXTRA` env 传 `um_create_managed_user`。每个 step 创建期都能独立选择，不强加。

---

## 23. 测试 harness 环境污染 ≠ 用户问题

Claude Code Bash 工具下的 shell 含 `BASH_ENV` 指向 snapshot，子 shell 会 source 它。用户实际跑 `./user-mgmt.sh` 在 clean env，不会受影响。验证时用：
```bash
env -u BASH_ENV bash -c '...'
```
模拟 clean env 跑测试。

---

## 加载验证

```bash
ls $(git rev-parse --show-toplevel)/AGENTS.md
```

Claude Code 启动会把仓库根 `AGENTS.md` 读入会话上下文。无需额外配置。
