# 任务（续）：音频出声 —— 打通 APM_CMD_GRAPH_OPEN（AudioReach 上游同步）

你是 y700-elden 的音频内核工程师。**先读** `AUDIO-2026-10-02.md`（上一轮成果）、`AUDIO-2026-10-01.md`、`SWARM-PLAN-2026-10-02.md`。

## 上一轮已完成（不要重做）
- tplg 设备子图已注册（vk35）：`amixer -c0 controls` 有 `SECONDARY_MI2S_RX Audio Mixer MultiMedia1/2`；`aplay -l` 有 MM1/2。根因=冷启加载了 ramdisk 里的 MTP 占位 tplg；修复=自定义 tplg 打进 ramdisk。

## 当前阻塞（本轮主攻）
打开 PCM 时 **ADSP 拒绝 `APM_CMD_GRAPH_OPEN`（status=1）**，仍无声。
上一轮判断：需同步上游 AudioReach 提交（参考 `blu-sharky/linux-piano` **PR #16 的 ~43 个 AudioReach upstream commit**：`topology-driven Audio IF support`、`Zero-init module config` 等）。

## 方法
1. 先只读复现：`ssh root@192.168.7.1`，`dmesg | grep -iE "apm|graph|open|audioreach"`、`aplay -D hw:0,0` 抓完整错误。
2. 定位 `q6apm-audioreach` 的 graph open 报文/参数与上游差异（`geekidos-linux/sound/soc/qcom/qdsp6/`：`q6apm.c`、`q6apm-dai.c`、`audioreach.c`、`topology.c`）。
3. 用 `git log`/web 获取 `blu-sharky/linux-piano` 的相关 commit 或 PR #16 补丁，**有选择地 cherry-pick**（不整树替换），产出 `patches/00XX-*.patch`。
4. 小步验证：改内核 → `scripts/build-kernel.sh` + `scripts/build-boot.sh` → `scripts/flash-b.sh out/boot-elden-vkNN.img --reboot` → 抓 `aplay` 是否出声。

## 设备纪律
- **本轮你拥有设备刷写优先权**。每次 `flash-b.sh --reboot` 前后各 `send SageYak` 报一句（"开始刷 vkNN / 刷完设备空闲"），以便协调其它任务。
- 保留可回退镜像（vk35 为已知良好基线）。

## 交付物
- 更新/新增 `AUDIO-2026-10-02.md`：graph_open 根因、cherry-pick 清单、验证（真实出声 `aplay` 日志）、回退镜像。
- 结论写 `task progress` / `task done`；完成即退出。

## 上一轮进度（2026-10-02 11:14，勿重做）
- vk35 冷启 `aplay -D hw:0,0` 仍 EINVAL；`dmesg`: `APM_CMD_GRAPH_OPEN(0x01001000) status=1 → q6apm_graph_open graph_id=0 "Could not allocate memory"`。
- 已 diff 本树 vs piano PR#16 的 `q6apm.c/audioreach.c/topology.c`：**GRAPH_OPEN 报文逐字节同构** → 「缺 43 commit」不是本层根因。
- 已解压 ramdisk 里 MTP 占位 tplg（1526B→29264B 真实 SM8750-MTP 拓扑）与我们的 tplg 反编译对比：FE stream0 子图结构一致。
- **新线索**：自定义 tplg 的 **container capability 用了 legacy CD(0x2)**，原厂 SM8750-MTP 用新 CD；已刷 **vk37** 验证（设备 11:14 因刷机重启）。
- **接续**：跑 vk37 的 `aplay`/`dmesg`，确认 legacy CD 是否根因；否则抓 GRAPH_OPEN 完整报文与原厂逐字段对比。
