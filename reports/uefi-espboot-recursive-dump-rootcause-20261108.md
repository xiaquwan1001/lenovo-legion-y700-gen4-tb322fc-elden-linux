# 「递归 dump」定因：ESP 上的 `\loader.log` 一旦存在，每次 ESP 启动都写地址 0（2026-11-08 夜，全主机侧）

日期 2026-11-08 · 结论 一条真因 + 一条「为什么只有一个数字」· 全部结论**零上机**得出

## 0. 一句话

屏上那个「神奇的递归报错」是**两个独立缺陷叠出来的**：

1. **真异常**：`LinuxLoader` 的 `LLogOpen()` 用 UEFI 规范的写法
   `Root->Open(Root, NULL, L"\\loader.log", READ|WRITE, 0)` 表示「先删旧日志」，但
   **本树 `EnhancedFatDxe` 的 `FatOpenEx()` 没有 `NewHandle == NULL` 分支** ⇒ 文件存在就打开成功
   ⇒ `*NewHandle = &NewIFile->Handle` **把 8 字节写到地址 0** ⇒ 同步异常 / data abort，
   ELR = `0xD0B99E2C` = `Fat` 装载基址 `0xD0B95000` + RVA **`0x4E2C`**。
2. **递归 dump**：`R18` 的异常处理器重挂写在 `R13StartLinuxLoader()` **体内**，而 `R54` 把 R13 的
   调用点挪到「ESP 失败之后」⇒ ESP 这条路径上用的是**预编译 `CpuDxe.efi` 的 stock handler**：
   没有 `[K] FLT` 归因行，也没有本树 `FrameBufferSerialPortLib` 的有界滚屏 ⇒ 屏满后 handler 自己
   二次异常 ⇒ 屏上成对无限重印，真 PC 只剩一个数字。

⇒ 「有时能进、有时必崩」不是随机的：**判据是 `\loader.log` 在不在**（第一次没有 ⇒ 成功，之后一直有 ⇒ 必崩）。

## 1. 证据链（可复算）

| # | 事实 | 复算方式 |
| --- | --- | --- |
| E1 | 崩溃前最后一条装载行 `[I] ? base=00000000D0B95000 size=0000D000` | 用户 21:xx 屏照 OCR（`.pi/sessions/2026-11-08T12-59-17-958Z_*.jsonl` 第 621/692 条） |
| E2 | `0xD0B99E2C − 0xD0B95000 = 0x4E2C`（落在该映像内，不是野地址） | 减法 |
| E3 | p59 FD 解压内层 FVMAIN 后，`SizeOfImage == 0xD000` 的模块只有 7 个：`ScmDxeCompat / PartitionDxe / UsbDeviceDxe / Fat / DriverHealthManagerDxe / AdvancedFileLogger / NvmExpressDxe` | 见 §3 脚本 |
| E4 | 日志里前三个是**带名字**的 ⇒ 本树源码编的模块 debug 被剥（`PdbPointer == NULL`）⇒ 打 `?`；后四个都没在日志里出现名字 | 同一份 OCR |
| E5 | 四个候选在 RVA `0x4E2C` 的指令：`Fat` = **`str x8, [x22]`**；另三个分别是 `ldp/str [sp]`、`mov` | `llvm-objdump -d --start-address=0x4e00` |
| E6 | `Fat` 的该处对应源码 `FatOpenEx()` 的 `*NewHandle = &NewIFile->Handle;`（`x22 = NewHandle`；`NewIFile->Handle` 在结构偏移 8 = 反汇编里的 `add x8, x23, #8`） | `Common/MU_TIANO/FatPkg/EnhancedFatDxe/Open.c:200-290` |
| E7 | 同一函数里**只校验 `FileName` 与 `OpenMode`，没有 `NewHandle == NULL` 分支** ⇒ NULL 会一路走到那条 store | 同文件 + 反汇编（无 `cbz x1`） |
| E8 | p59 FD 内层 FV 中 `DxeCore` 含 `FLT pc=`、`BdsDxe` 含 `esp ld=`，但屏上两者都没出现 ⇒ R61 现场用的是 stock handler | `grep -a` + OCR |
| E9 | `LLogOpen()` 里正是 `(VOID)Root->Open (Root, NULL, L"\\loader.log", READ|WRITE, 0);` | `LinuxLoader.c:203`（改前） |

⇒ E1–E7 给出「崩在哪条 store」，E9 给出「谁把 NULL 递进去」，E8 给出「为什么只剩一个数字」。

## 2. 为什么以前没查出来

- 屏上地址**每一次都一样**，看起来像「稳定在某个奇怪状态」，因此被当成「环境/复位深度」问题；
  实际是**同一条指令**（同一件事重复发生）。
