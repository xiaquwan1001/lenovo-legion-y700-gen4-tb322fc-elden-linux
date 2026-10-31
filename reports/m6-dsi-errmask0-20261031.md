# M6 第 5 步：DSI ERR_INT_MASK0 字段布局交叉定名（2026-10-31）

任务：把 `ERR_INT_MASK0` 内部字段布局从魔数降级为「有出处」，或证明公开材料不足以定名。
判据见派工单；本报告只读不改主线。

## 结论（先数字）

- **结论：可部分定名。** bit9 = CMD_DMA_FIFO_UNDERFLOW、bit16..19 = DLN0..DLN3_HS_FIFO_OVERFLOW、bit20 = 随组屏蔽位（含义未公开）——三路独立证据交叉一致；`ERR_INT_MASK0` 其余位确实无公开手册，维持「保留/未知」。
- 建议表达式与 `0005` 补丁一致：`GENMASK(20,16) | BIT(9)` = `0x001f0200`（python 复算逐位相等）。
- 与 `patches/local/b5-resoc-20261027/0005-dsi-name-fifo-error-bits.patch` **一致，无 diff 行需指出**。
- 证据日志：`reports/artifacts/m6-errmask-20261031/{a-dsixml,b-tree-usage,c-vendor-grep,d-vendor-mask-error-intr,e-supplement,f-cross-verify}.log`。

## 1. 交叉比对表

| # | 证据源 | 能否定名某 bit | file:line | 得到的位定义 |
|---|---|---|---|---|
| a1 | 上游生成头 `dsi.xml.h` | ❌ 对 MASK0 本身无字段（仅寄存器地址） | `build/vk151/drivers/gpu/drm/msm/generated/dsi.xml.h:597` | 只有 `REG_DSI_ERR_INT_MASK0 = 0x108`，无任何 bitfield |
| a2 | 树内 `dsi.xml`（寄存器描述 SSOT） | ❌ 同上 | `build/vk151/drivers/gpu/drm/msm/registers/display/dsi.xml:300`（`linux/` 同树同位） | `<reg32 offset="0x00108" name="ERR_INT_MASK0"/>`，无 bitfield 子节点 ⇒ 「无公开手册」判断在此层成立 |
| a3 | `dsi.xml.h` FIFO_STATUS 位（状态侧锚点） | ✅ 定名 5 个状态位 | `dsi.xml.h:166,172,176,180,184` | `CMD_DMA_FIFO_UNDERFLOW=0x400`(bit10)、`DLN0/1/2/3_HS_FIFO_OVERFLOW=0x40000/0x400000/0x4000000/0x40000000`(bit18/22/26/30)；OR = `0x44440400`（python 复算一致） |
| b1 | 树内同类掩码用法（mainline 初始掩码） | ⚠ 佐证 | `build/vk151/drivers/gpu/drm/msm/dsi/dsi_host.c:990`（`linux/.../dsi_host.c:972` 同值） | `dsi_write(REG_DSI_ERR_INT_MASK0, 0x13ff3fe0)`：该值含 bit9 与 bit16..20（`0x13ff3fe0 & 0x1f0200 == 0x1f0200`）⇒ 独立下游也把 bit9/16..20 当成同一组 FIFO 相关位操作 |
| b2 | 树内 `ERR_INT_MASK0` 全部 C 侧用法 | ✅（即 0005 自身） | `build/vk151/.../dsi_host.c:2356-2359,2380,2400` | `GENMASK(20,16)\|BIT(9)` 定义与两次 `|=`/`&=~` |
| c1 | 厂商血统树 `mask_error_intr()` 寄存器写入 | ✅ **直接定名 mask 位组** | `reference/vendor-display-sm8750/dsi_ctrl_hw_cmn.c:1832-1833`（与 `stock-src/android_kernel_lenovo_sm8750-modules/qcom/opensource/display-drivers/msm/dsi/dsi_ctrl_hw_cmn.c:1810-1811` 函数体逐字节相同，`diff` rc=0） | overflow 组 mask：`reg \|= (0x1f << 16); reg \|= BIT(9);` ⇒ mask bit16..19 + bit20 + bit9；与状态侧 overflow_clear `BIT(10)\|BIT(18)\|BIT(22)\|BIT(26)\|BIT(30)`（:1818）成对（mask 位 ↔ W1C 状态位） |
| c2 | 厂商调用点（语义：DSI_FIFO_OVERFLOW 组） | ✅ | `stock-src/.../dsi_ctrl.c:4324`（vendor 同形 `reference/vendor-display-sm8750/dsi_ctrl.c`） | `mask_error_intr(&hw, idx=BIT(DSI_FIFO_OVERFLOW), …)`，`DSI_FIFO_OVERFLOW=1`（`dsi_defs.h:804`）⇒ 上述 mask 位组语义 = 「FIFO overflow 错误组（含 cmd DMA underflow）」 |
| c3 | 厂商 `enum dsi_error_int_index` | ⚠ **不能当 mask 位表**（已证否一个直觉捷径） | `stock-src/.../dsi_ctrl_hw.h:232-265` | 该 enum 是**软件索引**（错误计数数组下标）：`CMD_DMA_FIFO_UNDERFLOW=14, DLN0..3_HS_FIFO_OVERFLOW=16..19`——与真实 mask 写值 `0x1f<<16\|BIT(9)` **不吻合**（bit9 在 enum 里是 `DLN0_ESC_ENTRY_ERR`）⇒ 只有 c1 的寄存器写入才是位级事实；恰好 16..19 与 lane overflow 重合属巧合，不可据此扩名 |
| b3 | 独立下游树（geekidos） | ✅ 同形魔数 | `geekidos-linux/drivers/gpu/drm/msm/dsi/dsi_host.c:2328,2344` | 独立血统的 `0x001f0200` 同位操作，无新语义信息 |

