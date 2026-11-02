# M6 B5 系列 v2（2026-11-02）—— 在公开 base `6628e7d4c6` 上重切

> 状态：**已重切 + 四条门禁全绿；未发送**（投递按 `TASKS/README.md` §7 逐次批准）。

## §0 要点（三条，先看这个）

1. **base**：`6628e7d4c6b25c8d18f1345e3a20d21829aae7e4` = `Linux 7.4-rc1`（torvalds 公开树，
   `git describe` = `v7.3-20051-g6628e7d4c6`），本地已在 `build/b5-v2`（分支 `b5/v2-20261102`）。
2. **v1 不可能"cherry-pick 到公开 base"**：v1 重构的那条 bonded 命令路径**在公开树里根本不存在**
   （`dsi_host.c` 在 base 上 `grep -c BROADCAST` = 0，无 `msm_dsi_host_bonded_*`、无
   `is_sm8750`、无 `dsi_bonded_cmd_failed`）。v1 的重构对象是本地 payload（`0f1fb1c9c1` =
   v7.3-rc7 + 一个 squashed 载荷提交）。因此 v2 只能是**把这半条路径本身**作为增量带上公开 base
   —— 这也正是 2026-11-02 回信里承诺的口径（"this series is the data half of proposing that path"）。
3. **净 diff**（`6628e7d4c6..HEAD`，仅 `drivers/gpu/drm/msm/`）：**6 文件 +653 −6**，
   4 枚补丁，全部落盘见 §2。

## §1 与上游的差集（`差集原则`落实）

base 已含 `80dd5911cb`(SM8750 DSI support) 与 `2482c6f93a`(Kaanapali) 的**结果**，
所以按"上游已实现的一律不进 v2"逐项核对（对照 base 树内容，不靠 commit 对象——本地是
partial clone，那两个 sha 不在本地对象里，`git show` 取不到，改用 base 树实测）：

| 项 | 上游 base 现状（实测） | v2 处理 |
|---|---|---|
| per-SoC cfg + host ops 分层 | `dsi_cfg.c:287` 已有 `msm_dsi_6g_v2_9_host_ops`，`dsi_cfg_handlers[]` 按 (major,minor) 选表 | **不重写**，只加 `.bonded` 数据字段与一个 ops 钩子 |
| SM8750 的 cfg 条目 | **没有** `sm8750_dsi_cfg`；SM8750 报 6G v2.9，走 `sm8650_dsi_cfg`（`git grep sm8750 drivers/gpu/drm/msm/dsi/` 无命中） | v1 把数据挂 sm8650 上（Dmitry ③）；v2 新增 `sm8750_dsi_cfg`，按 **compatible** 选表 |
| 广播寄存器描述 | `dsi.xml` 有 `BROADCAST_EN`（:190），但 `dsi_host.c` 中 `BROADCAST` 命中 **0**；且 v7.4-rc1 把 `BROADCAST_MASTER/WC_SEL/PACKET_TYPE`、`DMA_FIFO_CTRL`、`DMA_TRG_MUX/DMA_TRIGGER_EXT`、`DMA_SCHEDULE_CTRL{,2}`、`VBIF_CTRL`、`CMD_DMA_CTRL1` 从 `dsi.xml` **删掉了**（vk151 的 `dsi.xml` 有、base 没有，`diff` 可复现） | 只补回本路径真正用到的 10 处定义（21 行：CMD_DMA_CTRL 3 位 + DMA_FIFO_CTRL 1 + TRIG_CTRL 2 + SCHEDULE 2 + VBIF + CMD_DMA_CTRL1），随 1/4 一起进 |
| v1 1/5「把 flag 移进 `msm_dsim_glb`」 | 公开树没有 `dsi_bonded_cmd_failed` 可移 | **没有对应独立补丁**；flag 与 mutex 一进就在 `msm_dsim_glb`（Dmitry ②） |
| v1 3/5「bonded 路径走 host ops」 | 公开树没有可被搬的 helper | 由 2/4 **新写**为 host op（同一设计，落点变小：只 1 个 op + 1 个 capability 查询） |
| v1 4/5「master 从 per-SoC cfg 取」 | 公开树 master 由 DT `qcom,master-dsi` 决定（`dsi_mgr_parse_of()`） | **反向改**：删掉 cfg 里的 `master_link_id`，DT 独裁（Dmitry ④，见 3/4、4/4） |
| v1 5/5「命名 FIFO 错误位」 | — | 折进 1/4（新表里不该出现魔数） |

## §2 序列（4 枚）与逐枚校验

