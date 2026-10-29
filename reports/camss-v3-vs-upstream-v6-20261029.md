# camss v3 候选 × 上游高通 v6 逐枚对照 — 2026-10-29

lane 派工：**纯主机、只读上游、不发信**。写路径仅：本报告、
`reference/upstream-camss-v6/`（新建，下载件）、`TASKS/sessions/2026-10-29-camss-v3与上游v6对照.md`。

## 0. 结论摘要（先数字）

> 施工中 —— 本节在所有取证完成后回填。

## 1. 取证方法与环境

- 主机本地时间起点：2026-10-29 12:24 +0800
- lore 已上 Anubis PoW ⇒ 裸 `curl` 只回挑战页（HTTP 403 / "Making sure you're not a bot!"）；
  用项目自带 `scripts/lore-fetch-raw.py`（复用 `~/.local/bin/lore-query.py` 过挑战）取证。
- 搜索：`https://lore.kernel.org/all/?q=camss+sm8750`（Atom）

（后续小节边做边追加）
### 1.1 定位到 v6（已证实）

`https://lore.kernel.org/all/?q=camss+sm8750`（Atom，2026-10-29 12:25 +0800）直接命中整串，
另在结果中顺带看到 v1/v2/v3/v4/v5 全历史与 **2026-06-18 `[PATCH v2 0/3] Add CCI and CAMSS support for SM8750`（DTS 系列）**。

| 项 | 值（取自 raw 头，非记忆） |
|---|---|
| 系列 | `[PATCH v6 0/7] media: qcom: camss: Add SM8750 support` |
| 作者 | **Hangxiang Ma** `<hangxiang.ma@oss.qualcomm.com>`（Qualcomm OSS） |
| 日期 | Tue, 21 Jul 2026 05:45:59 -0700（各枚 05:46:00…05:46:06，b4 0.14.3 产出） |
| Message-Id 串 | `20260721-add-support-for-camss-on-sm8750-v6-{0..7}-a5f841061d18@oss.qualcomm.com` |
| X-Change-ID | `20251126-add-support-for-camss-on-sm8750-506c4de36d88`（与 v1 同一 Change-Id） |
| 规模 | **7 枚**，`10 files changed, 1008 insertions(+), 10 deletions(-)` |

### 1.2 下载落地（8/8 成功）

命令（可复跑）：

```
scripts/lore-fetch-raw.py all $(for i in $(seq 0 7); do \
  echo "20260721-add-support-for-camss-on-sm8750-v6-$i-a5f841061d18@oss.qualcomm.com"; done) \
  -o reference/upstream-camss-v6
```

- 结果：**8 枚全取到**（cover + 7 patch，共 264 KB raw），RC=0，无 `!!` 报错行。
- 注意：`/all/<msgid>/raw` 返回的 raw 里**同一封信出现两份**（交叉投递到 2 个列表：
  `linux-media@vger.kernel.org` + `linux-phy@lists.infradead.org`），因此每枚 raw 里有
  2 个 `From mboxrd@z` / 2 个 `Subject:` / 2 段 diff。已切出单副本到 `single/`（供 diff/`git am` 用）：

```
reference/upstream-camss-v6/
  0000-cover-v6-0-of-7.patch … 0007-v6-7-of-7.patch   # 原始 raw（双副本，未改）
  single/                                             # 单副本（本报告所有 diffstat/文件清单取自此处）
```

## 2. 上游 v6 逐枚清单（含触及文件 / diffstat）

