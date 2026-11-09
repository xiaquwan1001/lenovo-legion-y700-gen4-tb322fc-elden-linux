# 资源清单（RESOURCES）— 参考资源 + 本地资源

> 本角度文件夹的策展 SSOT（`README.md`）；`sessions/` 存以会话为单位的进度。标准见 `INDEX.md` §2。
> **本文件是唯一资产清单**：外部参考（含本轮取证的社区先例）与本地已有资产都在这里，含路径与校验状态。

---

## 1. 参考资源（外部，按用途分组）

### 1.1 本机型 / 本 SoC（TB322FC · SM8750P）

| 资源 | 用途 | 本地状态 |
|---|---|---|
| Lenovo GPL 源码 `lenovo-basements/*`（modules 仓 + 主内核） | 反查厂商 compatible/固件名/寄存器语义、tplg 参考 | ✅ `stock-src/`（modules 349 M 全量 + 主内核 sparse） |
| GEEKiDoS/linux `v7.2-elden` | 本项目内核树（作者已真机验证） | ✅ `linux -> geekidos-linux` |
| xiaobai-Lethe/Y700-elden-linux | 作者 `.config`、`project/*.sh`、Mesa deb、165 Hz mode table 补丁 | ✅ `Y700-elden-linux/` |
| EDL 全量包（63 文件 / ~599 MB） | 固件提取 + 救砖 | ✅ `~/下载/tb322fc/`，子集在 `backup/fw/`、`backup/stock-259/` |
| 原厂 ROM `/mnt/Samsung/l2/system_a.pristine.img`（Android 16 / `…_259`） | 固件/AVF/属性基线 | ✅ 已用 `debugfs` 离线取证 |
| Qualcomm SM8750 厂商 DT（dtc 反编译） | 驱动矩阵比对基线 | ✅ `backup/stock-elden/dtb/*.dtb` + `elden.dts` |
| **第三方解锁签名服务** https://lenovobl.neko.ink/（NekoYuzu《Lenovo BootLoader Unlock Tool》v1.0.0） | 免账号产出的四代新格式签名 blob（356 B）。**已实测无效（2026-10-03，Q18 已结）**：结构自洽、SN 绑定正确，但 `oem unlock` 在 1.5.10.259 上被拒 ⇒ **四代 1.5.x 换 ABL key，买/求签名文件这条路对高固件无用** | ⛔ **不再使用**；blob 与取证留作证据（`backup/HA2EXB0E-16+512/sn-neko-zuxos.img`） |
| **联想官方解锁入口** https://www.zui.com/iunlock | 官方签发 sn.img（需账号+大陆邮箱，限额 1 号/年 3 台）。**但在 1.5.x 上同样过不了 ABL**（与第三方 blob 同一道门）；仅对 ≤1.1.11.073/.076 的旧固件有意义 | ⚪ **无需申请**：本机型正解 = 降级 1.1.11.073 后 `fastboot oem unlock`（不依赖 sn.img）；见 `RUNBOOK` §0.5 ★权威顺序 |
| ROM基地《Y700 四代(TB322FC)解锁 BL 图文教程》(`m.romjd.com/jiaocheng/content/29817`, 2026-04) + ROM乐园(`romleyuan.com/lec/read?id=1427`) | 解锁命令与陷阱交叉印证：`flash unlock sn.img` → `oem unlock-go`（屏上选 UNLOCK）；新版可屏蔽解锁指令→回退旧版；9008 未端口加密 | 已消化进 §0.5；⚠️ 其付费“秒解”服务**不用** |

### 1.2 ARM Linux 主线化上游

| 资源 | 关键点 | 我们用它的哪一块 |
|---|---|---|
| linux-piano（AudioReach 上游 PR/系列） | 43+ 个 AGL/APM 修复 commit | 音频 `patches/0011` 的上游对照 |
| freedreno / Mesa 上游 | A830 (`gen80000`) 支持、turnip | **宿主**：Alpine apk 预制（`mesa-dri-gallium` + `mesa-vulkan-freedreno`），**零编译**、**不打 chip-id 补丁**（原版才对）；**Android/bionic**：自编 Mesa 26.1.8 解 Waydroid chip-id（清单见 §2.2） |
| `ath12k`（WCN7850/Peach 通路） | MHI 超时需本地重试补丁 | WiFi 稳定性补丁 |
| `qcom_battmgr` / PMIC-GLINK | 充电与**旁路供电**两个旋钮 | `scripts/charge-ctl.sh` |
| mainline `camss` + `s5kjns`/`gc08a8`/`gt9764`/`wl2868c` | SM8750 camss 已在树 | 相机 20 个 `.ko` |
| mobian / postmarketOS / pmOS wiki（SM8x50 系列） | 手机侧 mainline 经验（电源、Modem、显示）；**Android 设备主流做法 = 直接 ABL boot.img，不引入 U-Boot** | 参考实现与坑表 = 我们现状的社区验证 |
| Linaro U-Boot Qualcomm（博客 2024-08 + devboardsforandroid SM8x50 文档） | **链入方式**：U-Boot 伪装成 Linux kernel 被 ABL chainload（XBL→ABL→U-Boot→GRUB/内核）；HDK 开发板官方做法即 "chainload U-Boot from ABL" | 可选观察：仅在需要 GRUB/启动菜单/TF 卡引导/突破 boot.img ≤96 MiB 时再评估；U-Boot 对 SM8750 支持仍早期，HDK 经验≠TB322FC |
| edk2-msm（renegade-project 系） | 整体替换 XBL 的真·UEFI 固件（ESP/Boot Services/ACPI） | 不立项：TB322FC 无移植、变砖风险极高；G1 固件驱动经 TZ PAS 与 UEFI 无关 |

### 1.3 ★ 容器 / 安卓兼容（社区先例，本轮取证 2026-10-02）

> **用途**：证明「**容器内跑 GMS/谷歌服务是有先例的**」，因此**不预设"容器不能认证"**；
> 这些是 C3 要逐条复现/取证的入口，不是结论。

| 项目 | 取证到的事实（README 原文要点） | 对我们 |
|---|---|---|
| `remote-android/redroid-doc`（6.9k★） | **arm64 + amd64** 都支持；GMS 可经 **OpenGApps / MicroG / MindTheGapps** 加入；宿主 `binder_linux devices="binder,hwbinder,vndbinder"` | 与 Waydroid 并列的容器路线；vk40 已开 `CONFIG_ANDROID_BINDERFS` |
| `casualsnek/waydroid_script`（3.8k★） | 一键装 `gapps/magisk/libndk/libhoudini/microg/mitm` + **Widevine L3**；有 **`certified` 子命令**：打印 Android ID → 去 `google.com/android/uncertified` 注册 → 清 GMS 缓存即可登录 | **直接适用**：这正是"容器过未认证"的社区做法，C3 首要复现对象 |
| `WayDroid-ATV/waydroid-androidtv-builds`（571★） | Android TV 13（LineageOS 20）镜像，**内置 GApps + Widevine L3**（**L3 仍仅 x86-64**，release notes 原文）+ VA-API；**arm64 GAPPS 镜像存在**（SourceForge `waydroid_tv_arm64` lineage-20.0-20260106-GAPPS，2026-01）；未认证设备需 Play 注册才能登录 | GApps/Widevine 注入的镜像级参考；**arm64 GAPPS 可作 C2 第二镜像源**；L3 arm64 仍无 |
| `Nigel1992/Waydroid-Advanced-Manager` | Waydroid 一体化管理 CLI（装 APKS/GApps 等） | 运维脚本参考 |
| `ayasa520/redroid-script`（423★）、`CNflysky/redroid-rk3588`（327★） | redroid 的 GMS/构建脚本与 **ARM（RK3588）** 落地先例 | ARM 侧可行性的第二证据 |
| AOSP `virtualization` `custom_vm.md` | AVF 自定义 VM 契约（`vm_config.json`、`DMA_RESTRICT_POOL`、`--protected-vm-without-firmware`） | VM 备选路线（C8）契约文档 |
| `denialwm/droidloom`（**406★**，Rust，2026-10 日更；同作者 `denial` 合成器 **1354★**） | Linux 原生跑 Android 应用（Wayland 直出窗口，shared-kernel userspace）。**aarch64 已是一等产品配置**（`android/device/droidloom_arm64/`，`kgsl_dma_heap`/`drm_dma_heap` 两种图形后端 + Panfrost v11/Turnip），上游在 **OnePlus Pad 4** 真机跑 Android 17（Play 登录、装游戏、init 前属性投影经 getprop+分区文件双读验证）；**发布包仍只发 x86_64 Arch**。**两条否决性约束**：① 宿主合成器必须支持 `xdg-shell` + `linux-dmabuf` **v4 feedback** + **`linux-drm-syncobj`**（Phosh/Mutter 不满足）；② **PI/Widevine 官方明确未验证**（Moto cell 上 Play 显示「未认证设备」），主线内核无 Android SELinux LSM ⇒ binder SID 走 PID-context 回退、安全边界=宿主沙箱 | 跟踪（Q3）；**可搬资产 3 类**（19 条 AOSP/Mesa 共享内核补丁 / release 属性投影 / per-task Wayland 直出架构）= `sessions/2026-10-26-denial-droidloom深度评估.md` §4 |
| `denialwm/denial`（**1354★**，Rust+Smithay+Flutter，0.2.x 公开 beta，2026-10-24 push） | Wayland 合成器；**mobile 模式**（`DENIA_SHELL_PROFILE=mobile`）、48 px 内容 inset 协议 `denial_insets_manager_v1`、**原生持有旋转锁**、Moto Edge 70 上的 FOD/双击唤醒（原文「无需新内核」，只需 `/sys/class/touchscreen/primary/gesture`=49）；非目标 = 不替代 NM/BlueZ/PipeWire/logind、不自建浏览器/终端 | G1 **UI 层候选**（不施工）：两个**会话级致命坑**（GPU reset 与运行时改缩放均直接终结合话）、`direct_scanout` 明确未实现；细节 `sessions/2026-10-26-denial-droidloom深度评估.md` §2 |
| Droid-VM/DroidVM | Android 侧 VM 管理器 / Windows 11 ARM64 on crosvm+Gunyah（**需 Android 宿主**） | 与新前提冲突（a 槽可弃）；只观察（见 `../TASKS/README.md §5` Q4） |
| Box64 + Wine（Pi-Apps-Coders 0.4.5） | ARM 上跑 x86_64 Windows 程序 | 已 PoC 成功（`archive/topics/WIN-X86-POC-2026-10-02.md`） |
| `waydro.id/licensing.html` | 官方口径：GApps/ARM 翻译/Widevine 受许可限制，建议开源替代（microG 等） | C2 选型时的合规边界参考 |
| PlayIntegrityFork（pif.json 指纹注入） | 2025 社区主流过 Play Integrity 手段 | `env-pass/assets/PlayIntegrityFork-v18.zip` 已在手 |

