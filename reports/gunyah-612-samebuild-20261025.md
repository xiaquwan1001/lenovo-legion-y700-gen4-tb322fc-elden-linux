# Gunyah：同构建内核上复跑 6.12 栈 + 急切 LEND 否证 + 厂商 loader 路线定位（2026-10-25 下午）

> 设备：Y700 四代 TB322FC（U2）。全程 **零写盘**（`fastboot boot` 载临时镜像；分区未写）。
> 前置：`reports/gunyah-612-driver-port-20261025.md`（6.12 驱动集移植）、`PITFALLS #394`（同构建门禁）。

## 1. 数字结论

| # | 结论 | 判据 |
|---|---|---|
| 1 | **上轮 `list_del/list_add corruption` = 纯构建不一致，与 6.12 移植无关** | 同构建内核上加载 9 个 6.12 `.ko` + 建 VM 全流程，`dmesg` 0 条 corruption/Oops（6 条 grep 命中全是 `printk`/`ramoops` 噪声） |
| 2 | **6.12 栈在主线完整可用** | `/dev/gunyah`（`10,265`）在；`/root/rmtest` → `GUNYAH_CREATE_VM -> 4`；`/hypervisor` 节点 + capid 每开机自动落地 |
| 3 | **发现并修掉一个 7.3 DT 回归** | 7.3 的 `scripts/Makefile.dtbs:120` 用 `DTC_FLAGS_$(target-stem)`，`target-stem` = **无 `.dtb` 后缀** ⇒ 旧写法 `DTC_FLAGS_sm8750-lenovo-elden.dtb` 被静默忽略，DTB **无 `__symbols__`** ⇒ 厂商 hyp DTBO `apply -> -22`、RM 永不绑定（`PITFALLS #395`） |
| 4 | **「急切 LEND 整块 RAM」这条最后的内存模型也否证** | `PVM2=1 NOFWREG=1`（8 MiB 整块 `GH_VM_ANDROID_LEND_USER_MEM`，无 fw 区）→ `VM_INIT` 仍 `0xA MEM_INVALID`；kprobe 序列与 SHARE 模型逐字相同 |
| 5 | **`0xA` 与 DTB 在 parcel 中的偏移无关** | `DTBOFF=0`（DTB 落 LEND 区首地址，`dtb_offset` 必为 0）两种内存模型都仍是 `0xA` |
| 6 | **厂商那条能用的路走的是「MEM_DONATE + loader hypercall」，主线没有这两个东西** | 见 §5：`gunyah_loader.ko` 引用 `gh_rm_mem_donate`；`gh_rm_mem_donate` 发 `0x51000010`；主线只定义 `LEND(0x12)/SHARE(0x13)/RECLAIM(0x15)/APPEND(0x18)`；`gunyah_loader.ko` 另有 `hvc #0x6045/#0x604e/#0x604f/#0x6050/#0x6052/#0x6053/#0x6063/#0x6065` |

## 2. 同构建复跑（把上轮的失败条件消掉）

上轮设备内核 = `…-g2d223a4d0-dirty`，模块构建树 = `…-g24223e44ad80-dirty`（`PITFALLS #394`）。
本轮从**同一个 worktree `build/gunyah-port` @ `24223e4`（dirty）** 重编 `Image.gz dtbs modules`，
再用 `scripts/build-boot.sh` 打包，得到：

```
kernel UTS      = Linux version 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty (#2 ... 14:56:31)
module vermagic = 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty SMP preempt mod_unload aarch64   (9/9 逐字)
Image.gz        sha256 af173ac65ce0d5483cd729f9ba41d6a0eb6c331c7868d2baf5628d0fece3bb8e
dtb             sha256 7f8215346f8f1a8e20073360c8c32df92048896c1b3f291a49ca8223fbaaac34 (修 DTC_FLAGS 前，无 __symbols__)
boot img        out/boot-elden-gh612a.img  sha256 950aa0b61226604a7e15985357758fac58822f39eb31ad8289ef9ed73ccedadc
```

在 `gh612a` 上先确认「同样的模块集合不再踩内存」：`insmod` 了 `gunyah_hypercall / gunyah /
gunyah_platform_hooks / gunyah_qcom / gunyah_rsc_mgr(此时因无 DT 节点不可绑) / vcpu / irqfd /
ioeventfd / qtvm`，`dmesg` 无 corruption、无 BUG。

## 3. `__symbols__` 回归：7.3 的 `DTC_FLAGS_<stem>` 变了

