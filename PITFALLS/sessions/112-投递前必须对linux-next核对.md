## #449 「上游没有 X」要连谓语一起读 —— 我把「无固件装载」误读成「无波形装载」，并据此写错了归因

> 2026-10-27 晚。为回答 Konrad 的「基线换 `linux-next/master`」，把所有在途系列对 linux-next 过了一遍。
> 本轮**先写错、后自查纠正**：错判进了报告、任务台账与索引三处，纠正也落在三处。
> 完整表 = `reports/upstream-dedup-audit-20261027.md`（§2 已有「纠正本报告上一版」段）。

### 一、错在哪（逐条）

| 我写的 | 实际 |
|---|---|
| 「aw86927 的波形装载已被**上游半路占据**（linux-next 新加）」 | **错**。驱动内正弦表由 `df53055c540f`「Input: aw86927 - add support for Awinic AW86938」引入，**7.3-rc7 就有**（`grep -c aw86927_waveform` = 3） |
| 「10-13 核实的『上游无波形装载路径』两周就过时了」 | **错在引用**。U4 原文是「上游无**固件**装载路径」（`no request_firmware() path`），这句**一直成立**；是我把「固件」读丢了 |
| 「`0003`/`0005` 是功能冲突，系列必须重构」 | **错在归因**。linux-next 相对 7.3-rc7 在这个文件只漂移 **1 行**：新增 `#include <linux/interrupt.h>`，正落在 `0003` 第一个 hunk 的上下文里；`0005` 的上下文含 `0003` 新增的行 = **系列内依赖**（本来最后才套） |

### 二、三条教训

- **读结论连谓语一起读**。「没有 X」有三种完全不同的意思：没有该**能力**、没有该**实现**、
   没有该**实现中的某个变体**（固件 vs 驱动内数据）。差一个词，结论相反。
- **`git apply` 失败先定位到失败 hunk 的行号与上下文，再归因**。
   本轮报错行号是 10（include 块），我却按「功能冲突」解释——因为我已经先有了一个想要的结论。
   判据：失败行号落在 include/#define 区 = 上下文漂移；落在函数体且 `--3way` 也过不去 = 真冲突。
- **归因分层：功能面 / 接口面 / 文本面**。去重核对的三步（见下）只回答「有没有」，
   **不回答「为什么套不上」**；后者必须单独查。

### 三、可复用的核对三步（10 min，纯主机，仍然要做）

```sh
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890
B='https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain'

# ① binding / 文档：404 = 上游没有
curl -sSL -o /dev/null -w '%{http_code}\n' "$B/Documentation/devicetree/bindings/…?h=master"

# ② 功能面：grep 目标符号
curl -sSL "$B/drivers/input/misc/aw86927.c?h=master" | grep -c 'request_firmware\|AW86937'

# ③ 能否套：最小仓只放目标文件，逐枚 **顺序** git apply（孤立判会假失败）
```

④ 还要查**引入提交**：`https://git.kernel.org/…/log/<path>` 的 HTML 里 `?id=<sha>` 与标题能直接给你
`Fixes:` 需要的 hash（本轮 `df53055c540f` 就是这么核到的，不是猜的；本地仓 shallow 时 checkpatch
会报 `Unknown commit id`，属本地盲区不是补丁问题）。

### 四、另一类错（同轮，仍然有效）

提交信息写错「回落对象」：M2 A2 v1 写「falls back to `QCOM_BATTMGR_SM8350`」，实际 DT 的
`compatible` 第二项是 `qcom,sm8550-pmic-glink` ⇒ 按 compatible 顺序命中 **SM8550**。v2 已改正。
写「回落/默认是 X」之前，去读板级 DTS 的 compatible 顺序与 `of_match_table` 实表，不要只看
`/* Unmatched devices falls back to … */` 那条注释（那描述的是**最后一个表项**，不是本条路径）。

### 五、顺带确认（这些仍然有效，不必重做）

M2 P3、M3-1、M3-3、M3-4、M4-1、M6 L1、M8、M1-U6 在 linux-next master 上**全部没有被重复实现**；
其中 M1-U6（`qcom_q6v5_pas` DTB 固件泄漏）在 linux-next 上**同病**，补丁直接 `git apply --check` rc=0。
