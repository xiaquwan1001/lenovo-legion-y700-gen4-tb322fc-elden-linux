<!-- 来源：researcher lane 产出（2026-11-28 13:3xZ）；父代理独立复核了 Finding 1/2/3/4/5 的源码命中（src/anim 存在、view.c:1457 play、view->box 无插值、无 wlr_scene.h）后提升入 reports/。原文未改一字（仅此注）。 -->
# Research: phoc/phosh 线「边缘返回手势动画」可行性（D13 后续，2026-11-28）

## Summary

**前提要改**：phoc **0.46.0 已经带一套完整动画框架**（`src/anim/`：`PhocAnimatable` 帧回调 / `PhocTimedAnimation` 时长+easing / `PhocPropertyEaser` 属性补间），并且**已经在用**它做 per-view `alpha` 的 150 ms 淡入（`view.c:1299-1316`）。
缺的不是"动画能力"，而是：① 窗口**位置**不是可补间的 GObject 属性（`view->box.x/y` 直接赋值，无过渡）；② 没有 follow-finger 的触摸→位移通路（也无 back 手势本身）。
所以「返回动画」的代价主要是**手势与位移通路（~250–400 行 C）**，不是动画引擎；而 #125 线程上游 2023-02 已表态倾向 client-side ⇒ 建议第一版 MR **只做吞事件+手势+close**，动画单独一版、只做 close 前 ~200 ms 位移+alpha。

## Findings

1. **phoc 0.46.0 有动画框架（有，且已编译进 libphoc）**
   `src/meson.build:1` `subdir('anim')`，sources 末尾 `+ phoc_anim_sources`；`src/anim/` 含 `animatable.*`、`easing.*`、`property-easer.*`、`timed-animation.*`、`phoc-animation.h`。
   API：`phoc_animatable_add_frame_callback()`（`src/anim/animatable.h:39-46`）、`phoc_timed_animation_{set_duration,play,skip,reset}()`（`src/anim/timed-animation.h:19-37`）、`phoc_property_easer_set_props()/phoc_lerp()`（`src/anim/property-easer.h:20-33`）。
   **上游 main 同名同文件仍在**（`src/anim/` tree 2026-11-28 现查含同一批文件名）⇒ 对 main 提 MR 可直接复用，不必重造。
   **Sources:** 本地缓存 `/tmp/ph046/phoc-0.46.0/`（0.46.0 上游 tarball）；https://gitlab.gnome.org/api/v4/projects/World%2FPhosh%2Fphoc/repository/tree?path=src/anim&ref=main
   **Support:** direct evidence（文件内容逐行读过）。**Confidence:** high。

2. **0.46 已经在做 per-view 透明度动画：map 时 0→1，150 ms，ease-out-quad（有）**
   `view.c:28` `#define PHOC_ANIM_DURATION_WINDOW_FADE 150`；`view.c:39` `PROP_ALPHA`；`view.c:1299-1316` 组装 `PhocPropertyEaser("alpha",0.0,1.0)` + `PhocTimedAnimation("animatable"=PhocView 的 output, duration=150, easing=PHOC_EASING_EASE_OUT_QUAD)` 并 `play`。
   写入路径：`phoc_view_set_property()` → `phoc_view_set_alpha()`（只改 `priv->alpha` + `damage_whole`）。
   **Sources:** `src/view.c:28,39,1299-1316`（行号按源码逐行计数；复核：`grep -n "PHOC_ANIM_DURATION_WINDOW_FADE\|PROP_ALPHA\|PHOC_EASING_EASE_OUT_QUAD" src/view.c`）。**Support:** direct evidence。**Confidence:** high。

3. **★ 该淡入在 phosh 默认配置下基本不触发（gating）**
   `view.c:1299-1301` 条件 = `phoc_desktop_get_enable_animations(desktop) && self->parent == NULL && !phoc_view_want_auto_maximize(self)`；
   而 `data/sm.puri.phoc.gschema.xml` 的 `auto-maximize` **默认 true**（phosh 默认所有主窗最大化）⇒ 普通应用窗口进不了这个分支。
   ⇒ 不能拿"0.46 已有淡入"当作"返回动画已有一半"；它只在浮动窗口上生效。
   **Sources:** `src/view.c:1299-1301`、`data/sm.puri.phoc.gschema.xml:5-13`。**Support:** direct evidence（代码）+ interpretation（"默认不触发"是对该 gate 的推断，未上机验证）。**Confidence:** medium-high。