### 1.5 虚拟化上游（VM 路线参考，2026-10-02 取证）

| 资源 | 关键点 | 我们用它的哪一块 |
|---|---|---|
| LWN/RFC PATCH 00/34 **"Running Qualcomm's Gunyah Guests via KVM in EL1"**（K. Manaouil, Linaro, 2025-04-24） | **KVM 跑在 EL1**、VM 生命周期接口 + Gunyah 做后端；Kconfig 拆分 native/Gunyah-backed；WIP（pinned anonymous pages、无 guest_memfd、禁 compaction/swap） | C8 唯一"无 Android"硬件虚拟化新路线；需 port + 配套 QEMU |
| `karim-manaouil/qemu-for-gunyah` | 配套 QEMU fork（KVM API → Gunyah hypercall） | 同上 |
| `quic/gunyah-hypervisor` | Gunyah hypervisor 开源仓（RM ABI 参考） | guest 驱动 ABI 对照 |
| kodiak-el2.dtso 系列（**v11，2026-08**，Mukesh Ojha） | Qualcomm **dev kit**（qcm6490-idp/rb3gen2/qcs615/purwa-x1）的 EL2 引导 overlay 模式；[1]=官方 boot-developer-touchpoints 文档 | 证明"boot EL2"机制只对 dev kit 开放，**不适用消费者 Y700**（XBL 链内加载 hyp，ABL 上一级）；另证 Gunyah watchdog 补丁实测平台=SM8750 |
| **`Droid-VM/edk2-gunyah`**（本地 clone `edk2-gunyah/`，1.8 M） | 基于 ArmVirtPkg 的 **crosvm + Gunyah guest UEFI 固件**（`GunyahPkg/GunyahKernel.dsc` → `edk2-gunyah.fd`；README **明确测试平台含 Lenovo Y700 Gen4 = TB322FC/SM8750**）；跑法 `/apex/com.android.virt/bin/crosvm run --protected-vm-without-firmware ... edk2-gunyah.fd` | **若将来走 Gunyah VM（C8）**，这是现成的 SM8750 guest 固件；但 crosvm/AVF 需 Android 宿主 ⇒ 与新前提冲突，仅观察 |
| **`qemu-gunyah/edk2-gunyah-qemu`**（本地 clone `edk2-gunyah-qemu/`，469 M） | EDK2 + `ArmVirtPkg: add Gunyah QEMU support`（2026-03） | 配合 RFC 00/34 的 `qemu-for-gunyah`（KVM-in-EL1 + Gunyah backend，C8 唯一"无 Android"硬件虚拟化路线）的 guest 固件 |
| **Gunyah 驱动代次参照集**（2026-10-25，`reference/gunyah-refs/`，**总计 1.2 M，已入 git**） | `g612/` = AOSP **android16-6.12** 的 `drivers/virt/gunyah/` 全 17 文件（6735 行，含 `gunyah_qtvm.c`、`vm_mgr_cma_mem.c`）；`g612-hdrs/` = 对应 5 个头（`linux/gunyah.h` 608 行、`uapi/linux/gunyah.h` 459 行、`gunyah_qtvm.h`、`trace/hooks/gunyah.h`、`asm/gunyah.h`）；`crosvm-gunyah-slice/` = `Droid-VM/crosvm` 的 gunyah 后端切片（`aarch64.rs` 的 `create_fdt`/`init_arch` 是唯一在 tb322fc 上跑通过的真实序列）；`gunyah_host_mod/` = DroidVM 的额外内核模块（`/dev/gunyah_share`、`gh_unmovable`、`gunyah_kvcalloc`）；`DroidVM/` = 其 `gunyah.yaml`（SM8750/P 只标 `gunyah: yes`，无 `mthp_single`）。**这是 7.3 移植的唯一参照来源，不要再从外网重下**（googlesource 单文件请求常超时，用 aria2c 批量；GitHub 镜像 `aosp-mirror/kernel_common` 可用） | **上游化与逐代对照**：主线 `drivers/virt/` 至今无 `gunyah/`（2026-10-25 复核），6.12 Android 分支是最接近上游的形状 ⇒ 移植目标 |
| **`AnyLaySys/edk2-aarch64-gunyah`**（本地 clone `edk2-aarch64-gunyah/`，1.5 G） | aarch64 EDK2，构建 `ArmVirtPkg/ArmVirtGunyah.dsc`（含 `GunyahIoMmuDxe`/`GunyahRestrictedDmaPoolAcpiDxe`）；近期提交含 **"启动 Microsoft Windows 改 ramfb"** | **Windows-on-ARM64 guest 固件**（Gunyah VM 内起 Windows）；与 win-x86/DroidVM 方向相关，仅观察 |

### 1.6 间接引导层 / SM8750 UEFI（G1-29，2026-10-05 取证）

> 承接 `archive/topics/BOOTCHAIN-2026-10-05.md`（机制判定）。**本轮只定位资源，未 clone/未构建/未上机**；完整清单与检索记录见 **`archive/topics/UEFI-RESOURCES-2026-10-05.md`**。

| 资源 | 关键点 | 我们用它的哪一块 |
|---|---|---|
| **`sunflower2333/mu_wide_platforms`**（fork of `Project-Aloha/mu_aloha_platforms`；307 M；2026-07-19 建 / 2026-10-01 更新） | 含 **`Platforms/PakalaPkg/Device/lenovo-y700g4/`（TB322FC 设备包，518 文件）**：真实内存映射 `PlatformMemoryMapLib`、`PlatformConfigurationMapLib`、`ACPI/DSDT.aml`、`DeviceTreeBlob/Linux/linux-y700g4.dtb`、`Binaries/`（原厂 DXE 全集）、`PatchedBinaries/`（Clock/UFS/PMIC/SPMI/WDog/UsbConfig/FeatureEnabler）、1904×3040 framebuffer + SMBIOS `Lenovo/Y700/4`；另含 `Silicon/QC/Sm8750/`、同族 `Device/{oneplus-dodge,oneplus-erhai,xiaomi-piano,nubia-nx789j}` | **G1-29 路线 A 的现成设备包**（此前判定为「缺环」）；`./build_uefi.py -d lenovo-y700g4` → **`Build/PakalaPkg/lenovo-y700g4.img`**（Android boot 镜像 ＝ BootShim + UEFI FD，BootShim 参数 `build_cfg/sm8750.json`：`UEFI_BASE=0xFF300000, UEFI_SIZE=0x400000`） |
| **`Project-Aloha/UEFIFirmwareBackup`** → `lenovo-y700g4/BOOT.MXF.2.5.1-00240.1-PAKALA-1/`（480 文件，`3a48f03cf` 2026-04-21） | 从原厂固件提取的 **Y700g4 UEFI DXE 二进制备份**；README §SM8750 Pakala 表：`Lenovo y700 gen4 = lenovo-y700g4`、`Oneplus 13 = oneplus-pjz110`、`Xiaomi Piano = xiaomi-piano` | 上述 `Binaries/` 的来源；也可离线核对设备自带 DXE |
| **`Project-Silicium/Mu-Silicium`** + `Device-Binaries`（2026-10-22 复核：Mu `42fe5637` / Bin `a1501e0c`） | SM8750 已有**在用**设备：OnePlus 13 `dodge` —— `Status.md` 记 `Display ✅ / Internal Storage ✅ / Mass Storage ✅ / Linux Boot ✅`。关键：其 `UFSDxe` 用**打过补丁的二进制** `UFSDxe.patched.efi`，补丁内容 = 「sleep→wakeup」+「gear check 前强制 link 唤醒」（作者 `sunflower2333`/N1kroks），**正是上游对我们 UFS 失败的答复所指的 UFSDxe 专用补丁** | **G1-29 重试的最小增量**：只换这一个二进制（sha256 与本仓 `reference/upstream-mu-silicium/README.md` 对照），配方见该 README §3 |

> **★2026-11-03 增第二路线（同芯片开源实现）**：`slwyts/Project-SunUEFI`（小米平板 8 Pro = `piano` = **SM8750**）**不加载厂商 `UFSDxe`**，从寄存器层自写 UFS 只读栈（`uefi/core/PianoUfsReadOnlyDma.c` 1138 行 + `PianoUfsProbe.c` 时钟/GDSC 账本），实机 **133 GPT 分区 / 139 BlockIO 句柄 / 7 个只读 SFS 卷**（`docs/archive/storage-usb/blockio-usb-progress.md`）。同一仓库还提供**合体 BOOT 全套**（bootselect + BootShim + 2×4 KiB 请求页 + `RSTRv1` 无损恢复目录 + repack/restore 工具）与**UEFI 屏上可见性方法**（延后原厂 ClockDxe CESTA/media + DCD 初始化、GOP 色块检查点、LoadImage 副本内 trampoline 插桩）。本地克隆已在 `external/ext-repos/sunuefi`（`afe922b`，2026-10-28）。逐条裁决见 **`sessions/2026-11-03-Project-SunUEFI复用盘点.md`**。

