# 08 · 配置与环境变量

`lib/config.sh` 在 `SCRIPT_DIR` 设好之后被 source；可读 `<repo>/.env`（`set -a; source .env; set +a`）。

---

## 项目内固定变量（运行时设置）

| 变量 | 来源 | 含义 |
|------|------|------|
| `SCRIPT_DIR` | 入口或 `um_bootstrap` | 仓库根绝对路径 |
| `MANAGED_USERS_DIR` | `$SCRIPT_DIR/managed_users` | 单用户 JSON 目录 |
| `SCRIPTS_SRC` | `$SCRIPT_DIR/templates` | 部署到用户 `~/scripts` 的源 |
| `UM_PROXY_BEGIN` | `# BEGIN user_management proxy (templates/proxy.sh)` | 旧 proxy 锚点（兼容用） |
| `UM_PROXY_END` | `# END user_management proxy` | 旧 proxy 锚点终止 |
| `ESCAPE_KEY` | `$'\e'` | ESC 字面量 |

新 proxy 锚点（推荐）：`# BEGIN/END user_management proxy_bashrc`，由 `lib/install_steps/proxy_bashrc.sh` 写入；旧锚点仅用于 `strip_legacy`。

---

## 用户可设的环境变量 / `.env`

`<repo>/.env` 例（`.gitignore` 已忽略）：

```bash
# 主机标识：写入 SSH config 的 Host <user>-<HOSTNAME>
HOSTNAME=hushine-4090

# 默认登录 IP（设置后跳过自动检测；置空则探测本机首个非 127 IPv4）
HOST_IP=192.168.1.100

# 默认 home 父目录（默认 /home）
UM_HOME_PARENT=/data/home

# 默认是否部署 ~/scripts（默认 true）
UM_DEPLOY_SCRIPTS_DEFAULT=true

# 默认是否在 .bashrc 写 proxy 段（默认 false）
UM_CONFIGURE_PROXY_DEFAULT=false
```

| 变量 | 默认 | 影响 |
|------|------|------|
| `HOSTNAME` | `$(hostname)` | `HOST_NAME` ← 它；用于 SSH config Host 名 |
| `HOST_IP` | 空 | 自动检测 IP；非空时跳过 |
| `UM_HOME_PARENT` | `/home` | 创建用户默认 home 父目录 |
| `UM_DEPLOY_SCRIPTS_DEFAULT` | `true` | 创建第 8 题默认 |
| `UM_CONFIGURE_PROXY_DEFAULT` | `false` | 创建第 9 题默认 |
| `UM_SKIP_INTEGRATION` | 空 | `tests/run.sh` 看到 `1` 则跳过 |

进程环境优先于 `.env`。

---

## 集成测试可用变量

| 变量 | 默认 | 用途 |
|------|------|------|
| `UM_SKIP_INTEGRATION=1` | — | 跳过测试（CI 用） |

测试本身硬编码：

| 变量 | 例值 |
|------|------|
| `TEST_USER` | `umtest_<RANDOM>_<PID>` |
| `TEST_PASS` | 随机 hex |
| `FAKE_PUB` | 占位 ed25519 公钥 |
| `KEY_TYPE` | `id_ed25519` |
| `SELECTED_IP` | `127.0.0.1` |
| `SSH_PORT` | 从 sshd_config 读，缺省 22 |
| `HOME_DIR` | `${UM_HOME_PARENT:-/home}/$TEST_USER` |
| `DEPLOY_SCRIPTS` | `true` |
| `CONFIGURE_PROXY` | `false` |
| `USER_COMMENT` | `integration-test` |
| `LOGIN_SHELL` | `/bin/bash` |

---

## sshd_config 端口探测

`grep ^Port /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'`

无输出 → 默认 `22`。多行 `Port` 取首条（`head -1`）。

---

## IPv4 探测

```
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1
```

无可用 IP → fallback `127.0.0.1`。

---

## 注意事项

- `HOSTNAME` 与 bash 内置环境变量同名；`.env` 写它依赖 `set -a` 把它导出，再被 `lib/config.sh` 中 `HOST_NAME=${HOSTNAME:-$(hostname)}` 取到。若发现 `.env` 不生效，确认是用 `set -a; source .env; set +a`（`lib/config.sh` 已这么做）。
- 修改 `.env` 后需重新进入主菜单（或重新 `source user-mgmt.sh`）才生效。
