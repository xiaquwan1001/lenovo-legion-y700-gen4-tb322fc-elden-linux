# Gunyah：6.12 上游驱动集移植 + `VM_INIT` 路径穷尽（2026-10-25）

> 设备：Y700 四代 TB322FC（U2），当日两次干净启动（一次真 POR 后 fastboot，一次经 `boot_b`）。
> 上游参照：AOSP `android16-6.12`（主线 `torvalds/linux` 的 `drivers/virt/` **仍无** `gunyah/`，
> 已用 GitHub API 复核）⇒ 6.12 Android 分支是当前最接近上游的形状。

## 1. 数字结论

| # | 结论 | 判据 |
|---|---|---|
| 1 | **本机固件这一代 RM 的消息集与主线 6.6 移植不一致** | 厂商 `gh_rm_drv.ko` 反汇编：有 `VM_AUTH_IMAGE(0x5600000a)`，**没有** `SET_FIRMWARE_MEM(0x32)` / `SET_DEMAND_PAGING(0x33)` / `SET_ADDRESS_LAYOUT(0x34)` |
| 2 | **6.12 上游驱动把这三条拆成了 `config_image` 结构 + `gunyah_auth_vm_mgr` 插件** | 6.12 新增 `gunyah_qtvm.c`（注册 `VM_AUTH_IMAGE`）+ `vm_mgr_cma_mem.c`；`vm_configure` 改走 `config_image.{image_offset,image_size,dtb_offset,dtb_size}` |
| 3 | **6.12 驱动集已完整移植进 7.3 树并编译通过** | 9 个 `.ko` 全 0 error；vermagic 逐字 = 在机 `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty` |
| 4 | **`VM_INIT → 0xA MEM_INVALID` 对 DTB 内容/内存布局/固件布局完全不敏感** | 7 个单变量实验全部同一个错误码（见 §3） |
| 5 | **在机内核 UTS 与模块构建不是同一构建** | 设备侧 `g2d223a4d0-dirty` vs 全部模块 `g24223e44ad80-dirty`；随后出现 `list_del/list_add corruption` |

## 2. 厂商 RM 消息集（反汇编硬证据）

`aarch64-linux-gnu-objdump -d backup/stock-elden/vendor_ramdisk/gh_rm_drv.ko`
（脚本化提取，见 `build/gunyah-analysis/gh_rm_drv.dis`；按函数聚合 `mov w1,#<id>` + `movk w1,#0x5600`）：

| 消息 | ID | 厂商有 | 我们 6.6 移植有 | 6.12 上游有 |
|---|---|---|---|---|
| `VM_ALLOC_VMID` | `0x56000001` | ✅ | ✅ | ✅ |
| `VM_DEALLOC_VMID` | `0x56000002` | ✅ | ✅ | ✅ |
| `VM_START` | `0x56000004` | ✅ | ✅ | ✅ |
| `VM_STOP` / `VM_RESET` | `0x05` / `0x06` | ✅ | ✅ | ✅ |
| `VM_CONFIG_IMAGE` | `0x56000009` | ✅ | ✅ | ✅ |
| **`VM_AUTH_IMAGE`** | **`0x5600000a`** | ✅ | ❌ | ✅（经 `gunyah_qtvm.c`）|
| `VM_INIT` | `0x5600000b` | ✅ | ✅ | ✅ |
| `VM_GET_HYP_RESOURCES` | `0x56000020` | ✅ | ✅ | ✅ |
| **`VM_SET_FIRMWARE_MEM`** | `0x56000032` | ❌ | ✅ | ✅（`fw.config.size > 0` 才发）|
| **`VM_SET_DEMAND_PAGING`** | `0x56000033` | ❌ | ✅ | ✅（`pre_vm_init`）|
| **`VM_SET_ADDRESS_LAYOUT`** | `0x56000034` | ❌ | ✅ | ✅（`pre_vm_init`）|

`gh_rm_vm_auth_image` 报文（反汇编还原）：`{u16 vmid; u16 n; {u32 param_type; u32 param}[n]}`。
6.12 的 `gunyah_qtvm_authenticate()` 填 `param_type = GUNYAH_VM_AUTH_PARAM_PAS_ID`、`param = pas_id`，
**只用于 QTVM（`GUNYAH_RM_VM_AUTH_QCOM_TRUSTED_VM`）**，普通 pVM（`AUTH_GCOM_ANDROID_PVM`）不发它。
⇒ 「缺 `VM_AUTH_IMAGE`」**不能**单独解释普通 pVM 的 `MEM_INVALID`；真正的结构性差异是
**`config_image` 的 `image_size` / `dtb_offset` 语义**与 `auth_vm_mgr` 分层（见 §5）。

## 3. `VM_INIT` 穷尽实验（干净启动后逐条单变量）

