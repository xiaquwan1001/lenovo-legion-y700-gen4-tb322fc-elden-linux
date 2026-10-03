# 路线决定 v2 — 设备无关化（原「两轨分机」已作废）

> ## ⚠️ v2 修订（2026-10-02 21:3x，用户重述任务定位）
> **本文 §2/§3/§7 的「两轨分机」（新机=mainline／旧机=D 轨）作废。** 同型号单元**物理地位等价**，
> 唯一差异是容量 ⇒ **不得按机器身份分配任务**，改为**按单元当前状态分派**。
> 权威表述：`MISSION-SCOPE.md` §2 + `DEVICES.md` §4。**本文保留的价值 = 技术结论**（§1 两条轨不互斥、
> §5 主机预置清单、§6 收口），以及「为什么走 Android 侧虚拟化」的正反判断（§3 技术部分）。
> 旧 ID 映射：**D 轨 → G2-S2**；task-14/15 → **T5**；task-16/17 → **T6**（见 `ANDROID-COMPAT-PLAN.md` §6）。

> 输入：`ARM-VIRT-RESEARCH-2026-10-02.md`（虚拟化调研）+ `PLAN-NODEV` / `BRINGUP-UNIT`（主机预置与上机手册）。
> 目的：把**多条并行轨**收到**一套设备无关的流程**上，消除资流与设备锁冲突。

---

## 0. 一句话（v2）

**不做单选题**：同一目标形态（a 槽 stock Android + b 槽 mainline + `linux17`）装到**每一台**单元上；
虚拟化（G2-S2）跑在**当下处于「stock Android + root」状态的那一台**（此刻 = U1/`HA2ABH62`），
上机手术跑在**当下处于「原厂未动」状态的那一台**（此刻 = U2）。两者可并行，**因为不抢同一台设备**，而不是因为“新旧分工”。

---

## 1. 两条轨不是替代关系

| 轨 | 载体 | 做什么 | 是 Waydroid 的替代吗 |
|---|---|---|---|
| **主线 A/B/C** | 新机 **b 槽 mainline** | Waydroid / 音频 / 相机 / 基准 / Win-x86 | — |
| **D 轨（新）** | 旧机 **a 槽 stock Android** | 经 Gunyah `/dev/gunyah` 跑真 VM（`vm`/crosvm → Debian guest → DroidVM APK） | 否，完全不同层 |
| denial / droidloom | 主线桌面 | 在 Linux 桌面原生跑 Android 应用 | 是 Waydroid 的替代形态，但 **ARM64 未打包** → **仅观察，不立项** |

> 本机 EL2 被签名 Gunyah 占死、主线 Linux 拿不到 KVM（`EL2-VIRT`）；而 Android 侧 `/dev/gunyah` 现成，
> 且 **DroidVM 官方推荐 SoC 正是 SM8750**。D 轨把 `EL2-VIRT` §6 的数周工作量降到数小时。

---

## 2. 任务如何落到单元（v2：按状态，不按身份）

| 任务轨 | 所需单元状态 | 载体（此刻） | 说明 |
|---|---|---|---|
| **G1 主线**（mainline + 驱动/固件 + 基准） | b 槽 mainline + `linux17` 持久根 | **U2**（原厂未动，适合首次手术） | 任一单元可达：`BRINGUP-UNIT-2026-10-02.md`（容量参数化） |
| **G2-S1** Waydroid 容器 | 同上 | 同上 | Mesa 26.1.8 + GAPPS 镜像已就绪 |
| **G2-S2** AVF/Gunyah 真 VM（原 D 轨） | **stock Android + root + 大 `/data`** | **U1**（a 槽已 root，`/data` 211 GiB） | 硬要求是**状态**：谁先 root 完谁就能做，与新/旧无关 |
| **G2-S0** 兼容下限 | a 槽原厂 Android 在位 | **两台都是**（目标形态自带） | 不占用专用机 |
| 主机预置（A11/A12/T3/T7） | 无需设备 | — | 现在就能做 |

> 目标形态统一：每台都是 a 槽 stock Android + b 槽 mainline + `linux17`（容量按档位）。详见 `MISSION-SCOPE.md` §2.4。

---

## 3. 为什么走 Android 侧虚拟化（技术结论，与单元无关）

**正面**：本机 **EL2 被签名 Gunyah 占死**，mainline 拿不到 KVM（`EL2-VIRT`）；而 **Android 侧 `/dev/gunyah` 现成**，
AVF 全套（`crosvm` 带 Gunyah 后端 + `vm` + microdroid 6.6.77 + u-boot）**已从本机 ROM 离线提取**，
不需下载；高通/DroidVM 官方推荐 SoC 正是 **SM8750**；`vm` 实验全在用户态，**不碰 hyp/XBL/ABL/GPT**。

