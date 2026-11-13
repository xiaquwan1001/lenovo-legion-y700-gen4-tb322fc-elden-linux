# MDSS/INT2 三问取证（B3）— 2026-11-13

> 用途：给 A1（mdss v3 2/3 的 Dmitry 两问）提供**寄存器级与代码级证据**。本文件只写证据+结论，
> **不含回信正文**（回信在 A1 里写）。零发信、零设备动作、未改 SSOT。
>
> 取证基线：`build/m3v2-7.3rc7` 的 `gh/master` = **9d66f26fef**（2026-11-11，7.4-rc3 线），
> 只读；另用**下游树** `linux/`（GEEKiDoS `v7.2-elden`，本地快照）作第二源。
> 已把 7.4-rc3 的源树导出到 `/tmp/g74` 做行号检索（一次性，不在仓库内留痕）。

## §0 结论（三条，先给答案）

1. **复位表**：`sm8750` dispcc 只有**三枚** MDSS 块复位，都是 `寄存器 + bit0`：
   CORE=`0x8000`、CORE_INT2=`0xa000`、RSCC=`0xc000`（dispcc 基址 `0xaf00000`，见 `sm8750.dtsi:3759-3761`）。
   **上游与下游两源逐字相同**，没有 vendor 私有差异（§1）。
2. **「是不是中断控制器」要分两层答**：MDSS 节点**在 DT 与驱动层确实是**中断控制器
   （`interrupt-controller` + `#interrupt-cells = <1>`，DPU 用 `interrupts-extended = <&mdss 0>`；
   驱动注册 chained irqchip + 32 线 linear domain，只读一个状态寄存器）；
   但**硬件上 MDSS 顶层只是一个中断汇聚寄存器**（`MDSS_HW_INTR_STATUS` @`0xae00010`，5 个源位），
   **没有** per-line enable/ack 寄存器，mask/unmask 纯软件位图。
   真正有 `clear/en/status` 三件套的「中断控制器」在 **MDP TOP 块**里（`MDP_SSPP_TOP0_INTR` / `INTR2`），
   由 DPU 驱动自己管。⇒ **`INT2` 不是一个独立的中断控制器设备**，
   准确说法是「dispcc 给 MDSS core 的第二组中断（INT2）所在块提供一枚块复位」（§2）。
3. **副作用与测法**：不 reset 的副作用 = **间歇性 command-mode DMA 超时 → 面板 init `-5` → 只有背光无
   `/dev/dri/card0`**（A/B 实测 base 臂 9 发 5 次，§3.1/§3.3）；**执行** reset 的副作用 = 
   bootloader 交接的 framebuffer 被复位打掉（这是我们自己 DT 里**已观测**并因此**故意不描述**
   `simple-framebuffer` 的原因，§3.2）。两条症状各给只读判据命令（§3.4）。

---

## §1 ① sm8750 dispcc 的 MDSS 复位位（逐位）

### 1.1 表

| DT id | 宏 | 寄存器偏移 | 位 | 上游（gh/master `9d66f26fef`） | 下游（`linux/` = GEEKiDoS v7.2-elden） |
|---|---|---|---|---|---|
| 0 | `DISP_CC_MDSS_CORE_BCR` | `0x8000` | **bit 0** | `drivers/clk/qcom/dispcc-sm8750.c:1869`；`include/dt-bindings/clock/qcom,sm8750-dispcc.h:104` | `linux/drivers/clk/qcom/dispcc-sm8750.c:1869`；`linux/include/dt-bindings/clock/qcom,sm8750-dispcc.h:104` |
| 1 | `DISP_CC_MDSS_CORE_INT2_BCR` | `0xa000` | **bit 0** | 同文件 `:1870`；头文件 `:105` | 同文件 `:1870`；头文件 `:105` |
| 2 | `DISP_CC_MDSS_RSCC_BCR` | `0xc000` | **bit 0** | 同文件 `:1871`；头文件 `:106` | 同文件 `:1871`；头文件 `:106` |

