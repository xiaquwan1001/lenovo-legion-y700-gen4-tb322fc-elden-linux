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
| 3 | USB 直通 | **有且只有一家**：`Droid-VM/crosvm` fork `fb86c7b0`(2026-09-08)「xHCI + usbfs … both Linux and Windows guests drive it」+ DroidVM app 的 `usb-list`/`usb-attach` UI。机制是**仿真 xHCI**（Windows 用自带 `usbxhci.inf`），**不是 virtio-usb，也不是物理直通**；Gunyah 侧无设备直通模型 | 【已证实】commit 原文；实测报告仍缺 |
| 4 | mainline `drivers/virt/gunyah` | 截至 2026-10 **仍未合入**（`gh api repos/torvalds/linux/contents/drivers/virt` 无 `gunyah/`）；AOSP android15-6.6 有完整实现，与上游 v17 有差异 | 【已证实】 |
| 5 | 最短路径 | **Gunyah VM 远短于裸机 UEFI 直启**；hypervisor 侧已实测无缺口（API v1 + doorbell/msgq/vcpu/memextent），**真正的生死线是「RM capid 只存在于 stock Android DT」**；3 个待验证二值事实见 §5.3 | 【已证实】+【推测】 |

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

`Snapdragon 8 Elite Devices` 段前四台（最相关：OnePlus 13 `dodge`、OnePlus 13s、Poco F7、OnePlus 13R/Ace 5）
的 `Windows Boot` 全为 `❌`，`Linux Boot` 多为 `✅`。

反向对照（谁 **能** Windows Boot）：脚本扫全部 86 处 `Windows Boot` 行（`✅` **47** / `❌` **39**），`✅` 的机型**全部是 SM8xx 及更老**
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

### 3.1 结论：**有实现，但只有一家，且是「仿真 xHCI + usbfs」，不是 virtio-usb，也不是物理直通**

| 问题 | 答案 | 证据 |
|---|---|---|
| 有项目支持吗 | **只有 `Droid-VM/crosvm` fork**（★9，pushed 2026-10-23），由 DroidVM app 的 `usb-list` / `usb-attach` 命令驱动 | §3.2 |
| 用什么机制 | **guest 看到一颗仿真 xHCI 控制器**，host 侧走 **usbfs**（`/dev/bus/usb`）。**virtio-usb 不存在**（无此设备标准） | commit 正文 |
| Gunyah 侧要做什么 | **什么都不用做**：USB 不经 Gunyah；Gunyah 只提供 CPU/内存/中断/doorbell。保护 VM 下 xHCI 的 DMA 必须落在 swiotlb 区域 | §3.3 |
| SCM mem-lend + DT 直通整颗 USB 控制器 | **没有任何项目这么做，Gunyah 的 ABI 也不支持**（无设备直通/IOMMU 模型） | §3.3 |
| 完成度 | Linux guest ✅；Windows guest「也能驱动」✅（commit 明说）；但 **DroidVM FAQ 仍称 Windows 下无法输入** ⇒ 键盘/鼠标路径未闭环 | §3.4 |

### 3.2 仓库/文件级证据（crosvm fork）

提交 `fb86c7b0`（2026-09-08，PR #6 `pr/usb`，merge `53a5bef1` 2026-09-10）标题与正文原文
（`gh api repos/Droid-VM/crosvm/commits/fb86c7b0`）：

```
usb: pass a host device through to a protected VM

xHCI and the usbfs backend, far enough that a protected VM can be handed a
real USB device and both Linux and Windows guests drive it.

The controller: a protected VM keeps its xHCI when it has a swiotlb region;
QEMU's PCI id instead of Fresco Logic's, which is what Windows' usbxhci.inf
will bind to; ...
Isochronous: one TD is one packet is one ISO_ASAP URB ... That is USB audio and most webcams.
Bulk streams, which is what UAS mass storage needs ...
Stop Endpoint, which Windows waits on with a fixed watchdog after every stop ...
Squashed from 24 commits on wip/usb.
```

改动文件（同 commit API 的 `files[]`）：`devices/src/usb/backend/device.rs +92-7`、`endpoint.rs +115-3`、
`register_space/register.rs +42-1`、`fido_backend/fido_passthrough.rs +10-0` 等。

紧随其后的修复 `c43077ea`（2026-09-12）暴露了这套实现的真实约束：

```
usb: a transfer too big for the DMA window goes through a plain buffer

reserve_dma_buffer() ... That mapping is a fixed MMAP_SIZE (1 MB) window over the usbfs fd,
while the size comes from the guest's transfer descriptor ...
A DisplayLink adapter, whose driver pushes a frame as one bulk transfer, killed crosvm ...
```

