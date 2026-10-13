# M3-2 板基础片切分台账（2026-10-13）

> **状态**：本文件由 lane `m3-2-boardsplit`（`deepseek/deepseek-flash`）重建（原 lane B worker 被停止时只留空骨架，无任何数据）；编排者已独立复核关键门：`make dtbs` rc=0、板 DTB `dt-validate`（自带 binding）0 诊断、`grep -c ^&` = 58、基座 `m1/clean-tree` = Linux 7.2.0 vs pristine 7.3-rc7（`merge-base --is-ancestor 24a19b953e clean/base` rc=1）。
> 规则 = `reports/upstream-policy-20261013.md`（三问门）；M3 分片口径 = `reports/m3-series-plan-20261013.md` §0/§2/§3；
> compatible 级支持面 = `reports/m3-missing-support-matrix-20261013.md`。
> 上游参照 = **pristine 提交 `24a19b953e`**（Linux 7.3-rc7，仓库 `geekidos-linux`）；payload 树 = `build/m1-upstream/clean-tree`。
> 判"上游有没有驱动"一律查 `of_device_id` / `device_id` 表，不按 compatible 字符串 grep 下结论。

## §1 数字结论表

**口径**：统计单位为**板 DTS 顶层块** = 根 `/` 块 + 58 个 `&label` 块，共 **59**（`grep -c '^&[a-z_0-9]*' <dts>` → 58，+1 root；命令见 §5）。一个块内可有多个 compatible（如 `&i2c5` 同时含 fsa4480 与 ptn3222），按"该块是否需要 M3-2 之外的上游改动"归类，取所需改动最大的子节点。

| 类别 | 数 | 含义 |
|---|---|---|
| **顶层块总数** | **59** | `/ {`（22 行）+ **58** 个 `^&label {`（1542–3134 行） |
| 其中 **58 个 `&label` 块**分三类 ↓ | | |
| **上游 binding+驱动全齐**（纯板级 enablement，M3-2 主体） | **46** | 块内 compatible 的 binding 与驱动 `of_device_id` 都在 pristine `24a19b953e`，块本身只加 `status`/`regulators`/`pinctrl` |
| **需扩展现有驱动** | **3** | `&i2c6`(aw86937)、`&mdss_dsi0`(panel)、`&uart14`(wcn7861-bt) |
| **payload 新写**（无上游 binding 或驱动） | **7** | `&i2c9`(aw88461)、`&i2c10`(wl2868c)、`&camss`、`&cci0_i2c0`(gt9764+s5kjns)、`&cci1_i2c0`(gc08a8)、`&pcieport0`(pci17cb,110e)、`&spi4`(nt36536-ts) |
| **待重判（基线漂移）** | **2** | `&gpu`、`&gmu`（见下条"口径出入 ②") |
| **根 `/` 块**（自带 15 个 compatible 子节点，§2.1） | 1 | 内含新写 1（`lenovo,elden` binding）、扩展 1（`qcom,wcn7861-pmu`），其余归 M3-2/M3-3 |

46+3+7+2 = **58** ✅（= `&label` 块数）。

### 与缺口矩阵 `m3-missing-support-matrix-20261013.md` 的口径出入（逐条给证据）

**① 口径不同、不可相加**：矩阵按 **compatible**（"上游齐 14 / 需扩展 6 / 新写 9"），本报告按 **顶层块**（58）。同一个块的多个 compatible 会被矩阵拆成多行，故 14+6+9=29 不能与本表的 44+4+8 对齐。矩阵自己也声明"其余 14 项…直接引用"未逐条列全。

**② 矩阵的 payload diff 行数混入 7.2→7.3 上游漂移（重要）**：clean-tree 的基座是 **Linux 7.2.0**，pristine 是 **7.3-rc7**，两者不同谱系（repo 为 shallow，merge-base 不可用）：
```
$ head -4 build/m1-upstream/clean-tree/Makefile   # VERSION=7 PATCHLEVEL=2 EXTRAVERSION=
$ git -C geekidos-linux show 24a19b953e:Makefile | head -4   # VERSION=7 PATCHLEVEL=3 EXTRAVERSION=-rc7
$ git -C geekidos-linux merge-base 24a19b953e c73ff25222    # (空)
$ ls geekidos-linux/.git/shallow                             # 00008e6f… / 24a19b953e… (shallow 边界)
```
因此 §2 表里用派工规定命令（`git show 24a19b953e:<path> | diff -u - <clean-tree>/<path>`）得到的行数，**对"上游同名文件本身在 7.2→7.3 有演进"的条目是复合值，不等于 payload 自身改动量**。典型：
- `arch/arm64/boot/dts/qcom/pmk8550.dtsi` diff=26——实际是 7.3-rc7 **新增** `pmk8550_vadc`（ADC5-gen3）节点，与 elden payload 无关（`git diff 24a19b953e c73ff25222 -- pmk8550.dtsi` 显示是 `-` 整块 adc@9000）；
- `arm/qcom.yaml` diff=493、`sm8750.dtsi` diff=684 同理（后者含 7.3 删除 `uart15`、7.3 新增 `power-domains` 等漂移），真正的 elden 改动只有 `qcom,non-secure-domain`（见 §2 `&remoteproc_adsp` 行与 §5 未决问题）。
矩阵报的 **panel 74 / aw86927 363 / hci_qca 393 / pwrseq 591 / qca6390-pmu.yaml 46 / wcd939x.yaml 0** 六个数与本人复跑**完全一致**（§2 表内标 **✅复跑一致**），但其中非零项同样带此口径瑕疵。

