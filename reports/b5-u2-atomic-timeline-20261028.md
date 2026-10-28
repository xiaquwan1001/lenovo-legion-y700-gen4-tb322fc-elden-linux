# B5/M6 **U2** 收口：原子回调时序实测（bonded-DSI，2026-10-28）

> 触发：`继续任务` → 当前真开放项之一 = `U2 原子回调时序（需 drm.debug=0x4 时间线）`。
> 性质：**零写盘上机取证**（`ftrace` + `org.gnome.ScreenSaver.SetActive`，未刷写/未重启/未装包）。
> 判据可复跑：`scripts/b5-u2-atomic-timeline.sh`（采 + 判，rc=0 才 PASS）。
> 原始证据：`reports/artifacts/b5-u2-20261028-104918/`（`u2-trace.txt` 7.6 KB / `u2-dmesg-dsi.txt` / `capture.log`）。

## §0 结论（一行 + 数字）

**U2 关闭：树里「非原子回调 → 原子回调」的映射是**对的**，且现在有现场时间线作判据，不需要改代码。**
判据 **8 项全 PASS**，`enable n=2 / disable n=2` 两次循环**逐项同序**，全部错误计数 0→0，
`panel_prepare → host_enable` 间隔 **219.4 / 222.6 / 224.2 ms**（= 面板 DCS 初始化耗时，正是必须把 `host_enable`
从 `pre_enable` 挪到 `enable` 的原因）。

## §1 实测时间线（一轮 blank + 一轮 wake，`ftrace` function tracer，同一次采集的两轮逐项一致）

```
# ---- blank（disable 方向）-----------------------------------------------
4875.299  drm_atomic_helper_commit_modeset_disables
4875.299  drm_atomic_bridge_chain_disable          ← 反向遍历：面板侧先
4875.299  drm_panel_disable                        ← 面板先关
4875.301  dsi_mgr_bridge_disable                   ← 我们：.atomic_disable
4875.301  msm_dsi_host_disable  ×2                 ← master + slave（bonded）
4875.307  drm_atomic_bridge_chain_post_disable
4875.307  drm_panel_unprepare                      ← 面板 sleep-in 之后才允许断电
4875.307  dsi_mgr_bridge_post_disable              ← 我们：.atomic_post_disable
4875.307  msm_dsi_host_power_off ×2
4875.307  dsi_mgr_phy_disable
# ---- wake（enable 方向）-------------------------------------------------
4877.334  dsi_mgr_bridge_mode_set → msm_dsi_host_set_display_mode ×2
4877.337  drm_atomic_bridge_chain_pre_enable
4877.337  dsi_mgr_bridge_pre_enable                ← 我们：.atomic_pre_enable（只 power_on）
4877.340  msm_dsi_host_power_on ×2
4877.341  drm_panel_prepare                        ← 面板 DCS 初始化（≈227 ms，阻塞到 4877.568）
4877.568  drm_atomic_bridge_chain_enable           ← 同一次提交、同一个 helper，pre_enable 全部返回后
4877.568  dsi_mgr_bridge_enable                    ← 我们：.atomic_enable（host link enable）
4877.568  msm_dsi_host_enable ×2                   ← master + slave
4877.568  drm_panel_enable                         ← 先 video、后 display-on
```

dmesg 侧逐字佐证（同目录 `u2-dmesg-dsi.txt`）：

```
4877.340 msm_dsi ae94000.dsi: timing 1904x3040@165Hz ... (bonded=1 dsc=1 wide=1)
4877.341 msm_dsi ae96000.dsi: timing ...                (bonded=1 dsc=1 wide=1)
4877.567 novatek-nvt36xxx-spi spi0.0: panel prepared: scheduling firmware upload
```

## §2 为什么这个映射是**唯一**可行形状（上游要的论证）

