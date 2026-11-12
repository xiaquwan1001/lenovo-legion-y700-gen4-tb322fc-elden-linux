# OSK（虚拟键盘）自动弹出/收起 — 失效面取证与最小处置（2026-11-12）

- 触发：用户 2026-11-12 报「输入虚拟键盘的**自动弹出和收起**现在没做好」。
- 已知不重推：`reports/ime-osk-firefox-rootcause-20261112.md`（根因 = `GTK_IM_MODULE=fcitx` ⇒ 客户端不发 text-input-v3；
  处置 = focusd kimpanel 桥）、`reports/ime-osk-pop-20261111.md`、`PITFALLS #615/#618/#619`。
- 现役方案：phoc 已去版本门 + `fcitx5 --disable waylandim` + phosh-osk-stevia + 自写 `elden-ime-focusd`（kimpanel→`sm.puri.OSK0.SetVisible`）。
- 纪律：只读侦察，未改仓库/未写设备；设备命令经 `scripts/device-lock.sh`。

## §0 状态判定与结论摘要（TL;DR）

### 0.1 设备状态判定（本轮第一动作，原文）

```
$ adb devices
List of devices attached
MDX5T20730009849	device

$ adb shell 'uname -r'
5.10.43

$ adb shell 'getprop ro.build.version.release; getprop ro.product.device; uname -a'
12
HWELS
Linux localhost 5.10.43 #1 SMP PREEMPT Tue Nov 4 14:42:09 CST 2025 aarch64
```

⇒ **平板当前在 Android 12（内核 5.10.43 / `ro.product.device=HWELS`），Linux 根不可达**。
⇒ **本轮无 Linux 设备实测**：没有跑过任何 `SetVisible`/`busctl`/focusd/stevia 的现场命令，
也没有截图。下文所有「实测数据」都是**引用仓库里 2026-11-11 已记录的上机证据**（标了路径），
本轮新增的只有**静态代码/仓库取证**与**判据/测试计划**。**任何条目都不得读成「已修复」**。

### 0.2 结论六行

| # | 结论 | 级别 | 判据 |
|---|---|---|---|
| 1 | **「重启桌面即失效」的最大疑点成立（静态确认）**：现役 Debian 根里 focusd **没有任何自启安装点** —— 无 systemd user unit（全仓 `*.service` 中无 focusd 条目）、`out/stage-debian` 里既无 `usr/local/bin/elden-ime-focusd` 也无 `etc/xdg/autostart/elden-ime-focusd.desktop`；唯一的 `.desktop` 只存在于 **Alpine 世代**的 `rootfs/persistent-overlay/user-autostart/` 与 `patches-userland/zh-ime/`，靠 `scripts/deploy-zh-ime.sh`（squeekboard 时代脚本）或手工 `install` 落到设备 | 静态，确定 | §1.1 的三条 grep/find |
| 2 | **收起判据只有一条** `fcitx5 Controller1.State == 0`：`state==1`（inactive，IC 仍存在）**不收起** ⇒ 焦点移到**同一应用的非输入控件**、或 **Alt+Tab 到另一个有 IC 的窗口**（GTK 前端在建窗时就建 IC）时**漏收**，表现为「关掉输入框了键盘还挂着」 | 静态推断（代码 + fcitx5 状态语义），**须上机验** | `elden-ime-focusd.c:89-98`；§2.3 + §4 判据 T-H1/T-H2 |
| 3 | **误弹有一个确定的触发源**：`SetRelativeSpotRect` 的**矩形参数被完全丢弃**（`(void)params`），连 `(0,0,0,0)` 也算「有人要打字」⇒ fcitx5 建立输入上下文时那次零矩形会弹键盘。`probes/ime/kimpanel-probe.py` 2026-11-11 实测第一次调用正是 `SetRelativeSpotRect (0, 0, 0, 0)` | 静态 + 已有实测 | `elden-ime-focusd.c:137-145`；`reports/ime-osk-firefox-rootcause-20261112.md` §3 探针输出 |
| 4 | **没有超时自动隐藏**：`idle_check` 每秒一次，但只在 `fcitx_state()==0` 时收；应用崩溃/留下僵尸 IC（state 恒 1）时键盘会**永久悬浮**。`fcitx_state()==-1`（fcitx5 不在）时代码**故意不收起**（`elden-ime-focusd.c:80-83`）⇒ fcitx5 崩了键盘也收不掉 | 静态，确定 | §2.4 表 |
| 5 | **抖动/打字卡顿的结构性风险**：`want_keyboard()` 在**每次**光标矩形更新时做一次**同步** D-Bus `Get Visible`（500 ms 超时），而该调用发生在 kimpanel 方法回调里（同一连接、主循环）⇒ 打字时 `SetLookupTable` 被排队在后，且 Get 超时会把本地 `osk_visible` 误置 FALSE 后**重发 show** | 静态，需上机量测 | `elden-ime-focusd.c:44-60, 100-108` |
| 6 | **处置取舍**：(a) 把 focusd 固化成 **systemd user unit**（照 `fcitx5.service` 的既有模式：`/etc/systemd/user` + `graphical-session.target.wants`，`PITFALLS` #540）+ 源码加**零矩形过滤 + 兜底超时 + 非阻塞查询**，改动 1 个新 unit 文件 + 3 处 C 改动 + daily-baseline 1 块，**可在本机做静态/构建验证**，上机只需「重登一次」（≤10 min）；(b) 换单栈（fcitx5 开 `waylandim` + wvkbd）**必须先有 phoc `bb1f7465`**，即重编/升级合成器（15–25 min 编译 + 全量显示回归），且候选窗问题并不因此消失 | 静态评估 | §4 对比表 |

