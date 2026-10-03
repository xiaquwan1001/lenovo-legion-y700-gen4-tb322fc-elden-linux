# ARM / 高通虚拟化生态调研 — 5 个新动向深挖

> **任务**：2026-10-02，**只调查、不实践**（未刷机、未装包、未改设备）。
> **性质**：文献 + 仓库/源码 + 本机只读事实的交叉核对；承接 `EL2-VIRT-2026-10-02.md`。
> **一句话结论**：这 5 个来源分成**两条互不相干的线** ——
> ① **Linux 桌面线**（denial + droidloom）：在**主线 Linux**上把 Android 应用当原生窗口跑，是 Waydroid 的另一种形态；ARM64 仍未打包。
> ② **Android 虚拟化线**（DroidVM + AOSP custom_vm + lfdevs 讨论）：在**宿主 Android**上经 Gunyah/GenieZone/KVM 跑真 VM。**这条线正好接上本机结论**——本机 EL2 已被签名 Gunyah 占死、主线 Linux 拿不到 KVM，而 Android 侧的 `/dev/gunyah` 是现成的。**DroidVM 官方推荐 SoC 就是 SM8750/8 Elite = 本机 Y700 四代**，且 polygraphene 指南的环境就是本机。
> **本机现状**：stock Android 内核带 `hvc_gunyah.ko`、DT 有 `gunyah-hyp`/`pvmfw` 保留内存（`EL2-VIRT` §2.3）→ 宿主 Android 具备跑 VM 的硬件条件；缺的只是"用户态工具 + 权限"。

---

## 0. 结论先行（对照本机 TB322FC / SM8750P）

| 路线 | 载体 | 本机可行性 | 卡点 |
|---|---|---|---|
| 主线 Linux 内核 KVM | slot a mainline | ❌ 不可行 | EL2 归 Gunyah，见 `EL2-VIRT` |
| 主线 Linux 跑 Gunyah guest | slot a mainline | ⚠️ 高工作量 | 需移植**下游 gunyah 主 VM 驱动**（本树没有）+ 编 crosvm |
| **宿主 Android 跑 VM** | slot b stock Android | ✅ **现成路线** | 需 root（本机已有 KSU）；用 DroidVM/crosvm |
| 宿主 Android 无 root 跑 VM | slot b stock Android | ⚠️ 部分 | Podroid/TerminalAppPlus 靠 AVF 权限；Gunyah 非 pKVM，兼容性待验 |
| droidloom 原生 Android 窗口 | slot a mainline | ⚠️ 中高工作量 | ARM64 未打包；需 Denial 合成器；依赖匹配的 Android arm64 镜像 |
| denial 作为桌面合成器 | slot a mainline | ✅ 可试 | 需 ARM64 交叉编 Flutter engine（文档齐全但重） |

**推荐优先级（仅建议，未执行）**：宿主 Android + DroidVM > denial 作桌面壳 > droidloom > 主线 Gunyah 驱动移植。

---

## 1. denial — Wayland 合成器（denialwm/denial）

- **定位**：Rust + Smithay 做 Wayland/输入/显示，**Flutter 画 shell 与应用窗口**；自带设置、stacking/tiling/scrolling 布局、workspace、触控板手势、blur/glass、亮暗主题、Xwayland。
- **许可**：GPL-3.0-or-later；public beta。
- **平台**：一等二进制目前仅 **x86-64**；**ARM64 从源码构建有完整文档**（`CROSS_BUILDING.md`：交叉编 Flutter engine → shell AOT → Rust compositor → 打包）。已在 StarryOS kernel 上跑过（猎奇）。
- **与本机关系**：本机 mainline Linux 现在跑 Phosh/phoc。Denial 理论上可作替代桌面壳；但需要 aarch64 sysroot + Flutter depot_tools，工作量中等。**它本身不是虚拟化方案**，是 droidloom 的显示底座。

## 2. droidloom — 在 Linux Wayland 窗口里跑原生 Android 应用（denialwm/droidloom）

