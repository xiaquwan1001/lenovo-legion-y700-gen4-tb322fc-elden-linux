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


---

## 12. vk119 首坏发（20:12）——**首条命令成功**、卡在**后续命令**的 DYN pclk 域切换

日志 `logs/q28-cold-20261012-201253-vk119-s1`（POR 冷起，L1FAIL；record `20261012T121433Z-vk119-s1`）。

```
8.8389  Q28 link[before-first-cmd]:  CTRL=0x171 STATUS0=0x0 CLK_STATUS=0x343  ... CMD_DMA=0x14000000
8.8389  Q28 clk[before-first-cmd]:   byte=108107958 byte_intf=108107958 pixel=172972734 esc=19200000
8.8389  Q28 link[after-first-cmd-ok]: CTRL=0x175 STATUS0=0x0 CLK_STATUS=0x2343  ... CMD_DMA=0xd4000000   ← 首条命令 OK
9.0463  command DMA timeout: status=0x2200200 ... bonded command DMA failed: master=-110 peer=0   ← 第 2 条命令卡死（peer 已完成）
9.0463  Q28 link[before-reset]: CTRL=0x175 STATUS0=0x3 CLK_STATUS=0x3743 ...        ← DYN 位置起且不释放
9.0624  Q28 link[after-reset]:  CTRL=0x171 STATUS0=0x3 CLK_STATUS=0x1743 ...        ← 复位只清 CMD_PCLK，DYN 位保留
```

- `after-first-cmd-ok` 的 `CLK_STATUS=0x2343`（AON_PCLK+CMD_PCLK、**无 DYN 位**）与 10-09 记录的好发同点值**逐字相同**
  ⇒ **成功命令结束后 DYN pclk 域会被释放并回到 0x2343**；而失败命令后 DYN 位**留着不释放**。
- 本条与另外 3 条坏发的差异只在「第几条命令开始卡」（此题是第 2 条，另 3 题是第 1 条）⇒ 现象同一类：**某条命令的 DYN pclk 域切换卡住**。
- `peer=0`（从机已完成）说明并非从机链路死亡；卡的是主机命令引擎的 pclk 域切换。
- DYN 位在**控制器复位后仍为 1** ⇒ 该状态**不在 DSI 控制器内部**（`dsi_sw_reset` 脉冲 RESET 后 DYN_PCLK_ACTIVE / DYN_CMD_PCLK_ACTIVE 仍在），
  结合「坏发里 pclk RCG 无法更新（18 条 WARN）」⇒ **卡点在 dispcc 侧的像素时钟域**。

### 12.1 vk120 下一个探针（`q28/dsi-probe3` @ `950295e32`）

按 **DCS opcode** 记录 `CLK_STATUS` 的每次变化（`Q28 cmd[clk-status-change] op=… CLK_STATUS=… CLK_CTRL=…`），
并给所有既有 dump 加上 `CLK_CTRL`：
目的 = 在**同一发里**看清 DYN 位「出现→释放」的完整生命周期，并定位是**哪条 DCS 命令**触发切换；好发对照自然就有了（好发每条命令都该是出现即释放）。


---

## 13. vk120 样本 + 原厂（stock）对照：CLK_CTRL 编程与 DT 双链路模型

### 13.1 vk120-s1（20:24，POR 冷起，L1FAIL）——DYN 位一旦卡住就再也不变

```
8.8545  before-first-cmd: CLK_STATUS=0x343  CLK_CTRL=0x23f
9.0618  before-reset:     CLK_STATUS=0x3743  STATUS0=0x20003   ← 第 1 条命令即卡
9.0802  after-reset:      CLK_STATUS=0x1743  （DYN 位保留）
9.1097  cmd[clk-status-change] op=0xff CLK_STATUS=0x1743      ← 全boot唯一一次变化（重试第 1 条 = 0xff）
之后 3 次 before/after-reset 全 0x1743 —— 不再有任何变化
```

- `CLK_CTRL` 全程 `0x23f` = `AHBS_HCLK_ON|AHBM_SCLK_ON|PCLK_ON|DSICLK_ON|BYTECLK_ON|ESCCLK_ON|FORCE_ON_DYN_AHBM_HCLK`，与**原厂 `dsi_host.c:97` 的 `DSI_CLK_CTRL_ENABLE_CLKS` 定义逐位相同**
  ⇒ CLK_CTRL 编程没有漏位（原本怀疑「缺 DYN pclk 的 force-on 位」不成立：该寄存器只定义了 FORCE_ON_DYN_AHBM_HCLK 这一个 force 位）。