> 一句话：**「没做好」不是弹/收判据全错，而是①桥本身没固化（重登就没了）②收起只认 state==0（跨窗口/同窗换控件漏收）③没有兜底超时④零矩形会误弹⑤查询是阻塞的。** 这 5 点里 1、3、4 可以静态定案，2、5 必须上机量测。

## §1 focusd 的启动方式与实际生命周期

### 1.1 仓库内证据：现役 Debian 根**没有** focusd 的任何自启安装点

```bash
# (1) 全仓 systemd unit 里没有任何 focusd / IME 相关 unit
$ find . -path ./.git -prune -o -name '*.service' -print | xargs grep -l 'focusd' 2>/dev/null
（无输出）
$ find . -path ./.git -prune -o -name '*.service' -print | grep -iE '/(ime|fcitx)'
./rootfs/debian/ime/fcitx5-indicator.service     # 只有顶栏指示器
（注：`grep -i ime` 会假命中 time-sync.service，别用它当判据）

# (2) Debian 构建产物里没有 focusd 的二进制也没有 autostart 项
$ find out/stage-debian -name '*focusd*'
（无输出）
$ ls out/stage-debian/etc/xdg/autostart/
elden-waydroid.desktop          # 只有这一个
$ ls out/stage-debian/usr/local/bin/
bwrap elden-ime-mode elden-ime-toggle eldroid-bootctl feedback q28-race-hunt.sh scale.sh
                                # 没有 elden-ime-focusd
# 注：out/stage-debian 是 2026-10-31 的构建快照，可能比设备旧；结论不靠它 ——
# 重跑构建也一样（构建脚本里没有任何 focusd 安装语句，见下）。

# (3) .desktop 只存在于 Alpine 世代 overlay + patches-userland 源；安装者只有 squeekboard 时代脚本
$ find . -name '*focusd*.desktop' -not -path './.git/*'
./patches-userland/zh-ime/elden-ime-focusd.desktop
./rootfs/persistent-overlay/user-autostart/elden-ime-focusd.desktop   # Alpine 现役根的归档快照
$ rg -n 'focusd.desktop' --glob '!reports/**' .
scripts/deploy-zh-ime.sh:33:  scp ... "$TAB:/etc/xdg/autostart/elden-ime-focusd.desktop"   # 装 squeekboard + apk 的 Alpine 脚本
```

对照：**同目录同期**的其它 IME 组件**都**有 unit / 有构建侧安装点：

| 组件 | 自启方式 | 构建侧安装点 |
|---|---|---|
| `fcitx5` | `/etc/systemd/user/fcitx5.service` + `/etc/systemd/user/graphical-session.target.wants/` 符号链 | `rootfs/debian/daily-baseline.sh:147-178`；`rootfs/debian/build-rootfs.sh:248`（校验） |
| `fcitx5-indicator` | user unit `~/.config/systemd/user/fcitx5-indicator.service` | `rootfs/debian/daily-baseline.sh` §3b |
| **`elden-ime-focusd`** | **无** | **无**（仅 `packaging/elden-userland` 的**二进制** recipe，不装 unit/desktop） |

交叉验证（不依赖上面那个 10-31 快照）：

```bash
$ rg -n 'focusd' rootfs/debian/
（无输出）                       # 构建脚本 + 可部署文件里零命中
$ rg -ln 'focusd' packaging/elden-userland/
packaging/elden-userland/MANIFEST.tsv              # 版本账
packaging/elden-userland/sources.tsv
packaging/elden-userland/build/elden-ime-focusd.sh # 二进制 recipe（不装 unit/desktop）
packaging/elden-userland/build/artifacts.tsv
packaging/elden-userland/build/all.sh
packaging/elden-userland/build/README.md
packaging/elden-userland/tools/sync-from-device.sh # 从设备回收二进制
packaging/elden-userland/files/usr/local/bin/elden-ime-mode   # 那个 `pgrep || setsid` 兜底
```

⇒ **即使重跑一次完整 rootfs 构建，focusd 也不会被装进去**（`rootfs/debian/` 里没有任何安装语句）。

⇒ **focusd 目前只有两条「能被起起来」的路**：

1. **手工**：2026-11-11 晚那次是 `install -m755 … /usr/local/bin/` + `install -D -m644 … /etc/xdg/autostart/`，
   然后**当轮没有重登**（`reports/ime-osk-firefox-rootcause-20261112.md` §6 第 5 条自己写了
   「登录后自启已装，但本轮未重启桌面会话验证」）。
2. **顺带兜底**：`packaging/elden-userland/files/usr/local/bin/elden-ime-mode:44`
   （`pgrep -f /usr/local/bin/elden-ime-focusd || setsid …`）——只在用户**手动切模式**时才跑一次。

### 1.2 为什么「装个 `/etc/xdg/autostart/*.desktop`」不等于「重登后还在」

