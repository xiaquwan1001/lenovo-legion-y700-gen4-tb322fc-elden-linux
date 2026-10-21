# kexec（Q11）可执行实验方案 — 2026-10-21

> **定位**：把 Q11 从「掉电根因已定位、目标内核引导失败未解」推进到**可执行实验序列**。
> 新增能力：主机串口常驻采集（`scripts/serial-logger.sh` / `scripts/serial-fanout.sh` → `/dev/ttyACM0`，2026-10-20 打通）。
> **本文件只读研究 + 规划**；本 lane 未发出任何设备写命令（开工时 `fastboot devices` = `HA2EXB0E`；收尾时该 SN 已不在 fastboot —— 设备被**并行 lane** 启动到 Linux（`/dev/ttyACM0-1` 出现、串口日志在 `t=56 s` 持续输出），非本 lane 所为）。
> 结论口径：`【已证实】`=有仓库内路径行号或命令输出；`【未证实】`=有线索未闭环；`【推测】`=机制推理，禁止当结论引用。

---

## 0. 结论速览

1. **串口常驻采集不是“早期串口”**（最重要口径修正）。`/dev/ttyACM0` = USB CDC-ACM gadget 的 `ttyGS0`，≈8.8 s 才注册；但它**不是没用**：console 注册时 `CON_PRINTBUFFER` 会回放 ring buffer，实测含 `[0.000000]` 的 `setup_arch` 行 ⇒ 可作“目标是否进过 `setup_arch`”的判据。另发现 **ramoops@0xc2000000 会被 live-DT 重建带进目标内核**，配合 `PSTORE_CONSOLE=y` = 真正的早期可见性候选（待 C2）。【已证实】+【推测】
2. **“目标内核引导失败”至今没有任何一条设备证据**，历史结论只有“约 20 s 回 boot_b”。而默认 cmdline 带 **`panic=15`**（`scripts/build-boot.sh:67`）⇒ “目标起来了→panic→15 s 自复位→ABL 回 boot_b”与观测时标完全吻合。因此 H9（panic 归因陷阱）必须先排除，否则后面全是错靶。
3. **假设重排**：H1（SMMU 活跃 stream）仍第一，且得到两条新硬支撑：`arm_smmu_device_shutdown()` 就挂在 `.shutdown` 上、mask=1 必然跳过；而 cmdline 又用 `arm-smmu.disable_bypass=0` 把 BYPASS 打开（默认应为 FAULT）⇒ 残留 DMA 是“直通内存”而非 abort。H2（ITS/LPI）降级（`GENERIC_IRQ_KEXEC_CLEAR_VM_FORWARD=y` + CPU offline 的 `irq_force_complete_move()` 已收尾）。H5（VA_BITS_52 trans_pgd）**彻底作废**（修复已在树 + file-load 不走 trans_pgd）。
4. **最关键实验只一条**：kexec 到**逐字节相同的 Image**（C1）——一次回答：7.3 上 mask=1 是否仍到 `Starting new kernel`、交接机制本身有无病、历史上“目标起不来”是镜像还是交接问题（旧 `Image.kd` 已随换机丢失，无法考古）。
5. **代码只需一件事**：mask=1 旋钮回植到 7.3（~40 行；`patches/kernel-history/elden_vk53-hw/0019+0020` 可直接用，`stop_after/settle_ms` 不需要）。可选加 D2（跳转前只关 SMMU，~30 行）做 H1 直证。
6. **裁决：可解、值得试，但列并行低优先**（6–8 轮 × ≤10 min，全零写盘）。它不是 Q28/Q24 的解锁器（那两者约束是机理不可见，不是重启速度）。

---

## A. 现状事实表

> 树 = **`build/m1-73`（Linux 7.3.0-rc7，HEAD `24223e4` + 3 个未提交修改：`sm8750.dtsi`(EDL dload)/`tcsr.yaml`/`hci_qca.c`）**。`linux/`→`geekidos-linux` 是 7.2.0 `v7.2-elden`（实验/归档血统，已非基线）。

