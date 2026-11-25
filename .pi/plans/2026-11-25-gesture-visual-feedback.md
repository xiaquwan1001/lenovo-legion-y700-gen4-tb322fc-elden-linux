# 2026-11-25 · 侧滑返回的「视觉/触觉反馈」怎么做（只读设计 lane）

> **一句话推荐**：**先只做触觉（已落地的 `elden-swipe-back`，把 `ffrumble` 改后台）+ 5 分钟 phoc touch-points 视觉探针**；
> 边缘指示条要自写 evdev→layer-shell 客户端（≈1–3 天）；窗口滑出/缩小动画**只能改 phoc**（0.46 只有入场 150 ms 淡入，无退场动画）。
>
> **三个数字**：工时 **≤30 min**（触觉收尾 10 min + 探针 5 min，指示条另算 1–3 天）· 风险 **低**（零 phoc 改动，回退=改回一条命令）· **不需要改 phoc**。
>
> **口径**
> - 设备现役：Debian trixie、phoc 0.46.0-1 / phosh 0.46.0-3、1904×3042、无返回键；返回链已实测通（`lisgd` → `uinput-back` → KEY_BACK → `wm.keybindings close` 的 `XF86Back`）。
> - 源码取证：本机缓存 `/tmp/ph046/{phoc,phosh}-0.46.0/`（原版）；`/tmp/lisgd.c`（lisgd 主分支源码，2026-11-25 取，674 行）；上游 GitLab API **本 lane 现查，访问日 2026-11-25**。
> - 本 lane **未 ssh、未上机、未改任何既有文件、未发信**；唯一新增物 = 本文件。
> - `patches-userland/build-phoc-phosh.sh` 的 `PHOC_VER=0.55.1`（Alpine 线）与设备 0.46 **不是同一代**，行号勿混用；本文行号一律指 0.46。

---

## 0. 现状：触觉件在本 lane 期间已经落地（commit `68062bcf`），但有两处要修

`packaging/elden-userland/files/usr/local/bin/elden-swipe-back`（21 行，`lisgd-edge-swipe` 的默认
`BACK_CMD` 已指向它）做的是「先 `ffrumble` 再 `exec uinput-back`」。方向对，**两处与代码事实不符**：

| # | 问题 | 证据 | 后果 |
|---|---|---|---|
| **F1** | 注释写「ffrumble 是 fire-and-forget，不阻塞」，但 `ffrumble` **前台 sleep `ms+50`** 才退出 | `scripts/ffrumble.c:110`（`sleep_ms(ms + 50)`）、`:41-47`（nanosleep 循环） | 默认 `MS=25` ⇒ 每次手势把 `KEY_BACK` **推后 ~75 ms**；又因为 `lisgd` 用 `system(cmd)` **同步**执行回调（`/tmp/lisgd.c:236`），lisgd 事件循环再被占 ~575 ms（叠加 `uinput-back` 自己的 400 ms 建设备等待，`tools/uinput-back.c:30,153`） |
| **F2** | 复用了 `ELDEN_BACK_CMD` 作为「真正的注入器」变量名 | `elden-swipe-back:15`（`BACK=${ELDEN_BACK_CMD:-…}`）；同名变量在 `lisgd-edge-swipe:48` 表示「手势回调」 | 一旦有人按旧文档在 `/etc/conf.d/lisgd-edge-swipe` 写 `ELDEN_BACK_CMD=/usr/local/bin/elden-swipe-back`，wrapper 会 `exec` **它自己** ⇒ 无限 `exec` + 每轮再振一次（表现为持续振动 + 单核 100%） |

**建议的最小修正（下一轮改这一处即可，本 lane 不落盘）**：

```sh
#!/bin/sh
# elden-swipe-back — 手势「返回」：先起振（不阻塞），再发 KEY_BACK。
set -u
# 变量名故意用 ELDEN_BACK_BIN：ELDEN_BACK_CMD 是 lisgd-edge-swipe 的「手势回调」，同名会自 exec。
BACK_BIN=${ELDEN_BACK_BIN:-/usr/local/bin/uinput-back}
if [ "${ELDEN_SWIPE_HAPTIC:-1}" = 1 ] && command -v ffrumble >/dev/null 2>&1; then
	# ffrumble 自己会 sleep ms+50 才返回（scripts/ffrumble.c:110）⇒ 必须后台 + setsid，
	# 否则把 KEY_BACK 推后 ms+50，且 lisgd 的 system() 会跟着卡住。
	setsid ffrumble "${ELDEN_HAPTIC_DEV:-/dev/input/event2}" \
	                "${ELDEN_HAPTIC_MS:-40}" "${ELDEN_HAPTIC_MAG:-0x8000}" \
	                </dev/null >/dev/null 2>&1 &
fi
exec "$BACK_BIN"
```

