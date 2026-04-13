# Scripts

## setup-dev-env.sh

开发环境一键安装脚本，适用于 Ubuntu 用户级环境。

### 安装内容

- **nvm** - Node.js 版本管理器
- **Node.js LTS** - 最新长期支持版 Node.js
- **OpenCode CLI** - AI 编程助手
- **Cursor CLI** - AI 代码编辑器命令行工具
- **uv** - Python 包管理器（通过 pipx 安装，清华源）

### 使用方式

```bash
# 直接运行（安装过程中会询问是否使用代理）
bash scripts/setup-dev-env.sh

# 一行命令跳过代理选择
echo "n" | bash scripts/setup-dev-env.sh

# 使用代理安装
echo "y" | bash scripts/setup-dev-env.sh
```

安装完成后请重启终端或执行 `source ~/.bashrc`。

---

## proxy.sh

设置系统代理环境变量，代理地址为 `http://127.0.0.1:7890`。

### 使用方式

```bash
# 启用代理
source scripts/proxy.sh

# 验证代理是否生效
echo $http_proxy

# 取消代理
unset http_proxy https_proxy
```

### 典型场景

在网络受限环境下安装软件时：

```bash
source scripts/proxy.sh
bash scripts/setup-dev-env.sh
unset http_proxy https_proxy
```
