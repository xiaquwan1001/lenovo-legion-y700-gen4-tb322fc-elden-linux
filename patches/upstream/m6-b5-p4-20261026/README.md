# M6 · B5-P4 — vendor DSI video/bonded 使能增量补丁草案（2026-10-26）

> 状态：**备料草案（DRAFT），冻结不发**。产出依据 `reports/b5-dsi-resoc-20261013.md` §1.2/§2.4 的 P4 切分
> （hunk H01/H02/H12/H19/H20/H23/H26/H34/H37–H42/H45/H46 + 编译必需的支撑 hunks）。
> 基线 = pristine `v7.3-rc7`（`24a19b953e`）；机械门见 §3。

## 0. 文件清单

| 文件 | 内容 |
|---|---|
| `0001-drm-msm-dsi-bonded-broadcast-command-path-for-sm8750.patch` | P4 草案（含 Q28 现场代码 + video 使能时机重构 + 两个**前置支撑 diff**：`msm_gem` cache-sync 助手、`generated/dsi.xml.h` 寄存器增量） |

## 1. 补丁构成（逐 hunk：目的 / 硬件事实 vs 软件策略 / 落点 / 上游可接受性）

分类代号沿用 b5 报告（HW=硬件事实，Q28=Q28 实验钩子，STR=结构，MECH=机械，Q3=Q3 风险）。

### 1.1 dsi.h（H01/H02 全收）

| hunk | 内容 | 类别 | 归属 | 上游可接受性 |
|---|---|---|---|---|
| H01 | `msm_dsi_manager_cmd_xfer_trigger()` 返回 `bool`→`int`；新增 `msm_dsi_manager_cmd_failed()` 原型 | Q28 | bonded 协议 ABI（P4 门控内） | 随 bonded 路径走 RFC/下游；单独不可接受 |
| H02 | 11 个 `msm_dsi_host_bonded_*` / `cmd_xfer_config` 原型 | Q28/STR | 同上，整组 off-by-default | 同上 |

### 1.2 dsi_host.c（32 hunk 中收 20，其余归 P1/P2 或剔除）

| 原编号 | 内容 | 类别 | 归属 | 上游可接受性 |
|---|---|---|---|---|
| H03 | `#include "msm_mmu.h"`、`<drm/drm_modes.h>` | MECH | 支撑（iova/mode 用） | 机械，可接受 |
| H04 | `msm_dsi_host` 增 `byte/pixel_src_parent`、`link_*_rate`、`link_configured` | STR | link 状态机，被 bonded ESTALE 逻辑依赖（§b5 3.3-4：语义待证，随 P4 带注释） | 需 RFC 说明 |
| H05/H15/H16 | `tx_buf_iova` 缓存 | MECH | 支撑 bonded DMA 同步 | 可接受（性能类） |
| H06 | `cmd_dma_ctrl_restore`、`bonded_polling`、`dma_submit_seq/done_seq` | Q28 | bonded IRQ 状态机字段 | 随 P4 |
| H08/H30/H32 | `link_configured=false`（suspend/power_off/set_mode） | MECH | 同 H04 | 同 H04 |
| H12 | `dsi_intr_ctrl`：bonded_polling 屏蔽 `CMD_DMA_DONE`；新增 `dsi_cmd_dma_intr_update()`（W1C）、`dsi_intr_masks_restore()` | Q28 | bonded IRQ 协议 | 随 P4 |
| H17/H18 | `triggered bool→int` + 错误传播 | MECH/Q28 | 通用健壮性 | **可独立接受**（好候选） |
| H19 | `dsi_err_worker`：`msm_dsi_manager_cmd_failed()` 即 return | Q28 | 坏发即放弃策略（b5 §3.3-6） | 上游会要求可恢复路径 |
| H20 | `dsi_host_irq`：raw/ack、bonded_polling 不误清 DONE、submit/done 记账 | Q28 | 同 H12 | 随 P4 |
| H23（+324 行） | bonded 命令实现整组：`bonded_wait_video`、`dsi_cmd_error_prepare/cleanup`（魔数 `0x001f0200`/`0x44440400`）、`dsi_cmd_link_clk_set_rate`、`bonded_xfer_prepare/restore`、`bonded_cmd_build/init_trigger`（调度行算式 `vtotal-(vsync_start-vdisplay)+1`）、`stage/trigger/arm/wait`（200 ms）、`poll_slave`（500×10 µs） | **Q28 核心+Q3** | **不得当硬件事实**；根因未定，只能 RFC/quirk + 注释（本草案 commit 正文已声明） | **最大争议点**：魔数溯源、超时常量、"放弃"语义 |
| H24 | `pm_runtime_resume_and_get`（失败即返回）+ `link_clk_set_rate` 走 `dsi_cmd_link_clk_set_rate()`（-ESTALE 拒绝陈旧配置） | MECH+Q28 | 前半通用可接受；后半随 H23 | 前半可独立 |
| H25 | `err_runtime_put` 标签 | MECH | 支撑 H24 | 可接受 |
| H26 | `msm_dsi_host_cmd_xfer_config()`：置/清 `CMD_DMA_CTRL` BIT31/BIT30（broadcast/master） | Q28 | bonded broadcast 协议 | 随 P4 |
| H29 | power_on 记录 `link_*_rate`、`link_configured=true` | MECH | 同 H04 | 同 H04 |
| （剔除） | H07/H28（clk compat 分流）、H09/H10（dev 变量）、H11（v2_9 clk rate）、H13（C-PHY clkout=0）、H14（sw_reset_v2_9）、H21/H22（DSC 1.2）、H27（seq 复位+byte_intf_clk_rate，含 compat）、H31（parent restore） | — | 归 **P1/P2/P0**；避免把 cfg 重构混进 P4 行为补丁 | — |

