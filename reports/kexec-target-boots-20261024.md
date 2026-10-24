# kexec 目标其实**启动到了用户态**：冷/暖/kexec 这条轴的真正断点在 GIC ITS，不在显示 — 2026-10-24

> 触发：用户「考虑 kexec 和调查冷暖复位」。
> 在机：U2 `HA2EXB0E`，`boot_b` = vk152（`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`）。
> 前序：`reports/kexec-vk147-display-inherit-20261023.md`、`TASKS/sessions/2026-10-23-vk152日用载具与kexec复跑.md`、
> `reports/q32-matrix-20261024.md`、`reports/q28-workaround-closeout-20261024.md`。
> 产物：`reports/artifacts/kexec-pstore-probe-20261024/`（`pstore-pre-boot.txt` 346 196 B / `pstore-post-boot.txt` 122 891 B / `k1-run.log` / `k2-run.log`）。

## 0. 结论（先数字，含对既有口径的更正）

1. **更正「kexec 目标静默挂死、没到 initramfs `/init`」** —— 不成立。K1 发（同内核 Image + 同 DTB + 磁盘根 cmdline）
   的 pstore 里出现了**只有目标内核才会有的串**：`[init] ... with environment: elden_root=LABEL=linux17 /
   elden_kexec_target=1 / probe=K1`，紧跟 `[init] resolved LABEL=linux17 -> /dev/sda17`、`EXT4-fs (sda17): recovery complete`、
   `switching root to /dev/sda17`，随后是 `[camera] loaded …`、`udevd starting`。
   ⇒ **目标内核跑到了 initramfs `/init`、挂上磁盘根、switch_root 成功，用户态起来了**。
2. **目标不是「死得早」，是「慢」**：目标侧在 **t=2.53 s** 就出现第一条 `ITS queue timeout`，全程 **129 条**；
   `ath12k_wifi7_pci 0000:01:00.0: probe failed with error -110`。同一镜像的**当前回退启动 0 条 ITS 超时、ath12k 28 s 起来**。
   ⇒ 目标启动被 MSI 全灭拖到 **126.3 s 才到 `/init`**（对照：正常启动 ~9 s），并在 ~294 s 被复位回 `boot_b`。
3. **所以继承态的第一受害者是 MSI/ITS，不是 DSI**：`mask=1` 跳过 `device_shutdown()` ⇒ **GIC ITS 从未被 quiesce、dwc3 也未 deinit**；
   目标内核 `its_map_one()` 里虽有 `its_force_quiescent()`，实测仍拿不回命令队列（`ITS queue timeout (N 1057)` 持续）。
   本树上 ITS 的 quiesce 只挂在 **suspend 的 `its_save_disable`**（`syscore_ops`）与 probe 期，**kexec 路径没有任何 quiesce 调用点**
   （`build/vk151/drivers/irqchip/irq-gic-v3-its.c:5008/5044/5132`；`mask=1` 又跳过 `syscore_shutdown` ⇒ `mask=2` 也救不了这条）。
4. **对 Q32（暖/冷）的含义**：Q32 的 5 发全 GOOD 不是「复位深度无关」，而是**三个入口都没改到 ITS/MSI 的残留**；
   kexec 才是这条轴的**真正端点**（零复位、继承全部 live 状态），而它一上来就暴露了 MSI 断点。
   ⇒ 「冷暖复位调查」若还有区分力，必须先看 **复位深度 × ITS/MSI 残留**，显示只是下游；这与 Q28 收口口径不冲突
   （Q28 仍是时序竞态，不重开根因）。
5. **pstore 判读方法学更正**：`#377` 的「交错写坏」比记录里写的更严重 —— 同一 122 891 B 的 console record 里
   能同时看到**游标内核关机尾**（`[KD] stage=11a before device_shutdown … Restarting system`，294.66 s）与**目标内核的 /init**（126.3 s），
   字节顺序**不等于**时间顺序（新引导按行覆盖旧内容、行长差留残影）。**结论：pstore 只能做「存在性锚点」判读（有/无某串），
   不能用来重建时间线**；时间线必须走目标自己写到磁盘的 dmesg。

## 1. K1 发（磁盘根，零写盘）

