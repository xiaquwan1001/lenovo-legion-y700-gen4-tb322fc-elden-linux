# Gunyah Linux guest 驱动移植到 7.3-rc7（编译 + 静态审查）

日期：2026-10-24
范围：仅「编译通过 + 静态审查」，**不上机**、不写 boot、不动 build/vk151。
参考源：`reference/gunyah-android15-6.6/`（6.6 / android15 树）
目标树：`build/gunyah-port`（worktree @ `24223e4`，与在机 vk152 构建树 `build/vk151` 同 HEAD）

## 0. TL;DR

- **9 个 .ko 全部编成，0 error / 0 warning**（gunyah_hypercall + 8 个 drivers/virt/gunyah 模块 + 复验 gunyah_wdt）。
- 8 个新 .ko 的 `modinfo -F vermagic` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty SMP preempt mod_unload aarch64`，与在机 uname -r 逐字一致。
- **改动量极小**：4 个树内文件共 +5 行挂接；6.6→7.3 API 漂移实际只有 **7 处**（见 §3 表）。
- **1 个硬性功能缺口**：7.3 的 arm64 不导出 `set_direct_map_{invalid,default}_noflush`，`gunyah_rsc_mgr.ko` 在 vk152 内核上 **insmod 会因未知符号失败**；已在 worktree 补 2 行 `EXPORT_SYMBOL_GPL`，需随下一次内核构建生效（见 §9）。
- 参考快照里**缺 `include/uapi/linux/gunyah.h`**，已从 OnePlus SM8750 6.6 树（同源 Qualcomm 代码）补齐，sha256 记录于 §9。

## 1. 环境与 worktree 创建

```
$ git -C build/vk151 worktree add ../../build/gunyah-port 24223e4
Successfully wrote…（输出尾部：HEAD 现在位于 24223e4 drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable）
$ git -C build/gunyah-port log --oneline -1
24223e4 drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable
```

- `git describe --tags` → `v7.3-rc7-2-g24223e4`（Makefile: VERSION=7 PATCHLEVEL=3 EXTRAVERSION=-rc7）。
- `.config` / `Module.symvers` / `vmlinux.symvers` 从 `build/vk151` 拷入（vk151 本体未动）。
- 构建环境按 PITFALLS #381 配方：每条 make 带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=`；先 `syncconfig` + `prepare`，并确认 `grep TSK_STACK_CANARY include/generated/asm-offsets.h` → `#define TSK_STACK_CANARY 1272`；`make scripts/module.lds` 生成 `scripts/module.lds`。
- gunyah-port 树内 `.config` 的改动（留置，供复现）：`CONFIG_VIRT_DRIVERS=y`、`CONFIG_GUNYAH=m`、`CONFIG_GUNYAH_QCOM_PLATFORM=m`、`CONFIG_GUNYAH_IRQFD=m`、`CONFIG_GUNYAH_IOEVENTFD=m`、`CONFIG_GUNYAH_WATCHDOG=m`（备份：`/tmp/gunyah-port.config.bak`）。

## 2. 源码拷贝与挂接

```
cp reference/gunyah-android15-6.6/drivers/virt/gunyah/*  build/gunyah-port/drivers/virt/gunyah/
cp reference/gunyah-android15-6.6/include/linux/gunyah.h build/gunyah-port/include/linux/
cp reference/gunyah-android15-6.6/arch/arm64/include/asm/gunyah.h build/gunyah-port/arch/arm64/include/asm/
cp reference/gunyah-android15-6.6/arch/arm64/gunyah/gunyah_hypercall.c build/gunyah-port/arch/arm64/gunyah/
```

挂接（`git diff --stat` 实测 `4 files changed, 5 insertions(+)`）：

| 文件 | 改动 |
|---|---|
| `drivers/virt/Kconfig` | +1 行：`source "drivers/virt/gunyah/Kconfig"` |
| `drivers/virt/Makefile` | +1 行：`obj-y += gunyah/` |
| `arch/arm64/Kbuild` | +1 行：`obj-$(CONFIG_GUNYAH) += gunyah/` |
| `arch/arm64/mm/pageattr.c` | +2 行：`EXPORT_SYMBOL_GPL(set_direct_map_invalid_noflush)` / `(set_direct_map_default_noflush)`（§9） |
| `arch/arm64/gunyah/Makefile`（新建） | 2 行：`obj-$(CONFIG_GUNYAH) += gunyah_hypercall.o` |