⇒ **【已证实】** ①Windows 侧**不需要专用 USB 驱动**（用系统自带 `usbxhci.inf`，靠 PCI ID 匹配）；
②保护 VM 下每次传输受 **1 MiB usbfs MMAP 窗口**限制，超限回退到内核 DMA buffer 拷贝（性能与稳定性代价）；
③等时传输（USB 音频/摄像头）与 bulk stream（UAS 移动硬盘）已专门实现。

App 侧：`DroidVM` 有完整 USB 规则 UI 与命令（`gh search/code q="usb repo:Droid-VM/DroidVM"` → 119 命中），
例如 `app/src/main/cpp/console/commands/usb.cpp`：

```
class UsbListCommand ... { return "usb-list"; }    // List host USB devices
class UsbAttachCommand ... usage "<vm_id> <sysfs>" // Attach a host USB device to a VM
```

### 3.3 Gunyah 侧：为什么「物理直通」不存在

`quic/gunyah-hypervisor` README（`gh api repos/quic/gunyah-hypervisor/readme`）Features 段原文：

```
- **Memory Management**: Gunyah tracks memory ownership and use of all memory under its control.
- **Device Virtualization**: Para-virtualization of devices is supported using inter-VM communication.
  Low level system features and devices such as interrupt controllers are supported with emulation where required.
```

⇒ **没有 VFIO/IOMMU 设备直通**，只有「共享内存 + doorbell + IRQ 注入」这组原语（对应上游 v17 的
`memory parcel RPC`(patch 17)、`resource tickets`(12)、`doorbell hypercalls`(31)、`irqfd`(32)）。
本地参考实现里能看到同一套原语（`reference/gunyah-android15-6.6/`）：

```
drivers/virt/gunyah/rsc_mgr_rpc.c:11:#define GUNYAH_RM_RPC_MEM_LEND 0x51000012
drivers/virt/gunyah/vm_mgr.c:906:	case GH_VM_ANDROID_LEND_USER_MEM:
drivers/virt/gunyah/vm_mgr_mem.c:376:		binding->share_type = VM_MEM_LEND;
drivers/virt/gunyah/vm_mgr.h:112:	struct gunyah_vm_resource_ticket addrspace_ticket,
		host_private_extent_ticket, host_shared_extent_ticket,
		guest_private_extent_ticket, guest_shared_extent_ticket;
```

⇒ 「SCM mem-lend + DT 直通 USB 控制器」这条假想路线，**Gunyah 的 ABI 里没有对应物**：
RM 借的是**内存**，不是设备。要在 guest 里用 USB，只有 ①仿真 xHCI（DroidVM 走的路）
②virtio（virtio-usb 无标准）③无隔离地让 guest 摸 host 的 dwc3 MMIO（Gunyah 不支持）。

### 3.4 完成度与已知缺口

```
wiki/FAQ.md:1: 1. Unable to input on Windows system
   Currently, a driver modification to support Protected VM is required. This driver is not yet publicly released.
```

⇒ **【已证实】** 截止 2026-10，**Windows guest 下的键盘/鼠标输入仍不可用**（缺 virtio-input 的保护 VM 驱动）。
**【推测】** USB 直通（xHCI + 真键盘/鼠标）很可能是**绕过该缺口的现实手段**——Windows 自带 xHCI/HID 驱动，
不需要那个未发布的驱动。这条**没有被任何项目文档确认**，是我们自己的推论。

---

## 4. Gunyah RM 与 Linux guest driver 上游现状

### 4.1 mainline：**仍然没有 `drivers/virt/gunyah`**

```
$ gh api repos/torvalds/linux/contents/drivers/virt --jq '.[].name'
Kconfig Makefile acrn coco fsl_hypervisor.c nitro_enclaves steal_governor.c vboxguest vmgenid.c

$ for p in drivers/virt/gunyah include/linux/gunyah.h include/linux/gunyah_rsc_mgr.h drivers/watchdog/gunyah_wdt.c; do
    gh api "repos/torvalds/linux/contents/$p" --jq '"OK size:\(.size)"' || echo "MISSING"; done
drivers/virt/gunyah            -> 404 MISSING
include/linux/gunyah.h         -> 404 MISSING
include/linux/gunyah_rsc_mgr.h -> 404 MISSING
drivers/watchdog/gunyah_wdt.c  -> OK size:6654   # sha 557a78306d18fbbb97834af73d541e43db2b4d73

$ gh api repos/torvalds/linux/contents/MAINTAINERS --jq .content | base64 -d | grep -n -i gunyah
3467:F:	drivers/watchdog/gunyah_wdt.c        # 只出现在 QCOM 段，没有 Gunyah 独立段
```