**③ 矩阵漏项 / 命名不符**：
- 矩阵未收录 `st,st21nfca-i2c`（`&i2c0` NFC）——实测 pristine binding `net/nfc/st,st21nfca.yaml` ✅ + 驱动 `of_device_id` 含 `st,st21nfca-i2c` ✅，属"上游齐"，归 M3-2。
- 矩阵写 compatible `awinic,aw86927`（"基座"），**板 DTS 实际用的是 `awinic,aw86937`**；pristine `drivers/input/misc/aw86927.c` 的 `of_device_id` **只有** `{.compatible = "awinic,aw86927"}`，无 aw86937 ⇒ 该条本质是"扩展上游驱动的 compatible 表"，矩阵的"基座"表述方向对、编号错。
- 矩阵对面板写"驱动 ✅"，**未注明驱动 `of_device_id` 匹配的是 `csot,pp8807hb1-1`**（`panel-novatek-nt36536.c:469-472` 只有这一个），`novatek,nt36536` 只作 binding 的第二个 `const`。板 DTS 写成 `"csot,pp8807hb1-1", "novatek,nt36536"` 才成立——这正是"必须查 of_device_id"的历史误判点。

## §2 逐节点台账表

**判定方法**：每个 compatible 都在 pristine `24a19b953e` 上跑
`git -C geekidos-linux grep -l -F -e '<compat>' 24a19b953e -- Documentation/devicetree/bindings`（binding）与
`… -- drivers/ sound/`（驱动），并把驱动命中逐条回落到 `of_device_id` / `*_of_match` / i2c_device_id 表确认（**不按 compatible 字符串下结论**）。
"payload 改动"列用派工规定命令 `git show 24a19b953e:<path> | diff -u - <clean-tree path> | grep -c '^[+-][^+-]'`；`—` = pristine 无同名文件或未改动。
**归片缩写**：M3-2 板基础 / M3-3 音频温控 / M3-4 显示 / M3-5 相机 / M3-6 无线 / M4 需单独立项。

### §2.1 根 `/` 块（22–1541 行）内带 compatible 的子节点

| 子节点 | 行号 | compatible | 上游 binding | 上游驱动（of_device_id） | payload 改动 | 归片 | 备注 |
|---|---|---|---|---|---|---|---|
| model/compatible | 24 | `lenovo,elden`, `qcom,sm8750` | ❌ pristine `arm/qcom.yaml` **无 `lenovo,elden`** | — | `arm/qcom.yaml` 需新增 1 条 enum（clean-tree:1125 已有） | **M3-2** | 必须随 DTS 同行的 binding 改动 |
| thermal-zones | 26 | （无 compatible，纯策略） | n/a | n/a | — | M3-3 | 分级 passive trips（Q3：硬件限值进 DT，OK） |
| sound (sndcard) | 1125 | `qcom,sm8750-sndcard`, `qcom,sm8450-sndcard` | `sound/qcom,sm8250.yaml` ✅ | `sound/soc/qcom/sc8280xp.c` ✅ | sm8250.yaml diff=28；sc8280xp.c diff=393（含 7.2→7.3 漂移） | M3-3 | dai-link 需与 codec 一致 |
| wcd codec | 1170 | `qcom,wcd9395-codec`, `qcom,wcd9390-codec` | `sound/qcom,wcd939x.yaml` ✅ | `sound/soc/codecs/wcd939x.c:3591` ✅ | wcd939x.yaml **diff=0 ✅复跑一致**；wcd939x.c diff=20（漂移） | M3-3 | 无缺口，直接用 |
| framebuffer | 1211 | `simple-framebuffer` | `display/simple-framebuffer.yaml` ✅ | `drivers/gpu/drm/sysfb/simpledrm.c` ✅ | — | M3-2 | |
| fixed-clock ×2 | 1242/1248 | `fixed-clock` | `clock/fixed-clock.yaml` ✅ | `drivers/clk/clk-fixed-rate.c` ✅ | — | M3-2 | |
| fixed-factor-clock ×2 | 1254/1263 | `fixed-factor-clock` | `clock/fixed-factor-clock.yaml` ✅ | `drivers/clk/clk-fixed-factor.c` ✅ | — | M3-2 | |
| gpio-keys | 1273 | `gpio-keys` | `input/gpio-keys.yaml` ✅ | `drivers/input/keyboard/gpio_keys.c` ✅ | gpio_keys.c diff=7（漂移） | M3-2 | |
| pmic-glink | 1289 | `qcom,sm8750-pmic-glink`, `qcom,pmic-glink` | `soc/qcom/qcom,pmic-glink.yaml` ✅ | `drivers/soc/qcom/pmic_glink.c` ✅ | pmic_glink.c **diff=0** | M3-2 | |
| usb-c-connector ×2 | 1299/1337 | `usb-c-connector` | `connector/usb-connector.yaml` ✅ | DT-only（type-C class 框架） | — | M3-1/M3-2 | 与 M3-1 的 dwc3 mux 段耦合 |
| wcn7861-pmu | 1368 | `qcom,wcn7861-pmu` | ❌（pristine 只有 `wcn7850-pmu`；payload 改 `qca6390-pmu.yaml`） | `drivers/power/sequencing/pwrseq-qcom-wcn.c` **of_match 无 wcn7861** | qca6390-pmu.yaml **diff=46 ✅复跑一致**；pwrseq diff=591 ✅复跑一致 | M3-6 / **M4** | Q2 偏离候选（591 行≈重写） |
| ramoops | 1462 | `ramoops` | `reserved-memory/ramoops.yaml` ✅ | `drivers/of/platform.c`（of 平台设备） | — | M3-2 | |
| regulator-fixed ×4 | 1480/1491/1508/1525 | `regulator-fixed` | `regulator/fixed-regulator.yaml` ✅ | `drivers/regulator/fixed.c` ✅ | — | M3-2 | |

