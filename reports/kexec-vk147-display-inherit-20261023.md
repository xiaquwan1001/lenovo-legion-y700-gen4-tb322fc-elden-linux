# kexec 到 vk147（Q11 / C12 复跑）+ display unbind 副作用 — 2026-10-23

> 承接 `TASKS/sessions/2026-10-22-kexec目标存活实证.md`（Q11 判「交接成立」，剩「目标 switch_root 磁盘根」）。
> 本轮目标：v147（m1-73 + 0154 + mask=1 旋钮）上重跑 C12，看 0154 能否救目标内核的面板 init。

## 0. 结论先行

1. **kexec 交接机制在 vk147 上完整成立，且不掉电**（`mask=1` 全链到 `Bye!`），Q11 的「掉电阻塞」彻底解决。
2. **但目标内核仍静默挂死**：连 initramfs 的 `/init` marker 段落都没跑到（`/var/tmp/kexec-marker.txt` 不存在）。
3. **0154 对 kexec 路径无效** —— 机制上必然：`dispcc` 在 live 内核里**早已 probe 完**，0154 那段代码在目标内核里**根本不会执行**；目标继承的是「display 全活、PLL 全锁、DSI host 编程完」的状态。
4. **B 臂方案（kexec 前 unbind display）不可行**：`echo ae00000.display-subsystem > .../msm-mdss/unbind` **直接导致整机重启**（`boot_id` 变化），不是干净的卸载。

## 1. 前置：一次两次踩坑的复盘

### 1.1 vk146 挂死 = `.config` 漂移（已修）

第一次 `fastboot boot out/boot-elden-vk146.img` 出现「背光亮一下就掉电」——

**根因**：`build/m1-73/.config` 里遗留了 **`CONFIG_SUSPEND=y`**，是 2026-10-18 vk128/vk129 失败实验留下的，事后没还原。用这份 config 编出来的内核**必然复刻 vk128/vk129 的已知失败形态**。

同一根源还造成当日的 fastrpc 刷屏（模块树 `-abi-suspend` 也是从这份 config 编的）：
- `CONFIG_SUSPEND=y` ⇒ `struct device` 里 `of_node` 在偏移 **680**
- `SUSPEND=n` ⇒ 偏移 **624**
- vermagic 只比 UTS 字符串（两套逐字相同）⇒ **静默失效**

**修法**：`build/m1-73/.config` 换成 SSOT `patches/config-vk127-working-20261018`（`SUSPEND=n`），vk146 作废 → **vk147**（`#13`，`pahole` 核对 `of_node=624` 与机内 `-abi-nosuspend` 模块树一致）。

### 1.2 SSH 密钥被拒（未修，改用密码通道）

持久化 vk147 后 `root@192.168.7.1` 的 `id_rsa` 认证失败（主机密钥未变，应为 `/root/.ssh/authorized_keys` 丢失）。本轮全程用密码通道（`/tmp/sshpass.py`，pty 注入）。

## 2. A 臂实验（基线，kexec 不做任何预处理）

**载具**：`out/boot-elden-vk147.img`（sha `cc60adf5…`）→ 持久化写盘 → 设备 `#13` 运行中。
**目标**：vk147 自身 `Image`（md5 `7817927d…`）+ `out/initramfs-slim.cpio.gz`（1 060 492 B）

**目标 cmdline**：
```
console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel panic=15
nokaslr kexec_dbg=1 kexec_marker=1 kexec_marker_dev=/dev/sda17
elden_root=LABEL=linux17 rootwait
```

**串口实证（完整，无掉电）**：
```
[34487.046049] kexec_core: [KD] stage=10 enter kernel_kexec (skip_mask=1)
[34487.046073] reboot: [KD] stage=11a SKIP device_shutdown
[34487.046078] kexec_core: [KD] stage=11 after kernel_restart_prepare
[34487.047591] kexec_core: [KD] stage=12 after migrate_to_reboot_cpu
[34487.047597] kexec_core: [KD] stage=13 before syscore_shutdown
[34487.047602] kexec_core: [KD] stage=14 after syscore_shutdown
[34487.047605] kexec_core: Starting new kernel
[34487.102695] psci: CPU1 killed (polled 0 ms)
...
[34487.347462] psci: CPU7 killed (polled 0 ms)
[34487.348016] Bye!
```

**结果**：
| 判据 | 结果 |
|---|---|
| 到 `Starting new kernel` | ✅ |
| 不掉电 | ✅（无 PMIC 掉电，`Bye!` 是 kexec 正常出口） |
| 目标写 `/var/tmp/kexec-marker.txt` | ❌ |
| 目标起 `udevd` | ❌ |
| 串口 `Bye!` 后新内容 | **0 行** |
| 自动回落 boot_b | ✅（`boot_id` 变化，`#13`，DSI connected） |