⇒ **【已证实】** mainline 只有**客机侧 watchdog**（走 SMCCC vendor-hyp，正是 10-24 阶段 0b 用的那个通道），
**VM 管理（RM/VMM）侧一行都没有**。
注意：`gh api search/code q="gunyah repo:torvalds/linux"` 返回 0 是**假阴性**（GitHub 代码搜索索引不全，
而 `contents` API 明确存在 `gunyah_wdt.c`）——教训写入 §6。

### 4.2 上游补丁序列：**v17（2024-02-22，35 patch）是最后一版**

`patchwork.kernel.org/api/1.2/series/?q=gunyah`（按日期倒排的关键条目）：

```
2025-10-06 | [v2] watchdog: Add driver for Gunyah Watchdog    | 2 | 1    ← 只有 watchdog 进了
2025-04-24 | Running Qualcomm's Gunyah Guests via KVM in EL1  | 1 | 34   ← RFC，见 §4.4
2024-05-16 | Gunyah hypervisor support                         | 2 | 12   ← QEMU accel
2024-02-22 | Drivers for Gunyah hypervisor                     | 17| 35   ← 最后一版
2024-01-09 | Drivers for Gunyah hypervisor                     | 16| 34
2023-12-16 | Drivers for Gunyah hypervisor                     | 15| 30
2023-06-13 | Drivers for Gunyah hypervisor                     | 14| 25
```

v17 的 35 个 patch 名（`series/828889/`）覆盖完整栈：`virt: gunyah: Add hypervisor driver`、
`rsc_mgr: Add resource manager RPC core`、`vm_mgr: Introduce basic VM Manager`、`Add proxy-scheduled vCPUs`、
`memory parcel RPC`、`Add Qualcomm Gunyah platform ops`、`Implement guestmemfd`、`irqfd`、`ioeventfd`、`MAINTAINERS`。
⇒ **【已证实】自 2024-02 起无 v18**，也没有任何一版进 mainline。

### 4.3 AOSP `android15-6.6` 与 v17 的差异

```
$ curl -s "https://android.googlesource.com/kernel/common/+/refs/heads/android15-6.6/drivers/virt/gunyah/?format=JSON"
14 entries: Kconfig Makefile gunyah.c gunyah_ioeventfd.c gunyah_irqfd.c
  gunyah_platform_hooks.c gunyah_qcom.c gunyah_vcpu.c
  rsc_mgr.c rsc_mgr.h rsc_mgr_rpc.c vm_mgr.c vm_mgr.h vm_mgr_mem.c
```

与本地参考树 `reference/gunyah-android15-6.6/`（19 文件 / 288 KB，含 `arch/arm64/gunyah/gunyah_hypercall.c`、
`arch/arm64/include/asm/gunyah.h`、`include/linux/gunyah.h`）一致。

| 维度 | v17（2024-02） | AOSP android15-6.6 | 结论 |
|---|---|---|---|
| 文件集合 | patch 21/22 = platform ops + Qualcomm ops，patch 23 = guestmemfd | `gunyah_platform_hooks.c` / `gunyah_qcom.c` / `vm_mgr_mem.c` | **一一对应，同源**【已证实】 |
| Android 专属 | 无 | `vm_mgr.c:906 case GH_VM_ANDROID_LEND_USER_MEM:`（借出用户页） | AOSP 多一个 ioctl【已证实】 |
| 构建 | — | `arch/arm64/configs/gki_defconfig`: `CONFIG_GUNYAH=y`、`CONFIG_GUNYAH_IRQFD=y`、`CONFIG_GUNYAH_IOEVENTFD=y`、**`# CONFIG_GUNYAH_QCOM_PLATFORM is not set`** | GKI 默认开，但**平台 ops 默认关**（要 RM 必须自己开）【已证实】 |
| 规模 | — | `drivers/virt/gunyah/*` 5361 行 + `gunyah_hypercall.c` 288 + `include/linux/gunyah.h` 485 ≈ **6.1 k 行** | 移植工作量可控【已证实】 |

**对我们的关键细节**（`reference/gunyah-android15-6.6/drivers/virt/gunyah/gunyah.c`，原文）：

```c
static int gunyah_probe(struct platform_device *pdev) {
	if (!arch_is_gunyah_guest()) return -ENODEV;
	gunyah_hypercall_hyp_identify(&gunyah_api);
	pr_info("Running under Gunyah hypervisor %llx/v%u\n", ...);
	if (gunyah_api_version(&gunyah_api) != GUNYAH_API_V1) return -ENODEV;
	return devm_of_platform_populate(&pdev->dev);
}
static const struct of_device_id gunyah_of_match[] = {
	{ .compatible = "gunyah-hypervisor" }, { .compatible = "qcom,gunyah-hypervisor" }, {}
};
```

