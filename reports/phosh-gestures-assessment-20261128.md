# T29 上游化评估（主机侧那半）· phosh/phoc 手势导航交互 + 视觉效果

> **状态词只用** PASS / FAIL / 未证实。手感/观感类结论 **本轮一律不判优劣**（需设备窗 + 人目视，见 §5）。
> **只读纪律**：本轮唯一写入 = 本文件 + `reports/artifacts/phosh-gestures-20261128/`（新建）。未改 TASKS/DEVICE/INDEX/RESOURCES/PITFALLS/AGENTS 与任何既有 report；
> 设备侧只跑读命令（`dpkg -l` / `gsettings get|list-recursively` / `cat` / `ls` / `gresource list`），**零写、零重启、零装包**；未发信、未推 MR。
> **取证时间**：设备 2026-11-27T22:12Z（uptime 8h00），外部 URL 访问日 **2026-11-27**。
> **设备身份**：`lenovo,elden` / `qcom,sm8750`，Debian 13 (trixie)，phoc **0.46.0-1** / phosh **0.46.0-3+deb13u1**，wlroots 0.18.2-3，面板模式 1904x3040。
> **先例基线**：`reports/mobian-phosh-upstream-20261125.md`（版本线、GitLab 访问口径）、`TASKS/dim/D13.md`（侧滑返回）、`.pi/plans/2026-11-25-phosh-edge-swipe-back.md`、`.pi/plans/2026-11-25-gesture-visual-feedback.md`（视觉/触觉反馈设计）。
> **⚠ 与先例的一处数字冲突（据实记）**：`mobian-phosh-upstream-20261125.md` §4.3 / C 段写「我们设备 phosh **0.58.0**」；本轮设备现查 = **phosh 0.46.0-3+deb13u1 / phoc 0.46.0-1**（`dpkg -l` 逐字，见 `device-probe.log` §versions）。D13 与两份 plan 写的 0.46 与本轮一致 ⇒ **0.58 那句是笔误或指别的核**，本报告一律按 0.46 立论。

---

## 0. 一页结论

| 层 | 结论（一句话） | 判据 |
|---|---|---|
| **手势** | 现役手势集 = **底部 home-bar 纵向拖拽（上=overview、下=折叠）+ 顶部面板下拉（快捷设置）+ home 按钮长按（展开 OSK）+ phoc 层表面拖拽**；**没有任何「边缘侧滑」内建手势**，也没有任何手势参数暴露成配置键 | phosh 0.46 源码 `src/home.c`、`src/top-panel.c`、`src/drag-surface.h`；设备 `gsettings list-recursively` 全量（§1.3） |
| **配置面** | 可调面**极小**：phosh 0.46 的 shell schema 只有 **10 个键**，其中**零个**是手势/动画/圆角；phoc schema 只有 2 个键（`auto-maximize`/`scale-to-fit`）；`phoc.ini` 只有 `[core] xwayland` + 每输出 11 个输出参数 | `data/sm.puri.phosh.gschema.xml`(0.46) / `data/sm.puri.phoc.gschema.xml` / `src/settings.c:129-231`(phoc 0.46) |
| **视觉** | 动效唯一总闸 = `org.gnome.desktop.interface enable-animations`（当前 `true`）；圆角/刘海避让 = 由 **gmobile 内置 gresource 的设备表** 驱动，而 **elden 不在表内（26 条无一条 lenovo/elden/sm8750）⇒ 圆角避让当前等于关闭** | phosh `src/animation.c:223`、`src/layout-manager.c:239-286`；gmobile `src/gm-device-info.c:15-22` + 设备 `gresource list` |
| **上游** | 近 90 天（2026-08-29→11-27）与手势/动画/圆角相关的 **MR 14 条 / issue 6 条**（窗口内 phosh MR 64/issue 26、phoc MR 23/issue 7，按关键词筛出）；方向明确：上游正在把「手势过渡」从 phosh 下沉到 phoc（zoom-to-overview 系列），并且**仍然不提供任何手势/动画配置键**（0.60-dev 的 `mobi.phosh.shell` 22 个键里也是 0 个） | §4 表（全部带 URL/日期） |
| **本轮可动手的** | 问题表 **16 项**（§5）分类：**本机配置即可 3 项**（P13 主题/配色、P16 `close` 绑定、P12 动效总闸；另有 P4 链路已就位、P14 CSS 属未证实 hack）· **需下游补丁/升级 4 项**（P3 phoc !828 backport、P5+P6 gmobile 设备表、P7 zoom 过渡、P9 `focus-frame`）· **值得上游 6 件**（U1–U6，清单见 §6，只列不起草；其中 P1/P2/P8/P10/P11/P15 归并入 U2–U6） | §5 |

---

## 1. ① 现状取证（只读，主机侧）

证据原始日志：`reports/artifacts/phosh-gestures-20261128/device-probe.log`（159 行，`rc=0`）；脚本 `probe-device-readonly.sh`（可原样复跑）。

### 1.1 版本与运行形态