- `.desktop` 里的 `X-GNOME-Autostart-enabled` / `X-GNOME-AutoRestart` **只有实现 XDG autostart
  协议的会话管理器才认**。phosh 会话是否跑 XDG autostart、以及跑在哪个 target 上，**本仓没有任何实测记录**；
  而 **systemd user unit 这条路本仓有实测证据**：`PITFALLS` #540（Debian 的 fcitx5 无用户级自启单元 ⇒
  `/etc/systemd/user` + `graphical-session.target.wants` 才是「构建侧和现场同一路径」），
  以及 `reports/artifacts/net-selfheal-20261031/post.txt:18` 的 `Reached target graphical-session.target`。
  ⇒ **同一个会话里，unit 一定起，XDG autostart 只是「大概会起」。**
- 更硬的一条：即使 autostart 生效，**`CurrentUI=kimpanel` 本身不持久**（`PITFALLS` #619：
  `SetAddonsState` 不进 `~/.config/fcitx5/conf/`，fcitx5 重启回 `classicui`）。
  **重登 = fcitx5 重启 + focusd 不在 + CurrentUI 回 classicui**，三个独立失效叠在一起，
  用户侧看到的就是「键盘彻底不工作」——这与「自动弹出/收起没做好」的现场描述一致。

### 1.3 本轮能定/不能定

| 问题 | 本轮判定 | 依据 |
|---|---|---|
| 有 unit 文件吗？ | **没有** | `find … -name '*.service' \| grep -i ime` 空 |
| 开机自动在吗？ | **不在**（Debian 现役根里连二进制都没 staged） | `find out/stage-debian -name '*focusd*'` 空 |
| 重登后自动在吗？ | **静态判定不在**；但「设备上那份手工装的 `/etc/xdg/autostart/…` 在 phosh 下到底起不起」**未验** | 见 1.2；判据见 §5 T-S1 |

**DONE §0–§1**（静态；无 Linux 实测）

## §2 弹/收判据的完整映射（逐行对代码）

源码：`patches-userland/zh-ime/elden-ime-focusd.c`（产物 `out/ime-host/elden-ime-focusd`，sha256 `782f79e4…`，与设备现役件一致）。

### 2.1 弹出（show）触发面

| kimpanel 方法 | 代码位置 | 行为 | 备注 |
|---|---|---|---|
| `SetRelativeSpotRect(i,i,i,i)` | `:118`（接口声明）、`:142-144` | **无条件** `want_keyboard("SetRelativeSpotRect")` | **矩形参数被丢**（`:137` 的 `(void)params`）⇒ `(0,0,0,0)` 也弹 |
| `SetSpotRect(i,i,i,i)` | 同上 | 同上 | fcitx5 实际只发 `SetRelativeSpotRect`（探针实测） |
| `UpdateSpotLocation(i,i)` | `:128`、`:142-144` | **当作 show 信号** | 语义上它只是「光标位置变了」，与「聚焦」不等价 ⇒ 另一条误弹面 |
| `Enable(true)` | `:145-149` | `want_keyboard("Enable(true)")` | 2026-11-11 探针实测 **fcitx5 从不发** ⇒ 死分支（保留无害） |
| `ShowPreedit(true)` | `:150-154` | `want_keyboard("ShowPreedit(true)")` | 组词开始时的附加信号 |
| `SetLookupTable(as,as,as,b,b,i,i)` | `:155-160` | 仅当**第 2 个 array 非空**才 show | 即「有候选」时也弹（打字中补漏） |
| `ShowAux(b)` / `UpdateAux` / `UpdatePreeditText` / `UpdateProperty` … | `:120-133` | **只声明、不处理**（落到底部 `return_value(NULL)`） | 无害，但意味着「候选/Aux 状态变化」不能当收起信号 |

`want_keyboard()` 本体（`:100-108`）：

```
now = monotonic()
if now - last_show_us < 400_000: return        # ① 400 ms 去抖，早退
osk_get_visible()                             # ② 同步 Get Visible（500 ms 超时）
if osk_visible: return                        # ③ 已可见就什么都不做（也不更新 last_show_us）
log "show requested by <why>"
osk_set_visible(TRUE)                         # ④ 同步 SetVisible(true)
last_show_us = now                            # ⑤ 只有「真的发了 show」才更新时间戳
```

⇒ 三个可直接推出的行为：

1. **幂等是对的**（③ 先查 `Visible`，不会重复 `SetVisible(true)`）；
2. **但 ③ 分支不刷新 `last_show_us`** ⇒ 键盘已经在屏上时，**每一次**坐标更新都会再做一次
   同步 D-Bus 往返（500 ms 超时）——而 fcitx5 在**每次光标移动/按键**后都可能重发 `SetRelativeSpotRect`；
3. `osk_get_visible()` 在**任何错误/超时**下把 `osk_visible = FALSE`（`:53-56`），
   于是「stevia 忙 500 ms」被当成「键盘没显示」⇒ **重发 SetVisible(true)**，这是「弹了又弹」的结构性来源。

### 2.2 收起（hide）触发面

**只有一处**（`:89-98`，`g_timeout_add_seconds(1, idle_check, NULL)`，`:186`）：

```
idle_check():
  if not osk_visible (本地标志): return CONTINUE    # ① 本地认为没显示就什么都不做
  if fcitx_state() == 0:                            # ② 唯一判据
      log "hide requested by fcitx State=0"
      osk_visible = FALSE
      osk_set_visible(FALSE)
```

