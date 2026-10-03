# 技术报告：音频（播放/输入）+ 温控 + 桌面音频 —— 2026-10-04

> 本报告汇总 2026-10-04 一整天的工作。权威状态：`TASKS.md`（G1-4/G1-23）、`DEVICE.md`、`PITFALLS.md` #90/#91。
> 关联专题：`AUDIO-SDLINE-2026-10-04.md`（播放根因）。

---

## 0. 一句话结论

| 项 | 结论 |
|---|---|
| **音频播放** | ✅ **已出声**。根因不在内核，而在 **tplg 的 MI2S SD 数据线选错**（SD0 vs 硬件 SD1）。 |
| **桌面音频服务** | ✅ PipeWire + WirePlumber + UCM2 → 设置界面出现 **"Built-in Audio Speaker playback"**。 |
| **温控** | ✅ 四级热 trip（70/82/90/105 ℃）+ cdev 生效。 |
| **音频输入（麦克风）** | ❌ **未打通**。关键发现：**本机麦克风不是 DMIC，是模拟麦（AMIC）接在 WCD939x 上**；主线 DTS 未启用 WCD939x（需另做 bring-up）。 |
| **按键震动** | ◐ 硬件正常；根因是 feedback **profile='full'**（只映射 Sound），已设 **quiet**。 |
| **运行日志方法** | ✅ 新增 `scripts/devlogs.sh`。 |

---

## 1. 背景与目标

用户要求从"调查"转向"正确实现功能"，先把 **vk39 附近的两项改动（音频 + 温控）** 验证/落地，再做桌面音频与输入。

关键前提：**当前 vk41 内核里这两项都被 `elden/vk34-recon` 回退了**（为隔离"熄屏→重启"）。因此需要先干净重落。

---

## 2. 内核：vk42 ~ vk45

| 版本 | commit | 内容 | 验证 |
|---|---|---|---|
| vk42 | `eb432f18a` | 干净重落音频（`0009` APM cmd header + `0011` MI2S BE graph 在 prepare 启动）+ 温控（`0010` 四级 trip），**不带 vk40 DBG**，保留 vk41 PSCI | 温控 ✅ |
| vk43 | — | tplg **SD 线 SD0→SD1** 修正（见 §3）| **播放出声** ✅ |
| vk44 | `26cc186e9` | 加 DMIC 采集：`va-dai-link`（`VA_CODEC_DMA_TX_0`）+ VA macro DMIC pinmux + tplg 采集子图 | ALSA 出现 `MultiMedia3 Capture` |
| vk45 | `a923477be` | + `vdd-micb-supply` + `qcom,dmic-sample-rate` + `"VA DMICx","vdd-micb"` 路由 | DAPM/regulator 全 On，**但录音全 0**（见 §5）|

> 注：build 时工作树未提交 → uname 带 `-dirty`（`g26cc186e9485-dirty`），版本归属靠 commit 时间线。

---

## 3. 播放根因：tplg MI2S SD 数据线错（PITFALLS #90）

- 功放 I2S DIN 接在 **`gpio124 = i2s1_data1`（=SD1）**（主 DTS 与原厂 DT dump `probe/result/devicetree.dts:4636` 一致）。
- tplg 抄自 Google SC7180 模板，用 **`SD_LINE_IDX_I2S_SD0`** → ADSP 往 SD0/gpio122 发数据，功放挂在 SD1 收不到。
- **定位指标**：aw88461 的 **SYSST bit8 = SWITCHING**。无数据时 `0x0215`（SWITCHING=0），修好后 **`0x2315`**（=1）。
- 修复：`scripts/audio-tplg/...m4` 改 `SD_LINE_IDX_I2S_SD1`；tplg sha `db7e16e7…`。

---

## 4. 桌面音频服务（PipeWire + UCM2）

- `apk add pipewire pipewire-pulse pipewire-alsa wireplumber`（替换 pulseaudio）。
- 机器驱动无可用 port → ACP 只给 Dummy Output/Pro Audio。**必须写 UCM2**：
  - `scripts/audio-ucm/HiFi.conf`：`SectionVerb` + `SectionDevice."Speaker"`，`cset` 开 `SECONDARY_MI2S_RX Audio Mixer MultiMedia1` 并把功放音量抬到 1023；`PlaybackPCM "hw:${CardId},0"`。
  - `scripts/audio-ucm/install.sh`（`start-desktop.sh` 幂等调用）。
- PipeWire 由 `/etc/xdg/autostart/pipewire.desktop` 自启。
- 冷启实测：`Active Profile=HiFi`，sink = `HiFi__Speaker__sink`，GNOME 显示 "Built-in Audio Speaker playback"。

> **坑**：后来给 UCM 加了 `SectionDevice."Mic"`（为 DMIC 采集）→ **HiFi verb 整个消失**（只剩 off/pro-audio，扬声器 sink 丢失）。已撤回 Mic 段；重启后恢复正常。**UCM 加设备前务必验证 verb 仍可解析**。

---

## 5. 音频输入：结论是"硬件不是 DMIC"（PITFALLS #91）

### 5.1 我们做的（DMIC 方向）

- vk44：加 `va-dai-link`（cpu `VA_CODEC_DMA_TX_0`/110，codec `lpass_vamacro`）+ `&lpass_vamacro { pinctrl-0 = dmic01_default, dmic23_default }`；tplg 加采集子图（FE MultiMedia3 → VA codec-DMA TX0）。→ ALSA `arecord -l` 出现 `MultiMedia3 Capture`。
- vk45：补 `vdd-micb-supply = <&vreg_l1b_1p8>` + `qcom,dmic-sample-rate = <4800000>` + `audio-routing "VA DMIC0..3","vdd-micb"`。

