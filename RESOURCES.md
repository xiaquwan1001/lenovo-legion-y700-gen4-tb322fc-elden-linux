# 资源清单（RESOURCES）— 参考资源 + 本地资源

> 领域层活文档之一；文档分三层（领域 / 元 / 证据），定义与 SSOT 见 `INDEX.md` §2。
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
| freedreno / Mesa 上游 | A830 (`gen80000`) 支持、turnip | 自编 Mesa 26.1.8（解 Waydroid chip-id） |
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
| Droid-VM/DroidVM、denial | Android 侧 VM 管理器 / Windows 11 ARM64 on crosvm+Gunyah（**需 Android 宿主**） | 与新前提冲突（a 槽可弃）；只观察（见 `TASKS.md §5` Q4） |
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
| **`AnyLaySys/edk2-aarch64-gunyah`**（本地 clone `edk2-aarch64-gunyah/`，1.5 G） | aarch64 EDK2，构建 `ArmVirtPkg/ArmVirtGunyah.dsc`（含 `GunyahIoMmuDxe`/`GunyahRestrictedDmaPoolAcpiDxe`）；近期提交含 **"启动 Microsoft Windows 改 ramfb"** | **Windows-on-ARM64 guest 固件**（Gunyah VM 内起 Windows）；与 win-x86/DroidVM 方向相关，仅观察 |

### 1.6 间接引导层 / SM8750 UEFI（G1-29，2026-10-05 取证）

> 承接 `archive/topics/BOOTCHAIN-2026-10-05.md`（机制判定）。**本轮只定位资源，未 clone/未构建/未上机**；完整清单与检索记录见 **`archive/topics/UEFI-RESOURCES-2026-10-05.md`**。

| 资源 | 关键点 | 我们用它的哪一块 |
|---|---|---|
| **`sunflower2333/mu_wide_platforms`**（fork of `Project-Aloha/mu_aloha_platforms`；307 M；2026-07-19 建 / 2026-10-01 更新） | 含 **`Platforms/PakalaPkg/Device/lenovo-y700g4/`（TB322FC 设备包，518 文件）**：真实内存映射 `PlatformMemoryMapLib`、`PlatformConfigurationMapLib`、`ACPI/DSDT.aml`、`DeviceTreeBlob/Linux/linux-y700g4.dtb`、`Binaries/`（原厂 DXE 全集）、`PatchedBinaries/`（Clock/UFS/PMIC/SPMI/WDog/UsbConfig/FeatureEnabler）、1904×3040 framebuffer + SMBIOS `Lenovo/Y700/4`；另含 `Silicon/QC/Sm8750/`、同族 `Device/{oneplus-dodge,oneplus-erhai,xiaomi-piano,nubia-nx789j}` | **G1-29 路线 A 的现成设备包**（此前判定为「缺环」）；`./build_uefi.py -d lenovo-y700g4` → **`Build/PakalaPkg/lenovo-y700g4.img`**（Android boot 镜像 ＝ BootShim + UEFI FD，BootShim 参数 `build_cfg/sm8750.json`：`UEFI_BASE=0xFF300000, UEFI_SIZE=0x400000`） |
| **`Project-Aloha/UEFIFirmwareBackup`** → `lenovo-y700g4/BOOT.MXF.2.5.1-00240.1-PAKALA-1/`（480 文件，`3a48f03cf` 2026-04-21） | 从原厂固件提取的 **Y700g4 UEFI DXE 二进制备份**；README §SM8750 Pakala 表：`Lenovo y700 gen4 = lenovo-y700g4`、`Oneplus 13 = oneplus-pjz110`、`Xiaomi Piano = xiaomi-piano` | 上述 `Binaries/` 的来源；也可离线核对设备自带 DXE |
| `Project-Silicium/Mu-Silicium`（`Silicon/Qualcomm/PakalaPkg` + `Platforms/OnePlus/dodgePkg`） | SM8750 备选基线；`Status.md`：OnePlus 13 `Linux Boot ✅ / Internal Storage ✅ / Display ✅ / Touchscreen ✅` | 备选基线 + BootShim（`REQUIRES_KERNEL_HEADER` 补 `ARM\x64` 头的 arm64 壳）参考 |

> **要点**：资源已「现成」⇒ G1-29 Route A 由「自造 UEFI」变为「取用 + 主机构建 + 设备侧零写盘 `fastboot boot` 验证」。
> **仍未解**：① `lenovo-y700g4` 无 CI/产物/公开验证记录；② 平台默认 `PcdSystemMemorySize=12 GiB` ≠ 本单元 16 GB（按容量档需核对内存映射）；③ 四代 ABL 是否接受 BootShim 壳（BOOTCHAIN **E4** 未做）。

### 1.4 方法论 / 运维参考

- 本项目坑表：`PITFALLS.md`（**动手前扫一眼**，#80/#81 是本轮新增的流程坑）。
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
| 设备端操作 | `scripts/{flash-b,thermal-watch,thermal-stress,bench-run,bench-install,serial-run,serial-log,oob-gs1-activate,win-x86-rootfs,win-x86-run,waydroid-proxy-setup,charge-ctl,charge-watch}.sh` |
| BL 解锁（**未解锁单元前置**） | `scripts/bl-preunlock-evidence.sh`（locked 基线取证 + 打印申请表两项）、`scripts/bl-unlock.sh`（校 SN → `flash unlock` → `oem unlock-go`，逐条执行） | U2 基线已采：`backup/HA2EXB0E-16+512/pre-unlock/`（Widevine **L1**、by-name 119 项、传感器清单、getprop 全量 + SHA256SUMS） |
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
| Waydroid Mesa 26.1.8 | `~/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz` | sha256 全 OK，含 DRM chip-id 魔数 |
| Waydroid 镜像 | `~/下载/` GAPPS `system.zip`(1.17 G) + MAINLINE `vendor.zip`(77 M) | ✅ |
| x86 chroot 资产 | `pkgs-x86/`（ubuntu-base-arm64、box64 0.4.5、Strings64） | ✅ PoC 已通 |
| 原厂分区备份 | `backup/stock-259/`（abl/boot/dtbo/init_boot/recovery 双槽 + SHA256SUMS） | ✅ |
| U2 259 原厂 EDL dump | `backup/HA2EXB0E-16+512/stock/`（boot_b/dtbo_b/vbmeta_b/vbmeta_system_b/recovery_b，降级前状态） | ✅ |
| **U2 1.1 降级完整包**（当前状态恢复源） | `~/文档/TB322FU_ZUXOS_1.1.11.073/image/`（boot/dtbo/vbmeta/vbmeta_system/recovery/init_boot/vendor_boot + 全 6 LUN gpt + 全部固件 + super sparse） | ✅ 完整 |
| **U2 b 槽 mainline 链**（unlocked 用） | `bootslot-b-u2/{boot_b,vbmeta_b,dtbo_b}.img`（testkey 全链，rollback 1738713600，`--follow_chain_partitions` 验证全绿） | ✅ 2026-10-03 |
| GPT 快照（**234 GiB 档专属**） | `backup/gpt/gpt_*_device.bin` | ⛔ 禁止用于 512 档 |
| 固件子集 | `backup/fw/{vendor,modem,bluetooth,dspso,gen80000_*}` | 见 `backup/fw/README.md` |
| AVF 资产（**离线提取，不需设备**） | `backup/avf/`：`com.android.virt.apex` + `apex_payload.img` + `bin/{crosvm,vm,virtmgr,virtualizationservice,vmnic,vfio_handler,fd_server,early_virtmgr}` + `etc-fs/{microdroid_kernel(6.6.77-android15-8),microdroid_super.img,microdroid_vbmeta.img,microdroid_initrd_{normal,debuggable}.img,u-boot.bin,rialto.bin}` + SHA256SUMS | ✅ 2026-10-04 从原厂 259 镜像 `/mnt/Samsung/l2/system_a.pristine.img` 离线提取；`scripts/extract-avf-assets.sh` 可复原；crosvm 含 Gunyah/Geniezone/KVM 后端 → **GAPS Q13 资产部分已闭** |
| 过环境栈 | `env-pass/`（模块 + `repack_module_zip.py` + 检测器 APK + 内核产物） | Native Detector = normal |
| env-pass provision | `env-pass/scripts/envpass-provision.sh`（状态预检+自动 repack+幂等，A17） | --check 干跑通过 |
| C4 HAL 产物 | `waydroid-build/out/.../vendor/bin/hw/android.hardware.sensors@1.0-service.waydroid`（25 KB，UDP 实现）+ overlay 部署脚本 | 已编译（2026-10-03，32 s）；上机后用 `deploy-sensors-hal.sh` |