> 还可以更进一步（可选，收益=手势后 lisgd 立刻回到监听态）：把整条链一起 detach —
> `setsid sh -c 'ffrumble … & exec uinput-back' </dev/null >/dev/null 2>&1 & exit 0`。
> 代价是快速连划时会有多份并行的 uinput 设备（各 500 ms 后自毁），需要实测。

---

## 1. 三条反馈路径：今天能靠什么

### 1.a 触觉 —— **今天就能做，成本最低（推荐）**

**硬件/工具事实（已实测，不重做）**
- 两枚 FF 节点：`/dev/input/event2` = 马达 A = i2c `6-005a`（左）、`/dev/input/event3` = 马达 B = `6-005b`（右）
  （`reports/motor-haptics-vk127-20261017.md:12`、`.pi/memory/notes-q28-vk127-20261017-18.md:32`）。
- `ffrumble [dev] [ms] [magnitude]`：默认 `/dev/input/event2 600 0xffff`；`ms` **十进制**（`atoi` 语义）、
  `magnitude` 支持 `0x`；`strong=weak=mag`；行为**前台阻塞 `ms+50`**（`scripts/ffrumble.c:16-20,50-52,110`；
  规格 `packaging/elden-userland/sources/ffrumble/README.md`）。`ffrumble` 是**直连 evdev 的阳性对照**，
  绕过 `elden-hapticd`（后者的 `amplitude=0` 会静音，`reports/motor-haptics-vk127-20261017.md:41`）。
- 权限：`lisgd-edge-swipe` 是**系统级** unit（无 `User=`，以 root 跑，`out/units/systemd/lisgd-edge-swipe.service`）
  ⇒ wrapper 以 root 打开 `event2`，**不依赖** `input` 组/udev 规则（若改成 `systemctl --user` 的用户 unit 则要另查
  `/dev/input/event*` 的可写性——这是本 lane 无法 ssh 验证的一点，见 §4 R3）。

**具体命令（三条，逐条可判）**

```sh
# 1) 链路基线：两个马达各响一次（人手可感即过；rc=0 且打印 rumble ON）
ffrumble /dev/input/event2 40 0x8000 ; echo rc=$?
ffrumble /dev/input/event3 40 0x8000 ; echo rc=$?

# 2) 证明它「阻塞 ms+50」——这是 F1 的取证，也是「必须后台」的理由
time ffrumble /dev/input/event2 25 0x8000      # 期望 real ≈ 0.08–0.10s（不是 0.025s）

# 3) 定向手感：左边缘振左马达、右边缘振右马达（不需要第二个脚本，
#    lisgd 的回调走 /bin/sh -c，env 前缀合法；改 /etc/conf.d/lisgd-edge-swipe 或在 unit 里写死）
#    左：-g "1,LR,L,*,R,/usr/local/bin/elden-swipe-back"
#    右：-g "1,RL,R,*,R,ELDEN_HAPTIC_DEV=/dev/input/event3 /usr/local/bin/elden-swipe-back"
```

**为什么「不影响关窗时序」**（把论证摊开，别只写结论）：
1. `KEY_BACK` 的**发出时刻**由 `uinput-back` 决定：`UI_DEV_CREATE` 后固定等 `CREATE_SETTLE_MS=400`
   （`tools/uinput-back.c:30,153`）才写 key。这个 400 ms 是本链**固有**延迟，与振不振无关。
2. `ffrumble` 若前台跑，会在 400 ms 之外**再加** `ms+50`（默认 75 ms）——这就是 F1，必须后台化。
3. 后台化后两条是**并发**的：`setsid ffrumble … &` 立刻返回，`exec uinput-back` 随即开始建设备
   ⇒ 振感在 **t≈0**（抬手瞬间）出现，关窗仍在 **t≈400 ms** 发生，二者时间线不变。
4. 反过来看，这 400 ms 的空白正是触觉最值钱的地方：**手感先到、窗口后关**，用户不会觉得"卡"。
5. 若还想让 lisgd 不被 `system()` 卡 500 ms（F1 的第二个后果），用 §0 的可选 detach 形态。

**强度/时长标定建议（需上机，属"手感"不是"能否"）**：
`MS` 取 **40 ms** 起步（`25` 对 aw86927 的 CONT 包络偏短，`reports/motor-haptics-vk127-20261017.md:41-53` 说明了
"前强后弱"是厂商包络、不是驱动漏写）；`MAG` 三档试 `0x4000 / 0x8000 / 0xffff`。
`MS≥120` 会变成"嗡"，不适合"咔"的手感。

**失败判据**

