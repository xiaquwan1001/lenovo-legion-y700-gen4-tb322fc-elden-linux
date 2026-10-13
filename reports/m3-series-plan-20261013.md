# M3 板支持系列 — 拆分计划与验收口径（2026-10-13）

> 证据层档案。规则见 `reports/upstream-policy-20261013.md`；M1–M5 状态权威 = `TASKS.md §7`。
> 工作树 = `build/m1-upstream/clean-tree`（分支 `m1/clean-tree`，tip `c73ff25222`）；上游参照 = `build/m2-worktree` @ `torvalds/v7.3-rc7`（`24a19b953e`）。
> **pristine 参照 = tag 提交** `24a19b953e`（不要再把 `build/m2-worktree` 当 pristine：它是带本片补丁的工作树，重建方式 `git -C geekidos-linux worktree add --detach <dir> 24a19b953e`）。
> 本次实测工具链：`aarch64-linux-gnu-gcc`（`~/bin`）+ `~/venv-dtschema/bin/dt-validate`（2026.9）。

## 0. 验收口径（M3 每片的硬门）

1. **schema**：DTS 用**本系列自带 binding** 集合校验 → `dt-validate` **0 诊断**（用纯上游 binding 校验的差额 = 本系列必须随行交付的 binding 集合，不是"红点"）。
2. **binding 自检**：改/新增的 yaml 全过 `dt-doc-validate`。
3. **编译**：`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs` 成功（`DTC` 行无 warning）。
4. **风格**：`scripts/checkpatch.pl --strict --no-tree` 每补丁 0E/0W；每补丁英文 + `Signed-off-by`。
5. **功能不回归**：M3 系列是"可上游子集"，允许少于在机功能；但**不得**包含未定根因的实验项（`reports/upstream-policy-20261013.md` §3）。

## 1. 现状核验（2026-10-13 实测）

| 项 | 结果 |
|---|---|
| `make … dtbs`（重建板 DTB） | ✅ 成功（`DTC arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb`），149 236 B |
| 板 DTB 用**本树 binding** 校验 | ✅ **0 诊断** |
| 板 DTB 用**纯上游 v7.3-rc7 binding** 校验 | ⚠️ **382 诊断 / 22 个节点** ⇒ 差额即"binding 必须随 DTS 同行"的清单 |
| `arm/qcom.yaml` 登记 `lenovo,elden` | ✅ 已在（M1 树 line≈1126，与 `qcom,sm8750-mtp/qrd` 同 enum）⇒ A5 的 yaml 部分已完成 |
| 板 DTS `compatible` 总数 | **36**：上游 binding+驱动齐 **18**；无上游 binding **11**；无上游驱动 **18**（启发式 grep，逐条复核后再定片） |
| 板 DTS 中已被 sndcard 引用的功放节点 | `speaker_left/right = awinic,aw88461`（`sound-dai` 引用在 line 1145）⇒ 非死节点，属音频片 |

**结论**：M1 树在"自带 binding"口径下已经自洽（这也是 `UPSTREAM-REVIEW` §3.4 的 `usb@a600000` 红点在 M1 树消失的原因）；M3 的真实工作不是"修红点"，而是**把这棵自洽的树拆成上游可评审的分片序列**，并保证每片的 binding 与 DTS 同行、无实验项混入。

## 2. 分片计划（7 片，先小后大 / 先地基后外设）

