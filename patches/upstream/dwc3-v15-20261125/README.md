# dwc3 v15 备料（2026-11-25）——**备料完成，未投递，等放行**

- 触发：**Greg Kroah-Hartman 2026-11-24T07:14:47Z 对 v14 的回信**（MID `<2026112405-sniff-untying-8990@gregkh>`，
  原文：「Please test on real hardware before resending, AND also cc: the proper mailing lists (you forgot the usb list).」）。
  原文与判定 = `../../reports/comm-triage-20261124-e.md` §②1、`../../reports/comm-triage-20261125.md` §2.2。
- 范围：**3 个 patch 与 v14 逐字节相同**（`diff --git` 段 `cmp` 相同 + `git patch-id` 相同；见 `CHECKLIST.md`）。
  **只重写 cover**：新线程、正文首段说明「同内容，只因维护者要求补真机测试与 linux-usb 列表而重发」并引 Greg 原话，
  新增 `Testing on hardware` 段（数据**只**取 `../../reports/g7-routeA-dtfix-20261123.md` §8）。
- 收件人：`To: Thinh Nguyen`；`Cc:` **`gregkh` + `linux-usb@vger.kernel.org`**（v12/v13/v14 三代都缺 linux-usb）
  + `robh`/`krzk+dt`/`conor+dt`/`devicetree`/`linux-arm-msm`/`lkml`。
- 文件：`v15-0000-cover-letter.patch`（新写）、`v15-0001..0003-*.patch`（v14 同内容，仅 `Date:` 与 `Subject:` 的版本号 v14→v15）、
  `CHECKLIST.md`、`SEND.sh`、`logs/dry-run-20261125-160404.txt`。
- 投递：**未发**（本轮约束：禁止发邮件）。放行后 `bash SEND.sh`（默认 dry-run）→ `bash SEND.sh --send` 真发。
- 回退：本目录整体删除即可（仓内其它文件未改动；验证用 worktree 已删，`git worktree list` 无本目录残留）。

> **并发会话副作用（2026-11-25 15:52:58 发现，非本 lane 所为）**：另一会话的提交
> `4111d05c`（标题是 `docs(pitfalls): #725 checkpatch …`）把本目录当时已经落盘的
> `v15-000{1,2,3}-*.patch` 三枚一起 `git add` 进了提交（`git show --stat HEAD` 可见 1007 行新增里
> 有这三枚）。三枚内容与当前工作树**逐字节相同**（`git diff HEAD -- patches/upstream/dwc3-v15-20261125/`
> 对这三枚为空），所以没有内容损失；但 `patches/upstream/dwc3-v14-*/v14-000*.patch` 是不入库的，
> v15 这三枚现在在 HEAD 里 —— 要不要移出历史由维护者定，**本 lane 未做任何 commit/amend/push**。

## 一处必须知道的现状（v14 遗留，本轮按「不改 patch」处置）

`patches/upstream/dwc3-v14-20261124/` 里有两处**件与件不自洽**，都只在 cover 文本里，patch 内容本身没问题：

1. **v14 cover 说「Each patch carries the same disclosure below its "---" separator」，但 v14 的 1/3、2/3、3/3
   实际都没有 AI 披露段**（`grep -n 'AI-assistance' v14-000{1,2,3}-*.patch` 零命中；v13 有，v14 重出时掉了）。
   ⇒ v15 的 cover **不复述该句**，改为 series 级披露（在 tearline 之下），并在 `Changes since v14` 第 3 条里
   把这条遗留缺陷写明（诚实口径见 `AGENTS.md` 上游发信三件）。
2. **v14 cover 的 G1 门禁写的 yaml blob `7a9cb5a115a6` 是 v12/v13 的值**，与 v14 自己的 1/3 `index` 行
   （`dcfa8c3a81c5`）和 `GATES-v14.md` 都不一致。⇒ v15 的 cover 写**实测值**（本轮在 `aebb727447` 的干净
   worktree 上重跑 `git apply` + `git hash-object`，六枚 blob 逐个对过），见 `CHECKLIST.md` 第 3 条。

这两条都没有改 patch（硬约束 1）；第 1 条若要「从 patch 里补回披露」必须动 patch，只能等下一版（v16 或下一次
真正改 1/3 的版本）。

## 另一条未处理项（不阻塞投递，但下一版要答）

sashiko 2026-11-24T05:04:24Z 对**重复套 1/3**（与原线程同字节）报了 2 条 `[Low]`：
① 单连接器无 mux 路径的 plain `endpoint` 失去 `unevaluatedProperties: false`；② `'^endpoint@([2-9]|[1-9a-f][0-9a-f]+)$'`
漏 `endpoint@a`–`@f`（应为 `[2-9a-f]`）。原文 = `../../reports/comm-triage-20261124-e.md` §②2。
本轮硬约束是「不碰 patch」⇒ **v15 不带这两条修复**；下一版改 1/3 时一并处理（不需要单独回帖）。