- **定位**：**共享内核隔离，不是 VM**。一个 Linux 用户对应一个 Android userspace（Bionic/ART/Binder/Zygote/system_server 全用原生）。特权 supervisor 建 namespace/挂镜像/网络；桌面 presenter + 应用目录以普通用户跑。
- **显示路径**：每个 Android task → 一个普通 Wayland `xdg_toplevel`；Android Composer 与 Rust bridge 经私有 Unix socket 交换 task buffer/lifecycle/input；DMA-BUF + 显式同步；Denial 直接采样 Android buffer（去掉 SurfaceFlinger 中间合成）。有大量帧时序/释放/CPU 放置（cgroup/cpuset）工程细节。
- **构建**：`droidloom-package` 在 rootless Arch Podman 里编 Android 组件 + 打包 pacman。**统一打包仅 x86_64**；`tools/` 里有 **ARM64 specialist 流程**，测试机是 **Moto Edge 70（ARM64, `roadstr`）**，但官方明确写 **"unified ARM64 packaging is not established"**。
- **ARM64 转译**：含自研 **Digitalis/Berberis（ARM64→x86_64 NativeBridge）**，让 ARM-only APK 在 x86_64 桌面跑；`KNOWN_ISSUES` 详列 FP16/FPCR/FRINT/ptrace-BRK 等修复，说明还在攻坚期。
- **许可**：GPL-3.0-or-later。
- **与本机关系**：它是 **Waydroid 的替代思路**——但 Waydroid 用 LXC 容器跑 Android 镜像，droidloom 直接复用 Android userspace + 私有 Composer 协议。本机 Waydroid 已投产（Mesa 26.1.8 修好 A830）；droidloom 要落地需要：(a) denial 合成器、(b) 匹配的 Android arm64 基础镜像 + 重编组件、(c) 自建 ARM64 打包。**当前不具备即插即用条件**。

## 3. DroidVM — 宿主 Android 上的 VM 管理器（Droid-VM/DroidVM）★最相关

- **定位**：Android App，**多 hypervisor 后端**：Qualcomm **Gunyah**（`/dev/gunyah`）、MediaTek **GenieZone**（`/dev/gzvm`）、**Linux KVM**（`/dev/kvm`）。
- **VMM**：**crosvm** 与 **QEMU** 两种；UEFI 启动 Linux/Windows；GPU：VirGL / GfxStream / 2D 软渲；内置 VNC；外接屏投屏（Presentation API）；Termux 终端库做控制台；磁盘 raw/qcow2 管理（resize/convert/clone/optimize）；虚拟桥接网（NAT/DHCP/STP/IPv4/v6）；VirtFS(9p) 共享目录；Linux agent、Windows 改版 VirtIO 驱动。
- **要求**：Android 13+ / **root**；**Qualcomm SM8650 起，明确推荐 SM8750（8 Elite）**；MediaTek D9000+；或 EL2 + KVM 的其他 arm64。
- **许可**：GPL-3.0。最新 release `0.0.6`（2026-04）+ 滚动 `dev`（APK）。
- **Wiki 已知坑（对本机直接有用）**：
  - **OOM**（`failed to initialize virtual machine Out of memory os error 12`）：Android 默认 locked-memory rlimit 仅 64 kB → 跑前须 `ulimit -l unlimited`；或用其**预分配模块**（默认留 2 GiB，警告少数机型可能崩/砖）。
  - **SWIOTLB**：protected VM 必须有 restricted DMA pool，内核需 `CONFIG_DMA_RESTRICT_POOL`；Alpine/Debian 云镜像常缺 → 用它内置内核或重编。
  - **Gunyah RM 拒绝**（`RM rejected message 51000015` / `No such device`）：8 Gen 3 内核 Gunyah 内存分配缺陷（8E 已重构修好）→ 试切换 **Prepare Lend mTHP** 选项；SM8650 有专门补丁。
  - **Windows**：需 `gunyah-guest-drivers-windows`（`rdmapool.sys` 用 restricted DMA pool 做 bounce；viostor/NetKVM/vioinput/viosnd 全走池）；BCD 需 `testsigning on` + `nointegritychecks on`。
- **与本机关系**：**本机 SM8750P 正是推荐档**；stock Android 已有 gunyah 驱动/DT（`EL2-VIRT` §2.3）。唯一门槛是"装 APK + 给 root"。**这是把 `EL2-VIRT` §6 的"Gunyah-guest"从"数天到数周"降到"数小时"的现成封装**——因为它在 **Android 侧**、不用碰 mainline gunyah 驱动移植。

## 4. AOSP `custom_vm.md` — AVF 自定义 VM 的底层契约

