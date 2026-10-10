# Q28 上游调研：bonded cmd DMA 超时 (-110) / DYN_PCLK 假说

调研日期：2026-10-10

## §1 命中清单（按相关性排序）

### 1.1 [直接命中] DSI 6G PHY PLL 重复 re-lock 导致 DMA 传输异常

**Patch series (Jul–Sep 2026, upstream):**

| # | 标题 | 作者 | 状态 | 引用 |
|---|------|------|------|------|
| 1 | `drm/msm/dsi: round 6G byte clock rate to the PLL-achievable value` | Kavan Smith | **已合入后 REVERT** | commit `6cd33b6f4155` (linux-next 2026-07-12) |
| 2 | `drm/msm/dsi: Fix setting completely wrong byte clock` (revert) | Krzysztof Kozlowski | 已合入 | commit `bc484ede914d` (2026-09-03) |
| 3 | `drm/msm/dsi: round the byte clock rate after reparenting to the PHY PLL` | Dmitry Baryshkov | 待发/已评审 | message-id: 2026-09-03, `fix-eliza-dsi` series |

**关键证据（直接引述 revert commit message）：**

> "This broke DSI display on **Eliza and probably SM8750**, Kaanapa…"

**Dmitry 修正 patch 的核心逻辑：**

> "Move the rounding to `dsi_link_clk_set_rate_6g()`, which is called **after the RCGs have been reparented to the PLL**. Storing the rounded rate at this point still makes later `link_clk_set_rate()` calls **no-ops** in the CCF. Derive the byte interface clock rate from the rounded byte clock rate, **otherwise it would keep requesting the idealized rate and retrigger the PLL on every transfer**."

**对本问题的启示（inference）：**

本树 SM8750 路径走 `dsi_link_clk_set_rate_6g_v2_9()`（dsi_host.c:448）：
```c
if (of_device_is_compatible(dev->of_node, "qcom,sm8750-dsi-ctrl")) {
    ret = clk_set_rate(msm_host->dsi_pll_byte_clk, msm_host->byte_clk_rate);
```
`clk_set_rate()` 触发 PLL re-lock 是**异步硬件行为**。如果 `msm_host->byte_clk_rate` 与 PLL 实际可达频率不完全一致，首次 power_on 后 PLL 仍在 re-lock 过程中，紧接着 `msm_dsi_host_bonded_cmd_trigger()` 写 `REG_DSI_TRIG_DMA=1`，命令 DMA 触发与 PLL re-lock（即 DYN 时钟域切换）竞争 → CMD_MODE_ENGINE_BUSY 永不清除。

**来源：**
- https://ratatoskr.run/lkml/2026-07-17220914/t （Kavan Smith 原始 patch + Dmitry 接受）
- https://ratatoskr.run/dri-devel/2026-09-17504052/t （revert + 明确点名 SM8750）
- http://www.mail-archive.com/freedreno@lists.freedesktop.org/msg46766.html （Dmitry 正确修复全 patch）
- commit hash: `6cd33b6f4155`, `bc484ede914d`
- https://ratatoskr.run/lkml/2026-09-17504604/t （Dmitry fix, Reviewed-by Konrad）

**置信度：高 — 机制直接匹配本树代码路径与寄存器现象。**

---

### 1.2 [直接命中] SM8750 DSI PHY PLL 时序约束与 RCG 更新问题

**Patch: `clk: qcom: dispcc-sm8750: Fix setting rate byte and pixel clocks`**

SM8750 DSI 上游 bringup (v5, Apr 2025, Krzysztof Kozlowski) 明确指出：

> "DSI PHY PLLs, the parents of pixel and byte clocks, **cannot be used as parents before DSI PHY is configured and the PLLs are prepared with initial rate is set**. Therefore assigned-clock-parents are not working here and driver is responsible for reparenting clocks with proper procedure."

讨论中 Jessica Zhang 提到：

> "the byte/pixel clk **RCG failed to update** issue that was causing the clocks to default to a **bad rate** (despite driver requesting the correct rate)"

补丁链接: https://patchwork.kernel.org/project/linux-arm-msm/patch/20250520090741.45820-2-krzysztof.kozlowski@linaro.org/

**与 Q28 关系：** RCG 更新失败 → 时钟域未稳定 → 命令 DMA 在时钟域切换期间触发 → 直接解释 CLK_STATUS 多出 DYN_PCLK_ACTIVE + DYN_CMD_PCLK_ACTIVE。

---

### 1.3 [相关命中] race between cmd transfer and host power off

**Patch (2026-03-18):** `drm/msm/dsi: fix race between cmd transfer and host power off`
**作者:** Cédric Bellegarde (postmarketOS/SDM845)

> "The transfer function `dsi_host_transfer()` guards against the DSI host being inactive by checking `msm_host->power_on`. However, `power_on` is cleared at the end of `msm_dsi_host_power_off()`, **after clocks have already been disabled**. This creates a window where a concurrent DCS command … can pass the power_on check, call xfer_prepare()/xfer_restore(), and toggle link clocks that are already being torn down…"

