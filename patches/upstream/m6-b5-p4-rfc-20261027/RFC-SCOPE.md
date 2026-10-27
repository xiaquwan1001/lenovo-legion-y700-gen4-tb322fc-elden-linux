# M6 B5-P4 → RFC 备料（只写不发，2026-10-27）

> 目标：把 `patches/upstream/m6-b5-p4-20261026/`（45 hunk、含 Q28 实验钩子、checkpatch 有 style 问题）
> 收敛成一封**上游能接的 RFC**。本文件只定「说什么 / 不说什么 / 先等什么」，不含补丁正文。
> 领域规则：`reports/upstream-policy-20261013.md`；分片依据：`reports/b5-dsi-resoc-20261013.md`。

## 1. 主张（一句话）

**dual-DSI bonded 面板在 command 模式下，上游没有「一条命令同时打到两条链路」的路径**：
`is_bonded_dsi` 只覆盖时钟/PHY（`dsi_manager.c`），`REG_DSI_CMD_DMA_CTRL` 的 `BROADCAST_EN` 位
**在寄存器描述里已存在、驱动从未置位** ⇒ 两条链路各自 arm 自己的命令 DMA，两者的完成时序无协议约束。

本机（SM8750 / 1904×3040 / bonded CPHY + DSC）在上游栈上的可观测后果：首条 DCS 命令（`ff 20`）的
命令 DMA 引擎 hang（`STATUS0=0x20003`、`TRIG_DMA=0x1` 自不清），面板只出背光无画面；把两条链路按
「slave 先 stage、master 最后 arm、只有 master 拥有完成 IRQ」排序后现场消失。

## 2. 已核实的事实（写 RFC 时可直接引，逐条可复现）

| # | 事实 | 复现 |
|---|---|---|
| F1 | 上游**有** bonded 支持，但只在时钟/PHY 层：`qcom,dual-dsi-mode` → `msm_dsim_glb.is_bonded_dsi`，PLL0 同驱双链路 | `git show 24a19b953:drivers/gpu/drm/msm/dsi/dsi_manager.c \| grep -n bonded` |
| F2 | 寄存器描述**已有** `CMD_DMA_CTRL.BROADCAST_EN`（bit31）、`FROM_FRAME_BUFFER`(28)、`LOW_POWER`(26) | `.../registers/display/dsi.xml` §`CMD_DMA_CTRL` |
| F3 | 驱动只写 `FROM_FRAME_BUFFER\|LOW_POWER`，**从不置 `BROADCAST_EN`** | `dsi_host.c:878`、`dsi_host.c:1190-1197` |
| F4 | 草案用的两个魔数 `0x001f0200` / `0x44440400` **不能**由 `dsi.xml` 解释 ⇒ 涉及 bit30/29（master/slave 或广播主从语义），**上游 xml 未描述** | 本文 §4 风险 R1 |
| F5 | 草案 `checkpatch --strict` 有 style 问题（draft 未清理）；45 hunk 里约 1/3 是 Q28 取证钩子 | `perl scripts/checkpatch.pl --strict --no-tree <patch>` |

## 3. RFC 应有的形状（建议拆成 3 个独立提交，按可接受性排序）

1. **`drm/msm/dsi: enable broadcast command transfers for bonded DSI`**（核心，可能 2 个 hunk 级改动）：
   set/clear `BROADCAST_EN` 于 `msm_dsi_host_cmd_xfer_config()`，并把「slave 先、master 最后」的触发顺序
   写进 `msm_dsi_manager_cmd_xfer_trigger()`；补 `link_configured` / `link_clk_set_rate` 的最小状态机
   （拒绝陈旧配置属于通用健壮性，**可独立成补丁**）。
2. **`drm/msm/dsi: program bonded panel enable after panel PPS`**（H39/H40/H42 的 video 使能时机重构）：
   这条本质是**顺序 bug**（`pre_enable` 里先开 host 再做 panel PPS），与 bonded 无关也能单独论证，
   是最容易先落地的一块。
3. **错误传播**（`cmd_xfer_trigger()` 返回 `bool`→`int` + `dsi_err_worker` 早退）：机械、低风险。

**明确不放进 RFC**（会毁掉它）：Q28 的 IRQ 屏蔽/闩锁清零、看门狗旋钮、`PINUTS`、任何 `is_sm8750` 特判
（应换成 cfg flag 或 `msm_dsim_glb` 字段）、以及草案里 `/* vendor: ... */` 式注释。

## 4. 接受风险（要先解决再去发）

- **R1（阻断级）**：bit30/29 语义无上游寄存器描述 ⇒ 要么拿到能公开引用的寄存器说明，要么把该位用法
  改成「由 `BROADCAST_EN` + 现有 API 推导」的最小集。没有这一步，RFC 会被一句「undocumented magic」打回。
- **R2**：`is_sm8750` 全局变量（草案 H34/H35）会被要求改成 per-controller cfg flag。
- **R3**：`msm_gem_sync_for_cpu/for_device()` 前置支撑 diff 应独立提交（否则 RFC 混入 GEM 改动）。
- **R4**：结论只在本机验证过（n=1 面板型号）；RFC 里必须写清「同一现象的其它面板未知」。

## 5. 投递面（发送时用，不在此发）

- To: `Dmitry Baryshkov <dmitry.baryshkov@linaro.org>`、`Abhinav Kumar <quic_abhinavk@quicinc.com>`；
  Cc: `Rob Clark`、`Sean Paul`、`Marijn Suijten`、`Jessica Zhang`、`dri-devel@lists.freedesktop.org`、
  `linux-arm-msm@vger.kernel.org`、`devicetree@vger.kernel.org`（若带 DT 属性）、`linux-kernel@vger.kernel.org`
  ——**发送前用 `get_maintainer.pl` 复核一遍**（人员会变）。
- 前置：先回看 M6 已投的 L1（`<20261019130041.305805-1@…>`）与 L3 的「上游四问」是否已有答复，
  RFC 要在已有线程上加引用，避免重复开题。
- 投递闸门（与 M4 同口径）：`checkpatch --strict` 0/0、`git am` 到 pristine `24a19b953` 干净、
  `make drivers/gpu/drm/msm/` 编译过、`--dry-run` 核对 To/Cc/Subject/Message-ID。
