# UEFI 线换向调研：先把「看得见」修好，再谈 UFS/显示

> 2026-11-01 11:40–12:10 CST。性质：**只读调研 + 主机侧取证**（唯一设备接触 = ssh 只读 dd/读 sysfs，零写盘、无 fastboot、无 reboot）。
> 触发：用户指出「红条目视方案」已连败多轮（过联想 logo 立即黑屏掉电、无任何可观测点），要求换方向调研。
> 证据等级：`已证` = 今日实测命令输出 / file:line；`外部` = 上游仓库/文档原文；`未证` = 推断。

---

## §0 八条结论（先看这里）

1. **`logfs` 不是「每次启动重写的一小段」，而是最近 10 次 ABL 启动的环形日志**（8 MiB = 10 × 64 KiB，今日实测）。
   历史脚本（`scripts/abl-log.sh`）只解析最新那一段 ⇒ 我们一直丢掉前 9 次启动的 ABL 日志。`已证`
2. ABL 日志明写 **`HW Wdog Setting from PCD : Enabled`**（Qualcomm 官方参考日志是 `Disabled`），同段还有
   `WatchdogTimer.efi`、`boot_wdog_disable_check` ⇒ **载荷被武装了硬件看门狗**；而 `b .` 自旋臂同样 1–2 s 复位，
   **只有看门狗能复位一个死循环** ⇒ 1–2 s 掉电的头号解释仍是 wdog，且现在有 ABL 侧的文字证据。`已证`+`外部`
3. 本机**已有三条可读的崩溃取证分区**：`mdcompress`(20 MiB, minidump 压缩区)、`xbl_sc_logs`(128 KiB, 安全世界日志)、
   `xbl_ramdump_a/b`(各 2 MiB)。今日实测：**`mdcompress` 与 `xbl_sc_logs` 全 0**（多轮 handoff+复位之后仍然全 0）
   ⇒ 这些复位**没有**走 XBL/APSS 的崩溃转储路径，进一步支持「PMIC/硬件 wdog 复位」而非「异常被 XBL 捕获」。`已证`
4. **同 SoC 同形态（SM8750 平板）已有成功先例**：`SunUEFI`（小米平板 8 Pro / piano）——UEFI + Debian 可用，
   **物理屏上能看到它的阶段色块**，而且它**不走 `fastboot boot`**：走「合体 BOOT」（选择器 + 原厂内核 + UEFI 核心同一个 boot 镜像，
   ABL 按 header `kernel_size` 整段加载）。⇒ 我们卡的第一现场可能不是「载荷写错」，而是**装载路径不同**。`外部`
5. 我们自己的 Mu 树里**已经有 `Platforms/PakalaPkg/Device/xiaomi-piano/`**（同 SoC 设备包），可与我们 `lenovo-y700g4/`
   做同代 delta；两者的 `QcomWDogDxe.efi` 逐字节相同，`UFSDxe.efi` 不同（且树内至少有 3 个不同 UFSDxe 变体）。`已证`
6. **EUD = USB 口里的隐藏 JTAG/SWD**（Qualcomm 2025-02 开源了 EUD 库 + OpenOCD 分支；Linux 侧 `drivers/soc/qcom/eud.c` 已上游）。
   本机内核 **`CONFIG_USB_QCOM_EUD=m`** 已开。这是「不画红条也能知道载荷停在哪」的正解方向：真调试器。`外部`+`已证`
7. **不依赖屏幕的进度取证**完全可行（且比红条强一个量级）：把 checkpoint 写进一块被 Linux DT 保留、内核永不触碰的 DDR，
   复位后从 Linux `/dev/mem` 读回——**DDR 内容在 PS_HOLD 热复位后仍在**。这样能同时拿到「走到第几步」和「进入载荷到复位过了多少纳秒」。`未证`（需一次上机验证）
8. 历史唯一**屏上真出过字**的配方（10-05：`PakalaNoSb.dsc` RELEASE + `SCALE_FACTOR 3` + 未补丁 UFSDxe）**从未用干净 v0 header 复测**；
   而 11-01 的「7/7 载荷都被执行」证明当时那批判据被 header 污染。这条复测仍然是成本最低的「J1 出字」路径。`已证`（历史报告）+`未证`（复现）