| 项 | 现查值 | 来源 |
|---|---|---|
| OS | Debian GNU/Linux 13 (trixie) | `os-release` |
| phosh | **0.46.0-3+deb13u1**（`/usr/libexec/phosh`，pid 1372） | `dpkg -l` / `pgrep -a` |
| phoc | **0.46.0-1**（`Phoc 0.46.0 - Phone compositor`） | `phoc --version` |
| wlroots | libwlroots-0.18 **0.18.2-3** | `dpkg -l` |
| phoc 启动行 | `/usr/bin/phoc -v -S -C /usr/share/phosh/phoc.ini -E bash -lc 'exec gnome-session … --session=phosh'` | `pgrep -a phoc` |
| 输出 | `card0-DSI-1` 模式 **1904x3040**；`scaling-factor=0`（= phoc 侧自动缩放） | `/sys/class/drm/card0-DSI-1/modes`、gsettings |
| 上游/Sid 版本线 | phosh/phoc **0.59.0**（2026-11-15）；设备落后 **13 个 minor**（0.46 vs 0.59） | `mobian-phosh-upstream-20261125.md` §4.3（未重验） |

> **关键运行事实（影响「本机改法」可行性）**：phoc 的配置路径被会话**硬编码**为 `-C /usr/share/phosh/phoc.ini` ⇒ 用户级 `~/.config/phoc.ini`、`/etc/phoc.ini` **都不会被读**（两者本机均 absent）。想改任何 phoc.ini 内容，必须改 `phosh-session`/启动行（下游动作），不是「放个文件就行」。

### 1.2 phoc.ini 键集（0.46 = 上游 main 同集）

| 段 | 键 | 当前值（`/usr/share/phosh/phoc.ini`） | 视觉/手势相关 |
|---|---|---|---|
| `[core]` | `xwayland` | 注释掉 | 否 |
| `[output:<NAME>]` | `enable` `x` `y` `scale` `rotate` `mode` `modeline` `scale-filter` `drm-panel-orientation` `phys_width` `phys_height`（共 11） | 生效的只有虚拟输出段（Virtual-1/X11-1/WL-1/HEADLESS-1）；`[output:DSI-1]` 两行均注释 | 仅 `scale`/`scale-filter` 间接影响观感；**无 shadow / 圆角 / 动画 / 阻尼任何键** |

证据：`src/settings.c:129-231`（0.46 完整分支列表）与上游 main `src/settings.c`（同集，抓取于 `/tmp/phocmain-settings.c`，仅 `xwayland` + 11 个输出键）。phoc CLI 也只有 `-C/-E/-S/-X/-v/--version`（`phoc --help`），无视觉开关。

### 1.3 gsettings 全量（可调键值表）

**A. `sm.puri.phoc`（phoc 的 GSettings 面，仅 2 键）**

| 键 | 设备现值 | 上游默认 | 说明 |
|---|---|---|---|
| `auto-maximize` | **false** | `true` | 设备**偏离默认**（改过）：新窗口不强最大 → 影响窗口观感/边缘手势命中面 |
| `scale-to-fit` | false | false | 超屏窗口自动缩放 |

**B. `sm.puri.phosh`（phosh shell 面，0.46 共 10 键；**无一个**手势/动画/圆角键）**

| 键 | 现值 | 默认 | 与本题关系 |
|---|---|---|---|
| `shell-layout` | `'device'` | `'device'` | **直接决定圆角/刘海避让是否计算**（`layout-manager.c:get_corner_shift`：非 device 直接 goto out） |
| `osk-unfold-delay` | `1.0` | `1.0` | home bar 长按展开 OSK 的延迟倍率（唯一「手势手感」类键，范围 [0.5,2.0]） |
| `app-filter-mode` | `['adaptive']` | 同 | 无关 |
| `force-adaptive` | `@as []` | 同 | 无关 |
| `automatic-high-contrast` / `-threshold` | `false` / `500` | 同 | 视觉（主题切换） |
| `favorites` | 4 项 | 同 | 无关 |
| `enable-suspend` / `quick-silent` / `wwan-backend` | `false`/`false`/`'modemmanager'` | 同 | 无关 |

（另有 `sm.puri.phosh.lockscreen` 2 键、`.notifications` 3 键、`.plugins` 2 键、`.osk.*` 若干，均与手势/动效无关。）

**C. `org.gnome.desktop.interface`（phosh 是 GTK3 应用，这一组才是真正的视觉总闸）**

| 键 | 现值 | 与视觉效果关系 |
|---|---|---|
| **`enable-animations`** | **true** | phosh 全部动效的**唯一总闸**：`animation.c:223` 与 `fader.c:131` 走 `hdy_get_enable_animations()` → GTK `gtk-enable-animations` → 由本键驱动 |
| `gtk-theme` / `icon-theme` / `cursor-theme` | `Adwaita` / `Adwaita` / `Adwaita` | 圆角、阴影、控件观感的来源（phosh 自带 CSS 只是叠加层） |
| `color-scheme` | `'prefer-dark'` | 深色/浅色；影响视觉对比 |
| `text-scaling-factor` / `scaling-factor` | `1.0` / `uint32 0` | 缩放；与「手势步进感」相关（上游 phoc #293） |
| `font-*` | Cantarell 11 / grayscale / slight | 无关主旨 |

**D. 键绑定面（`org.gnome.desktop.wm.keybindings`，phoc 消费）**

| 键 | 现值 | 备注 |
|---|---|---|
| **`close`** | **`['<Alt>F4', 'XF86Back']`** | D13 链路的关键一环（见 §2.4） |
| `maximize` / `minimize` / `switch-applications` | `['<Super>Up']` / `['<Super>h']` / `['<Super>Tab','<Alt>Tab']` | phoc 注册表见 `keybindings.c:587-636`（共 22 条） |
| `always-on-top` / `toggle-fullscreen` | `@as []`（空=不绑定） | 可空手配 |