新增未跟踪源（行数 = wc -l）：drivers/virt/gunyah/ 共 14 文件（gunyah.c 53、gunyah_ioeventfd.c 139、gunyah_irqfd.c 187、gunyah_platform_hooks.c 117、gunyah_qcom.c 220、gunyah_vcpu.c 613、rsc_mgr.c 872、rsc_mgr.h 149、rsc_mgr_rpc.c 634、vm_mgr.c 1156、vm_mgr.h 232、vm_mgr_mem.c 597、Kconfig 48、Makefile 9）+ arch/arm64/gunyah/gunyah_hypercall.c 288 + include/linux/gunyah.h 485 + include/uapi/linux/gunyah.h 390 + arch/arm64/include/asm/gunyah.h 57。

注意：Kconfig 挂在 `if VIRT_DRIVERS` 块内 ⇒ 必须同时开 `CONFIG_VIRT_DRIVERS=y`，否则 `CONFIG_GUNYAH=m` 被 syncconfig **静默丢弃**（第一次实际踩到，GUNYAH 从 .config 消失）。

## 3. 6.6 → 7.3-rc7 API 漂移适配表

| # | 漂移 | 位置 | 解法 | 记录 |
|---|---|---|---|---|
| 1 | `vma_interval_tree_foreach(&mapping->i_mmap, …)` 与 `folio_index()` 在 7.3 rmap 重构后移除；替代宏 `mapping_rmap_tree_foreach(vma, mapping, …)`（include/linux/mm.h:4191），folio 偏移直接用 `folio->index`（mm_types.h FOLIO_MATCH(__folio_index, index)） | vm_mgr.h `folio_mmapped()` | 改用 `mapping_rmap_tree_foreach(vma, mapping, folio->index, folio->index + folio_nr_pages(folio))`；`i_mmap_lock_read()` 仍存在（fs.h:525），语义不变 | 功能等价 |
| 2 | `PageSwapBacked(page)` 页级宏移除，仅存 folio 版 `folio_test_swapbacked()`（page-flags.h:572） | vm_mgr_mem.c:436 | `if (!folio_test_swapbacked(folio))`；上一行本就有 `folio = page_folio(page)` | 功能等价 |
| 3 | `struct fd` 不再有 `.file` 成员，改为 `fd_file(fd)` / `fd_empty(fd)`（include/linux/file.h:38-48） | gunyah_irqfd.c 121/126/148 | 3 处改 `fd_empty(fd)` / `fd_file(fd)` | 功能等价 |
| 4 | `eventfd_signal(ctx, n)` 两参签名去掉计数参数 | gunyah_ioeventfd.c:29 | `eventfd_signal(iofd->ctx)` | 功能等价（7.3 恒注入 1） |
| 5 | `of_node_to_fwnode()` 不存在；用 `of_fwnode_handle()` | rsc_mgr.c:823 | 直接替换 | 功能等价 |
| 6 | `platform_driver::remove` 在 7.3 返回 **void**（6.11 的 `remove_new` 已并回 `.remove`），void 处理器直接挂 `.remove` | rsc_mgr.c:863 | `.remove_new` → `.remove`，`gunyah_rm_remove` 保持 void | 功能等价 |
| 7 | `set_direct_map_{invalid,default}_noflush` arm64 有实现（arch/arm64/mm/pageattr.c:254/267）但**无 EXPORT**，模块不可见（modpost: undefined symbol） | arch/arm64/mm/pageattr.c | 补 2 行 `EXPORT_SYMBOL_GPL` + 树内 `vmlinux.symvers`/`Module.symvers` 追加 2 条目（本树 CONFIG_MODVERSIONS=n，CRC 全 0，modpost 仅按名解析） | **需内核重编**才在真机生效（§9） |

**未触发**的候选漂移（核实过不适用）：无 `class_create/device_create`（用 miscdevice）；无 `guard()/__free()`、无 `MODULE_IMPORT_NS`（源码用旧式裸 EXPORT）；`qcom_scm_assign_mem(phys_addr_t, size_t, u64 *src, …)` 签名与我们树 `include/linux/firmware/qcom/qcom_scm.h:109` 一致（gunyah_qcom.c 5 处调用直接编过）；`folio_page_idx`/`pin_user_pages_fast`/`guestmemfd` 无碍（vm_mgr 用自己的 gup 路径，不依赖 guestmemfd——7.3 也没有该子系统）；mailbox/irq APIs 未用（用 platform_get_irq + devm_request_(threaded_)irq，均未变）。**未删任何功能，无 #if 0**。

## 4. 构建配方与结果

```
cd build/gunyah-port
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= M=arch/arm64/gunyah modules
KBUILD_EXTRA_SYMBOLS=$PWD/arch/arm64/gunyah/Module.symvers \
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= M=drivers/virt/gunyah modules
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= M=drivers/watchdog modules   # 复验 gunyah_wdt
```

