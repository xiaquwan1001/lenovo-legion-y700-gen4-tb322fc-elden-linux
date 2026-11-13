# M8 mdss v5 + 回 sashiko/Konrad（2026-11-14，**已发送**）

> 触发：v4 投出后收到两条回信（2026-11-13）：
> - **Konrad Dybcio** 给了 `Reviewed-by`（v4 3/3）；
> - **sashiko（AI 评审）** 提 **Medium** 质疑：0xa000 不是中断控制器，而是 dispcc 里一个**独立域**
>   （自己的 `mdss_int2_gdsc` @0xb000 + `mdp1` 族时钟），而 mdss 节点**没有 attach 它**
>   （`power-domains` 只有 `MDSS_GDSC`、`clocks` 无 `mdp1`），却去 assert 它的 BCR。
>
> 本轮处置 = 用户放行「按推荐做」⇒ **推荐 (a)**：保留 3/3、只收窄 commit message。两封信都已发出。

## 1. 先核实质疑是否成立（成立）

| 事实 | 位置 |
|---|---|
| mdss 节点 `power-domains = <&dispcc MDSS_GDSC>`（**只有主域**） | `sm8750.dtsi:3335` |
| mdss `clocks` = AHB_CLK / GCC_DISP_HF_AXI_CLK / MDP_CLK（**无 `mdp1` 族、无 `ahb1`**） | 同上 `:3322-3324` |
| dispcc 把 0xa000 描述成独立域：`[DISP_CC_MDSS_CORE_INT2_BCR] = { 0xa000 }` + `mdss_int2_gdsc`(0xb000) + `disp_cc_mdss_mdp1_clk` | `dispcc-sm8750.c:1870/1765/1555` |

⇒ sashiko 读代码是对的。v4 3/3 原话「a block reset for the MDSS core INT2 **interrupt controller**」
和「INT2 is part of the same block」**都过头了**。

**同时发现我们自己的一个自证缺陷**（必须写进信里）：
15/15 的实测是**三枚**（`0x8000+0xa000+0xc000`，含 RSCC），而 v4 已按 Dmitry 要求删掉 RSCC
只剩两枚 ⇒ **v4 这个形状从未上机验证过**。另外 `0xa000` 从未做过单变量隔离。

## 2. 回信（已发）

- 文件 `out/mail-20261114/re-sashiko-mdss-v4.txt` / `.mbox`
- MID **`<20261113234851.42e0bacd02fa-xiaqinghuan@mail.ustc.edu.cn>`**
- `In-Reply-To` = v4 3/3 `<8a0c75949fcf428a2163a2e63b27fcf08d3b4f9c.1794558882.git.xiaqinghuan@mail.ustc.edu.cn>`
- To Konrad；Cc linux-arm-msm / dri-devel / devicetree / lkml / Dmitry / Abel / Rob / Krzysztof / Conor / Bjorn
- `Result: 250`
- 内容要点：承认 sashiko 的读法正确 → 给出可观测事实（base 9 发 5 败 vs 组 15/15）→
  **明确标注两条边界**（三枚≠v4 两枚、未做单变量）→ 声明**没有 datasheet 级直证** →
  给出 (a)/(b) 两选项并说明选 (a) → 披露 AI 辅助 → **附上收窄后的 3/3 message 供确认**

## 3. v5 系列（已发，4×`Result: 250`）

`patches/upstream/m8-mdss-v5-20261114/`（`git format-patch` 从 `24a19b953e..5449e4c885` 生成，非手改）：

| # | 文件 | 说明 |
|---|---|---|
| 0/4 | `0000-cover-letter.patch` | v5 说明：1/3、2/3 未变；3/3 diff 逐字节相同、只改 message；三个 R-b 全部保留；写明测量边界与「若认为不可接受可发 v6 去掉 3/3」 |
| 1/4 | `0001-dt-bindings-…` | 未变 |
| 2/4 | `0002-drm-msm-mdss-reset-all-…` | 未变（`devm_reset_control_array_get`） |
| 3/4 | `0003-arm64-dts-…describe-the-second-MDSS-block…` | **message 重写**：去掉「interrupt controller」「same block」；改为「dispcc 提供两枚块复位，第二枚属于它单独描述的域」+ 三条可观测事实 + 测量边界；三个 R-b（Abel/Dmitry/**Konrad**） |

- MID：`<20261113155635.1677541-1…-4-xiaqinghuan@mail.ustc.edu.cn>`
- 日志 `out/mail-20261114/send-mdss-v5.log`

## 4. 门禁（本轮实跑）

| 门禁 | 结果 |
|---|---|
| `git am` 3/3 on pristine v7.3-rc7 (`24a19b953e`) | **干净 3/3** |
| `checkpatch --strict`（3/3） | **0E/0W/0C** |
| 3/3 diff vs v4 | **逐字节相同**（只改 message 与 Subject） |
| 代码/DT 未变 | ⇒ v4 的 `dt_binding_check` 与 `W=1` 结论继续有效 |

## 5. 下一步（等回信）

- 若 Konrad/Dmitry 接受 v5 ⇒ 等 Bjorn 收。
- 若被要求 (b) ⇒ 发 v6：删 3/3、只留 1/3+2/3（2/3 的数组 API 无争议）。
- **仍然存在的能力缺口**：`0xa000` 单变量 A/B 与 v4/v5 两枚形状的上机验证都没做
  （`reports/mdss-int2-evidence-20261113.md` §2.3 已标「未证实」）。