> **要点**：资源已「现成」⇒ G1-29 Route A 由「自造 UEFI」变为「取用 + 主机构建 + 设备侧零写盘 `fastboot boot` 验证」。
> **⚠ MIGRATION-LOST（2026-10-22 核实）**：2026-10-05 曾落盘 `mu_wide_platforms/`（fork `xiaquwan1001/mu_wide_platforms`，1.0 G，含设备包 391 文件）+ `uefi-firmware-backup/`（`Project-Aloha/UEFIFirmwareBackup`，1.3 G，二者同名驱动 sha256 逐字节一致），**2026-10-17 换机未随迁，本机已不存在** ⇒ 路线 A 重试须先重取。Mu-Silicium 与 `Device-Binaries` 本轮改为**按需取件**（小件快照 + 结论见 `reference/upstream-mu-silicium/`），不再全量 clone。
> **仍未解**：① `lenovo-y700g4` 无 CI/产物/公开验证记录；② `DeviceTreeBlob/Linux/*.dtb` 均为 **6 字节 `dummy` 占位符**（但 `PakalaPkg/PostBuild.py` 构建只用 `BootShim+SM8750_EFI.fd`，**不引用 DTB**，故不阻塞 boot.img 产出）；③ 平台默认 `PcdSystemMemorySize=12 GiB` ≠ 本单元 16 GB（按容量档需核内存映射）；④ 四代 ABL 是否接受 BootShim 壳（BOOTCHAIN **E4** 未做）；⑤ 备份 `uefi.elf`（2.79 MB）≠ 本机 `~/下载/tb322fc/uefi.elf`（5.24 MB，不同固件线）。

### 1.7 生态工具评估（2026-10-07，联网对比）

> 结论与理由详见 `.pi/plans/2026-10-07-造轮子审计.md`；已排除项登记见 `../PITFALLS/README.md` §15.6。

| 工具 | 用途 | 结论 |
|---|---|---|
| **`qbootctl`**（Alpine community） | Qualcomm A/B slot 的 boot_control HAL（读状态 / mark-successful） | ✅ **已采纳**（取代 `slot-attr.py` 常用操作，`PITFALLS` #126） |
| `casualsnek/waydroid_script` | Waydroid 后装注入：GApps / Magisk / MicroG | ◐ G2 候选（A13 arm64 GApps 走 GitHub 源） |
| `mkinitfs` · `pmbootstrap` · `alpine-make-rootfs` · `msm-firmware-loader` · `pil-squasher` | initramfs / 构建 / 固件 | ❌ 不采用（理由见 `PITFALLS` §15.6） |
| `FEX-Emu` | x86 转译（G3） | ◐ 仅作 Box64 对照 |

### 1.8 同机型另一条 Linux 分支（armadaos-freedom，2026-10-22 取证）

> 仓库 `mydanyi/armadaos-freedom`，main `244b7451`（2026-10-22）。快照与逐条裁决见 **`../reference/upstream-armadaos-freedom/README.md`**。
> 定位：ArmadaOS（SteamOS 风格、Fedora bootc）的平板分支，覆盖 **Y700 四代 `lenovo,elden` / SM8750** 与五代 `baldur`，统一 Linux **7.2.6**。

| 能用的 | 状态 |
|---|---|
| **`0154` dispcc probe 复位活显示 + `0155` DSI PHY `DIGTOP_PWRDN_B` 随 PLL bias 置/清**（均只对 `lenovo,elden` 生效，+32 行） | ❌ **本仓缺**（可干净 apply）⇒ **Q28「冷起 NOCARD」候选 A/B**：`0155` 的机理解释的正是本仓记录过的 `DSI PLL(0) lock failed status=0x00000000` |
| `0146` SMMU boot handoff 的**另一半**（`arm_smmu_boot_fb_range()` 把 `/chosen/simple-framebuffer` 范围从 DMA allocator 预留） | 🟡 本仓只有 `arm_smmu_map_boot_framebuffer()`；出现「splash 区被覆盖/花屏」时对照 |
| `0148` clk orphan reparent 保留迁移引用（`orphan_reparent_failed` 字段） | 🟡 同问题另一种写法，按需比 |
| **Steam ARM64 客户端 + Steam Runtime 的 pin**（`steam_client_steamdeck_stable_linuxarm64`、runtime `3c.0.20260729.253765`）+ `packages/{fex,gamescope,steam-bootstrap}` | ⚪ **G3 新选项**：官方 arm64 Steam + FEX，对比本仓 Box64+Wine 路线（需 Alpine 侧自建 FEX/gamescope） |
| 设备配置事实：触屏名 `NVTCapacitiveTouchScreen`、`ARMADA_GAMESCOPE_USE_ROTATION_SHADER=1`、无内置手柄 | ✅ 可直接引用的事实 |
| kShimC 启动菜单（5.4 MB 源码，**GPL-3.0**）+ `kshim-tools`（MultiBootKernelPatcher/UnpackTool） | ⛔ 不 vendor（许可与启动架构都要立项另议）；仅作外部依赖 |
| 显示/电池/SM8750 基础设施（`0142/0143/0144/0145/0149/0150/0033/0038/0066/0521`…） | ✅ 本仓已有或更全（逐条对照见该 README §4） |

### 1.9 方法论 / 运维参考（原误编为 1.4，2026-11-02 改号；无任何文档引用旧号）

- 本项目坑表：`../PITFALLS/README.md`（**动手前扫一眼**，#80/#81 是本轮新增的流程坑）。
- 解锁链签名取证（2026-10-03）：`archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`
  —— AVB 链 = 谷歌公开 AOSP testkey（原厂 `vbmeta`/`boot`/`recovery` pubkey sha1 `2597c218…`）；
  解锁标志链 = Lenovo 自签证书（serial `804940DE79164B1A`），但 SN 明文在偏移 `0x2048`、签名只覆盖前 `0x1000`
  ⇒ **通用模板改 SN 即可自造解锁文件（免签）**；四路对照：A 自造 / B 官网 / **C EDL（不依赖解锁）** / D 第三方重签包。
  实物模板：`y700四代工具/解BL/Y700 三代解锁工具箱by某贼.zip` → `bin/res/sn.img`（附 `HexTool.exe`/`hexconvetor.exe`）。
- 并发 worker 的限流与 SIGPIPE 复盘：`archive/topics/复盘-2026-10-02-swarm.md`、全局 `~/.pi/agent/AGENTS.md`（ustc_ai 20 req/窗口 + $30/3h 预算；现用 provider `deepseek`）。⚠️ 该轮 harness `pi-messenger-swarm` 已卸载 → 脚本失效、结论有效（`archive/2026-10-04-retired-entrypoints/README.md` §3）。
- 社区通用：`gsi-device-adaptation`、`qualcomm-*-flashing` 技能（`.pi/skills/`）。

---

## 2. 本地资源（主机侧，可直接使用）

### 2.1 构建链与工具（已就位，无需新装）