> phoc 实际注册的动作集（`src/keybindings.c:587-636`）：`always-on-top, close, cycle-windows(-backward), maximize, toggle-fullscreen, toggle-maximized, move-to-monitor-{up,down,left,right}, move-to-corner-{nw,ne,se,sw}, switch-applications(-backward), unmaximize, switch-input-source` + mutter 侧 `toggle-tiled-{left,right}`。**全部是键盘动作，没有 timeout/阈值/手势参数**。

### 1.4 其他相关现状

| 项 | 现值 |
|---|---|
| 会话用户 GTK 用户 CSS | `~/.config/gtk-3.0/` **不存在**；`/etc/gtk-3.0/` 只有 `im-multipress.conf` ⇒ 目前无任何 CSS 覆盖 |
| gmobile | `libgmobile0 0.3.1-1` + `libgmobile-common 0.3.1-1`；内置 display-panels **26 条**，`grep -iE "lenovo|elden|8750"` **无命中** |
| 侧滑返回链路 | `lisgd-edge-swipe` **enabled**（active 7h）；`/usr/local/bin/{lisgd-edge-swipe, uinput-back, elden-swipe-back}` 在位；`/etc/conf.d/lisgd-edge-swipe` **不存在**（全用默认：`ELDEN_SWIPE_EDGES=LR`、threshold 60、timeout 800ms、node=/dev/input/event4、geom 1904x3040）；`/var/log/lisgd-edge-swipe.log` 93 KB |
| OSK | `screen-keyboard-enabled = true`（D13 前提②满足）、`phosh-osk-stub 0.46.0-1` 在跑 |

---

## 2. ② 手势现状（逐项：是否可配 / 参数在哪）

### 2.1 现役手势集（phosh 0.46，源码级）

| # | 手势 | 实现位置（0.46 行号） | 可配？ | 参数在哪 |
|---|---|---|---|---|
| G1 | **上滑回桌面 / overview**：底部 home bar 纵向拖 → 折叠/展开 | `src/home.c`（`phosh_home_new`：`"threshold", PHOSH_HOME_DRAG_THRESHOLD`）；`src/drag-surface.c` 经 `zphoc_draggable_layer_surface_v1` 由 **phoc** 驱动位移 | ❌ | **编译期常量** `home.c:31 #define PHOSH_HOME_DRAG_THRESHOLD 0.3`（屏幕高比例）；`home.h:16 #define PHOSH_HOME_BAR_HEIGHT 15`（px，也决定可拖区高度） |
| G2 | **上滑「悬停」= overview 保持展开**（松手后停在 overview，不回弹） | 同 G1（`PhoshDragSurfaceState` UNFOLDED/DRAGGED/FOLDED，`home.c:479-520`） | ❌ | 同上；判定逻辑硬编码 |
| G3 | **顶部面板下拉 = 快捷设置** | `src/top-panel.c`（`drag-surface` + `phosh_top_panel_dragged`，`:436`） | ❌ | 拖拽区高度由 `settings.c:calc_drag_handle_offset()` **运行时算**（CSS 高度 + QS 高度），非用户键 |
| G4 | **home 按钮长按 = 展开 OSK** | `src/home.c`（`osk_toggle_long_press` + `sm.puri.phosh osk-unfold-delay` 绑定，`:704-708`） | ✅ **唯一可配** | `gsettings set sm.puri.phosh osk-unfold-delay <0.5..2.0>` |
| G5 | **窗口/层表面拖拽**（phoc 侧 drag gesture） | `phoc src/cursor.c:1028-1120`（drag-begin/update/end）+ `gesture-drag.c`；层表面经 `layer-shell-effects` | ❌ | 硬编码；接受阈值/捕获窗口在 `gesture-swipe.c:21 #define CAPTURE_THRESHOLD_MS 150` |
| G6 | **多任务 / 应用切换** | 无触摸手势：只有 overview（G1）+ 键绑定 `switch-applications ['<Super>Tab','<Alt>Tab']` | 部分 | 键绑定可改（`org.gnome.desktop.wm.keybindings`） |
| G7 | **边缘侧滑返回** | **上游无**（phoc **#125** 自 2020-04-09 open，无 MR）；本机 = lisgd 旁路（§2.4） | 本机 ✅（lisgd 参数） | `ELDEN_SWIPE_EDGES`（默认 `LR`）、lisgd `-t 60` 距离阈值 / `-T 800` 时间窗 / 边缘起点段 `L`/`R` |
| G8 | 锁屏滑动解锁 | **0.46 无**（`lockscreen.c` 无 drag/swipe 路径，只有 keypad + 长按删） | — | — |

**必读的使用面事实（不是缺陷判断，只是事实）**：G1/G2 的拖动**只能从 15 px 高的 home bar/把手段起步**（layer surface `exclusive-zone=PHOSH_HOME_BAR_HEIGHT`，`drag-mode` 默认 `HANDLE`，`home.c:151-167`）——屏幕底部任意位置起划**不会**拉出 overview。G1 的阈值是**整屏高度的 30%**（1904x3040 竖屏 ⇒ ≈912 px），这是「上滑要划多远」的唯一旋钮且**不可配**。

### 2.2 上游 0.46→0.59 之间新增/变化的手势相关件（决定「升级能不能白拿」）

