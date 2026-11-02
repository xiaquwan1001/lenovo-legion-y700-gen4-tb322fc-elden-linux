# M8 mdss v3（2026-11-02）：去 RSCC + 去长注释

- **状态**：🟢 **已投递**（用户已批准本批投递）。投递记录与回读见 `sent/`；证据表 `claims.tsv`。
- **与 v2 的差异**（`patches/upstream/q28-dispcc-v2-20261029/` = 已是 0/3 归档的上一版）：
  1. `0001` binding：`resets` 的 `items` 由三项降到**两项**（MDSS core + MDSS core INT2），
     example 同步两项；`minItems: 1` 保留 ⇒ 单复位 DT 仍合法（实测见 `claims.tsv` V15）。
  2. `0002` driver：**删掉 `msm_mdss_reset()` 上方新增的长注释**（Dmitry 10-31 意见），
     其余机制不变（仍是 `devm_reset_control_array_get(..., RESET_CONTROL_OPTIONAL_EXCLUSIVE)`）；
     changelog 同时去掉 RSC 表述。净 diff 由 +12/−3 收到 **+2/−3**。
  3. `0003` dtsi：`resets` 只留 `DISP_CC_MDSS_CORE_BCR` + `DISP_CC_MDSS_CORE_INT2_BCR`。
- **形状没改的部分**（如实标注）：复位时机仍是 mdss probe（dispcc 编程 PLL 之后）；
  API 仍是数组取复位；`dispcc-sm8750.c` 仍零改动。
- **门禁（2026-11-02 本轮，全部实跑）**：见 `GATES.md`。
- **证据强度自审**：只删复位项 + 删注释，不改 API ⇒ 不需要新上机。cover 里如实写了
  ①运营线 8/8 无坏发覆盖保留的两项；②mdss 侧位置**历史上已上机**（5/5 真 POR + 2/2 暖复位）；
  ③明确「不声称做了新 A/B」「v3 形状未上机」。**未声称 RSCC 是/不是 load-bearing**（无法静态判定）。
- **残余风险**：`claims.tsv` G1（array+EXCLUSIVE 在 2026-10-23 形态下曾 -EBUSY，v3 未复测）、
  G2（20 ms 保持时长对两项是否足够未测）。
- **文件**：`0000-cover-letter.patch` + `0001..0003`（`git format-patch --subject-prefix="PATCH v3"` 产物，
  非手写）、`claims.tsv`、`GATES.md`、`sent/`。
