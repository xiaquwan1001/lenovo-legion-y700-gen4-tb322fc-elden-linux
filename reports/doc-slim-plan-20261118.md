# 文档精简方案（只出方案，未改任何 SSOT；2026-11-18）

- **pi 会话 id**：`01a1e99c-e467-7036-8e4b-c301b44d9c11`
- **约束遵守**：全程只读；未改 `INDEX.md` / `TASKS/` / `PITFALLS/` / `DEVICE/` / `AGENTS.md`；未 `git add/commit`；未接触设备（平板不在线，未跑 adb/fastboot/ssh）；外部命令全部 `timeout -k 5`。
- **量体口径**：`wc -c -l`（字节 = `wc -c`），行号 = `sed -n`/`awk` 现查（2026-11-18 本会话实测，**针对磁盘上的工作树版本**）。
- **工作树状态（重要）**：开始时 `git status --porcelain` 已有**别的 lane 留下的未提交改动**（`INDEX.md`/`TASKS/README.md`/`DEVICE/README.md`，mtime 2026-11-17 21:45–21:48，本审计只读、`git diff | grep doc-slim-plan` = 0 命中）⇒ 本文行号对应**该工作树快照**；动手前先 `git diff <file>` 复核锚点仍在。

## 执行状态（2026-11-19 更新，第一刀已落地）

- **C1–C8 已执行**（提交 `12731b70` + `c79b2996`，已推 github/ustc 的 `main`）：`DEVICE §1.1` 两段历史快照 → `DEVICE/sessions/2026-11-19-§1.1历史快照三轮下沉.md`；`TASKS §5` 49 个历史块 → 11 行索引表（12 个内联块 → `TASKS/sessions/2026-11-19-TASKS5内联块下沉.md`）；`TASKS §7` 头 5 个增量块 → `TASKS/sessions/2026-11-19-§7头增量块下沉.md`；`INDEX §0` 下一步 4/5/6/8 压成指针行。
- **C9（PITFALLS 索引行合并）未做**：§2④ 已判「≈1.2 KB 收益 / 3 行 vs 每条都是独立判据」⇒ 收益 < 风险，`PITFALLS` 保持原样。
- **行数账**：`INDEX.md` 341→315、`TASKS/README.md` 706→559、`DEVICE/README.md` 407→323、`PITFALLS/README.md` 359（未动）。门禁 = `scripts/check-doctor.sh` FAIL=0 / WARN=2（均为既有 C 类登记项）。
- **注意**：下文 §1/§2/§3 的行号仍是 **2026-11-18 快照**的行号（执行时已按锚点文本重新定位，非按行号）。

## 0. 结论先行（数字）

| 项 | 数 |
|---|---|
| 5 份入口 SSOT 合计 | **2,776 行 / 507,330 B**（`INDEX` 42,354 · `TASKS/README` 180,736 · `PITFALLS/README` 152,177 · `DEVICE/README` 56,492 · `RUNBOOK-BRINGUP/*.md` 75,571） |
| 本方案可净减 | **≈ 44 KB / ≈ 250 行（占 5 份 8.7%）**；其中「第一刀」（§3）≈ 17 KB / ≈ 110 行 |
| 冗余主形态 | **不是跨文档逐字复制**（实测 0 处整段复制，见 §2-③），而是**同一事实在三处各写一遍**（`INDEX §0` / `TASKS §5·§7` / `DEVICE §1.1`）+ **已下达的沿革块仍留在入口文档** |
| 最大三处 | `DEVICE §1.1` 历史快照 14.6 KB · `TASKS §5` 历史块 15.6 KB · `INDEX §0` UEFI/ramoops 长段 8.4 KB |
| 有无先例 | 有：`reports/doc-slim-20261102.md`（P2-1）+ `reports/doc-trim-20261102.md` 已把 `DEVICE §1.1` 的 121 行搬进 `DEVICE/sessions/2026-11-02-在机状态沿革-vk64..vk172.md`；**两个月后同一节又长回 18.9 KB** ⇒ 本条属「重复执行既有 recipe」，不是新发明 |

## 1. 量体（逐文件）

