# M3-3 音频 + 温控片 —— 就绪化（文档 + 补丁草案 + Q2 评估）

> 日期：2026-10-13 · 范围：M3-3（音频 codec/机器驱动 + aw88461 Q2 评估 + 板 DTS thermal 归片）
> pristine 上游参照：geekidos-linux @ `24a19b953e`（Linux 7.3-rc7），工作树 `build/m3-3-worktree`
> 板 DTS 参照：`build/m1-upstream/clean-tree/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（payload）
> 纪律：纯主机侧，未上机 ⇒ 功能结论一律「未上机/未证实」。

---

## §1 Q2 评估：awinic,aw88461 独立驱动 vs 并入 aw88395 家族

### 1.1 事实基线（可复跑）

| 项 | 命令 | 输出（片段） |
|---|---|---|
| payload 独立驱动 | `wc -l build/m1-upstream/clean-tree/sound/soc/codecs/aw88461.c` | `547 .../aw88461.c`（含 of_device_id，兼容串 `awinic,aw88461`） |
| 上游家族文件 | `git -C build/m3-3-worktree ls-files sound/soc/codecs/aw88395/ sound/soc/codecs/aw88261.c sound/soc/codecs/aw88399.c` | `aw88395/aw88395{,_device,_lib,_data_type}.{c,h}`、`aw88395_reg.h`；兄弟驱动 `aw88261.c`、`aw88399.c` 平级 |
| 家族共享库 | `sound/soc/codecs/Kconfig` | `SND_SOC_AW88395_LIB`（= `aw88395/aw88395_lib.o + aw88395_device.o`）；**aw88261/aw88399 均 `select SND_SOC_AW88395_LIB` 但不 `select SND_SOC_AW88395`** |
| 家族 binding | `Documentation/devicetree/bindings/sound/awinic,aw88395.yaml` | `compatible: enum: [awinic,aw88081, aw88083, aw88166, aw88261, aw88395, aw88399]`（**无 aw88461**） |

> **上游 awinic 家族的既有形态 = 「一个芯片一个兄弟 .c 文件 + 共用 `aw88395/` 共享层」**（`aw88261.c`、`aw88399.c` 即此形态）。所谓「并入家族」在上游并非把芯片塞进 `aw88395_device.c` 的 switch，而是：驱动作为家族成员文件存在 + 复用 `aw88395/` 共享层 + 在家族 binding 里登记 compatible。

### 1.2 逐项对比

| 对比项 | aw88461（payload `sound/soc/codecs/aw88461.c`） | aw88395 家族（`aw88261.c` / `aw88399.c` + `aw88395/`） | 判定 |
|---|---|---|---|
| **1. of_device_id / compatible** | 独立表 `{ .compatible = "awinic,aw88461" }`；另有 i2c name | `aw88261_of_table { awinic,aw88261 }`、aw88399 用 ACPI `AWDZ8399`；`aw88395` 仅 i2c id | 同族做法；**只需把 `awinic,aw88461` 加进家族 binding enum**，不必新写 yaml |
| **2. 寄存器地址表** | 内联 `#define`：ID 0x00 / SYSST 0x01 / SYSINTM 0x03 / SYSCTRL 0x04 / SYSCTRL2 0x05 / I2SCTRL1 0x06 / NGCTRL3 0x5e；regmap 8-bit reg / 16-bit BE val / max 0x7f | `aw88395_reg.h`：ID 0x00/SYSST 0x01/SYSINT 0x02/SYSINTM 0x03/SYSCTRL 0x04/SYSCTRL2 0x05/I2SCTRL 0x06…；`aw88261.h` 同前缀 0x00–0x06；regmap 8/16 BE | **重叠寄存器 0x00–0x06 完全一致**；aw88461 的 PID 2308 私有寄存器（0x5e 等）与位定义（TXEN=bit13、ULS_HMUTE=bit15）属**芯片硬件事实**，本就该在**每芯片头文件**里 ⇒ 抽到 `aw88461.h`（家族惯例），不并入 `aw88395_reg.h` |
| **3. 固件格式 / fw bin 解析路径** | `#include "aw88395/aw88395_device.h"`，调用 `aw88395_dev_load_acf_check()` + `aw88395_dev_cfg_load()`，读 `struct aw_container` / `aw_cfg_hdr` / `aw_cfg_dde_v1` / `prof_desc[].sec_desc[AW88395_DATA_TYPE_REG]` | 同一套 `aw88395_lib.c` ACF 解析（magic `0xa15f908`），DDE 以 `chip_id` 匹配；aw88261/aw88399 亦 `#include "aw88395/aw88395_device.h"` | **同一 ACF 容器格式，已被 payload 复用** ⇒ 无独立固件格式 ⇒ 无独立驱动理由 |
| **4. 共用层可复用函数** | 复用 `aw88395_dev_load_acf_check`、`aw88395_dev_cfg_load`、`struct aw_device`/`aw_container`/`aw_prof_desc` | 共享 `aw88395_lib.c`+`aw88395_device.c`；aw88261/aw88399 各自实现芯片时序、共享解析 | **payload 已在复用共享解析层**；未复用者（`aw88395_dev_init/fw_update`，DSP/SRAM/校准）是 88395 私有序列，aw88461 无该 DSP 路径（见下） |
| **5. 初始化序列差异** | 无 DSP：PWDN→轮询 `SYSST`(PLL_LOCK)→AMPPD→poll `SYSST`(BOOST_READY/SWITCHING)→TXEN→解 mute→fade；写 ACF 的 **REG 段**，软复位 `ID=0x55aa`；自带 attenuation 音量模型 | `aw88395_dev_start`：PLL 检查→`aw_dev_check_sram`→DSP FW/CFG 下载（`DSPMADD/DSPMDAT` 0x40/0x41）→CRC/WDT 检查→`update_cali_re`；另含 calibration 服务 | **真实硬件差异**：PID 2308 无（或不需要）DSP 固件下载/校准路径；这段差异属硬件事实，**应留在 aw88461 自己的序列里，不能塞进 88395 共享 sequence** — 塞进去 = 用条件分支污染共享层（违反 §0「能复用则复用、不要把硬件事实变策略」的反面） |

