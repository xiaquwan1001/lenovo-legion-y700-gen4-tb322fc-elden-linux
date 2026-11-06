# UEFI 线（G1-29）：`(VS_STOP(34), VS_STOP(27))` 尾段静态定案 + 探针 35..38 与门控件就绪

> **状态：主机侧完成、上机未做（设备未连接）**。本文只给静态结论 + 可复现件 + 上机排产；
> 任何「修好了 / 崩溃点已定案」都不能在拿到 `diag st=` 判据之前写。
> 上一轮口径见 `reports/uefi-vsstop-and-fbconsole-20261106.md`（`sbprobe=3` 通道、窗口推到 34/27）。

- 日期 2026-11-06（下午）
- 树 `build/uefi-woa-prep/repos/7-mu-lenovo`（HEAD `6b6ac42a`）

## 0. 一页结论

1. **34→27 之间有一条 2026-11-04R15 加的、未纳入 `SbProbeMode` 的无条件 `SerialPortWrite`**
   （`FindBootableSlot` 的 `out:` 收尾）。⇒ `sbprobe=3`「完全不碰屏」在这条上是**失效的**，
   而屏显写穿正是 11-06 已定案的崩溃元凶 ⇒ 静态上它足以独立解释「34 回话 / 27 崩」，**`MarkPtnActive()` 不再是唯一嫌疑**。
2. **证据到指令级**：LTO 把 `FindBootableSlot` 整个内联进 `LoadImageAndAuth`，
   反汇编里标记顺序就是 `… #0x22(34) → MarkPtnActive 循环 → #0x23(35) → #0x24(36) → AsciiSPrint → SerialPortWrite → #0x25(37) → #0x26(38) → #0x1b(27) → #0x1c(28)`。
3. 已造好两代件（**零写盘、纯主机**）：`p8` = 尾段四刀（35/36/37/38）；`p9` = p8 + 把那条诊断写按
   `SbProbeMode` 门控。**上机只需 4 发**即可把「`MarkPtnActive` / 诊断写 / 收尾」三者分开，且**只需 1 次物理断电**。
4. 本轮**未上机**：板子当前不在 USB 上（在线的是主机上的 Android 模拟器 `sdk_gphone64_x86_64`，
   不是 TB322FC）⇒ 任何「已上机」表述都不成立。

## 1. 静态发现：窗口里那条未门控的屏显写

`Platforms/QcomModulePkg/Library/BootLib/PartitionTableUpdate.c`，`FindBootableSlot()` 尾部：

```c
  SB_VSTOP (34);                       // 2026-11-05R4：ValidateSlotGuids 之后、MarkPtnActive 之前
  MarkPtnActive (BootableSlot->Suffix);
out:
  {                                    // 2026-11-04R14/R15 的诊断块
    CHAR8  SbBuf[96];
    UINTN  SbLen;
    SbLen = AsciiSPrint (SbBuf, sizeof (SbBuf), "[V] slot0=%d st=%r\n\r", …);
    SerialPortWrite ((UINT8 *)SbBuf, SbLen);   // ← 无条件：不看 SbProbeMode
  }
  …
```

关键点三条：

| 事实 | 依据 |
|---|---|
| `SerialPortWrite` 走 `FrameBufferSerialPortLib` = **直写帧缓冲**，就是 11-06 定案的崩溃元凶 | `PITFALLS #514/#515`；`reports/uefi-vsstop-and-fbconsole-20261106.md` §4–§5 |
| `sbprobe=3` 的契约是「只更新 `SbLastMark`，不写帧缓冲、不写 NV」——但 R5/R6/R7 只改了 `SbVProbe`/`SbBootProbe` 两处 | `patches/uefi/20261105R6-probe-orthogonal/`、`20261105R7-probe-markonly/`（只动 `VerifiedBoot.c:130`、`BootLinux.c:111`） |
| 这一步**只有流程正常走到 `out:` 才会执行**：`34` 档是 `return EFI_ABORTED`（提前返回，不经过 `out:`）；`27` 档是「`FindBootableSlot` 正常返回」⇒ 必经 `out:` | 同文件；反汇编见 §2 |

⇒ 「34 回话、27 崩」与「`MarkPtnActive` 崩」**不是唯一自洽解**：也完全可以是
「`MarkPtnActive` 正常 → 走到 `out:` → 那条屏显写把帧缓冲写穿」。

另外：`MarkPtnActive()` 里的 GPT 写回路径**当前是关掉的** —— `UpdatePartitionAttributes()` 开头
`IsUpdatePartitionAttributes()` 恒 `FALSE`（`IsUpdatePartitionAttributes` 的函数体被整段注释，直接 `return FALSE`，
`PartitionTableUpdate.c:193-200`）⇒ 它实际只做一遍内存里的 `StrStr` + 属性 `|=`/`&=` 循环，
**不落盘**。这也降低了「`MarkPtnActive` 因 GPT 写入崩」的先验。

