# v8 → v9 逐条改动说明（2026-11-26）

> 触发件：Krzysztof Kozlowski `<179560818867.84329.911396338614062552.b4-reply@b4>`
> （2026-11-25 12:03:08Z，`In-Reply-To: <20261125091309.124354-3-…>`；lore：
> https://lore.kernel.org/all/179560818867.84329.911396338614062552.b4-reply@b4/ ）
> 原文一句：
> > Your changelog or cover letter should be explicit about waiting on bindings,
> > instead of wall of text.
>
> **硬事实**：v9 **没有任何代码/DT 改动**。下表逐条给「要求 → 落点」。

## A. 对 Krzysztof 那一条的落实

| # | 要求拆解 | v9 落点（可 grep） | 原文形状 |
|---|---|---|---|
| A1 | 必须**显式**说「本系列在等 bindings」 | `v9-0000-cover-letter.patch` 第一节标题 = `Waiting on bindings`，第一句 = `Stated up front, as requested:` | `grep -n "Waiting on bindings" v9-0000-cover-letter.patch` |
| A2 | 要**点名**等哪个 binding / 在哪 | 同节 `2/2 waits on willsemi,wl2868c` + 文件路径 `Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml` + 落点 `regulator.git for-7.5` + 两个 commit（`84e67d2ee13f` binding、`602f57223457` driver）+ 「v7.4-rc3 里没有，7.5 合并窗口进 mainline」 | 同节 |
| A3 | 要讲**合并顺序**（维护者最关心的可操作性） | 同节 `Merge order`：1/2 无依赖可立刻合；2/2 等 binding；「先 1/2、7.5-rc1 后再 2/2 也可以，不必重投」 | 同节 |
| A4 | 提前合 2/2 的**代价**要可核对 | 同节 `Cost of taking 2/2 early`：给出唯一那条诊断的**逐字**原文 + 括号指向 `Checks` 里的实测数字（带 binding = 0 条，不带 = 1 条） | 同节 + `Checks` 末两条 |
| A5 | **别用墙纸文字** | cover 由 ~120 行散文压到 ~95 行且**分节**（Waiting / The two patches / Relation / Not described / Checks / Disclosure）；删掉 v8 里「Why that is a real gap and not cosmetics」整段论证，只留一句结论 + 诊断引文 | `v9-0000-cover-letter.patch` 全文 |
| A6 | changelog **或** cover —— 两处都写，别让他在 2/2 里再问一次 | `v9-0002-…-Gen4.patch` tearline 下 `Changes in v9:` 首条即依赖 + 文件 + commit + 合并顺序 + 唯一诊断 | `sed -n '/^Changes in v9:/,/^Changes in v8:/p' v9-0002-*.patch` |

## B. 对 sashiko 两条 `[Medium]` 的处置（**声明 + 逐条点名，不改代码**）

| # | sashiko 原文（`<sashiko-outbox-232999@kernel.org>`，2026-11-25T09:19:44Z，挂 2/2） | v8 是否已声明 | v9 处置 |
|---|---|---|---|
| B1 | 「Is there a devicetree binding schema for "willsemi,wl2868c"? … make dtbs_check fails validation」 | 是（cover "Known dependencies" 埋在第 4 段） | **不需要改**：binding 就是 A2 那条，已进 `for-7.5`。v9 把它从「埋着」提到 cover 第一节 + 2/2 changelog（= 同时回答 sashiko 与 Krzysztof） |
| B2 | 「Does this board devicetree omit core boot and power nodes such as SPMI PMICs, RPMh regulators under &apps_rsc, console output, and storage?」 | 是（cover "What is in here, and what is not" + v6 线程） | **不需要改**：属**故意不在本系列**的范围，cover "Not described, not claimed" 保留并点名同四项；v6 已判定为「骨架板，随后续系列补」 |
| B3 | 判据说明 | — | 两条都**不产生 diff**：sashiko 的 B1 指向的是外部 binding 缺失（实测：加上 binding 后 dtbs_check 0 条，见 `logs/dtbs-check-3dtb-with-wl2868c-binding-20261126.log`），B2 是本系列明确声明的范围边界 |

> 为什么要「点名」而不是「沉默」：sashiko 的 note 已归档进 v8 线程，沉默会让后来读线程的人
> 以为未处理；逐条点名 + 指落点 = 一条消息同时结掉机器人 note 与 Krzysztof 的写作要求。

## C. 机械差异（v9 vs v8，逐字节可验）

| 文件 | 差异 | 验证 |
|---|---|---|
| `v9-0000-cover-letter.patch` | 全新正文（v8 无对应物；结构见 A） | — |
| `v9-0001-…-Y700.patch` vs `v8-0001-…` | `Subject` 的 `v8`→`v9`；`Date` 25→26 日 | `awk '/^diff --git/{f=1} f'` 后 `cmp` **相同** |
| `v9-0002-…-Gen4.patch` vs `v8-0002-…` | `Subject` 的 `v8`→`v9`；`Date`；tearline 下新增 `Changes in v9:` 段（v8 段保留在其下） | 同上，diff 段 **相同** |
| 板件本体 | **零改动**（`git hash-object` = `73f4452f46`，与 v7、v8 同日记录一致） | `logs/` + README §3 G1 |

## D. 没做的事（明确留白，不许读成已做）

- 没有为 sashiko B1 去 **vendoring** 一份 wl2868c schema 到本系列（会与 `for-7.5` 的
  `84e67d2ee13f` 冲突/重复，且维护者最反感夹带无关 binding）。
- 没有把 USB 那部分并回 v9（它依赖 dwc3 binding，仍在审：v16
  `<20261125142309.3265777-1-xiaqinghuan@mail.ustc.edu.cn>`，sashiko 已判无问题，等 Thinh/Greg）。
- 没有回信给 Krzysztof（冻结中，且按项目口径「v9 承载回应」比「先回一封信再发 v9」省一轮）。
