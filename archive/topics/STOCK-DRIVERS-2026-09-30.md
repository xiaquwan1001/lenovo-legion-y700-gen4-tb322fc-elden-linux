# 联想 GPL 公开源码调查 — TB322FC (elden/SM8750) — 2026-09-30

> 关联：`STOCK-KERNEL-2026-09-30.md`（厂商 DT + haptic.ko 反汇编）、`AUDIO-scout-2026-09-30.md`、
> `ROADMAP-dep-2026-09-30.md`。入口 `INDEX.md`。
> 目的：把联想公开的 GPL 内核/模块源码拉全，作为 **音频 / 显示刷新率 / TF 卡** 等硬骨头的权威参考。

---

## 0. 一句话结论

联想 `lenovo-basements` 公开了 **SM8750 完整内核树 + vendor 模块源码**（含 QCOM AudioReach、display-drivers、
touch、wlan、sdhci-msm）。**但 AWINIC 的 aw88461/aw8693x 驱动源码未公开**（代码搜索 0 命中）；
不过**这些 AW 驱动我们主线树里已经有了**（`linux/sound/soc/codecs/aw88461.c` 等），
所以**音频的瓶颈不在 codec 驱动，而在 QCOM ADSP 侧的 tplg（AudioReach 拓扑）**，
公开源码能帮助我们理解 dailink/端口，但**拓扑二进制本身没公开**。

---

## 1. 已克隆到本地（`stock-src/`）

| 仓库 | 大小 | commit | 内容 | 用途 |
|---|---|---|---|---|
| `android_kernel_lenovo_sm8750-modules` | 349 MB | `e1f3246` (2025-11-09) | vendor 模块源码 | ★ QCOM AudioReach、display-drivers、touch、wlan、bt |
| `android_kernel_lenovo_sm8750` | 51 MB（sparse） | `210981a` (2025-11-09) | SM8750 内核树 | codec/机器驱动、`sdhci-msm.c`、`drm/msm/dsi` |

> sparse-checkout 只拉了：`sound/soc/codecs`、`sound/soc/qcom`、`drivers/mmc/host`、
> `drivers/gpu/drm/msm/dsi`、`drivers/gpu/drm/panel`、`arch/arm64/boot/dts/qcom`。
> 用 `--filter=blob:none` 克隆，需要别的路径再 `git sparse-checkout add <dir>`。

`lenovo-basements` 其他仓库（未拉）：`android_device_lenovo_elden-kernel`（90 MB 预编译，已采进
`backup/stock-elden/`）、`proprietary_vendor_lenovo_elden`（614 MB 固件）、`linux`（6.1 GB）。
仓库用 `gh`（token 已登录）查列表，代理 `127.0.0.1:7897`。

---

## 2. modules 仓：`qcom/opensource/` 模块全景

| 目录 | 与我们的关系 |
|---|---|
| **`audio-kernel/`** | ★ QCOM AudioReach：`asoc/`（machine、codec）、`dsp/`、`ipc/`；含 `asoc/pineapple.c`（SM8750=pineaaple machine 驱动）、`asoc/codecs/`（WSA/va/lpass 等） |
| **`display-drivers/`** | ★ `targets/pineapple.bzl`、`msm/dsi/`、`config/gki_pineappledisp*` —— DSI/PLL/DPU（B2 刷新率） |
| `touch-drivers/` | 触屏（已可用，备查） |
| `wlan/` | ath12k/peach（长稳排查参考） |
| `mm-drivers/` | 只有 `hw_fence` / `sync_fence` / `msm_ext_display`，**无 sdhci**（存储 host 在主内核树） |
| `bt-kernel/`, `camera-kernel/`, `graphics-kernel/`, `dsp-kernel/`, `video-driver/` | 备查 |

`qcom/opensource/audio-kernel/asoc/pineapple.c` = **SM8750 的 AudioReach machine 驱动**，
定义全部 dailink（wsa_dma / rx_dma / tx_dma / display_port / btfm / proxy 等）。
这是理解"要拼出什么 ALSA 拓扑"的关键参考，但**档位/后端要连到 aw88461 的 MI2S**，
仍对应 `AUDIO-scout` 的结论：tplg 需自建。

---

## 3. AWINIC 驱动：主线已有，公开仓反而缺

| 器件 | 我们主线树 | 联想公开仓 |
|---|---|---|
| **aw88461** smartpa（I2S 功放，PID `0x2308`） | ✅ `linux/sound/soc/codecs/aw88461.c`（+ aw88395/aw88261/aw88399/aw88166） | ❌ 未公开（主仓只有 `aw88261.c`、`aw88395/`，且 `aw88395` 仅认 chip id `0x2049`） |
| **aw8693x** haptic | ✅ 已由反汇编移植（`patches/0003-…`） | ❌ 未公开（`haptic.ko` 反汇编见 `STOCK-KERNEL`） |

→ **结论**：codec/haptic 驱动不是障碍；音频卡在 ADSP AudioReach 拓扑（tplg），
haptic 已解决。**不要**再去公开仓找 aw 驱动。

---

## 4. 显示：厂商权威时序（B2 刷新率）

`backup/stock-elden/elden.dts` 里厂商 panel 节点
`qcom,mdss_dsi_elden_nt36523_csot_3k_dsc_vid` 含**per-rate timing-switch command**
（`qcom,mdss-dsi-timing-switch-command`）+ 各自 `qcom,mdss-dsi-panel-clockrate`：

- 出现的 framerate（全 DT 统计）：**120（29 处）、90（13）、60（28）、40、30、24**；
  另有 144/180/240 出现在**其它通用节点**（vtdr 等），**165 未在厂商 DT 出现**。
- 即厂商的 elden 面板只枚举了 **120 主刷 + 90/60/40/30 低刷**（动态 fps）。
- 上游 165 Hz 实验（`Y700-elden-linux/experiments/165hz-mode-table.patch`）明确
  **165/144/90 切换会 DSI FIFO 错误风暴，仅 120 验证通过** → B2 的希望在 **DSI/CPHY PLL 与
  per-mode DCS 序列**，可参考 `display-drivers/msm/dsi` + `targets/pineapple.bzl`。

---

## 5. 存储：TF 卡（C2）有了权威对照

vendor `android_kernel_lenovo_sm8750/drivers/mmc/host/sdhci-msm.c`（156 KB）已拉到本地。
我们主线 TF 卡的问题是 **flush/cache 一致性（buffered 写读回损坏，带日志 ext4 挂不上）**，
**下一步可直接 diff** 厂商版 vs 主线版 `sdhci-msm.c`（尤其 DMA/cache/`cqhci` 路径），
定位差异是 C2 的最短路径。

---

## 6. 建议用途（按价值）

1. **C1 音频**：读 `pineapple.c` dailink → 确认 MI2S→aw88461 后端 → 自建 AudioReach tplg（真正的硬骨头）。
2. **C2 TF 卡**：diff `sdhci-msm.c`（vendor vs mainline）→ 找 flush/cache 差异，**高性价比**。
3. **B2 刷新率**：读 `display-drivers/msm/dsi` + 厂商 per-rate timing-switch，评估 DSI PLL 补丁。
4. WiFi 长稳 / 蓝牙：`wlan/`、`bt-kernel/` 备查。

> 复核方式：`stock-src/` 为 git 工作树，随时 `git log`/`diff`；换机重建见本文件 §1。
