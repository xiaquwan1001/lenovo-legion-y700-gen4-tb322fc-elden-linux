# SM8750（Snapdragon 8 Elite / TB322FC）跑 Windows on ARM：开源现状调研 + Gunyah 路线事实基础

- 日期：2026-10-24
- 性质：**纯主机侧只读调研**（未接触设备；未跑 adb/fastboot/ssh；未 `pi install`；未改 `.pi/`）
- 服务对象：`TASKS/README.md` §4 拓展项「Gunyah 高通虚拟化做 VM」、G2/G3
- 前序输入：`reports/gunyah-roadmap-20261021.md`、`reports/gunyah-stage0-positive-20261024.md`、
  `reports/uefi-gunyah-reassess-20261024.md`、`reports/uefi-woa-prep-20261024.md`
- 证据等级：【已证实】= 本轮命令/API 原文输出可复核；【未证实】= 有线索无闭环；【推测】= 推理

## 0. 结论先行

| # | 问题 | 结论 | 证据等级 |
|---|---|---|---|
| 1 | 同 SoC（SM8750/8 Elite）**裸机**跑 WoA | **无任何项目**。Mu-Silicium 的 8 Elite 机型 `Windows Boot = ❌`；SM8750 平板 UEFI 项目 SunUEFI 自述「Windows / WinPE：目标，**尚未启动**」 | 【已证实】 |
| 1b | 同 SoC **虚拟机**跑 WoA | **有，且直接点名本机型**：`Droid-VM/edk2-gunyah` README「Tested devices: **Lenovo Y700 Gen4 (codename tb322fc, with SM8750)**」，guest = Windows 11 ARM64 on **crosvm + Gunyah** | 【已证实】（README 原文） |
| 2 | Gunyah + Windows 现状 | 三条独立证据链都在 2026 年：**AnyLaySys** 2026-06-18「新 启动Microsoft Windows 改 ramfb」；**Droid-VM** 把 restricted-dma-pool 作为 ACPI 设备发布「so a Windows guest can find one」+ 专门的 Windows 半虚拟化驱动仓库；**qemu-gunyah** 可跑 Windows guest 但需自建 | 【已证实】 |
| 2b | 是否需 Android 宿主 | **是**（现有全部实现都是 Android app/root shell 里跑 crosvm 或 qemu，Gunyah 由原厂 hyp 提供）。**我们这块板子相反**：Linux 是宿主 ⇒ 需 mainline Gunyah guest driver + crosvm/userspace，见 §4 | 【已证实】+【推测】 |
| 2c | 是否需签名/受保护 VM | 受保护 VM（`--protected-vm-without-firmware`）是 DroidVM 的主路径，guest 驱动**未签名**，装 Windows 必须 `testsigning on` + `nointegritychecks on`；但**非保护 VM 也能跑**（crosvm `--protected` 不是唯一选项） | 【已证实】wiki + 【推测】非保护路径 |
| 3 | USB 直通 | 见 §3：crosvm 有 `--usb` 后端但 Gunyah 下受限；Droid-VM/edk2-gunyah 2026-09-10 合了 `pr/usb`；**无任何项目做到可用的 USB 直通** | 详见 §3 |
| 4 | mainline `drivers/virt/gunyah` | 截至 2026-10 **仍未合入**（`gh api repos/torvalds/linux/contents/drivers/virt` 无 `gunyah/`）；AOSP android15-6.6 有完整实现，与上游 v17 有差异 | 【已证实】 |
| 5 | 最短路径 | **Gunyah VM 远短于裸机 UEFI 直启**；3 个必须先验证的二值事实见 §5 | 【推测】，附判据 |

## 1. 同 SoC（SM8750 / 8 Elite）已能跑 WoA 的项目

### 1.1 裸机路线：**零**

**（a）Mu-Silicium（Project-Silicium，★566，pushed 2026-10-21）** —— 手机/平板 UEFI 的事实标准移植库。
`Status.md` 里所有 **Snapdragon 8 Elite** 机型（OnePlus 13 `dodge`、OnePlus 13s 等）均为：

