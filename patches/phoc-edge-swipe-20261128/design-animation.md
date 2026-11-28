# 动画设计（第二版，不在本 MR 实现）

对照 libhandy `HdyDeck` 的 back 过渡，phoc 侧合成器层动画分四块：

## 1. Follow-finger 平移

- 识别起点后不立即 `phoc_view_close`，而是进入 `PHOC_CURSOR_*` 新状态（复用 cursor.c 里 `view_state`/`PHOC_DRAGGABLE_SURFACE_STATE_*` 的挂法）；
- 每个 damage 周期把视图沿 dx 平移（`PhocView` 已有 `move()`；或走 scene node offset 避免触发布局）；
- 竖向分量按阻尼折算（HdyDeck 是纯水平，建议 `dy*0.1` 跟随）。

## 2. 松手阈值判定

- 释放时取 `PhocGestureSwipe.get_velocity()` 的 vx（phoc 已有速度估计，`gesture-swipe.c` 事件历史 ±150ms）；
- 判定：`位移 ≥ 0.4×宽度 || vx ≥ 800 px/s` ⇒ 完成返回；否则回弹（ TimedAnimation 回到 0，phoc 已有 `anim/` + `timed-animation.c` 可直接用）。

## 3. Close 过渡

- 完成后不直接 close：先把视图滑出屏幕（同方向 1×宽度，约 150–250 ms，`phoc-anim` ease-out），动画结束再 `phoc_view_close()`；
- 若 close 前视图被客户端先行关闭（xdg close）要取消动画路径，避免 double-close。

## 4. 阴影

- HdyDeck 的 drop shadow = 拖出视图的「前缘」叠一张渐变（暗→透明，宽约 16–32 px）；
- phoc 可用现有 `PhocBling`/`color-rect.c` 思路：scene 直 add 一个带渐变纹理的 rect node，跟随视图偏移；纹理可预生成（cairo-texture.c）。

## 事件面注意

- 动画期间触摸序列保持被吞（cancel 已发），若做「不 cancel、全程跟随」需研究 wl 触摸所有权（seat grab），风险大，第一版不建议。
- 动画帧率与输入频率解耦（framerate clock 走 output frame，事件只更新目标位置）。
