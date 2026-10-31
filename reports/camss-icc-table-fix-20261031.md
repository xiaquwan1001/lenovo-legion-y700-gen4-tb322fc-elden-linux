# D6：camss interconnect 表不一致 —— 给 Hangxiang 的 fix 素材（2026-10-31）

- 来源：Shuai Liu 2026-10-29 对 `[PATCH 8/9] media: camss: vfe: add the gen4 block and SM8750 camera subsystem`
  的评审（`<tencent_3B08CBAEFC7B931B6E90D8D8C4BF3BB1B406@qq.com>`）：
  **binding+DTS 声明 4 条 interconnect，而 `icc_res_sm8750[]` 只有 2 条（`ahb`、`hf_mnoc`），
  `sf_mnoc` / `sf_icp_mnoc` 从未被投票**；建议把 binding 与 DTS 收敛到驱动真正使用的两条。
- 对象树：`build/m4-base`（HEAD `ca3d71e716` = SM8750 enable 系列已应用）与临时 worktree
  `build/camss-icc-wt`（detached，仅本地提交，未推送）。

## 0. 结论

| 项 | 结果 |
|---|---|
| 事实确认 | `drivers/media/platform/qcom/camss/camss.c:4519 icc_res_sm8750[]` 只有 `ahb` / `hf_mnoc`；binding `maxItems: 4` + 4 个 `interconnect-names`；`sm8750.dtsi` camss 节点 4 条 |
| 采纳形态 | **A：收敛到 2 条**（Shuai 建议；最小改动、与驱动一致） |
| 补丁 | `patches/upstream/camss-icc-20261031/0001-*.patch`（binding）、`0002-*.patch`（DTS） |
| 门禁 | `checkpatch --strict` **0E/0W/0C** ×2（15 / 16 行）；`dt-doc-validate` **rc=0**；`sm8750-mtp.dtb` 构建 **rc=0**；`dt-validate -m -s … material` **无输出（通过）** |
| 归属 | **这是给 Hangxiang 系列的素材，不由我方投递**（enable 系列整体归他；我方只发 fix-only 的 camss 0/2） |

## 1. 为什么是 A 而不是 B

- **A（采用）**：binding `interconnect-names` 收成 `ahb`,`hf_mnoc`，DTS 删掉 `sf_mnoc`/`sf_icp_mnoc` 两组 phandle。
  与驱动投票一致，DT schema 也能过（`items` 无 `minItems` 时四个名字是**全部必填**，所以 DTS 只写两条会校验失败 ⇒ binding 必须同改）。
- **B（未采用，留作备选）**：给驱动加两条投票。缺 **带宽数值与 icc tag 语义依据**（厂商 DTS/驱动无对应常量，凭空给数会被 review 打回），
  且要先确认硬件是否真需要 SF 通路；若 Hangxiang 手上有 SM8750 的 icc 表/带宽文档，B 才是功能正确的修法。
- 上游惯例允许 binding 声明比驱动更多的路径，但**已声明却从不投票**会静默不生效，属于应当消掉的歧义。

## 2. 补丁内容（对 `build/m4-base` HEAD 之上的增量）

```bash
# 应用顺序（在 Hangxiang 的 enable 系列之后）
git am patches/upstream/camss-icc-20261031/0001-dt-bindings-media-qcom-sm8750-camss-require-only-the.patch
git am patches/upstream/camss-icc-20261031/0002-arm64-dts-qcom-sm8750-drop-the-camss-interconnect-pa.patch
```

- 0001：`Documentation/devicetree/bindings/media/qcom,sm8750-camss.yaml`，`maxItems: 4→2`，names 去掉 `sf_mnoc`/`sf_icp_mnoc`。
- 0002：`arch/arm64/boot/dts/qcom/sm8750.dtsi` camss 节点，`interconnects` 4→2 组、`interconnect-names` 4→2。
- 两条都带 `Suggested-by: Shuai Liu`。

## 3. 门禁原始命令

```bash
cd build/camss-icc-wt
perl scripts/checkpatch.pl --strict --no-tree --no-signoff --patch ../../patches/upstream/camss-icc-20261031/0001-*.patch
perl scripts/checkpatch.pl --strict --no-tree --no-signoff --patch ../../patches/upstream/camss-icc-20261031/0002-*.patch
~/.local/opt/dtschema-venv/bin/dt-doc-validate Documentation/devicetree/bindings/media/qcom,sm8750-camss.yaml
make O=/tmp/icc-obj ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 qcom/sm8750-mtp.dtb
~/.local/opt/dtschema-venv/bin/dt-validate -m -s Documentation/devicetree/bindings /tmp/icc-obj/arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
```

> 说明：`build/m4-base` 里**没有** `sm8750-lenovo-elden.dts`（板级文件在我们的下游树），所以 DTB 门用上游 `sm8750-mtp.dtb`；
> camss 节点在 `sm8750.dtsi`，所有板都覆盖到。

## 4. 未做 / 风险

- 未上机验证（enable 系列本身未上机；本改动只影响 DTS 描述与 schema 必填项）。
- 若 Hangxiang 确认硬件需要 SF 通路投票，应改为 B；本素材可作为「至少先消除静默不投票」的过渡。
