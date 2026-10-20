# T9 阻塞项静态分析：qcom-pcie L2 进入超时（主机侧只读，未上机）

- **日期**：2026-10-20
- **内核树**：`build/m1-73`（`Makefile` VERSION=7 PATCHLEVEL=3 SUBLEVEL=0 EXTRAVERSION=-rc7，见 `build/m1-73/Makefile:2-5`）
- **树状态**：`git log --oneline -1` = `24223e44a drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable`；
  上游基线提交 `24a19b953 Linux 7.3-rc7`（tag `v7.3-rc7`）。工作区仅 4 个改动（tcsr.yaml / sm8750.dtsi 的 dload-mode+tcsr / gc08a8 / s5kjns），
  **pcie 节点与 7.3-rc7 原文逐字一致**（`git show 24a19b953:arch/arm64/boot/dts/qcom/sm8750.dtsi | grep -n 'pcie-sm'` → `5438: compatible = "qcom,pcie-sm8750", "qcom,pcie-sm8550";`）。
- **方法**：纯静态源码/DT 阅读 + 上游邮件归档检索；**未接触设备、未 ssh、未刷写、未改内核树**。
- **前置**：已读 `reports/suspend-pcie-l2-blocker-20261020.md`（权威实测：4/4 复现，LTSSM: 0x12，挂 ~1.4 s）。

---

## 0. 三条必须先纠正的前提（否则后续方案会打空）

1. **`qcom_pcie_suspend_noirq` / `qcom_pcie_host_init` / `qcom_pcie_disable_resources` / `qcom_pcie_core_clk`
   这套函数名是旧版本（~6.x 早期）的结构。** 在 7.3-rc7 里后两个**根本不存在**：
   `grep -c` 结果 `qcom_pcie_core_clk`=0、`qcom_pcie_disable_resources`=0、`qcom_pcie_enable_resources`=0；
   等价职能已被 `qcom_pcie_init_2_7_0` / `qcom_pcie_deinit_2_7_0` 取代（`pcie-qcom.c:1024`、`:1130`）。
   本报告按**实际代码**给行号。

2. **「Timeout waiting for L2 entry」这句 printk 已不再是 `return ret`，而是 `ret = 0`（非致命）。**
   主线已合入 "PCI: dwc: Proceed with system suspend on L2 timeout"（r7.0 §5.3.3.2.1 依据），
   代码在 `drivers/pci/controller/dwc/pcie-designware-host.c:1260-1268`，**本树已包含**（源码即证据）。
   ⇒ 权威报告 §2 里那句「`suspend_devices_and_enter()` 在 platform 阶段（PCIe 的 `.suspend_noirq`）就返回了错误」
   **与当前代码不符**：该函数返回 0。1.4 s 的提前唤醒**不能**归因于 L2 超时的返回值。
   （编译产物时间戳 `drivers/pci/controller/dwc/pcie-designware-host.o` = Oct 18 18:19，与运行内核
   `7.3.0-rc7-debug-vk127-...-dirty #4 SMP PREEMPT Sun Oct 18 18:19:56 CST 2026` 一致，见
   `reports/artifacts/vk129-suspend-verified-20261020.txt` 头 —— 运行的就是这份源码。）

3. **「link 重拉 + WiFi 重探」不是 L2 超时失败后的回退动作，而是 resume 的常规路径。**
   `dw_pcie_resume_noirq()` 只要 `pci->suspended == true` 就**无条件**调 `dw_pcie_start_link()` → `qcom_pcie_start_link()`
   → `ltssm_enable()` 重新使能 LTSSM（`pcie-designware-host.c:1297-1327`、`pcie-qcom.c:344-358`）。
   所以「`PCIe Gen.3 x2 link up`」这条日志在任何一次成功 suspend/resume 里都会出现，**它本身不是异常**。

> 结论：L2 超时是**真异常**（链路没走到 L2/L3 Ready，停在 L0S），但它**不是** 1.4 s 唤醒的充分解释。
> 本报告据此把候选方案重新排序，并在 §5 明确列出仍缺口的一环。

---

## 1. 主线 qcom-pcie 的 L2 进入完整代码路径（`build/m1-73`，行号可复现）

### 1.1 调用链（自顶向下）

