# Q28 驱动内自恢复臂（vk116-dsirec）设计评估与构建 — 2026-10-12

## 1. 结论（数字先行）

- **可行性：可行。** 且旧判据「DSI host 首超时后楔死、面板级 reset 救不回」**不成立**——那条 `-5` 是
  **纯软件闩锁在触碰硬件前短路**，与硬件可恢复性无关（证据见 §2）。
- **已落地并编译完成**：补丁 3 文件 / +78 −7；镜像 `out/boot-elden-vk116-dsirec.img`
  （85319680 B，sha `810445fa…`，内核载荷 `c44817ad…`，`verification=NOT_TESTED_ON_DEVICE`）。
- 与基准 **单变量**：同源码 `d02658e63` / 同 config / 同 ramdisk `35823240` / 同 DTB `5d658a2c` /
  同 cmdline / **同构建身份 `#121`（同时间戳）** ⇒ 唯一差异 = 本补丁。

## 2. 机制证据（代码级，d02658e63）

1. 首条 DCS 超时点在 `dsi_manager.c: dsi_mgr_bonded_cmd_xfer()`：master/peer 都 -110 →
   `WRITE_ONCE(dsi_bonded_cmd_failed, true)`（唯一实际触发的置位点，`dsi_manager.c:642`）。
2. 该 `static bool` **全树只写 true、从不清零**（`grep dsi_bonded_cmd_failed` 仅 4 处）。
3. DSI 层的 **-5 = `dsi_mgr_bonded_cmd_xfer()` 开头 `if (msm_dsi_manager_cmd_failed()) return -EIO;`**
   ⇒ 面板重试的第 2/3 次**根本没到 `msm_dsi_host_bonded_cmd_*`**，没碰 DMA 引擎。
   `-5` 因此**不能**作为「host 楔死」的证据（旧结论属过度归因）。
4. 同一闩锁还短路 `dsi_mgr_bridge_pre_enable/power_off/post_disable/enable`（5 处），
   置位后整条链路的**正常下电路径也被跳过** ⇒ 故障自锁。
5. 结论：PITFALLS #224 规约 ② 的方向（驱动内 `power_off/on` 再重试 DCS）正确，缺的恰好是
   「**清零闩锁 + 真正复位控制器/PHY**」两件事。

## 3. 为什么复位窗口是安全的

- `dsi_mgr_bridge_pre_enable()` 在 SM8750 上 **只 power_on host、故意不 enable 视频**就返回
  （`to_dsi_bridge(bridge)->powered = true; return;`）；视频在 `dsi_mgr_bridge_enable()` 才开。
  面板 prepare（DCS 写）发生在这两者之间 ⇒ 两侧 `msm_dsi_host_is_enabled()==false`，DPU INTF 未运行。
- `msm_dsi_host_power_on()` 内部已含 `dsi_sw_reset_v2_9()`（SM8750 原厂复位序列，含强制动态时钟）
  → `link_clk_set_rate_6g_v2_9` → `dsi_ctrl_enable` → `dsi_timing_setup`；
  `power_off()` 走 `dsi_ctrl_disable` + pinctrl sleep + clock parent 还原。
- PHY 侧沿用既有语义：`dsi_mgr_link_power_off(mid)` + `dsi_mgr_phy_disable(sid)`
  （**两条链都置 down 才关 PHY**）→ `dsi_mgr_link_power_on(mid)`（`reset_phy` 两个 PHY + PLL 重锁），
  与正常 pre_enable 路径**同构**。
- **守卫**：仅当两侧 video engine 都未使能时才复位；运行期（背光等）DCS 失败仍保留原闩锁行为 ⇒ 不会黑屏。

## 4. 补丁

分支 `q28/dsi-recover` @ `6702e9d59`；patch 文件 `patches/q28-dsi-link-recover.patch`（146 行 diff）。

| 文件 | 内容 |
|---|---|
| `dsi_host.c` / `dsi.h` | 新增 `bool msm_dsi_host_is_enabled()`（复位守卫用） |
| `dsi_manager.c` | `dsi_mgr_bridge_power_on/off` 拆出 id 版 `dsi_mgr_link_power_on/off`（闩锁守卫留在 bridge 包装里）；新增 `dsi_mgr_recover_link()`；在 `dsi_mgr_bonded_cmd_xfer()` 失败分支先置闩锁、再尝试恢复（成功则清零闩锁，让面板驱动的既有 retry 在干净链路上跑） |

