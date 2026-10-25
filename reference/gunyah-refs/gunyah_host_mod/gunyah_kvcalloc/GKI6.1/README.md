# gunyah_kvcalloc_mod

树外模块,复现 in-tree 提交 `b6ff6203e4bc`(*fix: large memory access*)的修复,**无需改内核源码**:让 Gunyah 的 `gh_vm_mem_alloc()` 用 `kvcalloc()`/`kvfree()` 而不是 `kcalloc()`/`kfree()`。

## 解决什么问题

大 guest VM 光是保存固定页(pinned pages)的指针数组就要几百 KiB。`kcalloc` 是高阶物理连续分配,内存碎片化时会失败,导致建 VM 返回 `-ENOMEM`。`kvcalloc` 在 kmalloc 失败时回退到 `vmalloc`,规避该问题。

## 原理

本机 GKI 配置 `CONFIG_FUNCTION_TRACER` **关闭** → kprobe 走经典 BRK 断点(无 `KPROBES_ON_FTRACE`)。在函数入口处 x0..x3 仍是入参、x30 是调用者返回地址,所以 pre_handler 里 `instruction_pointer_set(regs, 替换函数)` + `return 1` 就能把执行流整体重定向到模块内的函数副本,副本执行完直接返回原调用者。标准 arm64 整函数劫持手法,只需 `CONFIG_KPROBES=y`。

劫持两个**全局**函数(必须成对,否则 unfixed 内核用 `kfree` 释放 vmalloc 指针会 BUG):

| 原函数 | 替换为 | 改动 |
|---|---|---|
| `gh_vm_mem_alloc()` | `ghk_vm_mem_alloc()` | pages / mem_entries 用 `kvcalloc` |
| `gh_vm_mem_reclaim()` | `ghk_vm_mem_reclaim()` | 释放用 `kvfree` |

- 已导出符号直接链接:`account_locked_vm` `pin_user_pages_fast` `unpin_user_pages` `gh_rm_get_vmid`
- `gh_rm_mem_reclaim`(全局但未导出)→ 运行时 kallsyms 解析
- `struct gh_vm`/`gh_vm_mem`(私有非 KABI 结构)布局在模块内 **vendored** 逐字照抄(与 `gunyah_share_mod` 同一手法);by-value 子结构 `dtb_config`/`fw_config`/`exit_info` 由公用头 `<linux/gunyah_vm_mgr.h>` 提供,故编译**无需** gunyah 驱动源码树(不再 `#include "vm_mgr.h"`)

## 构建

```bash
./build.sh          # 用 out/ 里已配置的 GKI 树 + clang-r487747c
# 或
make KDIR=/path/to/kernel
```

产物 `gunyah_kvcalloc_mod.ko`,`vermagic` 须与运行内核一致。

## 加载

```bash
insmod gunyah_kvcalloc_mod.ko
dmesg | grep gh_kvcalloc     # "installed: ... use kvcalloc/kvfree"
```

## ⚠️ 重要约束

1. **模块内 vendored 的 `gh_vm`/`gh_vm_mem` 布局必须与运行内核字节一致**(私有非 KABI 结构)。内核改了就要重新 vendored、重新核对。与 `gunyah_share_mod` 同样的约束——但只需匹配的公用内核头,不需要驱动源码树。
2. **只有当基线内核不带该修复时才有实际效果**。如果基线已经是 `kvcalloc/kvfree`(比如当前这份树已 cherry-pick 了 `b6ff6203`),本模块只是跑一份等价副本,是无害的功能空操作。
   - 若想让"模块"成为唯一的修复来源,应在基线内核里 revert `b6ff6203`,再靠本模块打补丁。
3. 目标函数不能被内联/`notrace`——本例中两个都是全局符号,可被 kprobe 挂。