基线：`boot_b`（vk127）→ 用 `scripts/gunyah-rm-bringup.sh` 拉起 RM（`/dev/gunyah` 存在），
`tools/gunyah-modules/vmmtest/` 最小 harness。

| # | 变量 | 结果 |
|---|---|---|
| 1 | 基线 `SHARE` + `gunyah-vm-config` DTB | `0xA MEM_INVALID`（`Error: 10`）|
| 2 | 新增 `rm-rpc` vdevice（crosvm `aarch64.rs:187` 写法，我们从未有过）`guest-v9.dts` | 不变 |
| 3 | `NOFWREG=1`：只 LEND、不建 fw 区（`--protected-vm-without-firmware` 形状）| 不变 |
| 4 | fw 放 crosvm 的位置 `FWSTART=0x7fc00000`（RAM base 之下，`AARCH64_PROTECTED_VM_FW_START`）| 不变 |
| 5 | `DTBSEP=1`：DTB 独立到 `0x90000000`，消除 IMAGE/demand-paging 重叠 | 不变 |
| 6 | `EARLY_VCPU=1`：crosvm 顺序（`ADD_FUNCTION` 早于 `VM_START`）| 不变 |
| 7 | 内核侧 `elden_skip_demand_paging=1` / `elden_skip_addr_layout=1`（新增 `module_param`，A/B/C/D 四臂）| 不变 |
| 8 | DTB 变体 v10–v13（无 `gunyah-vm-config` / 无 `memory` 子节点 / `reg` 代替 / `size-max`=RAM）| 不变 |

**硬结论**：`VM_INIT` 请求体只有 vmid（`rsc_mgr_rpc.c:464`），RM 据此校验**此前登记的 vmid 侧状态**；
DTB-only 路线**已正式穷尽**，继续在 DTB 上试探没有信息增益。

实测 RM 调用序列（`kprobe:gunyah_rm_call id=%x1`）：

```
VM_ALLOC_VMID(0x01) → MEM_LEND(0x12) → VM_CONFIG_IMAGE(0x09)
                    → SET_DEMAND_PAGING(0x33) → SET_ADDRESS_LAYOUT(0x34)
                    → VM_INIT(0x0b) ← 0xA
   cleanup: MEM_RECLAIM(0x15) → VM_RESET(0x06) → VM_DEALLOC_VMID(0x02)
```

注意：`MEM_LEND` 只发了 **1 次**（DTB 那 1 页），guest RAM 全靠 `SET_DEMAND_PAGING` 按需分页。
crosvm 的可用路径恰恰是**把整块 guest RAM 急切 LEND**——这与主线移植的「bind 后按需」模型不同。

## 4. 上游参照（为什么长期收益在这条路）

对比 `Droid-VM/crosvm`（`README` 自述 tested platform 含 `tb322fc`）与 `qemu-for-gunyah`：

- 两者都**不**手写 RM 消息，只走 `/dev/gunyah` ioctl；因此「RM 消息集差异」是**内核驱动代次**问题，不是 VMM 问题。
- DroidVM 在 Android 上额外挂 `gunyah_host_mod`（`/dev/gunyah_share`、`gh_unmovable`、`gunyah_kvcalloc`），
  且其 `gunyah.yaml` 把 SM8750/P **只标 `gunyah: yes`**（SM8650 才有 `mthp_single`）⇒ 说明 sm8750 的 RM **不需要** sm8650 那套 mTHP 预处理。
- DroidVM 主路径是 `--protected-vm-without-firmware`（`needs_firmware_loaded()=false && runs_firmware()=false`）。

⇒ 结论：**换驱动代次（6.6 AOSP → 6.12 上游分层）是唯一能同时服务「跑通」与 G1 上游化**的动作。

## 5. 6.12 移植：改了什么（全部有 `ELDEN PORT` 注释）

目录：`build/gunyah-port`（原件备份 `build/gunyah-port-6.6-backup-20261025-1406.tar.gz`）

替换为 6.12 版（17 文件 / 6735 行）：`gunyah.c` `gunyah_vcpu.c` `gunyah_irqfd.c` `gunyah_ioeventfd.c`
`gunyah_platform_hooks.c` `gunyah_qcom.c` **`gunyah_qtvm.c`（新）** `rsc_mgr.c/h` `rsc_mgr_rpc.c`
`vm_mgr.c/h` `vm_mgr_mem.c` **`vm_mgr_cma_mem.c`（新）** `trace_vcpu.h` `Kconfig` `Makefile`；
头文件 `include/linux/gunyah.h`（608 行）、`include/uapi/linux/gunyah.h`（459 行）、
`include/linux/gunyah_qtvm.h`、`include/trace/hooks/gunyah.h`。

真实 API 漂移 **7 处**（7.3 vs 6.12），全部语义等价：