| 现象 | 判据 | 处置 |
|---|---|---|
| 完全不振、`rc≠0` | `ffrumble: EVIOCSFF …（该节点不支持 EV_FF？）` 或 `open …: No such file` | 节点名/编号漂了：`for e in /sys/class/input/event*; do cat $e/device/name; done \| grep -n aw86927` |
| 振但明显滞后（>0.5 s） | 手感 + 上面 `time` 判据 | wrapper 里 ffrumble 还在前台（F1 没修） |
| 手势后**窗关了但没振** | `/var/log/lisgd-edge-swipe.log` 有 `Execute …`，`getevent` 在 `event2` 上无 `EV_FF(0x15)` | 部署件不是新 wrapper（`command -v elden-swipe-back`）、或 `ELDEN_SWIPE_HAPTIC=0`、或 `ffrumble` 不在 PATH |
| **持续振动 / 单核 100%** | 一直嗡嗡、`top` 见 100% | 命中 F2 自 exec：`grep ELDEN_BACK_CMD /etc/conf.d/lisgd-edge-swipe` |
| 锁屏/空桌面上滑也振 | — | **已知**：lisgd 不知道有无焦点；phoc 的 `handle_close` 在无焦点时是 no-op（`src/keybindings.c:156-163`）⇒ 只有振、没有动作。要消掉需要"先查焦点再振"，lisgd 做不到（见 1.b） |

**风险**：① 无焦点也振（假确认，可接受/或靠 1.b 修）；② 一次手势两声（左右两条 `-g` 不会同时命中——`edge` 判据互斥，
但**同一侧连续快划**会叠加两发，短促时可感到"双击"）；③ 与 OSK 每键震动共用马达，写输入法时可能撞车（同一节点
并发 `EVIOCSFF` 由内核 ff-core 串行化，功能上安全，手感上偶尔会"吃掉"一下）；④ 节点编号重启漂移（系统级 wrapper
可在开头按 `device/name == aw86927-haptics` 校验再决定振，失败静默）。

### 1.b 边缘指示条 / 弧形 —— **能做，但要自写客户端（今天做不完）**

**先回答关键障碍（题面里那条判断是对的）**：
- `lisgd` **只知道「手势完成」**：坐标只用于内部判定（`/tmp/lisgd.c:84` 的 `xstart/xend` 全局数组；`touchdown:295` / `touchmotion:318` / `touchup:356`），
  **从不外传**给回调命令；回调只在 `touchup` 或 `ActModePressed` 分支里 `system()`（`:236,343,395`）。
  所以「实时位移」这件事用 lisgd 拿不到。
- `zwp_input_method` 无关；`wl_touch` 也拿不到：layer-shell 客户端只在**自己表面上有触摸**时收事件，
  而我们的指示条必须 `input_region = 空`（否则它会把返回手势本身吃掉）。
- ⇒ **要实时反馈就得自己读 evdev/libinput**（和 lisgd 并行读同一个触摸屏节点是允许的：两边都是非 grab 的普通 reader；
  只有 `EVIOCGRAB` 才独占，见 `PITFALLS #656`）。

**min 版设计（wlr-layer-shell + `wl_shm` 画矩形）**

| 部件 | 做法 | 关键点 |
|---|---|---|
| 连接/绑定 | `wl_display_connect` + 绑 `wl_compositor`、`wl_shm`、`wl_output`、`zwlr_layer_shell_v1` | 协议 XML 仓内已有：`external/phoc-work/phoc/subprojects/wlroots-0.20.x/protocol/wlr-layer-shell-unstable-v1.xml`（0.20 版协议，phoc 0.46 实现同一接口）；`wayland-scanner` 主机在位 |
| 表面 | `layer = OVERLAY`、`anchor = LEFT`、`size = 24 × H`、`namespace = "elden-edge-bar"`、`exclusive_zone = -1` | 必须 `wl_surface_set_input_region(空)`：**这条漏了会吃掉手势**，是这种客户端最常见的自伤 |
| 画 | 单 buffer（`wl_shm` + `memfd`，ARGB8888）×2 轮换，画一条圆角柱（或 3 段渐变矩形），只用 `damage` 局部提交 | 不用 cairo 也能画矩形；圆角要 cairo/pixman，先不做 |
| 输入 | 第二个线程用 **libinput path 后端**读触摸屏节点（与 lisgd 同法：`libinput_event_touch_get_{x,y}_transformed(w,h)`，`/tmp/lisgd.c:296-330`） | 用 libinput 而不是裸 evdev：省掉 `EVIOCGABS` 量程换算与 phoc 的 1904×3042 逻辑坐标映射 |
| 状态机 | touch down 且 `x ≤ 60` → 显示；motion → 柱长 = `min(x,240)`、alpha 随 `x/240`；up → `x≥60` 时快速闪一下再淡出（120 ms），否则立刻收回 | 只重画变化帧；60 Hz 下 evdev→屏 <2 帧（≈32 ms） |
| 落点/判据 | `PoC`：手指从边缘划出，柱随手指长出来；`失败`：柱挡住手势（input_region 没设空）、或柱在 OSK 之上遮住键盘（z 序问题，见下） | |

