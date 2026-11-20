# scripts/ 索引（arch-audit P1#3）— 生成器 + 地图

日期：2026-11-20 · 本轮 lane 3 · 上游待办：`.pi/reports/cleanup-audit-20261120/arch-audit.md` 风险表 **P1#3**
（"240 个一次性脚本无索引，重复造轮子；A3 审计 2026-11-19 是一次性 tsv 会过期"）

**产出**

| 文件 | 性质 | 说明 |
|---|---|---|
| `scripts/gen-scripts-index.py` | 新增（唯一新增代码） | 可重跑生成器；`--check` 可挂门 |
| `scripts/README.md` | 生成物（勿手改） | 333 个入口的分组地图 + 孤立件清单 |
| `reports/scripts-index-20261120.md` | 本文件 | 设计口径 + 本轮统计 |

**没有改任何被索引脚本**（`git status --porcelain -- scripts/` 只有 `?? README.md`、`?? gen-scripts-index.py`
两行是本轮产物；另两条 ` M scripts/rebuild-vk64-image.sh`、` M scripts/uefi-build-variant.sh` 是**别的 lane**
的 shellcheck 修复（arch-audit P1#4），本轮未触碰）。

---

## 1. 数字结论（先看这里）

| 指标 | 值 | 命令 |
|---|---|---|
| 入口总数 | **333** | `python3 scripts/gen-scripts-index.py --tsv \| wc -l` → 334 行（含表头） |
| 顶层 / 一层子目录 | 306 / 27 | `scripts/doctor`、`bisect`、`audio-tplg`、`audio-ucm`、`wd-audio-test` |
| 按类型 | sh 265、py 66、其它 shebang 文件 2（`eldroid-bootctl`、`elden-powerlog.initd`） | 见 TSV `shebang` 列 |
| 按组 | 设备操作 103、门禁 71、造件 69、取证 45、其它 37、公共库 6、一次性 2 | README 表头 |
| 引用数（提及行数） | 中位 **12**、均值 21.6、最大 **274**（`check-doctor.sh`） | |
| 引用数 0（孤立件） | **1** —— 就是本轮新增的 `gen-scripts-index.py` 自己 | |
| 引用数 ≤2（近孤立） | 7（见 §4） | |
| 生成耗时 / 稳定性 | 5.1 s；连续 3 次 TSV `md5` 完全一致（`e97148d9…`） | |
| 门禁 | `--check` rc=0；`check-doctor.sh` **FAIL=0 WARN=7**（WARN 全是存量 C 类，见 §6） | |

**与 arch-audit「240 个脚本」的差**：那个数字只数了 `scripts/*.sh`（239）。真实面是 333 个入口
（`ls scripts/*.sh scripts/*.py | wc -l` = 304，加 27 个子目录件、2 个无扩展名 shebang 件）。
旧 `reports/audit-20261119/A3-scripts-audit.tsv` 覆盖的一层 `.sh` 只是子集，且无 `--check`，会静默过期
——本轮的生成器补的正是这一层。

## 2. 生成器判据（口径 = 契约，改口径要改这段）

1. **扫描范围**：`scripts/` 一层 + 一层子目录；接受 `*.sh` / `*.py` / 任何首行 `#!` 的可执行文本。
   跳过 `__pycache__`；`.conf`/`.tsv`/`.c`/`.java` 等非入口件不索引（它们不是命令）。
2. **用途**：shebang 之后的**首个注释块**（py 优先模块 docstring，`ast` 解析失败退注释），
   取第一行描述；`名字 — 描述` / `名字: 描述` 形式剥掉名字前缀；跳过 `usage/用法` 小标题行。
   全部 333 条都有描述（0 条 `(无头注释)` 残留）。
3. **引用数**：对 `git ls-files` 的**受版本控制文本文件**（`.md .txt .sh .py .service .conf .dev .tsv`，
   剔 `out/ backup/ build/ .git/ node_modules/ .venv/`，单文件 >2 MB 跳过）做一次正则扫描，按 basename
   记**提及行数**，拆 `scripts_refs` / `docs_refs`；再扣掉定义文件里自提自己名字的行。
   生成器与 `scripts/README.md` **永不进语料**（否则计数自增、`--check` 永不收敛）。
4. **分组**：名字正则优先（`门禁 → 公共库 → 设备操作 → 造件 → 取证`），名字全不命中才退头注释正则，
   再不行 `其它`；`scripts/doctor/*` 一律门禁。
5. **一次性**：只认**自报**（首个注释行的"一次性脚本/工具/任务"、one-shot、退役、已过期、不再维护）
   或**文件名带日期**（`-YYYYMMDD.py`）。门禁/公共库永不被判一次性。