### §2.2 顶层 `&label` 块（58 个，按源文件出现顺序）

| 节点 | 行号 | compatible | 上游 binding | 上游驱动（of_device_id） | payload 改动 | 归片 | 备注 |
|---|---|---|---|---|---|---|---|
| `&apps_rsc` | 1542 | `qcom,pm8550-rpmh-regulators` / `pm8550ve-` / `pm8550vs-rpmh-regulators` | `regulator/qcom,rpmh-regulator.yaml` ✅ | `drivers/regulator/qcom-rpmh-regulator.c:2013/2017/2021` ✅ | qcom-rpmh-regulator.c diff=104（含漂移）；rpmh-regulator.yaml **diff=0** | M3-2 | 5 路 PMIC regulator bank |
| `&gpi_dma1` | 1987 | `qcom,sm8750-gpi-dma`, `qcom,sm6350-gpi-dma` | `dma/qcom,gpi.yaml` ✅ | `drivers/dma/qcom/gpi.c` ✅ | — | M3-2 | |
| `&gpi_dma2` | 1991 | 同上 | ✅ | ✅ | — | M3-2 | |
| `&i2c0` | 1998 | 主体 `qcom,geni-i2c`；子 `st,st21nfca-i2c`（NFC） | geni: `i2c/qcom,i2c-geni.yaml` ✅；NFC: `net/nfc/st,st21nfca.yaml` ✅ | geni: `i2c-qcom-geni.c:1345` ✅；NFC: `drivers/nfc/st21nfca/i2c.c:595-599` of_match 含 `st,st21nfca-i2c` ✅ | st21nfca.yaml **diff=0** | M3-2 | **矩阵漏项**（NFC 未收录） |
| `&i2c5` | 2016 | `qcom,geni-i2c`；子 `fcs,fsa4480`、`nxp,ptn3222` | fsa4480: `usb/fcs,fsa4480.yaml` ✅；ptn3222: `phy/nxp,ptn3222.yaml` ✅ | `usb/typec/mux/fsa4480.c:344` ✅、`drivers/phy/phy-nxp-ptn3222.c:105` ✅ | fsa4480.c **diff=0**；ptn3222.c diff=57（含漂移） | M3-2 | USB2 mux / redriver |
| `&i2c6` | 2072 | `qcom,geni-i2c`；子 `awinic,aw86937`×2（触觉） | ❌ 无 `awinic,aw86937`（上游仅 `input/awinic,aw86927.yaml`） | `drivers/input/misc/aw86927.c:863` of_id **只有 `awinic,aw86927`** ⇒ 需扩展 | aw86927.c **diff=363 ✅复跑一致**；awinic,aw86927.yaml diff=22 | **M3-未列**（B2/A3 挂账） | 连续模式魔数须 DT 化（政策 §3） |
| `&i2c9` | 2103 | `qcom,geni-i2c`；子 `awinic,aw88461`×2（功放） | ❌ 无 | ❌ 无（上游 `sound/soc/codecs/aw88395/` 家族**未列 aw88461**） | 新文件 `sound/soc/codecs/aw88461.c`（547 行） | M3-3 | Q2 偏离候选：评估并入 aw88395 家族 |
| `&i2c10` | 2127 | `qcom,geni-i2c`；子 `willsemi,wl2868c`（相机 PMIC）、`awinic,aw99706`（背光） | wl2868c ❌ 无；aw99706 ✅ `leds/backlight/awinic,aw99706.yaml` | wl2868c ❌ 无；aw99706 ✅ `drivers/video/backlight/aw99706.c:456` | wl2868c=新文件；aw99706.c diff=31（含漂移） | M3-5(wl2868c)/M3-2(aw99706) | 一块两 compatible，归片不同 |
| `&camss` | 2213 | 继承 `qcom,sm8750-camss` | ❌ 无 sm8750 代际（上游 camss 仅 csid-340/680、vfe gen2/3；existing `media/qcom,sm8750-iris.yaml` 是 ISP 另一套） | ❌ 无 gen4/980 | 新增 `camss-csid-980.c`/`camss-vfe-gen4.c`+改动 | M3-5 / **M4** | 最大件（B8） |
| `&cci0` | 2250 | 继承 `qcom,sm8750-cci`, `qcom,msm8996-cci` | `i2c/qcom,i2c-cci.yaml:46/144` 列 `qcom,sm8750-cci` ✅ | `drivers/i2c/busses/i2c-qcom-cci.c:803` of_match 含 `qcom,msm8996-cci` ✅（sm8750 靠 fallback 匹配） | — | M3-2 | |
| `&cci0_i2c0` | 2257 | `giantec,gt9764`（actuator）、`samsung,s5kjns`（前摄） | ❌ / ❌ | ❌ / ❌ | 新文件 `drivers/media/i2c/gt9764.c`、`s5kjns.c` + binding | M3-5 | V4L2 subdev |
| `&cci1` | 2298 | 继承 `qcom,sm8750-cci`, `qcom,msm8996-cci` | ✅ | ✅ | — | M3-2 | |
| `&cci1_i2c0` | 2305 | `galaxycore,gc08a8`（后摄） | ❌ | ❌ | 新文件 `drivers/media/i2c/gc08a8.c` + binding | M3-5 | V4L2 subdev |
| `&gpu` | 2334 | 继承 `qcom,adreno-44050000`, `qcom,adreno` | ⚠️ pristine **无** `qcom,adreno-44050000` 字样 | ⚠️ pristine **无** | — | M3-4 | **基线漂移**：pristine 7.3-rc7 `sm8750.dtsi` **无 gpu@3d00000 节点**（`git show 24a19b953e:.../sm8750.dtsi | grep -c gpu@3d00000` → 0），需 rebase 后重判 |
| `&gmu` | 2338 | 继承 `qcom,adreno-gmu-830.1`, `qcom,adreno-gmu` | ⚠️ 无 | ⚠️ `git grep adreno-gmu-830.1` 在 pristine 无命中 | — | M3-4 | 同 `&gpu`，待重判 |
| `&mdss` | 2342 | 继承 `qcom,sm8750-mdss` | `display/msm/qcom,sm8750-mdss.yaml:20` ✅ | `drivers/gpu/drm/msm/msm_mdss.c:556` ✅ | — | M3-4 | |
| `&mdss_mdp` | 2349 | 继承 `qcom,sm8750-dpu` | `display/msm/qcom,sm8650-dpu.yaml:24` ✅ | `drivers/gpu/drm/msm/disp/dpu1/dpu_kms.c:1515` ✅ | — | M3-4 | A1 GC gamma block 另见 `patches` |
| `&mdss_dp0` | 2353 | 继承 `qcom,sm8750-dp`, `qcom,sm8650-dp` | `display/msm/dp-controller.yaml` ✅ | `drivers/gpu/drm/msm/dp/dp_display.c` ✅ | — | M3-4 | |
| `&mdss_dp0_out` | 2357 | （endpoint，无 compatible） | n/a | n/a | — | M3-4 | |
| `&mdss_dsi0` | 2361 | 主体 `qcom,sm8750-dsi-ctrl`；子面板 `csot,pp8807hb1-1`, `novatek,nt36536` | dsi-ctrl `display/msm/dsi-controller-main.yaml` ✅；panel `display/panel/novatek,nt36536.yaml` ✅（compatible 为 `csot,pp8807hb1-1` + `const: novatek,nt36536`） | dsi-ctrl `dsi_phy/dsi_phy.c`+dsi ctrl ✅；panel `panel-novatek-nt36536.c:469` of_id **仅 `csot,pp8807hb1-1`** ✅（按第一 compatible 匹配） | panel-novatek-nt36536.c **diff=74 ✅复跑一致**；novatek,nt36536.yaml **diff=0** | M3-4 | **须先剥 `force_hz` 测试钩子**（政策 §3 D2）；B5 per-SoC cfg 重构同片 |
| `&mdss_dsi0_out` | 2409 | （endpoint） | n/a | n/a | — | M3-4 | |
| `&mdss_dsi0_phy` | 2414 | 继承 `qcom,sm8750-dsi-phy-3nm` | `phy/qcom,dsi-phy-7nm.yaml:32` ✅ | `drivers/gpu/drm/msm/dsi/phy/dsi_phy.c:580` ✅ | — | M3-4 | |
| `&mdss_dsi1` | 2423 | 继承 `qcom,sm8750-dsi-ctrl`, `qcom,mdss-dsi-ctrl` | `display/msm/dsi-controller-main.yaml` ✅ | `drivers/gpu/drm/msm/dsi/dsi_host.c` ✅ | — | M3-4 | |
| `&mdss_dsi1_out` | 2446 | （endpoint） | n/a | n/a | — | M3-4 | |
| `&mdss_dsi1_phy` | 2451 | 继承 `qcom,sm8750-dsi-phy-3nm` | `phy/qcom,dsi-phy-7nm.yaml:32` ✅ | `dsi_phy.c:580` ✅ | — | M3-4 | |
| `&pcie0` | 2459 | 继承 `qcom,pcie-sm8750`, `qcom,pcie-sm8550` | `pci/qcom,pcie-sm8550.yaml` ✅ | `drivers/pci/controller/dwc/pcie-qcom.c`（`qcom,pcie-sm8550` 命中） | — | M3-2 | |
| `&pcie0_phy` | 2469 | 继承 `qcom,sm8750-qmp-gen3x2-pcie-phy` | `phy/qcom,sc8280xp-qmp-pcie-phy.yaml` ✅ | `phy/qualcomm/phy-qcom-qmp-pcie.c` ✅ | — | M3-2 | |
| `&pcieport0` | 2476 | 子 `pci17cb,110e`（ath12k PEACH） | ❌（payload 改 `net/wireless/qcom,ath12k.yaml`） | ❌ 无（pristine ath12k 无 PEACH/WCN7861） | ath12k `core.c` diff=85、`hw.c` **pristine 无同名文件**；合计 ~800 行 | M3-6 / **M4（B6）** | 需按维护者偏好拆框架/数据表 |
| `&pm8550ve_f_gpios` | 2498 | 继承 `qcom,pm8550ve-gpio`, `qcom,spmi-gpio` | `pinctrl/qcom,pmic-gpio.yaml` ✅ | `pinctrl/qcom/pinctrl-spmi-gpio.c` ✅ | — | M3-2 | |
| `&pm8550_flash` | 2516 | 继承 `qcom,pm8550-flash-led`, `qcom,spmi-flash-led` | `leds/qcom,spmi-flash-led.yaml` ✅ | `drivers/leds/flash/leds-qcom-flash.c`（`qcom,spmi-flash-led` 命中） | — | M3-2 | |
| `&pm8550_gpios` | 2532 | 继承 `qcom,pm8550-gpio`, `qcom,spmi-gpio` | `pinctrl/qcom,pmic-gpio.yaml` ✅ | `pinctrl-spmi-gpio.c` ✅ | — | M3-2 | |
| `&pm8550ve_gpios` | 2542 | 继承 `qcom,pm8550ve-gpio`, `qcom,spmi-gpio` | ✅ | ✅ | — | M3-2 | |
| `&pmih0108_eusb2_repeater` | 2552 | 继承 `qcom,pm8550b-eusb2-repeater` | `phy/qcom,snps-eusb2-repeater.yaml` ✅ | `phy/qualcomm/phy-qcom-eusb2-repeater.c` ✅ | — | M3-2 | |
| `&pon_pwrkey` | 2557 | 继承 `qcom,pmk8350-pwrkey` | `input/qcom,pm8941-pwrkey.yaml` ✅ | `input/misc/pm8941-pwrkey.c` ✅ | — | M3-2 | |
| `&pon_resin` | 2561 | 继承 `qcom,pmk8350-resin` | ✅ | ✅ | — | M3-2 | |
| `&qupv3_1` | 2567 | 继承 `qcom,geni-se-qup` | `soc/qcom/qcom,geni-se.yaml` ✅ | `soc/qcom/qcom-geni-se.c` ✅ | — | M3-2 | |
| `&qupv3_2` | 2571 | 同上 | ✅ | ✅ | — | M3-2 | |
| `&remoteproc_adsp` | 2575 | 继承 `qcom,sm8750-adsp-pas`, `qcom,sm8550-adsp-pas` | `remoteproc/qcom,sm8550-pas.yaml` ✅ | `drivers/remoteproc/qcom_q6v5_pas.c`（`qcom,sm8550-adsp-pas` 命中） | `sm8750.dtsi` diff=684（多为 7.2→7.3 漂移）；**真实 elden 改动 = fastrpc 加 `qcom,non-secure-domain`**（commit c73ff25222） | M3-2（ADSP 启用）/ 独立 dtsi 补丁 | dtsi 改动不是板 DTS 改动 |
| `&remoteproc_cdsp` | 2630 | 继承 `qcom,sm8750-cdsp-pas`, `qcom,sm8650-cdsp-pas` | `qcom,sm8550-pas.yaml` ✅ | `qcom_q6v5_pas.c` ✅ | — | M3-2 | |
| `&spi4` | 2642 | 主体 `qcom,geni-spi`；子 `novatek,nt36536-ts`（触屏） | geni: `spi/spi-geni-qcom.yaml` ✅；触屏 ❌ 无 | geni: `spi/spi-geni-qcom.c:1237` ✅；触屏 ❌ 无 | 新文件 `drivers/input/touchscreen/novatek-nvt36xxx-spi.c` + `input/touchscreen/novatek,nt36536-ts.yaml` | M3-4 | 挂 SPI+input |
| `&sdhc_2` | 2672 | 继承 `qcom,sm8750-sdhci`, `qcom,sdhci-msm-v5` | `mmc/qcom,sdhci-msm.yaml` ✅ | `drivers/mmc/host/sdhci-msm.c`（`qcom,sdhci-msm-v5` 命中） | — | M3-2 | |
| `&q6apmdai` | 2688 | 继承 `qcom,q6apm-dais` | `sound/qcom,q6apm-dai.yaml` ✅ | `sound/soc/qcom/qdsp6/q6apm-dai.c` ✅ | — | M3-3 | |
| `&q6apmbedai` | 2694 | 继承 `qcom,q6apm-lpass-dais` | `sound/qcom,q6apm-lpass-dais.yaml` ✅ | `sound/soc/qcom/qdsp6/q6apm-lpass-dais.c` ✅ | — | M3-3 | |
| `&qup_spi4_cs` | 2705 | （pinctrl 状态，无 compatible） | pinctrl 框架 ✅ | ✅ | — | M3-4 | 与 `&spi4` 同片 |
| `&qup_spi4_data_clk` | 2710 | 同上 | ✅ | ✅ | — | M3-4 | |
| `&tlmm` | 2715 | 继承 `qcom,sm8750-tlmm` | `pinctrl/qcom,sm8750-tlmm.yaml` ✅ | `drivers/pinctrl/qcom/pinctrl-sm8750.c` ✅ | — | M3-2 | 全板 pinctrl 宿主 |
| `&uart14` | 3001 | 主体 `qcom,geni-uart`；子 `qcom,wcn7861-bt`（蓝牙） | geni: `tty/serial/qcom,geni-uart.yaml` ✅；BT ❌ 无 `wcn7861-bt`（上游用 `qcom,wcn7850-bt.yaml`） | geni: `drivers/tty/serial/qcom_geni_serial.c:2203` ✅；BT: `hci_qca.c:2781` of_match **无 wcn7861** ⇒ 需扩展 | hci_qca.c **diff=393 ✅复跑一致**；qcom,wcn7850-bt.yaml diff=3 | M3-6 / **M4（B3）** | PERI 固件下载协议为私有，先谈接口 |
| `&ufs_mem_phy` | 3027 | 继承 `qcom,sm8750-qmp-ufs-phy` | `phy/qcom,sc8280xp-qmp-ufs-phy.yaml` ✅ | `phy/qualcomm/phy-qcom-qmp-ufs.c` ✅ | — | M3-2 | |
| `&ufs_mem_hc` | 3034 | 继承 `qcom,sm8750-ufshc`, `qcom,ufshc`, `jedec,ufs-2.0` | `ufs/qcom,sm8650-ufshc.yaml` ✅ | `drivers/ufs/host/ufs-qcom.c`（`qcom,ufshc` 命中） | — | M3-2 | |
| `&usb` | 3045 | 继承 `qcom,sm8750-dwc3`, `qcom,snps-dwc3` | `usb/qcom,snps-dwc3.yaml` ✅ + M3-1 的 `snps,dwc3-common.yaml` 改动 | `drivers/usb/dwc3/dwc3-qcom.c` ✅ + M3-1 扩 `drd.c`/`core.c` | M3-1 已产 3 枚补丁（`patches/upstream/m3-2026-10-13/`）；driver-diff 未在本表重算（已就绪未发） | **M3-1**（本片不重复） | review 点名红点所在 |
| `&usb_dp_qmpphy` | 3080 | 继承 `qcom,sm8750-qmp-usb3-dp-phy` | `phy/qcom,sc8280xp-qmp-usb43dp-phy.yaml` ✅ | `phy/qualcomm/phy-qcom-qmp-combo.c` ✅ | — | M3-2 | |
| `&usb_dp_qmpphy_dp_in` | 3090 | （endpoint） | n/a | n/a | — | M3-2 | |
| `&usb_dp_qmpphy_out` | 3094 | （endpoint） | n/a | n/a | — | M3-2 | |
| `&usb_hsphy` | 3098 | 继承 `qcom,sm8750-m31-eusb2-phy` | `phy/qcom,m31-eusb2-phy.yaml` ✅ | `phy/qualcomm/phy-qcom-m31-eusb2.c` ✅ | — | M3-2 | |
| `&apps_smmu` | 3107 | 继承 `qcom,sm8750-smmu-500`, `qcom,smmu-500`, `arm,mmu-500` | `iommu/arm,smmu.yaml` ✅ | `drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c`（`qcom,smmu-500`/`arm,mmu-500` 命中） | — | M3-2 | |
| `&lpass_vamacro` | 3114 | 继承 `qcom,sm8750-lpass-va-macro`, `qcom,sm8550-lpass-va-macro` | `sound/qcom,lpass-va-macro.yaml` ✅ | `sound/soc/codecs/lpass-va-macro.c`（`qcom,sm8550-lpass-va-macro` 命中） | — | M3-3 | |
| `&swr1` | 3123 | 继承 `qcom,soundwire-v2.1.0`, `…v2.0.0`；子 `sdw20217010e00`（WCD9395 SDW codec） | `soundwire/qcom,soundwire.yaml` ✅；codec `sound/qcom,wcd939x-sdw.yaml` ✅ | controller `drivers/soundwire/`；codec `sound/soc/codecs/wcd939x-sdw.c` | — | M3-3 | |
| `&swr2` | 3134 | 同上 | ✅ | ✅ | — | M3-3 | |

