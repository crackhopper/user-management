#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$CONFIG_DIR/.env" ]]; then
    set -a
    source "$CONFIG_DIR/.env"
    set +a
fi

clear
echo "====================================================="
echo "          开发环境一键安装脚本 (Ubuntu 用户级)"
echo "          包含：nvm / Node / OpenCode / Cursor / uv"
echo "          openspec / claude-code / everything-claude-code"
echo "          无sudo · 国内网络优化 · 可选代理"
echo "====================================================="
echo

# ==============================================
# 询问是否使用代理
# ==============================================
read -p "是否需要临时启用代理 (http://127.0.0.1:7890)？[y/N] " use_proxy
if [[ "$use_proxy" =~ ^[Yy]$ ]]; then
    echo "✅ 本次安装将临时使用代理"
    export HTTP_PROXY=http://127.0.0.1:7890
    export HTTPS_PROXY=http://127.0.0.1:7890
    export ALL_PROXY=http://127.0.0.1:7890
else
    echo "✅ 不使用代理，直接安装"
fi
echo

# ==============================================
# 1. 安装 nvm
# ==============================================
echo -e "\n==== [1/8] 安装 nvm ===="
unset NVM_DIR
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
    echo "nvm 已存在，跳过安装"
fi

# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ==============================================
# 2. 安装 Node.js LTS
# ==============================================
echo -e "\n==== [2/8] 安装 Node.js LTS ===="
if ! command -v node &> /dev/null; then
    nvm install --lts
    nvm use --lts
    nvm alias default node
else
    echo "node 已存在：$(node -v)"
fi

# ==============================================
# 3. 安装 OpenCode CLI
# ==============================================
echo -e "\n==== [3/8] 安装 OpenCode CLI ===="
if ! command -v opencode &> /dev/null; then
    curl -fsSL https://opencode.ai/install | bash
else
    echo "opencode 已安装"
fi

# ==============================================
# 4. 安装 Cursor CLI
# ==============================================
echo -e "\n==== [4/8] 安装 Cursor CLI ===="
if ! command -v agent &> /dev/null; then
    curl -fsSL https://cursor.com/install | bash
else
    echo "cursor cli (agent) 已安装"
fi

# ==============================================
# 5. pipx 配置 + 安装 uv（清华源）
# ==============================================
echo -e "\n==== [5/8] 配置 pipx 并安装 uv ===="
if command -v pipx &> /dev/null; then
    echo "pipx 已全局安装"
    pipx ensurepath
    export PATH="$HOME/.local/bin:$PATH"

    if ! command -v uv &> /dev/null; then
        pipx install uv --pip-args="--index-url https://pypi.tuna.tsinghua.edu.cn/simple"
    else
        echo "uv 已安装：$(uv --version)"
    fi
else
    echo "⚠️  pipx 未全局安装，跳过 uv 安装"
fi

# ==============================================
# 6. 安装 openspec
# ==============================================
echo -e "\n==== [6/8] 安装 openspec ===="
if ! npm list -g @fission-ai/openspec &> /dev/null; then
    echo "安装 @fission-ai/openspec ..."
    npm install -g @fission-ai/openspec@latest
else
    echo "@fission-ai/openspec 已安装"
fi

# ==============================================
# 7. 安装 claude-code
# ==============================================
echo -e "\n==== [7/8] 安装 claude-code ===="
if ! npm list -g @anthropic-ai/claude-code &> /dev/null; then
    echo "安装 @anthropic-ai/claude-code ..."
    npm install -g @anthropic-ai/claude-code
else
    echo "@anthropic-ai/claude-code 已安装"
fi

# ==============================================
# 8. 安装 everything-claude-code
# ==============================================
echo -e "\n==== [8/8] 安装 everything-claude-code ===="

# 设置 MiniMax API Key（用于 Claude API）
if [[ -n "${MINIMAX_COM_KEY:-}" ]]; then
    export MINIMAX_COM_KEY="$MINIMAX_COM_KEY"
    export OPENAI_API_KEY="$MINIMAX_COM_KEY"
    export OPENAI_BASE_URL="https://api.openai.com/v1"
    echo "✅ 已配置 MiniMax API Key (OPENAI_API_KEY)"
else
    echo "⚠️  MINIMAX_COM_KEY 未设置，跳过 API Key 配置"
fi

CLONE_DIR="/tmp/everything-claude-code"
if [[ ! -d "$HOME/.claude" ]]; then
    echo "克隆 everything-claude-code ..."
    if [[ -d "$CLONE_DIR" ]]; then
        rm -rf "$CLONE_DIR"
    fi
    git clone https://github.com/affaan-m/everything-claude-code.git "$CLONE_DIR"

    echo "安装 everything-claude-code 配置 ..."
    mkdir -p ~/.claude/{agents,rules,commands,skills,hooks}

    if [[ -d "$CLONE_DIR/agents" ]]; then
        cp "$CLONE_DIR/agents/"*.md ~/.claude/agents/ 2>/dev/null || true
    fi
    if [[ -d "$CLONE_DIR/rules" ]]; then
        cp "$CLONE_DIR/rules/"*.md ~/.claude/rules/ 2>/dev/null || true
    fi
    if [[ -d "$CLONE_DIR/commands" ]]; then
        cp "$CLONE_DIR/commands/"*.md ~/.claude/commands/ 2>/dev/null || true
    fi
    if [[ -d "$CLONE_DIR/skills" ]]; then
        cp "$CLONE_DIR/skills/"*.md ~/.claude/skills/ 2>/dev/null || true
    fi
    if [[ -d "$CLONE_DIR/hooks" ]]; then
        cp "$CLONE_DIR/hooks/"*.md ~/.claude/hooks/ 2>/dev/null || true
    fi

    rm -rf "$CLONE_DIR"
    echo "✅ everything-claude-code 已安装"
else
    echo "everything-claude-code 配置已存在 (~/.claude)，跳过"
fi

# ==============================================
# 清理临时代理
# ==============================================
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
echo -e "\n✅ 临时代理已清理"

# ==============================================
# 最终检查
# ==============================================
echo -e "\n==================== 安装结果 ===================="
echo "nvm:        $(nvm --version 2>/dev/null || echo "未安装")"
echo "node:       $(node -v 2>/dev/null || echo "未安装")"
echo "npm:        $(npm -v 2>/dev/null || echo "未安装")"
echo "opencode:   $(opencode --version 2>/dev/null || echo "已安装")"
echo "cursor:     $(agent --version 2>/dev/null || echo "已安装")"
echo "pipx:       $(pipx --version 2>/dev/null || echo "未安装")"
echo "uv:         $(uv --version 2>/dev/null || echo "未安装")"
echo "openspec:   $(npm list -g @fission-ai/openspec 2>/dev/null | grep @fission-ai/openspec || echo "已安装")"
echo "claude-code: $(npm list -g @anthropic-ai/claude-code 2>/dev/null | grep @anthropic-ai/claude-code || echo "已安装")"
echo "everything-cc: $([[ -d ~/.claude ]] && echo "已安装" || echo "未安装")"
echo "===================================================="

echo -e "\n🎉 安装完成！"
echo "请重启终端或执行：source ~/.bashrc"
echo "可用命令：node npm opencode agent uv openspec claude-code"
