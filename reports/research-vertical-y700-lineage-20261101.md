# 纵向同产品线调研：Lenovo Legion Y700 五代（TB-9707F → TB323FU）与 Legion Tab 命名 —— 2026-11-01

> **性质**：只读 + 联网调研。**未接触设备**（无 adb/fastboot/ssh/EDL）、未构建、未改任何现有文档；
> 本文件是唯一新增产物。
> **证据等级**：`已证` = 有 URL+日期 / 仓库文件 / 本项目已上机记录；`未证实` = 仅第三方社区说法、未见一手复现；
> `推测` = 由已证事实外推，明确标注。
> **术语**：Gen1..Gen5 按社区代际（Lenovo 官方用年份命名，二者不一致，见 §1）。

---

## §0 结论先行（一页）

| # | 结论 | 证据等级 | 依据 |
|---|---|---|---|
| 0.1 | **这是一条连续五代的 8.8 英寸同模具产品线**：Gen1 `TB-9707F`(SD870) → Gen2 `TB320FC`(8+ Gen1) → Gen3 `TB321FU`(8 Gen3) → Gen4 `TB322FC`(8 Elite) → Gen5 `TB323FU`(8 Elite Gen5)；代号依次 Pike/Asphalt/Kirby/Elden/Baldur | 已证（型号+SoC）/ 代号部分未证实 | GSMArena/联想发布稿/社区总览（§1 表） |
| 0.2 | **Linux 成熟度不是单调上升，而是「Gen3 最完整、Gen4 在追赶、Gen1 只有 UEFI、Gen2 几乎为零」**：Gen3 有非破坏性双启动（GUF296）+ 两个 Armada 移植；Gen4 有下游内核与主线 DT 在审；Gen2 只有 Android 侧（TWRP/LineageOS/GSI）；Gen1 无 Linux，但 Mu-Silicium UEFI 能启 Windows | 已证（各仓库/Status.md） | §2 |
| 0.3 | **主线板级支持只有 Gen4 一份，且尚未合并**：`sm8750-lenovo-elden.dts` + `qcom.yaml`，Pengyu Luo，`[PATCH v2 0/2]`，patchwork 状态 `changes-requested`（Abel 2026-07-27、Konrad 2026-09-02），torvalds master 无此文件 | 已证 | §5；patchwork API 2026-11-01；`raw.githubusercontent.com/torvalds/linux/master/...` = 404 |
| 0.4 | **Gen1/Gen2/Gen3 没有任何板级 Linux 上游提交**：patchwork `q=tb321fu`/`q=sm8650 Lenovo`/`q=Legion Tab` 均 0 命中；Gen3 的 DTS 只存在于下游树（GUF296 的 7.1.1 内核） | 已证 | §5 |
| 0.5 | **真正可跨代搬的是「流程与工具」，不是「boot 链」**：UFS 6-LUN 布局、GPT 手术、ABL A/B + slot-retry、AVB testkey 窗口、EDL `xbl_s_devprg_ns.melf`、TWRP/LTBox/GSI、96 MiB boot 分区 —— 这些 Gen3↔Gen4 高度一致 | 已证（本项目 Gen3 参考 + Gen4 实测） | §3.1 |
| 0.6 | **断代点有四个**：① SoC 平台层全换（SM8250→SM8475→SM8650→SM8750）；② Gen3 的 `vm-bootsys_a/b` Linux boot-FAT 在 **Gen4 被删除**，GUF296 方案不能照搬；③ Gen4 ABL 对「异类载荷」的 boot header 行为不同（v3 静默忽略、v0 必须 `--base 0x10000000`）；④ 面板/触屏供应商组合与音频/触觉 codec 换代 | 已证（②③ 本项目实测；①④ 规格/DT） | §3.2 |
| 0.7 | **「Legion Tab」不是独立产品线，而是 Y700 的海外名**：Gen2 全球版就叫 Legion Tab（TB320FC，日本 OEM 版 NEC LAVIE Tab T9 / T0995HAS）；Gen3 全球名 Legion Tab (8.8", 3)；**Gen4 没有全球版**（联想跳代，2026-03 直接发 Legion Tab Gen 5） | 已证 | §4（NotebookCheck 2026-03-01、note.com 总览、CES 2025 报道） |
| 0.8 | **Gen1 的 Mu-Silicium UEFI 是全系唯一「Windows Boot ✅」记录**（Display/Storage/Buttons/USB host ✅，Linux Boot ❌，State Inactive）；这不能直接搬到 Gen4（不同 SoC 包），但证明「平板 + UEFI + WoA」在该产品线成立过 | 已证 | Mu-Silicium `Status.md`（2026-11-01 拉取） |
| 0.9 | **对 elden 最值钱的三份外部资产**：Pengyu Luo 的 Gen4 主线 DT v2（1170 行，可直接当基线）、GUF296 的 Gen3 非破坏性双启动架构（流程参照，非代码）、以及 Gen3 的 `slot-retry`/fastbootd/EDL 操作手册（我们已内化） | 已证 | §2.3/§2.4/§5 |
| 0.10 | **不要照抄的**：Gen3 的 `boot_b=UEFI 固件 + vm-bootsys FAT`（Gen4 无该分区）、Gen2 的「旧 ABL 降级解锁」细节（Gen4 是 1.1.11.073 门槛且 ABL 内嵌新 key）、任何跨代的 testkey 截止版本号（每代不同） | 已证/未证实 | §3.2 |

**一句话**：**同产品线的价值在「少踩刷机/分区/AVB 的坑」，不在「复用驱动」**；Gen4 的 Linux 只能站在 SM8750 主线 SoC 支持 + Gen4 自己的 DT 上，Gen3 给的是方法论。

---

## §1 代际对照表

> 命名口径：Lenovo 官方按「年份」卖（Y700 2022/2023/2025…），社区按「代」叫（Gen1..Gen5），两者**错位一年**（Gen3 官方叫 Y700 2025）。本表用社区代际，另列官方名。

| 代 | 官方/市场名 | 型号 | 代号 | SoC | 发布 | 屏幕 | 全球名 | 证据 |
|---|---|---|---|---|---|---|---|---|
| **Gen1** | 拯救者 Y700（2022） | `TB-9707F`（曾计划全球版 `TB-9707N`，未发） | Pike（社区亦称 `sheng`，未证实） | Snapdragon 870 (SM8250-AC) | 2022-03-10 | 8.8" 2560×1600 LCD 120 Hz | 无（PRC 独占） | GSMArena 11394；note.com 总览；LinuxDroidMaster 仓 |
| **Gen2** | 拯救者 Y700（2023） | `TB320FC`（日本 OEM：`T0995HAS`） | Asphalt | Snapdragon 8+ Gen 1 (SM8475) | 2023-07 | 8.8" 2560×1600 144 Hz | **Lenovo Legion Tab**（TB320FC，2024 全球） | GSMArena 12476；devicespecifications；note.com；XDA 4685115 |
| **Gen3** | 拯救者 Y700（2025）/ Y700 2025 | `TB321FU` | Kirby | Snapdragon 8 Gen 3 (SM8650) | 2024-09 末（中国） | 8.8" 2560×1600 165 Hz | **Legion Tab (8.8", 3)**（CES 2025） | note.com；GSMchoice；tikgadget（CES 2025） |
| **Gen4** | 拯救者 Y700 四代（Y700 2025 Gen4） | `TB322FC`（国行 `elden_prc_wifi`） | **Elden** | Snapdragon 8 Elite (SM8750/P) | 2025-05-08（中国） | 8.8" 3040×1904 165 Hz | **无全球版**（联想 2026-03 直接发 Gen5） | 新浪 2025-05-08；NotebookCheck 2025-05-08 / 2026-03-01；本项目 `DEVICE/README.md` |
| **Gen5** | 拯救者 Y700 五代 | `TB323FU`（另有 `TB324ZC` Infinite） | Baldur | Snapdragon 8 Elite Gen 5 (SM8850P) | 2025 末 / 2026 | 8.8" 3040×1904 165 Hz | **Legion Tab Gen 5**（2026-03 全球） | note.com；NotebookCheck 2026-03-01 |

