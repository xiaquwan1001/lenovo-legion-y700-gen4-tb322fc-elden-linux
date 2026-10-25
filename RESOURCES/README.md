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
| `denialwm/droidloom`（251★，Rust，2026-09 活跃） | Linux 原生跑 Android 应用（Wayland 直出窗口，shared-kernel userspace）；repo 声称支持 arm64+x86_64 平台，但**预览包只发 x86_64 Arch**（pacman+ship.yml）；自构建一条命令（Rust+rootless podman+AOSP pin，免宿主 sudo） | 跟踪（GAPS Q3）；R1 受阻再试 arm64 自构建 |
| Droid-VM/DroidVM、denial | Android 侧 VM 管理器 / Windows 11 ARM64 on crosvm+Gunyah（**需 Android 宿主**） | 与新前提冲突（a 槽可弃）；只观察（见 `../TASKS/README.md §5` Q4） |
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

### 1.4 方法论 / 运维参考

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
| boot 打包/签名 | `tools/mkbootimg/`、`scripts/sign-boot-b.sh`、AOSP testkey `env-pass/keys/testkey_rsa4096.pem` |
| AVB | `avbtool`（**实测不需 pycryptodome**）；b 槽自签密钥 `bootslot-b/avb.key` |
| GPT | `scripts/gpt-surgery-tb322fc.py`（list/build，读实际 GPT）、`scripts/gpt-dump.sh`（4096 B 扇区专用）、`scripts/slot-attr.py` |
| 自研 EDL 客户端 | `qdl/build/qdl`（+ `~/下载/tb322fc/xbl_s_devprg_ns.melf` loader） |
| locked 链构建（路 C） | `scripts/build-locked-chain.sh`（testkey 重打全链，从本单元 stock dump 自动读参数）+ `scripts/extract-avbpubkey.py`（从 AVB 镜像提公钥 blob，大端 header）+ `env-pass/keys/testkey_rsa4096.pem`（= 原厂受信 key 2597c218，私钥公开） |
| 设备端操作 | `scripts/{flash-b,thermal-watch,thermal-stress,bench-run,bench-install,serial-run,serial-log,oob-gs1-activate,win-x86-rootfs,win-x86-run,waydroid-proxy-setup,charge-ctl,charge-watch}.sh`、`scripts/wd-net-baseline.dev.sh`（设备侧 Waydroid 网络基线采集：`ip rule`/table 99·1002/网关 ping/出网 curl/netd 错误） |
| Q28 显示取证 + 跨重启串口抓取（2026-10-09/10 新增） | `scripts/q28-boot-cycle.sh`（温启→零写盘 `fastboot boot` 诊断内核→取证，单轮 GOOD/BAD，SSH over USB-NCM，本机无 adbd）、`scripts/q28-ab-delay.sh`（同时间窗 base/exp 各 N 轮统计坏发率，判 delay 能否压制 Q28）、`scripts/q28-verdict.sh`（串口日志三层判 GOOD/BAD：L1 cmd-DMA/panel-init、L2 ctl-reset/frame-done/vblank）、`scripts/q28-devprobe.sh`（设备端三态 NOCARD/STORM/GOOD，POSIX sh，只数风暴签名会把「无 card0」误判 GOOD）、`scripts/q28-race-hunt.sh`（设备端 rpm tracepoints 密集复现 power-on 竞态、零构建）、`scripts/serial-logger.sh`（ttyACM 跨重启自动重连抓取，pid `/tmp/q28_serial_logger.pid`） |
| BL 解锁（**未解锁单元前置**） | `scripts/bl-preunlock-evidence.sh`（locked 基线取证 + 打印申请表两项）、`scripts/bl-unlock.sh`（校 SN → `flash unlock` → `oem unlock-go`，逐条执行） | U2 基线已采：`backup/HA2EXB0E-16+512/pre-unlock/`（Widevine **L1**、by-name 119 项、传感器清单、getprop 全量 + SHA256SUMS） |
| **C10 马达透传链** | `scripts/elden-hapticd.c`（宿主桥 daemon：aw86927 FF_RUMBLE + `--amp-a/--amp-b` 每侧强度 + `amplitude` 缩放 + 自清 `activate`）+ `scripts/build-hapticd.sh` + `scripts/waydroid-haptics-setup.sh`（桥部署/验证）+ `patches-userland/waydroid-haptics-aidl/`（自编 **AIDL V2** vibrator HAL 源码）+ `scripts/waydroid-haptics-aidl-deploy.sh`（零写盘 bind 部署）+ `patches-userland/elden-vibration-overlay/`（静态 RRO：Settings 强度档位 1→3）+ `scripts/waydroid-haptics-bake-patch.py` / `waydroid-haptics-bake-vendor.sh`（**固化进 vendor.img**：`m vendorimage` → 原子替换 → 验证）; 设备侧 `/usr/local/bin/elden-hapticd` + `/etc/init.d/elden-hapticd` + `/etc/conf.d/elden-hapticd` | 2026-10-13 上机验收：零 bind 挂载的固化态 + 幅度/cancel/每侧强度实测；回退镜像 `vendor.img.bak-elden-haptics-20261013-115055` |
| C4 传感器链 | `scripts/eldroid-sensord.c`（数据源 daemon：fake/stdin→UDP，selftest 7/7）+ `scripts/build-sensord.sh`（native+aarch64 static）+ `scripts/deploy-sensors-hal.sh`（Waydroid overlay 部署）+ `env-pass/scripts/sensor-send-termux.sh`（真值转发） |
| AVF 离线提取 | `scripts/extract-avf-assets.sh`（从原厂 system 镜像 debugfs 取 crosvm/vm/microdroid_kernel/u-boot.bin，无需设备） |
| C0 真机取证 | `scripts/c0-android-evidence.sh`（adb 采身份/DRM/传感器/分区，输出 `backup/<SN>-<档>/c0-baseline/` + SHA256SUMS；手工项见脚本尾提示） |
| 磁盘/挂载工具 | `qemu-img`/`qemu-nbd` 已装（A13 ✅）；fstab nofail 已修（A18 ✅） |
| **全量脚本** | 上表仅列构建/刷机链骨干；全量见 `ls scripts/*.sh`（含快环 `scripts/iterate.sh` 四档环、`mod-loop/kexec-boot/to-fastboot/flash-b/cycle` 均自锁、`device-lock.sh` 设备锁、`build-manifest.sh` 版本指纹、`audio-alsa-init.sh` 裸 ALSA 路由、`apply-kernel-fragment.sh` 模块化片段等） |

