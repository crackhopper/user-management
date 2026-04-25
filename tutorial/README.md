# user-management 教程

按需翻阅。每篇可独立读。

## 入门
- [01 — 快速开始](01-quickstart.md)：装、跑、第一次创建用户
- [02 — 创建用户（详细问答）](02-create-user.md)：交互每一步含义、`.env` 变量影响、ESC 取消
- [03 — 管理已有用户](03-manage-users.md)：查看/删除/登录/Sync/启用禁用 sudo/重新配置预装项
- [04 — 预装模块管理](04-modules.md)：模块菜单的 4 种动作（探测/安装/卸载/总览）
- [05 — 添加新预装模块](05-add-module.md)：模板拷贝、5 函数 API、npm/pipx/apt/bashrc 范式

## 参考
- [06 — bin/ 脚本逐个](06-bin-scripts.md)：每个入口命令行用法
- [07 — 架构与数据流](07-architecture.md)：lib/ 模块图、调用链、加载顺序
- [08 — 配置与环境变量](08-config-env.md)：`.env`、`UM_*`、`HOST_NAME`、`HOST_IP` 等
- [09 — JSON 数据结构](09-json-schema.md)：`managed_users/<user>.json` 字段、迁移、`last_synced`
- [10 — 锚点块系统](10-anchors.md)：`# BEGIN/END user_management <name>` 工作原理与设计
- [11 — 常见场景与排错](11-faq.md)：跨发行版、缺 python3、proxy 端口不通、sudo 失败等

---

## 一句话定位

| 我想…… | 看哪 |
|--------|------|
| 第一次跑通 | 01 |
| 知道创建用户每个问题啥意思 | 02 |
| 给已有用户加 docker 权限 | 03（重新配置预装项）或 04（模块菜单） |
| 自己加一个 npm 全局包预装 | 05 |
| 看脚本到底做了啥 | 07 |
| 哪个变量改默认行为 | 08 |
| 出错了 | 11 |