| # | Subject | 文件 | checkpatch |
|---|---|---|---|
| 0001 | drm/msm/dsi: add per-SoC bonded command-path config | dsi_cfg.c/h、dsi_host.c、registers/display/dsi.xml | 0E/0W/0C |
| 0002 | drm/msm/dsi: add the bonded command broadcast host ops | dsi.h、dsi_cfg.c/h、dsi_host.c | 0E/0W/**1C**(`udelay`) |
| 0003 | drm/msm/dsi: route bonded commands through the DSI manager | dsi.h、dsi_host.c、dsi_manager.c | 0E/0W/0C |
| 0004 | drm/msm/dsi: reject bonded commands issued on the peer link | dsi_manager.c | 0E/0W/0C |

树内提交（`b5/v2-20261102`）：

```
57494c1d20 drm/msm/dsi: reject bonded commands issued on the peer link
f38983e7b4 drm/msm/dsi: route bonded commands through the DSI manager
be4425b7c9 drm/msm/dsi: add the bonded command broadcast host ops
76ec90f0fd drm/msm/dsi: add per-SoC bonded command-path config
6628e7d4c6 Linux 7.4-rc1
```

逐枚行数：0001 +121/−3、0002 +409/−3、0003 +110/−0、0004 +15/−2。

## §3 与 v1（`patches/local/b5-resoc-20261027`，5 枚）的差异

| v1 | v2 | 说明 |
|---|---|---|
| 0001 move bonded failure flag into manager state | **无** | 公开 base 没有该 flag；v2 在 3/4 里**直接**在 `msm_dsim_glb` 定义（Dmitry ②：与 flag 一起进 glb）。block comment 用规范 `/* ... */` 独立行 |
| 0002 per-SoC bonded cfg（挂 sm8650 + compatible 门控） | 0001 | 改成 **独立 `sm8750_dsi_cfg` 条目 + handler 表新增 `compatible` 字段（compatible 优先于 revision）**；正文只写"仅 SM8750 有该数据，其他 SoC `bonded == NULL`"，不再声称"per platform 一定不同"（Dmitry ③） |
| 0003 route bonded path through host ops | 0002 + 0003 | 落点按公开 base 重写：host 侧只暴露 `bonded_cmd_xfer` 一个 op（v1 是 `bonded_cmd_xfer` + `bonded_wait_video` 两个），manager 侧改为能力查询 `msm_dsi_host_get_cfg_ops()`，不再有 `is_sm8750` 判别 |
| 0004 take bonded master cfg from per-SoC config | **删除**（3/4、4/4 反向） | 全文删除 probe order 表述；master = DT `qcom,master-dsi`（`dsi_mgr_parse_of()`），cfg 里不再有 `master_link_id`（Dmitry ④）。4/4 把"非 master 链路发命令"从静默走错路改成带两条链路号的 `dev_err` |
| 0005 name FIFO error bits | 折进 0001 | 新表直接用 `DSI_ERR_INT_MASK0_FIFO_ERRORS` / `DSI_FIFO_STATUS_FIFO_ERRORS`，宏注释写出处（bit20 随组无名、分组来自 vendor `mask_error_intr()`） |
| 5 枚 + cover，净 +249/−99 | 4 枚 + cover，净 +653/−6 | 增量变大的原因即 §0.2：v1 只搬本地载荷的"形状"，v2 必须自带这条路径的可编译实现 |

**刻意排除在 v2 之外的本地载荷**（不属 B5 范围，避免把 feature 混成 mega-series）：
SM8750 时钟/复位特化（`dsi_link_clk_set_rate_6g_v2_9` 的 parent/OPP 处理、`dsi_sw_reset_v2_9`）、
C-PHY `CLKOUT_TIMING_CTRL`、DSC 1.2 RC 参数、bridge `enable/disable` 重排与 `panel->prepared` 门控。
它们在 2/4 里以"不引入"的方式体现：`dsi_bonded_xfer_prepare()` 直接用 `cfg_hnd->ops->link_clk_set_rate/
link_clk_enable`（公开 base 已有 v2.9 实现）。

## §4 门禁（原文见 `GATES.md` + `logs/`）

| 门禁 | 结果 |
|---|---|
| 逐枚 `checkpatch.pl --strict --no-tree`（stdin） | **0 error**，3 枚全 0W/0C，0002 有 1 个 `udelay` CHECK（保留理由见 GATES §1） |
| `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 O=/tmp/b5v2-out drivers/gpu/drm/msm/` | **rc=0，0 warning / 0 error**；`W=1` 复跑同样 rc=0/0 warning |
| `git am` 逐枚（干净 base `6628e7d4c6`） | **4/4 全绿**，`am_rc=0`，重放树与分支树 `diff` 为空 |
| 覆盖检查（Dmitry 四条） | ① cover 给可验证动机（`BROADCAST` 命中 0、`ff 20` `-22`、`STATUS0=0x20003`）；② flag+mutex 同进 `msm_dsim_glb`、comment 规范；③ 按 compatible 选表且只声明 SM8750；④ DT 决策、全文无 probe order |

## §5 复现命令

```sh
cd build/b5-v2
git log --oneline 6628e7d4c6..HEAD
for f in patches/upstream/m6-b5-v2-20261102/000[1-4]-*.patch; do
    perl scripts/checkpatch.pl --strict --no-tree - < "$f"
done
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 O=/tmp/b5v2-out drivers/gpu/drm/msm/
git checkout -B /tmp-am 6628e7d4c6 && git am patches/upstream/m6-b5-v2-20261102/000[1-4]-*.patch
```

## §6 发送前需要总管裁决的两点

1. **立场变化**：v1 是"纯重构、no functional change"，v2 是"新增一条命令路径"（SoC 无 bonded 数据时
   行为不变）。回信里已按后者措辞，但 review 难度与"为什么现在做"的举证责任都变了。
2. **`dsi.xml` 补回 10 处寄存器描述**：这些正是 v7.4-rc1 删掉的（删的时候本路径下游才有用），
   补回即等于宣告"上游缺失的登记册"。若担心 reviewer 对"重加已删定义"敏感，可退一步只在
   `dsi_host.c` 用本地宏——但那样更像 vendor hack，不建议。