```
$ gh api repos/Project-Silicium/Mu-Silicium/contents/Status.md | base64 -d > silicium-status.md
$ sed -n '798,830p' silicium-status.md
<summary><b><strong>Snapdragon 8 Elite Devices</strong></b></summary>
## OnePlus 13
**State:** Inactive <br>
**Codename:** dodge
| USB Host Mode        |              | ❌    |
| USB Device Mode      |              | ✅    |
| Mass Storage         |              | ✅    |
| Windows Boot         |              | ❌    |
| Linux Boot           |              | ✅    |
```

反向对照（谁 **能** Windows Boot）：脚本扫全部 86 处 `Windows Boot` 行，`✅` 的机型**全部是 SM8xx 及更老**
（Poco F6/SM8635、OnePlus 12R/SM8550、Legion Tab Y700 2022/SM870、Xiaomi Pad 6/SM870 …），
**没有一台 8 Elite / 8 Elite Gen5**。命令与解析见 §7.1。⇒ **【已证实】Mu-Silicium 生态里 SM8750 裸机 WoA 未实现。**

**（b）Project-SunUEFI（SM8750 平板 Xiaomi Pad 8 Pro `piano`，★31，pushed 2026-10-23）** ——
同 SoC 上最活跃的 UEFI/Linux 项目，README 明说：

```
$ grep -n "Windows" slwyts_Project-SunUEFI.md
9:  **Linux 已经能体验近乎完美，Windows 还在计划之中。**
90:    D -.->|"目标，尚未实现"| H["Windows"]
166:* **Windows / WinPE**：目标，尚未启动。
```
⇒ **【已证实】同 SoC 平板方向最前沿的团队也还没把 Windows 启动过**（他们走的是 Mu-Silicium 血统 + 合体 BOOT）。

**（c）同 SoC 的其他 UEFI 移植**：`AnyLaySys/uefi_oneplus_ace5_pro`（OnePlus Ace 5 Pro = SM8750，★1，pushed 2026-10-24）
是 Project Mu 移植，README 无 Windows 声明【未证实】。

### 1.2 虚拟机路线：**有，且点名我们的机型**

**`Droid-VM/edk2-gunyah`**（★26，created 2026-03-13，pushed 2026-10-14，default branch `droidvm`）
README 原文（`gh api repos/Droid-VM/edk2-gunyah/readme | base64 -d`）：

```
UEFI Firmware for crosvm + gunyah virtualization platform
...
## Tested platforms
### SoC
- **Qualcomm Snapdragon 8 Elite Gen 5** (SM8850)
- **Qualcomm Snapdragon 8 Elite** (SM8750)
### Devices
- **Xiaomi Redmi K90 Pro Max** (codename "myron", with SM8850)
- **Lenovo Y700 Gen4** (codename "tb322fc", with SM8750)
```

启动方式（同 README，**Android 宿主**）：

```
/apex/com.android.virt/bin/crosvm run     --mem 4096 --cpus 1     --protected-vm-without-firmware --no-balloon --disable-sandbox     --block disk.img,lock=false     edk2-gunyah.fd
```

⇒ **【已证实】「SM8750 + Gunyah + crosvm + UEFI」在 tb322fc 上已被第三方跑通**（我们不是首例，这是好消息：
别人的 bug 已经踩完；坏消息：他们的宿主是 **Android**，我们是 **Linux**，见 §4）。

**机型限制**：只有 SM8750/SM8850 两台被列出；8 Gen 3 反而**跑不动**（见 `wiki/FAQ.md` 第 4 条，
"8E and later versions refactored the Gunyah code"）⇒ **【已证实】我们这块板子恰好落在「能跑」的那一侧**。

---

## 2. Gunyah + Windows 现状

### 2.1 三条独立证据链

