# B5 设计稿：bonded-DSI 命令路径收进 **per-SoC cfg + host ops**（U1/U2/U5，2026-10-27）

> 承接：`reports/m1-rebase-7.3rc7-execution-20261013.md` §4 **U1/U2/U5** ·
> `reports/b5-dsi-resoc-20261013.md`（P1 机械样例已投）· `patches/upstream/m6-b5-p4-rfc-20261027/RFC-SCOPE.md`（三条硬事实）。
> 本轮**只出结构方案**（主机侧静态），未改代码、未上机。

## §0 结论（数字）

| 项 | 值 |
|---|---|
| elden bonded 增量规模（`git diff 24a19b953..HEAD`） | `dsi_host.c` **578 行改动** / `dsi_manager.c` **249 行** / `dsi.h` **19 行（含 10 个 `msm_dsi_host_bonded_*` 原型）** / panel `nt36536` **132 行**；四文件合计 **+902 −76** |
| **per-SoC 侧改动** | **0 行** —— `dsi_cfg.c`、`dsi_cfg.h`、`struct msm_dsi_config`、`struct msm_dsi_host_cfg_ops` **逐字节未动** |
| ⇒ 现状性质 | bonded 能力是**全局状态 + 硬编码常量**贴在 `dsi_host.c`/`dsi_manager.c` 上：`msm_dsim_glb.master_dsi_link_id`（**由 panel 绑定顺序在探测期写入**）、文件级 `static bool dsi_bonded_cmd_failed`、`IS_SYNC_NEEDED()` 宏包裹的 4 处分支、以及 `msm_dsi_host_bonded_*` 十个直调函数 |
| 已有上游抓手 | `struct msm_dsi_config`（per-SoC 表）与 `struct msm_dsi_host_cfg_ops`（per-generation 回调）**本来就在**，且 `.calc_clk_rate(msm_host, bool is_bonded_dsi)` 已把 bonded 概念引进 ops ⇒ 我们的增量等于绕过现有框架另开一套 |
| U5 一行 | panel 侧 `to_primary_dsi()`：上游 `ctx->desc->is_dual_dsi ? ctx->dsi[1] : ctx->dsi[0]`，elden **无条件 `ctx->dsi[0]`**（因为 elden 的 master = DSI0）⇒ 与 U1 同源，不能单独修 |

## §1 现状清单（按上游可接受度分类）

> A = 硬件事实/数据，可直接上游；B = 需重构后上游；C = SoC 特判/策略，隔离。

| # | 位置 | 内容 | 类 | 问题 |
|---|---|---|---|---|
| 1 | `dsi_manager.c:33/37/81` | `msm_dsim_glb.master_dsi_link_id`，panel 绑定时写入 | **C→B** | 语义依赖 **probe/bind 顺序**（谁先 attach 谁是 master）；上游不可接受"先到先得"决定主从 |
| 2 | `dsi_manager.c:40/41` | `dsi_bonded_cmd_lock`、`static bool dsi_bonded_cmd_failed` | B | 全局可变状态；应进 `struct msm_dsi_manager` |
| 3 | `dsi_manager.c:44` + 4 处（`:592/:671/:740` 等） | `IS_SYNC_NEEDED()` 宏（`is_sync_needed`） | B | 与 `is_bonded_dsi` 概念重复，两套开关 |
| 4 | `dsi_host.c` `dsi_cmd_error_prepare/cleanup` | 魔数 `0x001f0200`、`0x44440400`（W1C 清 FIFO/错误位） | **C** | RFC-SCOPE R1：`dsi.xml` 只描述 `CMD_DMA_CTRL.BROADCAST_EN`(bit31)，**bit30/29 无上游描述** ⇒ 无文档不得进上游 |
| 5 | `dsi_host.c` `dsi_sw_reset_v2_9()` | SM8750 stock 控制器复位序列（含动态时钟） | B | 属 per-generation 行为，可挂 V2_9_0 的 host op，但需 SoC 事实 |
| 6 | `dsi_host.c` `dsi_cmd_link_clk_set_rate()` | 命令前临时抬 link clk | B | 同上，per-generation |
| 7 | `dsi_host.c` 十个 `msm_dsi_host_bonded_*` | 引擎：prepare/restore/build/init/stage/trigger/arm/wait/poll/wait_video | A→B | 逻辑本身与硬件无关（调度/轮询/错误传播），适合作为 ops 实现 |
| 8 | `dsi_host.c:878/1190` 附近 | `CMD_DMA_CTRL` 的 `BROADCAST_EN`/`MASTER` 置位 | A | 位定义**上游 `dsi.xml` 已有**，是"从不置位"而非"没有定义" |
| 9 | `dsi_manager.c` `.atomic_enable/.atomic_disable` | U2：非原子回调改原子回调后的时序 | **B（需上机）** | 语义映射（prepare→enable→video on）纯静态判不了 |
| 10 | panel `to_primary_dsi()` | 无条件 `ctx->dsi[0]`（U5） | C→B | 主从索引应与 §3 的单一来源一致，panel 不该自己决定 |