- 表体（上游）：
  `static const struct qcom_reset_map disp_cc_sm8750_resets[] = { [DISP_CC_MDSS_CORE_BCR] = { 0x8000 }, [DISP_CC_MDSS_CORE_INT2_BCR] = { 0xa000 }, [DISP_CC_MDSS_RSCC_BCR] = { 0xc000 }, };`
  ——三处都只给了 `.reg`，`.bit` 走零初始化。
- **「bit 0」的出处**：`struct qcom_reset_map { unsigned int reg; u8 bit; u16 udelay; u32 bitmask; }`
  （`drivers/clk/qcom/reset.h:11-16`），`qcom_reset_set_assert()` 取
  `mask = map->bitmask ? map->bitmask : BIT(map->bit)`（`drivers/clk/qcom/reset.c:34`）
  ⇒ 未写 `.bit` 即 `BIT(0)`，写 1 断言、写 0 释放，且写完 `regmap_read()` 回读确认（`reset.c:36-38`）。
- 复位「保持时间」的默认值：`qcom_reset()` 用 `fsleep(rst->reset_map[id].udelay ?: 1)`（`reset.c:15`），
  即驱动自己触发 `.reset()` 时默认 1 µs；`msm_mdss_reset()` 走的是 assert/`msleep(20)`/deassert（见 §3.3）。
- 同块**电源域**（证明 INT2 是 MDSS core 里独立的一小块，而不是别的设备）：
  `mdss_gdsc.gdscr = 0x9000`、`mdss_int2_gdsc.gdscr = 0xb000`（`dispcc-sm8750.c:1753` / `:1765`），
  两者都在 `disp_cc_sm8750_gdscs[]`（`:1875-1876`）。
- 旁证（不是单板命名特例）：`dispcc-kaanapali.c:1877-1879` 有**同偏移同顺序**的三枚
  `DISP_CC_MDSS_CORE_BCR/…_CORE_INT2_BCR/…_RSCC_BCR`（`0x8000/0xa000/0xc000`）；
  `dispcc0-nord.c:1936-1938` 同；`dispcc-sc7180/sc7280/qcm2290` 只有 CORE(+RSCC) 两枚，
  即「有没有 INT2 复位」是 SoC 世代差异，不是 elden 特有。
- dispcc 可见寄存器上限 `max_register = 0xf004`，并在源码里注明
  「0x10000, 0x10004 and maybe others are for TZ」（`dispcc-sm8750.c:1883`）
  ⇒ 我们读/写 `0x8000/0xa000/0xc000` 全在非 TZ 区。

### 1.2 结论

- 三枚复位**都是单 bit、bit 0、独立寄存器**，可以逐个断言/释放，不需要 bitmask 组合写；
- 上游与下游表**逐字一致** ⇒ 「vendor 与上游两源」不构成分歧点，分歧只在**谁在什么时候驱动它们**
  （dispcc probe 内 vs 显示侧 `msm_mdss_reset()`），那属于设计问题不属寄存器事实。

---

## §2 ② `msm_mdss.c` 里中断的实际用法（`mdss_intr` 到底是什么）

**先说命名事实**：7.4-rc3 的 `drivers/gpu/drm/msm/msm_mdss.c` 里**没有** `mdss_intr` 这个符号
（`rg -n "mdss_intr" /tmp/g74/drivers/gpu/drm/msm/` 零命中）。与之对应的是
`REG_MDSS_HW_INTR_STATUS`（由 `#include <generated/mdss.xml.h>` 生成，`msm_mdss.c:23`）。

### 2.1 代码事实（`gh/master`，行号为 9d66f26fef）