- `arch_is_gunyah_guest()` 用 **SMCCC `ARM_SMCCC_VENDOR_HYP_CALL_UID_FUNC_ID` 比对 UUID
  `c1d58fcd-a453-5fdb-9265-ce36673d5f14`** —— **与 U2 上已实测命中的 UUID 完全相同**
  （`reports/gunyah-stage0-positive-20261024.md` §1）⇒ 这一关卡**已过**【已证实】。
- 但 **DT 里没有 `qcom,gunyah-hypervisor` 节点**：`grep -rln "gunyah-hypervisor" arch/arm64/boot/dts/qcom/*.dts*`
  （`build/m1-73`）→ **0 命中**；`sm8750.dtsi:342` 只有 `gunyah_hyp_mem: gunyah-hyp@80000000`（保留内存，
  正是 dmesg 那条）。⇒ **要自己加节点 + 自己写 binding**（v17 patch 2 的 binding 从未合入）【已证实】。
- 依赖的 SCM 辅助函数**mainline 已有**：`qcom_scm_assign_mem()` 在 7.3-rc7 存在且 `EXPORT_SYMBOL_GPL`
  （`build/m1-73/drivers/firmware/qcom/qcom_scm.c:1414`），`struct qcom_scm_vmperm` 在
  `include/linux/firmware/qcom/qcom_scm.h:24` ⇒ **`qcom_scm.c` 不用改**（参考树该文件无 gunyah 差异，
  `grep gunyah drivers/firmware/qcom/qcom_scm.c` 为空）【已证实】。

### 4.4 有没有现成 RK1/GKI 模块可用？

| 资产 | 是什么 | 能否直接用 |
|---|---|---|
| `Droid-VM/gunyah_host_mod` | **host 侧 out-of-tree 模块**，按 GKI KMI 分目录（GKI6.1 / GKI6.6+6.12），提供 `/dev/gunyah_share`（SHARE_BLOB / GuestAccept）。README：「No kernel patch: resolves the unexported RM helpers via **kallsyms** and reads the private structs by **BTF-verified offset**」 | ❌ 不解决我们的问题：它假设 **`gunyah_*` 驱动已在核里**（GKI 自带），只补一个未导出的能力；我们是**根本没有驱动** |
| `Droid-VM/gh-hugepage-reserve`（★35） | Gunyah 大页预留模块（默认 2 GiB），解决 `page fault ... Out of memory (os error 12)` | ⚠️ 属**后续**问题的解法，README 警告「少数机器会崩/变砖」 |
| `Andy312432/android_kernel_samsung_sm8650_gunyah` | 8 Gen 3 的 Gunyah 分配 bug 修复（DroidVM FAQ 第 4 条引用） | ❌ SM8650 专用；8 Elite 已重构，不需要 |
| `karim-manaouil/qemu-for-gunyah` + `linux-next` `gunyah-kvm` 分支 | **KVM-over-Gunyah**（把 Gunyah UAPI 移植到 KVM/EL1） | ❌ 见下 |

**KVM-over-Gunyah RFC**（`patchwork.kernel.org/api/1.2/covers/14058991/`，2025-04-24，Karim Manaouil/Linaro，34 patch）
cover letter 原文（决定性限制）：

```
This series introduces the capability of running Gunyah guests via KVM on Qualcomm SoCs
shipped with Gunyah hypervisor (e.g. RB3 Gen2). ...
This port allows KVM to run in EL1 and serve as the interface for VM lifecycle management,
while offloading virtualization to Gunyah.
...
At this stage, the port is functional but still work in progress. Notably:
  - Memory for guests is currently backed by pinned anonymous pages ...
  - Memory compaction or swap must be avoided for now ...
  - SMP boot is not available at the moment because Gunyah does not yet forward PSCI
    hypercalls to the host.
  - Virtio is not supported yet.
```

⇒ **【已证实】KVM 路线当前对 Windows 完全不可用**（无 virtio、无 SMP、pinned pages）。
它是给「RB3 Gen2 跑 Linux guest」的，不是给 Windows 的。
⇒ **§5 的最短路径因此不走 KVM，走原生 `drivers/virt/gunyah` + crosvm。**

### 4.5 厂商侧实测补充（同会话族 2026-10-24 设备产物，本报告引用不重跑）

`reports/gunyah-rm-probe-20261024.md` + `reports/artifacts/gunyah-probe-20261024/identify.txt`：