## §2 候选结构（三选一）

| 方案 | 形态 | 优点 | 致命问题 |
|---|---|---|---|
| **A** 全部塞 DT | 每个 bonded 参数一条 `qcom,*` 属性 | 板级差异免改驱动 | bit30/29 魔数与复位序列是**控制器**事实不是板级事实；且 `dsi_cfg` 已有 per-SoC 表，DT 化等于两处真源 |
| **B** 全部塞 ops | 只加回调，无数据表 | 改动小 | 十个函数的实参（poll 超时、错误位、clk 抬升量）会以字面量散落在实现里，等于把魔数换个地方 |
| **C（推荐）** 数据进 `msm_dsi_config` + 行为进 `msm_dsi_host_cfg_ops` | 见 §3 | 与上游现有 per-SoC/per-generation 分层一致；DT 只表达**拓扑**（哪两条 link 成对） | 需一次结构性搬移（但可切成行为中性步骤） |

**推荐 C**，理由：`struct msm_dsi_config` 已经是"每 SoC 一张表 + 一个 ops 集"的既有范式，bonded 只是同一范式里缺的另一半；
DT 仅保留 `qcom,dsi-bonded`（或复用 panel 上的 `is_dual_dsi`）这类**拓扑**信息——那本来就是板级事实。

## §3 推荐结构草案（骨架）

```c
/* drivers/gpu/drm/msm/dsi/dsi_cfg.h —— 新增 */
/**
 * struct msm_dsi_bonded_cfg - per-SoC bonded-DSI command path data
 * @master_link_id: link that drives the broadcast (NOT probe order)
 * @cmd_dma_ctrl:   CMD_DMA_CTRL value with BROADCAST_EN/MASTER from dsi.xml
 * @err_clear_bits: FIFO/IRQ status bits cleared before a command (TODO(doc))
 * @err_cleanup_bits: same after command-engine off (TODO(doc))
 * @poll_timeout_us: slave completion is polled, not IRQ-signalled
 */
struct msm_dsi_bonded_cfg {
	u8	master_link_id;
	u32	cmd_dma_ctrl;
	u32	err_clear_bits;
	u32	err_cleanup_bits;
	u32	poll_timeout_us;
	bool	needs_link_clk_bump;	/* dsi_cmd_link_clk_set_rate() */
	bool	needs_sw_reset;		/* dsi_sw_reset_v2_9() */
};

struct msm_dsi_config {
	... /* 现有字段不动 */
	const struct msm_dsi_bonded_cfg *bonded;	/* NULL = 无 bonded 能力 */
};

/* dsi_cfg.h —— host ops 新增（只有 bonded SoC 填） */
struct msm_dsi_host_cfg_ops {
	... /* 现有 9 个回调不动 */
	int  (*bonded_cmd_xfer)(struct mipi_dsi_host *host,
				const struct mipi_dsi_msg *msg);
	void (*bonded_wait_video)(struct mipi_dsi_host *host);
};

/* dsi_manager.c —— 全局态收进 manager */
struct msm_dsi_manager {
	struct msm_dsi *dsi[DSI_MAX];
	bool is_sync_needed;
	bool is_dual_dsi;
	bool bonded_cmd_failed;		/* 原 static dsi_bonded_cmd_failed */
	...
};
```

调用点变化（都是"少一层硬编码"）：

