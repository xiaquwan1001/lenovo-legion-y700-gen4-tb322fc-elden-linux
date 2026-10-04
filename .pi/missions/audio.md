# 任务：音频残余包（R1 有线耳麦 / R2 双麦 / UI 收尾）

> 状态与进度的**唯一权威 = `TASKS.md` §1 行 G1-4**；本任务书只是派工背景。2026-10-04 现代化。

你是 y700-elden（联想 Y700 四代 TB322FC / SM8750 / AudioReach）的音频内核工程师。工作目录 `~/y700-elden`。

## 现状（已完成，勿重做）
主任务线**已收官**：播放 ✅（vk43 听声，根因=tplg MI2S SD 线 SD0→SD1）、采集 ✅（WCD939x AMIC1 模拟麦 + UCM2）、裸 ALSA 默认 ✅（R3，`scripts/audio-alsa-init.sh`，保守增益 400）。桌面 PipeWire/UCM2 就绪。
证据链：`archive/topics/AUDIO-SDLINE-2026-10-04.md`、`WCD939X-2026-10-04.md`、`AUDIO-INPUT-2026-10-04.md`、`MIC-ARRAY-2026-10-04.md`、`HEADSET-HW-2026-10-04.md`。

## 残余工作（按价值排序，均需用户确认后才开工）
1. **R1 有线耳麦听声验收——进度冻结在硬件**：本机无 3.5mm，需 USB-C 模拟耳机/转接头（用户采购）。代码侧前置：本机 USB-C 模拟开关 = **FSA4480**（`&i2c5` typec-mux@42/43，已启用），驱动 `CONFIG_TYPEC_MUX_FSA4480=m` 在 RAM 启动不可用 → 需 built-in 或补匹配模块。RX 播放子图/路由已就绪（vk48 验证控件全部出现）。
2. **R2 双麦双路采集（低价值可选）**：本机 AMIC1+AMIC4 双麦阵列，Linux 现单路 AMIC1。
3. UI 层小项：UCM2 设备切换的边角（`wpctl` 已见 Source）。

## 先读（顺序）
`TASKS.md` §1 G1-4 → `INDEX.md` §3 → 上列 `archive/topics/AUDIO-*` 与 `HEADSET-HW-2026-10-04.md`。

## 资产
- tplg：`scripts/audio-tplg/`（m4 源 + `build.sh`，m4+alsatplg）；UCM2：`scripts/audio-ucm/`。
- 内核补丁：`patches/0011-*` 及更早音频补丁；DTS `linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`。
- 设备：U2 = b 槽 vk47 持久直启（Phosh），最新镜像 vk49；`ssh root@192.168.7.1`。
- 快环：音频驱动现为 `=y`，首次需一次性 `scripts/apply-kernel-fragment.sh patches/fragment-modular.config` + 全量构建，之后 `scripts/iterate.sh mod sound/soc/...` 走 30s 环。

## 纪律（2026-10-04 约定）
- 设备是串行资源：写操作一律走自锁脚本（`mod-loop`/`kexec-boot`/`to-fastboot`/`flash-b`/`cycle` 已自动 flock），或包 `scripts/device-lock.sh <cmd>`；`--status` 查占用。
- 一条命令只做一件事：副作用（reboot/刷写/fastboot boot）与长轮询**不同条命令**（`AUDIT3` 教训）；轮询自带 `timeout` 自限。
- 迭代统一 `scripts/iterate.sh`（mod/dtb/kernel/ram）；内核树内**绝不** `make olddefconfig`（会删 `CONFIG_ARCH_QCOM`）。
- 最终回复即交付物：结论 + 命令 + 原始日志。**不要改 `TASKS.md`**（编排者独立复跑后更新）；专题证据追加到 `archive/topics/<主题>-<YYYY-MM-DD>-subagent.md`（只增不改），不落根目录。
- 放音测试前先把音量调低（用户要求；裸 ALSA 满增益 1023 过响，脚本默认 400）。
- 有失联风险、超出任务书、涉及采购/凭据决策 → 停下上报。
