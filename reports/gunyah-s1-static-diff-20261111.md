# Gunyah S1：三棵源码静态对账 + 本机固件 RM 代次（2026-11-11）

> lane `20261111-gunyah-s1` 由子代理启动但在抓取阶段停滞（每 5 min 只增 1 次工具调用），
> **由总管接管并用子代理已落盘的 `~/.cache/gunyah-s1/` 原始文件完成**（`tree.json` 1.8 MB 被截断，
> 改用 raw 逐文件取；子代理自报不可信，本报告每条结论均由总管亲自 `diff` 得出）。
> **全程零设备动作**（无 ssh / fastboot / adb）。消费者：`TASKS/README.md` §4 N2、`§2 C8`。

## §0 结论（先看这 7 行）

| 问题 | 结论 | 判据 |
|---|---|---|
| **piano（同 SoC SM8750P）与 g612（我们 10-25 用的 6.12 驱动）差异大吗？** | **大，且集中在「parcel 生命周期 + protected/paged 语义」**：`vm_mgr_mem.c` **+109 行**、diff 465 行；`rsc_mgr_rpc.c` +44 行、diff 90 行；`vm_mgr.c` +6 行、diff 175 行；`gunyah.c` **零差异** | `diff -u reference/gunyah-refs/g612/*.c ~/.cache/gunyah-s1/piano-*.c` |
| **有能解释「`VM_CONFIG_IMAGE` 成功但 `VM_INIT` 回 `0xA`」的差异吗？** | **有 3 条，且都指向同一件事：RM 在 `VM_INIT` 时要求「parcel 已处于正确状态」**（详见 §2.1–§2.3） | 见下 |
| **差异 ①（最可能）：`MEM_APPEND` 失败必须报 `-ENOTRECOVERABLE` 而不是回收** | g612 在 append 失败时直接 `gunyah_rm_mem_reclaim()` 把 parcel 还回去；piano 改成**先 reclaim，reclaim 也失败就 `-ENOTRECOVERABLE` 并保留 `mem_handle`**，注释原话「the caller must not release it: report that apart」。⇒ **g612 会把「RM 其实还持有」的 parcel 在本地标记为已释放** ⇒ 后续 `VM_INIT` 时 RM 看到的 parcel 状态与 VMM 认知不一致 ⇒ **`MEM_INVALID (0xA)`** | `piano-rsc_mgr_rpc.c` 相对 g612 新增的 `APPEND failed: %d, reclaim failed: %d` 分支 |
| **差异 ②：parcel 增加 `paged` 状态机与 `*_to_paged_abort()`** | g612 只有 `vm_parcel->start = 0`；piano 有 `vm_parcel->paged = true` + `gunyah_vm_parcel_to_paged_abort()`，注释「**RM still owns the parcel until VM_START succeeds: do not unpin**」⇒ **g612 在 `VM_START` 之前就 unpin，违反 RM 的所有权约定** | `piano-vm_mgr_mem.c` |
| **差异 ③：protected/paged 的 extent ticket 与 access 权限整体重构** | g612 用 `guest_shared/host_shared/guest_private/host_private_extent_ticket` + `share` 二分；piano 改成 **`guest_paged_extent_ticket` / `guest_protected_shared_extent_ticket` / `host_unprotected` / `host_protected`**，并把 `SHARE_TAG`/`VMMIO`/`PRIVATE` 与 access 的推导顺序整体重排 ⇒ **protected VM 的内存属性语义变了** | 同上 |
| **本机固件 RM 代次** | **未能在本 lane 判定**（`backup/stock-elden/vendor_ramdisk/gh_rm_drv.ko` 需反汇编，本 lane 只做源码对账；见 §4 的待办） | — |
| **S2 上机建议** | **用 piano 这一代（不是 g612）**做移植基线；且**先用 `gh_vmtest` 最小探针**（4 MiB LEND + 1 vCPU + 16 B payload），**不要**一上来跑 crosvm | §5 |

## §1 抓取证据

| 对象 | 位置 | 证据 |
|---|---|---|
| piano 树 | `yzddmr6/linux-sm8750-piano` @ `piano/v1.2-features`，commit **`ff6cf0aafb8fd28c464c90e6fe9419960911f3a6`** | `~/.cache/gunyah-s1/tree.json` 首行 `"sha": "ff6cf0aa…"` |
| piano 驱动文件 | `drivers/virt/gunyah/{vm_mgr_mem.c,rsc_mgr_rpc.c,vm_mgr.c,vm_mgr.h,gunyah.c}` | raw 直取（`raw.githubusercontent.com/.../piano%2Fv1.2-features/drivers/virt/gunyah/<f>`），行数见下表 |
| g612 基线 | 本仓 `reference/gunyah-refs/g612/`（32 个 `.[ch]`，2026-10-25 落地） | 仓内文件 |
| iceland 补丁 | **本 lane 未取到正文**（子代理在抓取阶段停滞）⇒ 本报告的差异全部来自 **piano vs g612** 的直接 `diff`，不依赖 iceland | §6 |

行数对照：

