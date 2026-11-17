# phy: qcom: mipi-csi2: SM8750 2.4.0 lane 表 **v2（按 Bryan 要求重基到 on-list kaanapali v25）**

- 日期：2026-11-17（v1 = `../camss-csiphy-24-20261115/`，**已由本目录取代**）
- 状态：**备料，未投**（投放仍需用户逐系列批准）
- 基线：上游 **7.4-rc3 `aebb727447`** + **kaanapali v25 `[01/15]`–`[03/15]`** 三枚前缀
  （`logs/v25-0{1,2,3}-*.patch`，取自 lore `20261112-kaanapali-camss-v25-{1,2,3}-1d709f57f370@oss.qualcomm.com`；
  series 见 <https://patchwork.linuxtv.org/api/1.2/series/33877/>）
- 规模：2 枚，`4 files changed, 142 insertions(+)`

## 与 v1 的差别（为什么必须重基）

Bryan O'Donoghue 2026-11-15 17:44 UTC 对我方 RFC 的回信要求「先基于 on-list 的 8750/Kaanapali 工作」
（`<57ea8341-4685-4b50-9072-cceab6fc1623@kernel.org>`，摘录见 `reports/upstream-replies-20261117.md` §3.1）。
对账后我方 v1 有三处需要改：

| 项 | v1（2026-11-15） | v2（本目录） |
|---|---|---|
| 基线 | 只有 7.4-rc3 | **7.4-rc3 + kaanapali v25 01–03**（`mipi_csi2_dphy_3nm_kaanapali` 已存在） |
| `common_status_offset` | 未写（v25 前该字段不存在） | **`.common_status_offset = 0x138`**（v25 `[02/15]` 引入，3nm 件与 x1e 的 0xb0 不同） |
| binding 形状 | 独立 `const: qcom,sm8750-csi2-phy` | **`items: [sm8750, kaanapali]` 回退对**，与 Hangxiang 自带的 SM8750 CAMSS 系列 `[v6 1/7]` **逐字相同**（patchwork series `1131656`） |
| RFC 里那条「per-SoC 表 vs per-generation 表」问题 | 未决 | **已由 v25 `[03/15]` 回答**：上游采纳 per-SoC cfg，但该 cfg **复用了 `lane_regs_x1e80100[]`（4nm v2.1.2 表）** ⇒ 缺口仍在，本系列只补表 |

补充事实（写进 cover，供维护者判断这是不是重复工作）：

- v25 `[03/15]` 的 `mipi_csi2_dphy_3nm_kaanapali` = `init_seq = lane_regs_x1e80100`，即 3nm 件当前跑 **4nm v2.1.2** 的 lane 值；
- Qualcomm 自己的 SM8750 系列（`media: qcom: camss: Add SM8750 support` v6，patchwork `1131656`）
  `[4/7]` 把 `sm8750_resources` 直接指向 `csiphy_res_kaanapali`（其 subject 写的是 **v2.3.0** 两相 CSIPHY）；
- 本机 vendor `camera.ko` 的 SM8750 表 = `csiphy_2ph_v2_4_0_reg`，而 **v2.3.0 与 v2.4.0/v2.4.1 的 18 张 2ph 表逐字节同值**
  （`reports/camss-csiphy-v6-vs-240-20261113.md` §2.2）⇒ vendor 侧证据与 Qualcomm 的 v2.3.0 口径一致，
  而上游 phy 驱动当前用的 v2.1.2 值与两者都不同。

## 两枚内容

| # | Subject | 改动 |
|---|---|---|
| 0001 | `dt-bindings: phy: qcom,x1e80100-csi2-phy: add SM8750 CSI2 PHY` | `oneOf` 增加 `items: [qcom,sm8750-csi2-phy, qcom,kaanapali-csi2-phy]`（3 行） |
| 0002 | `phy: qcom: mipi-csi2: add SM8750 2.4.0 lane settings` | `lane_regs_sm8750[]`（105 条）+ `mipi_csi2_dphy_3nm_sm8750` cfg（含 `common_status_offset=0x138`）+ match + extern（137 行） |

## 必须写进 cover 的三条边界（v1 已定，仍然有效）

1. **净行为只有 4 字节**：13 条差异里 5 条 `SETTLE_CNT_LOWER_BYTE` 被 `gen2_config_lanes()` 用运行时 `settle_cnt` 覆盖、
   4 条 `CSIPHY_SKEW_CAL` 被 `continue` 跳过 ⇒ 实际生效的只有 4 个 `0x0000/0x0400/0x0800/0x0c00` 的 `0x8e→0x8c`。
   **不得**宣称「修复」。
2. 表与 vendor `csiphy_2ph_v2_4_0_reg` **103/103 (addr,data,type) 多重集全等**（`logs/40-table-diff.txt`），
   SKEW 的 `0x005c` 取 `0x00`（SKEW 行当前不下发，不回填历史备料的 `0x54`）。
3. **尚未做上机出流回归**（本 lane 只做静态门禁）。要投必须先补一次 `s5kjns`/`gc08a8` 30 fps 实测，
   或在 cover 显式声明「无实测」——后者按 §7 口径需用户裁决。

## 残留待维护者定的事（cover 里只提问、不自作主张）

| 项 | 我方立场 |
|---|---|
| 是否应反过来改 `mipi_csi2_dphy_3nm_kaanapali` 的 `init_seq`（即 v25 `[03/15]` 可能选错表） | 我方只有 SM8750 一台机、只有 2.4.0 表证据，**不替 Kaanapali 下结论**；本系列只加 SM8750 cfg，若维护者认为两者应共用一张 3nm 表，可把本系列压成 1 枚 |
| 2ph 上电两条 `0x101c=0x7a` / `0x1018=0x01` | vendor 把它们放在别的序列里；本驱动 `init_seq` 只有一张表（x1e 表同样带这两条）⇒ 保留 |
| 3ph 表 / `csiphy_3ph_v2_4_0_reg` | 本机走两相接线，不进本系列 |

## 复跑（一次性树，收尾可删）

```bash
cd /home/xuqianhui/y700-elden
# ① 前缀树 = 4 个文件的 7.4-rc3 blob + v25 01–03
git -C build/m3v2-7.3rc7 show aebb727447:<path>   # 取 binding + 三个 phy 文件
git apply logs/v25-01-binding.patch logs/v25-02-common-status-offset.patch logs/v25-03-kaanapali-cfg.patch
# ② 本系列
git apply --check 0001-*.patch 0002-*.patch && git am 0001-*.patch 0002-*.patch
# ③ 门禁（详见 GATES.md）
perl build/m3v2-7.3rc7/scripts/checkpatch.pl --strict --no-signoff <patch>
rsync -a --exclude=.git build/m3v2-7.3rc7/ /tmp/csiphy2/build/ && cp <4 files> 覆盖 → make -j6 W=1 drivers/phy/qualcomm/
make ARCH=arm64 dt_binding_check DT_SCHEMA_FILES=…/qcom,x1e80100-csi2-phy.yaml
python3 logs/verify-table.py <patched 3ph.c> <baseline 3ph.c> backup/stock-elden/vendor_dlkm/camera.ko
```

## 门禁

见 `GATES.md`（4 条门禁 + 表对账，本目录实跑）。