- **headless VM**：root 机 `cat vm_config.json | adb push` → `/apex/com.android.virt/bin/vm run ...`。其它子命令 `vm help`。
- **JSON 关键字段**：`kernel` / `initrd` / `params`；`disks[]`（image/partitions/writable）；`memory_mib`；`protected`；`cpu_topology: match_host`；`platform_version`；`debuggable`；`console_out`/`connect_console`/`console_input_device`（Debian 用 `ttyS0`、ChromiumOS 用 `hvc0`）；`network`；`input{...}`；`audio{speaker,microphone}`；`gpu{backend:"virglrenderer",context_types:["virgl2"]}`；`display{refresh_rate,scale}`。
- **流程**：Debian（resize 后 tar 保持稀疏 → push → 配置 → VmLauncherApp）；ChromiumOS 图形 VM（ferrochrome）。权限 `USE_CUSTOM_VIRTUAL_MACHINE`；控制台 `vm console`，日志在 vmlauncher files。
- **与本机关系**：这是 DroidVM/TerminalAppPlus 底下真正调用的契约。**注意**：`gpu.backend=virglrenderer` 是 AVF 官方支持的图形后端；polygraphene 在 SM8750 上实测 crosvm `virtio_gpu` **未通**（2025-06），后来 DroidVM 声称有 VirGL/GfxStream —— 图形加速仍是这套栈最不确定的一环。

## 5. lfdevs 讨论 #2 — 无 root 经 vsock 进 VM（及其衍生项目）

- **主题**：`adb forward tcp:22222 vsock:<CID>:22`，VM 内 `socat VSOCK-LISTEN:22,fork TCP:127.0.0.1:22`（或 systemd `ListenStream=vsock::22`）→ 宿主机 `ssh root@localhost -p22222`。CID 从 `/apex/com.android.virt/bin/vm list` 取。
- **实测坑**：无 root 可行，但**流量稍大即降为 0 / 卡死**，降 MTU/限流无解；作者建议看 `gvisor-tap-vsock`。
- **衍生项目**：
  - **Podroid（ExTV/Podroid）**：**无 root**，仅 `pm grant` 两个 AVF 权限即可调 AVF 后端；默认 Alpine + 自定义内核，预装 Podman/Docker/LXC，自带 xterm 终端 + X11 桌面 + USB 透传 + SSH + 端口转发；**也支持纯 QEMU 后端**。作者称 AVF 后端用于 "supported pKVM devices"。
  - **TerminalAppPlus（KawaiiHachimi）**：AOSP 17 TerminalApp 魔改，普通 APK（Shizuku/adb 授权），支持自定义 `vm_config.json`、U-Boot 启动、串口控制台、qcow2 导入、ttyd、**KMS 画面采集**（绕开受 SELinux 限制的显示 Binder）、cloud-init、镜像 resize；**无 3D 加速**。验证机是 **MT6991/GenieZone/Android 17**，并说明"API 37 不保证所有厂商 AVF 实现兼容"。
- **与本机关系**：本机是 Gunyah（非 pKVM）。Podroid 的 AVF 后端在 Gunyah 上的可用性未知（但 QEMU 后端不挑硬件）；TerminalAppPlus 的 KMS 采集绕 SELinux 的思路（**本机 ROM 的 VM 显示 Binder 也大概率被 SELinux 限给系统应用**）值得借鉴。

---

## 6. 交叉分析：这些动向如何拼到本机