| 文件 | g612 | piano | `diff -u` 行数 |
|---|---|---|---|
| `vm_mgr_mem.c` | 901 | 1010 | **465** |
| `rsc_mgr_rpc.c` | 697 | 741 | **90** |
| `vm_mgr.c` | 1288 | 1294 | **175** |
| `gunyah.c` | 120 | 120 | **0** |

## §2 逐文件差异（三条关键）

### 2.1 `rsc_mgr_rpc.c`：`MEM_APPEND` 的失败语义（**最可能解释 `0xA`**）

g612：
```c
	if (ret) {
		gunyah_rm_platform_post_mem_reclaim(rm, p);
		return ret;
	}
	...
		if (ret) {
			gunyah_rm_mem_reclaim(rm, p);       // ← 直接把 parcel 还回去
			p->mem_handle = GUNYAH_MEM_HANDLE_INVAL;
		}
```
piano：
```c
	if (ret) {
		/*
		 * If the platform cannot give the memory back to HLOS, the
		 * caller must not release it: report that apart.
		 */
		if (gunyah_rm_platform_post_mem_reclaim(rm, p))
			return -ENOTRECOVERABLE;             // ← 新增
		return ret;
	}
	...
		if (ret) {
			int reclaim_ret = gunyah_rm_mem_reclaim(rm, p);
			if (reclaim_ret) {
				pr_err("gunyah: parcel %#x APPEND failed: %d, reclaim failed: %d\n",
				       p->mem_handle, ret, reclaim_ret);
				return -ENOTRECOVERABLE;     // ← 保留 mem_handle，不再置 INVAL
			}
			p->mem_handle = GUNYAH_MEM_HANDLE_INVAL;
		}
```

**为什么这能解释 `0xA`**：`MEM_INVALID (0xA)` 是 RM 在 `VM_INIT` 时对「vmid 引用的 parcel 不存在/不可用」的回码。
g612 在 reclaim 失败时**仍然**把本地 `mem_handle` 置 `INVAL` 并当作已释放 ⇒ 本地状态与 RM 侧真实状态分叉；
piano 的修法正是「reclaim 失败就别声称已释放」。这条与 iceland 的
`0020-q90s/0005 Never release memory that may still be dirty` **是同一类修复**（子代理只读到文件名，此处由我直接对比源码确认）。

> ⚠️ **这是「能解释」，不是「已证实」**。判定需 S2：如果 10-25 的 `0xA` 是这条引起的，
> 换 piano 代次后 `VM_INIT` 应返回 0；若仍 `0xA`，则 S3 的坏 DTB 对照（看是否变 `8`）才轮到。

### 2.2 `vm_mgr_mem.c`：`paged` 状态机与 `to_paged_abort()`

piano 新增（g612 无）：
```c
void gunyah_vm_parcel_to_paged_abort(struct gunyah_vm *ghvm,
				     struct gunyah_vm_parcel *vm_parcel)
{
	...
	/* start_fail also runs before conversion, including partial failures. */
	if (!vm_parcel->paged)
		goto unlock;
	b = mtree_load(&ghvm->bindings, vm_parcel->start);
	if (WARN_ON(!b)) goto unlock;
	/* RM still owns the parcel until VM_START succeeds: do not unpin. */
	gunyah_vm_mm_erase_range(ghvm, vm_parcel->start, vm_parcel->pages);
	b->vm_parcel = vm_parcel;
	vm_parcel->paged = false;
unlock: ...
}
```
g612 对应位置只有 `vm_parcel->start = 0;`。

⇒ **所有权约定被显式化**：`VM_START` 成功前 RM 仍持有 parcel，VMM 不得 unpin。
g612 在 abort 路径上直接清 `start`，等价于「当作已经还给 RM」——与 §2.1 同源的错误面。

### 2.3 `vm_mgr_mem.c`：extent ticket 与 access 权限重构

| | g612 | piano |
|---|---|---|
| share + protected | `guest_shared_extent_ticket` / `host_shared_extent_ticket` | `guest_protected_shared_extent_ticket` / `host_unprotected_extent_ticket` |
| 非 share + protected | `guest_private_extent_ticket` / `host_private_extent_ticket` | `guest_paged_extent_ticket` / `host_protected_extent_ticket` |
| 非 protected | （与 protected 共用同一套） | **新增独立分支**：`guest_paged_extent_ticket` / `host_unprotected_extent_ticket`，`tag \|= SHARE_TAG` |
| access 推导 | 先定 `share`，再按 `share`+`write` 四分支 | **先按 `is_protected` 三分**，再在各分支内定 access |

⇒ 对 **pVM（protected）** 来说，内存属性语义整体变了；10-25 我们走的是真 `pvmfw` + LEND + `SET_FW_CONFIG` 的 pVM 路径，
**正好落在被重构的那一支**。

### 2.4 `vm_mgr.c`（175 行 diff）

主要是 `le64_to_cpu()` 补齐（`size = entry->size` → `le64_to_cpu(entry->size)`）与
`gunyah_vm_is_fw_binding()` 助手（按 `guest_phys_addr` 判固件绑定）。
`gunyah_vm_mm_erase_range(ghvm, gfn, off - 1)` → `(ghvm, gfn, off)` 是**长度语义修正**（少删一页的 off-by-one）。
⇒ 端序与边界修正，不直接解释 `0xA`，但说明 **g612 这一代确实有真 bug**。