| # | 事实 | 证据（路径:行 / 命令输出） | 状态 |
|---|---|---|---|
| A1 | 设备停在 fastboot，SN `HA2EXB0E` | `timeout 20 fastboot devices` → `HA2EXB0E\tfastboot` | 【已证实】 |
| A2 | **只有 `kexec_file_load(2)`**：旧系统调用 `CONFIG_KEXEC` 未编译；⇒ `kexec -l` 能用**只因为** kexec-tools ENOSYS 后回退 file syscall；`--dtb=` 在 file 路径上是**静默空操作**（伪单变量陷阱） | `.config:294-297`（`KEXEC_CORE=y`、`# CONFIG_KEXEC is not set`、`KEXEC_FILE=y`）；`archive/topics/KEXEC-2026-10-05.md:13` | 【已证实】 |
| A3 | `crashkernel=` 支持在，但**默认 cmdline 没有**；`KEXEC_HANDOVER`（7.3 新特性）未开 | `.config:292 CRASH_RESERVE=y`、`:298 CRASH_DUMP=y`、`:304 # KEXEC_HANDOVER is not set`；`scripts/build-boot.sh:67` 无 `crashkernel=` | 【已证实】 |
| A4 | 上游 trans_pgd VA52 修复（`1537e55728ec`）**已在树** ⇒ 2026-10-09 报告「本树未打」**已作废**（差量：那棵是 7.2 `d02658e63`）；且 file-load 走 IND_DONE in-place、**不建 trans_pgd** ⇒ 该缺陷对现路径本来就无关 | `arch/arm64/kernel/machine_kexec.c:132` = `_PAGE_OFFSET(vabits_actual), PAGE_END`；`:117`（IND_DONE 提前返回）、`:188-198` | 【已证实】 |
| A5 | **`device_shutdown` mask/诊断补丁不在树**；掉电调用链：`kernel_kexec` → `kernel_restart_prepare()` → **`device_shutdown()`**（内含 `cpufreq_suspend()`） | `drivers/base/core.c:4875 device_shutdown()`、`:4882 cpufreq_suspend()`，无 skip 开关；`kernel/kexec_core.c:1138/1192-1194`；`kernel/reboot.c:101/106`；`grep -rl kexec_diag` 只命中 `patches/kernel-history/elden_vk53-hw/00{19,20,22,23}-*.patch` | 【已证实】 |
| A6 | 掉电**非单一元凶**（`cpufreq_suspend()` + 设备遍历多触发叠加），唯一可靠规避 = 整段跳；mask=1 已能到 `Starting new kernel` | `archive/topics/KEXEC-DIAG-TEST-PLAN-2026-10-08.md:202-206`（§9.1）、`:113-119`（§6.2） | 【已证实】 |
| A7 | 普通 kexec **不掩中断**（`machine_kexec_mask_interrupts()` 仅 crash 路径）；但 ITS/LPI 的 kexec 收尾机制是编进去的 | `machine_kexec.c:211/220`（`machine_crash_shutdown()` → mask）、`:163 machine_kexec()`；`.config:75 GENERIC_IRQ_KEXEC_CLEAR_VM_FORWARD=y`、`:10407 ARM_GIC_V3_ITS=y` | 【已证实】 |
| A8 | 目标 FDT 由 **live DT 重建**：删/加 `kaslr-seed`（**新随机**）、写 `linux,booted-from-kexec`/initrd/`usable-memory-range`；**不删 `reserved-memory`** ⇒ **ramoops 节点会带进目标内核** | `drivers/of/kexec.c:489-504`、`:521`、`:446-464`、`:351`；`sm8750-lenovo-elden.dts:1460-1466`（`ramoops@c2000000` 4 MiB，console 2M + pmsg 2M，`no-map`）；`.config:11041-11047`（`PSTORE_RAM/CONSOLE/PMSG=y`） | 【已证实】（DT/config 层）+【推测】（目标能否真写，待 C2） |
| A9 | **串口常驻采集 ≠ 早期串口**：`/dev/ttyACM0` = USB CDC-ACM gadget 的 `ttyGS0`，≈8.8 s 才注册；但 console 注册时会**回放 ring buffer**（实测含 `[0.000000]` 的 setup_arch 行） | `scripts/serial-run.sh:4`、`build-boot.sh:62`；`PITFALLS/sessions/06-脚本工具.md:114`（#110）、`01-引导fastboot重启交接.md:30`；实测 `ttyACM0.log:540-577`/`:6168-6190`，而 `grep -c "Booting Linux\|Linux version"` = **0** | 【已证实】 |
| A10 | 默认 cmdline 带 **`panic=15`** ⇒ 历史「跳转后 ~20 s 回 boot_b」与「目标起→panic→15 s 自复位→ABL」**时标完全吻合** | `build-boot.sh:67`（`loglevel=8 ignore_loglevel panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0`）；时标 `KEXEC-DIAG-TEST-PLAN:128-129` | 【已证实】（cmdline）+【推测】（归因） |
| A11 | 旧载具已丢（`out/` 只剩 `vk77-modkdump.manifest`，需按 7.3 重建）；但 `kexec-boot.sh`/`kexec-diag-test.sh`/`kexec-bs-cycle.sh` 在位 | `ls out/*.img` 仅 vk64/vk127/vk130-133/elden；`kexec-boot.sh:5` 明写 file syscall 且不收 `Image.gz` | 【已证实】 |

