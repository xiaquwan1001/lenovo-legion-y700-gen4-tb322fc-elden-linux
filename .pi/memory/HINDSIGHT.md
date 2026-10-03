# Hindsight — flashing

Techniques and root causes proven on Qualcomm/Lenovo tablet flashing. Host-machine

<!-- Older entries compacted -->
论：5 个来源 = 2 条互不相干的线

| 线 | 来源 | 本质 | 对本机（SM8750P） |
|---|---|---|---|
| **A. Linux 桌面线** | denial、droidloom | 主线 Linux 上把 Android 应用当原生 Wayland 窗口跑 | ⚠️ ARM64 未打包；是 Waydroid 的替代形态 |
| **B. Android 虚拟化线** | DroidVM、AOSP custom_vm.md、lfdevs 讨论#2 | 宿主 Android 上经 Gunyah/GenieZone/KVM 跑真 VM | ✅ **正对本机，且官方推荐就是 SM8750** |

## 关键发现

**① DroidVM 直接接上本机的 `EL2-VIRT` 结论。** 本机 EL2 被签名 Gunyah 占死，主线 Linux 拿不到 KVM；而 DroidVM 在 **Android 侧**用现成的 `/dev/gunyah` 跑 crosvm/QEMU，**绕开了"移植 downstream gunyah 主 VM 驱动"这个数天～数周的大坑**。它明说推荐 SoC = Snapdragon 8 Elite (SM8750)，要求 root（本机 KSU 已有）。这把 `EL2-VIRT` §6 的"唯一路线"从数周降到数小时。

**② 本地核对的一个硬缺口**：本机 `stock-src/android_kernel_lenovo_sm8750`（仅 1670 文件）**连 `drivers/virt/gunyah` 都没有**，`arch/arm64/gunyah` 也缺 —— 主线移植路线连源码都得先去别处取。更坐实了"走 Android 侧"。

**③ 8 Elite 的免 pvmfw 红利**：polygraphene 指南（环境就是本机 Y700 gen4）证实 8 Elite 支持 `--protected-vm-without-firmware`，无需按 pvmfw 要求给 guest 内核做 avbtool 签名（8 Gen2/3 才必须）。附注：Y700 的 pvmfw 内嵌 AOSP testkey，公钥 sha1 `2597c218`，与本机 boot AVB key 同源。

**④ 已收集的坑清单（DroidVM wiki + polygraphene）**：`ulimit -l unlimited`（Android 默认 locked-mem 仅 64 kB → OOM）、guest 内核需 `CONFIG_DMA_RESTRICT_POOL`（Alpine/Debian 云镜像常缺，用它的内置内核）、Gunyah RM 拒绝 → 切 "Prepare Lend mTHP"、Windows 需 `gunyah-guest-drivers-windows`。**图形加速（virtio_gpu/VirGL）是这栈最不确定项**——polygraphene 在 SM8750 上实测未通。

**⑤ 无 root 方案**：Podroid（Alpine+docker，AVF/QEMU 双后端）、TerminalAppPlus（AOSP17，U-Boot/qcow2/KMS 采集绕 SELinux，无 3D）。本机已有 root，走 DroidVM 更省事；无 root 的意义主要在"不动系统/不过检测"。

## 建议优先级（仅建议）
宿主 Android + DroidVM **>** denial 作桌面壳 **>** droidloom **>** 主线 Gunyah 驱动移植。

需要的话，下一步可做**只读验证**（`/dev/gunyah`、`/apex/com.android.virt/bin/{vm,crosvm}`、`vm list`）来确认本机 AVF 工具链是否齐全。


## Memory - 2026-10-02

TB322FC 新机（同型号 16+512）bring-up 策略（2026-10-02 定）：选「只动 b 槽 + LUN0 GPT、不碰 a 槽」路线——b 槽直启自签 mainline（boot_b/dtbo_b/vbmeta_b flags3 + 自签 avb.key），a 槽 stock Android 作安全网；512G 与旧机唯一差异是 GPT 布局，GPT 手术脚本已按「读实际 GPT」参数化，需先 dump。首次进入 mainline 用「纯 RAM 版」boot.img（cmdline 去掉 elden_root，`ROOTARGS=` 即空；build-boot.sh 已用 `${ROOTARGS-…}` 支持空值）：它仍会无条件起 USB-NCM+SSH(192.168.7.1)，足够做 GPT dump/手术/恢复 rootfs，避免先覆盖 a 槽 dtbo（ABL 会用 stock dtbo overlay 内嵌 DTB → 卡 logo，故 fastboot boot 需 dummy dtbo）。GPT dump：442G 级 4096B 扇区，主表取 LBA0..5，备表取 [backup_lba-4 .. backup_lba]（无头 0x20 8B LE 读 backup_lba）。备份 b 槽原厂分区用 `fastboot fetch <part> <out>`（只读）。


## Memory - 2026-10-02

无 sudo 检查/提取 Android 分区镜像：`debugfs`（e2fsprogs 自带）可直接读 raw ext4，无需 loop mount/root。用法：`debugfs -R 'ls -l /path' img`、`debugfs -R 'dump /path/file /tmp/out' img`。Android APEX 是 zip，`unzip -l xxx.apex` 里有 `apex_payload.img`（ext4），再 debugfs 进去即可查 `bin/`、`etc/`。据此可从 stock ROM 的 system.img 离线提取 AVF 全套（crosvm/vm/microdroid kernel/initrd/u-boot）。读取 build.prop 判镜像来源：`debugfs -R 'dump /system/build.prop /tmp/bp' img`。


## Automatic settled outcome - 2026-10-02

A1/A4/A7 已落地并验证。汇报如下。

## 完成清单（数字先行）

| 项 | 产出 | 状态 |
|---|---|---|
| **A1 内核** | `out/boot-elden-vk40.img`（持久根）+ `out/boot-elden-vk40-ram.img`（纯 RAM） | ✅ 编成 |
| A1 模块 | `out/modules-7.2.0-debug-….tar.gz`（strip 后 20M，**1484** 个 `.ko`） | ✅ |
| A1 配置 | `patches/config-vk40-bringup`（netd+camera+thermal+audio 全合，补丁 0001–0011 全在树） | ✅ |
| **A4 runbook** | `BRINGUP-NEW-TABLET-2026-10-02.md` + `scripts/gpt-dump.sh` + b 槽签名包 `bootslot-b/boot_b_vk40{,-ram}.img` | ✅ |
| **A7 基准** | `scripts/bench-run.sh`（CPU/mem/disk/GLES/Vulkan，工具自适应+温控采样）+ `bench-install.sh` | ✅ 主机冒烟通过 |
| A2/A3/A5/A9 | Mesa 26.1.8、Waydroid 镜像、rootfs 归档、相机 20 `.ko` | ✅ 已复核 |
| 文档 | `PLAN-NODEV-2026-10-02.md`、`INDEX.md` 已登记 | ✅ |

## 关键设计（去掉了原方案的一个坑）

发现 **b 槽直启比 `fastboot boot` 干净**：`fastboot boot` 走 a 槽，ABL 会用 stock dtbo overlay 内嵌 DTB → 卡 logo，必须先覆盖 `dtbo_a`。改用新路线后**全程不碰 a 槽**：

1. **RAM 版 vk40 刷 b 槽**做首次 bring-up（仍无条件起 USB-NCM + SSH `192.168.7.1`，足够 dump GPT / 手术 / 恢复 rootfs）→ 确认已读 `rootfs/init`：usb-gadget/sshd 不受 `on_initramfs` 限制。
2. b 槽原厂分区用 **`fastboot fetch`** 只读备份（fastboot 36 支持）。
3. GPT dump 用新 `scripts/gpt-dump.sh`（4096B 扇区，主表 LBA0..5、备表 `backup_lba-4..backup_lba`；已用旧机 dump 验证 `od` 解出 `backup_lba=61390847` 正确）。
4. 手术脚本**已按实际 GPT 参数化**，512G 只需现 dump（`--linux-gib 128` 建议）。
5. 固化为 b 槽持久直启 → 改内核不再需要 fastboot。

顺带修了 `scripts/build-boot.sh`：`ROOTARGS` 改用 `${ROOTARGS-…}`，支持显式空值 = 纯 RAM 镜像。

## sudo 清单（未变）
- **建议**：`sudo bash scripts/fix-fstab-samsung.sh`（唯一遗留）。
- 实测 **avbtool 签名无需 pycryptodome**（本机已能签出 `boot_b_vk40`），其余可选包都不是必需。

## 请你拍板（到货当天用）
1. **Linux 分区大小**：128 GiB（建议）还是更大？
2. **a 槽 Android 保不保**：要保则手术后需 `fastboot erase userdata` 重建 `/data`（约 300G+）；纯 Linux 可跳过。
3. 目标：到 RAM 验收（Phase 2）还是走到持久 Linux + Waydroid（Phase 5）？

细节全在 `BRINGUP-NEW-TABLET-2026-10-02.md`。


## Automatic settled outcome - 2026-10-02

分析完成，已作为 **§9 结合本地研发流程与现有资源** 追加进 `ARM-VIRT-RESEARCH-2026-10-02.md`（INDEX 已更新）。核心结论如下。

## 最重要的发现：核心资产我们**已经握有**，不用下载

从本项目自己的 **stock ROM 备份**（`/mnt/Samsung/l2/system_a.pristine.img`，经 `debugfs` 无 sudo 确认 = `TB322FC_…_259`, **Android 16**）里，离线提取出了 `com.android.virt.apex`（87.8 MB），内含：

| 组件 | 证据 |
|---|---|
| `bin/crosvm` 10.7 MB | strings 出 `hypervisor/src/gunyah/*`、`HypervisorKind::Gunyah`、`qcom_trusted_vm_id/pas_id` |
| `bin/vm` 1.2 MB | `run`/`run-microdroid`/`console`/`list`/`info`，VmConfig 字段与 AOSP 文档一致 |
| `microdroid_kernel` 12.2 MB (`6.6.77-android15`) + initrd | guest 内核/initrd |
| `u-boot.bin` 719 KB | U-Boot 启动路径 |
| `virtualizationservice`/`virtmgr`/`vmnic`… | AVF 服务 |

**这意味着 DroidVM/Podroid 只是 APK 封装**；底层 `crosvm`+`vm` 我们自有（polygraphene 才需要从 Release 下 `crosvm-a16`）。我们要补的只有 **guest rootfs + guest 内核 + 磁盘工具**。

## 与本地流程的契合点

- **双槽策略天然对齐**：D 轨只动 **a 槽 stock Android**、不碰 b 槽 mainline，与 `BRINGUP-NEW-TABLET`「全程不动 a 槽/绝不动安全鞋」一致；最坏 guest 崩，不动 hyp/XBL/GPT。
- **A 轨可预置**：下 Debian nocloud rootfs、按 `microdroid_defconfig` 思路编带 `CONFIG_DMA_RESTRICT_POOL` 的 guest 内核、装 `qemu-utils` —— 全在主机。
- **任务制可套用**：建议新增与 F0–F5 解耦的 **「D 轨」**，拆 `task-14` 只读勘察 → `task-15` microdroid 最小 VM → `task-16` Debian guest → `task-17` DroidVM APK 实测；沿用「worker 只报原始日志、编排者独立复跑」。
- **坑已归档**：`ulimit -l unlimited`、SWIOTLB、RM/mTHP、8 Elite 免 pvmfw、图形最不确定。

## 差距（都不阻塞）

- 本地 AOSP 树是 **Lineage 20 / AOSP 13**，`external/crosvm` **只有 KVM 无 Gunyah** → 仅参考，不能直接搬。
- 主机缺 `qemu-img`/`virt-resize`/`pycryptodome`；guest rootfs/kernel 待备。
- 设备侧需 root（旧机 a 槽已有 KSU；新机 a 槽待定）。

## 需你拍板（决定 D 轨落在哪台）

1. **新机 vs 旧机角色**：新机做 mainline 主力、旧机当 Android VM 宿主？还是新机双系统都上？
2. **新机 a 槽是否保 stock Android 安全网**（若保，D 轨可跑在其上或旧机）。
3. D 轨是否立项（我建议**先手动 `vm run` 最小验证**，再考虑 DroidVM APK）。

只要你选定设备角色，我就可以按 A 轨把 guest 镜像/内核在主机侧备好，等设备上线做只读勘察。


## Automatic settled outcome - 2026-10-02

路线决定已落盘 `ROUTE-DECISION-2026-10-02.md`（INDEX/PLAN-NODEV 已登记）。核心如下。

## 决定：两轨分机（不是替代）

| | **新机 16+512** | **旧机 12+256** |
|---|---|---|
| a 槽 | stock Android 安全网（手术后重建 /data，暂不 root） | stock Android **已 root** → **D 轨宿主** |
| b 槽 | **mainline Linux**（接力主线） | stock（备用） |
| 用途 | Waydroid / 桌面 / 相机 / 音频 / 基准 / Win-x86 | Android 日常 + **AVF/Gunyah 真 VM** |

