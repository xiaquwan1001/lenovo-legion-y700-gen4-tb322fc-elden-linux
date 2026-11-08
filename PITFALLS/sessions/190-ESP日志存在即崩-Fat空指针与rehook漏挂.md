# 「递归 dump」不是机制问题：两个坑叠出来的（2026-11-08 夜，纯主机侧定位，零上机）

日期 2026-11-08 · 主题 UEFI 路线 B（ESP 上的 LinuxLoader 变体）· 结论 见下条每条

背景：11-08 21:00 起每一次 `fastboot boot` 都在 `[K] esp ld=Success i=1` 之后立刻
`Synchronous Exception at 0x00000000D0B99E2C` + 成对无限重印 `Recursive exception occurred while dumping
the CPU state`；**同一件（r58b）有时能进、有时崩**，且 ESP 上的 `\loader.log` 从此再没被改写。
上一轮把它记成「神奇的递归报错特性」，本轮不用上机就定死了。

## #569 `Root->Open(Root, NULL, \\loader.log, READ|WRITE, 0)` 在**文件已存在**时 = 写地址 0 → 同步异常

- 现象（稳定复现）：屏上 `Synchronous Exception at 0xD0B99E2C`，每发同一地址；
  一次成功（19:25）之后**每发必崩**；`\loader.log` 停留在成功那次的 149 B 不再更新。
- 归因链（RVA 指纹法，全部主机侧）：
  1. 崩溃前最后一条日志 `[I] ? base=00000000D0B95000 size=0000D000` ⇒ 映像基址 `0xD0B95000`，
     `0xD0B99E2C - 0xD0B95000 = 0x4E2C`。
  2. 把 p59 FD（`reports/artifacts/uefi-20261108R54-espfirst-p59/SM8750_EFI.fd`）里外层 FV 的
     LZMA GUIDed 段（`98584eee-1439-5942-9d6e-dc7bd79403cf`）解出内层 FVMAIN，枚举所有 PE：
     `SizeOfImage == 0xD000` 的只有 7 个 —— `ScmDxeCompat / PartitionDxe / UsbDeviceDxe / Fat /
     DriverHealthManagerDxe / AdvancedFileLogger / NvmExpressDxe`。
  3. 日志里前三个是**带名字**的（有 CodeView ⇒ `PdbPointer != NULL`），本树源码编的模块 debug 被剥
     ⇒ 一律打 `?`。所以 `D0B95000` 必是后四个之一。
  4. 四个候选在 RVA `0x4E2C` 的指令：`Fat` = **`str x8, [x22]`**（可 data abort）；
     其余三个分别是 `ldp/str [sp]`/`mov`（不会崩）。⇒ 元凶 = `Fat`
     （`Common/MU_TIANO/FatPkg/EnhancedFatDxe/Open.c` 的 `FatOpenEx()`
     `*NewHandle = &NewIFile->Handle;`，`x22 = NewHandle`，`NewIFile->Handle` 在结构偏移 8，
     与 `add x8, x23, #8` 完全对上）。
- 直接原因：`LinuxLoader.c` 的 `LLogOpen()` 用规范的「`NewHandle == NULL` + 非 CREATE ⇒ 删除」写法：
  `(VOID)Root->Open (Root, NULL, L"\\loader.log", READ|WRITE, 0);`
  **本树 EnhancedFatDxe 的 `FatOpenEx()` 只校验 `FileName` 与 `OpenMode`，没有 `NewHandle == NULL`
  的分支** ⇒ 文件存在就打开成功 ⇒ `*NewHandle = …` 把 8 字节写到 **地址 0** ⇒ 一次 data abort。
  文件不存在时 `FatOFileOpen` 返回 `NOT_FOUND`、不写 ⇒ **不崩**。
  这唯一地解释了「第一次成功、之后次次崩」「同一件两个结果」「`\loader.log` 不再更新」。
- 与 #567 的关系：#567 已发现 `Open(NULL,…)` **不会删除**旧文件（正确），但当时判为「无害，
  只要每次 Linux 侧 `rm`」；实际是**致崩**。别再靠外部 `rm` 绕：改调用方式。
- 处置：打开拿句柄再 `->Delete()`（`Delete` 兼带 `Close`），永不用 `NewHandle == NULL` 表达删除。
  该写法对 EnhancedFat / 其它 FAT 实现都成立。改点 = `Platforms/QcomModulePkg/Application/LinuxLoader/LinuxLoader.c`
  的 `LLogOpen()`（同一次改动里新增 `R61` 注释）。
