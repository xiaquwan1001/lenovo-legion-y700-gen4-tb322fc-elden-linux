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

## 4. 资产的现实约束

- 物理 POR 只能由用户执行；`fastboot boot` 零写盘，boot_b 全程不动。
- 旧镜像 `vk64`/`vk94` 是新编臂的字节可复现来源已核（unpack 后 kernel/dtb/ramdisk 均可寻址）。
- 下一步需用户配合开系列冷起（建议先各 2 发 A/B/C/D = 8 次 POR 看是否分离，再决定扩样）。

## 5. 关联

- `reports/q28-DOSSIER.md §h/§l/§p`、`PITFALLS #164/#166/#171/#172/#192`、`reports/q28-retro-audit-20261011.md`。
- Q24：仍以「Q28 GOOD 启动」为可测前提；若 STORM 实为旧镜像属性，日常 vk94 的 Q24 可测性随之改判。