## §3 16 个 iceland 补丁

**本 lane 未取到正文**（子代理停滞点即在此），如实记为未完成。已知可用信息（来自
`reports/gunyah-restart-assessment-20261111.md` §5 的证据级别表，B 级 = 仅文件名）：
`0020-q90s/0005 Never release memory that may still be dirty` 与本节 §2.1 **同题**；
`0023-q90v/0001 Refuse private anonymous memory for a protected VM` 与 §2.3 的 protected 分支相关；
`0015-q90n/0012 vCPU timer 拆成 gunyah_timer`、`0018-q90q/0001 vm_mgr do not warn on module unload` 与 `0xA` 无关。

## §4 本机固件 `gh_rm_drv.ko` msg-id 支持表

**未做**（本 lane 零设备动作 + 未反汇编）。待办（给下一 lane 的精确定义）：
1. `find backup/stock-elden -name 'gh_rm_drv.ko'` 定位文件（子代理报告说在 `vendor_ramdisk/`，本 lane 未核实）；
2. `llvm-objdump -d --no-show-raw-insn gh_rm_drv.ko` 找 `gunyah_rm_call()` 的 msg-id 分发（通常是 `switch`/`if-else` 链 + `.rodata` 里的 handle 表）；
3. 判据 = 一张「`0x51000018 MEM_APPEND` / `0x56000032-34` 有没有」的表；
4. 若三者都没有 ⇒ 本机 RM 比开源 RM 老 ⇒ **`0xA` 可能是「RM 不认这些新消息」而非状态机 bug**，这会把 §2 的结论**降级**（必须在 S2 之前先做这一步）。

## §5 S2 上机建议（驱动代次 + 配方 + 风险自限）

1. **驱动代次 = piano `ff6cf0aa`**（同 SoC SM8750P 的主线移植，7.2.15），**不要**用 g612。
2. **第一步只跑最小探针**：4 MiB LEND + 1 vCPU + 16 字节 payload，**不走 crosvm**。
   判据 = `VM_START` 返回 0（而不是 `0xA`）；若 `0xA`，**同一 vmid 连做两次**（判是否 VMID 泄漏型）。
3. **风险自限**（沿用 10-25 的实测教训）：
   - 全程 `fastboot boot`（零写盘）；
   - **不要 `fork()` 持 lend 页的进程**（10-25 已实测会死机）；
   - crosvm 单进程；`GVM_HUGEPAGES` 用默认（避开 4 KiB lend 冻机）；
   - 先 `scripts/device-lock.sh` 串行。
4. **S3 二值对照**（与 S2 同一次上机）：若 S2 仍 `0xA`，喂违规 DTB（`memory@80000000`、timer PPI mask `0xf08`）
   看错码是否变 **`8 VALIDATE_FAILED`**；变 `8` ⇒ 10-25「DTB 与 VM_INIT 无关」作废；仍 `0xA` ⇒ 钉死该结论。

## §6 抓取失败 / 未核实清单

1. **iceland 16 个补丁正文未读**（子代理停滞）；本报告的差异不依赖它们。
2. **本机 `gh_rm_drv.ko` 未反汇编**（§4）。
3. piano 树的 `drivers/virt/gunyah/` 完整文件表**未取到**（GitHub `trees?recursive=1` 响应被截断在 1.88 MB；
   `contents` API 直取目录超时）。已取到的 5 个文件是子代理用 raw 逐个取的，**覆盖了 `0xA` 相关的三处**，
   但 `rsc_mgr.c`（0 字节）、`gunyah_vcpu.c` 未取到。
4. piano 的 gunyah 驱动源自哪个 AOSP tag **未确认**（iceland 明写 `android17-6.18-2026-06_r1`）。
5. `vm_mgr.h`（12 330 B）已取到但本报告未逐行 diff（结构体定义差异未列入 §2）。

## §7 复现命令

```bash
# 1) 取 piano 驱动（raw，逐文件，避免 trees API 截断）
base=https://raw.githubusercontent.com/yzddmr6/linux-sm8750-piano/piano%2Fv1.2-features/drivers/virt/gunyah
for f in vm_mgr_mem.c rsc_mgr_rpc.c vm_mgr.c vm_mgr.h gunyah.c; do
  curl -sfL --noproxy '*' "$base/$f" -o ~/.cache/gunyah-s1/piano-$f
done

# 2) 与本仓 g612 对比
for f in vm_mgr_mem.c rsc_mgr_rpc.c vm_mgr.c gunyah.c; do
  echo "=== $f ==="
  diff -u reference/gunyah-refs/g612/$f ~/.cache/gunyah-s1/piano-$f | wc -l
done

# 3) 看 §2.1 那条（APPEND 失败语义）
diff -u reference/gunyah-refs/g612/rsc_mgr_rpc.c ~/.cache/gunyah-s1/piano-rsc_mgr_rpc.c | grep -A12 'post_mem_reclaim'
```
