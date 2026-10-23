# Q32 预研（静态）：暖起 vs 冷起差异的可查线索（2026-10-23）

> **状态：静态预研，未上机验证。** 三发实验设计见文末 §5。
> 本文只为 Q32 建立「可二分的问题清单」，不宣布任何结论。
> 相关：Q28（显示间歇失败）、`PITFALLS #166`（暖复位粘 NOCARD）、§4 第 10 条 kexec（同为「继承态」问题）。

---

## 0. 一句话

现有证据里「暖复位必坏 / POR 必好」**不成立**（两个方向都有反例），
所以暖/冷不是一个二元开关，而是**「这一层复位清掉了什么」的连续谱**。本文列出可在代码/DT/寄存器层直接查的 4 条差异面。

---

## 1. 现有证据的两处互相矛盾（必须先承认）

| 来源 | 观察 | 与另一条的关系 |
|---|---|---|
| `PITFALLS #166`（2026-10-10） | `reboot2 bootloader`（PSCI `SYSTEM_RESET2`，**不经完全断电**）= 暖复位，**不清 DSI PHY/PLL 态**；连续暖复位把 Q28 粘死 **NOCARD**（vk86-round 连 4/4） | 与下行「POR → STORM」同向：都说明「清得干净」不一定好 |
| `PITFALLS` §复位深度阶（同文） | 物理 POR（最深）→ **STORM**（复现坏发）；`fastboot reboot`（从 fastboot 起 boot_b）→ STORM；`busybox poweroff -f`（浅，PMIC 断电但**疑似不清 DSI PHY/PLL**）→ **GOOD** | ⇒ 「POR 必好」被否；但这一条只有 run1 单样本 |
| **反例（2026-10-23）** | `vk150-q28v2` 的 **2 发 `reboot2 bootloader` 暖复位 = 2/2 GOOD**，紧接的 5 发真 POR 也是 5/5 GOOD | ⇒ 「暖复位必坏」被否 |

**⇒ 结论只到这一层：「同一深度内结果是否一致」才是判据**；若同一深度内仍随机，暖/冷就不是主变量（Q28 的本体 = 命令引擎时序竞态）。

---

## 2. 静态线索 A：`psci` 的复位类型分派（代码已读，可直接查）

`drivers/firmware/psci/psci.c:311` `psci_sys_reset()`：

```c
if ((reboot_mode == REBOOT_WARM || reboot_mode == REBOOT_SOFT) && psci_system_reset2_supported)
        invoke_psci_fn(PSCI_FN_NATIVE(1_1, SYSTEM_RESET2), 0, 0, 0);   /* reset_type = 0 = WARM */
else
        invoke_psci_fn(PSCI_0_2_FN_SYSTEM_RESET, 0, 0, 0);             /* 架构级 SYSTEM_RESET */
```

我们自己的最小钩子（`patches/kernel-history/elden_vk53-hw/0003-*`）在**前面**插了 vendor 分支：

```c
#define PSCI_ELDEN_RESET_TYPE_EDL          0x80000000
#define PSCI_ELDEN_RESET_TYPE_BOOTLOADER   0x80010001
if (psci_system_reset2_supported) psci_elden_try_vendor_reset(data);   /* data = "bootloader"/"edl" */
```

⇒ **可查的三件事**：
1. `reboot bootloader` 走的是 **vendor reset_type = 0x80010001**，而普通 `reboot` 走 `SYSTEM_RESET`(0x2)、
   `reboot -f`/warm 走 `SYSTEM_RESET2`(type 0)。**三者是不同的固件入口**，ABL/XBL 的初始化深度必然不同 —
   这是「暖/冷差异」在软件侧的第一层可观测面。