---

## B. 「目标内核 kexec 引导失败」假设清单 + 判别信号

### B.0 先定观测窗（决定了“能看见什么”和“看不见不等于没发生”）

| 窗口 | 何时开启 | 能看到什么 | 证据 |
|---|---|---|---|
| W0 `0 s`–gadget 起 | 目标跳入→`usb-gadget` 绑定 `ttyGS0` | **无实时输出**；但 console 注册时 `CON_PRINTBUFFER` **回放 ring buffer 残存内容**——实测含有 `[0.000000]` 的 setup_arch 行（`OF: reserved mem`、`psci: probing …`、`Zone ranges`） | `PITFALLS/sessions/06-脚本工具.md:114`（≈8.8 s）；实测 `ttyACM0.log:540-577`、`:6168-6190`；`LOG_BUF_SHIFT=20`（1 MiB）⇒ 回放是残片，**不保证含第一行** |
| W1 `≈8.8 s`+ | 目标自己拉起 gadget（需 initramfs/磁盘根） | 目标实时 console（`ignore_loglevel` 下极详尽） | `scripts/build-boot.sh:62` `console=ttyGS0,115200` |
| W2 ramoops（`device_initcall` 级） | 目标 probe `ramoops@c2000000` | 之后所有 printk（含 panic）落 DRAM，回 boot_b 后可读 | dts:1460-1466、`.config:11041-11047`、`of/kexec.c`（不删 reserved-memory）【推测待验】 |

**铁则**：`ttyACM0` 上“什么都没有”**只等于**“目标未活到 gadget + 没写进 ramoops + 回放没命中”，**不等于**“没启动”。结论只能写“未观测到 W0/W1/W2 信号”。

### B.1 假设表

| # | 假设 | 机制 | 判别信号（现有通道会看到什么） | 强度/已有反证 |
|---|---|---|---|---|
| **H1** | **SMMU 活跃 stream / 残留 DMA**（mask=1 的必然后果） | 整段跳 `device_shutdown` ⇒ `arm_smmu_device_shutdown()`（`arm-smmu.c:2328`，`.shutdown` 在 `:2432`）**从未执行**；UFS/USB/显示/GPU stream 仍使能且在跑 DMA；目标 rescan 时旧 stream 命中旧 SME/S2CR → fault 或 DMA 踩目标 Image | ① W0 回放：目标 `setup_arch` 行出现但紧接死；② W1：`arm-smmu* … Unhandled context fault`/`C_BAD_STREAMID`/`SError`；③ W2：panic 回溯含 `arm_smmu_*` | **最强**（唯一人为引入的非默认状态）；直接反证 = 目标跑到 `arm-smmu` probe **之后**的里程碑（gadget） |
| **H2** | GIC/ITS LPI 未清 | 普通 kexec 不调 `machine_kexec_mask_interrupts()` | W1 里 LPI/`its` 行后紧接 `SError`，或卡在 `its: … allocating LPI` | **已被削弱**：`GENERIC_IRQ_KEXEC_CLEAR_VM_FORWARD=y` ⇒ `irq_force_complete_move()` 经 cpuhotplug 路径（`kernel/irq/cpuhotplug.c:78`）已在 CPU offline 阶段把 ITS 收尾 |
| **H3** | earlycon 未启用（可见性缺陷，非失败因） | 本机无硬件 UART；`ttyGS0` 需 gadget 绑定 | 本身就是“为何过去只看到 20 s 回 boot_b” | 【已证实】；本轮用 W0 回放 + W2 pstore 取代 |
| **H4** | 内存重叠 / crashkernel 保留区 | 目标 Image 装进 memblock hole；若带 `crashkernel=` 则 `crashk_res` 保留；ramoops/DMA 落进保留区或目标自踩 → 段损坏 | ① W2 panic = `Unable to handle kernel paging request` 且地址在 `crashk_res`/ramoops 区；② 载具 `crashkernel reserved:` 行与目标 `reserved mem` 列表比对 | 中；**极便宜**（同 Image 只改 `crashkernel=` 有无） |
| ~~**H5**~~ | ~~VA_BITS_52 / LPA2 trans_pgd~~ | — | — | **已排除**：修复已在树 + file-load 不走 trans_pgd（A4）。正向信号：目标 dmesg 应有 `52-bit Virtual Addressing (LPA2)` |
| **H6** | KASLR（目标拿到新 seed） | live-DT 重建**删旧 `kaslr-seed` 再注新 seed** ⇒ 目标基址每轮不同 | ① 同二进制多轮“有时活有时死”= 强指基址；② 加 `nokaslr` 后由“必死”变“活” = 命中 | 中；**1 轮** |
| **H7** | DTB 传递 | `--dtb=` 在 file 路径上是**空操作**（A2），DTB 由 live DT 重建 | W1 里目标 `/proc/device-tree/chosen` 有 `linux,booted-from-kexec`；`bootargs` = 传入 cmdline | 【已证实】机制；⇒ “用 `--dtb` 做变量” = 伪单变量 |
| **H8** | EL2/Gunyah 对 EL1→EL1 二次入场 | `is_hyp_nvhe()=false` ⇒ 不走 `__hyp_set_vectors`，EL1 关 MMU 直跳 | 不可观测（无 EL2 通道） | 低优先，**不可证** |
| **H9** | **`panic=15` 归因陷阱**（误判源，非失败因） | 目标继承 `panic=15` ⇒ 目标 panic 后 15 s 自复位→ABL→boot_b，外观与“挂死/掉电”相同 | 从 `kexec -e` 到 ttyACM0 再有输出的**墙钟**：`15±3 s` = 走过 `panic()`；`>60 s` = 更像挂死/PMIC 掉电 | 【已证实】cmdline（A10）；**所有历史“约 20 s 回来”的默认解释** |

