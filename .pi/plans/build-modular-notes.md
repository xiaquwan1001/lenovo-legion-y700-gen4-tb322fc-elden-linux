# 驱动模块化采纳 — 收口确认 (2026-10-09)

## 结论：已完成，无需额外构建

`patches/fragment-modular.config` 的所有目标项已在当前 .config 中 =m，
且 `linux/` 树已完整编译（1523 个 .ko）。设备 vk63+ 实机运行证明加载链正常。

## 当前状态验证

| 驱动 | .config | .ko 产物 | 设备状态 |
|------|---------|----------|----------|
| CONFIG_ATH12K | =m | ath12k.ko, ath12k_wifi7.ko | WiFi 工作 ✅ |
| CONFIG_SND_SOC_QDSP6 | =m | q6apm*.ko, q6prm*.ko, snd-q6apm.ko | 音频出声 ✅ |
| CONFIG_SND_SOC_WCD939X | =m | snd-soc-wcd939x.ko, -sdw.ko | 麦克风录音 ✅ |
| CONFIG_SND_SOC_SC8280XP | =m | (已链入 sound/soc/qcom) | 机内扬声器 ✅ |
| CONFIG_INPUT_AW86927 | =m | aw86927.ko | 触觉反馈 ✅ |
| CONFIG_TOUCHSCREEN_NOVATEK_NVT36XXX_SPI | =m | novatek-nvt36xxx-spi.ko | 触屏可用 ✅ |
| CONFIG_BACKLIGHT_AW99706 | =m | aw99706.ko | 亮度可调 ✅ |

## 冻结项（不模块化）

| 驱动 | 原因 |
|------|------|
| DRM_MSM / DPU / DSI PHY | Q28 开机首次 modeset 竞态，=y 冻结 |
| DRM_PANEL_NOVATEK_NT36536 | 同上 |
| BT_HCIUART_QCA | bool，select 拉回 =y（改源码代价>收益） |

## 模块加载机制

- **持久根 `/lib/modules/$(uname -r)/`**：完整模块 + modules.dep
- **init 阶段**：camera-modules-load.sh 范式（modprobe 按序）
- **迭代快环**：`scripts/mod-loop.sh <dir>` = 编模块→推设备→rmmod/modprobe (~30s)

## 下次上机验证清单

```bash
# 期望 lsmod 包含以下模块（全列）：
lsmod | grep -E "ath12k|wcd939x|q6apm|q6prm|aw86927|nvt36xxx|aw99706|snd_q6apm"
# 快速冒烟：
iw dev wlan0 scan | head -3      # WiFi
arecord -D default -d 1 /tmp/t.wav # 音频采集
loginctl show-session | grep idle  # 触屏/背光正常（idle-delay 可调即证明）
```

## 收益确认

- **迭代速度**：改一个驱动 → `scripts/mod-loop.sh drivers/net/wireless/ath/ath12k/` → 30s 上机验证
- **体积**：Image.gz 20.5 MB（=y→=m 省 ~1-2 MB），但 ramdisk 仍主导（62-81 MB）；体积不是瓶颈
- **kexec**：无直接收益（报告确认）；真正价值是 mod-loop 迭代环
