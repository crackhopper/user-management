# 02 · 创建用户（详细问答）

入口：主菜单 `1) 新建用户`，或 `./user-mgmt.sh add`，或 `./bin/create-managed-user.sh`。
实现：`lib/interactive/cmd_add_user.sh::cmd_add` → `lib/ops/create_user.sh::um_create_managed_user`。

---

## 问答顺序

任一步按 **ESC** 取消（返回主菜单）。

| # | 提示 | 默认 | 必填 | 说明 |
|---|------|------|------|------|
| 1 | 用户名 | 无 | 是 | 系统 username；JSON 文件名 |
| 2 | 初始密码 | 无 | 是 | 输入隐藏（`read -srp`） |
| 3 | 用户备注（GECOS） | 空 | 否 | `useradd -c`；可空 |
| 4 | home 目录 | `${UM_HOME_PARENT:-/home}/<user>` | 否 | 回车用默认 |
| 5 | 登录 shell | `/bin/bash` | 否 | `useradd -s` |
| 6 | SSH 端口 | 自动从 `/etc/ssh/sshd_config` 解析；缺省 `22` | 否 | 用于 SSH config 片段与 JSON `login_ips` |
| 7 | 登录 IP | `$HOST_IP` 或本机首个非 127 IPv4 | 否 | 同上 |
| 8 | 是否部署 scripts | `${UM_DEPLOY_SCRIPTS_DEFAULT:-true}` | y/N | 复制 `templates/` 到 `~/scripts` |
| 9 | 是否写 proxy 段 | `${UM_CONFIGURE_PROXY_DEFAULT:-false}` | y/N | `.bashrc` 加 `# BEGIN/END user_management proxy_bashrc` 段 |
| 10 | Sudo 模式 | `n` | 1/2/n | `1=NOPASSWD`、`2=需密码`、`n=不启用`；写 `/etc/sudoers.d/<user>` |
| 11 | 是否加入 docker 组 | `false` | y/N | `usermod -aG docker` |
| 12 | 默认安装 nvm + Node LTS | `true` | Y/n | step `nvm_node` |
| 13 | 默认安装 pipx 运行时 | `true` | Y/n | step `pipx_runtime`（系统级） |
| 14 | 默认安装 npm CLIs | `true` | Y/n | step `npm_dev_clis`：codex / opencode / cursor-cli |
| 15 | 默认安装 pipx mkdocs-material | `true` | Y/n | step `pipx_mkdocs_material`（含 pillow / cairosvg） |
| 16 | 默认安装 uv | `true` | Y/n | step `uv`（pipx 装；清华源） |
| 17 | authorized_keys（公钥） | 无 | 是 | 单行公钥 |
| 18 | 私钥文件名 | 推测：`ssh-rsa*` → `id_rsa`，`ssh-ed25519*` → `id_ed25519`，否则 `id_rsa` | 否 | 写入 JSON、SSH config 片段 |

---

## 实际执行步骤

`cmd_add` 收齐答案后调 `um_create_managed_user`，依次：

1. `sudo mkdir -p $(dirname $home)`
2. `sudo useradd -m -U -d $home -s $shell -c $comment $user`
3. `echo $user:$pass | sudo chpasswd`
4. **走预装 step 注册表**（`lib/install_steps/<key>.sh`）：
   - `sudoers` apply（按 Sudo 模式：`nopasswd`/`password`/不启用）
   - `docker_group` apply（若开）
   - `authorized_keys` apply（始终；走锚点段写法，不覆盖整文件）
   - `scripts_dir` apply（若开）
   - `proxy_bashrc` apply（若开）
   - `UM_STEPS_EXTRA` 中的 step（如 `npm_dev_clis`、`pipx_mkdocs_material`）按用户答 y/N 加入
5. 生成 `UM_SSH_CONFIG_SNIPPET`：
   ```
   Host <user>-<HOST_NAME>
       HostName <ip>
       Port <port>
       User <user>
       IdentityFile ~/.ssh/<key_type>
   ```
6. `_um_json_write_user` 用 python3 写 `managed_users/<user>.json`（字段见 [09](09-json-schema.md)）。

---

## 默认值的来源

`.env` 与环境变量影响默认值；优先级：进程环境 > `.env` > 内置默认。

| 变量 | 影响 |
|------|------|
| `HOST_NAME`/`HOSTNAME` | SSH config 的 `Host <user>-<HOSTNAME>` |
| `HOST_IP` | 跳过 IP 自动探测，直接作默认 |
| `UM_HOME_PARENT` | home 默认目录前缀 |
| `UM_DEPLOY_SCRIPTS_DEFAULT` | 第 8 题默认 |
| `UM_CONFIGURE_PROXY_DEFAULT` | 第 9 题默认 |

详见 [08 — 配置与环境变量](08-config-env.md)。

---

## 想加新问答？

不直接改 `cmd_add`；在 `lib/install_steps/<key>.sh` 加一个新 step 即可——`cmd_add` 当前未自动遍历 step 列表（保持现有问题语序），但「重新配置预装项」与「模块管理」会自动包含。

如果新 step 在创建期就要默认 apply，可在 step 的 `default` 函数返回 `"true"`，并在 `lib/ops/create_user.sh` 中追加 `_um_step_call <key> apply` 一行。

更结构化的做法见 [05 — 添加新预装模块](05-add-module.md) §「让模块也参与创建期」。

---

## 失败回滚

当前实现**没有自动回滚**。如果中途失败：
- 删 `/etc/sudoers.d/<user>`（若已写）
- `sudo userdel -r <user>`
- 删 `managed_users/<user>.json`

或直接：

```bash
./bin/delete-managed-user.sh
```

---

## 小坑

- `useradd -U` 自动建同名 group。某些发行版若该 group 已存在，会失败，先 `sudo groupdel <user>` 或换用户名。
- 若 `/etc/ssh/sshd_config` 没有 `Port` 行，端口默认 `22`。
- 第 12 题输入要去掉前后空格；多行公钥不被支持（仅单行）。