| 项 | 位置 / 版本 |
|---|---|
| 交叉编译 | `~/bin/aarch64-linux-gnu-gcc` 15.2.0 |
| 内核构建 | `linux/`（tree 605 M）+ `scripts/build-kernel.sh`、`scripts/build-boot.sh` |
| boot 打包/签名 | `scripts/mkbootimg.py`（自研 v2 头，pack/unpack/`--selftest`；**取代 2026-10-17 丢失的 `tools/mkbootimg/`**，后者已于 2026-11-06 清掉空壳）、`scripts/sign-boot-b.sh`、b 槽自签密钥 **`bootslot-b/avb.key`**（`scripts/sign-boot-b.sh:14` 实际取值；原 AOSP testkey `env-pass/keys/testkey_rsa4096.pem` ⚠️MIGRATION-LOST(2026-10-17)，见 §3.5） |
| AVB | `avbtool`（**实测不需 pycryptodome**）；b 槽自签密钥 `bootslot-b/avb.key` |
| GPT | `scripts/gpt-surgery-tb322fc.py`（list/build，读实际 GPT）、`scripts/gpt-dump.sh`（4096 B 扇区专用）、`scripts/slot-attr.py` |
| EDL 工具链（**源码自建，单根目录 `~/edl/`**，2026-11-03 重编） | **不再用 apt/.deb 打包版**（qdl 2.4-3 与 edl-ng 1.6.0 均已于 2026-11-03 卸载）。① **`~/edl/qdl`** = `linux-msm/qdl` **v2.9** 源码（干净构建，`qdl/build/qdl`，`~/.local/bin/qdl` 软链）——整包 `rawprogram`/`flashmap`/sparse/`sha256`/`--skipblock`/`--dry-run`/512·4096 扇区探测，**仍未上机**；② `~/edl/edl-ng` = `strongtz/edl-ng` 源码（`v1.6.0-2-g4a658ee`，提供 `printgpt`/`read-part`/`write-part`/`erase-*`/`reset`/`ramdump`；**本机无 dotnet，暂不可构建**，已真机验证的是旧 .deb 安装态，取证结论仍有效）；③ `~/edl/bkerler-edl`（含 `.venv`）= `peek` 族/Diag/loader 检索备胎；④ `~/edl/qdlrs` 只观察；⑤ `~/edl/survey` = 调研 issue 快照。loader：`~/下载/tb322fc/xbl_s_devprg_ns.melf`。构建依赖已装 `libusb-1.0-0-dev`（不再需 sysroot）。说明/追新/清理记录见 `~/edl/README.md`；选型与勘误见 `reports/edl-toolchain-survey-20261101.md`（§6/§7） |
| locked 链构建（路 C） | `scripts/build-locked-chain.sh`（testkey 重打全链，从本单元 stock dump 自动读参数）+ `scripts/extract-avbpubkey.py`（从 AVB 镜像提公钥 blob，大端 header）。⚠ 原厂受信 key 2597c218 的 AOSP testkey 在本机已丢失（`env-pass/keys/` 目录不存在，`env-pass` 被 `.gitignore` 排除） |
| 设备端操作 | `scripts/{flash-b,thermal-watch,thermal-stress,bench-run,bench-install,serial-run,serial-log,oob-gs1-activate,win-x86-rootfs,win-x86-run,waydroid-proxy-setup,charge-ctl,charge-watch}.sh`、`scripts/wd-net-baseline.dev.sh`（设备侧 Waydroid 网络基线采集：`ip rule`/table 99·1002/网关 ping/出网 curl/netd 错误） |
| Q28 显示取证 + 跨重启串口抓取（2026-10-09/10 新增） | `scripts/q28-boot-cycle.sh`（温启→零写盘 `fastboot boot` 诊断内核→取证，单轮 GOOD/BAD，SSH over USB-NCM，本机无 adbd）、`scripts/q28-ab-delay.sh`（同时间窗 base/exp 各 N 轮统计坏发率，判 delay 能否压制 Q28）、`scripts/q28-verdict.sh`（串口日志三层判 GOOD/BAD：L1 cmd-DMA/panel-init、L2 ctl-reset/frame-done/vblank）、`scripts/q28-devprobe.sh`（设备端三态 NOCARD/STORM/GOOD，POSIX sh，只数风暴签名会把「无 card0」误判 GOOD）、`scripts/q28-race-hunt.sh`（设备端 rpm tracepoints 密集复现 power-on 竞态、零构建）、`scripts/serial-logger.sh`（ttyACM 跨重启自动重连抓取，pid `/tmp/q28_serial_logger.pid`）。**⚠️MIGRATION-LOST(2026-10-17)：本行的 `q28-boot-cycle.sh` / `q28-ab-delay.sh` / `q28-verdict.sh` / `q28-race-hunt.sh` 四个脚本本机已无**（2026-10-17 换机未随迁）⇒ 按 `TASKS` §5 Q28 配方重放；现存只有 `scripts/q28-devprobe{,2}.sh` |
| BL 解锁（**未解锁单元前置**） | `scripts/bl-preunlock-evidence.sh`（locked 基线取证 + 打印申请表两项）、`scripts/bl-unlock.sh`（校 SN → `flash unlock` → `oem unlock-go`，逐条执行） | U2 基线已采：`backup/HA2EXB0E-16+512/pre-unlock/`（Widevine **L1**、by-name 119 项、传感器清单、getprop 全量 + SHA256SUMS） |
| **C10 马达透传链** | `scripts/elden-hapticd.c`（宿主桥 daemon：aw86927 FF_RUMBLE + `--amp-a/--amp-b` 每侧强度 + `amplitude` 缩放 + 自清 `activate`）+ `scripts/build-hapticd.sh` + `scripts/waydroid-haptics-setup.sh`（桥部署/验证）+ `patches-userland/waydroid-haptics-aidl/`（自编 **AIDL V2** vibrator HAL 源码）+ `scripts/waydroid-haptics-aidl-deploy.sh`（零写盘 bind 部署）+ `patches-userland/elden-vibration-overlay/`（静态 RRO：Settings 强度档位 1→3）+ `scripts/waydroid-haptics-bake-patch.py` / `waydroid-haptics-bake-vendor.sh`（**固化进 vendor.img**：`m vendorimage` → 原子替换 → 验证）; 设备侧 `/usr/local/bin/elden-hapticd` + `/etc/init.d/elden-hapticd` + `/etc/conf.d/elden-hapticd` | 2026-10-13 上机验收：零 bind 挂载的固化态 + 幅度/cancel/每侧强度实测；回退镜像 `vendor.img.bak-elden-haptics-20261013-115055` |
| C4 传感器链 | `scripts/eldroid-sensord.c`（数据源 daemon：fake/stdin→UDP，selftest 7/7）+ `scripts/build-sensord.sh`（native+aarch64 static）+ `scripts/deploy-sensors-hal.sh`（Waydroid overlay 部署）+ `env-pass/scripts/sensor-send-termux.sh`（真值转发） |
| AVF 离线提取 | `scripts/extract-avf-assets.sh`（从原厂 system 镜像 debugfs 取 crosvm/vm/microdroid_kernel/u-boot.bin，无需设备） |
| C0 真机取证 | `scripts/c0-android-evidence.sh`（adb 采身份/DRM/传感器/分区，输出 `backup/<SN>-<档>/c0-baseline/` + SHA256SUMS；手工项见脚本尾提示） |
| 磁盘/挂载工具 | `qemu-img`/`qemu-nbd` 已装（A13 ✅）；fstab nofail 已修（A18 ✅） |
| **UEFI 变体构建 / p7 阶梯（G1-29）** | `scripts/uefi-build-variant.sh`（唯一构建入口，配方进 manifest）、`scripts/uefi-repack-v2aligned.py`（payload → boot v2/base0）、`scripts/uefi-r21-p7-ladder.sh`（**p7 一族唯一重建入口**：`--list/--verify/--mkimg-only[--rebuild]`，配方 = `patches/uefi/p7-recipe.txt`）、`scripts/uefi-sbstop-patch.py`（cmdline 令牌，`--probe N` 写第二个令牌 `sbprobe=N`）。**逐目录分级**（活/已废）= `../versions/patches-uefi-status.tsv`，人读面 = `../patches/uefi/README.md` |
| **全量脚本** | 上表仅列构建/刷机链骨干；**全量清单 = `../versions/scripts-inventory.tsv`**（2026-11-06 起，机器生成：`python3 scripts/static-scan.py --inventory`，列 = path/行数/字节/live/hist/verdict；`HIST-ONLY` = 只能从历史记录得知的入口，`UNREFERENCED` 需人工裁决，见 `../PITFALLS/sessions/15-过时废弃功能缺陷登记.md` §15.1）；人读面 = `ls scripts/*.sh`（含快环 `scripts/iterate.sh` 四档环、`mod-loop/kexec-boot/to-fastboot/flash-b/cycle` 均自锁、`device-lock.sh` 设备锁、`build-manifest.sh` 版本指纹、`audio-alsa-init.sh` 裸 ALSA 路由、`apply-kernel-fragment.sh` 模块化片段等） |
| 低频但现役的诊断件（2026-11-06 补登记） | `rootfs/vk-probe.py`（ctypes 直调 Vulkan loader 枚举物理设备，本机无 `vulkan-tools`；G1-8 基准用）、`initramfs/probe-device.sh`（initramfs 内 DT/`msm-id`/`board-id`/reserved-memory 一次性 dump，bring-up 现场用）、`scripts/rambuild.sh`（内存盘构建区助手，设计见 `.pi/plans/2026-10-15_081500-内存盘构建区规划.md`）——这三件在 `scripts-inventory.tsv` 里无 live 引用，**不是废件** |

### 2.2 可上机资产（**设备无关**，任一单元通用）