**反面**（为何不做主线侧 Gunyah 主 VM 驱动移植）：本地 `stock-src/android_kernel_lenovo_sm8750`（仅 1670 文件）
**连 `drivers/virt/gunyah` 都没有**，AOSP 树 `external/crosvm` 也只 KVM 无 Gunyah → 源码都得别处取，工作量数周。

**仍未定项（如实记录，不预设乐观）**：`virtio_gpu`/VirGL 图形加速是最不确定一环（上游在 SM8750 实测未通）。
处理原则见 `ANDROID-COMPAT-PLAN.md` §7 第 2 条。

---

## 4. G2-S2 任务拆解（原 D 轨 task-14…17 → 现 T5/T6，对象=「处于 Android+root 状态的单元」）

| 旧 ID | 新 ID | 任务 | 类型 | 风险 |
|---|---|---|---|---|
| task-14 | **T5a** | AVF **只读勘察**：`ls /dev/gunyah`、`/apex/com.android.virt/bin/{vm,crosvm}`、`getprop ro.boot.hypervisor.*`、`vm info`/`vm list` | 只读 | 零 |
| task-15 | **T5b** | **最小 headless VM**：microdroid_kernel + initrd + `vm console`，验证 Gunyah 通路 | 用户态 | 零（崩 VM 不伤宿主） |
| task-16 | **T6a** | **Debian guest**：自编带 `CONFIG_DMA_RESTRICT_POOL` 的 guest 内核 + nocloud rootfs + `vm_config.json` | 用户态 | 低 |
| task-17 | **T6b** | **DroidVM APK 实测**（Linux/Windows guest、GPU 后端、OOM/RM 坑） | 用户态 | 低（先审计 APK） |

> 纪律照旧：worker 只报「命令 + 原始日志」，编排者**独立复跑**；每条留回退（卸 APK / 不跑 crosvm）。
> **并行性来自状态不重合**（一台在 mainline、一台在 Android），而不是来自机器身份。

---

## 5. 主机预置（不碰设备，现在可做；设备无关）

| 项 | 内容 | 现成程度 |
|---|---|---|
| **Debian nocloud arm64 rootfs** | `cloud.debian.org` nocloud arm64（~600 MB–2 GB）；走 `net-egress.sh`（教育网 107 MB/s）/USTC | 待下载 |
| **guest 内核** | 按 `microdroid_defconfig` 思路编一份带 **`CONFIG_DMA_RESTRICT_POOL`** 的 arm64 内核（交叉链已有） | 待编 |
| **磁盘工具** | `qemu-img`/`virt-resize`（`sudo apt install qemu-utils`） | **未装（需 sudo）** |
| DroidVM APK | 官方 release（`0.0.6`）/ dev；**有社区后门传闻，先审计再装** | 待下/审计 |
| **AVF 底层** | `crosvm`+`vm`+microdroid 内核/initrd/u-boot | ✅ **已从本机 ROM 提取**，不用下载（`/mnt/Samsung/l2/system_a.pristine.img` → `com.android.virt.apex`）|

---

## 6. 与既有事项的收口（v2）

- **Waydroid（G2-S1）**：跟目标形态走，**任一处于 mainline 的单元**都装（Mesa 26.1.8 已就绪）。
- **Win-x86（Box64+Wine）**：mainline 侧已 PoC 成功；G2-S2 的 Windows guest 是**并列路线**，不互斥。
- **bring-up 手册**：`BRINGUP-UNIT-2026-10-02.md` 已改为**设备无关 + 容量参数化**（变量 `$BAK`/`$LINUX_GIB`/`$BLK`）。
- **env-pass / SUSFS**：是「处于 Android 状态单元」的**可移植资产包**（`env-pass/`），谁进入 Android 状态就装谁，**不绑机**。
- **旧机遗留**：音频听声确认（G1#4）、相机出流（G1#5）、task-7 基准 → 全部改为**在任何处于 mainline 的单元上验收**。

---

## 7. 待你确认（v2：只剩 2 条，都是参数不是角色）

1. **每台单元的目标形态**是否就按§0（a=stock Android / b=mainline / `linux17` 容量按档位）？
2. **G2-S2 是否立项**，先 **T5 手动 `vm run` 最小验证** 还是直接 **T6b DroidVM APK**？（建议 T5→T6）

> ~~原「设备角色是否按 §2」~~ —— 已由 `MISSION-SCOPE.md` §2 设各等价原则回答：**不设角色**。