**表中不确定项（明确标出）**：

- Gen1 代号：note.com 写 `Pike`，GitHub 上一个 Magisk 模块写 `TB-9707F / sheng`；**两个都未见官方文档**，判 `未证实`。
- Gen3 代号 `Kirby`、Gen5 `Baldur` 来自同一篇社区总览，未见第二来源，判 `未证实`（Gen2 `Asphalt`、Gen4 `Elden` 有多个独立来源，判已证）。
- Gen5 的 `TB324ZC` 是「Infinite」变体（带 SIM），与本表 Gen5 同代不同 SKU。

**硬件连续性（规格层，已证）**：全系 8.8"、16:10、约 350–375 g、6550→7600→9000 mAh、双 USB-C（Gen2 起）、microSD（Gen3 取消、Gen4 恢复）；Gen1 有 3.5 mm 耳机孔，Gen2 起取消。**模具连续、主板不连续**（SoC 每代换）。

---

## §2 各代 Linux / 自定义 ROM / UEFI 进展

### 2.0 一眼矩阵

| 代 | postmarketOS | mainline board DTS | Mu-Silicium UEFI | TWRP | GSI | 设备专属 ROM | Linux 双启动 | Windows-on-ARM |
|---|---|---|---|---|---|---|---|---|
| Gen1 | ❌ 无 | ❌ 无 | ✅ `9707f`（Inactive；WoA ✅ / Linux ❌） | ✅ 多份 | ✅ 多份 | ❌（仅 GSI） | ❌ | ✅（UEFI 路径，驱动残缺） |
| Gen2 | ❌ 无 | ❌ 无 | ❌ 无条目 | ✅ polygraphene | ✅ | ✅ LineageOS 24（非官方） | ❌ | ❌ |
| Gen3 | ❌ 无 | ❌ 无（只有下游 DTS） | ❌ 无条目（Y700 条目仅 Gen1） | ✅ `b0006` | ✅ | ✅ Armada（enij90 等） | ✅ **GUF296 非破坏性双启动** | ❌ |
| Gen4 | ❌ 无 | 🟡 **v2 在审**（Pengyu Luo） | ❌ 无 TB322FC 条目（SM8750 仅手机） | ✅ twrp-16.0 | ✅ LineageOS 23.2 | ✅ 下游内核 2 条线，AOSP device tree 有人搭 | 🟡 下游内核 + `fastboot boot`；无 UEFI 落地 | ❌ |
| Gen5 | ❌ 无 | ❌ 无 | ❌ 无条目 | ? | ? | 🟡 Armada/kShimC 进行中 | 🟡 kShimC 多启动（tb323fu） | ❌ |

> 「✅/❌」判据 = 是否有公开、可下载、有人报告跑通的产物；`?` = 本轮未查到。逐代证据见下。

### 2.1 Gen1 — TB-9707F（SD870）：Android 生态齐全，Linux 为零，但 UEFI 能启 Windows

| 项 | 状态 | 关键链接 / 证据 |
|---|---|---|
| BL 解锁 | ✅ **官方申请制**：ZUI 官网填邮箱+SN 拿 `sn.img` → `fastboot flash unlock sn.img` → `fastboot flash unlock-go`（Gen1 要手动执行第二步） | note.com/forsaken_love02 总览（2024-11-28）；ZUI 解锁站 `zui.com` |
| 解锁副作用 | ✅ 解 BL 后 **Widevine 仍 L1**（该代独有优势） | 同上（社区观察，`未证实` 级） |
| TWRP | ✅ 至少 4 份设备树：`lddnsk/android_device_lenovo_9707F`（release `v1.0.48re-beta`，图形/触摸/解密可用）、`reindex-ot/TB-9707F_TWRP`、`Toygoon/twrp_device_lenovo_TB9707F`、`isrgish/twrp_device_lenovo_9707F` | XDA 4639897；GitHub 各仓 |
| GSI | ✅ crDroid / EvolutionX / Voltage / AOSP / LeOS / Elixir 均有实机报告；流程含 `--disable-verification flash vbmeta`、`fastboot reboot fastboot`、`delete-logical-partition product_b` | `LinuxDroidMaster/Lenovo-Legion-Y700-ROMs`（README，2024 起维护） |
| 设备专属 ROM | ❌ 未见 LineageOS/其它源码构建；社区以 GSI 为主 | 同上仓的 ROM 索引 |
| 主线 Linux | ❌ 无 DTS、无 postmarketOS 设备页；2023-08 XDA 有人求内核源码「to port mainline kernel」，无后续 | XDA 4621045 |
| Mu-Silicium UEFI | ✅ **支持**：`Lenovo Legion Tab Y700`，codename `9707f`，State **Inactive**；UEFI：Display ✅、Internal Storage ✅、Side Buttons ✅、USB Host ✅、USB Device ❌、**Windows Boot ✅、Linux Boot ❌** | `Project-Silicium/Mu-Silicium` `Status.md`（2026-11-01 拉取，§Lenovo Devices） |
| Windows-on-ARM | ✅ 有 Boot 记录（但 OS 功能表里 Touchscreen/WLAN/BT/GPU/Camera 全 ❌，只有 Storage/USB host/Display ✅） | 同上 |

