# UEFI p38：把「EB 之后专用」的转储改成真·无 boot service（静态定案 + 一发待上机）

> 线：G1-29（UEFI 间接引导）。承接 `reports/uefi-p37-logfs-20261107.md` §4。
> 本轮 = **纯主机侧**（改补丁 + 重建 + 反汇编复核），**未上机**（设备当时未连接）。
> 产物：`patches/uefi/20261107R33-true-nobs/`、`patches/uefi/p38-recipe.txt`、
> `reports/artifacts/uefi-20261107R33-p38/`（FD + 构建日志 + `obj/LinuxLoader.{efi,map}`）、
> `out/r21-sbstop-p38/uefi-preamble38-r1.img`（sha256 `0e2bddbd…272badad`，67 219 456 B）。
> 独立复核：`reports/uefi-p38-static-verify-20261107.md`（verify-worker，只读反汇编复核，PASS）。

---

## 0. 一句话结论

p37 的「EB 之后立刻死」**最可能是我们自己的取证探针自杀**：`R32` 那条号称「EB 之后专用、不碰 gBS」的
转储链里，`SbDumpLogNoBs()` 仍有两次 `AllocatePool`/`FreePool`、`SbWriteLogWindowNoBs()` 又一次
`AllocatePool`/`FreePool`；EB 之后 `gBS` 已失效 ⇒ `gBS->AllocatePool`（`+0x40`）取出 0 ⇒ `blr x8`
跳 **pc=0**，与 p37 屏上 `[K] FLT pc=00000000 esr=86000007` 同形，也解释了「`posteb` 永远不出现」。
`R33` 把该路径改成**静态缓冲 + 内存拷贝**，并顺手修掉同一函数里漏改的 `Lba` 单位（`R32` 只修了
`SbWriteLogWindow`）。静态复核已 PASS；**判据仍待一发上机**。

诚实标注两处未闭合：
1. p37 帧里 `x30 = LinuxLoader + 0x4B28` 落在 `BootLinux + 0xA0`（= `CheckAndSetVmData` 里的
   `AllocatePool`），与「`[K] dtb` 已在同函数 `+0x52C` 打印」矛盾 ⇒ 要么**相片转录的寄存器读错**，
   要么 `BootLinux` 被重入。`R33` 在入口加了无门控的 `[K] BL-in` + 一次 `tag=early` 落盘来分开这两种。
2. `BlkIo->WriteBlocks` 是固件里的实现，EB 之后还能不能用只能**上机证伪**
   （`[K] post-dump-ok` 出现即证）。

---

## 1. 静态定案（可复算）

### 1.1 缺陷位置

| 文件 | 符号 | 问题 |
|---|---|---|
| `BootLib/BootLinux.c` | `SbDumpLogNoBs()` | `AllocatePool(8192)` + `AllocatePool(RecLen)` + 两次 `FreePool` |
| `BootLib/LinuxLoaderLib.c` | `SbWriteLogWindowNoBs()` | `AllocatePool(SB_LOG_WINDOW)` + `FreePool`；且 `Base` 是字节偏移却当 LBA 传 |

调用点：`BootLinux()` 在 `ShutdownUefiBootServices()` 返回后立刻调 `SbDumpLogNoBs("posteb")`
⇒ 崩溃点在 EB 之后**第一条**用到 boot service 的指令上。

p37 的反汇编旁证（p36 构建）：`BootLinux` 内 `adrp x8,<gBS页>; ldr x8,[x8,#0xa10];
ldr x8,[x8,#0x40]; blr x8`，`esr=0x86000007` = EC 0x21（IABT from lower EL）+ IFSC 0x07
（translation fault level 3）⇒ 典型「间接调用到未映射地址 0」。

### 1.2 `R33` 改了什么

1. `SbDumpLogNoBs()`：`STATIC UINT8 m_SbNoBsRing[8192]` / `m_SbNoBsRec[SB_LOG_WINDOW-64]`。
2. `SbWriteLogWindowNoBs()`：`STATIC UINT8 m_SbNoBsBuf[SB_LOG_WINDOW]`，
   `Base = LastBlock + 1 - (SB_LOG_WINDOW / BlockSize)`。
3. 新增标记（全部同时进环，EB 后仍可落盘）：
   - `[K] BL-in`（`BootLinux` 入口，无门控）+ `SbDumpLog("early")`；
   - `[K] BL-vm=<0|1> ok`（`CheckAndSetVmData` 之后）；
   - `[K] gbs=… ap=… eb=… fp=…`（EB 前，屏 + 环）；
   - `ShutdownUefiBootServices()` 内紧贴调用两侧：`[K] EBC-call` / `[K] EBC-ret0|ret!`（**只写内存**，
     GetMemoryMap 与 ExitBootServices 之间不做任何会改内存图的事）；
   - `[K] post gbs=… ap=…`（EB 后**带 `cbz` 守卫的纯内存读**）；
   - `[K] post-dump-ok`（转储返回后的环内标记）。