---

## §1 今日新取证（本机实测，全部只读）

### 1.1 `logfs` 是 10 段环形日志（纠正既有口径）

```
ssh root@192.168.7.1 'dd if=/dev/disk/by-partlabel/logfs'   → 8 388 608 B
每 0x10000（64 KiB）一段：QC_IMAGE_VERSION_STRING 出现 10 次；
每段各有独立的 "PM: Reset by …" / "PM: Reset Type: …" / "Booting from slot (_x)" / "Start EBS [n]"。
```
- 结论：**前 9 次启动的 ABL 日志都还在盘上**，只在被第 11 次启动覆盖时消失。
- 影响：历史结论「交棒失败后回落 stock 会覆盖 ⇒ 无法给载荷死在哪取证」**只对最新一段成立**；对「上一次」不成立。
- 已见字段（可用于逐启动重建时间线）：`PM: Reset by PSHOLD` / `PM: Reset Type: Hard Reset|Shutdown` /
  `PON by SYSOK|PWR key DEB` / `Booting from slot (_a|_b)` / `Start EBS [13400]`（正常启动）vs `[4085]`（fastboot 模式）。
- 今日这 10 段里：9 段 `Booting from slot (_a)`（回落 Android）、1 段 `(_b)`（我们的 Linux）、1 段 `Shutdown/PWR key DEB`（用户物理断电真 POR）。

### 1.2 看门狗：ABL 侧文字证据

```
... 0x0D77CA000 [ 1542] DxeCore.efi
HW Wdog Setting from PCD : Enabled
...
D - 305 - boot_wdog_disable_check
```
- Qualcomm 官方 UEFI 日志样例（dragonwing / 80-70017-4）里同一行是 `Disabled`，跟着 `WatchdogTimer.efi`。
- 我们的 Mu 树里 `QcomWDogDxe` 也被登记在 **`APRIORI.inc:10`（很早）**，说明 Mu 侧本来也会去配置它；
  1–2 s 内死掉 ⇒ 大概率**在它跑起来之前**就已经复位。
- **待办**：ABL 的 `PcdWatchDog*` 超时值是多少（决定我们到底有多少时间窗），以及 Mu 侧同名 PCD 的默认值。

### 1.3 崩溃取证分区（可读，但为空）

| 分区 | 大小 | 今日内容 | 含义 |
|---|---|---|---|
| `mdcompress` | 20 MiB | **全 0** | minidump 压缩区；多轮复位后仍空 ⇒ 这些复位没有生成 minidump |
| `xbl_sc_logs` | 128 KiB | **全 0** | 安全世界（TZ）日志；空 ⇒ 无 TZ assert |
| `xbl_ramdump_a/b` | 各 2 MiB | 有二进制内容，a/b 差 1631 B，无可读字符串 | 疑似静态/训练数据，暂不作判据 |
| `ddr` | 1 MiB | 有内容（DDR 训练参数） | 与本问题无关 |
| `misc` | 1 MiB | `bootonce-bootloader` | 现有 `reboot bootloader` 机制的真身 |

⇒ **判据**：如果 1–2 s 复位是「APSS 异常被 XBL/TZ 接住」，minidump 或 xbl_sc_logs 应该有东西；现在两者都空，
**更符合硬件 wdog 复位**（PMIC 直接拉 PS_HOLD，没有任何软件经手）。这条与 §1.2 相互独立地指向同一结论。

### 1.4 设备当前状态（只读）