## 为什么（正反各一遍）
- **旧机做 D 轨** ✅：root 现成（SUSFS/KSU）、`/data` 211G、ROM 就是 AVF 资产来源机（`com.android.virt.apex` 已提取）；与新机主线**互不抢设备锁**。
- **新机做 D 轨** ❌：① 与「GPT 手术要 `erase userdata`」冲突；② 一机双轨抢设备锁；③ 新机 a 槽还要额外 root。收益全无。

## 合并后的资产/冲突收口
- **Waydroid 留在新机 mainline**（Mesa 26.1.8 就绪）→ 不变。
- **Win-x86 留新机**；DroidVM 的 Windows 是另一路线，并列比较。
- **新机 BRINGUP 无需改**（本就"只动 b 槽、a 槽保安全网"），且 D 轨跑旧机 → **两轨可真正并行**。
- `stock-src` 无 `drivers/virt/gunyah`、AOSP 树 crosvm 无 Gunyah → 再次坐实**主线移植路线放弃、走 Android 侧**。

## D 轨任务拆解（task-14…17，操作对象=旧机）
14 只读勘察 → 15 最小 headless VM（microdroid）→ 16 Debian guest → 17 DroidVM APK 实测。均为用户态，风险面不碰 hyp/XBL/ABL/GPT。

## 待你确认（3 条）
1. **设备角色**是否按上表（新机=mainline，旧机=Android+D 轨）？
2. **D 轨立项**，先走 **① 手动 `vm run` 最小验证** 还是直接 **② DroidVM APK**？（建议 ①→②）
3. 是否现在开始**主机 A 轨预置**：A11 下 Debian nocloud arm64 rootfs、A12 编带 `CONFIG_DMA_RESTRICT_POOL` 的 guest 内核（都不碰设备）；A13 的 `qemu-utils` 需你 sudo。


## Memory - 2026-10-02

y700-elden 任务定位（2026-10-02 用户重述，已落盘 MISSION-SCOPE.md 为总纲）：① 机型唯一 = TB322FC/elden/SM8750(P)，研究内容只有固件+驱动；② **同型号多台单元物理地位完全等价，唯一差异是容量（内存/UFS→GPT 数值）**，身份用 (SN, hwboardid, 容量) 记于 DEVICES.md，"新机/旧机"不是角色，任务按单元当前状态分派，原"两轨分机"决定作废（D 轨更名 G2-S2，task-14..17 → T5/T6）；③ 双目标：G1 = 功能健全的 Linux 且正常驱动原厂全部固件（8 条硬验收，缺口=音频听声/相机出流/TF卡/BT配对）；G2 = 最大化兼容安卓（四层并存：S0 两槽直启 Android / S1 Waydroid / S2 Android 侧 AVF-Gunyah VM / S3 denial-droidloom 观察），设计文档 ANDROID-COMPAT-PLAN.md。文件改名：BRINGUP-NEW-TABLET-2026-10-02.md → BRINGUP-UNIT-2026-10-02.md（设备无关+容量参数化 $SN/$CAP/$BLK/$BACKUP_LBA/$LINUX_GIB/$BAK）。备份目录规范 backup/<SN>-<容量档>/，禁用 new-tablet 命名；禁止跨容量档复用 GPT 二进制。


## Automatic settled outcome - 2026-10-02

文档集已按新定位整体重构。数字结论先给：

## 变更总账（12 个文件，3 新建 + 1 改名 + 8 修订）

| 动作 | 文件 | 核心内容 |
|---|---|---|
| **新建·总纲** | `MISSION-SCOPE.md` (194 行) | 机型唯一（TB322FC×SM8750P，只研究**固件+驱动**）/ **§2 设备等价原则** / **§3 G1 八条硬验收 + 固件清单 + 驱动缺口分级** / G2 入口 / 6 条决策原则 / **§7 术语统一** / **§8 被覆盖旧结论清单** |
| **新建·台账** | `DEVICES.md` | U1=`HA2ABH62` 12+256、U2=16+512；**容量差异参数表**（扇区 4096、`backup_lba`、`userdata`、建议 `linux17`）；按状态分派快照；命名规范 `backup/<SN>-<容量档>/` |
| **新建·G2 设计** | `ANDROID-COMPAT-PLAN.md` | 四层并存 **S0 两槽直启 / S1 Waydroid / S2 AVF-Gunyah VM / S3 观察** + 5 维兼容度打分 + **`elden-droid` 兼容层**（传感器注入、相机 `v4l2loopback` 共享、音频、身份伪装边界）+ 任务 **T1–T8** |
| **改名+改写** | `BRINGUP-NEW-TABLET-…` → **`BRINGUP-UNIT-2026-10-02.md`** | 新增 **§0.0 单元参数表**（`$SN/$CAP/$BLK/$SECTOR/$BACKUP_LBA/$LINUX_GIB/$BAK`）；命令里的 `backup/new-tablet/`→`$BAK`、`/dev/sda`→`$BLK`；GPT 校验改「读实际输出不预设」；Phase 2 验收并入 G1（含固件加载） |
| 修订 v2 | `ROUTE-DECISION-2026-10-02.md` | **「两轨分机」作废**（§2/§3/§7 重写为按状态分派）；技术结论保留；task-14…17 → **T5/T6** |
| 修订 | `PLAN-NODEV-2026-10-02.md` | 去掉「到货前/新机角色」框架；A11–A13 更名 G2-S2 预置；**新增 A14 传感器注入、A15 验收用例** |
| 加注 | `ARM-VIRT-RESEARCH-2026-10-02.md` | §9.4 D 轨→G2-S2 且不绑旧机；§9.6「角色先定」作废 |
| 重写入口 | `INDEX.md` | 新增 **§M 使命与范围（6 行）**；§0 现状改 G1/G2 口径 + U1 现状覆盖块（原 vk19/`sda17` 标为历史）；文档地图 +3 总纲文件、ROUTE-DECISION 标 ⚠️v2；§3 命令改 vk40 + 台账采集 + `gpt-dump.sh`；§4 优先级按目标重排 |
| 修订 | `AGENTS.md` | 开头改为机型唯一 + G1/G2 + **设备等价** + 术语规则；规则补「不跨单元复用 GPT / 先 `fetch` 备份 / 不动 a 槽 / 主线优先」 |
| 加导航 | `HANDOFF.md` | 顶部指向总纲/台账/兼容方案；§1 标注「本文的设备 = 台账 U1」 |
| 追加 | `PITFALLS.md` **#80/#81** | #80 把「第几台机器」当角色的三类代价；#81「状态才是前置条件」 |
| 记录 | `DOCS-CHANGELOG-2026-10-02.md` | 逐文件变更表 + 未改动的历史档案清单 + 遗留 3 项 |

## 新设定（写入所有入口）
1. **机型唯一**：只研究 TB322FC/elden/SM8750(P)；内容只有固件 + 驱动。
2. **设备等价**：同型号多台**物理地位完全等价**，唯一差异 = 容量（→ 仅 GPT 数值不同）。身份 = `(SN, hwboardid, 容量)`，**"新机/旧机"不是角色**，任务**按单元当前状态


## Memory - 2026-10-02

y700-elden 前提更新（2026-10-02 用户决定，已落盘六视角文档集）：① **a 槽 Android 可以不要**——G2 的目标正是"没有安卓时用 ARM Linux 侧参考社区资源完成安卓兼容"，主路线=容器（Waydroid，备胎 redroid），VM 因本机无 KVM（EL2 被签名 Gunyah 占）只作调研；回退靠 backup/stock-259 + EDL 全量包，不靠槽位常驻；覆盖 a 槽前必须先做"真 Android 对照取证"（属性/DRM 级别/传感器读数/App 行为），不可复得。② **Linux 分区容量不固定**，按项目体量估算后一次给足（估算表在 DEVICE.md §3），扩容首选回收 Android 专属分区（super_a/b 等），不是二次缩 userdata。③ **G2 边界不得预设结论**：容器可跑 GMS 有社区先例（redroid GMS via OpenGApps/MicroG/MindTheGapps；casualsnek/waydroid_script 有 gapps+Widevine L3+`certified` 未认证注册流程；WayDroid-ATV 内置 GApps+Widevine L3），故 Play Integrity/Widevine 一律记为待调查 GAPS Q1。④ 文档已按六视角合并：INDEX/DEVICE/TASKS/RESOURCES/GAPS/ANDROID-COMPAT + RUNBOOK-BRINGUP；旧文档进 archive/topics（41 个）与 archive/2026-10-02-merged（6 个）。


## Automatic settled outcome - 2026-10-02

三点前提更新已落地，文档按你要的六视角合并完成。

## 1. 前提更新（写进所有入口）

| 你的指示 | 落地方式 |
|---|---|
| **Linux 容量不固定，按项目体量决定** | `DEVICE.md` §3 新建**体量估算表**（rootfs 15–20 G / Waydroid 30–50 G / x86 chroot 10–15 G / 每 VM 镜像 20–60 G / 设备侧构建 25–40 G / 日志 5–15 G ⇒ **合计 105–180 G**）+ 4 条决策规则：**一次给足**（GPT 缩容不可逆，二次代价高）、可再生大对象留主机、**扩容首选回收 Android 专属分区**而不是二次缩 `userdata`。写死的 65/128 GiB 全部删除，改为 `LINUX_GIB` 变量 + GAPS Q7「上机后 `du` 实测回填」。 |
| **a 槽 Android 可以不要** | 目标形态改为「**b 槽 mainline 是唯一工作系统**」；回退从"槽位常驻"改为 `backup/stock-259/` + EDL 全量包（一次 EDL 可整机复原，非不可逆）。`RUNBOOK-BRINGUP.md` 新增 **Phase B：回收 `super_a/b`、`boot_a`、`recovery_a`、`metadata`… 腾数十~上百 GiB**，并列出**不可动清单**（xbl/abl/tz/hyp/modem/安全存列）。原「S0 两槽直启=100% 兼容下限」层级取消。 |
| **G2 边界不得立刻断言** | 改为**取证任务 C3**，并实际抓到了先例证据（见 §3）：`ANDROID-COMPAT.md` §1 的 C2「身份兼容」格一律填 **"待调查"**，不再是"只能 BASIC/L3"。 |

## 2. 文档合并（49 → 9 份活文档）

**根目录 9 份**：`INDEX.md`（入口+使命 6 行）· **`DEVICE.md`**（设备描述＋设备状态：规格/固件清单/驱动矩阵/单元台账/状态分派/GPT 参数/容量策略）· **`TASKS.md`**（任务拆解＋进度＋待办规划）· **`RESOURCES.md`**（参考资源＋本地资源）· **`GAPS.md`**（查漏补缺 Q1–Q12＋风险＋勾销规则）· **`ANDROID-COMPAT.md`**（G2 专项）· **`RUNBOOK-BRINGUP.md`**（上机手册）· `PITFALLS.md` · `AGENTS.md`。

**归档**：`archive/topics/`（43 个日期型专题文档＝过程证据，不再更新，引用路径已批量改写）＋ `archive/2026-10-02-merged/`（6 份被合并掉的原文：MISSION-SCOPE / DEVICES / ANDROID-COMPAT-PLAN / ROUTE-DECISION / PLAN-NODEV / DOCS-CHANGELOG）。引用完整性已脚本校验：除归档原文名与 AOSP `custom_vm.md` 外**无悬空引用**。

## 3. 社区先例取证（本轮直连 GitHub API 实测，代理 7897 仍故障）

| 项目 | 抓到的事实 | 意义 |
|---|---|---|
| `casualsnek/waydroid_script` 3.8k★ | 一键装 gapps/magisk/libndk/microg + **Widevine L3**；有 **`certified` 子命令**：打印 Android ID → `google.com/android/uncertified` 注册 → 清 GMS 缓存即登录 | **直接适用**，C3 首要复现对象 |
| `remote-android/redroid-doc` 6.9k★ | **arm64+amd64**，GMS 经 OpenGApps/MicroG/MindTheGapps；宿主需 `binder_linux`（**vk40 已开 `CONFIG_ANDROID_BINDERFS`**） | 定为 **R1'


## Automatic settled outcome - 2026-10-02

通读了 9 份活文档（INDEX/DEVICE/TASKS/GAPS/RESOURCES/ANDROID-COMPAT/RUNBOOK/PITFALLS/AGENTS），并做了实际核验：41 个归档引用、20+ 资产路径、config 快照、关键产物逐一对照。

**结论：引用完整性很好（无悬空引用、关键产物全在），但有 9 处不准确/过时（其中 2 处实质问题）、6 项待用户输入。**

## 一、不准确/过时（建议修）