| 项 | 值 |
|---|---|
| 载具 | vk152 运行中（uptime 972 s），`/sys/kernel/kexec_diag/kexec_diag` 写 1 并读回 `1` |
| 目标 | `build/vk151/arch/arm64/boot/Image` sha256 `c0b39ccb24b357f1…`（61 MiB）+ 同 DTB + `out/initramfs-slim.cpio.gz` |
| cmdline | `console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel panic=15 elden_root=LABEL=linux17 kexec_dbg=1 elden_kexec_target=1 probe=K1` |
| 跳转 | `LOAD OK`（`kexec_loaded=1`）→ `mask=1` → `kexec -e` |
| 结果 | 设备 +~300 s 回来，`boot_id` `b8ac16e2`、`/proc/cmdline` 是 **boot_b 长串**（= 回退，不是目标） |
| 目标侧证据 | pstore 命中 `probe=K1` 3 次，其中一次在 `Run /init as init process` 的 `with environment:` 段 ⇒ 目标到过 `/init` |

## 2. K2 发（RAM 根 + 目标 dmesg 落盘）— **设备未回来，需物理断电**

为绕开 pstore 交错，给 `initramfs/init` 的 marker 段加了**目标 dmesg 落盘**（`/var/tmp/kexec-target-dmesg.txt`
+ `kexec-target-irqs.txt`，见 `initramfs/init` 的 kexec_marker 段），重打 slim ramdisk（sha `55e2a0d2…`），
目标 cmdline 去掉 `elden_root`（RAM 根 ⇒ marker 段必走）并带 `kexec_marker=1`。

- 时间线：11:23:19 `kexec -e`；到 11:38 设备**未上网络**，宿主侧 NCM 接口 `enx021e5eede102` **carrier=0**，
  USB 只剩一个**僵死**的 `1d6b:0104 Multifunction Composite Gadget` 描述符（`mask=1` 跳过 dwc3 关机 ⇒ 宿主没看到 disconnect）。
- 判定：**卡在 RAM initramfs 或更早**（无 usb-gadget ⇒ 无网络、无可读控制台），与 `initramfs/init` 注释里
  2026-10-21 的同类事故一致。**恢复动作 = 长按电源 10 s 断电后短按开机**（不需要 fastboot/EDL）。
- **恢复后第一件事**（决定 K2 结论）：看 `/var/tmp/kexec-target-dmesg.txt` 是否存在
  - 存在 ⇒ marker 段跑通、`reboot -f` 没回来（initramfs 侧 bug），**目标 dmesg 已到手**（这正是我们要的仪器）；
  - 不存在 ⇒ 目标这次连 marker 段都没到（RAM 根路径与磁盘根不同），需换回磁盘根 + SSH 直取。

## 3. 下一步（按代价排序）

1. **K3（推荐，零写盘）**：磁盘根目标 + **从 +90 s 起每 3 s 轮询 SSH**，判据用 `/proc/cmdline` 是否含 `elden_kexec_target=1`
   （现有 `kexec-boot.sh` 只等 180 s 且不判目标身份）。目标用户态一起来就 `dmesg > /var/tmp/…` 直取 ——
   比 pstore（交错）和 marker（要重启）都干净。**已知窗口 ≈ 130–290 s**。
2. **ITS quiesce 补丁（~20 行，治根候选）**：在 `mask=1` 的跳转路径上，对每个 `its_node` 显式
   `its_force_quiescent(base)`（复用现成静态函数，或把它提到 `kernel_kexec()` 前调用），再跳。
   预期判据：目标 `ITS queue timeout` 计数 **0**、到 `/init` 的时间从 126 s 回到 ~10 s。
3. **冷暖复位的剩余区分力**：等 ①② 把 ITS 这条变量拿掉后，再把 W1/W2/C1/POR 与 kexec 放同一张表；
   只有当「同一深度内不一致」时才是 Q28 时序竞态，否则先按 ITS 残留解释。

## 4. 过程小账

- `kexec -e` 后宿主侧 `ssh` 会挂到 TCP 超时才返回（本轮 ~350 s），**不能用它的返回时间当设备复位时间**（K1 已踩）。
- 串口 `/dev/ttyACM0` 属 `root:dialout`，本机账号不在 `dialout`、无免密 sudo ⇒ **agent 读不到串口**；
  这轮再次证明「判据不能靠串口」。