**判读**：Gen1 的「Linux 价值」几乎全部在 Mu-Silicium 的 UEFI 记录上——它证明这条产品线的平板能被第三方 UEFI 点屏、读 UFS、跑 Windows PE/ARM；但**没有 Linux 双启动、没有 DTS、没有 GPU/WiFi**，不能作为 Gen4 的代码基线。

### 2.2 Gen2 — TB320FC（8+ Gen1）：Android 侧最活跃，Linux 侧空白

| 项 | 状态 | 关键链接 / 证据 |
|---|---|---|
| BL 解锁 | ⚠️ **被官方删命令**：新版本 ABL 无 `fastboot flashing unlock`，必须 EDL/QFIL 刷回**旧 ABL** 再执行；Gen2 的区域锁写在 SoC 深层（RMPB），基本不可逆；解 BL 会破坏 Widevine（TEE 证书消失，表面仍 L1） | note.com 总览；XDA 4685115（区域刷机指南） |
| 区域锁 | ⚠️ 已证存在：ZUI 15.0.774(PRC)/15.0.240(ROW) 起写区域码，锁态下刷异区 ROM 直接不启动；三个市场版本 PRC/ROW/NEC | note.com；XDA 4685115 |
| TWRP | ✅ `polygraphene/android_device_lenovo_TB320FC`（TWRP 3.7.x，android-12.1 分支） | XDA 4699005 |
| GSI | ✅ 大量实机报告；有专门的 GSI 兼容修复仓 `monefiera/Lenovo-Legion-Tab-GSI-FIX` | XDA 4690624 |
| 设备专属 ROM | ✅ **非官方 LineageOS 24（Android 17）**：`FAN789/y700-lineageos24`，2026-10-28 公开版，内核 5.10.260，基于 lolipuru 的设备/内核适配；完整源码 manifest + 每周 CI | GitHub 仓 README（2026-10-28） |
| Root | ✅ Magisk（`LinuxDroidMaster` 流程）/ CVE-2025-21479 内存提权（`xjoker/lenovo_y700_tb320fc_on_CVE-2025-21479`） | 各仓 README |
| 主线 Linux | ❌ 未查到任何 DTS / postmarketOS / 下游 Linux 移植 | 本轮 patchwork/GitHub/搜索均为 0 命中 |
| Mu-Silicium | ❌ `Status.md` 的 Lenovo 段只有 Gen1 `9707f`，**无 TB320FC** | Mu `Status.md` |
| Windows-on-ARM | ❌ 无 | — |

**判读**：Gen2 是「Android 自定义 ROM 最成熟的一代」（有真正的源码级 LineageOS），但**没有任何 Linux 尝试**；它的价值是反面教材——**区域锁 + BL 解锁命令删除** 这套组合拳后来在 Gen3/Gen4/Gen5 反复出现，只是每代的「旧 ABL 门槛版本」不同。

### 2.3 Gen3 — TB321FU（8 Gen3）：全系 Linux 完成度最高，但全靠下游

| 项 | 状态 | 关键链接 / 证据 |
|---|---|---|
| **GUF296 下游 Linux（自维护内核，非主线）** | ✅ **全系最完整**：umbrella 仓 `GUF296/tb321fu-linux`；内核 `7.1.1-g5df8e852ea72`；DTB `sm8650-lenovo-tb321fu.dtb`；Kubuntu 26.04 + Arch Linux ARM Plasma CI；Sensors/Haptics/Camera/Audio 均有打包件 | `GUF296/tb321fu-linux` README（2026-11-01 拉取） |
| **启动链（关键差异）** | ✅ ABL → `boot_a/b` 里的 **UEFI 载荷**（96 MiB boot.img）→ LUN4 `vm-bootsys_a` FAT（537 MB，卷标 `Y700BOOT`）→ `BOOTAA64.EFI`(GRUB) → `QCOMRAMP.EFI`(linuxdirect) → Linux；`root=PARTLABEL=userdata` | 本项目 Gen3 实测档案：`.pi/skills/qualcomm-edl-flashing/references/boot-chain-corrections.md`（2026-08-07） |
| 双启动方式 | ✅ **非破坏性**：保留 Android（a 槽），Linux 放 b 槽 + 新 `ubuntu`/`grubfat` 分区；`fastboot set_active a\|b` 切换 | 同上；`gpt-surgery.md` / `lenovo-lun4-safe-reset.md` |
| ArmadaOS 移植 | ✅ `enij90/armada-tb321fu`（SteamOS-like；165 Hz、触摸、GPU、Wi-Fi、BT、扬声器、G9 手柄、VRR、DP 外显；限制：**仅 BOE 屏**、安装即擦 Android、外显无声）；固件包 `enij90/firmware-lenovo-tb321fu` | 两仓 README；第三方调研 `skywalker512/armada-tb322fc/docs/00-RESEARCH.md` |
| 非破坏性社区版 | ✅ `vitalo233-eng/tb321fu-linux`（基于 `tb323fu-linux` 双启动架构 + GUF296 主线 bring-up）、`CharlesGool/tb321fu-android-armada-dualboot` | 各仓 README（2026） |
| TWRP | ✅ `polygraphene/android_device_lenovo_TB321FU`，release `b0006`（TWRP 3.7.1_12，portrait/landscape，100 MB） | 本项目 2026-08-08 调研 + 仓 release |
| GSI / 刷机工具 | ✅ GSI（NindoS 流程：**不能关 AVB**、erase system + flash + wipe）；LTBox 支持 TB321FU | 本项目 `community-tool-status-2026-08.md`；XDA 4742843 |
| 主线 Linux | ❌ **无板级上游提交**；DTS 只在 `enij90/armada-tb321fu` 的 `packages/kernel/dts/sm8650-lenovo-tb321fu.dts`（路径据该仓/第三方调研）与 GUF296 的内核树中；SM8650 SoC 本身早已在主线 | patchwork `q=tb321fu`/`q=sm8650 Lenovo` = 0；各仓文件路径 |
| Mu-Silicium | ❌ 无 TB321FU 条目；GUF296 用的是「自制 UEFI 载荷 + GRUB」，不是 Mu | Mu `Status.md`；GUF296 文档 |
| Windows-on-ARM | ❌ 无公开记录 | — |

