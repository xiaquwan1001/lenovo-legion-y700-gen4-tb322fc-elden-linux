# 进度审计（只读复核）：文档 vs 会话 vs 实测

> 生成：2026-11-17 21:29 CST（文件名按任务指定为 20261118）。工作目录 `/home/xuqianhui/y700-elden`，HEAD `36b7a886`。
> 原则：文档只作被核查对象，**结论以带证据的实测/会话为准**；本轮未改任何 SSOT 文件、未提交、未触设备（设备不在线，未跑 adb/fastboot/ssh）。

## 结论（先数字）

1. **数字全对**：`check-progress-counts.sh --tsv` = **G1 36/37**（39 ID −2 取消）、**G2 10/13**；与 `TASKS §0`、`INDEX §0`、`--selftest`（脚本断言 `(36,37)/(10,13)`）四方一致 → 一致，无需改。
2. **设备状态：文档自相矛盾且大面积滞后**。`INDEX.md:17` 已写「2026-11-17 20:0x 原厂 Android 16 完整启动」，但同一节 `INDEX.md:53` 仍写「⛔ 设备：卡 BL」；`DEVICE/README.md` 首条仍称「在机 = vk192（唯一权威状态行）」，并保留一段标着「现态」的卡 BL 块（`:65`）。→ **文档滞后**（不是会话冲突：会话与 reports 都说已恢复）。
3. **卡 BL 的定性已被推翻且已有实测证据**：真因 = 非原厂 GPT；只写 88 KiB GPT（19:2x T1）即恢复启动，19:52 Android 内核起来、20:04 `sys.boot_completed=1`（`reports/bl-stuck-20261118-forensics.md` §7.1 + `reports/artifacts/bl-stuck-20261118/recovered-getprop.txt`）。
4. **「在机 vk192」现已是历史**：19:36–19:37 T2 用原厂件覆盖 LUN4 `boot_a/boot_b/dtbo/vbmeta`，设备现跑原厂 Android（slot `_a`）→ vk192 不再在机，只是 `bootslot-b/boot_b.img` / `out/boot-elden-vk192.img` 里的**回退件**。
5. **工作区干净（审计开始时）**：`git status --short` 0 行（写本报告后多 2 个未提交报告，见 §四）；`check-doctor.sh` **FAIL=0 / WARN=2**（两条均为已登记存量；写本报告后 WARN=3），耗时 **0.83 s**。

## 一、命令实测（原样复现）

| # | 命令 | 结果 | 耗时 |
|---|---|---|---|
| 1 | `timeout -k 5 120 scripts/recent-sessions.sh 3` | rc=0；最近 3 轮 = `2026-11-17T03:12`（B13/B15/B14 收口）、`T10:40`（GPT 最小化细化，双推 `36b7a886`）、`T13:05`（最新会话，**无 assistant 文本**=本轮审计的父会话） | <5 s |
| 2 | `timeout -k 5 120 scripts/check-progress-counts.sh --tsv` | `G1_total 39 / cancelled 2 / in_scope 37 / complete 36`；`G2_total 13 / complete 10`；rc=0 | <1 s |
| 2b | 同上 `--selftest` | 打印 `G1 36/37`、`G2 10/13`，rc=0 | <1 s |
| 3 | `timeout -k 5 300 scripts/check-doctor.sh` | **FAIL=0 WARN=2**，`/usr/bin/time` = **0.83 s**（`--brief` 不是合法参数，脚本只认 `--staged-fast/--only N/--list/--json`） | 0.83 s |
| 5 | `git log --oneline -8` / `git status --short` | HEAD `36b7a886 2026-11-17 20:56:32`；status **0 行**（另见 §四） | <1 s |

WARN 明细（存量，非本轮引入）：① `vk-ledger` 已登记例外（`vk-ledger-known-issues.tsv`，`uts_dup*`/`num_ne_tag` 大批）；② 4 个 2026-11-03 镜像内核段解不出（免于身份核对）。

## 二、逐项对账