4. **窗口位置不可补间：只有 int 坐标 + 立即 damage（没有 x/y 补间）**
   `view.h:60-70` `struct wlr_box box;`（注释 "(x, y): surface position in layout coordinates"）；`view-private.h:12` `view_update_position()`；
   实现体内只有 `view->box.x = x; view->box.y = y;` + 两次 `phoc_view_damage_whole()`（`grep -n -A8 "^view_update_position" src/view.c`），**没有** easing/插值。
   `view_class->move = phoc_view_move_default` → `view_update_position`（`view.c` class_init 段，`grep -n "phoc_view_move_default" src/view.c`）。
   ⇒ 要做 follow-finger/松手动画，必须**新增**"位置随时间变化"的通路（两条便宜路线：给 PhocView 加 `x`/`y` 可写 GObject 属性走现有 `PhocPropertyEaser`；或在 frame callback 里直接 `phoc_view_move()`）。
   **Sources:** `src/view.h:60-70`、`src/view-private.h:12`、`src/view.c`（`view_update_position`）。**Support:** direct evidence。**Confidence:** high。

5. **phoc 0.46 的 toplevel 渲染不经 `wlr_scene`（任务里的假设不成立）**
   `desktop.c:11-41` 的 include 列表无 `wlr_scene.h`；渲染入口是自研的 `PhocRenderer` / `PhocRenderContext`（`render.h:19-27`，context 里带 `float alpha`）。
   ⇒ 「wlr_scene 能否 per-view 位移+alpha」这个问题在 phoc 里**不适用**；等价物是 `view->box`（位置）+ `priv->alpha`（透明度），两者都在 phoc 手里，改起来比 scene graph 更直接。
   **Support:** direct evidence（include/结构体）。**Confidence:** high（但仅覆盖 toplevel 路径；全仓 `wlr_scene` 使用未 grep，见 Missing evidence）。

6. **阴影/装饰有现成挂点：`PhocBling` 接口 + cairo 纹理路径（有）**
   `bling.h:~20-70` 定义 `PhocBling`（`get_box/render/map/unmap/is_mapped`）；`view.h` 有 `phoc_view_add_bling()/remove_bling()/get_blings()`；现有实现 = `view-deco.c`（客户端装饰/边框）。
   仓库自带 `cairo-texture.c`（cairo → 纹理），意味着"用 cairo 画阴影"是既有手法 —— 与 libhandy 的 4 层 cairo 阴影（见 7）可直接对齐。
   **Sources:** `src/bling.h`、`src/view.h`（`phoc_view_add_bling`）、`src/cairo-texture.c`。**Support:** direct evidence。**Confidence:** high。

7. **libhandy 侧：`HdyDeck`/`HdyLeaflet` 全部委托给 `HdyStackableBox`；跟手 1:1、松手 ease-out-cubic、阴影按"剩余距离"淡出**
   - 委托：`hdy-leaflet.c` 的 private 只有 `HdyStackableBox *box;`；`hdy-stackable-box.c` 头注释明写 "used as an internal implementation of Deck and Leaflet"。
   - 跟手位移：`get_child_window_x()`/`get_child_window_y()` = `width * (1 - progress)`（OVER）或 `width * progress`（UNDER）——**线性 1:1，无阻尼/无过冲**；手势期间 `is_gesture_active` 时不跑 ticker（progress 由 swipe tracker 直接给）。
   - 松手：`hdy_stackable_box_child_transition_cb()` 用 `gtk_progress_tracker_get_ease_out_cubic()` 在 `child-transition-duration` 内 lerp；`start_child_transition()` 在 `!hdy_get_enable_animations(widget) || duration==0` 时直接跳到终态（尊重 GNOME `enable-animations`）。
   - 阴影：`hdy-shadow-helper.c` `hdy_shadow_helper_draw_shadow(cr,w,h,progress,direction)` —— 4 个 cairo pattern（`dimming`/`shadow`/`border`/`outline`，尺寸取自 CSS 子节点 `min-width|min-height`）；`remaining_distance=(1-progress)*distance`；`shadow_opacity = remaining/shadow_size`（超过 shadow_size 即 1.0）；dimming = `paint_with_alpha(1-progress)`；尺寸带缓存，过渡结束 `clear_cache()`。
   - 起手区域：`hdy_swipeable_default_get_swipe_area()` 返回**整个 widget**，即 libhandy 的 back 手势可从窗口任意位置起手 —— 正是 #125 里 Sebastian 指出的"会和横向滚动冲突"的根因；phoc 版必须改成边缘窄带。
   **Sources:** https://gitlab.gnome.org/GNOME/libhandy/-/raw/main/src/hdy-leaflet.c 、 `.../hdy-stackable-box.c` 、 `.../hdy-shadow-helper.c` 、 `.../hdy-swipeable.c`（2026-11-28 取）。**Support:** direct evidence。**Confidence:** high（常数默认值未取，见 Missing evidence）。

