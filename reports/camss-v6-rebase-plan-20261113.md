# camss 路线改接 Qualcomm v6（2026-11-13）

> 触发：`reports/upstream-watch-20261113.md` §D #4——放弃自建 9 补丁串，接 Qualcomm v6，
> SOF 改走 `V4L2_EVENT_FRAME_SYNC`，撤掉「必须物理连续」限制。
> 本轮性质：**静态对账 + 一条代码回退 + 上机回归**；不做大规模 rebase（v6 未合入，基线树也还没到 7.4）。

## §0 结论（先数字）

- v6 = **7 补丁**（Hangxiang Ma @ Qualcomm，2026-07-21，series 1131656），已落盘
  `patches/upstream/qcom-camss-sm8750-v6-20260721/`（7 个 `.diff` + 来源表）。
- 我们自建系列 = **9 补丁**（`patches/upstream/m4-camss-series-20261028-v2/`）。逐项对账后：
  **5 项被 v6 直接覆盖（弃用）**、**2 项被 reviewer 否（废弃）**、**1 项已独立投递（保留）**、
  **1 项板级 DTS 等 v6 合入后 rebase**。
- **硬分歧只有 1 处**：CSIPHY 版本。v6 认为 SM8750 复用 kaanapali（v2.3.0）资源；我们的证据
  （vendor `camera.ko` 的 `csiphy_2ph_v2_4_0_reg`，103 条，地址/掩码 103/103 对齐）指向 **2.4.0**。
- 已落地：**撤掉「必须物理连续」**（`camss-video.c` −14 行），模块热换后前摄
  gc08a8→csiphy4→csid0→vfe0_rdi0 **出流 5 帧 rc=0**（回归通过）。

## §1 v6 逐项 vs 我们的 9 补丁

| v6 | 内容 | 我们对应 | 处置 |
|---|---|---|---|
| 1/7 | `phy/qcom,x1e80100-csi2-phy.yaml` 加 SM8750 | 无（我们不碰 phy binding） | **接 v6** |
| 2/7 | `media/qcom,sm8750-camss.yaml` | `0001`（自建 435 行 binding） | **弃用 0001**（v6 是正统） |
| 3/7 | camss SM8750 资源（`CAMSS_8750` + icc） | `0008` 的资源表 | **弃用**（v6 覆盖） |
| 4/7 | csiphy v2.3.0：「复用 `csiphy_res_kaanapali`」，**不新增 lane 表** | `0002` 新增 `lane_regs_sm8750`（2.4.0，103 条） | **硬分歧**，见 §2 |
| 5/7 | CSID 980 | `0004`（csid-980 full/lite + RUP/AUP 字段） | **弃用 0004** |
| 6/7 | VFE 980 | `0008`（vfe-gen4 + SM8750 相机资源） | **弃用 0008** |
| 7/7 | TPG v2.3.0 | 无 | **接 v6** |

我们系列里 v6 没有的部分：

| 我们 | 内容 | 处置 |
|---|---|---|
| `0003` | `csid_set_power()` 错误路径 unwind（顺带真 bug：pm_runtime 失败漏放 parent） | **已独立投递**（`patches/upstream/m4-camss-fixes-20261029/` 3 枚之一），不随本系列 |
| `0005` | SOF 由 CSID 上报 | **废弃**：Bryan 明确「SOF 与 buf-done 不必同一中断、进/出 idle 会破这套」，正解是他要发的 `V4L2_EVENT_FRAME_SYNC`（截至 11-13 未见投递）|
| `0006` | 只接受**物理连续** buffer | **废弃 + 本轮已从树上撤掉**（§3）：Bryan 称「gigantic step backwards」，要求出处或撤 |
| `0007` | 起流失败时停掉已启动的 subdevices | **保留候选**：v6 不碰 `camss-video.c`，属独立通用修复，可单独投 |
| `0009` | `arm64: dts: qcom: sm8750: add the camera subsystem` | **等 v6 合入后基于其 binding rebase**；现留在功能树里作可用件 |

## §2 硬分歧：CSIPHY 2.3.0 vs 2.4.0