### 1.3 结论：**并入 aw88395 家族**（按上游家族既有形态）

**建议 = 「并入」，但「并入」的实现形态是家族成员文件 + 家族 binding + 共享层，而不是把 aw88461 塞进 `aw88395_device.c` 的 chip_id switch。** 理由（逐条）：

1. **固件格式同源**（对比项 3/4）：payload 已在用 `aw88395/` 的 ACF 容器解析；固件 `awinic/*.bin` 的 DDE 以 `chip_id` 区分。若另立一套解析，等于复制 `aw88395_lib.c`（Q2 明确要避免）。
2. **寄存器前缀同源**（对比项 2）：0x00–0x06 与家族一致，只有高端私有寄存器/位不同 — 这正是 `aw88261.h`/`aw88399.h` 已经在做的事（每芯片一份寄存器头）。
3. **上游已有的「家族多芯片」范式**：`aw88261.c`/`aw88399.c` 就是与 `aw88395` **平级的兄弟驱动**，各自 `select SND_SOC_AW88395_LIB`。aw88461 完全落在这个范式内，不是 Q2 偏离；**矩阵把「有独立 .c」直接当作偏离是把「独立文件」误当「独立实现」**——真正判据是「是否复用共享层 + 是否登记进家族 binding」，两项 aw88461 前者已满足、后者缺登记。
4. **不得并入 `aw88395_device.c` 的理由**：88395 的 `dev_init/start/stop/fw_update` 深度绑定 DSP SRAM/CRC/校准寄存器与 `aw_dev_reg_update` 批量写路径；aw88461 无这些寄存器/流程。强行 switch 分支 = 在共享序列里插硬件差异分支（改造量大 + 污染共享层）⇒ 属「改造量过大」，按任务口径**只出方案**。

**若最终仍选「独立驱动」（不采纳，仅列举证要求）**：须给出 ① 寄存器地址 0x00–0x06 与家族**不同**的实证；② 固件**非 ACF**（magic 非 `0xa15f908`）的实证；③ 无法 `select SND_SOC_AW88395_LIB` 的技术原因。当前三项均**不成立**（1.2 已证），故不建议独立。