### 2.3 主机大容量资产（占盘大户，勿误删）

| 路径 | 内容 | 规模 |
|---|---|---|
| `/mnt/Samsung/waydroid-build` | Waydroid AOSP 树（1254 项目 / 1219 对象库 fsck 全 OK） | 550 G |
| `/mnt/Samsung/l2`（本 repo `./l2`） | 原厂 super / system_a / system_a.pristine（sha256 逐侧一致）；**stock-259 13 分区备份里没 super，这里是唯一一份**；自研 `lp_tool.py`（LP v1.2 dump/extract/splice）唯一副本 | 45 G |
| `~/mesa-out` | Mesa 构建产物 + manifest | — |
| `~/下载/tb322fc` | EDL 全量包 | 599 M |
| `stock-src/` | 联想 GPL 源码 | 400 M |

### 2.4 归档区（本轮合并结果，不再更新）

`archive/2026-10-02-merged/`：`MISSION-SCOPE.md`、`DEVICES.md`、`ANDROID-COMPAT-PLAN.md`、
`ROUTE-DECISION-2026-10-02.md`、`PLAN-NODEV-2026-10-02.md`、`DOCS-CHANGELOG-2026-10-02.md`
—— 内容已并入 `DEVICE.md` / `TASKS.md` / `TASKS.md §6` / `TASKS.md §5` / `RESOURCES.md`，仅留原文以便追溯。

另：`archive/topics/资料汇总-2026-09-30.md` + `L2-修剪流水线-2026-09-30.md` = 已退役的 `~/y700类原生安卓/` 项目全部文档（2026-10-02 并入）。
L2 原厂 system 修剪（super 拆包 → debugfs 删包 → e2fsck → splice 回拼 → 刷 super）**流水线已跑通但未刷入**，build 1 释放 519 MB；
要继续则从该文档 §下一步 接上（关键坑：debugfs `rm` 不同步位图，必须 `e2fsck -fp` 收尾；OTA 彻底失效是固定代价）。

### 2.5 资产瘦身优先级（2026-10-02 审计｜纯文字方案，**未执行**）

> 2026-10-03：条目状态、可清理标记与 git 归属已集中到 **`RESOURCES.md §3` §3**；本节的 P 级方案不变。
> **P0-b 前置闸已解除**：内核工作树 13 个 modified 文件已导出为
> `patches/elden-working-tree-ba28ec16f-2026-10-03.patch`（`git apply --check --reverse` 校验通过，
> 已覆盖 `patches/0001–0011` 未覆盖的 5 个文件，含 `q6prm.c`），`.config` 已存 `patches/config-vk40-bringup`，
> `HEAD=ba28ec16f`。→ `geekidos-linux make clean` 已可执行。

口径前提：**原安卓系统以云盘全量线刷包为准**（用户 2026-10-02 确认）。本地 `~/下载/tb322fc`（63 文件 / 599 M）
**不含 super / dtbo / vendor_boot / recovery**（§PITFALLS:198），`y700四代工具/…1.5.10.259/` 仅 40 M 重签 zip
→ **云包 = 唯一全系统副本**，本地 `l2/super.img.raw` = 本地唯一全系统副本。当前占用：根盘 25 G、外置盘 572 G。

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
| **P3** | AOSP 工作树 + `out` | 89 G + 12 G → 0 | 整树删（合计 **523 G**） | 决策：G2 是否还要自编 Waydroid。替代 = `~/下载/lineage-20.0-…-GAPPS-waydroid_arm64_only-system.zip`（1.1 G，官方现成） |
| **P3** | `l2/`（`./l2`）super + system_a + system_a.pristine | 45 G → 13 K | 回收 36–45 G | **两道闸**：① 先做 `TASKS.md` §5 Q13 的 AVF 重提取（源 `system_a.pristine.img`，U1 仍 stock 是唯一窗口）② 核验云包含 `super.img@1.5.10.259`。无论结论如何，先把 `lp_tool.py` + `dump-super.sh` + `trim-delete-only.cmds`（13 K，唯一副本）挪进 `tools/` |
| **不瘦** | `.pi/`（记忆+会话）· `archive/` · 领域层文档 · `stock-src/`(402 M GPL 源码) · `rootfs/`(193 M 部署基) · `y700四代工具/`(271 M) · `qdl/` · `backup/{gpt,fw,misc,sde-gpt-*,dtbo_a}` · `patches/` · `scripts/` · `/mnt/Samsung/{ccache,mesa-out}` | ≈1.6 G | 保留 | — |

**回收上限**：根盘 ≈18 G（P0–P2 全做）｜外置盘 4.1 G（仅 P0）→ 439 G（P3 剪历史）→ 523 G（P3 整树）+ 45 G（l2）。

**执行纪律**：① 按 P0→P3 逐级，不并行，每级 `df -h` 前后记录 ② 每删一项在 `archive/topics/清理清单-<date>.md` 记「体积 + 重建来源（URL / commit / 设备重取命令）」 ③ 先导出独有内容再删容器 ④ 删后回改本节与 §2.3 的路径，别让后续会话找空路径。

---

## 3. 文件与资产台账（FILES）

### 1. 版本控制边界（`.gitignore` 权威）

- **纳管（track）**：文档、脚本、内核补丁与 config、AI 记忆/技能/任务、小体积证据。
- **排除（ignore）**：上游 clone、构建产物、可再生成物、大二进制 dump、运行时状态、设备敏感数据。
- git 仓库根 = 本目录；分支 `main`。上游内核树 `geekidos-linux/` **不是** submodule，其进度以 `patches/` 为准。
- **异地备份（2026-10-04 起）**：顶层仓 `origin` = `git@git.ustc.edu.cn:xqh/y700-elden`（@xqh，SSH key `~/.ssh/id_ed25519_gitlab_ustc`，全分支+标签）；内核仓 `gitlab` remote = `git@git.ustc.edu.cn:xqh/y700-elden-kernel`（分支 `main` = 合成根 + 9 增量，因 shallow 不能直推）。映射见 `archive/2026-10-04-git-backfill/VERSION-MAP.txt`，内核增量补丁集见 `patches/kernel-history/`。
- ⚠️ gitignore 注释必须独占一行（行尾 `#` 会被当作模式一部分，静默失效）。

### 2. 顶层台账

