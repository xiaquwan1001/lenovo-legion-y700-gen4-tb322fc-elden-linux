# 路线 B（ESP-first）静态核对发现（2026-11-08 下午·收尾）

> 线：G1-29。本文只记**代码事实**（可复现的静态核对），不含上机结论。
> 上机那发的结论见 `reports/uefi-espboot-r55-indeterminate-20261108.md`（`INDETERMINATE`）。
> 代码树：`build/uefi-woa-prep/repos/7-mu-lenovo`（`mu_wide_platforms@6b6ac42a` + `build_cfg/sm8750.json`）。

---

## 1. 交接口确认：改动面确实只有「取件」一处

| 事实 | 位置 | 含义 |
|---|---|---|
| `BootLinux()` 取件 = `GetImage (Info, &buf, &size, "boot")` | `Library/BootLib/BootLinux.c:939` | 只是**查表** |
| `GetImage()` 实现 = 遍历 `Info->Images[]`，`AsciiStrnCmp(Name, ImageName, len(ImageName))` 前缀匹配 | `BootLinux.c:1445` | 表里 `Name="boot"` 即可命中，与分区名 `boot_a/boot_b` 同语义 |
| 表由 `LoadImageAndAuth()` 填 | `Library/avb/VerifiedBoot.c:1658` | **唯一插入点**（R55 打在这里，正确） |
| 内存图/DTB/ramdisk 全在 `BootLinux()` 内 | `BaseMem` / `UpdateKernelParams` / `SetandGetLoadAddr` / `GZipPkgCheck` | 复用 p58 已验证路径，无需重写 |
| 最终跳转 | `BootLinux.c:1117` `LinuxKernel ((UINT64)DeviceTreeLoadAddr, 0, 0, 0)` | 与 p58 同一条路 |

⇒ 结论：路线 B 的「自写 loader」其实**不需要自写**，只需要换「boot.img 从哪来」。这一点在 11-08 上午定案时是对的。

## 2. 已发现的真实缺陷：ESP-first 早退漏填 `Info->Pname`（→ `PITFALLS #561`）

- 正常路径：`LoadImageAndAuth()` 先 `StrnCpyS(Info->Pname, …, L"boot"/L"recovery", …)`，再 `LoadImageAndAuthVB1/VB2`。
- R55 的 ESP-first 分支在**填 Pname 之前** `return EFI_SUCCESS` ⇒ `Info->Pname` 全 0（调用方 `BootInfo Info = {0}`）。
- 下游 `BootLinux()` → `CheckMDTPStatus(PartitionName, Info)`：
  ```c
  PartitionNameLen = AsciiStrLen (PartitionNameAscii);          // = 0
  if (Info->MultiSlotBoot)                                       // 本机 A/B ⇒ TRUE
    PartitionNameLen -= (MAX_SLOT_SUFFIX_SZ - 1);                // 0 - 2 = 0xFFFF_FFFF_FFFF_FFFE
  AsciiStrnCatS (StrPartition, MAX_GPT_NAME_SIZE, PartitionNameAscii, PartitionNameLen);
  ```
- 现网后果：`EnableMdtpSupport` 为假时该值不被使用（只是算出垃圾数）；为真时走 MDTP 分支拿到 `"/"`。
  DEBUG 构建下 `AsciiStrnCatS` 的 `ASSERT` 会直接炸；`StrnCmp(PartitionName, L"boot", 4)` 恒不等 ⇒ **FFBM 参数被静默跳过**。
- **修法（R56 必带）**：ESP-first 命中后先 `StrnCpyS(Info->Pname, ARRAY_SIZE(Info->Pname), L"boot", …)` 再返回。
  纪律同 `#526`：**早退分支要复刻被跳过那段的前置状态设置**。

## 3. `extra_cmdline` 偏移：本平台是 **608**，不是 AOSP 的 584（已核实，放心用）

- Mu 的 `boot_img_hdr_v0`：`UINT32 id[8]`（**32 字节**，`BootImage.h:74`）在 576..608，`extra_cmdline[1024]` 紧随 ⇒ **608**。
- AOSP 的 `id[8]` 是 8 字节 ⇒ 584。两者差 24 字节。
- 本项目 `scripts/mkbootimg.py` 也用 608（`hdr[608:608+BOOT_EXTRA_ARGS_SIZE]`），与 Mu 一致；
  `scripts/grub-bootfiles.sh` 读 608 亦一致。
- ⇒ 本次给 ESP 的 `boot.img` 注入令牌 `elden_bootloader=esp` 写的就是 608，**LinuxLoader 能读到**（`CatCmdLine` 会拼 cmdline + extra_cmdline）。
  但注意：**ABL** 用哪个偏移未知（闭源），所以「令牌出现在 `/proc/cmdline`」只对 **UEFI/LinuxLoader 路径**成立，
  对 `boot_b`（ABL 引导）路径可能不成立 —— 判据设计时别混。

## 4. ESP-first 跳过的副作用（必须在报告里写清，不能当"透明"）

| 被跳过 | 后果 |
|---|---|
| AVB 校验（VB1/VB2） | 自签件本来过不了；但也意味着**没有回滚保护/没有 verified-boot 屏** |
| `DisplayVerifiedBootScreen` / `VBSendMilestone` | 没有 UEFI 侧「校验中」提示（对本线无影响） |
| `Info->Pname` 赋值 | 见 §2（缺陷） |
| `FindBootableSlot()` | 不会因为我们而改槽位状态（**好事**：`#525` 的 ABL 写 retry 问题不涉及） |