| 行为 | 位置 | 内容 |
|---|---|---|
| 状态寄存器定义 | `drivers/gpu/drm/msm/registers/display/mdss.xml:14-21` | `HW_INTR_STATUS` @ **0x00010**；位域：`INTR_MDP` pos 0、`INTR_DSI0` pos 4、`INTR_DSI1` pos 5、`INTR_HDMI` pos 8、`INTR_EDP` pos 12 |
| chained handler | `msm_mdss.c:91-116` | 读 `REG_MDSS_HW_INTR_STATUS`（`:99`）→ 对每个置位 `generic_handle_domain_irq()`（`:105`）→ `chained_irq_enter/exit` |
| mask/unmask | `msm_mdss.c:119-139` | **只改软件位图** `irq_controller.enabled_mask`（`clear_bit`/`set_bit` + 内存屏障），**不写任何硬件寄存器** |
| irq_chip | `msm_mdss.c:141-147` | 只有 `.irq_mask` / `.irq_unmask`，没有 ack/eoi/type/set_wake |
| domain | `msm_mdss.c:165-186` | `irq_domain_create_linear(dev_fwnode(dev), 32, …)`（`:172`），onecell xlate（`:160-163`），map 用 `handle_level_irq`（`:155`） |
| 注册 | `msm_mdss.c:429-438` | `platform_get_irq(pdev, 0)`（`:429`）→ `_msm_mdss_irq_domain_add()`（`:433`）→ `irq_set_chained_handler_and_data(irq, msm_mdss_irq, msm_mdss)`（`:437-438`） |
| 顺序 | `msm_mdss.c:388` vs `:429-437` vs `:504` | `msm_mdss_reset()` 在 `msm_mdss_init()` **第一行**（`:388`），之后才 ioremap/取中断/建 domain（`:429`/`:433`/`:437`），`of_platform_populate()` 更晚（`:504`） |
| DT（`sm8750.dtsi`） | `:3351` mdss 节点；`:3356` `interrupts = <GIC_SPI 83 …>`；`:3362` `resets`；`:3371` `power-domains = <&dispcc MDSS_GDSC>`；`:3375-3376` `interrupt-controller; #interrupt-cells = <1>;`；`:3384` DPU 子节点；`:3391` `interrupts-extended = <&mdss 0>` | DPU 只连 hwirq **0** = `INTR_MDP` |

### 2.2 真正的「中断控制器」在 MDP TOP 块

`MDP_SSPP_TOP0_INTR` / `MDP_SSPP_TOP0_INTR2` 是 DPU 硬件的中断组
（`disp/dpu1/dpu_hw_interrupts.h:17-18`），每组都有 clear/en/status 三个寄存器：
`INTR_EN 0x010 / INTR_STATUS 0x014 / INTR_CLEAR 0x018`、`INTR2_EN 0x008 / INTR2_STATUS 0x00c / INTR2_CLEAR 0x02c`
（`disp/dpu1/dpu_hwio.h:16-20`，注释「MDP TOP block Register and bit fields」）。
这些寄存器在 **MDP 基址** `0xae01000` 的空间里，由 `dpu_hw_interrupts.c` 直接管
（`dpu_intr_reg` 表，`:67-90`；`MDP_SSPP_TOP0_INTR2` 条目 `:73-77`）。

### 2.3 结论（措辞建议）

- 回答 Dmitry「Is it an interrupt controller?」：
  **MDSS 节点是（DT + 驱动两层都成立），但它只是「读一个状态寄存器再分发」的聚合器，
  硬件上没有任何配置寄存器；MDP TOP 里的 INTR/INTR2 才是带 clear/en/status 的中断块。**
- 因此 v4 3/3 里 `"…reset for the MDSS core INT2 interrupt controller"` 这种写法**会被追问**
  （它把 INT2 说成设备）。安全写法：**「dispcc 为 MDSS core 中承载第二组中断（INT2）的那个块
  提供一枚块复位」**，即只陈述 dispcc 的命名 + 复位作用域，不宣称 INT2 是独立中断控制器。
- **证据边界（未证实）**：`INT2` 与 MDP TOP 的 `INTR2` 是**同一硬件块**这一点，我们只有
  **命名证据**（dispcc 的 `…_CORE_INT2_BCR` / `MDSS_INT2_GDSC` + MDP TOP 的 `INTR2` 组）
  与**结构证据**（同属 MDSS core、同块不同 GDSC/BCR），**没有 datasheet 页码级直证**。
  回信里不要把它写成已证实事实。

---

## §3 ③「不 reset MDSS 块」的副作用 + 可测方法

### 3.1 症状 A：command-mode DMA 超时 → 面板 init `-5`

现场原文（`patches/upstream/q28-dispcc-2026-10-22/0001-…patch` 的 commit message 引用的实测串）：