| 项目 | 关键提交/文件 | 时间 | 含义 |
|---|---|---|---|
| `AnyLaySys/edk2-aarch64-gunyah` | `18a44801` **「26.6.18P1 新 启动Microsoft Windows 改 ramfb」**，改 `OvmfPkg/QemuRamfbDxe/QemuRamfb.c +282-188` | 2026-06-18 | **ramfb 是让 Windows 出画面的关键**（Windows 不吃 simple-framebuffer，需 ramfb 协议） |
| `Droid-VM/edk2-gunyah` | `a20669db`「publish every DroidVM pool as an ACPI device, **so a Windows guest can find one**」；`53d4a83b`「GunyahPoolAcpiDxe: a growable pool's window comes from `droidvm,pool-size`」；`09516e10`「patches/edk2: **the power, reset and idle states an ACPI-only guest needs**」 | 2026-08-30 | Windows 需要 **ACPI 电源/复位/空闲状态** 与 **可发现的 DMA 池**，这两条是 Linux guest 不需要的 |
| `Droid-VM/gunyah-guest-drivers-windows` | ★4，BSD-3，release `dev`(2026-09-12) `gunyah-arm64-drivers.zip` | 2026-09-18 | 把 **virtio-win 全套**（viostor/vioscsi/NetKVM/WDF）移植到 Gunyah 保护 VM 的「lent memory + restricted DMA pool」模型 |

`gunyah-guest-drivers-windows/README.md` 的核心机制（原文摘）：

```
In a protected VM, guest memory is not visible to the host by default (lent memory).
The only region shared with the host is the restricted DMA pool, declared in the boot FDT
and surfaced to Windows by edk2-fork as an ACPI\RDMA0000 node. ...
- rdmapool.sys (new) binds ACPI\RDMA0000 ...
- StorPort (viostor/vioscsi) shares the static library rdmapool/rdmaclient.c ...
- NDIS (NetKVM) uses ParaNdis_RdmaPool: ... TX is forced through the copy path.
```

⇒ **【已证实】Gunyah 上跑 Windows 的「难点清单」已经被别人写清楚了**：不是 CPU/中断（那些 crosvm 已解决），
而是 ①ramfb 显示 ②ACPI 电源模型 ③保护 VM 下所有 virtio 队列与 payload 必须落在 restricted-dma-pool 或经其 bounce
④驱动未签名。

### 2.2 完成度：**能装、能跑，但输入/外设残缺**

`DroidVM` wiki（`git clone https://github.com/Droid-VM/DroidVM.wiki.git`）：

```
wiki/FAQ.md:1: 1. Unable to input on Windows system
   Currently, a driver modification to support Protected VM is required.
   This driver is not yet publicly released.
wiki/Windows-Installation-Guide.md:
   Use Dism++ to import drivers for boot.wim (PE) or the system (full installation)
   Signature verification needs to be disabled:
   bcdedit /store BCD /set {default} testsigning on
   bcdedit /store BCD /set {default} nointegritychecks on
```

⇒ **【已证实】** ①Windows 安装需要 **PE + Dism++ 注入驱动**；②必须关驱动签名强制（即 **无签名/无 Secure Boot 链**）；
③**键盘/鼠标输入在 Windows 下仍不可用**（FAQ 第 1 条），即截止 2026-10 该路线**没有可用的交互输入**。
Windows 安装指南本身正文只有 `TODO` 一行 ⇒ 文档完备度低【已证实】。

### 2.3 是否需 Android 宿主 / 受保护 VM

- **宿主**：DroidVM = Android APK（★938，GPL-3.0）；crosvm 用 `/apex/com.android.virt/bin/crosvm`（Android 虚拟化 apex）；
  polygraphene 的 `gunyah-on-sd-guide`（★148）也是「Android 15 + root(APatch) + adb push crosvm-a16」。
  ⇒ **【已证实】现有全部可用方案都依赖 Android 宿主**。原因见 §4：**Linux 侧没有可用的 Gunyah guest 驱动 + VMM 用户态**。