| 文件 | 行 | 字节 | 备注 |
|---|---|---|---|
| `INDEX.md` | 313 | 42,354 | §0 = 9–103 行 **20,590 B（占全文 49%）** |
| `TASKS/README.md` | 651 | 180,736 | §5 = 206–476 行 45 KB；§7 = 616–651 行 25,943 B；>800 B 的行 **59 条**、>2000 B **8 条**（最长 `:97` 6,711 B） |
| `PITFALLS/README.md` | 350 | 152,177 | **只有索引**（正文在 `sessions/`）：350 行平均 **434 B/行**，799 B 上限行 5 条（门禁 `scripts/doctor/s07-08-docs.py:111` 限 800） |
| `DEVICE/README.md` | 397 | 56,492 | §1.1 = 27–230 行 **35,992 B（占 64%）**，其中历史快照 132–206 + 216–226 = **14,619 B** |
| `RUNBOOK-BRINGUP/{README,GPT-MINIMAL-DESIGN,LINUX-STATE-REPRO,f2fs-migration}.md` | 1,065 | 75,571 | 程序性文档，冗余度低（唯一重复 = `gpt-surgery-tb322fc.py build` 片段两处，参数不同，**不建议动**） |
| `reports/` | 539 个 `.md` | **7,212,235 B** md；目录全量（含 `artifacts/`）**2,057,723,938 B ≈ 1.92 GiB** | 只记数，本方案不动 |
| `*/sessions/` | 875 个 `.md` | — | TASKS 325 / PITFALLS 222 / SESSIONS 171 / RESOURCES 9 / DEVICE 3 / RUNBOOK 1 |
| `.pi/sessions/` | **345** 个 `.jsonl` | — | 会话原始流，不下沉 |

## 2. 三类冗余（证据 + 精度）

### ① `INDEX.md §0` 里的已完成历史（应下沉，只留 1–2 行指针）

| 行号 | 现状字节 | 内容 | 判据 |
|---|---|---|---|
| **29–43** | 3,611 | 「拓展：UEFI 两种形态都通」→ 2026-11-10 `dtbo_a` 定因 → 11-14 USB 抢占 → 11-14 夜间接形态 → 11-15 Shot A/B 六发 → **11-15 夜 ramoops 根因定案**（含 `0xc23e0000/0xc18b0000`、`t=0.0269 s`、`2.31 s` 等全部测量） | 全链已结案并有三份报告 + `PITFALLS #665`；且**与同节 74–85 行重复讲同一根因两次** |
| **74–85** | 3,266 | 下一步-5「UEFI GRUB 路径取证已完成 + pstore 守卫 2 枚已上游 + 真机 A/B 对照 + 14:03 ESP 归位 + 冷启验证 + `#667` 修复」 | 同批事实在 29–43、`PITFALLS #665/#666/#667`、`patches/upstream/pstore-ram-initrd-overlap-20261116/`、`reports/pstore-ram-initrd-guard-20261116.md` 各有一份 |
| **86** | 712 | 下一步-6「LastFile2 打印版 v2 **已撤销**」整段（含 sha、`lf2_addr=0xc23e0000` 复核） | 任务已撤销（2026-11-16），条目本身只剩沿革价值 |
| **88–91** | 845 | 下一步-8「磁盘 A 类清理已执行完」两轮释放 8.85+6.40 GiB 明细 | 执行记录全文在 `reports/disk-cleanup-20261115.md` §2 |

### ② `TASKS/README.md §5/§6` 已结项旧线与 §4 重复

| 行号 | 现状字节 | 内容 | 判据 |
|---|---|---|---|
| **214–375** | **15,570 / 162 行** | §5「查漏补缺」的 **49 个 `### 2026-xx-xx` 历史块**：其中 **37 块已只剩 `⟪全文见 sessions/…⟫` 一行（合计 2,219 B）**，另 **12 块仍是内联正文（7,233 B，全为 UEFI 2026-10-31→11-04）** | 已下沉的 37 块仍各占「1 标题 + 1 指针 + 空行」= 每块 ~130 B，49 块只传递「有这些历史」这一个信息 |
| **621–626** | **4,302** | §7 头的**历次邮件增量块**：11-08（795 B）/ 11-14 mdss v5（924 B）/ 11-12（789 B）/ 11-11 v10（958 B）/ 未答项（554 B）/ 归档复核口径（278 B） | 每块都已由 `reports/mail-triage-*.md`、`reports/upstream-status-20261113.md`、`INDEX §0-6` 覆盖；`:619`「当前一页」已指向 status 报告（自相矛盾的旧形态见 `HISTORY/days/2026-11-17.md:9` 的修正 commit） |
| **574–615** | 4,106 | §6-6「版本基线与自编/预制账（2026-10-06 裁决）」 | 资产台账职责属 `RESOURCES/README.md`；**风险评估 = 中**（无任何跨文档引用，见 §3 说明） |
| **137–199** | 约 27 KB | §4「开放待办」里 17 条 `> 沿革与逐轮明细（零删改）→ …` 指针行（**合计 72 行 / 31,377 B 含 §5**） | 结论 + 指针形态本身合规；但同一条目下常出现 **3–6 行证据路径**，可压到 1 行 |

