# UEFI 线（G1-29）**首次上机全场**：从 `VS_STOP` 尾段一路走到跳内核（2026-11-06 傍晚）

> 状态：**已上机取证**（零写盘，全程只用 `fastboot boot`）。本文只写设备侧判据；主机侧静态分析见
> `reports/uefi-vsstop35-tail-static-20261106.md`。所有结论都能从下面的 `results.tsv` 与逐发日志复算。

- 日期 2026-11-06 14:45–17:20（用户 3 次物理断电、2 次软件换会话）
- 设备 U2（`HA2EXB0E`，ABL fastboot）/ UEFI 侧 `51318dc0`
- 原始判据：`reports/artifacts/uefi-p9-onboard-20261106/results.tsv` + 每发 `*.log`

## 0. 一页结论（数字）

1. **门控那条屏显写之后，`(VS_STOP(34), VS_STOP(27))` 窗口整个消失**：p9（`sbprobe=3`）
   `vs-18/19/26/27/28/35/36/37/38` **九档全回话**；同一点在 p7（无门控）是崩的 ⇒
   **「屏显写穿」定案为那次崩溃的唯一变量**（单变量差异 = `out:` 那条 `SerialPortWrite` 是否受 `SbProbeMode` 管）。
2. **BootLinux 准备段全通**：`SB_STOP 1..6` 六档全回话 ⇒ LoadImageAndAuth → 参数/DTB/ramdisk 装载 → 释放资源 全部无异常。
3. **`SB_STOP(7)`/`(41)`/`(42)` 的「无应答」不是崩溃**：屏上刷 `Usbfn is not enabled` / `USB cable not attached`
   ⇒ `ShutdownUefiBootServices()` 真的把 USB 设备栈拆了，**宿主侧判据在 EB 之后天然失效**。这是本轮最重要的一条
   判据更正 —— 历史上「`ShutdownUefiBootServices` 崩溃」的读法**至少部分是这条假象**。
4. **真启动件（p11/p12，默认 `SbProbeMode=3` + 去掉 R18 的 `CpuDeadLoop`）首次被放行跳内核**：
   连打两发现在唯一现象 = **递归 dump 循环**，用户报异常 PC = `0x00000000cfe98c38`
   ⇒ 落在 **`DXE Heap`（`0xB90C0000 + 0x1D500000`，`PlatformMemoryMapLib.c:34`）内**，
   而 `Kernel` 区是 `0xA8000000 + 0x10000000` ⇒ **「跳进堆」**（与 2026-11-05 那条旧观测同型）。
   ⇒ 卡点已从「AVB/分区/装载」搬到**「EB 之后 → 跳内核」这一小段**。
5. 新发现的**会话污染**：同一固件会话里连打「stage ≥ 40」的件之后，后续每条 `boot` 都退化成
   `diag st=Load Error last=[[K] ldt=Load Error]`（`LoadAddrAndDTUpdate` → `UpdateDeviceTree` 失败），
   连原本好用的 `stop40` 也一起坏 ⇒ **EB 之后的档位每个会话只能打一发**。

## 1. 逐发判据（`results.tsv` 原文摘）

| 件 | 结果 |
|---|---|
| p9 `vs-35/36/27/28/38/26/18/19`（mode 3） | 全 `diag st=Aborted last=[vs-N]`，每发 1–2 s |
| p9 `stop=7` | 无应答（后确诊 = EB 后不可回话，非崩溃） |
| p9 `stop=1..6` | 全 `diag st=Aborted last=[[K] stop=N]` |
| p10 `stop=42`（`PreparePlatformHardware` 后） | 无应答 |
| p10 `stop=40`（`ShutdownUefiBootServices` 前） | **回话** `last=[[K] stop=40]` |
| p10 `stop=41`（EB 之后） | 无应答；**屏上刷 `Usbfn is not enabled`** |
| 同会话再打 41/40（3+1 发） | 全退化 `diag st=Load Error last=[[K] ldt=Load Error]` |
| 换会话单发 41（fresh） | 无应答 + `Usbfn is not enabled` 刷屏（复现） |
| p11 真启动 `out/boot-elden-vk172.img`（无令牌） | 宿主 `rc=124`；屏上**递归 dump**；USB 仍枚举 `045e:0c2f` 但 `getvar`/`reboot` 全无响应 |
| p12 真启动（跳内核前强制一行 `[K] JUMP-BANNER`） | 同上（banner 是否出现待用户目视确认） |

