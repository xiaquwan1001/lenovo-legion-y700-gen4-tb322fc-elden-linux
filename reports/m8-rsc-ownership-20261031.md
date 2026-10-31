# M8 RSC 归属静态取证：RSC/RSCC 是否属于 MDSS 可复位域（2026-10-31）

> 派工单：M8 —— 回答二值问题「Konrad：RSC 不属于 MDSS」是否成立，据此处置 `patches/upstream/q28-dispcc-v2-20261029/` 三枚补丁。
> 纪律：只读主线代码；证据命令落 `reports/artifacts/m8-rsc-20261031/`（5 个 log）。
> 树口径：上游 7.3-rc7 = `build/vk151`（@`509f271d52`，其 sm8750.dtsi 已含 v2 0003 补丁）；上游 7.2 参照 = `linux/`；vendor DT = `reference/stock-elden.dts`（反编译 overlay）。

## 0. 结论表

**二值裁定：RSC/RSCC 不属于 MDSS 可复位域 —— 成立（静态证据充分）。**
但注意：Konrad 信中把「RSC 在自己的节点 `apps_rsc@16500000`」当例证是**张冠李戴**——那是 RPMh RSC（`qcom,rpmh-rsc`），与 `DISP_CC_MDSS_RSCC` 是两个不同硬件块（地址/compatible/dispcc 时钟全部不同）。RSCC 的正确归属证据是 vendor DT 的 `sde_cesta`（reg 名 `"rscc"` @ `0x0af20000`，mdss_mdp 的 connector 之一，由显示侧驱动持有）。**结论对、例证错**；回信已按其结论承诺 v3 删 RSCC，方向不受影响。

| # | 判据 | 正面（RSC 属于 MDSS 域） | 反面（不属于） | 裁定 |
|---|---|---|---|---|
| J1 | 复位/时钟寄存器位置 | 名字都带 `MDSS` | 三个 BCR（0x8000/0xa000/0xc000）全在 dispcc 窗口 [0x0af00000,0x0af20000)，**无一落在 mdss 窗口 [0x0ae00000,0x0ae01000)**（file:line 见 §3） | 寄存器图论据只支持"复位位在 dispcc"，**不裁决块归属**（此即回信自陈的层级差异） |
| J2 | RSCC 硬件块归属 | 名字 `DISP_CC_MDSS_RSCC`；dispcc probe 常开其 AHB/VSYNC 时钟（clk 0xc008/0xc00c） | vendor DT：RSCC 块 = `sde_cesta` 的 `"rscc"` reg @ **0x0af20000**，在 dispcc 窗口**外**、mdss_mdp reg 窗口 [0x0ae00000,0x0ae93800) **外**；该节点是 `mdss_mdp` 的 `connectors` 成员、由 vendor 显示驱动持有（§3 E5/E6） | **不属于 mdss wrapper 的任何 reg 窗口**；属显示子系统但非 mdss 节点 |
| J3 | 上游 DT 消费者 | — | `rg RSCC` 在上游全部 qcom dtsi **零命中**（0 个节点消费 RSCC 时钟/复位）；`mdss-common.yaml` 的 `resets` 只描述 `MDSS_CORE` 一项（§1 E4） | 上游从未把 RSCC 当 mdss 子块描述 |
| J4 | Konrad 例证 | 引用 `apps_rsc: rsc@16500000`（build/vk151 dtsi:6251，`qcom,rpmh-rsc`） | 该块无 `DISP_CC_MDSS_RSCC_*` 时钟/复位引用，地址相距 0x3b00000，是 RPMh 域控制器不是显示 RSC（§3 E7） | **例证错误，但独立于结论**：结论由 J2/J3 独立支撑 |
| J5 | 疗效（是否 load-bearing） | vendor 栈上 CORE+INT2+RSC 三枚一起复位才消除面板 init 失败，从未单独测（`reports/q28-disp-init-ab-20261022.md` 行 10） | 未做单变量隔离 | **无法判定**；需真机冷起 A/B 重测 CORE+INT2（已列为 N4） |

## 1. 上游 dispcc 里 RSC 相关访问点（7.2 与 7.3 一致）