6. **确定性**：不读 mtime、不读时钟、不读环境变量；同输入 ⇒ 同字节输出（`--check` 才可挂门）。

### 一个真实踩到的坑（口径修正的由来）

首版 basename 正则带 `(?<![\w.\-/])` 前瞻禁 `-`/`/` 前缀 ⇒ **`scripts/foo.sh` 这种最常见的写法全漏算**，
于是报出 11 个「孤立件」（`android-v3-bringup-walkthrough.sh`、`build-sensord.sh`、`waydroid-*` 等），
实测它们在 `INDEX.md`/`TASKS/README.md`/`reports/*` 里被引用 6–11 次。改成只禁 `[\w.-]` 后，
孤立件从 11 降到 **1**。

> 教训写进这里而不是记忆：**"引用数 0" 的结论先做一次正例抽查（挑 3 个去 grep），再拿去判死**。
> 这批假孤立如果直接进"可删清单"，会删掉正在用的上机执行包。

## 3. 按组分布（详表在 `scripts/README.md`）

| 组 | 数 | 判据 | 备注 |
|---|---|---|---|
| 设备操作 | 103 | flash/fastboot/edl/slot/serial/ssh/deploy/waydroid/cam/… 或头注释"设备侧/在设备上/RUN ON DEVICE" | 含 `to-fastboot.sh`（107 引用）、`device-lock.sh`（108） |
| 门禁 | 71 | `check-*/verify/preflight/assert/sanity/selftest` 或 `scripts/doctor/*` | 聚合入口仍是 `check-doctor.sh`（274 引用，全仓最高） |
| 造件 | 69 | build/mk/gen/pack/assemble/img/bake/install/extract/fetch/… | 造件链最重资产 |
| 取证 | 45 | log/probe/dump/scan/audit/diag/watch/sample/bench/… | 大部分是"上机记一次"的实验脚本 |
| 其它 | 37 | 五类都不贴 | 主机侧元工具：`sess.sh`、`recent-sessions.sh`、`lane.sh`、`mail-*`、`partlun.py`、`odirect-sha.py` |
| 公共库 | 6 | `lib-*.sh` | `lib-device-lock`(48) `lib-boot-ready`(34) `lib-wait`(34) `lib-fastboot`(29) `lib-ssh`(25) `lib-serial-source`(11) |
| 一次性 | 2 | 文件名带日期 | `android-assets-extract-20261119.py`、`mailbox-cleanup-20261102.py` |

**"一次性 = 2" 是个结论，不是漏判**：333 个入口里只有 2 个在内容上自报一次性/带日期。
说明"240 个一次性脚本"这个表述在 arch-audit 里是"任务型脚本"的概称，不是字面的一次性产物；
按"活件 vs 孤立件"看，真正的死件几乎不存在（§4）。

## 4. 孤立 / 近孤立件（引用数 ≤2）

| 入口 | 引用 | 判断 |
|---|---|---|
| `scripts/gen-scripts-index.py` | 0 | 本轮新增，自身即工具；README 引用它后仍为 0（语料排除生成器）。**不是死件** |
| `scripts/t14-rebuild.sh` | 2 | T14 Mobian 换根重建 recipe（主机侧、零设备动作）；指针对仅在 TASKS |
| `scripts/build-payload-hook.sh` | 2 | payload 加载钩子（幂等小步骤） |
| `scripts/build-phosh-upstream-fix.sh` | 2 | 上游补丁验证用一次性构建 |
| `scripts/deskstack-sample.sh` / `deskstack-switch.sh` | 2 | T19/T20 A/B 对照实验件 |
| `scripts/mailbox-cleanup-weekly.sh` | 2 | 周更任务（systemd/cron 侧调用，文档提及少） |

对照：引用数 0 的**真死件 = 0**。arch-audit 说的"重复造轮子"风险不在"死脚本堆积"，
而在"同类脚本多份实现但无地图"——本轮给的是地图，不删任何东西。

**同名撞车**（引用数会被两条合计，别据此判活）：`build.sh` 在 `scripts/audio-tplg/` 与
`scripts/wd-audio-test/` 各一份（各 67）。README 里已单列这条限制。

## 5. 验收（全部实测）