| # | 位置 | 内容 |
|---|---|---|
| 1 | `drivers/pci/controller/dwc/pcie-qcom.c:2544` | `.pm = &qcom_pcie_pm_ops`；`:2543` `NOIRQ_SYSTEM_SLEEP_PM_OPS(qcom_pcie_suspend_noirq, qcom_pcie_resume_noirq)` |
| 2 | `pcie-qcom.c:2371-2381` | `qcom_pcie_suspend_noirq()` → `ret = dw_pcie_suspend_noirq(pcie->pci); if (ret) return ret;` |
| 3 | `pcie-qcom.c:1416-1420` | `qcom_pcie_host_init()` —— **suspend 路径不调用它**；它只在 probe 与 `resume_noirq`（经 `pp->ops->init`）中被调 |
| 4 | `pcie-designware-host.c:1225` | `dw_pcie_suspend_noirq()` 起点 |
| 5 | `:1231-1235` | link 不在则直接 `goto stop_link`；`pci_host_common_d3cold_possible()` 为 false 则 **`return 0`（完全不碰 L2）** |
| 6 | `:1237-1243` | `pp->ops->pme_turn_off()` —— qcom 的实现是 `qcom_pcie_host_pme_turn_off()`（`pcie-qcom.c:1525-1530`），只写 ELBI 的 `ELBI_SYS_CTRL_PME_TURNOFF_MSG` (BIT(4))，**写完不等** |
| 7 | `:1250-1253` | 若 `pp.skip_l23_ready` → `mdelay(10)` 后 `goto stop_link`（**qcom 不设置此标志**，见 §1.3） |
| 8 | `:1255-1259` | `read_poll_timeout(dw_pcie_get_ltssm, val, val == L2_IDLE \|\| val <= DETECT_WAIT, 1000, 10000, false, pci)` —— 10 ms 超时，1 ms 间隔 |
| 9 | `:1260-1268` | 超时 → `dev_warn(... "Timeout waiting for L2 entry! LTSSM: 0x%x\n", val)` 然后 **`ret = 0`** |
| 10 | `:1275` | `udelay(1)`（r6.0 §5.3.3.2.1 的 100 ns 要求） |
| 11 | `:1277-1293` | `stop_link:` → `skip_pwrctrl_off = pme_capable`；`dw_pcie_stop_link(pci)`（qcom 无 `stop_link` op ⇒ **空操作**）；`pp->ops->deinit()` → `qcom_pcie_host_deinit()`；`pci->suspended = true` |

### 1.2 「Timeout waiting for L2 entry」的准确位置与判据

**printk 位置**：`drivers/pci/controller/dwc/pcie-designware-host.c:1266`

```c
1260: 	if (ret) {
1261: 		/*
1262: 		 * Failure is non-fatal since spec r7.0, sec 5.3.3.2.1,
1263: 		 * recommends proceeding with L2/L3 sequence even if one or more
1264: 		 * devices do not respond with PME_TO_Ack after 10ms timeout.
1265: 		 */
1266: 		dev_warn(pci->dev, "Timeout waiting for L2 entry! LTSSM: 0x%x\n", val);
1267: 		ret = 0;
1268: 	}
```

**注意**：设备 dmesg 里是 `qcom-pcie 1c00000.pcie: Timeout waiting for L2 entry! LTSSM: 0x12`，
**前缀是 `dev_warn` 级**（不是 `dev_err`）—— 这本身就是「非致命」版本已上机的旁证。

**LTSSM 从哪读**：
- `dw_pcie_get_ltssm()`（`pcie-designware.h:847-856`）优先走 `pci->ops->get_ltssm`。
- qcom 的 `dw_pcie_ops` 注册了 `.get_ltssm = qcom_pcie_get_ltssm`（`pcie-qcom.c:1673-1677`）。
- `qcom_pcie_get_ltssm()`（`pcie-qcom.c:1367-1378`）：

```c
1371: 	if (pcie->cfg->ops->get_ltssm)
1372: 		return pcie->cfg->ops->get_ltssm(pcie);
1373:
1375: 	val = readl(pcie->parf + PARF_LTSSM);          /* PARF_LTSSM = 0x1b0, 见 :59 */
1377: 	return (enum dw_pcie_ltssm)FIELD_GET(PARF_LTSSM_STATE_MASK, val);  /* GENMASK(5,0), 见 :140 */
```

⇒ **本机走的是 `PARF + 0x1b0` 的 bit[5:0]**（`ops_1_9_0` 未提供 `get_ltssm`，`pcie-qcom.c:1595-1604`）。

**位含义（`drivers/pci/controller/dwc/pcie-designware.h:378-412`，注释「Need to align with PCIE_PORT_DEBUG0 bits 0:5」）**：