- `\loader.log` 不再更新，看起来像「崩在日志开启之前」；实际是**崩在日志开启的第一次 Open 里**。
- 之前那一版 r58b「对照组」也崩，被用来证明「不是我的菜单代码」；对，但更弱的一条结论没被利用：
  **崩点与 loader 版本无关** ⇒ 应该往「两者共用的外部模块」找（FAT）。
- `#567` 已经发现 `Open(NULL,…)` **不删除**文件（判断正确），但把它当成「无害，靠 Linux 侧 `rm` 规避」；
  实际它是致崩点。

## 3. 复算脚本（主机侧，约 10 秒）

```bash
cd ~/y700-elden
python3 - <<'PY'
import struct, lzma
fd = open('reports/artifacts/uefi-20261108R54-espfirst-p59/SM8750_EFI.fd','rb').read()
mix = lambda b: b[3::-1]+b[5:3:-1]+b[7:5:-1]+b[8:]
LZ  = mix(bytes.fromhex('EE4E5898391442599D6EDC7BD79403CF'))
# 外层 FV 的 LZMA GUIDed section → 内层 FVMAIN（12.8 MiB）
off = next(i for i in range(0,len(fd)-24,4) if fd[i:i+16]==LZ)
inner = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(fd[off+20:])
# 枚举内层 FV 的 PE，按 SizeOfImage 过滤（完整 walker 见本报告 §4）
PY
```

崩溃指令反查：

```bash
# 从 p59 FD 里取出 Fat 的 PE32（内层 FV 的 FFS 961578FE-B6B7-44c3-AF35-6BC705CD2B1F）
llvm-objdump -d --triple=aarch64-linux-gnu --start-address=0x4e00 --stop-address=0x4e60 /tmp/mod-fat.bin
# 4e2c: f90002c8  str x8, [x22]        <-- *NewHandle = &NewIFile->Handle
```

## 4. 处置

| 件 | 动作 | 状态 |
| --- | --- | --- |
| loader `LLogOpen()` | 改成「打开拿句柄再 `->Delete()`」，永不用 `NewHandle == NULL` 表达删除 | 已改（`LinuxLoader.c`，含 R61 注释；待重建 + 上机） |
| 固件 `BdsDxe`（`R61`） | `R61HookException()` 抽成函数，`R54TryEspBoot()` 一进来就调用 ⇒ ESP 路径也有 `[K] FLT`/ESR/FAR，且不再递归 dump | 补丁已写并验证可应用：`patches/uefi/20261108R61-hoist-exchook/`，配方 `patches/uefi/p60-recipe.txt` |
| 文档 | PITFALLS `#569`/`#570`（`sessions/190-…`） | 已写 |

判据（下一发上机）：

1. 屏上应出现 `[L] esp cpu-hook=ok`；
2. 正常路径：ESP `\loader.log` **每次都被截断重写**（不再保留上一发内容），且能走到 `Loader` 自己打的
   `[L] entry …`；
3. 若仍有异常：屏上应是**一行** `[K] FLT pc=… img=… b=… z=… o=… esr=… far=…`，屏停住不动。

## 5. 顺带解释的历史现象

- 19:25 那次 ESP 启动成功：当时 ESP 上**还没有** `\loader.log` ⇒ `FatOFileOpen` 返回 `NOT_FOUND`、
  那条 store 不执行。
- 之后每一发（r59 / r59b / r59c / r58b 对照件）全崩：文件已经在了。
- `loader.log` 停在 149 B（19:25 那版内容）：崩发生在**第一次 Open**，还没来得及写。
- 崩溃后能自己回到 boot_b 的 Linux：`CpuDeadLoop` 之后 `QcomWdogDxe` 的硬件看门狗复位，ABL 正常启动。

## 6. 未解决/不影响结论的点

- 屏上「`Synchronous Exception at 0x…` + `Recursive …`」为什么呈**成对**重印（而不是只印 Recursive），
  机制上没有逐字解释：stock handler 的递归分支只印一句就 `CpuDeadLoop`，按代码应是「一次
  Synchronous + N 次 Recursive」。合理解释是 stock handler 的屏显路径在滚屏时把已有内容重绘/粘连
  （面板在这一段本身就在异常路径里）。**这条不影响定因**（ELR 每次相同、且与 E6 的 store 一一对应），
  装上 `R61` 后该现象应整体消失，届时可顺带确认。

---

# 上机验证（2026-11-08 22:52 / 23:01，两发零写盘）

## 发 1：固件 p60（= p59 + R61）+ ESP loader **r62**（只修了 `LLogOpen`）

屏上原文见 `reports/artifacts/uefi-boot-20261108-p60-r62/screen-ocr.txt`。关键：

