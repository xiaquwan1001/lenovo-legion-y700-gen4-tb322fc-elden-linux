# Gunyah 虚拟化线（拓展项）资产盘点 + 事实核查 + 分阶段规划

> 日期：2026-10-21 · 角度：拓展（非主线）· 关联任务：`TASKS/README.md` C8 / §1 拓展行 / §5 Q4、Q13、R2
> 前置定案（不重推）：`archive/topics/EL2-VIRT-2026-10-02.md`、`.pi/agents/el2-virt.md`、`.pi/missions/el2-virt.md`
> 本轮约束：**纯主机侧只读**。设备停在 fastboot（`fastboot devices` = HA2EXB0E），全程未执行任何
> fastboot / adb / EDL / reboot 命令，未修改任何 README、未 commit、未动 `patches/` `out/` `backup/`。
> 证据标记：【已证实】= 本机命令输出或仓库/上游原文可复核；【未证实】= 有线索无闭环证据；【推测】= 推理。

## 0. 一句话结论

**Gunyah 线现在不该开工。** 主线至今只有 `gunyah_wdt`、无 RM/VM 驱动（本机 7.2 与 7.3-rc7 两树均无 `drivers/virt/gunyah`；上游公开最新仍 v17/2024-02），本机“主线侧”资产（下游驱动源码、edk2 三仓、DroidVM prebuilts、qemu-for-gunyah）**全部不在盘**（edk2 三仓 = 2026-10-17 换机丢失，可重下）；但本轮找到一条**比 C8 原判据强得多的零成本探测**：`qcom_scm` 已在 probe 时问 Gunyah UUID 并注册 `gunyah-wdt` 平台设备（`build/m1-73/drivers/firmware/qcom/qcom_scm.c`:2497–2528，我们树两个早退条件均不成立）⇒ 下次上机一条 `ls /sys/bus/platform/devices/ | grep gunyah` 就能闭环“hyp 到底是不是 Gunyah”这个 10 天前误以为已测的问题。**C8 应从「已探测、维持低优先」改为「驱动缺失已闭环 / hyp 存在性未测」，优先级仍为拓展线 P3，唯一许可动作 = 阶段 0 的两条只读命令。**

---

## A. 资产清单表

### A.1 实盘（本机 `/home/xuqianhui`，2026-10-21 只读 find/du）

| 资产 | 状态 / 体积 | 用途与裁定 |
|---|---|---|
| `edk2-gunyah`（GunyahPkg guest UEFI，README 自述测过 TB322FC）、`edk2-gunyah-qemu`、`edk2-aarch64-gunyah`（含 ramfb/Windows 分支） | **三个目录全不存在**（`RESOURCES/README.md`:279 登记三仓 2.0 G） | 阶段 2/3 的 guest 固件 ⇒ **丢失**：2026-10-17 换机未随迁，迁移包 `~/下载/migration-2026-10.tar.xz` tar 列表也无 ⇒ 可重下，不阻塞 |
| `DroidVM-Prebuilts`（自建 crosvm+SBSA UART/PmReset）、`gunyah-guest-drivers-windows` zip、Win11 ARM64 ISO | **未在本机发现任何副本** | 阶段 3 主链 ⇒ **从未落盘或已丢失**【未证实曾有：`RESOURCES` 从未登记其路径/体积，`TASKS/README.md`:386 只有能力描述】 |
| `qemu-for-gunyah`（karim-manaouil） | **不存在** | RFC 00/34 的 VMM ⇒ 从未 clone（`RESOURCES/README.md`:61 仅登记为链接） |
| 下游 gunyah 驱动源码 `drivers/virt/gunyah/*` | **不存在** | **阶段 1 第一必需件** ⇒ 缺：`stock-src/android_kernel_lenovo_sm8750`（6.6.104，1.5 G）find/grep 零命中【已证实】 |
| `backup/avf/bin/crosvm` + `etc-fs/{microdroid_kernel,microdroid_super.img,u-boot.bin,rialto.bin,initrd_*}` | ✅ 10.7 M / 12.2 M / 45.8 M / 1.0 M… | crosvm = `ELF aarch64 … interpreter /system/bin/linker64, for Android 36`（bionic）⇒ **不在 glibc/musl 主线上跑**；其余只对 Android guest 有意义 |
| `backup/stock-elden/kernel-headers/linux/{gunyah,gunyah_deprecated}.h` | ✅ 13.7 + 11.5 KB | **下游 `/dev/gunyah` UAPI 参考**（`GUNYAH_CREATE_VM`/`VM_SET_DTB_CONFIG`/`VM_START`…）⇒ 可用，阶段 1 的 ABI 对照基线 |
| `backup/stock-elden/{vendor_dlkm,vendor_ramdisk}/{hvc_gunyah,qrtr-gunyah,gunyah_loader}.ko` | ✅ 23.5 / 34.8 / 196 KB | **不可加载**（`vermagic=6.6.56-android15-8-maybe-dirty-4k`，依赖 `gh_rm_drv,gh_dbl,gunyah_loader,qcom-scm`）⇒ 只能当 ABI/符号清单读 |
| `hypvm.mbn`（EL2 hyp 本体） | ✅ 8 MiB（`~/下载/tb322fc/`） | 证明 hyp 固件在（XBL 加载）⇒ **只读参考，禁写回** |
| 主机 `qemu-system-aarch64` / AAVMF / `aarch64-linux-gnu-gcc` | ✅ qemu 10.2.1 + `qemu-efi-aarch64 2025.11` | 路线② TCG 台架 ⇒ **完全可用**（`qemu-img`/`nbd` 同装，736 G 空闲） |
| 主机 `cargo`/`rustc` | **缺** | 自编 crosvm 前置 ⇒ 缺（apt 候选 `rustc 1.93.1`；但需先有阶段 1 的 `/dev/gunyah`） |