**落地清单（= §2 的 (b)**，含「先出 binding、驱动改造随后」）：

| # | 动作 | 文件 | 本片是否出补丁 |
|---|---|---|---|
| 1 | binding 登记 `awinic,aw88461` | `Documentation/devicetree/bindings/sound/awinic,aw88395.yaml`（enum 加一行） | ✅ **本片出（0001）** |
| 2 | 驱动按家族形态落地 | `sound/soc/codecs/aw88461.c`（保留，去调试残留）+ `aw88461.h`（寄存器/位定义，家族惯例）+ Kconfig `SND_SOC_AW88461` `select SND_SOC_AW88395_LIB` + Makefile 两行 | ✅ **本片出驱动补丁（0002）**；抽 `aw88461.h` 见「后续项」 |
| 3 | 后续项（改造量适中，本片不强制） | 把内联寄存器表抽到 `aw88461.h`；音量/衰减语义与家族 `VOL_MASK` 定义对齐（若硬件语义一致） | ⏳ 后续 |

## §2 补丁草案

### 2.1 补丁清单（2 枚，均已出草案）

目录：`patches/upstream/m3-3-2026-10-13/`；工作树 `build/m3-3-worktree`（分支 `m3-3/audio`，pristine `24a19b953e`）。

| 补丁 | 主题 | 内容 |
|---|---|---|
| `0001-dt-bindings-sound-awinic-aw88395-add-AW88461-compati.patch` | `dt-bindings: sound: awinic,aw88395: add AW88461 compatible` | 家族 binding `awinic,aw88395.yaml` 的 `compatible` enum 增加 `awinic,aw88461`（1 行）。**不新写 yaml**（判「并入」，见 §1.3） |
| `0002-ASoC-codecs-aw88461-add-Awinic-AW88461-smart-amplifi.patch` | `ASoC: codecs: aw88461: add Awinic AW88461 smart amplifier driver` | 家族成员驱动 `sound/soc/codecs/aw88461.c`（547 行，复用 `aw88395/aw88395_device.h` 的 ACF 解析层）+ `Kconfig: SND_SOC_AW88461`（`select SND_SOC_AW88395_LIB`）+ `Makefile` 两行 + `MAINTAINERS` 家族条目（`AWINIC AW88395 FAMILY…`，`F: sound/soc/codecs/aw88*`） |

补丁哈希（sha256）：

| 补丁 | sha256 |
|---|---|
| 0001 | `91a51def4950e167c7def0d21263131ef92eaf7353b555271fe0d78b64068230` |
| 0002 | `fd4de4a43e146f058a1e92e7a93789da1773bc202b3de25c377d8b165eb77ce1` |

commit：`e71bede6e6c2695d2f89e43ca4a6387c69494eb3`（0001）、`17507cd07242b291f331cf37b7eec5f0cbd63725`（0002）。

### 2.2 关键设计取舍

- **驱动文件 = 家族成员，不是独立实现**（§1.3）：`#include "aw88395/aw88395_device.h"`，调用 `aw88395_dev_load_acf_check()`/`aw88395_dev_cfg_load()`，`Kconfig` `select SND_SOC_AW88395_LIB` —— 与 `aw88261`/`aw88399` 完全同构。`aw88461.c` 与 payload 的文件**逐字节相同**（未做改写），因为它本已符合家族形态、且**无任何测试钩子/调试参数**（见 2.3 门 4）。
- **MAINTAINERS 为何在 0002 里**：checkpatch `--strict` 对新增文件报 `WARNING: added, moved or deleted file(s), does MAINTAINERS need updating?`。上游 `MAINTAINERS` 原**无** AW88395 家族条目（`grep -i aw88395 MAINTAINERS` 空），故一并补家族条目，使 0002 达 0W。若审阅者要求拆分，可把 MAINTAINERS 独立成 0003。
- **DTS 不入补丁**：板 DTS 的 `speaker_left/right` 节点改动归 **M3-2 板基础片**（见 §3）。
- 改造量评估：**抽 `aw88461.h`（寄存器/位定义）+ 音量语义与家族定义对齐**属后续项（本片不做），因需要 PID 2308 数据手册/硬件证据才能确认位定义，避免凭空猜测（§1.3 落地清单 #3）。

