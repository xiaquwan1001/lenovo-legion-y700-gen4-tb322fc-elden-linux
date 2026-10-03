# 任务：SM8750 温控（thermal）—— trip 重标定 + GPU cooling + 监控守护

你是 y700-elden 的温控/电源管理工程师。工作目录 `~/y700-elden`。**先读** `INDEX.md`、`SWARM-PLAN-2026-10-02.md`。

## 背景（已实测，别重复走弯路）
- 设备 SM8750（TB322FC/elden）跑主线 Linux。**2026-10-02 实测**：Waydroid GAPPS 冷启爆发时 CPU 热区冲到 **93–103°C**、load avg 52，表面烫手；限频后立刻回落到 42–44°C。
- 主线 DTS `geekidos-linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` **已有** `thermal-zones`：每个 CPU 热区一个 `passive` trip = **105000 (105°C)**、hysteresis 5000，`cooling-maps` 绑定 `&cpu0`/`&cpu6`（cpufreq-dt cooling device）。
- 运行时确认：`/sys/class/thermal/thermal_zone1/cdev0 -> cpufreq-cpu0`，每 CPU/GPU 热区 3 个 cdev 链接；`critical`=125°C、`hot`=120°C。
- 问题：**passive 只在 105°C 触发**（贴 SoC Tj 上限），几乎不降温；GPU 热区是否绑定 `devfreq-3d00000.gpu` 待核实；缺少用户态监控。

## 目标
1. **重标定 trip 点**：分级降温且不过度伤性能。建议：
   - 在每个相关热区增加 2–3 个 passive trip（如 70000 轻度 / 82000 中度 / 90000 重度），对应的 `cooling-maps` 用**递增的 cooling-device state**（不要全用 `THERMAL_NO_LIMIT`）：例如轻度限到 per-cluster 的 ~70% 最高频、中度 ~50%、重度 ~35%。
   - 保留 `critical`=125°C、`hot`=120°C 不动。
   - 具体温度/状态以**压测实测曲线**回填（见验证），并把“性能损失可接受”作为约束（目标：持续 10 min 压测下 CPU 稳态温度 ≤ 90–95°C，频率不出现剧烈抖动）。
2. **GPU cooling**：核实 `gpuss*-thermal` 是否绑定 `devfreq-3d00000.gpu`（type `devfreq-3d00000.gpu`）；若未绑定则补 `cooling-maps`，分级限 GPU 频。
3. **其余热点**：DDR / 电池 / 充电 / modem / aoss 等，评估是否需要在 comfort 场景降温（至少加 passive trip 或纳入监控）。
4. **用户态监控守护**：写 `scripts/thermal-watch.sh`——周期采样各 `thermal_zone*/temp` + `cpufreq` 当前频点/限频状态，打印/落日志，超阈值告警（可选自动写入临时 `scaling_max_freq` 兜底）。开机可启（做成 `/init` 钩子或独立服务，先给出手动运行方式即可）。

## 方法
1. 只读盘点：`for z in /sys/class/thermal/thermal_zone*; do ...; done`，记录 type/temp/trip/cdev。
2. 读 DTS 现有 thermal 段与 `sm8750.dtsi` 的 `thermal-zones` 基座，确认 label（`&cpu0`/`&cpu6`/GPU）。
3. 改 DTS → `scripts/build-kernel.sh`（ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-，**勿直接在树里跑 make**）→ `scripts/build-boot.sh` → `scripts/flash-b.sh out/boot-elden-vkNN.img --reboot`。
4. **压测验证**：设备上装/用 `stress-ng`（或 `dd`/`sha256sum` 多进程 + GPU 负载），跑 5–10 min：
   - `watch -n1 'grep . /sys/class/thermal/thermal_zone*/temp'`（脚本化采样）。
   - 记录温度峰值、触发降频的温度点、频率曲线、稳态温度。
5. 产出 `THERMAL-2026-10-02.md`：现状表、改动（patch 路径）、压测曲线（文字/表格）、回退镜像、遗留（如缺电池/充电温区）。

## 设备纪律
- 本任务**要刷 boot**，属设备写操作。刷写/重启前 `send SageYak` 报备，等确认（音频 task-8 可能也在刷）。
- 压测会占满 CPU/GPU 且发热——**压测前先 `send SageYak` 报备**，避免叠加 Waydroid/Box64 负载导致过热。
- 保留当前可回退镜像（设备现为音频修复后的 vk35/更高）。SSH 禁长 sleep，后台 `nohup ... &` 后短命令轮询。

## 交付物
- DTS patch（`patches/`）+ boot 镜像 + `THERMAL-2026-10-02.md` + `scripts/thermal-watch.sh`。
- 结论与数据写 `task progress` / `task done`。