### 2.2 可上机资产（**设备无关**，任一单元通用）

| 资产 | 路径 | 状态/校验 |
|---|---|---|
| RAM 版基线（零写盘 bring-up） | `out/boot-elden-vk40-ram.img`、`bootslot-b/boot_b_vk40-ram.img` | ✅ 已签（testkey+rollback 1738713600） |
| 持久版基线 | `out/boot-elden-vk40.img`、`bootslot-b/boot_b_vk40.img` | ✅ |
| 全模块包（1484 个 `.ko`） | `out/modules-7.2.0-debug-gba28ec16f01f-dirty.tar.gz`（20 M strip） | vermagic 必须与内核一致 |
| 相机模块包（20 个） | `out/camera-modules/` + tar | ✅ 冷启自加载已在机验证 |
| **运行内核对齐模块包**（25 个，g4c68eb5ed4e3） | `out/camera-modules-7.2.0-debug-g4c68eb5ed4e3-dirty.tar.gz` | ✅ sha256 `4146dfd0…`；持久根相机/音频已复现（`archive/topics/KMOD-ALIGN-2026-10-05.md`） |
| **持久 rootfs 归档** | `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` | 3.44 GB / 30852 项，tar/gzip 完好 |
| **Waydroid Mesa 26.1.8（bionic，自编）** | `~/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz`（6.9 M，**11 个 .so**：`libgallium_dri` / `libgbm_mesa` / `dri_gbm` / `libgbm_mesa_wrapper` / `egl/{libEGL,libGLESv1_CM,libGLESv2,libGLES}_mesa` / `hw/{vulkan.freedreno,gralloc.minigbm_gbm_mesa,gralloc.gbm}` + `manifest.txt`） | sha256 全 OK，含 DRM chip-id 魔数 `0xffff44050000`；**重建** = `scripts/mesa-build.sh`（freedreno-only 定向 make，5.5 min；ccache 热 ~10 min）；部署 = `extract-mesa-libs.sh`+`waydroid-mesa-swap.sh`（bind-mount，可回退） |
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

> **2026-10-23 状态**：外置盘 `/mnt/Samsung` **未挂**（`./l2` 断链、`~/mnt/Samsung/l2` 空目录）⇒ 下表前两行目标**本机不存在**；现现盘最大项改为 `build/` 40 G 与 `.pi/trash/` 21 G（见 §3.2）。

| 路径 | 内容 | 规模 |
|---|---|---|
| `/mnt/Samsung/waydroid-build` | Waydroid AOSP 树（1254 项目 / 1219 对象库 fsck 全 OK） | 550 G（**2026-10-16 告知将随盘清空**：本地提交已推两个 USTC 仓、树外件已留档 `reference/waydroid-buildtree/`、构建产物 `vendor.img` 已进云盘包 ⇒ 可清） |
| `/mnt/Samsung/l2`（本 repo `./l2`） | 原厂 super / system_a / system_a.pristine（sha256 逐侧一致）；**stock-259 13 分区备份里没 super，这里是唯一一份**；自研 `lp_tool.py`（LP v1.2 dump/extract/splice）唯一副本 | 45 G |
| `~/mesa-out` | Waydroid bionic Mesa 构建产物（11 `.so` + `manifest.txt`），即上表自编产物的落地包 | ~7 M |
| `~/下载/tb322fc` | EDL 全量包 | 599 M |
| `stock-src/` | 联想 GPL 源码 | 400 M |

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

### 2.5 资产瘦身优先级（2026-10-02 审计｜纯文字方案，**未执行**）