- v6 4/7 的全部改动是 `sm8750_resources.csiphy_res = csiphy_res_kaanapali` +
  `csiphy_num = ARRAY_SIZE(csiphy_res_kaanapali)`——即**不新增任何 lane 表**。
- 我们的证据链（`reports/m4-csiphy-vendor-provenance-20261027.md`）：
  原厂 `camera.ko` 未 strip，数据段取到 `csiphy_2ph_v2_4_0_reg`（103 条）与
  `csiphy_3ph_v2_4_0_reg`（72 条）；我们的表与 vendor 2ph 表地址/掩码 **103/103 一致**，
  仅 4 条 SKEW_CAL `0x5c` 值不同（我们 0x54，vendor 0x00，且 0x54 在 vendor 82 张表中 0 命中）。
- **本机无法直接判定谁对**：需要一棵含 kaanapali CSIPHY 表的 7.4-rc2+ 树，把它的
  `csiphy_res_kaanapali` 与本机 vendor 2.4.0 表逐条比。目前 `build/` 里没有 7.4 树
  （v6 依赖的 `qcom,x1e80100-csi2-phy.yaml` 在 7.3-rc7 与 linux-next 快照里都不存在）。
- 处置：**先接 v6（2.3.0）并上机验证**；只有实测不出流/出坏帧时，才把 2.4.0 差集作为
  v7 delta 提出（附带本节证据）。**不先发信提问**——无 kaanapali 表在手时提问只能给结论不能给差集，
  正是 11-13 issue #12 里被指的那种「没有证据的猜」。

## §3 已落地：撤掉「必须物理连续」

- 代码：`build/camss-v6`（`build/daily` HEAD 的 worktree）删掉 `video_buf_init()` 里逐 plane
  扫 sg 表并要求 `contiguous >= sizeimage` 的循环，改为只取 `sg_dma_address(sgt->sgl)`（上游原状）。
- 补丁：`patches/upstream/camss-drop-contiguous-20261113/0001-…patch`（−14/+1）。
- 上机回归（2026-11-13，U2，vk189 线，模块热换）：
  `qcom-camss` 重编 → `rmmod`/`modprobe` → 17 个 video 节点回来 →
  `camera-stream-up.sh front stream 5` = **rc=0，5 帧**。
- **口径限定**：这证明「撤掉检查后正常路径不回归」；**没有**构造非连续 sg 场景去证明
  「非连续也能跑」（IOMMU 下 sg 通常连续，不易构造）。所以对 Bryan 的回复口径是
  「撤掉该约束」而不是「证明非连续可用」。

## §4 SOF：不自造，等 FRAME_SYNC

- 我们的 `0005` 废弃；`FRAME_SYNC` 事件（`V4L2_EVENT_FRAME_SYNC`）系列由 Bryan 承诺，截至 11-13 未投。
- 现役树保留现有 SOF/`frame_started` 逻辑（功能可用），**不向上游再提**；等 Bryan 系列出现后按它的形状改。

## §5 下一步（按依赖）

1. 拿一棵 **7.4-rc2+** 树（或等 v6 进 linux-next），把 `csiphy_res_kaanapali` 与本机 vendor 2.4.0 表逐条对
   （脚本：从 `camss.c` 抽表，比对 `lane_regs` 三元组）。结论决定是否需要 2.4.0 delta。
2. v6 合入后：`0009`（板级 dts）按 v6 binding rebase；我们的树把自建 camss 换成 v6 + 板级 dts。
3. `0007`（起流失败回退）作为独立补丁评估是否值得单独投。
4. 不再维护 `m4-camss-series-20261028-v2` 的后续版本（状态已改 superseded）。

## §6 证据

- v6 原件：`patches/upstream/qcom-camss-sm8750-v6-20260721/`（7 个 `.diff`；来源/msgid 见该目录 `README.md`）
- 我们的系列：`patches/upstream/m4-camss-series-20261028-v2/`（README 已加 superseded 状态行）
- 撤约束补丁：`patches/upstream/camss-drop-contiguous-20261113/`
- CSIPHY 证据：`reports/m4-csiphy-vendor-provenance-20261027.md` §2
- reviewer 意见：patchwork `14920894`（物理连续）、`14920895`（SOF）、`14920896`（v6 怎么了）
