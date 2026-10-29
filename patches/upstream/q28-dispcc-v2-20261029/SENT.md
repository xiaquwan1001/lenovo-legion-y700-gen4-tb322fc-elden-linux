# 投递记录（2026-10-29 20:32 +0800，用户批准）

- 系列：`[PATCH v2 0/3] drm/msm/mdss: reset all MDSS block resets described in DT`
  （v1 = 2026-10-22 的 RFC，已被 Taniya Das 否决形状；本 v2 为替代件）
- **To**：`linux-arm-msm@vger.kernel.org`、`dri-devel@lists.freedesktop.org`
- **Cc**：Rob Clark `<robin.clark@oss.qualcomm.com>`、Dmitry Baryshkov `<lumag@kernel.org>`、
  Abhinav Kumar `<abhinav.kumar@linux.dev>`、Jessica Zhang `<jesszhan0024@gmail.com>`、
  Sean Paul `<sean@poorly.run>`、Marijn Suijten `<marijn.suijten@somainline.org>`、
  Rob Herring `<robh@kernel.org>`、Krzysztof Kozlowski `<krzk+dt@kernel.org>`、
  Conor Dooley `<conor+dt@kernel.org>`、Bjorn Andersson `<andersson@kernel.org>`、
  Konrad Dybcio `<konradybcio@kernel.org>`、Taniya Das `<taniya.das@oss.qualcomm.com>`、
  `devicetree@vger.kernel.org`、`linux-kernel@vger.kernel.org`
- 投递方式：`git send-email`，4 封 **`Result: 250`**
- Message-ID：
  - `20261029123238.29877-1-xiaqinghuan@mail.ustc.edu.cn`（v2 0/3 cover）
  - `20261029123238.29877-2/-3/-4-xiaqinghuan@mail.ustc.edu.cn`（1/3、2/3、3/3）
- **lore 归档复核**：`/all/` **4/4 HTTP 200**，封面 Subject/From 逐字核对通过
- cover 里如实写明：**未上机**；复位时刻在 PLL 编程之后（与实测有效的臂不同）是开放点，
  请 reviewer 直接否掉若不成立；只有 SM8750 改动，其他平台留给各自 maintainer
- 门禁见 `GATES.md`（pristine `git am` 3/3、checkpatch 3/3、msm `W=1` 0 warning、
  `dt-doc-validate`/`dt-validate`（3 复位与 1 复位两态）/`dt-check-style` 全 rc=0）
- 待办：盯 review；**上机 A/B 未做**（真 POR ≥5 发，判据见 `GATES.md` §5）