面板驱动的 retry 循环（`d02658e63`，3 次尝试）**无需改动**：第 1 次失败即触发链路复位，第 2 次才真正打到硬件。

## 5. 构建

```
VERSION=vk116-dsirec PATCH=patches/q28-dsi-link-recover.patch \
  bash scripts/q28-build-daily-id.sh out/boot-elden-vk94.img vk116-dsirec
```

- `[3] ✅ 3 位构建号 #121`；UTS `Linux version 7.2.0-debug-vk64-gd02658e63cf6 … #121 SMP PREEMPT Mon Oct 12 18:00:00 CST 2026`
  （与 vk113 逐字同 ⇒ 构建身份不变量）。
- `config_sha256=af8a2d69…`、`ramdisk_sha256=35823240…`、`dtb_packed_sha256=5d658a2c…` 全等于基准。
- `System.map` 含 `msm_dsi_host_is_enabled` ⇒ 补丁确实链进内核。
- 日志 `logs/q28-build-vk116-dsirec-20261012-181826.log`。

## 6. 待上机（判据与协议）

判据（三态分类器照旧 `command DMA timeout` | `panel init attempt.*failed` | `vblank wait timed out`）：

- **修复生效**：日志出现 `command DMA failed before video enable, resetting DSI link`，
  随后 **不再出现 `dcs data … failed: -5`**，且 `panel init attempt 2` 无失败行 → 桌面起。
- **修复无效**：复位后第 2 次仍是 `-110`（或 `-5` 但**之前没有** resetting 行）⇒ 那时才可判定
  「控制器/PHY 级复位救不回，需面板或 PHY 供电级手段」。
- 协议：`scripts/q28-cold-run.sh out/boot-elden-vk116-dsirec.img vk116-dsirec`（每发必须真 POR 后进 fastboot；
  禁暖复位样本，PITFALLS #163/#164）；单臂先跑 ≥3 发；对照 `vk113-dailyid`（同身份、无补丁）。

## 7. 风险

- 复位落在 modeset 前半段，DPU 未参与 ⇒ 失败域限于 DSI 链路；最坏情况 = 第 2 次仍失败，
  日志等价于现状（多一条 warn）+ 一次链路上下电耗时（~10 ms 量级 + PLL 重锁）。
- 不做 sysfs 重绑（PITFALLS #224 已证会拆 DRM）。
- 若首发被判定 STORM，说明补丁没救回 ⇒ 才需要上「面板/PHY 供电级」或「避开首条 DCS 的时序」方案。

---

## 8. 首坏发实测（2026-10-12 19:10，vk116-dsirec，POR 冷起，L1FAIL）

日志 `logs/q28-cold-20261012-191056-vk116-s4/dmesg.txt`，record `reports/trials/20261012T111236Z-vk116-s4.json`。

### 8.1 恢复路径确实执行，且**软件闩锁被清除**

```
[ 9.036] ae94000.dsi: command DMA timeout: status=0x2200200
[ 9.041] ae96000.dsi: peer command DMA timeout: status=0x2200200
[ 9.041] ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
[ 9.041] ae94000.dsi: command DMA failed before video enable, resetting DSI link   <-- 本补丁
[ 9.061] panel-novatek-nt36536: sending dcs data ff 20 failed: -110
[ 9.061] panel-novatek-nt36536: panel init attempt 1 failed: -110, resetting and retrying
[ 9.296] ae94000.dsi: command DMA timeout: status=0x2200200        <-- 第 2 次仍是 -110
...
[ 9.552] ae94000.dsi: command DMA timeout: status=0x2200200        <-- 第 3 次仍是 -110
[ 9.577] panel: Failed to initialize panel: -110
```

- **第 2/3 次失败是 `-110` 而不是 `-5`** ⇒ 闩锁清除成功、重试**真的打到了 DMA 硬件**。
  这彻底废除了旧判据「首败后 DSI host 楔死、重试必然 -5」——那条 -5 一直是 `dsi_bonded_cmd_failed` 短路。
