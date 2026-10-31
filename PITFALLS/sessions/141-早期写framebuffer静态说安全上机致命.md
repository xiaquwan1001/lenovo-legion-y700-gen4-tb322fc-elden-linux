# #477 · 「早期写 framebuffer 是安全的」是纯静态推理 —— 上机两次都致命

- 日期：2026-10-31（一晚两发换来的）
- 背景：UEFI（Mu/edk2）在 A2 形态下**能交棒但全静默**，需要早期观测面。静态分析给的结论是「安全」：
  - `ModuleEntryPoint.S:32` 先 `ArmDisableCachesAndMmu` ⇒ 进到 `PrePi.c` 的 C 代码时 **MMU 是关的**；
  - `Display Reserved`（`0xFC800000`，43 MiB）在 `PlatformMemoryMapLib.c:35` 是**普通 DDR**（`AddMem … WRITE_THROUGH_XN`）；
  - SEC/PrePi 路径**没有 SMMU 初始化**（`QcomMmuDetachHelperLib` 未被 dsc 引用），而 CPU store 不过 SMMU；
  - ⇒ 「裸物理 DDR store，安全」。
- **实测：两次独立实验都死。**
  ① `VIS-R1`：在 **BootShim**（重定位前）里写 `0xFC800000` ⇒ **60/60 fastboot、不交棒**；
  ② `VIS-R2`：在 **PrePi `CEntryPoint` 首语句**写同一地址（MMU 已关、静态判定「安全」的那个位置）⇒ **同样不交棒**。
  同晚**同一份 10-30 原件 `A2-v0b.img`（一字节未改）仍然交棒** ⇒ 不是概率、不是台架，是这两处改动本身。
- 结论：**「关 MMU 就能随便写物理地址」是错的**。至少还有别的门槛（候选：该窗口 display 电源域/时钟未起、
  该区被 XPU/XPU-SMR 保护、ABL 已把该区标成设备内存、写触发 abort 而当时无 handler）。**原因仍未证实。**
- 教训（可推广，比这个具体地址重要）：
  - **静态推理只回答「按代码看应该怎样」，不回答「硬件此刻允许」。** 涉及 MMIO / reserved-memory / 电源域 / 保护域的写，
    静态结论最多写成「候选」，必须上机证伪或证实后才写「安全」。
  - 判据设计要**带对照组**：这次正因为有「A2 原件仍交棒」的对照，才能把「重建即失效」与「写 FB 致命」区分开；
    否则会把两次失败都归成「A2 不交棒」，结论跑偏一整轮。
  - 报告里已经写过的风险（「若 shim 时刻 fb 被 ABL 关显示，色条写了也看不见」）**低估了严重程度**：
    实际不是「看不见」，是**写它就死**。风险描述要往「可能致命」而不是「可能无效」写。