| # | 问题 | 位置 | 核验结果 |
|---|---|---|---|
| 1 | **AVF 资产虚记（最重要）** | `RESOURCES.md` §2.2 | 声称已提取 `crosvm(10.7M 带 Gunyah)/vm/microdroid_kernel/u-boot.bin`，但全机 find（`~` + `/mnt/Samsung`）**找不到任何提取产物**——只有 AOSP 13 树里无 Gunyah 的 crosvm 源码。要么已丢，要么没拷回主机。U1 现仍是 stock+root，可重提取，应登记 GAPS |
| 2 | **`CONFIG_IP_ADVANCED_ROUTER` 并未进内核** | `GAPS.md` Q2、`TASKS.md` C1 | Q2 写"已进内核”；实际 `patches/config-vk40-bringup` 是 `not set`（vk20/vk26/bak 同样未开）。Waydroid 真正需要的 iptables/NAT（`IP_NF_FILTER/NAT`、`NF_NAT_MASQ`、`XT_MATCH_COMMENT`）vk40 **已开** ✅，但 Q2 括号依据写反了 |
| 3 | **“在机 vk39”过时** | `INDEX.md` §3、`DEVICE.md` §1.1 | U1 已逆手术回 stock（b 槽原厂已刷回），当前无任何单元跑 mainline（`DEVICE.md` §2.3 自己也说“满足单元=暂无”）。应改为“最后一个在机基线（逆手术前）" |
| 4 | **qemu-utils 已装，3 处文档仍说“需 sudo"** | `TASKS.md` §0/A13、`GAPS.md` §3 | 实测 `/usr/bin/qemu-img`、`qemu-nbd` 已存在，应勾销 |
| 5 | **RUNBOOK 章节号重复** | `RUNBOOK-BRINGUP.md` | 两个 `## 7`（Phase 6 验证清单 + Phase B）、两个 `## 8`（回退 + 待你拍板）——合并编辑残留 |
| 6 | **RUNBOOK 残留旧容量口径** | `RUNBOOK-BRINGUP.md` §0.0 示例、§4 注释 | 示例 `LINUX_GIB=128`、注释“256 档 65；512 档 128" 与 `DEVICE.md` §3.2（512 档 160–200、256 档 64–96）矛盾；同文件表格和 DEVICE 是新口径，仅这两处是旧的 |
| 7 | **C2/C3 顺序矛盾** | `INDEX.md` §3 vs `TASKS.md` §4 | INDEX："C1→C2 登录→C3 取证”；TASKS："C1→C3→C2"（TASKS 合理：先取证再动配置） |
| 8 | 旧编号/默认值残留 | `RUNBOOK` §7 "bench-run.sh（A7）"（A7=已作废编号，现 G1-8）；`scripts/flash-b.sh` 默认仍 `vk13`；`PITFALLS.md` 头部"最后更新 2026-09-29"（实含 #80/#81=10-02） | 小 |
| 9 | 单位混用 | RESOURCES/DEVICE "3.44 GB"（实测=3.21 GiB ✅）vs RUNBOOK "3.3G" | 数字都对，建议统一写法 |

## 二、未完成/待用户输入（文档已登记，点名确认）

- **U2 到货状态未登记**：`DEVICE.md` §2.2 台账 U2 “待登记”，但 G1-1（当前关键路径）依赖 U2——U2 到了吗？
- **A18** `


## Automatic settled outcome - 2026-10-02

9 处全部修复并验证完毕。

## 修复总账（8 个文件）

| # | 问题 | 修法 | 验证 |
|---|---|---|---|
| 1 | **AVF 资产虚记** | `RESOURCES.md` §2.2 改为"⛔ 原记虚记，主机无产物"；新增 **GAPS Q13**（含重提取命令：`pm path com.android.virt` → 解 apex_payload → scp 回主机，随 C0 同批） | ✅ |
| 2 | `CONFIG_IP_ADVANCED_ROUTER` 口径反了 | `GAPS.md` Q2 改为"vk40 已开 iptables/NAT ✅；ADVANCED_ROUTER 仍 not set，若需策略路由再补" | ✅ |
| 3 | "在机 vk39"过时 | `INDEX.md` §3、`DEVICE.md` §1.1 改为"**当前无单元在机 mainline**（最后在机基线 vk39，U1 已逆手术回 stock）" | ✅ |
| 4 | qemu-utils 已装 | `TASKS.md` §0/A13、`GAPS.md` §3、`RESOURCES.md` §2.1 四处改 ✅（`qemu-img`/`qemu-nbd` 在位） | ✅ |
| 5 | RUNBOOK 章节号重复 | Phase B → **§9**、待你拍板 → **§10**，头部"见 §7”同步改 §9；章节序列 0.0/0/1…8/9/10 无重复 | ✅ |
| 6 | 残留旧容量口径 | §0.0 示例 `LINUX_GIB=128` → 占位符“按 DEVICE.md §3.2 一次给足"；§4 注释 → "256G 档 64–96；512G 档 160–200" | ✅ |
| 7 | C2/C3 顺序矛盾 | `INDEX.md` §3 改为"C1 → C3 → C2"，与 TASKS §4 对齐 | ✅ |
| 8 | 旧编号/默认值 | RUNBOOK "（A7）"→"（G1-8）"；`flash-b.sh` 默认 vk13→**vk40**；`PITFALLS.md` 头部 → 2026-10-02 | ✅ |
| 9 | 单位统一 | RUNBOOK "3.3G" → "3.44 GB"（全库现统一 3.44 GB） | ✅ |

**A18（/mnt/Samsung fstab）**：已按要求在 `TASKS.md`、`GAPS.md` §3、`RESOURCES.md` §2.1 三处标记 ✅ 完成（2026-10-02）。

**剩余待你输入的 4 项**（文档已登记，无阻塞改动）：
1. **U2 到货状态** → 回填 `DEVICE.md` §2.2 台账（G1-1 关键路径依赖它）
2. **C0 真机取证 + AVF 重提取（Q13）**：趁 U1 还在 stock+root，覆盖 a 槽前做，不可复得
3. **C2 上行 + 代理 + 谷歌凭据**
4. **`LINUX_GIB` 具体值**：U2 上机 `du` 实测后定（GAPS Q7）


## Automatic settled outcome - 2026-10-02

**不是 PC 意义上的 UEFI 启动，但底层借用了 UEFI 技术。**

- **启动链**：PBL → **XBL**（高通基于 EDK II/UEFI 实现的引导固件）→ **ABL**（一个 UEFI 应用，负责 fastboot + AVB 校验）→ 加载 `boot`/`dtbo`（Android boot image + 设备树）。
- **有 UEFI 痕迹**：分区表里有 `uefi` 分区（UEFI 变量），XBL 日志在 `logfs`（`UefiLog1.txt`）——本机 PITFALLS 里就用它排过 dtbo 校验失败。
- **不是标准 UEFI**：没有 ESP 分区、没有 Boot#### 启动项/UEFI 启动管理器、不给 OS 导出 Boot Services、无 ACPI（mainline 走设备树）。启动路径是固定的 Android/AVB 链，ABL 只是“长得像 UEFI 程序”的加载器。
- 社区跑 Linux 的做法通常是把 **U-Boot 当 EFI 应用链在 ABL 后面**，用它模拟出标准 UEFI 环境再引导 GRUB/内核——即“标准 UEFI”是后装的，不是原厂的。


## Automatic settled outcome - 2026-10-02

已落盘 `RESOURCES.md` §1.2（+3 行：postmarketOS 主流做法注记、Linaro U-Boot 链入、edk2-msm）。

**一句话回答**：UEFI 只在启动那几秒经过（XBL→ABL），不提供任何运行时服务；G1 要驱动全部固件走的是 Linux remoteproc + TrustZone PAS + 原厂签名固件，**与 UEFI 解耦，不需要做任何事**。U-Boot 链入是社区可选增强（GRUB/启动菜单/TF 卡引导/突破 96 MiB boot.img 限制），已记为观察项——只有将来需要启动管理器时才评估。


## Memory - 2026-10-02

主线 ARM 社区命名陷阱（2026-10-02 调查时差点误判）：Qualcomm 补丁系列里的 **kodiak = QCM6490**（sc7280 家族 dev kit：qcm6490-idp/qcs6490-rb3gen2），**不是 SM8750**；SM8750 的 vendor 代号是 Kera/KeraP（DT 名 "Qualcomm Kera SoC"）。kodiak-el2.dtso 等 `-el2.dtb` overlay 系列（v11 2026-08）只适用 Qualcomm dev kit 的 EL2 引导，不适用消费者 Y700（XBL 在 secure-boot 链内加载 hyp，加载点在 ABL 上一级）。另：本地 7.2 内核树无 drivers/virt/gunyah（主线独立 gunyah 驱动未合入），但 drivers/watchdog/gunyah_wdt.c + qcom_scm.c 的 gunyah UUID 探测在；CONFIG_DMA_RESTRICTED_POOL=y 已开。


## Automatic settled outcome - 2026-10-02

纯调查 4 项全部完成（不占设备，全部落盘）。**数字结论：新增/更新 4 份文档 + 存 1 条记忆；G2 完成度 35% → 40%；1 个结论被证据维持，1 个结论被修正。**

## 本轮成果

| # | 调查项 | 结论 | 落盘位置 |
|---|---|---|---|
| 1 | **C8/Q4 — VM 路线书面评估** | **维持低优先、不立项**：① 设备侧 KVM 不可达（XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 模式只适用 Qualcomm **dev kit**，ABL 重签救不了——hyp 加载点在 ABL 上一级）；② 独立 gunyah 驱动（v17）未进主线（本地 7.2 树 `drivers/virt/` 无 gunyah 目录）；③ **唯一新路线 = KVM-in-EL1 + Gunyah backend**（Linaro RFC 00/34，2025-04，配 `qemu-for-gunyah`，WIP：pinned pages/无 guest_memfd/禁 swap）——需数周 port 且 SM8750 固件 ABI 兼容性未验证。**决定性零成本实验**：vk40 上机后 `dmesg \| grep -i gunyah`（本地 qcom_scm 已带 UUID 探测） | `TASKS.md` C8、`GAPS.md` Q4、`ANDROID-COMPAT.md` R2、`RESOURCES.md` **新增 §1.5** |
| 2 | **Q3 — droidloom 可行性** | **结论修正**：repo（denialwm/droidloom，251★活跃）声称支持 arm64 平台，但**预览包只发 x86_64 Arch**；INSTALL 的"experimental ARM64"指 x86 上跑 ARM64 APK（翻译层）。arm64 宿主 = 自构建一条命令（Rust+rootless podman+AOSP pin），但 pacman 包格式需适配本 rootfs。对 ARM64 设备反而更简单（应用原生跑、无需翻译）。剩 2 个未知：arm64 自构建是否干净、freedreno+Phosh 下 GPU/输入路径 | `GAPS.md` Q3、`ANDROID-COMPAT.md` R3、`RESOURCES.md` §1.3 |
| 3 | **Q1/C3 社区侧补充** | WayDroid-ATV **有 arm64 GAPPS 镜像**（2026-01 SourceForge，可作 C2 第二镜像源）但 **Widevine L3 仍仅 x86-64**；官方 licensing 页明确 GApps/Widevine 受限、建议开源替代；PlayIntegrityFork(pif.json) 仍是主流过 PI 手段（v18 在手）；L1 需芯片商+GMS 认证，**L3 是默认必测项不需额外申请** | `GAPS.md` Q1、`RESOURCES.md` §1.3 |
| 4 | **C9/A15 — 验收用例集** | **定稿 10 条用例+阈值**（Play 登录/安装/地图旋转/视频通话/流媒体/游戏/相机/音频/多窗口/休眠唤醒+切槽），含 5 维打分口径与依赖列 | `ANDROID-COMPAT.md` **新增 §5**、`GAPS.md` Q6 勾销、`TASKS.md` A15 ✅ |

## 顺带核验的本地事实（已记账）

- `CONFIG_DMA_RESTRICTED_POOL=y` **vk40 已开**（protected VM guest 前置，A12 部分预置）✅
- Gunyah watchdog 补丁系列的实测平台就是 SM8750（2026-05 邮件列表原文）——印证设备 Gunyah 生态与主线关注点对齐
- 差点误判并防住：**kodiak = QCM6490 ≠ SM8750**（SM8750 = Kera/KeraP），已存记忆

## 剩余需设备/你的输入（不变）

U2 台账登记 → C0 真机取证（含 AVF 重提取 Q13）→ 


## Automatic settled outcome - 2026-10-03

全部完成。**数字结论：A14/A17 两项落地 + C4 前提重大修正（uinput 方案作废→UDP HAL 真实现）；新增 7 个文件、编译 1 个 HAL；G2 40% → 45%。**

## 本轮成果

### C4 前提修正（本轮最重要的发现）

| 发现 | 证据 |
|---|---|
| **uinput 方案作废**：Waydroid 传感器 HAL 是 stub，不读 evdev | 镜像里 service=16KB stub（`waydroid.stub_sensors_hal`）；上游 `Sensors.cpp` 的 `getSensorsList` 返回**空** |
| **stub prop 不能复用** | framework 0027 补丁见 `waydroid.stub_sensors_hal=true` 会默认锁旋转 |
| **真值通路改 UDP 直达** | 容器经 waydroid0 网桥与宿主互通，无共享文件系统问题 |

### A14 — 传感器链（✅ 代码全就绪，待上机部署）

| 产物 | 状态 |
|---|---|
| `scripts/eldroid-sensord.c`（数据源 daemon：fake/stdin→UDP） | ✅ selftest **7/7**；UDP 环回冒烟 3s/96 行 |
| `scripts/build-sensord.sh`（native + aarch64 static） | ✅ |
| `scripts/deploy-sensors-hal.sh`（Waydroid **overlay** 部署，不改 vendor.img） | ✅ 语法 OK |
| `env-pass/scripts/sensor-send-termux.sh`（真值来源：另一单元 Termux:API 转发） | ✅ 管道冒烟通过 |
| **HAL 真实现**（waydroid-build 树 `Sensors.cpp`：UDP 收值→喂 framework，5 传感器） | ✅ **编译成功 32s**（产物 25KB）；原文件备份 `*.orig` |

### A17 — env-pass provision（✅）

`env-pass/scripts/envpass-provision.sh`：**状态预检**（TB322FC 系+root，不绑 SN）→ 产物缺失**自动 repack** → 推送**读回校验** → 幂等执行；`--check` 干跑通过。`envpass-ondevice.sh` 同步幂等化（已装模块跳过 + Shamiko **-patched 优先**——避开 KSU 版本校验 abort 坑）。

### 文档更新（6 处）

`TASKS.md`（A14/A17 ✅、C4 重定义）、`ANDROID-COMPAT.md` §2①（UDP HAL 替代 uinput）、`GAPS.md` **新增 Q14**（C4 上机三未知：容器 UDP 可达性/SELinux context/Termux 传感器名）、`RESOURCES.md`（新脚本+HAL 产物）、`INDEX.md`（G2 ≈45%）、新增证据文件 `archive/topics/SENSORS-WAYDROID-STUB-2026-10-03.md`。

## 剩余需设备/你的输入（不变）

U2 台账登记 → C0 真机取证（含 AVF 重提取）→ G1-1…3 上机 → C4 部署验证（`deploy-sensors-hal.sh --restart`）→ C2 上行+凭据。


## Memory - 2026-10-03

联想拯救者 Y700 四代(TB322FC, ZUXOS)解锁 BL 唯一可行路径：官网 https://www.zui.com/iunlock 申请 sn.img（四代起官方改 ABL，传统强解/泄露 sn 全部失效）。申请表需 SN(8位=ro.serialno) + ZUX OS 特有的 Bootloader_SN=`getprop ro.boot.bootload_sn`(64位hex)；1 账号/年 3 台限额，Gmail 可能收不到附件；sn.img 一机一码但可重复使用。命令：`fastboot flash unlock sn.img`（by-name 里无 unlock 分区属正常，ABL 特殊处理）→ `fastboot oem unlock-go` → 屏上音量键选 UNLOCK+电源确认 → 自动擦数据 3–5 分钟。不可逆代价：保修、FOTA、Widevine L1→L3（先 `getprop sys.lenovo.widevine_security_level` 拍基线）。免解锁重签包只给 root 不给 fastboot 写权限，做不了需要 flash/boot 的主线项目。新版(1.5/Android16)有屏蔽解锁指令先例，失败则 EDL 降级旧版再解。


## Automatic settled outcome - 2026-10-03

已完成核验 + 取证 + 文档落盘。先给数字结论：

## 数字结论
- **当前在机单元 = U2**：SN `HA2EXB0E`、`ro.boot.hwboardid=SM8750P_16+512_13`（正是台账预期的 16+512）、`df /data`=450 G、ZUXOS **1.5.10.259**（Android 16，patch 2026-05-05）。
- **锁状态 = locked**：`flash.locked=1`、`vbmeta.device_state=locked`、`verifiedbootstate=green`、**Widevine=L1**。
- **U2 是全项目唯一 locked 单元**（U1 已解）→ 解锁动作不可逆项必须**先拍证**，已拍完（10 个文件 + SHA256SUMS）。

## 解锁方法（四代唯一可行路径；过往 skill 已核实并补注）
四代起官方改了 `abl`，**传统强解/泄露 sn 法全部失效**；`1.5.10.259免解锁重签.zip` 只给 root 不给 flash 权限 → 做不了 G1（要 `fastboot boot/flash`）。唯一通道 = **官网申请一机一码的 `sn.img`**：

**① 申请（需要你，助手不能代办：账号+邮箱）** — https://www.zui.com/iunlock （已实测可直连）
| 表单项 | 值 |
|---|---|
| 序列号 SN | `HA2EXB0E` |
| Bootloader_SN（ZUXOS 必填） | `EBC74CD1B224948C1FCD6511E393324757633D4B859984878EDB81E26975502E` |

大陆邮箱（Gmail 收不到附件）；1 账号/年 3 台；sn.img **一机一码但可永久复用**。

**② 解锁（你按键；命令逐条，勿批量——PITFALLS #1）**
```bash
cd ~/y700-elden && mv ~/下载/sn.img backup/HA2EXB0E-16+512/ && adb -s HA2EXB0E reboot bootloader
fastboot getvar all | grep -iE "serialno|unlocked|secure|product"   # 期望 DEVICE STATE - locked
fastboot flash unlock backup/HA2EXB0E-16+512/sn.img                 # by-name 里没有 unlock 分区 = 正常(ABL 特判)
fastboot oem unlock-go                                              # 屏上音量键选 UNLOCK，电源键确认
```
自动重启 + 擦除全部数据，**3–5 分钟勿拔线**。或直接 `SN_EXPECT=HA2EXB0E scripts/bl-unlock.sh <sn.img>`（已内置 SN 比对，防刷错机）。

**③ 校验**：`fastboot getvar unlocked`=yes → `flash.locked`=0、`verifiedbootstate`=orange。

## 已知风险（须你知悉，均已登记）
1. **Widevine L1 → 大概


## Automatic settled outcome - 2026-10-03

接着上次被切断处补完（内容已全部落盘，无需重跑）：

## 已知风险（续）
1. **Widevine L1 → L3 大概率不可逆**（TEE 内密钥）。U2 是唯一 locked 单元，解锁前基线已拍：`sys.lenovo.widevine_security_level=L1` 存于 `backup/HA2EXB0E-16+512/pre-unlock/key-props.txt` → 这是 G2 的 Q1（容器 DRM 上限）与 Q5（真机对照）的「标准答案」，事后无法复得。
2. **保修失效 + FOTA 不可用**（官方免责条款；本项目不吃 OTA，影响=少一条升级退路）。
3. **1.5.10.259 可能屏蔽解锁指令**（社区已知风险，Q16）：若 `flash unlock` 报 unsupported / 无响应 → 按 `RUNBOOK-BRINGUP.md` §0.5 ⑤ 用现成 `restore-259/` + `qdl/build/qdl` + `xbl_s_devprg_ns.melf` EDL 降级旧版 ZUXOS 再解，**不额外下载**；不推荐第三方付费"秒解"。
4. 解锁**只写 unlock 标志 + 擦 `/data`**，a 槽系统与 `abl` 内容不变 → 不影响 Phase 0–3；root 需重做（走 `env-pass/`）。
5. 操作前置：电量 ≥50%、原装线、开发者选项里 **OEM 解锁** 开关打开（若存在）。

## 本轮落盘（6 处文档 + 2 个脚本 + 1 份取证）
| 位置 | 内容 |
|---|---|
| `RUNBOOK-BRINGUP.md` **新增 §0.5 Phase −1** | 解锁全流程 5 步（取证→申请→解锁→校验→被屏蔽时的降级退路）；`§0.0` 参数表加 U2 SN/CAP/锁状态 |
| `scripts/bl-preunlock-evidence.sh`（新） | 设备无关：读实际 `hwboardid` 定备份目录、纯 adb 只读采集、打印申请表两项。已跑通 |
| `scripts/bl-unlock.sh`（新） | 校 SN（`SN_EXPECT` 不符即拒）→ `getvar all` 存档 → 确认提示 → `flash unlock` → `oem unlock-go` 逐条执行 |
| `backup/HA2EXB0E-16+512/pre-unlock/`（新） | getprop 全量(1047 行)/by-name 119 项/传感器清单/settings/packages/key-props + `SHA256SUMS` |
| `DEVICE.md` §2.2/§2.3/§2.5 | U2 台账登记（SN、`SM8750P_16+512_13`、locked、L1），状态表新增「原厂未动+BL locked」行 |
| `TASKS.md` §1/§4 | 新增 **G1-0 = U2 BL 解锁（前置门）**，G1-1 要求改为「U2 已解锁」；下一步顺序改为 G1-0 与 C0 并行 |
| `GAPS.md` | 新增 **Q15**（不可逆代价+已拍基线）、**Q16**（新版屏蔽解锁→降级退路）；风险登记 +2 行 |
| `PITFALLS.md` #82 | 四代解锁唯一通道、`unlock` 分区不存在属正常、免解锁包不满足 G1、L1 不可逆、降级退路 |
| `RESOURCES.md` §1.1/§2.1 | 官方入口 + 两篇教程（已消化，付费服务不用）+ 新脚本与取证目录 |
| `.pi/skills/gsi-device-adaptation/references/tb322fc-zuxos-ota-root.md` | 第 7 条补注（`bootload_sn` 形态、by-name 无 unlock 分区、L1 不可逆、sn.img 可复用） |
| 全局 profile_memory | 存了一条跨项目可复用的「联想四代解锁 BL」条目 |

## 现在等你的两个动作
1. **申请 sn.img**（账号/邮箱类，我不代办）→ 到手后放 `backup/