- hypercall 先单独编成模块（arm64/Kbuild 的 obj-$(CONFIG_GUNYAH) 在 M= 外部构建下不参与），其 `Module.symvers` 经 `KBUILD_EXTRA_SYMBOLS` 喂给 drivers/virt/gunyah 的 modpost，解决 `gunyah_hypercall_*` 跨模块符号。
- **0 error / 0 warning 证明**：干净全量重建后 `grep -ciE "warning|error" /tmp/b1.log /tmp/b2.log` → `b1.log:0`、`b2.log:0`（b2 尾部：`LD [M] gunyah_irqfd.ko / LD [M] gunyah_ioeventfd.ko`，exit=0）。
- 全程未触碰 `build/vk151`（worktree 独立目录）。

## 5. .ko 清单（大小 / sha256 / vermagic）

vermagic（9 个模块逐字相同）：`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty SMP preempt mod_unload aarch64`

| .ko | 大小 (B) | sha256 |
|---|---|---|
| arch/arm64/gunyah/gunyah_hypercall.ko | 193 744 | 7eaea9aa540a5bca0b059c9973a9eca42849a6535afa6f0266eff689c502be2f |
| drivers/virt/gunyah/gunyah.ko | 327 232 | a098dc8504bf9aa458a163ede3c242136e2e9528ca8577af436b5e55fcbc1978 |
| drivers/virt/gunyah/gunyah_rsc_mgr.ko | 1 170 512 | 1ed05ad0bae2bbf4724cf6b388a632a28e39e8622fec8d5327e197fa597a0dcc |
| drivers/virt/gunyah/gunyah_vcpu.ko | 423 392 | 40c281e75e8ab2a3600011fd50fc538f55552e7ab07b218eea571775b1a6ebc5 |
| drivers/virt/gunyah/gunyah_platform_hooks.ko | 332 064 | 287bccbe18efc096f0cd4a7485f116cd8aebab566199154f06d3163b5db7b130 |
| drivers/virt/gunyah/gunyah_qcom.ko | 346 232 | 4f6f5585449e7a047b6bbaec56c83a1bf8dd62bdcaafe02fc1f16773ad9762ff |
| drivers/virt/gunyah/gunyah_irqfd.ko | 329 232 | 6f061c2d2158cdada48d0199513fcc5069f0bafcc04cdeaf2dea9ad4434bcbcd |
| drivers/virt/gunyah/gunyah_ioeventfd.ko | 316 280 | 6ece332ac474015123f3d9ec53bc8c1e1370e4162ba5954dc0ee96abcc197a33 |
| drivers/watchdog/gunyah_wdt.ko（树内已有，复验） | 348 248 | 62e1195812ce11e7079fa06526a518637c9d35de15dc9679f06b77d20301da59 |

## 6. 静态审查与就绪度清单

**现在就能跑（不依赖 DT capid）——3 个可验证点：**

1. **arch_is_gunyah_guest + HYP_IDENTIFY**：`insmod gunyah_hypercall.ko` 后，其 `arch_is_gunyah_guest()`（SMCCC `VENDOR_HYP_CALL_UID`，UUID c1d58fcd-…）与 `gunyah_hypercall_hyp_identify()` 均不需要任何 capability；rm-probe 报告已用裸探针在这台机器验证 `hvc #0x6000` 与 SMCCC 形式返回一致（API v1，DOORBELL/MSGQUEUE/VCPU/MEMEXTENT 位全置）。本驱动的 hypercall 表与探针同源（`GUNYAH_HYPERCALL(fn)=SMCCC OWNER_VENDOR_HYP`）。
2. **platform 驱动注册**：`insmod gunyah.ko` 后 `/sys/bus/platform/drivers/gunyah-hypervisor`（compatible `gunyah-hypervisor`/`qcom,gunyah-hypervisor`）与 `gunyah-resource-manager` 出现；无 DT 节点时 probe 干净失败（-ENODEV 路径），不 panic。
3. **gunyah_wdt 绑定**：树内 `drivers/watchdog/gunyah_wdt.ko` vermagic 一致，且 gunyah-stage0-positive-20261024 已实证在机 insmod/绑定/rmmod 干净——本轮复验编译仍 0 warn，作为「不含 capid 依赖的模块链路」基线。

**必须等 DT capid（`/hypervisor/qcom,resource-manager-rpc` 的 `reg` + `interrupts`）：**

- `gunyah_rsc_mgr.ko` probe：`platform_get_irq`（tx/rx 两路）+ `of_property_read_u64_index(node, "reg", idx, &capid)`（rsc_mgr.c:707-728），拿到 tx/rx msgq capid 后才注册 `/dev/gunyah` miscdev；
- 由此依赖链阻塞：RM 客户端（auxiliary bus 设备）、VM 生命周期 ioctl、gunyah_qcom（SCM mem assign）、vcpu/irqfd/ioeventfd 全部要 `/dev/gunyah`；
- 静态 DT/固件 blob 里**没有**该节点（dt-capid 报告：只有 UEFI `RmVmDxe` 运行时生成），取值三条路（root 读 DT / vendor UEFI / 逆向）见该报告 §3。

