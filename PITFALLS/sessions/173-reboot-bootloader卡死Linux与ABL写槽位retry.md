## #525 `eldroid-bootctl reboot bootloader` 可能卡死 Linux；UEFI 实验失败会让 **ABL 写槽位 retry**

**已被 #542 取代（同一故障；看门狗已落地）**；本条只保留第 2 段「ABL 会自己写槽位 retry（`boot_b` 7→6）」这一独立事实。

日期 2026-11-06 · pi 会话 id 见 `.pi/sessions/` · 主题 UEFI(G1-29) 实验的操作面副作用
结论 ① Linux→ABL 的 `eldroid-bootctl reboot bootloader` **偶发在关机路径卡死**（需物理重启）；
② UEFI 载荷崩掉后，**ABL 自己会写 GPT 槽位元数据**（实测 `boot_b` retry 7→6），"零写盘"只对 agent 动作成立。
证据指针 用户现场报告（2026-11-06 21:2x）；`eldroid-bootctl slot info` 在崩溃前后对比

## 1. `eldroid-bootctl reboot bootloader` 卡死

- 现象：命令发出后 Linux 侧无返回、SSH 断、设备停在关机途中；只能物理断电/长按。
- 影响面：所有"从 UEFI 侧回到 ABL 再打下一发"的流程都以它为枢纽 ⇒ 一次卡死 = 一次人工干预。
- 现状对策（未验证，待上机确认）：
  1. `sync` 之后调用，减少关机路径的写回等待；
  2. 备选：`eldroid-bootctl` 已把 reason 写进 PMIC SDAM，随后用 `echo b > /proc/sysrq-trigger`
     **跳过正常关机**直接复位（reason 已被 ABL 读到），避开卡死的关机阶段；
  3. 从 UEFI 侧 fastboot 发 `reboot bootloader` **不会**进 ABL（实测落到 Linux），别用它取 ABL。

## 2. ABL 会写槽位 retry（推翻"实验零写盘"的绝对口径）

- 实测：多轮 UEFI 载荷崩掉后 `boot_b` 由 `byte6=0x7f(retry=7)` 变 `0x77(retry=6)`；
  同时用户看到"熄屏→recovery 崩溃警告→回落 Linux"。
- 机制：`fastboot boot` 的载荷失败被 ABL 计为一次启动失败，`retry_count` 递减；吃到 0 就会把该槽标
  unbootable 并切槽（`PITFALLS #487` 同片区域）。
- 纪律：**每轮崩溃实验后核 `eldroid-bootctl slot info`，必要时 `slot set-retry 7 b` 补回余量**（写前自动备份 GPT）。
- agent 侧仍然零写盘（不 flash / 不改 GPT / 不动槽位）；**要区分"我没写"与"盘没被写"**。

## 3. 顺带记一条判据口径

`[L] found=1 / [L] LoadImage=Success` 是 **BdsDxe** 在 `gBS->StartImage(LinuxLoader)` **之前**打的
（`MU_BASECORE/MdeModulePkg/Universal/BdsDxe/BdsEntry.c:758`）⇒ 不能当作"已进入 fastboot 会话/已跑到
LinuxLoader"的证据。

---

## #542（2026-11-07 补）：卡死实锤 + 兜底看门狗落进 `eldroid-bootctl`

- **复现**：2026-11-07 两次 `eldroid-bootctl reboot bootloader`（都在设备跑 7.3.1 重基件时）第一次直接卡死：
  SSH 断、屏不动、只能物理断电。第二次正常 4 s 进 fastboot ⇒ **确为间歇性，不是配置问题**。
- **机制判读**：magic 由 `nvmem-reboot-mode` 的 *reboot-notifier* 在 `kernel_restart()` **早期**写进 PMIC SDAM；
  卡死点在**其后**的关机/复位阶段。因此「绕开正常关机路径」不会丢 reason —— emergency restart 虽然不跑 notifier，
  但 ABL 只读 SDAM magic，目标仍然正确。
- **落地方案（已进 `scripts/eldroid-bootctl`，设备侧 `/usr/local/bin/eldroid-bootctl` 同步）**：
  带 reason 的重启前**预挂**一个 detached 看门狗 —— `sleep 6; echo b > /proc/sysrq-trigger`。
  正常路径成功 ⇒ 进程随复位消失、看门狗无处落脚；卡死 ⇒ 6 s 后被 sysrq-b 强制复位，**落在同一个 ABL 目标**。
  `sysrq` 被关（`/proc/sys/kernel/sysrq=0`）时打印警告并放弃兜底；`--no-watchdog` 可关（调关机链本身时用）。
- **判据**：`eldroid-bootctl reboot bootloader` 后 **≤10 s** 应出现 `fastboot devices`；超时即被兜底复位（也仍是 fastboot）。
  2026-11-07 实测：正常路径 **4 s** 进 fastboot（未触发兜底）。
- **共用纪律（仍有效）**：每轮崩后核 `eldroid-bootctl slot info`，必要时 `slot set-retry 7 b` 补余量
  （本日 p37 一发确实把 `boot_b` 从 `retry=7` 扣到 `6`，已补回）。