| 核查点 | 文档写法（文件:行） | 实测/证据 | 判定 |
|---|---|---|---|
| G1 数字 | `INDEX.md:22`「G1 = 36/37（2026-11-14 现查）」；`TASKS/README.md:15,24` | 脚本现算 36/37，`--selftest` rc=0 | **一致**（日期括注可更新，非错） |
| G2 数字 | `INDEX.md:27`「10/13」；`TASKS/README.md:16,24` | 脚本现算 10/13 | **一致** |
| TASKS §0 注 | `TASKS/README.md:23`「`--selftest` 断言 36/37 与 **9/13**」 | 脚本实际断言 `("G2",10,13)`（`scripts/check-progress-counts.sh:76`） | **文档滞后**（应 10/13） |
| 设备现态 | `INDEX.md:17`「✅ 20:0x 原厂 Android 16 完整启动」 | `recovered-getprop.txt`：`…ZUXOS_1.5.10.259_ST_260611` / `_a` / `orange` / `1`；§7.1 时间线 | **正确** |
| 设备现态（同节） | `INDEX.md:53`「⛔ 设备：卡 BL，软件层已排到底（11-17 18:05）」 | 同上 + 该块自己引用的 `bl-stuck-20261118-forensics.md` §7 标题即「**已修复**」 | **文档滞后 + 自相矛盾** |
| 在机内核 | `INDEX.md:22`「在机 = 持久化的 vk192」；`DEVICE/README.md:28`「在机 = vk192（唯一权威状态行）」 | §7.1：19:36–19:37 `rawprogram4+patch4` 把 `boot_a/boot_b/dtbo/vbmeta` = 原厂 Android 件；20:04 跑 Android（slot `_a`） | **文档滞后**（应为「回退件，不在机」） |
| 设备现态（DEVICE） | `DEVICE/README.md:65`「★★2026-11-17 现态：设备卡 BL，进不了系统」 | 同 §7.1；且该行**位于**自己承认正确的 `:59`「20:0x 现态=Android」**之后**，排序/标签自相矛盾 | **文档滞后 + 自相矛盾** |
| DEVICE `:69` | 「非原厂物只剩 GPT 里的 `linux17`/`eldenesp` 及其数据」 | T1 已写回原厂 GPT ⇒ 条目消失，数据物理保留（`forensics §7.2`、`INDEX.md:19`） | **文档滞后**（该句属 18:53 旧态） |
| U2 台账行 | `DEVICE/README.md:316`「当前在 **Linux**（b 槽持久直启，环境可 SSH）」；`:327`「U2（b 槽持久直启在跑…）」 | 现为原厂 Android 16 / slot `_a` / 无 sshd | **文档滞后** |
| 核对日期 | `INDEX.md:9`「核对日期：2026-11-17」 | 主机 `date` = 2026-11-17 21:29 CST；最新证据同一天 | **一致**（门禁 §15 通过） |

## 三、必须同轮改的文档行（文件 + 行号 + 原文 + 建议）

| # | 文件:行 | 原文（截断） | 建议改成 |
|---|---|---|---|
| 1 | `INDEX.md:53` | `- **⛔ 设备（U2 HA2EXB0E）：卡 BL，软件层已排到底（2026-11-17 18:05）**：全量刷回原厂引导固件 39 分区…冷起仍落 fastboot…` | `- **⛔ 卡什么 = Linux 未重建（不是设备坏）**：2026-11-17 20:0x 设备已回原厂 Android 16（见本节 0 条）；`linux17`/`eldenesp` 条目已随原厂 GPT 消失、数据保留在 LBA 73277435 ⇒ 下一步 = `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` §3 S3a 重建条目 + 刷回 `bootslot-b/boot_b.img`（vk192 回退件），**需设备窗口**。` |
| 2 | `INDEX.md:54` | `**★18:5x 定性降级 = 未定因…唯一未做的原厂对照 = 整包 rawprogram…线刷**` | 降为历史：`**★历史（11-17 18:5x 定性降级，已被 20:0x T1/T2 推翻）**：真因 = 非原厂 GPT（LUN0 条目名 + LUN4 槽属性），只写 88 KiB GPT 即恢复；硬件判读与送修单作废。取证 = reports/bl-stuck-20261118-forensics.md §7。` |
| 3 | `INDEX.md:55` | `…现况取证 + 分级刷机预案…= reports/bl-stuck-20261118-forensics.md。` | 同上句合并；或改为指向 §7「已修复」而不是「现况取证」。 |
| 4 | `INDEX.md:22` | `1. **G1 = 36/37**（2026-11-14 现查…）。**在机 = 持久化的 vk192（2026-11-16）**：uname -r = …` | `1. **G1 = 36/37**（2026-11-18 脚本现查…）。**设备现跑原厂 Android 16（2026-11-17 20:0x）**；vk192 现为**回退件**（`bootslot-b/boot_b.img` `06c081ca…`、`out/boot-elden-vk192.img` `bdf47f5f…`），以下 vk192 判据均属 2026-11-16 历史时点。` |
| 5 | `DEVICE/README.md:28` | `- ★★**在机 = 持久化的 vk192（2026-11-16；本条唯一权威状态行）**` | `- ★★**现态（2026-11-17 20:0x）= 原厂 Android 16 / ZUXOS 1.5.10.259 / slot _a / verifiedbootstate=orange**；本条以下 vk192 段落 = 历史时点 + 回退件清单（不在机）。` |
| 6 | `DEVICE/README.md:65` | `**★★2026-11-17 现态：设备卡 BL，进不了系统（…）**` | 改标题为 `**★历史（19:36 T2 之前）：卡 BL**`，并把整块（`:65–:92`）移到 `:63` 之后的历史区；删掉 `:69` 的「非原厂物只剩 GPT 里的 linux17/eldenesp」句或注明「18:53 时点，T1 后已消失」。 |
| 7 | `DEVICE/README.md:316` | `…**当前在 **Linux**（b 槽持久直启，环境可 SSH）**。基线回退：…` | `…**当前在原厂 Android 16（slot _a，无 sshd）**；回 Linux 需重建 GPT 条目 + 刷 `bootslot-b/boot_b.img`（vk192）。` |
| 8 | `DEVICE/README.md:327` | `\| mainline（b 槽直启 + 持久根） \| **U2**（b 槽持久直启在跑；当前镜像版本看 §1.1） \|` | 该行标为 `需重建`：U2 现为原厂 Android，mainline 需走 `LINUX-STATE-REPRO` §3；U1 已逆手术。 |
| 9 | `TASKS/README.md:23` | `（--tsv 机读 / --selftest 断言 36/37 与 9/13，漂了就 rc=1）` | `…断言 36/37 与 10/13…` |