### B.2 假设→实验映射（信息量/成本）

- 免费：H9（加墙钟对比）、H7/H5（只读 cmdline/DT）。1 轮：H6（`nokaslr`）、H4（`crashkernel=`）。1–2 轮：H1（同内核自跳 + D2）、H2（跟 H1 同轮看日志）。
- **最关键对照 = kexec 到逐字节相同的 Image**：同镜像自跳也死 ⇒ 与镜像内容无关，必在交接/遗留状态（H1/H2/H8）；活 ⇒ 旧 `Image.kd` 的构建/配置才是问题（而它已随换机丢失，A11）。

## C. 实验序列（每条 ≤10 min，零写盘优先）

### C.0 前置（主机侧 + 只读，不计轮次）

1. **构载具**：`vk134` = `build/m1-73` + D1 → `out/boot-elden-vk134.img`（持久变体：RAM 内核 + 磁盘根；≤96 MiB）。
2. **健康门**：`scripts/trial.sh gate`（只读 boot_b `succ/retry`）；WARN 则 `python3 scripts/slot-attr.py mark-successful b`。
3. **串口就位**：`systemctl is-active elden-serial-logger`=`active`；**记 `stat -c %s /var/log/elden-serial/ttyACM0.log` 偏移**，实验后只读新增段。
4. **每轮落 record**：`scripts/trial.sh record --reset por`（无 record 不得写 verdict，`.pi/AGENT-OPS.md:45`）。

### C.1 实验表

