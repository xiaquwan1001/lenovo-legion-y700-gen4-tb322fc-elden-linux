# UEFI 线 2026-11-06 正文：探针失效（10 发作废）、崩溃真因 = 屏显写穿、新通道 `sbprobe=3`

> 会话记录：`TASKS/sessions/2026-11-06-UEFI探针失效与帧缓冲写穿.md`
> 坑：`PITFALLS #514/#515/#516`（`PITFALLS/sessions/167-探针全局跨命令残留与屏显写穿与假回话.md`）
> 上游状态：`reports/uefi-screenlog-crash-20261105.md` §10–§12 **作废**（已加作废头）
> 设备动作：零写盘 34 发（`fastboot boot`），用户物理断电 6 次（崩一次一次，非看门狗）

## 0. 三条结论（先数字）

1. **11-05 夜 10 发全部无效**：`VS_STOP(16..25)` 判的全局 `SbStopStage` 唯一赋值点在 `BootLinux()`，
   而 `LoadImageAndAuth()` 先被调用 ⇒ 探针恒不命中 ⇒ 那 10 发 = 对照组。
2. **崩溃元凶 = `SerialPortWrite`（帧缓冲控制台）**，不是 `gRT->SetVariable`：
   `sbstop=26 sbprobe=2`（静默）→ `vs-26` 存活；`sbprobe=1`（只写屏）→ 崩。
3. **机制**：`splash_region` 声明 43 MiB / 实测只有 ~448 KiB 可安全写 / `SCALE_FACTOR 3` 下一行
   文字 274 176 B ⇒ 只装 ~1.6 行 ⇒ 屏显把帧缓冲写穿，表现为「回话一档、下一档必崩」。

## 1. 修好探针后的首批有效判据

| 档 | 件 | 结果 |
|---|---|---|
| 0 | `p2-stop0` | `diag st=Success last=[entry]`，随后 `product: sun` |
| 16 | `p2-stop16` | `diag st=Aborted last=[vs-16]` |
| 17 | `p3-stop17` | `diag st=Aborted last=[vs-17]` |
| 18 | `p3-stop18` | 崩（`Booting FAILED (usb_read failed: No such device)`） |
| 19 | `p2-stop19` / `p3-stop19` | 崩（×2） |

⇒ 窗口 = (`VS_STOP(17)`, `VS_STOP(18)`)。

## 2. 反汇编把「空白区间」变成「一次 SbVProbe」

`LinuxLoader.efi`（`LoadImageAndAuth` = `0x83cc`，`SbVProbe` = `0x9ed8`）：

```
8424: bl  WaitForFlashFinished
8428: ldr w8,[SbStopStage]; cmp w8,#0x11      <- VS_STOP(17)
8450: ldrb w2,[x19,#1]; ldrb w1,[x19]
8458: adrp x0,0x2b000; add x0,x0,#0xc0
8460: bl  SbVProbe                            <- SbVProbe("[V] ms=%d rec=%d")
8464: ldr w21,[SbStopStage]; cmp w21,#0x1a    <- VS_STOP(26)
```

同时发现 `if (Info == NULL)` 已被编译器删掉（我们入口的解析块先解引用了 `Info`）——
源码阅读会得出「这段没有代码」的错误结论，必须看反汇编。

## 3. 单变量判别（`sbprobe` 正交令牌）

| 件 | 结果 | 判读 |
|---|---|---|
| `sbstop=26 sbprobe=2` | `vs-26`，2 s，`product: sun` | 不写屏就不崩 |
| `sbstop=26 sbprobe=1` | 崩（40 s 超时、无 diag） | 只写屏就崩 ⇒ 元凶 = `SerialPortWrite` |

R5 的 `sbstop=9X` 设计有缺陷（关探针同时取消停机点 ⇒ 流程进 `BootLinux`，那里有自己的
`SbBootProbe` 与既有 `ShutdownUefiBootServices` 崩溃）⇒ 必须用正交令牌才能归因。