**判读**：Gen3 是「**方法论金矿、代码不可直接搬**」。它的 boot 链依赖 `vm-bootsys_a/b`（Gen4 没有）；它的面板只调好 BOE（Gen4 是 CSOT + Novatek NT36536）；它的 DTS 不在主线。但它把「非破坏性双启动 + GPT 尾部分区 + slot-retry 处理 + fastbootd 二次进入 + EDL 分区读写」整套流程跑通了，而这些**在 Gen4 上逐条成立**（见 §3.1）。

### 2.4 Gen4 — TB322FC（8 Elite）：下游内核两条线 + 主线 DT 在审，UEFI/WoA 为零

| 项 | 状态 | 关键链接 / 证据 |
|---|---|---|
| 主线 DT | 🟡 `[PATCH v2 0/2] Introduce Lenovo Legion Y700 Gen4`：`sm8750-lenovo-elden.dts`（1170 行，基于 `sm8750-qrd`）+ `qcom.yaml` 加 `lenovo,elden`；v2 加了 DSI panel 节点。**patchwork = changes-requested；Konrad 2026-09-02 有 review；无 v3** | lore v2：`https://lore.kernel.org/linux-devicetree/20260726143048.130116-1-mitltlatltl@gmail.com/`；patchwork 14711231/14711232 |
| 主线可用功能（v2 口径） | ✅ 按键、双 USB（含 altmode）、充电/电量计、framebuffer 显示、背光；🟡 触摸需下游补丁（Novatek）；❌ Wi-Fi/BT/摄像头/麦克风/传感器/马达 | 同 thread 的 cover + 第三方调研（`00-RESEARCH.md` §1） |
| 下游内核 | ✅ 两条活跃线：`GEEKiDoS/linux` 的 `v7.2-elden` 分支（`h0cheung/tb322fc-linux` 沿用/协作）与 `h0cheung/tb322fc-linux-kernel`；`h0cheung/tb322fc-linux` 报告：165 Hz、NT36536 触摸、Adreno 830（Turnip+Zink）、Wi-Fi（Peach/ath12k）、BT、扬声器（AW88461 + AudioReach）、内置麦、双 AW86927 触觉、ADSP/SSC 传感器、s2idle；摄像头部分可用 | `h0cheung/tb322fc-linux`、`GEEKiDoS/tb322fc-linux` README |
| 第三方 DT 副本 | ✅ `sunflower2333/linux` release `26.08.13.43` 带 `sm8750-lenovo-y700-gen4.dts`（1018 行） | 该仓 commit `f4b4bf129702d16ef5a61933d493161063e7cb4d`（第三方调研引用） |
| 本项目（xiaquwan1001） | ✅ 下游 bring-up + 上游化；自评 ≈90% 子系统可用；硬伤 Q28 冷启动 DSI 竞态、#106 亮屏后卡死、Q24 相机×熄屏互斥 | 本仓 `TASKS/README.md`、`reports/` |
| Android 侧 | ✅ TWRP `polygraphene/android_device_lenovo_TB322FC`（TWRP 3.7.1_16，`2026-04-04-2`）；LineageOS 23.2 GSI 实机通过（qtotter）；LTBox 支持；锁 BL 下 testkey 内核 root（`ll1zt/tb322fc-droidspaces-kernel`）；AOSP device/vendor 树 `lolipuru/android_device_lenovo_elden` + `lenovo-basements` org | 各仓 README；本项目 `tb322fc-y700-gen4.md` |
| 解锁门槛 | ⚠️ **必须先把 ABL 降到 ZUXOS ≤ 1.1.11.073/.076**，再从 `ro.boot.bootload_sn` 生成 `sn.img` → `fastboot flash unlock` + `fastboot oem unlock`；1.1.11.120 是陷阱（返回 OKAY 但 `unlocked` 仍 `no`）；1.5.x 的解锁 blob 全部失效（ABL 内嵌新 key） | 本项目 `tb322fc-y700-gen4.md`（两单元复现）；XDA 4743906；note.com 总览 |
| UEFI | ❌ Mu-Silicium **无 TB322FC 条目**（SM8750 仅 OnePlus 13 `dodge` / 13s `pagani`，且都是手机）；本项目自研 UEFI 线已搁置（亮屏曾成功，UFS/SMMU + 早期可见性卡死） | Mu `Status.md`；本项目 `reports/uefi-consolidated-20261030.md`、`reports/bootloader-alternatives-survey-20261030.md` |
| Windows-on-ARM | ❌ 无 SM8750 WoA bring-up（Renegade/edk2-msm 无 elden 配置）；Gen1 的 Mu WoA 记录不能跨 SoC 复用 | 本项目 `uefi-woa-prep-20261024.md`；Mu `Status.md` |

**判读**：Gen4 的 Linux **不是从零**——SoC 级 `sm8750.dtsi` 已在主线，板级 DT 有一份 1170 行的 v2 在审，下游有两条活跃内核线。真正缺的是：① v2 的 review 返工；② Wi-Fi/BT/摄像头/传感器的上游化；③ 一个不依赖 `vm-bootsys` 的**自启动**方案（目前靠 `fastboot boot` 或 b 槽直启）。

### 2.5 Gen5 — TB323FU（8 Elite Gen5）：只作为「下一代架构参照」

- `mydanyi/armadaos-freedom`：kShimC 多启动（STAR_CHART 菜单：Android / 机身 ArmadaOS / TF 卡 / 诊断 / Recovery / Fastboot / 9008），当前设备目录 `devices/lenovo-tb323fu`；`tb323fu-linux`（Joonhoe Kim）提供双启动架构（Gen3 的 `vitalo233` 版即基于它）。
- 解锁走 **`efisp` 分区**备份/替换，且解锁后 bootloader 模式的 fastboot 刷写被禁（只能 fastbootd）——与 Gen4 的「降级 ABL + sn.img」完全不同。
- 对本项目：**只借架构，不借代码**（不同 SoC、不同解锁机制）；若 Gen4 要做「自启动 + 多系统菜单」，kShimC 是唯一在 Y700 产品线上被第三方验证过的形态（Gen4 也有 `mydanyi/armadaos-freedom` 的文档提及）。

### 2.6 交叉验证：第三方调研与本轮一手证据的差异

- `skywalker512/armada-tb322fc/docs/00-RESEARCH.md`（2026-10-14）称 Gen4「主线 Linux bring-up ≈90%」——**这是把下游内核的能力算进「主线」**；本轮核对：主线只有 v2 DT（基础功能），90% 属下游树。引用时须区分。
- 该文称 Gen3 `enij90` 移植「仅 BOE，CSOT 黑屏」——与本项目 Gen3 档案（GUF296 模板、面板供应商差异）方向一致，但**未见一手复现**，判 `未证实`。
- 该文称 Gen4 上游 DT 面板为 `csot,pp8807hb1-1` + `novatek,nt36536`——与本项目主线 DT / v2 patch 一致，判 `已证`（patch 内容）。


