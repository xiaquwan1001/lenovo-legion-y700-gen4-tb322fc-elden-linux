# UEFI 重打包口径纠正：10-30/31 的「交棒条件」是 boot image header 的产物，不是载荷属性

> 2026-11-01 10:20–11:25 CST。设备 HA2EXB0E（U2，在机 `boot_b` = vk183 线）。**全部零写盘**（只 `fastboot boot`；
> 恢复用 `set_active b`）。执行 = `scripts/uefi-boot-trial.sh`（本轮新增），每条 = `reports/trials/*.json`。
> 现场目视 = 用户（联想 logo / 掉电重启 由用户确认）。

## §0 数字结论（先看这六条）

1. **「重建即失效」不成立**：同源重建 A2 的 FD 与 10-24 原件 `eb00db73…` **只差 6 字节**，差异全部是
   **构建时间字符串**（`21:54:49`/`Oct 24 2026` → `23:52:38`/`Oct 31 2026`，偏移 `0xb2d9–0xb2ed`）。
   用这份重建件重打包上机 **交棒（= 载荷被 ABL 接受并开始启动）** ⇒ 构建是可复现的，10-31 §5 待办 1 **已闭合**。
2. **「交棒/不交棒」判据被 boot image v0 header 污染**（本轮最重要的纠正）：
   **同一份 gz 载荷字节**（逐字节相同，见 §2）只改 header 的 5 个字段，`fastboot boot` 就从**拒绝**变成**接受**。
   ⇒ 10-30/31 的 E0/E1/N2/R1/R2/X1/X2 **全部从未被执行**，那批「厂商 UFSDxe × cachefix shim」「E1 不交棒」
   「X1/X2 交叉换件」结论 **作废**（不是被推翻成相反结论，而是**没有测到变量**）。
3. **干净 header 下，所有载荷都执行**：本轮实测被接受的载荷 = 纯 Mu FD(N2)、dodge UFSDxe FD(X1)、
   PrePi 红条插桩 FD(R2)、A2 原 FD、A2 重建 FD、80 B 自写 shim(BRK/spin)、X1 入口改 `b .`
   ⇒ **7 种载荷，7/7 接受**。
4. **ABL 跳转后 ~1–2 s 整机掉电**：BRK 与 `b .` 自旋两个对照臂都是「过联想 logo 立刻掉电 → 重启 → 回落 Android」
   （用户目视 + USB 采样 2/40、2/45）。⇒ 载荷侧可用的观测窗口只有 **1–2 s**；「屏上标记」方案必须在这个窗口内可见，
   否则永远看不到（这也是 J1 长期为 0 的一个新的、更强的候选解释）。
5. **J1（屏上出字）本轮仍未取到目视证据**：R2-repack（PrePi 红条 FD + 干净 header）**确实被执行**，
   但用户未报看到红条 ⇒ 「红条是否出现」必须**再打一发并专门目视/手机录像**才能定档（下一轮第一件事）。
6. **未解矛盾（必须写进下轮）**：A2-v0b（旧 header）**被接受**，而 N2-v0b（旧 header，除 `kernel_size`/`id` 外
   **header 逐字节相同**）**被拒绝**，两发均 2/2 复现。⇒ 旧 header 的接受与否**不是**单字段决定，
   目前**无自洽机制**（见 §4）。干净 header 侧没有这个矛盾。

## §1 本轮 10 发上机（全部零写盘）

