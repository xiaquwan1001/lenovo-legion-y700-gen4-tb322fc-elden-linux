# M8 dispcc v2：MDSS 块复位迁到显示侧（2026-10-29，未上机草案）

- **状态**：🟡 **静态产物，未上机；已发送**（2026-10-29 12:32Z，MID `20261029123238.29877-1..4`，见 `reports/mail-triage-20261030.md` §1；后续 v3 见 `../m8-mdss-v3-20261102/`）。本目录是 lane C2 的 v2 补丁草案（响应
  Taniya Das 对 v1 的否决），疗效待真机冷起 A/B 复测后才可投递（开放问题 1）。
  证据与论证：`reports/m8-dispcc-v2-20261029.md`（§1 输入盘点 / §5 顺序约束 / §6 开放问题）。
- **基点**：pristine `Linux 7.3-rc7`（`24a19b953e`），工作树 `build/m8-dispcc-v2`。
- **形状**：三枚补丁，把 `DISP_CC_MDSS_CORE_BCR` / `CORE_INT2_BCR` / `RSCC_BCR`
  三个 MDSS 块复位从 clk driver 迁到显示侧既有 `msm_mdss_reset()` 路径：
  1. `0001` dt-bindings: `mdss-common.yaml` 的 `resets` 改为 **`minItems: 1` + 三项 `items`**
     （**不能写 `maxItems`**：array-form `items` 下 meta-schema 明确禁止，且列表长度 3 自带
     `minItems: 3` 语义 ⇒ 必须显式 `minItems: 1` 才能让单复位的老平台 DT 继续合法；
     修前/修后输出见 `GATES.md` §6）；`qcom,sm8750-mdss.yaml` example 同步列三复位；
  2. `0002` drm/msm: `msm_mdss_reset()` 改用 `devm_reset_control_array_get(…,
     RESET_CONTROL_OPTIONAL_EXCLUSIVE)`，按 DT 全组 assert → 20 ms → deassert；
     clk driver（`dispcc-sm8750.c`）**零改动**；无复位平台与单复位平台行为不变；
  3. `0003` arm64: dts: sm8750 mdss 节点 `resets` 列全三 BCR。
- **与 v1（`q28-dispcc-2026-10-22`，已否决作废）的差异**：
  - 职责归位：复位由显示 SW 驱动（否决点 ①），clk driver 改动 35 行 → 0；
  - 不再触碰 dispcc 整块复位/PLL 重配（否决点 ②）：BCR 只复位 MDSS 块，
    PLL 寄存器与锁定状态不变；
  - 板级门控 `of_machine_is_compatible("lenovo,elden")` 删除，改 DT 描述
    （上游 sm8650/sm8750 等本就在 mdss 挂 dispcc 复位，此为惯例延伸）；
  - 复位时刻由「dispcc probe、PLL 编程**之前**」变为「mdss probe、PLL 编程**之后**」
    ——与 A/B 有效臂不同的新假设，未上机验证（见下）。
- **门禁（2026-10-29 全绿）**：
  - `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- drivers/gpu/drm/msm/ -j26`
    （`LOCALVERSION=` 空，msm 目录产物删净强制重编）：rc=0，0 warning / 0 error；
  - `checkpatch.pl --strict`：三枚均 0 errors / 0 warnings / 0 checks；
  - pristine 7.3-rc7 逐枚 `git am`：全干净无 fuzz；
  - binding 校验（致命版，dtschema venv）：`doc_validate`（两 yaml）/
    `dt-validate`（example vs processed-schema）/ `dt-check-style` 均 rc=0；
    注意 7.3-rc7 的 `make dt_binding_check` 校验步全带 `\|\| true`，其 rc=0 不构成证据；
- **留给上游的开放问题（≤3，详见报告 §6）**：
  1. 疗效等价性未上机：v2 复位时刻（PLL 后）与 A/B 验证过的时刻（PLL 前）不同，
     INT2/RSCC 在 PLL 后复位能否治 cold-boot command DMA 超时，需真机 A/B；
  2. 其他平台（sm8650 同款三 BCR；sc7180/sc7280/sc8280xp/sm6350/sm8150 有 RSCC_BCR）
     是否跟进列全，留维护者拍板，本系列只动 sm8750；
  3. 全组复用既有 20 ms 保持时长是否足够（v1 曾用 50 ms）。
- **纪律**：不发送邮件；基于 pristine 7.3-rc7；产品不含任何未公开信息。