### ③ 跨文档重复句子（`grep`/脚本实测）

- **逐字复制 = 0 处**：对 `INDEX.md`/`TASKS/README.md`/`PITFALLS/README.md`/`DEVICE/README.md`/`RUNBOOK-BRINGUP/*.md` 做分句切分（`。；，|`）+ `difflib.SequenceMatcher` 找 ≥2 连续子句匹配 ⇒ **0 命中**（说明 2026-11-12 去重审计仍然有效）。
- **同句只出现 2 处**（同文件/跨文件，长度 ≥40 字，归一化后 `<40` 的短句不计）：
  - `python3 scripts/gpt-surgery-tb322fc.py build ...` = `RUNBOOK-BRINGUP/README.md:309` 与 `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:122`（**参数不同**：`--linux-gib "$LINUX_GIB"` vs `--linux-gib 192` ⇒ 不算冗余）。
  - `证据 reports/artifacts/uefi-daily-v8-20261116/` = `INDEX.md:81` 与 `DEVICE/README.md:57`（同指针两处，可保留：一处是状态、一处是设备证据）。
- **同一报告指针被反复引**（`grep -o 'reports/…\.md' | sort | uniq -c`）：`TASKS` 里 `reports/upstream-status-20261113.md` ×4、`uefi-dtbo-a-rootcause-20261110.md` ×4、`userland-dark-brightness-verify-20261011.md` ×4；`INDEX` 里 `upstream-replies-20261117.md` ×2、`uefi-grub-initrd-rootcause-20261115.md` ×2 —— **都是「同节内前后两处讲同一件事」的指纹**，正是 §2-①表里那几段。

### ④ `PITFALLS` 同因多条（对题目给的候选逐条核对，结果与预期不同）

| 组合 | 判读 | 证据 |
|---|---|---|
| **#665 / #666** | **同因（ramoops 盖 initrd）**，`#666` 是 `#665` 的 QEMU 复刻子坑 ⇒ **可合并**：`#665` 正文末加一行「QEMU 复刻陷阱：`-dtb` 与 `-device loader` 同址 / 需 `force-raw` 自装内存 / 挪 `0x50000000`」 | `PITFALLS/README.md:344–345` |
| **#550 / #551** | **同因（UEFI 交棒判据）**，两行相邻、都讲「pstore 空是假阴性 / 三条持久通道」⇒ **可合并为一行 + 两条正文指针** | `:252–253` |
| **#617 / #620** | **同事件链**：`#620` 明写「`#617` 判读作废（60–70 s 掉电 = ramoops oops）」⇒ **可并成「作废旧说 + 真因」一行** | `:315`、`:318` |
| **#482 / #486** | **不同因**：`#482` = `fastboot boot` 接受/拒绝非确定性；`#486` = EDL loader 不放行 `peek`（`#488` 只是顺带复核） ⇒ **不建议合并**，只在 `#482` 行加「与 `#486` 无关，别互推」 | `:191`、`:195`、`:197` |
| **#658 / #667** | **不同因**：`#658` = 隔壁项目孤儿 `fastboot` 抢 USB 通道；`#667` = `q28-boot-watchdog` 只认 `card0` ⇒ **合并会丢判据，禁止** | `:338`、`:346` |
| 结论 | PITFALLS 可省 **≈ 1.2 KB（3 行）**，**收益远小于风险**（每条都是独立判据）；`PITFALLS` 应保持「索引满、正文不重复」现状，只做上面 3 组 | — |

## 3. 「第一刀」（最安全、低风险、可立即执行；精确到行）

> 执行顺序 = 从上到下；每步独立可回滚（`git diff` 粒度 = 1 次 commit）。**全部为「原文搬到 `*/sessions/` 后留指针」或「同节内合一」，不做语义删改。**