可选项（非必须）：`bootslot-b/README.md:38`「当前 b 槽在机内核（vk47clean）」→ 加「历史件」；`INDEX.md:72`「下一步 3. 设备窗口才做」建议补一句「设备现为 Android，设备窗口需先切槽/重建」。

## 四、未提交产物 / 未归档工件

- 审计开始（21:2x）时 `git status --short --untracked-files=all` = **0 行**；写本报告后变 2 行，均为**本轮新生成、未提交**的审计产物：
  `?? reports/progress-audit-20261118.md`（本文件）、`?? reports/todo-next-20261118.md`（21:33 由**并发兄弟会话**生成，非本审计产出，未打开、未改动）。
- 除上述外，比 HEAD 新的工作区文件只有 gitignore 的运行时状态：`.pi/sessions/2026-11-17T13-05-35-847Z_…jsonl`（本轮父会话）、`.pi/sessions/2026-11-17T10-40-20-007Z_…jsonl`、`.pi/fabric/mesh/state.json`。
- `out/`、`reports/artifacts/` 下**无**比 HEAD 更新的文件 ⇒ 恢复证据（`reports/artifacts/bl-stuck-20261118/{recovered-getprop.txt,recovered-screen.png,SHA256SUMS.txt,flash/,edl-read/}`）已随 `0077f5e8` 入库。
- 观察：报告名 `20261118` 与主机日期 `2026-11-17` 差一天（沿用 `bl-stuck-20261118-forensics.md` 的命名习惯），不影响内容。

## 五、门禁盲区（建议，不在本轮改）

**本报告自身带来的门禁增量**：写入后 `check-doctor.sh` 由 `WARN=2 → WARN=3`，新增一条 `报告无人引用: reports/progress-audit-20261118.md; reports/todo-next-20261118.md`。补指针需要改 `INDEX.md`/`TASKS` 类 SSOT，本轮硬约束禁止 ⇒ 作为交接项留给你（最省事：在 `reports/` 的入口 README 或 `TASKS §0` 加一行指针）。

`check-doctor.sh --only 15` 通过的原因：它只比较「§0 核对日期 ≥ 最新会话日期」且「§0 的 vkNN 出现在 DEVICE §1.1 首条」。**两边都写 vk192 ⇒ 相互一致即通过**，无法发现「两边一起过时」。建议加一条低成本断言：§0 / DEVICE §1.1 内不得同时出现「已恢复正常/原厂 Android」与「⛔ 卡 BL」的**现态**标签（同文档内 `✅ 恢复正常` + `⛔ 设备` 并存即 FAIL）。本次正是这种形态：`INDEX.md:17` vs `:53`、`DEVICE/README.md:59` vs `:65`。

## 六、证据清单

- 恢复：`reports/bl-stuck-20261118-forensics.md` §7.1（时间线 19:2x–20:04）、§7.2（单变量判据）；`reports/artifacts/bl-stuck-20261118/recovered-getprop.txt`（6 行：build/slot/verity/boot_completed）。
- 会话：`.pi/sessions/2026-11-17T10-40-20-007Z_01a1e917-….jsonl:906`（assistant，`2026-11-17T12:22:36Z` = 20:22 CST，「主机侧整理完成（设备已救回…）」）；同一会话 12:04Z 起有多条 Android 启动确认。最新会话 `2026-11-17T13-05-35-847Z_01a1e99c-….jsonl` 无 assistant 文本 ⇒ `recent-sessions.sh` 第 3 条显示「无 assistant 文本」属正常。
- 数字：`scripts/check-progress-counts.sh:75-82`（selftest 期望值）、`scripts/check-progress-counts.sh --tsv` 输出。
- 门禁：`scripts/check-doctor.sh` 全量输出 §15/§16 + `汇总: FAIL=0 WARN=2`。
- 提交：`git log -8`（`36b7a886` … `ec3b24f7`，11-17 19:24–20:56）；`git status --short` 空。

收尾: 审计完成 — 数字全对；设备状态与在机内核共 9 处文档行滞后（INDEX 3 处 / DEVICE 4 处 / TASKS 1 处 / bootslot 1 处可选），已列「必须同轮改」清单；check-doctor FAIL=0、WARN 由 2 增至 3（新增=本报告未被引用，需 SSOT 加指针，本轮禁改）。