`fcitx_state()`（`:74-87`）= `org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1.State`（`(i)`，300 ms 超时）。

**没有的东西**（逐条确认，因为这三条正是用户感知到的「没做好」）：

| 缺失项 | 后果 | 证据 |
|---|---|---|
| **没有超时自动隐藏**（无 `last_activity` 类变量） | 没有可靠的 state 变化时键盘永久悬浮 | 全文只有 `last_show_us`（`:30`），只用于去抖 |
| **没有 `state==-1`（fcitx5 不在）的退路** | fcitx5 崩/被 stop 后键盘**再也收不掉** | `:80-83` 注释「fcitx5 不在/未就绪：不据此收起」 |
| **没有 `SetCapabilities` / `SetCursorRect` 语义** | kimpanel 协议里「能力/焦点能力变化」完全不参与判定 | 接口 XML（`:110-134`）里没有 `SetCapabilities`；`method_call` 也不识 |
| **没有「矩形为零 = 失焦」判定** | 反向的误弹（§2.1 表格第一行） | `:137` `(void)params` |
| **没有窗口/表面身份** | 无法区分「换窗口」与「同窗换控件」 | 桩里不记录 sender/窗口 |

### 2.3 焦点在窗口间切换 / Alt+Tab 时的实际行为（静态推导）

前提：`Controller1.State` 是 **当前 InputContext 的状态**，fcitx5 的约定是
`0 = closed（IC 销毁） / 1 = inactive（IC 存在但输入法未激活） / 2 = active（组词中）`。
**注意分级**：本仓只实测到 **0 和 1** 两个值（2026-11-11 三次采样 `idle=0 / focused=1 / after close=0`，
见下）；「1 = IC 存在」是从该采样 + fcitx5 API 语义推的，**`2` 的值本轮无实测**。
凡是依赖「1 不等于 0」的推断（R2、§2.4）都必须在 Linux 上机确认（§5 T-H1/T-H3）。
原始采样见 `reports/ime-osk-firefox-rootcause-20261112.md` §4 T3。

| 动作 | fcitx5 侧 | focusd 判定 | 结果 |
|---|---|---|---|
| 点 A 窗输入框 | 新 IC，state 0→1，kimpanel `SetRelativeSpotRect(非零)` | show | ✅ 弹（已验证） |
| **Alt+Tab 到 B 窗（GTK/Qt 应用，无输入框）** | B 的 IC 被创建/激活，**state 仍为 1** | `state != 0` ⇒ 不收起 | ❌ **漏收：键盘挂在 B 窗上**（`PITFALLS`/报告都没测过这一条） |
| **Alt+Tab 到 B 窗（B 也是输入框）** | state 1，kimpanel 再来一次 `SetRelativeSpotRect` | ① 400 ms 内被去抖；② 之后 `osk_get_visible()` 已 true ⇒ 无动作 | ✅ 保持显示（正确，但键盘贴着 A 的光标矩形，位置不跟） |
| **同窗 Tab 到按钮/标签**（GTK 仍持有同一个 IC） | state 1 | 不收起 | ❌ **漏收（残留悬浮键盘）** |
| 关闭窗口 | IC 销毁 ⇒ state 0 | 收（1 s 内） | ✅ 已验证（T1 `post=(<false>,)`） |
| 杀掉应用 | IC 销毁（若 fcitx 收到 destroy） | 收 | ⚠️ 未测；若 IC 泄漏则永久悬浮 |
| **锁屏 / 解锁** | phoc 锁屏时 input-method grab 变化；stevia 自己也会应答锁屏键盘 | **未知**：focusd 既不看锁屏信号，也不区分 OSK0 的占用者 | ⚠️ 必须上机（§5 T-H4） |

⇒ **结论：`state==0` 只覆盖「IC 被销毁」这一种收起意图**，对「焦点离开输入控件」（IC 仍在）完全无感。
真正需要的是「**当前聚焦窗口里是否还存在输入焦点**」——kimpanel 侧有 `Enable(false)`/`ShowPreedit(false)`，
但 2026-11-11 探针证实 fcitx5 **不发 `Enable`**（`PITFALLS` #618）；所以退路只能是
**(i) 兜底超时**（§4.a-3 第 3 条）+ **(ii) 把 OSK 换成收 `text-input-v3` 的那条栈**
（§4.b 的 **b1**：phoc 发 activate → stevia 自己收；注意 b2 的 waylandim+wvkbd **并不**自动获得这个能力）。

### 2.4 「自动收起」四情形逐个判定（对应任务问题 4）

| 情形 | 会不会收 | 静态理由 | 上机判据 |
|---|---|---|---|
| 切窗口（Alt+Tab） | **漏**（多数情况） | §2.3 第 2/3 行；只要新窗有 IC，state 非 0 | T-H1 |
| 关应用 | 收（窗口销毁路径已验证；杀进程路径未验） | IC destroy ⇒ state 0 | T-H2 |
| 锁屏 | **未知** | 无任何锁屏信号参与；还要叠 stevia 锁屏键盘的抢槽行为 | T-H4（必须上机） |
| 关输入框（同窗失焦到按钮） | **漏** | 同一 IC 保持 state 1 | T-H3 |

**DONE §2**（静态推导，未上机）


## §3 「没做好」的失效面拆解与排序

