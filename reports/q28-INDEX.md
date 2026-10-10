# Q28 显示问题 — 文档地图（INDEX）

> 2026-10-10 整理。Q28 的过程稿散落多份，现收敛为**单一事实源（SSOT）= `q28-DOSSIER.md`**。
> 本地图列出全部 `q28-*` 文档、各自定位/日期，并逐个标注**是否已并入 DOSSIER**。
> 原则：**读现状/结论 → 只读 DOSSIER**；旧报告只作过程留痕与证据附件。

## 1. SSOT

| 文件 | 定位 | 日期 | 状态 |
|---|---|---|---|
| **`q28-DOSSIER.md`** | **唯一事实源**：现状 / 已定案 6 条 / 证据索引 / 两模式对比 / 候选修法 / 未决+下一步 / 不一致清单 | 2026-10-10 | **权威（SSOT）** |
| `q28-INDEX.md` | 本文件：文档地图 | 2026-10-10 | 索引 |

## 2. 过程稿 / 证据附件（均已并入 DOSSIER，仅保留溯源）

| 文件 | 定位 | 日期 | 是否已并入 DOSSIER |
|---|---|---|---|
| `q28-handoff-20261010.md` | 现场快照 / 断点续接（顶部三横幅为整理前最新状态；含恢复点、设备状态、Method B 复核、工具 quirk） | 2026-10-10 | **已并入**：结论→DOSSIER b/B1–B6、B5；恢复点/设备态→DOSSIER e/f；「下次先定」→f-1。顶部横幅口径与 `#163/#164/#165` 一致，正文其余为过程留痕。 |
| `q28-two-layers-20261010.md` | 「背光无画面」两层（L1 DSI cmd-DMA / L2 DPU CTL）分析 + 根因差分铁证 + 源码核实 | 2026-10-10 | **已并入**：L1=根因、L2=下游→B2；源码事实（nt36536.c:530、背光时序）→C6；差分→C5。**注意**：其正文"结论先行/建议下一步"主张 L2 为主因，已被顶部「★根因确认」+`#164`推翻（见 DOSSIER g-6）。 |
| `q28-upstream-diff-20261010.md` | 上游精确 diff + 移植裁决（一手原文 + 逐条对树核实，**取代 handoff §3 的 cherry-pick 方案**） | 2026-10-10 | **已并入**：上游正解/PR #1867/NOT-IN-TREE→B6+C15；Method B 正确落点→e/B5；"取整未必消 Q28"→f-4。**当前上游权威口径**。 |
| `q28-orchestration-20261010.md` | 编排轮整合（Lane A 编译 / B 取证 / C 联网 + 暖起 A/B + 死内核事故修复） | 2026-10-10 | **已并入**：取证数字/根因候选→C7–C9；vk84 单变量对→C13；死内核事故→C16（`#162`）。**注意**：其 §0/§4 冷暖方向写反（见 DOSSIER g-1），以 `#163`/B1 为准。 |
| `q28-upstream-research-20261010.md` | 早期联网调研（PLL re-lock 假说、命中清单、方案 A/B/C） | 2026-10-10 | **已并入（并被收窄）**：机制假说→B6；方案 A→e（Method A 变体）。其"机制完全吻合 / 直接 cherry-pick"结论已被 `q28-upstream-diff` 推翻（见 DOSSIER g-4）。 |
| `q28-delay-build-20261010.md` | Lane A 编译占位/残句（148 B，仅一句"先在不污染 `linux/.config` 的前提下试编"，**非完整报告**） | 2026-10-10 | **无实质内容可并入**；delay 镜像的权威口径取 `q28-orchestration` §3 + C13。此文件视为过程残句。 |
| `q28-binary-determinism-20261010.md` | 阶段稿：「按内核二进制确定性」（后被证伪） | 2026-10-10 | **已并入并降级**：顶部横幅 + DOSSIER §k/§l + `#171`。 |
| `q28-binary-determinism-provenance-20261010.md` | 溯源审计：21 发台账只有 7 发原始日志；5 MB 差是 `.rodata` 平移 | 2026-10-10 | **已并入**：DOSSIER §k 横幅/§l、`#171/#172`。 |
| `q28-layout-ab-20261010.md` | 构建控制对 + 设备 A/B（同镜像非确定；GOOD→HANG；存活门） | 2026-10-10 | **已并入**：DOSSIER §l、`#172`。 |

## 3. DOSSIER 引用的证据附件 / 工具（非 `q28-*` 报告，但属 Q28 证据链）

- 判据脚本：`scripts/q28-devprobe.sh`（三态 NOCARD/STORM/GOOD）、`scripts/q28-verdict.sh`（六类风暴签名）、`scripts/q28-ab-delay.sh`（暖起 A/B）、`scripts/q28-boot-cycle.sh`。
- 补丁（未上机）：`patches/q28-cmd-dma-delay.patch`（vk84 delay）、`patches/q28-methodB-round-byteclk.patch` + `patches/q28-methodB-NOTES.md`（Method B 草稿）。
- 镜像（单变量 A/B 对）：`out/boot-elden-vk84-q28delay-{base,exp}.img`(+`.manifest`)。
- 关键日志：`logs/q28-BAD-vk75dump-20261009-222932/`（L1 寄存器+dmesg）、`logs/q28-BAD-live-20261009-221729/serial.log`、`logs/q28-forensics-20261010-125030/`（GOOD 现场 clk/drm/PLL lockfail）、`logs/q28-control-coldboot-181758/control.txt`（GOOD 冷起 pllfail=8 基线）、`logs/q28-ab-20261010-130712.log`（暖起 8/8）。
- 定案条目：`PITFALLS.md #162`（死内核事故）、`#163`（冷/暖非时间）、`#164`（L1 根因/L2 下游）、`#165`（NOCARD+STORM 两模式）。

## 4. 阅读顺序建议

1. `q28-DOSSIER.md`（全部结论 + 证据指针）
2. 需一手细节：坏发现场 → `logs/q28-BAD-vk75dump-*`；上游细节 → `q28-upstream-diff`；GOOD 基线 → `logs/q28-forensics-*` / `logs/q28-control-coldboot-*`
3. 需断点/设备态：`q28-handoff` 顶部横幅

> 修订 2026-10-10：本 INDEX + `q28-DOSSIER.md` 为新建文件；未改动/删除任何已有 `q28-*` 报告。
