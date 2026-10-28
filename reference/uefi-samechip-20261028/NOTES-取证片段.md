# 2026-10-28 取证片段（网络中断前已取得的内容，按原文抄录）

> 来源：`sunflower2333/mu_wide_platforms` main（2026-10-28 取件）。网络在本次取证后段
> （raw.githubusercontent.com TLS unexpected eof，直连与 127.0.0.1:7890 均 000）中断，
> 以下 4 个设备包的 `PcdsFixedAtBuild.dsc.inc` **只取到 grep 命中的显示相关行**，未取全文件。
> 全文件副本：`xiaomi-piano` 已在中断前完整取到（见 §1）。

## 1. xiaomi-piano（Xiaomi Pad 8 Pro）PcdsFixedAtBuild.dsc.inc — **完整**

```ini
[PcdsFixedAtBuild.common]
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferWidth|3200
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferHeight|2136

# Display Caller
#gAndromedaPkgTokenSpaceGuid.PcdDisplayCallerExitDisableDisplay|FALSE
#gAndromedaPkgTokenSpaceGuid.PcdDisplayCallerStallBeforeEnable|1000

# Smbios Info
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemBrand|"Xiaomi"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemRetailSku|"MP"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemRetailModel|"Xiaomi Pad 8 Pro"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemModel|"8pro"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosBoardModel|"pinao"

gAndromedaPkgTokenSpaceGuid.PcdABLProduct|"sun"

[PcdsDynamicDefault.common]
gEfiMdeModulePkgTokenSpaceGuid.PcdVideoHorizontalResolution|3200
gEfiMdeModulePkgTokenSpaceGuid.PcdVideoVerticalResolution|2136
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoHorizontalResolution|3200
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoVerticalResolution|2136
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutColumn|400 # = 3200 / EFI_GLYPH_WIDTH(8)
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutRow|112    # = 2136 / EFI_GLYPH_HEIGHT(19)
gEfiMdeModulePkgTokenSpaceGuid.PcdConOutColumn|400      # = 3200 / EFI_GLYPH_WIDTH(8)
gEfiMdeModulePkgTokenSpaceGuid.PcdConOutRow|112         # = 2136 / EFI_GLYPH_HEIGHT(19)
```

注意 `PcdSmbiosBoardModel|"pinao"` 是**拼写错误**（应为 `piano`），属上游笔误，不影响显示。

## 2. oneplus-erhai（OnePlus Pad 2 Pro）— 仅显示相关行（grep 取得）

```ini
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferWidth|3392
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferHeight|2400
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemBrand|"OnePlus"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemRetailSku|"OPD2413"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemRetailModel|"OnePlus Pad 2 Pro"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemModel|"Pad 2 Pro"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosBoardModel|"OP615EL1"
gEfiMdeModulePkgTokenSpaceGuid.PcdVideoHorizontalResolution|3392
gEfiMdeModulePkgTokenSpaceGuid.PcdVideoVerticalResolution|2400
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoHorizontalResolution|3392
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoVerticalResolution|2400
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutColumn|424  # = 3392 / EFI_GLYPH_WIDTH(8)
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutRow|126    # = 2400 / EFI_GLYPH_HEIGHT(19)
gEfiMdeModulePkgTokenSpaceGuid.PcdConOutColumn|424       # = 3392 / EFI_GLYPH_WIDTH(8)
gEfiMdeModulePkgTokenSpaceGuid.PcdConOutRow|126         # = 2400 / EFI_GLYPH_HEIGHT(19)
```

## 3. lenovo-y700g4（本机 TB322FC）— 仅显示相关行（grep 取得）

```ini
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferWidth|1904
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferHeight|3040
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemBrand|"Lenovo"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemRetailSku|"NULL"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemRetailModel|"Y700"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosSystemModel|"4"
gAndromedaPkgTokenSpaceGuid.PcdSmbiosBoardModel|"NULL"
gEfiMdeModulePkgTokenSpaceGuid.PcdVideoHorizontalResolution|1904
gEfiMdeModulePkgTokenSpaceGuid.PcdVideoVerticalResolution|3040
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoHorizontalResolution|1904
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupVideoVerticalResolution|3040
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutColumn|180  # = 1904 / EFI_GLYPH_WIDTH(8)
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutRow|166    # = 3040 / EFI_GLYPH_HEIGHT(19)
gEfiMdeModulePkgTokenSpaceGuid.PcdConOutColumn|180       # = 1904 / EFI_GLYPH_WIDTH(8)
gEfiMdeModulePkgTokenSpaceGuid.PcdConOutRow|166         # = 3040 / EFI_GLYPH_HEIGHT(19)
```

