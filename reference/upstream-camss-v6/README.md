# reference/upstream-camss-v6 — 上游 Qualcomm SM8750 CAMSS v6（只读参考件）

**来源**：lore.kernel.org 公开归档，2026-07-21 投递；`[PATCH v6 0/7] media: qcom: camss: Add SM8750 support`，
Message-ID `20260721-add-support-for-camss-on-sm8750-v6-N-a5f841061d18@oss.qualcomm.com`（N=0..7）。

**不要改动本目录**：这是取证快照，用于与我方 `patches/upstream/m4-camss-series-*/` 对照。

## 取回命令（可复跑）

```
scripts/lore-fetch-raw.py all $(for i in $(seq 0 7); do \
  echo "20260721-add-support-for-camss-on-sm8750-v6-$i-a5f841061d18@oss.qualcomm.com"; done) \
  -o reference/upstream-camss-v6
```

## 布局

| 路径 | 内容 |
|---|---|
| `0000…0007-*.patch` | 原始 `/raw`，未改。因交叉投递到 linux-media + linux-phy，**每封内含两份副本** |
| `single/` | 每封的单副本（切掉重复的那份），供 `diff` / `git am` / 行号核对使用 |

## v6 的 7 枚（及 3 条未合并依赖）

1/7 phy binding `qcom,x1e80100-csi2-phy` 加 SM8750 · 2/7 `qcom,sm8750-camss.yaml`（**split-csiphy** 模型）·
3/7 camss compatible · 4/7 csiphy v2.3.0（**仅 +2 行**，PHY 交给外部 phy 驱动）· 5/7 **CSID 980**（新文件）·
6/7 VFE 980（+11 −3，实体在 kaanapali v15 的 `camss-vfe-gen4.c`）· 7/7 TPG v2.3.0。

依赖（未合并）：x1e-csi2-phy v13、x1e80100-camss dtsi v12、**kaanapali camss v15**。
v6 明确**不含 DTS**（另由 `pakala-camera v2` 2026-06-18 承担）。

对照结论见 `reports/camss-v3-vs-upstream-v6-20261029.md`。
