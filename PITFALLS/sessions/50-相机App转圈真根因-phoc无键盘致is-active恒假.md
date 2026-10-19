# §五十 相机 App 一直转圈的真根因：phoc 无键盘设备 ⇒ `wl_seat` 无 KEYBOARD 能力 ⇒ GTK `is-active` 恒为 false（#343）

> 2026-10-19 上午实测。**前置条件已全部满足**（portal 权限、`IsCameraPresent=true`、`OpenPipeWireRemote` 拿到 fd、
> pipewire 里两台相机都在），但 GNOME Snapshot 50 依然**永远转圈**。
> 一句话：**不是相机问题，是窗口焦点问题**；而焦点拿不到的原因在**输入设备缺失**，不在相机栈。

## 1. 链条（每一环都有实测）

```
phoc 的 seat 只有 libinput 的 touch/pointer，没有 keyboard
  ⇒ wl_seat.capabilities = 4 (只有 TOUCH；POINTER=2, KEYBOARD=1 都没有)   ← 实测
  ⇒ 客户端永远收不到 wl_keyboard.enter
  ⇒ GTK4 的 GtkWindow::is-active 恒为 false                              ← 实测
  ⇒ Snapshot 的 Camera::start() 挂在 connect_is_active_notify 上，永不触发 ← 源码
  ⇒ 从不调用 org.freedesktop.portal.Camera.AccessCamera                  ← dbus-monitor 0 条
  ⇒ 设备提供者未启动 ⇒ viewfinder 停在 Loading ⇒ UI 一直转圈
```

**排除项（本轮都测过、都不是原因）**：

| 环节 | 结论 |
|---|---|
| 权限 | `devices/camera = {org.gnome.Snapshot: [yes]}` ✅ |
| `IsCameraPresent` | `true` ✅ |
| `OpenPipeWireRemote` | 返回有效 fd ✅ |
| pipewire 节点 | `gst-device-monitor` 2 台（前 gc08a8 / 后 s5kjns，含 rotation）✅ |
| portal 后端 | `xdg-desktop-portal-gnome 50.0` 已装、后端注册正常 ✅（#335 已修） |
| 相机驱动 | 裸 libcamera 30 fps 满帧、AE 收敛 ✅（§46） |
| 触摸注入 | 事件真的进了内核并分发给客户端（`wl_touch.down/up` 有记录）✅ |

## 2. 判据（怎么一眼确认这个根因）

```sh
# ① seat 能力：4 = 只有 TOUCH，6 = TOUCH+POINTER，7 = 三样都有（含 KEYBOARD）
WAYLAND_DEBUG=1 <任意 GTK4 程序> 2>&1 | grep -oE "wl_seat#[0-9]+\.capabilities\([0-9]+\)"
# ② 窗口焦点（用最小复现器，别用 Snapshot 本身）
python3 -c '...GtkWindow... print(w.get_property("is-active"))'
#    正常应打印 True；本坑下恒 False
# ③ 客户端是否真的收到键盘
WAYLAND_DEBUG=1 <prog> 2>&1 | grep -c "wl_keyboard.*\.enter"
#    本坑下 = 0
```

**注意**：`wl_touch` 事件照常到达、手指点击也照常有反应（按钮能按），所以**"能交互"不能证明"有焦点"**。
GTK4 的 `is-active` 是 keyboard focus-in 驱动的，与触控无关。

## 3. 修法

**起 OSK 即可**（squeekboard 走 `zwp_input_method_v2`，phoc 会注册一个非 libinput 的虚拟键盘，
`seat_has_keyboard()` 对非 libinput 键盘直接返回 TRUE）：

```sh
# 验证（会话内）
squeekboard &            # 起来后 seat caps 变 6 或 7，wl_keyboard.enter 出现
# 生效判据
#  - wl_seat.capabilities 由 4 → 7
#  - GTK 临时窗 is-active 由 False → True
#  - Snapshot 日志出现 "Camera page showing: starting stream"
```

起 OSK 后实测：
- `AccessCamera` + `OpenPipeWireRemote` 被调用；
- `IsCameraPresent: true`、`Camera found: Built-in Front/Back Camera`、`Device provider started`；
- camerabin `Playing`；
- **屏幕出现真实预览画面，连续截图逐张不同（真动态流）**。

⚠ 持久化未做：squeekboard 现在是我手动起的（`pgrep squeekboard` → 6854）。开机自启应走
`/etc/xdg/autostart` 或 phosh 的 OSK 设置；**没有固化前，重启后又回到"转圈"**。

## 4. 顺带纠正的两条历史口径

- **"相机 App 没画面 = portal 缺后端"只对了一半**（#335 的结论不完整）：
   portal 后端缺是**必要条件之一**，装好 `xdg-desktop-portal-gnome` 之后还有**第二道门** = 窗口焦点 / seat 键盘能力。
   只装包不修 seat，UI 仍然转圈。
- **~~"软 ISP 只写第 0 帧"~~ 与本坑无冲突，但也别用它解释"转圈"**："转圈"发生在**还没开始协商流**的阶段
   （连 `AccessCamera` 都没调），属于纯用户态前置门；出流之后的成像问题才是 §45/§46 的范畴。

## 5. 方法教训（值得单独记）

- **"相机 App 转圈"必须按 UI 状态机分层查**，从上游往下：`窗口是否 active → 是否调用 portal → 是否枚举到设备 → 是否 START 流 → 是否出帧 → 帧是否正确`。
  本轮先花了很长时间在相机栈上（重装 IPA、重编 helper、排查 4 帧、盯 dmesg），**其实第一层就没过**。
- **判断"事件有没有送到客户端"要用 `WAYLAND_DEBUG=1` 抓客户端侧**，不要只在内核侧 `evtest` 看事件存在。
  本轮一度因为 grep 关键字写错（`wl_touch.` vs `wl_touch#32.`）误判"客户端收不到触摸事件"，浪费了一轮。
- **用一个 20 行的最小 GTK 窗口当对照**（本轮 `acttest2.py`）。它同样 `is-active=False` 立刻把
  "Snapshot 特有 bug" 排除成"环境通用问题"，这是本轮转折点。

## 6. 关联

- 相关条目：#335（portal 后端缺，snapshot 只走 pipewiresrc）、#318（greetd 崩导致无桌面）、
  §46（相机 AE）、`reports/camera-app-portal-rootcause-20261018.md`（前置的一半）
- 报告：`reports/camera-snapshot-window-focus-20261019.md`