**工时估计**：裸 wayland + `wl_shm` 版 **≈300 行 C，2–3 天**（含上机调，不含"好看"）；若改用 **GTK3 + `gtk-layer-shell`**
（Cairo 画圆角/渐变，代码 ≈120 行）**≈1 天**，但要额外打包 `libgtk-layer-shell0/-dev`（Debian trixie 有；
phosh 0.46 自己**不用** gtk-layer-shell，它用自研 `PhoshLayerSurface` 直接走 `zwlr_layer_shell_v1`，见 `phosh/src/layersurface.c:369`）。

**风险**：① **z 序**：phoc 渲染顺序 = 视图 → TOP 层 → drag icons → **OVERLAY 层** → debug 触点（`phoc/src/render.c:505-521`），
OSK 也被提升到 overlay（`phoc/src/layer-shell.c:452-501`）⇒ 两个 overlay 表面谁在上按创建顺序，键盘弹出时可能被柱子盖一下
（纯视觉，但要有预期）；② 第二个 reader 在 suspend/resume 后要重连（lisgd 已有同样问题，A7 判据同源）；
③ 竖/横屏旋转（`orientation`）要跟着换算；④ 指示条**不会**让窗口跟着手指走——那是合成器的事（见 1.c），别把两者混为一谈。

**5 分钟"零代码"替代（只用于验证"实时视觉可行"，不是产品）**：phoc 0.46 自带 touch-points 调试渲染
（`phoc/src/render.c:287-300`、`server.c` 的 DebugControl 属性 `TouchPoints`、`main.c:90` 的 `touch-points` debug flag），
D-Bus 一开就能看到「手指下面的圆点」，且**不影响输入**：

```sh
gdbus call --session --dest mobi.phosh.Phoc.DebugControl \
  --object-path /mobi/phosh/Phoc/DebugControl \
  --method org.freedesktop.DBus.Properties.Set \
  mobi.phosh.Phoc.DebugControl TouchPoints "<true>"
# 关：同上，把 "<true>" 换成 "<false>"
```
判据：真手指按在屏上任意位置出现圆点、抬手消失。**失败**（无圆点/报错）= DebugControl 属性名或版本不符，说明该版 phoc
没编译进这条调试路径——那就别指望"零代码视觉"，直接按上面的自写客户端排期。

### 1.c phoc 内建动画（窗口滑出/缩小）—— **0.46 没有，只能改 phoc**

**0.46 的动画家底（源码核实）**

| 事实 | 位置 |
|---|---|
| 通用动画框架齐全：`PhocTimedAnimation`（时长+帧回调驱动）、`PhocAnimatable`（挂在 output 帧时钟上）、`PhocPropertyEaser`（对 **GObject 属性**做缓动） | `phoc/src/anim/{timed-animation,animatable,property-easer}.c`；用法示例 `src/cursor.c:295-302`、`src/desktop.c:1344-1356`、`src/output-shield.c:276` |
| `PhocView` 有可动画的 `alpha` 属性，渲染时按它做透明度（`render.c:241` → `view_render_to_buffer_iterator` `render.c:307`） | `phoc/src/view.c:1605-1615,2139-2154`；`view.c:1884-1889` 属性定义 |
| **唯一的窗口动画 = 入场淡入 150 ms**：`phoc_view_map()` 里 `alpha 0→1`，条件是 `enable_animations && parent==NULL && !want_auto_maximize` | `phoc/src/view.c:28`（`PHOC_ANIM_DURATION_WINDOW_FADE 150`）、`:1301-1316` |
| **没有任何退场/滑出/缩小**：`phoc_view_unmap()` 直接摘视图、清 `wlr_surface`，不播动画 | `phoc/src/view.c:1344-1400` |
| 「关闭」是客户端自决：`close` vfunc 只 `wlr_xdg_toplevel_send_close()`，随后客户端自己 unmap | `phoc/src/xdg-surface.c:309-320`；`phoc/src/keybindings.c:156-163` → `phoc_view_close()` `view.c:2255` |
| 动画总开关：`org.gnome.desktop.interface enable-animations` + `--debug disable-animations` | `phoc/src/desktop.c:686-690,854-869`；`src/main.c:97` |

