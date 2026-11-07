# UEFI p45：EB 段逐步屏显 + 异常 dump 不清屏（主机侧已构建、静态复核 PASS，**未上机**）

> 线：G1-29（UEFI 间接引导）。承接 `reports/uefi-p39-p43-continue-20261107.md` §4「下一发（p45）该做什么」。
> 本轮**零上机、零写盘**：只做主机侧构建 + 静态复核 + 构建脚本加固。设备侧判据仍待用户在场时取。

---

## 0. 一句话

`p45` = `p43` + **R39**（把「转储内部三步 + EB 段每一步」全部改成屏显标记）+ **R40**（异常 dump
**不再清屏**）。两枚补丁都已进配方、成功应用、编进产物；静态复核 PASS：`LinuxLoader.efi` 里
8 条新标记串全在，`DefaultExceptionHandler.obj` 里 **`SerialPortClearScreen` 已不再是未定义符号**
（= 清屏调用确实删掉了）。镜像 `out/r21-sbstop-p45/uefi-preamble45-r1.img`（`fbde3a70…`）可直接上机。

---

## 1. 为什么是这两条补丁

p41/p43 的判读困境（`reports/uefi-p39-p43-continue-20261107.md` §3）：

- 屏上只有 `[K] preeb-go`，**没有 `preeb-ok`**；R38 新加的 `[K] dump-tag=preeb cached=…` 也没留证
  ⇒ 崩点在「进 `SbDumpLog("preeb")`」到「打出那行状态」之间，现有标记**再也分不下去**（分配？取环？写盘？）；
- 而 `posteb` 记录从 p37 起就**永远拿不到**，EB 段一旦崩，屏是唯一活着的通道；
- R30 的异常 dump 会在打印前 `SerialPortClearScreen()` —— 它把归因行钉在最上方，代价是
  **崩溃前的全部 `[K]` 标记被抹掉**，正好抹掉我们唯一要读的东西。

## 2. 补丁内容

### R39 `20261107R39-ebscreen`（`BootLinux.c`）

`SbDumpLog()` 内三步上屏：`[K] dump-in <tag>`（入口）→ `[K] dump-ring-ok <tag>`（`AllocatePool` 成功、
`SerialPortLogGet` 之前）→ `[K] dump-write <tag> len=<n>`（真正调 `SbWriteLogWindowNoBs()` 之前），
再接 R38 已有的 `[K] dump-tag=%a cached=%r`。

EB 段逐步上屏：`[K] eb-go`（调 `ShutdownUefiBootServices()` 之前）→ `[K] eb-ret st=<status>`（之后）→
`[K] bb4`（`SbBbMark(4)` 之后）→ `[K] posteb-go` → `[K] posteb-ok`（`SbDumpLogNoBs("posteb")` 两侧）。

全部只用 `SerialPortWrite`（R21 之后帧缓冲控制台惰性初始化、不碰 `gBS`），EB 前后都安全；
`trap` 与 `FreePool` 链一字未改。

### R40 `20261107R40-noclear`（子模块 `Silicon/Arm/MU_TIANO` 的 `DefaultExceptionHandler.c`）

删掉 `SerialPortClearScreen()` 调用（及其局部声明），归因行仍打两次（最前 + 紧贴 dump 块），
`sp/spsr/far` 与 x0..x28/FP/LR 打印不改。依据：R29 之后控制台几何已统一为像素语义
（scale 4：79 列 × **63 行**，满屏有界清屏 + 回顶），13 行 dump 直接追加完全放得下，
早先标记最多被顶掉 13 行、仍留在屏上。

## 3. 构建账（主机侧，零写盘）

```bash
PFX=p45 RECIPE=patches/uefi/p45-recipe.txt OUTDIR=out/r21-sbstop-p45 \
  BUILD_ARCHIVE=reports/artifacts/uefi-20261107R39R40-p45 STAGES="26" \
  scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild
```

- 配方 `patches/uefi/p45-recipe.txt` = `p43-recipe.txt` + R39 + R40，共 **66** 个补丁（顺序敏感）。
- 构建耗时 59 s（`build.log` 尾 = `PROGRESS - Success`，`0108 Images Verified`）；
  `成功应用补丁` **99** 处（含对同一文件的多枚补丁），**0** 处 `patch does not apply`。

## 4. 静态复核（PASS）

| 判据 | 命令 | 结果 |
|---|---|---|
| R39 标记串进产物 | `strings -a Build/.../AARCH64/LinuxLoader.efi \| grep -E 'eb-go\|eb-ret\|bb4\|posteb'` | 8 条全在（`[K] eb-go` / `eb-ret st=%r` / `bb4` / `posteb-go` / `posteb-ok` / `dump-in %a` / `dump-write %a len=%d` + 既有 `preeb-go`） |
| R40 清屏调用已删 | `llvm-nm -u DefaultExceptionHandler.obj` | 未定义符号里 **没有** `SerialPortClearScreen`（只剩 `SerialPortWrite`） |
| FD 身份 | `SM8750_EFI.fd` sha256 | `e61678e061ad0bf3…`（4 194 304 B） |