1. **宿主机 Android 是唯一"现成"的虚拟化载体**。本机 EL2 归 Gunyah（`EL2-VIRT`），主线 Linux 要跑 VM 必须移植未 upstream 的 gunyah 主 VM 驱动——而 `stock-src/` 里**连 `drivers/virt/gunyah` 都没有**（本工作树仅 1670 个文件、`drivers/` 只有 gpu/mmc），移植成本更高。DroidVM 把这条路整个搬到 Android 侧，绕开了该缺口。
2. **8 Elite 的"免 pvmfw"红利**：polygraphene 指出 **8 Elite 支持 `--protected-vm-without-firmware`**，无需按 pvmfw 要求对 guest 内核做 avbtool 签名；8 Gen 2/3 才必须走 `--protected-vm`+pvmfw。本机是 8 Elite → 更省事。（附注：Y700 的 pvmfw 内嵌 AOSP testkey，公钥 sha1 `2597c218`，与本机 boot AVB key 相同——见 `SUSFS-KERNEL`/`EL2-VIRT`。）
3. **图形加速是最不确定项**：AVF 契约支持 virglrenderer，但 SM8750 上 crosvm virtio_gpu 实测未通；DroidVM 声称 VirGL/GfxStream。若目标是"VM 里跑 Linux 桌面/GUI"，需实测。
4. **denial/droidloom 桌面线是另一件事**：denial/droidloom 想在 mainline Linux 桌面上**原生**跑 Android 应用，与本机已投产的 Waydroid 目标重叠。droidloom 的 ARM64 未打包，短期不如 Waydroid 成熟；但它的 SurfaceFlinger 直采 + Denial 合成思路，若 Denial ARM64 先跑起来，可作为 Waydroid 的替代/补充实验。
5. **无 root 方案（Podroid/TerminalAppPlus）与本机 root 现状**：本机 Android 已 root（KSU/SUSFS），直接走 DroidVM 的 root 路线最省事；无 root 方案的意义主要在于"不触发环境检测/不动系统"。

## 7. 待验证（只读，未执行；供后续决策）

- stock Android 上只读确认：`ls /dev/gunyah`、`ls /apex/com.android.virt/bin/{vm,crosvm}`、`getprop` AVF 相关、`vm list`（需 root）。
- Y700 的 pvmfw 是否接受 `--protected-vm-without-firmware`（polygraphene 在 8 Elite 上成功，本机同 SoC，概率高）。
- DroidVM 在本机 ROM 的 SELinux 下是否需额外 `magiskpolicy`（polygraphene 给 `vm` 命令加过 `allow virtualizationservice ... setrlimit`）。
- 本机 `/data` 211G 充裕，可容纳多个 qcow2/raw 镜像（DroidVM/Podroid 共用同一磁盘池的规划）。
- 主线 Gunyah 驱动移植的**真实工作量**：需从 `OnePlusOSS/android_kernel_oneplus_sm8750`（或联想完整树）取 `drivers/virt/gunyah/`，评估与 mainline 7.2.0 的 API 差异。

## 8. 引用

1. denial — https://github.com/denialwm/denial （README、CROSS_BUILDING.md）
2. droidloom — https://github.com/denialwm/droidloom （README、docs/architecture.md、KNOWN_ISSUES.md、AGENTS.md、desktop-integration.md）
3. DroidVM — https://github.com/Droid-VM/DroidVM （README、Wiki FAQ/4 个问题页、gunyah-guest-drivers-windows）
4. AOSP AVF custom VM — packages/modules/Virtualization/docs/custom_vm.md（android15-qpr1-release）
5. lfdevs 讨论 #2 — https://github.com/lfdevs/run-linux-on-android-guide/discussions/2 ；衍生：ExTV/Podroid、KawaiiHachimi/TerminalAppPlus
6. 本机前作 — `EL2-VIRT-2026-10-02.md`；polygraphene/gunyah-on-sd-guide（环境=本机 Y700 gen4/SM8750）

---

## 9. 结合本地研发流程与现有资源

> 本节把上面 5 个来源**落到本项目**：现有流程约束、我们手里已有什么、缺什么、怎么接入任务制。
> 全部为**只读核查**（host 侧提取/字符串/文档），未上机、未改任何分区。

### 9.1 本地研发流程速览（可套用点）

| 流程特征 | 内容 | 与本文的交点 |
|---|---|---|
| **双槽双系统** | `b` 槽 = mainline Linux（项目主战场），`a` 槽 = **stock Android，安全网**；`BRINGUP-UNIT` 明写「**全程不动 a 槽**」 | VM 路线正好落在 **a 槽 Android**（不动 b），与现有隔离策略天然一致 |
| **任务制 + 子代理 swarm** | task-1…13，harness 9878；「worker 自报成功不可信，编排者**独立复跑**」 | VM 路线可拆成 task-14…，用同一套 spawn/验收纪律 |
| **A 轨 / B 轨** | A=主机可做（不碰设备），B=需上机 | 本轮调研天然是 A 轨；guest 镜像/kernel 预置也全是 A 轨 |
| **文档先行 + INDEX** | 每任务一 MD、`INDEX.md` 登记、复盘；脚本幂等可回退 | 本文即 A 轨产物，已登记 INDEX |
| **资源分层 F0–F5** | F0 引导 / F1 持久 root / F5 内核迭代回路是地基；A/B/C 轨独立 | **D 轨（Android 虚拟化）与 F0–F5 解耦**，唯一依赖 = a 槽 Android 完好 + root |
| **只读探针纪律** | `scripts/gpt-dump.sh`、`serial-run.sh`、SSH `192.168.7.1`、OOB `ttyACM1` | 设备侧验证沿用；`vm info` / `vm list` 可做只读探针 |

