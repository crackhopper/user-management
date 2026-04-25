# 11 · 常见场景与排错

---

## Q1：跨发行版能跑吗？

| 发行版 | 状况 |
|--------|------|
| Ubuntu / Debian | 全功能（`useradd`、`gpasswd` 或 `deluser` 都有） |
| RHEL / CentOS / Rocky / Alma | 可用；`group_ops` 走 `gpasswd -d`（util-linux 自带） |
| Alpine | `useradd` 来自 `shadow` 包，需先 `apk add shadow sudo`；其他基本 OK |
| Arch | `gpasswd` 自带；OK |

不支持 Windows、macOS。

## Q2：缺 python3

```
错误: 需要 python3 写入 JSON。
```

装：

```bash
sudo apt-get install -y python3      # Debian/Ubuntu
sudo dnf install -y python3          # RHEL 系
sudo apk add python3                 # Alpine
```

`bin/list-managed-users.sh`、`bin/show-managed-user.sh` 不依赖 python3（用 grep+sed）；其他动作几乎都依赖。

## Q3：proxy 段写了，但代理端口不通，shell 启动慢

`templates/proxy.sh` 默认 `http://127.0.0.1:7890`。如果机器上没起代理：

- 移除：菜单 → 修改 → 4) 重新配置 → `proxy_bashrc` 选「不保留」
- 或：模块管理 → `proxy_bashrc` → 在该用户上 `remove`
- 或改默认地址：编辑 `templates/proxy.sh`，再 `bin/reinit-user-environment.sh --all --yes`

## Q4：`useradd: group <user> already exists`

`useradd -U` 自动建同名 group；若上次创建失败留下了 group 残骸，先：

```bash
sudo groupdel <user>
```

或选另一个用户名。

## Q5：sudo 启用了，但 `sudo` 仍要密码

确认：

```bash
sudo cat /etc/sudoers.d/<user>
# 应是：<user> ALL=(ALL) NOPASSWD: ALL
sudo ls -l /etc/sudoers.d/<user>
# 权限须 0440
```

若文件权限不对，sudo 会忽略它。重启菜单 →「禁用 sudo」→「启用 sudo」即可重写。

## Q6：authorized_keys 被覆盖了？

新版用锚点段写入，**不会**覆盖你段外的公钥。检查：

```bash
sudo cat /home/<user>/.ssh/authorized_keys
```

应能看到：

```
<其它公钥>

# BEGIN user_management authorized_keys

ssh-ed25519 ... 我们的公钥

# END user_management authorized_keys

<其它公钥>
```

若是从老版本迁移过来的用户，文件里只有我们的公钥（无锚点），下次 reconfigure / 模块菜单 apply 会改写为锚点格式，并把原内容当成「外部内容」保留——但因为最初就是 cat 进去的，已经无法区分；首次迁移会把原 authorized_keys **包进** 锚点段。手工备份再 apply 更稳妥。

## Q7：菜单输入数字没反应 / ESC 不生效

- 主菜单输入数字后回车
- 子菜单中 ESC 后通常立即回到上级；某些菜单需输入「ESC 字符」（按 ESC 键）
- 终端如把 ESC 当 `Alt-` 前缀，可能干扰；尝试快速按两次 ESC

## Q8：`HOSTNAME` 环境变量与 bash 内置冲突

`.env` 里 `HOSTNAME=<x>` 通过 `set -a; source .env; set +a` 导出可用；`lib/config.sh` 用 `HOST_NAME=${HOSTNAME:-$(hostname)}` 取值。若仍不生效：

```bash
HOSTNAME=foo ./user-mgmt.sh add        # 显式覆盖
```

## Q9：批量同步多台机器

每台机器独立部署本仓库；`managed_users/` 是本地状态（`.gitignore` 忽略），不要 git 同步它。
跨机器只同步 `templates/`、`lib/install_steps/<your_keys>.sh`。

## Q10：模块菜单看不到我新加的 step

确认：

1. 文件名 = step key + `.sh`，如 `lib/install_steps/my_npm.sh` → key `my_npm`
2. 文件第一行非注释逻辑里有 `UM_STEPS+=(my_npm)`
3. 已退出菜单并重新 `./user-mgmt.sh`（或 `source user-mgmt.sh`）
4. `bash -n lib/install_steps/my_npm.sh` 无语法错
5. `_um_steps_load` 已被调用（`user-mgmt.sh` 入口已经做；写 bin 脚本时记得手动调）

排查：

```bash
source user-mgmt.sh
echo "${UM_STEPS[@]}"
declare -F | grep '^um_step_my_npm_'
```

## Q11：`_load_user_data` 读不到字段（多行 JSON）

`_load_user_data` 用 grep+sed，假定每个字段在 JSON 中独占一行。`_um_json_write_user` 用 `indent=2` 已满足。若手工编辑 JSON 把某字段写成多行格式，会读不到。改回单行格式或 `bin/sync-user-scripts.sh` 触发一次 merge 即可。

## Q12：删除用户后想重建同名

```bash
./bin/delete-managed-user.sh   # 选择 → 是否保留 home
./user-mgmt.sh add             # 创建同名
```

若保留了 home 且 useradd 报「user already exists」，先 `sudo userdel <user>`。

## Q13：跑集成测试需要什么权限？

root 或免密 sudo：

```bash
sudo -n true && echo OK || echo "需要免密 sudo"
```

跳过：

```bash
UM_SKIP_INTEGRATION=1 ./tests/run.sh
```

---

## 还有问题？

- 看 [07 — 架构](07-architecture.md) 找数据流
- `bash -x ./bin/<script>` 看每一步执行
- `set -x` 加在某 lib 函数里，再次触发即可
