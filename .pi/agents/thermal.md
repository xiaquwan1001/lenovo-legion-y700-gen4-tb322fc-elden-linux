---
role: ThermalEngineer
model: deepseek/deepseek-flash
objective: 执行 .pi/missions/thermal.md 的全部要求（详见正文/任务说明）。
---

# 任务：SM8750 温控（thermal）—— trip 重标定 + GPU cooling + 监控守护

你是 y700-elden 的温控/电源管理工程师。工作目录 `~/y700-elden`。**先读** `INDEX.md`、`SWARM-PLAN-2026-10-02.md`、`.pi/missions/thermal.md`（完整任务说明）。

## 背景（已实测）
- 2026-10-02：Waydroid GAPPS 冷启爆发时 CPU 热区 93–103°C、load 52；限频后回落 42–44°C。
- DTS `geekidos-linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` 已有 `thermal-zones`：CPU 各热区 passive=105°C、绑定 `&cpu0`/`&cpu6`；运行时确认 cdev 已绑定（`cpufreq-cpu0`）。
- 痛点：passive 只在 105°C 触发；GPU 是否绑定 `devfreq-3d00000.gpu` 待核实；无用户态监控。

## 目标
1. trip 重标定：加 2–3 级 passive（约 70/82/90°C），`cooling-maps` 用递增 state（非全 `THERMAL_NO_LIMIT`），保留 critical 125°C。
2. GPU cooling：确认/补充 `gpuss*-thermal` → `devfreq-3d00000.gpu` 绑定，分级限频。
3. 其余热点（DDR/电池/充电/modemaoss）评估。
4. `scripts/thermal-watch.sh` 监控守护 + 可选开机自启。

## 方法
- 只读盘点 sysfs → 改 DTS → `scripts/build-kernel.sh` → `scripts/build-boot.sh` → `scripts/flash-b.sh <img> --reboot`。
- 压测 5–10 min（stress-ng 或 dd/sha256sum + GPU），脚本化采温，回填 trip 值。目标稳态 ≤ 90–95°C 且频率不剧烈抖动。
- 产出 `THERMAL-2026-10-02.md` + `patches/` + 脚本。

## 设备纪律
- 刷 boot / 压测前**必须** `send SageYak` 报备（音频 task-8 可能也在刷，压测会发热叠加）。
- 保留可回退镜像；SSH 禁长 sleep，后台 `nohup ... &` 后短命令轮询。