**A.2 结论**：Gunyah 线**完整成套的只剩「Android 侧运行件 + 下游 UAPI 头 + 下游 .ko 符号清单」**；与「主线 Linux 侧」有关的（驱动源码、guest 固件三仓、VMM）**一件都不在盘**。与 `RESOURCES/README.md`:279 口径差异：那里把 edk2 三仓写成「在位、可清理」，实盘已无 ⇒ **该行过期**（本轮不改 README，只登差量）。

---

## B. 事实核查

### B.1 主线 gunyah 驱动是否可用

**结论：不可用，与 C8 原结论一致（确认，非推翻）——但多一条「为什么不可能靠等上游」的具体依据。**【已证实】

| 检查 | 命令/路径 | 结果 |
|---|---|---|
| 7.3-rc7 基线树有无驱动 | `ls build/m1-73/drivers/virt/` | `Kconfig Makefile acrn coco fsl_hypervisor.c nitro_enclaves vboxguest vmgenid.c` —— **无 gunyah** |
| 7.2 树（`linux -> geekidos-linux`） | `ls linux/drivers/virt/gunyah` | No such file or directory |
| 头文件 | `ls {build/m1-73,linux,geekidos-linux}/include/linux/gunyah*.h` | 均不存在 |
| 树里唯一的 gunyah 代码 | `find build/m1-73 -iname '*gunyah*'` | 仅 `drivers/watchdog/gunyah_wdt.c` |
| 配置 | `grep GUNYAH build/m1-73/.config` | `# CONFIG_GUNYAH_WATCHDOG is not set`（且 `# CONFIG_KVM is not set`） |

**上游状态（网络 2 次）**：公开可见最近系列仍是 **v17（35 封，2024-02-22，含 `MAINTAINERS` 与 `drivers/virt/gunyah/*` 全量）**；命中的均为 v10–v17 评审/patchew 页，**无 v18+/merged 证据** ⇒【未证实（仅表示本轮检索未见）】。决定性依据仍以本机为准：**我们的 7.3-rc7 树里没有 ⇒ 不能把「等上游」当策略**。

**负面含义（新增差量）**：主线只合了 **`gunyah_wdt` 看门狗**（`drivers/watchdog/Kconfig`:2382，`tristate`，`depends on ARCH_QCOM || COMPILE_TEST`），所以「上游支持 Gunyah」**只到“能在 Gunyah 下拿到看门狗”这一层**，**不包含** RM（resource manager）通信与 VM 生命周期。要跑 guest 必须自己搬 ~6700 行（v15/v17 规模）。

---

### B.2 我们的内核能否探测到 Gunyah hypervisor

**结论：能，而且比 2026-10-10 的 C8 探测口径强得多；但设备侧结果仍【未证实】（本轮禁上机）。**

#### （1）C8 原判据是恒阴性的（口径更正）