| 变化 | 出处 | 对本题意义 |
|---|---|---|
| 「运行中应用 → overview」**zoom 过渡**（0.57 引入，**默认关**）；0.58/0.59 由 phoc 侧完成 | phosh NEWS 0.57（`NEWS:88`）；phosh **!1944**（merged 2026-10-26）+ phoc **!804**（merged 2026-10-03） | 手势到 overview 的**过渡动效**；**需 phoc+phosh 双升级**，0.46 拿不到 |
| `drag-surface: Separate animation from dragging` | phosh **!1950**（merged 2026-10-12，"CI will fail until we've updated with the new compositor"，Closes phoc work item **295**）+ phoc **!806**（merged 2026-09-17） | 拖拽松手后的动画与手指位置解耦 ⇒ 直接是「手感」改动；**需双升级** |
| thumbnail overlay 期间不再丢帧 / 视频继续播 | phoc **!823**（merged 2026-11-13）、phosh **!1999**（merged 2026-11-19）、phosh **!1951**（merged 2026-11-07，"Includes !1950 which also needs a phoc update"） | overview 展开时的**视觉连续性**；需双升级 |
| 键绑定新增 overview 开关 | 上游 main `src/home.c:31-33`：`org.gnome.shell.keybindings` `toggle-overview` / `toggle-application-view` | 键盘可达性，和触摸手势无关但同属导航面 |
| **阈值仍是硬编码 0.3** | 上游 main `src/home.c:37 #define PHOSH_HOME_DRAG_THRESHOLD 0.3` | 升级到 0.60-dev 也**调不了** |

### 2.3 手势参数是否暴露（结论）

**上游到 0.60-dev 依然没有任何手势/动画参数键。** 证据：上游 main `data/mobi.phosh.shell.gschema.xml` 共 **22 个 key**（`favorites, app-filter-mode, force-adaptive, wwan-backend, automatic-high-contrast, -threshold, enable-suspend, quick-silent, shell-layout, osk-unfold-delay, schema-migration` + brightness/cell-broadcast/emergency-calls/lockscreen/notifications/plugins 子 schema），逐条核对**无 animation/gesture/threshold/transition/radius 类键**；phoc 侧新增的 `mobi.phosh.phoc` schema（上游 main `data/mobi.phosh.phoc.gschema.xml`）只有 `focus-frame`(b,默认 true) 与 `hide-cursor-timeout`(u,默认 0)，**0.46 两者都没有**（设备 `gsettings list-schemas` 无 `mobi.phosh.phoc`；phoc 0.46 源码无 `focus-frame`）。

### 2.4 D13（edge-swipe-back）当前状态 —— **未变，仍 PASS；且比 D13 文本再前进半步**

| 项 | D13 写于 2026-11-25 | 本轮 2026-11-27 现查 |
|---|---|---|
| `wm.keybindings close` | 「设备侧 `close` 已还原成 `['<Alt>F4']`（lane 在改）」 | **现 = `['<Alt>F4', 'XF86Back']`** ⇒ 键绑定已并入并在位 |
| 手势 daemon | `systemctl enable --now lisgd-edge-swipe` = active+enabled | **enabled**，active 7h，日志正在写（node event4 / geom 1904x3040 / threshold 60 / timeout 800ms） |
| 回调命令 | 直接 `uinput-back` | **已换成 `/usr/local/bin/elden-swipe-back`**（先 `setsid ffrumble` 触觉再 `exec uinput-back`；左右马达 event2/event3 分流；`ELDEN_SWIPE_HAPTIC/MS/MAG` 可关/可调） |
| 两侧 | `1,LR,L,*` + `1,RL,R,*`（`ELDEN_SWIPE_EDGES` 默认 LR） | 一致（`/etc/conf.d/lisgd-edge-swipe` 不存在 ⇒ 走默认 LR；helper `:71-77` 逐字核对） |
| 上游 | phoc #125 open 自 2020-04-09，无 MR | **本轮复核：phoc 12 条 open MR 里仍无 back-gesture 件**（最新 !828 是 drag 接受抖动补偿，2026-11-20） |
| 待人手项 | OSK 弹出时左缘滑动 / 全屏视频内滑动 / 真人左缘滑动 | **仍未做**（需设备窗 + 人手；本轮不做） |

⇒ **D13 = PASS（工程侧），验收侧仍缺人目视 3 项**；`elden-swipe-back` 的两处已知缺陷（F1 `ffrumble` 前台 sleep 推后 KEY_BACK、F2 `ELDEN_BACK_CMD` 自 exec 风险）在仓内 plan 里已记，本轮**未核设备侧现值是否已修**（`docs` 一致，属另一 lane）。

---

## 3. ③ 视觉效果现状（圆角 / 过渡 / 动效逐项）