| file:line | 事实 | 证据命令 |
|---|---|---|
| build/vk151/drivers/clk/qcom/dispcc-sm8750.c:1869-1871 | 复位表三项：`CORE_BCR={0x8000}`、`CORE_INT2_BCR={0xa000}`、`RSCC_BCR={0xc000}` | `grep -n "RSC\|BCR" .../dispcc-sm8750.c`（artifacts/upstream-dispcc-sm8750-rsc.log） |
| build/vk151/.../dispcc-sm8750.c:1932-1933 | probe 时 `qcom_branch_set_clk_en(regmap, 0xc00c/0xc008)` 常开 `DISP_CC_MDSS_RSCC_AHB/VSYNC_CLK` | 同上 |
| linux/drivers/clk/qcom/dispcc-sm8550.c:1535-1560,1716-1717,1731 | 同类：sm8550 也有 `rscc_ahb/vsync` 分支时钟 + `RSCC_BCR={0xc000}`（同偏移，非 sm8750 特有） | `rg "RSCC" linux/drivers/clk/qcom/dispcc-sm8550.c`（artifacts/linux-dispcc-rsc.log） |
| linux/drivers/clk/qcom/dispcc-sc8280xp.c:2945-3042 | sc8280xp 双 dispcc 各有 RSCC AHB/VSYNC + `RSCC_BCR={0x4000}` | `rg -ln "RSCC_BCR" linux/drivers/clk/qcom/`（artifacts/upstream-dispcc-rscc-files.log，27 个文件） |
| linux/Documentation/devicetree/bindings/display/msm/mdss-common.yaml:97-100 | `resets:` 只有一项 `MDSS_CORE reset`；`qcom,sm8750-mdss.yaml:104` example 同 | `sed -n '90,115p' mdss-common.yaml` |

**结论**：上游 dispcc 系列对 RSC 的访问点全部是"clk 分支 + BCR 定义"，**没有任何复位名单/驱动代码把 RSCC_BCR 归给 mdss**；同类平台（sm8550/sc8280xp/sc7180/sdm845）上游 DT 也从未在 mdss 节点列 RSCC_BCR。

## 2. vendor 血统树对照

| file:line | 事实 | 证据命令 |
|---|---|---|
| reference/stock-elden.dts:11622-11640 | `sde_cesta@0x0af30000`：`reg-names = "rscc","wrapper","scc_0".."scc_5"`，`reg = <0xaf20000 0x850 0xaf30000 0x60 ...>` | `rg -n -i "rscc" reference/stock-elden.dts` |
| reference/stock-elden.dts:5600 | `mdss_mdp: qcom,mdss_mdp@ae00000` 的 `connectors = <... , &sde_cesta>` | 同上 |
| reference/stock-elden.dts:5598-5636 | vendor mdss_mdp reg = `0xae00000+0x93800, 0xaeb0000, 0xaf80000(regdma), ...` —— **不含 0xaf20000**，RSCC 是 mdss_mdp 之外的独立 region | `awk 'NR>=5598&&NR<=5800&&/reg = |reg-names/'` |
| build/vk151/.../sm8750.dtsi:6251-6268 | `apps_rsc: rsc@16500000` compatible = `qcom,rpmh-rsc`（RPMh，非显示 RSC） | `rg -n "rsc@|rpmh-rsc" sm8750.dtsi` |
| reference/vendor-display-sm8750/ | 本地 vendor 显示驱动快照（dsi_ctrl/dsi_pll 等）**不含** RSCC/cesta 源文件，无法从驱动侧补证 | `rg -ln "rscc" reference/vendor-display-sm8750/`（0 命中） |

## 3. DT 地址区间算术（sm8750）

| file:line | 事实 | 证据命令 |
|---|---|---|
| E1 build/vk151/.../sm8750.dtsi:3321-3324 | `mdss` reg = `0x0ae00000 + 0x1000` → [0x0ae00000, 0x0ae01000) | sed |
| E2 build/vk151/.../sm8750.dtsi:3730-3732 | `dispcc` reg = `0x0af00000 + 0x20000` → [0x0af00000, 0x0af20000) | grep -A6 |
| E3 dispcc-sm8750.c:1869-1871 | CORE_BCR=0x0af08000、INT2_BCR=0x0af0a000、RSCC_BCR=0x0af0c000 | grep |
| E4 stock-elden.dts:11634-11635 | vendor `"rscc"` region = 0x0af20000+0x850（dispcc 窗口外、mdss 窗口外） | rg |
| E5 stock-elden.dts:5600 | sde_cesta 是 mdss_mdp 的 connector（显示侧设备） | 同上 |
| E6 上游 sm8750.dtsi 全文 | `0xaf2xxxx` 无任何节点描述（RSCC 区域上游未建模） | `rg -n "af2[0-9a-f]{4}" sm8750.dtsi`（0 命中） |
| E7 build/vk151/.../sm8750.dtsi:6251-6252 | `apps_rsc: rsc@16500000` = `qcom,rpmh-rsc`（与 RSCC 无关） | 同上 |

**MDSS 窗口内/外计数**：`resets` 名单 3 项中，落在 MDSS 寄存器窗口 [0x0ae00000,0x0ae01000) 内的条数 = **0**；窗口外（dispcc 窗口内）= **3**；上游同类实现中 mdss DT 节点引用 RSC 的数量 = **0**。

## 4. 对 q28-dispcc-v2 三枚补丁的处置建议