| # | 6.12 | 7.3 | 处理 |
|---|---|---|---|
| 1 | `vma_interval_tree_foreach` + `folio_index` | 已被 maple tree 取代 | `folio_mmapped()` 改用上游 `folio_mapped()`（同一个问题）|
| 2 | `nth_page()` | 已删除 | `page + i`（`nth_page` 的定义就是指针加）|
| 3 | `hrtimer_init()` + `.function=` | 合并进 `hrtimer_setup()` | 直接用新 API |
| 4 | `.remove_new` | 7.3 已回到 `.remove` | 改 `.remove` |
| 5 | `of_node_to_fwnode()` | 改名 | `of_fwnode_handle()` |
| 6 | `trace_android_rvh_gh_*`（4 处）| 无 vendor-hook 框架 | 单文件 shim 成 no-op 宏，调用点源码保持上游原样 |
| 7 | `GH_VM_CHECK_EXTENSION` / `GH_CAP_VCPU_TIMER_WAKEUP`、`gunyah_arch_deadline_to_ktime`、`gunyah_{map,unmap}_addrspace_info_area`、`gunyah_arch_timer_init` | 分支未同步发布 | 前三个本地声明/实现（含 `arch_timer_read_counter()` 换算）；后两个显式说明缺席 |

编译：`make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= modules` ⇒ 9 个 `.ko` 全绿：

```
arch/arm64/gunyah/gunyah_hypercall.ko        198848
drivers/virt/gunyah/gunyah.ko                179904   ← 现在是 info-area 提供者
drivers/virt/gunyah/gunyah_rsc_mgr.ko       1519832
drivers/virt/gunyah/gunyah_qtvm.ko           391944   ← 新增
drivers/virt/gunyah/gunyah_vcpu.ko           737224
drivers/virt/gunyah/gunyah_irqfd.ko          328040
drivers/virt/gunyah/gunyah_ioeventfd.ko      315152
drivers/virt/gunyah/gunyah_platform_hooks.ko 330840
drivers/virt/gunyah/gunyah_qcom.ko           345064
```

## 6. 上机结果与失败（重要）

上机加载新栈后，`gunyah` / `gunyah_hypercall` 加载成功，随后内核出现：

```
list_del corruption, prev->next should be ... (device_shutdown → kernel_restart)
list_add corruption ... kobject_add_internal → typec_register_partner
```

同时设备自报内核为 `7.3.0-rc7-debug-vk127-00002-g2d223a4d0-dirty`，
而**所有模块**按 `g24223e44ad80-dirty` 构建 ⇒ **不是同一构建**。

判定：`vermagic` 只比较 UTS release 字符串，**同串不代表同构建**；结构体布局一变就是随机踩内存，
`list_del/list_add corruption` 是最典型表现。本轮**未**证明 6.12 移植本身有缺陷，但**也不能排除**，
因此该栈目前**未通过上机验收**，需在与模块同构建的内核上重跑。

## 7. 下一步（按收益排序）

1. **先把「同构建」做成硬门禁**：上机前比对 `/proc/version`（含 git 描述）与模块 `vermagic` 逐字一致，
   不一致直接拒绝加载。已记 `PITFALLS #394`。
2. 在同一构建的内核上重跑 6.12 栈 + vmmtest：判据 = 加载后无 `corruption`/`BUG`，再谈 `VM_INIT` 错误码是否变化。
3. 若错误码仍为 `0xA`：按 §2 的报文差异，把 guest RAM 改成**急切 LEND 整块 parcel**（对齐 crosvm），
   而不是当前的「bind + demand paging」；这是唯一还没测过的内存模型变量。
4. 上游化：6.12 的分层（`auth_vm_mgr` 插件 + `config_image`）正是主线可接受的形状，未来按模块拆补丁
   （先 `vm_mgr`/`vm_mgr_mem`，再 `gunyah_qtvm`）。

## 8. 复现命令

```bash
# 参照集（都在仓库内，无需重下）
reference/gunyah-refs/g612/          # 6.12 驱动 17 文件
reference/gunyah-refs/g612-hdrs/     # 6.12 头文件 5 个
reference/gunyah-refs/crosvm-gunyah-slice/  # DroidVM crosvm 的 gunyah 后端（含 aarch64.rs create_fdt）

# 反汇编对照
aarch64-linux-gnu-objdump -d backup/stock-elden/vendor_ramdisk/gh_rm_drv.ko \
  > build/gunyah-analysis/gh_rm_drv.dis

# 编译
cd build/gunyah-port && make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  LOCALVERSION= modules

# RM 调用序列观测（设备侧）
cd /sys/kernel/debug/tracing && printf 'p:rmcall gunyah_rm_call id=%x1\n' > kprobe_events
echo 1 > events/kprobes/rmcall/enable; echo 1 > tracing_on
# ... run vmmtest ...
grep -oE 'id=0x[0-9a-f]+' trace | uniq -c
```