**行数核对**：§2.2 共 **58** 行（每行一个 `&label`；`grep -c '^| \\`&' <本文件>` → 58），加 §2.1 的根块 15 个 compatible 子节点 ⇒ 覆盖 §1 的 59 个顶层块。

**跨节点观察**：
- 相机/无线两片（`&camss`、`&cci*_i2c0`、`&pcieport0`、`&uart14`、`/`wcn7861-pmu）是**唯一需要新驱动**的地带，其余 44 块是纯 enablement ⇒ M3-2 的目标应严格限定在"纯 enablement"，把新驱动推给 M3-5/M3-6。
- `&gpu`/`&gmu` 以及所有 7.2-era dtsi compatible 的"上游齐"结论，**以 pristine 7.3-rc7 为准时需先 rebase**（见 §5 未决问题 U1）。

## §3 M3-2 片补丁顺序草案

原则：**binding 先行 → 骨架 → 供电 → 总线条 → 人机接口**；每枚补丁 `dtbs` + `dt-validate` 0 诊断；英文 + `Signed-off-by`。仅覆盖 §2 归 M3-2 的"纯 enablement"节点，**不含**任何新驱动与实验项。

| # | 主题（subject 草案） | 涉及文件 | 依赖 | 为什么在这个位置 |
|---|---|---|---|---|
| **P1** | `dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4 tablet` | `Documentation/devicetree/bindings/arm/qcom.yaml`（sm8750 enum 加 `lenovo,elden`） | 无 | 没有它板 DTS 的 `compatible = "lenovo,elden"` 过不了 `dtbs_check`；且是**最小、独立**的提交 |
| **P2** | `arm64: dts: qcom: sm8750-lenovo-elden: add board skeleton` | 板 DTS（`model/compatible/chassis-type`、`fixed-clock`/`fixed-factor-clock`、`regulator-fixed`、`simple-framebuffer`、`reserved-memory`+`ramoops`）+ `arch/arm64/boot/dts/qcom/Makefile` | P1 | 后续所有补丁都在这份 DTS 上叠加，必须先落骨架 |
| **P3** | `arm64: dts: qcom: sm8750-lenovo-elden: enable PMIC regulators and GPIOs` | 板 DTS：`&apps_rsc`（pm8550/ve/vs 五路 regulator bank）、`&pm8550_gpios`/`&pm8550ve_gpios`/`&pm8550ve_f_gpios`、`&pm8550_flash`、`&pon_pwrkey`/`&pon_resin`、`&pmih0108_eusb2_repeater` | P2 | regulator 是其余外设的供电依赖，须早于消费它的节点 |
| **P4** | `arm64: dts: qcom: sm8750-lenovo-elden: enable storage, PCIe and I2C/spi buses` | 板 DTS：`&tlmm`、`&qupv3_1`/`&qupv3_2`、`&gpi_dma1`/`&gpi_dma2`、`&i2c0`(NFC)、`&i2c5`(fsa4480/ptn3222 mux)、`&i2c10`(aw99706 背光)、`&ufs_mem_phy`/`&ufs_mem_hc`、`&sdhc_2`、`&pcie0`/`&pcie0_phy` | P3 | 提供**最小可起根文件系统**（UFS）+ 通用总线，且不依赖显示/音频 |
| **P5** | `arm64: dts: qcom: sm8750-lenovo-elden: add PMIC glink, Type-C connectors and keys` | 板 DTS：`pmic-glink` 节点、两路 `usb-c-connector`、`gpio-keys` | P3/P4 | 人机接口放最后；Type-C 与 **M3-1** 的 dwc3 段共用 `&usb`/`connector`，靠后可与 M3-1 合并或紧随其后 |
| **P6（可选）** | `arm64: dts: qcom: sm8750: add qcom,non-secure-domain to ADSP fastrpc` | `arch/arm64/boot/dts/qcom/sm8750.dtsi`（一行属性） | 独立 | 见 §5 U3：SoC 文件改动单独一枚更合规；ADSP enablement（`&remoteproc_adsp`/`&remoteproc_cdsp`）可随 P4/P5 或并入 M3-3 |

