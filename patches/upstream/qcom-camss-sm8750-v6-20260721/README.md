# Qualcomm camss SM8750 **v6** 基线（2026-07-21，外部件）

- 作者：Hangxiang Ma `<hangxiang.ma@oss.qualcomm.com>`（Qualcomm）
- 系列：`media: qcom: camss: Add SM8750 support`，v6，7 补丁
- patchwork series：<https://patchwork.kernel.org/series/1131656/>
- 取回方式：patchwork REST `…/series/1131656/` → 每件 `…/patch/<msgid>/mbox/`，
  本目录存的是**去掉邮件头的 body（含 diff）**，扩展名 `.diff` 以免被误当可 `git am` 的 patch。

## 件与来源

| # | Subject | Message-ID |
|---|---|---|
| 1 | dt-bindings: phy: qcom,x1e80100-csi2-phy: Add SM8750 CSI2 PHY | `<20260721-add-support-for-camss-on-sm8750-v6-1-a5f841061d18@oss.qualcomm.com>` |
| 2 | media: dt-bindings: Add CAMSS device for SM8750 | `…-v6-2-…` |
| 3 | media: qcom: camss: Add SM8750 compatible camss driver | `…-v6-3-…` |
| 4 | media: qcom: camss: csiphy: Add support for v2.3.0 two-phase CSIPHY | `…-v6-4-…` |
| 5 | media: qcom: camss: csid: Add support for CSID 980 | `…-v6-5-…` |
| 6 | media: qcom: camss: vfe: Add support for VFE 980 | `…-v6-6-…` |
| 7 | media: qcom: camss: tpg: Add support for v2.3.0 TPG | `…-v6-7-…` |

## 基线要求（为什么本目录没有可 am 的 patch）

v6 依赖 7.4 周期的 `phy/qcom,x1e80100-csi2-phy.yaml`；本机现有树
（`build/daily` = 7.3.1、`build/m3v2-7.3rc7` = 7.3-rc7、linux-next 快照）都**没有该文件**，
`git am` 在 1/7 即失败（`不存在于索引中`）。等 7.4-rc2+ 树到位后可直接重取 mbox 重放：

```bash
curl -sL 'https://patchwork.kernel.org/project/linux-media/patch/<msgid>/mbox/' -o x.patch
```

## 与本仓的关系

- 对账与处置：`reports/camss-v6-rebase-plan-20261113.md`
- 我们的自建系列（已标 superseded）：`../m4-camss-series-20261028-v2/`
- 唯一硬分歧 = CSIPHY 2.3.0（v6 复用 kaanapali）vs 2.4.0（本机 vendor 表证据）；见对账报告 §2。