- pstore 读后即删：本轮两次都在读前先 `cp` 到 `/var/tmp` 再取回，归档在 §0 的产物目录。

---

## 5. K4/K5：目标逐字 dmesg 到手（仪器落地）

K2/K4 两发「什么都没写 + 设备卡死」的真因 = `PITFALLS #378a`：`/init` 的 cmdline 解析是**白名单**，
`kexec_marker=1` 被静默丢弃。修法 = 把 `kexec_marker`/`kexec_marker_dev` 加进白名单，
并把 dump 从「RAM 根分支」搬到 **`switch_root` 之前**（磁盘根目标也必走）→ `initramfs/init` 的 `kexec_marker_dump()`：
写 `kexec-marker.txt` / `kexec-target-dmesg.txt` / `kexec-target-irqs.txt` 到 `var/tmp/`。

**K5（成功，零写盘）**：目标 = 同 Image（sha `c0b39ccb24b357f1`）+ 同 DTB + slim initrd `2e9c9e1f30e49ca5`，
cmdline 含 `probe=K5 kexec_marker=1`，`mask=1`。产物 `reports/artifacts/kexec-pstore-probe-20261024/k5-*`。

```
kexec-marker.txt: alive uptime=126.57 kernel=7.3.0-rc7-… probe=K5
kexec-target-dmesg.txt: 1402 行，覆盖目标 0 → 126.58 s
复位回退：+323 s（3 次一致 +310~330 s）
```

### 5.1 目标 dmesg 的硬数字（这就是「kexec 到底坏在哪」的答案）

| 项 | 目标（kexec，零复位） | 对照：正常 boot_b 启动 |
|---|---|---|
| `ITS queue timeout` | **99 条**，首条 `t=2.549 s`，末条 `t=126.345 s` | **0 条** |
| ITS 命令队列进度 | `linear_idx` **冻结在 1057 字节**（33 条命令）贯穿全程，`to_idx` 从 1088 涨到 4224 ⇒ **ITS 在第 33 条命令后彻底停摆** | — |
| 每条超时代价 | **1.33 s**（`its_wait_for_range_completion` 的 `count=1000000` ≈ 1 s + 开销） | — |
| 到 `/init` | **126.35 s** | ~8.9 s |
| `ath12k` | `failed to init core: -110`（MSI 拉不起来） | 28 s 正常 up |
| display | 0.263 s 有 `boot framebuffer mapped before SID switch`（与正常一致）**但 126 s 内 `msm_dpu` 从未 bind**；`af54000.displayport-controller` 一直 `deferred probe pending`，`geni_i2c a94000.i2c: Failed to get tx DMA ch` / `geni_spi a90000.spi: Failed to get rx DMA ch` | 8.804 s `msm_dpu bound ae94000.dsi/ae96000.dsi`，9.1 s `fb0` |
| 固件 | `adsp.mdt` / `awinic/*.bin` / `ath12k/…/amss.bin` 全部 `-2`（slim initrd 无 `/lib/firmware`，磁盘根要 switch_root 后才有） | 同 —（不是差异项） |

**所以「kexec 目标静默挂死」的完整解释是**：它的 ITS 命令队列在启动早期就停摆，每条 MSI 命令付 1.33 s 超时，
99 条 ⇒ 启动被拖到 126 s；显示侧则是 **DPU 组件链没凑齐**（DP/`88e3000.phy`/i2c DMA 一路 deferred），
与 DSI 自锁无关。两条都不是「内核挂死」。

### 5.2 对下一步的含义（按代价）

1. **ITS 停摆是本轮唯一「便宜可攻」的点**：本树 ITS 的 quiesce 只挂 `suspend` 的 `its_save_disable`
   （`irq-gic-v3-its.c:5008/5044`），**kexec 路径没有调用点**；`mask=1` 连 `syscore_shutdown` 都跳。
   候选修法 ①「跳转前对每个 `its_node` 调 `its_force_quiescent()`」②「incoming 侧在写 CBASER 前补一次
   `GITS_CREADR`/`CWRITER` 同步」。**判据极硬**：目标 `ITS queue timeout` 应从 99 → **0**、到 `/init` 从 126 s → ~10 s。
