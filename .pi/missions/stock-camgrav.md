# 任务：拆解原厂 ZUXOS 未处理驱动 —— 相机 + 重力计(加速度计)

你是 y700-elden（联想 Y700 四代 TB322FC / SM8750）主线 Linux 项目的驱动分析员。工作目录 `~/y700-elden`。先读 `INDEX.md`、`STOCK-DRIVERS-2026-09-30.md`、`STOCK-KERNEL-2026-09-30.md`。

## 已有资产（先用这些，别重复下载）
- `stock-src/android_kernel_lenovo_sm8750-modules/qcom/opensource/camera-kernel`（厂商相机驱动源码）
- `stock-src/android_kernel_lenovo_sm8750`（sparse 内核树；`git sparse-checkout add <dir>` 可加路径）
- `backup/stock-elden/elden.dts`（厂商设备树）、`backup/fw/`、`~/下载/tb322fc/`（EDL 全量包）
- `stock-src/audioreach-topology`、`stock-src/vendor-audio`
- 联想 `lenovo-basements/*` 仓库（`gh` 已登录，代理 127.0.0.1:7897）

## 目标
对**相机**与**重力计/加速度计**两个模块做静态拆解 + 只读上机核对，产出主线移植评估。

### 相机
- 从 DT/固件/源码确认：**具体 sensor 型号**（如 XX5025 等）、CSI/CSIPHY/CAMSS 连接、供电与时钟。
- 评估主线 `drivers/media/platform/qcom/camss` 对 SM8750 的支持程度（现实是高度不成熟），给出"能不能/要多少工作量"的结论。

### 重力计/加速度计
- 从 DT/固件确认 **具体 chip**（Bosch BMI 系列 / ST / 其它）与 I2C/SPI 拓扑、中断、供电。
- 查主线 **IIO** 驱动是否已支持（`drivers/iio/imu`），若无则评估移植厂商驱动或写最小 IIO 驱动的工作量。
- 重力计通常比相机容易得多，优先给出**可落地的移植步骤**。

## 上机（只读，勿刷机/重启）
设备在线：`ssh root@192.168.7.1`。用只读命令采集：`dmesg`、`lsmod`、`ls /proc/device-tree`、`find /sys/bus/i2c /sys/bus/spi`、`cat /proc/config.gz | zcat | grep -i iio\|camera`。不要修改设备。

## 交付物
- 文档 `STOCK-CAMERA-GRAVITY-2026-10-02.md`（写在 `~/y700-elden/`）：
  - 两模块各自的 **器件识别表**（型号/总线/供电/中断 + 证据路径）
  - 主线支持现状 + **移植方案与工作量估计**
  - 一份可复用的**只读探测脚本**（放 `scripts/`），输出设备当前相关硬件/驱动状态
- 结论写入 `task progress` / `task done`，完成后 `task done` 退出。

## 约束
- 静态分析为主；设备只读。不要动 `/data`、不要刷写。
- 结论必须有文件/命令证据（路径、行号、输出片段）。
