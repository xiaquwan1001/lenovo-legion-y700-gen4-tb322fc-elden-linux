# camss CSIPHY 对账：上游 kaanapali 表 vs vendor 2.4.0（B1）+ 0007 独立评估（B2）

> 只读 lane（2026-11-13 晚）。未改任何树、未发信、未上机。临时物：`/tmp/b1/`（patchwork mbox 与抽取脚本输出）。
> 数据源：patchwork REST + `build/m3v2-7.3rc7` 的 `gh/master = 9d66f26fefa`（7.4-rc3）+ 本机
> `backup/stock-elden/vendor_dlkm/camera.ko`（未 strip）。

## §0 结论（先数字）

| 问题 | 答案 | 证据 |
|---|---|---|
| 7.4-rc3 里有 `csiphy_res_kaanapali` 吗？ | **没有**。`git grep -c` = 0；camss 目录里也没有任何 `kaanapali` | `git grep -in kaanapali gh/master -- drivers/media/platform/qcom/camss/` = 空 |
| v6 patch 4 引用的 `csiphy_res_kaanapali` 从哪来？ | 来自 **kaanapali camss v15**（2026-07-21，series **1131293**）的同日系列；其定义只是 5 个 `camss_subdev_resources`（`hw_ops = csiphy_ops_3ph_1_0`），**不含 lane 表** | `/tmp/b1/kaan-v15.mbox` `v15_04.diff`（`csiphy_res_kaanapali[]` 无 `.lane_regs`） |
| 真正的 lane 表在哪？ | 已迁到 `drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c` 的 `lane_regs_x1e80100[]`，kaanapali v25 直接复用它 + `common_status_offset = 0x138` | gh/master 该文件 105 条；`p02.diff`（v25 03/15） |
| kaanapali 表 == vendor 2.4.0 吗？ | **不相等**。地址集合 103/103 相同，但 **13 个 data 字节不同**（下表） | vendor `csiphy_2ph_v2_4_0_reg`（103 条）逐条比 |
| 13 条差是版本特征吗？ | **是**。vendor 侧 v2.1.x→2.2.0 改 0x0008/0xe08（0x10→0x19），v2.3.0 再改 0x0000/0x0060（0x8e→0x8c、0xbd→0xfd）。上游 `lane_regs_x1e80100` 的值 = **vendor v2.1.2** | 18 张 2ph 表逐版本扫（见 §2.2） |
| 结论：需要 2.4.0 delta 吗？ | **需要**（13 条 data）。但**不能按现有 9 连发 0002 的形状投**：上游已把 CSIPHY 挪出 camss，delta 必须写成 phy 驱动里的新 `lane_regs_sm8750[]` | §3 |

## §1 树与对比口径

- 7.4-rc3：`build/m3v2-7.3rc7` 的 `gh/master`（`9d66f26fef`），`phy-qcom-mipi-csi2-3ph-dphy.c` 已存在（v18 driver 已 mainlined）。
- vendor 表：`csiphy_2ph_v2_4_0_reg` @ `.data` 符号 `0xa3d6c`（1648 B = 103×16），`csiphy_3ph_v2_4_0_reg` @ `0xa4a4c`（1152 B = 72×16）。`.data` 文件偏移 `0x25fab8`。
- 我们自己的表：`patches/upstream/camss-csiphy-24-20261102/0001-*.patch` 的 `lane_regs_sm8750[]`（103 条）。
- 对比键 = `(addr, data)` 多重集；另单列地址集合。

可复跑脚本（本轮的）：

```sh
cd /home/xuqianhui/y700-elden/backup/stock-elden/vendor_dlkm
readelf -sW camera.ko | grep -E 'csiphy_(2|3)ph_v2_4_0_reg|csiphy_v2_4_0'
readelf -SW camera.ko | grep ' \.data '
# python: struct.unpack('<4I', ...) 每 16 B 一条 {addr,data,mask,param_type}
git -C build/m3v2-7.3rc7 show gh/master:drivers/phy/qualcomm/phy-qcom-mipi-csi2-3ph-dphy.c
```

## §2 差集表

### §2.1 上游 `lane_regs_x1e80100`（= kaanapali 实际使用的表）vs vendor `csiphy_2ph_v2_4_0_reg`

| 偏移 | 上游（2.1.2 值） | vendor 2.4.0 | 出现次数 |
|---|---|---|---|
| `0x0000 / 0x0400 / 0x0800 / 0x0c00` | `0x8e` | `0x8c` | 4 |
| `0x0008 / 0x0408 / 0x0808` | `0x10` | `0x19` | 3 |
| `0x0e08` | `0x10` | `0x19` | 1 |
| `0x0060 / 0x0460 / 0x0860 / 0x0c60` | `0xbd` | `0xfd` | 4 |
| （上游多出）`0x1018 / 0x101c` | `0x01` / `0x7a` | 表中无（上电序列，camss 侧另走） | 2 |

⇒ **13 条 data 差**（3 值 × 4 lane，加 1 条 `0x0e08`）；地址集合 103/103 相同。
类型分布：vendor 103 = 82 DEFAULT / 16 SKEW_CAL / 5 SETTLE；上游 105 = 84 / 16 / 5（多的 2 条是 DEFAULT 上电项）。

