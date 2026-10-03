# 资源清单（RESOURCES）— 参考资源 + 本地资源

> 六视角文档集之一（`DEVICE.md` / `TASKS.md` / `GAPS.md` / `ANDROID-COMPAT.md` / `INDEX.md`）。
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
| Droid-VM/DroidVM、denial | Android 侧 VM 管理器 / Windows 11 ARM64 on crosvm+Gunyah（**需 Android 宿主**） | 与新前提冲突（a 槽可弃）；只观察（见 `GAPS.md` Q4） |
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

### 1.4 方法论 / 运维参考

- 本项目坑表：`PITFALLS.md`（**动手前扫一眼**，#80/#81 是本轮新增的流程坑）。
- 解锁链签名取证（2026-10-03）：`archive/topics/UNLOCK-BLOB-FORENSICS-2026-10-03.md`
  —— AVB 链 = 谷歌公开 AOSP testkey（原厂 `vbmeta`/`boot`/`recovery` pubkey sha1 `2597c218…`）；
  解锁标志链 = Lenovo 自签证书（serial `804940DE79164B1A`），但 SN 明文在偏移 `0x2048`、签名只覆盖前 `0x1000`
  ⇒ **通用模板改 SN 即可自造解锁文件（免签）**；四路对照：A 自造 / B 官网 / **C EDL（不依赖解锁）** / D 第三方重签包。
  实物模板：`y700四代工具/解BL/Y700 三代解锁工具箱by某贼.zip` → `bin/res/sn.img`（附 `HexTool.exe`/`hexconvetor.exe`）。
- swarm 并发与 API 限流复盘：`archive/topics/复盘-2026-10-02-swarm.md`、全局 `~/.pi/agent/AGENTS.md`（ustc_ai 20 req/窗口 + $30/3h 预算；现用 provider `deepseek`）。
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
| 磁盘/挂载工具 | `qemu-img`/`qemu-nbd` 已装（A13 ✅）；fstab nofail 已修（A18 ✅） |

### 2.2 可上机资产（**设备无关**，任一单元通用）

| 资产 | 路径 | 状态/校验 |
|---|---|---|
| RAM 版基线（零写盘 bring-up） | `out/boot-elden-vk40-ram.img`、`bootslot-b/boot_b_vk40-ram.img` | ✅ 已签（testkey+rollback 1738713600） |
| 持久版基线 | `out/boot-elden-vk40.img`、`bootslot-b/boot_b_vk40.img` | ✅ |
| 全模块包（1484 个 `.ko`） | `out/modules-7.2.0-debug-gba28ec16f01f-dirty.tar.gz`（20 M strip） | vermagic 必须与内核一致 |
| 相机模块包（20 个） | `out/camera-modules/` + tar | ✅ 冷启自加载已在机验证 |
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
| AVF 资产 | （待重提取：源 `com.android.virt.apex`，Android 16/259） | ⛔ 原记“已提取”虚记，2026-10-02 全盘核验主机无产物 → **GAPS Q13**，U1 仍 stock+root 时随 C0 重提取 |
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
—— 内容已并入 `DEVICE.md` / `TASKS.md` / `ANDROID-COMPAT.md` / `GAPS.md` / `RESOURCES.md`，仅留原文以便追溯。

另：`archive/topics/资料汇总-2026-09-30.md` + `L2-修剪流水线-2026-09-30.md` = 已退役的 `~/y700类原生安卓/` 项目全部文档（2026-10-02 并入）。
L2 原厂 system 修剪（super 拆包 → debugfs 删包 → e2fsck → splice 回拼 → 刷 super）**流水线已跑通但未刷入**，build 1 释放 519 MB；
要继续则从该文档 §下一步 接上（关键坑：debugfs `rm` 不同步位图，必须 `e2fsck -fp` 收尾；OTA 彻底失效是固定代价）。

### 2.5 资产瘦身优先级（2026-10-02 审计｜纯文字方案，**未执行**）