| # | 视觉项 | 现状（证据） | 有开关吗 |
|---|---|---|---|
| V1 | **全局动效总闸** | `animation.c:223` `if (!hdy_get_enable_animations(widget) …) return` → GTK `gtk-enable-animations` → `org.gnome.desktop.interface enable-animations`（现 **true**）；`fader.c:131` 同路径 | ✅ 有（但是**全有/全无**，无「快/慢/阻尼」） |
| V2 | **动画时长** | 全部硬编码：phosh `revealer.c:194` 默认 **400 ms**；`app-grid.c:781-783` deck 过渡 **200 ms**（切换时先 0）；phoc `view.c:28` 窗口淡入 **150 ms**、`gesture-swipe.c:21` 手势捕获窗 **150 ms** | ❌ |
| V3 | **圆角避让（顶栏图标内缩）** | `layout-manager.c:239-286 get_corner_shift()`：`r = gm_display_panel_get_border_radius(panel)/scale`，`r≈0` 则 `goto out`（= 不内缩）。panel 数据来自 **gmobile 内置 gresource**（`gm-device-info.c:15-22`：「currently we only look at the built-in gresources」）。设备 gmobile 26 条面板中**无 lenovo/elden** ⇒ **radius=0 ⇒ 圆角避让未启用** | ❌（数据缺失，不是键） |
| V4 | **刘海/挖孔遮罩** | phoc `cutouts-overlay.c:156-182` 用 `gm_display_panel_get_cutouts(panel)` 画 overlay；无设备数据 ⇒ 不画。上游 gmobile 38 条里也无 lenovo/elden | ❌ |
| V5 | **phosh 自带 CSS 圆角** | `src/stylesheet/common.css` 内 `border-radius` 出现 **41 处**（99px/24px/18px/9px/12px/50%…），是 UI 元素圆角，不可配；GTK 用户 CSS 可覆盖（`~/.config/gtk-3.0/gtk.css`，当前**不存在**） | ⚠ 间接（GTK CSS 覆盖，副作用=样式耦合；**生效性未证实**） |
| V6 | **窗口阴影/边框/焦点框** | phoc 0.46：无焦点框（上游 0.58+ 才有 `focus-frame`）；`xdg-toplevel-decoration.c:45-56` 按客户端请求选 CSD/SSD（phosh 用 SSD），**两种模式都不画阴影/圆角**（`view-deco.c:271` 留着 `// TODO corners`） | ❌（0.46 无键；上游有 `focus-frame` 键） |
| V7 | **入场/退场过渡** | phoc 0.46 窗口**只有入场淡入**：`view.c:28 #define PHOC_ANIM_DURATION_WINDOW_FADE 150`（`view.c:1303-1316` 播放）；**无退场动画**（沿 `.pi/plans/2026-11-25-gesture-visual-feedback.md` §0 结论；本轮只复核了入场常量，退场未逐行走查 = **未证实**） | ❌ |
| V8 | **overview 过渡（zoom）** | 0.57 引入且**默认关**；0.58/0.59 由 phoc !804 + phosh !1944 完成 | ❌ 本机（0.46）不存在 |
| V9 | **缩放手感（步进）** | 上游 phoc **#293**（open，2023-12-11）「Scaling introduces stepping to gestures and GTK applications」；本机 `scaling-factor=0`（自动） | ❌ |
| V10 | **触觉反馈** | `elden-swipe-back` 已接 `ffrumble`（25 ms / 0x8000 / 左右马达分侧），`ELDEN_SWIPE_HAPTIC=0` 可关 | ✅（env） |
| V11 | 自动高对比 / 深色 | `automatic-high-contrast=false`、`color-scheme='prefer-dark'` | ✅ |
| V12 | 输出缩放/滤镜 | phoc.ini `[output:*] scale` / `scale-filter`（`auto`/`nearest`/`bilinear`），DSI-1 段当前注释 | ✅（但需改被引用的 `/usr/share/phosh/phoc.ini`，见 §1.1） |

---

## 4. ④ 上游评估（GNOME GitLab，近 90 天 2026-08-29→11-27）

口径：`GET /api/v4/projects/{16747=phosh,16763=phoc}/{merge_requests,issues}?state=…&updated_after=2026-08-29`（**匿名 API 可用**，本轮未用 token；`/search` 端点需登录 ⇒ 改为本地全文过滤）。原始 JSON 落盘 `reports/artifacts/phosh-gestures-20261128/gl-*.json`（phosh MR 64 / issue 26；phoc MR 23 / issue 7，窗口内）。

### 4.1 窗口内相关 MR

| 件 | 状态 / 日期 | 主题 | 与本题 |
|---|---|---|---|
| phosh **!1950** | merged 2026-10-12 | `drag-surface: Separate animation from dragging`（Closes phoc work item 295） | **手感核心**：松手动画与拖拽解耦 |
| phosh **!1944** | merged 2026-10-26 | `Zoom to overview - Part 2 (compositor version; Phosh part)` | overview 过渡动效 |
| phoc **!804** | merged 2026-10-03 | `Zoom to overview - Part 2 (Phoc part)` | 同上，compositor 侧 |
| phoc **!806** | merged 2026-09-17 | `layer-shell-effects: Separate user driven and compositor driven surface movement` | 拖拽/动画事件语义（`animated` vs `dragged`） |
| phoc **!823** | merged 2026-11-13 | `Make overlay thumbnails a gobject and damage with view` | overview 展开时视频不冻帧 |
| phosh **!1999** | merged 2026-11-19 | `home: Robustify thumbnail-overlay around unfolded state` | 上滑到顶时的图标时序 |
| phosh **!1951** | merged 2026-11-07 | `Skip thumbnail-overview on app launch`（含 !1950，需 phoc 更新） | 启动时不再抖动 |
| **phoc !828** | **opened** 2026-11-20 | `layer-shell-effects: Compensate for offset when accepting drag gesture` | **与本机「上滑起始跳变」直接同源**：拖拽被接受后表面跟手跳一下 |
| phosh !1574 | opened（2026-11-07 更新） | `overview: Hide activities when search bar gets focused` | overview 布局 |
| phosh !1452 | opened（2026-05 起） | `notification-content: Make notification content swipeable` | 横滑消通知（手势面扩展） |
| phoc !819 | opened 2026-10-17 | `desktop: Also check whether TOP layer covers output for view visibility` | 遮挡/可见性 |

### 4.2 窗口内相关 issue