### 2.3 验收证据（全部本机实跑）

| 门 | 命令 | 原始输出 | 结果 |
|---|---|---|---|
| 1 checkpatch（0001） | `build/m3-3-worktree/scripts/checkpatch.pl --strict --no-tree patches/upstream/m3-3-2026-10-13/0001*.patch` | `total: 0 errors, 0 warnings, 0 checks, 7 lines checked` + `has no obvious style problems and is ready for submission.` | ✅ **0E/0W/0C** |
| 2 checkpatch（0002） | 同上 `0002*.patch` | `total: 0 errors, 0 warnings, 0 checks, 592 lines checked` + `ready for submission` | ✅ **0E/0W/0C** |
| 3 binding 自检 | `PATH=~/venv-dtschema/bin:$PATH dt-doc-validate build/m3-3-worktree/Documentation/devicetree/bindings/sound/awinic,aw88395.yaml` | `RC=0` | ✅ |
| 4 无测试钩子 | `grep -nE 'module_param\|MODULE_PARM\|debugfs\|printk\(\|dev_dbg' 0002*.patch` | `EXIT=1`（无匹配） | ✅ 无钩子/调试打印进补丁 |
| 5 编译 | `cp build/m1-upstream/clean-tree/.config . && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig && timeout -k 5 900 make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- sound/soc/codecs/` | `BUILD_RC=0`；日志 `125:  CC      sound/soc/codecs/aw88461.o`；`error/warning` 行 0；产物 `sound/soc/codecs/aw88461.o`（405952 B） | ✅ **rc=0，0 error/0 warning** |
| 6 配置登记 | `grep CONFIG_SND_SOC_AW88461 .config` | `CONFIG_SND_SOC_AW88461=y`（`CONFIG_SND_SOC_AW88395_LIB=y`） | ✅ |

## §3 板 DTS 音频段归片与缺口语义

> 规则：**板 DTS 改动只写进本报告，不放补丁**（DTS 归 M3-2 板基础片）；本片只判「上游支持面 + dai-link 组合是否触发 driver 改动」。

### 3.1 清单

| # | 节点（板 DTS 行） | compatible | 上游绑定 | 上游驱动 / of_device_id | 归片 | dai-link 是否需改 driver |
|---|---|---|---|---|---|---|
| 1 | `sound`（1125） | `qcom,sm8750-sndcard`, `qcom,sm8450-sndcard` | `sound/qcom,sm8250.yaml` 已列（L33-34 `sm8750-sndcard` + fallback `sm8450-sndcard`） | `sound/soc/qcom/sc8280xp.c` `snd_sc8280xp_dt_match` **已含** `qcom,sm8750-sndcard → sm8750_priv_data`（L578/L574） | **M3-2**（板 DTS） | 见 3.2 |
| 2 | `wcd939x`（1169） | `qcom,wcd9395-codec`, `qcom,wcd9390-codec` | `sound/qcom,wcd939x.yaml` 已列（L28/30-31 oneOf） | `sound/soc/codecs/wcd939x.c` of_device_id **两个都有**（L3592-3593） | **M3-3**（enable+属性）；节点文本归 M3-2 | 否（无缺口） |
| 3 | `speaker_left/right`（2107/2117） | `awinic,aw88461` | 上游**无**（本片 §2 补进家族 binding enum） | 上游**无**（本片 §2 出驱动） | **M3-3**（驱动，§2）；节点归 M3-2 | 驱动侧：家族成员驱动，DAI `aw88461-aif`，无需改机器驱动 |
| 4 | `&swr1 wcd_rx` / `&swr2 wcd_tx`（3127/3138） | `sdw20217010e00` | `sound/qcom,wcd939x-sdw.yaml`（L18 const） | `sound/soc/codecs/wcd939x-sdw.c` `wcd9390_slave_id[]`（L1413） | **M3-2**（板 DTS） | 否 |
| 5 | `lpass_txmacro`（sm8750.dtsi 2462） | `qcom,sm8750-lpass-tx-macro`, `qcom,sm8550-lpass-tx-macro` | `sound/qcom,lpass-tx-macro.yaml`（L26 `sm8750` + fallback `sm8550`） | upstream LPASS TX macro 驱动（clk/macro） | **M3-2**（继承自 dtsi） | 否 |
| 6 | `q6apm`/`q6apmbedai`/`q6apmdai`（sm8750.dtsi 2334-2347；板覆盖 2688/2694） | `qcom,q6apm`, `qcom,q6apm-lpass-dais`, `qcom,q6apm-dais` | qdsp6 bindings | `sound/soc/qcom/qdsp6/` | **M3-2**（板 DTS 覆盖 iommus/dai） | 见 3.2 |
| 7 | `secondary_mi2s_default` pinctrl（2841） | — | pinctrl 通用 | — | **M3-2** | 否 |