| 资产 | 路径 | 状态/校验 |
|---|---|---|
| RAM 版基线（零写盘 bring-up） | `out/boot-elden-vk40-ram.img`、`bootslot-b/boot_b_vk40-ram.img` | ✅ 已签（testkey+rollback 1738713600）；⚠️MIGRATION-LOST（产物已轮转，2026-11-05 实测不在盘） |
| 持久版基线 | `out/boot-elden-vk40.img`、`bootslot-b/boot_b_vk40.img` | ✅；⚠️MIGRATION-LOST（同上，`out/` 侧已不在盘） |
| 全模块包（1484 个 `.ko`） | `out/modules-7.2.0-debug-gba28ec16f01f-dirty.tar.gz`（20 M strip） | vermagic 必须与内核一致；⚠️MIGRATION-LOST（2026-11-05 实测不在盘，可由 build/ 树重编） |
| 相机模块包（20 个） | `out/camera-modules/` + tar | ✅ 冷启自加载已在机验证；⚠️MIGRATION-LOST（目录 2026-11-05 实测不在盘） |
| **运行内核对齐模块包**（25 个，g4c68eb5ed4e3） | `out/camera-modules-7.2.0-debug-g4c68eb5ed4e3-dirty.tar.gz` | ✅ sha256 `4146dfd0…`；持久根相机/音频已复现（`archive/topics/KMOD-ALIGN-2026-10-05.md`）；⚠️MIGRATION-LOST（2026-11-05 实测不在盘） |
| **持久 rootfs 归档** | `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` | 3.44 GB / 30852 项，tar/gzip 完好 |
| **Waydroid Mesa 26.1.8（bionic，自编）** | `external/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz`（`~/mesa-out` 是指向它的软链；6.9 M，**11 个 .so**：`libgallium_dri` / `libgbm_mesa` / `dri_gbm` / `libgbm_mesa_wrapper` / `egl/{libEGL,libGLESv1_CM,libGLESv2,libGLES}_mesa` / `hw/{vulkan.freedreno,gralloc.minigbm_gbm_mesa,gralloc.gbm}` + `manifest.txt`） | sha256 全 OK，含 DRM chip-id 魔数 `0xffff44050000`；**重建** = `scripts/mesa-build.sh`（freedreno-only 定向 make，5.5 min；ccache 热 ~10 min）；部署 = `extract-mesa-libs.sh`+`waydroid-mesa-swap.sh`（bind-mount，可回退） |
| Waydroid 镜像 | `~/下载/` GAPPS `system.zip`(1.17 G) + MAINLINE `vendor.zip`(77 M) | ✅ |
| x86 chroot 资产 | `pkgs-x86/`（ubuntu-base-arm64、box64 0.4.5、Strings64） | ✅ PoC 已通 |
| 原厂分区备份 | `backup/stock-259/`（abl/boot/dtbo/init_boot/recovery 双槽 + SHA256SUMS） | ✅ |
| U2 259 原厂 EDL dump | `backup/HA2EXB0E-16+512/stock/`（boot_b/dtbo_b/vbmeta_b/vbmeta_system_b/recovery_b，降级前状态） | ✅ |
| **U2 1.1 降级完整包**（当前状态恢复源） | `~/文档/TB322FU_ZUXOS_1.1.11.073/image/`（boot/dtbo/vbmeta/vbmeta_system/recovery/init_boot/vendor_boot + 全 6 LUN gpt + 全部固件 + super sparse） | ✅ 完整 |
| **U2 b 槽 mainline 链**（unlocked 用） | `bootslot-b-u2/{boot_b,vbmeta_b,dtbo_b}.img`（testkey 全链，rollback 1738713600，`--follow_chain_partitions` 验证全绿） | ✅ 2026-10-03 |
| **f2fs 起根物料**（2026-10-25 上机完成） | `out/boot-elden-f2fs-root.img` + 同名 `.manifest`（cmdline `elden_root=LABEL=linux18`、内核 = vk152 `b6a074ff…`）；签名件 `bootslot-b/boot_b-f2fs-root.img`（100 663 296 B，sha256 `257266ec…`，**已写 `boot_b` 并读回一致**） | ✅ 真 POR 起根 + 首启后 `fsck.f2fs` 全 Ok；手术前 GPT 双表 `backup/HA2EXB0E-16+512/gpt-20261025/`，写盘往返留档 `backup/f2fs-migrate-*/` |
| GPT 快照（**234 GiB 档专属**） | `backup/gpt/gpt_*_device.bin` | ⛔ 禁止用于 512 档 |
| 固件子集 | `backup/fw/{vendor,modem,bluetooth,dspso,gen80000_*}` | 见 `backup/fw/README.md` |
| AVF 资产（**离线提取，不需设备**） | `backup/avf/`：`com.android.virt.apex` + `apex_payload.img` + `bin/{crosvm,vm,virtmgr,virtualizationservice,vmnic,vfio_handler,fd_server,early_virtmgr}` + `etc-fs/{microdroid_kernel(6.6.77-android15-8),microdroid_super.img,microdroid_vbmeta.img,microdroid_initrd_{normal,debuggable}.img,u-boot.bin,rialto.bin}` + SHA256SUMS | ✅ 2026-10-04 从原厂 259 镜像 `/mnt/Samsung/l2/system_a.pristine.img` 离线提取；`scripts/extract-avf-assets.sh` 可复原；crosvm 含 Gunyah/Geniezone/KVM 后端 → **GAPS Q13 资产部分已闭** |
| 过环境栈 | `env-pass/`（模块 + `repack_module_zip.py` + 检测器 APK + 内核产物） | Native Detector = normal |
| env-pass provision | `env-pass/scripts/envpass-provision.sh`（状态预检+自动 repack+幂等，A17） | --check 干跑通过 |
| C4 HAL 产物 | `waydroid-build/out/.../vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid`（25 KB，UDP 实现）+ overlay 部署脚本 | 已编译（2026-10-03，32 s）；上机后用 `deploy-sensors-hal.sh` |

### 2.3 主机大容量资产（占盘大户，勿误删）

> **2026-11-02 起**：设备的可重建工作区也归项目内 `external/`（`mesa-out`/`lc-cross`/`alpine-sysroot`/`phoc-work`/`aosp-vndk33`），
> 原 `~/` 路径保留**同名软链**（文档与 cross-file 里的绝对路径不用改）；`external/` 与 `wt/` 均 gitignore。

> **2026-11-03 状态**：外置盘 `/mnt/Samsung` **未挂**（`~/mnt/Samsung/l2` 只剩 16 K 脚本，`./l2` 软链已移除、唯一副本已收进 `tools/l2-extract/`）⇒ 下表前两行目标**本机不存在**；本机现盘最大项 = `build/` 185 G、官方线刷包 16 G、`out/` 6.8 G。

| 路径 | 内容 | 规模 |
|---|---|---|
| `/mnt/Samsung/waydroid-build` | Waydroid AOSP 树（1254 项目 / 1219 对象库 fsck 全 OK） | 550 G（**2026-10-16 告知将随盘清空**：本地提交已推两个 USTC 仓、树外件已留档 `reference/waydroid-buildtree/`、构建产物 `vendor.img` 已进云盘包 ⇒ 可清） |
| `/mnt/Samsung/l2`（本 repo `./l2`） | 原厂 super / system_a / system_a.pristine（sha256 逐侧一致）；**stock-259 13 分区备份里没 super，这里是唯一一份**；自研 `lp_tool.py`（LP v1.2 dump/extract/splice）唯一副本 | 45 G |
| `external/mesa-out`（`~/mesa-out` 软链） | Waydroid bionic Mesa 构建产物（11 `.so` + `manifest.txt`），即上表自编产物的落地包；**2026-11-02 从 `~/mesa-out` 迁入项目** | ~7 M |
| `external/lc-cross`（`~/lc-cross` 软链） | libcamera v0.7.1 源码 + 交叉构建树（b-dbg/b-time/b-gcc）；相机 AE/sensor helper 改动的工作区 | ~450 M |
| `external/alpine-sysroot`（`~/alpine-sysroot` 软链） | 设备侧 sysroot（include + lib，含 libyaml），aarch64 musl 交叉编译用 | ~94 M |
| `external/phoc-work`（`~/phoc-work` 软链） | phoc 合成器源码/补丁工作区（`patches-userland/` 的构建源） | ~9 M |
| `external/aosp-vndk33`（`~/aosp-vndk33` 软链） | VNDK33/AIDL 头与接口源（相机 HAL 交叉编译的依赖面） | ~74 M |
| `backup/fw/tb322fc-edl/`（`~/下载/tb322fc` 软链） | EDL 全量包 65 件（rawprogram/patch/firehose）；**2026-11-03 从 `~/下载` 收归项目**，原路径留同名软链 | 599 M |
| `backup/official-rom-15.10.259/`（`~/文档/TB322FC_15.10.259` 软链） | 官方全量线刷包（`super_1..8.img` 合计约 15 G 为 `super_4.img` 独占；含 `uefi.elf` 5.0 M / `abl.elf` / `xbl_s.melf` / `NON-HLOS.bin` / `dspso.bin` / GPT 双表 / `rawprogram*.xml`）。**2026-11-03 从 `~/文档` 收归项目**，原路径留同名软链；`backup/stock-259/` 只是其中 13 个分区的子集 | 16 G |
| `external/ext-repos/`（`~/ext-repos` 软链） | **Y700/UEFI 专用上游 clone**：`mu`（Mu-Silicium 主仓，403 M）、`dl`（245 M）、`mu-dodge`（dodge 的 4 个 UFSDxe 文件）、`sunuefi`（20 M）、`af`、`vk64rd`。**2026-11-03 从 `~/` 收归项目**（原判为「机器级」有误：内容 100% 本机型专用） | 1.1 G |
| `stock-src/` | 联想 GPL 源码 | 2.0 G |
| `~/.cache/ccache-elden`（**仓库外**，机器级构建缓存） | 内核构建 ccache；不入库、不属项目资产，但是本机最大项目相关占盘项之一（清理前须确认无构建在跑） | 13 G |

> **GPU 栈编译账（2026-10-06）**：宿主用户态 **0 编译**（Alpine apk），内核属 G1 主线；
> Android 用户态 = **1 组 11 库（已交付）**；剩余仅偶发 Mesa 重编（~10 min）与可选 `make vendorimage`（1–3h）。
> 逐层表见 `../TASKS/README.md` §6 §6-C。

### 2.4 归档区（本轮合并结果，不再更新）

`archive/2026-10-02-merged/`：`MISSION-SCOPE.md`、`DEVICES.md`、`ANDROID-COMPAT-PLAN.md`、
`ROUTE-DECISION-2026-10-02.md`、`PLAN-NODEV-2026-10-02.md`、`DOCS-CHANGELOG-2026-10-02.md`
—— 内容已并入 `../DEVICE/README.md` / `../TASKS/README.md` / `../TASKS/README.md §6` / `../TASKS/README.md §5` / `README.md`，仅留原文以便追溯。

另：`archive/topics/资料汇总-2026-09-30.md` + `L2-修剪流水线-2026-09-30.md` = 已退役的 `~/y700类原生安卓/` 项目全部文档（2026-10-02 并入）。
L2 原厂 system 修剪（super 拆包 → debugfs 删包 → e2fsck → splice 回拼 → 刷 super）**流水线已跑通但未刷入**，build 1 释放 519 MB；
要继续则从该文档 §下一步 接上（关键坑：debugfs `rm` 不同步位图，必须 `e2fsck -fp` 收尾；OTA 彻底失效是固定代价）。

### 2.5 资产瘦身优先级（**已作废，2026-11-03 下沉归档**）

> 原 2026-10-02 的 P 级方案自注「数字大量过期」且**从未执行**，已被 2026-10-23 全量对账（A0–A7）取代：
> **现行清理纪律 = 本节 §3.3 可清理标记 + `reports/assets-inventory-20261023.md` §5**；2026-11-03 整理 = `reports/asset-tidy-20261103.md`。
> 历史方案原文 → `sessions/2026-11-03-资产瘦身优先级-1002审计.md`。



