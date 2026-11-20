# Python 静态扫描补盲区（pyflakes / vulture）— 2026-11-20

对应 arch-audit **P2#10**：本机此前未装 pyflakes/vulture，`scripts/*.py` 无 lint 覆盖。
本轮建立独立 venv（不碰 PEP 668 系统环境）+ 首轮全量扫描 + 只修「未定义名字 / 未使用 import」两类最低危问题。

## 1. 工具与安装（可复现）

```bash
# python3 -m venv 在本机不可用：ModuleNotFoundError: No module named 'ensurepip'
#   （缺 python3-venv/ensurepip，装它需要 sudo；本轮不用 sudo ⇒ 换 virtualenv，不动系统环境）
python3 -m venv ~/.venvs/static-scan          # ⇒ 失败（ensurepip 缺），见上
virtualenv -p python3 ~/.venvs/static-scan    # ⇒ ok（seeder 自带 pip wheel，无需网络也能建 venv）
cd ~/.venvs/static-scan && ./bin/pip install -q pyflakes vulture
```

| 组件 | 版本 |
|---|---|
| Python | 3.14.4 (CPython, x86_64-linux) |
| virtualenv | 21.14.13（`~/.local/bin/virtualenv`） |
| pip | 26.2.2（venv 内，seeder bundle + PyPI 升级） |
| pyflakes | 4.1.0 |
| vulture | 2.16 |

安装走既有代理环境变量，PyPI 可达（无「网络/源不可达」情况）。venv 位置 `~/.venvs/static-scan`，与仓库无关，不入库。

## 2. 命令行

```bash
cd /home/xuqianhui/y700-elden
~/.venvs/static-scan/bin/pyflakes scripts/*.py tools/*.py
~/.venvs/static-scan/bin/vulture --min-confidence 80 scripts/*.py tools/*.py
```

扫描面：**scripts/\*.py = 63 个**（首轮快照；本轮进行中另一 lane 新增 `scripts/out-status.py`，见 §5 说明）、**tools/\*.py = 1 个**（`tools/avbtool.py`，无命中）。

## 3. 前后数字

| 工具 | 修复前 | 修复后 |
|---|---|---|
| pyflakes 命中行 | **23** | **10**（其中 2 行为扫描期间新增的未跟踪文件 `scripts/out-status.py`） |
| ├ F401 unused import | **15** | **0** |
| ├ F821 undefined name | **0** | **0** |
| └ 局部/全局变量未使用 | 8 | 8（本轮口径不改，见 §5） |
| vulture (min-conf 80) | **6** | **6**（同类 6 项，仅行号因删 import 位移；mkbootimg 80→79） |

**结论要点：全仓没有任何 undefined name（F821=0）**——即静态层面不存在「跑起来才 NameError」的显性缺陷；可自动判定的真问题只有未使用 import 与死变量/死代码。

## 4. 已修：15 处未使用 import（每处记录行号 + 原文）

改法统一为**只删那一行（或从多名字 import 里删一个名字）**，不改逻辑、不重排其他 import。

| # | 文件 | 行 | 原文 | 改为 |
|---|---|---|---|---|
| 1 | `scripts/android-assets-extract-20261119.py` | 27 | `from collections import Counter` | 删除 |
| 2 | `scripts/android-ext4-slim-test.py` | 19 | `from collections import defaultdict` | 删除 |
| 3 | `scripts/android-rom-segassemble.py` | 18 | `import shutil` | 删除 |
| 4 | `scripts/android-super.py` | 417 | `    import re`（函数内 `cmd_assemble`） | 删除 |
| 5 | `scripts/blackbox.py` | 40 | `import sys` | 删除 |
| 6 | `scripts/fb-survey.py` | 22 | `import sys` | 删除 |
| 7 | `scripts/ffs-extract.py` | 15 | `import sys, os, struct, uuid, lzma, argparse` | `import os, struct, uuid, lzma, argparse` |
| 8 | `scripts/gpt-surgery-tb322fc.py` | 34 | `import os` | 删除 |
| 9 | `scripts/mail-draft-check.py` | 26 | `import re` | 删除 |
| 10 | `scripts/manifest-from-image.py` | 28 | `import os` | 删除 |
| 11 | `scripts/mkbootimg.py` | 34 | `import tempfile` | 删除 |
| 12 | `scripts/uefi-fv-strings.py` | 15 | `import struct` | 删除 |
| 13 | `scripts/uefi-fv-strings.py` | 34 | `    import io`（`_try_raw` 内） | 删除 |
| 14 | `scripts/uefi-usb-gap.py` | 11 | `import argparse, glob, os, subprocess, sys, time` | `import argparse, glob, os, subprocess, time` |
| 15 | `scripts/waydroid-haptics-bake-patch.py` | 13 | `import sys` | 删除 |

