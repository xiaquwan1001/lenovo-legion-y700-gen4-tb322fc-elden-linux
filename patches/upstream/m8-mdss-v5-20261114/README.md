# M8 mdss v5（2026-11-14，**已发送**）

- 触发（两条，均为 2026-11-13）：**Konrad Dybcio** 对 v4 3/3 给 `Reviewed-by`；
  **sashiko（AI 评审）** 提 **Medium**——0xa000 不是「中断控制器复位」，而是 dispcc 单独描述的域
  （自己的 `mdss_int2_gdsc` @0xb000 + `mdp1` 族时钟），而 mdss 节点**没 attach 它**，却去 assert 它的 BCR。
- 质疑**成立**（`sm8750.dtsi:3335` `power-domains` 只有 `MDSS_GDSC`；`:3322-3324` clocks 无 `mdp1` 族）。
  另自曝一个自证缺陷：**15/15 实测是三枚**（含 RSCC），v4 已按 Dmitry 要求删成两枚 ⇒ v4 形状从未上机验证。
- 处置 = 用户放行「按推荐做」，推荐 = **保留 3/3、只收窄 commit message**：
  - 回信（承认质疑 + 给出可观测事实 + 明确两条测量边界 + 声明无 datasheet 直证 + 附收窄后的 message）
    `out/mail-20261114/re-sashiko-mdss-v4.txt|.mbox`，MID `<20261113234851.42e0bacd02fa-xiaqinghuan@mail.ustc.edu.cn>`，
    `In-Reply-To` = v4 3/3 `<8a0c75949fcf428a2163a2e63b27fcf08d3b4f9c.1794558882.git.xiaqinghuan@mail.ustc.edu.cn>`。
- **v5 形状**：1/3、2/3 与 v4 逐字节相同；3/3 **diff 逐字节相同、只改 Subject 与 message**。
  三个 R-b（Abel Vesa / Dmitry Baryshkov / **Konrad Dybcio**）全保留。
- 门禁（本轮实跑）：pristine v7.3-rc7（`24a19b953e`）`git am` **3/3 干净**；`checkpatch --strict` 3/3
  **0E/0W/0C**；3/3 diff vs v4 逐字节相同 ⇒ v4 的 `dt_binding_check` 与 `W=1` 结论继续有效。
- 投递：`out/mail-20261114/send-mdss-v5.log`（**4 × `Result: 250`**，`--thread` 新线程）。
  全账 `reports/mail-send-20261114-mdss-v5.md`。
- 本目录文件名为 `git format-patch` 原样输出（未按 `v5-` 前缀重命名）；同一系列的历史版本在
  `../m8-mdss-v4-20261113/`（保留作审计链，勿再投）。

## Message-ID

| # | Message-ID |
|---|---|
| 0/3 | `<20261113155635.1677541-1-xiaqinghuan@mail.ustc.edu.cn>` |
| 1/3 | `<20261113155635.1677541-2-xiaqinghuan@mail.ustc.edu.cn>` |
| 2/3 | `<20261113155635.1677541-3-xiaqinghuan@mail.ustc.edu.cn>` |
| 3/3 | `<20261113155635.1677541-4-xiaqinghuan@mail.ustc.edu.cn>` |

## 已知遗留（**未修**，下一版或收信时处理）

1. **1/3 丢了 Rob Herring 的 `Acked-by`**：v3 1/3 有 `Acked-by: Rob Herring (Arm)`（patchwork 2026-11-10T19:27:44Z），
   v4/v5 的 1/3 正文与 v3 相同却只带 `Signed-off-by`（v4 与 v5 均如此，v5 未改 1/3 故沿用）。
   若发 v6（无论删不删 3/3）应把该 Acked-by 补回。
2. **测量边界未闭合**：`0xa000` 单变量 A/B 与「v4/v5 两枚形状」的上机验证**都没做**
   （`reports/mdss-int2-evidence-20261113.md` §2.3 标「未证实」）。

## 下一步（等回信）

- 若 Konrad/Dmitry 接受 v5 ⇒ 等 Bjorn 收。
- 若要求 (b) ⇒ 发 v6：删 3/3，只留 1/3+2/3（2/3 的数组 API 无争议），并把 1/3 的 Rob Acked-by 补回。