### 3.2 dai-link 组合是否会触发 driver 改动（**未上机 ⇒ 未证实**）

- `sm8750_priv_data`（sc8280xp.c）当前 = `driver_name="sm8750"`, `dapm_widgets=sc8280xp_dapm_widgets`, `wcd_jack=true`，**未设** `mi2s_mclk_enable`/`mi2s_bclk_enable`/`codec_dai_fmt`（对比 `sm8450`/`sm8550`/`sm8650` 都设了这三项，注释「I2S Connected to HDMI」）。
- 板 DTS 的两个 dai-link：`Secondary MI2S`（`q6apmbedai SECONDARY_MI2S_RX` → `speaker_left/right`）与 `WCD Capture`（`TX_CODEC_DMA_TX_3` → `wcd939x`/`swr2`/`lpass_txmacro`）。
- **判定**：这两个链接**不需要新增 driver 代码**——机器驱动已用 `qcom_snd_parse_of()` 通用解析任意 dai-link，`sc8280xp_snd_hw_params` 按 `codec_dai_fmt`/MI2S 分支处理。**风险点**：若上机后 MI2S BCLK/MCLK 未使能导致无声，可能需要给 `sm8750_priv_data` 加 `mi2s_bclk_enable`/`mi2s_mclk_enable` 或 `codec_sysfreq`——那时是**机器驱动数据表改动**（非新增驱动），且属硬件时序事实进 DT/数据表。**未上机，现状只能标「未证实」。**
- `&q6apmbedai` 板覆盖用 `dai@12`（`SECONDARY_MI2S_RX`）加 `clocks=<&q6prmcc …SEC_MI2S_IBIT…>`：这是**已有驱动的时钟描述**，非新驱动。

## §4 温控（thermal trips）归片盘点

### 4.1 盘点（原始计数）

```sh
$ grep -c -- '-thermal {' <board>.dts        # 24
$ grep -c 'type = "passive"' <board>.dts     # 96
$ grep -c 'cooling-maps {' <board>.dts       # 24
$ grep -c 'map[0-9] {' <board>.dts           # 96
$ grep -oE 'cooling-device = <&[a-z0-9_]+ [0-9]+ [0-9]+>' <board>.dts | sed -E 's/.*<&([a-z0-9_]+).*/\1/' | sort | uniq -c
     48 cpu0
     16 cpu6
     32 gpu
```

| 项 | 值 |
|---|---|
| 板 DTS 覆盖的 thermal-zone | **24**（`cpu-0-0-0-thermal`…`cpu-0-5-1-thermal` 12 个 + `cpu-1-0-0-thermal`…`cpu-1-1-1-thermal` 4 个 + `gpuss0-thermal`…`gpuss7-thermal` 8 个） |
| 每 zone 新增 passive trip | 4（70 / 82 / 90 / 105 °C），共 **96** |
| hysteresis | passive0–2 = 3000 µ°C；passive3 = 5000 µ°C（96 trip 中 24 个 5000） |
| `polling-delay-passive` | `<100>`（板覆盖） |
| cooling-maps | 每 zone 1 个节点、4 条 map，共 **96** 条 |
| cdev 分布 | 12 个 CPU-perf zone → `&cpu0`（levels 5/8/10/15）；4 个 prime zone（`cpu-1-*`）→ `&cpu6`（levels 7/11/13/15）；8 个 GPU zone → `&gpu`（levels 5/8/10/13） |
| 继承自 `sm8750.dtsi`（未改） | 每 zone `thermal-sensors`、`trip-point0`（hot 120 °C / hyst 5000）、`*-critical`（125 °C / hyst 0） |

