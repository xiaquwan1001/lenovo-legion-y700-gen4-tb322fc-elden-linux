# M8 mdss v4（2026-11-13，**已发送**）

- 触发：Dmitry 对 v3 2/3 的三问（`<awb7bslhrhemsgvu7ubaejvurk6fecotgvqlwtvsoe2benqdgq@tvh2sfjbuzyu>`，11-11）：
  它是不是中断控制器 / 副作用是什么 / 怎么测的。
- 先回信（`out/mail-20261113/re-mdss-3q.txt`，MID `<179455879170.604684.2366646128926922044@mail.ustc.edu.cn>`），
  再发 v4：**只重写 3/3 的 commit message**，diff 与 v3 逐字节相同（除 message）。
- v4 去掉的因果声称：v3 3/3 写「command-mode panel init fails with command DMA timeouts ...
  because INT2 was left out of reset」—— 失败是 ~50% 间歇，从未把 INT2 隔离成单变量，该因果无数据支撑。
  现在只陈述：MDSS 在 DT 里是 interrupt controller（DPU 用 `interrupts-extended = <&mdss 0>`）、
  dispcc 提供两枚块复位、固件可能带着运行中的显示块交接 ⇒ DT 描述两枚复位。
- 3/3 带上 v3 收到的两个 R-b：Abel Vesa（11-02）、Dmitry Baryshkov（11-11）。
- 门禁：pristine v7.3-rc7（`24a19b953e`）`git am` 3/3 干净；checkpatch --strict 3/3 = 0E/0W/0C；
  代码/DT 未变 ⇒ v3 的 dt_binding_check 与 W=1 结论继续有效。
- 投递：`out/mail-20261113/send-mdss-v4.log`（4 × `Result: 250`），新线程 `--thread`。

## Message-ID

| # | Message-ID |
|---|---|
| 0/4 | `<cover.1794558882.git.xiaqinghuan@mail.ustc.edu.cn>` |
| 1/4 | `<114cd1bcce56c1267059826f7c9619d835a2912d.1794558882.git.xiaqinghuan@mail.ustc.edu.cn>` |
| 2/4 | `<a545b3898ac87742b57a6f44fb5fcd4b4bcb99da.1794558882.git.xiaqinghuan@mail.ustc.edu.cn>` |
| 3/4 | `<8a0c75949fcf428a2163a2e63b27fcf08d3b4f9c.1794558882.git.xiaqinghuan@mail.ustc.edu.cn>` |

## 回信给出的三问答案（供下次复用）

1. **是中断控制器**：`sm8750.dtsi` 的 mdss 节点有 `interrupt-controller;` + `#interrupt-cells = <1>`，
   DPU 子节点 `interrupts-extended = <&mdss 0>`；dispcc-sm8750 里 `MDSS_INT2_GDSC` +
   `DISP_CC_MDSS_CORE_INT2_BCR`(0xa000)，与 `DISP_CC_MDSS_CORE_BCR`(0x8000) 并列。
2. **副作用**：`msm_mdss_reset()` 在 `msm_mdss_probe()`:372，irq domain 创建在 :417、
   `of_platform_populate()` 在 :537 ⇒ 复位发生在 irqchip 注册与 DPU 之前；20 ms 保持沿用上游；
   不碰 dispcc PLL/时钟；RSCC 已按他要求删。
3. **怎么测的**：位置（mdss probe、dispcc PLL 之后）在 core+INT2+RSCC 三枚 bulk 形态下实测
   5/5 真 POR + 2/2 暖复位无坏发；只复位 core 的 base 臂 9 发 5 次 STORM。**未测** v4 形状
   （数组 API + 两枚）与「INT2 单变量 A/B」。

## ★2026-11-14 后续：v5 已发（本 v4 已被取代）

v4 投出后收到两条回信（11-13）：
- **Konrad Dybcio** 给 `Reviewed-by`（3/3）；
- **sashiko（AI 评审）** 提 **Medium**：0xa000 是 dispcc 里一个**独立域**（自己的 `mdss_int2_gdsc` +
  `mdp1` 族时钟），mdss 节点**没 attach 它**，却 assert 它的 BCR。

**质疑成立**（`sm8750.dtsi:3335` power-domains 只有 `MDSS_GDSC`；`:3322` clocks 无 `mdp1`）。
另发现自证缺陷：15/15 实测用的是**三枚**（含 RSCC），而 v4 只剩两枚 ⇒ **v4 形状未上机验证过**。

处置（用户放行「按推荐」，推荐 = 保留 3/3 只收窄措辞）：
- 回信 `out/mail-20261114/re-sashiko-mdss-v4.txt`（MID `<20261113234851.42e0bacd02fa-xiaqinghuan@mail.ustc.edu.cn>`），
  承认质疑、给出可观测事实与两条边界、声明无 datasheet 直证、附收窄后的 message；
- **v5 已发**：`patches/upstream/m8-mdss-v5-20261114/`（3/3 diff 逐字节相同、只改 message +
  subject 改 "describe the second MDSS block reset"；三个 R-b 全保留）。
- 全账 `reports/mail-send-20261114-mdss-v5.md`；本 v4 目录**保留作审计链**，勿再投。