2. **显示侧不要在 kexec 臂上追**：DPU 组件链问题在正常启动里由「8.8 s 时依赖已就绪」自然解决，
   kexec 臂上它被 ITS/固件/DMA 的延迟连锁拖住 —— 这解释了为什么 0154/0155 对 kexec「机制性无效」，
   **但原因和 10-23 记的「DSI 自锁」不同**，应以本轮为准。
3. **冷暖复位**：本轮数据没有给 W1/W2/C1/POR 增加区分力（三者都不碰 ITS/MSI 残留）。
   若还要做，必须先有「复位深度 × ITS 残留」的判据（目标侧 `ITS queue timeout` 计数就是现成的一条）。

---

## 6. vk153：ITS quiesce 钩子（退出侧）——**部分有效，33 次残留**

### 6.1 补丁（`build/vk151`，3 文件）

| 文件 | 改动 |
|---|---|
| `drivers/irqchip/irq-gic-v3-its.c` | 新增并导出 `gic_its_quiesce_for_kexec()`：逐 `its_node` 打印 `CTLR/CREADR/CWRITER` → `its_force_quiescent()` → 再打印结果；另加 `[KD] its-probe:`（probe 后 `CTLR/CREADR/CWRITER/cbaser`）与超时行补打 `CREADR/CTLR/CWRITER` |
| `kernel/kexec_core.c` | `mask=1` 路径在 `syscore_shutdown()` 之后调用上述钩子，打 `[KD] stage=14b after its-quiesce`；同文件提供 `__weak` 空实现 |
| `include/linux/kexec.h` | 钩子原型（顺手消掉 2 个 `-Wmissing-prototypes`） |

镜像 `out/boot-elden-vk153.img` sha `5efca31f…`（22 032 384 B），registry 已登记（lane `kexec-its`）。
**编译按用户要求留 2 个 P 核**：`taskset -c 0-11 make -j12`（i7-14700KF：CPU0–15 = 8 个 P 核 ×2 HT，CPU12–15 空出）。

### 6.2 上机（全程零写盘）

载具 = `reboot2 bootloader` → `fastboot boot out/boot-elden-vk153.img`（RAM 运行，UTS `…-dirty+`），
再 `mask=1` kexec 到同 Image（`probe=K8 kexec_marker=1`）。载具侧用 `cat /dev/kmsg > /var/tmp/k8-carrier-kmsg.log` 落盘（跳转即断，正好留下关机段）。

**载具侧（关键，第一次看到这条路径）**：

```
[KD] stage=10 enter kernel_kexec (skip_mask=1)
[KD] stage=11a SKIP device_shutdown
[KD] stage=13 before syscore_shutdown → stage=14 after syscore_shutdown
[KD] its-quiesce: @0x16040000 CTLR=00000001 CREADR=13760 CWRITER=13760   ← 队列已排空（两者相等）
[KD] its-quiesce: @0x16040000 ret=0        CTLR=80000000 CREADR=13760   ← QUIESCENT=1、ENABLE=0
[KD] stage=14b after its-quiesce
kexec_core: Starting new kernel
```

**目标侧（`reports/artifacts/kexec-pstore-probe-20261024/k8-*`）**：

| 判据 | vk152 载具（无钩子） | vk153 载具（有钩子） |
|---|---|---|
| `ITS queue timeout` | **99** 条 | **33** 条 |
| 首条 / 末条 | t=2.55 s / 126.35 s | t=3.39 s / **43.42 s** |
| 到 `/init` | 126.35 s | **43.42 s** |
| `CREADR` 行为 | 冻结在 1057 B，**永不恢复** | 冻结在 1057 B 约 41 s 后**恢复** |
| `its-probe` | `CTLR=00000001 CREADR=0 CWRITER=0` | 同（ENABLE 生效、队列重编程正常） |

⇒ **退出侧 drain+quiesce 确实把「ITS 永久停摆」变成了「有界停顿」**（1.25 s × 33 ≈ 41 s），但没有归零。

### 6.3 残留 33 次的原因（下一步唯一变量）

目标 dmesg 里仍然有 **8 个 CPU 各一条** `GICv3: CPU<n>: Booted with LPIs enabled, memory probably corrupted`，
且 `Expected reserved range [0x880310000:0x880310ffff], not found`：

