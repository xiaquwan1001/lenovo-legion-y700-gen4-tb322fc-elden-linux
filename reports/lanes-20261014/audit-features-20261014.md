# 已完成子功能 ↔ 会话档案 ↔ git 历史 对账

> 审计日期 2026-10-14 · 只读审计，未改仓库文件 · HEAD `c806a81`
> 口径：一处 = 一个文件/节（会话档案 / 各 README / PITFALLS / TASKS）。
> 提交 hash 默认指**本仓库**（docs+scripts）提交；标「内核」者为文档引用的内核树提交。

## 1. 已完成子功能总表

| 子系统 | 结论一句话 | 会话档案文件 | 关键提交 short hash | 目前描述所在处(≥1) | 分散 |
|---|---|---|---|---|---|
| 引导链/持久根 | b 槽 mainline 直启 + GPT 缩容手术（linux17=193 GiB）+ 自签 AVB 直启 Linux，已跑通 | `2026-09-29-持久根-b槽直启+gpt手术+睡眠.md`、`2026-10-03-持久根-u2上机与gpt手术.md` | `cbe9525` `4383f79` `19674fc` `2419885` | TASKS §1 G1-1/2/3（:45-47）、DEVICE §2.2/2.5、PITFALLS §一/§三、RUNBOOK | ✅ |
| 刷机控制（G1-24） | PSCI SYSTEM_RESET2 vendor reset 落地，`reboot bootloader` 真进 fastboot；logind 关机假成功修复 | `2026-10-03-刷机控制+桌面-psci-reboot与elogind.md` | `94d6d7f` `c1c9744` `47c14aa` | TASKS G1-24（:56）、SESSIONS §3（:139）、PITFALLS #88 | ✅ |
| 显示 Q28（未解） | 面板首条 DCS `ff 20` 走 bonded 命令 DMA 引擎 hang，~50% 冷起坏发；七臂否证，未根因 | `2026-10-09-q28-密集取证-...`、`2026-10-10-q28-定案-...`、`2026-10-12-q28-七臂否证.md` 等 | `b4616d5` `f80709d` `306a787` `e6f02f3` | TASKS §0(:15)+§5 Q28(:168)、INDEX §3(:91)、DEVICE(:29/31)、PITFALLS §19/22/23/25/26/32/33 | ✅ |
| 显示 Q31（M1-7.3 回归） | 上游 revert `44784327815b` ⇒ `PLL_SYSTEM_MUXES=0xc0` 永不写；E1b 补 1 行点亮面板 | `2026-10-14-m1-显示回归定位与根因分析.md`、`2026-10-14-m1-73-baseline-onboard.md` | `f863612` `54dc4dd8fe`(内核) | TASKS §5 Q31(:170)+§7(:461)、INDEX(:94)、SESSIONS(:261)、PITFALLS §33 | ✅ |
| WiFi ath12k（Q26 关） | 0001 ath12k MHI 超时 90s→3s + ATH12K=m，WiFi 打通，2026-10-10 用户确认关联即可用 | `2026-09-30-wifi-bt-驱动支持与充电旁路.md` | `4b8874f` `f42eca2` `6ed9666` | DEVICE §1.2(:43)、PITFALLS §九、SESSIONS §2(:49)、TASKS §5 Q26 | ✅ |
| 音频 tplg（G1-4） | tplg MI2S SD0→SD1 修复（功放接 i2s1_data1）⇒ 出声；WCD939x 采集 bring-up ⇒ 录音 | `2026-10-03-复盘-logind-关机-+-音频-温控重落与出声.md`、`2026-10-04-会话-音频收尾.md` | `31cde62` `cddb1ca` `3fd112c` `11f06ac` | TASKS G1-4(:49)、DEVICE §1.2(:41)、SESSIONS §2(:58/60) | ✅ |
| 触觉 aw86927 | AW86937 固件超 4KB 被写死窗口拒 → 按型号区分 SRAM 窗口，震动成功（vk19 干净基线） | `2026-09-30-触觉-aw86937-马达-sram-修复.md` | `3e84df3` `707c53e` `77daaf7` | DEVICE §1.2(:47)、SESSIONS(:50/99)、PITFALLS §四 | ✅ |
| Waydroid 马达透传（C10） | 容器 vibrator HAL→`aw86927` FF 桥 + 自编 AIDL V2 + 固化 vendor.img + 强度档位 RRO | **无 SESSIONS 档案**（仅 PITFALLS §29/30） | `536f77b` `a048d64` `2df5ca0` | TASKS C10(:84,+:308)、INDEX(:95)、DEVICE(:34)、PITFALLS §29/§30 | ✅（会话档案缺） |
| 传感器/自动旋转（G1-34） | SSC/QRTR svc400 + iio-sensor-proxy 出 accel/prox/als/compass；开机时序竞态修并持久化 | `2026-10-09-g1-34-重力与自动旋转.md` | `5d01d3324`(内核) `44f464e` `1ec6143` | TASKS G1-34(:48)、DEVICE(:29/48/59)、PITFALLS §16 | ✅ |
| 相机（G1-5 / Q24） | dma-buf 补齐 + libcamera 软件 ISP + Snapshot 全通、180° 修正；熄屏×相机互斥（未根治） | `2026-10-04-会话-相机出流-+-kexec-定论-+-g1-22-初判.md`、`2026-10-07-相机-g1-5-完整收口.md`、`2026-10-09-相机-模块驱动收尾-...` | `99d49aa` `684196a` `c377ac2` `d8ba26d` `933b78d` | TASKS G1-5(:50)/Q24、DEVICE §1.1(:29)、PITFALLS §20/21 | ✅ |
| 温控分级 | 0010 thermal graded trips：CPU 四级 trip 落地（G1-12…21 之一） | `2026-10-02-温控-过热限频与并发限流.md` | `ee9ebfe` `5fcdc6f` | DEVICE §1.3(:58)、TASKS §0(:14)、SESSIONS §2 | ◐ |
| GPU（G1-8 基准） | Adreno 830 freedreno/Turnip 工作；vkmark ~25532、es2gears ~164 FPS、温控峰 81.9 °C | （无专门会话档案；散在 10-11 会话） | `fe2fb6c` `214e06b` `1f02fee`? | TASKS G1-8(:60)、DEVICE §1.3、INDEX(:96) | ◐ |
| Waydroid 风控（C2/C3） | GMS 登录成功（人工验证）；Widevine 不存在（仅 ClearKey）⇒ L3 不可用；PI 前置不满足 | `2026-10-11-容器音频与-emulated-storage.md`（C2）；C3 仅报告 | `e6f02f3` `1a97ce5` `0600ba4` | TASKS C2(:76)/C3(:77)、README §6、reports/`c3-identity-drm-20261013.md` | ✅ |
| 上游化 M1-7.3 | 7.3-rc7 重基树 + WCN 停滞修 + 显示 1 行修；基线分支 `m1-73/baseline` tip `c7da05b1d8` | `2026-10-13-m1-7.3-重基树上机-bringup.md`、`2026-10-14-m1-73-baseline-consolidation.md` | `2ce4dec` `d1c096b` `8867012` `f863612` `c806a81` | TASKS §7(:400-462)、INDEX(:94/96)、PITFALLS §31-33 | ✅ |
| DP（G1-9）/CDSP（G1-11）/BT（G1-7） | DP `dr_mode=otg`+role-switch+`mdss_dp0` 同批打通；CDSP split 固件起 `remoteproc1`；BT 配对+TWS 实听 | `2026-10-05-会话-硬件驱动覆盖.md`、`2026-10-07-收盘-g1-9-dp-打通-+-q21-q24-根因.md` | `6c1376907`(内核) `c132a1bc7`(内核) `6f38865` | TASKS G1-9(:61)/G1-11(:63)/G1-7(:59)、DEVICE §1.2(:42)、PITFALLS #127/#128 | ✅ |