## 2.9 本角度的会话记录（`sessions/`，逐文件登记）

> `RESOURCES/` 是**逐文件登记**角度（门：`check-doctor` §8 `INDEXED_ANGLES`）：新增会话文件必须在下方列一行，
> 否则收尾自检 FAIL。`TASKS/sessions/` 是例外（按日期滚动，篇数现查 `ls TASKS/sessions | wc -l`；按主题在 §1/§5/§7 引用，不做逐文件登记）。

| 会话 | 主题 |
|---|---|
| `sessions/2026-10-22-外部同机型仓库复用盘点.md` | 外部同机型仓库复用盘点 |
| `sessions/2026-10-23-资产台账与磁盘真值对账.md` | 资产台账与磁盘真值对账（A0–A7 清理依据） |
| `sessions/2026-10-26-denial-droidloom深度评估.md` | denial/droidloom 可搬资产评估 |
| `sessions/2026-11-02-资产与经验技能收归仓库.md` | 记忆/技能/会话/工作区收归仓库 |
| `sessions/2026-11-03-项目整理.md` | 本轮整理（外部资产收拢 / 布局注册表 / SSOT 瘦身 / 纠错） |
| `sessions/2026-11-03-顶层台账快照-20261023.md` | 顶层台账 2026-10-23 快照（§3.2 收口归档） |
| `sessions/2026-11-03-资产瘦身优先级-1002审计.md` | 资产瘦身 P 级方案原文（§2.5 作废归档） |
| `sessions/2026-11-03-Project-SunUEFI复用盘点.md` | Project-SunUEFI（piano/SM8750）可复用资产盘点：UEFI 自研 UFS 栈 / 合体 BOOT / 屏上插桩法 / 内核补丁对照表 |

## 3. 文件与资产台账（FILES）

### 1. 版本控制边界（`.gitignore` 权威）

- **纳管（track）**：文档、脚本、内核补丁与 config、AI 记忆/技能/任务、小体积证据。
- **排除（ignore）**：上游 clone、构建产物、可再生成物、大二进制 dump、运行时状态、设备敏感数据。
- git 仓库根 = 本目录；分支 `main`。上游内核树 `geekidos-linux/` **不是** submodule，其进度以 `patches/` 为准。
- **异地备份（2026-10-04 起）**：顶层仓 `origin` = `git@git.ustc.edu.cn:xqh/y700-elden`（@xqh，SSH key `~/.ssh/id_ed25519_gitlab_ustc`，全分支+标签）——**这条仍然现役**。
  - ⚠️ **2026-10-24 起 `origin/main` 有意落后**（用户裁定「暂时落后」）：本地历史因剔除一个 2.75 GB 的
    `reports/trials/*/serial-delta.log`（曾触发 GitHub 100 MB 拒收）被重写，`origin/main` 是**保护分支**拒绝 force push，
    故 origin 停在旧 `ad7c6fb`；**权威远端 = GitHub**（已推 `59b93a6`）。
    ⇒ 本地已设 `remote.pushDefault=github` + `branch.main.remote=github`，`git push` 默认只推 GitHub。
    若要恢复 origin：先在其 Settings→Repository→Protected branches 临时放开 `main`，再
    `git push --force-with-lease origin main`（该 2.75 GB 文件仍在磁盘、已 gitignore，不入库）。
  - **最近一次复核同步（2026-10-16）**：把积压的 **181 提交 + 工作树**补推为 `main=3d98885`，并补齐本地独有的 **3 个分支**
    （`audit/early-reboot` / `lane/doctor-refactor` / `lane/upstream`）与 **8 个标签**
    （`base/2026100{5,5,12,14}-*` / `merge/{bootchain,bootslim,userland-session}` / `pre-docs-v2`）
    ⇒ **复核后 `origin` 与本地 refs 完全一致（5 分支 / 57 标签，`main` 零欠账）**；GitHub 镜像同批同步（含 `history/pre-vk34`）。
  - **本地独有工作 = 三条通道（2026-10-16 落，2026-11-02 修订）**：
    - **① 项目记忆本来就在仓库里**：唯一可写面 = `.pi/memory/`（`MEMORY.md` + `skills/*/SKILL.md`），
      全局 `~/.pi/agent/projects-memory/<repo>` 只是指向它的**符号链接**（`mem -t project` 等老入口仍可用）；
      自检 `scripts/check-project-memory.sh`（`--fix` 可重建软链）。
      **2026-11-02 前**的做法（仓库外活文件 + `sync-hermes-memory.sh` 单向快照进 `.pi/hermes-memory-mirror/`）已废弃：
      镜像目录删除，旧脚本留档 `archive/2026-11-02-hermes-mirror-retired/`。
    - **② 不可重下的大二进制 → 云盘**：`scripts/pack-cloud-backup.sh [DEST]` 按 **T1/T2** 硬链接整理（link count=2，**0 额外占盘**）+ `MANIFEST.sha256`；
      清单/理由 = `../reports/cloud-backup-manifest-20261016.md`。已生成 `~/cloud-backup-y700-elden-20261016/`（**6.9 G / 3594 文件，sha256 全验 OK**）⇒ **待用户上传云盘**。
      分层：**T1** 不可再生（设备独有分区/GPT/解锁前取证/内核 bundle/AVF/rootfs 归档）· **T2** 可重下但代价高（原厂厂商资产/EDL 全量包/厂商工具）·
      **T3-sessions** = `.pi/sessions/`（体积/会话数**以备份当时的 MANIFEST 为准**；**真实拷贝**冻结快照，非硬链接）。
    - **③ 会话轨迹 → 云盘**：见上 T3-sessions（2026-10-16 用户指示纳入）。
  - **仍未站外备份**：**内核现役线**——只有本地 bundle（本机无 `reccli-ts`/rclone ⇒ **云盘路未落，bundle 已在 T1 包内待上传**）。
  - **Waydroid 树（`/mnt/Samsung/waydroid-build`）的本地提交 → 两个 USTC 仓**（2026-10-16 核，服务端 `ls-remote` 与 HEAD 一致）：
    `device/waydroid/waydroid` → `xqh/y700-elden-waydroid-device`（`elden/lineage-20` = `79de788`）；
    `hardware/waydroid` → `xqh/y700-elden-waydroid-hardware`（`elden/lineage-20` = `944b06a`）。
    **全树 1254 项目已扫：无任何项目存在「不在任何远端」的本地提交**（`rev-list --branches --not --remotes` 全 0）。
    树的**树外本地件**（`.repo/local_manifests/*.xml`、构建脚本、日志、`PROGRESS.md`）留档在 `reference/waydroid-buildtree/`；
    文本 diff = `patches/waydroid-buildtree-local-20261016.patch`（23 文件，**取代**过期的 `-20261011` 版——后者缺 10-13 的 vibrator/haptics 提交）。
    > 背景：`/mnt/Samsung`（`waydroid-build/` 530 G + `l2/` 47 G + `ccache` + `fiotest`）**2026-10-16 用户告知将清空** ⇒ 清空前已完成上述核对、留档与云盘打包。
- **内核 gitlab 镜像 = 归档中（2026-10-08）**：本地侧已冻结完成；**服务端 Archive 待用户在网页点**（本机浏览器无 git.ustc.edu.cn 登录态、无 API token，agent 不代填凭据）。页面路径：项目 → **Settings → General → Advanced → Archived project → Archive project**（与它相邻的 **Delete project 不要碰**）；或 API：`curl --noproxy '*' --header "PRIVATE-TOKEN: <token>" -X PUT https://git.ustc.edu.cn/api/v4/projects/xqh%2Fy700-elden-kernel/archive`。`xqh/y700-elden-kernel`（本地 remote 已改名 `gitlab-archived`，`pushurl=no-push://…` 本地拦截 push，fetch 仍可用）。它的内容是 **2026-10-04 的回填合成线**（tip `fe54fcfff` = vk48 draft，10 提交含一个合成 base 提交），与现役线 `elden/vk53-hw`（19 提交）**无祖先关系**（已实测 merge-base 为空）；该线在本地由分支 `archive/gitlab-mirror-vk48` 固定。**为何不能更新**：`geekidos-linux/` 是 **shallow 仓**（`.git/shallow` graft 于 `ba28ec16f`），服务器拒绝任何 shallow 更新（实测 `! [remote rejected] … (shallow update not allowed)`，**force push 同样不行**）——与 10-04 当时记的「因 shallow 不能直推」同一回事。映射见 `archive/2026-10-04-git-backfill/VERSION-MAP.txt`，内核增量补丁集见 `patches/kernel-history/`（这两者才是内核历史的权威文本记录）。
- ⚠️ **内核仓现役线目前无站外 git 备份**（镜像冻结、`origin` 是上游 GEEKiDoS 不是我们的）。现役可用备份 = `backup/kernel-git-repair-2026-10-23/elden-all-refs-66.bundle`（**实测 303,660,780 B ≈ 290 MB / 67 head-ref，含 vk34→vk127**；体积/号段一律现查 `ls -l backup/kernel-git-repair-*/*.bundle` + `git bundle list-heads`。原 2026-10-08 / `elden-all-refs-1820.bundle` **目录已不在盘**）。要恢复站外备份只有两条路：① 把 bundle 传云盘（技能 `ustc-cloud-drive`，零 git 约束）；② `git fetch --unshallow origin` 补全上游历史后新建项目推（要下 1–2 GB，与「避免重复下载大文件」相左，需拍板）。
- ⚠️ gitignore 注释必须独占一行（行尾 `#` 会被当作模式一部分，静默失效）。