`uname -r` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`（在机 `boot_b` = vk183 线），
根 `sda17`，ssh over USB-NCM 正常；`CONFIG_USB_QCOM_EUD=m`、`CONFIG_POWER_RESET_QCOM_PON=y`、
`smem@0x81d00000` 2 MiB nomap 保留区在 DT 里。

---

## §2 外部调研（同芯片/同形态参考）

### 2.1 `SunUEFI`（小米平板 8 Pro = piano = SM8750）—— 最强的参考系

- **它的装载路径与我们完全不同**：`合体 BOOT` = 开机选择器 + 原厂 Android 内核 + UEFI 核心放进**同一个 boot 镜像**，
  「内核留在原位，只把入口分支改向一个小选择器；选择器和 UEFI 接在内核之后，由 ABL 按 header 的 `kernel_size` 整段加载」。
  临时调试才用 `fastboot boot`；它自己的 fastboot **不实现 `boot`**（`PIANO_FASTBOOT_MAX_DOWNLOAD` 64 MiB，`boot` 返回未实现）。
- **屏上色块在这个 SoC 上是能看见的**（`docs/devel/uefi-display-checkpoints.md`）：蓝/绿/橙/紫/青蓝五段
  `BEFORE DRIVERS / BEFORE CLOCK / AFTER CLOCK / AFTER DRIVERS / AFTER UFS / BEFORE SIMPLEINIT` 每段停 3 s，
  实机确认蓝块可见 ⇒ 之后白屏的根因被它定位到**原厂 `ClockDxe` 的 CESTA/media + DCD 启动初始化**，
  修法是派生 ClockDxe 改 **5 个字节**（`0xc784` BL→`MOV w0,#0`；`0x3ead0` 标志 1→0），之后菜单正常显示。
- **它把状态存在固件内存里并周期重发**（每 5 s 打印摘要），理由原话是「避免早期日志被 UFS 文件读取记录覆盖」
  ⇒ 与我们的「早期可见性」是同一类问题的成熟做法。
- 它还做了 `ramoops` 提前注册 + UEFI fault handler（`docs/linux-efi-memory-debug.md`、`linux-efi-handoff-audit.md`），
  即**把崩溃现场留到下一次启动再读**，思路与我们 §3 的 P0 一致。

**对我们的直接含义**：我们缺的可能不是「UEFI 内部某行代码」，而是**装载路径**（`fastboot boot` vs 正常 boot 路径）
以及**原厂 ClockDxe 的启动序列**（它是 vendor 二进制，Mu 会照跑；SunUEFI 的证据说明它能白屏/黑屏而不报错）。

### 2.2 我们自己的 Mu 树里已有同 SoC 设备包（可直接 diff）

`build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/` 有
`lenovo-y700g4` / `xiaomi-piano` / `oneplus-dodge` / `oneplus-erhai` / `nubia-nx789j`。

`PatchedBinaries` 今日 sha 对比（`已证`）：

| 设备 | QcomWDogDxe.efi | UFSDxe.efi | ClockDxe.efi | PmicDxeLa.efi |
|---|---|---|---|---|
| lenovo-y700g4 | `05173fed…` 28 672 | `00ae059f…` 151 552 | `3e439a7a…` | `e34f2478…` 274 432 |
| xiaomi-piano | `05173fed…`（同） | **`c1f38f91…` 155 648** | `3e439a7a…`（同） | `b5519e13…` 270 336 |
| oneplus-dodge | `05173fed…`（同） | `1ff2d468…` 151 552 | — | `e34f2478…` |
| nubia-nx789j | `05173fed…`（同） | `00ae059f…`（与我们同） | `3e439a7a…` | `e34f2478…` |

⇒ ① 「vendor UFSDxe vs dodge UFSDxe」这个二分**本身不成立**：树内至少 3 个 UFSDxe 变体，我们与 nubia 同件；
② `QcomWDogDxe` 全设备同一件 ⇒ 它由 PCD 驱动，**不能靠换件改行为**；
③ `xiaomi-piano` 是同 SoC 上「已证能起 Linux」的配置，是比 dodge 更对的对照件。

### 2.3 EUD：USB 口里的 JTAG（这条最像「换维度」）

- Qualcomm 2025-02 开源了 EUD 用户态库，并把 OpenOCD 分支改为依赖它；Linaro 博文实测（845/855/865）：
  使能后 PC 上出现 **7 口 USB hub**，其中一口是 EUD 控制口，再用 USB 命令让第二个设备出现，**暴露出 SWD**
  ⇒ 不用拆机、不用焊线、不用买调试器就能 halt/单步/断点（含 Hexagon）。
- 上游 Linux 有 `drivers/soc/qcom/eud.c`；本机内核 **`CONFIG_USB_QCOM_EUD=m`**（现成）。
- 风险/未知：新 SoC（SM8450+ 之后）需要额外改动；量产机可能被 fuse 关闭；**一旦使能会占用/切换 USB 口**
  （我们的 ssh 就走这根线）⇒ 必须先把无线/串口备用通道准备好再试。