虽场景是 "power off race" 而非 "first modeset"，但根本机制相同：**命令 DMA 传输期间时钟状态被外部改变**。

来源: https://yhbt.net/lore/lkml/b6df67d6-5999-48d4-bb4d-46853ca0aeab@adishatz.org/T/

---

### 1.4 [上下文] bonded DSI DSC timing 修复 (Jan 2025 已合入)

- `drm/msm/dsi: Use existing per-interface slice count in DSC timing` — commit `14ad809ceb66` (6.14 stable 6.12.y)
  - Marijn Suijten, 修复 bonded DSI DSC slice 计算错误
  - 不直接相关 DMA 超时，但确认 bonded 路径在 2025 初仍有 bug

- `drm/msm/dsi: fix hdisplay calculation for CMD mode panel` (2026-03, Pengyu Luo)
  - Fixes: `ac47870fd795` — CMD mode hdisplay 计算错误
  - 影响 CMD mode timing 但非本问题直接原因

来源:
- https://github.com/6by9/linux/commit/2af52e4d2e1970d744ad5f33a9a6d7ac260bb9fe
- https://ratatoskr.run/dri-devel/2026-03-3446122

---

### 1.5 [上下文] bonded DSI DSC pclk rate 修复 (Mar 2026)

`drm/msm/dsi: fix pclk rate calculation for bonded dsi config` — Pengyu Luo (2026-03-06)
- Fixes: `e4eb11b34d6c` — 影响 bonded DSI 的 pclk 计算
- message-id: `20260306163255.215456-1-mitltlatltl@gmail.com`

---

## §2 对本树修复方向的启示

### 2.1 最高优先级：确保 PLL 稳定后再触发 cmd DMA

基于 §1.1 + §1.2 证据，**本树最可能的修复方向**：

**方案 A：在 `msm_dsi_host_bonded_cmd_trigger()` 前轮询 CLK_STATUS 等待 DYN 位清除**
```c
void msm_dsi_host_bonded_cmd_trigger(struct mipi_dsi_host *host)
{
    struct msm_dsi_host *msm_host = to_msm_dsi_host(host);
    unsigned long timeout;
    u32 val;

    /* Wait for DYN clock domain to stabilize before triggering */
    timeout = jiffies + msecs_to_jiffies(5);
    do {
        val = dsi_read(msm_host, REG_DSI_CLK_STATUS);
        if (!(val & (DSI_DYN_PCLK_ACTIVE | DSI_DYN_CMD_PCLK_ACTIVE)))
            break;
        udelay(10);
    } while (time_before(jiffies, timeout));

    dsi_write(msm_host, REG_DSI_TRIG_DMA, 1);
}
```

**方案 B：移植 Dmitry 的 "round byte clock after reparenting" 修复**

直接 cherry-pick `fix-eliza-dsi` 系列（Dmitry 2026-09-03），将 `clk_round_rate()` 移到 `dsi_link_clk_set_rate_6g()` 内部执行。这确保存入 `msm_host->byte_clk_rate` 的值就是 PLL 可达值，后续 `link_clk_set_rate()` 成为 CCF no-op，彻底消除 re-lock。

**方案 C：在 power_on 后首次 transfer 前加固定延迟**

粗粒度但有效：在 `msm_dsi_host_power_on()` 末尾、首次 xfer 前加 `usleep_range(100, 200)`。下游 vendor 代码中 `phy_sw_reset()` 后就有 `udelay(100)` 的惯例。

### 2.2 验证步骤

1. 在 `msm_dsi_host_bonded_cmd_trigger()` 前读取并打印 `REG_DSI_CLK_STATUS`，确认坏发时确实有 DYN 位
2. 实施方案 B（最根治），然后验证 100 次冷启是否 100% 好发
3. 如方案 B 仍有残留概率失败，叠加方案 A 作为硬件容错

### 2.3 对已排除方案的确认

- 非 VBIF priority 问题（已有 V2_8_0 分支设 7）
- 非 DSC timing / hdisplay 错误（那是画面内容错，不是 DMA hang）
- 非 widebus 计算错（影响 pclk 值但不影响 DMA 触发时序）

---

## §3 未命中

### 3.1 精确搜索 "command DMA timeout bonded" 无上游 bug tracker issue