## 2. 分散描述清单（同一完成功能被详细描述 ≥2 处）

| 功能 | 处 1 | 处 2 | 处 3 | 建议保留处 |
|---|---|---|---|---|
| Waydroid 马达透传 C10 | TASKS/README.md:84 | DEVICE/README.md:34 | PITFALLS/README.md:55（§29）+ §30 | **TASKS:84**（状态 SSOT）+ PITFALLS §29/30（踩坑），DEVICE:34 降为指针 |
| Q28 显示间歇 | TASKS/README.md:15 与 :168（同一文件两处，正文重复历史链） | INDEX.md:91 | DEVICE/README.md:29/31 | **TASKS §5 Q28:168**；TASKS:15 与 INDEX/DEVICE 只留指针 |
| Q24 熄屏×相机 | TASKS/README.md:34（G1-22）与 §5 Q24 | DEVICE/README.md:29/78/81 | PITFALLS #197–#212 | **TASKS §5 Q24**；G1-22/G1-33 与 DEVICE 去重 |
| WiFi ath12k（Q26） | DEVICE/README.md:43 | PITFALLS §九 | SESSIONS §2:49 | **DEVICE §1.2:43**（固件/通路）+ TASKS Q26 结论，PITFALLS 保留排查 |
| 音频 tplg（G1-4） | TASKS/README.md:49 | DEVICE/README.md:41 | SESSIONS §2:58/60 | **TASKS G1-4:49** |
| 传感器/自动旋转 | TASKS/README.md:48 | DEVICE/README.md:29/48/59 | PITFALLS §16 | **TASKS G1-34:48** + 技能 `y700-adsp-ssc-sensors-bringup` |
| 相机 G1-5 | TASKS/README.md:50 | SESSIONS §3:158/198 | PITFALLS §20/21 | **TASKS G1-5:50** |
| 上游化 M1 | TASKS §7（多行 400-462） | INDEX:94/96 | PITFALLS §31-33 | **TASKS §7** |
| 引导链/持久根 | TASKS G1-1/2/3:45-47 | DEVICE §2.2/2.5 | PITFALLS §一/§三 | **TASKS §1 + DEVICE §2.5** |

> 说明：TASKS:15（G1 阻塞项速览）与 TASKS §5 正文同文件重复 Q28/Q24 的长历史链，是最大的一处冗余。