| 路径 | 体积 | 版本控制 | 说明 / 处置 |
|---|---|---|---|
| 领域层 `INDEX/DEVICE/TASKS/RESOURCES/RUNBOOK.md` + `PITFALLS.md` + `AGENTS.md` | <200 K | ✅ track | 平面 1 领域层＝唯一维护面；分层与 SSOT 见 `INDEX.md` §2（GAPS/ANDROID-COMPAT 已并入 `TASKS.md` §5/§6） |
| `.pi/{skills,memory,missions,agents}` `.pi/README.md` `.pi/settings.json` | ~1 M | ✅ track | AI 大脑：技能/持久记忆/子代理任务卡/模型配置（分工见 `.pi/README.md`）。⚠️ `pi-messenger.json` 与 `messenger/` 已随插件卸载清除（`PITFALLS` §15.1） |
| `.pi/sessions/`（66 个 jsonl） | ~66 M | ignore | 会话轨迹；**整理候选**：旧会话归档（见 §3 H1） |
| `scripts/` | ~530 K | ✅ track | 构建/刷机/GPT/温控/基准/容器脚本全集（6 个 swarm 脚本已移入归档，§15.1） |
| `patches/` | 3.7 M | ✅ track | 内核补丁 + config 快照 + 工作树全量 patch + `kernel-history/`（各 elden 分支增量补丁，异地留档） |
| `archive/` | ~5.5 M | ✅ track | 过程证据（64 篇专题 + 2 截图 + `2026-10-04-retired-entrypoints/` 退场入口归档），只增不改 |
| `PITFALLS.md` | 64 K | ✅ track | 踩坑正文 #1–#101 + §0 零号纪律 + §15 废弃登记 |
| `RESOURCES.md §4` | 21 K | ✅ track | 68 条会话索引（权威，§4）+ 内核实机验证边界 |
| `initramfs/` | 2.0 M | ✅ track | init/脚本 + busybox（重建输入） |
| `rootfs/`（脚本/conf/init） | 小 | ✅ track | `alpine/ dl/ debs/`（176 M+）已 ignore |
| `env-pass/{scripts,tools}/` | 12 K | ✅ track | 过环境脚本 + 模块重打包工具 |
| `bootslot-b/README.md` `backup/fw/README.md` `restore-259/*.md` | ~15 K | ✅ track | 关键说明文档（其余二进制 ignore） |
| `net/ build/ waydroid-ota/` | <220 K | ✅ track | 小体积资产 |
| `linux -> geekidos-linux` | 符号链接 | ✅ track | 目录约定 |
| `geekidos-linux/` | 13 G | ignore | 上游 `GEEKiDoS/linux` v7.2-elden + 构建产物 |
| `Y700-elden-linux/` | 15 M | ignore | 旧迭代上游 clone |
| `stock-src/` | 350 M | ignore | 联想 GPL 源码 clone（可重下） |
| `qdl/` | 3.2 M | ignore | 上游 qdl（`qdl/build/qdl` 为构建物） |
| `tools/` | 14 M | ignore | `venv-avb` + 上游 `mkbootimg`（可重建） |
| `edk2-gunyah/` `edk2-gunyah-qemu/` `edk2-aarch64-gunyah/` | 2.0 G | ignore | 2026-10-05 研究 clone（`Droid-VM/edk2-gunyah`、`qemu-gunyah/edk2-gunyah-qemu`、`AnyLaySys/edk2-aarch64-gunyah`；Gunyah VM/Windows guest 固件参考，**可重下、可清理**）。前两者由 bootchain lane clone；`edk2-aarch64-gunyah` 由并发会话 clone。详见 §1.5 |
| `out/` | 4.6 G | ignore | boot 产物 / cpio / modules |
| `bootslot-b/` `bootslot-b-u2/` | 905 M | ignore | 自签 b 槽包（含 `avb.key` 私钥，禁止入库） |
| `backup/` | 1.5 G | 混合 | 原厂分区/固件/GPT dump（不可替代，留盘）。**证据文本已纳入 git**（`elden-dump.txt`、`HA2EXB0E-16+512/*.txt`、`pre-unlock/`、`vk40-ram-acceptance-dmesg.txt`）；二进制与 `sn-neko-zuxos.img` 仍 ignore |
| `env-pass/`（余） | 3.8 G | ignore | 过环境栈 + rootfs 归档 |
| `logs/` | 92 M | ignore | 串口/构建/agent 日志 |
| `pkgs/ pkgs-phosh/ pkgs-x86/` | 639 M | ignore | apk/deb 缓存（可重下） |
| `probe/` `twrp/` `y700四代工具/` | 552 M | ignore | 探针数据 / TWRP 镜像 / 厂商工具 |
| `flashing-bundle/` | 15 M | ignore | 换机迁移包快照（tar.gz 已归档 `2026-10-04-root-strays/`） |
| `restore-259/`（二进制） | 254 M | ignore | AVB/KSU/EDL 救砖资产 |
| `archive/2026-10-04-root-strays/y700-elden-docs-*.tar.gz`（5 个） | 240 K | 已入库 | 旧文档快照；2026-10-04 自根目录归档 |
| `backup/HA2EXB0E-16+512/sn.img` | 356 B | ignore | **含本机序列号，禁止入库**；2026-10-04 自根目录迁入 |
| `l2 -> /mnt/Samsung/l2` | 45 G（外置） | ignore | 外置盘 super/system 镜像 |

### 3. 可清理标记（不动手，等确认）

编号对应 `RESOURCES.md` §2.5 的 P 级；状态：⬜ 未执行 / ✅ 已执行。

| 标记 | 目标 | 体积 | 前置闸 | 状态 |
|---|---|---|---|---|
| P0-a | `/mnt/Samsung/fiotest/` | 4.1 G | 无 | ⬜ |
| P0-b | `geekidos-linux/` 构建产物（`make clean`） | 13 G→1.6 G | **已解除**：工作树 13 文件已导出 `patches/elden-working-tree-ba28ec16f-2026-10-03.patch`（反向 apply 校验通过）+ config 已存 `patches/config-vk40-bringup` + HEAD=`ba28ec16f` | ⬜ |
| P1-a | `out/` `bootslot-b/` 旧 boot 镜像（留 vk40±ram、vk39） | 5.3 G→0.6 G | vk40 上机验收通过后才删 vk39 | ⬜ |
| P1-b | `pkgs/ pkgs-phosh/ pkgs-x86/` | 638 M | 无（`rootfs/debs-manifest.txt` 已记版本） | ⬜ |
| P2-a | `env-pass/{build,kernel-susfs}` 中间物 | 494 M | 保留 `env-pass/backup-20261002/linux17-rootfs.tar.gz` | ⬜ |
| P2-b | `backup/rawdump.img` 压缩 | 257 M→~30 M | 无 | ⬜ |
| P2-c | 重复快照（`flashing-bundle/`、`y700-elden-docs-*.tar.gz`） | ~30 M | 保留最新一套 | ◐ **tar.gz 已于 10-04 归档** `archive/2026-10-04-root-strays/`；`flashing-bundle/` 目录仍在根目录 |
| P2-d | `backup/stock-259/` 13 分区 | 443 M | 须先核对云全量包含 abl/dtbo/recovery/vbmeta 且 =1.5.10.259 | ⬜ |
| P3-a | AOSP `.repo` 历史 + 工作树（外置） | 523 G | 决策 G2 是否自编 Waydroid；先导出 local_manifests | ⬜ |
| P3-b | `l2/` super/system 镜像 | 45 G | 先做 `TASKS.md` §5 Q13 AVF 重提取 + 核验云包 | ⬜ |
| H1 | `.pi/sessions/` 旧会话 | 45 M | 归档非活跃会话（保留最近若干） | ⬜ **索引已完成（`RESOURCES.md §4`）；删除待任务 #2 完成 + 用户确认** |

**纪律**：按 P0→P3 逐级、不并行；每级前后记 `df -h`；删前先导出独有内容；删后回改
`RESOURCES.md §2.5` 与本节状态、并记 `archive/topics/清理清单-<date>.md`。

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

---

## 4. 会话索引（SESSION-INDEX）

### 1. 统计

| 维度 | 分布 |
|---|---|
| 实机验证 | ✅ 实机 34 / ◐ 部分 5 / ✗ 未上机 39 |
| 状态 | active 45 / reference 25 / junk 4 / superseded 4 |
| 时间跨度 | 2026-09-29 → 2026-10-05（磁盘 jsonl **79**（顶层 70 + `fold-evidence` 嵌套 9）；本索引 **78** 行；70 个顶层会话 ID；`01a10527`×3、`01a105fb`×3、`01a10596`×2、`01a10736`×2 为同 ID 拆分会话） |

---

### 2. 全量索引（按开始时间）

`实机`：✅ 有真实设备交互且给出结论 ｜ ◐ 部分 ｜ ✗ 未上机（纯文档/编译/主机侧）。
`kv`＝摘要中**提及**的内核版本（原始提及含噪声，**非已验证版本**；见 §5 时间线）。

