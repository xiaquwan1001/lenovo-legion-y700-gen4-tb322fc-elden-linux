# 工作区索引 — TB322FC "elden"（SM8750P）固件与驱动研究

> **入口。** 新会话：本文件 §1（使命）→ §2（文档分层）→ §3（现状）→ 需要细节再进对应文档/专题档案。
> **唯一入口 = 本文件**；根目录只有 **6 份维护文档**（§2）+ `AGENTS.md`。
> 2026-10-03：git 纳管 + 文档收敛（12→6）；自检 `scripts/check-doctor.sh`；不再有 SQLite/生成物。

---

## 1. 使命与范围（6 行）

1. **机型唯一**：只研究 **TB322FC / elden / SM8750(P)**；研究内容只有 **固件 + 驱动**。不做别的机型移植。
2. **设备等价**：同型号多台单元**物理地位完全等价**，唯一差异 = **容量**（内存/UFS → GPT 数值）。
   身份 = `(SN, hwboardid, 容量)`；**"新机/旧机"不是角色**，**任务按单元当前状态分派**。
3. **G1**：跑**功能健全的 Linux**，**正常驱动原厂全部固件**（ADSP/CDSP/WCN/GPU/触屏/触觉/功放/tplg）。
4. **G2**：**在没有 Android 的前提下**最大化兼容安卓（**a 槽可弃**）——以容器为主路线、参考社区先例；
   **GMS/Play Integrity/Widevine 能做到哪一级 = 待调查，不预设"不可能"**。
5. **Linux 存储容量不固定**：按项目体量估算后一次给足（`DEVICE.md` §3），并可回收 Android 专属分区扩容。
6. 术语：设备称 **U1 / U2**；备份目录 `backup/<SN>-<容量档>/`；禁用 `new-tablet` 与"两轨分机"旧口径。

---

## 2. ★ 文档分层（入口最少）

> **单一事实源（SSOT）**：每个数字/结论只在一个文件维护，其余用链接引用。
> 根目录只有 6 份维护文档：`INDEX`（本文件）· `DEVICE` · `TASKS` · `RESOURCES` · `RUNBOOK-BRINGUP` · `PITFALLS`。
> **推荐阅读顺序**：本文件 → `TASKS.md`（任务/进度/未解）→ `PITFALLS.md`（动手前扫）→ 需要时再进 `DEVICE`/`RESOURCES`/`RUNBOOK`。

### 入口（唯一）

| 文件 | 装什么 |
|---|---|
| **`INDEX.md`** | 使命与范围、分层地图、现状快照、快速命令、专题档案索引 |

### 领域层（4 份，唯一维护面）

| 角度 | 文件（权威） | 装什么 |
|---|---|---|
| **设备状态 + 设备描述** | **`DEVICE.md`** | 机型规格、固件清单与通路、驱动矩阵、单元台账 U1/U2、状态→任务分派、GPT 参数、**§3 Linux 容量策略** |
| **任务 / 进度 / 未解 / 方案** | **`TASKS.md`** | **唯一任务台账 + 进度权威**（§0）；G1/C/A 任务（§1–4）；**§5 查漏补缺（GAPS/Q1–Q23）**；**§6 G2 安卓兼容方案**；**§7 上游化（M1–M5）** |
| **资源 / 资产 / 会话轨迹** | **`RESOURCES.md`** | §1 外部参考 · §2 本地资源 · **§3 文件与资产台账（git 边界/可清理）** · **§4 会话索引（68 条 + 实机边界）** |
| **上机手册** | **`RUNBOOK-BRINGUP.md`** | 任一单元从原厂状态做到 b 槽直启 + 持久根的 Phase −1…9 |

### 经验层（1 份）

| 文件 | 装什么 |
|---|---|
| **`PITFALLS.md`** | **§0 零号纪律**（动手前先做三件事）+ 踩坑正文 #1–#98（按主题）+ **§15 过时/废弃/功能缺陷登记**（DEPRECATED） |

### 证据层（`archive/`，只增不改、不改结论）

> 专题档案＝**过程证据**；结论一律以领域层为准，archive 不得被引用为「当前结论」。
> 新证据只追加，不回头改写。

### 机器可查（无 SQLite，无生成物）

- 文本搜索：`rg` / `grep`（`PITFALLS.md` 找踩坑、`RESOURCES.md` 找资源、`TASKS.md` 找任务）。
- 会话回忆：pi 原生会话选择器（`/resume`）+ `rg .pi/sessions`。
- 结构自检：`scripts/check-doctor.sh`（计数/死链/口径冲突）。

