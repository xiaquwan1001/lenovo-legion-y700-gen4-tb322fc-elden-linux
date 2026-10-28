# B5 **第 5 步**解阻：所谓「无上游描述的魔数」其实在 `generated/dsi.xml.h` 里有名字（2026-10-28）

> 承接：`reports/b5-per-soc-cfg-design-20261027.md` §1 第 4 项 + `patches/upstream/m6-b5-p4-rfc-20261027/RFC-SCOPE.md` **R1**。
> 原文口径：`0x001f0200` / `0x44440400` 涉及 **bit30/29「上游无描述」⇒ 第 5 步永久隔离、不得进上游**。
> 本轮**静态复核把这句证否了**，并给出**可评审**的实现 + 机器码级等价证明。性质：纯主机侧（`build/vk151` 内编译），**零设备操作**。

## §0 结论（数字）

| 项 | 结果 |
|---|---|
| `0x44440400` | = `DSI_FIFO_STATUS_CMD_DMA_FIFO_UNDERFLOW` \| `DLN0/1/2/3_HS_FIFO_OVERFLOW`，**全部有上游名字**（`drivers/gpu/drm/msm/generated/dsi.xml.h:166,178,180,182,184`），OR 起来**逐位相等** |
| `0x001f0200` | = `GENMASK(20,16)` \| `BIT(9)`：`dsi.xml` **没有** `ERR_INT_MASK0` 的字段定义（只有 `REG_DSI_ERR_INT_MASK0 = 0x108`，`:597`），所以这一半仍需写明；bits 16..19 = 同一组四条 lane 的 HS FIFO overflow，bit 20 与组同掩，bit 9 = CMD DMA FIFO 下溢 |
| 「bit30/29 无描述」 | **不成立**：bit30 = `DSI_CMD_DMA_CTRL_BROADCAST_MASTER`（`:320`）、bit29 = `DSI_CMD_DMA_CTRL_WC_SEL`（`:321`），都在同一头文件里 |
| 重新实现 | 新增 `patches/local/b5-resoc-20261027/0005-dsi-name-fifo-error-bits.patch`（+24 −9，注释重写为上游口径、去掉 "Stock" 措辞） |
| **等价证明** | `dsi_host.o` 的 `.text` **逐字节相同**（`objcopy --only-section=.text` + `cmp`，23 048 B / 23 048 B）⇒ 改名与注释**在机器码上零差异**，不是「看着一样」 |
| 门禁 | `make drivers/gpu/drm/msm/dsi/dsi_host.o` **rc=0 / 0 warning**；patch `-p1` 应用后目标文件**逐字节一致** |

## §1 位解码（可复跑的判据）

```sh
# 上游头（dsi.xml 生成）
grep -nE "DSI_FIFO_STATUS_(CMD_DMA_FIFO_UNDERFLOW|DLN[0-3]_HS_FIFO_OVERFLOW)" \
     build/vk151/drivers/gpu/drm/msm/generated/dsi.xml.h
#   166: DSI_FIFO_STATUS_CMD_DMA_FIFO_UNDERFLOW   0x00000400   (bit 10)
#   178: DSI_FIFO_STATUS_DLN0_HS_FIFO_OVERFLOW    0x00040000   (bit 18)
#   180: DSI_FIFO_STATUS_DLN1_HS_FIFO_OVERFLOW    0x00400000   (bit 22)
#   182: DSI_FIFO_STATUS_DLN2_HS_FIFO_OVERFLOW    0x04000000   (bit 26)
#   184: DSI_FIFO_STATUS_DLN3_HS_FIFO_OVERFLOW    0x40000000   (bit 30)
#   ⇒ OR = 0x44440400
grep -nE "DSI_CMD_DMA_CTRL_(BROADCAST_MASTER|WC_SEL)" build/vk151/drivers/gpu/drm/msm/generated/dsi.xml.h
#   320: DSI_CMD_DMA_CTRL_BROADCAST_MASTER  0x40000000  (bit 30)
#   321: DSI_CMD_DMA_CTRL_WC_SEL            0x20000000  (bit 29)
```

与厂商 GPL 源码交叉对账（`stock-src/android_kernel_lenovo_sm8750-modules/qcom/opensource/display-drivers/msm/dsi/dsi_ctrl_hw_cmn.c`）：
`dsi_ctrl_hw_cmn_mask_error_intr()`（`:1796`）里 `overflow_clear = BIT(10)|BIT(18)|BIT(22)|BIT(26)|BIT(30)`
与我们这五个具名位 **逐位相同**；同函数用 `reg |= (0x1f << 16); reg |= BIT(9);` 掩 `ERR_INT_MASK0` 的 FIFO 溢出组
⇒ 与 `GENMASK(20,16) | BIT(9)` 同形。也就是说：`dsi.xml` 有名字的在 `dsi.xml.h` 里，没名字的（`ERR_INT_MASK0` 布局）
在厂商驱动里有一致的**行为证据**，两边不冲突。

## §2 为什么之前会判成「无描述」（方法学）

判据只查了 **`dsi.xml`**（或只查 `REG_DSI_*` 与 CMD_DMA_CTRL 的少量位），**没查生成的
`drivers/gpu/drm/msm/generated/dsi.xml.h`**。而 freedreno 的生成头恰恰把 FIFO_STATUS 的**每一位**都写成了符号
（含 bit30/bit29 这些被当成"无描述"的位）。⇒ 纪律：**判「上游无描述」必须两头都查**：
`drivers/gpu/drm/msm/generated/*.xml.h`（生成头）+ 对应 `registers/../*.xml`（源头），并把命中行号写进报告。

## §3 对 M6 / B5-P4 的影响

- **第 5 步不再"永久隔离"**：`0x44440400` 侧完全用上游符号；`0x001f0200` 侧保留一个**写明来历**的组掩码。
  仍存的评审风险只剩「`ERR_INT_MASK0` 的字段划分没有公开寄存器手册」——上游 `dsi_host.c` 本来就在
  `:990` 写 `0x13ff3fe0` 这类裸常量，所以这属于**可争辩**而不是**不可提交**。
- RFC 文本需改口径：删掉「bit30/29 无上游描述 ⇒ 不可上游」，改成「FIFO 状态位有上游符号；
  `ERR_INT_MASK0` 组掩码按厂商驱动行为给出并在注释里写明」。

## §4 产物

- `patches/local/b5-resoc-20261027/0005-dsi-name-fifo-error-bits.patch`（自述含出处与等价证明）
- 本报告；机器码对比件 `/tmp/{before,after}.text`（一次性，不入库）