| 件 | 状态 / 更新 | 主题 |
|---|---|---|
| phosh **#1368** | open 2026-11-23 | `thumbnail-overview: New flicker at end of fold animation`（折叠动画末尾闪烁） |
| phosh **#1354** | open 2026-09-17 | `overview: Bump max children per line in landscape` |
| phosh #1365 | closed 2026-11-09 | `screenshot-qs: Needs to wait til top-bar animation finishes` |
| phoc **#435** | closed 2026-10-31 | `Fast gestures can cause a use-after-free crash in Phoc`（**快滑可崩溃**，已修） |
| phoc #434 | closed 2026-09-26 | `Incorrect key used when retrieving a sequence state`（!811 修） |
| phoc #295(work item) | closed 2026-09-17 | `layer-shell-effects: Differentiate user-initiated drag and compositor-initiated animation` |

### 4.3 更早但仍 open 的手势栅格（升级也拿不到，需盯）

| 件 | 建于 | 主题 | 意义 |
|---|---|---|---|
| phoc **#125** | 2020-04-09 | `Have a back gesture to close dialogs` | D13 的「正门」；6 年无 MR |
| phoc **#385** | 2024-12-17 | `Bottom bar gesture to bring the whole screen down (one hand use)` | 下拉悬停（reachability） |
| phoc **#376** | 2024-07-05 | `Allow to disable edge-tiling` | 边缘手势与平铺冲突 |
| phoc **#374** | 2024-06-10 | `dragable-layer-surface: Avoid jump when gesture gets accepted` | = !828 的 issue 侧 |
| phoc **#275 / #276 / #265 / #292 / #281** | 2022–2024 | 只锚一边 / 客户端确认拖拽态 / FadeableLayerSurface / 动画期间不投事件 | 边缘手势基础设施 |
| phosh **#1322** | 2026-04-05 | `Postpone/hide notification *without* dismissing by vertical swipe` | 通告栏手势 |
| phosh **#1221** | 2025-12-31 | `Allow to blur background of UI elements` | 观感 |

### 4.4 圆角/设备数据上游

| 项 | 现查 |
|---|---|
| gmobile 仓库 | `World/Phosh/gmobile`（id 22559，last activity 2026-11-05，`main`） |
| display-panels 条数 | 上游 **38** 条（设备侧 0.3.1 只有 26 条）；**无 lenovo/elden/sm8750** |
| JSON 形态（可照抄的样例） | `data/devices/display-panels/fairphone,fp5.json`：`{"name","x-res","y-res","corner-radii":[135,135,135,135],"width","height","cutouts":[{"name","path"}]}` |
| 影响 | 有 `corner-radii` ⇒ phosh `get_corner_shift()` 才会内缩顶栏；`cutouts` ⇒ phoc 才会画遮罩 |
| 加载路径限制 | 只读内置 gresource（`gm-device-info.c:15-22`）⇒ **本机放 JSON 文件无效**，必须重编 libgmobile 或上游收录 |

---

## 5. ⑤ 问题清单表（项 | 现状 | 本机改法 | 上游评估）

> 「本机改法」= 只描述，**本轮未执行**任何写操作。「上游评估」三分类 = **配置即可 / 需下游补丁 / 值得上游**。

