# Q28 追溯审计（2026-10-11）：以 PITFALLS #192 / DOSSIER §o 为基准重审旧现象报告

> 只读审计（`evidence-auditor` 子代理，2026-10-11；父代落盘）。
> 基准（权威）：`PITFALLS #192`、`reports/q28-DOSSIER.md` §o + §o-附、
> `reports/trials/index.tsv` 的 `*q28cold*` 行（12 发物理 POR 冷起 + vk102-c1pin 钉 UTS 验证）。
> 新事实三则：① 冷起 GOOD/NOCARD 由 UTS 版本串内容决定（逐字 `7.2.0-debug-vk64-gd02658e63cf6`⇒GOOD 5/5，其它⇒NOCARD 7/7）；
> ② 钉死 UTS（PINUTS）后改内核/config 仍 GOOD ⇒ 冷起 A/B 恢复可用；
> ③ STORM 独立随机，#192 法则只解释 NOCARD 分支。

## 主表

| 旧结论（出处/日期） | 现判 | 混淆点 | 需要的重测（PINUTS 可用） |
|---|---|---|---|
| §k「Q28=按内核二进制确定性，冷/暖不是判别变量」（DOSSIER §k、PITFALLS #171，2026-10-10） | **作废**（已被溯源审计降级，本审计确认） | ① 21 发仅 7 发有原始日志；② 「8% 二进制差」= UTS 长差→`.rodata` 平移 4 字节的假象；③ 同 vk64.img 冷路径 3/3 STORM 反证「非冷/暖」不成立 | 无需重测（判据链完整）；结论以 §l/§o 为准 |
| §l「同镜像同路径非确定」（5 发 GOOD/STORM/STORM/GOOD/STORM；PITFALLS #172，2026-10-10） | **事实仍成立；归因需补** | 与 #192 不冲突：该路径是 reboot2 暖路径 + 旧 Oct-8 镜像；「非确定」部分是暖复位粘态（#166），部分是 STORM 随机 | 若引用该组数据须按"暖路径/旧镜像"标注，不可作冷起结论 |
| §m「NOCARD 由版本串（LOCALVERSION）长度决定」（PITFALLS #175，2026-10-11） | **仍有效（方向正确），但收窄** | #192 证明「内容」也足够（不只长度）；GOOD 侧当时 n=1，现已扩到 5/5 | 无需；§m 的 vk93-lv64 GOOD 1/1 已被 §o base/base2 GOOD 5/5 覆盖 |
| DOSSIER B1/§a「冷起基本失败、暖起基本成功；用户 ~60%」（PITFALLS #163，2026-10-10 前） | **被构建身份混淆** | vk63 时代跨复位类型+跨构建身份混采；「~60%」无法区分 NOCARD（UTS 命中）与 STORM（随机） | PINUTS 钉 UTS 后重测冷/暖各自的 STORM 率（冷起已可用；暖路径 STORM 率仍无受控数据） |
| vk90/vk92 的 NOCARD 判定（FIX-2/E4a 三臂 A/B，PITFALLS #175 尾、DOSSIER §m，2026-10-11） | **作废**（已作废，本审计确认） | 非 `-vk64` UTS ⇒ #192 法则必落 NOCARD；NOCARD 是构建伪影，不证伪臂逻辑 | 用 PINUTS（vk102-c1pin 已示范）钉死 UTS 后重测 FIX-2/E4a 臂 |
| round / Method-B 的 NOCARD =「修复无效」证据（DOSSIER §o 第 3 条、vk96 round NOCARD 3/3） | **作废；但已被 §o-附 部分解禁** | 默认构建改代码即改 UTS（observer effect）；空提交/一行 pr_info 也翻 ⇒ 非 patch 逻辑 | §o 第 3 条「冷起 A/B 作废」仅对默认构建成立；**PINUTS 钉死后可用**——vk96 round 需以 PINUTS 重建重测 |
| T1/T2/T3 冷 A/B NOCARD 样本（DOSSIER §B5/§f，2026-10-10） | **作废**（DOSSIER §i 已作废，本审计确认） | 带 vk73–85 诊断链（`ca81318f2`）+ 部分 reboot2 暖复位粘态 | 无需原样重测；若复测 delay 修法须干净 base + PINUTS |
| trials/index.tsv warm-path 结论「vk64 GOOD×7 vs 全部新编 NOCARD×14」（#171 台账，2026-10-10） | **事实（该路径成立）；归因作废** | 同 §k；且 14/21 发无原始日志、镜像已删 | 无需重测；引用时标注"无日志的 14 发不可作证据" |
| layout-* 组（`reports/q28-layout-ab-20261010.md`：8B 二进制差、布局漂移机制） | **机制描述仍有效（4B 平移实锤）；触发点已收窄** | 只测到「长度」维度；#192 证明「内容」同样足够 | 可选：PINUTS 下扫等长不同内容版本串，定位是长度还是哈希内容 |
| §h「用户真实日常失败 = STORM；delay/round 靶没错」（DOSSIER §h，2026-10-10） | **仍有效** | 未被 #192 混淆：#192 只解释 NOCARD 分支，STORM 独立随机（§j/#192 补充实测 2/2 POR=STORM） | 无需；STORM 率的统计样本仍偏小 |
| §B3「NOCARD/STORM 两模式、共同根=DSI PLL/PHY 冷起锁不稳」 | **NOCARD 归因待重测** | NOCARD 各样本（T1/T2/T3、vk86、vk89/93/96–101）全部落在非基准 UTS 上 ⇒ "PLL lock failed → 无 card0" 的因果链可能只是构建伪影的固有签名 | 在 PINUTS 钉死的 GOOD/NOCARD 对照下重验 NOCARD dmesg 是否仍现 `DSI PLL(0) lock failed` |
| §B6/§g 上游 `2028280686f4` 裁决（逐字 cherry-pick 无效、未必同根因） | **仍有效** | 不依赖冷起 A/B 样本，基于对树静态核验 | 无需 |
| §B4 三态判据 + 存活门（devprobe + 65 s 存活，PITFALLS #172） | **仍有效** | 与 #192 正交（判定基建） | 无需 |
| DOSSIER §n「Q28 决定 Q24 能否被测」 | **仍有效且被 #192 更新** | Q28-bad 现可由构建身份制造/消除；Q24 每次有效测试仍以 GOOD boot 为前置，且该 GOOD 现可**确定性**获得（PINUTS） | 无需 |

## 未审清单
- `archive/topics/SLEEPDEATH-*.md`、`archive/topics/BOOTCHAIN/UEFI`：grep 未发现引用 Q28/NOCARD 结论（`card0` 命中均为 DP/音频/通用记录），无需改判。
- `reports/q28-handoff-20261010.md`、`q28-orchestration-20261010.md` 正文细节：属过程稿，DOSSIER 已标注其 §g-1 反向表述问题，未逐行复审。

## 审计说明
- 「事实仍成立」与「归因被污染」已分列；#192 的 STORM 范围限定（§o/`wd-net-baseline-20261011.md` §4）使大部分 STORM 类结论免疫于本审计。
- §o 第 3 条「冷起 A/B 作废」被 §o-附（vk102-c1pin）部分推翻——PINUTS 后恢复可用；引用 §o 时必须带上 §o-附。
