# pstore/ram initrd 重叠跳过补丁 — 独立评审（2026-11-16）

评审对象：`build/daily` 工作区未提交改动（fs/pstore/ram.c + include/linux/initrd.h + init/initramfs.c）。
评审方式：只读；实际通读 ram.c / ram_core.c 全文、initramfs.c 相关段、initrd.h，并跑 checkpatch。

## §0 一句话结论

**可以上游，无 P0（不会崩、不会泄漏、不会写坏 initrd）**；上游前建议处理 2 个 P1（late/deferred probe 时 initrd 已释放导致保护静默失效的 API 语义孔；skip 后 module param 回写值与实际状态不一致），其余为 P2 打磨。

## §1 缺陷表

### P1

| file:line | 问题 | 判据/引文 | 建议 |
|---|---|---|---|
| init/initramfs.c:785 + fs/pstore/ram.c:726（`ramoops_overlaps_initrd`） | `initrd_phys_range()` 在 initrd 释放后（`do_populate_rootfs` 末尾 `initrd_start = 0`，initramfs.c:764-765）返回 false。=y 时 ramoops 在 postcore_initcall probe（早于 rootfs_initcall，已核实 initramfs.c:798），时序正确；但若 ramoops 设备 **deferred probe / 更晚才 probe**（=y 场景下平台依赖导致的 -EPROBE_DEFER 是合法路径），probe 时 initrd 已释放 → 保护静默消失 → 原始 bug（console 写进 initrd）原样复发，且无任何日志。一个 API 同时服务「=y 早期 probe」和「=m 晚期 probe」两种消费者，语义是二选一的折衷。 | initramfs.c:756-765：`free_initrd_mem(...); ... initrd_start = 0; initrd_end = 0;`；ram.c:789 `postcore_initcall(ramoops_init)` | 上游讨论选项：① 在 boot 早期快照物理区间（如新函数在 `reserve_initrd_mem`/arch 设置处记录到独立变量，`initrd_phys_range()` 返回「本次 boot 曾有的 initrd」区间）；或 ② 保留现语义但在 ramoops 侧补一条注释/`pr_warn` 说明「若 probe 晚于 initrd 释放则无法检测」。至少在 cover letter 里向 maintainer 说明这个时序边界，别让 reviewer 先发现。 |
| fs/pstore/ram.c:926-930 | dmesg skip 时把 `cxt->record_size` 置 0（:827），但 probe 成功路径回写 module param 用的是 `pdata->record_size`（未置 0）→ `/sys/module/ramoops/parameters/record_size`（及 console/pmsg/ftrace 同理，:928-930）显示的尺寸与实际注册的 zone 状态不符，误导现场取证。 | ram.c:926 `record_size = pdata->record_size;` vs :827 `cxt->record_size = 0;` | 回写改为 `record_size = cxt->record_size;` 等四个 cxt 值（或注释说明该 sysfs 显示的是 DT 请求值而非生效值）。 |
| fs/pstore/ram.c:860-863 | ftrace skip 分支没有像 console/pmsg 那样 `paddr += cxt->ftrace_size`。ftrace 是最后一个 zone 所以当前无功能影响，但若日后在其后加 zone 或调整顺序即成静默错位；且四个分支不对称，reviewer 会问。 | 对比 :838/:848 有推进 | 补 `paddr += cxt->ftrace_size;` 保持对称。 |

### P2

| file:line | 问题 | 建议 |
|---|---|---|
| fs/pstore/ram.c:744-752（`ramoops_skip_zone`） | `initrd_phys_range()` 被调用两次（`ramoops_overlaps_initrd` 内一次、打日志再取一次）。冗余且两次结果理论可变（虽然窗口内不会）。让 `ramoops_overlaps_initrd()` 返回区间（出参）或把日志挪进同一个函数一次取齐。 | 合并为单次调用。 |
| include/linux/initrd.h:22-28 | 新桩用了 `bool`/`phys_addr_t`，initrd.h 自身不 include `<linux/types.h>`（历史上靠用户先 include）。ram.c 里恰好在 `<linux/mm.h>` 之后所以编译过，但上游 checkpatch/0-day 的独立编译可能挑头文件自包含性。 | initrd.h 顶部加 `#include <linux/types.h>`。 |
| fs/pstore/ram.c:723-736 注释 | 注释说 "The initrd is freed later during boot, so a zone skipped here stays unused for this boot only" —— 与 §1 P1 第一条的 deferred-probe 孔直接相关，注释只讲了 happy path。 | 补一句时序前提（"this relies on the ramoops device probing before the initrd is freed, which holds for the built-in postcore initcall path"）。 |
| init/initramfs.c:781 | `initrd_phys_range` 未标 `__init` 是**正确的**（=m 晚期调用），但建议 kdoc 里加一句 "must not be marked __init; callable after initmem freed"？——实际上它不引用 initmem 数据（initrd_start 是普通 .data，定义在 init/do_mounts_initrd.c:9，非 __initdata），现状安全；仅建议注释明示此约束，防止后人"优化"成 __init 被 section 回收。 | 一句话注释。 |

### 无 P0 的依据（关键否定性核查）