| 片 | 内容 | 依赖 | 判据 | 备注 |
|---|---|---|---|---|
| **M3-0** | 依赖台账（本文）+ 系列骨架 `patches/upstream/m3-2026-10-13/` | — | 台账数字可复现 | 本轮交付 |
| **M3-1** | **USB 双连接器 mux 系列**：`drivers/usb/dwc3/drd.c`（`dwc3_mux_role_set` 等 +182 行）+ `core.c`（`usb-psy-name` psy 绑定）+ 其 schema（现挂在 `snps,dwc3-common.yaml`）+ 板 DTS `&usb` 段 | 无（自包含） | 上表 §0 全绿；Q2 = 扩展既有 dwc3 drd（合规） | **review 点名的红点所在**；建议同轮把 `usb-psy-name`（按名查找）改为 **phandle 引用**（上游更易接受） |
| **M3-2** | **板基础**：UFS / PMIC regulators（pm8550 family）/ TLMM / `gpio-keys` / `ramoops` / `simple-framebuffer` / `pmic-glink` 等"上游齐 18 项"的板级 enablement | M3-1（USB 段已定） | §0 全绿 | 地基片；后续片都在其上叠加 |
> 各片依赖的逐项上游支持面（含 payload 改动规模与两条 Q2 偏离）= `reports/m3-missing-support-matrix-20261013.md`。

| **M3-3** | **音频 + 温控**：WCD939x codec + `qcom,sm8750-sndcard` dai-links + `awinic,aw88461` 功放 + 分级 thermal trips | M3-2 | §0 全绿 + sndcard 与 dai-link 一致 | cod 侧驱动已在树（`sound/soc/qcom`） |
| **M3-4** | **显示**：mdss/dpu sm8750（含 A1 GC block）+ `panel-novatek-nt36536` 驱动 + 触屏 `novatek,nt36536-ts` | M3-2 | §0 全绿；驱动须先剥 §3 实验钩子 | 与 Q28 强耦合：**B5 per-SoC cfg 重构可与本片合并做** |
| **M3-5** | **相机**：camss 一族（`camss.c`/新 CSID 980/VFE gen4/csiphy）+ `samsung,s5kjns`/`galaxycore,gc08a8`/`giantec,gt9764`/`willsemi,wl2868c` | M3-2（+ M4 立项） | §0 全绿 + media binding 齐 | 最大件；`gt9764` 缺 binding 需补 |
| **M3-6** | **无线**：ath12k PEACH（`pci17cb,110e`）+ `qcom,wcn7861-pmu` pwrseq + `qcom,wcn7861-bt`/`hci_qca` PERI | M3-2（+ M4 立项） | §0 全绿 | `pwrseq-qcom-wcn` 与 `qca6390-pmu.yaml` 配套 |

**顺序理由**：M3-1 自包含且是 review 点名的具体红点；M3-2 是其余各片的地基；M3-4 与 Q28 共用一份 DSI 重构（一次投入两份收益）；M3-5/M3-6 属 M4 大件，先在 M3 内定 binding 与 DTS 面。

## 3. 每片可复制的验收命令

```sh
cd build/m1-upstream/clean-tree
export PATH=~/venv-dtschema/bin:$PATH
# 1) 编译板 DTB（源码 → dtb）
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs
# 2) schema（自带 binding）
dt-validate -s Documentation/devicetree/bindings \
    arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb     # 期望 0 诊断
# 3) binding 自检
dt-doc-validate Documentation/devicetree/bindings/<改动的 yaml>
# 4) 补丁风格
scripts/checkpatch.pl --strict --no-tree patches/upstream/m3-*/0*.patch
```

## 4. 与 M1/M2/M4 的关系

- **M1**（干净资产树）：本计划直接在其 tip 上施工；M1 仍缺"上机功能对照"。
- **M2**（首发小系列）：已投 A2/P3 两枚独立补丁；M3 不与 M2 抢同一文件。
- **M4**（大件立项）：M3-5 camss、M3-6 ath12k 的 driver 侧属 M4，本计划只负责把它们在 **DTS/binding 面**定位清楚。
- **B5**（per-SoC cfg 重构）：与 M3-4 合并执行。

## 5. 下一步

**M3-1 开工**：把 dwc3 双连接器 mux 从"payload 里的一坨"整理成独立可评审系列（binding → 驱动 → DTS 三段），
过程中把 `usb-psy-name` 的按名查找改为 phandle 引用；随后 M3-2 板基础片。