| 值 | 枚举 | 含义 |
|---|---|---|
| 0x11 | `DW_PCIE_LTSSM_L0` | L0 |
| **0x12** | **`DW_PCIE_LTSSM_L0S`** | **L0s（低功耗子态，链路仍活动）** |
| 0x13 | `L123_SEND_EIDLE` | 进 L1/L2/L3 的过渡 |
| 0x14 | `L1_IDLE` | L1 |
| 0x15 | `L2_IDLE` | **L2（判据之一）** |
| 0x16 | `L2_WAKE` | L2 唤醒 |
| 0x0–0x6 | `DETECT_QUIET … DETECT_WAIT` | 训练/检测态（`val <= 0x6` 也算满足，见 `:1257`） |

⇒ **判据 = `LTSSM == 0x15`（L2_IDLE）或 `LTSSM <= 0x6`（≤DETECT_WAIT）**。
本机读到 **0x12 = L0S**，两个条件都不满足，10 ms 后超时。
**这告诉我们：PME_Turn_Off 已经发出去 10 ms，链路却仍停在 L0s —— 端点（WCN7861）根本没朝 L2 走。**

### 1.3 为什么本机不会走 `skip_l23_ready` 分支

`skip_l23_ready` 只在 3 个驱动被设置：`pcie-eswin.c:283`、`pcie-ultrarisc.c:165`、`pci-imx6.c:1982`。
**qcom 从不设置**（`grep -rn skip_l23_ready drivers/pci/controller/dwc/pcie-qcom*.c` → 无输出）。
⇒ 本机必然走 §1.1 第 8 步的轮询分支。

### 1.4 `qcom_pcie_host_init` 与 suspend 的关系（澄清）

`qcom_pcie_host_init()`（`pcie-qcom.c:1416-1484`）在 **resume** 时经 `dw_pcie_resume_noirq()` 的 `pp->ops->init` 调用，
顺序为：`perst_assert` → `cfg->ops->init()`（= `qcom_pcie_init_2_7_0`：拉 regs + 开 clocks + 反 reset + **清 `REQ_NOT_ENTR_L1` 使能 L1/L1SS** + `pci->l1ss_support = true`，`pcie-qcom.c:1024-1096`）
→ `phy_power_on` → `pci_pwrctrl_power_on_devices`（DT 无 pwrctrl 子节点 ⇒ 实质 no-op）→ `perst_deassert`。

`qcom_pcie_deinit_2_7_0()`（`pcie-qcom.c:1130-1142`）在 **suspend** 时被调：
置 `PHY_TEST_PWR_DOWN`（PARF_PHY_CTRL）→ `clk_bulk_disable_unprepare` → `regulator_bulk_disable`。
**即：suspend 真的把 PCIe 的 clocks 和 vdda/vddpe-3v3 都关了。**

⇒ 所谓「保持 ref clk」类方案，需要改的是**这里**，不是某个不存在的 `qcom_pcie_core_clk()`。

---

## 2. 与上游 sm8750/kaanapali 的差异对比

### 2.1 驱动：`qcom_pcie_cfg` / `of_device_id` 表

`qcom_pcie_match[]`（`pcie-qcom.c:2499-2528`）里**没有** `qcom,pcie-sm8750`，也**没有** `qcom,pcie-kaanapali-pcie`：

```c
2519: 	{ .compatible = "qcom,pcie-sm8250", .data = &cfg_1_9_0 },
2520: 	{ .compatible = "qcom,pcie-sm8350", .data = &cfg_1_9_0 },
2521: 	{ .compatible = "qcom,pcie-sm8450-pcie0", .data = &cfg_1_9_0 },
2522: 	{ .compatible = "qcom,pcie-sm8450-pcie1", .data = &cfg_1_9_0 },
2523: 	{ .compatible = "qcom,pcie-sm8550", .data = &cfg_1_9_0 },
2524: 	{ .compatible = "qcom,pcie-x1e80100", .data = &cfg_sc8280xp },
```

| SoC compatible | cfg | ops | `no_l0s` | `override_no_snoop` | 有其他特殊 |
|---|---|---|---|---|---|
| sm8250 | `cfg_1_9_0` (`:1629`) | `ops_1_9_0` (`:1595`) | false | false | `config_sid` |
| sm8450-{pcie0,pcie1} | `cfg_1_9_0` | `ops_1_9_0` | false | false | 同上 |
| sm8550 | `cfg_1_9_0` | `ops_1_9_0` | false | false | 同上 |
| sm8650 | **驱动无条目**（binding 有 `qcom,pcie-sm8650`，`Documentation/devicetree/bindings/pci/qcom,pcie-sm8550.yaml:23`） | — | — | — | **未查证为何缺** |
| **sm8750** | **驱动无条目** | — | — | — | **靠 DT fallback 落到 sm8550** |
| sa8775p | `cfg_1_34_0` (`:1633`) | `ops_1_9_0` | **true** | **true** | — |
| sc8280xp / x1e80100 / sa8540p | `cfg_sc8280xp` (`:1664`) | `ops_1_21_0` (`:1606`) | **true** | false | 无 `config_sid` |