| 补丁 | 处置 | 理由 |
|---|---|---|
| 0001（mdss-common binding） | **改后保留**：删 `MDSS RSC` 那条 description，`items` 缩为 CORE + CORE_INT2（`minItems: 1` 机制不变） | J3/J2：RSCC 不属于 mdss 名单 |
| 0002（drm/msm reset array） | **原样保留**：机制按 DT 数组驱动，与名单长度无关，CORE+INT2 两项同样适用 | 名单由 0003/DT 决定 |
| 0003（sm8750.dtsi） | **改后保留**：`resets` 删 `DISP_CC_MDSS_RSCC_BCR` 一项与 `reset-names` 中 `"rscc"`；commit message 中 "the MDSS RSC" 表述改为不复位（或移出本系列） | 同上 + 已向 Konrad 承诺 v3 |

改法片段（0003，可直接应用；0001 同理删一条 description）：

```diff
-			resets = <&dispcc DISP_CC_MDSS_CORE_BCR>,
-				 <&dispcc DISP_CC_MDSS_CORE_INT2_BCR>,
-				 <&dispcc DISP_CC_MDSS_RSCC_BCR>;
-			reset-names = "core", "core_int2", "rscc";
+			resets = <&dispcc DISP_CC_MDSS_CORE_BCR>,
+				 <&dispcc DISP_CC_MDSS_CORE_INT2_BCR>;
+			reset-names = "core", "core_int2";
```

同步注意：若给 Konrad 的后续回信引用例证，**不要**沿用 `apps_rsc@16500000`（那是 RPMh RSC）；正确例证 = vendor DT `sde_cesta` 的 `"rscc"` reg @ 0x0af20000 + 上游 RSCC 零 DT 消费者。

## 5. 遗留（未证实 / 待真机）

- RSCC 复位是否为治面板 init 失败的 load-bearing 项：**无法静态判定**（J5），需一次零写盘冷起 A/B（CORE+INT2 vs CORE+INT2+RSCC），判据沿用 `reports/q28-disp-init-ab-20261022.md`。不自行上机。
- vendor 显示驱动中 RSCC/cesta 的驱动源码本地无快照，"vendor 由显示驱动持有 RSCC" 仅由 DT 归属证明 —— 标**待确认**（不影响 J2/J3 的静态结论）。
- 本报告未跑内核编译（纯静态文本证据，无需单目标烟雾测试）。

## 6. 复现命令

```
grep -n "RSC\|RSCC\|BCR" build/vk151/drivers/clk/qcom/dispcc-sm8750.c
sed -n '3321,3336p;3730,3732p' build/vk151/arch/arm64/boot/dts/qcom/sm8750.dtsi
rg -n -i "rscc" reference/stock-elden.dts
rg -ln "RSCC_BCR" linux/drivers/clk/qcom/
rg -n "RSCC" linux/arch/arm64/boot/dts/qcom/*.dtsi   # 0 命中
sed -n '97,100p' linux/Documentation/devicetree/bindings/display/msm/mdss-common.yaml
```

---

## 7. 总管独立复核（2026-10-31，自报不可信）

逐条重跑，结论保持：

| 判据 | 复核命令 | 实测 | 判定 |
|---|---|---|---|
| 上游 qcom dtsi 对 RSCC 零引用 | `rg -n "RSCC" linux/arch/arm64/boot/dts/qcom/*.dtsi \| wc -l` | **0**（小写 `rscc` 的 13 处全是 adreno `gmu` reg-name / pcie / tpdm，与 DISP RSCC 无关） | ✅ |
| mdss/dispcc 的 `resets` 不含 rsc/rscc | awk 抽 `sm8750/sm8650/sm8550` 的 mdss/dispcc 节点 `resets` 行后 `grep -i rscc` | **0** | ✅ |
| `DISP_CC_MDSS_RSCC_BCR` 在 dispcc 内 | `grep -n "RSC\|BCR" build/vk151/drivers/clk/qcom/dispcc-sm8750.c` | `[DISP_CC_MDSS_RSCC_BCR] = { 0xc000 }`（另有 `RSCC_AHB_CLK/VSYNC_CLK` @0xc00c/0xc008） | ✅ |
| vendor `sde_cesta` 的 rscc reg 在 MDSS 窗口外 | `sed -n '11625,11640p' reference/stock-elden.dts` | `reg = <0xaf20000 0x850 …>`；dispcc 窗口 `[0xaf00000,0xaf20000)`、mdss `[0xae00000,0xae01000)` ⇒ **恰在 dispcc 窗口之外** | ✅ |
| Konrad 例证是 RPMh RSC | `rg -n "apps_rsc" build/vk151/.../sm8750.dtsi` | `apps_rsc: rsc@16500000` + `compatible = "qcom,rpmh-rsc"` | ✅（后续回信不沿用该例证） |

**处置未变**：0002 原样保留；0001/0003 各删 1 条 RSC 项（diff 见报告 §4）；J5 疗效仍需真机冷起 A/B（CORE+INT2 单独测），未上机。