8. **libadwaita 侧（GTK4 后继）有可借鉴的"进度+速度"模型与数值**
   `adw-swipe-tracker.c` 文件头宏块：`DRAG_THRESHOLD_DISTANCE 16`（起判像素）、`VELOCITY_THRESHOLD_TOUCH 0.3`（进度/ms，低于即回弹到最近 snap point）、`MIN_ANIMATION_DURATION 100` / `MAX_ANIMATION_DURATION 400`、`DECELERATION_TOUCH 0.998` + 抛物线投影（松手落点预测）、`OVERSHOOT_DISTANCE_MULTIPLIER 0.1`（橡皮筋）。
   `adw-spring-params.c` 提供 mass/stiffness/damping-ratio 弹簧（critically damped = 最短时间无振荡）。
   ⇒ 若 phoc 做手势，**用"位移/速度"判定而不是角度档**（比 lisgd 的 45° 桶更符合拇指弧线）。
   **Sources:** https://gitlab.gnome.org/GNOME/libadwaita/-/raw/main/src/adw-swipe-tracker.c 、 `.../adw-spring-params.c`。复核：`grep -n "DRAG_THRESHOLD_DISTANCE\|VELOCITY_THRESHOLD_TOUCH\|MIN_ANIMATION_DURATION" src/adw-swipe-tracker.c`。**Support:** direct evidence。**Confidence:** high。

9. **上游态度的关键变化（2023-02-17 起）＝ 倾向 client-side，且疑"边缘手势该不该在合成器"**
   #125 全文（2026-11-28 读取）末段：Alice（alicem）"Fwiw I'm leaning towards doing most of it on the client side."；Guido 回 "Yeah, I guess that's fine. A e.g. two/three finger swipe close could benefit other toolkits though."
   同线程 Sebastian（2020）已指出合成器版会破坏横向滚动/滑动；Adrien 指出合成器与客户端之间"Basically, there's none"（无协商通道，需新协议）。
   ⇒ 单 MR 塞"follow-finger + 阴影 + 关闭动作"被质疑的概率高；**吞事件+手势+close 的"能修好什么"论证**反而是最容易被接受的切口。
   **Sources:** https://gitlab.gnome.org/World/Phosh/phoc/-/issues/125（全文，含本仓 2026-11-28 的 note）。**Support:** direct evidence（引文）+ interpretation。**Confidence:** high。

## 三条路径对比

| | A 合成器侧（phoc 内） | B 应用侧（GTK/libhandy 自己动画） | C phosh shell 层 |
|---|---|---|---|
| 能否吞事件 | **能**（`send_touch_cancel`，cursor.c 已有先例） | 不能（现状＝lisgd 旁听，Firefox 误滚动） | 不能（phosh 是客户端） |
| 能否动画**别的**窗口 | 能（`view->box`+`priv->alpha` 都在手） | 只有 libhandy/libadwaita 应用会动画；Firefox/foot/Waydroid 不动 | **不能**：拿不到别人 toplevel 的 buffer，只能画覆盖层（dim/blur）；要让 phoc 动就得走新协议 ⇒ 等于 A |
| 工作量 | ~250–400 行 C + 2 个 gschema key（手势 80 / 跟手位移 40 / 松手动画 40 / 阴影 60–100 / 样板） | 0 行本仓代码，但**收益只覆盖自家 GTK 应用** | 覆盖层 ~100 行 QML/C，但**做不出返回动画** |
| 风险 | 触摸 cancel 与 OSK grab、draggable layer、shell reveal、全屏视频冲突；每次 phoc 升级 rebase | 无 | 低，但无意义（解决不了"窗口动"） |
| 上游接受度 | 中：切"吞事件"好谈；切"整套 iOS 式动画"难（#125 5.5 年 + 2023 倾向 client-side） | 上游偏好方向（alicem 原话） | 不适用（动画**不该**进 shell） |

**必须进 phoc**：① 触摸序列的 claim/cancel（只有合成器能决定"这次触摸不给客户端"）；② 窗口位移/透明度（buffer 归合成器管）；③ 边缘命中与 layer 优先级（OSK/top-panel 谁先吃）。
**不该进 phoc**：a11y/开关策略（沿用 GNOME `enable-animations`）、阴影的视觉参数（应交 CSS/gschema 而非硬编码）、以及"返回语义分级"（应用内返回→应用栈→关窗，属 phosh/协议层）。

## 建议给父代理的 MR 第一版范围（一行）

