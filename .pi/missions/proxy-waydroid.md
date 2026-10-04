# 任务：Waydroid 容器网络/代理（已收官，墓碑+残余）

> 状态与进度的**唯一权威 = `TASKS.md` §2**（「容器代理通路」✅）。2026-10-04 现代化。

**主线不再执行。** 根因链（内核缺 `CONFIG_IP_ADVANCED_ROUTER`/`IP_MULTIPLE_TABLES` → netd 多路由表下发失败 → 容器无默认路由）与修复过程全在 `archive/topics/PROXY-WAYDROID-2026-10-02.md`；后续 Google 上行收口并入 `.pi/missions/gplay.md`（C2，阻塞在用户侧凭据/上行）。

## 若被派到本任务书，只做残余（先只读核实，勿重做历史）
1. 在当前内核（vk47+）上只读验证：容器默认路由与 per-network 路由是否由 netd 原生下发（config 是否已含 `IP_MULTIPLE_TABLES`），旧 workaround 是否仍需保留。
2. 结论（含 `ip rule`/`ip route` 原始输出）追加到 `archive/topics/proxy-waydroid-<YYYY-MM-DD>-subagent.md`，由编排者回写 `TASKS.md`。

## 纪律（2026-10-04 约定）
- 设备侧读操作走 `scripts/device-lock.sh`；一条命令只做一件事；SSH 禁长 sleep。
- 最终回复即交付物（命令+原始日志）；**不改 `TASKS.md`**。