按「用户能感知 + 静态已定案」排序；**R1/R3/R4/R5 可在本机静态/构建级收口，R2/R6 必须上机**。

| 序 | 失效面 | 具体触发条件（代码行） | 用户看到什么 | 严重度 |
|---|---|---|---|---|
| **R1** | **桥根本没起来**（重登/重启后） | §1：现役根无 unit、stage-debian 无二进制；`CurrentUI` 也不持久（#619） | 点输入框完全没反应（比「没做好」更硬） | 阻断 |
| **R2** | **跨窗口/同窗失焦不漏收** | `idle_check` 只认 `State==0`（`:92`）；IC 存在即 `state=1` | 关掉输入框/切到别的窗口，键盘仍悬在底部；再点别的应用还得手动按▼ | 高 |
| **R3** | **无兜底超时；fcitx5 不在时永不收** | 无 `last_activity`；`:80-83` 对 `state=-1` 直接返回 | 输入法崩了 / 应用崩了 → 键盘永久挡屏，只能手动收 | 高 |
| **R4** | **零矩形 / 位置更新被当聚焦**（误弹） | `:137` `(void)params` + `:142-144` 不区分 `SetRelativeSpotRect` 的矩形和 `UpdateSpotLocation` | fcitx5 刚启动/切 IC 的一瞬间弹一下又收（「弹了又收」抖动），或鼠标/光标一动就弹 | 中 |
| **R5** | **查询阻塞主循环 + Get 失败误置位** | `osk_get_visible()` 同步 500 ms（`:44-60`）；`want_keyboard` 的 ③ 分支不刷新 `last_show_us`（`:104-105`） | 打字时候选/上屏变卡；stevia 忙时重复 `SetVisible(true)` → 键盘闪 | 中 |
| **R6** | **候选窗与 stevia 键盘可能重叠**（#619 遗留） | focusd 的 kimpanel 桩**不渲染任何 UI**（接口里只有 method，无 layer-shell/窗口） | 候选条压在键盘上/根本看不到候选窗（当前是用户看到候选的，但**不确定是谁画的**） | 中（待验） |
| **R7** | **键盘位置不跟光标** | 矩形参数被丢，`SetVisible` 不带位置；stevia 自己决定贴哪 | 长文本输入时光标在屏上半部，键盘仍占底部（stevia 正常行为，但对照「自动弹出/收起做好」预期算体验缺口） | 低 |

### 3.1 R4 的证据链（这一条是本轮唯一「新增的硬证据」）

2026-11-11 的探针输出（`reports/ime-osk-firefox-rootcause-20261112.md` §3）：

```
CALL[1] org.kde.impanel2.SetRelativeSpotRect (0, 0, 0, 0)          ← fcitx5 启动/上下文建立
CALL[2] org.kde.impanel2.SetRelativeSpotRect (27, 114, 0, 2781)    ← GTK3 Entry 拿到焦点
```

两条在 focusd 里**走完全相同的分支**（`:142-144` → `want_keyboard`），因为矩形从未被读入。
⇒ 「键盘在 fcitx5 刚起、或新 IC 建立时闪一下」是**代码层面可预言的**，不需要新机制。
修法：`if (w == 0 || h == 0) return;`（相对矩形在 fcitx5 里零高即无光标），并用
`SetRelativeSpotRect` **非零** 作为唯一的 show 主信号（`UpdateSpotLocation` 不弹）。

### 3.2 R2 的静态论证（为什么它一定是错的，而不只是「可能」）

fcitx5 的 GTK/Qt 前端在**窗口获得焦点时**就建 IC（而不是在输入框获得焦点时）；
所以从 A 窗切到 B 窗，`/controller` 的当前 IC 换成 B 的，`State` = 1（inactive，非 0）。
⇒ 只要目标窗口是**任何 fcitx 客户端**（GTK3/4 全系、Qt+fcitx5-qt），键盘就不会收。
旁证：`#619` 的取证方法本身就是「新窗口有焦点后 `fcitx5-remote -n`」——说明新窗口确实有独立 IC。

### 3.3 R6 的定性（不要沿用旧口径）

`PITFALLS` #619 写「候选窗本身仍由 fcitx5 侧渲染」，但同一篇又写了「classicui 已显式禁用」——
而 `CurrentUI=kimpanel` 时，kimpanel owner（= focusd）**什么都没画**。
两者矛盾，当前**无法从代码定案候选窗归属**（可能来自 `fcitx5-frontend-gtk3` 的
client-side candidate window，也可能是 classicui 残存）。
判别实验（§5 T-C1）：先 `systemctl --user stop elden-ime-focusd`（让 `org.kde.impanel` 没 owner），
再打 `ni` —— **有候选 = 不是 kimpanel 画的**（也就意味着 focusd 与候选窗重叠无关，R6 降级）；
**没候选 = 篔面板必须由 focusd 实现**（R6 升级为「彻底没有候选窗」，优先级提到 R2 之后）。

**DONE §3**（静态；R6 定性待上机）

## §4 两条最小处置 + 代价 + 判据

### 4.a 处置 a：focusd 固化为 systemd user unit + 兜底超时（推荐）

#### a-1 新增文件 `rootfs/debian/ime/elden-ime-focusd.service`（照 `fcitx5.service` 已有模式）