| v6 # | Subject | 触及文件 | diffstat |
|---|---|---|---|
| 0/7 | `[PATCH v6 0/7] media: qcom: camss: Add SM8750 support` | — | 覆盖信（含 Dependencies 三条 + Changes in v2…v6） |
| 1/7 | `dt-bindings: phy: qcom,x1e80100-csi2-phy: Add SM8750 CSI2 PHY` | `.../bindings/phy/qcom,x1e80100-csi2-phy.yaml` | 1 file, +7 −3 |
| 2/7 | `media: dt-bindings: Add CAMSS device for SM8750` | `.../bindings/media/qcom,sm8750-camss.yaml` | 1 file, **+427** |
| 3/7 | `media: qcom: camss: Add SM8750 compatible camss driver` | `camss.c`, `camss.h` | 2 files, +23 |
| 4/7 | `media: qcom: camss: csiphy: Add support for v2.3.0 two-phase CSIPHY` | `camss.c` | 1 file, **+2** |
| 5/7 | `media: qcom: camss: csid: Add support for CSID 980` | `Makefile`, `camss-csid-980.c`(新), `camss-csid.h`, `camss.c` | 4 files, **+520** |
| 6/7 | `media: qcom: camss: vfe: Add support for VFE 980` | `camss-vfe-gen4.c`, `camss-vfe.c`, `camss.c` | 3 files, +11 −3 |
| 7/7 | `media: qcom: camss: tpg: Add support for v2.3.0 TPG` | `camss-csid-980.c`, `camss-tpg-gen1.c`, `camss.c` | 3 files, +20 −6 |

### 2.1 v6 cover 里的三条硬事实（决定后面 A/B/C 选择）

1. **v6 是「RDI only」**，且**架构已改成 split-CSIPHY**：CSIPHY 不再由 camss 内建驱动，
   而交给独立 `phy-qcom-mipi-csi2` DPHY 驱动（v6 Changes: *"Drive the CSIPHY through the
   standalone phy-qcom-mipi-csi2 DPHY driver based on new split-csiphy arch"*）。
   4/7 因此只有 **+2 行**（只加 compatible→gen4 资源映射），把 PHY 的活全推给外部 phy 驱动。
2. **v6 有 3 条未合并的前置依赖**（cover `Dependencies:`）：
   - `20260720-x1e-csi2-phy-v13-0-160c31958863@linaro.org`（x1e CSIPHY v13）
   - `20260708-b4-linux-next-25-03-13-dtsi-x1e80100-camss-v12-0-f8588da41f16@linaro.org`（x1e80100-camss dtsi v12）
   - `20260720-kaanapali-camss-v15-0-c0b1c1167c5d@oss.qualcomm.com`（**kaanapali camss v15**）
   ⇒ v6 **不能单独落地**，它骑在 kaanapali 系列上，并**复用 kaanapali 的 gen4 VFE/TPG 资源**。