### §2.2 13 条是不是「2.3.0/2.4.0 版本特征」——是

对 `camera.ko` 全部 `csiphy_2ph_*_reg`（不含 combo_mode）逐版本取值：

| 版本 | 0x0000 | 0x0008 | 0x0060 | 0x0e08 | 0x005c(SKEW) |
|---|---|---|---|---|---|
| v2.1.0 / 2.1.1 / 2.1.3 | 0x8e | 0x10 | 0xbd | 0x10 | 0x00 |
| v2.1.2 | 0x8e | 0x10 | 0xbd | 0x10 | **0x04** |
| v2.2.0 / 2.2.1 | 0x8e | **0x19** | 0xbd | **0x19** | 0x04 |
| v2.3.0 / 2.4.0 / 2.4.1 | **0x8c** | 0x19 | **0xfd** | 0x19 | 0x00 |

⇒ 上游 `lane_regs_x1e80100` 与 **v2.1.2** 完全一致（仅 SKEW 0x005c 取 0 而非 0x04，且多 2 条上电项）；
**「SM8750 复用 kaanapali」在数据上等于复用一张 v2.1.2 表**。v6 patch 4 的措辞「v2.3.0」与
v25 的实际内容（v2.1.2 值 + 0x138 状态偏移）也不一致。

补充：我们的 `lane_regs_sm8750` 与 vendor **2.4.0 逐条一致（103/103 地址+数据+掩码）**，唯一偏离是 4 条
SKEW_CAL `0x005c/0x045c/0x085c/0x0c5c = 0x54`（vendor 0x00）；这一条 11-13 之前的取证已记录
（`reports/m4-csiphy-vendor-provenance-20261027.md` §2），实测 90 帧无差异。

### §2.3 3ph 变体

vendor `csiphy_3ph_v2_4_0_reg` = 72 条，地址体系从 `0x294/0x2f4/0x2f8` 起，与 2ph 表完全不同；
上游没有任何 3ph lane 表（`phy-qcom-mipi-csi2-3ph-dphy.c` 的 `lane_regs_x1e80100` 注释写明是 2PH 模式）。
本机 SM8750 走两相接线（出图用的是 2ph 表）⇒ 3ph 表**不进 delta**。

## §3 结论与建议形状

1. **需要 2.4.0 delta**，内容是 13 个 data 字节；不是「103 条新表」。
2. 现有 `patches/upstream/camss-csiphy-24-20261102/` 的形状（camss `csiphy_ops_3ph_1_0` 里加
   `lane_regs_sm8750` + `CAMSS_8750` 分支）**已过时**：上游自 v15/v18 起 CSIPHY 是独立 phy 驱动，
   SM8750 若照 v6 接 kaanapali，走的也是该驱动。
3. 建议后续（不本轮做）改成：
   `phy-qcom-mipi-csi2-3ph-dphy.c` 新增 `lane_regs_sm8750[]`（= vendor 2.4.0，SKEW 取 vendor 0x00 或
   0x54 需二选一并给实测）+ `mipi_csi2_dphy_3nm_sm8750` cfg（`common_status_offset = 0x138`）+
   `qcom,sm8750-csi2-phy` compatible（或挂到 v6 的 SM8750 线程里作为增量）。
4. **对 v6 的公开口径**：不质疑「复用 kaanapali」的架构（v25 已定型），只给数据差集——13 条 data
   与 v2.1.2 表不同、且 vendor 2.3.0/2.4.0 都这样；附带 2.3.0 vs 2.4.0 在 lane 数据上无差这一事实，
   把讨论从「版本号」拉回「值」。

## §4 B2：camss 0007（起流失败回退）独立评估

- 补丁本体 = `patches/upstream/m4-camss-fixes-20261029/0003-*.patch`（与 9 连发 `0007` 逐字相同；
  该 3 枚系列 2026-10-29 已投并归档）。
- 依赖面：只改 `drivers/media/platform/qcom/camss/camss-video.c`，不碰 binding / SoC 资源表 /
  CSIPHY ⇒ **可完全脱离 9 连发独立成立**。
- 门禁（本轮实跑）：
  - `git apply --check` 于 `build/m3v2-7.3rc7`（7.4-rc2 + 板级 DTS）→ **rc=0**；
  - `build/daily`（7.3.1 + payload v2）→ **rc=1**（`camss-video.c:265`，payload 改过该函数）——
    预期，与「可选 9 条」里 camss 四连的冲突同源；
  - `checkpatch --strict --no-signoff`（在 `geekidos-linux` 树内跑，避免 `--no-tree` 的假阳性）→
    **0E/0W/0C，89 行**。
- 结论：**可投（独立单枚，不随 v6）**；投前只需在 7.4 树上重编 `drivers/media/platform/qcom/camss/`
  并上机出流一次。当前状态 = 已在 10-29 投出且无 reviewer 反对 ⇒ 建议**不重投**，只在 v6 线程里
  提一句「这条已单独在审」。
