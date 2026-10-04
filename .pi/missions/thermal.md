# 任务：温控（已收官，墓碑+残余）

> 状态与进度的**唯一权威 = `TASKS.md` / `DEVICE.md` §1.3**。2026-10-04 现代化。

**主线不再执行。** 2026-10-02~03 已实机落地：passive 分级 **70/82/90/105 °C** + cooling-maps 递增 state + 用户态监控 `scripts/thermal-watch.sh`（另有压测脚本 `scripts/thermal-stress.sh`）。全文：`archive/topics/THERMAL-2026-10-02.md`。

## 残余（低优先，被派到时才做）
1. 其余热点（DDR / 电池 / 充电 / modem / aoss 热区）是否需补 passive trip——只读盘点后给增量 DTS 建议。
2. GPU 热区分级限频的实测复核（`devfreq-3d00000.gpu` cdev 曲线）。

## 纪律（2026-10-04 约定）
- 压测占设备且发热：全程持 `scripts/device-lock.sh` 锁；一条命令只做一件事；轮询自带 `timeout`。
- 改动走 `scripts/iterate.sh`（DTS → `dtb` 环）；最终回复即交付物；**不改 `TASKS.md`**；证据追加 `archive/topics/thermal-<YYYY-MM-DD>-subagent.md`。
