# M4-2…M4-4 camss 驱动系列（draft，2026-10-27）

面向上游 `linux-media` 的 **camss sm8750 驱动主体**分片草案。承接 M4-1（binding 三枚已投，
`patches/upstream/m4-camss-2026-10-13/sent-20261027/`）。规则 = `reports/upstream-policy-20261013.md`；
拆解方案 = `reports/m4-camss-project-20261013.md` §2.1。

**状态：未投递。** 本轮只做「可评审分片 + 每条提交都自洽可编译」；评审风险见 §4（其中 3 条须在投递前处理）。

## 1. 基线与复现

| 项 | 值 |
|---|---|
| 基线 | pristine `24a19b953`（Linux 7.3-rc7，`build/m4-base` worktree，从 `build/m3v2-7.3rc7` 拉出） |
| 系列 tip | `d20da3f67`（7 提交，13 文件，**+1760/−61**） |
| 来源 | 本地功能树 `build/vk151`（@`24223e44a`）的 camss 现状，按「一次性提交 → 7 个可编译提交」重切 |
| 重放 | `git -C build/m4-base format-patch 24a19b953..HEAD`；或 `git am 000*.patch`（顺序不可变） |

```sh
# 编译门（arm64 defconfig，CONFIG_VIDEO_QCOM_CAMSS=m）
cd build/m4-base && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
for c in $(git rev-list --reverse 24a19b953..HEAD); do
  git checkout -q $c && make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
      drivers/media/platform/qcom/camss/ || echo "FAIL $c"; done
```

## 2. 提交清单与依赖

| # | 文件 | 主题 | 依赖 | 编译 |
|---|---|---|---|---|
| 1 | `0001-csiphy-sm8750-2.4.0.patch` | CSIPHY 2.4.0 lane 数据表 + `CAMSS_8750` 枚举（M4-2） | — | OK |
| 2 | `0002-csid-power-unwind.patch` | `csid_set_power()` 错误路径统一 unwind（**顺带修真 bug**：pm_runtime 失败时漏放 parent 引用） | — | OK |
| 3 | `0003-csid-980-and-frame-start.patch` | csid-980（full/lite）+ RUP/AUP 拆分 + **SOF 改由 CSID 上报**（`camss_frame_start`→VFE `FRAME_SYNC` 事件） | 1 | OK |
| 4 | `0004-video-prepare-hook.patch` | `prepare_buffer` 视频层钩子 + DMA 连续性校验 + 起流失败时的 subdev 回退 | — | OK |
| 5 | `0005-dt-binding-sm8750-camss.patch` | `qcom,sm8750-camss.yaml`（独立提交，因 checkpatch 要求 binding 与驱动分开） | — | OK |
| 6 | `0006-vfe-gen4-and-sm8750-resources.patch` | vfe-gen4 + sm8750 六 CSIPHY/四 CSID/三 VFE 资源表 + icc + compatible | 3,4,5 | OK |
| 7 | `0007-NOT-FOR-UPSTREAM-csid-vfe-pairing.patch` | **不进上游**：CSID↔VFE 按 `i==k` 配对 + 重复 link 跳过（M4-5 隔离层） | 6 | OK |

依赖链是**真的**：提交 1 新增的 `CAMSS_8750` 直到提交 6 才被资源表选中；提交 3 的 `frame_start` 直到提交 6
才有实现者（gen4）；因此 **1/3 单独投递会有「无使用者」质疑，须整系列一起送**。

## 3. 已跑门禁（2026-10-27）

| 门 | 结果 |
|---|---|
| `checkpatch.pl --strict` ×7 | **0 errors**；3 条 WARNING 全是同一假阳性（见 §4 R5）：0003/0005/0006 的 `added file(s), does MAINTAINERS need updating?` |
| `dt-doc-validate`（`documentation/devicetree/bindings/media/qcom,sm8750-camss.yaml`） | **rc=0** |
| 逐提交 `make drivers/media/platform/qcom/camss/` | **7/7 BUILD_OK**（arm64 defconfig，0 warning） |
| 终态与本地功能树一致性 | camss 目录 + binding 与 `build/vk151` 逐字节一致，**除两处有意改动**：`csid_device` 用显式 `rup_update`/`aup_update` 字段替代下游的匿名 union（匿名 union 会被维护者否）；提交 7 的两处 SoC 特判独立成提交 |
| 未跑 | `dtbs_check`（本系列不含 `sm8750.dtsi`/板级 DTS，见 §4 R6）；未上机（下面 §4 R1/R2/R3 就是"上机能证明什么"的缺口清单） |

