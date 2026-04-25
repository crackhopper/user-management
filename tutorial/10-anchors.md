# 10 · 锚点块系统（`# BEGIN/END user_management <name>`）

防止「我装了什么，怎么干净卸载」的工程化答案。

---

## 锚点格式

```
# BEGIN user_management <name>

<内容>

# END user_management <name>
```

实现位于 `lib/anchors.sh`。

---

## API

| 函数 | 作用 |
|------|------|
| `_um_anchor_strip <file> <name> [mark] [chown_user]` | 删除现有 BEGIN..END 段（不存在不报错） |
| `_um_anchor_present <file> <name> [mark]` | 输出 `true`/`false`：段是否存在 |
| `_um_anchor_write <file> <name> <chown_user> [mark]` | 从 stdin 读内容；先 strip 再追加；前后留空行 |

`mark` 默认 `#`；其他注释字符（如 `//`）也支持。
`<chown_user>` 是写完之后 `chown <user>:<user>` 的目标用户（避免文件被 sudo 拥有）。

---

## 工作示例

`templates/proxy.sh` 内容写入 `<home>/.bashrc`：

```bash
cat "$SCRIPTS_SRC/proxy.sh" | _um_anchor_write "$home/.bashrc" "proxy_bashrc" "$user"
```

结果（`<home>/.bashrc` 末尾追加）：

```
...原有内容...

# BEGIN user_management proxy_bashrc

# user_management proxy 段
# 默认值：http://127.0.0.1:7890
# 修改地址请同时改大小写两组变量

export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"

export HTTP_PROXY="http://127.0.0.1:7890"
export HTTPS_PROXY="http://127.0.0.1:7890"

# END user_management proxy_bashrc
```

卸载：

```bash
_um_anchor_strip "$home/.bashrc" "proxy_bashrc" "#" "$user"
```

---

## 设计要点

1. **不破坏用户已有内容**：仅删除 BEGIN..END 段；段外的 `.bashrc` 内容（用户的别名、PATH 等）保留。
2. **写之前先 strip**：保证「重复 apply」=「替换」，幂等。
3. **空行隔离**：BEGIN/END 行与内容、与外部之间各空一行；视觉上易分辨；用户在 BEGIN 之前手写注释也不会被卷进 sed 的 `\|^...\$|` 范围匹配。
4. **变量化锚点字面**：`# BEGIN user_management <name>` 中的 `<name>` 可任意，由 step 自取。`lib/config.sh` 的 `UM_PROXY_BEGIN/END` 是历史旧锚点（含括号），仅供 strip_legacy 兼容用，新代码不再依赖。
5. **chown 一致性**：写完 `chown <user>:<user>`，避免文件属主被 sudo（root）持有导致用户登录无法读 `.bashrc`。

---

## 已采用锚点的位置

| step | 文件 | 锚点 name |
|------|------|-----------|
| `proxy_bashrc` | `<home>/.bashrc` | `proxy_bashrc` |
| `authorized_keys` | `<home>/.ssh/authorized_keys` | `authorized_keys` |
| 旧版 proxy（兼容） | `<home>/.bashrc` | `proxy (templates/proxy.sh)` —— `proxy_bashrc` apply/remove 同时 strip 之 |

---

## 自定义模块用锚点

写文件类的预装项推荐用：

```bash
um_step_my_aliases_apply() {
    local user="$1" home="$2"
    cat <<'EOF' | _um_anchor_write "$home/.bashrc" "my_aliases" "$user"
alias ll='ls -lah'
EOF
}

um_step_my_aliases_status() {
    local home="$2"
    _um_anchor_present "$home/.bashrc" "my_aliases"
}

um_step_my_aliases_remove() {
    local user="$1" home="$2"
    _um_anchor_strip "$home/.bashrc" "my_aliases" "#" "$user"
}
```

`<name>` 推荐与 step key 同名，便于排查。

---

## 调试

肉眼检查某个用户是否含某锚点：

```bash
sudo grep -F "BEGIN user_management" /home/<user>/.bashrc /home/<user>/.ssh/authorized_keys 2>/dev/null
```

或用 step：

```bash
source user-mgmt.sh
_um_anchor_present /home/alice/.bashrc proxy_bashrc
```