## Memory - 2026-10-03

联想 Y700 四代(TB322FC)解锁 BL —— 更正「官网申请 sn.img 是唯一路径」的说法：① AVB 镜像链用的是谷歌公开的 AOSP testkey（avbtool info_image 实测原厂 vbmeta/boot/recovery pubkey sha1=2597c218…），自签镜像本就被 ABL 认可；② 解锁标志链用 Lenovo 自签证书(serial 804940DE79164B1A, RSA-2048, 非谷歌 key)，但解锁 blob 是**通用模板**：SN 明文在偏移 0x2048、签名只覆盖前 0x1000，四代的校验字段是模板内 `Bootloader_SN Part1+Part2`(=本机 ro.boot.bootload_sn 两段 32 hex) ⇒ 改 hex 即可**自制**解锁文件，属"免签"而非"自签"；③ EDL(qdl) 写分区不看 lock 位 ⇒ 需要 fastboot/刷机的项目**不必先解锁**。失败特征串 `Download is not allowed on locked devices` = ABL 较新，先降级。教训：下"唯一路径"结论前先 grep 本项目 skill 与本地工具包实物。


## Automatic settled outcome - 2026-10-03

文档已按你的更正改口完毕（未实现任何脚本）。

## 数字结论
**你的说法一半成立、一半需修正**——关键是两条链要分开：

| 链 | 实测签名密钥 | 能自己做吗 |
|---|---|---|
| **AVB 镜像链**（`vbmeta`/`boot`/`recovery`） | **谷歌公开的 AOSP testkey**，pubkey sha1 `2597c218…`（`tools/avbtool.py info_image` 打原厂 259 备份实测；`recovery`/`vbmeta_system` 的 chain 是 OEM key `8fcb864f`） | ✅ **成立**。自签镜像本就被 ABL 认可——我们 `bootslot-b/` 一直这么干 |
| **BL 解锁标志**（`flash unlock` 的 blob） | **Lenovo 自签证书** serial `804940DE79164B1A`、`C=CN/ST=BEIJING/L=Lenovo/O=Android/OU=PAD`、RSA-2048、2020→2047（modulus sha256 `3a12b26b`，与 AOSP build testkey `b446c577`、avb testkey2048 `f6e43242` 均**不同**） | ✅ **但机制不是「自己签」而是「免签」**：模板通用，改 hex 即可 |

## 两条实物证据（本地已有，没下载东西）
1. **`y700四代工具/解BL/Y700 三代解锁工具箱by某贼.zip` → `bin/res/sn.img`**（5386 B）：签名块在 `0x1000..0x150A`，内含 `PrintableString "/boot" + INTEGER 0x1000` ⇒ **签名只覆盖前 4 KiB**；工具箱只改**偏移 `0x2048` 的 8 字节 ASCII SN**（在覆盖范围外）→ 一份通杀模板，**不需要申请**。
2. **我先前漏读了本项目自己的记录**：`.pi/skills/qualcomm-edl-flashing/references/tb322fc-y700-gen4.md` 早已写着「sn.img = 官网申请 **or modify LoGen0110's sn.img template hex (Bootloader_SN Part1+Part2)** — must match own `bootload_sn`」，并给出失败特征串 `Download is not allowed on locked devices`。⇒ 四代自制的正确补丁字段是 **`Bootloader_SN` 两段 32 hex**（U2 = `EBC74CD1…6975502E`），比三代只改 SN 更贴 ABL 校验点。

## 最重要的一条：G1 不必卡在解锁上
`qdl` 走 EDL 写分区**不看 lock 位**，AVB 又是公开 testkey ⇒ **路 C（不解锁直写 b 槽）可让整个 G1 照跑**，Widevine L1、保修、FOTA 全保住。已登记为 **GAPS Q17**（首轮上机即可判定，可取代 G1-0）。

## 落盘（8 处）
| 文件 | 改动 |
|---|---|
| `archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md` | **新建**：结构表、证书身份、密钥比对表、§2.4 项目内既有结论、四路对照、A 路生成命令 |
| `RUNBOOK-BRINGUP.md` §0.5 | 「唯一路径」→ **A/B/C/D 四路表**（A1 改 SN / A2 改 Bootloader_SN → B 官网 → C EDL → D 重签包）+ A 路命令；⑤ 改为「不为解锁停摆，转 C」+ 失败特征串 |
| `PITFALLS.md` | #82 重写（两链两密钥 / 「必须先解锁」是错的）；**新增 #83**（自制补丁字段 = `Bootloader_SN Part1+Part2`） |
| `GAPS.md` | Q16 改为「三代模板法在四代是否有效（一发