- `clk-status-change` 全程只出现 **1 次**：DYN pclk 域一旦卡住就**永不释放**，重试全部在 0x1743 下失败。

### 13.2 stock（原厂）对照——`backup/stock-elden/elden.dts` + `stock-src/android_kernel_lenovo_sm8750`

| 项 | 原厂 | 本树 | 结论 |
|---|---|---|---|
| 双链路模型 | `mdss_dsi0/dsi1` 各带 `qcom,split-link-supported`；单个 `qcom,dsi-display-primary` 同时引用两个 ctrl+phy | `qcom,dual-dsi-mode`+`sync-dual-dsi`+`master-dsi` | **同一件事的主线写法** ⇒ 「删掉 sync-dual-dsi 以绕开双引擎」**不是有效实验**（会让一条链路不被初始化/时钟化），已排除 |
| CLK_CTRL | `DSI_CLK_CTRL_ENABLE_CLKS` 含 `FORCE_ON_DYN_AHBM_HCLK` | 逐位相同 | 寄存器编程无差异 |
| 命令传输（sync 双链路） | `msm_dsi_manager_cmd_xfer()`：`xfer_prepare(另一条 host)` → `cmd_tx(本 host)` → `cmd_xfer_commit` **两条都提交**（标准 `dsi_cmd_dma` 路径 + 正常中断/completion） | 自定义 `msm_dsi_host_bonded_cmd_*` 序列（prepare→build→init_trigger→stage→trigger→arm_master→wait_master→poll_slave） | **结构性差异**：卡点在命令引擎启动瞬间的 DYN pclk 域切换，触发次序/等待方式正是两者最大不同 ⇒ 候选修复 |
| 默认面板 | `elden_nt36523_csot_3k_dsc_vid`（video 模式 DSC） | mainline `panel-novatek-nt36536` | 同族 |

### 13.3 下一步候选

1. **vk121（推荐）**：把双链路命令传输换成**原厂/stock 的写法**（prepare 两条 host → 在 master 上 `cmd_tx` → 用 `msm_dsi_host_cmd_xfer_commit()` 同时提交两条），即弃用自定义 `bonded_cmd_*` 序列。
   理由：原厂在**同一块硅**上就是这么发命令的；卡点正是「命令引擎启动」这一步。
2. 继续采样等 **GOOD 发**（对比生命周期；每发需一次 POR，当前处于坏发簇）。
3. 暂时把精力移到 Q24（上游 RFC v2 + 外部电测），等坏发簇翻转再回来。


---

## 14. vk121（标准广播路径）首个样本：**干净否证——自定义 bonded 序列被洗清**

`logs/q28-cold-20261012-205156-vk121-s1`（POR 冷起，L1FAIL；record `20261012T125348Z-vk121-s1`）。

```
8.8490  Q28 link[before-first-cmd]: CTRL=0x171 STATUS0=0x0 CLK_STATUS=0x343 CLK_CTRL=0x23f
9.0521  dsi_cmds2buf_tx: cmd dma tx failed, type=0x15, data0=0xff, len=4, ret=-110   ← 标准路径的失败行
9.0815  Q28 cmd[clk-status-change] op=0xff CTRL=0x171 STATUS0=0x20003 CLK_STATUS=0x1743 CMD_DMA=0xd4000000
9.2840  dsi_cmds2buf_tx: ... ret=-110    (attempt 2)
9.5160  dsi_cmds2buf_tx: ... ret=-110    (attempt 3) → Failed to initialize panel: -110
```

- **失败签名确实变了**：不再有 `bonded command DMA failed: master/peer`，改为标准 `dsi_cmds2buf_tx` 的 `-110`
  ⇒ 路径切换**已生效**（`msm_dsi_manager_cmd_xfer_trigger()` 的广播提交在跑）。
- **但同一个卡死态照旧**：`CLK_STATUS=0x1743`（DYN_PCLK|DYN_CMD_PCLK 置起不释放）、`STATUS0=0x20003`（ENGINE_BUSY+DMA_BUSY）、3 次尝试全 -110（间距 ~232 ms）。
- ⇒ **自定义 `bonded_cmd_*` 序列不是原因**：两条命令路径在**同一层**（`dsi_cmds2buf_tx` → 命令引擎 DMA + dispcc DYN pclk 域切换）卡死。
- 注：本臂里恢复钩子位于（已停用的）bonded 路径内，故无 `resetting DSI link` 日志——符合预期，不影响判定。

