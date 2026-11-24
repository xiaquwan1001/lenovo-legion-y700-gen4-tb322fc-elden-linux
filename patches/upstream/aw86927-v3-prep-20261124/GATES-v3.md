# aw86927 v3 门禁账（2026-11-24，**已备料，未投递**）

> 为什么有 v3：sashiko 对 **v2 6/6** 的报告（`sashiko-bot@kernel.org`，2026-11-17 05:46Z，
> lore `?q=sashiko+aw86927` 可现查）给了 **1 条 [High] + 1 条 [Low]**。两条都成立，**只改 6/6**，
> 1–5 与 v2 逐字节相同。

## 0. 数字结论

| 门 | 命令形状 | 结果 |
|---|---|---|
| 基线 | worktree @ `aebb727447` | v7.4-rc3（**注意**：v2 的声明基线是 linux-next master 2026-10-27，本地无该树；本轮按 7.4-rc3 验，6 枚 `git apply` 全绿 ⇒ 上下文未漂） |
| G1 落树 | `git apply` ×6（顺序） | **6/6 干净** |
| G2 checkpatch | `--strict --no-signoff --no-tree` ×6 | **0E/0W/0C**（7 / 30 / 112 / … 行，逐封见 `logs/G2-checkpatch.log`） |
| G3 编译 | `make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/input/misc/aw86927.o`（`CONFIG_INPUT_AW86927=y`） | **rc=0，0 warning / 0 error**（`logs/G3-W1-build.log`） |
| G4 上机 | — | 未做（触觉驱动，需设备；本机在机内核是 7.3.1，未带本系列） |

## 1. 相对 v2 的两处改动（只在 6/6）

1. **[High] unbind 竞态（use-after-free 形状）**：`aw86927_reset()`（devres 动作）原来只拉高 reset GPIO，
   不排空 `play_work`。而 `input_close_device()` 对 **inhibited** 设备会被跳过，`input_flush_device()`
   会（重新）排队 `play_work` ⇒ unbind 后 worker 仍可能写已经释放的 regmap。
   修法：devres 动作里先 `disable_work_sync(&haptics->play_work)` 再拉 reset；
   `aw86927_shutdown()` 改为调用同一个 helper（不再自己排空）。
2. **[Low] 提交信息与注释同代码不符**：message 现在明确「suspend 只让芯片进 standby、不拉 reset；
   shutdown 拉 reset、不额外 stop」，与代码一致。

## 2. 复现命令

```sh
cd /home/xuqianhui/y700-elden
git -C build/elden-tree worktree add --detach /tmp/aw86927-v3 aebb727447
cd /tmp/aw86927-v3
for p in /home/xuqianhui/y700-elden/patches/upstream/aw86927-v3-prep-20261124/v3-000{1,2,3,4,5,6}-*.patch; do
  git apply "$p" && git add -A && git commit -q -m x      # 只为 format-patch 的计数
done
make -j26 ARCH=arm64 O=/tmp/kb-aw-v3 defconfig
./scripts/config --file /tmp/kb-aw-v3/.config -e INPUT_MISC -e INPUT_AW86927
make -j26 ARCH=arm64 O=/tmp/kb-aw-v3 olddefconfig
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-aw-v3 W=1 drivers/input/misc/aw86927.o
```

## 3. 边界与未做

- **未投递**（按 `TASKS/README.md` §7 逐系列批准）。投递前建议：在 linux-next 基线（v2 的原基线）上再跑一次
  `git apply` + `W=1`，因为维护者树以 linux-next 为准。
- 未做上机验证（触觉实际行为，尤其 suspend/shutdown 路径）。
- 临时 worktree / `O=` 构建目录**已在收尾时删除**。

## 4. 2026-11-24 追加：按 **linux-next master**（v2 的原基线）复验

本地无 linux-next 树，用 `git.kernel.org` 的 `plain` 接口取两枚目标文件（`drivers/input/misc/aw86927.c`、
`Documentation/devicetree/bindings/input/awinic,aw86927.yaml`，2026-11-24 快照）搭一个最小 git 树再 `git apply`：

| 项 | 结果 |
|---|---|
| 1–5 落树 | **5/5 干净** |
| 6/6 落树（**原 v2 上下文**） | **失败**：`#include` 块漂了 1 行（linux-next 在 10-27 之后加过 include） |
| 6/6 落树（**本轮重生成的上下文**） | **干净**（`patch --fuzz=3` 先验只偏移 1 行/0 语义改动，然后按新基线重出 `git format-patch`） |
| checkpatch（在**内核树内**跑，`--strict --no-signoff --no-tree`） | 6 枚 **0 条**真问题（唯一 1 条是「Unknown commit id `df53055c540f`」，因为最小树没有内核历史；在真树里可解析） |

⚠ **方法论坑（新记）**：不要在本项目仓里对内核补丁跑 checkpatch —— 目标文件不在本仓，checkpatch 会把
**补丁文件自身**当目标，报一堆假 `trailing whitespace`（本轮先被它误导了一次）。必须在内核树内跑。

⇒ v3 的 6/6 已按 linux-next master 2026-11-24 的上下文重生成（`index` 行与 hunk 偏移随之更新），
content 与"v2 内容 + 两处修复"一致；1–5 未改动。