```ini
[Unit]
Description=elden IME focus bridge (kimpanel -> sm.puri.OSK0)
After=graphical-session-pre.target fcitx5.service
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elden-ime-focusd
Environment=ELDEN_IME_LOG=%t/elden-ime-focusd.log
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
```

要`After=fcitx5.service`（否则桥先起、`Controller1.State` 一开始不可用）；
`ELDEN_IME_LOG=%t/…` 把日志放到 `$XDG_RUNTIME_DIR`（现在硬编码 `/tmp/elden-ime-focusd.log`，多用户/权限都会撞，`elden-ime-focusd.c:35`）。

#### a-2 安装点（三处，必须同改，否则构建侧/现场又不一致）

| 文件 | 改动点 | 作用 |
|---|---|---|
| `rootfs/debian/daily-baseline.sh`（§3 末，约 :178 后新增 §3d） | ① `install -m0755 out/ime-host/elden-ime-focusd → /usr/local/bin/`；② `install -m0644 rootfs/debian/ime/elden-ime-focusd.service → /etc/systemd/user/`；③ `ln -sf … /etc/systemd/user/graphical-session.target.wants/elden-ime-focusd.service`（**与 fcitx5 完全同构**，理由见 `PITFALLS` #540） | 自启 + 幂等修复（`--check` 能报 MISS） |
| `rootfs/debian/build-rootfs.sh:248` | 追加一条 `[ -L …/graphical-session.target.wants/elden-ime-focusd.service ]` 校验 | 构建期门禁 |
| `packaging/elden-userland/MANIFEST.tsv:25` / `sources.tsv:15` | 二进制 sha/尺寸更新（重编后必变） | 版本账一致（`check-doctor`） |

> 为什么不把 `.desktop` 当主路径：见 §1.2 —— phosh 下 XDG autostart 本仓无实测证据，
> 而 unit 路径有实测（`PITFALLS` #540 + `artifacts/net-selfheal-20261031/post.txt:18`）。
> `.desktop` 可保留作兼容（**不要两份同时起**，否则两个 owner 抢 `org.kde.impanel`，后上的 `RequestName` 失败→ 进程直接 exit）。

#### a-3 源码改动（4处，每处 ≤10 行）

| # | 位置 | 改法 | 解决 |
|---|---|---|---|
| 1 | `elden-ime-focusd.c:137`（`(void)params`）/ `:142-145` | 把 `params` 真正解成 `(iiii)`；**零宽/零高直接 return**；把 `UpdateSpotLocation` 从 show 触发集里**删除** | R4 误弹/抖动 |
| 2 | 全局新增 `last_activity_us`；`method_call` 末尾与 `want_keyboard` 开头都更新 | — | 超时基准 |
| 3 | `idle_check`（`:89-98`） | 三条收起条件取或：① `state==0`（现状）；② `state==-1` **连续 3 个 tick**（fcitx5 走了）；③ `now-last_activity > ELDEN_IME_IDLE_S`（默认 30）**且 `state!=2`**（不在组词/未激活） | R2 漏收 / R3 永不收 |
| 4 | `osk_get_visible`（`:44-60`） | 改成**不阻塞**：要么订 `PropertiesChanged(Visible)` 维护缓存；要么取消 每次 Get，只用本地 `osk_visible`（`SetVisible` 成功/失败已足够）+ 失败时置 UNKNOWN 而不是 FALSE | R5 抖动/卡顿 |

> 变更后行为边界（必须写进报告，免得又被读成「已修」）：
> **`state==1` 依旧无法区分「输入框焦点」与「窗口焦点」**，所以超时是**唯一**能收掉「同窗/跳窗后挂着」的路径；
> 代价是「长时间只在英文状态下敲键（无 kimpanel 流量）也可能被收」——所以默认 30 s 且 `state!=2` 才收。

#### a-4 代价

| 项 | 估计 | 依据 |
|---|---|---|
| 仓库改动 | 1 个新文件 + 3 个文件小改 + 2 行版本账 | 上表 |
| 重编 | `bash packaging/elden-userland/build/elden-ime-focusd.sh`（arm64 chroot，只编 1 个 C 文件） | 本机可做 |
| 上机 | 1 次安装 + **1 次重登** + 4 条测试；≤ 20 min | 需 Linux 根可达 |
| 风险 | 低：不碰 phoc/内核/显示；回退 = `systemctl --user disable --now elden-ime-focusd`（单命令） | — |

#### a-5 判据（本机可做的先做）

```bash
# 本机（静态/构建）
bash packaging/elden-userland/build/elden-ime-focusd.sh         # 必须成功且 sha 变
packaging/elden-userland/tools/verify.sh --rebuildable          # FAIL=0 WARN=0
rg -n 'elden-ime-focusd' rootfs/debian/daily-baseline.sh rootfs/debian/build-rootfs.sh  # 三处安装+门禁都在
# 设备（Linux 侧，必须）
systemctl --user is-enabled elden-ime-focusd   # → enabled（重登后）
systemctl --user status elden-ime-focusd       # → active (running)
busctl --user list | grep -c 'org.kde.impanel '  # → 1（且只有一个 owner）
```

### 4.b 处置 b：「单栈」换法（两个变体，代价完全不同）

先纠一个口径：**单栈不等于没有桥**。