**上游定性**：sm8750 的 PCIe 支持是 Qualcomm 自己按「与 SM8550 的 DWC 兼容」提交的
（`lore`：Krishna Chaitanya Chundru, *[PATCH v3 0/3] arm64: dts: qcom: Add PCIe Support for sm8750*, 2025-08-26，
`https://lore-kernel.gnuweeb.org/linux-pci/20250826-pakala-v3-0-721627bd5bb0@oss.qualcomm.com/t/`）。
其 binding 补丁就是在 `qcom,pcie-sm8550.yaml` 的 enum 里加 `qcom,pcie-sm8750`，**没有新增 cfg**。
⇒ **本机 `compatible` 与上游完全一致，这不是 bug**（不是漏移植）。

### 2.2 DT 层：本机 vs 上游 sm8750

| 项 | 本机值（`build/m1-73/...`） | 上游 7.3-rc7 值 | 一致？ |
|---|---|---|---|
| pcie0 `compatible` | `"qcom,pcie-sm8750", "qcom,pcie-sm8550"`（`sm8750.dtsi:5969`） | 同（`24a19b953:sm8750.dtsi:5438`） | ✅ 一致 |
| `num-lanes` | `<2>`（`sm8750.dtsi:5994`） | 同 | ✅ |
| `reg` / `reg-names` | 6 项，含 `mhi`（`sm8750.dtsi:5970-5981`） | 同 | ✅ |
| `linux,pci-domain` | `<0>`（`:5988`） | 同 | ✅ |
| `max-link-speed` | **未设置**（`grep max-link-speed sm8750.dtsi` → 无） | 同样未设置 | ✅（一致地缺失）|
| perst GPIO | `pcieport0` 里 `reset-gpios = <&tlmm 102 GPIO_ACTIVE_LOW>`（`sm8750-lenovo-elden.dts:2487`） | 上游 `qcom,pcie-sm8550.yaml` 示例用 `perst-gpios`（`:233`），但**驱动现行代码读的是 `reset-gpios`**（`pcie-qcom.c:2005`、`:2015`、`:2027`） | ✅ **本机是正确的新写法**，见下 |
| `wake-gpios` | `pcieport0` 有（`elden.dts:2486`，`&tlmm 104`） | 有 | ✅ |
| `qcom,*-offsets` | **均无** | 均无（新 binding `qcom,pcie-common.yaml` **已无 offsets 属性**，`grep 'qcom,.*-offsets' .../bindings/pci/*.yaml` → 无输出） | ✅ 一致（该问题不存在）|
| `vdda-supply` / `vddpe-3v3-supply` | `vreg_l1f_0p88` / `vreg_l3g_1p2`（`elden.dts:2470-2471`） | 板级差异 | ✅ 合理 |
| `pcie0_phy` supply | `vdda-phy = vreg_l1f_0p88`、`vdda-pll = vreg_l3g_1p2`（`elden.dts:2480-2481`） | 同板级 | ✅ |
| `pcie0_default_state` pinctrl | perst=gpio102（`bias-pull-down`）、clkreq=gpio103（`function = "pcie0_clk_req_n"`，`bias-pull-up`）、wake=gpio104（`sm8750.dtsi:4196-4216`） | 上游同结构 | ✅ |
| `t-power-on-us`（L1SS，port 节点） | **未设置**（`elden.dts` pcieport0 无此属性） | 上游示例亦通常不设 | ✅（一致）|

**perst 属性名：本机写法正确，不是 bug（已核定）**

驱动有两套解析，`reset-gpios` 是**现行的 port 级写法**：

```c
/* pcie-qcom.c:1987-2040, qcom_pcie_parse_perst() */
1998: 	if (pcie->reset) {                      /* 仅当 host 节点用了旧式 perst-gpios 才非 NULL */
1999: 		dev_warn_once(dev,
2000: 			      "Reusing PERST# from Root Complex node. DT needs to be fixed!\n");
2005: 	if (!of_find_property(np, "reset-gpios", NULL))
2006: 		goto parse_child_node;          /* 递归到子节点 */
2015: 	gpio_np = of_parse_phandle(np, "reset-gpios", 0);
2027: 	reset = devm_fwnode_gpiod_get(dev, of_fwnode_handle(np), "reset",
2028: 				      GPIOD_OUT_HIGH, "PERST#");
```