---

## §3 方案排序（按「信息增益 ÷ 成本 ÷ 风险」）

> 纪律沿用 `PITFALLS` #477（静态推理只写候选，判据必须带对照组）与 #480（观测窗只有 1–2 s）。
> 全部实验的前提：**先 `fastboot --set-active=b`**，让失败回落直接进 Linux（而不是 stock Android），
> 这样既省 ~30 s，也让 §3-P0 的 DDR 保留区不被 Android 启动过程污染。

### P0（强烈推荐，先做）不依赖屏幕的「黑匣子」：DDR checkpoint + 复位后读回

- **原理**：PS_HOLD 热复位不清 DRAM。在 Linux DT 里加一个 `no-map` 保留区（例如 `0x90000000` 起的 1 MiB，落在 DDR bank 内、
  内核永不分配）；`BootShim`/PrePi 在最早期把 `{序号, cntpct, ESR/FAR/ELR}` 写进去；复位后 Linux `dd /dev/mem` 读回。
- **一次上机能同时回答三件事**：
  ① 载荷到底执行到第几条（拷贝完？cache 维护后？跳进 FD？PrePi 第一条？）；
  ② **进入载荷到复位经过多少 ns**（`cntpct` 差值，`cntfrq` 已知）⇒ 反推 wdog 超时，判定是否为固定超时；
  ③ 如果是异常而非 wdog：自建 VBAR 把 `ESR_EL2/FAR_EL2/ELR_EL2` 落盘 ⇒ **直接给出出错指令地址**。
- **成本**：主机侧 ~100 行 asm + DT 一个节点 + 一次构建；设备侧 2 次操作（`set-active=b`、`fastboot boot`）+ 1 次 `dd`。
- **为什么不违反 #477**：我们只写「Linux 保留、no-map、明确无人使用」的 DDR，不写 MMIO/电源域/显示保留区；
  且第一次实验就带对照（同一 shim 连打两发 `b .`，若 cntpct 差值稳定 ⇒ 固定超时器；抖动大 ⇒ 另有触发源）。

### P1 判定并延长复位窗口（看门狗）

- 先把 §1.1 的 10 段环形日志**逐启动重建**（主机侧 pcap 级分析，零设备操作）：把「fastboot 模式那一段」与
  「紧随其后的回落段」配对，读后者的 `Reset by / Reset Type / PON by`，看 wdog 复位与普通重启是否在字段上可分。
- 然后两条候选：① 在 BootShim 第一条指令处**停表**（若定位到 SoC/PMIC wdog 寄存器；需先静态确认地址与权限）；
  ② 把 Mu 的 `QcomWDogDxe` 的 PCD 改成 Disabled，或把该 DXE 的调用前移到 PrePi 之前。
- **判据**：`cntpct` 窗口从 ~2 s 变成「直到我们主动复位」即成功；对照组 = 同镜像不改 wdog。

### P2 装载路径切换：合体 BOOT 形态（借 SunUEFI 已验证的入口）

- 把现有 Mu FD 塞进 boot 镜像的 `kernel_size` 区段，前面放一个极小选择器/加载器（本质就是现在的 BootShim），
  让 **ABL 走正常 `boot` 路径**而不是 `fastboot boot`。
- 价值：① 隔离「装载路径」这个至今没被单独测过的变量；② 成功即得到**不依赖 PC 的持久 UEFI**；
  ③ 与 SunUEFI 的成功条件对齐，便于直接搬它的经验（ClockDxe 5 字节派生、阶段色块、状态重发）。
- 风险：写 `boot_b` 分区（有备份件 `bootslot-b/`，可 `fastboot flash` 回退）。**先只写 b 槽**。

### P3 参考件替换：用 `xiaomi-piano` 的同代 DXE 组合做对照

- 我们与 nubia 同 UFSDxe、与 piano 不同；piano 是**已证**在 SM8750 平板起 Linux 的配置。
- 单变量实验：只换 `UFSDxe.efi`（piano 件 `c1f38f91…`）/ `PmicDxeLa.efi`（piano 件）各一发，配 P0 的黑匣子读判据。

