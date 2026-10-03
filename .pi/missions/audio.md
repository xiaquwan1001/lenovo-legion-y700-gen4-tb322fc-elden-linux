# 任务：打通音频出声 —— tplg 设备子图未注册（AudioReach / AW88461）

你是 y700-elden（联想 Y700 四代 TB322FC / SM8750）项目的音频内核工程师。工作目录 `~/y700-elden`。
**先完整读** `AUDIO-2026-10-01.md`、`AUDIO-2026-09-30.md`、`AUDIO-scout-2026-09-30.md`、`INDEX.md`。

## 已有进展（不要重做）
- GPR 源端口已修（APM=3/PRM=7，patch `patches/0005-*`）。
- APM 命令头已修（`alloc_apm_cmd_pkt`，patch `patches/0009-*`）：`GET_SPF_STATE` 有应答、共享内存 map 不再报错。
- 设备当前内核 **vk34**（`out/boot-elden-vk34.img`），声卡注册成功，`aplay -l` 有 MultiMedia1/2，但 `aplay -D hw:0,0` 仍 **EINVAL**。

## 当前阻塞（你的主攻方向）
DAPM 显示 **FE 子图已注册，但 tplg 的 I2S 设备子图未注册**：
```
MultiMedia1 Playback: ASoC: no valid Playback path
MultiMedia1 Playback: ASoC: found 0 new BE paths
no backend DAIs enabled for MultiMedia1 Playback
```
- `amixer -c0 controls` **没有** `SECONDARY_MI2S_RX Audio Mixer MultiMedia1`。
- tplg 二进制里**有** `SECONDARY_MI2S_RX` 等字符串 → 包没丢，是**加载/匹配**阶段被丢弃。
- 可疑点：tplg 设备子图的 DAI 名（`DEVICE_SG_ADD(..., 'SECONDARY_MI2S_RX')`）与内核 BE DAI 名（DTS `link-name = "Secondary MI2S"` → `Secondary MI2S Playback`）是否一致；`sound/soc/qcom/qdsp6/topology.c` 的 `audioreach_route_load` / mixer 控件创建；`subgraph-device-i2s-playback.m4` 的 `DEVICE_PLAYBACK_ROUTE`。

## 资产
- tplg 源：`scripts/audio-tplg/SM8750-Lenovo-Y700-Gen4.m4`；构建 `scripts/audio-tplg/build.sh`（m4 + alsatplg）。
- 上游参考：`stock-src/audioreach-topology/audioreach/subgraph-device-i2s-playback.m4`、`util/mixer.m4`、`util/route.m4`、`Google-SC7180-WSA-Speakers-SEC-I2S-VA-DMIC-WCD-TX3.m4`（与我们的写法逐字对比）。
- 内核：`geekidos-linux/sound/soc/qcom/qdsp6/topology.c`、`q6apm-dai.c`、`q6apm-lpass-dais.c`；DTS `geekidos-linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`（sound 节点 ~488、aw88461 ~1400、q6apmbedai ~2000）。
- 厂商参考：`stock-src/android_kernel_lenovo_sm8750-modules/qcom/opensource/audio-kernel/asoc/pineapple.c`。
- 构建/刷写：`scripts/build-kernel.sh`、`scripts/build-boot.sh`、`scripts/flash-b.sh [img] --reboot`（写 boot_b，SSH 内完成，会重启设备）。

## 方法建议
1. **先只读复现**：`ssh root@192.168.7.1`，抓 `dmesg | grep -i -E "asoc|tplg|audioreach|apm|mi2s|mixer|dai"`、`amixer -c0 controls`、`cat /sys/kernel/debug/asoc/*/dapm/*`，确认哪些 widget 建了、哪些没建。
2. **对比上游**：本树 `topology.c` 与上游 v6.12/master、以及 blu-sharky/linux-piano（SM8750 已出声）的差异；重点看 tplg widget/route 加载与 BE 名匹配。
3. 用 **ftrace/dynamic_debug**（debug 内核 vk20 能力可用）追 tplg 加载，定位被丢弃的具体 widget。
4. 定位后改 tplg（m4）/内核 patch，**小步验证**：先只改 tplg 重刷固件文件（不必重刷内核），再改内核。

## 设备纪律（重要）
- 设备被 Google Play（task-5）等任务共享。**任何 `flash-b.sh --reboot` 前先 `send SageYak` 报告并等待确认**，避免打断别人。
- SSH 不要长 `sleep`；后台任务用 `nohup ... &`，再短命令轮询。
- 改内核前备份当前 `.config` 与旧 boot.img。

## 交付物
- 文档 `AUDIO-2026-10-02.md`：根因证据链、patch/tplg 改动、验证结果（`aplay` 出声日志）、回退镜像。
- 结论与证据写入 `task progress` / `task done`；完成后 `task done` 退出。