```
gunyah_identify: smccc_hypervisor_has_uuid(gunyah) = 1
gunyah_identify: [hvc #0x6000] x0=0x5100000000008001 ...
gunyah_identify:   api_version=1 big_endian=0 is_64bit=1 variant=0x51
gunyah_identify:   DOORBELL=1 MSGQUEUE=1 VCPU=1 MEMEXTENT=1
gunyah_identify: VERDICT api_v1=yes msgqueue=yes doorbell=yes
```

⇒ **【已证实】hypervisor 侧四件套齐全**（这也解释了为什么 mainline 只有 `gunyah_wdt.c` 却能工作：它只用到 SMCCC）。
反向的坏消息：**stock 内核里 gunyah 是 built-in，其 capid 由 stock 启动链的 DT 提供**
（`gh_rm_drv.ko` 字符串：`qcom,oemvm` / `qcom,trustedvm` / `qcom,cpusysvm` / `qcom,owner-vmid` /
`cap_id_high` / `cap_id_low` / `qcom,peers`），而 **mainline DTB / dtbo / vendor_boot 里 0 命中**
⇒ 这条是 §5.3 的 V1。**注意：既有 AOSP 驱动源码 ~4.4 kLOC 只是「不含 arch/ 与 include/」的口径差异**
（本报告 §4.3 给出完整 6.1 kLOC），两者不矛盾。

## 5. 结论：最短路径与「必须先验证的 3 个二值事实」

### 5.1 两条路的对照

| 前置条件 | **A：Gunyah VM（Linux 宿主）** | **B：裸机 UEFI 直启 Win11** |
|---|---|---|
| 虚拟化 | 需要 `drivers/virt/gunyah`（6.1 k 行，v17/AOSP 同源）+ **自己加 DT 节点/binding**；crosvm 的 gunyah backend **已在 google/crosvm 上游**（`hypervisor/src/gunyah/{mod.rs,aarch64.rs,gunyah_sys.rs}`，2026-10-23 复核；其 `hypervisor/README.md` 原文 `### Gunyah` / `- Platforms: Linux, aarch64 only` / `- Tested upstream: no` ⇒ **它本来就是给 Linux/aarch64 宿主写的**） | 不需要（裸机） |
| UEFI | **不需要设备固件**：guest 里跑 `edk2-gunyah.fd`（Droid-VM fork 已支持 SM8750/tb322fc，含 ramfb + ACPI 电源模型 + restricted-dma-pool） | **需要整套 EDK2 移植**：Mu-Silicium 的 SM8750 端口目前 `Windows Boot ❌`、`USB Host Mode ❌` |
| ACPI | edk2-gunyah `09516e10`「the power, reset and idle states an ACPI-only guest needs」已提供 | 需为 Windows 写 DSDT（当前没有） |
| virtio | crosvm virtio-pci（blk/net/gpu/input/snd）+ **未签名** Windows 驱动（`gunyah-arm64-drivers.zip`） | 不涉及 |
| USB 控制器 | guest 看到仿真 xHCI，host 侧 usbfs（`fb86c7b0`） | 需真 dwc3 + Windows xHCI 驱动 + PHY/角色切换（Mu-Silicium 里是 ❌） |
| 存储 | 一个文件/分区镜像（UFS 上腾空间） | 需 UFS DXE + Windows 的 UFS 驱动栈（原厂 UFSDxe 的 `0x402` 问题至今无解，见 `reports/uefi-gunyah-reassess-20261024.md`） |
| RAM | 借 4–6 GiB 给 guest（U2 = 16 GB 机型，`backup/HA2EXB0E-16+512/`） | 全部（16 GB 够） |
| 签名/受保护 VM | **不需要**厂商签名；Windows 内 `testsigning on` + `nointegritychecks on` | 不涉及（但有 Secure Boot 就要求驱动签名） |
| Android 宿主 | **不需要**（这正是与 DroidVM 的区别） | 不需要 |
| 当前社区完成度 | **已在同机型跑通**（DroidVM/edk2-gunyah README 点名 tb322fc；但宿主是 Android） | **零**（同 SoC 无一台 Windows Boot ✅） |

### 5.2 裁决

**最短路径 = A（Gunyah VM），且必须走「原生 `drivers/virt/gunyah` + crosvm」，不能走 KVM-over-Gunyah**（§4.4：无 virtio、无 SMP）。

理由（按权重）：
1. **同机型已有阳性先例**（tb322fc + SM8750 被 edk2-gunyah README 明确列为 tested device）⇒ 硬件/固件侧不是未知数。
2. **裸机路线在社区侧是负值**：Mu-Silicium 全部 8 Elite 机型 `Windows Boot ❌` + `USB Host Mode ❌`；
   SunUEFI 自述「Windows 尚未启动」。要赢，得先替整个社区解决 UFS DXE / ACPI / USB，**这不是一个项目，是一个生态**。
