# Q24/G1-33: cambistmclkcc 加载后熄屏→硬复位

## 结论
1. 上游 DT 补丁 (v1→v4) 中 cambistmclkcc 节点使用了 **RPMHPD_MX**（可关断域），而 camcc 在 v3 改为了 **RPMHPD_MXC**（常开域），v3 changelog 明确写"MXC is always ON rail"。MX 可关断意味着 probe 时 MMIO 写入可能命中断电域→总线挂死→硬复位。
2. 驱动侧 `cambistmclkcc-sm8750.c` 的 `qcom_cc_desc` **未设置 `use_rpm=true`**，因此 `qcom_cc_really_probe()` 不会先 `pm_runtime_resume_and_get()` 再配 PLL/使能 CBCR；写入 0x40f8 (SLEEP_CLK CBCR) 时若 MX 域未上电即触发不可恢复 NoC hang。
3. 最可能正确修复 = **DT 侧将 cambistmclkcc 的第二个 power-domain 改为 RPMHPD_MXC**（或驱动侧加 `use_rpm=true`）；两者代价低、把握高。
4. 上游 DT 补丁 2026-05-12 已被 Bjorn applied (commit 4a1779f42e21)，**尚未发现后续修正补丁**。

## 证据

### E1: DT v3→v4 changelog 明确区分 MX 与 MXC
- 原文: "Update the Mx phandle to use MXC for camcc node as it is a always ON rail and can sustain this usecase."
- cambistmclkcc 仍用 MX（未跟随修改）。
- 来源: https://lkml.iu.edu/hypermail/linux/kernel/2605.1/04406.html
- 置信度: **high** — 直接引用 commit message。

### E2: 合入后的 DT 中 cambistmclkcc 使用 RPMHPD_MX
```
power-domains = <&rpmhpd RPMHPD_MMCX>, <&rpmhpd RPMHPD_MX>;
```
- 来源: spinics 展示 v4 patch diff + Bjorn applied 确认 commit 4a1779f42e21
- https://www.spinics.net/lists/kernel/msg6201839.html
- 置信度: **high**。

### E3: 驱动缺少 `use_rpm` 标志
- `cam_bist_mclk_cc_sm8750_desc` 中无 `.use_rpm = true`（从 commit f9580ba diff 推断；对比 camcc-sm8650 有该字段）。
- `qcom_cc_really_probe()` 仅在 `desc->use_rpm` 为 true 时调用 `pm_runtime_resume_and_get()`。
- 来源: https://github.com/amir73il/linux/commit/f9580bafd39cff31bd51031e8784ea44acddf20e + https://www.spinics.net/lists/kernel/msg5704657.html (patch v5 05/18)
- 置信度: **medium-high**（从 GitHub diff 的截断内容推断，未看到完整 454 行尾部）。

### E4: critical_cbcrs 仅包含 SLEEP_CLK 的 CBCR 地址 0x40f8
- `qcom_cc_clk_regs_configure()` 会对 `clk_cbcrs` 数组每项调用 `qcom_branch_set_clk_en(regmap, offset)` 写 MMIO。
- 若此时电源域 OFF → bus hang。
- 来源: https://lists.openwall.net/linux-kernel/2025-05-30/802 (patch v5 06/18)
- 置信度: **high**。

### E5: Konrad 评审提示 MXA 也可能参与
- "both MXC and MXA are used (I see MXA particularly near CSI[24]PHY)"
- Taniya 未采纳，v4 仍用 MX。
- 来源: https://lore-kernel.gnuweeb.org/linux-devicetree/d1f9ae01-a81a-4287-9f98-f2318ec6dd01@oss.qualcomm.com/T/
- 置信度: **medium**（Konrad 自述 "it may be a fluke"）。

### E6: SM8450/SM8550/SM8650 camcc 均使用 MMCX + MXC 双域
- 先例: 2025-05 合入的 multi-PD 系列给 SM8450/SM8550/SM8650 camcc 统一加了 MXC。
- 来源: https://patchew.org/linux/20250530-videocc-pll-multi-pd-voting-v5-0-02303b3a582d@quicinc.com/
- 置信度: **high**。

