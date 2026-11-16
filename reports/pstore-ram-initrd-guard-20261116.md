# pstore/ram 拒绝与 initrd 重叠的 zone —— 落地与门禁（2026-11-16）

> 承接 `reports/uefi-grub-initrd-rootcause-20261115.md`（真机根因定案）与 INDEX §0「下一步 5」的修法 ①。
> 本轮完成：**补丁落地（2 枚系列）+ 独立评审 + 构建 + QEMU A/B + 真机一发**（UEFI/GRUB 路径，守卫生效，见 §5）。
> 备料件 = `patches/upstream/pstore-ram-initrd-overlap-20261116/`（`0000` cover + `0001`/`0002` + `README.md` + `logs/`）。

## §0 一句话结论

内核侧守卫**已成形并全绿**：`initrd_phys_range()` + `ramoops_probe()` 逐 zone 判重叠 ⇒ 重叠段 `dev_warn` 跳过、
其余照常注册；QEMU 同一因果链两发 A/B 分别给出「无守卫：`Initramfs unpacking failed`」「有守卫：跳过 console 段并起进 `/init`」。
**真机已验**：同一颗内核、同一份 64 MB initrd、保留 `ramoops@c2000000`（11-15 夜必失败的那份 DTB）⇒ 三段 zone 全部
`ignoring … overlaps the initrd`、ramoops 本 boot 关闭、initrd 完整解包、60 s 起进 SSH（§5）。
**已发**：2026-11-16 12:00:49（USTC 通道）→ To Kees Cook / Tony Luck / Guilherme G. Piccoli，Cc `linux-kernel` + `linux-arm-msm`；
3 × `Result: 250`，lore `/lkml/` 与 `/linux-arm-msm/` 均命中 0/2（归档 2026-11-16T04:01:14Z）。
线程根 `Message-ID` = `20261116040049.434247-1-xiaqinghuan@mail.ustc.edu.cn`，账 = `patches/upstream/…/logs/40-sent.txt`。**等回复**。

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

## §5 真机一发（2026-11-16 11:46–11:48，UEFI/GRUB 路径，**守卫在真机生效**）

链路：`fastboot set_active a` → ABL → `boot_a`(Mu UEFI pc1) → ESP `\EFI\BOOT\BOOTAA64.EFI`（本轮自打嵌入菜单 GRUB
`cc6391b3…`）→ `\boot\grub\grubenv` 逐步打点 → `devicetree /boot/elden.dtb`（**含** `ramoops@c2000000`）→
`linux /boot/Image`（= 本轮 `build/daily` `v7.3.1-5-g4bdf1711b5`，`0a55e52c…`）→ `initrd /boot/initrd.img`（64 595 425 B，`3282ae6c…`）。

**60 s 起进 SSH**、`uname -r` = `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，串口（dmesg）原文：

```
[    4.623508] ramoops c2000000.ramoops: ignoring dmesg zone 0xc2000000-0xc21fffff: it overlaps the initrd (0xc1ab0000-0xc584a5e0)
[    4.715498] ramoops c2000000.ramoops: ignoring console zone 0xc2200000-0xc23fffff: it overlaps the initrd (0xc1ab0000-0xc584a5e0)
[    4.807561] ramoops c2000000.ramoops: ignoring pmsg zone 0xc2400000-0xc27fffff: it overlaps the initrd (0xc1ab0000-0xc584a5e0)
[    4.899447] ramoops c2000000.ramoops: every zone overlaps the initrd; ramoops disabled for this boot
[   15.575674] Unpacking initramfs...
[   29.574689] Run /init as init process
```

判读（逐条）：

| 观测 | 含义 |
|---|---|
| initrd 物理区间 `0xc1ab0000-0xc584a5e0`（63 MB）**整段盖住** `ramoops@c2000000` 的 8 MB（`0xc2000000-0xc27fffff`） | 与 11-15 夜失败的落点同类（那两发是 `0xc23e0000` / `0xc18b0000`），**这次是真的重叠**，不是"没撞上" |
| 三段 zone 逐条 `ignoring …: it overlaps the initrd` + 四段全跳 `ramoops disabled for this boot` | 守卫按设计触发：**console 段没有被注册**（根因面直接关掉），而非"注册后侥幸没写坏" |
| `Unpacking initramfs...` → `Run /init` → 起进 systemd → 60 s SSH | initrd 完好；对照 11-15 同配置（无守卫内核）= `broken padding` 后回落 b 槽 |
| `OF: reserved mem: failed to reserve memory for node 'ramoops@c2000000'`（t=0） | 正常：initrd 已先占住那段，memblock 拒绝再 reserve；随后 nomap 标记照做，与本补丁无关 |
| `/sys/fs/pstore` 空、`pstore: Registered efi_pstore` | 本 boot 的 ramoops 全线关闭（预期副作用）；efi_pstore 后备仍在 |

**同轮旁证**：换回 11-15 夜那份 GRUB（`92a4d8b2…`，嵌入菜单，默认臂带 `devicetree elden.dtb`）在同一天先跑过一发，
结果是「菜单后滚三四行 → 黑屏仅背光 → 20 s 关机 → ABL 回落 b 槽」——与本轮同 DTB、同 initrd、只差内核有无守卫，
**构成真机上的有/无守卫对照**（11-15 夜那发是"删 DTB ramoops 节点才起"，本轮是"保留节点、守卫挡住即起"）。

产物：`reports/artifacts/uefi-pstoreguard-20261116/`（`dmesg-guard.txt` 全文、`guard-summary.txt`、自打菜单与 EFI）。
断点：设备现处 a 槽（`set_active a`）；回滚 = `fastboot set_active b`（b 槽 `boot_b` vk190 未动）。


## §6 剩余动作

1. ~~真机一发~~ **已于 §5 完成（守卫在真机生效）**。注意 ESP 现役件本轮换成了自打嵌入菜单 GRUB（`cc6391b3…`），
   ESP `\EFI\BOOT\BOOTAA64.EFI` 的历史件全在（`.grub-fixr2-20261116.bak` 等），r73 = `\EFI\elden\Loader.efi`。
2. 用户批准后按 `TASKS/README.md` §7 逐系列发信（pstore 维护者 Kees Cook + linux-kernel；cover letter 骨架已填正文）。
3. 若上机验证通过，再决定是否把该内核作为 vk192 入账（涉及 `versions/vk-kernel-identity.tsv`，**禁重跑** `vk-identity.py`）。
