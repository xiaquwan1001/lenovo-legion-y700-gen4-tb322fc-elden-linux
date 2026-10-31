# #478 投递前必须跑「系列自足性重放」，裸 diff 不能 `git am`

> 2026-10-31 立（阻塞项调查轮，M3v5 + B5 两处同时踩到）。
> 索引行见 `PITFALLS/README.md` 表末（#478）。

## 现象

投递前门禁只看 `checkpatch`（0E/0W/0C）+ 目标文件编译 + `dt-doc-validate`，仍然出事：

- **M3v5**：2 枚补丁对 **pristine 上游不自足**（缺前置依赖，reviewer 无法 apply），且**没有 cover letter**、没有 `base-commit:`。
- **B5 本地序列**（`patches/local/b5-resoc-20261027/`）：按文件名序重放，`0004` 是**裸 `diff --git`**（首行不是 `From <sha> Mon Sep 17 …`），`git am` 报 **「补丁格式探测失败」**；`0005` 与 `0002` 冲突（`0002` 已把 `dsi_cmd_error_prepare()` 改成 `bonded->err_clear_bits`，`0005` 的旧侧上下文还是改前的 `{ u32 val; …}`）。

## 根因

- 「补丁内容对」≠「补丁可投递」。可投递要求三件事：**格式**（`git format-patch` 头 + `Subject`/`From`/日期）、**自足**（在声明 base 上按序 apply）、**有 cover/base-commit**。
- `checkpatch` 读的是 diff 正文，对首行是不是 `From` 完全不敏感 ⇒ 裸 diff 会一路绿灯。
- 手工改过的 `.patch`（改注释、剪 hunk）容易把 **hunk 计数**改坏，而计数错只会在 `git apply` 时报「补丁损坏」，`checkpatch` 不报。
- 就地"重写注释"会让两个补丁对同一函数的**上下文分叉**，后一枚的旧侧上下文失效 —— 单看每一枚都"语法合法"。

## 判据 / 工具

`scripts/check-series-selfcontained.sh <patch-dir> [<base-ref>] [--repo <tree>]`：

- 建**临时 worktree** 到 `/tmp`，按文件名序逐枚 `git apply --check` → `git apply` / `git am --3way`；收尾 `worktree remove --force` + `prune`。
- 首行正则区分 **format-patch** 与**裸 diff**：裸 diff 只过 `apply` 并记 **WARN「不能 git am / 不能直接投递」**（关键：不要把「格式失败」误诊成「内容不自足」）。
- 目录内无 `*0000*`/`*cover*` ⇒ **WARN 缺 cover letter**。
- `--self-test`：内置正例（3 枚，含 cover）+ 负例（删 0001 后剩依赖它的 0002）⇒ 正例 PASS、负例必须在 0002 处 FAIL 且退出码 1。
- 汇总行 `PASS/FAIL/WARN` + 退出码，可直接进门禁链。

## 用法（投递前固定跑）

```bash
bash scripts/check-series-selfcontained.sh --self-test
bash scripts/check-series-selfcontained.sh patches/upstream/<series> <base-commit> --repo <kernel-tree>
```

实测落点：`m3v5-20261030` 对 `24a19b953e` **FAIL**、对 `fd69bd54e3` **PASS 2/2**；`q28-dispcc-v2-20261029` 对 `24a19b953e` **PASS 3/3**（唯 WARN 缺 0000 存档）；`patches/local/b5-resoc-20261027` 对 `0f1fb1c9c1` **PASS=4 FAIL=1 WARN=2**。

## 顺带记住的三条

- **base 不能是系列自身 tip**：`reports/code-boundary-preinject-20261031.md` 曾把 `34865c8915`（= v5 自身 tip）当 base ⇒ 「终态与 tip 逐字节相同」是自指。base 必须是系列**父提交**。
- `git am` 失败文案要分清：**「补丁格式探测失败」= 不是邮件格式**；**「补丁不适用 / 冲突」= 内容问题**。混在一起会把重出方向带偏。
- 与 `#474`（`checkpatch` 必须 stdin，文件参数会假报 ERROR）同类：**工具调用形态本身会制造假阴性/假阳性**，投递类门禁每条都要有正负例自检。