`git diff --stat`：14 文件、+2/−15 行（uefi-fv-strings 1 文件 2 处）。

### 逐处核验（改前确认「真的没用到」，不单信 pyflakes）

对每个被删名字做 `grep -c "\bNAME\." file`：`sys.` / `struct.` / `io.` / `os.` / `re.` / `shutil.` / `tempfile.` / `Counter` / `defaultdict` 在对应文件中均为 0 命中。
其中 3 处是**容易误伤**的，单独确认：
- `uefi-fv-strings.py` 的 `struct`（其余 UEFI 脚本大量用 struct）：该文件走 `lzma` + 手工字节切片，`struct.` 0 命中。
- `uefi-fv-strings.py:34` 的 `io`：`d.decompress(payload)` 返回 `bytes`，未构造 `BytesIO`；`io.` 0 命中。
- `ffs-extract.py` 保留 `struct`（`struct.` 3 命中）；`gpt-surgery-tb322fc.py` 保留 `struct`（33 命中）、删 `os`（0 命中）。

### 改后验证

```bash
python3 -m py_compile scripts/*.py tools/*.py     # exit 0，全部通过
```

`--help` 冒烟（14 个改过的脚本，`timeout -k 3 30`）：

| 结果 | 脚本 |
|---|---|
| OK（rc=0，打印正常用法） | android-assets-extract-20261119 / android-ext4-slim-test / android-rom-segassemble / android-super / blackbox / fb-survey / ffs-extract / gpt-surgery-tb322fc / mail-draft-check / manifest-from-image / mkbootimg / uefi-usb-gap |
| rc=2（**改前同样 rc=2**） | `uefi-fv-strings.py`：无 argparse，`--help` 走自写的 usage 分支（打印「用法：…」后 exit 2）。用 `git show HEAD:` 取原版对照，输出逐字一致 ⇒ 非本次回归 |
| rc=1（**改前同样 rc=1**） | `waydroid-haptics-bake-patch.py`：无 argparse、顶层即执行，`os.makedirs('/mnt/Samsung')` ⇒ `PermissionError`（该脚本设计在另一台机器/路径上跑）。原版对照同为该 PermissionError ⇒ 非本次回归 |

## 5. 未修清单与分类

### 5.1 pyflakes：局部/全局变量未使用（8 条，**按本轮口径不改**，只列）

| 位置 | 内容 | 分类 | 理由 |
|---|---|---|---|
| `check-shell-hygiene.py:130` | `waived = [...]` 赋值后未用 | 真问题（死计算，无害） | 汇总打印只用了 `len(hits[k]) - len(live)`；删/改属行为等价清理，但非 F401 类，本轮不动 |
| `detect-memory-corruption.py:152` | `disk_sha256 = b/c` 未用 | 真问题（死赋值，无害） | 三读一致性已由 `consistent`/`shas` 承载；改它要动取证脚本，风险不对称 |
| `out-manifest-check.py:156` | `global fail, warns` 未赋值 | 真问题（多余 global，无害） | `fail` 只读（`fail - fails0`）、`warns` 未在此函数写；删 `global` 属等价改动，非本轮范围 |
| `out-manifest-check.py:174` | `cases = [...]` 未用 | 真问题（死常量） | selftest 已改为直接造树 + `check_tree`；留着是文档性残留 |
| `out-manifest-check.py:183` | `n = check_tree(tmp)` 未用 | 真问题（死赋值） | 判定走 `fail - fails0`；删赋值需确认 check_tree 无副作用依赖（有副作用，删名字安全）——下一轮可做 |
| `rawprogram-preflight.py:206` | `limit = limits.get(0)` 未用 | 真问题（死赋值） | 逐 LUN 用 `limits[lun]`；单值入口已弃用 |
| `serial-tap.py:70` | `except OSError as e:` 的 `e` 未用 | 有意 | 端口未就绪时静默重试是设计；`as e` 只为占位可读性，加 `del e`/去掉 `as e` 无功能差异 |