`gh612a` 起机后 `gunyah-dtbo` 报 `dtbo[0] apply -> -22`，`/hypervisor` 缺失，RM 不绑。
现场 `V=1` 抓到的 dtc 命令行**没有 `-@`**。根因：7.3 的 `scripts/Makefile.dtbs:120` 是

```
DTC_FLAGS += $(DTC_FLAGS_$(target-stem))
target-stem = $(basename $(patsubst $(obj)/%,%,$@))
```

⇒ 变量名是 **`DTC_FLAGS_sm8750-lenovo-elden`**（无 `.dtb`），不是老内核的 `DTC_FLAGS_<name>.dtb`。
已改 `arch/arm64/boot/dts/qcom/Makefile:413`，重编后 `dtc -I dtb -O dts … | grep -c __symbols__` = **1**，
`dtbo[0] apply -> 0`，`/hypervisor` 出现。

打包：`out/boot-elden-gh612b.img` sha256 `c3fd81eb5565c71499098acb748515198411e16e524ea257f635e0b9b5faaad9`
（只有 DTB 变，`Image.gz` 与 `gh612a` 同）。

## 4. 6.12 栈 + 两种内存模型的 `VM_INIT` 结果

栈：AOSP `android16-6.12` 驱动集（17 文件 + 5 头文件，`config_image` + `auth_vm_mgr` + `gunyah_qtvm`），
`/dev/gunyah` 由 `gunyah.ko` 提供；RM 节点值 = 当次开机新 capid（`0x0fe23b820621593b`）。

| 臂 | 内存模型 | RM 调用序列（kprobe `gunyah_rm_call id=%x1`） | 结果 |
|---|---|---|---|
| A | `GH_VM_SET_USER_MEM_REGION`（SHARE）+ 按需分页 | `01 → 12 → 09 → 33 → 34 → 0b` | `RM rejected 5600000b. Error: 10` |
| B | `GH_VM_ANDROID_LEND_USER_MEM` 整块 8 MiB 急切 LEND（`PVM2=1 NOFWREG=1`） | 同上，**逐字相同** | 同上 |
| A' / B' | 同上但 `DTBOFF=0`（DTB 在 parcel 首地址） | 同上 | 同上 |

`Error: 10` 是**十进制打印**，即 `0xA = MEM_INVALID`（`PITFALLS #393` 已更正过一次同型误读）。

⇒ **`0xA` 不是 VMM/harness 的参数问题**：
- 对 DTB 内容/布局不敏感（上轮 7 个变体 + 本轮 DTBOFF=0）；
- 对内存模型不敏感（SHARE+demand-paging vs 整块急切 LEND）；
- 对驱动代次不敏感（6.6 AOSP 移植 / 6.12 上游分层，同一错误码）；
- 对构建一致性不敏感（上轮 corrupt 的构建，错误码也一样）。

## 5. 厂商那条路：MEM_DONATE + `gunyah_loader`

Android 侧 AVF/DroidVM 走 **`/dev/qgunyah`**（`10,263`、ioctl 类型 `'A'`），主线无此节点。
本机 vendor ramdisk 里的模块集给出了它的机制链：

| 证据 | 内容 |
|---|---|
| `gunyah_loader.ko` 未定义符号 | `gh_rm_mem_donate` / `gh_rm_populate_hyp_res` / `gh_rm_all_res_populated_cb` / `gh_rm_get_vm_name` … |
| `gh_rm_mem_donate`（`gh_rm_drv.ko` @`0x67cc`） | `mov w0,#0x10; movk w0,#0x5100` ⇒ 消息 **`0x51000010` = MEM_DONATE**，走 share/lend 同一个 helper |
| 主线 `rsc_mgr_rpc.c:11-14` | 只定义 `LEND 0x51000012 / SHARE 0x51000013 / RECLAIM 0x51000015 / APPEND 0x51000018`，**没有 DONATE** |
| `gunyah_loader.ko` 里的 `hvc` | `#0x6045 #0x604e #0x604f #0x6050 #0x6052 #0x6053 #0x6063 #0x6065`（vendor loader hypercall 族；与 `RmVmDxe` 的 `MemShare`/`FwSetVmFirmware` 同一族） |
| `gh_ctrl.ko` | 只提供 sysfs `api/type/variant/version` 与 debugfs，不碰 RM ⇒ `/dev/qgunyah` 的 VM 生命周期在 loader 侧 |