### 14.1 剩余差异范围（下一步）

命令路径已排除，剩下只可能在基础设施层：
1. **DT 调参**：原厂 `elden.dts` 的 DSI ctrl/PHY 节点属性（`frame-threshold-time-us=0x320`、PHY 的 `qcom,dsi-phy-*`/supply/lane 配置等）与本树逐项对比。
2. **PHY/D-PHY 时序编程**（`dsi_phy_10nm/7nm` 的 PLL + lane 设置）。
3. **dispcc 时钟源**（pixel/byte RCG 的父与 rate；已知坏发里 pclk RCG 无法更新）。


---

## 15. ★原厂（vendor）display 源码到手：dyn refresh 寄存器面 + **force-on 使能序列差异**

来源：`LineageOS/android_kernel_oneplus_sm8750-modules`（**同一 SoC SM8750/sun**）的 `qcom/opensource/display-drivers/msm/dsi/`，已取回 8 个文件到 `/tmp/vdsrc/`。

### 15.1 原厂有、本树完全没有的 dyn refresh 寄存器面

| 项 | 原厂 | 本树 |
|---|---|---|
| 寄存器 | `DSI_DYNAMIC_REFRESH_CTRL = 0x0200`、`DSI_DYNAMIC_REFRESH_STATUS = 0x0210`（`dsi_ctrl_reg.h`）⇒ 正是原厂 DT 里 PHY 的 `dyn_refresh_base = <0xae94200 0xa0>` | generated 的 `dsi.xml.h` 在 0x200–0x2ff **一个寄存器都没定义**，驱动也从不碰 |
| 握手 | `DSI_LANE_CTRL` bit28 = 请求；`DSI_INT_CTRL` bit28 = done（轮询 ≤84 ms ≈5 vsync）+ **W1C 回写 ack** | 无 |
| PHY v7.2 | `dyn_refresh_config` / `dyn_refresh_pipe_delay` / `dyn_refresh_trigger_sel` / `dyn_refresh_helper` / `cache_phy_timings` | 无 |
| DT 侧 | 本机原厂 DT 的面板节点带 `qcom,mdss-dsi-pan-enable-dynamic-fps`、`qcom,dsi-dyn-clk-enable` + `qcom,dsi-dyn-clk-list = <0x3083ad80 0x30c45d12 0x31050ca4>`（3 档动态时钟） | 本树面板/DPU 侧无动态刷新概念 |

### 15.2 ★差异点：使能 `DSI_EN` 时的 dynamic force-on

原厂 `dsi_ctrl_hw_cmn_ctrl_en()`：
```
clk_ctrl = DSI_R32(DSI_CLK_CTRL);
DSI_W32(DSI_CLK_CTRL, clk_ctrl | DSI_CTRL_DYNAMIC_FORCE_ON);   /* 强制打开内部动态时钟 */
wmb();
reg = DSI_R32(DSI_CTRL); on ? reg |= BIT(0) : reg &= ~BIT(0); DSI_W32(DSI_CTRL, reg);
wmb();                                                          /* DSI_EN 生效后才允许关时钟 */
DSI_W32(DSI_CLK_CTRL, clk_ctrl);
```
其中 `DSI_CTRL_DYNAMIC_FORCE_ON = 0x23F|BIT(8)|BIT(9)|BIT(11)|BIT(21)` —— 与本树 `dsi_sw_reset_v2_9()` 里那段 `force_on` **逐位相同**（常量没问题，位置不对）。

本树 `msm_dsi_host_xfer_prepare()`（以及 bonded 版）**直接写** `DSI_CTRL |= CMD_MODE_EN|ENABLE`，**没有任何 force-on 保护**。

⇒ **根因假设**：命令引擎在「动态 pclk 域尚未起来」时被使能 —— 正好解释我们观测到的坏发态：`DYN_PCLK_ACTIVE`/`DYN_CMD_PCLK_ACTIVE` 闩住、`STATUS0=0x20003`（ENGINE+DMA busy）、**零中断**、且 DSI 侧复位清不掉（DYN 请求仍在）。

### 15.3 vk122（候选修复，`q28/stock-cmd` @ `03836b22e`，patch `patches/q28-forceon.patch`）