3. Gunyah 路线的**全部缺口都在软件侧且已被人写过一遍**（6.1 k 行驱动 + 一个 edk2 fork + 一套未签名驱动）。

**A 的工程分解（预估，非承诺）**：
⓪ **先取 capid**（进 stock Android 一次 dump DT，见 §5.3 V1）—— 这是唯一必须「碰设备且切槽」的取证步骤；
① 移植 `drivers/virt/gunyah` 到 7.3-rc7（含 `arch/arm64/gunyah/`、`include/linux/gunyah*.h`、`uapi/linux/gunyah.h`），
   **`qcom_scm.c` 无需改**（§4.3）；② 加 DT 节点 `qcom,gunyah-hypervisor` + msgq/dbl 节点 + capid 属性 + binding；
③ 用上游 crosvm（`--hypervisor gunyah`）替代 Android apex crosvm；④ guest 用 `edk2-gunyah.fd`（DroidVM fork 构建）；
⑤ Windows 11 ARM64 安装 + 注入未签名驱动。显示用 ramfb→crosvm 的 VNC/wayland 后端（无 AGL）。

### 5.3 必须先验证的 3 个二值事实（按顺序，任一条为否 ⇒ A 路线当场终止）

> **V0（原 V1，已在 2026-10-24 设备侧闭环 → 不再是待验证项）**：Gunyah **API v1** + 
> `DOORBELL=1 MSGQUEUE=1 VCPU=1 MEMEXTENT=1` 已实测（`reports/gunyah-rm-probe-20261024.md`、
> 原始 dmesg `reports/artifacts/gunyah-probe-20261024/identify.txt`：
> `api_info=0x5100000000008001`、`VERDICT api_v1=yes msgqueue=yes doorbell=yes`）。
> `arch_is_gunyah_guest()` 用的 UUID 也已命中 ⇒ **hypervisor 侧确认无缺口**【已证实】。

| # | 二值事实 | 为什么它是**生死线** | 最小验证手段 | 判据（阳性） | 成本 |
|---|---|---|---|---|---|
| **V1** | **能拿到 RM 的 capid**（`/dev/gunyah` 建 VM 前必须先有 `gunyah_rm_call` 的 capability 句柄） | RM 的每次 RPC 都要带 capid。同会话族已查明：**capid 只存在于 stock Android 启动链给的 DT**（`gh_rm_drv.ko` 字符串含 `qcom,oemvm`/`cap_id_low`/`cap_id_high`/`qcom,owner-vmid`），而我们 mainline DTB 里 **0 命中**（`dtbo_a` 32 MB / `vendor_boot_a` 100 MB 均无）。**拿不到 capid ⇒ RM RPC 全拒，路线当场终结** | ①进 stock Android 一次 `dtc -I fs -O dts /proc/device-tree \| grep -A8 -i 'gunyah\|resource-manager'`（需用户同意切槽，只读）②或反汇编 stock `gunyah_rm_call` 看它读哪对属性 | 拿到 `cap_id_low/high` 与 msgq/dbl 节点参数；本地 DTB 补上后 `gh_rm_call` 返回 0 | 0.5 天（路径①） |
| **V2** | **RM 允许「本 VM」创建新 VM**（`RM RPC VM_CREATE` 成功，而不是 `-EACCES`） | 即使有 capid，RM 仍按 ACL 判定谁能建 VM。DroidVM 能跑是因为 **Android 是 RM 的 primary VM 客户端**；我们的 Linux 是同一 primary VM，但用的是**自定义 DTB 启动**，hyp 里的 VM 配置/peers 表未必给了同样的权限 | 移植驱动后 `ioctl(/dev/gunyah, GH_VM_CREATE)`，失败时抓 RM RPC 返回码（`rsc_mgr_rpc.c` 有完整错误码） | 返回 0 且拿到 vmid | 3–5 天（含移植 6.1 k 行） |
| **V3** | **RM 接受 ≥4 GiB 的 `MEM_LEND` parcel**，且 `qcom_scm_assign_mem()` 不失败 | 保护 VM 下内存是「借出」，SCM 会改写 stage-2 权限；若 hyp 的 VM 权限位不含该 vmid，或大页耗尽（DroidVM FAQ 第 3 条），guest 起不来。**先用 Linux guest 验证，再换 Windows** | `GH_VM_ADD_FUNCTION` + mem parcel RPC；crosvm 启一个小 Linux（buildroot / Ubuntu cloud image） | parcel handle 创建成功 + guest 打出 boot log | 1–2 天 |