## 7. DT 需求（对照 gunyah-dt-capid-20261024.md 实测）

驱动期望（v17 口径）vs 实测节点 `qcom,resource-manager-rpc@93ddea6be110409a`：

| 驱动读取 | 属性 | 实测节点属性 | 状态 |
|---|---|---|---|
| `of_property_read_u64_index(node,"reg",0/1)` → tx/rx capid | `reg`（#address-cells 由 `/hypervisor` 决定） | `reg` 在（内容 SELinux 不可读） | 待取值 |
| `platform_get_irq(pdev,0/1)` → tx/rx 中断 | `interrupts` | 在 | 待取值 |
| —（本驱动不读） | `qcom,free-irq-start / is-full-duplex / rx-message-size / rx-queue-depth / tx-message-size / tx-queue-depth` | 全在 | 备用信息 |
| 父节点 `/hypervisor` | `compatible`（`gunyah-hypervisor` 等） | 实测为 `qcom,gh-watchdog` 同级；gunyah.c 匹配 `qcom,gunyah-hypervisor` | ** Linux 侧 DTB 需补**：主线驱动认 `gunyah-hypervisor`/`qcom,gunyah-hypervisor` 兼容串，而产品 DT 用的是厂商布局（`qcom,resource-manager-rpc` 直接作 platform 节点 + `qcom,gh-watchdog`）。上机时需 overlay：`hypervisor { compatible="qcom,gunyah-hypervisor"; …-rpc@… { compatible="gunyah-resource-manager"; reg=<capid_tx capid_rx>; interrupts=<…>; }; }`（具体 compatible 以 overlay 实测为准） |

## 8. 上机计划与回退

1. **前置（内核侧）**：把 §3-#7 的 `pageattr.c` 2 行 export 带进下一次内核构建（vk152 之后的 spin），否则 `gunyah_rsc_mgr.ko` insmod 报 `Unknown symbol set_direct_map_*`。
2. **顺序**：`gunyah_hypercall.ko → gunyah.ko → gunyah_platform_hooks.ko → gunyah_qcom.ko → gunyah_rsc_mgr.ko → gunyah_vcpu.ko / gunyah_irqfd.ko / gunyah_ioeventfd.ko`；每步 `dmesg` 锚点（arch_is_gunyah_guest 打印、bus 目录、/dev/gunyah 出现）。
3. **capid 就绪后**：写入 DT overlay（§7），`/dev/gunyah` 出现即 RM 通道建立；先跑只读 RM 调用（RM_INFO 等价 hypercall）再谈 VM 生命周期。
4. **回退**：全部为模块，`rmmod` 逆序即可；不写 boot 分区、不改日用树 `.config`；若 `set_direct_map` export 无法进内核，降级方案 = 把 GUNYAH 改 `=y` 随内核编入（无需 export）。

## 9. 失败 / 未证实项

- **`set_direct_map_{invalid,default}_noflush` 在 vk152 vmlinux 未导出**（`grep EXPORT arch/arm64/mm/pageattr.c` = 空；`grep set_direct_map vmlinux.symvers` = 空）。已补 export 但**真机内核不含** ⇒ `gunyah_rsc_mgr.ko` 在当前在机内核 insmod 必失败（`modprobe --force` 之外的任何方式都无法绕过）。未证实项：未上机验证（任务范围外）。
- **参考快照缺 `include/uapi/linux/gunyah.h`**（任务背景称有 14 文件含此头，实际 `find reference/gunyah-android15-6.6 -name gunyah.h` 仅 2 个）。已从 OnePlus OSS `android_kernel_common_oneplus_sm8750`（分支 `oneplus/sm8750_b_16.0.0_oneplus_13`，Qualcomm 同源 6.6 代码，gh-proxy.com 镜像下载）补齐：sha256 `08253667336ae3f72b5e7ef61bf8ea967b39da17c70b712c93d7e19715977624`（13 749 B）。与 include/linux/gunyah.h 的 ioctl/结构引用交叉核对一致（编译通过佐证）。
- **capid 数值仍未取得**（SELinux 拒读，见 dt-capid 报告）——本移植不含真值验证，§6-1/2/3 是无 capid 可验证面的全部。
- 尝试从 torvalds/linux 取 uapi 头失败（mainline 已无该文件，v6.8–v6.14 与 master 均 404；gunyah 驱动已从主线移除），lore.kernel.org 被 Anubis 拦截、codelinaro 需 Auth0 登录——均只影响取文件途径，不影响结论。
- gunyah-port 树 `.config` 为模块构建工作态（含 `CONFIG_VIRT_DRIVERS=y` 等 6 项），**非**在机内核身份；vk151 的 `.config` 原样未动。