**上游现状（GitLab API，访问日 2026-11-25）**
- phoc **#27「Slide in/out animations」**：opened 2019-06-17，**closed 2023-03-17**，原文「We need these for layer surfaces…」
  ⇒ 结题范围是 **layer surface**（phosh 自己的 shell 表面），**不含 app view**。
- phoc **#292「layer-shell-effects: Add FadeableLayerSurface」**（opened 2023-03-15）、**#146「allow to fade in layer surfaces」**
  （opened 2020-07-19）**仍未关闭**，且**依旧是 layer surface**。
- MR **!440「Make view alpha a property and fade in toplevels on map」**（merged 2023-05-21）= 0.46 的那条淡入。
- 检索式：`issues?search=animation|minimize|fade`、`merge_requests?search=animation`（`/api/v4/projects/World%2FPhosh%2Fphoc/...`）。
- 结论：**"关窗时窗口滑出/缩小"在上游不存在、也没人在做**；如要做，理论上是新 feature（`phoc` #125「back gesture」同族）。

**若真要改：最小改动点与回归面**

| 方案 | 改动点 | 量级 | 回归面 |
|---|---|---|---|
| **c1（最小可行）：关窗淡出** | 在 `xdg-surface.c:_close()`（`:309`，所有 close 入口汇聚：keybinding / foreign-toplevel / overview）里，`enable_animations` 时先播 `PhocPropertyEaser` 把 `view` 的 `alpha 1→0`（150 ms，`PHOC_ANIM_DURATION_WINDOW_FADE` 同款），动画结束再 `wlr_xdg_toplevel_send_close()` | ~40–60 行 C，**要重编 phoc**（`scripts/phoc-install.sh` 的 divert+hold 纪律） | 客户端在 150 ms 内仍活着（用户可能再点它）；`enable-animations=false` 时必须逐字节等价；damage/帧循环（`phoc_animatable_add_frame_callback` 已要求"自己 damage"） |
| **c2（真"滑出/缩小"）** | 需要给 view 渲染加**位移/缩放变换**：`render.c` 的 `view_render_to_buffer_iterator`（`:300-340`）与命中测试（`view.c` 的 `get_wlr_surface_at`/`box` 系列）都要跟着变；同时不能用 `phoc_view_move()` 逐帧挪（会与 layout-transaction / `desktop.c` 重排打架） | ~150–250 行 + 若干处 `box` 同步，2–4 天 | **大**：焦点框/窗口装饰（`view-deco.c`）、全屏、OSK 提升、Waydroid（一个 view 里跑整个 Android）、damage 残留；每次 phoc 升级 rebase（0.46 → 0.55 之间 `render.c`/`view.c` 都改过） |
| **c3（不改 phoc 的"伪动画"）** | 用 1.b 的 overlay 客户端在**手势期间**画一条"窗口向边缘收缩"的暗色遮罩，制造"要被推走"的暗示；窗口本身还是 400 ms 后瞬间消失 | =1.b 的成本 | 与 1.b 相同；**不是**真动画（窗口内容不跟手），别宣称"类 Android" |

> 口径提醒：题面里"phoc 内建动画"这条路在本机型上等价于**重编 phoc + divert/hold + 每次升级 rebase**。本项目当前设备侧
> phoc 是 Debian 发行版件（0.46.0-1），改它就要进 `scripts/phoc-install.sh` 的维护面——这是"要不要立项"的问题，不是"能不能"。

---

## 2. 与现有手势的兼容面：**哪些手势位不能碰**

按"已经在用这个边缘/区域的东西"列清单（触摸屏 1904×3042；我们的手势 = 左右边缘 50 px 起手、水平 ±20°、单指、抬手触发）：

