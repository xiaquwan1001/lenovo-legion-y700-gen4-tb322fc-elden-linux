# kexec ITS/LPI 根因与修法：SM8750 的 EnableLPIs 是 RES1，只能「认领」不能「清」

- 日期：2026-10-24
- pi 会话 id：$PI_SESSION_ID
- 主题：kexec 目标「静默挂死」的真因（GIC ITS 命令队列停摆）+ incoming 侧 claim 修法
- 结论（一句话）：**kexec 交接后 `GICR_CTLR.EnableLPIs` 在本 SoC 上是 RES1、清不掉，而 LPI 属性表/待发表跨 kexec 没有被保留 ⇒ incoming 内核 `redist_disable_lpis()` 返回 -EBUSY、`its_cpu_init()` 直接返回、LPI 从未重配 ⇒ ITS 命令队列停摆（99 次 ×1.25 s，`/init` 被拖到 126 s）。修法 = incoming 侧用 `memblock_reserve()` **认领**继承的 LPI 表、走 preallocated 路径：`ITS queue timeout 99→0`、`/init 126.35 s→1.31 s`。**
- 证据指针：`reports/kexec-target-boots-20261024.md` §6/§7/§8；
  `reports/artifacts/kexec-pstore-probe-20261024/{k5,k8,k13,k15,k16}-*`（目标逐字 dmesg + 载具 `k8-carrier-kmsg.log` + 内核写盘报告）；
  registry `vk153/vk157/vk159/vk160`（lane `kexec-its`）
- ★SSOT 待并入：`TASKS/README.md` §4 第 10 条（已就地补）、§5 Q32 口径（已补）；`TASKS/README.md` §7 上游化（本条待立 M 项）

## 1. 取证链（每一步否决了什么）

| 步骤 | 手段 | 结果 | 否决的假设 |
|---|---|---|---|
| K1 | pstore（`console-ramoops-0`） | 目标独有串 `probe=K1` 出现在 `Run /init as init process` 的 `with environment:` 段 | 「目标没到 `/init`、静默挂死」——错，目标到过用户态 |
| K3 | 目标 userland 起 SSH | 目标**无网络**（`mask=1` 跳过 `device_shutdown` ⇒ dwc3 继承活态） | 「目标能靠 SSH/串口观测」——不能 |
| K5 | `initramfs/init` 在 `switch_root` 前把 dmesg 写盘 | 目标 0→126.58 s 逐字 dmesg（1402 行） | 「pstore 能重建时间线」——不能（按行覆盖、字节序≠时间序） |
| K5 | 目标 dmesg 计数 | `ITS queue timeout` 99 条，`CREADR` 冻结在 **1057 B**，每条 1.33 s | 「显示/DSI 是 kexec 第一受害者」——不是，MSI/ITS 先崩 |
| K8 | vk153：退出侧 `its_force_quiescent()` | 载具 `CREADR=CWRITER=13760 → ret=0 CTLR=80000000`；目标 99→**33**、`/init` 126→**43.4 s** | 「ITS 没被 quiesce 是唯一原因」——不是，只解释了一半 |
| K13 | 目标 dmesg 看 LPI 报错 | 8 个 CPU 全 `Booted with LPIs enabled` + **`Failed to disable LPIs`** | 「RD 可以清 LPI」——不行 |
| vk157 | 新增 `/sys/kernel/its_quiesce` 触发口 + **内核直接写盘**报告 | ITS quiesce `ret=0`；RD `GICR_CTLR 00000005 → 00000005`（8/8） | 「写 0 能清 EnableLPIs」——**RES1，写不进** |
| vk159 | 给 `gic_reserve_range()` 打点 | `ret=-3 = -FDT_ERR_NOSPACE`，live DTB `rsv 0→0` | 「在退出侧用 FDT memreserve 保留表」——DT 上不可行（且 kexec 在 `-l` 时就克隆完 FDT） |
| **K16 / vk160** | incoming 侧 `memblock_reserve()` 认领 | `ITS queue timeout` **0**、`Failed to disable LPIs` **0**、9 次 claim、`Using preallocated redistributor tables`、`/init` **1.31 s** | — |

## 2. 最终修法（2 处，`drivers/irqchip/irq-gic-v3-its.c`）

1. `enabled_lpis_allowed()`：属性表不在保留区时 `memblock_reserve(addr, LPI_PROPBASE_SZ)` 后复查。
   —— 此时还在 `memblock_free_all()` 之前，页未进入 buddy，认领有效。
2. `its_cpu_init_lpis()` 的 preallocated 分支：每个 CPU 的待发表同样 `memblock_reserve(paddr, LPI_PENDBASE_SZ)`，
   然后就地沿用（原来是 `WARN_ON` + 带着未保留内存继续用）。

效果：`RDIST_FLAGS_RD_TABLES_PREALLOCATED` 成立 ⇒ `redist_disable_lpis()` 提前返回
（不再需要清 RES1 的 `EnableLPIs`）⇒ ITS 命令立即完成。

**对普通 POR 惰性**：`enabled_lpis_allowed()` 只在「进来时 `EnableLPIs=1`」才调用，preallocated 分支只在
该 flag 存在时进入 ⇒ 正常启动零行为变化（这也是可上游化的前提：不改变既有启动语义）。

## 3. 载具可见性（工程经验，已进 `PITFALLS #378`）

- `cat /dev/kmsg` 每次重开都从缓冲区头重放；用 `>>` 循环会重复写，且用户态落盘进程在开机早期会被系统清掉。
- 可靠通道只有两条：**目标自己在 initramfs 里写盘**（`kexec_marker_dump()`，`switch_root` 之前），
  或**内核自己 `filp_open`+`kernel_write` 写盘**（`its_kexec_report()`，本轮新增，绕开一切用户态）。

## 4. 遗留

1. 目标 userland 起来后 **~155 s 复位回落**：高度怀疑是自家 Q28 看门狗（`local.d` 起 + `WAIT=75`，
   判据要求 `card0` 存在；kexec 目标若 `card0` 缺失即重启）。下一步：目标 cmdline 加 `elden_q28_nowd`，
   并在磁盘根放一个按 boot-id 落盘的 bootlog 钩子，取 switch_root 之后的现场。
2. 修法上游化：见 `TASKS/README.md` §7 与 `reports/kexec-its-lpi-upstream-20261024.md`。