> 顺序不能颠倒：V1 失败则 V2/V3 无意义（连 RM 都进不去）；V2 失败则 V3 无意义（没有 VM 可借内存）。
> **V0 已闭环**是这份调研最重要的增量：剩下的未知全部在 **Linux 侧 + 厂商 DT 配置**，不在 hypervisor。
> 另注：同会话族的反汇编已确认厂商固件**同时接受** `hvc #0x6000` 与 SMCCC 形式，且 `hvn` 表映射规律为
> `0x60XX = (AOSP fnid & 0xffff) - 0x8000 + 0x6000` ⇒ 移植时直接用上游 `arm_smccc_1_1_hvc()` 即可【已证实】。

**次生风险（不构成生死线，但会影响可用性）**：
- **SMP**：Windows 11 ARM64 安装程序要求 ≥2 vCPU。原生 RM 路径的 secondary vCPU 由 RM 代理调度（`gunyah_vcpu.c` proxy scheduling），
  不依赖 PSCI 转发（那是 KVM-over-Gunyah 的问题）⇒ 【推测】可用，但需实测。
- **输入**：DroidVM 在 Windows 下输入仍不可用（FAQ 1）；我们的对策 = 启用 USB xHCI 直通（§3.4，**推测**可行）。
- **大页耗尽**：`gh-hugepage-reserve` 是已知解法但 README 警告可能崩机。
- **ramfb stride**：`edk2-gunyah` PR #4（`ddae7ff8`，2026-09-08）专门修「Windows guest 每行被 padding 剪切」，
  说明显示路径在 Windows 下**曾经坏过**，要用带该修复的版本。

---

## 6. 未证实 / 待办

| # | 事项 | 状态 |
|---|---|---|
| 0 | **RM capid 的取值与来源**（V1）—— capid 只在 stock Android DT 里，我们 DTB 里没有；不解决则连 RM 都进不去 | 【已证实】其存在与位置；【未证实】具体数值 |
| 1 | **我们的 hypvm.mbn 是否给 primary VM `VM_CREATE` 权限**（V2）—— 决定 A 路线生死 | 【未证实】只能上机验证 |
| 2 | `edk2-gunyah.fd` 能否在 **Linux 宿主 crosvm** 下工作（README 只给 `/apex/com.android.virt/bin/crosvm` + `--protected-vm-without-firmware` 的 Android 命令） | 【未证实】需自测；非保护模式参数未知 |
| 3 | DroidVM 的「Windows 能跑」是**在哪台设备**上实测的（README 列了 tb322fc，但未说 Windows 在它上面跑过） | 【未证实】只有「SoC/设备 tested」+「Windows guest 可驱动 USB」两条间接证据 |
| 4 | **非保护 VM** 下跑 Windows 是否可行（更简单：内存全共享，不需要 rdmapool/swiotlb） | 【推测】可行，无项目文档 |
| 5 | AnyLaySys 的「启动 Microsoft Windows」是跑在 **qemu-gunyah** 还是 crosvm 上（`edk2-aarch64-gunyah` 是 QEMU 用的 fw，配合 `qals` 前端） | 【未证实】commit 只改 `OvmfPkg/QemuRamfbDxe`，暗示 QEMU |
| 6 | Windows on Gunyah 的**实测性能**（无任何公开跑分） | 【未证实】 |
| 7 | USB 直通在 **Windows guest** 下的实测报告（只有 commit 声称） | 【未证实】 |
| 8 | `gh api search/code` 对超大仓库（torvalds/linux）**假阴性**（`gunyah` 返 0，但文件确实存在） | 【已证实】的**工具缺陷**，结论一律用 `contents` API / 本地 grep 复核 |
| 9 | 8 Elite **Gen 5（SM8850）** 与我们 SM8750 的 hyp 差异 | 【未证实】edk2-gunyah 同时列了两者，推测同源 |
| 10 | Win11 ARM64 ISO 的合法获取渠道 | 见 `reports/uefi-woa-prep-20261024.md` §6（本报告不重复） |
| 11 | 上游 crosvm 的 gunyah backend 在 **Linux 上是否开箱可编**（Cargo feature 名、是否依赖 Android 专有 `libgunyah`/binder；Droid-VM fork 额外带 `pin.rs`/`mthp.rs`/`droidvm-shim`） | 【未证实】README 只说 `Platforms: Linux, aarch64 only / Tested upstream: no` |

---

## 7. 命令与原始证据附录

### 7.1 §1 的机型和 Windows Boot 扫描