- `power_on` 未报失败（无 `failed to bring the DSI link back`）⇒ 恢复函数走完了整条链路复位。
- 但 3 次 DCS 写入每次都在 ~200 ms（既有 `wait_for_completion_timeout(200ms)`）后超时，`status=0x2200200` 逐字相同。

### 8.2 ★本轮否证**受污染**，不能作为「复位救不回」的结论

同一坏发里出现：

```
[ 9.042] Turning OFF PHY while PLL is on
[ 9.042] unbalanced disables for vreg_l3i_0p88   (WARNING drivers/regulator/core.c:3261)
```

坏发共 **6× `unbalanced disables for vreg_l3i_0p88` + 2× `Turning OFF PHY while PLL is on`**；同口径 GOOD 发（s1/首测）**0 次**。
根因 = 我写的恢复序列多调了一次 `dsi_mgr_phy_disable(sid)`，而 `dsi_mgr_link_power_off(mid)` 内部的 `dsi_mgr_phy_disable(mid)`
在「两个 `phy_enabled` 都为假」时**已经把两个 PHY 都关了**（与 `dsi_mgr_bridge_post_disable` 同语义）⇒ 第二次属重复关闭。
`msm_dsi_phy_disable()`（`phy/dsi_phy.c:811`）**没有幂等守卫**：无条件 `regulator_bulk_disable()` + `pm_runtime_put()`。
⇒ PHY 稳压器引用计数与 runtime-PM 参考数被破坏，**这一轮的「复位无效」结论作废**。

### 8.3 修正臂 vk117-q28rec2（`q28/dsi-recover2` @ `a9ee55520`，patch `patches/q28-dsi-recover2.patch`）

1. 去掉重复的 `dsi_mgr_phy_disable(sid)`（恢复序列与 `post_disable` 完全同构）。
2. 新增 `msm_dsi_host_dump_link_state()`，在恢复**前后**各打一行 `Q28 link[before-reset|after-reset]`:
   `CTRL / STATUS0 / CLK_STATUS / INTR_CTRL / CMD_DMA_CTRL`——用来判定复位是否真的清掉了 2026-10-09 差分出的区分态
   （`STATUS0` bit、`CLK_STATUS` 的 `DYN_PCLK_ACTIVE`/`DYN_CMD_PCLK_ACTIVE`、`cmd_dma_busy`）。

判据：① 不再出现 `unbalanced disables`/`Turning OFF PHY while PLL is on`；② 有 before/after 两行寄存器；
③ 若 after-reset 已清零区分位但第 2 次 DCS 仍 -110 ⇒ 楔点不在 DSI 控制器/PHY 寄存器态，转面板/供电级；
④ 若第 2 次 DCS 通过 ⇒ 修复成立（且 vk116 的失败可归因于被污染的恢复序列）。

---

## 9. vk117 构建与首轮验证（2026-10-12 19:21 起）

- 镜像 `out/boot-elden-vk117-q28rec2.img`，sha `b9fa06db…`，载荷 `fd4f6729…`，85319680 B；分支 `q28/dsi-recover2` @ `a9ee55520`；
  身份与 vk116/vk113 逐字同（`#121` + 同时间戳）⇒ 唯一差异 = 恢复序列修正 + 寄存器转储。预检：`System.map` 有 `msm_dsi_host_dump_link_state`、内核串含 `Q28 link[`。
- 暖启验证循环 `scripts/q28-warm-vk117-loop.sh`（sysrq-b 自举 → 就绪门 → `q28-boot-cycle.sh` → 判读）：
  **第 1 轮 rc=0（GOOD，无 DCS 失败 ⇒ 恢复路径未触发，无鉴别力）**；
  第 2 轮在 `uptime=15.4 s` 发 `reboot2 bootloader` 后设备**再次进入无任何 USB 通道态**（与 18:55 那次 `uptime=20.4 s` 同型）⇒ 循环中止。
  ⇒ 该现象 2/2（uptime<25 s）vs 3/3 正常（uptime>100 s），已落 **PITFALLS #225**，并在循环里加「等就绪再复位」；就绪门已接入 `q28-boot-cycle.sh`。
- 待办：设备 POR 后重跑「就绪门 + 3 轮」，**必须抓到至少一次坏发**才算验证 vk117（判据：无 `unbalanced disables`、出现 before/after 寄存器、第 2 次 DCS 是否仍 -110）。


---

