# M4-2…M4-4 camss 驱动系列 **v3**（2026-10-29 候选，**未发**）

面向上游 `linux-media` 的 **camss SM8750 驱动主体**，9 提交。v1 已投、v2 已整（v2 未发），本目录 = **v3 候选**：
在 v2 基础上修掉 sashiko 自动评审剩下的 #4 两条（High 位掩码累积 / Medium 三字段数据竞争），并明确 **#8 不改**
（vfe-gen4 与 csid_isr 的竞争已被同一把锁覆盖）。

- 源分支：`build/m4-v3` @ **`m4/v3-20261029`**（tip `413d7e784`，9 提交 / 14 文件 / **+1979 −61**）
- 基线：v2 tip `ca3d71e71`；`git diff ca3d71e71 <tip>` = **`+42 −1`，只有 `camss-csid-980.c` 与 `camss-csid.h`**
- 上一版：`patches/upstream/m4-camss-series-20261028-v2/`（其 README 记录了 v1→v2 的 4 处修复）
- 本次自检与判断：`reports/m4-camss-v3-20261029.md`
- finding 定性原件：`reports/camss-upstream-response-20261028.md` §5、`reports/m4-sashiko-triage-20261028.md`

## v3 相对 v2 的改动（只有 0004 + cover）

| Patch | Sashiko 严重度 | 处理 | 改动 |
|---|---|---|---|
| 4/9 `aup/rup_update` 位掩码累积 | **High** | ✅ 改（**write-then-clear**） | `__csid_aup_update()`/`__csid_rup_update()` 在 `writel` 之后立刻 `csid->{reg,aup,rup}_update &= ~<本流位>`。根因：本代每 RDI 状态位只有 `INFO_RUP_DONE`(BIT 23) 与 `INFO_CAMIF_SOF`(BIT 4)，**没有 AUP-done 位** ⇒ AUP shadow 永不消除；且 `CAMSS_INIT_BUF_COUNT` 的 qualifier 逐流配置会把前几流的位一起写进命令寄存器（重发陈旧 RUP/AUP） |
| 4/9 三字段数据竞争 | Medium | ✅ 改（**加锁**） | `camss-csid.h` 加 `spinlock_t reg_update_lock`；三个 `__csid_*` 全 `spin_lock_irqsave/irqrestore`；`csid_subdev_init()` 里 `spin_lock_init`（先于 `devm_request_irq`，`camss-csid.c:1107` < `:1137`） |
| 8/9 vfe-gen4 ↔ csid_isr 竞争 | Medium | ⏸ **不改** | gen4 的 `vfe_isr` 是 `/* nop */`；VFE 侧 `reg_update` 走 `camss-vfe.c:570 → camss_reg_update() → csid->res->hw_ops->reg_update`，**已进同一把 `reg_update_lock`** ⇒ 0008 无需改动 |
| 4/9 gen2/gen3/680 同类无锁模式 | Medium | ⏸ 不改（回复） | 既有上游问题（`camss-csid-gen3.c:242-248`、`camss-csid-680.c:173-183`），属**独立 camss 加锁补丁线**；已在 0004 提交信息里明示「older generations are not converted here」 |

> 说人话：**#4 的 High + Medium 在 0004 内一起修掉**；**#8 证明已被同一把锁覆盖、零改动**；gen2/gen3 留独立线并写进提交信息。

## 门禁（2026-10-29 本 lane 重跑，主机侧）

| 门 | 结果 |
|---|---|
| `checkpatch.pl --strict` ×9 | **9/9：0 errors / 0 checks**；3 条 WARNING 全为同一假阳性（`MAINTAINERS need updating?`，patch 1/4/8）。已证假阳性：`MAINTAINERS:22371-22379` 的 camss 条目已含 `Documentation/devicetree/bindings/media/qcom,*camss*` 与 `drivers/media/platform/qcom/camss/` |
| 编译（arm64，只编 camss） | **rc=0，0 条编译器诊断**；`make O=/tmp/camss-obj ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j26 M=drivers/media/platform/qcom/camss KBUILD_MODPOST_WARN=1` → `LD [M] qcom-camss.ko` **2,105,232 B**。`KBUILD_MODPOST_WARN=1` 只是因为新 objdir 无 `vmlinux`/`Module.symvers`（116+ 条 `symbol ... undefined`），CC/LD 阶段全绿 |
| 三字段 RMW 全在锁内 | **已证**：awk 深扫 22 处访问全 depth=1，唯一 depth=0 是 `spin_lock_init`；`camss-csid-980.c` 之外无文件访问 `rup_update`/`aup_update` |
| 其余 8 枚与 v2 一致 | **已证**：剔除 `index`/`From` 行后逐字节比较，0001/2/3/6/7/8/9 无差异；0005 仅 4 个 `@@` 行号平移 |
| pristine `git am` 9 枚 | **未跑**（v2 跑过）；v3 验证了 0005–0009 对改后 0004 的 `git am -3` 干净 |
| `dtbs_check` | **未跑**（0001/0009 未改） |
| **上机出流复验** | **未做（本 lane 纯主机）**。判断**需要**跑：命令寄存器写入值从「累积位图」变「单流位」属行为变更。最小命令见 `reports/m4-camss-v3-20261029.md` §4 |

## 发送

**未发。** 发送需用户按系列批准；**建议先跑 §4 的上机复验**（双摄 90/90、错误计数 0→0，且各跑两遍以覆盖「先停再起」），
通过后再 `send-email --dry-run` 复核，以 `[PATCH v3]` 新串发出（cover 已含 `Changes in v3`）。

## 文件

```
0000-cover-letter.patch   6492   [PATCH v3 0/9] + Changes in v3 两条 + v3 diffstat
0001..0003, 0005..0009    ——     与 v2 逐字节等同（0005 仅 hunk 行号平移）
0004-...-980-generation.patch  23996  唯一实质改动（+42 −1）
```