= vk121（标准广播路径，已证中性）+ 在 `msm_dsi_host_xfer_prepare()` 里按原厂序列包上 force-on：
`CLK_CTRL |= ENABLE_CLKS|BIT8|BIT9|BIT11|BIT21` → `wmb` → 写 `CMD_MODE_EN|ENABLE` → `wmb` → 恢复 `CLK_CTRL` → `wmb`。
镜像 `out/boot-elden-vk122-forceon.img`，sha `73e1fe6a…`，载荷 `7965d616…`；**verification=NOT_TESTED_ON_DEVICE**


### 15.4 vk122 样本记录

| # | 时间 | 复位 | 判定 | 失败标记 | 说明 |
|---|---|---|---|---|---|
| s1 | 21:15 | POR 冷起 | **GOOD** | `dsi_cmds2buf_tx failed`=0 / `rcg didn`=0 | `l1=0 l2=0 storm_sig=0`，phoc/phosh/wayland 全起；`before-first-cmd` 与坏发同（CLK_STATUS=0x343）；**全 boot 无 clk-status-change**（DYN 位从未闩住）|

（基线坏发率 ~50% 且按时间成簇 ⇒ 单发不作数，继续采样。）

| s2 | 21:18 | POR 冷起 | **GOOD** | 0 | 抓到**健康发生命周期**：op=0x92 时 `CLK_STATUS=0x743`（=0x343+DYN_PCLK_ACTIVE），下一条 op=0xb2 前已回到 `0x343` ⇒ DYN pclk 域按命令瞬时开/放 |
| s3 | 21:21 | POR 冷起 | **GOOD** | 0 | 无 clk-status-change（DYN 位未闩住）|

**累计 vk122 = 3/3 GOOD、失败标记 0**（同一时间窗内前一段基线是 5 连 L1FAIL；零假设下单侧 p≈0.125，仍需再补 2 发到 5 发）。

| s4 | 21:23 | POR 冷起 | **L1FAIL（坏发）** | 3× `dsi_cmds2buf_tx ... ret=-110` | **与 vk121/基线逐字同签名**：op=0xff、9.05/9.29/9.52 s、`STATUS0=0x20003`、`CLK_STATUS=0x1743`；`Failed to initialize panel: -110` |

### 15.5 ★结论：vk122（dynamic force-on 使能保护）**否证**

- 累计 **3/4 GOOD**（≈基线 ~50%），且第 4 发的坏发**签名逐字相同**（同一个 op=0xff、同样的 `STATUS0=0x20003`/`CLK_STATUS=0x1743`/三连 -110）。
- ⇒ 在 `xfer_prepare()` 按原厂序列包 dynamic force-on **不能**阻止 DYN pclk 域闩住；**使能保护不是根因**。
- 仍未解的核心事实：健康发里 DYN pclk 域「按命令瞬时开/放」（0x343→0x743→0x343），坏发里它**闩住不释放**（0x1743/0x3743）⇒ 引擎/DMA 永久 busy、零中断、DSI 侧复位清不掉。
- 今日已否证的路线（均为单变量、可复现）：① 面板级 reset（vk64 旧补丁）② 软件闩锁（vk116，闩锁确实被清）③ DSI ctrl+PHY 复位（vk117，寄存器证明确实复位）④ 自定义 bonded 触发序列（vk121，换标准路径仍坏）⑤ 使能期 dynamic force-on（vk122）。

---

## 16. Q28 今日收束：已证 / 已否证 / 剩余靶点（2026-10-12 晚）

### 16.1 已**证**实（不再是假设）

1. **旧判据作废**：「首败后 DSI host 楔死、重试必然 -5」= 软件闩锁短路（vk116 实测：第 2/3 次改回 -110，重试真的打到硬件）。
2. **DSI 控制器复位确实发生但救不回**（vk117 寄存器转储：`CTRL 0x175→0x171`、`CLK_STATUS 0x3743→0x1743`、`CMD_DMA_CTRL 0xd4000000→0x14000000`，第 2/3 次仍逐字 -110）。
3. **判别量 = DYN pclk 域生命周期**：健康发里按命令瞬时开/放（实测 `0x343 →(op=0x92) 0x743 →(op=0xb2) 0x343`）；坏发里**闩住不释放**（`0x1743`/`0x3743`）+ `STATUS0=0x20003`（ENGINE_BUSY|DMA_BUSY）+ **DSI 中断计数 0** + `PLL_UNLOCKED` 位未置（PLL 是锁的）。
4. **DYN 位在控制器 sw_reset 后仍在** ⇒ 它不是 DSI 内部状态，而是**dispcc/INTF 侧「动态时钟」请求的映射**（DSI 只是采样显示）。
5. 坏发**首命令前**的寄存器与好发**逐字相同**（CTRL/STATUS0/CLK_STATUS/CLK_CTRL/INTR_CTRL 全同）⇒ 差异是**命令执行瞬间**产生的竞态，不是 bring-up 配置差异。

