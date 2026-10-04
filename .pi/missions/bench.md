# 任务：CPU / GPU 性能基准（GL vs Vulkan，多 API）——仍开放（TASKS G1-8 ⬜）

> 状态与进度的**唯一权威 = `TASKS.md` §1 行 G1-8**；本任务书只是派工背景。2026-10-04 现代化。

你是 y700-elden（联想 Y700 四代 TB322FC / SM8750 / Adreno A830 / 8 核 / Phosh Wayland / Alpine musl）项目的性能测试员。工作目录 `~/y700-elden`。宿主与设备均为 **Alpine(musl)**，GPU 走主线 `msm` + freedreno/Turnip（**Mesa 26.1.8 已在跑**）。

## 现状
- 设备 U2 = b 槽 vk47 持久直启，Phosh 自启，桌面图形栈可用（165 Hz）——**基准可直接在宿主 Wayland 上跑**。
- 温控分级 70/82/90/105 °C 已落地（passive 降频会介入，压测数据必须记录是否被温控限频；`scripts/thermal-watch.sh` 可同步采样）。
- 既有脚本：`scripts/bench-install.sh`（装依赖）、`scripts/bench-run.sh`（串跑）——先读再补，不重造。

## 目标
可复现的 **CPU + GPU 基准**，比较 **OpenGL ES vs Vulkan**，产出数据与结论。

### GPU（宿主 Phosh/Wayland，非容器）
`glmark2-es2-wayland` / `glmark2-wayland`、`vkmark`、`vulkaninfo`/`es2_info`；可选 `clpeak`、gfxbench。
### CPU / 内存
`sysbench cpu`、`openssl speed`、`7z b`、`stress-ng --cpu`、`mbw`/`tinymembench`。

## 方法
1. 只读盘点：`/proc/cpuinfo`、GPU 频率档、`uname -r`、`vulkaninfo --summary`。
2. 工具优先 `apk`（community/testing）；源码构建需记录步骤。
3. 每项：预热 1 次 + 正式 ≥3 次，记均值/方差；标注分辨率、插电、温度与温控触发情况。
4. 出表：GL vs Vulkan 差距 + 原因分析（驱动路径 / tiling / 频率策略 / 温控介入）。

## 交付物
- 证据文档 `archive/topics/BENCH-<YYYY-MM-DD>-subagent.md`：测试矩阵、原始数据、结论。
- 把可复跑逻辑补进 `scripts/bench-run.sh`（参数化），不新开根目录文档。

## 纪律（2026-10-04 约定）
- 压测占设备且发热：开始前 `scripts/device-lock.sh --status` 确认空闲，压测全程持锁（`scripts/device-lock.sh <cmd>` 包一层）；不刷 boot、不重启内核。
- 一条命令只做一件事；轮询自带 `timeout` 自限，SSH 禁长 sleep（后台 `nohup ... &` + 短命令轮询）。
- 温控红线：稳态温度贴近 90 °C 未降频时主动停测并记录。
- 最终回复即交付物（结论+命令+原始日志）；**不改 `TASKS.md`**，编排者独立复跑后更新。
