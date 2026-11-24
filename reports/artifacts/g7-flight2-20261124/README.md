# G7 dtfix flight-2 原始日志（2026-11-24）

来源：`ssl elden-root` 采集 + `fastboot boot out/g7-routeA-dtfix-20261123/boot-elden-g7a2.img`（零写盘）。
- `pre-snapshot.txt` / `vk189-baseline.txt`：上机前与回滚后的日常核 vk189 对照
- `post-boot.txt`：候选核起机后 `uname -r` / 根 / boot_id
- `criteria*.txt`：判据逐项采集（devlink、role switch、typec、udc、mux、gpio）
- `g7a2-dmesg.txt`：候选核完整 dmesg（42 条内核 WARN 的原文）
- `boot-cmd.txt`：fastboot 输出

⚠ 判读口径以 `reports/g7-routeA-dtfix-20261123.md` §7 为准（含 2026-11-24 的两次更正：
判据 1「=0」不可达 ⇒ 改「不高于基线」；42 条 WARN 归因于 DSI PLL 未锁）。

## 追加：2026-11-24 第二次上机（只为找判据 3 的观测面，零写盘）

同件再 boot 一次，读 GPIO29（mux 选择线）：
```
$ grep -E ' gpio29 ' /sys/kernel/debug/gpio
 gpio29  : out low  func0 2mA pull down      # = mux state 0
```
⇒ 判据 3 的判法 = 插拔前/后各读一次该行，`out low ↔ out high` 翻转即成。
`/sys/class/mux/muxchip0` 只有 device/of_node/power/uevent，**没有 `mux_state`**；`/sys/kernel/debug/mux/` 为空。
（`echo device > /sys/class/typec/port0/data_role` 可以强制切角色，但那样 `usb0` 上的 ssh 会断、恢复要人工断电 —— 不做。）
