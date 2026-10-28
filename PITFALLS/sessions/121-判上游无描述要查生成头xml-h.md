# 121 · #458 「上游无描述」不能只查 `dsi.xml`：生成头 `generated/*.xml.h` 里其实有名字

- **日期**：2026-10-28
- **场景**：B5 第 5 步被判定为「`0x001f0200` / `0x44440400` 涉及 bit30/29，上游无描述 ⇒ 永久隔离、不得进上游」
  （`reports/b5-per-soc-cfg-design-20261027.md` §1 第 4 项、`RFC-SCOPE.md` R1）。复核时发现**这句是错的**。

## 事实

`drivers/gpu/drm/msm/generated/dsi.xml.h`（freedreno 由 `registers/*.xml` 生成的头）里：

| 位 | 符号 | 值 |
|---|---|---|
| FIFO_STATUS bit 10 | `DSI_FIFO_STATUS_CMD_DMA_FIFO_UNDERFLOW` | `0x00000400` |
| FIFO_STATUS bit 18/22/26/30 | `DSI_FIFO_STATUS_DLN0/1/2/3_HS_FIFO_OVERFLOW` | `0x00040000/0x00400000/0x04000000/0x40000000` |
| CMD_DMA_CTRL bit 30 | `DSI_CMD_DMA_CTRL_BROADCAST_MASTER` | `0x40000000` |
| CMD_DMA_CTRL bit 29 | `DSI_CMD_DMA_CTRL_WC_SEL` | `0x20000000` |

⇒ `0x44440400` = 上面五个 FIFO 状态位 OR 起来，**逐位相等**；「bit30/29 无描述」的两个位也都有符号。

真正**没有**上游描述的只有 `ERR_INT_MASK0` 的字段布局（生成头里只有 `REG_DSI_ERR_INT_MASK0 = 0x108`），
那部分只能按厂商驱动行为写成 `GENMASK(20,16) | BIT(9)` 并在注释里说明。

## 纪律

判「某寄存器位上游无描述」时，**两头都要查**：

```sh
grep -n "REG_DSI_<REG>" -A20 build/vk151/drivers/gpu/drm/msm/generated/dsi.xml.h   # 生成头（符号在这里）
grep -rn "<REG>" build/vk151/drivers/gpu/drm/msm/registers/*.xml                  # 源头
```

只查 `dsi.xml` 正文或只 grep `REG_` 定义，会把**已经命名好的位**当成魔数，进而把一个可提交的改动
误判成「永久隔离」。报告里必须写命中**文件:行号**。

## 顺带的两条等价性证明手法（第 5 步用过）

- ① **位值等式**：把具名位的值从生成头里 `grep` 出来 OR 起来，与旧魔数比 —— 一行 python 就够。
- ② **机器码零差异**：改名/注释类「行为中性」改动，最硬的判据是编译产物比对：
   ```sh
   aarch64-linux-gnu-objcopy -O binary --only-section=.text a.o a.text
   aarch64-linux-gnu-objcopy -O binary --only-section=.text b.o b.text
   cmp a.text b.text        # 相同 ⇒ 改动真的没碰机器码
   ```
   （注意：宿主的 `objcopy` 不认 aarch64 目标文件，要用交叉工具的 `aarch64-linux-gnu-objcopy`。）