### 9.2 现有资源 → 五来源的映射（**关键：核心资产我们已握有**）

**本机 ROM 的 AVF 栈已离线提取成功。** 证据：`/mnt/Samsung/l2/system_a.pristine.img` 经 `debugfs`（无需 sudo）确认是**我们自己的 stock ROM**（`TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`, **Android 16**），其 `/system/apex/com.android.virt.apex`（87.8 MB）内含：

| 来源所需 | 本地已有 | 证据 |
|---|---|---|
| **Gunyah crosvm** | `bin/crosvm`（10.7 MB，Rust 1.83 / Android 16 构建） | `strings` 出 `external/crosvm/hypervisor/src/gunyah/{aarch64,mod}.rs`、`HypervisorKind::{Gunyah,Kvm,Geniezone}`、`qcom_trusted_vm_id/pas_id`、`Gunyah failed to reclaim` |
| **AVF `vm` 工具** | `bin/vm`（1.2 MB） | 子命令 `run` / `run-microdroid` / `run-app` / `console` / `list` / `info` / `create-partition` / `create-idsig`；VmConfig 字段 `kernel/initrd/params/bootloader/disks/protected/memory_mib/cpu_topology/devices/usb_config` |
| **guest 内核/initrd** | `etc/fs/microdroid_kernel`（12.2 MB，`Linux 6.6.77-android15-8`）、`microdroid_initrd_{normal,debuggable}.img` | debugfs dump |
| **U-Boot 启动** | `etc/u-boot.bin`（719 KB） | 同上（对应 TerminalAppPlus 的 U-Boot 路径） |
| **pvmfw** | `~/下载/tb322fc/imagefv.elf` + `pvmfw_a/b` 分区 | `EL2-VIRT` §3；8 Elite 可 `--protected-vm-without-firmware` 免签 |
| **AVF 服务** | `virtualizationservice` / `virtmgr` / `early_virtmgr` / `vmnic` / `fd_server` / `vfio_handler` | 同 apex |
| **内核构建链** | 交叉 `aarch64-linux-gnu-gcc 15.2`、`tools/venv-avb` 里的 avbtool、自编内核流程（`build-kernel.sh`/`build-boot.sh`） | `HANDOFF` §2；可编 guest 内核 |
| **AOSP 参考树** | `/mnt/Samsung/waydroid-build`（Lineage **20.0 / AOSP 13**） | ⚠️ 其 `external/crosvm` **只有 KVM，无 Gunyah**（grep 无命中）→ **不能直接搬**，仅作参考；主机 `qemu-img`/`virt-resize`/`pycryptodome` **未装** |

> 结论：**DroidVM/Podroid 只是 APK 封装**；底层 `crosvm`+`vm` 我们**不必下载**（polygraphene 才需要从 Release 取 `crosvm-a16`）。我们要补的只是 **guest rootfs / guest 内核 / 磁盘工具**。

### 9.3 差距清单（A 轨可补 vs 需设备）

| 缺口 | 性质 | 现成程度 |
|---|---|---|
| Debian/Ubuntu cloud rootfs（~600 MB–2 GB） | A 轨（下载） | 有 `net-egress.sh`（教育网 107 MB/s）、USTC 镜像；可下 `cloud.debian.org` nocloud arm64 |
| 能跑 Debian 且带 `CONFIG_DMA_RESTRICT_POOL` 的 **guest 内核** | A 轨（编译） | microdroid_defconfig 思路 + polygraphene `build-linux.sh`；交叉链已有 |
| `qemu-img`/`virt-resize`（镜像转换/扩容） | A 轨（apt 或纯 dd） | 未装；`vm` 工具也能 `create-partition` |
| root（DroidVM 硬要求） | 设备 | **旧机 a 槽已有 KSU**；新机 a 槽是否 root 待定（`PLAN-NODEV` B8 可选） |
| `ulimit -l unlimited` + 可能 `magiskpolicy`(setrlimit) | 设备 | polygraphene 已给命令；VM 启动前一条命令 |
| guest 图形（VirGL/GfxStream） | 设备 | ROM crosvm 含 `gpu` 后端；SM8750 实测未通，属最不确定项 |