| 变体 | 组成 | 谁把「有输入框」变成「出键盘」 | 是否还需要 focusd/其它桥 |
|---|---|---|---|
| **b1** 保留 stevia，去掉 `GTK_IM_MODULE=fcitx` | phoc（已去版本门）+ stevia 占 IM 槽 + `GTK_IM_MODULE=wayland` | phoc 发 `activate` → stevia 自己弹/收 | **不需要**（`PITFALLS` #618 的 D 臂已证 `Visible=(<true>,)`）——**但中文组词换成 stevia，未验** |
| **b2** fcitx5 开 `waylandim` + `wvkbd` | fcitx5 占 IM 槽 + wvkbd 发 zwp_virtual_keyboard | 需 **phoc `bb1f7465`**（waylandim grab 崩溃修）；**且 wvkbd 不是 input-method-v2 客户端 ⇒ 收不到 activate ⇒ 仍要一个「可见性驱动器」** | **需要**（旧 `osk0-bridge`/focusd 改一改） |

因此任务描述里「(b) 换单栈就能天然弹收」**只对 b1 成立**，且 b1 的代价是丢掉已验证的 Rime 组词。

#### 改动点（b1）

| 文件 | 改动 | 风险 |
|---|---|---|
| `rootfs/debian/daily-baseline.sh:141-143`（以及设备 `/etc/environment.d/50-elden-ime.conf`） | `GTK_IM_MODULE=fcitx` → `wayland`；`QT_IM_MODULE` 同理（Qt 的 wayland IM 前端需 `qt6-wayland`） | GTK/Qt 客户端从此**不走** fcitx 的 DBus 前端 |
| `rootfs/debian/daily-baseline.sh:147-178` | `fcitx5.service` **可保留**（终端/stevia 组词可能要），但客户端不再经它 | — |
| `rootfs/debian/ime/elden-ime-focusd.service` | **不装**（b1 不需要桥） | — |

#### 改动点（b2）

| 文件 | 改动 |
|---|---|
| `rootfs/debian/daily-baseline.sh:161` | `ExecStart=/usr/bin/fcitx5 -r --disable waylandim` → 去掉 `--disable waylandim` |
| `patches/` 新增 phoc rebase | 把 `patches/phoc-osk-versiongate-20261111/0001-…patch` + syncobj 补丁 rebase 到 **≥ `bb1f7465`** 的上游；重编 15–25 min（`make -j26`） |
| `rootfs/debian/ime/wvkbd.service`（新） | `ExecStart=/usr/bin/wvkbd-mobintl --hidden`，同 unit 模式；但**还得有一个“何时 show/hide”的组件**（见上表） |
| stevia | `systemctl --user mask mobi.phosh.OSK.service`（把关槽让给 fcitx5） |

#### 代价对比（结论：先做 a，b 只作为 b1 的后续实验）

| 维度 | a（focusd 固化+超时） | b1（stevia 原生） | b2（waylandim+wvkbd） |
|---|---|---|---|
| 合成器重编 | 不需 | 不需（当前 phoc 已含去版本门补丁） | **需**（bb1f7465 + 两个补丁重放） |
| 中文组词 | 保持（Rime，已验证） | **未验**（stevia 组词） | 保持 |
| 收起是否靠协议 | 否（超时/state） | **是** | 否（仍需桥） |
| 候选窗 | 现状（R6 待定性） | 未验（stevia 自己有候选行？） | classicui 在 phoc 上仍出不了窗（#619 层A） |
| 回退成本 | 1 条 `systemctl` | 改回 3 行 env + 重登 | 重装 phoc + 重登 |
| 阻塞项 | 无 | `GTK_IM_MODULE=wayland` 下 Firefox 已验证能弹，但组词未验 | phoc 版本/补丁 |

**DONE §4**（方案与判据已写成可执行；本机只做了静态部分，重编/上机未执行）

## §5 待办清单（每条带判据命令）

> 前提：**平板当前在 Android 12**（§0.1）⇒ 带 🔒 的条目全部要求在 Linux 根上跑；
> 切回 Linux 是**物理动作**（由用户执行），agent 不触发。设备命令一律走 `scripts/device-lock.sh`。
> 标 🖥 的可在本机（x86）完成。

### P0 —— 先确认现状（不确认就不改）

| # | 事项 | 判据命令 | 位置 |
|---|---|---|---|
| T-S1 | 🔒 设备上 focusd 现在到底在不在、靠什么起 | `pgrep -af elden-ime-focusd`；`busctl --user list \| grep -c 'org.kde.impanel '`；`ls -l /etc/xdg/autostart/elden-ime-focusd.desktop /usr/local/bin/elden-ime-focusd`；`systemctl --user list-unit-files \| grep -i ime` | 设备 |
| T-S2 | 🔒 重登（`loginctl terminate-user xuqianhui1001`）后重跑 T-S1 | 期望：**当前应全部缺失**（即验证「重启桌面即失效」） | 设备 |
| T-S3 | 🔒 `CurrentUI` 是否回 `classicui` | `gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller --method org.fcitx.Fcitx.Controller1.CurrentUI` → 重登后期望 `('classicui',)`（#619） | 设备 |

### P1 —— 处置 a 落地（本轮建议）

