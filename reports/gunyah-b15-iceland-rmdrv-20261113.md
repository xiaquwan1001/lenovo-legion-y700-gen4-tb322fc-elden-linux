# Gunyah B15：iceland 16 补丁正文 + 本机 gh_rm_drv.ko 反汇编（2026-11-13，零设备）

> 任务（`TASKS/README.md`:175-176）：补 S1 静态对账的两空，给出 `VM_INIT 0xA` = 「RM 太老」还是状态机 bug 的结论。
> 证据：① iceland 16 个 gunyah 补丁**正文已全部取到**（`/tmp/iceland-linux/patches/00{14..23}-q9*/`，来源
> `mzakamin-hub/iceland-linux` 分支 `iceland-7.3-rc7-next`，sparse fetch）；② 本机 stock 固件
> `backup/stock-elden/vendor_ramdisk/gh_rm_drv.ko` 反汇编（llvm-objdump，全函数 movz/movk msg-id 重建）。

## §0 结论（先看）

| 问题 | 结论 |
|---|---|
| 0x51000018（MEM_APPEND）本机 RM 认不认 | **认** —— stock 驱动自己就发它（`gh_rm_mem_append` 内 `mov w1,#0x18; movk w1,#0x5100,lsl16`），且 stock Android 在产线可用 ⇒ 该 ID 不可能是「RM 不认识」 |
| 0x56000032-34（SET_FIRMWARE_MEM / SET_DEMAND_PAGING / SET_ADDRESS_LAYOUT） | **本机 stock 驱动完全不用**（反汇编全表 0 命中；stock 走 0x56000009 `VM_CONFIG_IMAGE` + 0x5600000a `VM_AUTH_IMAGE` 老流程，且带 `gh_feature_use_scm_assign` 的 **SCM-assign 回退特性**）⇒ 这版 Lenovo 固件 RM **很可能早于主线 boot-context 流程的世代**，但「RM 不认 32-34」**只是强暗示不是证明**（vendor 驱动不用 ≠ RM 不支持） |
| **0xA（MEM_INVALID）定性** | **两因并存、主嫌疑 = RM 世代差**：① 本机 RM 世代证据（上两行）指向「主线驱动的 lend/parcel 前置流程与本固件 RM 预期不匹配」；② g612 驱动确有真实状态机 bug（piano 的三组修复，见 §2），10-25 那发**不能排除踩中它们**。**判别仍必须靠 S2 上机**（换 piano 代次 + 最小探针；若仍 0xA 再喂违规 DTB 看是否变 8）。本轮把「上机前必须先补的空」补完了，A12 的前提成立 |

## §1 iceland 16 个 gunyah 补丁逐条（q90m–q90v，正文已读）

| 补丁 | 内容（正文） | 与 0xA 的关系 |
|---|---|---|
| q90m/0001 `virt: gunyah: import …android17-6.18` | 9289 行整栈 import；**msg-id 表与主线同代**：含 `0x56000031 SET_BOOT_CONTEXT`、`0x56000032 SET_FIRMWARE_MEM`、`0x56000033 SET_DEMAND_PAGING`、`0x56000034 SET_ADDRESS_LAYOUT`（行 4104-4107）；错误码表 `MEM_INVALID=0xA`、`VALIDATE_FAILED=8` | 主线流程所依赖的 31-34 正是本机 stock 驱动不用的那组 |
| q90m/0002 `adapt to mainline 7.2` | 纯 API 适配（android_kabi/vendor hooks/direct_map/of_fwnode_handle）；OnePlus Pad 4 实测 10 模块全载、`Running under Gunyah hypervisor 51/v1` | 无 |
| q90m/0003 `tools: VM smoke test` + 0005 `hello mode` | 最小探针工具（gh_vmtest 雏形） | S2 探针现成可借用 |
| q90m/0004 `follow v7.3 rename of rmap` | 跟随 7.3 文件重命名 | 无 |
| q90m/0006 `report VM status when vCPU of an e…` | 错误报告改进 | 无 |
| q90m/0007 `allow gunyah.ko to be unloaded` | 可卸载 | 无 |
| q90m/0008 `Add runtime protected share (GuestAccept) ioctls` | protected VM 的 SHARE/ACCEPT/UNSHARE ioctl（DroidVM in-tree 化）；**MEM_INUSE→-EBUSY**（Android 源映射成 -EINVAL） | pVM 内存语义重构面（对照 S1 §2.3） |
| q90n/0012 `build vCPU timer as gunyah_timer.ko` | 模块改名 | 无 |
| q90o/0004 `rsc_mgr: unregister the PM notifier on unload` | 卸载后 suspend 调 freed module text 的真 bug | 无 |
| q90q/0001 `vm_mgr: do not warn on every module unload` | WARN_ON(module_refcount==-1) 真 bug | 无 |
| q90s/0005 **`Never release memory that may still be dirty`** | 三处错误路径把「可能仍属 guest/secure world」的页还给分配器；share 不能回滚时 **-ENOTRECOVERABLE** + 保留 pin（与 piano `rsc_mgr_rpc.c` 同题同修，S1 §2.1 的 iceland 版） | **正是「本地状态与 RM 分叉 ⇒ MEM_INVALID」一类的修复** |
| q90s/0006 `qcom: log failed demand-page assigns + probe owner` | 失败 assign 记 pfn/order/VM + `debug_assign` 参数探测页当前属主 | S2 取证工具 |
| q90u/0002 `Report a missing resource manager log as information` | 无 RM log 的固件回 "not supported" ⇒ `-EOPNOTSUPP` 改 info 级 | **本机 RM 若无 log，modprobe 时的 "Error in returning log: -95" 是正常现象，不是失败** |
| q90v/0001 **`Refuse private anonymous memory for a protected VM's shared region`** | QEMU 私有匿名 RAM 的 swiotlb 页 SCM assign 拒绝（-EINVAL，retry 也拒）⇒ guest 永久 fault；必须 shared memfd/crosvm | **10-25 若用私有匿名 VMM 内存走 pVM，正是这一类失败**；同时修了「release 覆盖 start 错码 ⇒ VM_START 报 -ENODEV」 |