## 4. 评审风险 / 投递前必须处理

- **R1（必须）硬件数值出处**：`lane_regs_sm8750`（提交 1）与 `csiphy_res_8750`/`csid_res_8750`/`vfe_res_8750`
  （提交 6）的寄存器序列、供电名、时钟率、icc 带宽全部来自**厂商实现**（本地功能树血统），我们不是 QCOM，
  上游通常要求「硬件编程手册出处」或 QCOM 同签。binding 的 `maintainers:` 是
  `Hangxiang Ma <hangxiang.ma@oss.qualcomm.com>`（= 该 binding 原文来自 QCOM 侧），可作为 co-author/ack 线索，
  但**投递前需就此与 QCOM 侧的 camss 系列对齐**，否则大概率收到「请提供文档依据」。
- **R2（必须）`common_status_offset = 0x138` 未上机专项验证**：CSIPHY 2.4.0 我们设了 `0x138`（2.3.0 为默认 `0xb0`），
  该偏移**只被 `csiphy_isr()` 的错误上报路径读取**，正常出流不经过；设备上相机 30 fps 正常只说明 lane 数据正确，
  不说明这个偏移正确。要么上机取证（出流时 `devmem` 对比两组偏移的 lane status），要么在提交里改成显式说明。
- **R3（必须）提交 3 是架构性改动**：把「帧起始」从 VFE 移到 CSID（gen4 VFE 的 `isr` 是 nop），
  并且 `vfe_buf_done()` 的 sequence 语义随之改变（帧号只由 SOF 递增、SOF 前完成的 buffer 标 `VB2_BUF_STATE_ERROR`）。
  按项目方案（`reports/m4-camss-project-20261013.md` §2.1 M4-3/M4-4）这应当**单独立 RFC**并附上
  「为什么 gen4 的 VFE 不再报中断」「错误帧为何用 ERROR 而非丢弃」的说明，而不是夹在 csid-980 里。
- **R4（建议）提交 4 混了两件事**：DMA 连续性校验（硬件要求）与起流失败回退（通用清理）应拆两枚，评审更好过。
- **R5（不用改）MAINTAINERS 假阳性**：`MAINTAINERS` 的 `QUALCOMM CAMERA SUBSYSTEM DRIVER` 段已含
  `F: drivers/media/platform/qcom/camss/` 与 `F: Documentation/devicetree/bindings/media/qcom,*camss*` ⇒ 新增文件已被覆盖，
  checkpatch 的整目录 glob 启发式仍报。回复时贴这两个 glob 即可。
- **R6（缺件）DT 侧未随本系列**：`qcom,sm8750-camss.yaml` 只是 binding；`sm8750.dtsi` 的 `isp@ad27000` 节点
  与板级 DTS 的 sensor/csiphy 连线仍在 M1 树里，**未纳入本系列**，因此 `dtbs_check` 无法跑。上游要求
  「有节点无驱动 / 有驱动无节点」都不可接受 ⇒ 投递时必须把 dtsi 节点补齐（或与 M3 的 SoC 基础系列合并送）。
- **R7（已知遗留，未纳入）**：csid-980 里 `for (k < CAMSS_INIT_BUF_COUNT) { aup; rup; }` 的重复 RUP（= 下游
  `CAMSS_INIT_BUF_COUNT` 规避）、SOF/EOF 用时间戳排序的兼容分支、以及 `mc-entity.c` 的核心改动**都不在本系列**；
  这些归 M4-5（`reports/m4-camss-project-20261013.md` §2.1），根因未定案前不进上游。

## 5. 与本地功能树的差异（为什么不直接 `git diff` 上游）

下游树里三块是「本地为出图硬塞」的，本系列的做法：

| 下游现状 | 本系列处理 |
|---|---|
| `csid_device` 用匿名 `union { u32 reg_update; struct { rup_update; aup_update; }; }` | 改成三个并列字段（提交 3），语义不变、不引入匿名 union |
| `camss_link_entities()` 与 `camss_subdev_notifier_complete()` 两处 `CAMSS_8750` 特判 | 独立成提交 7 并标注 **NOT FOR UPSTREAM** |
| `camss-video.c` 的 DMA 连续性/回退逻辑与驱动改动混在一提交 | 抽出为提交 4（通用改进，任何 SoC 都受益） |