### 16.2 已**否证**（今日，均单变量 + 可复现签名）

| 路线 | 臂 | 结果 |
|---|---|---|
| 面板级 reset 重试 | vk64 旧补丁 | 无效（闩锁短路，从未真重试） |
| 软件闩锁 = 根因 | vk116 | 闩锁确实被清，故障照旧 |
| DSI ctrl+PHY 复位 | vk117 | 寄存器证明确实复位，故障照旧 |
| 自定义 bonded 触发序列 | vk121 | 换标准广播路径，签名改变但同一卡死态 |
| 使能期 dynamic force-on | vk122 | 3/4 GOOD，第 4 发同签名坏发 |
| VBIF 优先级/FIFO 水位 | （既有 bonded 路径已设 7/禁用位）| 同签名坏发 ⇒ 非此因 |

### 16.3 剩余靶点（按可执行性排序）

1. **dispcc / INTF 侧的「动态时钟」请求**：原厂把 `disp_cc_base=0xaf0f000`、`mdp_intf_base=0xae36000` 映射进 DSI 控制器驱动，主线这两块归 DPU/dispcc 管；需要读原厂 `dsi_ctrl_hw_cmn` 的 INTF/dyn 相关写入（`DSI_DYNAMIC_REFRESH_CTRL=0x200`/`_STATUS=0x210`、`LANE_CTRL` bit28、`INT_CTRL` bit28 done+ack）并判断主线缺哪一步。
2. **原厂 `kickoff_command` 逐步对照**（`DSI_COMMAND_MODE_DMA_CTRL` 的 embedded/LPM/bit31/30、`DSI_DMA_FIFO_CTRL`、`DSI_VBIF_CTRL`、`DSI_CMD_MODE_DMA_SW_TRIGGER`）与主线 `dsi_cmds2buf_tx` 的差异点。
3. **模式/时序层面的规避**：换 panel 模式参数（如强制非动态、改 DSC/wide bus 组合）——但主线面板驱动参数与原厂 panel 的 mode 串尚未逐项对齐。
4. **运营侧**：Q28 只在冷起 ~50% 命中，且**坏发可用 SSH 侧判据提前识别**（`l1/l2/storm_sig` 与 `card0`）⇒ 可做自动「坏发 → sysrq-b 重启」看门狗（第二次启动 50% 成功，期望把可用性从 50% 提到 ~75%）；但这不改根因。


---

## 17. 收尾交接（2026-10-12 深夜）

- 本会话共出 **7 个实验臂**（vk116–vk122），全部按单变量构建并在设备上取过样本；镜像与补丁均入库（`out/boot-elden-vk11{6,7,8,9}-*.img`、`out/boot-elden-vk12{0,1,2}-*.img`、`patches/q28-*.patch`），台账 `versions/vk-registry.tsv` 有逐条注记。
- 子代理（lane）状态：
  - `audit/early-reboot`（脚本过早复位审计）**已完成**并已并入 main（`bd97123`，含 `scripts/lib-boot-ready.sh` 就绪门 + 审计报告），另落 **PITFALLS #225**。
  - 上游补丁合并 lane（内核 `elden/lane-upstream`，3 commit/14 补丁 + 报告 `reports/upstream-hits-20261012.md`）的**合并/变基子代理在收尾时仍在跑**（worktree `/home/xuqianhui1001/y700-wt/wt-merged` @ `d02658e63`，未产出 deliverable）⇒ 下一轮请重跑该任务；其已给出的结论摘要（供参考）：`methodB` 语义已定、lane 的 `d152b582`（round-in-calc）在本树会把 XO 父下的 bogus 值喂给 SM8750 预设 PLL workaround，而 `c59e4a90`（round-after-reparent）正好消解该隐患。
- 设备收尾状态：停在 vk122 的**坏发态**（`L1FAIL`，只有背光；SSH 可用、`card0=1`），无后台任务、设备锁空闲；下次使用前先物理 POR（长按电源 ~15 s → Vol- + 电源）。
- 参考资产：`reference/stock-elden.dts`（原厂设备 DTS，来自 `backup/stock-elden/elden.dts`）；原厂 display 源码已取到 `/tmp/vdsrc/`（易失，需要时按报告 §15 的 URL 重取）。