3. **v6 明确不含 DTS**（v2 changelog：*"Remove DTS patch due to conflict with camcc dependency.
   Will post it as an individual series."*）。DTS 另有一个 **2026-06-18 `[PATCH v2 0/3] Add CCI and
   CAMSS support for SM8750`**（DTS + CCI）系列承担。

## 3. 逐枚对照表（我方 v3 9 枚 × 上游 v6 7 枚 + 2 个关联系列）

图例：**重叠**=同一文件同一职责被上游已发补丁覆盖；**新**=上游 v6/关联系列均无；**换路**=意图相同但机制不同。

| 我方 v3 | 主题 | 触及文件 | diffstat | 上游对应 | 判定 | 谁更完整 / 我方需 citation 处 |
|---|---|---|---|---|---|---|
| 0001 | dt-bindings: media: SM8750 camera subsystem | `qcom,sm8750-camss.yaml`(新) | +435 | **v6 2/7** 同名 yaml +427 | **重叠（架构冲突）** | **上游更完整**：v6 是 split-csiphy 模型（camss 不再持有 CSIPHY 寄存器/时钟/供电，改由 `phys`/`phy-names` 引外部 `phy-qcom-mipi-csi2`）。我方是**单体模型**（camss 内建 4×CSIPHY、12 条 `vdd-csiphyX-{0p9,1p2}-supply`）。krzk/Bryan 已按 v6 评审。若坚持我方 yaml 必须点名 supersede v6 2/7 并给出反对 split 的技术理由 —— 目前没有 |
| 0002 | media: camss: csiphy: CSIPHY 2.4.0 lane settings | `camss-csiphy-3ph-1-0.c`, `camss.h` | +125 | **v6 4/7** 仅 `camss.c` **+2** | **换路** | 上游把 SM8750 PHY 交给 `x1e-csi2-phy` v13（v6 依赖①）＋ phy binding v6 1/7；我方 0002 只对"in-tree 3ph CSIPHY"有意义，split-csiphy 落地后为死代码。**除非**我方主张 camss 内建 PHY 路线，否则整枚报废 |
| 0003 | media: camss: csid: power-on 反序回滚 | `camss-csid.c` | +20 −25 | 无（v6 5/7 只动 `camss-csid.h`＋新增 980 文件，**不碰** `camss-csid.c`） | **新** | 通用 bugfix，与 SoC 无关，独立可合。无需 citation |
| 0004 | media: camss: csid: add the 980 generation | `Makefile`, `camss-csid-980.c`(新), `camss-csid.h`, `camss-csiphy-3ph-1-0.c`, `camss-vfe.c/.h` | +505 −8 | **v6 5/7** 同名 `camss-csid-980.c` 443 行（+520 含 Makefile/h/camss.c） | **近似重复** | 证据（脚本核过）：我方文件 vs v6 文件 unified diff 仅 **296 行**；函数名集合 **15/15 全部相同**（`__csid_full_aup_rup_trigger`/`__csid_aup_update`/`__csid_rup_update`/`__csid_aup_rup_clear`/`__csid_configure_rx{,_vc}`/`__csid_configure_rdi_{stream,pix_store}`/`__csid_ctrl_rdi`/`csid_reset`/`csid_configure_stream`/`csid_configure_testgen_pattern`/`csid_isr`/`csid_subdev_init`/`csid_subdev_reg_update`），**v6 独有函数 0 个，我方独有函数 1 个（`csid_read_timestamp`）**；逐行看 v6 独有 24 行、我方独有 77 行。我方**多**：`spinlock_t reg_update_lock` + `csid_read_timestamp()`（为 0005 服务）；v6 多：`CSID_TOP_IRQ_SET`、`CSID_CSI2_RX_IRQ_{STATUS,MASK,CLEAR,SET}`、`MUP`、`RDI_CFG1_{DROP,CROP}` 位。**结论：应基于 v6 5/7 重做增量，不能并列重投** |
| 0005 | media: camss: csid: report frame starts from CSID | `camss-csid-980.c`, `camss-vfe.c/.h`, `camss.c`, `camss.h` | +101 −1 | v6 无；**bod 已公开预告将另发 `V4L2_EVENT_FRAME_SYNC` 系列**（见 §4） | **新但已被拒路** | bod 原话：*"SOF and buf done need not happen in the same interrupt and quite likely won't. This logic can't hold over idle entry/exit scenarios. Also I think we need a different approach to latching qtime regs, generally. In fact let me follow up this email with a series to enable V4L2_EVENT_FRAME_SYNC which is the right way IMO to latch SOF."*（`84bc6332-1db6-4c9c-a956-51b76f96352a@kernel.org`）⇒ 重投=再被拒 |
| 0006 | media: camss: video: buffer DMA 连续性检查 | `camss-video.c/.h` | +18 −1 | v6 无 | **新** | 唯一 choke 点：body 质疑前提（*"can you cite sources?"*）。需引用 VB2/DMA-API 依据或降到"SM8750 RDI 具体需要"的实测证据，否则属无据加检查 |
| 0007 | media: camss: video: start 失败回滚已启动 subdev | `camss-video.c` | +30 −30 | v6 无 | **新（最强）** | 7.3-rc7 基线复核：`video_start_streaming()` 失败路径**只** `video_device_pipeline_stop()`，已 `s_stream(1)` 的 subdev 不回滚，下次 start 重复启动 ⇒ 对所有 SoC 成立的真 bug。与 v6 零冲突，独立成篇 |
| 0008 | media: camss: vfe: add gen4 block + SM8750 | `Makefile`, `camss-vfe-gen4.c`(新), `camss.c` | +570 | **v6 6/7** 仅 +11 −3（`camss-vfe.c`/`camss.c`），gen4 VFE 实体在**依赖③ kaanapali v15** 的 `camss-vfe-gen4.c` | **近似重复（第三份实现）** | 上游 gen4 VFE 由 kaanapali v15（6 轮评审）承载，v6 只补 SM8750 资源映射。我方再写一份 = 与两家 Qualcomm 作者抢同一文件 |
| 0009 | arm64: dts: qcom: sm8750: add the camera subsystem | `sm8750.dtsi` | +179 | v6 **明确不含 DTS**；但 `[PATCH v2 0/3] Add CCI and CAMSS support for SM8750`（2026-06-18，Hangxiang Ma，`20260618-pakala-camera-v2-*`）给 `sm8750.dtsi` **+541**（camss 节点 + CCI + camera MCLK pinctrl） | **重叠（未合并系列）** | 我方 dts 按单体 camss 模型写（camss 内 csiphy 子节点），与 v6/pakala 的 split-csiphy + 独立 CCI 不兼容；且 pakala 那套更全（含 CCI、MCLK）。7.3-rc7（`24a19b953`）`sm8750.dtsi` 复核：`grep -ci camss` = **0**（未合并） |

**统计**：9 枚中 **5 枚重叠**（0001/0002/0004/0008/0009）、**1 枚被评审明确否掉方向**（0005）、**3 枚独立**（0003/0006/0007，其中 0006 有 citation 缺口）。

## 4. FRAME_SYNC 系列核实 + DTS/CCI 归属

### 4.1 FRAME_SYNC（krzk/bod 提到的"另一个系列"）

- 已试命令（anubis 已解，搜索索引有效）：
  - `https://lore.kernel.org/linux-media/?q=s:"V4L2_EVENT_FRAME_SYNC"` → 命中全部是 **2023–2024** 的
    `mipi-csis`（Stefan Klug）与 `uvcvideo`，**没有** 2026 年 camss/SM8750 条目。
  - `https://lore.kernel.org/all/?q=s:camss+AND+s:"frame+sync"` → 该 URL 形式返回 404（`/all/` 不做 s: 组合检索），
    改走 `linux-media` 与 `linux-arm-msm` 逐个查，均无 2026-10 之后的新系列。