### 4.2 归片判定

- **归片 = M3-2 板基础片**（板 DTS 内容；本片只盘点，不改）。
- **纯 DTS 数据，无驱动改动**：trips / cooling-maps / cdev 引用全部是 devicetree 层；`&cpu0`/`&cpu6` 是 cpufreq cooling device（`#cooling-cells` 由 dtsi 提供），`&gpu` 是 devfreq cooling device。无任何 thermal driver 或 governor 代码需改（`drivers/thermal/qcom/tsens`、`drivers/thermal/gov_step_wise` 等在上游已具备）。
- 温度值「硬编码进 DTS」**不是规范问题**——按三问门 Q3，板级温控策略属**软件策略/板级数据**，放 DTS 正是正确落点（不应进 C）。

### 4.3 上游规范观察（供 M3-2 送审前注意，非 blocker）

| 观察 | 说明 | 建议 |
|---|---|---|
| 用**完整路径**重新声明 `/thermal-zones/<zone>` 节点来追加 `trips`/`cooling-maps` | DT 允许节点合并，`dtc`/`dt-validate` 可通过；但审阅者常偏好 `&label { … }` 形式 | 保持现状可接受；若 dtbs_check 报 node 重定义可改 `&label` 形式 |
| trip 标签命名 `cpu_0_0_0_passive0` / 子节点名 `passive0` | 唯一、可引用；非上游强制命名 | 可接受；语义化命名（`*_alert0`）仅美观 |
| 阈值 70/82/90/105 °C 与 cdev level 的对应是**厂商 HAL 复刻**（注释「Stock … 105 C」） | 属板级热策略，DTS 是正确落点 | 保留；送审时在 commit log 说明来源（本机实测/原厂 HAL）而非推测 |
| 12 个 perf zone 都指向 `&cpu0`、4 个 prime zone 指向 `&cpu6` | 与 sm8750.dtsi 的 per-core zone 结构匹配 | 无 driver 影响 |
| `hysteresis` 单位 | DTS 用 µ°C（3000 = 3 °C），正确 | — |

**结论（未上机）**：thermal 段是**纯 DTS 数据 + 上游已有驱动框架**，无缺口、无驱动补丁；本片不产生补丁，归 M3-2。功能是否生效（实际降频曲线是否与厂商一致）**未上机 ⇒ 未证实**。

## §5 验收原始输出 · 产物清单 · 未决问题 · 未上机声明

### 5.1 验收原始输出（本机实跑，2026-10-13）

```sh
# 门 1/2 checkpatch --strict --no-tree
$ build/m3-3-worktree/scripts/checkpatch.pl --strict --no-tree patches/upstream/m3-3-2026-10-13/*.patch
total: 0 errors, 0 warnings, 0 checks, 7 lines checked
…/0001-dt-bindings-sound-awinic-aw88395-add-AW88461-compati.patch has no obvious style problems and is ready for submission.
total: 0 errors, 0 warnings, 0 checks, 592 lines checked
…/0002-ASoC-codecs-aw88461-add-Awinic-AW88461-smart-amplifi.patch has no obvious style problems and is ready for submission.

# 门 3 binding 自检
$ PATH=~/venv-dtschema/bin:$PATH dt-doc-validate build/m3-3-worktree/Documentation/devicetree/bindings/sound/awinic,aw88395.yaml
DT_RC=0

# 门 4 编译（config 取自 m1-upstream/clean-tree）
$ cd build/m3-3-worktree && cp build/m1-upstream/clean-tree/.config . && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
$ timeout -k 5 900 make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- sound/soc/codecs/
  CC      sound/soc/codecs/aw88461.o      # /tmp/m33-build.log:125
BUILD_RC=0   # 0 error / 0 warning（grep -iE 'error|warning' 无命中）
$ ls -l build/m3-3-worktree/sound/soc/codecs/aw88461.o   # 400K

# 门 5 干净应用
$ git -C geekidos-linux worktree add --detach /tmp/m33-verify 24a19b953e
$ cd /tmp/m33-verify && git am patches/upstream/m3-3-2026-10-13/*.patch
应用：dt-bindings: sound: awinic,aw88395: add AW88461 compatible
应用：ASoC: codecs: aw88461: add Awinic AW88461 smart amplifier driver
AM_RC=0

# 门 6 无测试钩子
$ grep -nE 'module_param|MODULE_PARM|debugfs|printk\(|dev_dbg' 0002*.patch
EXIT=1      # 无匹配
```