```c
/* pcie-qcom.c:2102-2107, qcom_pcie_parse_ports() —— 旧式 host 级 perst-gpios 兼容路径 */
2103: 	if (of_find_property(dev->of_node, "perst-gpios", NULL)) {
2104: 		pcie->reset = devm_gpiod_get_optional(dev, "perst", GPIOD_OUT_HIGH);
```

⇒ 本机 host 节点没有 `perst-gpios`（正确），port 节点有 `reset-gpios`（正确）⇒
走 `:2005-2028` 正常路径，**不会**打印 `DT needs to be fixed!`。
`qcom,pcie-sm8550.yaml:233` 里的 `perst-gpios` 属于 binding 文档示例/旧式兼容，与驱动现行首选写法不同。

> **未查证**：PERST# 在该板实测是否真的被 toggle（需 `cat /sys/kernel/debug/gpio | grep -E 'gpio-102|gpio-103|gpio-104'`）。

### 2.3 kaanapali

`arch/arm64/boot/dts/qcom/kaanapali.dtsi` 存在于本树，binding 也列了 `qcom,kaanapali-pcie`
（`qcom,pcie-sm8550.yaml:22`），但驱动 `qcom_pcie_match[]` 无对应条目 ⇒ 同样靠 sm8550 fallback。
**与 sm8750 处理方式一致，无额外差异**。

---

## 3. 候选修复方案（按风险从低到高）

> 排序原则：**先做「不改行为、只加可观测性」**，再做「改变 L2 策略」，最后才动「suspend 期间保留时钟/电源」。
> 每条都标注：改动点 / 预期效果 / 风险 / 验证方法（设备上做什么 + 看哪些 dmesg 行）。

### 方案 A（推荐首选，风险最低）：DT 显式声明「本平台不能可靠读到 L2」⇒ 设 `skip_l23_ready`

- **改动点**：`drivers/pci/controller/dwc/pcie-qcom.c` 的 `qcom_pcie_host_init()`（`:1416`）里，
  对 `of_device_is_compatible(pci->dev->of_node, "qcom,pcie-sm8750")` 的实例置 `pp->skip_l23_ready = true`；
  或更通用：新增带 `skip_l23` 标志的 `cfg_sm8750 = { .ops = &ops_1_9_0, .skip_l23 = true }` 并在
  `qcom_pcie_match[]` 加 `qcom,pcie-sm8750` 条目（后者触及 cfg 结构与 DT binding，**风险更高**，故草稿走前者）。
- **预期效果**：`dw_pcie_suspend_noirq()` 走 `:1250-1253` 分支 → `mdelay(10)` 后直接 `stop_link`，
  **不再轮询 PARF_LTSSM、不再刷 `Timeout waiting for L2 entry`**。行为与 spec r6.0 §5.3.3.2.1 的
  「读不到就别读，等 10 ms」完全一致（这正是 `pci-imx6.c:1982` / `pcie-ultrarisc.c:165` 的做法）。
- **风险**：**低**。它只是把「已知读不到」变成「明说不读」。不改变 `deinit`（仍关 clocks/regulator），
  所以功耗行为与现在**等价**；唯一副作用是少了 10 ms 的无效轮询（反而更快）。
  **注意**：若真因不是「读不到」而是「端点真的不进 L2」，本方案只能**消日志**，不能修行为 ——
  所以它是「零风险消噪 + 暴露真问题」的一步，**必须配合 §5 的取证**。
- **验证**：`dmesg | grep -E 'Timeout waiting for L2|L2 entry'` 应**无输出**；
  `cat /sys/kernel/debug/pcie-qcom*/ltssm_status`（若 debugfs 有，`pcie-designware-debugfs.c:493-499`）
  在 suspend 前应显示 `L0`。

### 方案 B（次选）：`skip_l23_ready` + 加长/取消 L2 等待并保留「端点在不在 L2」的取证日志

- **改动点**：`pcie-designware-host.c:1255-1268`：把 `PCIE_PME_TO_L2_TIMEOUT_US`（`drivers/pci/pci.h:47` = `10000`）
  只用于本次轮询，改成可配置；并在超时分支里额外 `dev_warn` 出 `PARF_SYS_CTRL`/`PARF_PHY_CTRL` 值。