- 通用纪律：**对「规范允许、但这棵树没实现」的参数组合，先在这棵树的源码里确认分支存在再依赖**；
  尤其 `(VOID)` 吞返回值的调用 —— 崩的不是你喜欢的那行，而是库里第一次解引用你的错误参数的那条 store。

## #570 ESP 路径**跳过了异常处理器重挂**（R18 在 R13 里），于是崩溃取证退化成 stock handler + 递归 dump

- 现象：崩溃时屏上**没有** `[K] FLT pc=… img=… b=… z=… esr=… far=…` 归因行，也没有 `[L] cpu-hook=…`；
  只有 `Synchronous Exception at 0x…` + `Recursive exception occurred while dumping the CPU state` 成对重印。
- 根因：`2026-11-06R18` 把 `Cpu->RegisterInterruptHandler(EXCEPT_AARCH64_SYNCHRONOUS_EXCEPTIONS,
  DefaultExceptionHandler)` 写在 **`R13StartLinuxLoader()` 内部**；`2026-11-08R54` 把 `R13StartLinuxLoader()`
  的调用点挪到 `R54TryEspBoot()` **失败之后**。⇒ ESP 件被 `StartImage` 起来时，运行期用的仍是
  **预编译 `Binaries/ArmPkg/Drivers/CpuDxe/CpuDxe.efi` 自带的 stock handler**（#499）：
  既没有 `[K] FLT` 归因，也没有本树 `FrameBufferSerialPortLib` 的有界滚屏（R19/R25/R27/R29 全在源码侧）
  ⇒ 一次真异常被放大成屏上无限递归，真 PC 只剩 `0x…E2C` 一个数字。
- 判据（主机侧，不用上机）：p59 FD 内层 FV 里 `DxeCore` 含 `FLT pc=`、`BdsDxe` 含 `esp ld=`，
  但屏上两者一个都没出现 ⇒ 说明注册的那份没被用上，而不是补丁没编进去。
- 处置：把 rehook 提成独立函数，在**进入 `R54TryEspBoot()` 之前**调用一次（`patches/uefi/20261108R61-hoist-exchook/`）。
  装上后 handler 用 BdsDxe 自己那份（带 `FrameBufferSerialPortLib` 有界滚屏）⇒ 递归 dump 消失、`[K] FLT` 出来。
- 通用纪律：**任何「新增一条启动路径」的补丁都要检查带副作用的初始化（异常 handler / watchdog /
  console 预算 / 定时器）是否还在这条路径的上游**；把 R13 的调用挪走时，一并挪走它体内的仪式。

## 上机确认（2026-11-08 23:01，两发零写盘）

- 发 1（固件 p60 + loader r62，只修了 `LLogOpen`）：屏上 `[L] esp cpu-hook=ok` + 
  `[K] FLT pc=D0B99E2C img=- b=D0B95000 z=0D000 o=4E2C esr=96000047 far=00000000`，
  寄存器 `x22=0` ⇒ **esr 的 ISS 里 WnR=1、DFSC=7（translation fault L3）、FAR=0 = 往地址 0 写**，
  与 #569 的推断逐字吻合。该发 `\loader.log` 已被截断重写（崩点已后移到**第二处**同一个 bug：
  `VerifiedBoot.c` `EspMark()` 里连写两条 `Root->Open(Root, NULL, L"\\espboot.log", …)`）。
- 发 2（同一固件 + loader r63，两处都改）：`uname -r` = `…vk184-00002…`、`/proc/cmdline` 里
  `elden_bootloader=esp`、`\loader.log` 158 B 且是本发完整序列（`entry → pre-boardinit → boardinit st 0 →
  pre-vmdata → force-boot → bootfastboot 0 → pre-auth → post-auth st 0 → pre-bootlinux`）
  ⇒ 崩溃消失、ESP 启动器正常交棒。trial record `reports/trials/20261108T150553Z-uefi-p60-r63-both-fixed.json`。
- 教训补充：**同一个错误写法在一棵树里通常不止一处**（本轮 `LLogOpen` 与 `EspMark` 各一处）；
  修完先 `grep -rn "Open (.*NULL"` 全树扫一遍，别等着下一发上机再撞第二次。