⚠ FD 内部是 LZMA 压缩卷，**不能**在 FD 上直接 `strings` 验标记（(`preeb-go` 同样 0 命中）；
验标记一律在模块级 `LinuxLoader.efi`（`reports/artifacts/uefi-20261107R39R40-p45/obj/` 已归档该件 + `.map`）。

## 5. 上机单（待用户在场；**必须补发 `fastboot continue`**）

零写盘，只在 boot 槽 b 之外跑 RAM 载荷：

1. 设备在 Linux（`192.168.7.1`）时：`ssh root@192.168.7.1 eldroid-bootctl reboot bootloader`（或用户按键进 fastboot）；
2. `fastboot boot out/r21-sbstop-p45/uefi-preamble45-r1.img` —— 期待 `Sending 1.49 s` + `Booting OKAY ~10.1 s`；
3. **等 UEFI 进 fastboot（`fastboot devices` 能看到 `product: sun`）后，再发一条 `fastboot continue`**
   （本树 `BootIntoFastboot` 写死 TRUE；不补发这一发信息量为 0）；
4. 拍照（屏上最好的一帧）+ 崩后物理断电 → 起回 Linux → `python3 scripts/uefi-logfs-read.py` 读 `preeb`/`posteb`。

判读表：

| 屏上/记录 | 结论 |
|---|---|
| 有 `dump-in` 无 `dump-ring-ok` | 崩在 `AllocatePool(8192)` 本身（`gBS` 已失效） |
| 有 `dump-ring-ok` 无 `dump-write` | 崩在 `SerialPortLogGet`（纯内存，基本可排除） |
| 有 `dump-write` 无 `dump-tag cached=` | 崩在 `SbWriteLogWindowNoBs()` 里（缓存 `BlkIo` 句柄失效） |
| 有 `preeb-ok` + `eb-go` 无 `eb-ret` | 崩在 `gBS->ExitBootServices` **调用内部** |
| 有 `eb-ret` 无 `bb4` | 崩在 `SbBbMark(4)`（纯内存写 + cache 维护） |
| 有 `bb4` 无 `posteb-go` | 崩在 `SbDumpLogNoBs` 入口前的那几行环内标记 |
| 有 `posteb-go` 无 `posteb-ok` | 崩在 NoBs 写入（则「EB 后 `BlkIo->WriteBlocks` 不可用」成立） |
| `posteb-ok` + `EB-OK st=…` | EB 全过，崩点在其后（`PreparePlatformHardware()`/跳内核段） |

## 6. 构建脚本加固（本轮顺带修的真问题）

`scripts/uefi-build-variant.sh`：

1. `apply_patch()` 每层加 `--ignore-whitespace` 兜底（严格 apply 失败后才用，并打 `note:`）。
   这就是 11-07 那条「R40 因 CRLF 没进配方」的直接修法 —— 实测本轮 R40 **严格 apply 就成功**，
   兜底只是防复发。
2. **`revert_patch()` 不再吞错**：原来 `git apply -R … || true`，回滚失败照样「成功」，
   于是工作区残留补丁改动而脚本以为干净 —— 本轮手工回滚 p43 时就踩到：
   `MU_BASECORE`（Dispatcher/DxeMain/Image/BdsDxe）与 `Common/MU_TIANO`（PrePiLib/FwVol）留着改动，
   只有逐个 `git -C <sm> status` 才看得见。现在失败会 `WARN`（`PITFALLS #545`）。

## 7. 产物

- 镜像：`out/r21-sbstop-p45/uefi-preamble45-r1.img`（`fbde3a70efefe7672ded119195bcf4423050012ed6c7bfd90d0ef3eceb9911e6`，67 219 456 B）
  与二分件 `p45-s26-pb3.img`（`98b7d4aa…`，`sbstop=26 sbprobe=3` 前缀）；
- 构建归档：`reports/artifacts/uefi-20261107R39R40-p45/`（`SM8750_EFI.fd`、`build.log`、`SHA256SUMS`、
  `obj/LinuxLoader.{efi,map}`、`obj/p45-recipe.txt`）；
- 补丁：`patches/uefi/20261107R39-ebscreen/`、`patches/uefi/20261107R40-noclear/`；配方 `patches/uefi/p45-recipe.txt`。

## 8. 未闭合（诚实标注）

- 本轮**没有设备证据** ⇒ 不构成任何「已修复」结论（`AGENT-OPS` §3 纪律）。p45 的价值是「把判别点做细」。
- 上机一次崩一次要物理断电；设备当前在 Linux（`7.3.1-debug-vk184`），`boot_b` 仍为 `vk185-adsp`，槽位 `retry=7 succ=1`，本轮未动盘。
