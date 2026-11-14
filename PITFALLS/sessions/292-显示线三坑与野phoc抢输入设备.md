# 292 — 显示线三坑：`wlr-randr --mode` 静默无效、空闲时 vblank IRQ 为 0、自己起 `phoc` 会抢 `/dev/input/event0`

## #655 同分辨率多模式时 `wlr-randr --mode` 会**静默按首选模式生效**（本机 8 个 1904x3040@165/144/120/90/60/40/30/24）

- **现象（2026-11-14 实测）**：`wlr-randr --output DSI-1 --mode 1904x3040@60Hz` 与 `--mode "1904x3040@60.000000Hz"` 都
  **返回 rc=0**，`wlr-randr --json` 也一度看不出变化，phoc 日志仍是 `Modesetting with 1904x3040 @ 165.000 Hz`。
- **原因**：8 个模式的 W×H 完全相同，输出管理协议只按 W×H（加 refresh 匹配实现差异）匹配 ⇒ 命中首选（165 Hz）。
- **处置**：要真切刷新率必须用 **`wlr-randr --output DSI-1 --custom-mode 1904x3040@60Hz`**；
  验证用 `phoc` 日志 `[backend/drm/drm.c:980] connector DSI-1: Modesetting with … @ NN Hz`，不要只看 rc。
- **附带坑（同一轮踩到，浪费了判读时间）**：**空闲时 `msm` vblank IRQ 计数为 0**（无 pending commit 时 msm 会屏蔽 vsync）
  ⇒ **不能用 `/proc/interrupts` 判「当前刷新率/显示是否活着」**；要判刷新率必须制造连续 damage（例如背光来回切）。
  同理：屏幕静止时 `Atomic commit failed: Device or resource busy` 只在切模式/会话启动瞬间大量出现，属瞬态。

## #656 自己随手跑一个 `phoc -v` 会独占输入设备，让真会话收不到按键

- **现象**：查版本随手 `phoc -v`（root，非活动会话）后，**电源键从此无响应**：`logind` 有 `Power key pressed short.`，
  phosh/gsd 零动作；真会话的 phoc 一切正常（触摸、键鼠都在）。
- **机制**：libinput 打开 evdev 设备后 **EVIOCGRAB 独占**；野 phoc 的 fd 列表里 `/dev/input/event{0,1,4,5}` 全在，
  电源键设备 `event0` 被它抓住，真会话的合成器拿不到 `KEY_POWER`。
- **判据**：`for p in $(ls /proc|grep -E '^[0-9]+$'); do readlink /proc/$p/fd/* ; done | grep input/event0`
  列出持有者；正常应只有 **1 个 phoc** + `seatd` + `systemd-logind`。多于 1 个 phoc = 有野合成器。
- **处置**：`kill -TERM <野 phoc>`（必要时 `-KILL`），再确认 `ps -eo comm | grep -cx phoc` = 1。
- **纪律**：查 phoc/phosh 版本用 `dpkg -l phoc` 或 `strings`，**不要启动二进制本身**；同理别在活动会话外起合成器。