```
msm_dsi ae94000.dsi: command DMA timeout: status=0x2200200
msm_dsi ae94000.dsi: bonded command DMA failed: master=-110 peer=-110
panel-novatek-nt36536: Failed to initialize panel: -5
```

- 性质：**间歇**，不是每次必现。A/B 实测（`reports/q28-disp-init-ab-20261022.md`）：
  base 臂（只复位单个 CORE）9 次真 POR **5 次** 失败；含三枚 BCR 的臂 15/15 正常。
- 因果边界（重要）：只有「三枚 BCR 是否被复位」与失败率相关；
  **从未把 INT2 单独抽出来做单变量**，也没有证明「INT2 未复位」是唯一原因
  ⇒ 这正是 v4 把 v3 3/3 里那句因果声称删掉的原因（`patches/upstream/m8-mdss-v4-20261113/README.md`）。

### 3.2 症状 B：只有背光、没有 DRM 设备（`/dev/dri/card0` 不存在）

- 触发链：面板 init 失败 → DPU/DSI 拿不到 panel → 不出 `card0`；背光由 pwm/leds 子系统独立开，
  所以「屏亮但全黑」。
- **反向（执行 reset）的副作用，我们已有现场证据**：`build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:1211-1216`
  明确写着：`simple-framebuffer` **故意不描述**，因为「DISP_CC_MDSS_CORE_BCR reset 会把 ABL 交接的
  framebuffer 从 simple-framebuffer 底下抽走，fbcon 会绑到一个死 fb」。
  ⇒ 这就是 Dmitry 问的 side effect 的**真实另一半**：复位本身会杀掉 bootloader 交接的显示内容。
- 静态影响面（可用于回信的分寸）：7.4-rc3 里 **52 个** qcom 板级 dts 描述了 `simple-framebuffer`
  （`rg -l "simple-framebuffer" arch/arm64/boot/dts/qcom/ | wc -l`），其中包括 **`sm8650-valve-deckard.dts`**；
  sm8750 的 mtp/qrd/elden **都没有**描述它。
  ⇒ 若把「多枚 BCR」推广到别的 SoC，必须先确认那块板子没有在用 simpledrm/fbcon，
  否则就是「把启动画面打掉」（可解释但用户可见的回归）。这是 v4 只动 sm8750 的技术理由。

### 3.3 「怎么测的」——已做过的 A/B（可复述给维护者）

| 臂 | 复位内容 | 复位时刻 | n | 失败（STORM） |
|---|---|---|---|---|
| base | 仅上游既有单 CORE | mdss probe（PLL 编程之后） | 9 | **5** |
| only0154 | CORE+INT2+RSCC（dispcc probe 内直接写 BCR） | **PLL 编程之前** | 5 | **0** |
| exp | only0154 + DIGTOP_PWRDN_B 处理 | 同上 | 10 | **0** |

- 2×2 解离：失败率只随「三枚 BCR 是否复位」变化，与「PLL 是否锁上」「DIGTOP 是否处理」无关
  （合并含 0154 两臂 15/15 vs base 4/9，Fisher 双侧 p=0.003）。
- 复位保持时长：上游 `msm_mdss_reset()` 是 assert → `msleep(20)` → deassert（`msm_mdss.c:337-343`），
  v1 的 dispcc 侧写法用 50 ms；两种都出现过 0 失败样本，**哪个必要未做单变量**。

### 3.4 只读判据命令（设备侧，今晚不用跑；留作上机时的判据）

分类口径：每次冷起（真 POR）记一条，**出现 ≥1 行 `command DMA timeout` 即判 STORM**，
否则判 GOOD；同时记 `card0` 是否出现（两者应一致）。

