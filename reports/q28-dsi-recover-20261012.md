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