---

## 3. 现状速览（数字权威在 `TASKS.md` §0，本节仅为快照）

> **SSOT**：进度百分比与任务状态以 `TASKS.md` §0 为准；本节若与之不符，以 `TASKS.md` 为准。

- **G1 ≈88%**（对齐 TASKS §0）：mainline 已在真机全线可用（冷启 ~5 s 进 Phosh、165 Hz、A830 + Mesa 26.1.8、触屏、WiFi、BT、充电+旁路、温控分级 70/82/90/105 °C、**音频出声 + 桌面 PipeWire/UCM2**、**相机前后摄出流**、触觉、带外串口）。
  **U2 实跑 vk46-dirty**（b 槽持久直启；vk50 经 `fastboot boot` 零写盘实跑验证，kexec 热重载**硬挂不可用**，见 `TASKS.md` §4）。**剩 2 个硬缺口**：TF 卡、BT 配对（音频播放+输入均✅，相机出流 ✅ 2026-10-05）。
- **G2 ≈45%**：Waydroid 容器+内核+Mesa+GAPPS 镜像+代理通路就绪；Win-x86（Box64 0.4.5+Wine 9）PoC 成功；C9 用例集定稿；C4 传感器链（UDP HAL 实现+宿主数据源+部署脚本）全就绪待上机验证。
  待办：C1 复跑 → **C3 身份/DRM 取证** → C2 Play 登录 → C4 部署验证（与 `TASKS.md` §4 对齐）。
- **本轮主线（2026-10-05 用户定）= 尽可能覆盖硬件驱动**：G1-6 TF 卡 / G1-7 BT / G1-9 DP / G1-10 NFC / G1-11 CDSP + 在树未实测项；**不做**桌面用户态（G1-26/27/28）、熄屏/关机（G1-22/Q24）、UEFI（G1-29 已搁置）。
- **U1** 当前 = stock Android + root + **无 Linux 分区**（已逆手术，`/data` 211 GiB）；Linux 侧归档 3.44 GB 可无损恢复。
- **U2** = **BL 已解锁** + a 槽 stock 259 + **b 槽 mainline 持久直启**（当前 boot_b=干净内核 `vk47clean`，`/`=`/dev/sda17` ext4，Phosh 自启）；GPT 已手术（`linux17`=193 GiB / `userdata`=256.7 GiB），双表 dump 在 `backup/HA2EXB0E-16+512/`。功能状态（音频/温控/熄屏重启 G1-22/G1-24）与任务进度**权威在 `TASKS.md` §0/§4**，此处不复述。
  🟠 **熄屏→重启（G1-22/Q24）仍未解（间歇性）**：受控复现成立，但 vk42 与干净重建的少样本「免疫」不可信；**刷入干净内核到 boot_b 后仍复位** ⇒ 「`-dirty` 镜像为根因」假设**未证实**。**停止深究（2026-10-05 用户定）**；若再续须长时窗+多样本+单变量。见 `TASKS.md` §5 Q24、`PITFALLS` #102、`archive/topics/REBOOT-5MIN-2026-10-05.md` §7.9。
  🟠 **桌面用户态四问已定根因（G1-26/27/28，2026-10-05）**：`gtk-theme=Adwaita-dark` 解析回退浅色（应 `Adwaita`）⇒ 深色/图标反色/accent 同源；亮度=elogind 无 session。见 `archive/topics/DT-UI-2026-10-05.md`，修复待上机。
  ⇒ **解锁议题已定稿关闭**：看 `RUNBOOK` §0.5 ★权威顺序 + `archive/topics/复盘-2026-10-03-BL解锁.md`；**不要重新论证**。

---

## 4. 快速入口命令

```bash
cd ~/y700-elden          # ★ 启动入口即此（旧 flashing/eacndev/lob-remake 三个 cd 包装 2026-10-04 移除 → PITFALLS §15.1）
# 【收尾自检】计数漂移 / 死链 / 口径冲突（全绿再收工）
scripts/check-doctor.sh
# 【动手前 30 秒】引导链类问题（解锁/AVB/降级/GPT/EDL）先查本地 7、8 月已有结论（#87）
grep -rn -iE "unlock|解锁|sn\.img|1\.1\.11\.|rollback|testkey|073|\.120" \
  .pi/skills/*/references/*.md *.md archive/topics/*.md | grep -v '^Binary'
```