```sh
# ① 症状 A：command DMA 超时（只读）
dmesg -t | grep -cE 'command DMA timeout|bonded command DMA failed'
dmesg -t | grep -E 'command DMA|panel.*Failed to initialize|nt36536' | tail -n 8

# ② 症状 B：只有背光、没有 DRM 设备（只读）
ls -l /dev/dri/ 2>&1                      # 期望 GOOD: card0 在；STORM: 目录空/不存在
ls /sys/class/drm/ 2>&1                   # 期望 GOOD: card0、card0-DSI-1
for f in /sys/class/drm/card*-DSI-*/status; do echo "$f: $(cat "$f")"; done
cat /sys/class/backlight/*/brightness /sys/class/backlight/*/max_brightness
dmesg -t | grep -cE 'msm_dpu|dpu .*probe'  # DPU 有没有走到 probe 成功

# ③ 可选（需 root；**有风险**：对无时钟块做 devmem 读可能触发 SError，只在串口/pstore 可回看时做）
busybox devmem 0xaf08000 32   # DISP_CC_MDSS_CORE_BCR      bit0=1 ⇒ 该块仍被按在复位里
busybox devmem 0xaf0a000 32   # DISP_CC_MDSS_CORE_INT2_BCR bit0=1 ⇒ 同上
busybox devmem 0xaf0c000 32   # DISP_CC_MDSS_RSCC_BCR      bit0=1 ⇒ 同上
busybox devmem 0xae00010 32   # MDSS_HW_INTR_STATUS        bit0 MDP / bit4 DSI0 / bit5 DSI1
```

判据说明：
- ③ 的第一行给出「bootloader 是否把块留在运行态」的**客观读数**（deassert=0 即块已出复位），
  这是把 §3.1 的「bootloader 交棒时块是活的」从叙述变成数字的唯一低成本方法；
- ③ 最后一行 `0xae00010` 是 §2.1 的状态寄存器，可以在同一发里看「MDP/DSI 有没有报中断」，
  用来区分「面板没起来」与「起来了但没中断」。

---

## §4 可直接复用的三句话（不是回信正文）

1. **复位表**：sm8750 dispcc exposes three single-bit MDSS block resets — `DISP_CC_MDSS_CORE_BCR`
   (0x8000, bit 0), `DISP_CC_MDSS_CORE_INT2_BCR` (0xa000, bit 0), `DISP_CC_MDSS_RSCC_BCR`
   (0xc000, bit 0) — matching `MDSS_GDSC` (0x9000) and `MDSS_INT2_GDSC` (0xb000).
2. **中断控制器**：the MDSS node is an interrupt controller in DT
   (`interrupt-controller; #interrupt-cells = <1>`, DPU uses `interrupts-extended = <&mdss 0>`)
   and `msm_mdss.c` registers a chained irq chip over a 32-line linear domain that reads
   `MDSS_HW_INTR_STATUS` (offset 0x010: MDP/DSI0/DSI1/HDMI/EDP) — mask/unmask are software-only,
   the sub-blocks clear their own status. `INT2` is not a separate controller; it is the dispcc
   block reset covering the MDSS core's second interrupt group, as named by dispcc itself.
3. **副作用与测法**：without the block resets, cold boots intermittently fail with
   `command DMA timeout: status=0x2200200` → panel init `-5` → backlight only, no `/dev/dri/card0`
   (5 of 9 real PORs in the control arm; 15/15 with the three BCRs). Resetting the block also wipes
   the bootloader's handover framebuffer, which is why this board's DT deliberately omits
   `simple-framebuffer`; 52 other qcom board files do describe one (incl. `sm8650-valve-deckard.dts`),
   which is the reason the series is limited to sm8750.

---

## §5 证据边界（勿越界）

- `.bit` 默认 0 的推导来自 `reset.c:34` + 零初始化，**不是**从 datasheet 抄的；
- `INT2` = MDP TOP `INTR2` 组：**命名+结构证据，无文档直证**；
- 「三枚 BCR 复位」与「失败率下降」的因果：只有 **A/B 相关性 + p=0.003**，
  没有 INT2 单变量实验；复位保持时长（20 ms vs 50 ms）未做单变量；
- 「执行 reset 会打掉 ABL framebuffer」：来自我们 DT 注释里的现场观察 + 52 个板级文件的静态影响面，
  **未做**「同镜像带/不带 `simple-framebuffer` 节点」的对照上机（该实验已写进 B10，见
  `patches/upstream/dispcc-reset-v2-20261113/README.md` §4）。