> **2026-10-23：本节数字大量过期（换机后 / 重下后），现行口径以 `../reports/assets-inventory-20261023.md` §5（A0–A7）与 §3.3 状态表为准**；本节只保留 P 级方案的历史推理。

> 2026-10-03：条目状态、可清理标记与 git 归属已集中到 **`README.md §3` §3**；本节的 P 级方案不变。
> **P0-b 前置闸已解除**：内核工作树 13 个 modified 文件已导出为
> `patches/elden-working-tree-ba28ec16f-2026-10-03.patch`（`git apply --check --reverse` 校验通过，
> 已覆盖 `patches/0001–0011` 未覆盖的 5 个文件，含 `q6prm.c`），`.config` 已存 `patches/config-vk40-bringup`，
> `HEAD=ba28ec16f`。→ `geekidos-linux make clean` 已可执行。

口径前提：**原安卓系统以云盘全量线刷包为准**（用户 2026-10-02 确认）。本地 `~/下载/tb322fc`（63 文件 / 599 M）
**不含 super / dtbo / vendor_boot / recovery**（§PITFALLS:198），`y700四代工具/…1.5.10.259/` 仅 40 M 重签 zip
→ **云包 = 唯一全系统副本**，本地 `l2/super.img.raw` = 本地唯一全系统副本。

> **★ 2026-10-11 审计 + 已提取（`reports/android-required-resources-audit-20261011.md`）**：EDL 包 `rawprogram_save_persist_unsparse0.xml`/`rawprogram5.xml` 把
> **设备独有分区留空（不刷、保留）** ⇒ 全量刷机**不恢复**它们，必须从本机 dump。
> **✅ 已提取 21 个 → `backup/HA2EXB0E-16+512/unique/`（133 MB，含 `MANIFEST.txt`+`SHA256SUMS`，双端 md5 21/21 一致）**：
> `persist proinfo lenovolock ssd keystore frp misc modemst1 modemst2 fsg fsc secdata mdcompress connsec tzsc spunvm xbl_sc_test_mode dpm qmcs devinfo uefivarstore`。
> 已 dump 的还有 `backup/misc/`（misc/devinfo/uefivarstore）+ GPT。未提 `lenovoraw`/`lenovocust`（包内有 filename）/`rawdump`/`pstoredump`（日志）。
> **云包核对（用户 2026-10-11 确认）**：版本 = `1.5.10.259`、含 `super`/`dtbo`/`recovery`/`vendor_boot` ⇒ §P2 `backup/stock-259/`、§P3 `l2/` 的**云包闸已清**（删除仍需单独下令）。当前占用：根盘 25 G、外置盘 572 G。

| 优先级 | 目标 | 体积 → 剩 | 动作 | 前置闸（不满足就别动） |
|---|---|---|---|---|
| **P0** | `/mnt/Samsung/fiotest/` | 4.1 G → 0 | 直接删（fio 临时文件） | 无 |
| **P0** | `geekidos-linux/` 构建产物 | 13 G → 1.6 G | `make clean`（源码/config/diff 全留） | ✅ **已解除**：13 modified 文件已导出 `patches/elden-working-tree-ba28ec16f-2026-10-03.patch` + `.config` 快照 + `HEAD=ba28ec16f`（见本节顶部注） |
| **P1** | `out/` + `out/archive`（E1/E2） | 5.3 G → ~0.6 G | ✅ **已执行（2026-10-04 精简审计，用户批）**：删 47 个旧镜像 + out/archive（~5.0 G）；只留 vk46/vk47/vk47a/vk50 基线 + vk34recon + V1/V2 二分 + boot_b-vk49 + dtbo-dummy；清单外保留理由见 `archive/topics/清理清单-2026-10-04-精简审计.md` | 其余可按 `patches/config-vk*` + 脚本重建；**`bootslot-b/` 历史签名包未批（E3）** |
| **P1** | `pkgs/` `pkgs-phosh/` `pkgs-x86/`（508 apk/deb） | 638 M → 0 | 删 | 无（上游可重下；`rootfs/debs-manifest.txt` 已记版本） |
| **P2** | `env-pass/build` + `env-pass/kernel-susfs` | 494 M → 0 | 删中间物 | **保留** `env-pass/backup-20261002/linux17-rootfs.tar.gz`（3.3 G＝过环境栈成功态里程碑，不瘦身） |
| **P2** | `backup/rawdump.img` | 257 M → ~30 M | `zstd`（sda14 日志型 dump，结论已进 PITFALLS） | 无 |
| **P2** | 重复快照：`flashing-bundle/`(+tar) · `backup/pi-assets-*` · `backup/pi-sessions-*` · 5 个 `y700-elden-docs-*.tar.gz` | ~30 M → ~10 M | 只留最新一套 | 无 |
| **P2** | `backup/stock-259/` 13 分区 | 443 M → 0 | 删（云全量包已覆盖） | **须先核对云包清单含 abl/dtbo/recovery/vbmeta 且版本 = 1.5.10.259** |
| **P3** | AOSP `.repo/project-objects` + `projects` | **435 G** → 0 | 剪 git 历史（**工作树照常编译**，但此后不能 `repo sync`） | **先**导出 `.repo/local_manifests/`（`00-remotes`/`01-removes`/`02-waydroid`.xml）+ `device/waydroid/waydroid/waydroid_arm64_only/BoardConfig.mk`（唯一改动，+10/−2）|
| **P3** | AOSP 工作树 + `out` | 89 G + 12 G → 0 | 整树删（合计 **523 G**） | **❌ 裁决保留（2026-10-06）**：原闸「G2 是否还要自编 Waydroid」已答——**保留**，因 Mesa 偶发重编仍需此树（与是否换安卓版本无关，见 `../TASKS/README.md` §6 §6）；真不要了再删，替代 = `~/下载/lineage-20.0-…-GAPPS-waydroid_arm64_only-system.zip`（1.1 G，官方现成） |
| **P3** | `l2/`（`./l2`）super + system_a + system_a.pristine | 45 G → 13 K | 回收 36–45 G | **两道闸**：① 先做 `../TASKS/README.md` §5 Q13 的 AVF 重提取（源 `system_a.pristine.img`，U1 仍 stock 是唯一窗口）② 核验云包含 `super.img@1.5.10.259`。无论结论如何，先把 `lp_tool.py` + `dump-super.sh` + `trim-delete-only.cmds`（13 K，唯一副本）挪进 `tools/` |
| **不瘦** | `.pi/`（记忆+会话）· `archive/` · 领域层文档 · `stock-src/`(402 M GPL 源码) · `rootfs/`(193 M 部署基) · `y700四代工具/`(271 M) · `qdl/` · `backup/{gpt,fw,misc,sde-gpt-*,dtbo_a}` · `patches/` · `scripts/` · `/mnt/Samsung/{ccache,mesa-out}` | ≈1.6 G | 保留 | — |