（`scripts/out-status.py:262/263` 两条 `global fail`、`fails0` 未用出现在**修复后**的列表里：该文件是本轮进行中另一 lane 新建的未跟踪文件，不在首轮 63 个快照内，故不计入前后对比；同样归「局部变量类，本轮不改」。）

### 5.2 vulture `--min-confidence 80`（6 条，**全部不改**）

| 位置 | 内容 | 分类 | 理由 |
|---|---|---|---|
| `gpt-preflight.py:396` | 内嵌函数参数 `crc_bad=False` 未用 | 真问题（死参数，无害） | 仅在 selftest 的 `hdr()` 里；`grep crc_bad` 全文件仅定义处 1 命中 |
| `mail-append-sent.py:174` | `search(self, charset, *criteria)` 的 `charset` 未用 | 有意 | 模拟 `imaplib` 方法签名，形参名/顺序必须与真实 API 对齐 |
| `mail-append-sent.py:181` | `append(self, box, flags, date_time, msg)` 的 `date_time` 未用 | 有意 | 同上，FakeIMAP 与 `imaplib.append` 签名对齐 |
| `mkbootimg.py:79` | `compose(..., id_mode="aosp")` 未用 | 真问题（死参数）但**不改** | 参数属对外打包 API 的文档化槽位（`grep` 显示仓内无调用方传它）；删参数是 API 变更，超出「最低危」范围 |
| `vk-identity.py:348` | `while True:` 循环之后的 `return None, '', 'absent'` 不可达 | 真问题（死代码，无害） | 循环体内所有出口都 `return`/`continue`，循环永不正常退出。**该脚本禁重跑**（`.pi/AGENTS.md` 版本账规则），故只记录不触碰 |
| `vk-identity.py:911` | `return 0` 之后重复的 `sys.stdout.write(text)` / `return 0` | 真问题（复制粘贴残留，无害） | 同上，脚本禁重跑；可读性瑕疵，留待改该脚本的专轮一起清 |

**「unused function」类一律未出现在结果中**（`vulture` 100% 置信度未报任何未使用函数），即本轮无需按「入口函数不删」的豁免处理。

## 6. 验收

```bash
python3 -m py_compile scripts/*.py tools/*.py        # exit 0
timeout -k 3 300 bash scripts/check-doctor.sh        # exit 0
```

`check-doctor.sh` 汇总：**FAIL=0  WARN=6**（与改动前的存量一致，无新增；§24 scripts 索引门 `[ok] scripts/README.md 最新（336 个入口）`，删 import 不改入口名 ⇒ 无需重生成索引）。

WARN 归类（**C 类存量，全部与本次改动无关，已登记豁免**）：

| # | WARN | 归类 |
|---|---|---|
| 1 | 源树已档 `geekidos-linux/` 不在盘：75 行身份暂不可核（逐行登记 `versions/kernel-src-archive.tsv`） | C 存量（2026-11-19 清盘决定） |
| 2 | 账本已登记例外（`vk-ledger-known-issues.tsv`，uts_dup 类） | C 存量（已豁免） |
| 3 | 4 个 boot 镜像内核段不可读（免于身份核对） | C 存量 |
| 4 | 内核身份表降级一致（C=2，源树不在盘） | C 存量 |
| 5 | 未找到内核树 `.config` → ABI 核对跳过 | C 存量（无 build 树） |
| 6 | 无构建树可用 → 模块化门禁跳过 | C 存量（同上） |

## 7. 后续建议（下一轮可选，均低危）

1. `out-manifest-check.py` 的 3 处死代码（`global fail/warns`、`cases`、`n`）——selftest 语义已由 `fails0` 承载，删后跑 `bash scripts/check-doctor.sh --only 23` 即可回归。
2. `check-shell-hygiene.py:130` / `rawprogram-preflight.py:206` / `detect-memory-corruption.py:152` 的死赋值清理（每处配一次 §对应门禁跑）。
3. `gpt-preflight.py` 的 `crc_bad` 参数与 `mkbootimg.py` 的 `id_mode` 属签名级决定，建议并入各自模块的上游化轮（M 系列）一起评审。
4. 把 `~/.venvs/static-scan` 的两个命令接进 `check-doctor.sh` 新段（或独立 timer），避免这份补盲只做一次。