**M3-2 明确不包含**（留给各自片）：`awinic,aw88461`(M3-3)、`csot/novatek` 面板 + `nt36536-ts` 触屏(M3-4)、`camss`+`s5kjns/gc08a8/gt9764/wl2868c`(M3-5)、`ath12k PEACH`+`wcn7861-pmu/bt`(M3-6)、`aw86937` 触觉(未列片)、`&usb` dwc3(M3-1 已产)。

## §4 验证证据（本次实测）

工作树 = `build/m1-upstream/clean-tree`（分支 `m1/clean-tree`，tip `c73ff25222`）。

**1) 编译 DTB**（源文件 `touch` 后强制重建，捕获 `DTC` 行）：
```
$ cd build/m1-upstream/clean-tree
$ touch arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
$ make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs
MAKE_RC=0
  DTC     arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
```
→ rc=0，无 `warning`/`error`（`grep -iE 'warning|error' /tmp/m32-dtbs2.log` 无输出）。产物 `sm8750-lenovo-elden.dtb` = 149 236 B。

**2) schema 校验（本系列自带 binding，§0 硬门）**：
```
$ export PATH=/home/xuqianhui1001/venv-dtschema/bin:$PATH
$ dt-validate -s Documentation/devicetree/bindings \
      arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
RC=0
$ wc -l <（诊断输出）
0
```
→ **0 诊断**，与 `m3-series-plan-20261013.md` §1 的实测一致。

