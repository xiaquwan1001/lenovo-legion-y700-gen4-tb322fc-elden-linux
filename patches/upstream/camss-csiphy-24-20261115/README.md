# phy: qcom: mipi-csi2: SM8750 CSIPHY 2.4.0 lane 表 —— 2 枚系列，**备料，不发**

- 基线：上游 `gh/master` = **`9d66f26fef`（Linux 7.4-rc3）**，`drivers/phy/qualcomm/` 下 CSIPHY 已是
  独立 phy 驱动（`phy-qcom-mipi-csi2-3ph-dphy.c` / `-core.c` / `.h`，v18 已 mainline）。
- 规模：2 枚，`git diff --stat` = **4 files changed, 141 insertions(+), 1 deletion(-)**
  （`0001` = binding 3+/1-；`0002` = 驱动 3 文件 138+，其中 `lane_regs_sm8750[]` 表 128 行 + cfg 16 行 + match/extern 各 1 行）。
- 内容：`0001` = 绑定额外 compatible `qcom,sm8750-csi2-phy`；`0002` = 新增 `lane_regs_sm8750[]`
  （105 条 = 2 条 2ph 上电 + **103 条 vendor 2.4.0 表**）+ `mipi_csi2_dphy_3nm_sm8750` cfg + match 项。

## 动机（为什么要这张表）

上游 `lane_regs_x1e80100[]` 注释自称 “4nm 2PH v 2.1.2”，**数据上确实等于 vendor 的 v2.1.2**；
vendor 自 v2.2.0/v2.3.0 起改了 SM8750 这张 2ph 表的值。逐版本取证见
`reports/camss-csiphy-v6-vs-240-20261113.md` §2.2（18 张 `csiphy_2ph_*_reg` 逐版本扫）：

| 版本 | `0x0000` | `0x0008` | `0x0060` |
|---|---|---|---|
| v2.1.x（= 上游 x1e80100 表） | `0x8e` | `0x10` | `0xbd` |
| v2.2.0 / 2.2.1 | `0x8e` | `0x19` | `0xbd` |
| **v2.3.0 / 2.4.0 / 2.4.1（SM8750 本机）** | **`0x8c`** | **`0x19`** | **`0xfd`** |

即：SM8750 若直接复用 x1e80100 表，等于用 v2.1.2 的 lane 值跑 2.4.0 的 PHY。

## 两版本差异：13 条 data（地址集合 103/103 完全相同）

`logs/40-table-diff.txt` 的实测（`verify-table.py` 直接比对 vendor `csiphy_2ph_v2_4_0_reg` 与上游表）：

| 寄存器 | 上游 x1e80100（v2.1.2） | SM8750（vendor 2.4.0） | 条数 | 类型 |
|---|---|---|---|---|
| `0x0000 / 0x0400 / 0x0800 / 0x0c00` | `0x8e` | `0x8c` | 4 | DEFAULT（**唯一被驱动的常量写**） |
| `0x0008 / 0x0408 / 0x0808 / 0x0c08 / 0x0e08` | `0x10` | `0x19` | 5 | SETTLE_CNT_LOWER_BYTE |
| `0x0060 / 0x0460 / 0x0860 / 0x0c60` | `0xbd` | `0xfd` | 4 | SKEW_CAL |
| | | | **13** | |

三点必须写进 cover/README，否则评审会误判「这枚改了行为」：

1. **13 条里只有 4 条在当前的驱动代码下真正生效**：`phy_qcom_mipi_csi2_gen2_config_lanes()` 对
   `CSIPHY_SETTLE_CNT_LOWER_BYTE` 写入运行时算出的 `settle_cnt`（5 条表值被覆盖），对
   `CSIPHY_SKEW_CAL` 直接 `continue`（4 条被跳过，代码里还留着 `TODO: support application of skew
   from dt flag`）。所以这枚的**净行为**是 4 个 lane 的 `0x0000` 写从 `0x8e` 变 `0x8c`。
2. **表里 SKEW 的 `0x005c` 取 vendor 的 `0x00`**，不用上一版备料里的 `0x54`：既然 SKEW 行当前根本
   不下发，「偏离 vendor」没有依据；取 `0x00` 后本表与 vendor 表 **103/103 (addr,data,type) 多重集全等**
   （`logs/40-table-diff.txt`），评审可直接对二进制比对。`0x54` 的 90 帧实测（
   `patches/upstream/camss-csiphy-24-20261102/` cover 里那段）保留为旁证，不进本枚。