| # | 事项 | 判据命令 | 位置 |
|---|---|---|---|
| T-A1 | 🖥 `elden-ime-focusd.c` 四处改动（零矩形/超时/非阻塞/日志路径） | `bash packaging/elden-userland/build/elden-ime-focusd.sh` 成功；`packaging/elden-userland/tools/verify.sh --rebuildable` → `FAIL=0 WARN=0` | 本机 |
| T-A2 | 🖥 新增 unit + daily-baseline §3d + build-rootfs 门禁 + 版本账 | `rg -c 'elden-ime-focusd' rootfs/debian/daily-baseline.sh` ≥2；`rg -n 'focusd' rootfs/debian/build-rootfs.sh` 命中 1 行 | 本机 |
| T-A3 | 🔒 部署 + 重登 | `systemctl --user is-enabled elden-ime-focusd` = `enabled`；`status` = `active`；`busctl --user list \| grep -c 'org.kde.impanel '` = **1** | 设备 |
| T-A4 | 🔒 弹：GTK3 测试窗 | `probes/ime/e8-verify.sh` 的 T1 → `mid=(<true>,)` | 设备 |
| T-A5 | 🔒 弹：Firefox | `probes/ime/e8-verify.sh` T2（`ffprobe.html` 先 scp） → `mid=(<true>,)` | 设备 |
| T-A6 | 🔒 **误弹回归（新）**：fcitx5 重启不应弹 | `systemctl --user restart fcitx5; sleep 3` 后查 `Visible` 期望 `(<false>,)`；日志里**不应**有零矩形引起的 `show requested` | 设备 |
| T-A7 | 🔒 **超时收起（新）**：卡在「有 IC 但无输入焦点」 | GTK 窗内焦点移到按钮并保持 40 s → `Visible` 期望 `(<false>,)`；日志 `hide requested by idle timeout` | 设备 |
| T-A8 | 🔒 回退面 | `systemctl --user disable --now elden-ime-focusd` 后键盘仍可用 `sm.puri.OSK0.SetVisible` 手动控制（基线不倒退） | 设备 |

### P2 —— 收起四情形（对应 §2.4）

| # | 情形 | 命令（设备） | 期望 |
|---|---|---|---|
| T-H1 | Alt+Tab 到另一个 GTK 窗（无输入框） | `wtype -M alt -k Tab -m alt` 后 2 s 查 `Visible` | 现栈 `true`（漏收，预期失败）→ 改后 `false` |
| T-H2 | 关应用（Firefox 整窗关闭） | `pkill -x firefox; sleep 3;` 查 `Visible` | `false`（2026-11-11 已验，回归用） |
| T-H3 | 同窗 Tab 到按钮（不关窗） | `probes/ime/ime-gtk3-entry.py` 加一个 `Gtk.Button` 并轮换焦点 | 改后 ≤ 超时秒数内 `false` |
| T-H4 | 锁屏/解锁 | `loginctl lock-session` → 查 `Visible`；解锁后再点输入框 | 锁屏不弹/不挡；解锁后能弹（**完全未验，本轮最不确定**） |
| T-H5 | fcitx5 死掉 | `systemctl --user stop fcitx5; sleep 3` 后查 `Visible` | 改后 ≤ timeout 内 `false`；现栈永久 `true`（预期失败） |

### P3 —— 候选窗归属与遮挡（R6）

| # | 事项 | 判据命令 | 位置 |
|---|---|---|---|
| T-C1 | 🔒 判别候选窗是不是 kimpanel 画的 | `systemctl --user stop elden-ime-focusd`（`org.kde.impanel` 无 owner）→ GTK 输入框打 `ni` → `grim` 截屏 + `dbus-monitor "interface='org.kde.impanel2'"` | 设备 |
| T-C2 | 🔒 遮挡目视 | 弹键盘 + 打 `nihao` → `grim` 截屏，看候选条是否压键盘 | 设备 |
| T-C3 | 🖥 若 T-C1 结论 =「必须 focusd 画候选」 | 需在 C 里接 `SetLookupTable` + layer-shell（估 1–2 天，**不在本轮范围**） | 本机 |

### P4 —— 收尾固化（不阻塞）

| # | 事项 | 判据命令 | 位置 |
|---|---|---|---|
| T-F1 | 🖥 `classicui` 永久禁用（避免每次重登手工 `SetAddonsState`） | 新文件 `rootfs/debian/ime/classicui.conf`（`Enabled=False`）→ `/etc/xdg/fcitx5/addon/` | 本机 |
| T-F2 | 🔒 重登后 `CurrentUI` 仍 `kimpanel` | `gdbus … CurrentUI` = `('kimpanel',)` | 设备 |
| T-F3 | 🔒 Qt 客户端（`fcitx5-qt` 未装）与 XWayland | 装 `fcitx5-frontend-qt6` 后跑 Qt `QLineEdit` → `Visible=(<true>,)` | 设备 |
| T-F4 | 🖥 本报告并入 SSOT | 由总管做（`TASKS/README.md` G1-38、`PITFALLS` 新条），本 lane 不改 | 本机 |

### 必须在 Linux 侧上机才能验的条目（汇总）

**T-S1/S2/S3、T-A3…A8、T-H1…H5、T-C1/C2、T-F2、T-F3**
——即：§0 结论 2/5（收起与抖动）、§3 的 R2/R5/R6、§4 的全部「判据」栏位。
本机只能验：编译可重建（`verify.sh --rebuildable`）、unit/脚本静态一致性、版本账。

**DONE §5**（清单可执行；本机仅静态，未编译未上机）