## 2. 指令级证据（本机 p8/p9 构建件）

`llvm-objdump -d Build/.../LinuxLoader/OUTPUT/LinuxLoader.efi`（p8 构建，`reports/artifacts/uefi-20261106R8-vsstop35/`）：

| 地址 | 指令 | 含义 |
|---|---|---|
| `0x8978` | `b.ne 0x88f0` | `MarkPtnActive` 的属性循环back-edge（`stp w16,w17,[x15]` 在 `0x8974`） |
| `0x897c` | `cmp w8,#0x23` → `mov w9,#0x23` | **35**（`MarkPtnActive` 之后） |
| `0x911c` | `cmp w8,#0x24` → `mov w9,#0x24` | **36**（`out:` 块入口） |
| `0x9130`/`0x9154` | `bl 0x13b0`、`bl 0x13b58` | 那条**无条件**诊断写：`AsciiSPrint` 与 `SerialPortWrite`（符号归属按 `LinuxLoader.map` 核：p9 件里两者是 `0x13b0` / `0x13b4c`，p8 件因代码量略短整体平移 12 B，同一对符号） |
| `0x9158`/`0x915c` | `ldr w21,[x26,#0x5b0]`、`cmp w21,#0x25` | **37**（写之后） |
| `0x9174`/`0x918c` | `cmp w21,#0x26` | **38**（`return` 之前） |
| `0x9184` | `cmp w21,#0x1b` | **27**（调用方 `GUARD (FindBootableSlot(…))` 之后；`#0x1b`=27） |

p9（`reports/artifacts/uefi-20261106R9-gateout/`）同一位置变成
`0x8f94: ldr w8,[x27,#0x63c]`（`SbProbeMode`）`0x8f98: cmp w8,#0x1` `0x8f9c: b.hi 0x8fb0`（>1 跳过写）
⇒ 门控**真的进了二进制**，不是「补丁打了但没编进去」。

## 3. 本轮产物（全部零写盘、纯主机）

| 件 | 内容 | 关键 sha256 |
|---|---|---|
| `patches/uefi/20261106-vsstop35/0001-vsstop35-findbootableslot-tail.patch` | `VS_STOP(35..38)` 四刀 | — |
| `patches/uefi/20261106R2-gate-outwrite/0001-gate-findbootableslot-diagnostic-write.patch` | 诊断写纳入 `SbProbeMode` | — |
| `patches/uefi/p8-recipe.txt` / `p9-recipe.txt` | p7 + 上述（p7 不动，在盘四件仍可逐字节复现） | — |
| `reports/artifacts/uefi-20261106R8-vsstop35/` | p8 构建（FD + manifest + build.log，35+1 补丁全绿） | `SM8750_EFI.fd 6a8b4162…a73f4407` |
| `reports/artifacts/uefi-20261106R9-gateout/` | p9 构建 | `SM8750_EFI.fd f67af2fe…1a54155` |
| `out/r21-sbstop-p8/` | `uefi-preamble8-r1.img` + `p8-m3-stop{27,28,34,35,36,37,38}.img` | preamble `e7708221…f6eec5` |
| `out/r21-sbstop-p9/` | `uefi-preamble9-r1.img` + `p9-m3-stop{18,19,27,28,35,36,37,38}.img` + `p9-s26-pb3.img` | preamble `ceee8d1a…211713`；stop27 `b36ebcb9…542b94`；stop36 `f50bea42…9b0986`；stop37 `8bb8c56b…cee48c` |

**归档口径**：这两个 `reports/artifacts/uefi-20261106R{8,9}-*/` 只入库**复现必需件**
（`SM8750_EFI.fd` + `BootShim.bin` + `manifest.txt` + `build.log` + `SHA256SUMS`，共约 3.6 MB/个）；
`payload-v2aligned*` / `kernel.bin` / `lenovo-y700g4-v3.img` / `uefi-v0.img`（约 11 MB/个、全部可由 FD 重新生成）
**故意不入库**——`uefi-r21-p7-ladder.sh` 的 repack 只需要前两个文件。

脚本侧（同时修掉「活线件不可再生」的老账）：`scripts/uefi-r21-p7-ladder.sh` 新增
`PFX`（世代前缀）/`BUILD_ARCHIVE`（构建目录落持久位）两个开关；`--verify` 在 p7 世代仍 **rc=0**（回归通过）。

## 4. 上机排产（4 发，1 次断电；全部 `fastboot boot`，零写盘）

前提：板子接 USB；崩一次要**物理断电/开机**（不是看门狗自复位，用户 11-06 明确更正）。

