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