| # | label | 载荷 | v0 header | 结果 | 判据 |
|---|---|---|---|---|---|
| 1 | `uefi-a2replay` | A2 重建 FD（`088d99fe…`，与 A2 差 6 字节时间串）+ 160 B cachefix shim | **干净** | **HANDOFF** | `Booting FAILED (usb_read failed)`，USB 1 s 内消失 |
| 2 | `uefi-c1-brk` | 80 B shim：`brk #1` → `b .` | 干净 | **HANDOFF + 掉电** | USB 在采样 3（~3 s）消失；用户目视「立刻掉电重启」 |
| 3 | `uefi-c2-spin` | 80 B shim：`b .` 自旋 | 干净 | **HANDOFF + 掉电** | 同上 |
| 4 | `uefi-p2-x1-entryspin` | X1 FD（vendor→dodge UFSDxe）把入口 `0x8c68` 改成 `b .` | 干净 | **HANDOFF** | 同 1 |
| 5 | `uefi-p3-x1-repack` | **X1 FD 原样**（10-31 判「不交棒」的那份） | 干净 | **HANDOFF** | 同 1 |
| 6 | `uefi-p4-n2-old-image-retest` | `N2-v0b.img`（10-30 原件，sha `90659a4d…`） | 旧 | **NOJUMP**（复现） | `Booting OKAY [10.107s]`、USB 30/30 在、`getvar` 0.004 s 应答 |
| 7 | `uefi-p5-n2-repack` | **N2 FD 原样**（纯 Mu UFSDxe） | 干净 | **HANDOFF** | 同 1 |
| 8 | `uefi-p6-idtest-oldid` | 第 7 发 + 把 `id` 换成 N2-v0b 的 `id` | 干净（旧 id） | **HANDOFF** | ⇒ **`id` 字段不参与判定** |
| 9 | `uefi-p7-n2-old-retest2` | `N2-v0b.img` 第二次 | 旧 | **NOJUMP**（2/2） | 同 6 |
| 10 | `uefi-p8-r2-prepi-marker-cleanheader` | **R2 FD**（PrePi `CEntryPoint` 红条插桩 `c6e0e887…`） | 干净 | **HANDOFF** | 载荷被执行；红条目视**未记录**（待补） |

- 「HANDOFF」= ABL 接受并开始启动：`fastboot boot` 在 **0.05 s** 内 `usb_read failed`（ABL 拆 USB），随后整机掉电/回落。
  **注意口径**：这是「ABL 决定启动这份 image」，**不等于**「payload 已执行到最后」；2 s 后一切都被掉电截断。
- 「NOJUMP」= ABL 拒绝：**恰好 ~10.1 s** 后回 `Booting OKAY`，USB 不断、bus/device 不变、`getvar` 继续应答，`fastboot reboot` 0.001 s。
- 每条 trial 的原始采样：`reports/artifacts/uefi-boot-20261101-*/{usb-watch.txt,boot.txt,run.log,ssh-*.txt,logfs.img,abl-log.txt}`。

## §2 「同一份载荷、两种 header、两种结果」的硬证据

**N2-v0b.img（10-30，拒绝）vs N2-repack-v0.img（本轮，接受）**：两个文件**等长 2 441 216 B**，
逐字节 diff 只有 7 段：

| 偏移 | 字段 | 旧（拒绝） | 新（接受） |
|---|---|---|---|
| `0x17` | `ramdisk_addr` 高字节 | `0x01`（=`0x01000000`） | `0x00` |
| `0x1e–0x1f` | `second_addr` 高位 | `0x10f0`（=`0x10f00000`） | `0x0000` |
| `0x2c–0x2f` | `os_version` | `0x1e000133` | `0x00000000` |
| `0x240–0x253` | `id`（SHA1） | `a1197365…` | `c31a241e…` |
| `0x66c–0x66d` | `dtb_size`（v1/v2 字段遗留） | `0x067c` | `0` |
| `0x676–0x677` | `dtb_addr` 高 16 位 | `0x11f0` | `0` |

- **载荷完全相同**的证明：把「本轮 python gzip 出的 payload」写回旧镜像的 kernel 段，得到的文件
  sha256 = **`90659a4dc3565758…`** = `N2-v0b.img` 原件（逐字节相等）⇒ 旧/新两份用的是**同一个 gz 流**。
- **`id` 被排除**：第 8 发把 `id` 换回旧值仍 HANDOFF。
- **`kernel_size` 被排除**：两份都是 2 436 721 B。
- 于是「拒绝」只可能来自 `ramdisk_addr` / `second_addr` / `os_version` / `dtb_size` / `dtb_addr` 之一（或组合），
  但 `A2-v0b` 这些字段与 N2-v0b **完全相同却仍被接受**（§4 矛盾）。

## §3 构建可复现性（10-31 §5 待办 1 闭合）

`scripts/uefi-build-variant.sh reports/artifacts/uefi-rb-20261031/a2-replay --ufsdxe vendor --rmvmdxe mu --shim cachefix --clean`