| # | 项 | 现状（可复现证据） | 本机改法（不改代码） | 上游评估 |
|---|---|---|---|---|
| P1 | 上滑回桌面要划多远 | 阈值 = 屏高 **30%**（≈912 px，1904x3040），硬编码 `home.c:31` | 无（只能适应）；`enable-animations=false` 可让回弹变成瞬切，但不是「变短」 | **值得上游**：把它做成 `mobi.phosh.shell` 的 double 键（`home-drag-threshold`，[0.1,0.6]）；当前 22 键无一视觉/手势键 |
| P2 | 上滑必须从 15 px home bar 起划 | `exclusive-zone=PHOSH_HOME_BAR_HEIGHT=15`、`drag-mode=HANDLE`（`home.c:151-167`, `home.h:16`） | 无 | **值得上游**：底缘整条可起划（或 `drag-handle-height` 键）——与 phoc #385（下拉悬停）同一讨论面 |
| P3 | 拖拽被接受时表面「跳一下」 | 上游 phoc **!828**（opened 2026-11-20）复现的正是此现象；本机 phoc 0.46 无补偿 | 无 | **需下游补丁（等上游）**：!828 合入前要自行 backport；本机可先提供 1904x3040 + lisgd 日志证据 |
| P4 | 边缘侧滑返回 | 上游无（phoc #125 open 6 年）；本机 lisgd 链路 **PASS**（§2.4） | ✅ 已有；手感旋钮 = `ELDEN_SWIPE_EDGES`、lisgd `-t/-T`、`ELDEN_SWIPE_HAPTIC*`（改 `/etc/conf.d/lisgd-edge-swipe`，本轮不动） | **值得上游**：把 #125 当作「要什么」的原始需求；我们的 lisgd+uinput 方案可作为「用户态可行做法」证据回帖，**不构成上游提交候选**（D13 结论未变） |
| P5 | 顶栏图标顶到屏幕圆角 | gmobile 无 elden 面板数据（26 条无命中）⇒ `border_radius=0` ⇒ 不内缩 | ❌ 纯配置不可达 | **需下游补丁 / 值得上游**：`lenovo,elden.json`（`corner-radii` 需实测/查面板规格）→ 提交 gmobile；本地想立刻生效只能重编 libgmobile（下游补丁） |
| P6 | 刘海/挖孔遮罩 | 同上（无 cutout 数据） | ❌ | **值得上游**（同一份 JSON） |
| P7 | 手势到 overview 无过渡（zoom） | 0.46 无（0.57 引入且默认关；0.58/0.59 完成于 phosh !1944 + phoc !804） | ❌ 本机不可达 | **需下游补丁/升级**：phosh+phoc 升到 ≥0.58（含 schema 迁移 `sm.puri.phosh`→`mobi.phosh.shell`，需迁移验证） |
| P8 | 全部动画时长固定（400/200/150/150 ms） | phosh `revealer.c:194`、`app-grid.c:783`；phoc `view.c:28`、`gesture-swipe.c:21` | 只有全有/全无（`enable-animations`） | **值得上游**：`animation-speed` 倍率键（GNOME Shell 有 `org.gnome.desktop.interface` 之外的先例，如 `gtk-enable-animations` 粒度太粗） |
| P9 | 无窗口退场动画 / 无焦点框 | phoc 0.46 无；上游 0.58+ 有 `mobi.phosh.phoc focus-frame`（默认 true） | ❌ | **需下游补丁/升级**：focus-frame 只需升级 phoc ≥0.58（+ phosh 消费） |
| P10 | overview 折叠末尾闪烁 | 上游 phosh **#1368**（open 2026-11-23） | ❌ | **值得上游（先跟踪）**：属上游在办，等修；本机可在升级后复测 |
| P11 | 缩放导致手势/应用步进 | 上游 phoc **#293**（open 2023-12）；本机 `scaling-factor=0` 自动 | 可试固定 `[output:DSI-1] scale=`（需改 `/usr/share/phosh/phoc.ini`，属写操作） | **值得上游**：本机 1904x3040 + 自动 scale 是良好复现面，可提供数据 |
| P12 | 动效总闸粒度 | `enable-animations=true` 只有布尔 | ✅ 唯一现成旋钮 | 见 P8 |
| P13 | 主题/配色/字体观感 | `Adwaita` + `prefer-dark` | ✅ `gtk-theme`/`color-scheme`/`icon-theme`/`text-scaling-factor` | 配置即可（无上游必要） |
| P14 | GTK 级圆角/阴影微调 | 无用户 CSS | ⚠ 可建 `~/.config/gtk-3.0/gtk.css`（phosh 是 GTK3 应用）**但生效性与副作用未证实**（需设备窗） | 不建议上游（hack） |
| P15 | 触觉反馈 | 已接 `ffrumble`，左右马达分侧，25 ms | ✅ `ELDEN_SWIPE_HAPTIC=0/1`、`ELDEN_HAPTIC_{DEV,MS,MAG}` | **值得上游（弱）**：上游无「手势触觉」概念（phosh 无 vibrate portal 消费），可作 #125 讨论的补充诉求 |
| P16 | `close` 键绑定含 `XF86Back` | `['<Alt>F4','XF86Back']`（D13 必需） | ✅ `gsettings set`（已在位） | 不需上游（属 D13 已闭环工程） |

### 5.1 手感/观感免责（本轮的边界）

以下结论**本轮不做**，均需 **设备窗 + 人目视**（列成下轮验收清单，不在此判优劣）：
1. P1/P2 的实际「划多远才顺」「底部起划够不够」；2. P3 的跳变幅度是否可感；3. P5/P6 圆角与挖孔是否真的顶到（1904x3040 面板四角是否物理圆角**未证实**）；4. P8/P9 的动效快慢、是否有拖影/撕裂（60 Hz 面板块度未知）；5. P15 触觉强度/时长是否合适；6. D13 遗留的三项人手项（OSK 弹出时左缘滑动、全屏视频内滑动、真人左缘滑动）。

---

## 6. 上游可投递项清单（**只列，不起草、不发送**）

> 纪律：投递权在用户；`AGENTS.md`「上游发信」= 开头披露 AI 辅助 + 每条论断可复现证据 + 逐条回应。本清单仅给「投什么、投到哪、凭什么」。

| U# | 目标仓库/载体 | 形态 | 一句话内容 | 我方证据就绪度 |
|---|---|---|---|---|
| U1 | `World/Phosh/gmobile` | **MR（新 JSON）** | 新增 `data/devices/display-panels/lenovo,elden.json`：`x-res 1904 / y-res 3040 / corner-radii[…] / width,height`（有 cutout 再补） | **缺一件**：`corner-radii` 与物理 mm 尺寸需实测/查规格（本轮未取到）；格式已核（fp5 样例） |
| U2 | `World/Phosh/phosh` | **issue（特性请求）** | `mobi.phosh.shell` 增 `home-drag-threshold`（double，[0.1,0.6]）与 `animation-speed`（double 倍率），替代 `home.c:37`/`revealer.c:194`/`app-grid.c:783` 硬编码 | 就绪（源码行号 + 当前 22 键清单 + 现状值 0.3/400/200） |
| U3 | `World/Phosh/phoc` **!828** | **MR 评论（复现数据）** | 在 !828 下补「1904x3040 @ phoc 0.46 + lisgd 驱动」的跳变实测（before/after 位移曲线或视频） | 部分（需设备窗补录；本轮仅有代码级证据） |
| U4 | `World/Phosh/phoc` **#293** | **issue 复现** | 提供 1904x3040 + `scaling-factor=0`（自动）下的步进量化 | 部分（需设备窗） |
| U5 | `World/Phosh/phoc` **#125** | **issue 评论（workaround 证据）** | 说明「lisgd 读 evdev + 只广告 KEY_BACK 的 uinput + `wm.keybindings close` 含 `XF86Back`」在 phoc 0.46 上端到端可用；若上游要内建，需注意「只广告 KEY_BACK 才不被当 hw keyboard」这一约束 | **就绪**（D13 端到端 PASS + 日志） |
| U6 | `World/Phosh/phoc` **#385 / #376** | **issue 评论** | 平板形态下「底部任意位置下拉=reachability」「禁用边缘平铺」的诉求与我们的 `exclusive-zone=15px` 观察 | 部分（需人目视确认诉求真实性） |