- **预期效果**：拿到「10 ms 时链路停在哪个态、L23_CLK_RMV_DIS/L1_CLK_RMV_DIS 是否置位」的现场证据。
- **风险**：**低-中**。只加日志/调参数，但 `read_poll_timeout` 的 `sleep_us=1000, timeout_us=10000`
  改成更大值会**拉长每次 suspend 的 noirq 阶段**（最坏 100 ms），对掉电测量是可接受误差，但对「断电率」报告要说明。
- **验证**：日志里出现 `LTSSM` 值与附加寄存器快照；确认是否恒为 `0x12`。

### 方案 C（中风险）：suspend 时不关 clocks/regulator（保持 ref clk 与 L1SS 能力）

- **改动点**：`qcom_pcie_deinit_2_7_0()`（`pcie-qcom.c:1130-1142`）里，在 suspend 深度为 `PM_SUSPEND_MEM`
  时**跳过** `clk_bulk_disable_unprepare` + `regulator_bulk_disable`（只置 `PHY_TEST_PWR_DOWN`）。
- **预期效果**：端点状态在 suspend 期间不丢，resume 时 `dw_pcie_resume_noirq` 的 `init` 变成幂等操作，
  **可能避免** WiFi 重探链条（若该链条真由「clocks 被关 ⇒ 端点掉 D3cold ⇒ 重枚举」引起）。
- **风险**：**中-高**。直接牺牲 suspend 功耗（PCIe 子系统全程供电/时钟），与 T9 的「测掉电率」目标**方向相反**：
  即使 suspend 待住了，测出的 `%/h` 会**显著偏高**（不能用它当「Linux 待机基线」）。
  另外 `qcom_pcie_suspend_noirq`（`:2383-2400`）的 `icc_disable` 与 `dev_pm_opp_set_opp(NULL)` 也要相应跳过，
  否则「保留时钟但不给带宽」会造成 NoC 错误（代码注释 `:2413-2417` 正是在警告这个）。
- **验证**：`suspend_stats/success` 增长、挂起时长 > 60 s；但同时 `powertop`/`rtcwake` 测的能耗必然偏高 ——
  **可作「确认因果」的实验，不可作最终交付**。

### 方案 D（中风险，与 A/B 正交）：关掉 ASPM L0S，避免链路停在 0x12

- **改动点**：给 sm8750 用带 `no_l0s = true` 的 cfg（现成的 `cfg_1_34_0` 就带 `no_l0s`+`override_no_snoop`，
  或新建 `cfg_sm8750`），使 `qcom_pcie_clear_aspm_l0s()`（`pcie-qcom.c:360-378`）真的清 `PCI_EXP_LNKCAP_ASPM_L0S`。
- **预期效果**：链路不再进 L0S，suspend 时 LTSSM 不会是 `0x12`；
  即便仍未进 L2，也至少能从「L0S」这个中间态排除干扰。
- **风险**：**中**。L0S 关闭会抬高**运行态**功耗（WiFi 空闲功耗上升）——对 T9 又是反向影响；
  并且 `override_no_snoop` 会顺手改掉 no-snoop 行为，**不应直接复用 `cfg_1_34_0`**，必须新建只带 `no_l0s` 的 cfg。
- **验证**：`lspci -vv -s 01:00.0 | grep -i aspm` 应显示 `L0s not supported`；suspend 时 LTSSM 不再是 0x12。

### 方案 E（独立第二缺陷，风险低但要单独验证）：ath12k hwmon parent 睡眠访问

- **实测现象**：`hwmon hwmon57: PM: parent phy0 should not be sleeping`
- **真身（本次静态定位）**：这句话**不是**「运行时访问了睡眠设备」，而是 **PM core 在注册新设备时打的告警**：

```c
/* drivers/base/power/main.c:153-159, device_pm_add() */
154: 	device_pm_check_callbacks(dev);
155: 	mutex_lock(&dpm_list_mtx);
156: 	if (dev->parent && dev->parent->power.is_prepared)
157: 		dev_warn(dev, "parent %s should not be sleeping\n",
158: 			dev_name(dev->parent));
159: 	list_add_tail(&dev->power.entry, &dpm_list);
```

- **含义**：**在 suspend 流程已经把 parent（`phy0`）prepare 完之后，又有一个新设备被注册进来**
  ⇒ 它是「**suspend 期间有设备被创建**」的铁证，而 `ath12k` 的 hwmon 正是在 `ath12k_thermal_setup_radio()`
  里注册的（`drivers/net/wireless/ath/ath12k/thermal.c:232-235`，`hwmon_device_register_with_groups(&ar->ah->hw->wiphy->dev, "ath12k_hwmon", ...)`）。
  ⇒ **这条告警是「WiFi 在 resume 早期被重新 probe」的下游症状，不是独立诱因。**
