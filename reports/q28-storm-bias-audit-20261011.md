# Q28 — STORM 是否也是认知偏差误判：证据审计 + 2×2 判定实验（2026-10-11）

> 触发：NOCARD 已被判为构建身份伪影后，用户提出「继续排查 STORM 是否也是认知偏差导致的误判」。
> 本文 = 只读证据审计 + 为判定实验构建的对照臂。权威口径暂以 `reports/q28-DOSSIER.md §p` 为基线，本文结论待上机后回填。

## 0. 数字结论

1. **已落盘 STORM 样本 = 真失败，不是指标误判**：全部 10 个 STORM 样本的 L1（`command DMA timeout` /
   `bonded command DMA failed` / `Failed to initialize panel` / `sending dcs data … failed`）≥ 6，
   即使把 L1/L2 拆开也照样判坏 ⇒ 探针没有「把良性噪声当 STORM」。
2. **但 STORM 证据与「构建/镜像」高度共线**：所有 STORM 样本都在**旧内核/旧 ramdisk**镜像上
   （`out/boot-elden-vk64.img` Oct-8、`boot-q28-oct8.img` 旧内核、`vk94`）；**16 发新 PINUTS 冷起（vk97/vk100/
   vk102–vk105）L1=0 且 L2=0**，无一例 STORM。
3. ⇒「STORM = 独立随机，与构建身份无关」这一 §p 结论，**其证据基础只有 1 个无原始日志的样本**
   （`wd-net-baseline §4`，日常 boot_b vk94 一次 `storm=45`）。而**同一天同镜像又被记为一次 GOOD**
   （`DOSSIER §o`，`storm=0`）。两条都 n=1、都无落盘 dmesg ⇒ **STORM 的随机性尚未被受控证据坐实**，
   用户的「可能也是误判」假设成立且优先。

## 1. STORM 样本清单（逐条溯源）

| 样本 | 镜像 / 内核 | 复位路径 | L1 | L2 | 有原始 dmesg？ |
|---|---|---|---|---|---|
| C1real-vk64 | `vk64` Oct-8 / `8efb2731` | 真实 POR 盘启 | 7 | 23* | 仅 devprobe（无全 dmesg） |
| C2-vk64 | `vk64` Oct-8 | 冷 fastboot | — | 16* | 仅 devprobe+state |
| coldfb-vk64 | `vk64` Oct-8 | 冷 fastboot | 7 | 45 | ✅ |
| realpor-run1/2 | `vk64` Oct-8 | 真实 POR | 7 | 319/26 | ✅ |
| softpor-baseline/recover | `vk64` Oct-8 | 暖 | 7 | 44 | ✅ |
| layout-oct8 ×3 | 旧内核 + 当日 ramdisk | 暖 reboot2 | 6–7 | 24–27 | ✅ |
| **§4 日常 boot_b** | `vk94`（=vk64 内核 + ADSP DT） | 纯净冷起 | ? | `storm=45` | ❌ **仅文字转述** |
| §o 日常 boot_b | `vk94` | 纯净冷起 | ? | `storm=0` | 部分 |

\* C1real/C2 的 `storm_sig` 是 v1 混合计数；L1/L2 用保存的 devprobe 明细手工拆。

**对照（全部新编 PINUTS 冷起，`q28-cold-*`）**：16/16 `storm=0`；其中 GOOD（card0+connected+session）
= base1/2/3、base2-1/2、c1pin1、vk103、round-pin1、base-pin1；NOCARD = round1/2/3、sham1、sham2-1/2、empty1。

## 2. 判据加固：`scripts/q28-devprobe2.sh`（L1/L2 拆分）

旧 `q28-devprobe.sh` 把 L1（DSI/panel 真失败）与 L2（DPU 下游：ctl reset / frame done / vblank）合成
`storm_sig`，理论上存在「L1=0 但 L2>0 的健康启动被误判 STORM」的风险（`#164` 判 L2 是 L1 下游）。
新探针拆开并加 session 门：
- `NOCARD`（无 card0）/ `L1FAIL`（真 Q28）/ `L2STORM`（仅下游）/ `GOOD`（L1=0 + connected + session）/ `GOOD-NOSESSION`。
- 离线回放全部已保存 dmesg：**无任何 L1=0 且 L2>0 的样本** ⇒ 旧指标未实际误判，v2 作方法学加固。
- `q28-cold-run.sh` 已改为优先调用 v2，并把 `l1=/l2=` 落盘。

## 3. 判定实验：内核构建 × ramdisk 2×2 因子（已构建，未上机）

目的：把「STORM 随镜像」与「STORM 随机」分开。旧 STORM 样本在**旧内核 + 旧 ramdisk**；新 GOOD 在
**新内核 + 新 ramdisk** —— 两者共变，必须拆成 2×2。