- `gic_reserve_range()` 在本树**只在 EFI 下生效**（`efi_mem_reserve_persistent`），**DT 启动恒返回 0** ⇒
  LPI 属性表/待发表跨 kexec **没有任何保留**；`enabled_lpis_allowed()`（= 属性表是否在保留区内）因此为假。
- 目标内核于是走「重新分配自己的表」的干净路径，但 **RD 侧 `GICR_CTLR.EnableLPI` 仍是载具留下的 1**，
  `redist_disable_lpis()` 要等到 `its_cpu_init()` 逐 CPU 才清，而 `its_init()` 的 MAPC/MAPD 先发出去了 ⇒ 前 33 条命令卡在那里，
  等 8 个 CPU 陆续把 RD 的 LPI 清掉后才继续。

**下一增量（未做，~15 min，仍零写盘）**：在退出侧钩子里**一并把每个 redistributor 的 `GICR_CTLR.EnableLPI` 清零**
（`redist_disable_lpis()` 的 all-CPU 版本），使目标内核从一开始就看不到「LPIs enabled」。
预期判据：`Booted with LPIs enabled` 0 条、`ITS queue timeout` **33 → 0**、到 `/init` **43 s → ~10 s**。

---

## 7. 定案：不是「ITS 没 quiesce」，是 **`GICR_CTLR.EnableLPIs` 在这颗 SoC 上是 RES1**

### 7.1 决定性证据：内核自己写盘（`/sys/kernel/its_quiesce/its_quiesce` 触发口，vk157）

用户态一行触发即可跑同一钩子，绕开「载具日志抓不到」的死结（`its_kexec_report()` 由**内核**直接
`filp_open`+`kernel_write` 写 `/var/tmp/its-kexec-report.txt`，不依赖任何用户态进程）：

```
its-quiesce report (kernel-side, kexec)
ITS @0x16040000 CTLR=00000001 CREADR=9376 CWRITER=9376
ITS @0x16040000 quiesce ret=0 CTLR=80000000          ← ITS 侧 quiesce 完全有效
RD cpu0 CTLR 00000005 -> 00000005
RD cpu1 CTLR 00000005 -> 00000005
…  cpu7 同上                                          ← EnableLPIs 写不进去
```

目标侧同一条因果链（`k13/k15` 目标 dmesg）：

```
GICv3: CPU0: Booted with LPIs enabled, memory probably corrupted
CPU0: Failed to disable LPIs          ← redist_disable_lpis() = -EBUSY
… 8 个 CPU 全一样
```
⇒ `its_cpu_init()` 在 `redist_disable_lpis()` 失败处直接返回 ⇒ **LPI 从未重新配置** ⇒ 依赖 LPI 的
ITS 命令永远等不到完成 ⇒ 命令队列排队到 33/99 条、每条付 1.25 s 超时。
这解释了 `CREADR` 冻结在 1057 B、以及 vk153 之后从「永久停摆」变成「有界停顿」。

### 7.2 各版实测汇总（全部零写盘；载具 = `reboot2 bootloader` + `fastboot boot`）

| 版本 | 改动 | 目标 `ITS queue timeout` | 到 `/init` | 目标 `Failed to disable LPIs` |
|---|---|---|---|---|
| vk152（载具） | 无钩子 | **99** | 126.35 s | 8 |
| **vk153** | ITS quiesce（stage 14b） | **33** | **43.42 s** | 8 |
| vk154/155/156 | 加 RD 清理 + 内核写盘报告 | 99（载具侧证据缺失，结论作废） | 126 s | 8 |
| vk157 | 同上 + `/sys/kernel/its_quiesce` 触发口 | **99**（钩子在 stage 11b 已实测执行：report 文件在） | 126 s | 8 |
| vk158 | `gic_reserve_range()` 加 DT `fdt_add_mem_rsv` 分支（让表跨 kexec 保留、走 preallocated） | **99（未生效）** | 128.7 s | 8（且无 `Using preallocated redistributor tables`） |

### 7.3 结论与下一步（写死，避免下次重推）

1. **「继续清 EnableLPIs」这条路已证伪**：SM8750 上该位是 RES1，`writel` 无效（vk157 实测 8/8 `00000005->00000005`）。
2. **唯一正确方向 = 让 incoming 内核走 preallocated 路径**（它不需要清 EnableLPIs）：要求 prop/pending 表在
   incoming 的 memblock 里**是 reserved**。上游 EFI 路径用 `efi_mem_reserve_persistent()`；本机是 DT，本站补的
   `fdt_add_mem_rsv()` 分支**没有生效**（vk158：目标仍报 `Expected reserved range […] not found` 1 次）。