```
$ python3 scripts/gen-scripts-index.py                 # 首次生成
wrote scripts/README.md（333 个入口）        real 0m5.1s

$ python3 scripts/gen-scripts-index.py --check
OK scripts/README.md 最新（333 个入口）      rc=0

$ touch scripts/build-kernel.sh scripts/doctor/05-vk.sh   # 改无关文件（只动 mtime）
$ python3 scripts/gen-scripts-index.py --check
OK scripts/README.md 最新（333 个入口）      rc=0        # 不受 mtime 影响

$ echo "手改的一行" >> scripts/README.md && python3 scripts/gen-scripts-index.py --check
STALE scripts/README.md 过期（333 个入口）→ 跑 python3 scripts/gen-scripts-index.py   rc=1   # 门是活的

$ cd /tmp && python3 /home/xuqianhui/y700-elden/scripts/gen-scripts-index.py --check
OK scripts/README.md 最新（333 个入口）      rc=0        # 与 cwd 无关（ROOT 由脚本自身定位）

$ for i in 1 2 3; do python3 scripts/gen-scripts-index.py --tsv /tmp/d$i.tsv; md5sum /tmp/d$i.tsv; done
e97148d9aa7160a76f2a9e08b0e9a322 …（三次相同）            # 幂等

$ bash scripts/check-doctor.sh | tail -1
== 汇总: FAIL=0  WARN=7 ==
```

`--tsv` 机读列：`path · group · name · refs · scripts_refs · docs_refs · shebang · 用途一句话`
（`--tsv PATH` 落盘、裸 `--tsv` 打 stdout）。`--diff` 与 `--check` 合用可看过期差异。

**以后挂门**（待用户批准，本轮不改 `check-doctor.sh`）：
`scripts/doctor/` 加一个子门跑 `python3 scripts/gen-scripts-index.py --check`，与 §17 静态卫生同档。

## 6. check-doctor WARN 归类（FAIL=0；生成/验收时 8 条 → 收尾 7 条，全是存量 C 类）

| # | WARN | 归类 |
|---|---|---|
| 1 | 源树已档（`geekidos-linux/` 不在盘）：75 行身份暂不可核 | **已登记豁免**（`versions/kernel-src-archive.tsv`，2026-11-19 清理） |
| 2 | 账本已登记例外（`vk-ledger-known-issues.tsv`，uts_dupN） | **已登记豁免** |
| 3 | 4 个 markspin 镜像内核段不可读（免于身份核对） | 存量，本轮不涉 |
| 4 | 内核身份表降级一致（C=2） | 同上，需恢复源树（**需人项**：决策是否恢复/清理存档） |
| 5 | 未找到任何内核树 `.config` → ABI 核对跳过 | 存量（`build/` 已清） |
| 6 | ~~报告无人引用：`bigfile-verdict-20261120.md`、`shellcheck-fix-20261120.md`~~ | **本轮已消**：这两篇在 §6 本表里被点名 ⇒ 本报告成了它们的指针，收尾实测该 WARN 消失（WARN 8→7）。本报告自身也已在 `scripts/README.md` + 生成器 docstring 里被引用，不新增孤儿 |
| 7 | HISTORY/days 落后 HEAD | 存量，`scripts/gen-history.sh` 可补（**需人项**：是否现在重生成 HISTORY） |
| 8 | 无构建树可用 → 模块化门禁跳过 | 存量（同 #5） |

本轮**没有新增 WARN**，**没有 FAIL**（WARN 由 8 降到 7，降的那条见上表 #6）。需 root 的动作：无（本 lane 全程只读 + 写 2 个新文件）。

## 7. 可复现命令

```bash
cd /home/xuqianhui/y700-elden
timeout -k 5 180 python3 scripts/gen-scripts-index.py            # 生成/更新 scripts/README.md
timeout -k 5 180 python3 scripts/gen-scripts-index.py --check    # 门禁：rc=1 = 过期
timeout -k 5 180 python3 scripts/gen-scripts-index.py --tsv      # 机读（stdout）
timeout -k 10 300 bash scripts/check-doctor.sh                   # FAIL=0
```

## 8. 下一步（P1#3 之外的动手项，本轮不做）

1. 把 `--check` 接进 `check-doctor`（子门 `scripts/doctor/24-scripts-index.sh`）——需要用户同意改门禁。
2. 「其它 37」再收一轮：`sess.sh`/`recent-sessions.sh`/`lane.sh` 可聚成 `meta-*` 前缀族，
   让名字本身表达分组（改名影响调用点，属结构性改动，另开 lane）。
3. 同名 `build.sh` 两份：`scripts/audio-tplg/build.sh`、`scripts/wd-audio-test/build.sh` 建议改名为
   `build-tplg.sh` / `build-wdaudio-test.sh`，消除引用数歧义（本轮只标注不改）。