- **改动点（若要做）**：让 `ath12k` 的 hwmon **只在 probe 一次注册、suspend/resume 不重注册**；
  或在 `ath12k_pci_pm_resume`（`ath12k/pci.c:1771-1781`）路径上禁止走「重新 setup radio」的完整 probe 分支。
- **风险**：低（只影响 hwmon 注册时机），但**收益低**：它治的是症状。
- **验证**：`dmesg | grep -c 'should not be sleeping'` = 0；且 `ls /sys/class/hwmon/ | wc -l` 在 resume 前后不变。

---

## 4. patch 草稿（最低风险 = 方案 A）

文件：**`reports/artifacts/0001-pci-qcom-skip-l23-ready-wait-for-sm8750.patch`**

设计取舍（说明为什么这样写最保守）：
- **不动 `cfg` 表、不加新 `qcom,pcie-*` compatible**（避免触及 DT binding 与 `dtbs_check`）；
- 用 `of_device_is_compatible(np, "qcom,pcie-sm8750")` 在 `host_init` 里按需置位，**只影响本机 compatible**，
  其它 SoC 零影响；
- 只置 `pp->skip_l23_ready = true`，**不碰** `deinit`/`icc`/`opp`，因此 suspend 功耗行为不变。

（完整 diff 见该文件；此处不复述，避免两处漂移。）

**静态验证结果**：`git apply --check` 在该树 **exit=0 通过**；应用后树状态不变（未写入）。
hunk 为 `@@ -1419,6 +1419,19 @@`（13 行插入）。

---

## 5. 关键缺口：1.4 s 唤醒的真正一环（诚实标注）

静态阅读**无法**闭合下面这一环，必须上机取证（本任务明确不接触设备）：

1. `dw_pcie_suspend_noirq()` 在 L2 超时后 **`return 0`**（`pcie-designware-host.c:1267`），
   `.suspend_noirq` 不会失败 ⇒ **不满足「platform 阶段返回错误」**的解释（权威报告 §2 的原话需修正）。
2. s2idle 下 **不 kill CPU**（`kernel/power/suspend.c:504-545`，`do { suspend_enter(...) } while (...)`）；
   只有 `deep` 会 `Disabling non-boot CPUs`。实测 **deep 也只 1.43 s**，说明是 `suspend_enter()` 里
   `wakeup = true` 或 `syscore`/`psci` 阶段被**某个已挂起的唤醒源**立刻拉回。
3. `1c00000.pcie` 是 **pcie0**（`sm8750.dtsi:5967`），下面挂 `wifi@0`（`elden.dts:2488`）。
   `qcom_pcie_deinit_2_7_0()` 关掉了 PCIe clocks 与 vdda/vddpe-3v3（`:1135-1141`）
   ⇒ 若 endpoint 的 `wake-gpios`（`gpio104`，`elden.dts:2486`）因为 **PERST# 断言 + 断电**而抖动，
   就是一个现成的「立即唤醒」来源。**这是当前最值得先测的假设，但本报告未验证。**
4. `gpio104` 的 pinctrl 是 `bias-pull-up`（`sm8750.dtsi:4213-4216`）而 `wake-gpios` 声明为
   `GPIO_ACTIVE_LOW`（`elden.dts:2486`）—— **电平极性与上拉/下拉是否自洽未查证**，
   若极性反了，PERST 断言瞬间就会触发一次 wake。**这是零成本、首选的下一轮验证点。**

**下一轮建议（按代价排序，均不涉及刷写）**：

| # | 动作 | 判据 |
|---|---|---|
| 1 | `cat /proc/interrupts \| grep -i 'pcie\|tlmm'` + `echo mem > /sys/power/state` 期间看 `dmesg -w` 有无 `PM: Wakeup pending` / `wakeup` 行 | 找出真正的 wakeup source |
| 2 | `grep . /sys/devices/platform/soc@0/1c00000.pcie/power/wakeup* ; grep . /sys/bus/pci/devices/0000:01:00.0/power/wakeup*` | `wakeup_count` 是否在 suspend 前增加 |
| 3 | 应用方案 A 的 patch 后重测（一次构建，不改 DT） | `Timeout waiting for L2` 消失；挂起时长是否 > 60 s |

---

## 6. 未验证 / 未查证（明确边界）

**只做了以下静态检查（无任何上机行为）**：

