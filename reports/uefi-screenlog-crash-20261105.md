# 屏上日志取证（2026-11-05 20:3x，用户拍屏 5 张）—— 崩溃点 = **DXE Heap 内的 ELR**

> 来源：用户在 20:3x 这一轮（control / 未改动 R21 件经 UEFI 侧 `fastboot boot`）拍到的屏上串口。
> 用途：把「崩溃落点」从猜变成可复算 —— 这批日志第一次给出了**模块装载基址表**与**崩溃 ELR**。

## 1. 决定性两行

```
[L] found=1 size=0x2C200
[I] ? base=00000000CFEB5000 size=00045000
[L] LoadImage=Success
usb_repeater_reset, core_num : 0x0        ← USB 设备栈重初始化
ssusb_phy_init_success lane: 0x0
Dev_Common_Speed: Dev Bus Speed: High, state 2
...
Synchronous Exception at 0x00000000CFE988F0
Recursive exception occurred while dumping the CPU state   ← ×N，死循环
```

## 2. 0xCFE988F0 落在哪 —— 复算

`Platforms/PakalaPkg/Device/lenovo-y700g4/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c`：

```c
{ "DXE Heap", 0xB90C0000, 0x1D500000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv, WRITE_BACK_XN },
```

⇒ DXE Heap = **[0xB90C0000, 0xD6610000)**，而 `0xCFE988F0` 在其内。

**结论：ELR 落在 DXE 堆里 ⇒ 控制流跳进了堆（坏函数指针 / 错误入口地址 / 已释放缓冲被当代码执行），
不是某个 DXE 模块自己的代码跑飞。** 与 2026-11-04 记的 `0xCFE99xxx` 是同一类（同区、同一现象），
当时「`DxeCore` 仅 111 KB、ELR 偏移超出本体」的换算也指向同一结论。

## 3. 崩溃时序（与源码对齐）

`Platforms/QcomModulePkg/Library/BootLib/BootLinux.c` 尾部：

```c
  Status = LoadAddrAndDTUpdate (Info, &BootParamlistPtr);   // SB_STOP(5) 在这之后
  FreeVerifiedBootResource (Info);                          // 释放 AVB/Ops/SlotData/VBCmdLine
  FreeBootLogoBltBuffer ();
  ...
  Status = ShutdownUefiBootServices ();                      // ⇒ 屏上的 usb_repeater_reset / Dev_Common_Speed
  ...
  LinuxKernel (DeviceTreeLoadAddr, 0, 0, 0);                 // 跳内核
```

屏上顺序「`LoadImage=Success` → USB 重初始化 → 同步异常」与「`FreeVerifiedBootResource` 之后紧接
`ShutdownUefiBootServices`」吻合。**可疑点（按优先级）**：

1. `FreeVerifiedBootResource()` 释放 `VBData/SlotData/VBCmdLine` 之后，后续仍解引用其中之一
   （`UpdateCmdLine` 已消费 `Info->VBCmdLine`，但 `BootParamlistPtr.FinalCmdLine` 的所有权/生命周期未验）；
2. `ShutdownUefiBootServices()` 之后仍调用 Boot Services 上的函数指针（堆里的 EFI_BOOT_SERVICES 或协议指针）；
3. 跳内核的入口地址取自被覆写的字段（`BootParamlistPtr.KernelLoadAddr` 类），拿成了堆地址。

三者都是「跳进堆」的同一临床表现，用**二分停机点**即可分辨（见 §4）。

## 4. 判据必须换：`diag` 回传在这段窗口里**结构性不可达**

崩溃伴随 USB 设备栈重初始化 ⇒ 端点 shutdown。宿主侧表现为
`fastboot devices` 仍列 `51318dc0`（描述符被缓存），但
`fastboot -s 51318dc0 getvar product` 报
`FAILED (reap_urb(0) failed: urb returned error: Cannot send after transport endpoint shutdown)`。
⇒ **凡崩在 `ShutdownUefiBootServices` 之后的档位，`FastbootFail("diag …")` 永远送不出去。**

替代判据（**仍然零拍照、零额外代码**）：

| 判据 | 含义 |
|---|---|
| 打完这一发 20 s 后 `getvar product` **仍有 `product:` 输出** | 该档位**没有崩**（`SB_STOP(n)` 的 `EFI_ABORTED` 路径跑完，固件还活着） |
| `getvar` 报 endpoint shutdown / 无输出 | **崩了** ⇒ 崩溃点在 n **之后**（含 n） |
| 屏上出现 `[K] stop=n` | 该档位命中（仅在需要精确定位时再看，属可选证据） |