1. `drm_atomic_helper_commit_modeset_enables()` 在**同一次提交**里先 `drm_atomic_bridge_chain_pre_enable()`
   全套走完，再 `drm_atomic_bridge_chain_enable()`（`drm_bridge.c`；实测两段之间隔 219–224 ms，
   全在 `drm_panel_prepare` 里）⇒ **「面板就绪」是 enable 方向的硬闸门**：
   - `.atomic_pre_enable` 只能做 power_on（Host power-on 已提供 LP11 与可命令链路）；
   - `.atomic_enable` 才是 host link enable，且此处 `panel->prepared` **必然为真**
     （树里 `if (!panel->prepared) { … refusing video enable }` 因此只在异常路径触发，实测 0 次）。
   - 若反过来把 host_enable 留在 `pre_enable`（字段版/厂商 7.2 形状），就会在面板 DCS init 之前
     把 video 打开 ⇒ 这正是 7.2 侧需要「熄屏重算 timing」的根因面，也是 B5 第 4 步判别臂
     `master=DSI1` 时首条 DCS `ff 20` 三连 `-22` 的同族失败。
2. disable 方向 `drm_atomic_bridge_chain_disable()` **反向遍历**（面板侧先）⇒ `panel_disable` 先；
   `post_disable` **正向遍历** ⇒ `panel_unprepare` 在 `dsi_mgr_bridge_post_disable` 之前。
   因此 `host_disable` 放在 `.atomic_disable`（而不是 post_disable）是**必须**的：
   它夹在 `panel_disable` 与 `panel_unprepare` 之间，关屏命令（sleep-in）仍可下发，实测序满足。
3. bonded 侧：桥回调 **1 次**（slave 桥早退，`IS_MASTER_DSI_LINK` 门控），host/power 调用 **2 次**
   （master + slave 各一），phy_disable **1 次**（单 PHY refcount 由两条 link 共用）——
   与 `patches/local/b5-resoc-20261027/0004-*` 的字段化（`master_link_id` 从 per-SoC 表来）语义一致。

## §3 判据与复跑

```sh
scripts/b5-u2-atomic-timeline.sh              # 采 2 轮 + 判，rc=0=PASS；artifacts 自动归档
scripts/b5-u2-atomic-timeline.sh --no-capture # 只判最新一包
```

| 断言 | 内容 | 结果 |
|---|---|---|
| A1 | enable 序 `pre_enable < panel_prepare < bridge_enable` | ✅ ×2 |
| A2 | `host_enable` 在 `panel_prepare` 之后 | ✅ ×2 |
| A3 | `panel_enable` 在 `host_enable` 之后（先 video 后 display-on） | ✅ ×2 |
| A4 | `panel_disable < host_disable < panel_unprepare` | ✅ ×2 |
| A5 | `host_power_off` 在 `host_disable` 之后 | ✅ ×2 |
| A6 | bonded 计数：host_* ×2、桥回调 ×1 | ✅ ×2 方向 |
| A7 | `command DMA timeout` / `vblank timeout` / `reset failure` / `panel is not prepared` 前后不变 | ✅ 0→0 |

**负向测试**（纪律，`PITFALLS #454/#455` 同族）：把 `drm_panel_prepare` 在 trace 里挪到
`dsi_mgr_bridge_enable` 之后 ⇒ **A1 精确 FAIL、rc=1**（脚本自测过，不是「看着对」）。

## §4 顺带的两个方法学事实（已进 `PITFALLS #456`）

- `/sys/class/drm/card0-DSI-1/dpms` 在本机是 **0444 只读**，`modetest -w 36:DPMS:3` 也是空操作；
  真实熄屏路径 = 会话总线上的 `org.gnome.ScreenSaver.SetActive`（以会话用户 + `/run/user/<uid>/bus` 调用，
  root 直连会被 session bus 的 EXTERNAL 认证拒掉）。
- **ftrace 分组不能按时间间隔切**：`panel_prepare` 本身 ~227 ms，按 50 ms 切会把同一次提交的
  `pre_enable` 与 `enable` 拆成两组（首版检查器因此误报 `enable n=0`）。正确锚点 = 桥链入口函数
  （`drm_atomic_bridge_chain_{disable,pre_enable}`）。

## §5 对上游化（M6 B5-P4 / 设计稿 §1 第 9 项）的含义

- **不需要额外补丁**：`atomic_pre_enable/atomic_enable/atomic_disable/atomic_post_disable` 的现状形状即推荐形状，
  U2 从「待上机」转「已证」；
- 投递前仍待做的两件（与 U2 无关，见 `TASKS` §7 M6）：① bonded 表从 `sm8650_dsi_cfg` 拆独立 SM8750 表项；
  ② 把「调用者必须是 master」做成**显式检查**（现在只表现为 `-22`）。
