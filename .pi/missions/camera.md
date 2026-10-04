# 任务：相机出流（G1-5 下一轮）——仍开放（TASKS G1-5 🟡）

> 状态与进度的**唯一权威 = `TASKS.md` §1 行 G1-5**；本任务书只是派工背景。2026-10-04 现代化。

你是 y700-elden 的相机驱动工程师。工作目录 `~/y700-elden`。

## 现状（2026-10-04 实机复验 ✅，勿重做）
- vk49 起：20 相机模块全载（vermagic 匹配 + `depmod` 冷启自动加载已修好）、`/dev/media0` + 17 个 video 节点；sensor 全注册：**s5kjns 11-0056（4080×3072）/ gc08a8 12-0031（3264×2448）/ gt9764 / flash**；graph `gc08a8→csiphy4→csid0→vfe0_rdi0→video0` 已 ENABLED。
- **唯一剩余 ❌：实际出流** `v4l2-ctl --stream-mmap` → `Failed to start media pipeline: -32`。已知不匹配：csiphy 默认格式 `UYVY8_1X16` vs sensor `SRGGB10` → 需手工设 subdev 格式 / 链路启用 / 曝光与 3A 最小序列。
- 上一轮全记录：`archive/topics/CAMERA-2026-10-04-subagent.md`；拆解背景 `CAMERA-2026-10-02.md`、`STOCK-CAMERA-GRAVITY-2026-10-02.md`（同目录）。

## 主攻
1. 只读取证先行：`media-ctl -p` 全格式枚举、`v4l2-ctl --get-fmt` 逐级（sensor→csiphy→csid→vfe），把格式协商断点定位到具体 subdev pad。
2. 用 `media-ctl --set-v4l2` 强制 SRGGB10 全链一致后重试 `--stream-mmap`；区分「格式/使能顺序问题」与「时钟/供电/power-domain 缺失」两类根因。
3. 厂商参照：`stock-src/android_kernel_lenovo_sm8750-modules/qcom/opensource/camera-kernel`、`backup/stock-elden/elden.dts`（供电/时钟/GPIO 序列）。
4. 改动落 `patches/`；camss/sensor 已是 `=m` → 应用 fragment 后走 `scripts/iterate.sh mod drivers/media/...` 30s 环。

## 资产
`scripts/camera-modules-load.sh`（冷启加载）、`scripts/package-camera-modules.sh`、`rootfs/build-camera-overlay.sh`、`out/camera-modules-*.tar.gz`、DTS `linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`。设备 U2：vk47 持久直启，最新镜像 vk49。

## 纪律（2026-10-04 约定）
- 只读探测（dmesg / media-ctl / v4l2-ctl）随时可做；写操作走自锁脚本或 `scripts/device-lock.sh`。
- 一条命令只做一件事（副作用与轮询分开）；轮询自带 `timeout`。
- 迭代统一 `scripts/iterate.sh`；内核树内绝不 `make olddefconfig`。
- 最终回复即交付物（结论+命令+原始日志）；**不改 `TASKS.md`**；证据追加 `archive/topics/camera-<YYYY-MM-DD>-subagent.md`。