**推断（标注为推断，不是结论）**：本代 firmware 的 RM 只接受「内存先 `MEM_DONATE` 给 hyp（loader 认领），
再由 loader hypercall 挂到 VM 上」这一种内存所有权模型；主线的 `MEM_LEND`（内存仍归 host VM 所有、按需分页）
在 RM 侧留下的是它不认的状态 ⇒ `VM_INIT` 判 `MEM_INVALID`。
这与「vendor `gh_rm_drv.ko` 里**根本没有** `SET_FIRMWARE_MEM(0x32)/SET_DEMAND_PAGING(0x33)/SET_ADDRESS_LAYOUT(0x34)`」
一致：厂商路径不需要这三条，因为它不用 RM 管理 VM 内存。

## 6. 顺带否证/澄清的几件事

- **`gunyah.ko` 是 `[permanent]`**（6.12 用 `core_initcall` + `MODULE_LICENSE`，无 `module_exit`）⇒ `rmmod` 永远
  `Resource busy`，换栈只能**换磁盘上的 `/lib/modules/<release>/…` 再重启**（记 `PITFALLS #396`）。
- 6.12 的 `gunyah.ko` 不再是 platform driver（`/sys/bus/platform/drivers/gunyah` 不存在），
  实际出现的是 `gunyah-wdt` + `gunyah_cma_vm_mem_driver`；RM 节点不再是 platform device，但 `/dev/gunyah` 正常。
- 6.12 `gunyah_generic_pre_vm_configure` 在 `gunyah_share_parcel()` **之前**算 `dtb_offset`，而
  `gunyah_gup_share_parcel()` 会把 `parcel.start` 回退到 folio 基址 ⇒ 理论上 `dtb_offset` 可能偏小。
  实测 `DTBOFF=0` 不改变错误码，因此**不是**本次 `0xA` 的原因；作为上游潜在缺陷单独记录。

## 7. 产物与复现

```bash
# 构建（同一 worktree，含 DTC_FLAGS 修正）
cd build/gunyah-port && make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= Image.gz dtbs modules
# 打包
KDIR=build/gunyah-port VERSION=gh612b RAMDISK_KIND=rootfs \
  RAMDISK=$PWD/out/rootfs-vk127.cpio.gz bash scripts/build-boot.sh
# 上机（零写盘）
fastboot boot out/boot-elden-gh612b.img
# 设备侧
/root/rmtest                                   # GUNYAH_CREATE_VM -> fd  = RM RPC OK
cd /root/vmmtest-run && /root/vmmtest ./stub.bin ./guest-v9.dtb          # 臂 A
PVM2=1 NOFWREG=1 /root/vmmtest ./stub.bin ./guest-v9.dtb                 # 臂 B（急切 LEND）
# RM 调用序列
echo 'p:rmcall gunyah_rm_call id=%x1' > /sys/kernel/debug/tracing/kprobe_events
grep -oE 'id=0x[0-9a-f]+' /sys/kernel/debug/tracing/trace | uniq -c
```

- 镜像：`out/boot-elden-gh612a.img`（无 `__symbols__`，留作反例）、`out/boot-elden-gh612b.img`（当前有效件）。
- 设备现状：已 `reboot2 normal` 回到磁盘 `boot_b`；`/lib/modules/7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty/`
  下已是 6.12 驱动集（6.6 原件备份 `/root/ghmodules-6.6-backup.tar.gz`），开机钩子
  `/etc/local.d/50-gunyah.start` 加载 9 个模块 ⇒ 干净启动即 `/dev/gunyah` 可用、`dmesg` 无 corruption。

## 8. 下一步（需要裁决的分叉）

1. **继续（高成本、低上游价值）**：逆向 `gunyah_loader` 的 `MEM_DONATE + hvc 0x60xx` 协议，在主线实现一条
   「donate 型」内存路径。风险：纯厂商 ABI、随固件版本变、不可上游化（与 G1 目标相悖）。
2. **换参考 VMM 做差值**（中成本）：在**同一镜像**上跑 `qemu-for-gunyah`/crosvm-glibc。但前提是它也只走 `/dev/gunyah`，
   因此**不足以**绕开 `MEM_INVALID`（除非它的序列里还有我们没做的 RM 调用）。
3. **裁决 G2 回 Waydroid**（零成本）：把「本 firmware 下主线自建 Gunyah 子 VM 不可用（RM 路径）」写成结项判据，
   Gunyah 停在上游化工作（`drivers/virt/gunyah` 6.12 分层已就绪，可作 G1 的补丁素材），WoaA 另找载体（如 UEFI/bare-metal 或等新固件）。