- `record_size=0` / `console_size=0` / `pmsg_size=0` / `ftrace_size=0` 的所有后段消费点逐一核对：`ramoops_init_przs` :499 对 0 直接 return 0；`pstore.flags`（:888-896）按 `max_dump_cnt`/size 置位，被 skip 的类型不置 flag → pstore 核心不会建对应文件、不会注册 printk console（根因面被正确关掉）；write 路径 :229/:240/:263 均先判 `!cprz/!fprzs/!dprzs`；write_user :275 判 `!mprz`；erase :419/:427 用 `id >= max_*_cnt` 拦截（skip 后 cnt=0，任何 id 都 -EINVAL）；read 的 per-cpu ftrace dummy 路径（:239-259）在 `max_ftrace_cnt=0` 时循环 0 次、`prz_ok` 为假、`free_prz` 释放临时对象，无 NULL 解引用。`ramoops_free_przs`（:462-485）对 NULL/cnt=0 幂等。**无崩溃路径。**
- 内存量守恒：dump_mem_sz(:824) 用原始 sizes 计算，各 skip 分支 `paddr += size` 精确回补，不会越界（跳过路径不做 init_przs 的越界检查，但加法本身封顶在 region 内）。
- "全跳过 → -ENODEV"（:873-877）走 `fail_init` → `ramoops_free_przs`（此时全 NULL）→ 干净退出；`max_dump_cnt` 仍 0，不阻塞后续 probe 重试。
- 跨 boot 一致性：被 skip 的 zone 内存残留 initrd 数据，下个 boot 无 initrd 时 `persistent_ram_post_init`（ram_core.c:391-420）sig 不匹配 → zap，自愈。

## §2 机械门输出摘要

`./scripts/checkpatch.pl --no-tree --strict -f fs/pstore/ram.c`：
`total: 0 errors, 5 warnings, 13 checks, 1064 lines checked`。
5 warning + 13 check **全部位于改动前既有行**（:795 对齐、:798 拆行字符串、:852 对齐、:866 LINUX_VERSION_CODE、:1034 对齐）；**新增行（约 723-760、826-880）零告警**。

`grep record_size|max_dump_cnt|... ` 全部 54 处命中已逐条过（见 §3 清单）。

## §3 无缺陷走查清单（逐条实际核对项）

1. **dump 属性/record_size=0**：`module_param(record_size, 0400)` 只读；`ramoops_init_przs` :498-502 对 `record_size==0` return 0 且 `*cnt=0`；probe :888 判 `max_dump_cnt` 才置 DMESG flag；:904 bufsize 只在 DMESG flag 下读 `dprzs[0]` → 无 NULL 访问。
2. **console 置 0**：`pstore.flags` 不含 CONSOLE → pstore 核心不注册 printk console（根因关闭点确认）；`ramoops_pstore_write` :229 判 `!cxt->cprz` 返回 -ENOMEM。
3. **pmsg 置 0**：write_user :275 判 `!mprz`；read :223 `ramoops_get_next_prz(&cxt->mprz,...)` 对 NULL 返回 NULL。
4. **ftrace 置 0 + max_ftrace_cnt=0**：write :240 判 `!fprzs`；read :239-259 per-cpu dummy 分支循环 0 次 → `prz_ok` 假 → size 0，tmp_prz 在 out 处 kvfree/kfree；erase :427 `id>=0` 恒假→-EINVAL；`ramoops_free_przs` :476-483 对 fprzs NULL 跳过。
5. **skip 后 paddr 推进**：dmesg/console/pmsg 分别 +dump_mem_sz/+console_size/+pmsg_size，与 init_przs 成功路径的推进等价（dmesg 的 init_przs 因 record 对齐可能少推进尾部，两分支各自自洽，无跨 boot 影响）。
6. **全跳过 -ENODEV**：err 置于 `fail_init` 前，`ramoops_free_przs` 幂等，`pstore.buf` 尚未分配，无泄漏；`max_dump_cnt` 未被置位，不触发 "already initialized" 死锁。
7. **`ramoops_pstore_read` 对 dprzs=NULL**：`ramoops_get_next_prz` :134 判 `!prz`（数组指针）返回 NULL；while 条件 `dump_read_cnt < max_dump_cnt(=0)` 不进入。
8. **ecc 与 skip 无交互**：`cxt->ecc_info` 不因 skip 改变；被 skip 的 zone 不建 prz，不触碰 ECC 解码。
9. **`initrd_phys_range` 生命周期**：initrd_start/end 定义于 init/do_mounts_initrd.c:9（普通数据，非 __initdata）；置 0 点 = reserve 失败 :658-659、free 路径 :764-765（retain/keepinitrd 路径也置 0）→ 无 "释放后仍返回 true" 的窗口；=y probe（postcore）早于 rootfs_initcall(:798) 与其 async worker → 检测时机确定。
10. **非 `__init` 函数放 init/ 会不会被丢 section**：init/initramfs.c 为 `obj-$(CONFIG_BLK_DEV_INITRD)`（init/Makefile:12），函数未标 __init → 进 .text 正常；EXPORT_SYMBOL_GPL 在该文件合法（符号随 BLK_DEV_INITRD=y 存在，=n 时头文件 inline 桩，无悬空符号）。
11. **include 链**：ram.c 中 `<linux/initrd.h>` 在 `<linux/mm.h>` 之后，`phys_addr_t`/`bool` 可用；initrd.h 无反向依赖 ram.c 的头，无循环；initrd.h 引用的 `rd_image_start` 等仅 extern 声明，不需额外头。
12. **重叠判定方向**：`start < iend && istart < start+size` 标准半开区间相交测试，size==0 短路，部分重叠整段跳过（保守方向正确——宁可少用一个 zone）。