**回收上限**：根盘 ≈18 G（P0–P2 全做）｜外置盘 4.1 G（仅 P0）→ 439 G（P3 剪历史）→ 523 G（P3 整树）+ 45 G（l2）。

**执行纪律**：① 按 P0→P3 逐级，不并行，每级 `df -h` 前后记录 ② 每删一项在 `archive/topics/清理清单-<date>.md` 记「体积 + 重建来源（URL / commit / 设备重取命令）」 ③ 先导出独有内容再删容器 ④ 删后回改本节与 §2.3 的路径，别让后续会话找空路径。

---

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
  - **本地独有工作 = 三条通道（2026-10-16 落）**：
    - **① hermes 项目记忆 → 入库**：`scripts/sync-hermes-memory.sh` 把**仓库之外**的 `~/.pi/agent/projects-memory/<repo>/` **单向快照**进 `.pi/hermes-memory-mirror/`
      （`MEMORY.md` + `skills/*/SKILL.md`，共 620 K / 9 文件；**不含** hermes 自滚动的 `.MEMORY.md.recovery-*`/`.retired-*` 26 M 派生历史），
      随本仓推 USTC/GitHub；`scripts/sync-hermes-memory.sh --check` 判新鲜度。
      **方向纪律：记忆只改 hermes 活文件（`memory_add` 等），勿手改镜像**（下次同步原样覆盖）。
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
- ⚠️ **内核仓现役线目前无站外 git 备份**（镜像冻结、`origin` 是上游 GEEKiDoS 不是我们的）。现役可用备份 = `backup/kernel-git-repair-2026-10-08/elden-all-refs-1820.bundle`（**265 MB / 41 ref**，`bundle verify` 判为「完整历史」，含 vk40→vk64 + 5 个 `archive/*`；旧的 1743 那份 279 MB/38 ref 没有 vk43 留白 tag，保留作修复前留存）。要恢复站外备份只有两条路：① 把 bundle 传云盘（技能 `ustc-cloud-drive`，零 git 约束）；② `git fetch --unshallow origin` 补全上游历史后新建项目推（要下 1–2 GB，与「避免重复下载大文件」相左，需拍板）。
- ⚠️ gitignore 注释必须独占一行（行尾 `#` 会被当作模式一部分，静默失效）。

### 2. 顶层台账

> **2026-10-23 全量对账 + 清理**（`reports/assets-inventory-20261023.md`、`archive/topics/清理清单-20261023.md`）：对账时为 **83.5 GB**；按 A0–A7 执行后 **≈47 GB**（根盘 `df` 184.0→146.7 GiB，净回收 **37.3 GiB**）。入 git **2399 文件 / 49 MB**（`.git` 另 31 MB）。
> 下表体积为**清理后 2026-10-23 晚现查**。**删除仍按 §3 纪律（逐级、记 df、删前导出独有件）；批量删用 `python3 shutil.rmtree`——本机 pi bash 会把 `rm` 改成 trash（教训见清理清单 §0）。**