---

## §3 代际可复用性：能搬什么、哪里断代

> 口径：**「能搬」= 已在 Gen4 上逐条复现或由同一份代码/同一套工具直接支持**；**「断代」= 换 SoC/换 boot 链/换供应商，必须重测或重写**。
> Gen3 证据主要来自本项目 2026-08 的 TB321FU 实测档案（`.pi/skills/qualcomm-edl-flashing/references/`），Gen4 证据来自本项目 `DEVICE/README.md`、`PITFALLS/README.md` 与 `reports/`。

### 3.1 可以直接搬（Gen3 → Gen4 已验证）

| # | 经验/事实 | Gen3 证据 | Gen4 状态 | 判定 |
|---|---|---|---|---|
| 1 | **UFS 多 LUN 布局**：LUN0 = `super` + `userdata`（数据），LUN4 = A/B boot 集（`boot/vendor_boot/init_boot/dtbo/vbmeta/recovery`） | TB321FU：LUN0 super 13 GiB + userdata 218 GiB；LUN4 boot 96 MiB×2、init_boot 8 MiB、dtbo 24 MiB、vbmeta 64 KiB、recovery 100 MiB | TB322FC：LUN0 super 22 GiB + userdata 211 GiB；LUN4 boot 96 MiB；112 分区（Gen3 107） | ✅ **搬布局，不搬数字** |
| 2 | **扇区 = 4096 B**（GPT/EDL 的 LBA 单位都是 4096，不是 512）；`edl.py rs/ws` 的块单位同 | TB321FU LUN0 60,884,992 扇区 × 4096；`rs` 512B 单位会读到幻影盘 | 本项目实测同（`DEVICE/README.md`：LUN0 扇区 4096 B） | ✅ 直接搬 |
| 3 | **GPT 手术方法**（Python 改 entry、entries_crc → hdr_crc 顺序、primary LBA0 + backup 尾部、16 个空闲槽） | `.pi/skills/qualcomm-edl-flashing/references/gpt-surgery.md`（TB321FU 验证） | Gen4 已按同法手术出 `linux17` 192 GiB（本项目 2026-10-25/10-31） | ✅ 直接搬 |
| 4 | **ABL A/B slot + slot-retry 语义**：槽状态在 GPT attribute byte 6（`0x04` active / `0x40` successful / `0x80` unbootable / `0x38` retry）；桌面 Linux 不标 successful ⇒ 每次启动递减，7 次后 `slot-unbootable`；`fastboot set_active` 清标志并重置 7 | TB321FU 实测（`boot-chain-corrections.md`，2026-08-07） | Gen4 同一套 ABL（本项目多次 `set_active a/b` 恢复） | ✅ 直接搬 |
| 5 | **EDL 工程 loader = `xbl_s_devprg_ns.melf`**（不是 `prog_firehose_ddr.elf`）；`qfil` 会静默漏写 ⇒ 逐分区读回校验 | TB321FU（XDA 4706488 + 本项目实测） | Gen4 固件包同样带 `xbl_s_devprg_ns.melf`，已用于降级/救砖 | ✅ 直接搬（文件名以各代包为准） |
| 6 | **fastboot 三个坑**：① 无 `fastboot fetch`（`Unable to get max-fetch-size`）⇒ 回读走 EDL；② `adb reboot fastboot` 只到 bootloader，需再 `fastboot reboot fastboot` 才是 fastbootd（`is-userspace:yes`）才能动 logical partition；③ 长写（22 GiB super）后通道脆弱，`getvar` 超时，物理重插可恢复 | TB321FU（本项目 2026-08-08） | Gen4 **逐条复现**（本项目 GSI 流程/22 GiB super 直刷记录） | ✅ 直接搬 |
| 7 | **AVB testkey 窗口 + 区域/防刷链**：联想用公开 AOSP testkey 签启动链，锁态也能 EDL 刷自签件；但**每代截止版本不同** | Gen3：ABL 信任 testkey 到 ZUI 17.5.10.170（LTBox 文档）；区域转换用 `vendor_boot` 的 `.PRC`↔`.ROW` + 重建 vbmeta | Gen4：testkey 漏洞到 ZUXOS **1.5.10.138**；主 vbmeta/boot 链 testkey sha1 `2597c218`；1.5.10.138 之后 ABL 换新 key | ✅ 搬「思路」，❌ 搬「版本号」 |
| 8 | **TWRP / LTBox / GSI 工作流**：TWRP 刷 `recovery_a/b`（EDL 或 fastboot）；LTBox 做 EDL 分区读写/root/救砖；GSI 必须走 fastbootd + `erase system` + `flash system`（自动 resize） | Gen3：polygraphene `b0006`、LTBox、NindoS GSI 流程 | Gen4：polygraphene twrp-16.0、LTBox（Simple Flasher）、LineageOS 23.2 GSI 已实机 | ✅ 直接搬 |
| 9 | **`boot` 分区 96 MiB 上限**：超过就只能 `fastboot boot`（RAM）或 kexec，不能 `fastboot flash boot_b` | Gen3 boot_a/b 96 MiB | Gen4 同；本项目 vk95 镜像 107.7 MB 只能 `fastboot boot` | ✅ 直接搬 |
| 10 | **只刷 LUN4 的 `rawprogram4` 是「安全重置 Android 侧」**（不碰 LUN0 GPT 尾部的自定义分区；`vm-bootsys_a`/`_b` 的 filename 为空会被跳过） | TB321FU（`lenovo-lun4-safe-reset.md`，2026-08-08 实测） | Gen4 没有 `vm-bootsys`，但 LUN4-only 重置思路同样成立 | ✅ 搬方法 |
| 11 | **解锁前先取 Widevine/DRM 基线**（解锁会 L1→L3） | Gen3：据社区，解 BL 后仍 L1（与 Gen2/Gen4 不同） | Gen4：L1→L3（本项目两单元记录） | ⚠️ **每代单独确认**，不能假设 |

### 3.2 明确断代（不能照搬）

