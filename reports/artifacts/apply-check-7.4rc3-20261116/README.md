# 上游待发系列对当前主线基线的 apply-check（2026-11-16）

> 目的：`INDEX` §0「下一步 2」列出的几组待批准系列，之前的门禁是对更早的基线（`9d66f26fef`，7.4-rc3 之前）跑的。
> 本轮把基线推到 **mainline 7.4-rc3 final = `aebb727447`**（2026-11-15 发布）重跑一遍，确认「点下去就能发」。
> 原始输出 = 本目录 `apply-check.log`，逐系列错误 = `<系列>.err`。

## 环境

```sh
git -C build/m3v2-7.3rc7 fetch --no-tags origin master:refs/remotes/gh/master   # 9d66f26fef → aebb727447
git worktree add --no-checkout /tmp/gm-7.4rc3-final aebb727447                 # 部分克隆 + 稀疏检出，避免整树拉 blob
git -C /tmp/gm-7.4rc3-final sparse-checkout set drivers/usb drivers/media/platform/qcom/camss \
    drivers/phy/qualcomm drivers/gpu/drm/msm drivers/input \
    Documentation/devicetree/bindings arch/arm64/boot/dts/qcom
```
每个系列前 `git reset --hard aebb727447 && git clean -fdq`，再按顺序 `git apply`（顺序应用，不是逐枚 `--check`：
系列内后一枚依赖前一枚，逐枚 `--check` 必假红）。

## 结果

| 系列 | 枚数 | 结果 | 说明 |
|---|---|---|---|
| `board-dts-single-20261113` | 1 | **rc=0** | 新建 `sm8750-lenovo-elden.dts` + Makefile 行 |
| `dwc3-v9-20261113` | 4 | **rc=0**（前置 = board DTS） | `v9-0004` 改的是 board DTS，所以必须后于 board 系列；单独 check 会报 `sm8750-lenovo-elden.dts` 不存在 |
| `m8-mdss-v4-20261113` | 3 | **rc=0**（前置 = board DTS） | `v4-0003` 同样改 board DTS |
| `dispcc-reset-v2-20261113` | 3 | rc=0 | **与 `m8-mdss-v4` 同内容、只是版本标签 v2**（md5 不同、patch 正文相同）⇒ 以 v4 为准，本目录属重复备料 |
| `dpu-gamma-lut-v2-20261113` | 1 | rc=0 | — |
| `m6-dsi-pll-v2-20261113` | 1 | rc=0 | — |
| `camss-csiphy-24-20261115`（2.4.0 delta） | 2 | rc=0 | 说明 phy 侧那块代码在 `9d66f26fef..aebb727447` 之间**零改动**（`git diff --stat` 空），此前结论原样有效 |
| `haptics-v2-20261113` | 6 | **原 5/6 → 6/6**（本轮已修） | `0006` 的 hunk#1 以 `#include <linux/interrupt.h>` 为上下文，而该 include **只在 linux-next 侧存在**，mainline 7.4-rc3 已没有 ⇒ 重切 hunk#1（`-15,6 +15,7` → `-15,5 +15,6`，删那行上下文），其余 9 个 hunk 本来就以 `-2` 偏移干净应用。改后 checkpatch 复跑 0 error（2 W = `Fixes: df53055c540f` 未知 commit 假阳性）。**只改上下文，不改内容**，`drivers/input/misc/aw86927.c` 改动量与编译证据不变 |

## 结论 / 待办

1. **`dwc3 v9` / `m8-mdss v4` / `dpu-gamma v2` / `m6-dsi-pll v2` / `board DTS` / `haptics v2` / `camss delta` 都能直接打在 7.4-rc3 final 上**；
   dwc3 v9 与 m8-mdss v4 的 DTS 枚**必须**排在 board DTS 之后（同一系列顺序发即可）。
2. **`dispcc-reset-v2-20261113` 与 `m8-mdss-v4-20261113` 重复** ⇒ 发 v4，别把 v2 目录再发一遍。
3. `wl2868c-v11` 的 `0002` 现在打不上（`MAINTAINERS:29063` 漂移）——**该系列 2026-11-14 已投**，仅作为记录；若要再发 v12 需先 rebase MAINTAINERS hunk。
4. `camss-csiphy-24-delta` 仍受 §4 三条约束（binding 与在飞 v6 撞段、需一次出流回归、需先在 v6/kaanapali 线程问口径）——
   7.4-rc3 final 里 **`sm8750-csi2-phy` 仍无、camss 里仍无 kaanapali**（`git grep` 空）⇒ v6 未合入，现状不变。