## 2. 位图与建议表达式（每 bit 标出处）

```
ERR_INT_MASK0 = 0x001f0200：
  bit 9      = CMD_DMA_FIFO_UNDERFLOW   [c1: vendor BIT(9) ↔ a3: FIFO_STATUS bit10]
  bit 16..19 = DLN0..DLN3_HS_FIFO_OVERFLOW [c1: 0x1f<<16 的低 4 位 ↔ a3: FIFO_STATUS bit18/22/26/30]
  bit 20     = 随组屏蔽位，含义未公开     [c1: vendor 置位；无任何源给出名字 ⇒ 保留/未知]
  其余位     = 无公开出处 ⇒ 保留/未知
```

```c
#define DSI_ERR_INT_MASK0_FIFO_OVERFLOW		GENMASK(20, 16)	/* bit20 无名，随组 */
#define DSI_ERR_INT_MASK0_CMD_DMA_FIFO_UNDERFLOW	BIT(9)
#define DSI_ERR_INT_MASK0_FIFO_ERRORS \
	(DSI_ERR_INT_MASK0_FIFO_OVERFLOW | DSI_ERR_INT_MASK0_CMD_DMA_FIFO_UNDERFLOW)
```

无形态变化 ⇒ 无需新 diff 片段。

## 3. 与 0005 的一致性判定

- `0005-dsi-name-fifo-error-bits.patch` 的 `GENMASK(20,16)|BIT(9)`、FIFO_STATUS 五位 OR、
  「dsi.xml 无 MASK0 字段故显式写明」的注释口径：与上表 a2/a3/c1 逐条一致。
- patch 注释「bit 20 is masked with the group」如实反映 bit20 无名（c3 已证明不能从 vendor enum 取名）——**一致，无需指出 diff 行**。
- 唯一补充建议（不改判定）：0005 注释可加一句「vendor `dsi_error_int_index` 是软件索引、与 mask 位不对应」（c3 证据），防止后人误用 enum 扩名。

## 4. 复现命令

```bash
grep -n "CMD_DMA_FIFO_UNDERFLOW\|HS_FIFO_OVERFLOW" build/vk151/drivers/gpu/drm/msm/generated/dsi.xml.h
grep -n -A40 "mask_error_intr" reference/vendor-display-sm8750/dsi_ctrl_hw_cmn.c | sed -n '1,45p'
python3 -c "print(hex(0x400|0x40000|0x400000|0x4000000|0x40000000), hex((0x1f<<16)|0x200))"
```

---

## 5. 总管独立复核 + 新发现（2026-10-31）