**3) 上游支持面判定命令（§2 全表复用此三步，已逐 compatible 执行）**：
```
R=/home/xuqianhui1001/y700-elden/geekidos-linux ; P=24a19b953e
git -C $R grep -lF -e '<compat>' $P -- Documentation/devicetree/bindings   # binding
git -C $R grep -lF -e '<compat>' $P -- drivers/ sound/                     # 驱动命中
git -C $R show $P:<driver> | grep -n -A8 'of_device_id\|_of_match\[\]'    # 必须回落到表
```
逐文件 payload 规模：`git -C $R show $P:<path> | diff -u - <clean-tree>/<path> | grep -c '^[+-][^+-]'`。



## §5 产物清单 + 验证命令 + 未决问题

### 5.1 产物（绝对路径清单）

| 产物 | 路径 | 说明 |
|---|---|---|
| 本报告（唯一交付） | `/home/xuqianhui1001/y700-elden/reports/m3-2-board-basics-split-20261013.md` | 重写原空骨架；§1–§5 |
| 输入（只读） | `/home/xuqianhui1001/y700-elden/reports/m3-missing-support-matrix-20261013.md` | 缺口矩阵 |
| 输入（只读） | `/home/xuqianhui1001/y700-elden/reports/m3-series-plan-20261013.md` | M3 分片与验收口径 |
| 输入（只读） | `/home/xuqianhui1001/y700-elden/build/m1-upstream/clean-tree/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` | 板 DTS（59 个顶层块） |
| 参照 | `/home/xuqianhui1001/y700-elden/geekidos-linux` @ `24a19b953e` | pristine（7.3-rc7） |
| 临时证据 | `/tmp/m32-dtbs2.log`、`/tmp/m32-dtv.log` | make / dt-validate 原始输出（非交付） |