即：**「崩不崩」本身就是宿主可判的**，不必依赖 `diag` 字符串；代价是每次崩都要**物理断电**（用户动作）。

## 5. 下一轮两发（各 1 次，崩了就断电）

| 发 | 命令 | 若 getvar 仍活 | 若 endpoint shutdown |
|---|---|---|---|
| A | `sbstop=5` | 5 档之后的 `FreeVerifiedBootResource`/`ShutdownUefiBootServices` 是嫌疑（§3.1/§3.2） | 崩在 5 之前 ⇒ 回到 3 → 4 二分 |
| B | `sbstop=6` | 崩溃在 6 之后 ⇒ 锁定 `FreeBootLogoBltBuffer`/`ShutdownUefiBootServices` | 崩溃就在 6 这一小段 ⇒ 直接查 `FreeVerifiedBootResource` 的释放后使用 |

## 6. 顺带记录（同一批日志）

- `ConnectionSts: Attach, Data Role: UFP (DEVICE Mode)` ⇒ UEFI 侧 USB device 模式成立（P1 的 USB 日志 gadget 有地基）。
- `usb_redriver Failed slave: 0x10` / `Failed to init i2c: 12` / 成片 `ERROR:NAK SAr:0x0E` + `Geni command not active`
  ⇒ Redriver（`usb_shared_wcd_*`）在这条路径上 I2C 全挂；不影响「USB 能枚举」，但**可能是 USB 重初始化那一瞬的次要干扰源**（第 3 点嫌疑时一并考虑）。
- `ButtonsDxeTest: Keypress SDAM data payload 3` ⇒ 按键栈确实起来了（之前没到这一步）。

---

## 7. 21:0x 决定性一发：`sbstop=0` 入口探针 —— 回传通路成立

新件 `out/uefi-20261105-diagentry-r1.img`（sha `6974296f…`，25 条 R21 补丁 + `patches/uefi/20261105-diagentry/`）：
`CmdBoot` 在 `SetBootDevImage()` **之前**、只要 cmdline 带 `sbstop=0` 就直接
`FastbootFail("diag st=Success last=[entry]")` 并 return。

```
$ fastboot -s 51318dc0 boot out/r21-sbstop/r21-stop0.img
Sending 'boot.img' (65624 KB)  OKAY [  1.494s]
Booting                        FAILED (remote: 'diag st=Success last=[entry]')
$ fastboot -s 51318dc0 getvar product
product: sun                    ← 固件仍应答（没崩）
```

**一发同时排除三件事**：
1. `SbParseStopStage()` 解析**成立**（令牌被正确读到）；
2. `FastbootFail()` 回传通路**成立**（宿主完整收到字符串）；
3. 探针之后固件**活着**（`getvar` 仍应答；且 `product: sun` 是 UEFI 侧 LinuxLoader 自报，
   与 ABL 的 `elden_prc_wifi` 区分开）。

## 8. 崩溃窗口收窄到 CmdBoot 内 4 步

`sbstop=1`（`BootLinux` 第一行 `SB_STOP(1)`，紧接 `SbBootProbe("[K] enter")`）**崩了**
（设备进递归 dump 循环，宿主端点 shutdown）。⇒ 崩溃在
**`CmdBoot` 入口 → `SbBootProbe("[K] enter")` 之前**，即下面 4 步之内：

```
SetBootDevImage()  →  Info.Images[] 装填 / PartitionHasMultiSlot()  →  ClearUnbootable()  →  LoadImageAndAuth()
```

下一发用细二分件 `out/uefi-20261105-finebisect-r1.img`（sha `47ba2cb2…`，
加 `patches/uefi/20261105-finebisect/`），四个只回话的停机点：

| 件 | 停机点 | 命中含义 |
|---|---|---|
| `fb-stop13.img` | `LoadImageAndAuth()` **之前** | 11/12 都不崩 ⇒ 崩在 `LoadImageAndAuth` 内部 |
| `fb-stop11.img` | `SetBootDevImage()` 之后 | 崩在 `SetBootDevImage` 或更早 |
| `fb-stop14.img` | `LoadImageAndAuth()` 返回之后 | 崩在 `BootLinux` 早段（`[K] enter` 前后） |
| `fb-stop12.img` | `ClearUnbootable()` 之后 | 崩在 `ClearUnbootable` 或 `PartitionHasMultiSlot` |

判据仍是宿主字符串：收到 `diag st=Success last=[<tag>]` ⇒ 该点之前不崩；无响应 ⇒ 崩在该点之前。
**每次"无响应"要一次物理断电**，所以按 13 → 11 → 14 顺序打，命中即止。