## 5. 其它静态风险（R56 之后若仍失败，按这个顺序查）

1. **85.6 MB 单块 `AllocatePool`**：`boot.img` 整块进 pool（`EfiBootServicesData`），UEFI 内存池碎片化时可能失败
   （失败会静默回落分区路径，方向安全，但会让实验「看起来没跑」——所以 R56 必须有 `[E] esp miss <Status>`）。
2. **`dtbo` 语义**：ESP 路径填 `Name="dtbo"` 后，overlay 应用仍由 `BootLinux` 的 `LoadAndValidateDtboImg` 走 `GetImage("dtbo")`；
   我们放的是 `dtbo_b` 的整分区 dump（33 554 432 B，含分区尾零），**是否与「分区读取」等价未证**。
   若 `LoadAndValidateDtboImg` 依赖分区头/大小校验，可能校验失败 → overlay 跳过（p58 时代 dtbo 正常，故可能只是少一层 overlay）。
3. **`GZipPkgCheck`/`SetandGetLoadAddr`**：p58 走的是分区读入的 buffer；ESP 路径 buffer 来自 pool，**物理地址分布不同**，
   若这两步依赖「buffer 落在某区间」的假设，会有差异（静态看不出，需上机看 `[E] esp take` 之后的行为）。

## 6. 屏可见性通道（diag 内核那一发给出的结论）

- `CONFIG_SYSFB_SIMPLEFB=y` 的 vk184（`7.3.1-debug-fbdiag-…`）上机后**同墙同死**（无新 pstore、无 ssh、屏上仍只到 `App Log Flush`）。
- 静态原因：本平台 UEFI **不提供 GraphicsOutput**，屏是 Mu 用 `Display Reserved` 内存直接涂
  （`Platforms/AndromedaPkg/Library/FrameBufferSerialPortLib`，R21 补丁的惰性初始化就是找这块区）。
  ⇒ `simpledrm` 无 EFI framebuffer 可绑，**fbcon 通道在这条路径上不存在**。
- 因此 UEFI 侧的唯一可见通道 = **我们自己的 `SerialPortWrite` 面板打印**（就是 R56 采用的方式）。

## 7. 复现命令（全部主机侧、只读）

```bash
cd ~/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo
grep -n "GetImage (Info" -A4 Platforms/QcomModulePkg/Library/BootLib/BootLinux.c
grep -n "PartitionNameLen" -B4 -A2 Platforms/QcomModulePkg/Library/BootLib/BootLinux.c
sed -n '70,80p' Platforms/QcomModulePkg/Include/Library/BootImage.h   # id[8] 是 UINT32 ⇒ extra_cmdline=608
grep -n "extra_cmdline" ~/y700-elden/scripts/mkbootimg.py
```

---

## 8. 追加核对（2026-11-08 收尾后）：dtbo **不是**阻塞点，但 ESP 上那份 dtbo.img 是多余的

| 事实 | 位置/证据 |
|---|---|
| `LoadAndValidateDtboImg()` 先查 dtbo **表头魔数** `0xD7B7AB1E`，不符即返回 FALSE | `PartitionTableUpdate.c:1746`、`LocateDeviceTree.h:66` |
| 返回 FALSE ⇒ `BootLinux()` 走 `else`（DTB overlay 分支）：先 `GetSocDtb()`（从 kernel 的 appended DTB 取），再 `GetDtboNeeded()` | `BootLinux.c:511,556,569` |
| `DtboNeed` 默认 **TRUE**，只有当 appended DTB 的 compatible **全位精确匹配**时才置 FALSE | `LocateDeviceTree.c:48,1036` |
| 本机 `dtbo_b`（`sde49`，33 554 432 B）**前 64 字节全 0** ⇒ 魔数不匹配 | 设备 `dd | xxd` 实测 |
| `DTBO_MAX_SIZE_ALLOWED = 24 MiB`，而该分区 32 MiB | `LocateDeviceTree.h:69` |

**结论**：
1. 本机 dtbo 分区**本来就是空的**，分区路径与 ESP 路径拿到的都是「无效 dtbo」⇒ **行为等价**，dtbo 不是路线 B 的变量。
2. p58 能起，说明本机 appended DTB（`elden.dtb`）与 SoC 精确匹配 ⇒ `DtboNeed=FALSE` ⇒ 不查 dtbo。
   **路线 B 用的是同一份 `boot.img`（含 appended DTB）⇒ 下游代码路径与 p58 完全相同**。
3. 由此可反推：若 R55 真的把 `boot.img` 交给了 `BootLinux()`，那么它**应该能起来**（与 p58 同路）。
   14:33 那发没起来 ⇒ 更可能是 **R55 分支根本没跑到**（与 `#559` 的两个盲区一致），而不是「B 路线撞墙」。
4. ESP 上的 `/boot/dtbo.img`（32 MiB 全零 dump）**多余且误导**，已删除（保留 `/boot/boot.img` 与 `Loader.efi`）；
   若将来真需要 dtbo，必须放**有效 dtbo 表**且 ≤24 MiB。
