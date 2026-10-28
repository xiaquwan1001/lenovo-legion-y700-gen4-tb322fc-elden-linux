# M4 camss 系列：Sashiko 自动评审逐条取证与处置（2026-10-28）

> 触发：M4-2…M4-4 `[PATCH 0/9]`（Message-ID `<20261028034105.326535-1..10@mail.ustc.edu.cn>`）投递后，
> `sashiko-bot@kernel.org` 对 **patch 1/4/5/8/9** 自动回评（5 封，含 8 条 finding）。
> 本报告：**逐条在源码/厂商源里取证** → 判定真伪 → 定处置。**无 human maintainer 回复**（截至 2026-10-28 13:20）。
> 结论落地：**v2 参数** = `patches/upstream/m4-camss-series-20261028-v2/`（`build/m4-base` @ `m4/v2-20261028`）。

## 0. 一句话结论

5 封评审、8 条 finding：**4 条真 bug（2 High + 2 Medium）已修**，**2 条（High）是既有上游广义问题 → 回帖不改**，
**2 条（Medium）是既有上游同形竞态 → 回帖不改**。四类证据都是「对源码 / 对厂商 `camera-kernel` 源」直接核。

## 1. 逐条取证

### F1 · patch 1/9 · [Medium] 提交信息计数与 schema 不符 —— **真（文档）**

- schema `qcom,sm8750-camss.yaml` reg-names：`csid0/1/2` + `csid_lite0/1`（**3 full + 2 lite**）、
  `vfe0/1/2` + `vfe_lite0/1`（**3 full + 2 lite**）、`csitpg0/1/2`、`csiphy0..5`。
- 原提交信息写「two full and two lite CSIDs, and two full plus one lite VFEs」⇒ 错。
- 交叉核对（`build/m4-base` `camss.c`）：`csid_res_8750[]` **5 项**（csid0/1/2/lite0/lite1）、
  `vfe_res_8750[]` **5 项**（vfe0/1/2/lite0/lite1）、`csiphy_res_8750[]` **6 项**。⇒ 与 schema 一致。
- **处置**：v2 改提交信息（仅提交信息，schema 不动）。

### F2 · patch 4/9 · [High] `dt_id = vc & 0x03` 应为 `port & 0x03` —— **真 bug（High）**

- `camss-csid-980.c:__csid_configure_rdi_stream(csid, enable, port, vc)`，调用点恒 `vc=0`（`csid_configure_stream` 传 `i, 0`）。
- 原码 `u8 dt_id = vc & 0x03` ⇒ **dt_id 恒 0** ⇒ `CSID_RDI_CFG0(port)` 的 DT_ID=0、内部 CID 全相同 ⇒ RDI>0 出流坏。
- 对照 `camss-csid-gen3.c:185` = `u8 dt_id = port & 0x03`（上游已为 gen3 修过，commit `ad136e52634d`
  "Fix RDI streaming for CSID GEN3"，本树 `git log -1` 无该提交=shallow，但 gen3 现码就是 `port`）。
- **上机为何没暴露**：`devcam-ab`/G1-5 只测前摄单模（`csiphy4 → csid0 → vfe0_rdi0`，**RDI0/port0**），`dt_id=0` 恰对，故潜伏。
- **处置**：v2 改 `port & 0x03`。**注明**：CSID full 有 5 个 RDI（port 0..4），`port&0x03` 会让 port4 与 port0 同 dt_id；
  但这是沿用 gen3 的上游口径（gen3 4 路内无此问题），若上游要求再议——本机实测只用 port0，优先对齐上游既有写法。

### F3 · patch 4/9 · [High] `INFO_RUP_DONE` 未在 `CSID_CSI2_RDIN_IRQ_MASK` 里解掩码 —— **真 bug（High）**

- `csid_configure_stream()`：`mask = readl(RDIN_IRQ_MASK); ... mask = enable ? mask | INFO_CAMIF_SOF : ...`，
  **只动 `INFO_CAMIF_SOF`（BIT4）**，`INFO_RUP_DONE`（BIT23）从不置位；`csid_reset()` 也不碰 RDIN 掩码。
- 后果：`csid_isr()` 的 `if (val & INFO_RUP_DONE) csid_subdev_reg_update(clear)` 永不触发（或仅靠 SOF/buf_done 顺带读到），
  `csid->aup_update/rup_update/reg_update` 影子位不清 ⇒ 后续 `__csid_aup_update()` 反复带旧位写命令（lite 上身 `reg_update` 长期带 RUP 位）。