| # | 目标 | 操作（全部 `fastboot boot` 零写盘 + `kexec -s -l` + `kexec -e`） | 成功/失败判据 | 人在场 | 时长 |
|---|---|---|---|---|---|
| **C1** | **7.3 基线复原 + 同镜像自跳（控制组）** | ① `fastboot boot out/boot-elden-vk134.img`；② SSH 验 `uname -r` 含 `vk134`；③ 记串口偏移；④ `echo 1 > /sys/kernel/kexec_diag/kexec_diag`；⑤ `kexec -s -l Image --initrd=<同一 ramdisk> --command-line="$(cat /proc/cmdline) nokaslr"`（**目标与本内核逐字节相同**）；⑥ 验 `kexec_loaded`=1；⑦ `sync; kexec -e` | **PASS**：串口新段出现第二次 `[0.000000] psci: probing …` 回放且 SSH 回来 `uname -r`=`vk134` ⇒ **Q11 当场解**。**MID**：有 `Starting new kernel` 但 ~15±5 s 回 boot_b ⇒ 进 C2–C6。**FAIL**：无 `Starting new kernel` ⇒ 7.3 上掉电规避不成立（回 §9 二分，超本 lane） | 否；挂死不自复位时需按电源键 | 8 |
| **C2** | **可见性阳性对照（必须最先做）** | 同 C1，目标 cmdline 改**必然失败**：`… nokaslr root=/dev/does-not-exist panic=20` | **PASS**：回 boot_b 后能在 W2/W1 看到目标自己的 init 失败/panic 文本。**FAIL**：什么都没有 ⇒ W2 不可用 ⇒ 后续只能靠 W0 回放（结论口径降级） | 否 | 7 |
| **C3** | **H6 KASLR 单变量** | 同 C1，目标 cmdline **去掉 `nokaslr`**，其余逐字相同 | 同镜像多轮：“有 nokaslr 必活 / 无 nokaslr 必死” = H6 成立；两臂同结果 = H6 排除 | 否 | 7 |
| **C4** | **H4 crashkernel/内存保留** | 同 C1，目标 cmdline **加 `crashkernel=64M`** | 仅带 `crashkernel=` 时死 ⇒ H4；两臂同结果 = H4 排除 | 否 | 7 |
| **C5** | **H1 SMMU bypass（零代码单变量）** | 同 C1，目标 cmdline `arm-smmu.disable_bypass=0` → `=1` | 死→活 = 残留 stream 真在 DMA 踩内存（H1 钉死）；活→死 = bypass 是该机正常工作的必要条件 | 否 | 7 |
| **C6** | **H1 直证（需 D2）** | `vk135` = vk134 + 跳转前仅对 `arm,mmu-500` 设备调 `.shutdown`（写 `sCR0.CLIENTPD`），目标同镜像 | 变活 ⇒ H1 钉死；仍死 ⇒ H1 不足，转 H2/H8 | 否 | 7 |
| **C7** | **H9 归因（“到底是 panic 还是掉电”）** | 同 C1，目标 cmdline **去掉 `panic=15`**（`panic=0` = panic 后不重启） | 设备**不回** boot_b 而是挂死（需按电源键）⇒ 目标真的 panic 过；仍 ~15 s 回 ⇒ 不是 panic，是复位/掉电 | **是**（需按电源键/断电） | 10 |
| **C8** | **kdump 复跑（crash 路径隔离）** | `crashkernel=64M` 启动 + `kexec -s -p` + `echo c > /proc/sysrq-trigger`，crash 内核 cmdline 加 `keep_bootcon` | W2 有 crash 内核记录 ⇒ crash 路径能跳进目标早期（把 H1/H2 与跳转机制切开）；无 ⇒ 本机 crash 也看不见 | 否 | 10 |

### C.2 判读规则（防误判）

- **先对齐时钟**：记“`kexec -e` 墙钟 + 串口日志偏移”。回 boot_b 延迟 `15±5 s` ⇒ 目标走过 `panic()`（H9）；`>60 s` ⇒ 挂死/PMIC 掉电。
- **回放看特征行**：目标应在回放里出现 **`psci: probing for conduit method from DT.`** 与 `Zone ranges`（本机正常启动实测就有：`ttyACM0.log:6168-6190`）。**只看时间戳不够**（可能回放到旧内容）。
- **一变体一轮，最多两轮**（第 2 轮只验可重复性，不跑第 3 次）；命令拆单条（`PITFALLS` #3）；不用封装脚本代跑 fastboot（`.pi/AGENT-OPS.md:37`）。
- C1 PASS ⇒ C3–C8 降为可选优化。

## D. 需要的代码改动最小集（只写方案，本轮不落地）