| 路径 | 体积（2026-10-23 现查） | 版本控制 | 说明 / 处置 |
|---|---|---|---|
| 领域层 `INDEX/DEVICE/TASKS/RESOURCES/RUNBOOK.md` + `AGENTS.md`（各角度 `README.md` 单列） | 领域层合计 ≈ 0.8 M（`TASKS/` 456 K、`HISTORY/` 144 K、`RESOURCES/` 84 K、`DEVICE/` 48 K、`RUNBOOK-BRINGUP/` 44 K、`INDEX.md` 20 K、`PROGRESS.md` 20 K、`README.md` 12 K、`AGENTS.md` 4 K） | ✅ track | 平面 1 领域层＝唯一维护面；分层与 SSOT 见 `INDEX.md` §2（GAPS/ANDROID-COMPAT 已并入 `../TASKS/README.md` §5/§6） |
| `.pi/{skills,missions,agents}` `.pi/README.md` `.pi/AGENT-OPS.md` `.pi/CONCURRENCY.md` `.pi/settings.json` `.pi/plans` `.pi/hermes-memory-mirror` `.pi/fabric.json` | 1.5 M | ✅ track | AI 大脑：行为规范/并发细则/技能/子代理/模型/计划（分工见 `.pi/README.md`）+ hermes 项目记忆单向镜像 620 K。⚠️ `.pi/memory/` 已于 2026-10-05 删除（迁 hermes）；`pi-messenger.json` 与 `messenger/` 已随插件卸载清除（`PITFALLS` §15.1）。`.pi/lanes/`、`.pi/fabric/` 为运行时，已 ignore |
| **`.pi/trash/`**（trash-cli 回收站） | **0（已清空 2026-10-23）** | ignore（依据在 `.git/info/exclude:7`） | **2026-10-23 A0**：曾 **21 G**（单件最大 `out-m1-73` 11 G + 5.07 G 云盘包 tar），已核实无独有价值件（抢救 2 件已恢复）后整删。⚠ **别再攒**：本机 pi bash 会把 `rm -rf` 转成 trash，批量删用 `python3 shutil.rmtree` |
| `.pi/sessions/`（jsonl 会话轨迹，含会话子目录副本） | **现查**（2026-10-23 = 496 M / 209 个 jsonl） | ignore | 会话轨迹。**会话数不在这里维护**：现查 `ls .pi/sessions/*.jsonl \| wc -l`；检索用 `scripts/sess.sh` 或 `/resume`。**整理候选**：旧会话归档（见 §3 H1） |
| `scripts/` | 1.3 M（180 文件） | ✅ track | 构建/刷机/GPT/温控/基准/容器脚本全集（6 个 swarm 脚本已移入归档，§15.1） |
| `patches/` | 11 M（310 文件） | ✅ track | 内核补丁 + config 快照 + 工作树全量 patch + `kernel-history/`（各 elden 分支增量补丁，异地留档）。**Q28 显示诊断补丁系列**（均设备无关诊断/实验件，非 G1 交付）：已 RAM 上机取证 = `q28-dsi-regdump.patch`/`q28-dsi-regdump-with-baseline.patch`（vk72/vk73/vk75 好坏寄存器差分）、`q28-poweron-propagate.patch`（vk74 4/4 复现）、`q28-cmd-dma-delay.patch`（vk84-{base,exp} 单变量对，暖 8/8 GOOD 不判别、冷 A/B 仅 T1=NOCARD 未定案）；候选未独立上机 = `q28-dsi-cmd-recover.patch`（vk64 源有界复位）；草稿未编未 apply = `q28-methodB-round-byteclk.patch`+`q28-methodB-NOTES.md`（取整 byte-clk，落点待按上游校准） |
| `patches-userland/` | 536 K（62 文件） | ✅ track | **用户态（Phosh/phoc）补丁 + 构建/安装脚本**（2026-10-11 新增）：`0001-phoc-honor-any-mode.patch`（切非 preferred 刷新率）、`0002-phosh-report-supported-scale.patch`（修非整数比例显 100%）、`0003-...`（自动旋转磁贴，**已撤销 2026-10-19：内置磁贴重复**，原文在 `withdrawn/`）、`alpine-phosh-*.patch`（发行版补丁，保一致）、`build-phoc-phosh.sh`、`install-on-device.sh`（设备侧幂等安装；已不再装插件）、`build-deps.txt`、`upstream/`（**上游 MR 草案**）。已上机验证，证据见 `reports/userland-display-scale-refresh-20261011.md`、`reports/userland-auto-rotation-toggle-20261011.md`。设备侧还原副本 = `rootfs/persistent-overlay/userland-display/`（restore.sh 自动调用） |
| `archive/` | 2.6 M（219 文件，含 124 篇 md） | ✅ track | 过程证据（124 篇 md + 2 截图 + 2 截图 + `2026-10-04-retired-entrypoints/` 退场入口归档），追加为主 |
| `reports/` | 15 M（154 篇 md + `artifacts/` 1.1 M） | ✅ track（2026-10 整理轮起入库） | **2026-10-23 资产盘点** = `assets-inventory-20261023.md`（顶层磁盘真值 / 台账失配 / 不可再生 / 清理候选 A0–A7 / MIGRATION-LOST 对账）。 **活跃主题的工作区证据**（活跃期可读可改；主题定案后整体迁 `archive/topics/`，归档层追加为主）。现含 **Q28 显示线过程稿**（`q28-DOSSIER.md`=SSOT、`q28-INDEX.md`=文档地图、`q28-{handoff,two-layers,upstream-diff,orchestration,upstream-research,nocard-research}-20261010.md`）、**Q24+Q28 会话/进度/产物合并台账 `Q24-Q28-INDEX.md`**、**用户态显示修正 `userland-display-scale-refresh-20261011.md`**、**自动旋转磁贴 `userland-auto-rotation-toggle-20261011.md`**、本地清理审计 `local-cleanup-audit-20261010.md`、本轮整理提案 `tidy-20261010/`（`resources-edits.md`/`cleanup-candidates.md` + T1/T2/T3 简报） |
| `../PITFALLS/`（`README.md` 正文 + `sessions/`） | 564 K | ✅ track | 踩坑正文（按主题编号）+ §0 零号纪律 + §15 废弃登记 |
| `SESSIONS/README.md` + `SESSIONS/sessions/` | 792 K | ✅ track | 会话索引/统计（**会话数 SSOT = §1**）+ 内核实机验证边界；逐会话档案一行一文件（原 `README.md §4` 会话索引已迁此） |
| `initramfs/` | 2.0 M | ✅ track | init/脚本 + busybox（重建输入） |
| `probes/` | 2.1 M（8 文件纳管；2 个 `.ko` + `.module-common.o` 被 ignore） | ✅ track | **2026-10-23 新登记**：Q28 设备侧探针模块源码 + 预编 `.ko`（`q28latch/`、`q28peek/`，另见 `probes/README.md`）；`.ko` 属可重编，结论在 `reports/q28-*` |
| `reference/` | 4.0 M（58 文件） | ✅ track | **2026-10-23 新登记**：外部同机型/厂商资料的**快照与裁决**（`upstream-armadaos-freedom/`、`upstream-mu-silicium/`、`upstream-pengyuluo/`、`vendor-display-sm8750/`、`waydroid-buildtree/`、`stock-elden.dts`） |
| `versions/` | 652 K（8 文件） | ✅ track | **2026-10-23 新登记**：供机器门与台账比较的派生表（`vk-kernel-identity.tsv`、`vk-registry.tsv`、`migration-gaps-2026-10-17.tsv`、`cloud-backup-20261016.MANIFEST.sha256`…）；`*.lock` 为运行时，已 ignore |
| `rootfs/`（脚本/conf/init） | 672 K（63 文件） | ✅ track | 现体量在 `persistent-overlay/` 568 K（`userland-display/`、`user-autostart/`、`usr-libexec-elogind-system-sleep/`）；旧注的 `alpine/ dl/ debs/` **已不存在** |
| `env-pass/{scripts,tools}/` | 44 K | ✅ track | 过环境脚本 + 模块重打包工具 |
| `bootslot-b/README.md` `backup/fw/README.md` `restore-259/*.md` | ~15 K | ✅ track | 关键说明文档（其余二进制 ignore） |
| `net/ waydroid-ota/` | <220 K | ✅ track | 小体积资产 |
| `dl-cam/` | 50 M | ignore（**已纳管 231 文件**：`libcxx/` 185 + `gen-src/` 40 + 脚本） | **C5 容器侧 camera provider 的构建工作区（2026-10-18）**。**2026-10-23 A6**：删掉全部下载件/中间物（NDK 1.7 G、los20 OTA、`system*.dat/.img`、`vdump`/`stage`/`aosp`/`out-cam`/`gen*`/`sysroot`/`.venv`/`vendor-cam.img` 等 41 项，apparent 10.8 G）⇒ 仅留 `hw-interfaces/`（AOSP external HAL + 自研 YUV 补丁）+ `donor/` + 6 个纳管件。**重建**：按 `patches/waydroid-camera-64bit-20261018/README.md` 重下 NDK/OTA 再跑 `build-cam-provider.sh`
| 根目录 `*.deb`（8 个） | 1.9 M | ignore（`/*.deb`） | C5 工具链包（`hidl-gen`、`aidl` + android-lib*）：`dpkg -i` 装过即可；重建时按 `patches/waydroid-camera-64bit-20261018/README.md` 重下 |
| **`build/`** | **33 G**（6 棵树） | ignore（`/build/`） | **2026-10-10 起内核构建目录**。⚠ **旧口径「整目录可再生」不成立**（2026-10-23 实测）：`build/base-7.2` 与 `build/m3v2-7.3rc7` 是**独立仓**，含**本地独有提交**（`master`/`elden-payload-v2` `378459aff`、`m3v2` `f3cf334`、`replay-m1-73-vk127` `24223e4`）；其余为 worktree，**未提交改动**：`m1-73` 13 / `q28-disp` 1 / `q28-disp2` 1 / `q28-disp-73` 4。**2026-10-23 A1 只删了 idle 的 `vk83-tree`（7.3 G，对象仍在 `geekidos-linux`）+ `linux-7.2.tar.xz`（153 M）**；其余 6 棵是活跃车道（24 h 内有改动），保留。**若要再收，先 bundle 两仓 + 导 4 棵 worktree diff**（逐项见 `reports/assets-inventory-20261023.md` §4.1） |
| `linux -> geekidos-linux` | 符号链接 | ✅ track | 目录约定 |
| `geekidos-linux/` | 2.9 G | ignore | 上游 `GEEKiDoS/linux` v7.2-elden + 构建产物（换机后重量；refs 到 `elden-archive/q28/vk86`，另有本地线 `replay/m1-73-vk127`）。无站外 git 备份 ⇒ 见 §1 的 bundle 行 |
| `Y700-elden-linux/` | 28 M | ignore | 旧迭代上游 clone |
| `stock-src/` | 2.0 G | ignore | 联想 GPL 源码 clone（可重下） |
| `qdl/` `twrp/` `probe/` `pkgs-phosh/` `pkgs-x86/` `flashing-bundle/` `bootslot-b-u2/` | **磁盘已不存在** | — | 换机未随迁或已清理；保留本条只为消除旧台账死路径（需时重下/重建） |
| `tools/` | 232 K | ignore | 只剩 `avbtool.py` + 上游 `mkbootimg`（可重建）；`venv-avb` 已不在 |
| `build/uefi-woa-prep/repos/`（新位置，2026-10-24） | **2.0 G**（6 仓，shallow depth 1） | ignore | **WoaA/Gunyah 备料（已重下）**：`1-edk2-aarch64-gunyah` 1.5 G `ebd28432`（含 `ArmVirtGunyah.dsc/fdf` + `QemuRamfbDxe`）、`2-Droid-VM-edk2-gunyah` 1.8 M `90c4d52`（README「Tested platforms: Lenovo Y700 Gen4 tb322fc」）、`3-edk2-gunyah-qemu` 165 M `50c9eb7`、`4-qemu-for-gunyah` 198 M `9248d80`（`accel/kvm/gunyah.c`）、`5-mu_wide_platforms` sparse 6.4 M `3e1d052`（两个 UFSDxe.efi）、`6-DroidVM-Prebuilts` 148 M `c4998e1`（含 `crosvm` prebuilt）。直连 GitHub 仅 ~30 KB/s，改走 `gh-proxy.com` 镜像；工具链在 `build/uefi-woa-prep/tools/`（UEFIExtract/UEFIFind + venv）。清单/命令见 `reports/uefi-woa-prep-20261024.md` |
| ~~`edk2-gunyah/` `edk2-gunyah-qemu/` `edk2-aarch64-gunyah/`~~（旧路径） | **磁盘已不存在（原 2.0 G）** | ignore | 2026-10-05 研究 clone（`Droid-VM/edk2-gunyah`、`qemu-gunyah/edk2-gunyah-qemu`、`AnyLaySys/edk2-aarch64-gunyah`；Gunyah VM/Windows guest 固件参考，**可重下、可清理**）。前两者由 bootchain lane clone；`edk2-aarch64-gunyah` 由并发会话 clone。详见 §1.5 |
| `mu_wide_platforms/` | **磁盘已不存在（原 1.0 G）** | ignore | **G1-29 主资源（2026-10-05 落盘）**：fork `xiaquwan1001/mu_wide_platforms` ← `sunflower2333/mu_wide_platforms`；含 **TB322FC 设备包** `Platforms/PakalaPkg/Device/lenovo-y700g4/`（391 文件）。可重下；详见 §1.6 |
| `uefi-firmware-backup/` | **磁盘已不存在（原 1.3 G）** | ignore | `Project-Aloha/UEFIFirmwareBackup`（2026-10-05 落盘，shallow）；`lenovo-y700g4/` 原厂 UEFI DXE 备份（含 `uefi.elf`、`BOOT.MXF.2.5.1-00240.1-PAKALA-1/`），即设备包 `Binaries/` 的来源。可重下；详见 §1.6 |
| `out/` | 1.9 G（20 个 img / 172 个 manifest） | ignore（`*.manifest` 入库） | 现存 vk64、vk127、vk132–vk147 等；**A4 已删** `vk130/vk131`（「内核段不可读」）+ 3 个 `*-unpack/`（解包中间物）。 boot 产物 / cpio / modules。**2026-10-10 清理审计已回收 ~6.28 G（9.4→3.6）**；留盘口径同 `versions/vk-identity-inflight.txt`：vk64=持久 boot_b 内核（+`Image-vk64.gz`）、**在途留**=vk84-q28delay-{base,exp}+vk74-q28power（Q28 冷 A/B 未定案）、vk77/vk78 modular 线；**用户已判死可删**=vk71-mxc/mxnom（Q24 变体）。逐项见 `reports/local-cleanup-audit-20261010.md` 与 `reports/tidy-20261010/cleanup-candidates.md` |
| `bootslot-b/`（`bootslot-b-u2/` 已不存在） | 409 M | ignore | 自签 b 槽包（含 `avb.key` 私钥，禁止入库） |
| `backup/` | 2.7 G | 混合 | 2026-10-23（清理后）构成：`HA2EXB0E-16+512/` 669 M（含 `unique/` 133 M、`device-rescue-20261017/` 19 M）、`stock-259/` 443 M、`stock-elden/` 271 M、`kernel-git-repair-2026-10-23/` 290 M（**全量 67 heads，含 `replay/m1-73-vk127`**）、`kernel-git-repair-2026-10-10/` 265 M（pre-boundary，**唯一保存悬空提交 `f61b4b82ca`**）、`avf/` 249 M、`fw/` 191 M、`misc/` 1.6 M、`gpt/` 92 K、`slot-probe/` 6.7 M、`rawdump.img` 256 MiB、`dtbo_a.img` 32 M、`doctor-scripts-wt-20261015/` 16 K。**A2/A3 已删**：`kernel-git-repair-2026-10-08/`（265 M，被覆盖）、`git-pack-repair-20261020/`（574 M，全为内核上游对象、可从 kernel.org 重取）。 原厂分区/固件/GPT dump（不可替代，留盘）。**证据文本已纳入 git**（`elden-dump.txt`、`HA2EXB0E-16+512/*.txt`、`pre-unlock/`、`vk40-ram-acceptance-dmesg.txt`）；二进制与 `sn-neko-zuxos.img` 仍 ignore |
| `env-pass/`（余） | 3.3 G | ignore | 只剩 `backup-20261002/linux17-rootfs-20261002.tar.gz` 3.3 G（里程碑件，不瘦身）；`build/`、`kernel-susfs/` 已不在 |
| `logs/` | 14 M | ignore | 串口/构建/agent 日志；**A5 已删** 5 个 `cam-*` 目录（190 M，结论在 `reports/camera-*`） |
| `pkgs/` | **已删除（A7）** | — | 原 apk/deb 缓存 639 M 早已清空，2026-10-23 把空目录也删了；`pkgs-phosh/`、`pkgs-x86/` 不存在 |
| `y700四代工具/` | 271 M | ignore | 厂商工具（`probe/`、`twrp/` 已不存在） |
| `flashing-bundle/` | **磁盘已不存在（原 15 M）** | ignore | 换机迁移包快照（tar.gz 已归档 `2026-10-04-root-strays/`） |
| `restore-259/` | 20 K（只剩 2 个 md） | ✅ track | 二进制 254 M 已不在（按 `.gitignore` 只留 md 的设计） |
| `archive/2026-10-04-root-strays/y700-elden-docs-*.tar.gz`（5 个） | 240 K | 已入库 | 旧文档快照；2026-10-04 自根目录归档 |
| `backup/HA2EXB0E-16+512/sn.img` | 356 B | ignore | **含本机序列号，禁止入库**；2026-10-04 自根目录迁入 |
| `.gitignore` `LICENSE` `cycle.sh` `elden-net.sh` `.githooks/` `.pi/rambuild/` | 32 K | ✅ track | **2026-10-23 补登记**（根配置/快环脚本/提交钩子/内存盘构建 manifest） |
| `l2 -> ~/mnt/Samsung/l2` | 0 B（目标 16 K：`dump-super.sh` + `lp_tool.py`） | ignore | 原 45 G 外置 super/system **已随盘丢失**；⚠ **`lp_tool.py`（自研 LP v1.2 dump/extract/splice）是唯一副本、`dump-super.sh` 是新机路径版** ⇒ 应尽快收进 `tools/`；P3-b 无可回收 |
| `.git/` | 31 M | — | 2026-10-23 新登记（受管 2399 文件 / 49 MB） |

