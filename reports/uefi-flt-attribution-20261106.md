# 2026-11-06 夜·第二轮：崩溃 PC 归因成功 —— **PC 在 `LinuxLoader` 自己的 `SerialPortWrite` 里**，「第三方二进制驱动」判断作废

> 两发零写盘（p25 / p26），把 `Synchronous Exception` 的 PC 从「一个数字」变成「模块 + 函数」。
> 权威判据：屏上单行 `[K] FLT pc=cfeb5c84 img=- b=cfea2000 z=45000 o=13c84`。

## 1. 两发做了什么

| 发 | 件 | 结果 |
|---|---|---|
| p25 | `20261106R17-faulthandler-image`：把 Mu `DefaultExceptionHandlerLib` 里**被 `DEBUG_CODE` 编掉**的 `GetImageName(ELR,…)` 打印搬出 RELEASE 路径，命中就打一行并 `CpuDeadLoop`（不打印递归 dump） | **一次都没打出来**：屏上仍是 `Synchronous Exception at 0xCFE94C84` + 递归 dump |
| p26 | `20261106R18-rehook-exception`：在 BDS `StartImage(LinuxLoader)` 之前 `LocateProtocol(gEfiCpuArchProtocolGuid)` → `Cpu->RegisterInterruptHandler(EXCEPT_AARCH64_SYNCHRONOUS_EXCEPTIONS, DefaultExceptionHandler)` | **打出来了**：`[K] FLT pc=cfeb5c84 img=- b=cfea2000 z=45000 o=13c84` |

**p25 失败的原因（主机侧定因）**：本平台用的是**预编译**的 `Binaries/ArmPkg/Drivers/CpuDxe/CpuDxe.efi`，它自带一份
`DefaultExceptionHandlerLib`（字符串 `Exception at 0x%016lx` 全树只出现在它和 `DxeCore.efi` 里），且在 DxeCore **之后**注册
⇒ 覆盖了我们编进 DxeCore 的那份。**改树内 lib 对运行期无效，必须晚注册一次**（`RegisterInterruptHandler` 是覆盖语义）。

## 2. 归因（三步收敛，全部可在主机复算）

1. **命中区间**（屏上）：`pc=0xCFEB5C84`，`b=0xCFEA2000`，`z=0x45000`，`o=0x13C84`；`img=-` = 该映像 PE 里没有 Pdb 指针。
2. **`z=0x45000` + 无 Pdb ⇒ 唯一命中 `LinuxLoader`**：全树 `SizeOfImage == 0x45000` 的 .efi 只有
   `Build/…/QcomModulePkg/Application/LinuxLoader/{OUTPUT,DEBUG}/LinuxLoader.efi`（以及 FV 里那份同名拷贝）；
   这也解释了历史上屏上那行 `[I]? base=… size=0x45000`（名字是 `?` 因为 PdbPointer 为 NULL）。
3. **`o=0x13C84` 落在哪个函数**：`LinuxLoader.map` 里 `00013bd8 000000d0 SerialPortWrite`（下一个符号 `FastbootFail` 在 `0x13CA8`）
   ⇒ **RVA `0x13C84` ∈ `SerialPortWrite`，函数内偏移 `+0xAC`（函数长 `0xD0`）**。

⇒ **崩在我们自己的屏显写函数里**，不是第三方二进制 DXE 驱动。

## 3. 三条被推翻/被修正的结论

- ❌ **「崩在第三方二进制 DXE 驱动（USB redriver/Usbfn 一族）」** —— 2026-11-06 深夜块的那个判断基于**历史屏上的** `LinuxLoader base=0xCFEB2000`；
  本次上机的实际 base 是 **`0xCFEA2000`**（DxeCore/BdsDxe 因为 R17/R18 长大，映像分配整体下移 `0x1000`）。
  用旧 base 减出来的 `PC-LinuxLoaderBase ≈ -0x1C000` 纯属假象。**PC 归属必须用同一次上机的装载表**。
- ✅ **「崩溃元凶 = `SerialPortWrite` 帧缓冲写穿」（11-06 上午那条）成立** —— 但**门控没做完**：
  `sbprobe` 只罩住了 `SbVProbe`/`SbBootProbe`；`20261104R15-noavbprobe`（no-AVB 路径的可见串口探针）、
  `20261104R2-slow-serial`、`20261106R5/R6`（banner）这些 `SerialPortWrite` 调用点仍在真路径上无条件执行。
- ✅ **`[K] JUMP-BANNER` 永远不出现的直接原因** = 打 banner 的那次 `SerialPortWrite` 自己先崩（不是「跳内核失败」）。

## 4. 一条必须记住的取证限制

EDK2 AArch64 的 `.text` 里有**被 DIR64 重定位的字面量槽**，所以**对未重定位的 `.efi` 反汇编看到的指令不可信**：
本轮在文件视角下 `0x13C84` 是 `ldr x8,[x8]`（基址 `0x8`），那是重定位前的字面量，不是运行期指令。
⇒ 只能靠 **`.map` 的符号区间**判函数归属；要判到指令级，需要先按 `.reloc` 把 DIR64 应用一遍再反汇编。

## 5. 下一步（p27 的设计已由本轮结果锁定）

不必再找「凶手模块」，直接修屏显写通道：

1. **帧缓冲控制台加硬边界**：`FbConPutCharWithFactor` 算出像素地址后，若超过安全区（`splash_region` 只有前 ~448 KiB 可写，
   `PITFALLS #492/#515`）就**回卷到 `y=0`**（或直接丢弃该字符），保证任何调用方都不可能越界写。
   这是结构性修复：之后不管谁打印都不会把固件打死。
2. **把真路径上剩余的 `SerialPortWrite` 全部纳入 `SbProbeMode` 门控**（先枚举调用点：`SbVProbe`/`SbBootProbe` 之外的 R15/R2/banner/`out:`）。
3. **异常归因行补 `ESR`/`FAR`**（本轮 found 分支只打了 PC/base/size/off，丢掉了「写穿 vs 野指针」的判别依据）。
4. 判据：先看 `[K] JUMP-BANNER` 是否出现（出现 ⇒ 跳内核调用真的走到了），再看内核是否真的接管
   （宿主侧 `fastboot boot` 后 USB 的行为 + 后续 Linux 起来与否）。

## 6. 附件/证据

- 判据行：屏上 `[K] FLT pc=cfeb5c84 img=- b=cfea2000 z=45000 o=13c84`（p26）
- 构建：`reports/artifacts/uefi-20261106R17-faulthandler/`（FD `528d86c2…`）、`reports/artifacts/uefi-20261106R18-rehook/`
- 镜像：`out/r21-sbstop-p25/uefi-preamble25-r1.img`（`5beff362…`）、`out/r21-sbstop-p26/uefi-preamble26-r1.img`（`b7e0802b…`）
- 补丁：`patches/uefi/20261106R17-faulthandler-image/`、`patches/uefi/20261106R18-rehook-exception/`；配方 `p25/p26-recipe.txt`
- 坑：`PITFALLS #499`（预编译 ArmPkg 件使源码补丁失效 + 本次的晚注册修法）、新增 `#527/#528/#529`
