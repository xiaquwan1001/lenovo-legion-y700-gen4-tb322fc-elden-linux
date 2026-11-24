# 0004 — `Completers.Rime user-data` 空串兜底（2026-11-24，D3 源码正解）

**叠加次序**：`0003-osk-stub-rime-completer-wiring.patch` → **本补丁**。
0003 建出 `src/completers/pos-completer-rime.{c,h}` 与 gschema 的 `Completers.Rime` 子 schema，
本补丁只在其结果上做增量（不重写任何文件），必须**先 0003 后 0004**，否则 hunk 无上下文。

```sh
cd <phosh-osk-stub-0.46.0 树>
git apply 0003-osk-stub-rime-completer-wiring.patch      # 或 patch -p1 -N -s
git apply 0004-osk-stub-rime-userdir-fallback.patch      # 或 patch -p1 -N -s
```

## 改动点（file:line = 打完两个补丁后的行号）

| 位置 | 内容 |
|---|---|
| `src/completers/pos-completer-rime.c:30,33` | 新增 `#include <errno.h>`、`#include <glib/gstdio.h>`（`g_mkdir_with_parents` + `g_strerror`） |
| `src/completers/pos-completer-rime.c:362-375` | `pos_completer_rime_init()` 里在读完三键、`RIME_STRUCT_INIT` 之前加兜底：`*user == '\0'` ⇒ `g_build_filename (g_get_user_data_dir (), "rime", NULL)` + `g_mkdir_with_parents (user, 0700)`；建目录失败只 `g_warning`（含 `g_strerror (errno)`），**继续初始化**，键盘与候选不受影响 |
| `src/completers/pos-completer-rime.c:379` | `traits.user_data_dir = user;` 不变 —— 空串已在上游被替换为默认目录，librime 不会再收到 `""` |
| `data/sm.puri.phosh.osk.gschema.xml:100-107` | `user-data` 键：`<summary>` 去掉错误断言「Empty disables the user dictionary」，`<description>` 改为「Empty uses the XDG default directory ($XDG_DATA_HOME/rime, usually ~/.local/share/rime)」 |

`<default>''</default>` **不变**：兜底在代码里，用户已有的 dconf 值不受影响；`shared-data` / `schema` 两键不动。

## 为什么（根因一句）

librime 把「非 NULL 空串」当合法路径（`rime_api.h` 只判非 NULL），`InstallationUpdate` 对 `""` 调
`create_directories("")` 必败 ⇒ 每次启动 `deployment_tasks.cc:90 Error creating user data dir:`，
用户词典/定制/`installation_id` 不持久化、部署产物落进进程 cwd（osk-stub 由 phosh 拉起，cwd 不在用户目录）。
详见 `reports/d3-ime-userdir-fallback-20261124.md`、`reports/rime-completer-userdir-20261124.md` §3。

## 门禁（原始命令见报告）

- `git apply 0003 && git apply 0004` 于 0.46.0 干净副本 rc=0（`patch -p1` 路径亦 rc=0）
- `gcc -fsyntax-only -Wall -Wextra`（glib/gio + osk-stub src + rime_api.h）rc=0
- `glib-compile-schemas --strict --dry-run` rc=0
- aarch64 交叉重编（同一 sysroot/交叉文件）`ninja` rc=0，产物 `sha256 688acbe7…`

## 风格说明

本文件属 phosh 上游（GLib 2 空格 + `func (args)` 风格），**不是**内核 C 风格，`scripts/checkpatch.pl`
会以「space prohibited between function name and open parenthesis」「no spaces at start of line」全量告警，
属**不可比风格**；实际自查用：2 空格缩进与邻行一致、新增行 ≤ 80 列（`awk 'length>80'` 只命中既存注释行）、
续行按 `g_warning (` 左括号对齐、块注释 `*/` 单独成行（与文件头注释一致）。