```
[L] esp cpu-hook=ok
[K] esp ld=Success i=1
[K] FLT pc=D0B99E2C img=- b=D0B95000 z=0D000 o=4E2C esr=96000047 far=00000000
[K] sp=A764AB00 … x22=0 x30=D0B99E20
```

- **R61 成立**：`[L] esp cpu-hook=ok` 出现；`[K] FLT` 归因行 + 全寄存器 dump 打出来了；屏**停住不再递归**
  ⇒ §0 的两层结构（真异常 + 只有数字）都被证实。
- **真异常性质**：`esr=0x96000047` ⇒ EC=0x25（EL1 数据异常）IL=1 ISS=0x47 = **DFSC 7（translation fault L3）+ WnR=1（写）**，
  `far=0`、`x22=0` ⇒ **往地址 0 写**，与 §1 的 E5/E6（`Fat` RVA `0x4E2C` = `str x8,[x22]`，x22 = `NewHandle`）逐字吻合。
- 该发**崩点已后移**：`\loader.log` 被截断重写（120 B，内容 `[L] boardinit st 0 … pre-auth`），
  `\espboot.log` 未重写 ⇒ 说明 `LLogOpen` 已不会再崩，撞上的是**同一 bug 的第二处**：
  `VerifiedBoot.c` `EspMark()` 里连写两条 `Root->Open(Root, NULL, L"\\espboot.log", …)`。

## 发 2：同固件 + ESP loader **r63**（两处都修）→ 通过

```
uname -r                 = 7.3.1-debug-vk184-00002-g4da9a8b69fc8
/proc/cmdline            = elden_bootloader=esp          ← 确实从 ESP 启动器交棒
\loader.log (158 B, 全部本发内容)：
  [L] entry r59-menu
  [L] pre-boardinit
  [L] boardinit st 0
  [L] pre-vmdata
  [L] force-boot
  [L] bootfastboot 0
  [L] pre-auth
  [L] post-auth st 0
  [L] pre-bootlinux
```

- trial record：`reports/trials/20261108T150553Z-uefi-p60-r63-both-fixed.json`（`VERDICT=ESPBOOT_TAGGED`，
  产物目录 `reports/artifacts/uefi-boot-20261108-230112/`）。
- 判据逐条达成：① 两个「已存在」的日志文件不再是崩溃触发；② `\loader.log` 每发被截断重写；
  ③ 走通 menu → auth → bootlinux 并交棒给内核（`elden_bootloader=esp`，vk184 = ESP 默认条目）；
  ④ 全程零写盘（`fastboot boot`，没碰任何分区）。

⇒ `#569`（Fat 空指针）在**两个调用点**都修掉；`#570`（rehook 漏挂）由 `R61` 修掉并实测有效。

---

# 附：启动菜单（R60 = 屏显 UI + 按键选择）上机通过（2026-11-08 23:26）

- 件：ESP loader `r65`（`3523b320…`，184 320 B）= r63 全套修复 + `LMenuDrawScreen/LMenuDrawSelect`
  （复用 `BootLib/DrawUI` 的 `DrawMenuInit/SetMenuMsgInfo/DrawMenu/UpdateMsgBackground`，
  **不用** `SerialPortWrite` 画菜单 —— 避开 `#514/#515/#567` 的帧缓冲写穿）。
- 首次尝试（r64）**屏上无菜单、直接进 Linux**，`\loader.log` 里连 `[L] menu in` 都没有：
  菜单调用被 `LEspHasFile(L"\\menu.enable")` 门控，而那个文件从来不在 ESP 上 ⇒ 整段菜单静默不执行。
  ⇒ 判据：**任何「加了开关文件」的功能，第一次上机必须确认那个文件真的存在**；否则「功能没生效」会被误读成
  「功能有 bug」（同族坑 `#559`/`#564`）。修法 = 去掉门控，开关改成 `\menu.cfg` 的 `#timeout`（缺文件或 0 ⇒ 零等待、不登屏）。
- 上机（`fastboot boot` p60 + `\menu.cfg` `#timeout=8`，4 个条目）：
  ```
  [L] menu entry n 4
  [L] menu timeout s 8
  [L] menu in 4
  [L] menu ui 4
  [L] menu key 2          ← 音量下（SCAN_DOWN）
  [L] menu sel 1
  [L] menu key 258        ← 电源（SCAN_SUSPEND）确认
  [L] menu boot \boot\boot2.img
  ```
  `uname -r` = `…vk184-00003…` ⇒ 确实按选择起了 `\boot\boot2.img`（备选内核），而不是默认项。
  用户屏照确认：菜单正常显示、反白项随音量键移动。
- 结论：**G1-29「启动菜单」这一项闭环**（屏显 + 按键 + 选择生效 + 日志可审）。