### P4 复测 10-05 配方（唯一历史「屏上出字」配置）

- `PakalaNoSb.dsc` RELEASE + `SCALE_FACTOR 3` + **未补丁** UFSDxe + **干净 v0 header**（`--base 0x10000000 --kernel_offset 0x8000`）。
- 判据：屏上出现可辨认 ASCII（用户录像），或用 P0 黑匣子读到「已进 BDS」。

### P5 EUD/JTAG（中期，收益最大但需准备备用通道）

- 先在**现有 Linux** 上做只读侦察：DT 是否有 EUD 节点、`qcom_eud` 模块能否加载、`/sys` 暴露什么；
  再决定是否用 `fastboot oem`/寄存器写使能（**此时 USB 会被 EUD 占用**，ssh 会断 ⇒ 需先配好 WiFi/串口备用）。

### P6 硬件 UART 考古（低优先级，保留）

- 树内已有 `QcomGeniSerialPortLib`，本机 PCD 未覆盖；缺的是**测试点位置**证据。EUD 命中概率更高，先做 P5。

---

## §4 与既有结论的关系（哪些要作废/降级）

| 既有口径 | 今日处理 |
|---|---|
| 「交棒失败后回落 stock 会覆盖 ABL 日志 ⇒ 无法取证」 | **降级**：只对最新一段成立；`logfs` 是 10 段环 |
| 「早期写 FB 致命」（#477） | 保留为**未复现的候选**：那两发处于 header 污染期（#479），变量未真正测到 |
| 「交棒条件 = 厂商 UFSDxe × cachefix shim」 | 已由 11-01 纠正块作废，本报告 §2.2 再补一条：UFSDxe 至少 3 个变体，二分不成立 |
| 「J1 屏上出字 = 唯一可见性判据」 | **换向**：先用 DDR 黑匣子（P0）拿到「在哪死、几时死、异常类型」，屏幕出字降为 P4 的副产品 |
| 「同芯片平板亮屏回挖」（10-28 报告） | **新增最强参考**：SunUEFI（piano，SM8750）已证 UEFI + Linux + 物理屏可见 |

---

## §5 工具/资产（今日新增或指出）

- 取证原始件（主机 `/tmp/uefi-forensics/`，建议移到 `reports/artifacts/uefi-forensics-20261101/`）：
  `logfs-1146.bin`（8 MiB，10 段）、`xbl_ramdump_{a,b}.bin`、`xbl_sc_logs.bin`。
- 待写脚本（下一轮）：
  `scripts/logfs-decode.py`——按 64 KiB 切段，输出每启动一行（reset 类型 / slot / Start EBS 时刻 / 关键错误），
  用于任何一次上机后的自动分诊；
  `scripts/ddr-blackbox-read.sh`——按 DT 保留区 PA 读回 checkpoint 并解析（序号 / cntpct 差 / ESR-FAR-ELR）。
- 阻塞（非本线）：`pi-fabric` 子代理在本机不可用 —— `Fabric workers require Node.js 24+; detected 22.23.4`
  （需要 Node 24 或 Bun，或 `PI_FABRIC_NODE_BINARY` 指向其一）。本轮所有调研由主会话直接完成。

---

## §6 证据清单

- 设备侧只读：`ssh root@192.168.7.1` 的 `dd`/`blockdev`/`/proc/iomem`/`dmesg`/`/sys/class/reboot-mode`（本轮全部只读）。
- ABL 日志：`/tmp/uefi-forensics/logfs-1146.bin`；历史单段解析件 `reports/artifacts/uefi-boot-20261101-*/abl-log.txt`。
- 外部：`lmnduy/SunUEFI`（README、`docs/devel/uefi-display-checkpoints.md`、`docs/devel/uefi-console.md`、
  `docs/fastboot-ram-boot-plan.md`、`docs/linux-efi-memory-debug.md`）；Linaro EUD 博文（2025-06-30）；
  Qualcomm UEFI log 文档（`80-70017-4`，`HW Wdog Setting from PCD : Disabled` 样例）。
- 本地树：`build/uefi-woa-prep/repos/7-mu-lenovo`（`6b6ac42a`），`Platforms/PakalaPkg/Device/*/PatchedBinaries/*`。