### 1.3 复核结果（verify-worker 独立反汇编，编排者已抽样复跑）

| 判据 | 结果 | 证据 |
|---|---|---|
| EB 调用点 | `0x5a9c bl 0x1630c`（全镜像唯一） | `ShutdownUefiBootServices` 内真 EB 在 `0x164f4 blr x8`，`x8 = [gBS+0xE8]`（编排者已独立复跑该 12 条指令） |
| EB 后到跳内核前 | **0 处 boot service 调用** | 区间内唯一 gBS 触点是 `0x5b2c ldr x3,[x26,#0xa90]` → `0x5b30 cbz` → `0x5b34 ldr x4,[x3,#0x40]`，只作打印实参 |
| `SbDumpLogNoBs`（`0x47f4–0x49c8`） | gBS 0 处、`AllocatePool/FreePool` 0 处 | `bl` 只有 `AsciiSPrint`/`CopyMem`；唯一间接调用是 `m_SbLogBlkIo+0x20`(WriteBlocks) |
| 静态缓冲 | `0x2f470`(Ring) / `0x31470`(Rec) / `0x39680`(Buf) | 全镜像引用扫描；`Buf` 只被 `SbDumpLogNoBs` 用 |
| 镜像 ↔ 构建件 | 载荷 gz `a5c8994e…` = `payload-v2aligned.bin.gz`；载荷 `[192:]` sha = 构建 FD `15678b24…` | 三方 sha 链一致 |

**已知残留（不判失败，上机见分晓）**：EB 后仍走 `gRT`（`0x5e60`、`0xac7c`、`0xacb0`，物理寻址合法）；
`BlkIo->WriteBlocks` 的实现不在本镜像；arm32 出口用 SCM 协议指针；EB 失败会 `CpuPause` 死循环
（别误判成内核崩）。

---

## 2. 上机单（p38，一发零写盘）

```bash
# 前置：设备在 Linux（adb/ssh 可用）；先说清「崩了要长按 12 s 物理断电」由用户执行
ssh <device> 'sudo eldroid-bootctl reboot bootloader'          # ≤10 s 应出现 fastboot devices
fastboot devices                                              # 期望 HA2EXB0E
fastboot boot out/r21-sbstop-p38/uefi-preamble38-r1.img        # Sending/Booting OKAY
sleep 45                                                       # 崩/活都等够
# 现场判据（用户看屏）：出现 [K] EB-OK / [K] JUMP-BANNER，或 [K] FLT …（记录 pc/esr 与 x30）
# 恢复：长按断电 → 短按开机 → boot_b 回 Linux（vk185-adsp）
```

崩后读回（**不要用 `oem sbread`**，一读打死 USB 端点 —— `PITFALLS #537`）：

```bash
scripts/uefi-logfs-read.py --ssh root@192.168.7.1 --len 0x4000      # 默认 off=0x7FC000（分区尾 16 KiB）
# 等价手打：dd if=/dev/disk/by-partlabel/logfs bs=1 skip=8372224 count=16384 status=none
```

### 判读表

| logfs 里的 `tag=` | 说明 | 下一步 |
|---|---|---|
| `early` | 崩在 `BootLinux` 入口 → EB 之间（则 p37 的 `x30=+0xA0` 是**真的**） | 转查 `CheckAndSetVmData`/`IsVmEnabled` 路线（Gunyah 残留），不是 EB |
| `preeb` | 崩在 EB 调用本身或紧随其后（看记录末尾是否已有 `[K] EBC-call`） | 有 `EBC-call` 无 `EBC-ret` ⇒ 崩在 `ExitBootServices` 内部 |
| `posteb` | **修好了**：EB 后落盘成功 | 看 `[K] post gbs/ap` 与 `[K] EBC-ret0`；继续盯「跳内核」段的判据 |
| 什么都没有 | 连 `early` 都没落盘 | 先验 `SbDumpLog("early")` 的 LBA 口径（本机 logfs 窗口基址是否仍 0x7FC000） |

止损：沿用 §7 既有线 —— p37 之后**再 3 发无实质进展即收口**；本轮（p38）为第 2 发。

---

## 3. 纪律补充

- 「某阶段不可用的服务」**不要凭函数名相信**：`NoBs` 里照样可以有 `AllocatePool`。
  写这类路径前先 `grep -n "AllocatePool\|FreePool\|gBS->"` 把符号扫一遍（`PITFALLS #543`）。
- 同族的「单位/口径修正」要**按函数逐个改**：`R32` 修了 `SbWriteLogWindow` 的 LBA，
  漏了 `SbWriteLogWindowNoBs`，等于没修。
- 构建世代：`PFX=p38 RECIPE=patches/uefi/p38-recipe.txt BUILD_ARCHIVE=reports/artifacts/uefi-20261107R33-p38 \
  OUTDIR=out/r21-sbstop-p38 scripts/uefi-r21-p7-ladder.sh --mkimg-only --rebuild`（本次 ~3 min，
  `assert-ok: header v2, text_offset=0, flags=0xa`）。
