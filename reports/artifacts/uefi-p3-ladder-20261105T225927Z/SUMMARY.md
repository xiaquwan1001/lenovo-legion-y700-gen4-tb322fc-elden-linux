# UEFI 线 2026-11-05 夜 R2/R3：**探针 bug 定案 + 修好 + 首批有效判据**

## 0. 最重要的更正（推翻上一轮 10 发的判读）

`patches/uefi/20261105-vsbisect/0001` 的 `VS_STOP(n)` 判的是全局 `SbStopStage`，而该全局的
**唯一赋值点在 `BootLinux()` 内**（`patches/uefi/20261104R20-stage-bisect/0001`），
`CmdBoot` 的调用序却是 `LoadImageAndAuth()` → `BootLinux()` ⇒ 进入 `LoadImageAndAuth` 时它恒为 `-1`
⇒ **`VS_STOP(16..25)` 一次都不会命中**。

后果：2026-11-05 夜 `vs-stop20…25` + `pre-stop16/18/19` 共 **10 发全部无效**，它们的行为等于
「未加探针的对照件」，一律崩在同一处。`reports/uefi-screenlog-crash-20261105.md` §10–§12 的
窗口收窄结论（含「首要嫌疑 `FindBootableSlot`」）**作废**。

## 1. 修法（主机侧，两版）

`patches/uefi/20261105R2-vsstop-fix/0001-vs-stop-inline-parse.patch`：在 `LoadImageAndAuth()` 入口
当场从 `Info->Images[0].ImageBuffer` 的 boot image 头 cmdline 解析（与 `FastbootCmds.c` 的
finebisect 同一做法）。

- **R2 版**带 `SbStopStage < 0` 守卫 ⇒ 错：该全局跨 fastboot 命令保留，同一固件会话连打第二发
  会沿用上一发的值（实测 `sbstop=18` 被打成 `vs-16`）。
- **R3 版（在用）**无条件重解析。

反汇编核查（`LinuxLoader.map` + `llvm-objdump`）：
`0x83f8 cbz x8`（ImageBuffer 非空）→ `0x83fc add x0,x8,#0x40`（&cmdline）→
`0x8400 bl SbParseStopStage` → `0x8408 str w0,[x26,#0x5c0]`（写回 SbStopStage）→
`0x840c cmp w0,#0x10`（VS_STOP(16)）→ `0x8420 str w9(=16),[x8,#0x634]`（SbDiagAbort）。

## 2. 首批**有效**判据（preamble2 / preamble3，零写盘 `fastboot boot`）

| 档 | 件 | 结果 | 判读 |
|---|---|---|---|
| 0 | `p2-stop0` | `diag st=Success last=[entry]`，随后 `product: sun` | 解析/回传/存活三件成立（对照组） |
| 16 | `p2-stop16` | `diag st=Aborted last=[vs-16]` | **`LoadImageAndAuth()` 入口可达，入口之前不崩** |
| 19 | `p2-stop19` / `p3-stop19` | 无应答（端点死、枚举仍在） | **崩在 `VS_STOP(19)` 之前** |
| 18 | `p2-stop18` | `vs-16`（R2 守卫 bug，无效） | 需用 R3 重打 |

⇒ **崩溃窗口 = (`VS_STOP(16)`, `VS_STOP(19)`)**，即
`WaitForFlashFinished()` / `Info==NULL` / 分区名块 / `FindBootableSlot()` / `GetAVBVersion()` 之间。

## 3. 产物

- 构建：`reports/artifacts/uefi-20261105R2-vsstopfix/`（R2，守卫 bug 版）、
  `reports/artifacts/uefi-20261105R3-vsstopfix2/`（R3，在用）
- 镜像：`out/r21-sbstop/uefi-preamble2-r1.img`（`ecb521e7…`）、
  `out/r21-sbstop/uefi-preamble3-r1.img`（`25263ba3…`）；件 `out/r21-sbstop/p3-stop{0,17,18,19}.img`
- 补丁：`patches/uefi/20261105R2-vsstop-fix/0001-vs-stop-inline-parse.patch`

## 4. 纪律更正

「崩后回 ABL fastboot」**不是看门狗自复位**，是用户手动断电/开机（2026-11-05 用户确认）。
⇒ 每次崩 = 一次物理动作，必须排在用户在场时。

## 5. 下一步（每档 1 发，崩了就断电）

打序 **18 → 17**（件已备 `p3-stop18.img` / `p3-stop17.img`，各只改 cmdline 9 字节）：

| 打序 | 件 | 回话 ⇒ | 崩 ⇒ |
|---|---|---|---|
| 1 | `p3-stop18` | 窗口收进 (`VS_STOP(18)`, `VS_STOP(19)`) | 窗口 = (`VS_STOP(16)`, `VS_STOP(18)`)：分区名块或 `FindBootableSlot` |
| 2 | `p3-stop17` | 窗口 = (`VS_STOP(17)`, 上一档下界)：`Info==NULL` 块 / 分区名块 / `FindBootableSlot` | 窗口 = (`VS_STOP(16)`, `VS_STOP(17)`)：`WaitForFlashFinished` 或其紧邻 |