| 臂 | 内核 | ramdisk | 说明 |
|---|---|---|---|
| A = `vk104-base-pin` | 新（clean/base + PINUTS，`553c315c`） | 新模块化（`28c02622`） | 既有，GOOD 1/1 |
| B = `vk106-newK-oldR` | 新 `vk104` 内核 | **旧** `vk94` ramdisk（`35823240`） | **本轮构建** |
| C = `vk94`（日常 boot_b） | 旧 `vk94` 内核（`71b7ac9b`） | 旧 `35823240` | 既有，STORM 疑似台 |
| D = `vk107-oldK-newR` | 旧 `vk94` 内核 | 新模块化（`28c02622`） | **本轮构建** |

- B/D 为**纯 repack（零重编译）**，内核与 DTB 各自随臂，唯一变量 = ramdisk 内容（旧 `/init` vs 模块化 `/init`
  + payload 模块层）。
- 产物：`out/boot-elden-vk106-newK-oldR.img`（`0e4eae91…`）、`out/boot-elden-vk107-oldK-newR.img`（`213427bc…`），
  各带 manifest。`tools/mkbootimg/unpack_bootimg.py` 解包，`mkbootimg.py` 重打（header v2，参数同 `build-boot.sh`）。

**判定（冷起系列，每臂 N 次，交替，每次真实 POR）**：
- A/B/C/D **各自内部一致**（如 C 恒 STORM、A 恒 GOOD）⇒ STORM 是**镜像确定性属性**（偏向构建/ramdisk），
  §p「独立随机」是误判，收窄为「旧镜像构件伪影」，与 NOCARD 同类。
- A/B/C/D **内部混合** ⇒ STORM 确为逐启动随机，与镜像无关。
- 单看 A vs B：若 B STORM 而 A GOOD ⇒ **ramdisk/`/init` 是触发轴**；B vs D 反之则内核轴。

成本：每样本 1 次人工 POR 进 fastboot；判定用 v2 探针（L1/L2 + session + 65 s 存活门）。

## 6. ★上机结果（2026-10-11 深夜 / 10-12 早，8 发物理 POR 冷起）

| 样本 | 臂 | 内核 | ramdisk | 结果 |
|---|---|---|---|---|
| A1 / A2 | `vk104-base-pin` | 新 | 新 | **GOOD / GOOD** |
| B1 / B2 | `vk106-newK-oldR` | 新 | 旧 | **GOOD / GOOD** |
| C1 / C2 | `vk94` | 旧 | 旧 | **L1FAIL / GOOD** |
| D1 / D2 | `vk107-oldK-newR` | 旧 | 新 | **L1FAIL / GOOD** |

**观察**：
1. **STORM 被复现**（C1/D1）：签名与历史完全一致——`command DMA timeout: status=0x2200200` → `bonded command DMA failed: master=-110 peer=-110` → `sending dcs data ff 20 failed: -110` → `Failed to initialize panel: -5`（t≈9 s），`session=0`。
2. **不是严格镜像确定**：C1=L1FAIL 而 C2=GOOD（同镜像同路径反向）。
3. **也不是「与镜像无关的独立随机」**：8 发里 2 次坏发**全部落在旧内核**（C/D，2/4），新内核 0/4；但**两次坏发又都在 Round 1 且连续**（C1、D1），Round 2 全 GOOD ⇒ 无法区分「旧内核高坏发率」与「首轮/时序状态效应」。
4. **ramdisk 与结果无关**（B 用旧 ramdisk 恒 GOOD；D 用新 ramdisk 与 C 同模式）。

**统计诚实**：n 太小。2/8 总坏发率、旧内核 2/4 vs 新内核 0/4、Fisher 精确 p≈0.43，**不显著**。

**下一步（建议）**：同一时间窗内**交替**打 C/A（如 C3,A3,C4,A4…）以解耦「内核」与「轮次/时序」，目标每臂累计 ≥6 发。

## 7. 现象整理与原因分析（2026-10-12）

### 7.1 现场事实

1. **STORM 被冷路径复现**：C1/D1 与历史逐字同签名，坏发发生在 `msm_dsi … timing …` 之后 **~0.22 s**：
   `command DMA timeout: status=0x2200200` → `bonded command DMA failed: master=-110 peer=-110` → `sending dcs data ff 20 failed: -110` → `Failed to initialize panel: -5`（attempt1/2 都失败）。
   GOOD 启动在 **同一偏移**做的是 `panel prepared: scheduling firmware upload`（面板首条 DCS 成功）。
   DSI 时序参数与 `DSI_PLL_lockfail=4`/`device_link_fail=8` 在好坏启动**完全相同**（旧已定案为良性噪声）。
2. **ramdisk 与结果无关**：B（新内核+旧 ramdisk）恒 GOOD；D（旧内核+新 ramdisk）与 C 同模式。
3. **非严格镜像确定**：C1=L1FAIL vs C2=GOOD（同镜像同路径反向）。
4. **与内核构建身份强相关**：今日 2 次 L1FAIL 全在旧内核；**历史全部 ~10 次 STORM 也都落在 Oct-8 `#60` 构建**（`vk64`/`vk94`/`oct8`）；而**新构建（`vk97`–`vk107`，共 20+ 发）0 次 STORM**。