**第一版 phoc MR 只做「边缘手势识别 + 吞触摸 + 调 `phoc_view_close()`」，零动画**（形状即 #125 + 我们 note 里的 `PhocGestureSwipe`/边缘起点/位移阈值/`send_touch_cancel`，阈值用位移+速度而非角度档）；**动画放第二版、单独 MR**，最小形态 = **松手后 ~200 ms 位移（±屏宽 1/3）+ alpha→0，ease-out-quad，复用 `PhocTimedAnimation`**，**不做 follow-finger、不做阴影**（follow-finger 需要 cancel 后回弹、与 OSK/draggable-layer 抢触摸、以及"位置补间"新通路，是第二版之后的第三版；阴影是 `PhocBling` 独立件，可最后做）。

## Contradictions

- 任务假设"phoc 0.46/main 有没有任何窗口动画框架"→ 答案与假设相反：**有**（`src/anim/`，0.46 与 main 均在），且已用于 alpha 淡入。已在 Findings 1–3 用文件与行号订正；"0.46 没动画"这类说法（含 `.pi/plans/2026-11-25-*.md` §2 的隐含口径）应视为过时。
- 「0.46 有 150 ms 淡入」与「用户看不到窗口淡入」不矛盾：gate 掉了自动最大化窗口（Finding 3）。

## Missing evidence

- `phoc_desktop_get_enable_animations()` 的**实现**（`desktop.h:104` 有声明；`struct _PhocDesktop` 里无对应字段）⇒ 推断是每次读 GSettings；键名推断为 `org.gnome.desktop.interface enable-animations`（phoc 链接了 `gsettings_desktop_schemas_dep`）。**未读实现**，复核：`grep -n "enable.animations" src/desktop.c`。
- libhandy `child-transition-duration` 的**默认毫秒值**未取（属性存在：`hdy-leaflet.c` `hdy_leaflet_get_child_transition_duration`）；复核：`grep -n -A6 "PROP_CHILD_TRANSITION_DURATION\]" src/hdy-stackable-box.c`。
- 0.46 中 `on_swipe`/`cursor.c` 具体行号沿用上一 lane 的附录 C（`cursor.c:1126-1163`、`:1082-1091`），**本轮未复验**。
- 全仓 `wlr_scene` 使用面未 grep（Finding 5 只覆盖 desktop.c 的 include 与 render.h）。
- 设备侧 `gsettings get org.gnome.desktop.interface enable-animations` 现值未查（上机项，决定动画是否被 a11y 开关关掉）。
- **本 subagent 无 shell 工具**（只有 read/write/web_fetch/web_search）⇒ 无法执行 `glab api`、`git status --porcelain`、`grep`；所有 grep 命令已写在上面供父代理一键复核。`git status` 回执缺失，见 acceptance 的 residualRisks。

## Sources

- Kept: phoc 0.46.0 源码（本地 `/tmp/ph046/phoc-0.46.0/`：`src/view.c`、`src/view.h`、`src/view-private.h`、`src/bling.h`、`src/render.h`、`src/meson.build`、`src/anim/*`、`data/sm.puri.phoc.gschema.xml`）— 逐行读出，是"有没有 X"的唯一直接证据。
- Kept: phoc API tree（`.../repository/tree?path=src/anim&ref=main`）— 证明框架在 main 仍在，MR 可对齐。
- Kept: phoc #125 全文 — 上游设计约束与 2023 立场，决定 MR 切分。
- Kept: `hdy-stackable-box.c` / `hdy-shadow-helper.c` / `hdy-leaflet.c` / `hdy-swipeable.c` — libhandy 的实现范式（1:1 跟手、ease-out-cubic、4 层阴影、全程起手）。
- Kept: `adw-swipe-tracker.c` / `adw-spring-params.c` — 现代阈值与速度模型数值来源。
- Deprioritized: 本仓 `.pi/plans/2026-11-25-phosh-edge-swipe-back.md` §1（上游 issue/MR 台账）— 事实仍有效，但"phoc 无动画框架"的隐含前提已过时，只取它的 0.46 行号索引。

## Next steps

1. 父代理跑上面 3 条 grep，把 `enable-animations` 的真正键名与 libhandy 默认时长钉死（10 分钟）。
2. 上机一条命令确认 a11y 开关：`gsettings get org.gnome.desktop.interface enable-animations`（若 false，任何动画 MR 在设备上"看不见"，会误判为失败）。
3. 若要动第二版：先在 QEMU 里验"松手后 200 ms 位置+alpha 补间 + 立刻 `phoc_view_close()`"不会与应用自绘/全屏视频打架（无需上机）。
