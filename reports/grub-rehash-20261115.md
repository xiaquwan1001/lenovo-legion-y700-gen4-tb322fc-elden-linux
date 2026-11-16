# arm64 standalone GRUB：LoadFile2 填 buffer 后回读校验（grub-rehash 一发）

**日期**：2026-11-15（**纯主机侧**：不打设备、不 flash、不碰 `build/` 内核树）
**前序**：
- `TASKS/sessions/2026-11-15-UEFI-ShotAB-读路径清白分配页存活.md`（读路径清白，C1 否证）
- `reports/uefi-grub-initrd-memmap-20261115.md`（断点收窄到「64 MB 缓冲区填进去后内容就变味」）
- `PITFALLS/sessions/295-GRUB大initrd交接坏掉.md`（#659）、`PITFALLS #664`（ESP 满导致装件半成功）

**要回答的那一个比特**：GRUB 把数据填进内核 stub 给的 buffer **之后**，那块 buffer 里是不是**正确的字节**？

| 观测 | 判读 | 下一步 |
|---|---|---|
| `elden_lf2_sum` == 主机期望值（且 sum2/sum3 也相等） | 填进去就是对的，**且填完这一小段时间内没变** ⇒ 破坏发生在 `ExitBootServices` **之后**（缓存属性/一致性，或别人写这片页） | 转**属性侧**（`EFI_MEMORY_WB/WT/UC` 与 arm64 `memblock`/cache 属性；细节见 §6） |
| `elden_lf2_sum` ≠ 主机期望 | **GRUB 的 fill 本身就错**（指针/长度/跨 4 GiB/读路径） | 转 fill 二分（8 块里哪几块错——见 §7 后续设计） |
| sum 相等但 sum2/sum3 ≠ sum | **填对了，随后在 EBS 之前就被别人改写** ⇒ C2（Mu 分配页不独占/被复用）成立 | 上 Mu 侧插桩定位写者；GRUB 侧无解 |

**产物**：`out/grub-rehash-20261115/`（EFI + 菜单 + 补丁 + 构建日志 + expected 输出）、`scripts/lf2-expected.py`（主机侧同规则复算）。

---

## 0. 状态：进行中

（分段追加中。）

## 1. 补丁

## 2. 构建

## 3. 主机期望值

## 4. 上机单

## 5. 回滚

## 6. 判读分支细则

## 7. 待办

## 后续（2026-11-15 20:0x，编排者接手）

- lane 卡在 `genmoddep.awk` 的 `asorti()`（Ubuntu 默认 mawk 不支持）；编者在改 `AWK=gawk` 后**增量完成构建**，并在本树里 `grub-mkstandalone` 出两条 EFI：
  - **v1**（`5b45c50f…`）：3 次采样 + 中途 grubenv 回写 ⇒ 上机后 GRUB 报 `alloc magic is broken at 0xbffa227a0:0` 并卡住（设备需断电）；
  - **v2**（`b9fb14cb…`）：改为**只打印**（`[LF2] addr=/size=/fnv=/tail=` + 期望值）+ 内嵌 `big.pf2` 大字体。
- **判决结果（已钉死）**：v1 的 **step-1 采样**（就在 `grub_initrd_load()` 返回后立刻）落进 grubenv 的值是
  `len=64595425 / addr=0xc23e0000 / calls=1 / sum=0x5c53688e / tail=8eff7f5eb9feff01db29f8bf008ad60a`，
  与 `scripts/lf2-expected.py` 对**原始 initrd 文件**算出的期望值**完全相等** ⇒ **填完瞬间内容正确**，GRUB fill 清白。
- 期望值脚本：`scripts/lf2-expected.py`（抽样规则与补丁逐字一致：8×4 KiB、`off_i = i*(size-blk)/7`、FNV-1a-32、末 16 字节 hex）。
- ~~**未完成**：v2 的**屏上取证**（用户拍 `[LF2]` 三行）—— v2 不写盘，所以不经拍照拿不到打印内容；已记入 `INDEX.md` §0 下一步第 6 条与 `TASKS` §4 N1 的待补项。  → **2026-11-16 撤销该项**：v2 只是同一测量的「只打印」通道变体，判据已由 v1 grubenv 值与 11-16 守卫臂覆盖，见 `reports/pstore-ram-initrd-guard-20261116.md` §7 第 3 条。