```bash
# 0) 进 ABL：Linux 侧 `eldroid-bootctl reboot bootloader`；Android 侧 `adb reboot bootloader`
fastboot devices                                # 记 ABL 序列号
fastboot boot out/r21-sbstop-p9/uefi-preamble9-r1.img      # ~11.6 s，UEFI 侧 fastboot ~13 s 后出现
fastboot devices                                # 应出现 UEFI 序列号 51318dc0
# 1) 尾段：不经 out: 的档 —— 只测 MarkPtnActive
timeout -k 5 45 fastboot -s 51318dc0 boot out/r21-sbstop-p9/p9-m3-stop35.img
# 2) out: 块入口（写之前）
timeout -k 5 45 fastboot -s 51318dc0 boot out/r21-sbstop-p9/p9-m3-stop36.img
# 3) ★判决发：= p7 里崩的那一点，唯一变量 = 诊断写已被门控
timeout -k 5 45 fastboot -s 51318dc0 boot out/r21-sbstop-p9/p9-m3-stop27.img
# 4) 单变量反证：同一点、把写开回来（mode 1）—— 崩 ⇒ 该写点就是凶手（1 次断电）
timeout -k 5 45 fastboot -s 51318dc0 boot out/r21-sbstop-p9/p9-m3-stop37.img   # 需 mode 1 件，见下
```

**第 4 发要 mode 1 件**：`STAGES="37" PROBE=1 PFX=p9m1 … --mkimg-only`（秒级，用归档 p9 构建目录 repack，
无需重建）。判据表：

| 发 | 档 | 预期若「诊断写是凶手」 | 预期若「`MarkPtnActive` 是凶手」 |
|---|---|---|---|
| 1 | 35 / mode 3 | `diag st=Aborted last=[vs-35]` | 无应答（崩，需断电） |
| 2 | 36 / mode 3 | `last=[vs-36]` | 不适用 |
| 3 | 27 / mode 3 | `last=[vs-27]` 或继续往下（28…） | 无应答 |
| 4 | 37 / mode 1 | 无应答（崩，断电 1 次） | 不适用 |

- 1/2/3 都回话 ⇒ 尾段全部通过，窗口搬到 `28` 之后（下一段 = `18/19` 等，p9 已备 `stop18/19` 件）。
- 2 回话、3 崩 ⇒ 门控没起作用（回去查 `SbProbeMode` 是否被 `CmdBoot` 重解析覆盖）。
- 1 崩 ⇒ `MarkPtnActive` 定案，转读它的 `StrStr`/属性循环（注意本树 GPT 写回已被 `IsUpdatePartitionAttributes()` 关掉）。

顺带（同一固件会话内，不额外断电）：`p9-m3-stop{18,19,28}` 可用 `sbprobe=3` 把
11-05 那两条「18/19 崩」在**新通道**下重测一遍（旧判据是 mode 0 时代、已被 `PITFALLS #514` 降级）。

## 5. 未做 / 不做

- **未上机**：板子未连接，本轮的判据一律「未证实」。本文任何 §4 的表格都是**排产**，不是结果。
- 不做：`FbConFlush()` 的整块 cache 维护判别（被 mode 3 绕过，等尾段收口后再决定是否单独立项）。
- 不做：恢复屏显通道（要先把绘制限制在实测可写窗口 ≤448 KiB，或先修 `FbConScrollUp()` 的 16 bit 搬 32bpp）。

## 6. 复现

```bash
cd ~/y700-elden
# 重建 p8 / p9（~2.5 min/次；FD 不比 sha，见 PITFALLS #510）
PFX=p8 RECIPE=$PWD/patches/uefi/p8-recipe.txt OUTDIR=$PWD/out/r21-sbstop-p8 \
  STAGES="35 36 37 38 27 34 28" PROBE=3 \
  BUILD_ARCHIVE=$PWD/reports/artifacts/uefi-20261106R8-vsstop35 \
  scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild
PFX=p9 RECIPE=$PWD/patches/uefi/p9-recipe.txt OUTDIR=$PWD/out/r21-sbstop-p9 \
  STAGES="18 19 26 27 28 35 36 37 38" PROBE=3 \
  BUILD_ARCHIVE=$PWD/reports/artifacts/uefi-20261106R9-gateout \
  scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild
# 指令级核对（门控是否真进二进制）
llvm-objdump -d --no-show-raw-insn \
  build/uefi-woa-prep/repos/7-mu-lenovo/Build/PakalaPkg/RELEASE_CLANGPDB/AARCH64/QcomModulePkg/Application/LinuxLoader/LinuxLoader/OUTPUT/LinuxLoader.efi \
  | grep -nE 'cmp\s+w[0-9]+, #0x2[3-6]|ldr\s+w8, \[x27, #0x63c\]'
```