3. **下一轮只做一件事**：给 `gic_reserve_range()` 打点（`addr/size/返回值`）+ 打印 FDT 里 memreserve 条数，
   判断是 `fdt_add_mem_rsv` 返回 `-FDT_ERR_NOSPACE`（ABL 给的 DTB 没余量）还是 kexec 侧没沿用。
   若是没余量，正解 = 在 DT 里预留 `memreserve` 或改用 `/proc/device-tree` 侧的固定 carveout。
4. 载具可见性经验（已进 `PITFALLS #378`）：`cat /dev/kmsg` 每开一次都从缓冲区头重放，用 `>>` 循环会重复写；
   用户态落盘进程在开机早期会被系统清掉 ⇒ **用内核写盘**（本轮的 `its_kexec_report()`）或目标侧 dump 才是可靠通道。

---

## 8. ★ 修好了：incoming 侧「claim 继承的 LPI 表」⇒ ITS 超时 99 → **0**，到 `/init` 126.35 s → **1.31 s**

### 8.1 为什么不是补 FDT（vk159 实测否决）

给 `gic_reserve_range()` 打点后（vk159，载具上直接读 dmesg）：

```
[KD] gic-reserve: addr=0x880310000 size=65536 ret=-3 rsv 0->0 totalsize=154698
```

`ret=-3 = -FDT_ERR_NOSPACE`：ABL 给的 live DTB **一个 memreserve 都没有、也没有余量**，
而 `fdt_add_mem_rsv()` 是就地改活 FDT（kexec 只在 `kexec -l` 时克隆它，**跳转时再改已经太晚**）。
⇒ 「靠 FDT 保留」这条路在 DT 上要额外搬 FDT，代价大且与 `of_kexec` 的克隆时机耦合，放弃。

### 8.2 落地的修法（只改 **incoming** 侧，2 处，`build/vk151/drivers/irqchip/irq-gic-v3-its.c`）

SM8750 上 `GICR_CTLR.EnableLPIs` 是 **RES1**（vk157 实测 8/8 `00000005 -> 00000005`），
所以 incoming 内核**既不能清 LPI 也不能重编程 BASER**；唯一可行解 = **继承的表现在就认领**：

| 位置 | 改动 |
|---|---|
| `enabled_lpis_allowed()` | 属性表不在保留区时：`pr_info` + `memblock_reserve(addr, LPI_PROPBASE_SZ)`，再复查（在 `memblock_free_all()` 之前，页还没进入 buddy） |
| `its_cpu_init_lpis()` preallocated 分支 | 每个 CPU 的待发表同理：`memblock_reserve(paddr, LPI_PENDBASE_SZ)` 后就地沿用（原来是 `WARN_ON` + 带着未保留内存继续用） |

效果：`RDIST_FLAGS_RD_TABLES_PREALLOCATED` 成立 ⇒ `redist_disable_lpis()` 提前返回（不再 -EBUSY）
⇒ `its_cpu_init()` 不再短路 ⇒ LPI 表沿用载具的原表（内容本来就在）⇒ ITS 命令立即完成。

**对日常启动是惰性的**：`enabled_lpis_allowed()` 只在「进来时 `EnableLPIs=1`」才被调用（POR 时为 0），
`preallocated` 分支只在有该 flag 时进入 ⇒ 普通 POR 路径零行为变化。

### 8.3 上机判据（K16：载具 = vk152 日常线，零写盘 kexec 到 vk160）

| 判据 | vk152 基线 | vk153 半程 | **vk160（本轮）** |
|---|---|---|---|
| `ITS queue timeout` | 99 | 33 | **0** |
| `Failed to disable LPIs` | 8 | 8 | **0** |
| `Using preallocated redistributor tables` | 无 | 无 | **有（1 次）** |
| `claiming inherited LPI …table` | — | — | **9 次**（属性表 1 + 待发表 8） |
| 到 `/init` | 126.35 s | 43.42 s | **1.31 s** |
| initramfs marker uptime | 126.5 s | 43.5 s | **1.51 s** |