| # | 区域/场景 | 谁在用 | 证据 | 我们能不能碰 |
|---|---|---|---|---|
| 1 | **顶边 ≤10 px（全屏视图时）** | phoc 的 shell reveal：触摸落在顶边 10 px 内 ⇒ `phoc_output_force_shell_reveal()`，且**这次触摸不再转发给应用** | `phoc/src/cursor.c:778-846,1551-1556`；阈值 `src/cursor.h:31`（`PHOC_SHELL_REVEAL_TOUCH_THRESHOLD 10`） | **不能碰**（只有 top 锚定的 TOP 层存在时才生效=顶栏；左右两侧不在此列） |
| 2 | **顶边整条 + 下拉** | phosh 顶栏拖动（通知/快捷设置抽屉）：`PhoshDragSurface` | `phosh/src/top-panel.c:436,731-743`；`src/drag-surface.c` | **不能碰**（我们的左右边缘手势起点 y 若在顶栏高度内，会与下拉争焦点） |
| 3 | **底边 + 上滑** | phosh home bar（高 **15 px**）拖动 → overview / 解锁 | `phosh/src/home.c:462-517,725`；`home.h:16`（`PHOSH_HOME_BAR_HEIGHT 15`） | **不能碰**（竖划本来就不匹配我们的 LR/RL；但**贴底左角**的横划有可能既触发 home 又触发返回） |
| 4 | **OSK 弹出时的下半屏** | `phosh-osk-stub` 的 overlay 层表面 | `phoc/src/layer-shell.c:258,452-501`；`scripts/ime-single-stack.sh` | **要实测**：lisgd 不认 layer，OSK 键区左边缘横划会**照样触发返回**（这是 lisgd 路线的结构性缺陷） |
| 5 | **全屏视频** | ① 顶边 reveal（同 #1）② 应用自己的手势 | 同 #1 | 左右边缘可用；顶边别碰；应用内双动作见 #7 |
| 6 | **锁屏 / 无焦点** | phosh 锁屏是 layer surface（`phosh/src/lockscreen.c:945-962`） | 同上 | 安全但**无意义**：`phoc_seat_get_focus_view()` 为空 ⇒ `handle_close` no-op（`seat.c:1247-1259`、`keybindings.c:156-163`）⇒ 只有触觉/视觉，没有动作 |
| 7 | **应用内左边缘手势** | GTK/libadwaita 的 swipe-back、Firefox 历史滑动、地图平移 | 应用侧（不在本仓） | **已知风险**：lisgd 不消费触摸 ⇒ 可能"页面后退 + 窗口关闭"双动作（先前 lane 的 H1/H2 判据） |
| 8 | **双指及以上** | 未占用（lisgd 只绑 `nfingers=1`） | `lisgd-edge-swipe:68,71` | 空闲，可留给未来（但别在 PoC 阶段扩，免得误触面变大） |
| 9 | **XWayland 客户端** | Waydroid 整个容器 = 1 个 view | 先前 lane §路线③ | 语义是"关容器窗"，不是 Android back（与本 lane 无关但别混） |

**由此得到两条设计约束**：
1. 边缘起手区**越窄越好**（当前 50 px；可用 `lisgd -s` 缩到 10–20 px 降低与应用争抢面），但**不要**为了 OSK 去改 y；
   `lisgd` 没有 y 范围过滤（`gesturecalculateedge` 只看四条边，`/tmp/lisgd.c:178-215`）⇒ "OSK 期间禁用返回"只能用 1.b 那种自写监听器做。
2. **不要碰顶/底边**：我们的手势只注册 `L`/`R`；任何"顺手也支持上下"的扩展都先过 #1/#3 的判据。

---

## 3. 推荐方案 + ≤30 min PoC（零 phoc 改动）

**推荐**：**触觉为主**（`elden-swipe-back` 把 `ffrumble` 改成后台，左右马达定向）+ **phoc touch-points 探针验证视觉可行性**；
指示条留给独立排期（1–3 天）；窗口退场动画**不做**（要重编 phoc，收益/维护比不划算）。

### 3.1 30 分钟时间盒（全部真机可跑、可回退）

**0–5 min：确认底座**
```sh
dpkg -l phoc phosh lisgd | tail -n +6            # 0.46.0-1 / 0.46.0-3 / 0.3.7
gsettings get org.gnome.desktop.wm.keybindings close     # 期望含 'XF86Back'
systemctl is-active lisgd-edge-swipe ; command -v elden-swipe-back uinput-back ffrumble
```

**5–12 min：触觉链路与阻塞取证**
```sh
ffrumble /dev/input/event2 40 0x8000 ; echo rc=$?
ffrumble /dev/input/event3 40 0x8000 ; echo rc=$?
time ffrumble /dev/input/event2 25 0x8000       # 期望 ~0.08–0.10s ⇒ 坐实 F1
```
- **通过**：两侧都有人手可感的"咔"。
- **失败**：`EVIOCSFF`/`open` 报错 ⇒ 先修节点（§1.a 失败表），别往下走。