> 2026-10-03：条目状态、可清理标记与 git 归属已集中到 **`FILES.md` §3**；本节的 P 级方案不变。
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
| **P1** | `out/` + `out/archive` + `bootslot-b/` | 5.3 G → ~0.6 G | boot 镜像只留 **vk40(+ram) / vk39** + README + `avb.avbpubkey` | vk40 上机（G1-1）通过后才删 vk39；其余 33 个可按 `patches/config-vk*` + 脚本重建 |
| **P1** | `pkgs/` `pkgs-phosh/` `pkgs-x86/`（508 apk/deb） | 638 M → 0 | 删 | 无（上游可重下；`rootfs/debs-manifest.txt` 已记版本） |
| **P2** | `env-pass/build` + `env-pass/kernel-susfs` | 494 M → 0 | 删中间物 | **保留** `env-pass/backup-20261002/linux17-rootfs.tar.gz`（3.3 G＝过环境栈成功态里程碑，不瘦身） |
| **P2** | `backup/rawdump.img` | 257 M → ~30 M | `zstd`（sda14 日志型 dump，结论已进 PITFALLS） | 无 |
| **P2** | 重复快照：`flashing-bundle/`(+tar) · `backup/pi-assets-*` · `backup/pi-sessions-*` · 5 个 `y700-elden-docs-*.tar.gz` | ~30 M → ~10 M | 只留最新一套 | 无 |
| **P2** | `backup/stock-259/` 13 分区 | 443 M → 0 | 删（云全量包已覆盖） | **须先核对云包清单含 abl/dtbo/recovery/vbmeta 且版本 = 1.5.10.259** |
| **P3** | AOSP `.repo/project-objects` + `projects` | **435 G** → 0 | 剪 git 历史（**工作树照常编译**，但此后不能 `repo sync`） | **先**导出 `.repo/local_manifests/`（`00-remotes`/`01-removes`/`02-waydroid`.xml）+ `device/waydroid/waydroid/waydroid_arm64_only/BoardConfig.mk`（唯一改动，+10/−2）|
| **P3** | AOSP 工作树 + `out` | 89 G + 12 G → 0 | 整树删（合计 **523 G**） | 决策：G2 是否还要自编 Waydroid。替代 = `~/下载/lineage-20.0-…-GAPPS-waydroid_arm64_only-system.zip`（1.1 G，官方现成） |
| **P3** | `l2/`（`./l2`）super + system_a + system_a.pristine | 45 G → 13 K | 回收 36–45 G | **两道闸**：① 先做 `GAPS` Q13 的 AVF 重提取（源 `system_a.pristine.img`，U1 仍 stock 是唯一窗口）② 核验云包含 `super.img@1.5.10.259`。无论结论如何，先把 `lp_tool.py` + `dump-super.sh` + `trim-delete-only.cmds`（13 K，唯一副本）挪进 `tools/` |
| **不瘦** | `.pi/`（记忆+会话）· `archive/` · 六视角文档 · `stock-src/`(402 M GPL 源码) · `rootfs/`(193 M 部署基) · `y700四代工具/`(271 M) · `qdl/` · `backup/{gpt,fw,misc,sde-gpt-*,dtbo_a}` · `patches/` · `scripts/` · `/mnt/Samsung/{ccache,mesa-out}` | ≈1.6 G | 保留 | — |

**回收上限**：根盘 ≈18 G（P0–P2 全做）｜外置盘 4.1 G（仅 P0）→ 439 G（P3 剪历史）→ 523 G（P3 整树）+ 45 G（l2）。

**执行纪律**：① 按 P0→P3 逐级，不并行，每级 `df -h` 前后记录 ② 每删一项在 `archive/topics/清理清单-<date>.md` 记「体积 + 重建来源（URL / commit / 设备重取命令）」 ③ 先导出独有内容再删容器 ④ 删后回改本节与 §2.3 的路径，别让后续会话找空路径。