| # | 断代点 | 具体差异 | 影响 | 证据 |
|---|---|---|---|---|
| 1 | **SoC 平台层** | SM8250-AC → SM8475 → SM8650 → SM8750(P)；CPU 从 Kryo 到 Oryon，时钟/PMIC/RPMh/PHY/GPU 全换 | 所有 clk/pinctrl/regulator/display/camss 驱动与 DT 节点不能跨代复用；只能复用「同一子系统框架」 | 各代规格表（§1）；主线 `sm8750.dtsi` 为 Oryon |
| 2 | **Gen3 的 `vm-bootsys_a/b` 在 Gen4 被删除** | Gen3：LUN4 有 537 MB `vm-bootsys_a/b` FAT（卷标 `Y700BOOT`），是 GUF296 启动链的枢纽；Gen4：**无此分区**，vendor fstab 里对应项被注释 | GUF296 的「boot_b=UEFI → vm-bootsys FAT → GRUB」**完全不可移植**；Gen4 必须走 `fastboot boot`/b 槽直启/自研 UEFI | 本项目 `tb322fc-y700-gen4.md`（2026-08-15 实测）；Gen3 `boot-chain-corrections.md` |
| 3 | **ABL 对「异类载荷」的 boot header 行为** | Gen4 实测：**v3 header 的 UEFI/异类载荷被静默忽略**（返回 `Booting OKAY` 但不交棒、USB 不断）；改 **v0 + `--base 0x10000000`** 才真交棒；v0 header 的 `os_version`/`ramdisk_addr` 等遗留字段也会翻转行为（#479）。Gen3：GUF296 的 boot_b 载荷就是 v3 header（kernel_size 2,413,234 gzip → 4,194,416 B ARM64 Image，magic `0x10000381`，非标准 Linux Image），ABL **接受** | Gen4 上做 UEFI/自定义载荷必须用「干净 v0 + base 0x10000000」；普通 mainline `boot.img`（v3）不受影响 | 本项目 `PITFALLS` #387/#418/#479；Gen3 `tb321fu-y700.md`（载荷分析） |
| 4 | **解锁机制** | Gen1：官方 sn.img + `unlock-go`；Gen2：旧 ABL + `flashing unlock`；Gen3：官方 sn.img（`flash unlock` 自动 `unlock-go`）；**Gen4：必须先降 ABL 到 ≤1.1.11.073/.076，再 `flash unlock` + `oem unlock`，且 1.5.x blob 全失效**；Gen5：`efisp` 分区替换 | 「按上一代教程解锁」会失败；Gen4 的 1.1.11.120 还会假成功 | 本项目 `tb322fc-y700-gen4.md`；note.com 总览；Gen5 kShimC 文档 |
| 5 | **AVB/回滚保护** | Gen2/Gen3 有 rollback index；**Gen4 无 rollback 保护**（可随意降级，hitin911/社区 + 本项目实测）；Gen5 又变 | 不能把 Gen3 的 vbmeta rollback 处理套到 Gen4；Gen4 反而是「降级最自由」的一代 | 本项目 `tb322fc-y700-gen4.md`；note.com |
| 6 | **区域锁/防刷** | Gen2 起写入 SoC 深层 RMPB，基本不可逆；Gen3 PRC/ROW/NEC 三版且需 `vendor_boot` 区域码 + 重建 vbmeta；**Gen4 只有 PRC**（无 ROW 版） | Gen4 不需要跨区转换；但也不能用 Gen3 的 ROW→PRC MOD 包 | note.com 总览；本项目 Gen4 档案；Gen3 `community-tool-status-2026-08.md` |
| 7 | **面板/触屏供应商组合** | Gen3 社区移植**只调好 BOE**（CSOT 黑屏，`未证实`）；Gen4 主线 DT/v2 用 **CSOT `pp8807hb1-1` + Novatek `nt36536`**；分辨率 2560×1600 → 3040×1904 | 面板时序/初始化序列、触屏固件不能跨代复用；Gen4 若买到不同供应商屏需另测 | 主线 v2 patch；`00-RESEARCH.md`（第三方）；本项目 `p1-upstream-dsi-20261013.md` |
| 8 | **触觉/音频/连接 codec** | Gen3 触觉 AW86937；Gen4 双 **AW86927**；Gen4 音频 **AW88461 + AudioReach 拓扑**；Gen4 Wi-Fi/BT = **WCN7861（Peach/ath12k）**，需要 `tmel_peach_20.elf` 等 5 个固件 | 马达/功放/UCM/tplg/固件文件名全部要重做；不能拿 Gen3 的 debs 直接装 | GUF296 README（Gen3 AW86937）；本项目 `DEVICE/README.md` 固件表 |
| 9 | **分区数量/容量** | Gen3：107 分区、super 13 GiB；Gen4：112 分区、super 22 GiB、userdata 211 GiB | 任何写死分区号/偏移的脚本（rawprogram、GPT 手术、`/dev/sdaN`）都要按实际 GPT 重算 | 本项目 Gen3/Gen4 档案 |
| 10 | **内核基线** | Gen3：GUF296 7.1.1（SM8650 下游补丁）；Gen4：GEEKiDoS `v7.2-elden` / 主线 7.3-rc + SM8750 补丁 | 驱动补丁不能 cherry-pick 跨 SoC；只能对照同一子系统（如 DSI/DPU）的实现思路 | GUF296 README；本项目 `reports/` |

### 3.3 boot header / 96 MiB / `fastboot boot` 的准确口径（避免以讹传讹）

1. **「v3 被拒」只对异类载荷成立**。Gen4 上日常 mainline 内核（v3 header、gzip Image）用 `fastboot boot` 正常；被静默忽略的是 **UEFI/非 Linux 载荷**的 v3 包装（`Booting OKAY` 但设备留在 bootloader）。判据不是「OKAY」，而是 **USB 是否掉线 / `usb_read failed`**（`PITFALLS` #387/#481）。
2. **v0 不是万能钥匙，`--base` 必须对**。Gen4 的异类载荷 v0 必须 `--base 0x10000000`（`kernel_addr=0x10008000`）；`--base 0x0` 同样「OKAY 不交棒」（#418）。且 v0 header 的遗留字段会影响结果（#479），必须用干净 header。
3. **96 MiB 是分区上限，不是 `fastboot boot` 上限**。`fastboot boot` 走 RAM，不受 96 MiB 限制；受限的是 `flash boot_a/b`（本项目 107.7 MB 镜像只能 boot 不能 flash）。
4. **Gen3 接受过 v3 的非标准载荷**（GUF296 boot_b：ARM64 Image magic `0x10000381` + `uefiplatLA.cfg`），说明「ABL 对 header 的容忍度」**逐代/逐分区不同**；不要把 Gen4 的结论外推到 Gen3，反之亦然。

### 3.4 子系统延续性速查

