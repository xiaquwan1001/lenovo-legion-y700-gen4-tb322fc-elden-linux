# M4 取证：从厂商 `camera.ko` 里取出 CSIPHY 2.4.0 的寄存器图（R1/R2）

> 目标 = M4 系列的 **R1（硬件数值出处）/ R2（`common_status_offset=0x138` 未验证）**。
> 手段 = 反汇编设备原厂 `vendor_dlkm/camera.ko`（`backup/stock-elden/vendor_dlkm/camera.ko`，**not stripped**）。
> **纯主机侧、零设备操作**；结论是「厂商数据段级一致」，不是「运行期实测」。

## §0 结论（数字）

| 项 | 结果 |
|---|---|
| **R2（`0x138`）** | ✅ **厂商一致**。`csiphy_v2_4_0`（80 B 数据段）= `{0x1028, 0x1138, 0x1058, 0, 0, 0, 0x400, 0xb, 0x14, 5, 1, 3, 0x67, 0x48, 0, 0x67, …}`；反汇编 `cam_csiphy_common_status_reg_dump` 证实用法：`x27 = base + [ver + 4]` → 读 12 个 status 寄存器，第二块 `base + [ver + 8]`。`0x1138 = 0x1000 + 0x138` ⇒ 我们的 `offset=0x1000` + `common_status_offset=0x138` 与厂商寄存器图**逐位相同** |
| **R1（lane 表出处）** | 🟡 **可逐条对账**：我们的 `lane_regs_sm8750`（103 条）与厂商符号 `csiphy_2ph_v2_4_0_reg`（1648 B = 103×16）：**地址/掩码/类型 103/103 相同，`data` 99/103 相同**；差异 4 条全是 SKEW_CAL 的 `0x5c` 偏移（见 §2） |
| 新事实 | 厂商还有 **`csiphy_3ph_v2_4_0_reg`**（72 条，地址体系完全不同：`0x294/0x2f4/0x2f8…`）⇒ 该 PHY 有 2ph / 3ph 两套变体，驱动按 DT 选；**本机用 2ph 表出图** ⇒ 本机是 2ph 变体（与上游文件名 `csiphy-3ph-1-0.c` 易混，补丁正文必须点明） |
| 产物 | 本报告 + 更新后的 `patches/upstream/m4-camss-series-20261027/README.md`（R1/R2 状态改写） |

## §1 方法（可复跑）

```sh
cd backup/stock-elden/vendor_dlkm
readelf -sW camera.ko | grep -E "csiphy_(2|3)ph_v2_4_0|csiphy_v2_4_0"
#   12930: a3d6c 1648 OBJECT  csiphy_2ph_v2_4_0_reg
#   12932: a4a4c 1152 OBJECT  csiphy_3ph_v2_4_0_reg
#   12966: aab48   80 OBJECT  csiphy_v2_4_0          ← 每代参数结构（含状态块偏移）
readelf -SW camera.ko | grep '\.data '                # → file off 0x25fab8

# 解码（每张 lane 表 = 103 条 × 16 B {addr, data, mask, param_type}）
python3 -c '
import struct
d=open("camera.ko","rb").read(); bo=0x25fab8
print([hex(w) for w in struct.unpack("<20I", d[bo+0xaab48:bo+0xaab48+80])])'
# → ["0x1028", "0x1138", "0x1058", "0x0", ..., "0x400", "0xb", "0x14", ...]

# 用法确认（状态块就是 [ver+4]）
aarch64-linux-gnu-objdump -d --start-address=0x16fb7c --stop-address=0x16fd94 camera.ko
#   16fbb8: ldp w24, w10, [x25, #4]      ← w24 = [ver+4] = 0x1138（common status 基址）
#   16fc84: add x27, x23, x24            ← 读 0x1138 + 4*i, i=0..11
#   16fc90: add x23, x23, x10            ← 第二块 = [ver+8] = 0x1058（mipi status）
```

## §2 `lane_regs_sm8750` vs 厂商 `csiphy_2ph_v2_4_0_reg`

对账口径：`(addr, data)` 多重集。结果 **99/103 相同**，差异 4 条：

| 偏移 | 我们（`camss-csiphy-3ph-1-0.c`） | 厂商 `csiphy_2ph_v2_4_0_reg` |
|---|---|---|
| `0x005c` | `{0x005c, 0x54, 0x00, CSIPHY_SKEW_CAL}` | `{0x5c, 0x00, 0x00, type=64}` |
| `0x045c` | `0x54` | `0x00` |
| `0x085c` | `0x54` | `0x00` |
| `0x0c5c` | `0x54` | `0x00` |

**并且这 4 个值不是搬错了表**：把 `camera.ko` 里 **82 张** `csiphy_*` 寄存器表全扫一遍，
**没有任何一张**含 `{0x5c, 0x54}` ⇒ `0x54` 是**我方偏离**（SKEW_CAL 控制位的本地取值），
不是厂商图的一部分。今天相机能出图（G1-5：前后摄 30 fps 满帧）用的是 `0x54` 版本。

## §3 对 M4 系列的影响

| 原风险 | 现状 |
|---|---|
| **R2**「`0x138` 只走错误上报路径、未上机 ⇒ 值对不对不知道」 | ✅ **降级**：与厂商 `csiphy_v2_4_0` 寄存器图一致（`0x1138` 即 common status 块），不再是"猜的"。补丁正文可从"vendor implementation"改成"vendor CSIPHY 2.4.0 register map"并附本报告指针 |
| **R1**「数值出处不明，非 QCOM 投递需同签」 | 🟡 **降级**：2ph v2.4.0 lane 表可逐条对账（99/103），剩 4 条偏离需**决策**：要么回退成厂商 `0x00` 做一次上机 A/B，要么保留并在提交里显式说明「SKEW_CAL 使能由我们打开」 |
| **R3**「SOF 从 VFE 移到 CSID 属架构改动」 | 不变（见系列 README §4） |
| 附带 | 3ph v2.4.0 表的存在说明驱动/绑定文档里应写清「SM8750 用 2ph 变体」，否则 review 第一问就是"为什么不复用 3ph" |

## §4 下一步（可选，按性价比）

1. **改写补丁正文**（30 min，零风险）：R2 的事实写进 `0001-csiphy-*` 的 commit message + 系列 README；
2. **4 条 SKEW_CAL A/B**（需设备）：`0x54` vs `0x00` 各出图 30 s ×3，判据 = 前后摄帧率/无 timeout/无 `EPIPE`；结果决定是"保留并解释"还是"回退成厂商值"；
3. 把 `camera.ko` 的这种「数据段取证」写进 `PITFALLS`（原厂 .ko not stripped ⇒ 寄存器图可直接取，别再靠猜）。