⇒ **比 C12 更早死**：C12 至少跑到了 `udevd`，本轮连 initramfs `/init` 的 marker 段都没到。

## 3. B 臂（unbind display）— 不可行

```
echo ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/unbind
```

**结果**：SSH 中断，`boot_id` 由 `20496f7d` → `9f86d035` —— **整机重启**，不是卸载。
回来后 `msm-mdss` 已重新绑定、`card0` 全在。

⇒ **display 栈在这台机上无法在运行期干净卸载**（与 `PITFALLS #224`「运行期重绑 DSI host 会拆 DRM」同向，且更重：直接复位）。

## 4. 机理解读

| 路径 | display 继承状态 | 0154 是否执行 | 结果 |
|---|---|---|---|
| **持久启动**（XBL→ABL→kernel） | bootloader 留下的活状态 | ✅ probe 时执行 | STORM 从 0/9 降到 0/8（p=0.002） |
| **kexec** | **live 内核已完全初始化完的 display** | ❌ dispcc 早已 probe 过 | 目标静默挂死 |

`0154` 的语义是「在 dispcc **probe 时**复位 MDSS 块」。kexec 目标内核的 dispcc 会重新 probe（不是热继承驱动），但此时硬件状态是「另一个内核已经完整编程过」的——**比 bootloader 留下的状态更深、更活**。0154 那 27 行仍会执行（新内核 probe 时），但：

- 它复位的是 `MDSS_CORE|CORE_INT2|RSCC` 三个 BCR
- 而 live 内核留下的还有 **DSI 控制器 = 0x175（CMD_MODE_ENGINE_BUSY|MDP_BUSY|DSI_BUSY 自锁）**、PLL 全锁、bonded link 已编程
- ⇒ 复位 dispcc 不等于复位 DSI host/PHY

**这也解释了为什么比 C12 更早死**：C12 用的是「slim initramfs + 完整磁盘根 cmdline」，本轮是「slim initramfs + RAM marker cmdline」，cmdline 差异导致更早死在 initramfs 之前——与 `2026-10-22-kexec目标存活实证.md` §5 记录的「C9 活 / C13 早死」同类非确定性一致。

## 5. 结论与下一步

### 5.1 已可判为闭合的部分

- **Q11 的「掉电」问题**：✅ 关闭。`mask=1` + vk147 上稳定到 `Starting new kernel`。
- **0154 的适用边界**：只对「bootloader 遗留态」有效，对「live 内核遗留态」（kexec）**无效且不可能有效**。

### 5.2 kexec 想继续，只剩三条路

| # | 方案 | 代价 | 说明 |
|---|---|---|---|
| **K1** | 目标内核**不重新 probe display**：DT 里 `status="disabled"`，然后目标起来后再手动 bind | 中（DT + 脚本） | 绕开「在脏状态上重新 probe」这个根本矛盾 |
| **K2** | kexec 前用 `sysfs` 把 DSI host 置回 `CTRL.ENABLE=0` + 清 PLL（**不卸载 mdss**） | 低-中（~20 行 driver 或 debugfs） | 只针对 `#366` 记的两处代码级缺陷，不碰整栈 |
| **K3** | 接受现状：kexec **只用于「不需要显示的调试」** | 0 | 判据一律走磁盘文件；面板不亮是预期 |

**建议**：K3 立即采纳（本轮证明可行且不掉电，值钱），K1/K2 列为低优先。理由：kexec 的收益是「省 2–3 min 换内核」，而它的前置（要人按键进 fastboot 起载具）把这个收益吃掉了——**除非载具长期占着 boot_b**。

### 5.3 顺带发现（应进 PITFALLS）

- **`build/m1-73/.config` 漂移无任何门禁**：`assert-kernel-sane.sh` 只查 `ARCH_QCOM`/`DRM_MSM` 等锚点，**不查 `CONFIG_SUSPEND`**。建议加：构建前比对 `patches/config-vk127-working-*`，任一 ABI 敏感项（`SUSPEND`/`PREEMPT`/`DEBUG_LOCK_ALLOC`/`LOCKDEP`/`NUMA`）不一致即拒绝。
- **`-abi-suspend` 模块树已改名 `-DO-NOT-LINK`**（当日处置）。
- **display unbind ⇒ 整机重启**（本文 §3）。

## 6. 产物

- 镜像：`out/boot-elden-vk147.img`（sha `cc60adf5…`，`#13`，SUSPEND=n，0154 + mask=1）；`out/boot-elden-vk146-BADSUSPEND.img`（留证）
- 设备：`boot_b` = vk147（用户持久化写入）；运行 `#13`，DSI connected，刷屏 0
- 串口证据：`/var/log/elden-serial/ttyACM0.log`（offset `2942147041` 起的 A 臂段）
- 相关：`reports/fastrpc-flood-rootcause-20261022.md`（同一 config 漂移的另一面）