`TASKS/README.md`:74 的依据是「`dmesg` 仅见 reserved-memory `gunyah-hyp@80000000`，无 `gh_rm`/gunyah 驱动」⇒ 推「第一步不成立」。但树里**根本没有** `gh_rm` 驱动（B.1）⇒ `dmesg | grep gh_rm` **必然**为空；归档日志里 gunyah 也只有一行：`logs/vk127-20261017/baseline-dmesg.txt` → `OF: reserved mem: 0x80000000..0x80dfffff (14336 KiB) nomap non-reusable gunyah-hyp@80000000`（`s1/s5/s7` 同）。
⇒ 该探测**只能证明“没有驱动”，不能证明“没有 Gunyah”**。C8 应写成「驱动缺失已闭环；hyp 存在性**未测**」。【已证实：日志/代码】

#### （2）真正的零成本判据：`qcom_scm` 已把 UUID 探测结果物化成 platform device

`build/m1-73/drivers/firmware/qcom/qcom_scm.c`：`:2497` `qcom_scm_gunyah_wdt_init()`、`:2503` UUID `c1d58fcd-a453-5fdb-9265-ce36673d5f14`、`:2511-2513`「不在 Gunyah 下就 return」(`IS_ENABLED(CONFIG_HAVE_ARM_SMCCC_DISCOVERY) && arm_smccc_hypervisor_has_uuid()`)、`:2518-2525`「DT 有 `qcom,kpss-wdt`/`arm,sbsa-gwdt` available 也 return」、`:2528` `platform_device_register_simple("gunyah-wdt", …)`，调用点 `:2942`（probe 末尾无条件）。

本机两个早退条件都不成立 ⇒ **若 hyp 是 Gunyah，`/sys/bus/platform/devices/gunyah-wdt` 必然存在**：

| 早退条件 | 我们树的状态 |
|---|---|
| `CONFIG_HAVE_ARM_SMCCC_DISCOVERY` / `CONFIG_QCOM_SCM` | 均 `=y`（`build/m1-73/.config` 与 `logs/vk127-20261017/baseline-config.txt`）【已证实】 |
| DT 有 `kpss-wdt`/`sbsa-gwdt` available | `sm8750*.dtsi` 零命中 ⇒ 不短路【已证实】 |
| `CONFIG_GUNYAH_WATCHDOG` | `not set` ⇒ 设备被注册但**无驱动绑定**；`platform_device_register_simple()` 不打 log ⇒ **dmesg 里永远看不到，必须查 sysfs**【已证实：代码】 |

**阶段 0 判据（只读，≤2 条命令）**：`ls /sys/bus/platform/devices/ | grep -i gunyah`（有 `gunyah-wdt` = 阳性）；`ls /proc/device-tree | grep -i hypervisor` 旁证。

**若想再排除误判**（阶段 0b，需自编一次）：`CONFIG_GUNYAH_WATCHDOG=m` → `modprobe gunyah_wdt` → 看 `/sys/class/watchdog/watchdogN/uevent` 是否 `driver=gunyah-wdt`。但 probe 在 SMC 返 `-EOPNOTSUPP` 时**静默 `-ENODEV`**（`gunyah_wdt.c`:176-178）⇒「没绑驱动」≠「hyp 不在」；硬判据仍只有 `:2528` 的设备。

#### （3）已有旁证（均非闭环，但同向）

- 内核运行在 EL1：`CPU: All CPU(s) started at EL1`（`logs/vk127-20261017/baseline-dmesg.txt`）——**这行在没有 hyp 的普通裸机也会出现，不能单独当证据**；
- EL2 被占的痕迹：`Broken CNTVOFF_EL2`、`Enhanced Virtualization Traps`、`CNTPOFF`（同日志）；`# CONFIG_KVM is not set`；
- DT 保留区被内核履行：`gunyah-hyp@80000000`（14336 KiB，`build/m1-73/arch/arm64/boot/dts/qcom/sm8750.dtsi`:342）；
- 固件侧：`~/下载/tb322fc/hypvm.mbn`（8 MiB）在位。

⇒ 合成判断：**「EL2 有一个 hyp」是【已证实】；「这个 hyp 是 Qualcomm Gunyah 且其 RM 对我们开放」是【未证实】，而 B.2(2) 给了 2 条命令就能闭环的办法。**

### B.3 无 KVM 前提下三条路线可行性

先钉前提（不重推）：**KVM 不可得** = `DEVICE/README.md`:21「签名 Gunyah 占 EL2（内核只到 EL1）」+ `# CONFIG_KVM is not set` + `All CPU(s) started at EL1`；替换/禁用 hyp 会碰 XBL 签名链（`EL2-VIRT-2026-10-02.md` §4/§5 已定稿）——本线不碰。

