# B1 复核：camss CSIPHY 2.4.0 对账（实证，2026-11-13 夜）

> 本轮 = 对 `reports/camss-csiphy-v6-vs-240-20261113.md`（B1 原始报告）做**独立复跑与纠偏**。
> 全部只读主机侧，**未改任何树、未上机、未发信**。可复跑脚本见 §4。

## §0 结论（先数字，四条）

1. **「需要 2.4.0 delta」这个待办已经不存在** —— `build/daily`（现役功能树）里 `CAMSS_8750` 走的就是
   `lane_regs_2_4_0[]`（`camss-csiphy-3ph-1-0.c:1380-1386`，`offset=0x1000`、`common_status_offset=0x138`），
   该表由**我们自己的 payload v2**（`88cd0bc0f4f`）引入（上游 7.3.1 `grep -c lane_regs_2_4_0` = **0**）。
   ⇒ B1 报告 §3「需要 2.4.0 delta，13 个 data 字节」对**上游树**成立，对**我们的树已无动作**。
2. **实证对账：103/103 条地址集合完全相同，数据只剩 4 条分歧** —— 与 vendor `csiphy_2ph_v2_4_0_reg`
   逐条比（按地址归组、data 多重集比较）：地址集合 `set()` **相等**（94 个唯一地址）；
   唯一分歧 = 4 条 SKEW_CAL（`0x005c/0x045c/0x085c/0x0c5c`），**我们 `0x54`、vendor `0x00`**。
   这与 `reports/m4-csiphy-vendor-provenance-20261027.md` §2 的记录一致（且当时实测 90 帧无差异）。
3. **`CAMSS_8750` 在我们的树里是完整使能的**（`camss.c:6090` 起 `csiphy_res_8750`/`csid_res_8750`/
   `vfe_res_8750`/`icc_res_sm8750` 全齐，`camss-csiphy-3ph-1-0.c:1259` 支持列表含 `CAMSS_8750`）。
   ⇒ B1 报告里「公开树里没有任何 SM8750 表项 ⇒ 单投时评审会问 who sets CAMSS_8750」这条**只对上游成立**，
   对我们自己的树不构成缺口。
4. **形状问题是真的，但只影响「要不要把它投给上游」** —— 上游 7.4 已把 CSIPHY 从 camss 拆成独立
   `drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c`（`gh/master` 现查有 `lane_regs_x1e80100`，
   camss 目录仍留 2ph/3ph 文件但不再是唯一实现）。我们这张表在 camss 里，投上游就得改成 phy 驱动形状。
   **但这不阻塞我们自己用**（第 1 条已证在役可用）。

## §1 上游 vs 我们的树：差在哪（这是 A9 的真正判断依据）

| 项 | 上游 7.4-rc3 (`gh/master` `9d66f26fef`) | 我们的 `build/daily` (7.3.1 + payload v2) |
|---|---|---|
| CSIPHY 归属 | `drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c`（独立 phy 驱动） | camss 内 `camss-csiphy-3ph-1-0.c` |
| SM8750 lane 表 | **无**（`csiphy_kaanapali` 也未进 camss，`git grep -c` = 0） | **有** `lane_regs_2_4_0[]`（103 条） |
| `CAMSS_8750` 资源表 | **无**（`camss_resources[]` 无该项） | **有**（`camss.c:6090`） |
| 表值来源 | kaanapali v25 用 `lane_regs_x1e80100[]`（= vendor **v2.1.2** 值） | vendor **v2.4.0** 值（+ 4 条 SKEW=0x54） |

⇒ **A9「camss 接 Qualcomm v6 后上机验证出流」的前提要重写**：不是「先做 B1 对账再决定带不带 2.4.0 delta」，
而是「**我们已经有 2.4.0 且在役**；接 v6 反而是**降级到 v2.1.2 表 + 等上游补 `CAMSS_8750` 资源表**」。
这一点必须在动 A9 之前讲清，否则会拿一个已经工作的东西去换一个上游还没接受的。

## §2 那 4 条 SKEW_CAL 要不要改

- 现状：我们 `0x54`（84）、vendor `0x00`。SKEW_CAL 语义 = 校准延迟，值越大校准窗口越长。
- 已有证据：`reports/m4-csiphy-vendor-provenance-20261027.md` §2 记「实测 90 帧无差异」。
- 本轮不改（没有新证据支持改，且改它需要上机出流对比，属 C-U 类）。
- 若要收敛，最小动作 = 单变量改成 `0x00` 出一版镜像，跑 `camera-stream-up.sh` 前后摄各 90 帧比对；
  判据不足就不要动（现状工作，动它只为民意）。

## §3 对后续任务的影响

- **A9（camss v6 上机）**：优先级下调 —— 它不再是「把相机弄到上游形态」的必经步骤，反而是功能降级路径。
  真要投上游，正确顺序是「先在 phy 驱动形状里加 `lane_regs_sm8750` + `qcom,sm8750-csi2-phy`，
  再谈接 v6」。
- **B2（camss `0007` 起流失败回退独立评估）**：不受影响，仍可独立做（v6 不碰 `camss-video.c`）。
- **上游发信**：本轮不产生新发信素材（结论是「我们没有欠账」），不需要用户批准。

## §4 可复跑（本轮的实证脚本）

```sh
cd /home/xuqianhui/y700-elden
# 1) 我们树里的表（103 条 / 82 DEFAULT + 16 SKEW + 5 SETTLE）
grep -c "CSIPHY_" build/daily/drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c
sed -n '809,925p' build/daily/drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c
# 2) CAMSS_8750 走 2.4.0 表 + 资源表齐备
sed -n '1380,1387p' build/daily/drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c
sed -n '6088,6100p' build/daily/drivers/media/platform/qcom/camss/camss.c
# 3) 上游 7.3.1 确实没有（证明是我们 payload 加的）
git -C build/daily show 79a907609d:drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c | grep -c lane_regs_2_4_0   # = 0
# 4) 与 vendor .ko 逐条比（脚本见 reports/artifacts/b1-csiphy-20261113/diff.py）
python3 reports/artifacts/b1-csiphy-20261113/diff.py
```

## §5 与 B1 原始报告的差异（纠偏清单）

| B1 原报告 | 本轮实证 | 处置 |
|---|---|---|
| 「需要 2.4.0 delta，13 个 data 字节」 | 我们树**已有** 2.4.0，delta 只对上游成立 | 本条从「待办」改为「上游侧素材」 |
| 「现有 `camss-csiphy-24-20261102/` 形状已过时」 | 正确（上游已拆 phy 驱动） | 保留 |
| 「13 条 data 差」 | **实证是 4 条**（SKEW_CAL），其余 9 条我们的表已与 vendor 一致 | **纠正** |
| 「SM8750 复用 kaanapali = 复用 v2.1.2 表」 | 对上游成立；我们不用 kaanapali 路径 | 保留（口径限定到上游） |