**iceland 实测口径（0002 commit message）**：`Running under Gunyah hypervisor 51/v1`——piano/iceland 都是 hyp 51/v1；本机 hyp 版本待 S2 读取（`/dev/gunyah` 起来后 dmesg），**这是比 msg-id 更直接的世代判据**。

## §2 本机 `gh_rm_drv.ko` msg-id 支持表（反汇编）

方法：`llvm-objdump -d` 全函数扫描 `mov wN,#imm` + `movk wN,#imm,lsl16` 成对重建（脚本化，全表 52 个 0x51/0x56 段常量）。stock 驱动使用的 id（⇒ **RM 至少得认这些**，否则 stock 自己跑不起来）：

| msg-id | stock 函数 | 备注 |
|---|---|---|
| 0x51000010-13/15 | mem donate/share/lend/reclaim | memparcel 全套（含 LEND 0x51000012） |
| **0x51000018** | `gh_rm_mem_append` | **命中** |
| 0x51000017/1a | mem notify / qcom lookup sgl | vendor 私有 |
| 0x56000001/02/04/05/06 | vm alloc/start/stop/reset | VM_INIT=0x5600000b 也在（`ghd_rm_vm_init`） |
| **0x56000009/0a** | `VM_CONFIG_IMAGE` / `VM_AUTH_IMAGE` | **老 boot 流程**（主线用 31-34 替代） |
| 0x5600000b | `ghd_rm_vm_init` | 命中 |
| 0x56000010/11/17/20/24 | get_id/lookup/status/hyp_res/this_vmid | |
| 0x56000030/35 | set_time_base / set_debug | **32/33/34 无命中** |
| 0x56000040-43 | minidump ×4 | vendor |
| 0x56000050-54 | vm_irq lend 族 | |
| 0x56000080/81-84/b0 | set_status/console/ipa_reserve | |

另：模块符号里有 **`gh_feature_use_scm_assign` / `gh_rm_setup_feature_scm_assign`** —— vendor 驱动带「SCM assign 替代 RM memparcel」的特性开关，进一步说明这代固件的内存路径以 SCM assign 为主。

## §3 对 S1 三条差异结论的修正（C-I12）

S1 报告的三条（APPEND 失败语义 / unpin 时序 / protected extent 重构）**仍然成立**，但权重下调一档：
iceland q90s/0005、q90v/0001 证明**连已经跑通的 iceland 平台也要靠这些修复**才能不踩 MEM_INVALID 一类错——
即它们是「必要修复」而非「本机独有病因」。判定优先级改为：
**S2 第一发先读 hyp 版本（`Running under Gunyah hypervisor NN/vN`）与 `VM_INIT` 错码；驱动代次 = piano `ff6cf0aa`（含 §2.1-2.3 全部修复）**。

## §4 S2 上机配方增量（给 A12）

1. modprobe 后 dmesg 第一手：hyp 版本行、RM log 是否 -95（§1 q90u——是 info 不是错）。
2. `gh_vmtest` 最小探针（iceland q90m/0003+0005 的 tools/virt/gunyah 可直接抄，或 4 MiB LEND 手写）。
3. 若 `VM_INIT` 仍 0xA：**同一发里**补 q90s/0006 的 `debug_assign` 式对照（喂违规 DTB 看是否变 8）。
4. VMM 内存一律 shared memfd（q90v/0001）；**不要 fork() 持 lend 页**（不变）。

## §5 证据与复现

```bash
# iceland 补丁正文
git clone --filter=blob:none --sparse https://github.com/mzakamin-hub/iceland-linux /tmp/iceland-linux
cd /tmp/iceland-linux && git fetch --depth 1 origin iceland-7.3-rc7-next
git checkout FETCH_HEAD -- patches/0014-q90m patches/0015-q90n patches/0016-q90o patches/0018-q90q \
  patches/0020-q90s patches/0022-q90u patches/0023-q90v
# 反汇编（msg-id 重建）
llvm-objdump -d backup/stock-elden/vendor_ramdisk/gh_rm_drv.ko > /tmp/gh_rm.dis
grep -nE "#0x51[0-9a-f]{2}, lsl #16|#0x56[0-9a-f]{2}, lsl #16" /tmp/gh_rm.dis
```