## 10. vk117 首个坏发：DSI 控制器复位"确实生效"但**不能**救回（2026-10-12 19:41，POR 冷起，L1FAIL）

日志 `logs/q28-cold-20261012-194103-vk117-s1/dmesg.txt`；record `reports/trials/20261012T114243Z-vk117-s1.json`。

### 10.1 寄存器转储结论：控制器被复位了，故障原样复现

| 时点 | CTRL | STATUS0 | CLK_STATUS | INTR_CTRL | CMD_DMA_CTRL |
|---|---|---|---|---|---|
| before-reset #1 | 0x175 | 0x20003 | **0x3743** | 0x2200200 | 0xd4000000 |
| after-reset #1 | 0x171 | 0x20003 | **0x1743** | 0x2200200 | 0x14000000 |
| before-reset #2 | 0x175 | 0x20003 | 0x1743 | 0x2200200 | 0xd4000000 |
| after-reset #2 | 0x171 | 0x20003 | 0x1743 | 0x2200200 | 0x14000000 |
| before/after #3 | 同上 | | | | |

- `CLK_STATUS` 的 `DYN_PCLK_ACTIVE`/`DYN_CMD_PCLK_ACTIVE`（0x3743→0x1743）**被复位清掉了**，`CMD_DMA_CTRL=0xd4000000→0x14000000`、`CTRL 0x175→0x171` 同样改变
  ⇒ **DSI 控制器寄存器态确实被整车复位**（`dsi_sw_reset_v2_9` + PHY 下电/上电 + regulator 循环）。
- 但第 2/3 次 DCS 写入仍**逐字相同**地失败：`command DMA timeout: status=0x2200200`（200 ms 软超时）→ `master=-110 peer=-110`。
- **⇒ 楔点不在 DSI 控制器的可编程寄存器态**。「驱动内复位 DSI ctrl+PHY」这条路线到此**走到尽头**（PITFALLS #224 规约②的假设被否证）。
- 恢复路径本身这次是干净的：`unbalanced disables` **0 次**（vk116 为 6 次）；剩余的 `Turning OFF PHY while PLL is on` 与正常下电路径同源。

### 10.2 两个新的硬判别量（好/坏发二分，均为 0 vs 非 0）

1. **`disp_cc_mdss_pclk{0,1}_clk_src: rcg didn't update its configuration.`**（`clk-rcg2.c:136`，`clk_pixel_set_rate`→`clk_rcg2_configure`→`update_config`，等 `CFG_UPDATE` 500 µs 未清）
   - 坏发 vk117-s1：**18 次**（9×pclk0 + 9×pclk1，集中在 3 次恢复各自的 `power_on` 里，每次 6 条）；坏发 vk116-s4：**18 次**。
   - 好发 vk116-s1 / vk116-首测：**0 次**。
   - 位置：`msm_dsi_host_power_on → dsi_link_clk_set_rate_6g_v2_9 → clk_set_rate → clk_pixel_set_rate`（**在 `dsi_sw_reset` 之前**，即 RCG 重编程发生在 DSI 还处于"DYN pclk 未完成"态时）。
2. **DSI 中断计数**：好发 `dsi_isr` IRQ **41 次**（另一条 0）；坏发两条 `dsi_isr` 自开机起**全 0**（`/proc/interrupts`，死机态实测 351 s 未变）
   ⇒ 坏发里 DSI 控制器**从未产生任何中断**，命令引擎装填后从不推进。
- 另：`dsi1vco_clk`（从 PLL）好坏发都关（0 0 0）、`mdss_int2_gdsc` 好坏发都 `off-0` ⇒ 这两个**不是**判别量（早期怀疑作废）。

### 10.3 下一步（vk118 设计）

把"**首次命令 DMA 之前**"的 DSI + 时钟态在**每发**都打出来（好/坏发都打），直接找判别位，而不是只在失败后才看：

- `dsi_mgr_bonded_cmd_xfer()` 里用一次性 static 标志，在**第一条** bonded 命令前 dump：`CTRL/STATUS0/CLK_STATUS/INTR_CTRL/CMD_DMA_CTRL` + `clk_get_rate(pixel/byte)` + pclk RCG 的父索引（`CFG_REG`）；
- 并在 `dsi_link_clk_set_rate_6g_v2_9()` 返回处打印**返回值**（当前 power_on 把它的错误吞了：坏发 18 条 RCG WARN 但无 `failed to enable link clocks`）；
- 目的：若"首条命令前"好/坏发就有寄存器/时钟差异 ⇒ 拿到真正的判别量；若完全相同 ⇒ 判别发生在命令发射的瞬间（PHY/lane 侧或 dispcc DYN 握手），下一靶转向 PHY 模拟/面板侧 LP11。