## 3. git 历史缺口

**【A】完成功能在会话视角缺失**
1. **Waydroid 马达透传 C10（2026-10-13）**：PITFALLS §29/§30 有完整专题档，提交 `536f77b/a048d64/2df5ca0` 齐，但 `SESSIONS/README.md` §3 **无对应会话行**，`SESSIONS/sessions/` **无档案文件**（`ls SESSIONS/sessions | grep -iE '马达|waydroid|haptic'` 无 10-13 条）。→ 补一行 + 一档案。

**【B】重要提交无会话/文档提及（grep 全仓 .md 无命中，除提交本身）**
2. `f4e8588` `feat: 知识库化整理（LESSONS 统一入口 + SQLite 索引）`（2026-10-03）——`知识库化` 全仓无命中；该产物后来被移除（INDEX 明示「不再有 SQLite/生成物」），属**已成死路的 feat 且当前文档零记录**。
3. `b04fc91` `fix(process): 迭代链闸门——打包前内核身份硬门 + trial 记录器 + 槽位门接入`（2026-10-10）——`迭代链闸门` 无命中，无会话档案行记录该基建提交。
4. `86ddd60` `fix(ab): qbootctl 未在 runlevel -> 启动次数耗尽卡 fastboot（PITFALLS #181）`（2026-10-11）——提交自称 #181，但 grep `qbootctl 未在 runlevel` 在 PITFALLS 无命中（#181 正文措辞不同）；**文档号与提交号未互链**。
5. 过程类 fix `5cd7a70`/`8c75369`（软件 POR、复位深度）仅出现于 reports 与 `.pi/plans`，未进任何 SESSIONS 档案行。

**【C】SESSIONS 快照表内的结构性缺口**
6. **重复短 id `01a12d5a`**：`SESSIONS/README.md` 出现 2 次（:238 q28-storm-现象整理 / :239 q28-构建身份伪影定案），应为两会话却共用 id → sfx 缺失。
7. `01a11650`（状态 junk）自陈「遗留未提交：`scripts/bench-run.sh`、`scripts/thermal-stress.sh`」；两脚本后续由 G1-8 线补交，但**该 junk 行未标已闭环**。

## 4. junk / superseded 会话行（归档候选）

**junk 12 行**（§1 统计 junk 12，逐行核对一致）：

| 短 id | 日期 | 标题 | 理由 |
|---|---|---|---|
| 01a1071b | 2026-10-04 | 会话（空「可以继续了」） | 0 助手产出 |
| 01a10744 | 2026-10-04 | dt-ui 重派（空） | 仅派发词 |
| 01a1074a | 2026-10-04 | dt-ui 重派（空） | 仅派发词 |
| 01a10759 | 2026-10-04 | 编排（预算墙中断） | 结论被 01a1072e 取代 |
| 01a109e7 | 2026-10-05 | memory_search 冒烟 | 冒烟 |
| 01a109e8 | 2026-10-05 | 冒烟（只回 OK） | 空测试 |
| 01a109e8 | 2026-10-05 | memory_search 冒烟 2 | 冒烟 |
| 01a109ec | 2026-10-05 | standing-instructions 条数冒烟 | 冒烟 |
| 01a109ec | 2026-10-05 | 冒烟（只回 OK） | 空测试 |
| 01a109ed | 2026-10-05 | 冒烟（只回 OK） | 空测试 |
| 01a11650 | 2026-10-07 | 测试接续（中断，无产出） | 无终报无提交（已由 G1-8 闭环，可删） |
| 01a12d9c | 2026-10-12 | 空会话（冒烟，仅「你好」） | 空 |

**superseded 5 行**：

| 短 id | 日期 | 标题 | 理由 |
|---|---|---|---|
| 01a0ed5b | 2026-09-29 | 分区：安卓GPT缩容与游戏备份 | 65G 缩容方案被持久化取代 |
| 01a100d9 | 2026-10-03 | 解锁:sn.img解密blob取证 | blob 路径未采用，解锁走降级 1.1 |
| 01a101f3 | 2026-10-03 | 引导：Linux→fastboot 能力核实 | 「能力不存在」被 PSCI vendor reset 推翻 |
| 01a10504 | 2026-10-04 | 会话：pi 启动入口差异说明 | 旧 cd 包装已移除 |
| 01a1167d | 2026-10-07 | 稳定基线 vk62 收尾 | vk62 经 #131 判 tree_drift |

> 建议：§4 表本身保留作审计痕迹；只对 `SESSIONS/sessions/*.md` 中对应档案做「已归档」横幅，不删正文（与现状「待批」一致）。junk 冒烟类（01a109e7/01a109e8×2/01a109ec×2/01a109ed/01a12d9c）价值最低，可优先清。

---
**核对方法**：`git log --format='%h|%ad|%s' --date=short`；`grep -n` 于 `SESSIONS/README.md`/`TASKS/README.md`/`DEVICE/README.md`/`PITFALLS/README.md`/`INDEX.md`；`ls SESSIONS/sessions/`、`ls PITFALLS/sessions/`。