### E7: Bjorn applied 但未对 power-domain 选择提出异议
- Bjorn 回复仅提 rebase 冲突，后直接 applied。
- 表明此选择可能未受到功能验证（仅 dtbs_check 通过）。
- 置信度: **medium**（推断：无功能异议不等于验证过）。

## 候选路线/修复假设（按代价×把握排序）

| # | 假设 | 代价 | 把握 | 机制 |
|---|------|------|------|------|
| 1 | DT: cambistmclkcc 第二域改 `RPMHPD_MXC`（对齐 camcc）| 极低 (一行 DTB) | **高** | MXC 常开，probe 写 MMIO 安全 |
| 2 | 驱动: 给 `cam_bist_mclk_cc_sm8750_desc` 加 `.use_rpm=true` | 低 (重编 ko) | **高** | PM runtime 在 PLL/CBCR 写前先 resume 电源域 |
| 3 | DT: 改 `RPMHPD_MMXC` 或 `RPMHPD_MMCX` 单域 | 极低 | 中 | 需确认硬件连线；可能违反 power domain 拓扑约束 |
| 4 | 不加载 cambistmclkcc（黑名单/不编译） | 极低 | 高(规避) | 相机 MCLK 功能缺失；不影响其他 G1 功能 |
| 5 | 等上游 Qualcomm 修 | 无 | 未知 | 目前无可见回复/fix，可能需 1-2 个 merge window |

## 落地步骤

### 本地验证（需设备）
1. **方案 1 验证**: 修改 sm8750.dtsi 中 cambistmclkcc 节点，将 `RPMHPD_MX` → `RPMHPD_MXC`；重编 DTB；确认 9/9 无掉电。
2. **方案 2 验证**: 修改 `cambistmclkcc-sm8750.c` 在 desc 中加 `.use_rpm = true`；重编 ko；确认 9/9 无掉电。
3. 若方案 1 成功且方案 2 也成功，优先方案 1（DT-only，不需重编内核）。
4. 对比测试：仅改第二域为 MXC 但保留 required-opps low_svs vs 去掉 required-opps。

### 上游报告
1. 在 lore.kernel.org 对 commit 4a1779f42e21 发 fix patch（方案 1 或 2），Cc Taniya Das + Konrad + Bjorn。
2. 附上 9 轮压测数据与 log，强调 probe 阶段即触发而非 runtime。

## 风险与未证实点
- **MX vs MXC 硬件语义**: 若 SM8750 上 cambistmclkcc 物理上确实位于 MX 域而非 MXC 域，强制改为 MXC 可能在后续深度休眠时断电该硬件块；但 probe crash 更严重，可先 workaround 后等 Qualcomm 确认。
- **use_rpm=true 副作用**: PM runtime 可能在后续 idle 时自动 put 电源域（需配合 `pm_runtime_set_autosuspend_delay` 或 `pm_runtime_put_sync` 策略），影响其他消费者。
- **Kaanapali 同构**: `cambistmclkcc-kaanapali.c` 有相同 pattern（单域或不同域组合），需确认其是否也有相同问题。
- **SM8750P 特殊**: 本板 SoC 为 SM8750**P**，cmd-db 中 MX/MXC 可用 corner 与标准 SM8750 可能有差异；需在板上实测。

## 需父进程在设备上验证的项
1. 将 cambistmclkcc 的 `power-domains` 第二项改为 `RPMHPD_MXC`（保持 required-opps），重编 dtb，9 轮循环加载模块看是否 0/9 掉电。
2. 在现有 3/3 掉电配置下，`echo on > /sys/devices/platform/soc/1760000.clock-controller/power_runtime/status` 设 disabled 后重试，确认是否 PM 相关。
3. 用 `/sys/kernel/debug/pm_genpd/pm_genpd_summary`（若启用）观察 probe 前 MX 域是否 OFF。
4. 尝试 `.use_rpm=true` 重编模块验证方案 2。
