# ★2026-11-06 定案（p19/p20 轮）：真启动崩溃 = **我们自己的探针写屏**，不是 AVB/槽位/EB/USB

## 一句话
`LoadImageAndAuth()` 入口那行 `SbProbeMode = (...) ? ... : 0;` **无条件**把探针模式重置为 0（完整模式），
把 R4 特意设的默认值 3（沉默）覆盖掉 ⇒ 真件（cmdline 无令牌）里十几次 `SbVProbe` 全部直写帧缓冲，
scale 3 每行 ≈274 KiB × 十几行 ≫ splash 前 ~448 KiB 可写区 ⇒ `PITFALLS #514/#515` 的写穿崩溃。
修法 = `patches/uefi/20261106R12-probemode-guard/`（只有带 `sbstop=` 令牌时才改模式）。

## 上机取证（全部零写盘，同一 82 MB 真内核载荷 `out/boot-elden-vk172.img`）
| 件 | cmdline | 探针模式 | 结果 |
|---|---|---|---|
| p12/p14/p15/p16/p17 | 真件原样 | **0（写屏）** | 崩 `0xCFE98C38`（各版 PC 略异） |
| p18 `real-vs16..38` | `sbstop=N sbprobe=3` | 3 | **16/20/24/26/27/28/34/35/36/37/38 全回话** |
| p18 `real-vs43` | `sbstop=43 sbprobe=3` | 3 | 走到 `ret-after-lia`（LIA 正常返回） |
| p18 `real-c-tty0`（只改 cmdline 首 21 B） | 真件+改 console | **0** | 崩 ⇒ 与 cmdline 文本无关 |
| **p19** 真件 + R12 修复 | 真件原样 | 3 | **`ret-after-lia` 回话、设备存活** ⇒ 修复成立 |
| **p20**（去掉早退，全路径） | 真件原样 | 3 | 宿主 `Booting OKAY [0.001s]` ⇒ 越过 LIA/ExitMenuKeys/FastbootOkay；随后崩 `0xCFE98C4C` |

## 被推翻的旧归因（都不要再用）
- 「跳进堆」：DXE Heap 是 `Conv` 内存，DXE 映像代码本就分配在那里（`DxeCore` 自身在 `0xD4CA6000` 就在其中）。
- 「`MarkPtnActive()` 崩」「`FastbootUsbDeviceStop()` 崩」：p17（零屏显写、不进这三个调用）仍崩，
  p19/p20 证明真因是探针写屏。
- 「诊断模式 vs 真启动是两条路径」仍然成立（`FastbootOkay`/`FastbootUsbDeviceStop`/`ResetBootDevImage`
  只在真启动分支），但它不是崩溃原因。
- 递归 dump 打出来的 PC（`…DA8`/`…DA9` 每条差 1）是垃圾；只有**非递归**首行 PC 才可当信号。

## 判据纪律（本轮新增）
- `[L] found=/[L] LoadImage=Success` 是 **BdsDxe** 在 `gBS->StartImage(LinuxLoader)` **之前**打的
  （`MU_BASECORE/MdeModulePkg/Universal/BdsDxe/BdsEntry.c:758`）⇒ 不能当"已进 fastboot 会话"的证据。
- `uefi-sbstop-patch.py` 只覆盖 cmdline **前 19–21 B**，其余 1536 B 原样保留 ⇒ 令牌阶梯的 cmdline 与真件
  只在头部不同，可当单变量用。
- 带 `sbprobe=3` 的令牌件是静默的，可以在**真载荷**上安全跑（这是本轮之前一直没做过的事）。