| 项 | 10-24 原件 | 本轮重建 |
|---|---|---|
| `SM8750_EFI.fd` | `eb00db73…` | `088d99fe…`（**只差 6 字节**） |
| `BootShim.bin` | `0c1bb4da…`(160 B) | `0c1bb4da…`（**逐字节相同**） |
| 差异定位 | — | `0xb2d9–0xb2ed`：`21:54:49`/`Oct 24 2026` vs `23:52:38`/`Oct 31 2026`（`<null string>` 构建时间串） |

⇒ 构建链（clang 21.1.8 / python 3.14.4 / 上游 `6b6ac42a`）**确定性成立，唯一不确定量 = 构建时刻字符串**。
10-31 §5 待办 1「重建即失效的字节级对比」**完成，结论 = 不存在该效应**。

## §4 仍未解的两件事（下一轮起点，按价值排序）

1. **旧 header 的接受/拒绝规则**（1 发解析 + 2–3 发上机即可夹死）：
   A2-v0b（接受）与 N2-v0b（拒绝）header 仅差 `kernel_size`/`id`，且两者都被单独排除 ⇒ 目前**不自洽**。
   机制候选：ABL 对 v0 header 仍读取 v1/v2 的 `dtb_size`/`dtb_addr`/`ramdisk_addr` 派生出的区间，
   再用**载荷长度**做边界判断（A2 与 N2 只差载荷内容/长度）。实验 = 从 N2-repack 出发**逐字段**回改旧值（1 字段 1 发）。
   **工程口径不受影响**：干净 header（全零）在本轮 7 种载荷上 7/7 被接受。
2. **J1 = 屏上出字**：R2-repack 已证载荷被执行（§1 #10），只缺**目视/录像**判定。
   同时 §0-4 给出新的窗口约束：**跳转后 ~1–2 s 整机掉电** ⇒ 任何标记方案必须在 2 s 内可见；
   若红条仍未出现，下一个候选变量 = **boot watchdog 未喂**（Qualcomm ABL 跳转前 arm 的 PMIC/SoC wdog，
   Linux 靠 `qcom_wdt`/SCM 早喂；Mu 侧没有）⇒ 在 PrePi 最早期 pet/disable wdog 可把窗口从 2 s 拉到分钟级。

## §5 工具（本轮新增，已入库）

- `scripts/uefi-build-variant.sh <outdir> [--ufsdxe mu|vendor] [--rmvmdxe mu|vendor] [--shim stock|cachefix|markers|custom:<bin>]
  [--patch p]… [--clean]`：唯一构建入口；产出 FD/payload/v3/v0 镜像 + `manifest.txt`（含子模块 SHA、clang 版本、变体、
  树状态）+ `SHA256SUMS`；收尾自动还原树。**v0 一律 `--base 0x10000000 --kernel_offset 0x8000`、其余全零**。
- `scripts/uefi-boot-trial.sh --image <img> --label <L> [--watch N]`：设备锁 → 健康门 → `eldroid-bootctl reboot bootloader`
  → 前置 getvar → 1 Hz USB + 3 s `getvar` 活性采样 → `fastboot boot` → 判定 → 恢复（`fastboot continue` → `reboot` →
  Android `adb` 兜底 + `set_active b`）→ 后置态 + **logfs 取出并解析 UEFILOG1.TXT** → 落 trial record。

## §6 证据清单

- trials（10 条）：`reports/trials/20261101T*Z-uefi-*.json`、`reports/trials/index.tsv`
- 构建：`reports/artifacts/uefi-rb-20261031/a2-replay/`（manifest+SHA256SUMS+build.log）
- 重打包对照：`reports/artifacts/uefi-rb-20261031/repack/`（`N2-repack-v0.img`、`N2-repack-with-oldid-v0.img`、`X1-repack-v0.img`）
- 入口改 `b .`：`reports/artifacts/uefi-rb-20261031/entryspin/`
- 自写 shim：`reports/artifacts/uefi-rb-20261031/abortshims/{shim-brk,shim-spin}{.S,.bin,-v0.img}`
- 每次上机现场：`reports/artifacts/uefi-boot-20261101-*/`