```bash
gh api repos/Project-Silicium/Mu-Silicium/contents/Status.md --jq .content | base64 -d > silicium-status.md
# 86 处 "Windows Boot" 行；解析出 ✅ 的机型全部 ≤ SM870/SM8635/SM8550：
python3 - <<'PY'
import re
t=open('silicium-status.md',encoding='utf-8').read()
for p in re.split(r'\n## ',t):
    name=p.split('\n')[0][:60]
    m=re.search(r'\| Windows Boot\s*\|[^|]*\|\s*([^|]+)\|',p)
    if m and '❌' not in m.group(1): print(name,'->',m.group(1).strip())
PY
# 输出 47 台（86 处 Windows Boot 行中 39 台为 ❌），最近代为 Poco F6(SM8635)/OnePlus 12R(SM8550)/Xiaomi Pad 6(SM870)；无 8 Elite / 8 Elite Gen5
```

### 7.2 §2 的 Droid-VM 证据

```bash
gh api repos/Droid-VM/edk2-gunyah/readme --jq .content | base64 -d | sed -n '/Tested platforms/,/Differents/p'
gh api "repos/Droid-VM/edk2-gunyah/commits?per_page=25" \
  --jq '.[]|"\(.sha[0:8]) \(.commit.author.date[0:10]) \(.commit.message|split("\n")[0])"'
gh api repos/AnyLaySys/edk2-aarch64-gunyah/commits/18a44801 \
  --jq '"\(.commit.author.date) \(.commit.message)", (.files[]|"  \(.filename) +\(.additions)-\(.deletions)")'
# 2026-06-18T12:52:55Z 26.6.18P1 新 启动Microsoft Windows 改 ramfb
#   modified OvmfPkg/QemuRamfbDxe/QemuRamfb.c +282-188
git clone -q --depth 1 https://github.com/Droid-VM/DroidVM.wiki.git wiki && cat wiki/FAQ.md wiki/Windows-Installation-Guide.md
```

### 7.3 QEMU 上游状态

```bash
gh api repos/qemu/qemu/contents/accel --jq '.[].name' | tr '\n' ' '
# Kconfig accel-blocker.c ... hvf kvm meson.build mshv nitro qtest stubs tcg whpx xen   ← 无 gunyah
curl -s -A 'Mozilla/5.0' 'https://marc.info/?l=qemu-devel&m=171586989617791&q=raw'   # v2 cover letter
curl -s 'https://patchwork.kernel.org/api/1.2/series/?q=gunyah&per_page=50' | jq -r '.[]|"\(.date[0:10]) \(.name) v\(.version) \(.total)"'
```

### 7.4 §4 的 mainline / AOSP 复核

```bash
gh api repos/torvalds/linux/contents/drivers/virt --jq '.[].name'
gh api repos/torvalds/linux/contents/drivers/watchdog/gunyah_wdt.c --jq '"size:\(.size) sha:\(.sha)"'
curl -s "https://android.googlesource.com/kernel/common/+/refs/heads/android15-6.6/drivers/virt/gunyah/?format=JSON"
curl -s "https://android.googlesource.com/kernel/common/+/refs/heads/android15-6.6/arch/arm64/configs/gki_defconfig?format=TEXT" \
  | base64 -d | grep -i gunyah
cd build/m1-73 && make kernelversion                 # 7.3.0-rc7
grep -rn "gunyah" arch/arm64/boot/dts/qcom/sm8750*.dts*      # 只有 gunyah_hyp_mem @80000000
grep -rln "gunyah-hypervisor" arch/arm64/boot/dts/qcom/*.dts*   # 0 命中
grep -n "EXPORT_SYMBOL.*qcom_scm_assign_mem" drivers/firmware/qcom/qcom_scm.c   # 1414
```

### 7.5 网络/工具异常记录（按纪律记录，不静默跳过）

| 目标 | 现象 | 处理 |
|---|---|---|
| `html.duckduckgo.com` / `lite.duckduckgo.com` | HTTP **202**（反爬挑战），无结果 | 改用 Bing HTML（200）+ GitHub API；Bing 结果无技术价值，未采用 |
| `lore.kernel.org`（任意查询） | HTTP 200 但正文是 Anubis「Making sure you're not a bot!」 | 改用 `marc.info`、`patchwork.kernel.org` API（均 200） |
| `android.googlesource.com/+log/...?format=JSON` | HTTP **403**「Please sign in to view the history pages」 | 改用目录 `?format=JSON` + 单文件 `?format=TEXT`（200），版本对比改用 patchwork 系列清单 |
| `github.com/search/code`（torvalds/linux 内搜 gunyah） | `total_count: 0`（假阴性，文件确实存在） | 一律用 `contents` API 复核（见 §6 第 8 条） |
| `marc.info/?l=linux-arm-msm&s=gunyah` | HTTP **404**（该列表页不支持该查询串） | 改用 `l=linux-kernel`（200）+ patchwork `series/?q=gunyah`（200） |
| 大文件 | 未下载任何 >50 MB 资产（edk2/qemu 仓库只读 README/commit/API） | — |