| 子系统 | Gen1 | Gen2 | Gen3 | Gen4 | 可否跨代复用 |
|---|---|---|---|---|---|
| SoC | SD870 (SM8250-AC) | 8+ Gen1 (SM8475) | 8 Gen3 (SM8650) | 8 Elite (SM8750P) | ❌ |
| UFS | 3.1 | 3.1 | 4.0（SoC 支持；实测 6 LUN） | 4.0（实测 6 LUN、4096 B） | 🟡 布局/工具可，PHY/时钟不可 |
| 面板 | 8.8" 2560×1600 120 Hz | 同 144 Hz | 同 165 Hz（BOE/CSOT 混装） | 8.8" 3040×1904 165 Hz（CSOT PP8807HB1） | ❌ |
| 触屏 | 未证 | 未证 | 未证（社区移植可用） | Novatek NT36536 | ❌（Gen3→Gen4 未证同型） |
| 触觉 | 未证 | 未证 | AW86937 | 双 AW86927 | ❌ |
| 音频功放 | 未证 | 未证 | 未证 | AW88461 + AudioReach | ❌ |
| Wi-Fi/BT | Wi-Fi 6 / BT5.0 | Wi-Fi 6E / BT5.2 | Wi-Fi 7 / BT5.4 | WCN7861（Wi-Fi 7 / BT6.0） | ❌ |
| 充电/电量计 | 未证 | 未证 | 未证 | `qcom_battmgr` + WL2868C（相机 PMIC） | ❌ |
| GPU | Adreno 650 | 730 | 750 | 830 | ❌ |

> 表中「未证」= 本轮没有找到可靠的拆机/DT/驱动证据，不臆造型号。

### 3.5 一句话判据

- **能搬的判据**：只涉及「分区/GPT/槽/AVB/EDL/fastboot/TWRP/GSI」这些**平台无关层** → 直接搬（§3.1 的 1–10 条）。
- **不能搬的判据**：一旦涉及「SoC 寄存器、时钟、PHY、面板时序、codec 型号、分区数字」→ 必须按 Gen4 实测重做（§3.2 的 1–10 条）。
- **最危险的错觉**：把 Gen3 的 `vm-bootsys` 双启动当成「Y700 通用方案」——它在 Gen4 上**物理不存在**。


---

## §4 Lenovo Legion Tab 与 Y700 是什么关系

**结论：Legion Tab 是 Y700 的海外市场名，不是独立产品线；同一代硬件、不同 ROM/区域码，部分代还有 OEM 换标版。**