## 2. 三次判据更正（都写进了 `PITFALLS`）

| 旧读法 | 新判据 |
|---|---|
| `stop=7/41/42` 无应答 ⇒ 崩在 `ShutdownUefiBootServices` | **EB 成功后 USB 设备栈被拆 ⇒ 回不了话**；屏上 `Usbfn is not enabled` 是证据不是崩溃 |
| `MarkPtnActive()` 是 34→27 窗口的首要嫌疑 | 单变量已定案 = `out:` 那条未门控诊断写（`PITFALLS #522`）；关掉它以后 27/28/35..38 全通 |
| 同一固件会话可以连打多档（11-05 时代确实可以） | **stage ≥ 40 之后不行**：后续一律 `Load Error`（`ldt` 失败），必须换会话 |

## 3. 异常 PC 的含义（`0xcfe98c38`）

- `PlatformMemoryMapLib.c` 的分区表（本机在机值，普适到 TB322FC）：

| 区 | 基址 + 长 | 覆盖 `0xcfe98c38`? |
|---|---|---|
| `Kernel` | `0xA8000000 + 0x10000000` | ❌ |
| `DXE Heap` | `0xB90C0000 + 0x1D500000`（→ `0xD65C0000`） | ✅ |
| `Display Reserved` | `0xFC800000 + 0x02B00000` | ❌ |

⇒ 异常发生在**堆内执行**：不是「内核代码跑飞」，而是 **EB 之后某条函数指针/返回地址已被破坏，
或者跳转目标本身解析成了堆地址**。这与 2026-11-05 记录（`ELR` 落在 DXE heap = 「跳进堆」）同一形态，
但那次的嫌疑（`SbVProbe` 的 `SerialPortWrite`）已被本轮门控排除 ⇒ **新的第一嫌疑是
`PreparePlatformHardware()` / 跳转前的最后一段（`BootStatsSetTimeStamp`、`LinuxKernel` 调用约定）**。

## 4. 下一步（已排产，待设备重启后执行）

**p13 = p12 + `--scale 1`（一行文字从 274 KiB 降到 91 KiB ⇒ 屏上预算从 ~1.6 行变 ~4.8 行）+ 四行强制 banner**，
把 EB 之后的每一步都在屏上留一行（EB 之后宿主必然收不到东西，屏是唯一通道）：

1. `[K] A: pre-EB`（`ShutdownUefiBootServices()` 之前）
2. `[K] B: post-EB`（返回之后）
3. `[K] C: post-PPH`（`PreparePlatformHardware()` 之后）
4. `[K] D: JUMP`（`LinuxKernel()` 之前）

判据：**哪一行之后停**就是了。若 4 行都出现 ⇒ 故障在 `LinuxKernel()` 调用/进入本身（下一轮读
`LinuxKernel` 的调用约定：x0=DTB、MMU/DCache 关闭、`PreparePlatformHardware` 是否清了 `SCTLR` 等）。

同时（同一发可带上）：给 `PreparePlatformHardware()` 内部加 2–3 个 SB_* 变体 banner，若 C 行即停则直接进它。

**设备动作纪律**（本轮验证有效的换会话办法，不需要断电）：

```bash
fastboot -s 51318dc0 reboot bootloader      # UEFI → 复位；落 Linux 则 ssh → eldroid-bootctl reboot bootloader
fastboot -s HA2EXB0E boot out/r21-sbstop-p13/uefi-preamble13-r1.img   # ~11.6 s
```

只有「真启动件触发递归 dump」之后才需要**物理断电**（USB 端点已死，`reboot` 也进不去）。

## 5. 本轮设备动作账

| 动作 | 次数 |
|---|---|
| `fastboot boot` 载 UEFI preamble（ABL 侧） | 5 |
| `fastboot boot <stage/真启动件>`（UEFI 侧） | 26 |
| 用户物理断电/开机 | 3 |
| 软件换会话（`reboot bootloader` → Linux → `eldroid-bootctl`） | 2 |
| 写盘（flash/set_active/GPT/槽位） | **0** |