### 9.4 建议：新建「D 轨 — 宿主 Android 虚拟化」并纳入任务制

> ⚠️ **v2 注解（2026-10-02）**：本节“D 轨”已更名 **G2-S2**，task-14/15 → **T5**、task-16/17 → **T6**；
> 且**不绑定到“旧机”**——它跟的是「**处于 stock Android + root 状态的单元**」（见 `DEVICE.md` §2、`ANDROID-COMPAT.md` §2）。
> 技术内容（资产、契约、坑、验收纪律）仍然有效。

- **定位**：与 A/B/C 轨并列的**独立轨**，不依赖 F0–F5，也不动 b 槽；只在 a 槽 stock Android 上操作。
- **载体二选一**：① **手动** `adb root` + `/apex/com.android.virt/bin/vm run <config>`（AOSP `custom_vm.md` 契约，最可控，利于沉淀文档/脚本）；② **DroidVM APK**（图形化 + 磁盘/网络管理，最省事）。建议**先走①做一次最小验证**，再决定是否引入②做日常使用。
- **可拆的任务（示例，需你拍板后派）**：
  - **task-14**：宿主 Android AVF 只读勘察（`vm info`、`getprop ro.boot.hypervisor.*`、`ls /dev/gunyah`）——零风险。
  - **task-15**：最小 headless VM（microdroid_kernel + microdroid initrd + `vm console`）——验证 Gunyah 通路。
  - **task-16**：Debian guest（自编 SWIOTLB 内核 + rootfs + `vm run` 配置）——对应 `custom_vm.md` 「Running Debian」。
  - **task-17**：DroidVM APK 实测（Linux/Windows、GPU 后端、OOM/RM 坑）——对照社区。
- **验收纪律照旧**：worker 只报「命令+原始日志」，编排者独立复跑；每条改动留回退。

### 9.5 与现有相关工作的关系（避免重复劳动）

| 已有工作 | 与 VM 路线的关系 |
|---|---|
| **Waydroid（已投产，Mesa 26.1.8）** | 宿主 = **b 槽 mainline**，容器跑 Android 应用；droidloom 是它的替代形态，**D 轨不替代它** |
| **task-10 Win-x86（Box64+Wine，已 PoC）** | 在 **b 槽 mainline 用户态**跑 x86 Win 程序；DroidVM 是 **a 槽 Android 上跑 Windows ARM64 VM**——两条不同路线，可并列比较 |
| **mainline Gunyah guest（`EL2-VIRT` §6）** | 需移植未 upstream 的下游 gunyah 驱动（且 `stock-src` 无 `drivers/virt/gunyah`）→ **D 轨把这条整个绕开** |
| **denial / droidloom** | 桌面线，目标 = mainline 上原生跑 Android 应用；**ARM64 未打包**，短期不如 Waydroid，仅作观察 |

### 9.6 建议的下一步（只读 / 主机，等你点头）

1. ~~新机/旧机角色先定~~ → **已作废**：同型号单元**物理等价**，任务按**单元当前状态**分派（`DEVICE.md` §2、`DEVICE.md` §2.3）。此刻满足“Android + root”状态的是 U1（`HA2ABH62`）。
2. 主机 A 轨预置：下 Debian nocloud arm64 rootfs、按 `microdroid_defconfig` 思路编一份带 `CONFIG_DMA_RESTRICT_POOL` 的 guest 内核、`apt install qemu-utils`——**均不碰设备**。
3. 设备侧 **task-14 只读勘察**（设备上线时一条 `adb`/`ssh` 命令即可）。
4. 若走 APK，清理一条 a 槽路径：AVF 权限 `USE_CUSTOM_VIRTUAL_MACHINE` / `MANAGE_VIRTUAL_MACHINE`、root、`ulimit -l unlimited`。

> 风险：D 轨**不碰 hyp/XBL/ABL/GPT**，最坏是 guest 崩、不影响宿主，回退 = 卸 APK / 不跑 crosvm。与「绝不动安全鞋」原则一致。