2. `psci_elden_try_vendor_reset()` 之后**有 fallthrough**（firmware 拒绝则继续走普通 reboot）⇒
   若某次 `reboot bootloader` 实际没进 bootloader，会静默降级成普通重启 ⇒ **复位深度可能与脚本以为的不同**。
   **判据**：dmesg 里必须有 `psci: SYSTEM_RESET2 vendor reset_type=0x80010001 cookie=0x2 (cmd=bootloader)`。
   （2026-10-23 就出现过「`slot-switch a --reboot` 没进 fastboot」的不明情形，正是该打印是否出现没查 →
   已列为 Q32 的第一个现场检查项。）
3. `PITFALLS #166` 说的「暖复位不清 DSI PHY/PLL」目前是**行为观察**，没有寄存器级证据 ⇒ 见线索 B。

---

## 3. 静态线索 B：ABL 交接的 `simple-framebuffer`（★最可能的差异源）

**7.2 血统（在机 vk64 树）DT 有 `chosen/framebuffer`**：

```dts
chosen {
        framebuffer: framebuffer@fc800000 {
                compatible = "simple-framebuffer";
                reg = <0x0 0xfc800000 0x0 0x2b00000>;   /* 43 MiB */
                width = <1904>; height = <3040>;
                stride = <(1904 * 4)>; format = "a8r8g8b8";
        };
};
```

**7.3 树（vk151/vk152）把它删掉了，并且 DT 里留下了明确理由**（`build/vk151/.../sm8750-lenovo-elden.dts`）：