### 3. 可清理标记（不动手，等确认）

编号对应 `README.md` §2.5 的 P 级；状态：⬜ 未执行 / ◐ 部分 / ✅ 已执行 / ⛔ 无需执行。
**2026-10-23 复核**：A0–A7 见 `../reports/assets-inventory-20261023.md` §5；**用户 2026-10-23 批准后已全部执行**（执行记录 + 每级 df + 保留理由 = `../archive/topics/清理清单-20261023.md`）。

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
| H1 | `.pi/sessions/` 旧会话 | 496 M | 归档非活跃会话（保留最近若干） | ⬜ **索引已完成**；删除待用户确认 |

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
| 镜像 | `out/*.img`（`vk42–vk126`） | ◐ **部分重建**：现 22 个 img（vk64、vk127、vk130–vk147） | 旧号仍缺；`.manifest` 172 个；台架臂不可复跑（在机 b 槽 + `backup/HA2EXB0E` 各留 1 份） |
| 日志/工具 | `logs/`（原 92 M）、`tools/`（原 14 M，含 `tools/wd-audio-test/`） | ◐ `logs/` 已到 204 M；`tools/` 只剩 232 K | 旧证据指针 `logs/bench-20261011`、`logs/ui-20261011` 仍悬空；`venv-avb`、`wd-audio-test` 仍缺 |
| 可重下 | `edk2-*`、`mu_wide_platforms`、`uefi-firmware-backup`、`qdl`、`twrp`、`pkgs*`、`probe`、`rootfs/{alpine,dl,debs}` | LOST-REDOWNLOADABLE（2026-10-23：仍均为空） | 重下/重建，非硬伤 |

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
