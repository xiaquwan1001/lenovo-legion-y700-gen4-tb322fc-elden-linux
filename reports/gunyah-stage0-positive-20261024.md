# Gunyah 阶段 0/0b：**阳性** —— 本机确实跑在 Gunyah 下，且 SMCCC vendor-hyp 通道可用（2026-10-24）

> 触发：`TASKS/README.md` §4 N2（用户 2026-10-24 定的下一步「考查 Gunyah」）+ 用户「设备在 Linux、SSH 通、不依赖外界的准备工作尽量做」。
> 设备：U2 `HA2EXB0E`，`root@192.168.7.1`，在机内核 `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`（= `vk152`）。
> 前序：`reports/gunyah-roadmap-20261021.md`（当时结论「不该开工」，其阶段 0 探测**从未真正跑过**）。
> 产物：`reports/artifacts/gunyah-probe-20261024/{probe.txt,wdt-test.txt,gunyah_wdt.ko}`；
> 参考源码 `reference/gunyah-android15-6.6/`（18 文件 / 272 KB，见 §4）。

## 0. 结论（先数字）

| 探测 | 判据 | 结果 |
|---|---|---|
| **阶段 0**（零成本） | `ls /sys/bus/platform/devices \| grep gunyah` | ✅ **`gunyah-wdt`**（由 `qcom_scm` 在 SMCCC UUID 命中后注册） |
| **阶段 0b**（自编探针） | `gunyah_wdt.ko` probe 通过 = `GUNYAH_WDT_STATUS`(SMCCC vendor-hyp func 0x0006) 返回 0 | ✅ 模块加载、驱动绑定、`watchdog0` 出现、`rmmod` 干净 |
| 主线驱动 | `gh api torvalds/linux:drivers/virt` 有 `gunyah/` | ❌ **仍无**（今日复核；上游最新仍 v17/2024-02） |

**⇒ 原判断「Gunyah 线现在不该开工」的前提被推翻一半**：
以前说「DT 只有一个保留区、没证据说明 hyp 在」，现在的证据链是
**EL2 里 Gunyah + RM 实现齐全（`hypvm.mbn` 字符串）→ SCM 询问 Gunyah UUID 命中 → SMCCC vendor-hyp 调用真正可用**。
「能不能用 Gunyah」不再是猜测，而是**设备侧已实测为真**；剩下的缺口全在 Linux 侧软件（驱动/VMM/guest 固件），**可自建**。

## 1. 阶段 0：`gunyah-wdt` 平台设备

```
$ ls -d /sys/bus/platform/devices/*gunyah*
/sys/bus/platform/devices/gunyah-wdt
$ cat /sys/bus/platform/devices/gunyah-wdt/uevent
MODALIAS=platform:gunyah-wdt
$ ls /sys/hypervisor            → No such file or directory   （arm64 不走该 sysfs，正常）
$ dmesg | grep -i gunyah
[0.000000] OF: reserved mem: 0x80000000..0x80dfffff (14336 KiB) nomap non-reusable gunyah-hyp@80000000
```

**这个设备的产生路径**（`build/m1-73/drivers/firmware/qcom/qcom_scm.c:2497`，`probe` 第 2942 行调用）：
`CONFIG_HAVE_ARM_SMCCC_DISCOVERY=y`（在机 config 已确认）→ `arm_smccc_hypervisor_has_uuid(c1d58fcd-a453-5fdb-9265-ce36673d5f14)`
→ 命中后 `platform_device_register_simple("gunyah-wdt")`。**设备存在 ⇒ UUID 询问命中 ⇒ 本机运行在 Gunyah guest 里。**

> 提醒（写进报告避免后人再误判）：`dmesg | grep gh_rm` 恒空（树里没该驱动），**不能**当反证；10-10 那次「没有 gunyah 驱动」的阴性判据就是这个错误仪器。

## 2. 阶段 0b：自编 `gunyah_wdt` 探针（SMCCC 通道实证）

树里**已有**主线 `drivers/watchdog/gunyah_wdt.c`（SMCCC vendor-hyp，控制/状态/喂狗四个 func），只是没编进内核
（`# CONFIG_GUNYAH_WATCHDOG is not set`）。编成模块加载即证明通道可用：