### 5.1 逐条复核（全部成立）
| 主张 | 复核 | 实测 |
|---|---|---|
| FIFO_STATUS 五个状态位 OR = `0x44440400` | `sed -n '160,190p' build/vk151/.../generated/dsi.xml.h` + python reduce-or | `0x400`(bit10) / `0x40000`(18) / `0x400000`(22) / `0x4000000`(26) / `0x40000000`(30) → **0x44440400** ✅ |
| mask 侧 `GENMASK(20,16)\|BIT(9)` = `0x001f0200` | python | `0x1f0200` ✅（**注意：与状态侧 0x44440400 不是同一个编码**，报告 §1/§2 已按「mask 位 ↔ W1C 状态位」成对表述，无误） |
| vendor `mask_error_intr()` 同组屏蔽 + 清 5 个状态位 | `sed -n '1826,1840p' reference/vendor-display-sm8750/dsi_ctrl_hw_cmn.c` | `reg \|= (0x1f << 16); reg \|= BIT(9);` ✅；与 stock-src 对应段 `diff` **rc=0** ✅ |
| mainline 初始掩码含该组 | `sed -n '988,992p' build/vk151/.../dsi_host.c` | `0x13ff3fe0 & 0x1f0200 == 0x1f0200` ✅ |
| 独立下游同形魔数 | `sed -n '2326,2330p' geekidos-linux/.../dsi_host.c` | `val \|= 0x001f0200` ✅ |
| vendor enum 不能当 mask 位表 | `sed -n '/^enum dsi_error_int_index/,/^};/p' …/dsi_ctrl_hw.h` | bit9=`DLN0_ESC_ENTRY_ERR`、14=`CMD_DMA_FIFO_UNDERFLOW`、16..19=`DLN0..3_HS_FIFO_OVERFLOW`；且 `DSI_CMD_DMA_FIFO_UNDERFLOW = BIT(14)` ⇒ **enum 枚举的是 ERROR_STATUS0 状态位，既不是 FIFO_STATUS 也不是 MASK0 布局** ✅（比报告原话更准确：不是"软件索引"，是另一套状态位编码） |

### 5.2 已做的收紧（M6 投递风险）
- `patches/local/b5-resoc-20261027/0005-*` 的注释与 cover 段改为**带出处**表述：mask bit9/16..20 的分组"follows the vendor driver's `mask_error_intr()`"，不再把推断写成无来源事实（bit9 的确切错误名在 dsi.xml 中无定义）。
- 同步修正该 patch 的 hunk 计数（`+2345,44`），两 hunk 现均自洽（python 逐 hunk 校验 old/new 计数一致）。

### 5.3 **新发现：本地 B5 序列不能按文件名序重放（M6 重出前必须解）**
用本轮新建的 `scripts/check-series-selfcontained.sh`（已修 `git am` 误判，见 §5.4）以 `0f1fb1c9c1` 为基跑：

```
ok    0001 / 0002 / 0003
WARN  0004: 裸 diff（无 format-patch 头）⇒ 只过 apply，不能 git am / 不能直接投递
FAIL  0005: git apply --check 失败（对当前序列状态不自足）
PASS=4 FAIL=1 WARN=2 退出码=1
```

- **0004 是裸 `diff --git`**（首行不是 `From <sha> Mon Sep 17 …`）⇒ 不是 `git am` 可消费形态，与 M3v5「缺 cover / 缺 base-commit」同类缺陷。
- **0005 与 0002 冲突**：0002 把 `dsi_cmd_error_prepare()` 改成 `const struct msm_dsi_bonded_cfg *bonded = …; val |= bonded->err_clear_bits;`，而 0005 的旧侧上下文是改前的 `{ u32 val; …}`。
- 更实质的一处**设计分叉**：`build/vk151` 工作树（0005 已应用）里 `err_clear_bits` **零命中** ⇒ 树上的终态用「通用宏 `DSI_ERR_INT_MASK0_FIFO_ERRORS`」取代了 0002 的「per-SoC 表给 `err_clear_bits`」。两者只能留一个。按三问门「硬件事实进 DT/数据表」，**建议保留 0002 的表驱动形态**，把 0005 收缩为「给 bit 组加名字」而不改数据来源；否则 reviewer 会问"为什么刚建了 per-SoC 字段又不用"。
- 结论：**M6 序列当前不可投**（形态 + 冲突 + 设计重复），需按上述裁决重出后再过门禁。

### 5.4 门禁脚本修复（属 M3v5 lane 交付物）
`git am --3way` 对裸 diff 会报「补丁格式探测失败」，原实现把它误报成"不自足"。已改：先用首行正则区分 `format-patch` 与裸 diff，裸 diff 只跑 `apply` 并记 **WARN「不能 git am / 不能直接投递」**；`git am` 失败则明确是"内容冲突，非格式问题"。`--self-test` 复跑仍 **PASS**（正例 3/3、负例在 0002 处 FAIL 退出码 1）。