| # | 文件 | 原文首行 → 末行（逐字锚点） | 动作 | 预计净省 |
|---|---|---|---|---|
| **C1** | `DEVICE/README.md` | `:132` `- **2026-11-10 20:15（历史快照，已被上面 11-13 行覆盖；当时 \`active=a\` 走 UEFI/ESP 路径）**…` → `:206` `  **改非活动槽属性必须用 \`scripts/slot-attr.py\` 直写 LUN4**…` | **逐字搬**到新 `DEVICE/sessions/2026-11-18-§1.1历史快照二轮下沉.md`（file header 6 字段照 `INDEX §2`），本节留 3 行指针 | **10,294 B / 75 行 → ~350 B** |
| **C2** | `DEVICE/README.md` | `:216` `- ★**2026-10-15 晚：M1-7.3 模块树已补齐并部署**…` → `:226` `- **2026-10-10 离线快照（Q28 调试轮收尾…）**…` | 同上（同一目标文件续写）；`:227–230`（串口 logger / 相机 AE / `CONFIG_LOCALVERSION` / Waydroid 资产）**保留原位** | **4,325 B / 11 行 → ~200 B** |
| **C3** | `TASKS/README.md` | `:214` `### 2026-11-09（傍晚，p62）：**R63 分区普查…` → `:375` `> ⟪全文见 \`sessions/2026-11-13-TASKS5沿革-37.md\`⟫` | 49 个历史块 → **一张 12 行「日期 → sessions 文件」两列表**（37 个已有指针原样进表；12 个内联块先搬进 `TASKS/sessions/2026-11-18-TASKS5-12内联块下沉.md`） | **15,570 B / 162 行 → ~1.6 KB / 15 行** |
| **C4** | `INDEX.md` | `:29` `4. **拓展：UEFI 两种形态都通**…` → `:43` `     → \`reports/uefi-grub-initrd-rootcause-20261115.md\`…` | 压成 2 行：①「UEFI 两形态都通（2026-11-10 `dtbo_a` 定因）」②「initrd/ramoops 根因已定案 + 守卫已上游（`#665`/`reports/uefi-grub-initrd-rootcause-20261115.md`）」，其余测量值只留报告 | **3,611 B / 15 行 → ~600 B / 2 行** |
| **C5** | `INDEX.md` | `:74` `5. **UEFI GRUB 路径：取证已完成（2026-11-15 夜）…**` → `:85` `   → \`patches/upstream/pstore-ram-initrd-overlap-20261116/\`…` | 压成 2 行（「守卫 2 枚已上游、真机 A/B 已验、等回复」+ 指针），`qemu-ramoops-initrd-ab.sh` 等留在报告 | **3,266 B / 12 行 → ~500 B / 2 行** |
| **C6** | `INDEX.md` | `:86`（单行）`6. ~~**LastFile2 打印版（v2）缺屏上取证**~~ **→ 已撤销…**` | 压成 1 行「6. ~~LastFile2 v2 屏照~~ 已撤销（2026-11-16，信息增量为 0）→ `reports/` 见 §0-5」 | **712 B → ~150 B** |
| **C7** | `INDEX.md` | `:88` `8. **磁盘 A 类清理已执行完（2026-11-16）…**` → `:91` `   → \`reports/disk-cleanup-20261115.md\` §2…` | 压成 1 行「8. 磁盘清理两轮共释放 15.25 GiB（项目 91→76 G）→ `reports/disk-cleanup-20261115.md` §2」 | **845 B / 4 行 → ~150 B** |
| **C8** | `TASKS/README.md` | `:621` `> **★2026-11-08 增量（\`reports/mail-triage-20261108.md\`…**` → `:626` `> **归档复核口径（2026-11-04 起）**…` | 搬进 `TASKS/sessions/2026-11-18-§7头增量块下沉.md`，§7 头留 1 行「历次邮件增量（11-04…11-14）→ 本文件 + `reports/upstream-status-20261113.md`」；**`:626` 归档复核口径若判据性强，可保留为独立一行** | **4,302 B / 6 行 → ~400 B** |
| **C9** | `PITFALLS/README.md` | `:252`（`#550`）+ `:253`（`#551`）；`:315`（`#617`）+ `:318`（`#620`）；`:344`（`#666`）→ 并入 `:345`（`#665`） | 3 组各并成 1 行（`#665` 收 `#666` 为子句；`#617/#620` 写成「作废 + 真因」一行；`#550/#551` 写成「三条持久通道」一行），**正文条目文件不动**，只在索引行末尾互相指针 | **~1.2 KB / 3 行** |

**C1+C2 前置检查（已实测通过）**：`scripts/doctor/15-timeline.sh` 只要求 §1.1 内 **`★★` 行恰好 1 条**（`grep -c '^[- ]*★★'`）且**前 12 行**里能取到 `vkNN` ⇒ 132–226 区间 **`★★` 命中 0**（`awk 'NR>=131&&NR<=229 && /★★/'` 空），首条 `★★` 仍在 `:28`，**不受影响**。

## 4. 明确不要动的部分（判据 / 禁跑 / 版本账 / 上游发信）