- ⇒ **结论：截至本次核查（2026-10-29），上游未见 bod 承诺的 camss FRAME_SYNC 系列**。它只存在于
  `84bc6332` 的公开声明里（"let me follow up this email with a series"）。**未证实已存在**。

### 4.2 与我方 0005 的关系

- 我方 0005 = "CSID 在 RDI 中断里读 SOF/EOF qtime 时间戳，用 `v4l2_event` 类的自定义事件报到用户态"。
- bod 的方向 = 用 **标准 `V4L2_EVENT_FRAME_SYNC`**（`v4l2_event.subsrc`/`sequence`/`timestamp`）承载 SOF，
  并且"锁存 qtime 寄存器的做法要整体重新设计"。
- 关系判定：**同一需求的两种实现，标准事件版是上游要的形状**。我方 0005 的**有效残值**只有两块：
  ①`camss-csid-980.c` 里 `CSID_RDI_SOF_TS(i)` 的读取与 latching（可作为 bod 系列的 980 支持补齐）；
  ②`csid_read_timestamp()` 与 `reg_update_lock`（若 bod 系列不覆盖 980 的 AUP/RUP 并发，则仍有价值）。
  ⇒ 0005 **不应重投**，应转为"等 bod 系列出现后，在其上补 980 分支"的后续增量。

### 4.3 DTS/CCI 归属

- v6 cover/changelog：*"Remove DTS patch due to conflict with camcc dependency. Will post it as an individual series."*
  → **Qualcomm 自己也没把 DTS 合进去**，DTS 由 `pakala-camera v2`（2026-06-18，+541 行）承担，尚未合并。
- 我方 0009 若单独重投，会与该系列在 `sm8750.dtsi` 同一区域冲突，且模型不兼容 ⇒ 属"重复劳动 + 结构倒退"。

## 5. 结论：推荐的推进形状

### 5.1 选择：**C → B**（先一封回信定调，落地按 B 的子集）