| 门 | 结果 |
|---|---|
| checkpatch 0001 / 0002 | ✅ **0E/0W/0C**，ready for submission |
| `dt-doc-validate` binding | ✅ rc=0 |
| `make … sound/soc/codecs/` | ✅ rc=0，0 error/0 warning，`CC aw88461.o` |
| `git am`（pristine `24a19b953e`） | ✅ rc=0，两枚干净应用 |
| 测试钩子扫描 | ✅ 无 |

### 5.2 产物清单

| 路径 | 内容 |
|---|---|
| `reports/m3-3-audio-thermal-slice-20261013.md` | 本报告（§1 Q2 评估 / §2 补丁 / §3 DTS 归片 / §4 温控 / §5 验收） |
| `patches/upstream/m3-3-2026-10-13/0001-dt-bindings-sound-awinic-aw88395-add-AW88461-compati.patch` | binding enum 扩展 |
| `patches/upstream/m3-3-2026-10-13/0002-ASoC-codecs-aw88461-add-Awinic-AW88461-smart-amplifi.patch` | 家族成员驱动 + Kconfig/Makefile + MAINTAINERS |
| `patches/upstream/m3-3-2026-10-13/README.md` | 本片 README（补丁清单/验收/发送纪律） |
| `build/m3-3-worktree` | 工作树，分支 `m3-3/audio`，pristine `24a19b953e`，tip `17507cd07242b291f331cf37b7eec5f0cbd63725` |

### 5.3 未决问题

1. **aw88461 寄存器表/位定义抽头文件**（`aw88461.h`）与音量语义对齐家族定义——需 PID 2308 数据手册或硬件证据（避免凭空猜位）。列为后续项（§1.3 #3），本片不改。
2. **aw88461 驱动未做运行时功能验证**：ACF `y700-gen4-speakers.bin` 的 DDE `chip_id=0x2308` 只在驱动路径上被解析，未在设备上播放验证。
3. **`sm8750_priv_data` 的 MI2S 时钟 flag**（§3.2）：上机若无 MI2S 声音，需评估是否加 `mi2s_bclk_enable`/`mi2s_mclk_enable`；未上机无法判定。
4. **MAINTAINERS 条目是否单独成补丁**：现并入 0002；若审阅者要求拆分，可拆成独立补丁。
5. **AUX 路径（`wcd939x` 的 MBHC/jack、`qcom,sm8750-sndcard` 的 `wcd_jack`）**：本片只做支持面盘点，实际耳机检测/切换未验证。

### 5.4 未上机声明

**本片全部为主机侧静态分析 + 构建 + schema 校验。** 未接触设备、未运行 fastboot/EDL、未在 TB322FC 上播放音频或观察温控降频。因此：

- 「上游有无驱动」结论基于 **of_device_id / binding 表的静态核对**（§3 逐项列出文件行号）；
- 「编译通过 / checkpatch 0E0W / dt-doc-validate rc=0」= **主机侧就绪**；
- **任何功能结论（发声、耳机检测、温控曲线正确）一律标「未上机/未证实」**，不得表述为「已修复/已验证」。

---
（报告完）

