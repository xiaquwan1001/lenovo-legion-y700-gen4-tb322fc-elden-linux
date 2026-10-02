# 任务：CPU / GPU 性能基准（多 API：OpenGL ES / Vulkan 等）

你是 y700-elden（联想 Y700 四代 TB322FC / SM8750 / Adreno 830 / 8 核 / Phosh Wayland / Alpine musl）项目的性能测试员。工作目录 `~/y700-elden`。先读 `INDEX.md`。宿主与设备均为 **Alpine(musl)**，GPU 用主线 `msm`+`freedreno`/Turnip Mesa。

## 目标
建立一套可复现的 **CPU + GPU 基准**，并**比较不同图形 API 下的表现**（至少 OpenGL ES vs Vulkan），产出数据与结论（驱动/内核性能分析）。

## 覆盖项
### GPU（宿主 Phosh/Wayland 上跑，非容器）
- **glmark2**（`glmark2-es2-wayland` / `glmark2-wayland`）
- **vkmark**（Vulkan）
- `vulkaninfo`、`es2_info`（能力/版本核对）
- 可选：`clpeak`（OpenCL）、`gfxbench`/`vulkan gpuinfo`
### CPU / 内存
- `sysbench cpu`、`openssl speed`、`7z b`、`stress-ng --cpu`、`mbw`/`tinymembench`（内存带宽）
- 可选：单核/多核/调度、温度与频率（`/sys/class/thermal`、`cpufreq`）记录

## 方法
1. 先设备只读盘点：`cat /proc/cpuinfo`、`cat /sys/class/kgsl/kgsl-3d0/*`、GPU 频率档、`uname -r`。
2. 需要的工具优先用 **apk 安装**（community/testing）；缺的用源码构建（记录步骤）。
3. 每个基准：**预热 1 次 + 正式跑 ≥3 次**，记录均值/方差；标注分辨率、是否全屏、温度与是否插电。
4. 数据写入表格，给出 **GL vs Vulkan 的差距**与可能原因（驱动路径、tiling、频率策略）。

## 交付物
- 文档 `BENCH-2026-10-02.md`：测试矩阵、原始数据、图表/表格、结论与建议。
- 一份可复跑的脚本 `scripts/gpu-bench.sh`（把安装+运行串起来，参数化）。
- 结论写入 `task progress` / `task done`；完成后 `task done` 退出。

## 设备纪律
- 压测会发热/耗电并**占用 GPU**；开始前先 `send SageYak` 报备，避免与音频刷 boot / Waydroid 安装冲突。
- 不要刷机/重启内核。SSH 禁长 sleep，后台任务 `nohup ... &` 后短命令轮询。