```bash
# 目标形态：b 槽直启 Linux（~5–9 s 进 Phosh），日常不需 fastboot
sudo bash elden-net.sh && ssh -o StrictHostKeyChecking=no root@192.168.7.1
# 内核迭代＝统一入口 scripts/iterate.sh（四档环，细则 RUNBOOK §迭代；mod-loop/kexec/to-fastboot/flash-b/cycle 均已自锁）
scripts/iterate.sh mod <driver-dir>              # 环0：=m 模块热载 ~30s 不重启（需先应用 fragment-modular）
scripts/iterate.sh kernel --kexec VERSION=vkNN   # 环2：全量重编 + kexec 热重载（无 fastboot/无按钮）
scripts/iterate.sh kernel --flash VERSION=vkNN   # 写回 boot_b（内部 sign+flash-b，哈希回读校验）
scripts/device-lock.sh --status                  # 谁占着设备；并发子代理写操作前必查
# ★ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM）
./cycle.sh --soft                          # 软回 fastboot（免按电源键）
fastboot boot out/boot-elden-vk40-ram.img  # 零写盘·纯RAM（无桌面/服务），仅内核/引导/分区级验证；先 blank 活跃槽 dtbo（否则卡 logo）
fastboot boot out/boot-elden-vk40.img      # 零写盘·RAM内核+磁盘根（有桌面/服务），功能测试用（见 PITFALLS #93）
# 新单元开工三件套（先写台账，再备份，再手术）
fastboot getvar serialno; adb shell getprop ro.boot.hwboardid   # → 写进 DEVICE.md §2.2
sh scripts/gpt-dump.sh                                          # 打印本单元 backup_lba（禁跨容量档复用）
fastboot fetch boot_b "$BAK"/boot_b.img                         # dtbo_b / vbmeta_b 同理
python3 scripts/slot-attr.py show                               # 槽位属性（在 GPT attribute，非 misc）
```

---

## 5. 目录速查

| 路径 | 内容 |
|---|---|
`linux -> geekidos-linux` | 内核树（7.2.0 + `patches/0001–0011`）
`patches/` | 内核改动与 config 快照（`config-vk40-bringup`）；**`elden-working-tree-ba28ec16f-2026-10-03.patch` = 权威工作树全量补丁**
**`RESOURCES.md §3`** | **文件台账：版本控制边界 / 顶层分类 / 可清理标记 / 内核补丁回导纪律**
**`PITFALLS.md`** | **经验总入口（新会话动手前先读）**：§0 零号纪律 + 踩坑正文 #1–#98
**`RESOURCES.md §4`** | **历史会话索引 + 实机验证边界**（68 条）
`scripts/` | 构建/刷机/GPT/温控/基准/串口/容器代理 全套脚本（清单见 `RESOURCES.md` §2.1）
`out/`、`bootslot-b/` | 产物与 b 槽自签包（`boot_b_vk40{,-ram}.img`、`avb.key`）
`backup/` | 原厂分区/固件/GPT 快照（**按容量档隔离**）；`backup/fw/README.md` 说明来源
`stock-src/` | 联想 GPL 源码（厂商驱动/DT/固件名反查依据）
`env-pass/` | 过环境栈 + **Linux rootfs 归档**（3.44 GB）
`archive/2026-10-02-merged/` | **本轮合并掉的旧文档原文**（MISSION-SCOPE/DEVICES/ANDROID-COMPAT-PLAN/ROUTE-DECISION/PLAN-NODEV/DOCS-CHANGELOG）

---

## 6. 专题档案地图（证据层，只增不改）