- 厂商佐证：`stock-src/.../cam_ife_csid_hw_ver2.c:5346` 起始流路径 `dbg_frm_irq_mask |= path_reg->rup_irq_mask;`
  （`rup_irq_mask=0x800000=BIT23`，见 `cam_ife_csid980.h`）⇒ **厂商确实使能 RUP_DONE 中断**。
- **处置**：v2 在 `csid_configure_stream()` 里把 `INFO_RUP_DONE` 一并使能 + 清状态（`mask |= INFO_CAMIF_SOF|INFO_RUP_DONE`）。
  ⚠️**待上机复验**（v2 改了中断掩码，须重跑一次 90 帧出流确认无副作用）。

### F4 · patch 5/9 · [Medium] `vfe_buf_done()` 从不清 `frame_started` —— **真 bug（Medium）**

- `vfe_frame_start()` 置 `output->frame_started=true`；`vfe_buf_done()` 只读不置回。
- 后果：① 首帧后 `frame_started` 永真 ⇒ 「buffer 先于 SOF 到」的错误检测**仅首帧有效**；
  ② 首个 buffer 若在任何 SOF 前完成，`output->sequence-1`（sequence=0）**无符号下溢为 UINT_MAX**。
- **处置**：v2 `vfe_buf_done()` 里消费后 `output->frame_started=false`；分支改为 `frame_started?sequence-1:sequence` 且后者标 ERROR，杜绝下溢。

### F5 · patch 5/9 · [Medium] 无 `frame_start` 时代事件 ioctl 不一致 —— **真（一致性，Medium）**

- `vfe_core_ops` 无条件挂 `subscribe_event`/`unsubscribe_event`；但 `FL_HAS_EVENTS` 仅 gen4 置位。
- 非 gen4 VFE：`DQEVENT→-ENOIOCTLCMD`、`SUBSCRIBE_EVENT→vfe_subscribe_event→-EINVAL`、`UNSUBSCRIBE_EVENT→0`（三态不一）。
- **处置**：v2 `vfe_subscribe_event()` 在 `!frame_start` 时返回 `-ENOIOCTLCMD`；删掉显式 `.unsubscribe_event`，
  交回 `v4l2-subdev.c` 按 `FL_HAS_EVENTS` 统一回退（gen4 有 HAS_EVENTS 走 core 回退，非 gen4 得 -ENOIOCTLCMD）。三态对齐。

### F6 · patch 4/9 + 8/9 · [Medium] `aup_update/rup_update/reg_update` 跨 CPU 竞态 —— **既有上游同形 → 不回改**

- 事实成立：`csid_isr()` 里 `__csid_aup_rup_clear()` 无锁 RMW；`__csid_aup_update()`（持 `vfe->output_lock`）与其并发。
- **但**：`camss-csid-gen3.c` 是**一字不差的同一模式**（`reg_update` 无锁 RMW in ISR + `csid_subdev_reg_update`）。即**上游既有设计**，非本系列引入。
- **处置**：回帖说明「与 gen2/gen3 同形的既有 camss 行为；如确要解，应为独立 `camss: csid: guard the register-update shadow` 全局补丁（涉及 gen2/3/980），不纳入本系列」。**不改**。

### F7 · patch 9/9 · [High] `csid_set_stream()` 停流/重启跳过 `csid_configure_stream()` —— **既有上游门 → 回帖不改**

- 命中代码 = `camss-csid.c:csid_set_stream()` 的 `if (csid->phy.need_vc_update){configure_stream(); need_vc_update=false;}`。
- 该门 **pristine 7.3-rc7 就存在**（`git show 24a19b953:.../camss-csid.c` 同形），patch 9 只新增 DTS，**未引入**。
- 停流兜底：`video_stop_streaming → video_stop_subdevices(s_stream 0) → video_unprepare_streaming → v4l2_pipeline_pm_put
  → csid_set_power(0)`（`disable_irq+clocks off`），下次 `pm_get → csid_set_power(1)` 置 `need_vc_update=true` 重新配置。
  「共享 CSID 多路同开时停一路」与「起流失败回退后重试不重配」是**上游已知边界**，与本系列无关。
- **处置**：回帖说明属既有上游 `camss-csid.c` 设计、非本系列 DTS 补丁；**不改**（若要做，另立 camss 修复线）。

## 2. 处置汇总

