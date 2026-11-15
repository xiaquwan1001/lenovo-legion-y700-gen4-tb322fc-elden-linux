# camss CSIPHY SM8750 2.4.0 delta → 可投递补丁（本轮备料）

> lane：2026-11-15，主机侧备料。**未发信、未上机、未改 `build/` 功能树**。上游基线 = `gh/master`
> `9d66f26fef`（7.4-rc3）。产物：`patches/upstream/camss-csiphy-24-20261115/`
> （`0001`/`0002`/`README.md`/`GATES.md`/`logs/`）。规格书 = `reports/camss-csiphy-v6-vs-240-20261113.md` §0/§2.1/§3。

## §1 结论（先数字）

| 问题 | 答案 | 证据 |
|---|---|---|
| patch 成形了吗 | **成形**：2 枚系列（binding + 驱动），`git apply --check` 于 gh/master blob **rc=0** | `GATES.md` §1 |
| 13 条 data 差全覆盖吗 | **13/13**，且新表与 vendor `csiphy_2ph_v2_4_0_reg` **103/103 (addr,data,type) 全等** | `logs/40-table-diff.txt` |
| 门禁 | ①rc=0 ②**0E/0W/0C**×2 ③`W=1` rc=0 0 warning ④`dt_binding_check` rc=0 | `GATES.md` |
| 能直接投吗 | **还不能**：① binding 与在飞的 v6 1/7 撞同一段 `oneOf`；② 需一次上机出流回归；③ 净行为只有 4 个字节，得先在 v6/kaanapali 线程里问过口径 | §4 |
| 与上一版备料（`camss-csiphy-24-20261102`）的关系 | 那枚是 **camss 侧** `csiphy_ops_3ph_1_0` 形状，**已过时**（上游把 CSIPHY 挪成独立 phy 驱动）；本枚重写到 phy 驱动 | §2 |

## §2 形状：为什么重写、写成什么样

上游自 v15/v18 起 CSIPHY 是独立 phy 驱动（`drivers/phy/qualcomm/phy-qcom-mipi-csi2-{core,3ph-dphy}.c`
+ `.h`）。选表路径两条：`of_match_table` 用 compatible 选 `mipi_csi2phy_soc_cfg`
（`device_get_match_data()`），cfg 里 `reg_info.init_seq` 指向 lane 表。x1e80100 与 SM8750 的
supplies/clocks/genpds 完全同构（对照 v6-0002 的 `csiphy0` 节点：`vdda-0p9`/`vdda-1p2`、
`core`/`timer`/`ahb`、`top`/`mmcx`/`mx`），差别只在 lane 表 ⇒ 新增一张表 + 一个 cfg + 一个 compatible。

SM8750 的 DT 用 `compatible = "qcom,sm8750-csi2-phy", "qcom,kaanapali-csi2-phy";`，设备 compatible
按序匹配 ⇒ `qcom,sm8750-csi2-phy` 命中本枚 cfg，不会落到 kaanapali/x1e 的 cfg。

两枚的分工：

- `0001`：binding 加 `qcom,sm8750-csi2-phy`（独立 const，进 `oneOf` 的 enum）。
- `0002`：`lane_regs_sm8750[]`（105 条 = 2 条 2ph 上电 + 103 条 vendor 2.4.0）
  + `mipi_csi2_dphy_3nm_sm8750` cfg + match 项 + 头文件 `extern`。

（占位：§3 起追加）
## §3 数据：13 条差的三组，以及「只有 4 条真的生效」

地址集合 103/103 相同，`(addr,data,type)` 只有 13 条不同（`GATES.md` §5 原始输出）：

| 组 | 寄存器 | 上游 x1e80100 | vendor 2.4.0 | 条数 | 类型 | 当前驱动是否写入该值 |
|---|---|---|---|---|---|---|
| A | `0x0000/0x0400/0x0800/0x0c00` | `0x8e` | `0x8c` | 4 | DEFAULT | **是**（唯一实际生效） |
| B | `0x0008/0x0408/0x0808/0x0c08/0x0e08` | `0x10` | `0x19` | 5 | SETTLE_CNT_LOWER_BYTE | 否：被运行时算出的 `settle_cnt` 覆盖 |
| C | `0x0060/0x0460/0x0860/0x0c60` | `0xbd` | `0xfd` | 4 | SKEW_CAL | 否：`gen2_config_lanes()` 里 `continue`（代码留着 `TODO: support application of skew from dt flag`） |

**规格书 §2.1 的表格漏了 `0x0c08`**（它把 B 组写成 `0x0008/0x0408/0x0808` 3 条 + `0x0e08` 1 条，
但 B 组实际是 5 条；表里「13 = 3×4 + 1」的算式因此对不上）。按 vendor 二进制逐条比对，13 条的
准确构成是 4+5+4。本轮的 `verify-table.py` 直接对 `readelf` 出的 vendor 表比对，不再靠手抄。

