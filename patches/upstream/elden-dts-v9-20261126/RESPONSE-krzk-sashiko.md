# 逐条回应：Krzysztof（v8 2/2）+ sashiko 两条 [Medium]

> 只读复核于 2026-11-26（lore raw 逐字）。**本文件不是要发出的邮件**，是 v9 投递时 cover /
> 2/2 changelog 的依据账；真要回信时按最后 §3 的模板裁。

## 1. Krzysztof Kozlowski —— 唯一需要回应的评审

| 项 | 值 |
|---|---|
| Message-ID | `<179560818867.84329.911396338614062552.b4-reply@b4>` |
| Date | `Wed, 25 Nov 2026 13:03:08 +0100` = **2026-11-25T12:03:08Z**（lore 归档 12:03:11Z） |
| From / X-Mailer | `Krzysztof Kozlowski <krzk@kernel.org>` / `b4 0.17-dev`（所以 MID 是 `b4-reply@b4` 形式，**不是**伪造：DKIM `d=kernel.org` pass，见 raw 头） |
| 挂在哪 | `In-Reply-To: <20261125091309.124354-3-xiaqinghuan@mail.ustc.edu.cn>` = **2/2**（不是 cover） |
| 归档 | `/linux-arm-msm/`（raw 头 `List-Id: <linux-arm-msm.vger.kernel.org>`）；lore URL：https://lore.kernel.org/all/179560818867.84329.911396338614062552.b4-reply@b4/ |

**逐字原文（唯一一句，无其它内容）**：

```
Your changelog or cover letter should be explicit about waiting on
bindings, instead of wall of text.
```

**语义拆解 + 我方落点**

| 语义 | 他实际在要什么 | v9 落点 |
|---|---|---|
| "explicit about waiting on bindings" | 读者应在**前 10 行**内知道「这个系列现在不能合，因为等 X」 | cover 第一节 `Waiting on bindings`（A1/A2） |
| "waiting on bindings"（复数意味：可能不止一条） | 不止 WL2868C —— 你把 USB 部分挪走也是「在等 binding」，一并说明 | cover 同节末段 + dwc3 v16 的 lore URL（A2 后续段） |
| "changelog **or** cover letter" | 二选一即可；两处都写不算错，但**别只写在长文里** | 两处都写（A1–A6），2/2 的 `Changes in v9` 首条 |
| "instead of wall of text" | v8 cover **结构**有问题（论证段太长、依赖埋在 "Known dependencies" 第 4 段） | cover 分节 + 删论证段（A5） |

**结论**：这是一条**写作要求，不是设计反对**；没有任何一句质疑 DT 内容、binding 行或 commit 拆分。
⇒ v9 不需要改补丁，只需改文字；**不需要**在这个线程里先单独回一封（v9 本体即回应）。
若冻结解除后想更稳妥：v9 发出后**不**再补一封信（避免「重复确认」噪音），除非他 v9 上再提。

## 2. sashiko —— 2 × [Medium]，均在 2/2

| 项 | 值 |
|---|---|
| Message-ID | `<sashiko-outbox-232999@kernel.org>` |
| Date | `Wed, 25 Nov 2026 09:19:44Z`（投出后 6 分 19 秒） |
| 归档 | `/linux-devicetree/`（raw 头 `List-Id: <devicetree.vger.kernel.org>`） |
| 链接 | https://lore.kernel.org/all/sashiko-outbox-232999@kernel.org/ · `https://sashiko.dev/#/patchset/20261125091309.124354-1-xiaqinghuan@mail.ustc.edu.cn?part=2` |

### 2.1 `[Medium]` undocumented `willsemi,wl2868c` in `pmic@2f`

sashiko 原文要点：

```
Is there a devicetree binding schema for "willsemi,wl2868c"?  No schema
under Documentation/devicetree/bindings/ documents "willsemi,wl2868c" or
its vsys-supply, reset-gpios, and regulators child nodes, so make
dtbs_check fails validation on sm8750-lenovo-elden.dtb.
```

- **事实核查（我方）**：schema **存在且已被接收** —— `Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml`，
  在 `broonie/regulator.git for-7.5`（`84e67d2ee13f` binding、`602f57223457` driver，merge `0216753490ff`），
  也在 linux-next；只是 **v7.4-rc3 基线**里没有。作者就是本系列的作者（= 同一条线，不是第三方缺件）。
- **sashiko 并没有说错**（对它看的基线而言它是对的），所以**不能反驳**，只能声明 + 指明落点。
- **处置 = 已声明 + 提前置**（v9 cover A2 + 2/2 `Changes in v9`）；**实测**：把该 binding apply 到同一
  worktree 后 dtbs_check elden **0 条诊断**（`logs/dtbs-check-3dtb-with-wl2868c-binding-20261126.log`）。
- **不做**：不把 schema 夹带进本系列（与 `for-7.5` 的 `84e67d2ee13f` 重复，且维护者反对混装无关 binding）。

### 2.2 `[Medium]` missing core boot and power nodes

sashiko 原文要点：

```
Does this board devicetree omit core boot and power nodes such as SPMI
PMICs, RPMh regulators under &apps_rsc, console output, and storage?  The
UARTs, USB, storage, and display controllers in sm8750.dtsi are disabled by
default, leaving &i2c10 and an unused camera PMIC as the only enabled
peripherals on the board.
```

- **事实核查（我方）**：全部成立。这正是 cover "Not described, not claimed" 与 **v6 线程**已摊开说明的
  「骨架板」判定（v6 review 之后拆系列：板件本体先走，PMIC/regulator/console 随后续系列）。
- **处置 = 已声明，不改**：v9 cover 同节点名四项（SPMI PMICs / RPMh regulators / console / storage），
  并保留「boots nothing by itself」一句。**不**在本系列补节点（会把它从 2 枚变 N 枚，正是 v6 之后
  拆系列的初衷；且这些节点作者还没有真机验证路径，见 v9-prep GATES G7「上机未做」）。
- **风险自陈**：本系列合入后，`sm8750-lenovo-elden.dtb` 在上游仍是「只有 i2c10 + 相机 PMIC 使能」的板子；
  维护者可能因此选择**压着不合** —— 这是已知、已声明的取舍，不是新问题。

## 3. 若冻结解除后需要「先回一封信」的模板（**默认不采用**）

只在他 v9 上再追问「你倒底在等什么」时用；否则 v9 自身即回应。

```
Subject: Re: [PATCH v9 0/2] arm64: dts: qcom: sm8750-lenovo-elden: ...
In-Reply-To: <179560818867.84329.911396338614062552.b4-reply@b4>

On 2026-11-25 13:03 +0100, Krzysztof Kozlowski wrote:
> Your changelog or cover letter should be explicit about waiting on
> bindings, instead of wall of text.

Done in v9: the letter opens with "Waiting on bindings" and names
willsemi,wl2868c (Documentation/devicetree/bindings/regulator/
willsemi,wl2868c.yaml, in regulator.git for-7.5 as 84e67d2ee13f +
602f57223457, not in v7.4-rc3), the merge order (1/2 now, 2/2 after that
binding), and the cost of taking 2/2 early (one dtbs_check diagnostic,
quoted).  2/2's changelog says the same.  No diff changed.
```
