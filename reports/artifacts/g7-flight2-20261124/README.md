# G7 dtfix flight-2 原始日志（2026-11-24）

来源：`ssl elden-root` 采集 + `fastboot boot out/g7-routeA-dtfix-20261123/boot-elden-g7a2.img`（零写盘）。
- `pre-snapshot.txt` / `vk189-baseline.txt`：上机前与回滚后的日常核 vk189 对照
- `post-boot.txt`：候选核起机后 `uname -r` / 根 / boot_id
- `criteria*.txt`：判据逐项采集（devlink、role switch、typec、udc、mux、gpio）
- `g7a2-dmesg.txt`：候选核完整 dmesg（42 条内核 WARN 的原文）
- `boot-cmd.txt`：fastboot 输出

⚠ 判读口径以 `reports/g7-routeA-dtfix-20261123.md` §7 为准（含 2026-11-24 的两次更正：
判据 1「=0」不可达 ⇒ 改「不高于基线」；42 条 WARN 归因于 DSI PLL 未锁）。