### 2. 顶层台账（**入口已收口，不再维护本表**）

> **2026-11-03 收口**：本表原先与 `INDEX.md` §2「顶层布局」47 行表、`versions/layout.tsv`（机器真源，46 项）
> **三份同构**，且体积列冻结在 2026-10-23 后已漂 ⇒ 现行只读三处，本文件不再维护：
> **① 机器真源** `versions/layout.tsv`（门 = `scripts/check-layout.sh` / `check-doctor` §14）；
> **② 人读面** `INDEX.md` §2「顶层布局」；**③ 体积**一律现查 `du -sh <路径>`（不写死）。
> 2026-10-23 那次的 49 行快照与逐项处置说明 → `sessions/2026-11-03-顶层台账快照-20261023.md`；
> 盘点权威报告 = `reports/assets-inventory-20261023.md`，2026-11-03 整理（外部资产收拢 / 3.0 G 冗余删除 / git 树 450 M→201 M）
> = `reports/asset-tidy-20261103.md`、`reports/git-tree-consolidation-20261103.md`。**删除纪律见 §3**。


### 3. 可清理标记（不动手，等确认）

编号对应 `README.md` §2.5 的 P 级；状态：⬜ 未执行 / ◐ 部分 / ✅ 已执行 / ⛔ 无需执行。
**2026-10-23 复核**：A0–A7 见 `../reports/assets-inventory-20261023.md` §5；**用户 2026-10-23 批准后已全部执行**（执行记录 + 每级 df + 保留理由 = `../archive/topics/清理清单-20261023.md`）。
**2026-11-05 复核**：全仓逐项盘点（含引用命中/可再生性/前置闸）= `../reports/asset-tidy-20261105.md` + 机器账 `../reports/asset-inventory-20261105.tsv`（56 行，含每行 `verify_cmd`）；文档账目 = `../reports/doc-audit-20261105.md`。本轮**执行了 A8 + B1**（B1 见下表），B2–B4 仍待批。
**2026-11-09 清理轮（用户当面批准「可以删掉冗余文件」）**：删 UEFI **判死世代**镜像目录 `out/r21-sbstop-p8…p53`（44 个目录）+
`out/real-ladder` + 历史取证目录 `reports/artifacts/uefi-{ddr,ddrcut,posctrl}-2026110{1,3}` 与 `uefi-20261107R33…R40`（6 个）+
5 个「内核段解不出/无版本号」镜像；**根分区 519 G→508 G**、`out/` 8.8 G、`reports/artifacts/` 2.3 G。
保留 = `out/r21-sbstop`（p7 基点）+ `out/r21-sbstop-p54…p61`（`--gen` 可复现）。**设备 GPT 原始双表**删前已转存 `backup/lun4-gpt-20261101/`。
逐项账（含重建入口）= `../reports/asset-cleanup-20261109.md`；候选来源 = `../.pi/plans/2026-11-09-整理候选清单.md`。

**2026-11-05 完整性基线（BIOS 静默损坏事件后设）**：`../versions/out-images-sha256-20261105.tsv` = 129 件镜像的 sha256 + 是否入账 + manifest 比对 + 第 7 列 `path`（含 114 件已归档件）；全仓校验报告（重试定性）= `../reports/integrity-audit-20261105.md`。复算须走 `O_DIRECT`（页缓存会给出错哈希，`PITFALLS #513`）：表头注释带完整命令（`awk ... print $1"  "$7` 后逐件 `dd iflag=direct | sha256sum`）。

| 标记 | 目标 | 体积 | 前置闸 | 状态 |
|---|---|---|---|---|
| **A0** | `.pi/trash/`（含 5.07 G 云盘包 tar） | 21 G | 先抢捑（已做，2 件恢复） | ✅ **2026-10-23 已执行** |
| **A1** | `build/` 可弃 worktree | 7.45 G（仅 `vk83-tree` + `linux-7.2.tar.xz`） | 对象留 `geekidos-linux` | ✅ **已执行（部分）**：其余 6 棵为活跃车道，保留 |
| **A2** | `backup/kernel-git-repair-2026-10-08/` | 265 M | 逐 ref 覆盖 | ✅ **已执行** |
| **A3** | `backup/git-pack-repair-20261020/` | 574 M | 对象归属核实（全为上游内核对象） | ✅ **已执行** |
| **A4** | `out/` 旧镜像 + `*-unpack/` | ~0.5 G | registry 已登记 | ✅ **已执行**（3 unpack + vk130/vk131） |
| **A5** | `logs/cam-*` | 190 M | 结论已在 `reports/` | ✅ **已执行** |
| **A6** | `dl-cam/` 下载件/中间物 | 8.8 G（apparent 10.8 G） | 配方在 `patches/waydroid-camera-64bit-20261018/` | ✅ **已执行**（仅留 `hw-interfaces/`+`donor/`） |
| **A7** | `pkgs/` 空目录 | 4 K | 无 | ✅ **已执行** |
| P0-a | `/mnt/Samsung/fiotest/` | — | — | ⛔ **目标不存在**（外置盘未挂） |
| P0-b | `geekidos-linux/` 构建产物 | — | — | ✅ 换机后已无旧构建产物（现 2.9 G）；后续口径见 A1 |
| P1-a | `out/` `bootslot-b/` 旧镜像 | — | — | ◐ 现 2.4 G / 22 img，逐号裁决见 A4 |
| P1-b | `pkgs/ pkgs-phosh/ pkgs-x86/` | 639 M→4 K | 无 | ✅ **已清**（只剩空目录） |
| P2-a | `env-pass/{build,kernel-susfs}` | 494 M | — | ✅ **已清**（目录不在） |
| P2-b | `backup/rawdump.img` 压缩 | 256 MiB | 无 | ⬜ 仍在 |
| P2-c | 重复快照（`flashing-bundle/`、`y700-elden-docs-*.tar.gz`） | ~30 M | 保留最新一套 | ◐ tar.gz 已归档；`flashing-bundle/` 目录已不存在 |
| P2-d | `backup/stock-259/` 13 分区 | 443 M | 须先核对云全量包含 abl/dtbo/recovery/vbmeta 且 =1.5.10.259 | ⬜ 仍在 |
| P3-a | AOSP `.repo` 历史 + 工作树（外置） | — | — | ⛔ 目标不存在（`/mnt/Samsung/waydroid-build` 未挂，随盘清空） |
| P3-b | `l2/` super/system 镜像 | — | — | ⛔ 目标断链（`~/mnt/Samsung/l2` 空） |
| H1 | `.pi/sessions/` 旧会话 | **705 M / 290 件**（2026-11-05 复测，原 496 M） | 归档非活跃会话（保留最近若干） | ⏸ **挂起 = 用户统一操作**（先上云盘再本地瘦身；索引已完成为 2026-10-17 口径） |
| **A8** | `reports/artifacts/uefi-dxe{,2..11}-20261104/` 二进制载荷（77 件，7 类/目录） | 236 200 182 B | 已打包 `backup/artifacts-bundle-20261105/uefi-dxe-20261104-binaries.tar.zst`（45.9 M，`zstd -t` OK、抽检 sha 一致）+ `SHA256SUMS.all`（77 行） | ✅ **2026-11-05 已执行**（净释放 ≈ 172 MiB；文本三件 `build.log/manifest.txt/SHA256SUMS` 与 `BootShim.bin` 留原处） |
| **B1** | `build/` 旧线 worktree（29 棵：vk151 / vk-camssv3 / gunyah-port / m3v5-{fix,daily,pristine} / m4-* / b5-* / m8ab-* / q28-* / m1-73 / vk64-{sync,ret}-arm 等） | 释放 **174 G**（`build/` 190.7 G → **16 G**） | 逐棵：detached HEAD 先建 `tidy-20261105/<name>` 保留 ref；脏树导出 `tracked.diff` + `untracked.tgz`；共享 `.git` 整体备份 `backup/build-bundles/m3v2-7.3rc7-git-20261105.tar.zst`（1.33 G，含全部 142 个未推送提交 + 26 个 worktree 元数据，已抽验） | ✅ **2026-11-05 已执行**（明细 `backup/build-bundles/MANIFEST-20261105.tsv` + `dirty-20261105/*/`；新增日常线树 `build/daily` = `replay-m1-73-vk127` + `patches/config-vk163-modular-v2-20261026`，`patches/current-tree` 已改指它） |
| **B2** | `env-pass/backup-20261002/`（2026-10-02 老 rootfs 整包 3.44 G） | 3.44 G | 先验证 `rootfs/` 重建链能覆盖 10-02 时期内容 | 🛑 **结案 = 用户 2026-11-06 裁决「backup 不上云、留在本地即可」** ⇒ 本项不再执行、不再每轮询问；文件继续留盘（盘上可用 456 G，无压力） |
| **B3** | `out/` 历史镜像（129 件 `*.img`，8.78 GiB） | 已归档 7.66 GiB / `out/` 剩 1.12 GiB | **账目闸**：每件都在 `versions/vk-kernel-identity.tsv` 有行 ⇒ 不能删；改为**脚本同时扫归档目录**（`scripts/vk-identity.py` 的 `out_images()`）⇒ 账表一行未改、新鲜度门 `C=0` | ✅ **2026-11-05 已执行**：114 件 `mv` 到 `backup/out-history-20261105/`（逐件 sha 账 `ARCHIVE.tsv` + `ROLLBACK.sh`），`out/` 只留 15 件在机/在用/取证件；脚本 `scripts/out-archive.py`；执行账 `../reports/out-archive-20261105.md`。**净释放 0 字节**（同盘 rename），真回收需 `tar.zst` 或上云后删（未做） |
| **B4** | `.pi/trash/files/`（pi 回收站，90 项） | 484 M | 无（回收站语义） | 🛑 **结案 = 用户 2026-11-06 裁决「trash 不用清理，等用户自己清」** ⇒ 本项不再执行、不再每轮询问（`.pi/trash` 受 harness 保护，agent 也确实删不动） |