| 路线 | 本质 | 本机就绪度 | 真前置缺口 | 裁定 |
|---|---|---|---|---|
| **① Gunyah guest**（主线 Linux 当 primary VM，调 RM 开子 VM） | 唯一能真用上硬件虚拟化的路线（非 KVM） | 下游 UAPI 头 + AVF 运行件 + `hypvm.mbn` 在位；**驱动源码/DT/VMM 全缺** | ① 阶段 0 阳性；② 下游 `drivers/virt/gunyah` 源码（本机无）；③ 6.6→7.3 API 漂移；④ RM msgq/中断资源与 DT 节点；⑤ 用户态 VMM | **部分可行、高工作量**。外部先例只能证明“Android 宿主下能跑”（polygraphene 在同一机型 Y700 gen4 用 crosvm+`--protected-vm-without-firmware` 跑起 Debian 12.8），**主线侧零先例**【未证实】 |
| **② QEMU TCG**（纯模拟） | 不碰 EL2 | **完全就绪**【已证实】：qemu 10.2.1 + `/usr/share/AAVMF/{AAVMF_CODE.fd,QEMU_EFI.fd}` + `aarch64-linux-gnu-gcc` + `qemu-img/nbd` + 736 G 空闲 | 无 | **能跑但不算交付**：aarch64 Linux guest 小时级能通；**Windows-on-ARM64 在 TCG 下实质不可用**（无 KVM/HVF），且与 G3（x86 Steam via Box64/Wine）**不重叠** ⇒ 只做镜像/固件离线验证台 |
| **③ crosvm** | 不是独立路线，是 ① 的用户态前端 | `backup/avf/bin/crosvm` = **bionic 动态 ELF（`/system/bin/linker64`，Android 36）**⇒ 主线上跑不了；自编需 `cargo`（缺） | 依赖 ① 的 `/dev/gunyah`（其 gunyah 后端就是 `GUNYAH_CREATE_VM` 等 ioctl） | **不可单独成立**；即使编好仍受「只支持 protected VM」「virtio/图形不稳」两条已知限制 |

**关键判断**：三条里只有 ① 是真虚拟化；② 与 ① **不共享代码**，不能当 ① 的预热，只能当 guest 镜像/EDK2 固件的离线验证台；③ 是 ① 的前端 ⇒ **实际待决策的只有两条：① 做不做，② 现在建不建台架**。

**隐藏成本（逐项有据）**：生产 hyp 只给 protected VM（`--protected-vm-without-firmware` + `ulimit -l unlimited` 是 workaround）；guest 内无 KVM（嵌套不开）；Windows guest 无 GPU（`viogpu` 未移植，`TASKS/README.md`:386/400）；阶段 3 需 **a 槽 Android + root**，与 G2 前提冲突。

---

## C. 分阶段实现规划

### 阶段 0 — 探测（零风险，只读）

| 项 | 内容 |
|---|---|
| **前置** | 无。在机 `boot_b` = vk127（7.3-rc7，`CONFIG_HAVE_ARM_SMCCC_DISCOVERY=y`、`qcom_scm=y`）—— **C8 所需能力已在设备上**，不须重编、不须写盘 |
| **动作** | 跑主线时捾带：`ls /sys/bus/platform/devices/ \| grep -i gunyah`、`dmesg \| grep -iE 'gunyah\|hypervisor'`，顺手 `ls /proc/device-tree/ \| grep -i hypervisor` |
| **产物** | `archive/topics/EL2-VIRT-probe-2026-10-2x.md`（原始输出）+ 本报告 B.2 回填 |
| **判据** | 阳性 = 出现 `gunyah-wdt` 设备（⇒C8 转「立项评估」）；阴性 = 无（⇒C8 正式关闭）。工时 **0.2 h**，捾带，不单独占设备 |
| **停损** | 一窗内完成；**不得为本项单独 `fastboot boot`/刷写/重启** |

**阶段 0b（可选，仅当 0 阴性且想排除误判）**：`CONFIG_GUNYAH_WATCHDOG=m` 重编一版 + `modprobe gunyah_wdt`，看 `/sys/class/watchdog/watchdogN/uevent` 是否 `driver=gunyah-wdt`。工时 1–2 h（一次构建）；不改变阴性/阳性判据强度（因为 0 的 `gunyah-wdt` 设备已足以证明 UUID 匹配）。

---

### 阶段 1 — 驱动与 DT

