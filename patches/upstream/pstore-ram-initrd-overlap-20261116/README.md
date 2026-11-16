# pstore/ram: 跳过与 initrd 重叠的 zone —— 2 枚系列（**备料，未发信**）

- 基线（真源）：上游 `gh/master` = **`9d66f26fef`（7.4-rc3）**；本地论证树 = `build/daily`（7.3.1 + elden payload v2）。
- 规模：2 枚 / 3 文件 / `125 insertions(+), 24 deletions(-)`（`0001` = init + 头文件 35+；`0002` = `fs/pstore/ram.c` 114±）。
- 状态（2026-11-16）：**门禁全绿**（apply-check 2/2、checkpatch 0 error、构建 0 error/0 warning、QEMU A/B 两发各自符合预期）；**等用户批准才发**（发信口径 = `TASKS/README.md` §7）。
- 未做：**真机上机一发**（需要 `set_active a` 或物理 POR，走 UEFI/GRUB 路径；QEMU 已按同一因果链复现并验证守卫）。

## 为什么

真机根因（`reports/uefi-grub-initrd-rootcause-20261115.md`，2026-11-15 夜定案）：
Mu UEFI 把 GRUB LoadFile2 的 64 MB initrd buffer 分配进 DTB 的 `ramoops@c2000000`（8 MB `no-map`）保留区；
内核在 **t=0.0269 s** 就把 ramoops 注册成 printk console ⇒ 之后每一行 console 输出都写进那 8 MB
⇒ initrd 中间几 MB 被内核自己覆盖 ⇒ 解包 ~120 ms 即 `broken padding`，启动失败回落 b 槽。

DT 里的保留区只存在于内核（固件读不到），所以「谁是受害者」不该由固件负责：
**内核侧在注册 ramoops zone 前拒绝与 initrd 重叠的那一段**，并大声打日志。

## 改法

- `0001 init: initrd: add initrd_phys_range()` —— 新增 `initrd_phys_range(phys_addr_t *start, *end)`：
  initrd 存在时返回其物理区间（`__pa(initrd_start)`），释放后返回 `false`；**不标 `__init`**（=m 的调用者可能很晚才问）。
- `0002 pstore/ram: skip zones overlapping the initrd` —— `ramoops_probe()` 对 dmesg / console / pmsg / ftrace
  四个 zone 逐个判重叠：重叠则 `dev_warn` 跳过、把该 zone 的 `*_size`（以及 dmesg 的 `record_size`、ftrace 的
  `max_ftrace_cnt`）置 0 并继续进程；四段全被跳过时 `dev_err` + `-ENODEV` 干净退出。
  同时把 `paddr` 推进补齐（四个分支对称），并把 `/sys/module/ramoops/parameters/*` 回写改成**生效值**（`cxt->*`）。

## 时序边界（写进 cover letter，不留给 reviewer 挑）

`initrd_phys_range()` 只在 initrd 还活着时有效（释放后 `initrd_start=0`）。
内建驱动走 `postcore_initcall()`，远早于 `rootfs_initcall()` 的解包 ⇒ 正常路径一定覆盖。
若 probe 被 defer 到解包之后，或驱动是 `=m` 后加载，则检测不到（那种情况下 initrd 早已释放、不再有覆盖风险，
但同一 boot 里也不会再保护）。这条在补丁注释与 cover letter 里都写明。

## 门禁（原始输出在 `logs/`）

| 门 | 命令 | 结果 |
|---|---|---|
| apply-check（mainline 基线） | `git worktree add --detach wt/pstore-master gh/master` + `git apply --check` ×2 | **2/2 rc=0**（并在该 worktree 里实际 `git apply` 成功） |
| checkpatch | `scripts/checkpatch.pl --no-tree --strict 0001/0002` | **0 error**；`0002` 有 1 WARNING（`LINUX_VERSION_CODE`，是**被缩进的既有行**）+ 1 CHECK（对齐，同一既有行）；`0001` 只有 1 CHECK（头文件 `extern`，与 `initrd.h` 既有风格一致）→ `logs/00-checkpatch.log` |
| 构建（本地线） | `JOBS=26 scripts/build-kernel.sh Image.gz dtbs` | **0 error / 0 warning**，符号守卫 OK（`gcc_sm8750` / DSI bonded / `rpmh`）→ `logs/10-build.log` |
| QEMU A/B（守卫版） | `scripts/qemu-ramoops-initrd-ab.sh` | `ignoring console zone = 2`、`Run /init = 2`、`unpack failed = 0`、`panic/oops = 0` ⇒ **PASS(guard)** → `logs/{20,21}` |
| QEMU A/B（无守卫版） | `scripts/qemu-ramoops-initrd-ab.sh --expect-fail <旧 Image>` | `unpack failed = 98`、`panic/oops = 294`（`ramoops-1` console 注册后立刻写坏）⇒ **PASS(expect-fail)** → `logs/{22,23}` |

QEMU 复刻方式（单轮 ≈ 35 s，TCG）：`-M virt,acpi=off` + QEMU 自 dump 的 virt dtb 里插一个
`ramoops@4ff00000`（`record-size=0x20000`、`console-size=0x100000`，console 段正好压住 initrd 起点），
initrd 用 `initrd=0x50000000,<size>` + `-device loader,…` 钉在物理地址上。
`-dtb` 在 `-m 2048` 下默认装到 `0x48000000`，与 initrd 同址会被 QEMU 判 overlap 拒启动 ⇒ 一律放 `0x50000000`。

## 发信前还要做的两件事

1. 在 `build/daily` 上跑一次**真机 UEFI/GRUB 路径**验证（`set_active a` 或物理 POR；设备窗口 + 用户在场）。
2. 按 `scripts/upstream-*` 的既有流程准备 cover letter 正文（骨架已生成在 `0000-cover-letter.patch`，`*** SUBJECT/BLURB ***` 待填）、
   以及 `TASKS/README.md` §7 的逐系列批准。
