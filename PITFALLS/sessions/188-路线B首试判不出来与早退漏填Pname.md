# 188 — 路线 B 首试「判不出来」：RELEASE 剥 DEBUG + 菜单歧义 + GRUB 超时不推进

日期：2026-11-08 · 线：G1-29 路线 B · 正文：`reports/uefi-espboot-r55-indeterminate-20261108.md`

## #559 实验件没有**面板可见**的自证标记时，一次上机的屏照可以同时兼容「成功路径没跑」和「跑了自己死」⇒ 整轮白烧

**事实链**（2026-11-08 14:33 一发，`fastboot boot` p59 + GRUB `chainloader` ESP 的 `Loader.efi`）：
- ESP 前置件 sha 双侧核对一致（`/boot/boot.img` vk184 + 令牌 `elden_bootloader=esp`、`/boot/dtbo.img`、`/EFI/elden/Loader.efi` R55 176 640 B）；
- 屏上仍是 `[I] ? base=…C5D80000 size=03F40000` → `DBI dump table info not found` → `App Log Flush : 0 ms`，随后掉电回 `boot_b`；
  无新 pstore、ssh 恒 down；`verdict = INDETERMINATE`。
- 两个盲区叠加：
  1. **R55 是 `TARGET=RELEASE` 构建**，EDK2 的 RELEASE DebugLib 把 `DEBUG()` 串**整段丢弃** ⇒ 我们自己的分支即使命中也不留痕
     （作者在实现报告 §3.2 已提示，但当时没把它当成**实验可行性**问题）；
  2. `grub.cfg` 当时有 5 个条目、`default=1`，而**本机 GRUB 超时不会自动推进**（会一直停在菜单）⇒ 不排除选到了
     `/boot/Image`（EFI-stub 项），那屏上必然是这三行（`#558`）。

**纪律/教训**：
- 任何「新代码路径」上机件，**必须自带一条走既有可见通道的自证标记**（本树 = `SerialPortWrite` 面板打印，R21 惰性初始化已修）；
  判据写成「看到 `<标记>` 才算该路径跑过」，否则 verdict 只能是 indeterminate，不要写成失败/成功。
- **RELEASE 构建 ≠ 可归因构建**：要归因就走 DEBUG 构建，或改用 `SerialPortWrite` 这类不经 DebugLib 的通道。
- **菜单条目必须单变量**：一次上机只留一个可选项（`timeout` + 唯一条目），否则「选了哪条」本身就成了未控变量。

## #560 本机 GRUB 的 `set timeout=N` **不会自动推进**（停在菜单直到按键）

- 现象（用户实测 + 2026-11-08 下午一发）：`set timeout=15` 的菜单**不倒数、不自动选**，机器停在菜单不动，
  表现为「设备没反应」（不是挂死）。
- 处置：判据要按「可能需人工确认」设计——单条目 + `timeout=3`，并**明确告知用户按电源键确认**；
  若需真正无人值守，得走「UEFI 侧 R54 直接加载 ESP 的 `Loader.efi`」（不经 GRUB）。
- 与 `#557`（判据通道在载体上是否有效）同族：**先把「谁来推进」证清楚，再谈功能**。

## #561 ESP-first 早退会漏填 `Info->Pname` ⇒ `CheckMDTPStatus()` 里 `PartitionNameLen -= (MAX_SLOT_SUFFIX_SZ-1)` 无符号下溢

- 代码事实（`build/uefi-woa-prep/repos/7-mu-lenovo`，2026-11-08 静态核对）：
  - `LoadImageAndAuth()` 正常路径先 `StrnCpyS(Info->Pname, …, L"boot", …)` 再 `LoadImageAndAuthVB1/VB2`；
  - R55 的 ESP-first 分支在**填 Pname 之前**就 `return EFI_SUCCESS` ⇒ `Info->Pname` 保持全 0（调用方 `BootInfo Info = {0}`）；
  - `BootLinux()` 里 `PartitionName = Info->Pname` → `CheckMDTPStatus()`：
    `PartitionNameLen = AsciiStrLen("") = 0`，然后 `if (Info->MultiSlotBoot) PartitionNameLen -= (MAX_SLOT_SUFFIX_SZ-1)`（= 减 2）
    ⇒ **0xFFFFFFFFFFFFFFFE**，随后 `AsciiStrnCatS(..., PartitionNameLen)`。
- 现网后果：该值只在 `EnableMdtpSupport` 为真时才被使用（未启用时只是算出个垃圾数）；但 DEBUG 构建下
  `AsciiStrnCatS` 的 ASSERT 会直接炸，且 `StrnCmp(PartitionName, L"boot", 4)` 恒不等 ⇒ FFBM 参数被静默跳过。
- 修法（R56 顺手做）：ESP-first 命中后**先** `StrnCpyS(Info->Pname, …, L"boot", …)`（或按 `FindBootableSlot` 填 `boot_b`）再返回；
  纪律同 `#526`：**早退分支要复刻被跳过的那段「前置状态设置」**，否则下游拿到的不是零就是垃圾。