**纪律**：按 P0→P3 逐级、不并行；每级前后记 `df -h`；删前先导出独有内容；删后回改
`README.md §2.5` 与本节状态、并记 `archive/topics/清理清单-<date>.md`。

### 4. 日常 git 工作流

```bash
cd ~/y700-elden
git status                      # 看改动（大文件已被 ignore，不会刷屏）
git add -A && git commit -m "..."   # 文档/脚本/补丁/记忆 改动
git log --oneline -10
```

- **内核改动**：在 `geekidos-linux/` 改完，务必回导补丁，否则进度只留在 dirty tree：
  `git -C geekidos-linux diff > patches/elden-working-tree-$(git -C geekidos-linux rev-parse --short HEAD)-$(date +%F).patch`
  并同步 `.config` → `patches/config-vkNN-*`。**这是本仓库版本控制覆盖不到的唯一边界。**
- **内核 per-version 提交（修 F1/F4，2026-10-03 起）**：内核仓库自身 git 已建分支
  `elden/vk40-2026-10-03`（现状）与 `elden/vk34-recon`（回退 post-vk34 增量）。
  `.config` 已开 `CONFIG_LOCALVERSION_AUTO=y` → **每版干净提交后 uname 自动带唯一 commit**
  （如 `7.2.0-debug-g6ef87e6a8868`），设备上可直接分辨在跑哪版。改内核后：
  `git -C geekidos-linux add -A && git commit -m "elden: vkN ..."`，从干净树构建。
- **不要** `git add -f` 大文件；确需留档走磁盘备份 / 云盘，不入 git。

### 5. ⚠️MIGRATION-LOST 迁移缺口登记（2026-10-17，2026-10-23 对账）

> **标记约定**：凡引用下列路径的位置一律带 `⚠️MIGRATION-LOST`；机器可查登记 = `versions/migration-gaps-2026-10-17.tsv`。
> 背景：2026-10-17 换机（`xuqianhui1001`→`xuqianhui`）。**已进 git 的一切 100% 恢复**（443 提交、HEAD `1a4bd89`、origin USTC HTTPS + GitHub 镜像）；
> **未进 git 的大目录与内核 git 线未随迁**，故登记如下（结论只在 `TASKS`/`DEVICE` 维护，此处只登记「资料在不在」）。

| 类别 | 内容 | 状态 | 影响 / 重建路径 |
|---|---|---|---|
| 内核线 | `geekidos-linux` refs `vk87–vk126`、`m1/*`、`m3/*` | ⚠️MIGRATION-LOST（**2026-10-23 复核：仍缺**；但 bundle 已补齐到当前全量） | 现役线（含部署 vk94、`m1-73/baseline` tip `c7da05b1d8`）无提交对象。**2026-10-23 已重做一版全量 bundle**：`backup/kernel-git-repair-2026-10-23/elden-all-refs-66.bundle`（290 M / 67 heads，含 `replay/m1-73-vk127`）；旧的 10-10 pre-boundary（265 M）保留（唯一保存悬空提交 `f61b4b82ca`） |
| 资产树 | `build/`（原 ~4 G） | ✅ **已重建（2026-10-23：40 G / 7 棵）**，但**不是纯可再生** | 两独立仓含本地独有 commit（`base-7.2` 的 `master`/`elden-payload-v2`、`m3v2-7.3rc7` 的 `m3v2`/`replay-m1-73-vk127`）；回收前先 bundle（`reports/assets-inventory-20261023.md` §4.1） |
| 镜像 | `out/*.img`（`vk42–vk126`）+ 归档件 | ◐ **部分重建**：现查 `ls out/*.img back backup/out-history-*/\*.img 2>/dev/null \| wc -l`（2026-11-05 归档后 = `out/` 15 + 归档 114 = 129；vk130/vk131 仅剩 `.manifest`，A4 已删其 `.img`） | 旧号仍缺；`.manifest` 220 个；台架臂不可复跑（在机 b 槽 + `backup/HA2EXB0E` 各留 1 份）；历史镜像路径见 `backup/out-history-20261105/ARCHIVE.tsv` |
| 日志/工具 | `logs/`、`tools/` | ✅ **2026-11-06 `tools/` 已入库**（`.gitignore` 由整目录 `/tools/` 改为 `/tools/*` + 白名单：`avbtool.py`、`l2-extract/`、`gunyah-modules/` 源码；构建产物 `.dtb/.bin/vmmtest` 仍挡；20 个文本文件）；`tools/mkbootimg/` 空壳（只剩 pyc）已删，打包器在 `scripts/mkbootimg.py` | `tools/` 原 232 K → 现 1.0 M（多出来的是 `avbtool.py` 204 K + gunyah 源码）；`wd-audio-test` 仍未迁（C6 工具，`reports/container-audio-20261011.md`） |
| Q28 取证脚本 | `scripts/q28-boot-cycle.sh`、`scripts/q28-ab-delay.sh`、`scripts/q28-verdict.sh`、`scripts/q28-race-hunt.sh` | ⚠️MIGRATION-LOST（2026-10-17；**2026-11-02 复核仍缺**，现存只有 `scripts/q28-devprobe{,2}.sh`） | Q28 取证/采样链的**重放配方**在 `TASKS/README.md` §5 的 Q28 行；§2.1 表内引用处已就地带 `⚠️MIGRATION-LOST` 注 |
| 签名密钥 | AOSP testkey `env-pass/keys/testkey_rsa4096.pem`（`env-pass/` 整目录不入 git） | ⚠️MIGRATION-LOST（2026-10-17；**2026-11-02 复核本机已无该目录**） | 现役 b 槽自签密钥 = **`bootslot-b/avb.key`**（`scripts/sign-boot-b.sh:14` 实际取值）；locked 全链重打 = `scripts/build-locked-chain.sh`；§2.1 表内引用处已就地带注 |
| 可重下 | `edk2-*`、`mu_wide_platforms`、`uefi-firmware-backup`、`qdl`、`twrp`、`pkgs*`、`probe`、`rootfs/{alpine,dl,debs}` | LOST-REDOWNLOADABLE（2026-10-23：仍均为空） | 重下/重建，非硬伤 |

**2026-11-02 新增：两枚镜像静默损坏（不是迁移缺口，是内容坏了）** —— `out/boot-elden-vk155.img`、`out/boot-elden-m3v5-onboard-b.img` 的 boot header 正常、4096 处有 gzip magic，但 zlib 解压 CRC 失败；文件 sha256 与各自 `.manifest` 的 `image_sha256` 不符，而 mtime 未变 ⇒ 不可再作构建身份证据。`check-doctor` §5d 每轮 WARN 报出；损坏前的身份行留档 `reports/artifacts/vk-identity-corrupt-20261102.txt`。重建或删除后本条与 WARN 一并收口。
**已用备份包补回（2026-10-17）**：`.pi/sessions/`（文件数/体积见 `versions/cloud-backup-20261016.MANIFEST.sha256`，含 subagent 工件）、`~/mnt/Samsung/mesa-out/`（Mesa 26.1.8，14 文件）、`backup/fw/vendor/firmware/wlan/*`（11 条软链）。
**核对**：`~/下载/cloud-backup-y700-elden-20261016.tar.zst` 按包内 `MANIFEST.sha256` 全量校验 = **3608/3609 OK、0 缺失**；唯一差异 = `mnt/Samsung/l2/dump-super.sh`（本地版=新机路径适配，实测仅 2 行差，保留本地版）。核对后 **tar 已删除**；清单留档 `versions/cloud-backup-20261016.MANIFEST.sha256`（内容摘要 = `reports/cloud-backup-manifest-20261016.md`）。
另：`~/下载/migration-2026-10.tar.xz`（490 M，dotfiles/secrets 迁移包）**未动**。

> **2026-10-23 对账**：上表状态已按现查刷新；完整逐项（含体积与 A0–A7 清理候选）= `../reports/assets-inventory-20261023.md`。
> 另查得 5.07 G 的 `cloud-backup-y700-elden-20261016.tar.zst` **尚在 `.pi/trash/`**（核对后删除的 tar 落进了回收站，非真删）——随 A0 一并回收。

---

## 4. 会话检索（**不手抄索引、不维护会话数**）

> **会话数量/统计不在这里维护，也不写死**（历史上写过 108 M / 390 M / 162 / 168 / 198 等多个互相矛盾的值）。
> 要数字就现查：`ls .pi/sessions/*.jsonl | wc -l`（顶层会话数）、`du -sh .pi/sessions`（体积）。

**检索入口（按用途选一个）**：

| 用途 | 命令 |
|---|---|
| 本项目会话全文检索 | `scripts/sess.sh <关键词>`（= `PI_SESSION_DIR=.pi/sessions sess …`） |
| 交互式挑选/重命名/分支 | `/resume`（pi 会话选择器，Ctrl+R 改名） |
| 原始 jsonl 全文 | `rg -uuu <关键词> .pi/sessions`（`-uuu` 必需：该目录在 `.gitignore` 里） |

> ⚠ **全局 `sess` 直接跑会漏本项目 95% 的会话**：它默认扫 `~/.pi/agent/sessions`，而项目 `sessionDir=.pi/sessions`。
> 一律用 `scripts/sess.sh`（已包好 `PI_SESSION_DIR`），或 `/resume`。

各角度的会话进度见 `<角度>/sessions/YYYY-MM-DD-<主题>.md`；**逐会话历史快照（已冻结）**见 `SESSIONS/`（仅档案，不再增补）。