---

## 11. 首命令探针（vk118）与 CLK_STATUS 位解码：判别量 = **DYN pclk 域**

坏发 `logs/q28-cold-20261012-200402-vk118-s1`（POR 冷起，L1FAIL；record `20261012T120542Z-vk118-s1`）。

### 11.1 首条 bonded 命令**之前**的固定点（每发都打）

```
Q28 power_on: link_clk_set_rate -> 0            (初始 bring-up；无 rcg WARN)
Q28 link[before-first-cmd]: CTRL=0x171 STATUS0=0x0 CLK_STATUS=0x343 INTR_CTRL=0xaa20aa02 CMD_DMA_CTRL=0x14000000
Q28 clk[before-first-cmd]: byte=108107958 byte_intf=108107958 pixel=172972734 esc=19200000
```

### 11.2 位解码（`generated/dsi.xml.h`）

| CLK_STATUS 位 | 值 | 含义 |
|---|---|---|
| 0x1/0x2 | AHBM HCLK | AON / DYN |
| 0x40/0x80 | BYTECLK | AON / DYN |
| 0x100/0x200/0x400 | ESCLK / PCLK / DYN_PCLK | |
| 0x1000 / 0x2000 / 0x4000 | DYN_CMD_PCLK / **CMD_PCLK** / VID_PCLK | |
| 0x10000 | **PLL_UNLOCKED** | |
| STATUS0 0x1 / 0x2 | CMD_MODE_ENGINE_BUSY / CMD_MODE_DMA_BUSY | |

| 时点 | CLK_STATUS | 置位域 | STATUS0 |
|---|---|---|---|
| 坏发·首命令前 | 0x343 | AHBM(AON+DYN) + AON_BYTECLK + AON_ESCCLK + **AON_PCLK** | 0x0 |
| 坏发·失败后 | **0x3743** | += **DYN_PCLK(0x400) + DYN_CMD_PCLK(0x1000) + CMD_PCLK(0x2000)** | **0x20003** = ENGINE_BUSY+DMA_BUSY+bit17 |
| 坏发·本补丁复位后 | **0x1743** | += DYN_PCLK + DYN_CMD_PCLK（**CMD_PCLK 清，DYN 位保留**） | 0x20003 |
| 10-09 记录·好发同点 | 0x2343 | AON_PCLK + CMD_PCLK（**无 DYN 位**） | — |

- **PLL_UNLOCKED 未置位** ⇒ 失败时 PLL 是锁的（排除 PLL 未锁假说）。
- 坏发进入 **DYN pclk 域**（0x400/0x1000）并卡在那里；DSI 控制器复位只清 CMD_PCLK，**DYN 位保留** ⇒ 重试再撞同一域、逐字复现。
  ⇒ 与 10-09 的「命令引擎撞上 DYN 像素时钟域切换」假说一致，且现在有**可读位证据**。
- `STATUS0=0x20003`：命令引擎与命令 DMA 都报 busy（永不完成）；同期 **DSI 中断计数 0**（引擎从不产生完成/错误中断）。
- `link_clk_set_rate -> 0`（初始与每次恢复都返回 0）：pclk RCG 的 `-EBUSY`/WARN 被 clk 框架吞掉 ⇒ **power_on 不报错不代表时钟编程成功**（18 条 `rcg didn't update` 与「返回 0」并存）。

### 11.3 vk119（`q28/dsi-probe2` @ `fc7af79a1`，patch `patches/q28-dsi-probe2.patch`，镜像 sha `033d4676…`）

= vk118 + **成功路径同点 dump**（`Q28 link[after-first-cmd-ok]`）：好发只有 before 点、坏发有 before/failure 点，缺的就是「好发在命令成功后台 DYN 位是否也置起」。
有了它即可判定：DYN 位是**正常命令模式的常态**（那坏发就另有其因）还是**只在坏发出现的卡死标记**。