3. **103 条 vendor 表 + 2 条 `0x101c=0x7a`/`0x1018=0x01` 2ph 上电写** = 105 条。vendor 表把这
   两条放在别的序列里；本驱动 `init_seq` 只有一张表，去掉它们 SM8750 的 lane 起不来
   （上游 x1e80100 表同样带这两条）。所以 `lane_regs_sm8750[]` 与 `lane_regs_x1e80100[]` **逐行同构、
   只差上表 13 个 data 字节**。

## 为什么是「新表 + 新 cfg + 新 compatible」而不是改 x1e80100

`mipi_csi2phy_soc_cfg` 用 `init_seq` 指针选表，`of_match_table` 用 compatible 选 cfg（
`device_get_match_data()`）；x1e80100 还在用同一张表，不能就地改。SM8750 的 DT 节点（
`qcom-camss-sm8750-v6` 系列 v6-0002 `sm8750.dtsi`）写的是
`compatible = "qcom,sm8750-csi2-phy", "qcom,kaanapali-csi2-phy";`，
设备 compatible 列表按序匹配，`qcom,sm8750-csi2-phy` 命中本枚新增的 cfg。

## 已知待上游确认 / 本枚故意不做

| 项 | 状态 |
|---|---|
| common status 窗口 | 3nm 件在 `0x1000 + 0x138`，x1e80100 在 `+0xb0`。该窗口**只**用于 `dev_dbg()` 打印 hw_version，本枚不动它（不复制在飞的「per-SoC status offset」改造：kaanapali v25 `p01`）。kaanapali 系列落地后 `mipi_csi2_dphy_3nm_sm8750` 应加 `.common_status_offset = 0x138`。 |
| binding 归属 | `0001` 与在飞的 `qcom-camss-sm8750-v6-20260721` 1/7（Hangxiang）**改同一段** `oneOf`；本枚给的是「独立 const」形状，v6 给的是「`sm8750` + `kaanapali` fallback」形状。两者只可存一个，**投递前必须先看 v6 是否已进 tree**。 |
| 2ph 上电两条 | 本驱动需要，vendor 表没有（在别的序列里）。若评审认为 3nm 件不需要，可删（`0x1018/0x101c`）。 |
| 3ph 表 | 本机 SM8750 走两相接线，`csiphy_3ph_v2_4_0_reg`（72 条、地址体系完全不同）**不进本系列**。 |
| 上机验证 | 本 lane 不上机。净行为只有 4 个 `0x0000` 字节，仍需一次出流回归（`s5kjns`/`gc08a8` 30fps）才能投。 |

## 复跑（一次性树，收尾干净）

```bash
cd /home/xuqianhui/y700-elden
rsync -a --exclude=.git build/m3v2-7.3rc7/ /tmp/csiphy-build/     # 见 GATES.md「基线说明」
cd /tmp/csiphy-build
git show ... # 三个驱动文件与 binding 用 gh/master 的 blob 覆盖（GATES.md 命令）
for f in /home/xuqianhui/y700-elden/patches/upstream/camss-csiphy-24-20261115/0*.patch; do
    git apply --check "$f" && git apply "$f"; ./scripts/checkpatch.pl --strict --no-signoff "$f"; done
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 W=1 drivers/phy/qualcomm/
make ARCH=arm64 dt_binding_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/phy/qcom,x1e80100-csi2-phy.yaml
```

## 门禁

见 `GATES.md`（四条门禁的原始输出 + 基线限制 + `logs/` 目录）。

## 问询信（2026-11-15 起草，**未发**）

按「先问形状再发补丁」的口径，本轮已起草一封不带补丁的 RFC 问询信给
**Bryan O'Donoghue <bod@kernel.org>**（该 phy 驱动/binding 的 maintainer），CC `linux-phy` / `linux-arm-msm` / `devicetree`。
草稿 = `out/mail-20261115/draft-rfc-csiphy-24.txt`（`out/` 在 .gitignore 内，故此处留指针）。
三个问题：① 形状用 per-SoC `lane_regs_sm8750[]` 还是 per-generation `lane_regs_2_4_0[]`；② 只有一台 SM8750、只能做 30 fps 出流回归，这个证据级别是否够，或要不要把当前驱动**并不生效**的 SETTLE/SKEW 条目剔掉；③ binding 用独立 const 还是 items+kaanapali 回退（与在飞的 kaanapali v25 撞同一段 `oneOf`）。
发信需用户逐封批准（`TASKS/README.md` §7 口径）。