| # | 改动 | 为什么必需 | 工作量/风险 | 现成资产 |
|---|---|---|---|---|
| **D1** | **mask=1 旋钮回植到 7.3**：`kernel/kexec_core.c`（`diag_skip_mask` + `/sys/kernel/kexec_diag`）、`kernel/reboot.c`（`kernel_restart_prepare()` 里 `if (kexec_in_progress && (diag_skip_mask & SKIP_DEVICE)) return;`）、`include/linux/kexec.h` | A5：基线无此旋钮；A6：“唯一可靠规避 = 整段跳 device_shutdown” ⇒ 不回植就无法在 7.3 做任何 kexec 实验 | ~40 行；只影响 kexec 路径；两处锚点代码未变（`reboot.c:101-106`、`kexec_core.c:1191-1194`）⇒ `git am -3` 应基本干净 | `patches/kernel-history/elden_vk53-hw/0019-*.patch` + `0020-*.patch`；**不需 0022/0023**（stop_after/settle_ms 已结题） |
| **D2** | **跳转前只“关 SMMU”**（H1 直证）：mask=1 分支里遍历 platform devices，对 `driver->name` ∈ {`arm-smmu`,`arm-smmu-v3`} 调 `dev->driver->shutdown(dev)` | A10 + `.config:9231`：`disable_bypass` 默认 FAULT，但 cmdline 改成 0（BYPASS）⇒ 残留 stream “直通内存”而不 abort；而 `arm_smmu_device_shutdown()`（`arm-smmu.c:2328`，`.shutdown` `:2432`）只写一个寄存器 `sCR0.CLIENTPD`，**不碰 regulator/PMIC** ⇒ 理论上不触发 §9 掉电 | ~30 行；`CONFIG_ARM_SMMU=y`（内建）⇒ 直接链接，无需 EXPORT | 新写 |
| **D3** | **目标侧可见性：不加代码**（DT/cmdline 层） | A8：ramoops 节点会被 live-DT 重建带进目标 FDT，`PSTORE_CONSOLE=y` ⇒ 目标自己就能写（待 C2 验证）。若要不混淆，加**第二个** ramoops 节点（`ramoops@c2400000`，~8 行）只给目标用 | 极低；**先不加**（少一个变量） | `sm8750-lenovo-elden.dts:1460-1466` |
| **D4** | ~~目标 cmdline 加 `earlycon`~~ | — | **不做**：本机无硬件 UART（A9）；gadget 上拿不到早期输出 | — |
| **D5** | 脚本卫生（非内核）：`kexec-boot.sh` 删 `--dtb=`（file 路径静默空操作，A2/A11）；目标 cmdline 不默认继承 `panic=15` | 防伪单变量 / 防 H9 常驻 | 低 | `scripts/kexec-boot.sh:5,71,77` |
| **D6** | （上游化，不阻塞）mask=1 → “只跳 `cpufreq_suspend()` + 只关 SMMU/USB” | §9.1：`K=0`（零真关机）仍掉电 ⇒ 先得找到真实触发（PMIC/regulator），属深度硬件工作 | 高；**不在本里程碑** | — |

## E. 结论：可解性与投入产出

1. **可解，且第一次真正可判**。阻塞不是“kexec 不会用”，而是**缺可见性**（A9）。本轮把可见性拆成三层：W0 ring-buffer 回放（`psci:`/`Zone ranges` ⇒ 目标已进 `setup_arch`）、W1 目标自己的 gadget console（需 initramfs）、W2 ramoops/pstore（`device_initcall` 级，含 panic）。**C2 是本轮真正里程碑**：它一旦 PASS，后面每个“失败”都变成有含义的观测。
2. **最可能只差一次实验**：C1（kexec 到逐字节相同的 Image）同时回答：① 7.3 上 mask=1 是否仍到 `Starting new kernel`（A6 跨版本复核）；② 交接机制本身有无病；③ 历史上“目标起不来”是镜像问题还是交接问题（旧 `Image.kd` 已不可考，A11）。
3. **假设排序被本轮证据改写**：H1 仍第一（`arm_smmu_device_shutdown()` 就挂在 `.shutdown` 上、mask=1 必然跳过；cmdline 又开了 BYPASS），且有**零代码单变量**（C5）；H2 降级（ITS 收尾机制已在）；**H9（`panic=15`）升为“先排除的归因陷阱”**（它免费，却能推翻一半历史叙事）；H5 彻底作废（A4）；H8 不可证。
4. **投入**：主机侧 ~半天（D1 + 构 vk134）；设备侧 **6–8 轮 × ≤10 min ≈ 60 min**，全零写盘。产出要么是“Q11 解开 + 热重载快环”，要么是一张签名清楚的失败表。
5. **ROI：值得试，但不抢主线**。kexec 只省“换内核 2–3 min + 需人在场”；Q28/Q24 的约束是机理不可见 ⇒ 列**并行低优先**（每轮 ≤10 min、一次 ≤3 轮）。
6. **明确不做**：`earlycon`/真 UART 改造（无硬件）；`device_shutdown` 逐设备二分（A6 已结题）；重复论证“kexec 能不能用”（已到 `machine_kexec`）。