| 主题 | 文件 |
|---|---|
音频（tplg→APM 图全链） | `archive/topics/AUDIO-2026-10-02.md` `archive/topics/AUDIO-2026-10-01.md` `archive/topics/AUDIO-2026-09-30.md` `archive/topics/AUDIO-scout-2026-09-30.md`
相机 + 重力计拆解 | `archive/topics/CAMERA-2026-10-02.md` `archive/topics/STOCK-CAMERA-GRAVITY-2026-10-02.md`
显示/刷新率 | `archive/topics/PANEL-REFRESH-2026-10-01.md`
温控 / 充电 | `archive/topics/THERMAL-2026-10-02.md` `archive/topics/CHARGE-2026-09-30.md`
Waydroid / Play / 容器网络 | `archive/topics/WAYDROID-2026-10-01.md` `archive/topics/WAYDROID-AOSP-AUDIT-2026-10-01.md` `archive/topics/GPLAY-2026-10-02.md` `archive/topics/PROXY-WAYDROID-2026-10-02.md`
Win-x86 转译 PoC | `archive/topics/WIN-X86-POC-2026-10-02.md`（截图 2 张）`archive/topics/WIN-X86-2026-10-02.md`
虚拟化（EL2/Gunyah/AVF/生态） | `archive/topics/EL2-VIRT-2026-10-02.md` `archive/topics/ARM-VIRT-RESEARCH-2026-10-02.md`
间接引导层 / SM8750 UEFI（**G1-29 路线 A 已搁置 2026-10-05**） | `archive/topics/BOOTCHAIN-2026-10-05.md`（机制） `archive/topics/UEFI-RESOURCES-2026-10-05.md`（可用资源+中文社区检索） **`archive/topics/UEFI-UFS-BRINGUP-2026-10-05.md`（上机实验矩阵 + UFS 阻塞根因）** **`archive/topics/UEFI-UFS-UPSTREAM-ASK-2026-10-05.md`（上游 issue #12）**
驱动主线覆盖审计 / 厂商源码 | `archive/topics/DRIVER-MAINLINE-AUDIT-2026-10-02.md` `archive/topics/STOCK-DRIVERS-2026-09-30.md` `archive/topics/STOCK-KERNEL-2026-09-30.md`
持久化上机 + 熄屏重启故障 | `archive/topics/复盘-2026-10-03-持久化与睡眠.md` **`archive/topics/G1-22-2026-10-05.md`**（受控复现；根因未证实） **`archive/topics/REBOOT-5MIN-2026-10-05.md`**（§7.9 收尾）
过环境 / 隐藏模块 | `archive/topics/ENV-PASS-2026-10-02.md` `archive/topics/SUSFS-KERNEL-2026-10-02.md` `archive/topics/YUEHONG-MODULE-2026-10-02.md` `archive/topics/GPT槽位元数据-2026-09-30.md`
存储手术与回退 | `archive/topics/LINUX-REMOVE-2026-10-02.md` `restore-259/`（AVB/KSU/EDL 救砖）
带外调试 / 出网 | `archive/topics/OOB-CONSOLE-2026-10-02.md` `archive/topics/NET-EGRESS-PLAN-2026-10-01.md`
AOSP 迁盘校验 | `archive/topics/AOSP-MIGRATE-CHECK-2026-10-02.md`
踩坑总表（**动手前扫**） | `PITFALLS.md`（#80/#81＝“把机器当角色”“状态才是前置条件”；**#87＝引导链问题先 grep 本地既有结论**）
BL 解锁（**要不要 / 怎么**——已定稿，别再重推） | `RUNBOOK-BRINGUP.md` §0.5 ★权威顺序·`archive/topics/复盘-2026-10-03-BL解锁.md`（时线 + 7/8 月对照 + 根因）·`archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`（签名链取证）
操作史/复盘 | `archive/topics/HANDOFF.md` `archive/topics/复盘.md` `archive/topics/复盘-2026-09-29-夜.md` `archive/topics/复盘-2026-09-30-日.md` `archive/topics/复盘-2026-10-02-swarm.md` **`archive/topics/复盘-2026-10-03-BL解锁.md`** `archive/topics/PAUSE-2026-10-02-android.md`
**内核增量风险审核** | `archive/topics/AUDIT-since-vk34-2026-10-03.md`（GAPS Q22 / TASKS G1-23）与 **`RESOURCES.md §4`** 配套
换机迁移包 | `flashing-bundle/`（tar.gz 已归档 `archive/2026-10-04-root-strays/`）
**退场的入口**（快捷方式 + 已卸载插件 `pi-messenger-swarm` 全套，含恢复步骤） | `archive/2026-10-04-retired-entrypoints/README.md`
**上游化审查**（内核树 vs 主线 v7.2 全量 diff，A/B/C/D 分级） | `archive/topics/UPSTREAM-REVIEW-2026-10-04.md`（任务 `TASKS.md` §7 M1–M5）

---

## 7. 兄弟项目与边界

- ~~`~/y700类原生安卓/`~~ **已于 2026-10-02 退役并入本 repo**：该目录只有 2 份文档（24 K）+ 一个 `l2` 软链，无代码无记忆。文档原文进 `archive/topics/`（`资料汇总-2026-09-30.md`、`L2-修剪流水线-2026-09-30.md`）；LineageOS/erhai 移植线与 `aweiyry/lenovo-ota-tool` 进 gsi 技能 references；`/mnt/Samsung/l2` 改由本 repo 直接引用（`./l2` 软链）。类原生路线的**结论仍是不做**（本 repo 走 mainline + 容器）。
- `~/netfix`（USTC 路由）、`~/eacndev`、`~/lobcorp-remake`：与本设备无关。
- 外部资产位置与用途见 `RESOURCES.md` §2.3。