| 日期 | ID | 名称（建议） | 主题 | 实机 | 状态 | 结论 | kv(提及) | 风险/未收口 |
|---|---|---|---|---|---|---|---|---|
| 2026-09-29 | `01a0ed5b` | 分区：安卓GPT缩容与游戏备份 | gpt-slot | ✅ | superseded | TWRP(adb recovery)成功启动并验证；探索GPT缩容/f2fs；定位TF卡写丢失真相；Limbus/HollowKnight加密存 | vk11 | 缩容方案(65G)被后续持久化方案取代；f2fs须clean卸载；游戏存档加密未解密 |
| 2026-09-29 | `01a0edac` | 文档：flashing资料打包与索引 | docs-reorg | ✗ | reference | 生成 flashing-bundle(257文件/15MB)+tar.gz(4.1MB,tar tzf校验)+MANIFEST.sha256+s | - | 有意排除 auth.json/models.json 等敏感文件；大二进制品留在原位 |
| 2026-09-29 | `01a0edaf` | 持久根:b槽直启+GPT手术+睡眠 | persistence | ✅ | active | b槽直启mainline(/dev/sda17)打通,GPT缩userdata加linux分区,定位睡死=进deep挂死;AVB/KSU侦察就绪 | vk12,vk13 | 睡死根因未完全闭环(deep休眠挂死);a槽AVB/KSU刷写序列未在本会话执行;会话结束时设备在fastboot |
| 2026-09-30 | `01a0eff8` | 解锁:a槽KSU收尾+电源键唤醒 | unlock-avb | ✅ | active | a槽刷dtbo/init_boot/vbmeta/recovery后zuxos首启boot_completed=1;电源键由只能熄屏修到可正常唤 | vk12 | a槽KSU/重签AVB刷写;唤醒依赖dbus/gsd-power旁路,触屏唤醒仍不可用 |
| 2026-09-30 | `01a0f067` | 槽位：GPT A/B 槽元数据逆向 | gpt-slot | ✅ | active | 确认槽状态不在 misc 而在 boot LUN GPT：set_active 交换分区 type GUID 并翻转属性 bit，冷/热重启使  | - | 实验涉及临时改 slot successful 位与多次重启；若写错可能致槽不可启动。 |
| 2026-09-30 | `01a0f0c7` | 显示: 桌面对齐与缩放 | display | ✅ | active | chrony修复1970→2026；foot终端装好；NetworkManager接管wlan0；缩放定位phoc.ini与phosh moni | - | 睡眠挂死未实测收口；Displays面板缩放不持久化；PMIC RTC只读只能NTP校时 |
| 2026-09-30 | `01a0f14f` | 显示：缩放深色夜灯与刷新率 | display | ✅ | active | 定位 colord/dbus 激活与 gamma 链路问题并部分修复；发现面板固件仅适配120Hz，切60Hz会黑屏；缩放数值显示不动 | - | 60Hz模式切换黑屏未解决；缩放百分比显示与夜灯阈值仍需内核/面板线跟进 |
| 2026-09-30 | `01a0f1ee` | 触觉：AW86937 马达 SRAM 修复 | touch-haptic | ✅ | active | 定位 AW86937 固件超 4KB 被驱动写死窗口拒绝，按型号区分 SRAM 窗口后震动成功，出 vk19 干净基线并盘点各子系统缺口。 | vk14,vk15,vk16,vk17,vk | 音频 tplg FE→BE 路由未通；USB-C alt mode、传感器、fsa4480 未绑定等缺口仍在。 |
| 2026-09-30 | `01a0f22e` | 会话: pi资产内聚迁移 | session-meta | ✗ | reference | profile/技能/会话迁入~/y700-elden/.pi/；新增项目settings.json与trust.json；用pi SDK实测技 | - | 迁移需重启profile才生效；旧会话软链待删；android-screen-streaming留在全局 |
| 2026-09-30 | `01a0f23c` | 音频：AudioReach共享内存根因 | audio | ✅ | active | 用 kprobe 定位 SHARED_MEM_MAP 失败根因：PCM 缓冲地址 bit32 与 AudioReach 的 SMMU sid 约 | vk19,vk20,vk21,vk22,vk | 音频修复未收口（DMA掩码/地址约定改动未生效）；多次改内核刷机；TF卡SDR104静默写坏仅记录未解决 |
| 2026-09-30 | `01a0f292` | 存储：TF卡UHS与A2支持评估 | other | ✗ | reference | 控制器仅UHS-I(上限SDR104)、无UHS-II；主线/厂商内核都会启用A2 cache特性；现被3.3V降速workaround压到约1 | - | 结论基于既有 dmesg 与静态分析；白牌卡是否真A2无保证；SDR104静态写坏未解 |
| 2026-09-30 | `01a0f29e` | WiFi-BT: 驱动支持与充电旁路 | wifi-bt | ✅ | active | vk26上机验证binderfs可用；BT频繁断连定位为QCA WCN7861 IBS深度睡眠；充电'净掉电'为USB输入限流100mA；Way | vk19,vk25,vk26 | Waydroid系统镜像未下成、容器未跑通；BT IBS睡眠调参未收口；充电限制依赖ADSP |
| 2026-09-30 | `01a0f2be` | 虚拟化:EL2与安卓模拟器调研 | virtualization | ✗ | reference | 结论：SM8850 efisp漏洞不适用SM8750、hyp由XBL验签加载不可绕；EL2仍不可达，建议Waydroid容器+Alpine有包( | - | EL2/KVM判定为不可达属静态分析；Alpine包可用性未上机验证 |
| 2026-10-01 | `01a0f537` | 容器：Waydroid 编译与 Mesa 卡点 | waydroid | ✅ | active | 系统/vendor 镜像下载校验完成、waydroid init 成功，容器进到 Android 系统层；SurfaceFlinger 因 Me | vk27 | 8 字节补丁绕过 GPU 查表后引发 gpu hangcheck lockup；AOSP 树 sync 未完成，容器尚不可用。 |
| 2026-10-01 | `01a0f5a0` | 音频:主线vs厂商AudioReach分析 | audio | ✗ | active | 发现厂商Android内核本身自带q6apm/audioreach(AudioReach SPF路径),正在diff厂商与主线APM协议实现,未 | - | 结论未闭环;主线apr按protection-domain门控/GPR_SVC_ADSP_CORE值待确认;tplg I2S子图未注册根因改动未 |
| 2026-10-01 | `01a0f61c` | 下载:盘符纠正与sync续传 | download-mirror | ✗ | active | 纠正NVMe盘符漂移(系统盘/新盘互换),改用by-id定位;定位sync失败=Clash代理整体挂,直连恢复,下载续传 | - | 1T盘被fio全盘覆写且累计写扇区超7%,建议回读校验;盘符漂移易误擦系统盘 |
| 2026-10-01 | `01a0f71b` | 下载:教育网出口矩阵+AOSP迁移 | download-mirror | ◐ | active | 修正http_proxy污染后实测出口矩阵:USTC镜像IPv6约100MB/s,GitHub只能走代理1.3-1.9MB/s;AOSP.git | - | GitHub仅代理1.3-1.9MB/s为瓶颈;CERNET路由未持久化;代理时好时坏致误判 |
| 2026-10-01 | `01a0f779` | 审计：Waydroid sync 进度与前置 | probe-audit | ✗ | reference | sync 未完成约 48%，为真进度非卡死；构建依赖树约一半未检出故不能开工；发现看门狗停与 23G 废弃 repo。 | - | 在途 tmp_pack 129G，重启会丢失；盘空间看门狗未运行。 |
| 2026-10-01 | `01a0f7b4` | 显示：面板 165Hz 刷新率支线 | display | ✅ | active | 把 165Hz 档移到 mode table 首位，冷启即 165Hz 且 DSI 无报错；音频走 kprobe 定位 GPR/APM 问题；并 | vk28,vk29,vk30,vk31 | 165Hz 稳定性与功耗未长期验证；音频 FE→BE 仅静态推进。 |
| 2026-10-01 | `01a0f7cd` | 审计：Waydroid 卡点与自编 Mesa | probe-audit | ✗ | reference | 卡点=SurfaceFlinger 需 bionic Mesa≥26.1；成品不存在→树内定向编可行但全量 sync 属过度下载，可用 free | vk27 | 「升 Mesa 26.1 即不 hang」为推断非实测，存在 Glymur 反例；sync 未收敛。 |
| 2026-10-01 | `01a0f7f0` | 音频: tplg/DAPM出声排查 | audio | ✅ | active | 构建vk32-34上机；音频定位到'no backend DAIs enabled/found 0 new BE paths'的DAPM/tpl | vk31,vk32,vk33,vk34 | 音频BE通路未打通；面板165Hz默认是否最终验收不明；多次reboot验证 |
| 2026-10-01 | `01a0f802` | 文档:补写Waydroid AOSP审计 | waydroid | ✗ | reference | 新建WAYDROID-AOSP-AUDIT-2026-10-01.md(~7KB)，含535GB树/1070+11工程/从未构建、卡点链、三路径 | - | 审计后freedreno-only最小构建尚未执行 |
| 2026-10-01 | `01a0f80f` | 元：回顾近期会话确认方向 | session-meta | ✅ | reference | 汇总音频 GPR 根因修复(vk34)与 165Hz(vk32)成果，现场复核 vk34 在跑；锁定音频 tplg I2S 子图为主攻方向。 | vk32,vk34 | 音频 aplay 仍 EINVAL；Waydroid sync 出现 bad object 引用损坏。 |
| 2026-10-01 | `01a0f821` | Waydroid:黑屏修复+Mesa实测 | waydroid | ✅ | active | 黑屏真因=pulse挂载非optional致LXC起不来,改lxc.py后Session/Container RUNNING;Mesa 26.1 | - | Waydroid最终由用户点图标验证;ramoops DT节点未加;容器网络未测 |
| 2026-10-01 | `01a0f845` | 文档:资源就绪盘点(Mesa/设备) | probe-audit | ✗ | reference | Mesa 26.1.8已构建并部署到设备(含A830表项),AOSP树550G;设备SSH在线内核7.2.0;新Mesa尚未上机验证 | - | 残留sync进程仍在跑;新Mesa未实测;内核树11文件未提交 |
| 2026-10-01 | `01a0f868` | 会话:swarm规划与子代理派遣 | session-meta | ◐ | active | 规划并发并派出多worker;抢修harness宕机;修复项目分桶被劫持到lobcorp;回收EL2与Play报告 | - | harness曾掉线;分桶劫持靠父PID修复可能复发;子代理产出未独立验证 |
| 2026-10-02 | `01a0fa45` | 温控:过热限频与并发限流 | thermal-charge | ✅ | active | ssh 47；CPU热区93–103°C而passive trip=105°C几乎不降温，负载52；执行限频后降至42–44°C；记录ustc_ | vk39,vk38 | 温控passive trip贴SoC上限、无有效cdev绑定，未固化降温策略 |
| 2026-10-02 | `01a0fa6f` | 审计：未进主线驱动盘点 | probe-audit | ✗ | reference | 对比厂商529 compatible/297 ko，SoC层已越过；缺SLPI传感器栈(架构性放弃)、OEM私有、FM/SE；温控/旁路/DP实 | - | DP 被 DT disabled 因缺 ADSP altmode/UCSI 会 defer；相机差 config 是最高性价比下一步 |
| 2026-10-02 | `01a0fadc` | 环境:过检测env-pass与SukiSU | other | ✅ | active | adb 583/fastboot 614；装SukiSU 4.2.0与envpass_props模块、隐藏KSU管理器包名后Native Det | vk39 | 刷入第三方SUSFS boot_a后ABL拒启已回刷原厂；后门模块经用户决定不装；收尾未完成（设备仍在fastboot） |
| 2026-10-02 | `01a0fc02` | 文档: AOSP资料迁移校验 | other | ✗ | reference | 1219裸库fsck全OK、1254项目齐全、24仓库抽检干净，数据零损失；清理23G冗余与4.1G tmp_pack；fstab加固需sudo | - | gcc-4.9仓库损坏(repo sync唯一失败源)已用remove-project规避；fstab nofail需用户sudo收尾 |
| 2026-10-02 | `01a0fc50` | 路线：两轨分机决定与vk40准备 | bringup | ✗ | active | 落盘 ROUTE-DECISION：新机跑mainline/Waydroid、旧机做Android+AVF D轨；定全程不碰a槽、b槽纯RAM根 | vk40,vk39,vk38 | 仅有准备与结论，vk40 未上机；GPT手术未执行；D轨(旧机)未开工 |
| 2026-10-02 | `01a0fc63` | 虚拟化: DroidVM/AVF路线调研 | virtualization | ✗ | reference | 报告落盘ARM-VIRT-RESEARCH-2026-10-02.md；拆两条线；发现本机stock已含com.android.virt.ape | vk40,vk39,vk38 | 判断基于文档与离线APEX提取，未真机跑VM；host AOSP树无Gunyah |
| 2026-10-02 | `01a0fcbf` | 文档：六视角重构与设备等价 | docs-reorg | ✗ | reference | 新建 MISSION-SCOPE/DEVICES/ANDROID-COMPAT-PLAN，改写入口与 AGENTS，合并为六视角文档集（12 文 | vk40 | G2 的 Play DEVICE 级/Widevine L1 边界、LINUX_GIB 容量、a 槽去留均待用户拍板。 |
| 2026-10-02 | `01a0fcee` | 解锁:降级1.1解锁BL成功 | unlock-avb | ✅ | active | fastboot 523；实测U2出厂259下oem unlock-go失败，线刷1.1.11.073后oem unlock直接成功；核出boo | vk40,vk39 | 降级路径擦数据不可逆；EL2/KVM仍不可达，仅容器路线 |
| 2026-10-02 | `01a0fd4e` | 引导:UEFI启动链调研 | bringup | ✗ | reference | 结论：启动链PBL→XBL(EDK II)→ABL(UEFI app)，无ESP/Boot####/ACPI；G1驱动固件走remoteproc | vk40,vk39 | 无；仅文档结论 |
| 2026-10-03 | `01a10060` | 解锁: BL解锁取证与自制sn.img | unlock-avb | ✅ | active | 证实AVB镜像链用AOSP testkey确实可自签；BL解锁blob为Lenovo自签证书(serial 804940DE…)，机制是免签模板 | vk40,vk39 | 1.5.10.259可能屏蔽解锁指令；Widevine L1解锁后不可逆；本轮未实际执行解锁 |
| 2026-10-03 | `01a100d9` | 解锁:sn.img解密blob取证 | unlock-avb | ✅ | superseded | fastboot 189；blob 356B、magic 1a2blenovo3c4d5e、Bootloader_SN与本机逐字节一致、RSA- | vk40 | 该blob路径最终未采用；真正的解锁由降级1.1路线达成 |
| 2026-10-03 | `01a10110` | 解锁：BL解锁经验整理定稿 | unlock-avb | ✗ | reference | 出复盘-2026-10-03-BL解锁.md并统一11处口径：流程=降073→oem unlock→unlock_critical；关闭G1-0 | - | 流程依赖固件≤1.1.11.073 版本门；判定行易误读(flash unlock OKAY 非判定) |
| 2026-10-03 | `01a10158` | 持久根:U2上机与GPT手术 | persistence | ✅ | active | ssh 247；userdata 449.7→256.7GiB、新增linux17=193GiB写后CRC OK；vk40持久b槽直启Phosh | vk40,vk39,vk38 | 熄屏/睡眠→整机重启未解（G1-22/Q21）；改idle-delay复现致重启环、SSH窗口过短，设备一度不可达 |
| 2026-10-03 | `01a10185` | 会话: 项目整理与git纳管 | session-meta | ✗ | active | git init纳管293文件；导出权威内核补丁；建RESOURCES.md §3台账；发现patches 0001-011不能完整重建内核树；发起swarm | vk40,vk39,vk38 | vk40引入未上机验证的历史新bug；旧会话归档与清理未执行；patch回导边界依赖单份导出 |
| 2026-10-03 | `01a101bf` | 审计：vk34后增量第二遍（AUDIT2） | kernel-audit | ✅ | active | 逐hunk分类N1–N4；建V1/V2二分镜像；取得可量化回归 vk40re vblank=6/PPM=1 vs vk34recon 0/0；落盘AUDIT2 | vk40,vk34 | 静默复位间歇；V1/V2未取有效样本；取证钩子有观察者效应已回退 |
| 2026-10-03 | `01a101ee` | 审计：vk34后增量第三遍（AUDIT3） | kernel-audit | ✅ | active | 审计前序工具调用；排除「副作用在轮询内」(0条)；查明boot_b实为vk40内核致版本归属污染；备vk34recon基线 | vk40,vk34 | reboot与轮询同命令被harness杀死(4/10)；跨版本复位比较作废 |
| 2026-10-03 | `01a101f3` | 引导：Linux→fastboot能力核实 | flashctl | ◐ | superseded | 本地检索确认BCB bootonce不被采纳、ABL无明文串；给出flash-b.sh免fastboot做A/B | vk40,vk34 | 「能力不存在」结论后被PSCI vendor reset推翻（见01a1021c） |
| 2026-10-03 | `01a1021c` | 刷机控制+桌面：PSCI reboot与elogind | flashctl-power | ✅ | active | 实机确认 PSCI SYSTEM_RESET2 vendor reset 生效：`eldroid-bootctl reboot bootloader` 真进fastboot；另修elogind关机（HandlePowerKey占位致shutdown inhibitor卡in-progress） | vk41,vk40 | EDL/recovery的vendor reset未测；长按关机待实测；配置重启持久性待复核 |
| 2026-10-03 | `01a10224` | 会话：项目架构整理与文档分层 | docs-reorg | ✗ | active | 审查12份根文档；定三层架构(领域/元/证据)+SSOT规则；新增scripts/check-doctor.sh；启动全面收敛到6份 | - | 收敛重构进行中；db/LESSONS拟删除 |
| 2026-10-03 | `01a10264` | 复盘：logind 关机 + 音频/温控重落与出声 | power-audio | ✅ | active | ①logind 关机假成功真根因=busybox helper 不带 `-f` 只 `kill(1)`，PID1 是 shell→假成功；落 `fix-logind-poweroff.sh`。②建 `devlogs.sh` 运行日志采集。③vk39 两增量（音频 0009/0011 + 温控 0010）被 vk34-recon 回退→新分支 vk42 干净重落（uname `geb432f18a0d1`）。④音频无声根因=tplg MI2S **SD 线错**（SD0→SD1，功放接 `i2s1_data1`）→ tplg 修正 + ramdisk 字节替换 → **vk43 出声** ✅ | vk43,vk42,vk41 | 熄屏→重启仍未解；**输入端❌**（实测本机麦克风=模拟麦接 WCD939x，非 DMIC；需 WCD939x bring-up）；温控四级 trip ✅
| 2026-10-04 | `01a10440` | 会话：进度盘点与下一步规划 | session-meta | ✗ | active | 实测 U2=vk45 持久根 up 7h20m；发现 INDEX §3/TASKS §0 文档漂移；定优先级 P0 收口→P1（U1 C0 取证）→P2（WCD939x / 熄屏重启） | - | P1 需 U1 接入；WCD939x 与 G1-22 未开工 |
| 2026-10-04 | `01a104a2` | 会话：并发版本协作任务规划（swarm→subagent） | session-meta | ✗ | active | 确认可并发的版本协作任务，定主 agent 编排 + 子 agent 执行形态，给下一步建议（未执行） | - | 仅规划 |
| 2026-10-04 | `01a104e1` | 会话：音频剩余问题专攻 | audio | ✅ | active | 主任务线收官转入残余（R1 耳麦/R2 双麦）；证据 `archive/topics/AUDIO-*`、`WCD939X-2026-10-04.md` | vk44–vk48 | R1 受硬件限制挂起 |
| 2026-10-04 | `01a104e2` | 会话：TF 卡 + 相机并行（vk47 基线，三子代理） | tfcard-camera | ✅ | active | 派相机/存储/蓝牙三子代理并行；产出见 `*-2026-10-04-subagent.md` | vk47–vk49 | — |
| 2026-10-04 | `01a104f1` | 会话：测试环境约束修正（RAM vs 持久变体） | docs-reorg | ◐ | active | 修正「RAM 启动缺桌面服务被误判功能故障」→ PITFALLS #93 + AGENTS 测试环境选择条款 | vk47 | — |
| 2026-10-04 | `01a10500` | 会话：音频收尾（R2 双麦/R3 裸 ALSA） | audio | ✅ | active | R2 定位 AMIC1+AMIC4 双麦；R3 `audio-alsa-init.sh` 裸 ALSA 开箱可用（保守增益 400） | vk47,vk48 | 双路采集未做（低价值） |
| 2026-10-04 | `01a10504` | 会话：pi 启动入口差异说明 | session-meta | ✗ | superseded | 两种入口差异解释；后续旧 cd 包装已移除 | - | PITFALLS §15.1 |
| 2026-10-04 | `01a10527` | 子代理：相机 vk49 基线 + 冷启加载 | camera | ✅ | active | 20 模块全载、graph ENABLED、出流 -EPIPE 待续；`CAMERA-2026-10-04-subagent.md` | vk49 | 子会话 |
| 2026-10-04 | `01a10527` | 子代理：TF 卡根因定性 + 5 候选补丁 | tfcard | ✅ | active | 卡本身 70–80%；`max-sd-hz` 等价厂商 shifter；`TF卡-2026-10-04-subagent.md` | vk47 | 子会话；待换卡 A/B |
| 2026-10-04 | `01a10527` | 子代理：BT 根因重定位 + KEEPALIVE A/B | bt | ✅ | active | H4 不成立、H3 排除，剩 H1/H2 单变量待测；`BT-2026-10-04-subagent.md` | vk47a | 子会话 |
| 2026-10-04 | `01a1056c` | 审查：上游化全量 diff 分级（M 系列） | upstream | ✗ | reference | 内核树 vs 主线 v7.2 全量 diff，A/B/C/D 分级 → `UPSTREAM-REVIEW-2026-10-04.md` + TASKS §7 | - | — |
| 2026-10-04 | `01a1058b` | 迭代快环工具链 + 双仓异地备份 | vcs-iterate | ✗ | active | `iterate.sh` 四档环、`device-lock.sh`、kexec/to-fastboot、模块化片段、GitLab 双仓 | vk49,vk50 | 实机首测见 `01a105d1` |
| 2026-10-04 | `01a1058e` | git 历史回填 vk1–vk40（史记官编排） | vcs | ✗ | active | 分支 `history/pre-vk34` 49 提交 + 49 tag + graft；`archive/2026-10-04-git-backfill/` | 回填 | mtime 归因局限（见 README） |
| 2026-10-04 | `01a10596` | 子代理：史记官 vk1–vk13 史料 | vcs | ✗ | reference | 为回填供版本史料（base1–vk13） | - | 子会话 |
| 2026-10-04 | `01a10596` | 子代理：史记官 vk14–vk34 史料 | vcs | ✗ | reference | 为回填供版本史料（vk14–vk34） | - | 子会话 |
| 2026-10-04 | `01a105d1` | 会话：重构复核三维度 + P0/P1 落地 + 快环接通 | docs-reorg | ✅ | active | 复核（子代理过期/锁旁路/manifest 断链）→ agents+missions 重写、flash-b/cycle 补锁、`!out/*.manifest`、fragment 应用、vk50 构建+kexec 首测 | vk50 | 本会话 |
| 2026-10-04 | `01a105f5` | 会话：精简审计执行（产物 -6G） | cleanup | ✗ | reference | 执行 E1/E2/E4/E5/S1/C1/C2：out 旧镜像/中间物/死脚本/junk 会话清理；**补回 `extract-avfpubkey.py`**（自测 PASS）；check-doctor FAIL=0；提交 `76c444c` | vk50 | E3/E6/S2-S4 未批；`archive/topics/清理清单-2026-10-04-精简审计.md` |
| 2026-10-04 | `01a105fb` | 子代理：只读审计（会话清理候选） | audit | ✗ | reference | 会话/复盘覆盖归属审计，产出可删候选清单（未删） | - | 子会话；被 01a105f5 采纳 |
| 2026-10-04 | `01a105fb` | 子代理：只读审计（文档精简） | audit | ✗ | reference | 6 份文档全读：过时数字（51/59/68 会话数、33/57 镜像数）、死链（`extract-avfpubkey.py`、`config-vk-modular`、`net-up-manual.sh`、flashing-bundle 路径）、SSOT 违规 | - | 子会话；多数已修 |
| 2026-10-04 | `01a105fb` | 子代理：只读审计（.pi 配置） | audit | ✗ | reference | agents/missions/skills/settings 审计：93 处路径引用 0 真死链（missions/agents）、**2 处 SKILL 死链**（已修）、HINDSIGHT +5 行值得提交 | - | 子会话；check-doctor 已扩覆盖 SKILL |
| 2026-10-04 | `01a10635` | 会话：相机出流 + kexec 定论 + G1-22 初判 | camera-kernel | ✅ | active | **G1-5 前后摄连续出帧**（根因=csiphy/vfe 默认格式与 sensor raw 不匹配+链路未使能）；**kexec 定论硬挂不可用**；vk50 `LOCALVERSION=-vk50` 重建 1513 模块对齐；G1-22 初判=vk40 音频插桩+热区（**2026-10-05 反转：未证实，见 Q24**） | vk50 | `CAMERA-2026-10-05.md`、`G1-22-2026-10-05.md` |
| 2026-10-04 | `01a1068c` | 会话：并发任务基线+fork 工作流 | vcs | ✗ | reference | `lane.sh`/`.githooks/commit-msg`/`versions/vk-registry.tsv`/`.pi/CONCURRENCY.md` 落地（提交 `bfe0002`）；修「扫 out 猜版本号」撞车根因 | - | 冒烟验证通过 |
| 2026-10-04 | `01a106b9` | 会话：持久根模块对齐 + 干净内核判定 | kmod-clean | ✅ | active | 25 模块部署到运行内核 → 相机/音频在持久根复现；确认 **boot_b=vk47 `-dirty` 镜像**；出 `bootslot-b/boot_b-clean.img` 并刷入（Q24）。⚠️ **后续反转**：刷后仍复位 ⇒「dirty 镜像为根因」**未证实**，转间歇性未解 | vk47 | `KMOD-ALIGN-2026-10-05.md`；结论见 Q24/REBOOT-5MIN §7.9 |
| 2026-10-04 | `01a1071b` | 会话：（空「可以继续了」） | session-meta | ✗ | junk | 仅一句用户消息，无助手产出 | - | - |
| 2026-10-04 | `01a1072e` | 会话：编排桌面四问+bootchain（内联侦察） | desktop-bootchain | ◐ | active | 编排 G1-26/27/28（dt-ui）+ G1-29（bootchain）；内联定位：dconf 未落错 HOME、**无 logind 会话**、gsd-power 在 **session bus**、elogind SetBrightness 任意 name 均 EISDIR | - | 子代理受预算墙；转内联 |
| 2026-10-04 | `01a10736` | 子代理：bootchain（G1-29 间接引导层） | bootchain | ✗ | reference | 四代 UEFI **被拆成 `uefi_a`/`imagefv_a`/`abl_a` 由 XBL 加载**、ABL 自身不扫 FAT；路线 C（min initramfs）现在可做、A（自建可自举 UEFI 壳）有原型；交付 `scripts/grubfat-*.sh`；`BOOTCHAIN-2026-10-05.md`；vk51 | vk51 | lane 已 merge；E1/E3→E4→E5 待排期 |
| 2026-10-04 | `01a10736` | 子代理：dt-ui（G1-26/27/28 桌面用户态） | desktop-ui | ✅ | reference | **GTK3 无头探针证实 `Adwaita-dark`→回退浅色**（应 `Adwaita`+prefer-dark）；accent 被 phosh guard 拦（同名问题）；亮度=elogind 无 session/VT；gsettings 须 `dbus-run-session`。**lane 未提交、会话中断** → 证据父代落 `DT-UI-2026-10-05.md` | - | lane `dt-ui` 仍 open（无改动） |
| 2026-10-04 | `01a10744` | 会话：dt-ui 重派（空） | session-meta | ✗ | junk | 仅派发词，0 助手消息（预算墙/模型解析失败） | - | - |
| 2026-10-04 | `01a1074a` | 会话：dt-ui 重派（空） | session-meta | ✗ | junk | 仅派发词，0 助手消息 | - | - |
| 2026-10-04 | `01a10759` | 会话：编排（预算墙中断） | session-meta | ✗ | junk | 编排被 `ustc-ai-3` 预算墙打断；结论被 01a1072e 取代 | - | - |
| 2026-10-04 | `01a10789` | 会话：进度整理 + 卡点 + 会话成果汇总 | session-meta | ✗ | active | 汇总 12 个未收录会话的成果；补 `DT-UI-2026-10-05.md`、PITFALLS #103、TASKS G1-26/27/28、登记 3 份 EDK2-Gunyah 参考 | - | - |
| 2026-10-05 | `01a10996` | 资源：SM8750 UEFI 资源收集 + 中文社区检索 | uefi-resources | ✗ | reference | 定位 TB322FC 设备包**已现成**（`mu_wide_platforms` → `lenovo-y700g4`）+ 原厂 DXE 备份（`UEFIFirmwareBackup`）；证实 `build_uefi.py` 原生产出 `boot.img`（BootShim + FD）；中文社区无 UEFI/WoA/U-Boot 产出；落 `UEFI-RESOURCES-2026-10-05.md`、`RESOURCES.md` §1.6 | - | 未 clone/未构建/未上机；本设备无验证记录、容量档差异待核 |

---

### 3. 内核版本时间线与「实机验证边界」（任务 #2 的界）

**关键缺陷（vk7–vk41）**：早期 vkNN 构建共用同一 `uname -r` = `7.2.0-debug-gba28ec16f01f-dirty`（localversion 未改）
→ 设备上无法从内核自报分辨在跑哪个 vk；版本只能靠**镜像文件名 + 刷入命令**追溯。
**vk42 起已分离**：vk42=`geb432f18a0d1`、vk45=`g26cc186e9485`（不再是同一 uname）。

构建时间线（`out/boot-elden-vk*.img`）：

| vk | 构建时间 | 关键改动（据补丁/配置落地时间） | 会话实机确认 |
|---|---|---|---|
| vk7–vk13 | 09-28 23:43 → 09-29 23:39 | 0001 ath12k；初始 bringup | 09-29/30 会话 ✅（vk11–13） |
| vk14–vk19 | 09-30 19:08 → 19:54 | 0002 dspp-gc-gamma、0003 aw86927 haptics | 09-30 ✅（触觉修复，vk19 干净基线） |
| vk20–vk26 | 09-30 21:21 → 23:36 | 0004 wcn7861；audio SMMU/kprobe；binderfs | 09-30 ✅（vk25/26 WiFi-BT/充电） |
| vk27–vk34 | 10-01 10:55 → 23:12 | 0005 q6apm-gpr、0006–0009（DSI/面板165Hz/APM header） | 10-01 ✅（vk32/33/34，**vk34 有明确「在跑」确认**） |
| vk35 | 10-02 01:40 | 温控限频会话前后 | 10-02 ⚠️ 仅 ssh 读数，未见明确 vk35 确认 |
| vk36–vk39 | 10-02 10:48 → 12:01 | 0010 thermal-graded-trips、0011 q6apm-mi2s、config-vk40-bringup | ⚠️ INDEX 称『最后在机基线 vk39』但**无会话级确认** |
| vk40 / vk40-ram | 10-02 19:43 / 20:02 | vk39 之后 + 10-03 initramfs 持久化改动 | 10-03 ✅ 上机（U2 持久 Phosh），**但曝熄屏即重启等新 bug** |
| vk40re / vk41-psci | 10-03 19:51 / 22:46 | vk40 热区重落；`psci.c` vendor reset（→fastboot） | 10-03 ✅ `eldroid-bootctl reboot bootloader` 真进 fastboot（G1-24 S2） |
| vk42 | 10-04 00:04 | vk34-recon 基础上干净重落音频/温控增量 | 10-04 ✅ 上机 |
| vk43 / vk44 / vk45 | 10-04 00:20 / 00:42 / 00:49 | vk43：tplg MI2S SD0→SD1（出声）；vk44：VA DMIC 采集尝试；vk45：DMIC 偏置 | 10-04 ✅ **vk43 出声**；vk44/45 采集图全绿但录音恒 0（本机无 DMIC，方向证伪） |

**边界判定**：最后**有明确实机确认**的版本 = **vk45（2026-10-04，当前在跑）**；
播放出声已在 **vk43** 确认（tplg SD1），温控四级在 **vk42** 确认。
「熄屏→重启」现象仍在（受控复现成立），但**根因未证实、间歇性未解**（vk42/干净重建各 2 轮「免疫」不可信；详见 `TASKS.md` §5 Q24）。

---

### 4. 删除候选（**S1 已执行**：junk 会话已删；其余待确认）

> **2026-10-04**：S1 的 6 条 junk/空会话（`01a0f533`/`01a0f608`/`01a0fa4b`×2/`01a0fabe`/`01a101b5`）**已删除**（见 `archive/topics/清理清单-2026-10-04-精简审计.md`），本表仅留未批项。

| 类型 | ID | 日期 | 现名 | 处置建议 |
|---|---|---|---|---|
| junk/空 | `01a0f533` | 2026-10-01 | summarize: 微信端汇报进度 | 删除（无内容） |
| junk/空 | `01a0f608` | 2026-10-01 | analyze: 继续下载数据任务 | 删除（无内容） |
| junk/空 | `01a0fa4b` | 2026-10-02 | - | 删除（无内容） |
| junk/空 | `01a0fa4b` | 2026-10-02 | - | 删除（无内容） |
| junk/空 | `01a0fabe` | 2026-10-02 | - | 删除（无内容） |
| 已被取代 | `01a0ed5b` | 2026-09-29 | 分区：安卓GPT缩容与游戏备份 | 归档（结论已进更晚文档） |
| 已被取代 | `01a100d9` | 2026-10-03 | 解锁:sn.img解密blob取证 | 归档（结论已进更晚文档） |

> `01a0fa4b` 有两个文件（`-7536…`/`-6dec…`）均为 OK 测试；`01a0f868`/`01a0fd4e` 短会话可归并。

---

### 5. 建议重命名（append `session_info`，可逆；待确认后批量执行）

| ID | 现名 | → 建议名 |
|---|---|---|
| `01a0ed5b` | troubleshoot: 平板连接后续工作 | **分区：安卓GPT缩容与游戏备份** |
| `01a0edac` | chore(workspace): 整理 flashing profil | **文档：flashing资料打包与索引** |
| `01a0edaf` | troubleshoot: fastboot 设备后续刷机步骤 | **持久根:b槽直启+GPT手术+睡眠** |
| `01a0eff8` | 2026-09-30T10:04+08:00 | **解锁:a槽KSU收尾+电源键唤醒** |
| `01a0f067` | feat(flashing): 继续下一个任务 | **槽位：GPT A/B 槽元数据逆向** |
| `01a0f0c7` | analyze(sessions): 检查未完成的 agent 分析 | **显示: 桌面对齐与缩放** |
| `01a0f14f` | 2026-09-30T18:22+08:00 | **显示：缩放深色夜灯与刷新率** |
| `01a0f1ee` | plan(desktop): 全局进度与待办依赖层级 | **触觉：AW86937 马达 SRAM 修复** |
| `01a0f22e` | chore(workspace): 移动 skill、sessions  | **会话: pi资产内聚迁移** |
| `01a0f23c` | analyze: 检查当前进度 | **音频：AudioReach共享内存根因** |
| `01a0f292` | analyze(tf): 平板固件对 TF 卡 UHS/A2 支持 | **存储：TF卡UHS与A2支持评估** |
| `01a0f29e` | feat(wifi): 添加 WiFi 和蓝牙支持 | **WiFi-BT: 驱动支持与充电旁路** |
| `01a0f2be` | research: 芯片平板运行安卓模拟器可行性 | **虚拟化:EL2与安卓模拟器调研** |
| `01a0f537` | analyze: 检查昨晚进度 | **容器：Waydroid 编译与 Mesa 卡点** |
| `01a0f5a0` | 2026-10-01T12:25+08:00 | **音频:主线vs厂商AudioReach分析** |
| `01a0f61c` | analyze: 继续下载任务 | **下载:盘符纠正与sync续传** |
| `01a0f71b` | migrate: 移动 AOSP 数据包到新盘 | **下载:教育网出口矩阵+AOSP迁移** |
| `01a0f779` | audit: 审计 waydroid 下载任务与下一阶段 | **审计：Waydroid sync 进度与前置** |
| `01a0f7b4` | plan: 整理待办、资源与未来规划 | **显示：面板 165Hz 刷新率支线** |
| `01a0f7cd` | audit(waydroid): 卡点与本地编译 AOSP 必要性 | **审计：Waydroid 卡点与自编 Mesa** |
| `01a0f7f0` | analyze(aosp): 下载进度与面板音频验收 | **音频: tplg/DAPM出声排查** |
| `01a0f802` | docs(waydroid): 补写 AOSP 审计技术文档 | **文档:补写Waydroid AOSP审计** |
| `01a0f80f` | summarize: 回顾近期 sessions 确认方向 | **元：回顾近期会话确认方向** |
| `01a0f821` | (无) | **Waydroid:黑屏修复+Mesa实测** |
| `01a0f845` | (无) | **文档:资源就绪盘点(Mesa/设备)** |
| `01a0f868` | 加载一下最近的进度。我们新加入了插件swarm，现在可以真正意义上的派出 | **会话:swarm规划与子代理派遣** |
| `01a0fa45` | (无) | **温控:过热限频与并发限流** |
| `01a0fa6f` | (无) | **审计：未进主线驱动盘点** |
| `01a0fadc` | (无) | **环境:过检测env-pass与SukiSU** |
| `01a0fc02` | (无) | **文档: AOSP资料迁移校验** |
| `01a0fc50` | 我们需要继续主线。新的平板明日到，同型号，16+512g，现在我们要整理 | **路线：两轨分机决定与vk40准备** |
| `01a0fc63` | (无) | **虚拟化: DroidVM/AVF路线调研** |
| `01a0fcbf` | (无) | **文档：六视角重构与设备等价** |
| `01a0fcee` | (无) | **解锁:降级1.1解锁BL成功** |
| `01a0fd4e` | (无) | **引导:UEFI启动链调研** |
| `01a10060` | (无) | **解锁: BL解锁取证与自制sn.img** |
| `01a100d9` | (无) | **解锁:sn.img解密blob取证** |
| `01a10110` | (无) | **解锁：BL解锁经验整理定稿** |
| `01a10158` | (无) | **持久根:U2上机与GPT手术** |
| `01a10185` | (无) | **会话: 项目整理与git纳管** |