> The simple-framebuffer is deliberately NOT described here (matching the author's working DT):
> MDSS/DPU drives the panel, and its **`DISP_CC_MDSS_CORE_BCR` reset pulls the ABL handover framebuffer
> out from under simple-framebuffer**, so fbcon would bind to a dead fb.

⇒ 这条注释本身就是 **Q28 与「复位深度」耦合的直接书面证据**：
`DISP_CC_MDSS_CORE_BCR`（= M8/vk151 的那个 mdss reset）会把 **ABL 留下的正在扫描的显示**拆掉。
而 sashiko 在 M8 评审里给的 High 意见正是同一件事（「撕掉 bootloader framebuffer / 打断 DMA」）。

**两个方向都可疑，取决于 ABL 在本次启动里到底有没有留下活着的显示**：
- 若 **ABL 本次点亮了面板并交给内核**（bootloader splash / 常亮）⇒ 内核 reset MDSS 会**撕掉它** ⇒
  「复位越彻底越坏」= 与 POR→STORM 的观察一致；
- 若 **ABL 没点屏**（本次面板本来就是暗的）⇒ 内核 reset 是纯粹的「从 known-zero 开始」⇒ 越彻底越好。

**⇒ Q32 的实验变量应该是「本次启动 ABL 有没有留活显示」，而不是「暖/冷」这个代理指标。**
可查的量（都在 `q28-clkdiag.sh` 覆盖范围内，本轮已验证能取到）：

| 量 | 含义 |
|---|---|
| 启动最早阶段 `card0-DSI-1/status=enabled` 是否在 **drm/msm probe 之前**就有 | ABL 是否已点屏（需要 `dmesg` 时间戳对齐，当前 clkdiag 取的是稳态，需加一版「probe 前快照」） |
| `0xfc800000` 这段 43 MiB 是否被 MDSS 重新 used（`/proc/iomem` / DT `reserved-memory`） | 交接 framebuffer 是否真被接管 |
| `simpledrm` 是否 probe 过（`dmesg \| grep -c simpledrm`） | 7.3 树没有 `chosen/framebuffer` ⇒ 大概率 0；7.2 树应非 0。**这一项本身就是两树的可观测差异** |
| `simpledrm` 是否被 `aperture_remove_conflicting_devices()` 移除 | 移除时机 vs MDSS reset 时机谁先 |

实测补充（2026-10-23，vk152 真 POR 后）：`dmesg | grep -ic 'simple-framebuffer|simpledrm'` = **0**、
`/proc/device-tree/chosen/` 下**没有** `framebuffer` 节点 ⇒ 7.3 树上 simpledrm 全程未参与，
所以「ABL 交接 framebuffer 被撕」在当前日常线上**只能通过 MDSS reset 的副作用体现**，不是 simpledrm 打架。

---

## 4. 静态线索 C/D：另两条更弱但便宜的面

| # | 面 | 怎么查 | 预期 |
|---|---|---|---|
| **C** | **dispcc/DSI 残留寄存器在三种复位后是否不同** | 每种复位后（在 drm/msm probe 之前尽量早）读 `STATUS0`/`CLK_STATUS`/`PLL_SYSTEM_MUXES`/`CTRL.ENABLE`/`dsi0_phy_pll_out_*` | `PITFALLS #166` 说暖复位「不清 DSI PHY/PLL」⇒ 若寄存器读数相同，则该说法需要改写为「清的是别的东西」 |
| **D** | **PMIC/`spmi-reset` 与 TCSR 在 POR 上的差异** | 查 `qcom,dload-mode`(TCSR `0x1fc0000+0x19000`) 与 `spmi-reset` 在 `SYSTEM_RESET`/`SYSTEM_RESET2` 下是否都被清 | POR 必然清 TCSR；`SYSTEM_RESET2(type=0)` 未必 ⇒ 「EDL 有时进得去有时进不去」可能同源 |

---

## 5. 三发实验设计（等物理 POR 时一次做，与 Q28 剩余样本共用断电）

> **不需要新镜像**：全部用当前在机 `vk152`，每发只改「怎么复位」，不改内核/DTB。
> 每发都跑 `scripts/q28-clkdiag.sh` + `scripts/q28-devprobe.sh`（同口径），并额外记 `dmesg` 里的
> `psci: SYSTEM_RESET2 vendor reset_type=…` 与 `simpledrm` 计数。

| 臂 | 复位方式 | 怎么产生 | 要记的 |
|---|---|---|---|
| **W1** | 暖复位（vendor reset_type `0x80010001`） | `reboot bootloader` → `fastboot reboot`（从 fastboot 起 boot_b） | clkdiag + devprobe + psci 打印 |
| **C1** | 真 POR | 长按电源 ~10 s → 短按开机 | 同上 |
| **W2** | 暖复位（架构 `SYSTEM_RESET`，type=0） | `reboot -f`（注意 `PITFALLS #215`：可能落 STORM 且 ~11 min 不可达） | 同上 |

**判据**：
1. **同臂内一致性**（W1、C1 各 ≥2 发）：若同一复位方式结果不一致 ⇒ 暖/冷不是主变量，Q32 降级为「Q28 的子现象」；
2. **跨臂差异**：若 W1 稳定 NOCARD 而 C1 稳定 GOOD（或反之），则按 §3 的「ABL 是否留活显示」去解释，而不是直接写「暖复位坏」；
3. 任何一条结论都必须**带寄存器/时间戳证据**，不接受「因为暖所以坏」。

**注意**：`reboot -f` 在 STORM 态可能让设备 ~11 min 不可达（`PITFALLS #215`）⇒ W2 放在最后做，且做之前确认 `boot_b succ=1`。

---

## 6. 与本轮 Q28 样本的关系

- Q28 剩余 2 发（r1/r2）是**真 POR**，它们回答「POR 深度下 vk152 是否稳定 GOOD」；
- Q32 回答「为什么不同深度会不同」⇒ **必须显式改变复位方式**，所以不能只用 POR 样本回答。
- 两者共用断电动作：做 Q32 的 C1 臂时顺手就能多产一发 Q28 的 POR 样本（同口径、同一脚本）。

---

## 7. 复现命令

```bash
# 每发取同口径数据（Q28/Q32 共用）
ssh root@192.168.7.1 'bash -s' < scripts/q28-clkdiag.sh
ssh root@192.168.7.1 "cat /var/tmp/q28-clkdiag-$(ssh root@192.168.7.1 'cut -c1-8 /proc/sys/kernel/random/boot_id').txt"
ssh root@192.168.7.1 'sh -s' < scripts/q28-devprobe.sh
ssh root@192.168.7.1 "dmesg | grep -E 'psci: SYSTEM_RESET2|simpledrm|simple-framebuffer'"
```