结论性事实（必须写进 cover，否则评审会以为这枚改了行为）：**净行为 = 4 个 lane 的 `0x0000`
从 `0x8e` 变 `0x8c`**；B 组 5 条与 C 组 4 条在当前驱动下不下发。表里仍保留 vendor 值，理由是
(i) 与 vendor 表逐条可对二进制，(ii) skew 支持一旦落地（`TODO` 那条）值就是现成的。

SKEW 的 `0x005c` 取 vendor `0x00`（上一版备料取 `0x54`）：SKEW 行当前根本不写，偏离 vendor 无依据；
取 `0x00` 后新表与 vendor 表 103/103 全等，评审成本最低。`0x54` 的 90 帧实测仍作为旁证留在
`patches/upstream/camss-csiphy-24-20261102/` 的 cover 里，不搬进本枚。
## §4 仍需上游确认 / 仍不能投递的点

| # | 点 | 判据/处置 |
|---|---|---|
| 1 | **binding 与在飞的 v6 1/7 撞同一段** | `patches/upstream/qcom-camss-sm8750-v6-20260721/v6-0001.diff` 把同一 `oneOf` 改成 `sm8750 + kaanapali` 两项 fallback 形状；本枚 `0001` 是「独立 const」。二者只可存一个 ⇒ **投递前先看 v6 是否已进 tree**；若 v6 先落，本枚 `0001` 直接丢掉、`0002` 的 compatible 沿用 v6 的即可（`0002` 不用改）。 |
| 2 | **common status 窗口 `0x138`** | 3nm SM8750 与 kaanapali 一样在 `0x1000+0x138`（x1e80100 在 `+0xb0`）。该窗口只用于 `dev_dbg()` 打 hw_version；本枚**故意不加** `common_status_offset` 字段，避免和在飞的 kaanapali v25 `p01`（把硬编码 `0xb0` 改成 per-SoC 字段）重复。kaanapali 落地后此处补一行 `.common_status_offset = 0x138` 即可。**这是本枚唯一「已知不完整」的硬件描述**。 |
| 3 | **2ph 上电两条 `0x1018/0x101c`** | vendor 表没有（在别的序列里），但本驱动 `init_seq` 只有一张表。若评审认为 3nm 件不需要，删掉即可（不影响 13 条口径）。 |
| 4 | **上机回归** | 本 lane 不上机。净行为只有 4 字节，仍需一次 30fps 出流（`s5kjns` 后摄 + `gc08a8` 前摄）确认；历史上 `0x8e`/`0x8c` 两值都能出图（`reports/m4-csiphy-vendor-provenance-20261027.md`），所以这枚严格说是**数据保真**而非修 bug——cover 里不要宣称「修复」。 |
| 5 | **3ph 表** | 本机两相接线，`csiphy_3ph_v2_4_0_reg`（72 条、地址体系完全不同）不进本系列。 |
| 6 | **基线可编译性** | `build/m3v2-7.3rc7` 的 pack 有 3 个坏 object ⇒ 拿不到完整 7.4-rc3 树；编译门禁是在「7.3-rc7+payload 树 + gh/master 的四个被改文件」上跑的（`GATES.md` §0）。**判据强度：对这四个文件成立，对整棵 7.4-rc3 未验证。** 若要更硬的证据，需重新 clone/fetch 一份 7.4-rc3（本 lane 未做，避免大下载）。 |

## §5 产物与复跑

```
patches/upstream/camss-csiphy-24-20261115/
├── 0001-dt-bindings-phy-qcom-x1e80100-csi2-phy-add-SM8750-CS.patch   (3+/1-)
├── 0002-phy-qcom-mipi-csi2-add-SM8750-2.4.0-lane-settings.patch      (138+)
├── README.md   动机 / 两版本差异 / 三条必读事实 / 待确认项 / 复跑命令
├── GATES.md    四条门禁 + 表对账的原始输出、基线限制、踩过的 style 坑
└── logs/       00..40 原始日志 + verify-table.py（可复跑的对账脚本）
```

复跑入口：`GATES.md` §0 的树准备 + `README.md` 末尾命令块。临时物 `/tmp/csiphy-{git,build,out,src}`、
`/tmp/base-*`、`/tmp/new-*` 均可删；`build/m3v2-7.3rc7` 全程零改动（`git status` 里没有本系列的 4 个文件）。

## §6 一句话

13 条 data 差已做成 2 枚可 `git am` 的补丁并通过四条门禁（0E/0W/0C、`W=1` 无 warning、binding 检查绿），
**但投递闸门是 v6 的 binding 归属 + 一次上机回归**，本 lane 按纪律只备料不发。