## Automatic settled outcome - 2026-10-03

已做完本地取证。设备现在就在 fastboot 里（`unlocked:no` / `secure:yes` / `product:elden_prc_wifi`），我把结论和下一步给你。

## 数字结论
**文件本身是"对的那一种"，`flash unlock` 的 OKAY 不算证据，生效与否 = 下一条命令一发即判，且失败无损。**

| 检查项 | 结果 |
|---|---|
| 大小/格式 | **356 B**，四代新格式（不是三代 5386 B 的 PKCS#7 模板） |
| magic `0x00` | `1a2blenovo3c4d5e` |
| 头部 | u32 = `0/1/**256**/**32**/1` —— `256` 正好等于尾部签名长度、`32` = SN 每段 hex 长 ⇒ **结构自洽** |
| `Bootloader_SN` @`0x24` | `EBC74CD1…6975502E` — **与本机 `ro.boot.bootload_sn` 逐字节一致** ✅（说明是按 U2 现值签的，不是通用模板） |
| 签名 @`0x64` | 256 B = RSA-2048 |
| 离线验签 | 用三代模板内嵌的 Lenovo 证书（serial `804940DE79164B1A`，modulus `b7448bed…`）穷举 PKCS1/PSS × SHA1/256/384/512/MD5 × 9 种 payload —— **全部验不过**，恢复块无 PKCS#1 结构 ⇒ **签名密钥 ≠ 三代那把** |

## 三点判读
1. **你看到的 OKAY 什么也没证明。** `unlock` 在 by-name 里不存在（分区 size=0，ABL 特判缓冲），刷进去的是垃圾也是同样的 `Sending 'unlock' (0 KB) OKAY / Writing OKAY`。真正的验签发生在 `oem unlock-go`。
2. **四代 blob 里没有证书**（公钥烧在 ABL 内）⇒ 三代那把 key 验不过是**预期内**的（四代官方改过 `abl`），不等于无效；但也让我**无法离线确认**服务端真持有联想私钥。
3. **试的成本为零**：验签失败 → ABL 直接报错，**不擦机、不改锁状态**；验签成功 → 屏出 UNLOCK 菜单，还要你按键确认才擦 `/data`。双重闸门。

## 下一步（你执行，逐条）
```bash
cd /home/xuqianhui1001/y700-elden
fastboot -s HA2EXB0E flash unlock backup/HA2EXB0E-16+512/sn-neko-zuxos.img   # 已归档+SHA256 的那份
fastboot -s HA2EXB0E oem unlock-go        # ★判定行；屏上音量键选 UNLOCK，电源键确认
```
- 出现 UNLOCK 菜单 = **生效**；报 `Download is not allowed on locked devices` / `Unlock command not allowed` = **不生效**，停手转路 C（EDL，`qdl` 不看 lock 位，G1 不受影响），**别重复刷**。
- 报 OEM 解锁被禁用 → 回系统开「开发者选项 → OEM 解锁」再重来（不丢数据）。
- 按确认前想清楚：擦 `/data` 不可逆；Widevine **L1 基线已拍**（`backup/HA2EXB0E-16+512/pre-unlock/key-props.txt`），解锁后预期永久掉 L3。

## 落盘（6 处）
`archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md` **§5**（新格式结构表＋验签失败记录＋风险边界）· `RUNBOOK-BRINGUP.md` §0.5 新增**路 A3**（先试）+ ③ 加注「OKAY ≠ 生效」· `GAPS.md` **Q18** · `PITFALLS.md` **#84** · `RESOURCES.md` §1.1 服


## Memory - 2026-10-03

TB322FC locked 单元 b 槽 mainline 链（2026-10-03 管线落地）：联想原厂信任谷歌公开 AOSP testkey（env-pass/keys/testkey_rsa4096.pem 公钥 sha1 2597c218 = 原厂 vbmeta_a 顶层公钥），qdl EDL 写分区不看 lock 位 → locked 单元不解锁也能刷 b 槽 mainline。现有 bootslot-b 自造密钥链（fc1e3b33+flags3+rollback0）只适用 unlocked orange 宽容态，locked/green 过不了 root-of-trust。修法 = scripts/build-locked-chain.sh：从本单元 stock dump 自动读参数（boot rollback 1738713600 + 3 props；vbmeta flags=1 原厂自关 hashtree + 14 props）生成 testkey 全链（vbmeta_b 顶层 2597c218 + chain boot:3 + recovery:1/vbmeta_system:2 原样公钥）。avbtool 四坑：--chain_partition 要 .avbpubkey 非 PEM；AVB header 全字段大端；公钥 blob 偏移 = 256+auth_block+pub_off（漏加 auth_block 则 sha1 全错）；verify_image 加 --follow_chain_partitions。公钥提取工具 extract-avbpubkey.py（自动搜 AVB0 magic，支持裸 vbmeta 与 hash-footer 两种布局）。fastboot boot（RAM 兜底）locked 下不可用 → b 槽写入=真写盘，失败靠 EDL 恢复，a 槽 stock 原样不受影响。


## Automatic settled outcome - 2026-10-03

全部就绪。回答你的两个问题：

## 结论

**Q1：locked 下能否 AOSP 签名 + 9008 刷写？——能，且管线已建好、验证全绿。**

| 环节 | 结论 | 依据 |
|---|---|---|
| EDL 9008 读/写 | ✅ 与锁无关 | firehose 用官方签名 programmer（`xbl_s_devprg_ns.melf` 在手），锁只挡 ABL fastboot，不挡 EDL 裸写 |
| **AOSP testkey = 原厂受信密钥** | ✅ 实测确认 | `env-pass/keys/testkey_rsa4096.pem` 公钥 sha1 = `2597c218...` = 原厂 vbmeta_a 顶层公钥（联想确认谷歌公开密钥，眼见为实） |
| **现有 bootslot-b 链** | ⛔ **不适用 locked** | fc1e3b33 自造密钥 + flags3 + rollback0 只在 unlocked（orange 宽容）下能用；locked green 过不了 root-of-trust |
| **新管线（本轮建）** | ✅ 验证全绿 | `build-locked-chain.sh` 从 stock dump 自动读参数 → testkey 全链 → `avbtool verify --follow_chain_partitions` 全绿 |

原厂结构已从 U1 dump 复刻：vbmeta = testkey + **flags=1（原厂自己关 hashtree）** + rollback=0；boot footer = rollback **1738713600** + 3 条 props；**dtbo 无 descriptor**（只有 fingerprint prop → fake 4KB 全零 locked 下也能容忍）。

**Q2：先做 fastboot 能做的？——对，Phase 0 只读采集先行，而且 locked 下 fastboot boot（RAM 兜底）不可用，所以 b 槽写入=真写盘，必须先备份。**

## 操作序列（你执行，我出资产）

**Phase 0 — 只读采集（零风险，先做）**
```bash
cd ~/y700-elden
adb -s HA2EXB0E reboot bootloader
fastboot getvar all 2>&1 | tee backup/HA2EXB0E-16+512/getvar-locked.txt
fastboot fetch boot_b   backup/HA2EXB0E-16+512/stock/boot_b.img
fastboot fetch dtbo_b   backup/HA2EXB0E-16+512/stock/dtbo_b.img
fastboot fetch vbmeta_b backup/HA2EXB0E-16+512/stock/vbmeta_b.img
fastboot fetch vbmeta_system_b backup/HA2EXB0E-16+512/stock/vbmeta_system_b.img
```
（fetch 被拒就 `adb reboot edl` 走 EDL read，效果相同）

**Phase 1 — 我跑：生成 locked 链 + 核对 Q19 三未知**（U2 vbmeta_b 公钥/rollback 是否与 U1 一致）
```bash
scripts/build-locked-chain.sh out/boot-elden-vk40.img backup/HA2EXB0E-16+512/stock/{boot_b,vbmeta_b,vbmeta_system_b,recovery_b}.img --out bootslot-b-locked-HA2EXB0E
```

**Phase 2 — 你执行：EDL 写 b 槽三件套（只写 b！a 槽 stock 原样）+ 读回校验 + 启动**
```bash
adb -s HA2EXB0E reboot edl
qdl/build/qdl -s ufs ~/下载/


## Automatic settled outcome - 2026-10-03

Continue from where you left off.


## Automatic settled outcome - 2026-10-03

两个发现都核对完了，**你的解读要反过来看——那个输出恰恰说明刷进去了，而且这份文件是对的**。

## 1. `flash unlock` 的 OKAY 是预期行为，不是“找不到分区”

- `Warning: skip copying unlock image avb footer (unlock partition size: 0)` = GPT 的 by-name 里**本来就没有** unlock 分区（size=0，ABL 特判处理这条命令，blob 进的是特判缓冲，不是普通分区）——`PITFALLS` #82/#84 已记录，**属正常**。
- `OKAY/OKAY/Finished` = 传输和写入路径都走完了。但正如 #84 记的：**这行 OKAY 什么也没证明**——刷垃圾也是同样输出。真正的验签发生在下一条命令。

## 2. 你下的 sn.img = 另一轮已取证归档的那份（同一服务）

md5 完全一致（`3a7007a1...`）：lenovobl.neko.ink 就是 `sn-neko-zuxos.img` 的来源站点。那份 blob 的取证结论（`archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md` §5）：

| 检查项 | 结果 |
|---|---|
| 格式 | 356 B 四代新格式（magic `1a2blenovo3c4d5e`），不是三代 5386B 模板 |
| `Bootloader_SN` @0x24 | `EBC74CD1…6975502E` = **本机 `ro.boot.bootload_sn` 逐字节一致** ✅ |
| 签名 | 256 B RSA-2048；四代 ABL 内嵌公钥 ≠ 三代 key，离线验不过是**预期内** |

## 3. 下一步：一条命令判定（你执行，失败无损）

```bash
fastboot -s HA2EXB0E oem unlock-go        # ★判定行
```

- **屏上出 UNLOCK 确认菜单** = 生效 → 音量键选 UNLOCK、电源键确认（⚠ 擦 `/data`，Widevine L1 基线已拍）
- 报 `Download is not allowed on locked devices` / `Unlock command not allowed` = **不生效** → 停手，别重复刷，转下面的路 C
- 报 OEM 解锁被禁 → 回系统开「开发者选项 → OEM 解锁」再来（不丢数据）

## 4. fetch 被拒 → Q19 dump 转走 EDL read（零风险只读）

```bash
adb -s HA2EXB0E reboot edl
qdl/build/qdl -s ufs ~/下载/tb322fc/xbl_s_devprg_ns.melf read backup/HA2EXB0E-16+512/stock/boot_b.img 0x6000000
# vbmeta_b 0x10000 / dtbo_b 0x2000000 / vbmeta_system_b 0x10000 同理
# 读回后我来跑 build-locked-chain.sh（核对 Q19：U2 的 vbmeta_b 公钥/rollback 是否与 U1 一致）
```
（分区长度以 `gpt-dump`/by-name 表为准，上面是 U1 布局的期望值；你执行前我先把四条 read 的精确命令和长度整理给你。）

**顺序建议**：先跑 `oem unlock-go`（一发即判，成本为零）。出菜单 = 走解锁路（后面 fastboot 全通）；报错 = 停手告诉我输出，我整理 EDL read 四条命令 → 生成 locked 链 → 路 C 直写 b 槽（G1 不受影响）。


## Automatic settled outcome - 2026-10-03

我的命令给错了——qdl 的语法是 `read <地址> <文件>`（地址在前），address 支持**裸 GPT 分区名**（自动加载全 LUN GPT 表解析起止扇区，源码 `gpt_find_by_name` 已核实）。它把你给的第一参数（文件路径）当成了分区名去查，所以报 `no partition found`。

## 修正后的命令（四条 read，一次会话跑完）

```bash
cd ~/y700-elden
mkdir -p backup/HA2EXB0E-16+512/stock
qdl/build/qdl -s ufs ~/下载/tb322fc/xbl_s_devprg_ns.melf \
  read boot_b          backup/HA2EXB0E-16+512/stock/boot_b.img \
  read dtbo_b          backup/HA2EXB0E-16+512/stock/dtbo_b.img \
  read vbmeta_b        backup/HA2EXB0E-16+512/stock/vbmeta_b.img \
  read vbmeta_system_b backup/HA2EXB0E-16+512/stock/vbmeta_system_b.img \
  read recovery_b      backup/HA2EXB0E-16+512/stock/recovery_b.img
