# MR: cursor: Add an edge swipe back gesture

- **目标仓库**：https://gitlab.gnome.org/World/Phosh/phoc（基线 `main` = `51808950fc4f`，版本 0.59.0）
- **分支**：`wip/edge-swipe-back`（补丁 `0001-cursor-Add-an-edge-swipe-back-gesture.patch`，425 行新增）
- **Closes**: https://gitlab.gnome.org/World/Phosh/phoc/-/issues/125（2020-04-09 由 guidog 提出，至今 0 个 MR）

## 标题

`cursor: Add an edge swipe back gesture`

## 动机

phoc issue #125 想要「shell 层的 back 手势来关对话框」，最好带 libhandy `HdyDeck`/`HdyLeaflet` 那种 drop shadow。
目前 phoc 的 `PhocGestureSwipe` 实际只覆盖 touchpad（wlr pointer gestures，见 `phoc_gesture_swipe_filter_event`），
touch 屏侧没有任何边缘手势；用户侧只能用 lisgd 旁听 evdev 模拟，代价是**事件照常透传给前台应用**（Firefox 里既触发返回又滚动网页）。
本 MR 把识别与事件吞噬收进合成器。

## 实现要点

1. 新增 `PhocGestureEdgeSwipe`（`PhocGestureSingle` 子类，与现有 gesture 家族同风格）：
   - `filter_event` 只放行 touch 事件，touchpad/鼠标全部过滤；
   - `TOUCH_BEGIN` 时判断落点是否在左/右边缘带内（`edge-width` 属性，默认 16 layout px），不在带内不认领序列；
   - `TOUCH_UPDATE` 累计位移，**|dx| > |dy| 且 |dx| ≥ max(32, 输出宽度×1/4)** 时 emit `::back`（edge 枚举）。
     只要求「横分量大于竖分量」而非精确角度——拇指弧线（D13 实测弦角 20°–45°）可识别；
   - 第二根手指按下即 reset，避免捏合误触。
2. `phoc_cursor_init` 挂载该手势；`on_edge_swipe_back` 中：
   - **吞序列**：`wlr_seat_touch_get_point` + `send_touch_cancel()`——这是 phoc 既有先例
     （draggable layer surface 的 `on_swipe` fling 同样这样吞），cancel 后 seat 触摸点被移除，
     后续 motion/up 在 `phoc_cursor_handle_touch_motion/up` 里因 `wlr_seat_touch_get_point()==NULL` 不再发客户端；
   - **返回语义（第一版）**：与 `wm.keybindings close` 一致，对 focus view 调 `phoc_view_close()`。
3. 边缘带宽度为 GObject 属性 `edge-width`（默认 16），gsettings 配置项的接线留作后续（见已知限制）。

## 如何测

- `meson compile -C build`（本 MR 在 x86_64 宿主上以 `-Dembed-wlroots=enabled` 全量编译链接通过，0 warning）。
- 手机上：从屏幕左/右边缘水平（含弧线）滑入 ≥1/4 屏宽 ⇒ 顶层窗口关闭；触摸抬手前应用不应收到任何事件（可用 `WAYLAND_DEBUG` 或 Firefox 内滚动无反应验证）。
- 反例：屏幕中部竖划、双指、面板上按下均不触发。

## 已知限制

- 「back」目前只有 close 语义；#125 期望的「逐级返回意图」（应用内返回 → 应用栈 → shell 关闭）需要与 phosh 的协议面协商，本 MR 不引入新协议。
- 应用在 down 时已收到过一次 touch-down（识别在合成器侧必然滞后），之后收到 cancel——这是 wl 语义下能做到的最干净形态。
- `edge-width` 尚未接 gsettings；第一版先用属性注入。
- 动画未实现，设计见 `design-animation.md`。

## AI 披露

本 MR 由 AI 辅助起草（代码、描述与设计文档），作者本人负责校对、测试与最终决定，内容与决定归作者。

## 后续

1. follow-finger 平移动画 + 阴影（`design-animation.md`）；
2. `edge-width` 接 cfg/gsettings；
3. 与维护者讨论 back 意图逐级传递（phosh-private 或新协议）。