```
$ insmod gunyah_wdt.ko            → OK
$ lsmod | grep gunyah             → gunyah_wdt  12288  0
$ readlink /sys/devices/platform/gunyah-wdt/driver
../../../bus/platform/drivers/gunyah-wdt
$ rmmod gunyah_wdt                → rmmod_OK
```

`gunyah_wdt_probe()` 的第一句就是 `gunyah_wdt_call(GUNYAH_WDT_STATUS)`，`-EOPNOTSUPP` 会直接 `-ENODEV`；
**probe 成功 = 该 SMCCC vendor-hyp 调用返回 0**，且随后的 `gunyah_wdt_stop()`（DISABLE）也成功。
（`/sys/class/watchdog/watchdog0/*` 属性不存在是**本内核未开 `CONFIG_WATCHDOG_SYSFS`**，与驱动无关；别当异常。）

**为什么它价值高**：这是「hyp 存在」之外的第二层证据 —— **hypervisor 真的在服务 EL1 的调用**，
而不是只留了个 UUID 应答。任何后续 Gunyah 方案（RM RPC、VM 生命周期）都依赖同一层 SMC 路由。

## 3. 构建配方（已实测；三个坑见 `PITFALLS` #379）

```bash
cd build/vk151                      # = vk152 的树
cp .config /tmp/vk151.config.bak
sed -i 's/^# CONFIG_GUNYAH_WATCHDOG is not set/CONFIG_GUNYAH_WATCHDOG=m/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- syncconfig      # 必须做，否则 auto.conf 还带旧值
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= prepare
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= scripts/module.lds
cp vmlinux.symvers Module.symvers                                 # 缺它 ⇒ modpost 全部 unresolved
mkdir -p .gwdt-probe && cp drivers/watchdog/gunyah_wdt.c .gwdt-probe/
printf 'obj-m := gunyah_wdt.o\n' > .gwdt-probe/Makefile
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= M=.gwdt-probe modules
modinfo -F vermagic .gwdt-probe/gunyah_wdt.ko   # 必须逐字 = 在机 uname -r
```
- `LOCALVERSION=` 必须显式置空，否则 `+` 后缀 ⇒ vermagic 失配（`PITFALLS #367` 同型）。
- `M=` 要用**树内相对路径**（绝对 `/tmp/...` 会让 kbuild 去掉前导斜杠）。
- 收尾已把 `.config` 还原（`CONFIG_GUNYAH_WATCHDOG` 未开）、删掉 `.gwdt-probe/`；`.ko` 存进产物目录。

## 4. 源码获取（不等上游回信，已落地）

`lore.kernel.org` 现在挡在 Anubis 机器人校验后面（raw/mbox 都拿不到 v17 系列）。改取 **AOSP `kernel/common` android15-6.6**
（高通自己维护的下游主线版，结构与 v17 同源）：

```
https://android.googlesource.com/kernel/common/+/refs/heads/android15-6.6/drivers/virt/gunyah/
```
已抓到 `reference/gunyah-android15-6.6/`（18 文件 / 272 KB）：
`drivers/virt/gunyah/`（14：Kconfig/Makefile/gunyah.c/rsc_mgr.c/rsc_mgr_rpc.c/vm_mgr.c/vm_mgr_mem.c/gunyah_vcpu.c/gunyah_qcom.c/gunyah_platform_hooks.c/gunyah_irqfd.c/gunyah_ioeventfd.c/rsc_mgr.h/vm_mgr.h）
+ `include/linux/gunyah.h`、`include/uapi/linux/gunyah.h`、`arch/arm64/include/asm/gunyah.h`、`drivers/firmware/qcom_scm.{c,h}`（供平台钩子对照）。

**移植缺口初判**（静态）：QCOM 平台钩子 `gunyah_qcom.c` 只用 `qcom_scm_assign_mem()` + `struct qcom_scm_vmperm`，
这两个在**我们 7.3 树里都有**（`include/linux/firmware/qcom/qcom_scm.h:24,109`）⇒ **不必改 qcom_scm 内核主体**，
主要工作在 `drivers/virt/gunyah/` 本身（AOSP 版 ~4.4 kLOC，比 v17 的 6.7 kLOC 小，无 guestmemfd/按需分页）。