| 代 | 中国名 | 海外/全球名 | 关系与差异 | 证据 |
|---|---|---|---|---|
| Gen1 | 拯救者 Y700（2022） | **无**（曾规划 `TB-9707N`，未上市） | PRC 独占；因此 Gen1 的社区资料几乎全在中文/日文圈 | GSMArena 11394；note.com 总览 |
| Gen2 | 拯救者 Y700（2023） | **Lenovo Legion Tab**（`TB320FC`） | **同一硬件**（8+ Gen1、8.8" 144 Hz、6550 mAh）；海外版只是 ROW ROM。日本另有 OEM 版 **NEC LAVIE Tab T9（`T0995HAS`）**，同为 TB320FC 硬件、NEC logo/ROM | GSMArena 12476；note.com 总览；XDA 4660243（「Y700 Global Release」） |
| Gen3 | 拯救者 Y700（2025） | **Legion Tab (8.8", 3)**（`TB321FU`） | 同一硬件；2025-01 CES 全球发布。PRC/ROW/NEC 三版，**区域锁从这代起是默认配置** | note.com 总览；tikgadget（CES 2025）；XDA 4685115 |
| Gen4 | 拯救者 Y700 四代（`TB322FC`） | **没有全球版**（传闻名「Legion Tab Gen 4」，未上市） | 联想 2026-03 直接发布 **Legion Tab Gen 5**，官方确认「不会有 Legion Tab Gen 4」；Gen4 是 PRC 独占 | NotebookCheck 2025-05-08（预期全球名）/ 2026-03-01（官方跳过 Gen4）；note.com 总览 |
| Gen5 | 拯救者 Y700 五代（`TB323FU`） | **Legion Tab Gen 5** | 同代硬件；2026-03 全球发布 | NotebookCheck 2026-03-01 |

**对项目的三条实际影响**：

1. **找资料时中英日三语都要搜**：Gen2 的日本资料在 NEC LAVIE Tab T9 名下，Gen3/Gen4 的英文资料常写「Legion Tab (8.8", 3)」而不是 Y700。
2. **ROM/固件不能跨区互刷**：Gen2 起区域锁写进 SoC 深层；Gen3 的 PRC→ROW 需要 `vendor_boot` 区域码 + 重建 vbmeta；Gen4 只有 PRC，反而没有跨区问题，但也拿不到 ROW 固件。
3. **「Legion Tab」的 Linux 资料不能按名字直接套代**：例如 `enij90/firmware-lenovo-tb321fu` 标题写的是「Legion Tab Gen 3 / Y700 2025」，不是 Gen4；`GUF296/tb321fu-linux` 同理。

---

## §5 主线 Linux 上游提交（同系列设备）

### 5.1 唯一一份「设备级」上游提交：Gen4 板级 DT（未合并）

| 文件路径 | 作者 | 系列/版本 | 状态（2026-11-01） | 链接 |
|---|---|---|---|---|
| `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（新增，1170 行） | **Pengyu Luo** `<mitltlatltl@gmail.com>` | `[PATCH v1 0/2]` 2026-07-19；`[PATCH v2 0/2]` 2026-07-26 | **未合并**。patchwork `changes-requested`；Abel Vesa 2026-07-27 质疑 cover 说「framebuffer 需禁用 mdss/dispcc」但 DT 实际 enable 了 mdss；Konrad Dybcio 2026-09-02 有 review；**无 v3**。torvalds master 无此文件（404） | v2 cover：<https://lore.kernel.org/linux-devicetree/20260726143048.130116-1-mitltlatltl@gmail.com/>；patchwork 14711231/14711232 |
| `Documentation/devicetree/bindings/arm/qcom.yaml`（+1 行：`lenovo,elden`） | 同上 | 同上 | 同上 | 同上 |
| `arch/arm64/boot/dts/qcom/Makefile`（+1 行 `sm8750-lenovo-elden.dtb`） | 同上 | 同上 | 同上 | 同上 |

**v2 的覆盖范围**（决定「主线能用到什么」）：按键、双 USB（含 altmode）、充电/电量计、framebuffer 显示、背光、DSI panel 节点；**不含** Wi-Fi/BT/摄像头/麦克风/传感器/马达；触摸需下游 Novatek 补丁。第三方报道（Phoronix 2026-07）与此一致。

### 5.2 SoC 级（非设备级）基线：已在主线

| 文件 | 内容 | 状态 |
|---|---|---|
| `arch/arm64/boot/dts/qcom/sm8750.dtsi` | SM8750 SoC 级 DT（CPU Oryon、GIC、RPMh、UFS、PCIe、USB、display 等） | ✅ 已在 torvalds master（2026-11-01 核对，7484 行） |
| `arch/arm64/boot/dts/qcom/sm8750-qrd.dts` / `sm8750-mtp.dts` | 高通参考板 | ✅ 主线有（v2 DT 即以 qrd 为基线） |

> 这意味着 Gen4 的「SoC 支持」不是瓶颈；瓶颈是**板级外设与电源/面板细节**。

### 5.3 本项目自己的上游动作（与 Gen4 板级 DT 有冲突风险，需注意）

| 系列 | 文件 | 作者 | 状态 | 备注 |
|---|---|---|---|---|
| `[PATCH v4 0/4] regulator: add the Will Semiconductor WL2868C camera PMIC` | 含 `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（**新建，175 行**）+ `sm8750.dtsi` + `qcom.yaml` | Qianhui Xu（本项目） | patchwork `new`（2026-10-31）；sashiko 提 3 条 Medium，其中一条是 **「new sm8750-lenovo-elden board DT lacks boot infrastructure」** | ⚠️ 这份 175 行 board DTS 与 Pengyu v2 的 1170 行**是同一个文件名、两个来源**；v2 未合并时它会「先占坑」，合并后必然冲突。上游化策略需二选一（见 §6 第 1 条） |
| `[PATCH v3/v4 3/3 or 4/4] ... describe the WL2868C regulators` | 同上 | 同上 | 同上 | 同上 |

### 5.4 同系列其它代：**零**设备级上游提交

| 代 | 设备级 DTS（主线） | 说明 |
|---|---|---|
| Gen1 TB-9707F | ❌ 无 | 只有下游 TWRP/GSI，无 Linux DTS |
| Gen2 TB320FC | ❌ 无 | 只有 Android 内核（5.10）与 LineageOS 设备树，不是 Linux 上游 |
| Gen3 TB321FU | ❌ 无 | `sm8650-lenovo-tb321fu.dts` 只存在于 GUF296 的 7.1.1 下游内核与 enij90 的 `packages/kernel/dts/`（路径据第三方调研，本轮未逐文件核对）；patchwork `q=tb321fu` = 0 |
| Gen4 TB322FC | 🟡 v2 在审 | 见 §5.1 |
| Gen5 TB323FU | ❌ 无 | 只有 kShimC/Armada 下游 |

**下游 DTS 位置（可作代码参考，但不是上游）**：

- Gen3：`enij90/armada-tb321fu` → `packages/kernel/dts/sm8650-lenovo-tb321fu.dts`；GUF296 `ubuntu-y700-build-ci` 的 DTB `sm8650-lenovo-tb321fu.dtb`（内核 7.1.1）。
- Gen4：`GEEKiDoS/linux` 分支 `v7.2-elden`；`h0cheung/tb322fc-linux-kernel`；`sunflower2333/linux` release 内 `sm8750-lenovo-y700-gen4.dts`（1018 行，commit `f4b4bf129702d16ef5a61933d493161063e7cb4d`）。

---

## §6 对我们（TB322FC / elden）有用的五条

1. **主线 board DTS 只留一个来源：等/推 Pengyu v2，别让我们的 wl2868c 系列继续「新建同名 board 文件」。**
   现状是两个来源：v2 的 1170 行完整板级 DT（在审）vs 我们 v4 的 175 行最小 board DT（2026-10-31 投出，sashiko 已指「lacks boot infrastructure」）。
   建议：把我们的 DTS 补丁改成 **「基于 v2 的增量」**（明确写 `Depends-on: <v2 Message-ID>`），或先只上游 WL2868C driver/binding、DTS 等 v2 落地后 rebase。否则同一个 `sm8750-lenovo-elden.dts` 两份来源，reviewer 只会拒后者。

2. **Gen4 的自启动不要抄 Gen3 的 `vm-bootsys` 方案——该分区在 Gen4 不存在。**
   Gen3 的「boot_b=UEFI → vm-bootsys FAT → GRUB」是它独有的（537 MB `Y700BOOT` FAT），Gen4 的 vendor fstab 里对应项已被注释。
   Gen4 现实路线只有三条：① 继续 `fastboot boot`（零写盘，但依赖 PC）；② b 槽直启 mainline（已跑通，代价是 Android 侧让位）；③ 自研 UEFI（本项目已证「能亮屏」但卡在 UFS/SMMU 与早期可见性，维持搁置）。**先把 ①/② 的 Q28 显示稳定性做成可交付，比追 ③ 收益高。**

3. **把 Gen3 验证过的「跨代不变层」固化成 Gen4 的脚本与门禁**：slot-retry 7 次语义（桌面 Linux 不标 successful 会被 ABL 判 unbootable）、fastbootd 必须 `fastboot reboot fastboot` 第二次进入、GPT 4096 B 双表 + entries_crc→hdr_crc 顺序、EDL `rs/ws` 的 4096 B 单位、`qfil` 静默漏写要逐分区读回。这些在 Gen3/Gen4 上逐条成立，且**每次换内核/换根都会用到**。

4. **面板/触屏供应商是 Gen4 最大的「同代碎片化」风险，先统计再写死 DT。**
   Gen3 的教训是社区移植只调好 BOE、CSOT 黑屏（`未证实` 级但方向一致）；Gen4 主线 v2 写的是 **CSOT `pp8807hb1-1` + Novatek `nt36536`**，而国行机可能混装。建议：DT 里保留按 panel compatible 分支的能力（或至少记录 `panel-name`/DDIC 读回），并在设备侧先采一批 `dmesg | grep -i panel` 统计，再决定是否只支持 CSOT。**不要假设「Gen3 的 BOE 补丁能用在 Gen4」。**

5. **上游化排序：先「设备专属外设增量」，后「board DTS 整体」；WoA 不在 Gen4 路线内。**
   可独立成 series 的增量：WL2868C（相机 PMIC，已在投）、AW86927（双触觉）、WCN7861/ath12k 固件与 DT、NT36536 触摸、CSOT 面板、`qcom_battmgr`。每一项都写清「依赖 Pengyu v2 的哪个 commit/文件」，避免再出现「同文件两份来源」。
   Windows-on-ARM 只有 Gen1 通过 Mu-Silicium 成功过（Display/Storage/USB host ✅，但 Touch/WLAN/BT/GPU ❌），SM8750 没有 WoA 栈；**Gen4 的 G3（x86 游戏）应继续走 Box64+Wine/Proton，不要为 WoA 分叉**。

---

DONE