### 1.3 dsi_manager.c（15 hunk 全收 — 本文件即 P4 主体）

| hunk | 内容 | 类别 | 上游可接受性 |
|---|---|---|---|
| H33 | include mutex/of/panel | MECH | 可接受 |
| H34/H35 | `is_sm8750` + `dsi_bonded_cmd_lock/failed` 全局 + `dsi_mgr_uses_bonded_cmd()` | **STR+Q28** | 跨模块全局（C1 同味）——正式版应收进 `msm_dsim_glb`/cfg flag；草案保留原样并已在 commit 正文声明 |
| H37/H38/H41 | 坏发后 bridge power_off/pre_enable/post_disable 直接 return | Q28 | "放弃"语义，同 H19 |
| **H39/H40/H42** | **video 使能时机重构**：sm8750 下 `pre_enable` 不再调 `msm_dsi_host_enable()`，改在新增 `.atomic_enable`（panel PPS 全部完成后）调用；`post_disable` 对应挪到 `.atomic_disable`；`panel->prepared` 校验失败置 `dsi_bonded_cmd_failed` | **Q28/STR（video/bonded 使能增量的本体）** | 生命周期重构 + 首条 DCS 时的链路状态改变 = **最可能移动 Q28 坏发率**（b5 §3.2）；上机验证必须与 P4 绑定，不能拆开混入其它补丁 |
| H43/H44/H36 | `disable_irq:` 标签、`powered` 字段、注册 `.atomic_enable/.atomic_disable` | MECH | 可接受 |
| H45/H46 | bonded 配对/触发序（prepare→build→stage→slave→arm master→wait→poll→restore）+ `cmd_xfer_trigger` 重写（master 最后触发、仅 master 拥有完成 IRQ、返回 `int`） | **Q28 核心** | 坏发发生地；**一行不改语义**，上游仅可作 RFC |
| H47 | 空行噪声 | — | 已剔除 |

### 1.4 前置支撑 diff（两个，均与 bonded DMA 路径耦合）

| 内容 | 归属 | 说明 |
|---|---|---|
| `msm_gem.{c,h}` `msm_gem_sync_for_cpu/for_device()`（+33 行） | 支撑（H23 的 tx buf cache 维护） | 独立性好，正式版可拆为前置补丁 |
| `generated/dsi.xml.h` 寄存器增量（CMD_DMA_CTRL1、DMA_SCHEDULE_CTRL、VBIF、TRIG_MUX 等 82 行） | **XML 数据（硬件事实，方向正确）** | 该文件 gitignored（构建期生成）⇒ 草案里以 diff 形式携带；正式版应连同 XML 源一起提交（参照 `a6xx.xml.h` 惯例） |

## 2. 硬件事实 vs 软件策略判定（Q3 三问）

- **硬件事实（可留）**：`CMD_DMA_CTRL1`/`DMA_SCHEDULE_CTRL*` 寄存器定义（XML）；broadcast master/slave 分工；C-PHY 无时钟 lane（未在本补丁，属 P2）。
- **软件策略（必须声明）**：坏发即放弃、超时常量、`link_configured` ESTALE 语义、使能时机挪移——全部属 Q28 实验行为，commit 正文已写 DRAFT 声明。
- **Q3 风险（魔数）**：`ERR_INT_MASK0 0x001f0200/0x44440400`、调度行算式 —— 待 stock 对照佐证后才能升格为硬件事实。

## 3. 机械门（原始数字）

| 门 | 命令 | 结果 |
|---|---|---|
| 干净应用 | `git apply`（pristine 7.3-rc7 worktree `/tmp/p4-base`） | **rc=0**（`dsi.xml.h` 为 gitignored 生成文件，单独拷入） |
| 编译 | `make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/gpu/drm/msm/` | **rc=0，0 error / 0 warning**（`/tmp/gates/compile-p4g.log`） |
| 风格 | `checkpatch.pl --strict --no-tree`（7.3 树自带） | **0 errors / 1 warning / 8 checks**（1119 行）。warning = `dsi.xml.h` 生成头 101 列（生成文件惯例，正式版随 XML 源处理）；checks = `udelay`（bonded poll 500×10 µs，Q28 现场语义原样保留）+ 多空行（b5 §1.2 分类噪声） |
| 验证树 | `git rev-parse HEAD` = `24a19b953e`（Linux 7.3-rc7） | ✓ |

## 4. 与 P1–P3 的关系（正式投递时的形态）

P4 依赖 P1（per-SoC select）与 P2（controller cfg）；本草案为可独立 review 而**内联**了最小支撑（gem/xml），正式版应：P0（DSC，可选）→ P1 → P2 → P3 → P4，P4 删去 `of_device_is_compatible` 散落判定（`is_sm8750` 收进 `cfg->bonded_cmd`）。