### 5.2 现象（全绿但无声）

| 检查 | 结果 |
|---|---|
| ALSA | `arecord -D hw:0,2` 可录（**先要 `numid=15 MultiMedia3 Mixer VA_CODEC_DMA_TX_0=on`**，否则 open EINVAL）|
| APM/DAPM 图 | 全 On（`VA_CODEC_DMA_TX_0 Capture`、`device110.*`、`MultiMedia3 Mixer`、`VA DMIC0`、`VA DEC0 MUX`…）|
| VA macro 寄存器 | `084 = 0x1`（DMIC0 使能，clk_div=DIV2 = MCLK 9.6M/4.8M）——配置正确 |
| LPASS LPI pinmux | gpio6=dmic1_clk/gpio7=dmic1_data、gpio8/9=dmic2 —— 已 mux |
| 偏置 | vk45 后 `vdd-micb: On`、`vreg_l1b_1p8 state=enabled` |
| **录到的数据** | **peak 0 / 全通道（DMIC0–3）全 0** |

### 5.3 真正的根因（原厂设备树 `backup/stock-elden/elden.dts`）

原厂 `sound` 的 `qcom,audio-routing`（line 16249）**全是模拟麦，没有一条 "VA DMIC"**：

```
"AMIC1","Analog Mic1","AMIC1","MIC BIAS1" ... "AMIC5","MIC BIAS4"
"VA AMIC1","Analog Mic1","VA AMIC1","VA MIC BIAS1" ...
"VA SWR_INPUT","WCD_TX_OUTPUT"  "VA_AIF1 CAP","VA_SWR_CLK" ...
```

- 本机音频栈 = **Awinic smart PA（I2S，已打通）+ WCD939x 编解码器（SoundWire TX/RX）**。
- 麦克风 = **模拟麦**，偏置由 **WCD939x 的 MIC BIAS1–4** 提供，ADC 在 WCD，经 **SoundWire** 给 ADSP。
- **主线 DTS 未启用 WCD939x**（只有 I2S 的 aw88461），SWR master 也未启用。

⇒ vk44/vk45 的 DMIC 方向**软件对、硬件不对**：该机没有 DMIC 麦（原厂 routing 也没有），所以数据恒 0。

### 5.4 正确路线（未实施）

镜像主线 `sm8750-mtp.dts` 的 WCD939x 配置：
1. DTS：`wcd939x` 节点（SWR slave + `cdc-vdd-rx/tx/buck/px/mic-bias` 稳压 + reset GPIO + pinctrl）+ 启用 rx-macro/va-macro 的 SWR master。
2. `wcd-capture-dai-link`（cpu `TX_CODEC_DMA_TX_3`，codec `wcd939x`+`txmacro`）。
3. tplg 加 WCD 采集子图；UCM 加 Mic。
4. 稳压映射照原厂（`L15B`=WCD vdd、`BOB1`=mic-bias）。

**快速兜底**：USB/Type-C 或蓝牙麦（当前即可让"输入设备"不为空）。

---

## 6. 温控（vk42 验证）

- 所有 CPU/GPU 热区 trip = `120000 125000 70000 82000 90000 105000`（hot/critical + 四级 passive）。
- cdev：`cpufreq-cpu0` 0/15、`cpufreq-cpu6` 0/15、`devfreq-3d00000.gpu` 0/13；空闲 CPU 38–44 ℃。
- 对照 vk41：单级 `105000`。

---

## 7. 按键震动（haptics）

- **硬件正常**：`busctl --user call org.sigxcpu.Feedback … Haptic Vibrate "sa(du)" …` 返回 `b true`。
- 根因：feedbackd **profile = "full"**（schema 默认），默认主题里 `full` 只映射 Sound；**Vibra\* 只在 "quiet" profile**。
- 已修：`gsettings set org.sigxcpu.feedbackd profile quiet` + 重启 feedbackd。
- 想要"声音+震动分开/强度可调"：feedbackd 每个事件**只能一种类型**（Sound 或 Vibra）。要两者兼得需写自定义 device theme（如按键→Vibra、其它→Sound），并用 `max-haptic-strength` 调强度。

---

## 8. 运行日志方法：`scripts/devlogs.sh`

| 子命令 | 用途 |
|---|---|
| `pull [tag]` | 单次 SSH 抓快照（dmesg、`/run/*.log`、`/var/log/kmsg`、pstore、uname/boot_id/power）→ `logs/devlogs-<tag>-<ts>/` |
| `watch [秒] [间隔]` | 周期 pull + 靠 `boot_id` 变化标记复位 |
| `pstore` / `tail` / `serial` | ramoops 崩溃日志 / 实时 dmesg / 主机串口 |

---

## 9. 当前设备状态（报告时）

- 内核 **vk45**（`7.2.0-debug-g26cc186e9485-dirty`，含 DMIC 采集尝试 + 温控 + PSCI）。
- **播放**：✅ HiFi 扬声器 sink 正常（重启后已恢复）。
- **输入**：ALSA `MultiMedia3 Capture` 在，但录音全 0（硬件无 DMIC）→ 需 WCD939x。
- 提交：内核 `eb432f18a`/`26cc186e9`/`a923477be`；主线 `18bbf08`(devlogs) `31cde62`(tplg SD1) `9934f7b`(PipeWire+UCM) `34394bc`/`cddb1ca`/`d5c7e1a`(文档)。

## 10. 下一步（未开工）

1. **WCD939x bring-up**（麦克风/耳麦正路，§5.4）。
2. 或先做 USB/BT 麦兜底。
3. 自定义 feedback device theme（声音/震动分开 + 强度）。
4. 清理 vk44/vk45 的 DMIC 采集改动（在 WCD939x 落地时替换）。