## 4. oneplus-dodge / nubia-nx789j — 仅显示相关行（grep 取得）

```ini
# dodge (OnePlus 13, Status Display ✅)
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferWidth|1440
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferHeight|3168
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutColumn|180
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutRow|166

# nubia-nx789j (RedMagic 10)
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferWidth|1216
gAndromedaPkgTokenSpaceGuid.PcdMipiFrameBufferHeight|2688
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutColumn|180
gEfiMdeModulePkgTokenSpaceGuid.PcdSetupConOutRow|166
```

## 5. `Display Reserved` 内存映射条目 — 5 个设备包**逐字节相同**

从各设备 `Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c` grep 得（5 个包输出一致）：

```c
{ "Display Demura",    0xA3500000, 0x02C80000, AddMem, MEM_RES, SYS_MEM_CAP, Reserv, WRITE_THROUGH_XN },
{ "FD Reserved I",     0xA7000000, 0x00400000, AddMem, SYS_MEM, SYS_MEM_CAP, BsData, WRITE_BACK },
{ "FD Reserved II",    0xA7400000, 0x00200000, AddMem, SYS_MEM, SYS_MEM_CAP, BsData, WRITE_BACK },
{ "Display Reserved",  0xFC800000, 0x02B00000, AddMem, MEM_RES, SYS_MEM_CAP, Reserv, WRITE_THROUGH_XN },
```

## 6. `Andromeda.dsc.inc` 的 `USE_SCREEN_FOR_SERIAL_OUTPUT` 分支（原文）

```ini
#######################
# Add UART section here.
!if $(USE_SCREEN_FOR_SERIAL_OUTPUT) == 1
  !if $(USE_MEMORY_FOR_SERIAL_OUTPUT) == 1
    SerialPortLib|AndromedaPkg/Library/FrameBufferInMemorySerialPortLib/FrameBufferInMemorySerialPortLib.inf
  !else
    SerialPortLib|AndromedaPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.inf
  !endif
!else
  ...
```

`PakalaNoSb.dsc:31` = `USE_SCREEN_FOR_SERIAL_OUTPUT = 1`；`Pakala.dsc:31` = `0`。
⇒ **NoSb 变体把 `SerialPortLib` 换成「直接写 `Display Reserved` 的 framebuffer 控制台」**，
`BaseDebugLibSerialPort`（`Andromeda.dsc.inc:123`）的全部 DEBUG 输出因此**在 GOP 存在之前就能上屏**。

## 7. `FrameBufferSerialPortLib.c` 关键行（原文行号）

```
28: UINTN gWidth  = FixedPcdGet32(PcdMipiFrameBufferWidth);
30: UINTN gHeight = FixedPcdGet32(PcdMipiFrameBufferHeight);
31: UINTN gBpp    = FixedPcdGet32(PcdMipiFrameBufferPixelBpp);
52: EFI_STATUS Status = LocateMemoryMapAreaByName("Display Reserved", &DisplayMemoryRegion);
57: p_Position = (FBCON_POSITION*)(DisplayMemoryRegion.Address + (W*H*Bpp/8));
68: void ResetFb(void)
88: void FbConReset(void)
99: void FbConPutCharWithFactor(char c, int type, unsigned scale_factor);
165: void FbConDrawglyph(...)
264: void FbConScrollUp(void)
282: void FbConFlush(void)
298: SerialPortWrite(...)
317: SerialPortWriteCritical(...)
```

`PcdMipiFrameBufferPixelBpp` 默认值 = **32**（`AndromedaPkg/AndromedaPkg.dec:108`，
`0x0000a403`），5 个设备包均未覆盖 ⇒ 一致。