- **不建议 A**（全部重投 + supersede v6）：5/9 重叠，其中 3 枚（0001/0004/0008）是与 Qualcomm 已迭代 6 轮的
  同文件竞争；0004 与 v6 5/7 的函数级几乎同构（296 行 diff / 13 函数同名），一旦并列会被直接判为
  duplicate work + 需自行承担"为何不基于 v6"的举证。0002 与 split-csiphy 架构方向相反。
- **不建议只做 C 不发补丁**：0003/0007 是与 SoC 无关的通用 bugfix，卡在别人的系列后面没有收益。
- **落地形状 = B**：C 只用于避免"沉默 + 重复投递"的印象，随后立刻发 B 子集。

### 5.2 若选 B 的具体子集（3 枚，按发送顺序）

| 顺序 | 补丁 | 理由 | 前置检查 |
|---|---|---|---|
| 1 | **0007 media: camss: video: stop the subdevices already started when a start fails** | 纯通用 bugfix，7.3-rc7 基线可复现（失败路径不回滚已 `s_stream(1)` 的 subdev）；与 v6 任何补丁零文件重叠；不依赖 SM8750/980/gen4；reviewer 无需理解新硬件 | `checkpatch` + 用 v4l2-compliance 或注入失败构造复现日志 |
| 2 | **0003 media: camss: csid: unwind the power-on path through a single error label** | 通用资源回滚清理，`camss-csid.c` 与 v6 5/7（`camss-csid.h` + 新 980 文件）不冲突 | 已核：kaanapali v15 全 8 枚**不碰** `camss-csid.c`（`grep '^diff --git .*camss-csid.c'` 零命中）⇒ 与 v6 依赖链无 3-way 冲突，可立即发 |
| 3 | **0006 media: camss: video: check that a buffer is DMA contiguous** —— **条件发送** | 仅有实质价值：若能在 cover 里点名依据（VB2 `dma_attrs`/DMA-API 对 non-coherent 设备的要求，或 SM8750 RDI 的实测失败日志）。**拿不出 citation 就撤下**，否则重演 body 的 *"can you cite sources?"* | 补 citation 或写实测证据；否则不发 |

**同时撤下**：0001/0002/0004/0008/0009（重叠）、0005（等 bod 的 FRAME_SYNC 系列）。
**后续增量位（不是现在发）**：等 v6 + kaanapali v15 落地后，只需两小枚 ——
(i) 980 的 `reg_update_lock` 并发保护（v6 5/7 无锁）；(ii) FRAME_SYNC 系列的 980 SOF/qtime 分支。

### 5.3 C 的那封回信要点（3 句，不发代码）

1. 已读 v6 全 7 枚 + kaanapali v15 依赖，我方 v2 的 camss 内建 CSIPHY/单体 binding 路线**撤回**，不再主张。
2. 我方只保留与 SoC 无关的通用修复（`camss-video` start 回滚、`camss-csid` 回滚路径），单独成小系列发出，不与 v6 争文件。
3. 关于 SOF：接受 bod 的 `V4L2_EVENT_FRAME_SYNC` 方向，撤回 v2 5/9 的 qtime 自研事件，等其系列出现后补 980 分支；
   顺便询问 `camss-video` 的 DMA 连续性检查是否有既有依据（把 0006 的存废交给 maintainer 判）。

## 6. 取证与边界声明

- v6 下载：**8/8 消息成功**（cover + 1..7），落 `reference/upstream-camss-v6/`（根目录=原始 raw 双副本，`single/`=单副本），
  与 §1.2 一致；`mail-triage-20261029.md` §结论 4 的"上游已有 v6"**已证实**。
- kaanapali v15 依赖：`out/lane-camss-v6/deps/kaanapali/`（用于比对 `camss-csid-gen4.c` / gen4 VFE 归属）。
- pakala-camera v2（DTS/CCI）：`out/lane-camss-v6/dts-frame/1..3.raw`。
- FRAME_SYNC：**未证实存在**，已列试过的 URL。
- 边界：**未修改 `patches/`、未发任何邮件、未登录站点、未接触设备**。所有结论仅基于 lore 公开件 + 本地 7.3-rc7 树。