1. **`INDEX.md §2` 全部规则**（会话写什么 8 条、时间序裁决 5 条、入口阶梯、四文件职责边界、`check-doctor §15` 门）—— 这是元规则，删改即入口失效（`scripts/doctor/15-timeline.sh` 依赖 `## 0. 现在一页` + `核对日期：` 字面量）。
2. **`.pi/AGENT-OPS.md`、`AGENTS.md` 全文**——授权/行为唯一入口。
3. **`INDEX.md §4「快速入口命令」块**（`:273–313`）里的禁跑/判据行，尤其：`:300` `★ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM → 死内核，PITFALLS #162）`、`:284` 引导链先查 `PITFALLS #87`、`:307`「本 ABL **无 fastboot fetch**」、`:294` `build-id` 成功判据、`:296` `REFUSING` 跨 KV 规则。
4. **版本账与内核身份**：`versions/vk-kernel-identity.tsv`、`scripts/vk-identity.py`（**禁重跑**，镜像缺失会清空整表）、`DEVICE §1.1 :28–35` 首条（在机 `vk192`，`★★` 唯一权威行）、`DEVICE §2.5/§3.3`（GPT 参数/容量决定）。
5. **`PITFALLS` 各条正文里的判据与禁跑命令**（例 `#162` olddefconfig、`#290` 无 fetch、`#482` 非确定性、`#486` EDL peek 不可用、`#658` `getvar product` 探活、`#667` `cardN` 认卡、`#646` IME 前置条件）—— 本方案只允许**索引行合并**，不动正文条目文件。
6. **上游发信 rule**：`AGENTS.md`「上游发信（2026-10-31 用户授权）」三件套 + `TASKS §7`「按系列逐次批准」+ `patches/upstream/*/SENT.md`（MID 清单）。`C8` 搬走的是**增量快照文字**，投递状态与 `SENT.md` 指针必须留在 §7。
7. **§0 条目编号**：`INDEX.md:66` 有 `见上第 6 条与本文件 §0-6` 这类**按序号引用** ⇒ 精简只许**缩短条目正文**，**不许重排/重编号** `§0` 的 0–6 与 `下一步` 1–9。
8. **`scripts/doctor/s07-08-docs.py:111` 的 800 B 索引行上限**：`C9` 合并后每行仍需 ≤800 B（合并 ≠ 变长）。

## 5. 执行后的验收（照 `AGENTS.md`「收尾」口径）

```sh
timeout -k 5 60 scripts/check-doctor.sh            # 必须 FAIL=0；WARN 逐条归类
timeout -k 5 60 scripts/check-doctor.sh --only 15   # §0 核对日期不落后 + DEVICE §1.1 单 ★★
timeout -k 5 60 scripts/doctor/s07-08-docs.py       # 索引行 ≤800 B / 会话可检索 / 报告被引用
timeout -k 5 60 scripts/check-progress-counts.sh --tsv   # 36/37、10/13 不动
grep -rn 'DEVICE/README.md §1.1\|TASKS.*§5\|§0-6' --include='*.md' . | wc -l   # 与改前同数（引用点不变）
```

## 6. 证据（命令与实测输出）

- 量体：`wc -c -l INDEX.md TASKS/README.md PITFALLS/README.md DEVICE/README.md RUNBOOK-BRINGUP/*.md`；`find reports -maxdepth 1 -name '*.md' -printf '%s\n' | awk`（539 files / 7,212,235 B）；`du -sb reports`（2,057,723,938）；`for d in */sessions; do ls $d|wc -l; done`（325/222/171/9/3/1）；`ls .pi/sessions | wc -l`（345）。
- 分节字节：`python3` 对 `L[i-1]` 累加 `len(x.encode())+1`（与 `wc -c` 口径一致，见 §1/§2 各行数字）。
- 跨文档重复：分句切分 + `difflib.SequenceMatcher`（≥2 连续子句）⇒ 0 命中；`grep -o 'reports/…\.md' | sort | uniq -c` 给出重复指针计数。
- 门禁依赖：`scripts/doctor/15-timeline.sh:48–53`（单 `★★` 检查 + 前 12 行取 `vkNN`）；`scripts/doctor/s07-08-docs.py:111`（800 B）。
- 先例：`DEVICE/sessions/2026-11-02-在机状态沿革-vk64..vk172.md`（header 自述 = `DEVICE/README.md:35–155` 121 行原文搬出，依据 `reports/doc-slim-20261102.md` §2.1）。
- 网络：本方案未发任何网络请求（无失败记录）；设备侧命令 **0 次**（平板不在线，按要求未尝试）。