**12–22 min：把 wrapper 改成非阻塞 + 左右定向（先在 /tmp 验证，不改仓）**
```sh
# a) 用 §0 的脚本内容写一个临时件（关键是 ffrumble 走 setsid 后台、变量叫 ELDEN_BACK_BIN）
cat > /tmp/elden-swipe-back-try <<'EOS'
#!/bin/sh
set -u
BACK_BIN=${ELDEN_BACK_BIN:-/usr/local/bin/uinput-back}
if [ "${ELDEN_SWIPE_HAPTIC:-1}" = 1 ] && command -v ffrumble >/dev/null 2>&1; then
	setsid ffrumble "${ELDEN_HAPTIC_DEV:-/dev/input/event2}" \
	                "${ELDEN_HAPTIC_MS:-40}" "${ELDEN_HAPTIC_MAG:-0x8000}" \
	                </dev/null >/dev/null 2>&1 &
fi
exec "$BACK_BIN"
EOS
chmod 755 /tmp/elden-swipe-back-try

# b) 让手势回调暂时指向它（conf.d 由 systemd unit 的 EnvironmentFile= 读取）
echo 'ELDEN_BACK_CMD=/tmp/elden-swipe-back-try' >> /etc/conf.d/lisgd-edge-swipe
systemctl restart lisgd-edge-swipe

# c) 验完回退（别忘了这一步）
sed -i '/elden-swipe-back-try/d' /etc/conf.d/lisgd-edge-swipe && systemctl restart lisgd-edge-swipe
```
判据（三条，缺一即失败）：
1. 真手指左边缘内滑 ⇒ **先感到一次短振**，随后 ~0.4 s 窗口关闭（顺序对 = 反馈早于结果）；
2. `time` 那条已证 ffrumble 会阻塞 ⇒ 修改后 lisgd 日志里两次 `Execute` 的间隔不再被 75 ms 拖长（快速连划两次即可看出）；
3. **反向判据**：锁屏上滑**会振但不会关**任何东西（这是已知上限，不是 bug）。

**22–27 min：视觉探针（可选）**：执行 §1.b 的 `gdbus … TouchPoints "<true>"`，看圆点跟手；用完关掉。
- **通过** ⇒ "实时视觉反馈"技术上无障碍，可按 1.b 排期。
- **失败** ⇒ 记下报错，视觉路线只能靠自写客户端（不走 debug 面）。

**27–30 min：回退与记录**
```sh
gdbus call --session --dest mobi.phosh.Phoc.DebugControl --object-path /mobi/phosh/Phoc/DebugControl \
  --method org.freedesktop.DBus.Properties.Set mobi.phosh.Phoc.DebugControl TouchPoints "<false>"
systemctl restart lisgd-edge-swipe      # 回到仓内件
```

### 3.2 放弃/降级判据

| 判据 | 含义 | 处置 |
|---|---|---|
| 改了后台化后**手感仍"先关窗、后振"** | ffrumble 没真正后台（被 shell `wait` 住，或 wrapper 里没加 `&`） | 逐行核 `setsid ffrumble … &` 是否在位；仍不对就用 §0 的可选形态（整条链 `setsid sh -c '… & exec uinput-back' &`） |
| 触觉与 OSK 每键震动**互相打断** | 同一节点并发 FF，aw86927 只跑一路 | 手势振改到**另一侧马达**（左滑振 `event2`、右滑振 `event3`，天然分流） |
| OSK 弹出时左边缘滑动**误关窗** | lisgd 结构性缺陷（不看 layer） | 收窄到 `-s 0.2`（10 px）；仍误触 ⇒ 进 1.b 自写监听器（可做 y 过滤） |
| 用户要"类 Android 的窗口跟手" | 只能 c2 | 立项评估：重编 phoc + divert/hold + 每版 rebase（见 1.c） |

---

## 4. 风险与未决（本 lane 不替你拍板）

- **R1（F1/F2 已落地的缺陷）**：`elden-swipe-back` 当前版本把 `KEY_BACK` 推后 ~75 ms 且存在 `ELDEN_BACK_CMD` 自 exec 风险
  （§0）。修复只改 1 个文件 + `MANIFEST.tsv` 的 sha，属"触觉路线能不能收尾"的前提。
- **R2（无焦点假确认）**：锁屏/空桌面滑一下会振但什么都不关；lisgd 拿不到焦点信息（`phoc` 也没有 D-Bus 查询焦点 view 的接口），
  要消掉只能走 1.b 的自写监听器 + `wlrctl toplevel list`/foreign-toplevel `activated` 状态判断。
- **R3（权限/生命周期，本 lane 无法 ssh 验证）**：lisgd 以 root 跑 ⇒ ffrumble 无权限问题；若改成 user unit（先前 plan 的 PoC 形态），
  需确认 uid 1001 对 `/dev/input/event{2,3}` 可写（Debian 默认 `root:input 660`）。另：suspend/resume 后 `eventN` 编号变化
  ⇒ 系统级 unit 有 `Restart=always`，但**马达节点编号也一样会变**（wrapper 里的 `ELDEN_HAPTIC_DEV` 默认值是硬编码的 event2）。
- **R4（1.b 的 z 序/输入区）**：漏设 `input_region` 会吃掉手势；overlay 层与 OSK 的先后顺序未定；旋转后坐标要换算。
- **R5（1.c 的维护面）**：改 phoc = 自行维护一颗 divert 过的二进制；`patches-userland/build-phoc-phosh.sh` 现在写的是 0.55.1（Alpine 线），
  与设备 0.46 不同代，真要改先解决"源码从哪来、跟哪条线"。