**明确不投**：P13（主题/配色，属用户偏好）、P14（GTK 用户 CSS hack）、D13 的 lisgd 链路本身（用户态 workaround，不进上游树）。

---

## 7. 未取到 / 工具事实（给下一轮省时间）

1. **GNOME GitLab `/search` 端点需登录**（匿名 401）；匿名可用的只有列表端点（`?state=&updated_after=&per_page=100`）⇒ 关键词过滤改在本地做（本轮做法）。
2. **GitLab 匿名 API 会命中 406**（Fastly 限速）：连发超过 ~10 次 `projects/<id>/<res>/<iid>` 单件请求即 406；退避后用列表 JSON 已够（本轮即如此）。
3. **keyring 已锁**（`secret-tool: Cannot get secret of a locked object`，`host gitlab.gnome.org` 两种 lookup 均失败）⇒ 本轮全部走匿名 API，无 token 落盘。
4. **`phosh --version` 不存在命令**（phosh 装的是 `/usr/libexec/phosh`，`DPKG` 里无 `bin/phosh`）⇒ 版本一律用 `dpkg -l`。
5. **phoc 的配置路径硬编码**：`-C /usr/share/phosh/phoc.ini`（`pgrep -a phoc` 逐字）⇒ `~/.config/phoc.ini`、`/etc/phoc.ini` **不被消费**（两者本机 absent）。
6. **gmobile 只读内置 gresource**（`gm-device-info.c:15-22`）⇒ 加设备 JSON 必须重编或上游收；本机「丢文件」方案无效。
7. **0.59 的 schema 迁移**（NEWS：「Migrate gsettings schema to `mobi.phosh`」）⇒ 若升级，设备上所有 `sm.puri.phosh.*` 的 dconf 值需要迁移；phoc 侧 `sm.puri.phoc` 上游保留为 legacy（`mobi.phosh.phoc` 为新增）⇒ `auto-maximize=false` 这类现值升级后仍在，但 `sm.puri.phosh` 面要逐键核对。
8. 本轮**未做**：任何设备写操作、`gsettings set`、服务重载、CSS 落地、上机目视、MR/issue 投递。

---

## 8. 复现命令（全部只读）

```bash
# 1) 设备侧一次性取证（159 行；脚本只含读命令）
cd /home/xuqianhui/y700-elden && sh reports/artifacts/phosh-gestures-20261128/probe-device-readonly.sh \
  | tee reports/artifacts/phosh-gestures-20261128/device-probe.log

# 2) 上游 90 天窗口 MR/issue（匿名 API，两个项目；>10 次单件请求会 406）
curl -sS --noproxy '*' "https://gitlab.gnome.org/api/v4/projects/16747/merge_requests?state=all&updated_after=2026-08-29T00:00:00Z&per_page=100&order_by=updated_at" \
  -o reports/artifacts/phosh-gestures-20261128/gl-16747-merge_requests.json
curl -sS --noproxy '*' "https://gitlab.gnome.org/api/v4/projects/16763/issues?state=all&updated_after=2026-08-29T00:00:00Z&per_page=100&order_by=updated_at" \
  -o reports/artifacts/phosh-gestures-20261128/gl-16763-issues.json

# 3) 上游「有没有手势/动画键」的权威判据
curl -sS --noproxy '*' "https://gitlab.gnome.org/api/v4/projects/16747/repository/files/data%2Fmobi.phosh.shell.gschema.xml/raw?ref=main" | grep -E "<key name"
curl -sS --noproxy '*' "https://gitlab.gnome.org/api/v4/projects/16763/repository/files/data%2Fmobi.phosh.phoc.gschema.xml/raw?ref=main"

# 4) gmobile 设备表（38 条上游 / 26 条设备侧；均无 lenovo,elden）
curl -sS --noproxy '*' "https://gitlab.gnome.org/api/v4/projects/22559/repository/tree?ref=main&path=data/devices/display-panels&per_page=100"
ssh elden 'gresource list /usr/lib/aarch64-linux-gnu/libgmobile.so.0 | grep -c display-panels'

# 5) 源码级常量（本机缓存 /tmp/ph046，缺失则从 Debian source 重新解包）
grep -n "PHOSH_HOME_DRAG_THRESHOLD\|PHOSH_HOME_BAR_HEIGHT" /tmp/ph046/phosh-0.46.0/src/home.c /tmp/ph046/phosh-0.46.0/src/home.h
grep -n "hdy_get_enable_animations" /tmp/ph046/phosh-0.46.0/src/animation.c
grep -n "CAPTURE_THRESHOLD_MS" /tmp/ph046/phoc-0.46.0/src/gesture-swipe.c
grep -n "PHOC_ANIM_DURATION_WINDOW_FADE" /tmp/ph046/phoc-0.46.0/src/view.c
grep -n "get_corner_shift" -A12 /tmp/ph046/phosh-0.46.0/src/layout-manager.c
```