产物：`reports/artifacts/kexec-pstore-probe-20261024/k16-*`。

### 8.4 剩余未解（下一步）

1. 目标 userland 起来后（switch_root 之后）**约 155 s 会复位回落**——本轮 dump 在 `switch_root` 之前（1.5 s），
   看不到那段的死因。下一步：把 `kexec_marker_dump()` 之外再加一个**磁盘根 userland 的 boot-id 落盘**
   （或直接趁窗口 SSH 进去，ITS 修好后 USB 是否恢复也值得复测）。
2. 修法值得**上游化**（比现状「taint 后带着未保留内存继续用」更正确），先内部稳定几轮再发。
3. 若要把 kexec 快环变成日常能力，需要把这 2 处改动并入日常线（当前 `boot_b` 仍是 vk152）。

---

## 9. 上游投递 + 目标 userland 现场（2026-10-24 收尾）

### 9.1 上游化

补丁 `patches/upstream/m-gic-its-claim-20261024/0001-*` **已投递**（用户批准解除投递冻结）：

- Message-ID **`<20261024075856.835932-1-xiaqinghuan@mail.ustc.edu.cn>`**（USTC 通道，SMTP `Result: 250`）
- To Thomas Gleixner；Cc Marc Zyngier / linux-arm-kernel / linux-kernel
- **归档复核**：`/lkml/` 与 `/linux-arm-kernel/` 两个 inbox 按 Message-ID 取 raw **均命中全文**，正文与本地补丁逐 hunk 一致
- 投递前用**最终补丁文本**重跑上机（vk161，不是 vk160）：`ITS queue timeout` **0**、`Failed to disable LPIs` **0**、
  claim 属性表 1 次 + 待发表 1 次（`pr_info_once`）、`Using preallocated redistributor tables` 有、`/init` **1.275 s**

### 9.2 kexec 目标「userland 之后」的现场（第一次拿到）

设备端新增 `/etc/local.d/elden-bootlog.start`：每次启动把 `cmdline/boot_id/uptime/drm 列表/dmesg` 写到
`/var/log/dmesg-<boot_id>.txt`（带 boot_id 后缀 ⇒ kexec 目标的快照不会被回落启动覆盖）。
vk161 目标那次（`probe=K18`，uptime 65.6 s 时落盘，产物 `reports/artifacts/kexec-pstore-probe-20261024/k18-target-userland.log`）：

| 观测 | 值 | 含义 |
|---|---|---|
| `/sys/class/drm` | 只有 `version` | **目标里没有 card0**：`msm_dpu` 没 bind |
| `[usb-gadget] no UDC after 20s` | 22.1 s | **dwc3 没回来**（`mask=1` 跳过 `device_shutdown` ⇒ 继承活态） |
| 之后的复位 | ~157 s（回落 uptime 14.5 s） | 高度吻合自家 **Q28 看门狗**（`local.d` 起 + `WAIT=75`；`card=no` ⇒ 重启一次） |

⇒ **kexec 修好的是「内核与 MSI」，不是「显示与 USB」**：`mask=1` 的代价就是把 dwc3/显示留在 live 态，
目标侧 `no UDC` + `无 card0` 是同一根因的两面。这与 Q11 的 K3 裁决一致（kexec 用于**不需显示/USB 的调试**），
但把「为什么」从「静默挂死」改写成了「内核 1.3 s 到 /init，但显示与 USB 继承态未复位」。

### 9.3 下一步（写给下一轮）

1. 若要 kexec 臂也能连网/出图：需要**有选择地**在跳转前把 dwc3 与 DSI/dispcc 关到「可重新 probe」的程度
   （`mask=1` 跳过了 `device_shutdown`，可考虑只对这两个 device 调 `.shutdown()` 或 `unbind`——
   但 `msm-mdss/unbind` 已实测会整机重启，见 `reports/kexec-vk147-display-inherit-20261023.md` §3）。
2. 上游侧等 review；若要求更严格，v2 = 在 `its_init()` 遍历 redistributor 帧一次性认领待发表（消除「认领太晚」的局限）。
3. 顺手修的文档坑：`lore-query.py` 过不去当前 Anubis（`pass-challenge` 404）⇒ 用 `web_fetch(provider=firecrawl)` 取 raw。