### 5.2 各条结论的验证命令

| 结论 | 验证命令 |
|---|---|
| 顶层块 = root + 58 `&label` = 59 | `grep -n '^&[a-z_0-9]*\|^/ {' build/m1-upstream/clean-tree/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` |
| §2 台账行数 = 58 | `grep -c '^| .&' reports/m3-2-board-basics-split-20261013.md` |
| 上游 binding（逐 compatible） | `git -C geekidos-linux grep -lF -e '<compat>' 24a19b953e -- Documentation/devicetree/bindings` |
| 上游驱动（**必须查 of_device_id**） | `git -C geekidos-linux show 24a19b953e:<driver> \| grep -n -A8 'of_device_id\|_of_match\[\]'` |
| payload 逐文件规模 | `git -C geekidos-linux show 24a19b953e:<path> \| diff -u - build/m1-upstream/clean-tree/<path> \| grep -c '^[+-][^+-]'` |
| 基线口径（7.2 vs 7.3-rc7） | `head -4 build/m1-upstream/clean-tree/Makefile` vs `git -C geekidos-linux show 24a19b953e:Makefile \| head -4`；`git -C geekidos-linux merge-base 24a19b953e c73ff25222`（空）；`ls geekidos-linux/.git/shallow` |
| 编译 | `cd build/m1-upstream/clean-tree && make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs` |
| schema | `cd build/m1-upstream/clean-tree && PATH=/home/xuqianhui1001/venv-dtschema/bin:$PATH dt-validate -s Documentation/devicetree/bindings arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb` |