## 4. 屏显预算（为什么「写屏」会崩）

| 量 | 值 | 来源 |
|---|---|---|
| `Display Reserved` / DT `splash_region` | `0xFC800000` + `0x02B00000`（43 MiB 声明） | `PlatformMemoryMapLib.c:35`、实机 DT |
| 面板 | 1904×3040@32bpp | 实机 `/sys/class/drm/*/modes`、`PcdsFixedAtBuild.dsc.inc` |
| 可安全写 | ~448 KiB | `PITFALLS #492` |
| 每行文字（scale 3） | 36 行像素 × 1904 × 4 = 274 176 B | `FbConPutCharWithFactor` |
| 可容纳行数 | **~1.6** | 448 KiB ÷ 274 KiB |

未单独判别的第二嫌疑：每换行 `FbConFlush()` 对整块 22.08 MiB 做 `WriteBackInvalidateDataCacheRange`。
另记 `FbConScrollUp()` 用 `unsigned short *` 搬 32bpp 缓冲（只搬一半字节、行宽错位）。

## 5. 新通道 `sbprobe=3` 与重推后的窗口

`sbprobe=3` = 只更新 `SbLastMark`（不写帧缓冲、不写 NV 变量）；标记经 fastboot 响应
`diag st=%r last=[%a]` 回宿主。指令级核查：`0x8464 csel`（≤3 才采用）→ `0x8468 str [SbProbeMode]`；
`SbVProbe` 内 `0x9f30 cmp w8,#0x1` + `0x9f34 b.hi`。

| 档 | 语义 | 结果 |
|---|---|---|
| 26 | 分区名块之前 | `vs-26` ✅ |
| 30 | `FindBootableSlot` 入口 | `vs-30` ✅ |
| 31 | `GetActiveSlot` 之后 | `vs-31` ✅ |
| 32 | `GetBootPartitionEntry` 之后 | `vs-32` ✅ |
| 33 | `ValidateSlotGuids` 之前 | `vs-33` ✅ |
| 34 | `MarkPtnActive` 之前 | `vs-34` ✅ |
| 27 | `GUARD (FindBootableSlot (…))` 之后 | **崩** |
| 7 | 跳内核前（另一路径） | 崩（与上表自洽） |

⇒ 窗口 = (`VS_STOP(34)`, `VS_STOP(27)`)。这段只剩
`MarkPtnActive (BootableSlot->Suffix)` + `out:` 收尾 +
`IsSuffixEmpty` / `IsDynamicPartitionSupport` / `StrnCpyS` / `StrnCatS`。
**首要嫌疑 = `MarkPtnActive()`**（槽位属性写回路径，`PITFALLS #484` 同片区域），是唯一未被覆盖的大调用。

## 6. 复现步骤（全部零写盘）

```bash
cd ~/y700-elden
# 1) ABL 侧载 UEFI（preamble7 = R7 mode-3 构建）
fastboot boot out/r21-sbstop/uefi-preamble7-r1.img          # ~11.6 s，UEFI fastboot 约 13 s 出现
# 2) UEFI 侧逐档打（回话 1–2 s；崩了要物理断电）
fastboot -s 51318dc0 boot out/r21-sbstop/p7-m3-stop34.img  # 判据 diag st=Aborted last=[vs-34]
fastboot -s 51318dc0 boot out/r21-sbstop/p7-m3-stop27.img  # 无应答 = 崩
```

判据：**必须要求真的出现 `diag st=` 字符串**（`rc=1` 也可能是本地读文件失败，见 `PITFALLS #516`）。

## 7. 下一步

1. 加探针 35（`MarkPtnActive()` 之后）单发定案；崩则读它的 GPT 属性写回路径。
2. 若要恢复屏显通道：把绘制/刷新限制在实测可写窗口内（≤448 KiB），或先修 `FbConScrollUp()`。
3. 单独判别 `FbConFlush()` 的整块 cache 维护是否也会触发异常。
