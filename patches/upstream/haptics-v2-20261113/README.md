# haptics aw86937 v2 备料（B9，2026-11-13）

> 只读 lane。本目录 = 在 `../aw86927-20261027-v2/`（已投 2026-10-27）基础上**重排 + 采纳两条 bot 意见**的
> 6 枚系列。**未投递**（下一轮统一发信）。

## 与上一版（5 枚）的差别

| 变化 | 位置 | 理由 |
|---|---|---|
| 新增 `0002`：`AW86938_PLAYCFG1_BST_MODE_MASK` 由 `GENMASK(5, 5)` → **`GENMASK(6, 5)`**，带 `Fixes: df53055c540f` | 0002 | sashiko（patchwork `14918445` 评论）：boost mode 是 6:5 两位域，1 位掩码会留下 bit6 |
| `aw86927_reset()` 移到 probe 之前，probe 里在拿到 reset GPIO 后注册 `devm_add_action_or_reset()` | 0006 | sashiko（patchwork `14918446` 评论）：unbind / probe 中途失败也应把芯片按回 reset |
| 其余 4 枚内容不变，仅重编号 | 0001/0003/0004/0005/0006 | — |

## 门禁（本轮实跑）

| 门 | 结果 |
|---|---|
| `checkpatch --strict --no-signoff`（逐枚） | 0001/0002：**0E/1W**（W = “Unknown commit id 'df53055c540f'”，本机两棵树都没有该 commit，属树历史不全的假阳性；上游全树不会有）；0003–0006：**0E/0W/0C** |
| `git apply` 6 枚顺序（7.4-rc2 + 本机 payload 树副本 `/tmp/b9/tree`） | 5/6 直接 OK；**0006 需要先有 `#include <linux/interrupt.h>`**——该行是 linux-next 侧漂移（7.4-rc2 里没有），补上后 rc=0。**系列基线 = linux-next，不是 7.4-rc2**，投前要么等该 include 进主线，要么把它作为系列前置说明 |
| 编译（最终树，`W=1`，`make -j26 ... drivers/input/misc/aw86927.o`） | **rc=0，无 warning**（`CC [M] drivers/input/misc/aw86927.o`） |
| 逐提交编译 | **未重跑**（v2 时 5/5 rc=0；本轮只编终态，新增 0002 是 1 行宏、0006 是同一文件的重排，风险低） |
| `dt-doc-validate` binding | **未重跑**（0003 binding 相对 v2 逐字未变，v2 时 rc=0；本机 `dt-doc-validate` 在 `~/.local/bin`，今晚可一行复跑） |

## MAINTAINERS / binding 冲突核查

- **MAINTAINERS**：`gh/master` 的 MAINTAINERS 里**没有** aw86927/awinic-haptics 条目
  （`git show gh/master:MAINTAINERS | grep -i awinic` 只命中 AW88399 / AW99706）。
  ⇒ 我们的系列不改 MAINTAINERS，也不会与别人抢条目；但**若 AW8695/AW8697 系列先合入并新增条目**，
  我们的 binding 文件路径必须与之保持一致（见下）。
- **binding 文件冲突**：上游 `Documentation/devicetree/bindings/input/awinic,aw86927.yaml`
  的 `maintainers:` 当前是 **Griffin Kroah-Hartman**（AW8695 系列作者）。我们的 0003 只在该文件的
  compatible 回落组里加 `awinic,aw86937`（+1 行），**不新增文件、不改 maintainers**。
  ⇒ 与 Griffin v3（AW8695）/ armandas v3（AW8697）**同文件冲突风险 = 纯上下文级**，谁后合谁 rebase 一次；
  不构成语义冲突。**需要注意**：若他们改了 `maintainers:` 或 compatible 结构，我们这 1 行要跟着挪。

## 未完成

- 逐提交编译与 `dt-doc-validate` 未重跑（命令在 v2 的 `reports/aw86927-series-v2-20261027.md` §4，可直接复跑）。
- AW86937 仍**无实物**，commit message 已避免声称实测。