### 5.3 未决问题

- **U1 基线口径（阻塞级）**：payload 树基座 = **Linux 7.2.0**，pristine = **7.3-rc7**，二者不同谱系 ⇒ 本报告"上游齐/驱动 of_device_id"结论对 7.2-era dtsi compatible 有效，但**7.2→7.3 有演进的文件**（`sm8750.dtsi`、`arm/qcom.yaml`、`a6xx_gmu.c`、`sc8280xp.c` 等）必须先 rebase 再定论。需父 agent 裁决：M3 系列是"在 7.2 基座上评审"还是"先 rebase 到 7.3-rc7"。
- **U2 `&gpu`/`&gmu` 的上游状态**：pristine 7.3-rc7 的 `sm8750.dtsi` **无** `gpu@3d00000` 节点，且 `qcom,adreno-44050000`/`qcom,adreno-gmu-830.1` 在 pristine 无任何命中。是 7.3-rc7 尚未合入、还是该节点/驱动为 elden payload 自造？（`git -C geekidos-linux grep -n '44050000' 24a19b953e` 仅命中无关 dsa yaml）
- **U3 `sm8750.dtsi` 改动的归片**：`qcom,non-secure-domain`（ADSP fastrpc，commit c73ff25222）属 SoC 文件，建议单独一枚，但归 M3-2 还是 M3-3（ADSP 是音频前置）待定。
- **U4 M3-1/M3-2 在 `&usb`/`usb-c-connector`/`&i2c5` 的边界**：M3-1 已产 USB mux 段；本片 P5 的 Type-C connector 与 `&i2c5`(fsa4480/ptn3222) 是否并入 M3-1 序列，需与 `patches/upstream/m3-2026-10-13/README.md` 对齐，避免两片抢同一节点。
- **U5 缺口矩阵建议修订**（提请父 agent，矩阵为其专属）：① 补 `st,st21nfca-i2c`（上游齐，M3-2）；② `awinic,aw86927` 应记为 `awinic,aw86937`；③ 面板行注明"驱动 `of_device_id` 匹配 `csot,pp8807hb1-1`，`novatek,nt36536` 仅为 binding 第二 const"；④ 逐文件 diff 数字加"含 7.2→7.3 漂移"脚注。
- **U6 `&i2c10` 与 `&spi4` 的双归片**：一个块内两个 compatible 归不同片（wl2868c→M3-5 / aw99706→M3-2；geni-spi→M3-2 / nt36536-ts→M3-4），拆片时需按子节点而非按块切。

---

### 产物绝对路径清单

1. `/home/xuqianhui1001/y700-elden/reports/m3-2-board-basics-split-20261013.md`（本报告）

（本轮 mission 明确"唯一可写产物 = 本文件"，未创建/修改任何其它仓库文件；`/tmp/m32-*.log` 为过程日志，非交付。）
