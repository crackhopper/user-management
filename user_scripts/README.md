# Scripts

## setup-dev-env.sh

开发环境一键安装脚本，适用于 **Ubuntu 用户级**环境（无需 sudo）。脚本使用 `set -eo pipefail`（未启用 `-u`），依赖网络与 `curl`/`git`/`npm` 等。

### 安装步骤（与脚本一致，共 8 步）

1. **nvm** — Node 版本管理器  
2. **Node.js LTS** — `nvm install --lts`  
3. **OpenCode CLI** — `curl` 安装  
4. **Cursor CLI** — `agent` 命令（`cursor.com/install`）  
5. **pipx + uv** — 若系统已有 `pipx`，则配置路径并以清华源安装 `uv`；若无 `pipx` 则跳过 `uv`  
6. **openspec** — `npm install -g @fission-ai/openspec`  
7. **claude-code** — `npm install -g @anthropic-ai/claude-code`  
8. **everything-claude-code** — 从 GitHub 克隆配置到 `~/.claude/`（若已存在 `~/.claude` 则跳过）

### 可选环境变量

- **`MINIMAX_COM_KEY`**：若已设置，脚本会为本次会话设置 `OPENAI_API_KEY` / `OPENAI_BASE_URL`（用于后续工具链；详见脚本内注释）。

脚本会从**上一级目录**加载仓库根目录的 `.env`（与 `user_management` 根目录 `.env` 一致），可在其中配置上述变量。

### 使用方式

```bash
# 在用户 ~/scripts 目录下（由 user-mgmt 部署后）
bash setup-dev-env.sh

# 一行跳过代理询问
echo "n" | bash setup-dev-env.sh

# 使用代理安装
echo "y" | bash setup-dev-env.sh
```

安装完成后请重启终端或执行 `source ~/.bashrc`。

---

## proxy.sh

设置 `http_proxy` / `https_proxy`，默认 `http://127.0.0.1:7890`。根目录 `user-mgmt.sh` 可将本文件内容追加到用户 `~/.bashrc` 的固定段。

```bash
source scripts/proxy.sh
echo $http_proxy
```

---

## unset_proxy.sh

清除代理相关环境变量（与 `proxy.sh` 配对使用）。

```bash
source scripts/unset_proxy.sh
```

### 典型场景

```bash
source scripts/proxy.sh
bash scripts/setup-dev-env.sh
source scripts/unset_proxy.sh
```