- **受保护 VM**：DroidVM 例子用 `--protected-vm-without-firmware`（不需要签名固件，即 **pvmfw 不参与**），
  但 guest 内部仍需 `testsigning`。⇒ **不需要厂商签名**，但**需要自签/关校验**【已证实】。
- 非保护 VM 路径：crosvm 上游支持 `--protected` 省略；但 DroidVM 的驱动栈是按保护 VM 写的（rdmapool），
  非保护模式下反而更简单（内存全共享）——**未见到项目明说支持**，【推测】可行。

### 2.4 qemu-gunyah（RFC 与社区实现）

**上游 QEMU：没有。** `accel/` 目录清单（2026-10-24 复核）：

```
$ gh api repos/qemu/qemu/contents/accel --jq '.[].name' | tr '
' ' '
Kconfig accel-blocker.c accel-common.c accel-internal.h accel-irq.c accel-qmp.c accel-system.c
accel-user.c dummy-cpus.c dummy-cpus.h hvf kvm meson.build mshv nitro qtest stubs tcg whpx xen
$ gh api -X GET search/code -f q="gunyah repo:qemu/qemu" --jq .total_count
0
```
⇒ **【已证实】主线 QEMU 无 gunyah 加速器**。

**RFC 停在 v2（2024-05-16），此后无 v3。** marc.info 索引（`marc.info/?l=qemu-devel&s="Gunyah hypervisor support"`）
同时列出 v0(2023-10)、v1(2024-01)、v2(2024-05) 三版；v2 cover letter 原文
（`marc.info/?l=qemu-devel&m=171586989617791&q=raw`）关键段：

```
This patch series adds support for Gunyah hypervisor via a new accelerator option, 'gunyah'.
This patch series is based on the Linux kernel's Gunyah driver, which is being actively
developed and not yet merged upstream [1, 2].
This patch series is thus *NOT YET READY* for merge. ...
Limitations:
* Confidential guests (or protected VMs) are not yet supported by Linux Gunyah driver published
  upstream. I have tested it using a variant of the driver available in Android Common Kernel [3].
* Instructions ... based on v17 Gunyah driver will be provided later.
```
（作者 Srivatsa Vaddagiri，12 个 patch；`gunyah: UAPI header (NOT FOR MERGE)`）
⇒ **【已证实】qemu-gunyah 上游化自 2024-05 起停滞**，且当时**保护 VM 需要 ACK 的私有驱动变体**。

**社区实现（活着的）**：
- `AnyLaySys/qemu-gunyah`（★21，pushed 2026-09-07，44 MB）：**out-of-tree QEMU + `-accel gunyah` + `-M virt,confidential-guest-support=prot0`**，
  README 给出完整 Android 命令行（virtio-blk-pci/virtio-gpu-gl-pci/virtio-snd-pci/virtio-net-pci + AGL/AAudio 后端）。
  历史自述「**qemu 直接调用 gunyah**」，是关键证据：**Gunyah 的 UAPI 足以让第三个 VMM（非 crosvm）跑起来**【已证实】。
- `qemu-gunyah/qemu-android-gunyah`（★17）、`karim-manaouil/qemu-for-gunyah`（KVM-over-Gunyah 内核移植）、
  `code002-2/librevm`（★5，「first-class Gunyah support」的 Linux VMM，2026-10-15）【未证实完成度】。
- `AnyLaySys/als`（★23）= 「任何层原生运行系统」，前端把 qemu-system-aarch64 的 gunyah/gzvm/tcg 加速器包成 App。

> 注意：AnyLaySys 的 repo 明说 `-m 4352M`、`swiotlb-size=256M`、`-cpu host`，即 **guest 直接看到 host CPU**（无 CPU 模型），
> 这对 Windows 是双刃剑（见 §5）。

## 3. USB 直通
（填）

## 4. Gunyah RM 与 Linux guest driver 上游现状
（填）

## 5. 结论：最短路径与「必须先验证的 3 个二值事实」
（填）

## 6. 未证实 / 待办
（填）

## 7. 命令与原始证据附录
（填）
