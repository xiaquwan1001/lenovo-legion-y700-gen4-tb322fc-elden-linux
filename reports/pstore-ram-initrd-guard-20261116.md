# pstore/ram 拒绝与 initrd 重叠的 zone —— 落地与门禁（2026-11-16）

> 承接 `reports/uefi-grub-initrd-rootcause-20261115.md`（真机根因定案）与 INDEX §0「下一步 5」的修法 ①。
> 本轮完成：**补丁落地（2 枚系列）+ 独立评审 + 构建 + QEMU A/B 复现与拦截**；**未上机**（需设备窗口）。
> 备料件 = `patches/upstream/pstore-ram-initrd-overlap-20261116/`（`0000` cover + `0001`/`0002` + `README.md` + `logs/`）。

## §0 一句话结论

内核侧守卫**已成形并全绿**：`initrd_phys_range()` + `ramoops_probe()` 逐 zone 判重叠 ⇒ 重叠段 `dev_warn` 跳过、
其余照常注册；QEMU 同一因果链两发 A/B 分别给出「无守卫：`Initramfs unpacking failed`」「有守卫：跳过 console 段并起进 `/init`」。
**剩余 = 用户批准 + 真机一发（GRUB/UEFI 路径）**。

## §1 落地内容

| 文件 | 改动 |
|---|---|
| `init/initramfs.c` | 新增 `initrd_phys_range(phys_addr_t *start, *end)`（initrd 存活时返回 `__pa(initrd_start)…`，释放后 `false`；**不标 `__init`**）+ `EXPORT_SYMBOL_GPL` |
| `include/linux/initrd.h` | 原型 + `!CONFIG_BLK_DEV_INITRD` 的 `false` 桩 + `#include <linux/types.h>` |
| `fs/pstore/ram.c` | `ramoops_skip_zone()`：dmesg / console / pmsg / ftrace 四段逐个判重叠 → `dev_warn` + 该段 `*_size=0`（dmesg 另置 `record_size`，ftrace 置 `max_ftrace_cnt`）并继续；四段全跳过 → `dev_err` + `-ENODEV` 干净退出；四分支 `paddr` 推进对称；`/sys/module/ramoops/parameters/*` 回写改生效值 |

树：`build/daily`，commit `5c72e9e838`（init/头文件）+ `4bdf1711b5`（pstore/ram），base `bf0adba8ff`。
`git describe`（干净）= `v7.3.1-5-g4bdf1711b5`（本轮仅供主机侧验证，**未打 vk 号、未上机、未进版本账**）。

## §2 独立评审（子代理只读评审，`reports/pstore-ram-initrd-review-20261116.md`）

- **0 个 P0**（不会崩/不泄漏/不写坏 initrd）；3 个 P1、4 个 P2。
- **已修 2 个 P1**：① dmesg skip 后 `/sys/module/ramoops/parameters/record_size` 与生效值不符（改回写 `cxt->*`）；② ftrace skip 分支漏 `paddr += ftrace_size`（补上，四分支对称）。P2 一并处理：`initrd_phys_range` 双次调用合并为一次、`initrd.h` 补 `<linux/types.h>`、注释补时序前提与「不可标 `__init`」。
- **未修 1 个 P1（有意）**：`initrd_phys_range()` 在 initrd 释放后返回 `false` ⇒ **deferred probe / `=m` 晚期加载时守卫静默失效**。理由：内建驱动走 `postcore_initcall()`，必然早于 `rootfs_initcall()` 解包；改成「整 boot 记住区间」会让 `ramoops.ko` 在 initrd 释放后合法复用内存的场景被误判。**处置 = 代码注释 + cover letter 明写这条时序边界**（不留给 reviewer 先挑）。

## §3 门禁（原始输出 `patches/upstream/…/logs/`）

| 门 | 结果 |
|---|---|
| apply-check（mainline `gh/master` = `9d66f26fef`，7.4-rc3，临时 worktree） | `0001`/`0002` **2/2 rc=0**，且实际 `git apply` 成功 |
| checkpatch（`--no-tree --strict`） | `0001`：0 error / 0 warning / 1 check（头文件 `extern`，与 `initrd.h` 既有风格一致）；`0002`：0 error / **1 warning**（`LINUX_VERSION_CODE`，是**被缩进的既有行**）/ 1 check（同一既有行的对齐） |
| 构建 | `JOBS=26 scripts/build-kernel.sh Image.gz dtbs`：**0 error / 0 warning**，符号守卫 OK（`gcc_sm8750` / DSI bonded / `rpmh`） |
| QEMU A/B 守卫版 | `ignoring console zone = 2`、`Run /init = 2`、`unpack failed = 0`、`panic/oops = 0` ⇒ PASS |
| QEMU A/B 无守卫版（同树、stash 前构建） | `unpack failed = 98`、`panic/oops = 294` ⇒ PASS（复现真机现象） |

QEMU 配方与两个装法陷阱（`-dtb` 与 `-device loader` 抢 `0x48000000`；`-initrd` 落点不可控）见 `PITFALLS #666`，脚本 `scripts/qemu-ramoops-initrd-ab.sh`。

## §4 为什么这发修法优先级最高（承接 11-15 的裁决）

真机路径上「Mu 把 initrd 铺进 ramoops」是必然的（Mu 读不到 Linux 侧 `reserved-memory`，`no EFI_RNG` ⇒ 无 KASLR ⇒
落点只由 Image 尺寸决定），而 GRUB 侧「对 `/reserved-memory/*` 先 `AllocatePages` 占位」只能治 GRUB 一条路、
且要重打 EFI；内核守卫对所有 loader（Mu/GRUB/kexec/UEFI stub）同时生效，且是**可上游**的通用行为。

## §5 剩余动作

1. **真机一发**（设备窗口 + 用户在场）：`fastboot set_active a` 或物理 POR 走 UEFI/GRUB 路径，判据 = 串口/屏上出现
   `ignoring console zone … overlaps the initrd` + initrd 完整解包（对照 `PITFALLS #665` 的失败签名）。
   注意 ESP 现役件 = Loader-r73，菜单指向 ESP `\boot\boot.img`；**不是** GRUB 嵌入菜单件（见 `DEVICE/README.md` §1.1）。
2. 用户批准后按 `TASKS/README.md` §7 逐系列发信（pstore 维护者 Kees Cook + linux-kernel；cover letter 骨架已填正文）。
3. 若上机验证通过，再决定是否把该内核作为 vk192 入账（涉及 `versions/vk-kernel-identity.tsv`，**禁重跑** `vk-identity.py`）。