| 项 | 内容 |
|---|---|
| **前置** | 阶段 0 **阳性**；且先拿到下游驱动源码（本机 **无**：stock 6.6.104 树无 `drivers/virt/gunyah`、`geekidos-linux` 也无）；建议取 **v17 系列**（是公开且与 `backup/stock-elden/kernel-headers/linux/gunyah.h` 同一代 UAPI：`GUNYAH_CREATE_VM`/`VM_SET_DTB_CONFIG`/`VM_START`） |
| **内容** | ① 搬 `arch/arm64/gunyah/`+`drivers/virt/gunyah/*`+`asm/gunyah.h` 到 7.3-rc7（v17 base 约 6.8、stock 6.6 ⇒ 有 API 漂移）；② 补 DT hyp 节点 + RM msgq/mailbox/中断（现树只有 `gunyah-hyp@80000000` 保留区，`sm8750.dtsi`:342）；③ 开 `CONFIG_GUNYAH*` 并进 vk 构建链 |
| **产物** | 分支 `el2-gunyah/port-v17`（按纪律不直推 mainline 树）+ `/dev/gunyah` + `dmesg` 里 `gh_rm` 版本/vmid |
| **判据** | **`/dev/gunyah` 存在 + `gh_rm_get_vmid` 返回 0 + 一次 `gh_rm_call` 往返成功**（三件全中才算通） |
| **工时** | **3–10 人日**（乐观：只编得动 + RM 直接应答；悲观：需逆向 ABI 差异/找 msgq 中断） |
| **停损** | ⚠️ ① RM 回 `51000015`/权限拒绝（社区已见）且无绕过 ⇒ 停；② msgq 中断/MSI 资源在 DT 里无着 ⇒ 停（意味着生产 hyp 不为非 Android VM 开 RM）；③ **连续 3 天无进展 ⇒ 写复盘后归档**（全局硬规则） |

---

### 阶段 2 — 最小 guest

| 项 | 内容 |
|---|---|
| **前置** | 阶段 1 三判据全中；先可用 `samples/gunyah` 风格最小 VMM（不先碰 crosvm） |
| **内容** | ① 用 `/dev/gunyah` 建一个非 proxy 的 VM，装 BusyBox initramfs guest；② 再试 `gunyah_loader` 风格的 rsc_mgr 路径；③ 最后才试 crosvm（需自编，`rustc 1.93.1` apt 可装） |
| **产物** | guest console 日志（首次 `Run /init`）+ 启停脚本 + 最小 guest 镜像制作说明 |
| **判据** | **guest 终端有输出 + 能正常关机 + 宿主不 panic/不泄页 30 min** |
| **工时** | **2–5 人日** |
| **停损** | 若生产 hyp **只接受 protected VM** 且 `--protected-vm-without-firmware` 在本机 vk127 不成立 ⇒ 停（不为此去碰 `pvmfw`/签名链） |

---

### 阶段 3 — DroidVM / Windows

| 项 | 内容 |
|---|---|
| **前置**（全缺） | ① 重下 `edk2-aarch64-gunyah`（1.5 G）、`DroidVM-Prebuilts`、`gunyah-guest-drivers-windows` zip、Win11 ARM64 ISO；② 一台 **x64 Windows 或 Apple Silicon** 镜像构建主机（本机不满足）；③ `a` 槽 Android + root（DroidVM 是 Android 应用）；④ `viogpu` 移植（未做） |
| **产物 / 判据** | Windows-on-ARM64 guest 快照 + 盘/网（viostor/NetKVM）可用；判据 = Windows 登录界面 + 磁盘/网卡驱动加载（**无 GPU，仅 ramfb/simplefb**） |
| **工时 / 停损** | **≥2 周**（主要花在镜像构建环境与 virtio-win 驱动池）。⚠️ **与 G2 前提直接冲突**（需 Android 宿主）+ 无 GPU ⇒ 建议**永久冷藏**；**性价比终点是阶段 2（Linux guest），不是 Windows** |

---

## D. 结论与建议

### D.1 三个直接回答

1. **是否现在开工？——不开。** 阶段 1–3 全部挂起；**只允许做阶段 0（2 条只读命令，捎带一次上机窗口）**。理由：阶段 1 的第一必需件（下游 `drivers/virt/gunyah` 源码）本机不存在，且阶段 0 尚未阳性 —— 现在开工就是“先搬 6700 行再验证 hyp 在不在”，顺序错了。
2. **优先级：P3（拓展，低于 G1/G2/G3）**。与 `TASKS/README.md`:18 一致；但 C8 的状态词应由「探测已做」改为 **「驱动缺失已闭环；hyp 存在性未测」**（B.2 口径更正）。
3. **第一步是否只读？——是，且能只读。** 决定性判据就是 `/sys/bus/platform/devices/gunyah-wdt`（`qcom_scm.c`:2528 的产物），只需一次正常启动 + 一条 `ls`，零写盘、不占独立设备窗口。