1. 源码行号与片段：`build/m1-73/drivers/pci/controller/dwc/{pcie-qcom.c, pcie-designware-host.c, pcie-designware.h,
   pcie-designware.c, pci-host-common.c}`、`drivers/base/power/main.c`、`kernel/power/suspend.c`、
   `drivers/net/wireless/ath/ath12k/thermal.c`、`drivers/phy/qualcomm/phy-qcom-qmp-pcie.c`、
   `drivers/pci/pwrctrl/core.c`、`drivers/pci/pci.h`、`drivers/pci/pci.c`。全部用 `awk 'NR>=a && NR<=b'` 打印，可复现。
2. DT/binding：`build/m1-73/arch/arm64/boot/dts/qcom/{sm8750.dtsi, sm8750-lenovo-elden.dts, kaanapali.dtsi}`、
   `Documentation/devicetree/bindings/pci/{qcom,pcie-sm8550.yaml, qcom,pcie-common.yaml}`。
3. 版本一致性：`build/m1-73/Makefile`、`git log/status/diff`、`pcie-designware-host.o` 时间戳 vs 运行内核版本串
   （`reports/artifacts/vk129-suspend-verified-20261020.txt`）。
4. 上游对照：`git show 24a19b953:arch/arm64/boot/dts/qcom/sm8750.dtsi`；lore 归档
   `https://lore-kernel.gnuweeb.org/linux-pci/20250826-pakala-v3-0-721627bd5bb0@oss.qualcomm.com/t/`
   （sm8750 PCIe v3 系列，共 3 补丁）。
5. 编译产物存在性：`drivers/pci/controller/dwc/pcie-designware-host.o`（Oct 18 18:19）。

**已做的静态验证（可复现）**：

- ✅ **`git apply --check` 通过**：在 `build/m1-73` 里执行
  `git apply --check --verbose /home/xuqianhui/y700-elden/reports/artifacts/0001-pci-qcom-skip-l23-ready-wait-for-sm8750.patch`
  → `正在检查补丁 drivers/pci/controller/dwc/pcie-qcom.c...`，**exit=0**。
  事后 `git status --porcelain` 与开始时逐行一致（仍只有 tcsr.yaml / sm8750.dtsi / gc08a8.c / s5kjns.c 四个改动），
  **内核树未被写入**。
- ✅ 引用的符号均已核对存在：`pp->skip_l23_ready`（`pcie-designware.h:472`，`struct dw_pcie_rp` 成员）、
  `pci->dev`（`struct dw_pcie` 成员，本函数 `:1418` 已有 `struct dw_pcie *pci = to_dw_pcie_from_pp(pp);`）、
  `of_device_is_compatible()`（`include/linux/of.h`）。
  **没有**使用 `pp->of_node`（该字段在 `struct dw_pcie_rp` 中**不存在**，已核实——`awk '/^struct dw_pcie_rp \{/,/^\};/' pcie-designware.h | grep of_node` 无输出）。

**未做 / 未查证**：

- ❌ **未编译**（`make` 会写内核树，本任务禁止）。所以「能编过」只有 `git apply --check` + 符号存在性核对，**不等于编译通过**。
- ❌ **未跑 `checkpatch.pl`**（同属写/读树操作，本次未做）。
- ❌ **未实测该 patch 的任何运行时效果**（需构建 + 上机，超出本任务范围）。
- ✅ **已核定** `qcom_pcie_parse_perst()` 读 `reset-gpios`（`pcie-qcom.c:2005/2015/2027`）⇒ §2.2 的 perst 结论已更正为「本机写法正确」（原稿曾误判为差异）。
- ❌ **未验证** `wake-gpios` 的极性/上下拉自洽性（§5 第 4 点）—— 需要设备上 `cat /sys/kernel/debug/gpio`。
- ❌ **未查证** `sm8650`（binding 有、驱动表无）的缺失原因，以及是否有人正在上游补 `qcom,pcie-sm8750` 的专用 cfg。
- ❌ **未查证** WiFi「`chip_id` + `mhi power ON`」到底是 probe 重跑还是 `ath12k_core_resume` 路径里重新下发 firmware
  （`ath12k/qmi.c:3334` 的 `ath12k_info(ab, "chip_id ...")` 只在 cap 响应处理里，强烈暗示是重 probe，**但未在 dmesg 里取到 `pci_dev` 的 remove/probe 行来闭环**）。
- ❌ 本报告**不产生任何掉电率数字**（遵守 T9 的「修好前不得记录 `%/h`」）。