## 5. 仍缺什么（都属「可自建」，不是外部依赖）

| 缺口 | 状态 | 自建成本 |
|---|---|---|
| **RM 传输通道是否可达** | **未测**。AOSP/v17 走 Gunyah 自有 hypercall（msgq），不是 SMC；我们的 DT 没有 msgq/dbl 节点 | 需先做一个**安全的探测**（见 §6 选项 B），否则直接编驱动只会 probe 失败 |
| `drivers/virt/gunyah` 移植到 7.3 | 源码已在盘 | ~4.4 kLOC 适配 + 1 次 `make`；预计 1–3 天 |
| VMM（crosvm / `qemu-for-gunyah`） | 不在盘；AVF 里的 crosvm 是 **bionic** 版（`/system/bin/linker64`），glibc/musl 跑不了 | 重下/自编（`cargo` 未装） |
| guest 固件（`edk2-gunyah*` 2.0 G） | 不在盘 | 可重下 |

## 6. 下一步（按风险/收益排序，供用户拍板）

- **A. 只保留证据、不开工**（成本 0）。若「拿 Gunyah 做什么」还没答案，这是理性选择。
- **B. 安全的 RM 可达性探测**（0.5–1 天）：先读 `asm/gunyah.h` 与 `rsc_mgr.c` 的 hypercall 号与 msgq ABI，
  在**只读/无副作用**的前提下发一个 `GH_HYPERCALL_GET_VERSION` 类调用（或先只查 EL2 是否支持该 hypercall 号），
  **不发 VM 创建/内存借出**。产物 = 「RM 通道存在/不存在」的二值结论。**风险：错误的 hvc 号可能触发 hyp panic ⇒ 整机复位**（`boot_b` 可恢复，但会打断当前会话）。
- **C. 直接移植驱动**（1–3 天）：即使 RM 不通，也能先把代码落进树并编译通过，作为 staging；风险低、但可能白做。
- **D. 先答「要它做什么」**：AVF/受保护 VM 在解锁机上收益有限；若目标只是「跑一个 VM」，KVM 不可用时 Gunyah 是唯一路线，
  而 G3（Steam）现在走 Box64/Wine 已可跑 —— Gunyah 的**收益点**需要单独定义。

## 7. 复现命令

```bash
ssh root@192.168.7.1 'ls -d /sys/bus/platform/devices/*gunyah*; dmesg | grep -i gunyah'
# 阶段 0b（模块已在产物目录）
scp reports/artifacts/gunyah-probe-20261024/gunyah_wdt.ko root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'insmod /tmp/gunyah_wdt.ko && lsmod | grep gunyah && readlink /sys/devices/platform/gunyah-wdt/driver && rmmod gunyah_wdt'
```

## 8. 口径影响

- `TASKS/README.md` C8「维持低优先不立项」→ **改为「阶段 0 阳性，进入立项评估」**（§4 N2 同步）。
- `TASKS/README.md` §5 Q4（无 KVM 前提下 VM 路线值不值得投）→ 增加本条实测证据；**结论仍待「要它做什么」**。
- 与 `reports/gunyah-roadmap-20261021.md` 的差异：该报告「本机主线侧资产一件不在盘」仍成立，但
  「hyp 是否在、通道是否可用」这一层已由本轮实测闭环（原为【推测/未证实】）。

## 9. 追加（同日）：方向 B 首轮 = RM 通道在 hyp 层**已确认可用**

用户明确目标 = **在这块板子上跑 Windows on ARM**（Gunyah VM 路线），选定先做方向 B。
只读探针 `probes/gunyah-identify/` 调 HYP_IDENTIFY：**API v1、`flags[0]=0x10010fff` ⇒ DOORBELL/MSGQUEUE/VCPU/MEMEXTENT 全部支持**，
且 `hvc #0x6000` 与 SMCCC 形式（`hvc #0` + `x0=0xc6008000`）返回同一组值。
厂商 hypercall 表已从 `backup/stock-elden/vendor_ramdisk/*.ko` 反汇编落地。
详见 **`reports/gunyah-rm-probe-20261024.md`**。