```

- 总量 ≈ 232 MiB（100+32+0.06+0.06+100），EDL 下几分钟
- 想逐条跑也行：每次 `qdl ... read <分区名> <输出文件>`（裸分区名，不带路径不带长度）
- 程序员（firehose）还驻留在设备上，重复调用会自动接上，不用重进 EDL

跑完我来做两件事：
1. `build-locked-chain.sh` 用 **U2 自己的 dump** 生成 locked 链（核对 Q19：U2 vbmeta_b 顶层公钥是否 = U1 的 8fcb864f、rollback 是否 = 1738713600）
2. `sha256sum` 读回校验 + 与 U1 同分区 diff（确认 b 槽原厂内容一致性）

## 顺带：`oem unlock-go` 还没跑

你上条只跑了 EDL read，还没回 fastboot 试判定行。**不急**——EDL 采集完、locked 链验证过之后，如果不想解锁可以直接走路 C；解锁 img 到手前后任何时候在 fastboot 里跑 `fastboot oem unlock-go` 都是一发判定（成功出菜单，失败零损失）。两条路不冲突，先看 EDL read 结果。


## Memory - 2026-10-03

联想拯救者平板 BL 解锁机制（2026-10-03 U2=TB322FC/HA2EXB0E 实测）：**1.5 高版本（如 1.5.10.259/Android16）堵死官方解锁通道**——第三方签名 sn.img 的 `fastboot flash unlock` 显示 OKAY 但 `oem unlock-go` 失败（四代 ABL 换了密钥，社区三代 blob 无效）；**线刷降级到出厂 1.1（TB322FU_ZUXOS_1.1.11.073，Android15）后直接 `fastboot oem unlock` 一次成功**，无需 sn.img（`getvar unlocked: yes`、`oem device-info: Device unlocked=true/critical unlocked=true`）。代价：解锁+降级都擦 /data、Widevine L1→L3。跨版本 AVB 参数不变：vbmeta 顶层/boot chain = AOSP testkey sha1 2597c218（私钥公开）、boot rollback 1738713600、vbmeta rollback 0。1.1 与 259 差异仅在 vbmeta flags（1.1=0）与 vbmeta_system chain key（1.1=cdbb7717）。本地 7/8 月记录早有预警（ROM基地："新版屏蔽解锁指令可回退旧版恢复"；"甜点位=1.1 终版+unlocked+Magisk"）。


## Memory - 2026-10-03

引导链类问题（BL 解锁/AVB 签名/固件降级/GPT/EDL）必须「先本地检索 → 再外部取证 → 最后自研」：技能 references/*.md 正文不进上下文，不 grep 等于不存在。y700-elden 案例：TB322FC 解锁的答案（版本门 = 仅 ≤1.1.11.073/.076 有解锁命令；1.1.11.120 是 trap；1.5.x 上任何 sn.img 全无效；正解 = 全量降级 073 后 `fastboot oem unlock`）在 2026-08 的记录里已完整写过且同型号已成功过一次，2026-10-03 仍在 1.5.10.259 上白试一轮第三方签名 blob。纪律：① 开场跑 grep -rn -iE "unlock|解锁|sn\.img|1\.1\.11\.|rollback|testkey|073|\.120" .pi/skills/*/references/*.md *.md archive/topics/*.md；② 命中即只做确认/推翻；③ 引用旧成功记录先查它属于哪台单元 + 当时固件/锁态；④ 动手前写下期望判据与停手特征串（如 `Download is not allowed on locked devices`；`flash unlock` 的 OKAY 不算判定行）。


## Automatic settled outcome - 2026-10-03

整理完成。**结论先行：解锁的答案 7、8 月记录里已完整存在，且同型号 U1 早在 2026-08-16 用这条路解成功过一次；10-03 白花的是"检索顺序"，不是"力气"。**

## 1. 本轮产出（1 份新复盘 + 11 处口径统一）

| 文件 | 改了什么 |
|---|---|
| **`archive/topics/复盘-2026-10-03-BL解锁.md`**（新，152 行） | 主交付：时间线+成本 → **7/8 月记录 ↔ 10-03 实测逐条对照表** → 要不要解锁判定框架 → 唯一权威流程 → 5 条根因 → 防复发机制 |
| `RUNBOOK-BRINGUP.md` §0.5 | 顶部新增 **★权威顺序（0→5）**：判版本门 → 拍基线 → 全量降级 073 → `oem unlock`（中间不重启）→ `unlock_critical` → 校验回填；A/A3/B/D 四条备选路**折进 `<details>` 并把"先试"改成 ⛔已判死/⚪仅旧固件** |
| `PITFALLS.md` | 新增 **#87**（技能 `references/` 正文不进上下文 ⇒ 不 grep 等于不存在；含开场 grep 命令 + 引用旧记录先查单元态） |
| `GAPS.md` | **Q16 / Q18 关闭**（三代模板、第三方 blob 在四代 1.5.x 均判死）；**Q17 降为可选**；**新增 Q20** 跟踪本流程病；风险行改「已发生 → 已解决」 |
| `TASKS.md` | G1-0 行补「已判死」；**§4 第 1 步从"先试 A3"改成 ✅已关闭 + 以后不再碰解锁** |
| `RESOURCES.md` | 签名服务 ⛔不再使用、官网入口 ⚪无需申请（避免下轮又当"当前最优"） |
| `INDEX.md` | §3 标"解锁议题已定稿，不要重新论证"；§4 加**动手前 30 秒 grep**；§6 加解锁专题行 |
| `AGENTS.md` | 新增规则：引导链问题「先本地检索 → 再外部取证 → 最后自研」 |
| `.pi/skills/qualcomm-edl-flashing/references/tb322fc-y700-gen4.md` | §version gates 顶部加 **TWICE-CONFIRMED（U1 08-16 / U2 10-03）** 块，让下次 grep 第一屏就命中 |
| `.pi/skills/gsi-device-adaptation/references/tb322fc-zuxos-ota-root.md` | 追加终局结论（1.5.x 上任何 sn.img 无效） |
| `scripts/bl-unlock.sh` | 头部加适用前提（未过版本门就别跑） |
| 全局 `profile_memory` | 跨项目教训一条 |

## 2. 8 月早已写明、10 月重新"发现"的三条

1. **版本门**：解锁命令只存在于 **≤ 1.1.11.073/.076**；`1.1.11.120` 是 trap（显成功但回滚）；1.5.x 通道被堵 → 原文明确写「**Do NOT attempt unlock from .120**」「Error `Download is not allowed on locked devices` = wrong/newer ABL → **downgrade first**」。
2. **实操序列**：8/16 U1 记录已含「LUN4 全量降到 073 → `flash unlock` → `oem unlock` → 音量下×2+电源 → `flashing unlock_critical`」+「**flash 与 oem unlock 之间不得重启**」+「stock 120 ABL 会让 `oem unlock-go` 返回 OKAY 但 `unlocked` 恒 no」。
3. **AVB = 公开 testkey `2597c218`**：8/10、8/17 两次记录都有，同时已写明「手动造 flags=2 disable vbmeta 在 CN ABL 上是死


## Automatic settled outcome - 2026-10-03

已按「先本地检索」把六视角文档与**实机 HA2EXB0E**逐条对过。下面是核对结果与路线确认。

## 1. 实机核对（刚跑，U2 当前在线 adb）

| 项 | 实机 | 文档（DEVICE §2.2 / RUNBOOK §0.0） | 判定 |
|---|---|---|---|
| BL 锁 | `flash.locked=0`、`verifiedbootstate=orange` | U2 已解锁 ✅（但 RUNBOOK §0.0 表仍写 `U2=1 locked`） | **文档部分过期** |
| 固件 | `ZUXOS_1.5.10.259_ST_260611`（内核 6.6.118，**a 槽**） | U2 = **1.1.11.073**（Android15） | **不一致，需你确认** |
| Widevine prop | `L1` | 预期 L1→L3 | 记录待复测（prop 静态值不等于实测级别） |
| 容量/GPT | `16+512_13`，`/data` 450G，**无 linux17** | U2 未手术 | 一致 ✅ |
| root | 无 su（shell） | U2 无 root | 一致 ✅ |

即：**U2 现在是「已解锁 + 原厂 259 完整系统」，不是文档写的 073**。这大概率就是你说的"情况更新"——如果是你手动刷回 259 的，请确认（a 槽 259 / b 槽是不是仍是 073？我这边不加设备操作只能看到运行槽 = a）。

主机侧资产齐全：`vk40{,-ram}.img`、`bootslot-b/`（vk40 持久+RAM+flags3 vbmeta）、`modules-*.tar.gz`、`camera-modules-*.tar.gz`、rootfs 归档 3.44 GB、EDL `qdl` + `xbl_s_devprg_ns.melf`、073 降级包都在。

## 2. 确认接下来的路线（TASKS §4，按当前真实状态校正）

**关键路径 = U2 首次上机（G1-1…3）**——设备已连、已解锁，`fastboot boot`/`fetch` 全通，正好走标准 RUNBOOK：

```
Phase 0 采集  → getvar all / gpt-dump（现 dump BACKUP_LBA，勿套 U1）
Phase 1 备份  → fastboot fetch boot_b/dtbo_b/vbmeta_b/vbmeta_system_b + GPT 双表
Phase 2 RAM   → fastboot boot out/boot-elden-vk40-ram.img（★零写盘验收，解锁后可用）
Phase 3 手术  → GPT 加 linux17（512 档建议 160–200 GiB，读本机 dump）
Phase 4 建分区 + 恢复 rootfs（3.44 GB 归档）
Phase 5 持久化 → b 槽直启 vk40 持久版
```
§0.5 解锁对 U2 **整段跳过**（已 unlocked）。

并行/前置于此（不冲突）：
1. **C0 真 Android 对照取证（U1，HA2ABH62）**——a 槽覆盖前唯一机会，U1 现在没连，建议在任何 GPT Phase B 之前抓一次。
2. G1-4 音频听声 / G1-5 相机出流（各需你 1 次现场确认）。
3. C1 → C3 → C2（Waydroid 复跑 → 身份/DRM 取证 → Play 登录）。

## 3. 需你拍板 / 我下一步

1. **U2 固件口径**：确认是"你已刷回 259 且保持 unlocked"吗？确认后我把 `DEVICE.md §2.2` 与 `RUNBOOK §0.0/§0.5` 的过期字段一并更正（顺带把已解锁状态写死，避免下轮又按 locked 走一遍）。
2. **是否现在就上机 U2**？你点头后我先出 **Phase 0 逐条命令**（只读、零风险），并把 `LINUX_GIB` 按 512 档定下来（建议 176 GiB 起步）。

要我先更正文档里的 U2 状态，还是先出 Phase 0 命令？


## Automatic settled outcome - 2026-10-03

明白。已按你的口径处理：**U2 = 259 + unlocked 为唯一事实**，上一轮 AI 留下的「073 / locked」条目按作废处理，相关待办不再执行。

## 已更正的文档（防下轮再按错态走）

| 文件 | 改法 |
|---|---|
| `DEVICE.md` §2.2 U2 行 | 固件 → `ZUXOS_1.5.10.259`（Android15/6.6.118，a 槽）；GPT → **无 `linux17`、施工时现 dump**；加「旧 073/locked 条目已作废」说明 |
| `RUNBOOK` §0.0 | `BL 锁` 行 → **U1=0、U2=0，§0.5 对两台均跳过** |
| `RUNBOOK` §0.5 顶部 | 加「当前状态：两台均已解锁，本节仅对新到货 locked 单元」 |
| `INDEX.md` §3 | U2 行 → 259 + unlocked + 无 `linux17` |
| `GAPS.md` Q15 / 风险行 | 「唯一 locked 单元」→ **两台均已解锁**；风险行注明 U2 现态已回 259 unlocked |

> 附带实测：U2 解锁后 `sys.lenovo.widevine_security_level` **仍报 L1**（不是预期的永久 L3）——prop 静态值≠实际 DRM 级别，`GAPS` Q1/Q5 的实测项保留待复测，**不预设结论**。
> `archive/topics/复盘-2026-10-03-BL解锁.md` 与技能里的解锁机制（版本门/降级路）**保留为已索引经验**，不删；删掉的只是"当前态"的过时待办。

## 确认接下来的路线（TASKS §4，按真实状态）

**关键路径 = U2 首次上机 G1-1…3**：设备已连（adb HA2EXB0E）、已解锁 → 可直接跑标准 RUNBOOK，且 `fastboot boot/fetch` 可用。

```
Phase 0  采集   : getvar all / gpt-dump（现 dump BACKUP_LBA，禁套 U1）
Phase 1  备份   : fetch boot_b/dtbo_b/vbmeta_b/vbmeta_system_b + GPT 双表
Phase 2  RAM    : fastboot boot out/boot-elden-vk40-ram.img   ★零写盘验收
Phase 3  手术   : GPT 加 linux17（512 档建议 160–200 GiB，读本机 dump）
Phase 4  建分区 : mkfs + 恢复 rootfs 归档（3.44 GB）
Phase 5  固化   : b 槽直启 vk40 持久版
```
主机侧资产已核验齐全（vk40 双版、bootslot-b、modules、相机模块、rootfs 归档、EDL、073 包）。

**并行/前置于此**：C0 真 Android 对照取证（U1，a 槽覆盖前唯一机会）、G1-4 听声、G1-5 相机出流、C1→C3→C2。

## 请你拍板

1. 现在上机 U2 走 Phase 0–5？点头我就出 **Phase 0 逐条命令**（只读、零风险），并把 `LINUX_GIB` 按 512 档定为 **176 GiB** 起步。
2. 还是先安排 **U1 的 C0 取证**（需把 U1 接上）？

我的建议：**先 Phase 0–2（零风险，拿到 U2 的 GPT 与 b 槽原厂镜像 + RAM 验收），再决定 Phase 3 给多大的 `linux17`**；C0 在有 U1 的窗口再插。


## Automatic settled outcome - 2026-10-03

开始。先把能安全做的做完，然后把需要你动手的 fastboot 段整理出来。

## 已做（主机侧 + adb 只读，零风险）

- **U2 实机采集** → `backup/HA2EXB0E-16+512/current-259/`（getprop 1052 行、by-name 121 项、df）
- **b 槽原厂备份核验**：`backup/HA2EXB0E-16+512/stock/` 五件套是**真镜像**，`boot_b` AVB 指纹 = `ZUXOS_1.5.10.229_260514`（Android15）→ 即 **b 槽是上一版 229，a 槽才是运行中的 259**（A/B 常态，符合预期）
- ⚠️ `backup/HA2EXB0E-16+512/stock-1.1/*.img` 全是 **0 字节**（上轮失败的残留）→ **作废，不作为依据**
- 资产就位：`out/boot-elden-vk40-ram.img`（83 MB 纯 boot，无 AVB，适合 `fastboot boot`）、`bootslot-b/`（vk40 RAM+持久+flags3 vbmeta）、`bootslot-b-u2/`（locked 链，本轮不用）

## 你来执行（一轮，含 ★零写盘 RAM 验收）

```bash
cd ~/y700-elden
adb -s HA2EXB0E reboot bootloader
fastboot devices                       # 应出现 HA2EXB0E
fastboot getvar current-slot           # 期望 a
fastboot getvar unlocked               # 期望 yes
fastboot getvar partition-size:boot_b  # 期望 0x6000000
fastboot getvar partition-size:dtbo_b  # 期望 0x2000000

# 校验手上的 b 槽备份 = 设备现状（只读）
fastboot fetch boot_b /tmp/u2_boot_b.img
sha256sum /tmp/u2_boot_b.img backup/HA2EXB0E-16+512/stock/boot_b.img

# ★零写盘 RAM 启动（不碰任何分区/GPT）
fastboot boot out/boot-elden-vk40-ram.img
```

等约 15 s，然后在**另一个终端**：

```bash
sudo bash ~/y700-elden/elden-net.sh
ping -c3 192.168.7.1
ssh -o StrictHostKeyChecking=no root@192.168.7.1 'uname -r; findmnt /; ls /dev/sd*'
```

**期望**：`uname -r` = `7.2.0-debug-…-dirty`；`findmnt /` = RAM/initramfs。

把上面 fastboot 段的输出（尤其 `sha256sum` 两行、`fastboot boot` 返回、`uname -r`）贴回来，之后 **GPT dump + 硬件验收（显示/触屏/固件加载）由我经 ssh 接管**；确认 GPT 后可谈 Phase 3 的 `linux17` 容量。

> 回退：RAM 启动失败会停在 bootloader，`fastboot reboot` 即回 Android，a 槽与数据不变。
> 若 `fastboot boot` 被 ABL 拒（返回 Load Error），改走 RUNBOOK Phase 2 的「写 b 槽再重启」路线——那需要写 b 槽，届时我再确认。


## Automatic settled outcome - 2026-10-03

已定位并修复，**U2 现在跑起来了**（b 槽 mainline vk40，RAM 根）。

## 根因：不是内核问题，是 **ABL 应用了 Android 的 dtbo overlay**

- stock `dtbo_a/b` 是含 **76 个 Android overlay** 的合法 dtbo（平台 `kera`）。`fastboot boot <img>` 时 ABL 会把这些 overlay 合并进内核 DT → 模型/面板不匹配 → **卡联想 logo**，随后 ABL 判定启动失败回 fastboot。
- 这正是 2026-09-28 就记录过的结论（`archive/topics/复盘.md` §一：*"写假 dtbo 后，屏幕从卡 logo 变成黑屏，ABL 成功把控制权交给内核"*）。
- 所以 `fastboot boot` 单靠一颗 boot 镜像不够——必须**先把目标槽的 dtbo 清空**（或刷 mainline dtbo）。

## 处置（我已执行）

```bash
fastboot flash dtbo_b   bootslot-b/dtbo_b.img          # 32 MiB 全零 = blank dtbo
fastboot flash boot_b   bootslot-b/boot_b_vk40-ram.img # vk40 RAM
fastboot flash vbmeta_b bootslot-b/vbmeta_b_flags3.img
fastboot --set-active=b && fastboot reboot
```
结果：**NCM 网卡 ~24 s 起来，`ping 192.168.7.1` 通，ssh 进 mainline**（`uname -r`=`7.2.0-debug-gba28ec16f01f-dirty`，`findmnt /`=rootfs）。

## Phase 0–2 验收（全绿）

| 项 | 结果 |
|---|---|
| b 槽直启 | ✅ RAM 根；b 槽原厂镜像已在 `backup/HA2EXB0E-16+512/stock/`（=1.5.10.229），可回退 |
| **GPT dump** | ✅ **U2 自己的**：`backup_lba=123871231`、`last_usable=123871226`、`userdata`=449.7 GiB、free slots 16–31 → `backup/HA2EXB0E-16+512/gpt_{main0,backup0}.bin` |
| 显示/GPU | ✅ `card0-DSI-1`、adreno 载入 `gen80000_{sqe,gmu,aqe}.fw`、backlight `aw99706` 在 |
| ADSP | ✅ `remoteproc0` running（`adsp.mdt`），GPR/APR 起来 |
| 蓝牙 | ✅ `wcn7850` hci0 setting up |
| 触摸 | `/dev/input/event0-6` 在位（**请你看一眼屏幕确认显示/触控**） |
| 日志存档 | `backup/HA2EXB0E-16+512/vk40-ram-acceptance-dmesg.txt` |

文档已同步：`DEVICE.md §2.2/§2.5`（U2 GPT 实测值）、`TASKS.md G1-1/G1-2`。

## 请你拍板 Phase 3 的两个参数

**① `linux17` 容量**：建议 **176 GiB**（§3.1 体量合计 105–180 GB；512 档留余量）。

**② 手术后 a 槽 Android 怎么办**（缩 `userdata` 后 f2fs 不匹配，a 槽会 bootloop）：
- **A** 弃 Android，不管 a 槽（后续 Phase B 还能回收 `super` 22 GiB 等）；
- **B（我建议）** 手术后 `fastboot erase userdata && fastboot erase metadata` 重建 `/data`（≈273 GiB）


## Automatic settled outcome - 2026-10-03

已恢复，并且顺势把 **U2 做成了持久 Linux（b 槽直启 + Phosh）**。下面按「结论 → 原因 → 处置 → 下一步」说。

## 现状（实机核验）

| 项 | 值 |
|---|---|
| b 槽 | mainline **vk40 持久直启**，`findmnt /` = `/dev/sda17 ext4` |
| 桌面 | **Phosh 已自启**（phoc/phosh/gnome-session 7 个进程在跑） |
| 持久性 | 已重启一次验证：仍从 `/dev/sda17` 起来 |
| a 槽 | stock 259 Android（原样，未动；`/data` 待重建） |
| GPT | `userdata` 449.7→**256.7 GiB**、新增 **`linux17`=193.0 GiB**（写后重 dump CRC OK） |

## 为什么会 panic、一直重启

屏幕那句是 `Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)`——含义是 **initramfs 的 PID 1 在切换持久根那一步没能继续**（`exec switch_root /newroot /init` 之后进程退出），内核只好回头挂 root，失败即 panic。

副作用：每失败一次 ABL 就把 `boot_b` 的重试计数扣 1。实测 `slot-attr.py show`：**`boot_b` byte6 从 7 被扣到 4**（`0x27`，succ=0），所以它会反复重启并最终落到 fastboot。

根因还没 100% 钉死（首次挂载/switch_root 的时序最可疑）；但**带“早期初始化 USB 控制台”的版本能稳定切根成功**，这点已复现两次。

## 我做了什么

1. **先救回**：fastboot 回刷 RAM 核到 b 槽 → 拿回可用系统。
2. **诊断镜像**：在原 persistent ramdisk 的 `/init` 里提前初始化 USB 控制台并打点日志，重打包 → `dd` 到 `boot_b`。
3. 启动 → dmesg 实测 `[init] switching root to /dev/sda17 (/init)` → Phosh。
4. **`slot-attr.py mark-successful b`**：把 `boot_b` 写回 `succ=1/retry=7`，防止 ABL 再把 b 判成不可启动。
5. 重启回归验证通过。

另外最初"卡联想 logo"是**另一件事**：`fastboot boot` 不清 dtbo 时，ABL 会把 stock 的 76 个 Android overlay 合进内核 DT → 卡 logo；刷 blank `dtbo_b` 后即正常（已把这条写进 `RUNBOOK §3`/`INDEX §4`）。

## 待你确认 / 下一步

1. **看一眼屏幕**：现在应该是 Phosh 桌面——显示/触屏正常吗？
2. **a 槽 Android 回退**：我们清过 `userdata`+`metadata`，它下次启动会重建 256.7 GiB 的 `/data`。要不要现在切 `active=a` 实测一次能进 Android（测完切回 b）？
3. **b 槽镜像收口**：现在用的是"诊断版"（早初始化 USB 控制台），很可能是它救了 switch_root。要不要我重建一个干净版（去掉 DIAG 打点、保留早 USB 等待）再固化？建议保留早 USB 等待。

文档已同步：`DEVICE.md §2.2/§2.5`、`TASKS.md G1-1/2/3 ✅`、`INDEX.md §3`。


## Automatic settled outcome - 2026-10-03

屏幕正常 ✅。U2 = **b 槽 mainline 持久 + Phosh**，这已经是可以日常用的状态了。下面给下一步规划（按「先稳固基线 → 再刷 G1 收官 → 再进 G2」）。

## 现况一句话

- U2：Linux 持久可用（`/dev/sda17`）、Phosh、SSH、USB-NCM；a 槽 Android 259 原样（`/data` 待重建）。
- 工具链在位：`amixer/speaker-test/v4l2-ctl/media-ctl/waydroid` 都有；持久根里 `/dev/disk/by-partlabel/` 有了 → **后续内核迭代可全程在 Linux 内 `dd boot_b`，不再需要 fastboot**。
- 唯一遗留：b 槽现在跑的是"诊断版"镜像（含早 USB 打点）。

## 建议路线

**A. 先稳固基线（1 轮，低风险，之后才敢放心改内核）**
1. 重建**干净版持久镜像**（保留"早 USB 等待"、去掉调试 echo）→ `flash-b.sh` 写 b 槽 → 哈希回读 → 重启验证；把它定成 vk40 正式基线。
2. 核验持久态自启项：温控分级、充电/旁路、串口、Wi-Fi/BT 服务。
   → 产出：一条命令刷内核 + 自动验证的稳定闭环（`scripts/flash-b.sh --reboot`）。

**B. G1 收官（U2 在机；多数我可独立做，2 项需你现场确认）**
3. **G1-5 相机出流**：`v4l2-ctl`/`media-ctl` 取 10 帧（前后摄）——我可独立跑。
4. **G1-4 音频听声**：`amixer numid=8 on; speaker-test` —— **需你听 + 录音回放**。
5. G1-7 BT 配对、G1-6 TF 卡、G1-8 CPU/GPU 基准（脚本已备，零交互）。
6. 低优先：G1-9 DP、G1-10 NFC、G1-11 CDSP。

**C. G2 主线（Linux 稳定后）**
7. C1 Waydroid 端到端复跑（去掉旧 workaround）→ **C3 身份/DRM 取证** → C2 Play 登录（需你给上行+代理+凭据）→ C4 传感器链路部署验证。

**并行 / 前置**
- **a 槽 Android 回退验证**：切 `active=a` 让它重建 `/data`(256.7 GiB) 进一次系统，成功即说明回退通道可用。
- **C0 真 Android 对照取证**：U1（stock+root，未连）或 U2 a 槽；覆盖 a 槽前唯一机会。
- Q13 AVF 资产复采（U1）。

## 我的建议

先做 **A（固化干净基线）**，紧接着 **B3（相机出流，我能独立完成）**；然后 **B4（需要你花 2 分钟听声）**。G2 的 C1 也可以现在就并行启动（设备就在手边）。

请拍板：
1. 先跑 **A + B3**？（我这就开始重建干净镜像）
2. 还是先把 **a 槽 Android 回退**实测一次再说？
3. G2 的 C1 是否现在就并行开跑？


## Automatic settled outcome - 2026-10-03

已停止操作，全部记录完毕。下面是本轮总结（数字在前，一页内）。

## 本轮成果（U2）

| 项 | 结果 |
|---|---|
| GPT 手术 | ✅ `userdata` 449.7→**256.7 GiB**、新增 `linux17`=**193.0 GiB**（`/dev/sda17`）；写后重 dump CRC OK |
| 持久 rootfs | ✅ 归档 30852 项 / 8.3 GB 解包到位 |
| 持久直启 | ✅ `findmnt /`=`/dev/sda17`，**Phosh 自启**，重启保持（G1-1/2/3 达成） |
| 内核迭代 | ✅ 持久根有 `/dev/disk/by-partlabel/` → 后续可 `dd boot_b`，免 fastboot |

关键复用经验：`fastboot boot` 必须先 blank `dtbo_b`（否则卡 logo）；`slot-attr.py mark-successful b` 复位槽位重试计数。

## 未解故障（本轮终结于此）

**桌面空闲熄屏（DPMS blank）→ 整机重启**。串口证据：重启前 `ucsi_glink … PPM init failed`，**无 kernel panic 打印**（像 ADSP/PMIC 级复位）。规避方向 = **禁止空闲熄屏**（`idle-delay=0` / caffeine），`CONFIG_SUSPEND=n` 无 `mem_sleep` 可设。

**当前状态**：我把 `idle-delay` 改成 10s 复现后，设备陷入**重启环、SSH 窗口过短，未能改回** → **现在不可达**（无 adb/fastboot USB）。

## 记录（已落盘）

| 文件 | 内容 |
|---|---|
| `archive/topics/复盘-2026-10-03-持久化与睡眠.md` | **主复盘**：时间线、已确认事实、故障证据与推测、当前危险状态、**§5 恢复方案**、教训 |
| `DEVICE.md` §2.2 / `INDEX.md` §3 | U2 现态：持久可跑但熄屏即重启、当前不可达 |
| `TASKS.md` | G1-1/2/3 ✅；新增 **G1-22 熄屏/睡眠稳定性**（🔴）；§4 第 1 步改为「先救机器」 |
| `GAPS.md` | 新增 **Q21**（熄屏→重启）+ 风险登记行 |
| `RUNBOOK` §3 | 加「持久根禁止空闲熄屏」的强制步骤与命令 |
| 全局 memory | 教训：单一远程通道的持久系统上不做自锁式实验 |

## 下次开工第一件事（无需现在做）

物理键进 fastboot（关机后长按 电源+音量下）→ 回刷 `bootslot-b/boot_b_vk40-ram.img` 拿回可达 RAM 环境 → 把持久根 `idle-delay` 改回 0（或写进 `start-desktop.sh`）→ 再谈继续。命令与判据都在复盘 §5。

设备现在在重启环里等人工介入，本轮不再动。


## Automatic settled outcome - 2026-10-03

完成。结论先行。

## 结果

| 项 | 数值 |
|---|---|
| 建立 git 仓库 | 分支 `main`，**293 文件 / 7.9 M** 纳管，`.git` 仅 4.5 M |
| 排除资产 | `geekidos-linux` 13 G、`out` 4.6 G、`env-pass` 3.8 G、`backup` 1.5 G、`l2` 45 G 外置等全部 ignore |
| `git status` 耗时 | 0.004 s（大目录被忽略，不再刷屏） |
| 发现并修复的一个真问题 | `patches/0001–0011` **不能完整重建内核工作树**（5 个文件有差异，`q6prm.c` 根本没 patch） |
| 导出权威补丁 | `patches/elden-working-tree-ba28ec16f-2026-10-03.patch`（13 文件，反向 apply 校验通过）|

## 做了什么

1. **`.gitignore`（版本控制边界）**
   - 纳管：八份文档、`scripts/`、`patches/`、`archive/`、`.pi/{skills,memory,missions,agents,settings}`、`initramfs/`、`rootfs/` 脚本、`env-pass/{scripts,tools}`、几个关键 README。
   - 排除：上游 clone、构建产物、大二进制 dump、运行时状态（`.pi/sessions`、`.pi/messenger`）、**`sn.img`（含本机序列号）** 与 `l2` 外置挂载。
   - 踩坑记录：gitignore **不支持行尾注释**，`#` 必须独占一行，否则模式静默失效（第一次就栽在这）。

2. **`FILES.md`（新台账，已接入 `INDEX.md`）**：顶层逐项分类（体积 / 是否纳管 / 说明）+ 可清理标记表（P0–P3 + H1）+ 内核补丁回导纪律。

3. **内核进度固存**：把真实工作树导出为补丁。这是本仓库版本控制覆盖不到的唯一边界——之前进度只存在于 dirty tree。

4. 更新 `RESOURCES.md §2.5`：**P0-b 前置闸已解除**，`geekidos-linux make clean` 现在可安全执行。

## 可清理标记（未动手，等你确认）

| 标记 | 目标 | 可回收 | 风险 |
|---|---|---|---|
| P0-a | `/mnt/Samsung/fiotest/` | 4.1 G | 无 |
| P0-b | `geekidos-linux` 构建产物 `make clean` | ~11.4 G | 低（补丁已存） |
| P1-a | `out/`+`bootslot-b/` 旧 boot（留 vk40/vk39） | ~4.7 G | 低 |
| P1-b | `pkgs*` 包缓存 638 M | 0.6 G | 无 |
| P3 | AOSP 树 + `l2`（外置） | 568 G | 需先做 Q13 取证 |

根盘 P0–P2 合计约 **18 G** 可回收。

## 关于「轨迹变复杂」

38 个会话 / 45 M 在 `.pi/sessions/`（H1 标记）——这部分也影响 AI 上下文稳固度。可用 `session-librarian` 技能归档非活跃会话，只留最近若干。

## 请你拍板

1. 现在就执行 **P0（fiotest + `make clean`，约 15 G）**？（我可以先 `df -h` 记录、执行后再核）
2. 要不要顺手做 **P1（旧 boot 镜像 + 包缓存，约 5.3 G）**？——vk39 建议等 vk40 上机验收后再删。
3. H1 会话归档现在做吗？

`git log` 已有一条初始提交，工作树干净；后续每轮改动 `git add -A && git commit` 即可。


## Automatic settled outcome - 2026-10-03

DONE batch3: 9


## Automatic settled outcome - 2026-10-03

DONE batch1: 9


## Automatic settled outcome - 2026-10-03

DONE batch2: 9


## Automatic settled outcome - 2026-10-03

DONE batch4: 9


## Automatic settled outcome - 2026-10-03

DONE batch5: 9


## Automatic settled outcome - 2026-10-03

三件事的进展如下（数字先行，一页）。

## 任务 #1：会话条目整理 ✅

| 项 | 结果 |
|---|---|
| 派子代理 | **5 个**（batch1–5，各 9 会话），全部 `completed` |
| 产出 | `SESSION-INDEX.md`（全量 45 会话）+ `archive/sessions-catalog-2026-10-03.jsonl`（机器可读） |
| 独立复核 | 条目 45/45 合法唯一、字段齐全；抽查 09-29/09-30 两条**证实子代理准确**（非臆造） |
| 分类 | 实机验证 **20 ✅ / 2 ◐ / 23 ✗**；状态 **active 23 / reference 15 / junk 5 / superseded 2** |

会话分布在两处：`.pi/sessions/*.jsonl`（36）+ slug 子目录（7）+ 2 个重复测试。

## 任务 #2：以「最后一版实机验证」为界审核 ✅（第一遍）

**边界判定：vk34（2026-10-01 23:12）** 是最后一个有明确会话级实机确认的版本；INDEX 曾写「最后在机基线 vk39」但**无会话确认**（待你核）。

**未验证增量精确到 5 个文件 + config**（全部 10-02 10:48–12:12，mtime 取证）：

| 文件 | 内容 | 单独上机 |
|---|---|---|
| `sm8750-lenovo-elden.dts` | 分级热 trip 70/82/90/105 ℃ | ❌ |
| `q6apm.c` | APM 命令头 + **残留 `DBG` 打印** | ❌ |
| `q6prm.c` | 5 行（**`patches/0001–0011` 里根本没有**） | ❌ |
| `audioreach.c` | 35 行 | ❌ |
| `q6apm-lpass-dais.c` | MI2S BE graph 提前到 prepare（patch 0011） | ❌ |

vk34 之前的 8 个文件改动都已上机。**vk40 = vk34 基线 + 这 5 文件 + 10-03 持久化 initramfs**，是「新 bug」的最可能来源。

**4 条结构性缺陷（比单条改动更值得修）**：
- **F1** 所有 vk 共用同一 `uname -r` → 设备上**无法分辨在跑哪版**（回归无法归因，正是「进步不稳固」的根）
- **F2** `patches/0001–0011` 不能忠实重建工作树
- **F3** `q6apm.c` 残留调试打印
- **F4** 无 per-version git commit → 不能 bisect

已落盘：`archive/topics/AUDIT-since-vk34-2026-10-03.md`；登记 **GAPS Q22**、**TASKS G1-23**。

## 待你拍板

1. **边界确认**：10-01 之后到 10-03 之间，mainline 上机你是否**亲眼确认过任何一版**？若没有，就以 **vk34** 为界。
2. **任务 #2 下一步**（我建议）：`geekidos-linux` 建 `elden/` 分支提交现状 + 唯一 localversion（修 F1/F4）→ 以 vk34 为基线**反向移除音频 4 文件改动**，看 vk40 症状是否消失，直接定位回归源。
3. **重命名 + 删除**（任务 #3）：索引 §5 已列 38 条建议重命名、§4 列删除候选（5 junk + 2 superseded）。**等 #2 收口后再执行**——你要不要我先批量应用重命名（可逆）？

`git log` 已有 3 条提交（边界 → 会话索引 → 审计），工作树干净，296 文件纳管，`.git` 4.6 M。


## Automatic settled outcome - 2026-10-03

下一步已执行（全部主机侧、可回滚）。结论先行。

## 做了什么

**1. 内核树固存 + 修 F1/F4**（`geekidos-linux` 自己的 git）：

| 分支 | commit | 含义 |
|---|---|---|
| `elden/vk40-2026-10-03` | `6ef87e6a8` | vk40 现场原样（含 DBG 插桩）——回归对照 |
| `elden/vk34-recon` | `e72a036ed` | 回退 vk34 之后的 5 文件增量 |

因为 `.config` 早已有 `CONFIG_LOCALVERSION_AUTO=y`，**一提交 uname 就自动唯一**：
- vk40re → `7.2.0-debug-g6ef87e6a8868`
- vk34recon → `7.2.0-debug-ge72a036ed4be`

→ 设备上 `uname -r` 终于能分辨在跑哪版（这就是「进步不稳固」的根，已修）。

**2. 用真机镜像校验重建的 vk34**（关键可信度）：

| 项 | vk34 实机镜像 | 重建 recon |
|---|---|---|
| DBG 字符串 | 无 | **无** ✅ |
| 分级热 trip（DTB） | 无（单一 max 状态） | **无** ✅ |
| `sm8750-lenovo-elden.dtb` | 136346 B | **逐字节相同** ✅ |

→ recon 忠实重建了 vk34；顺带**确定**：DBG 插桩与分级热 trip 都是 vk34 之后的增量。

**3. 产出 A/B RAM 镜像**（`out/`，`fastboot boot` 即可，不写 flash）：`vk34recon.img`/`-ram`、`vk40re.img`/`-ram`。音频/QDSP6 全是 `=y`，不受 vermagic 影响。

## 请你上机做隔离实验（判据明确）

```bash
cd ~/y700-elden
fastboot fetch boot_b backup/HA2EXB0E-16+512/boot_b.pre-ab.img   # 备份
# 进 fastboot；确认活跃槽 dtbo 已 blank（否则卡 logo）
fastboot --set-active=b && fastboot flash dtbo_b bootslot-b/dtbo_b.img
fastboot boot out/boot-elden-vk34recon.img                       # 先跑 vk34
ssh root@192.168.7.1 'uname -r'      # 期望 …-ge72a036ed4be
# 复现熄屏：设 idle-delay=10，SSH 常 ping 观察是否重启；测完改回 0
# 再 reboot 回 vk40，对 vk40re 重复对照
```

- **vk34recon 不重启 / vk40re 重启** → 回归源就在那 5 个文件里，继续二分（先只留 DTS 热 trip，或只留音频）。
- **两者都重启** → 与内核增量无关，转向 10-03 持久化 initramfs / `start-desktop.sh` / UCSI 电源路径。

⚠️ RAM 引导非持久，万一重启回到 flash 的 boot_b（vk40）可恢复；但 `idle-delay` 写在持久根**会留存**，务必改回。

完整步骤与哈希记在 `archive/topics/AUDIT-since-vk34-2026-10-03.md` §5；父仓库 4 条提交、内核仓库 2 分支，均已固存。

**一个前提想跟你确认**：设备现在是从先前的「重启环」里救回来了吗、fastboot 可用？如果暂时不方便上机，我可以先把「只回退音频 / 只回退热 trip」的中间变体也编好备着。


## Memory - 2026-10-03

内核回归定位法（可复用）：①从实机 boot 镜像解包内核/DTB，用 `strings`/DTB 逐字节对比确定"最后实机验证版本"到底含哪些改动；②用文件 mtime 锁定边界之后的增量文件集；③重建时把重建 DTB 与实机 vk34 DTB 逐字节比对来证明重建忠实；④内核树开 CONFIG_LOCALVERSION_AUTO=y 并**每版一 commit**，uname 即自动带唯一 commit（否则所有构建共用同一 uname，回归无法归因）。