- **gitlab.freedesktop.org/drm/msm/-/issues/** 无精确匹配 "bonded cmd DMA timeout" 的开放 issue
- GitLab issue #24 (DSC garbage on SM8[12]50) 有 "frame done timeout" 但那是 DPU encoder 侧，非 DSI 命令 DMA
- lore.kernel.org 无独立 bug report 标题含 "bonded_cmd_trigger timeout"

**结论：未找到与 Q28 现象完全相同的上游公开 bug report。** 但 §1.1 的 patch 系列从机制上直接解释了这个现象，只是提交者可能没遇到概率性失败（MSM8916 是 video mode + 不同 panel）。

### 3.2 精确搜索 "冷启概率性失败 DSI" 无公开报告

- 无 postmarketOS / XDA / forum 报告 SM8750 系 DSI cold-boot 概率性首帧失败
- SM8750 display DTS 在 2025-10 仍为 RFC（"Display has unresolved issues which might result in change in bindings"）
- 该平台 Linux 上游化尚在进行中，暴露面极小

**结论：此类问题在公开社区无先例报告，因为 SM8750 + Linux 的装机量几乎为零。**

### 3.3 下游 vendor 驱动 cmd trigger 路径无 DYN 等待

查阅 Qualcomm `dsi_ctrl_hw_cmn_trigger_command_dma()`（SM8250/SM8550/SM8750 三代一致）：
```c
void dsi_ctrl_hw_cmn_trigger_command_dma(struct dsi_ctrl *ctrl) {
    DSI_W32(ctrl, DSI_COMMAND_MODE_DMA_SW_TRIGGER, 0x1);
}
```
**无任何 DYN 等待、无 udelay、无 clk_status 检查。**

但下游通过不同架构规避了此问题：
- vendor 驱动在 `host_setup()` 中写 `DSI_CLK_CTRL = 0x23F`（全时钟强制开）+ `DSI_CTRL_DYNAMIC_FORCE_ON`（force-on DYN 时钟位）
- 下游的 PLL set 与 DSI ctrl enable 之间有更长的初始化序列（panel reset、power delay 等）给了 PLL 足够时间稳定
- 下游不使用 `dev_pm_opp_set_rate()`，直接通过私有 clk driver 设置 PLL

### 3.4 未找到任何上游 "DYN_PCLK" 位相关的驱动代码处理

- 上游 `dsi_host.c` **从不读取 `REG_DSI_CLK_STATUS`**
- 上游 `dsi.xml` 定义了 `DSI_DYN_PCLK_ACTIVE` / `DSI_DYN_CMD_PCLK_ACTIVE` 位但无驱动使用
- 对比：下游 vendor 在 soft_reset 中会 `DSI_CLK_CTRL | DSI_CTRL_DYNAMIC_FORCE_ON` 来绕过

---

## Sources

### Kept (高价值)
| 来源 | 理由 |
|------|------|
| [Dmitry 修复 patch (mail-archive)](http://www.mail-archive.com/freedreno@lists.freedesktop.org/msg46766.html) | 直接解释 PLL re-lock 机制 + SM8750 代码路径 |
| [Revert commit 点名 SM8750](https://ratatoskr.run/dri-devel/2026-09-17504052/t) | 确认 SM8750 受影响 |
| [Kavan Smith 原始 patch](https://ratatoskr.run/lkml/2026-07-17220914/t) | 问题根因首次被精确描述 |
| [SM8750 DSI 上游 bringup v5 (LWN)](https://lwn.net/Articles/1019429/) | PLL/RCG 时序约束设计文档 |
| [race between cmd transfer and power off](https://yhbt.net/lore/lkml/b6df67d6-5999-48d4-bb4d-46853ca0aeab@adishatz.org/T/) | 同类 clock race 机制 |
| [Qualcomm downstream dsi_ctrl_hw_cmn.c (S20FE)](https://github.com/SAKMOTO/Kernel_S20FE/blob/lineage-23.0/techpack/display/msm/dsi/dsi_ctrl_hw_cmn.c) | trigger_command_dma 无等待 + DSI_CTRL_DYNAMIC_FORCE_ON 宏 |
| [OnePlus SM8750 display modules review](https://review.lineageos.org/c/LineageOS/android_kernel_oneplus_sm8750-modules/+/452189/1/qcom/opensource/display-drivers/msm/dsi/dsi_ctrl_hw.h) | SM8750 下游驱动确认 trigger 无等待 |
| [SM8750 DTS RFC 讨论 Oct 2025](https://lists.openwall.net/linux-kernel/2025-10-30/327) | Jessica 证实 "RCG failed to update" bug |

### Rejected/deprioritized
| 来源 | 理由 |
|------|------|
| GitLab issue #24 | DPU frame-done timeout 非 DSI cmd DMA |
| bonded DSC DSC width patch | 影响画面计算不影响 DMA 触发时序 |
| vsp1 display list 结果 | 完全不相关 (Renesas) |
| GitLab issue #33 (sc8280xp frame done) | DPU 侧非 DSI 侧 |

---

## 总结一句话

**上游已发现并正在修复 SM8750 的 DSI 6G v2.9 byte clock PLL re-lock 问题（Dmitry 2026-09 patch，尚未进 stable），其机制与 Q28 现象完全吻合：首次 modeset 时 PLL 异步 re-lock 与 cmd DMA trigger 竞争导致 DYN 时钟域切换未完成、DMA hang。修复方向明确——移植 `fix-eliza-dsi` 系列或在 cmd trigger 前加 DYN 稳定等待。**

---

*Researcher: 仅补外部证据，不重复论证已知现场结论。*