### D.2 相对现有定案的确认 / 推翻 / 差量

| 现有口径 | 本轮判定 |
|---|---|
| KVM 不可得（EL2 被签名 hyp 占） | **确认**（`DEVICE/README.md`:21；`# CONFIG_KVM is not set`；`All CPU(s) started at EL1`） |
| 独立 gunyah 驱动未进主线 | **确认并加现**：7.2 与 7.3-rc7 两树均无；上游公开最新 v17（2024-02）；主线只合了 `gunyah_wdt` |
| C8「2026-10-10 探测已做」 | **部分推翻（口径）**：无驱动是因树里没编，“探测”恒阴性；**hyp 存在性从未被测**，需新判据（B.2） |
| 路线①「KVM-in-EL1 + Gunyah backend」 | 仍成立但**不是最优入口**（也需先有 `/dev/gunyah`）；`qemu-for-gunyah` 本机无、RFC 仍 WIP |
| edk2 三仓「在位、可清理」；Win-on-ARM「主链全预制」 | **均推翻/降级**：前者实盘已无（2026-10-17 丢失）；后者本机找不到任何副本，应改为「需重下/未落盘」 |

### D.3 给父 agent 的 README 动作建议（本轮不改 README）

- `TASKS/README.md` C8：状态词改「驱动缺失已闭环；hyp 存在性**未测**（新判据 = `gunyah-wdt` 设备）」+ 链本报告；
- `RESOURCES/README.md` §1.5/§3：edk2 三仓行加 **MIGRATION-LOST(2026-10-17)**；新增一行「下游 gunyah 驱动源码：**缺（阶段 1 阻塞件）**」；
- `DEVICE/README.md`:21：可补一句「Gunyah 存在性待用 `gunyah-wdt` 设备闭环」，不改变现有判定。

### D.4 一句话成本账

【已证实】阶段 0 = **0.2 h**；【推测】阶段 1 = **3–10 人日**（不确定度主要来自「拿不拿得到下游源码」与「RM 生不生产环境给非 Android VM 开口」，而非编码量）；阶段 2 = 2–5 人日；阶段 3 = ≥2 周且**与 G2 前提冲突**。
⇒ 正确顺序：**阶段 0 → 若阳性，先花半天只做「找下游驱动源码 + 读 RM ABI」再决定要不要投阶段 1**。

---

## 附：本轮执行的只读命令清单

主机侧（`/home/xuqianhui/y700-elden`，均只读）：

```bash
find . -maxdepth 4 \( -iname '*gunyah*' -o -iname '*droidvm*' -o -iname '*crosvm*' -o -iname 'edk2*' \) -not -path './.git/*'
find /home/xuqianhui -xdev -iname '*gunyah*' -o -iname '*DroidVM*' -o -iname '*crosvm*'   # 全盘无
tar -tJf ~/下载/migration-2026-10.tar.xz | grep -iE 'gunyah|droidvm|crosvm|edk2'   # 迁移包也不含
file backup/avf/bin/crosvm ; strings -a backup/stock-elden/vendor_dlkm/*gunyah*.ko | grep -i vermagic
find stock-src/android_kernel_lenovo_sm8750* -maxdepth 5 -iname '*gunyah*'   # 空
ls build/m1-73/drivers/virt/ ; ls linux/drivers/virt/gunyah build/m1-73/include/linux/gunyah*.h   # 均不存在
sed -n '2480,2545p;2940,2944p' build/m1-73/drivers/firmware/qcom/qcom_scm.c
grep -n 'kpss-wdt\|sbsa-gwdt' build/m1-73/arch/arm64/boot/dts/qcom/sm8750*.dtsi   # 零命中
grep -i gunyah logs/vk127-20261017/*.txt logs/vk127-20261017/s*/dmesg-full.txt
```

网络：2 次（LWN/LKML/patchew “Gunyah driver mainline status” + 下游源码仓），均只回 v10–v17（最新 **v17 = 2024-02-22**）。**设备侧命令：0 条**（未运行 fastboot/adb/ssh）。