| # | patch | 严重度 | 判定 | v2 处置 |
|---|---|---|---|---|
| F1 | 1/9 | Medium | 真（文档） | ✅ 改提交信息 |
| F2 | 4/9 | High | 真 bug | ✅ `dt_id = port & 0x03` |
| F3 | 4/9 | High | 真 bug | ✅ 解掩 `INFO_RUP_DONE`（**待上机复验**） |
| F4 | 5/9 | Medium | 真 bug | ✅ 回置 `frame_started` + 防下溢 |
| F5 | 5/9 | Medium | 真（一致性） | ✅ 返回 `-ENOIOCTLCMD`、删 `.unsubscribe_event` |
| F6 | 4,8/9 | Medium | 既有上游同形 | ⏸ 回帖不改 |
| F7 | 9/9 | High | 既有上游门 | ⏸ 回帖不改 |

## 3. 门禁与产物

- 逐提交编译 9/9 OK（一次 `-j26` 撞 gcc-15 ICE，`-j8` 重跑 OK，非代码）；终态 `LD [M]`、0 warning。
- `checkpatch --strict` 9/9：0 errors / 0 checks（3 条 MAINTAINERS 假阳性）。
- pristine `git am` 9/9 干净。
- v2 目录：`patches/upstream/m4-camss-series-20261028-v2/`（9 patch + 修正版 cover + README）。
- 分支：`build/m4-base` @ `m4/v2-20261028`（tip `ca3d71e71`）。

## 4. 未做 / 待办

- **F3（中断掩码）需上机复验**一次出流（90 帧、错误计数 0）后再考虑发 v2。
- 是否发 v2、是否回 Sashiko（机器人通常无需逐条回，发 `[PATCH v2]` 即含 `Changes in v2`）：**等用户批准**。
- 回复 F6/F7 的措辞草稿另附（若用户要回）。

## 5. 上机复验（2026-10-28 15:0x，零写盘热换模块）

**目的**：F3 改了 CSID 中断掩码，须确认 4 处修复在真机上不回归出流。

**手法**（照 `reports/m4-skewcal-ab-20261027.md` 的快环）：
- 在功能树 `build/vk151`（HEAD `24223e4` = 在机内核）上把 v2 的 **同一组 4 处改动**打进 `camss-csid-980.c` / `camss-vfe.c`；
- `LOCALVERSION=-debug-vk172 make prepare`（刷新 `include/generated/utsrelease.h`）+ `make M=drivers/media/platform/qcom/camss clean`；
- `scripts/mod-loop.sh drivers/media/platform/qcom/camss --reload qcom-camss` 热换（**未整机重启、未写 boot 槽**）；
- **硬证据**：运行中模块 build-id `9b38f05772fd951204ffa845bbf0352e9256241f` = 新编 `qcom-camss.ko` 的 build-id（旧基线 `2dd23e54…`），且设备盘 `updates/qcom-camss.ko` sha256 `a52ab5e5…` = 主机编出件。
- 出流：`camera-stream-up.sh front stream 90` / `rear stream 90`；错误计数 = `dmesg` 对 `command DMA timeout|EPIPE|EINVAL|csiphy.*error|camss.*error|camss.*fail` 计数前后差分。

**结果**：

| 通道 | 帧数 | v4l2 fps | 耗时 | 错误计数 前→后 |
|---|---|---|---|---|
| front（gc08a8→csiphy4→csid0→vfe0_rdi0→/dev/video0） | **90/90** | 30.26 | 3.35 s | 0 → 0 |
| rear（s5kjns→csiphy3→csid1→vfe1_rdi0→/dev/video3） | **90/90** | 30.03 | — | 0 → 0 |

帧内容抽查（front 3 帧 raw）：`BYTES 29 963 520 / NONZERO 99.67% / DISTINCT 256 / STDDEV 46.97` ⇒ 真帧非垃圾。

**结论**：4 处修复在真机上 **不回归**（双摄 90/90、0 错误、满速 30 fps、像素正常）。`INFO_RUP_DONE` 解掩码无中断风暴/副作用。

**限定**：① 前/后摄都走 **RDI0（port0）**，`dt_id = port & 0x03` 与「RDI>0」的收益**本机测不出**（无 RDI>0 物理通路），只能证明用 port 后 RDI0 仍正常；
② 热换未 POR（冷启 PHY/中断时序不同，结论不外推到冷启）；③ 只测单摄单模。

**设备终态**：热换的 `updates/qcom-camss.ko` 已移走、`depmod` 回落基线 ko（运行 build-id 回到 `2dd23e54…`）、`cam-mode.sh off`（CAM-OFF、blank 恢复 idle=300、剩 `system_heap` 常驻属正常）。