- **R6（上游口径）**：phoc #125（back gesture）自 2020 open 至今；动画侧的 #27 只覆盖 layer surface、#292/#146 仍 open。
  任何"view 动画"提案都要先开 issue 对齐设计，否则不会进上游。
- **R7（联网面）**：本 lane 只用了 GitLab API（可达，访问日 2026-11-25）；未用 sourcehut（Anubis 拦），lisgd 事实全部取自
  本机 `/tmp/lisgd.c` 与先前 lane 的检索记录。

---

## 附录 A：本 lane 引用的 file:line 索引

| 事实 | 位置 |
|---|---|
| `ffrumble` 默认值 / 阻塞 `ms+50` | `scripts/ffrumble.c:16-20,50-52,110` |
| `uinput-back` 建设备后固定等 400 ms | `tools/uinput-back.c:30,153` |
| lisgd 回调 = `system()`、同步、不外传坐标 | `/tmp/lisgd.c:215-240,343,395`；坐标仅内部 `xstart/xend`：`:84,296-330` |
| lisgd 边缘判据（无 y 过滤） | `/tmp/lisgd.c:178-215` |
| 手势命令/旋钮 | `packaging/elden-userland/files/usr/local/bin/lisgd-edge-swipe:48,66-80`；`files/usr/local/bin/elden-swipe-back:14-20` |
| 系统级 unit（root 运行） | `packaging/elden-userland/out/units/systemd/lisgd-edge-swipe.service` |
| phoc 动画框架 / view alpha / 入场淡入 / 无退场 | `phoc/src/anim/*`；`src/view.c:28,1301-1316,1344-1400,1605-1615,2139-2154` |
| close 语义（客户端自决） | `phoc/src/xdg-surface.c:309-320`；`src/keybindings.c:156-163`；`src/view.c:2255` |
| 无焦点安全返回 | `phoc/src/seat.c:1247-1259` |
| shell reveal（顶边 10 px，吞触摸） | `phoc/src/cursor.c:778-846,1551-1556`；`src/cursor.h:31` |
| 渲染顺序（OVERLAY 在视图之上；touch points 最后） | `phoc/src/render.c:505-521,287-300` |
| OSK 是 overlay layer | `phoc/src/layer-shell.c:258,452-501` |
| 触屏节点/几何 | `lisgd-edge-swipe:19-46`（`NVTCapacitiveTouchScreen`、DRM modes） |
| 两马达节点映射 | `reports/motor-haptics-vk127-20261017.md:12`；`.pi/memory/notes-q28-vk127-20261017-18.md:32` |
| haptics 静音缺陷（amplitude=0） | `reports/motor-haptics-vk127-20261017.md:41-53` |
| home bar 高度 15 px / 拖动 | `phosh/src/home.h:16`；`src/home.c:462-517,725` |
| 顶栏拖动 | `phosh/src/top-panel.c:436,731-743`；`src/drag-surface.c` |
| phosh 已有 feedbackd 事件 `window-close` | `phosh/src/overview.c:171-177`（`phosh_trigger_feedback("window-close")`） |

## 附录 B：备选——用 feedbackd 的 `window-close` 事件做触觉（"规范出口"，需先验证设备在跑 feedbackd）

phosh 自己在"从 overview 关掉应用"时会发 feedbackd 事件 `window-close`（`phosh/src/overview.c:175`）。
如果设备上 `feedbackd` 在跑且 device theme 把 `window-close` 映射成 Vibra，那么"手势返回"可以用**同一条事件名**，
好处是以后进设置 GUI/静音档案（silent/quiet）都能被用户统一控制：

```sh
# 1) 先确认 feedbackd 在位（本 lane 无法 ssh，未验证）
busctl --user list | grep -i sigxcpu
busctl --user introspect org.sigxcpu.Feedback /org/sigxcpu/Feedback
# 2) 触发一次（方法名/签名以 introspect 结果为准）
busctl --user call org.sigxcpu.Feedback /org/sigxcpu/Feedback org.sigxcpu.Feedback \
  TriggerFeedback 'sa{sv}' window-close 0
```
- **已知坑**：feedbackd 的 `full` 档案默认只映射 Sound，**Vibra 只在 `quiet`**；本仓历史结论见
  `archive/topics/AUDIO-INPUT-2026-10-04.md:121-123`（当时是靠 `gsettings set org.sigxcpu.feedbackd profile quiet` 解决）。
- 因此**当前推荐仍是直连 `ffrumble`**（可控、可验、不依赖主题/档案），feedbackd 只作为"要接系统统一开关时"的升级路线。