- `dsi_mgr_use_bonded_write()` → `msm_dsim->bonded_cfg && IS_SYNC_NEEDED() && msg→sync`
- `dsi_mgr_bonded_cmd_xfer()` 保留调度骨架，但 master/slave 由 `bonded_cfg->master_link_id` 决定，**不再看谁先 bind**
- `dsi_cmd_error_prepare/cleanup()` 的两个魔数改为读 `bonded_cfg->err_*`（首次落地时值逐字照抄，标 `TODO(doc)`）
- panel `to_primary_dsi()` 改为 `ctx->dsi[ctx->desc->master_link_id]` 或由 core 提供 `mipi_dsi_device.master` 语义

## §4 提交拆分（5 步，前 3 步**行为中性**）

| # | 提交 | 内容 | 行为 | 机械判据 |
|---|---|---|---|---|
| 1 | dsi: manager: move bonded state into struct msm_dsi_manager | 搬 `dsi_bonded_cmd_failed` / `is_sync_needed` 等全局 | 中性 | `grep -c "^static bool dsi_bonded_cmd_failed"` = 0；`dsi_mgr_*` 调用点全改 `msm_dsim->` |
| 2 | drm/msm/dsi: add per-SoC bonded config | 加 `struct msm_dsi_bonded_cfg` + sm8750 表项（值逐字取自现状），host 侧改读表 | 中性 | 编译 0 warning；`grep -c 0x001f0200` 在 `dsi_host.c` = 0（移入 cfg 表） |
| 3 | drm/msm/dsi: route the bonded command path through host ops | 十个直调函数降为两个 ops（xfer/wait_video），内部实现不变 | 中性 | `dsi.h` 跨文件原型 10 → ≤3；`git grep msm_dsi_host_bonded_ dsi_manager.c` 只剩 ops 调用 |
| 4 | drm/msm/dsi: take the bonded master from the SoC config | master 不再由 bind 顺序决定 | **会变**（需上机） | 判据见 §5 |
| 5 | （不投）**隔离层** | `err_clear_bits`/`err_cleanup_bits` 的 `TODO(doc)` 与 `dsi_sw_reset_v2_9()` 细节 | 中性 | 不进上游包；仅在树内 |

**顺序理由**：1–3 是搬移，可用 `grep`/行数做硬判据，不需要设备；4 才动语义（U1 的"先到先得"→"配置指定"），必须上机；
5 是 RFC-SCOPE 指的 R1 阻断项，等 `dsi.xml` 之外的文档或 Qualcomm 侧确认。

## §5 上机判据（合并 U2 + 第 4 步）

1. **时序**（U2）：`atomic_enable` 路径下，`prepare → enable → video on` 三段的时间戳顺序在 `drm.debug=0x4` 日志里单调，
   且不出现"命令 DMA 在 video engine 未 ON 时就被调度"（现状代码里有 `/* Stock schedules only while its video engine state is actually ON */` 的分支）；
2. **命令通路**：亮度设置/熄屏再亮（`dpms Off→On`）各 20 次，`command DMA timeout` 计数 = 0，`DSI_PLL_lockfail` = 0；
3. **主从**：把 `master_link_id` 显式设成与当前 bind 顺序**相反**的值，若显示正常 ⇒ 说明语义确实不再依赖顺序；若花屏/超时 ⇒ 说明 DSI0/DSI1 的广播角色不可自由选（则 cfg 字段改为只读断言）。
4. **回退**：Q28 的坏发口径不变（`reports/q28-workbench-closeout-20261024.md` 的 GOOD 判据 5 条）。

## §6 依赖与未答

- **M6 上游四问**仍无回复（bonded 命令路径落在 `cfg->bonded_cmd` 还是独立框架）⇒ 本设计先按"per-SoC 数据 + ops"落地，不等待。
- **RFC-SCOPE R1（阻断）**：`err_clear_bits=0x001f0200`、`err_cleanup_bits=0x44440400` 涉及 `CMD_DMA_CTRL` bit30/29，`dsi.xml` 无描述
  ⇒ 第 5 步永远隔离，除非拿到文档；这也是 P4-RFC 目前不敢发的主因。
- **U2 只能靠设备**：原子回调语义映射没有静态判据，故第 4 步之后统一上机。