### 7.2 两内核到底差什么（已反查）

| 维度 | 旧K（vk94 = vk64 `8efb2731`） | 新K（vk104 `553c315c`） |
|---|---|---|
| 源码 | `d02658e63` | `5d01d3324` |
| 源码差 | — | **仅 1 个提交**：ADSP fastrpc 加 `qcom,non-secure-domain`（DT-only） |
| config（ikconfig 实提） | 11948 行 | 11948 行，**唯一差 = `CONFIG_LOCALVERSION_AUTO=y` vs `n`** |
| UTS localversion 后缀 | `-vk64-gd02658e63cf6` | 同上（逐字同） |
| UTS_VERSION（`#N … 日期`） | **`#60 SMP PREEMPT Thu Oct  8 17:06:14`** | **`#118 SMP PREEMPT Sun Oct 11 22:33:36`** |
| 内核 payload 差 | — | **5,108,388 B**（含从 36.9 M 起 ~5 MB 的 `.rodata` 串区，其首字串就是 `#118…` vs `#60…`） |
| DTB | 149,063 B | 149,051 B（ADSP 节点差，其余 phandle 平移） |

⇒ **两个内核代码几乎一样**；差别集中在：① UTS_VERSION 串长度（`#60` 2 位 vs `#118` 3 位）触发 `.rodata` 整段平移——**与 NOCARD 的 `#171/#175/#192` 同一机理**；② 一个 ADSP DT 节点。

### 7.3 可能原因（假设）

- **H1（首选）构建身份/布局刀刃**：STORM 是真实的首条 DCS 命令-DMA 冷起竞态；内核构建身份（UTS_VERSION 长度 → `.rodata` 布局）把竞态窗口移了位。旧的 `#60` 构建偏向坏侧（高坏发率），新构建偏好好侧。**能同时解释**：历史 STORM 全在 `#60`、新构建 20+ 发干净、以及 C2 偶发 GOOD（竞态本质随机，布局只是偏置）——与 NOCARD 的结论同构。
- **H2 DTB 轴**：那 1 个 ADSP DT 提交改了 DTB（phandle 平移/探测顺序）→ 可能微移冷起时序。未隔离。
- **H3 纯随机低率**：今 2/4 vs 0/4 不显著（Fisher p≈0.43）⇒ 不能单独成立；但**历史 `#60` 集群（~10 坏）对上新构建 0 坏**，若纯噪声该概率极低 ⇒ H3 只能作次要成分。
- **H4 时序/状态/轮次**：两次坏发都是 Round 1 且连续，Round 2 全 GOOD ⇒ 可能含会话/热/POR 深度效应。用交替采样（C/A 交替）可剔除。

### 7.4 为何「STORM 独立随机」是误判（与 NOCARD 同教训）

- 历史 STORM 样本**几乎全在同一构建身份（`#60`）**上采集，且**从未做同身份重复冷起**；这本身就是「改代码→改身份→改被观测结果」观察者效应的适用面缺失。
- §p 的两条“日常 boot_b”证据（§4 一次 STORM、§o 一次 GOOD）都在 `vk94`=`#60`，恰好落在 H1 的“旧构建高偏置 + 竞态随机”预期内，**不足以推出“与身份无关”**。

### 7.5 决定实验（可即建）

| 实验 | 做法 | 判读 |
|---|---|---|
| **E1 身份解除（首选）** | **现在重编旧K 源码 `d02658e63`**（自然 UTS，新 `#N`/日期）→ `vk108`；冷起系列 | 若 GOOD（新K 同率）⇒ 源码/驱动无罪，**身份布局是轴**（H1）；若仍 STORM ⇒ 源码/DT 是轴（H2） |
| E2 DTB 轴（repack） | 新K 内核 + 旧K DTB；旧K 内核 + 新K DTB | 翻转 DTB 是否翻转结果 |
| E3 采样 | C/A 交替冷起 | 剔除 H4/Round 效应 |

> E1 是本轮结论的分水岭：它把「`#60` 旧源码有 bug」与「`#60` 这个构建身份在竞态刀刃上」分开；也是可直接“构建”的下一步。

## 4. 资产的现实约束

- 物理 POR 只能由用户执行；`fastboot boot` 零写盘，boot_b 全程不动。
- 旧镜像 `vk64`/`vk94` 是新编臂的字节可复现来源已核（unpack 后 kernel/dtb/ramdisk 均可寻址）。
- 下一步需用户配合开系列冷起（建议先各 2 发 A/B/C/D = 8 次 POR 看是否分离，再决定扩样）。

## 5. 关联

- `reports/q28-DOSSIER.md §h/§l/§p`、`PITFALLS #164/#166/#171/#172/#192`、`reports/q28-retro-audit-20261011.md`。
- Q24：仍以「Q28 GOOD 启动」为可测前提；若 STORM 实为旧镜像属性，日常 vk94 的 Q24 可测性随之改判。
