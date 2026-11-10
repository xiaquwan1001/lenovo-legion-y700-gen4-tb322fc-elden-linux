# 主机侧调研：Phosh(phoc) × fcitx5 × OSK 共存可行性（2026-11-10）

> lane：纯主机侧调研（不写设备 / 不重启设备 / 不改仓库既有文件）。只读核验设备状态允许。
> 背景：`reports/ime-chinese-20261109.md`、`TASKS/README.md` G1-37、`PITFALLS/README.md` #576/#577/#578、
> `rootfs/debian/ime/`、`patches-userland/zh-ime/`（squeekboard + focusd 旧栈）、`patches/upstream/phoc-im-keyboard-grab-2026-10-18/`。
> 本次调查起点（2026-11-10 只读核验，设备在线）：**phoc 0.58.0-1 / phosh 0.59~alpha1-1 /
> phosh-osk-stevia 0.59~rc1-1 / squeekboard 1.43.1-2.1（装了但未跑）/ fcitx5 5.1.23-1**，
> 在跑进程：`phoc -v -S -C /usr/share/phosh/phoc.ini -E gnome-session --session=phosh`、
> `fcitx5 -r --disable waylandim`、`phosh-osk-stevia --allow-replacement`。

## §1 机制层：phoc 0.58 实现了哪些 Wayland 文本输入协议

**取证方式**：主机侧拉 `phoc` **v0.58.0** 源码 tarball（与在机 `phoc 0.58.0-1` 同版本）逐行读，不靠记忆。
`curl -sL https://gitlab.gnome.org/World/Phosh/phoc/-/archive/v0.58.0/phoc-v0.58.0.tar.gz`（452 KB）。

### 1.1 phoc 实际创建的协议全局（源码 path:line）

| 协议 | phoc 0.58 是否有 | 出处（文件:行） |
|---|---|---|
| `zwp_text_input_manager_v3`（text-input-unstable-v3，**version 2**） | ✅ 有，全局 create | `src/desktop.c:687` `self->text_input = wlr_text_input_manager_v3_create (wl_display, PHOC_TEXT_INPUT_VERSION);`，`src/desktop.c:60` `#define PHOC_TEXT_INPUT_VERSION 2` |
| `zwp_input_method_manager_v2`（IM 槽位） | ✅ 有，全局 create | `src/desktop.c:686` `self->input_method = wlr_input_method_manager_v2_create (wl_display);` |
| `zwlr_virtual_keyboard_manager_v1` | ✅ 有 | `src/desktop.c:700`；handler `src/virtual.c:13` |
| `zwp_input_method_v1`（unstable **v1**） | ❌ 无。`protocols/meson.build` 只引入 `unstable/text-input/text-input-unstable-v3.xml`（`protocols/meson.build:15`），IM 协议全部来自 wlroots，而 wlroots 只剩 v2 | `protocols/meson.build:15`；`subprojects/wlroots.wrap` 钉 `revision=0.20.2` |

**要点**：phoc 的 text-input-v3 版本被定义成 **2**，而且这是 phoc 自己带 patch 顶上来的
（`subprojects/wlroots.wrap` 的 `diff_files` 里有 4 个 `text-input-v2/000x-*.patch`，即「给 text-input-v3 加 version-2 事件/请求」）。
⇒ **别处查到的 text-input-v3「version 3」特性在 phoc 上不可用**，写客户端/判据时要按 v2 算。

### 1.2 IM 槽位：唯一持有者，第二个直接被 `unavailable`

`src/input-method-relay.c:484-491`（`relay_handle_new_input_method`）：

```c
  if (relay->input_method != NULL) {
    g_debug ("Attempted to connect second input method to a seat");
    wlr_input_method_v2_send_unavailable (input_method);
    return;
  }
```

⇒ **每个 seat 只允许一个 `zwp_input_method_v2` 客户端**；后到者被明确告知 `unavailable`。
这与 `PITFALLS #578` / `PITFALLS/sessions/59` §3 的记录一致，且现在有了上游源码出处（不再是经验推断）。

### 1.3 关键机制：phoc 什么时候「让 OSK 弹起来」

OSK 弹出只有两条上游路径，都在 `input-method-relay.c`：

**(a) text-input 客户端 enable（老客户端兼容路径）——对 v≥1 客户端是死代码**

```c
static void
handle_text_input_enable (...)
{
  ...
  /* TODO: only for osk input-methods */
  if (wl_resource_get_version (text_input->input->resource) >=
      ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION)
    return;
  activate_osk (text_input);
}
```

`ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION == 1`，而 text-input-v3 **只有 v1 起**，
所以这个 `return` **恒成立** ⇒ phoc 0.58 **从不**因为 text-input 被 enable 而弹键盘。
（出处：`src/input-method-relay.c:249-263`）

**(b) 客户端显式 `show_input_panel` —— 唯一实际生效的路径**

```c
static void
handle_text_input_show_input_panel (...)
{
  ...
  g_debug ("Explcit request to show input panel");
  activate_osk (text_input);
}
```

`activate_osk()` 做两件事（`src/input-method-relay.c:228-238`）：
`wlr_input_method_v2_send_activate (relay->input_method)`（通知 IM 客户端 = OSK 该出来了）
+ `elevate_osk (text_input->input->focused_surface)`。

⇒ **推论（本次调研的核心判据）**：phoc 侧「弹键盘」= 某个 **text-input-v3 客户端** 发了 `show_input_panel`，
由 phoc 转成 `zwp_input_method_v2.activate` 给 IM 客户端（stevia/squeekboard）。
**没有任何 `zwp_text_input_v3` 客户端 ⇒ phoc 永远不发 activate ⇒ 任何 OSK 都不会自动弹。**

### 1.4 phosh 0.59 自己不动手弹键盘

`phosh/src/osk-manager.c`（main 分支，322 行）注释就写明：

> “The #PhoshOskManager is responsible for handling the on screen keyboard. It tracks the OSKs visible
> property and can toggle the state. Note that **there's no way to ensure keyboard state via this interface**
> as it just uses DBus to express preference. **Any text input can make the keyboard...**”
> —— `src/osk-manager.c:26-30`

代码行为对得上：phosh 只做三件事——
① 代理 `sm.puri.OSK0` 的 `Visible`/`SetVisible`（`osk-manager.c:79-110`、`:219`）；
② 跟随 gsettings `org.gnome.desktop.a11y.applications screen-keyboard-enabled`（`:136`，关掉时强制 `SetVisible(FALSE)`）；
③ 锁屏时隐藏（`:180`）。
**phosh 没有「跟随焦点自动弹」的逻辑**（`on_visible_changed` 注释原文 “Just need to sync the property, **osk shows/hides itself**”，`osk-manager.c:157-172`）。

### 1.5 OSK 与 IM 是否互斥：是同一槽位的两种角色

- 在机 OSK = `phosh-osk-stevia 0.59~rc1-1`，它**既是 IM 客户端又是 OSK 进程**：
  `stevia/src/pos-input-method.c:301` `zwp_input_method_manager_v2_get_input_method(...)`，
  `:89` `handle_activate()` / `:110` `handle_deactivate()`（即：收到 activate 才「展开」）；
  同时 `stevia/src/pos-osk-dbus.c:17-18,188` 自己 own `sm.puri.OSK0` / `/sm/puri/OSK0`，`:105` 实现 `SetVisible`。
- 设备只读核验（2026-11-10）：`sm.puri.OSK0` 的 owner 是 pid 2394 `phosh-osk-stevi`（`busctl --user list` 一行 `sm.puri.OSK0  2394 phosh-osk-stevi  xuqianhui1001`）。
- ⇒ **IM 槽位（`zwp_input_method_v2`）与「OSK 实体」在 stevia 里是同一个进程同一个连接**；
  fcitx5 一旦打开 `waylandim`，stevia 拿 `unavailable`，键盘就没有提供者（`reports/ime-chinese-20261109.md` §3 表 B 臂）。
- squeekboard 也是 IM 客户端（`sm.puri.OSK0` + input-method），并且 **上游已标记 unmaintained**：
  GitLab 项目描述原文 “An on-screen-keyboard input method for Wayland. **This software is unmaintained.**”
  （https://gitlab.gnome.org/World/Phosh/squeekboard ，2026-11-10 取）；在机 `squeekboard 1.43.1-2.1` 已装但未运行。

### 1.6 本节结论

1. phoc 0.58 **只**实现 text-input-v3(v2) + input-method-v2 + virtual-keyboard-v1，**没有** IM v1；IM 槽位单占。
2. **OSK 自动弹出 = text-input-v3 客户端主动 `show_input_panel`**；phoc 不在 `enable` 上兜底（死代码），phosh 也不兜底。
3. 因此「谁在用 text-input-v3」决定了键盘会不会自己弹——这条把 §7 的根因指到了 **`GTK_IM_MODULE=fcitx` 让 GTK 不再使用 text-input-v3**（见 §7，设备已取证）。

DONE 1

## §2 fcitx5 侧：waylandim 需要哪个协议 + 与 phoc 的已知不兼容

**取证**：主机侧拉 `fcitx/fcitx5` master 的 `src/frontend/waylandim/*`、`src/modules/wayland/*` 源码（`gh api .../contents | base64 -d`）；
issue 用 `gh search issues --repo fcitx/fcitx5` 与 GNOME GitLab API 搜。在机版本 = **fcitx5 5.1.23-1**。

### 2.1 fcitx5 两个 Wayland 前端，只认「IM 侧」协议

| 前端 | 源文件 | 要求的全局 | 说明 |
|---|---|---|---|
| waylandim **v2**（phoc 走这条） | `src/frontend/waylandim/waylandimserverv2.cpp:51-71` | `zwp_input_method_manager_v2` + `zwp_virtual_keyboard_manager_v1` + `wl_seat` | `display_->requestGlobals<wayland::ZwpInputMethodManagerV2>(); ... requestGlobals<wayland::ZwpVirtualKeyboardManagerV1>();` |
| waylandim **v1**（KWin 走这条） | `src/frontend/waylandim/waylandimserver.cpp`；`src/modules/wayland/waylandmodule.cpp:163` 里监听字符串 `"zwp_input_method_v1"` | `zwp_input_method_v1` | **phoc 不提供 v1**（§1.1）⇒ 这条对 elden 无效 |

关键点：**fcitx5 不创建也不消费 `zwp_text_input_v3`**。它作为 IM 客户端拿 `zwp_input_method_v2`，键事件靠**键盘 grab** 拿：

```cpp
// src/frontend/waylandim/waylandimserverv2.cpp:214-222
// There can be only one grab. Always release old grab first.
keyboardGrab_.reset();
keyboardGrab_.reset(ic_->grabKeyboard());
if (!keyboardGrab_) { WAYLANDIM_DEBUG() << "Failed to grab keyboard"; }
```

⇒ 只要 fcitx5 占了 IM 槽位，它就必须 grab 键盘才能拿到按键，而**它自己不画键盘**（无 OSK 视图）。
这就是 `reports/ime-chinese-20261109.md` §3 表 B 臂里「能组词但没有屏幕键盘」的结构性原因：
**不是配置错，是 fcitx5 根本不提供 OSK。**

### 2.2 反面：`GTK_IM_MODULE=fcitx` 会让 GTK 应用彻底不用 text-input-v3

- `fcitx5-gtk` 自述：「**Gtk im module for fcitx5 and glib based dbus client library**」
  （https://github.com/fcitx/fcitx5-gtk ，README 首行）⇒ GTK 侧的 fcitx 通道是 **DBus 进程间**，不是 Wayland 协议。
- GTK 一旦被 `GTK_IM_MODULE` 指定了外部 IM 模块，就不会创建 `zwp_text_input_v3` 对象；
  Qt 同理（`QT_IM_MODULE`），XWayland 同理（`XMODIFIERS`）。
- 与 §1.3 合起来：**当所有应用都被 `GTK_IM_MODULE=fcitx` 接管时，桌面上可能一个 text-input-v3 客户端都不剩
  ⇒ phoc 永远不会 `activate` OSK**。这正是本项目 Alpine 时期 `PITFALLS/sessions/59` §5 写下的结论
  （「GTK 不用 text-input-v3 ⇒ phoc 永远不通知 squeekboard」），当时用 `elden-ime-focusd` 桥掉了。

### 2.3 phoc × IME 的已知冲突（上游 issue，非我们环境特有）

| issue | 状态 | 内容 |
|---|---|---|
| **phoc #302** “If IME is installed on the system, OSK will not be elevated to top surface.”（2022-10-10 创建，**至今 opened**，源站 https://gitlab.gnome.org/World/Phosh/phoc/-/work_items/302） | OPEM | 复现步骤原文：`apt install fcitx5 fcitx5-mozc` → 启 IME → 重启 Phosh → 循环 `busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true` → `pkexec echo test` ⇒ **OSK 不提层、无法输入密码**。原文：“Issue can be worked around by reverting 13ee2645dbc409fca7b2b22fca07f9cfafd76830” |
| phoc #198 / phosh #485 “Active app hides while using fcitx5”（2021-02） | opened | 旧年遗留 |
| phoc #153 “input-method-v2 not setting cursor correctly”（2020） | opened | IM 光标矩形不准（影响候选窗定位，不影响弹出） |

⚠ phoc #302 的措辞（“not elevated to top surface”）只对应**层叠层级**问题（锁屏密码框前 OSK 被遮挡），
**不是**「OSK 不弹」；本次亲自看到的「不弹」另有原因（§7）。不要拿 #302 当本次根因。

### 2.4 fcitx5 侧 issue 检索结果（空结果也要写清楚口径）

- `gh search issues --repo fcitx/fcitx5 phosh` ⇒ **0 条**；`--repo fcitx/fcitx5 "input method wayland"` 15 条里无一条提 phoc/phosh。
- 相关但不针对 phoc 的：
  - fcitx5 #1088 “fcitx5 is reporting lacking kimpannel in gnome on ubuntu 24.04”（open）——与 `PITFALLS #578`（无 SNI 托盘）同类。
  - fcitx5 #1609 “fcitx5 never sees the caret pixel position from any Wayland app”（closed 2026-07-15）——关系到候选窗/OSK 定位信号的可信度。
- ⇒ **未找到**「fcitx5 与 phoc 已知不兼容」的官方条目；现有兼容性事实只有 phoc #302（层级）与「IM 槽位独占」（§1.2）。

### 2.5 本节结论

1. fcitx5 waylandim 只需要 `zwp_input_method_v2` + `virtual_keyboard_v1`，**不需要也不需要提供** text-input-v3；
2. 它必须 grab 键盘且**不画键盘** ⇒ 与任何「拿同一 `zwp_input_method_v2` 槽位当 OSK」的实现**结构性互斥**；
3. `GTK_IM_MODULE=fcitx` 会让应用绕过 text-input-v3，这才是「OSK 收不到焦点」的真正断裂点（fcitx5 本身无错）。

DONE 2

## §3 xime 项目是什么

**取证**：`gh api`（已登录 `xiaquwan1001`）直取元数据 + README/PROGRESS/DECISIONS/源码，不靠搜索摘要。
（注意：GitHub 匿名 REST 已限流，`api.github.com/search` 匿名 403；本次改用已认证的 `gh`。）

### 3.1 先消除歧义：`xime` 名下有三个不相关的东西

| 项目 | 是什么 | 元数据（2026-11-10 取） | 与本次相关吗 |
|---|---|---|---|
| **`ximeiorg/Xime`** | **Android** 输入法（Kotlin，Rime 内核，五笔/拼音），F-Droid 上架 | stars **1370**、GPL-3.0、`pushed 2026-11-10`（活跃） | ❌ 安卓 IME，帮不了 Linux/Phosh |
| **`ximeiorg/XimeChe`**（曦码·澈） | **Linux 桌面**输入法（Rust + librime，不依赖 ibus/fcitx，自己对接 Wayland） | stars **35**、**GPL-3.0**、create `2026-05-11`、pushed **2026-11-02**、默认分支 `main` | ✅ **用户说的应是这个** |
| `ximeiorg/XimeYao` | Windows 版（Rust，51★）；另有 `libximecore`（共用库，pushed 2026-11-10） | — | ❌ |

### 3.2 XimeChe 关键事实（逐条带出处）

| 项 | 事实 | 出处 |
|---|---|---|
| 仓库 / 作者 | `github.com/ximeiorg/XimeChe`，作者 GitHub 名 `kingzcheung`（PR 均来自该账号）；同组织另有安卓版/Windows 版 | `gh api repos/ximeiorg/XimeChe`；commits 里 `Merge pull request #26 from kingzcheung/main` |
| 许可 | **GPL-3.0** | `gh api ... --jq .license.spdx_id` = `GPL-3.0` |
| 活跃度 | 2026-05-11 建仓，最近 push **2026-11-02**，317 commits 量级，仍在迭代（v0.2.3） | commits 列表；PROGRESS.md |
| 定位 | “一个用 Rust 实现的 Linux 输入法，**不依赖 ibus 和 fcitx**，直接对接 Wayland 和 librime”；“**不是 ibus/fcitx 的插件**” | README 首两段 |
| 支持矩阵（作者自述） | “**当前输入法只支持 wayland 应用和 KDE（KWin）桌面，不支持 Gnome**…登录 KDE 时需选 wayland 模式”；“**我只考虑支持 KDE，不会考虑支持 Gnome**” | README |
| 协议 | 主打 **`zwp_input_method_v1`**（KWin）；同时**已有 v2 实现**：`crates/xime-wayland/src/im_v2.rs`（1167 行，模块注释 “Common backend interface shared by the **v1 (KWin) and v2 (GNOME/wlroots)** input method implementations”，且 `lib.rs` 里 `pub use im_v2::…ZwpInputMethodManagerV2`） | `crates/xime-wayland/src/{lib.rs,im_v2.rs}`；`crates/xime-wayland/protocols/{input-method-unstable-v1.xml,input-method-unstable-v2.xml,virtual-keyboard-unstable-v1.xml}` |
| 架构 | daemon（DBus 服务 + Rime + Wayland）+ launcher（从 KWin 收 `WAYLAND_SOCKET` fd）；候选窗**自绘**（tiny-skia/cosmic-text，iced 打包），托盘用 SNI+DBusMenu | README 「架构」节；`crates/xime-ui/Cargo.toml`（`iced_tiny_skia`/`tiny-skia`） |
| 与 squeekboard 的关系 | **无任何关系**：不基于 squeekboard，也不提供 OSK（它是桌面 IM，假定有物理键盘）；不 fork/submodule squeekboard | `git trees` 无 squeekboard 相关路径；README 无提及 |
| 已知缺口（作者自己写的） | ① v1 多 context 共享 serial ⇒ 偶发选词不上屏；② v1 无 `release grab`/`context.destroy` ⇒ 合成器侧留孤儿；③ **Alt+Tab 时 KWin 1ms 内连发多轮 ACTIVATE/DEACTIVATE** ⇒ 客户端无解；④ v2 路径未声明支持任何具体合成器的测试证据 | `PROGRESS.md`「未修的已知问题」 |

### 3.3 XimeChe 对 elden 的**可用性判定**（直说）

- 它想取代 fcitx5 做桌面 IM，**不是「OSK 与 fcitx5 共存」的方案**，所以**不能直接拿来做这次的需求**。
- 但它证明了**一个可复用的结构**：`input-method-v2 客户端 + virtual-keyboard 注入 + 自绘候选层`
  在 wlroots 类合成器上是可行的（`im_v2.rs` 里 `requestGlobals` 有 `zwp_input_method_manager_v2`、
  `zwp_virtual_keyboard_manager_v1`，并 import 了 `zwp_text_input_v3` 的常量）。这与 fcitx5 waylandim 的协议需求**完全同构**（§2.1）。
- 它的 v2 路径**从未在 phoc 上跑过**（作者只保 KDE）⇒ 拿它当「phoc 兼容性证明」是**过度外推**；
  能引用的只有「协议组合在同一类合成器上能跑通」这一层。

DONE 3

## §4 hook 方法全集（OSK 与 fcitx5 共存）

前提事实（已在 §1/§2 取证）：**一个 seat 只有一个 `zwp_input_method_v2` 槽位**；
但**「给手机注入按键」不需要这个槽位**——`zwlr_virtual_keyboard_manager_v1` 是另一个全局，任何客户端都能用
（phoc 的 handler 不做任何权限检查：`src/virtual.c:13-23` 直接 `phoc_seat_add_device (seat, &keyboard->keyboard.base)`）。
这就是所有 hook 的共同地基。

### (a) 在 phoc 内部让 OSK 与 IM 分居不同协议

| 项 | 内容 |
|---|---|
| 现状 | phoc 只能把「键盘该出来」表达为 `zwp_input_method_v2.activate`（`input-method-relay.c:230-237`），而这个事件只能发给**占了槽位的那个客户端**。无法「激活 A 的键盘、把按键交给 B」。 |
| 可行挂钩 | ① 在 `activate_osk()` 旁加一条旁路：除发 IM activate 外，再通过 D-Bus（如 `mobi.phosh.Phoc.DebugControl` 同款私有接口，`src/debug-control.c`）或 `phoc.ini` 策略通知独立的 OSK 进程；② 在 seat 的 keyboard focus 变化时（不只 text-input）调 `activate_osk`，即「有焦点就弹盘」。 |
| 代价 | C 补丁 + 重新打 phoc 包（本项目已有先例：`patches/upstream/phoc-im-keyboard-grab-2026-10-18/`，设备上 meson 构建 14 s）；每次 phoc 升级要重做；② 会连终端/游戏里都弹盘，必须配 app_id 黑名单（stevia 已经有 `pos-activation-filter.c` 的同类机制可抄）。 |
| 可验证判据 | 打完补丁后：`busctl --user monitor` 应看到道具发起的调用；phoc 日志出现 `Explcit request to show input panel` 或新加的点位日志；OSK 进程收到 activate（wvkbd/stevia 自身日志）。 |

### (b) squeekboard 的 `sm.puri.OSK0` 控制面 + libei / virtual-keyboard 注入

| 子项 | 事实（带出处） | 可用性 |
|---|---|---|
| `sm.puri.OSK0.SetVisible(bool)` 控制面 | squeekboard/stevia 都实现（stevia：`pos-osk-dbus.c:17-18,105-117,188`；在机 owner = pid 2394） | ✅ **现成可用**，`gdbus call … SetVisible true` 就能弹（与 fcitx5 无关） |
| libei / EIS 注入 | **phoc 0.58 完全不支持**：源码树 `grep -rn "libei\|eis"` 零命中（只在 wlroots 外部才有 ei 支持） | ❌ 不可用，不要往这条路上投时间 |
| virtual-keyboard 注入 | phoc 全局 `zwlr_virtual_keyboard_manager_v1`（`desktop.c:700`），无权限门槛 | ✅ **可用，是真正的共存地基** |
| 【关键发现】**wvkbd 是唯一「不占槽位也能出键盘」的现成 OSK** | `jjsullivan5196/wvkbd` `main.c:1240-1252` **无条件** `zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(...)`；`:1260-1263` 只是**额外**去抢 IM v2 槽位拿 activate/deactivate 做自动显隐，而 `im_unavailable()` 是**空函数**（`main.c` 定义 `{ }`）⇒ 槽位被 fcitx5 占了 wvkbd 依然能打字 | ✅ 协议层面 **与 fcitx5 waylandim 共存完全成立** |
| wvkbd 活跃度 | stars **486**，`pushed 2026-10-27`，非归档 | ✅ 维护中 |

⚠ 未取证的风险点（不要写成结论）：fcitx5 grab 键盘后，wvkbd 经 virtual-keyboard 注入的按键是否会先进入 grab（即被 fcitx5 拿去组词）而不是直接进应用。
按 wlroots 的 grab 语义推断「会进 IM」，但**需实验确认**（§6 E4）。

### (c) fcitx5 的 kimpanel/dbus 前端当「聚焦与几何」信号源（现有 focusd 走的这条）

**上游源码证实这是被支持的钩子，不是 hack**：

- `fcitx5/src/ui/kimpanel/kimpanel.cpp` 是 **UI/panel addon**，它一旦在 session bus 上看到
  `org.kde.impanel`（`:205-232`），就向它 Introspect，并据此选光标矩形的下发方式：
  `SetSpotRect` / `SetRelativeSpotRect` / `SetRelativeSpotRectV2`（`:55-57, 235-244`）。
- 触发时机在源码里写死为两个事件（`:248-250`）：`EventType::InputContextFocusIn` 与
  `EventType::InputContextCursorRectChanged`，且要求 `inputContext->hasFocus()`。
- ⇒ `elden-ime-focusd` 把 `SetRelativeSpotRect` 当「聚焦」信号**是正解型 hook**（上游明确的事件点），
  但注意两个边界：① 只有焦点**进入**，没有 FocusOut（所以收起键盘没有信号，这是个设计缺陷不是 bug）；
  ② 它要求 fcitx5 自己有 InputContext（GTK/Qt IM 模块会创建），若应用走 waylandim（B 臂）则 kimpanel 仍活但无意义。
- 代价：**最低**（二进制已存在 `patches-userland/zh-ime/elden-ime-focusd.c`；Debian 栈只是**没部署**，见 §7）。
- 判据：`busctl --user list | grep -F org.kde.impanel` 有 owner；`/tmp/elden-ime-focusd.log` 每点一个输入框 +1 行；
  同时 `gdbus call … sm.puri.OSK0 … Visible` 从 `false` 变 `true`。

### (d) 三条路线收益/成本对比

| 路线 | 能解决什么 | 代价 | 风险 | 判据 |
|---|---|---|---|---|
| **D1. 只补 focusd（当前栈：fcitx5 `--disable waylandim` + stevia）** | 「点输入框 OSK 不弹」——100% | 拷一个 158 行 C 程序 + 一个 systemd user unit；零上游改动 | ① 无自动收起（需手动/图标）；② 仍不支持「不用 GTK/Qt IM 模块的 Wayland 原生 app」组词（但 elden 当前环境三变量全设，覆盖了 GTK3/4/Qt/X11） | §6 E1/E2 |
| **D2. fcitx5 waylandim（全协议）+ wvkbd 当 OSK** | 变成「真正 Wayland 原生 IM + 屏上键盘」两组件分居不同协议——**架构上最干净** | ① 必须 phoc ≥ 0.59（否则 keyboard-grab NULL 解引用崩合成器，§5）；② 装 wvkbd；③ 候选窗仍靠 fcitx5（无 SNI 托盘问题 #578 依旧） | 未验证点：grab 与 virtual-keyboard 的交互（§6 E4）；stevia 会因 `unavailable` 自动退出（需保留 `--allow-replacement`） | §6 E4/E5 |
| **D3. 改换合成器（wlroots 系 + fcitx5 waylandim）** | 证明「协议层不缺东西」 | 丢掉整个 phosh shell（phosh 只能跑在 phoc 上）⇒ 手机 UX 全重做 | 对 G1 目标是倒退 | 仅作实验台：`sway` 同样建 `wlr_input_method_manager_v2` + `wlr_text_input_manager_v3`（`sway/server.c:463-469`） |
| **D4. 换 OSK（phosh-osk-stub → 已改名 stevia；wvkbd）** | wvkbd = D2 的组件；stevia 已是在用 OSK | 低 | 单独换 OSK **不解决**「应用不报 text-input」这个根因（§1.3） | — |
| **D5. 靠 stevia 自带 completer 做中文** | 零冲突（同一进程内） | 0 | **做不到**：`src/completers/` 只有 hunspell/presage/uim/fzf/pipe/varnam，无拼音引擎；上游 #108/#109 “Support for Chinese word completion” **仍 open** | — |

### (e) 上游是否已合并修复

见 §5。一句话：**与本项目最相关的那个 phoc 崩溃修复已在 0.59_rc1 里（commit `bb1f7465`），而安装的 0.58.0 没有**；
但「OSK 不弹」**不是上游 bug**，是 text-input-v3 焦点语义的必然结果，上游不会修。

DONE 4

## §5 上游修复状态（截至 2026-11-10）

| 项 | 状态 | 证据 |
|---|---|---|
| phoc **keyboard-grab NULL 解引用**（本项目 2026-10-18 自写补丁的那个 bug） | ✅ **已上游**：commit `bb1f7465` “input-method-relay: Fix keyboard-grab NULL deref”（2026-10-26），进 **v0.59_rc1（2026-11-08）**；v0.58.0（2026-10-04）**不含** | `GET /projects/World%2FPhosh%2Fphoc/repository/commits?path=src/input-method-relay.c`；tags API：`v0.58.0 2026-10-04`、`v0.59_rc1 2026-11-08`；0.58.0 tarball 里 `src/input-method-relay.c:119-123` 仍是裸 `keyboard_grab->keyboard`，wlroots 0.20.2 `types/wlr_input_method_v2.c:274` 仍发 `wl_signal_emit_mutable(..., NULL)` ⇒ **在机 phoc 0.58.0-1 理论上仍会崩**（Debian 是否 backport 未核验，见 §8） |
| phoc **text-input-v3 version 2** | ✅ 在 0.58：`832125ad`（2026-09-19）+ wlroots.wrap 里 4 个 `text-input-v2/000x` patch | `subprojects/wlroots.wrap`；`src/desktop.c:60` |
| phoc **#302 IME 安装后 OSK 不提层** | ❌ 仍 open（2022-10-10 至今） | §2.3 |
| phosh **自动弹 OSK 的策略** | ❌ 上游不打算做：`osk-manager.c:26-30` 注释明写 “there's no way to ensure keyboard state via this interface … Any text input can make the keyboard…”；phosh #1004（可切换 OSK）2023-11-18 关闭 | §1.4 |
| stevia **支持 fcitx5/ibus** | ❌ 未支持：#74 “Support Chinese input using ibus or fcitx5” 状态 **closed（2026-02-28）**，但代码里只有「把 gsettings 里 ibus engine id 映射成自带 layout」的逻辑，注释原文 `/* We don't actually do ibus bus but try to match these to completers */`（`src/pos-input-surface.c:2168`）⇒ 判定为「不接 ibus/fcitx 总线」 | GitLab API issue #74；stevia-main tarball 源码 |
| stevia **中文词组补全** | ❌ 仍 open：#108 “Support for Chinese word completion”、#109 “Allow expanding the completion list for chinese”（2026-04-30 创建） | GitLab API |
| squeekboard | ☠️ **unmaintained**（项目描述原字） | §1.5 |

⇒ **最低版本建议（若走 D2）**：`phoc ≥ 0.59`（或给 0.58 打 `bb1f7465` 等价补丁 —— 与本仓 `patches/upstream/phoc-im-keyboard-grab-2026-10-18/` 思路一致但因 wlroots 0.20 行为变化需重写）。

DONE 5

## §6 最小判别实验清单（本轮**只写不跑**，按「主机可做 / 必须上机」分组）

### 6.0 先修一条前置事实（影响 §1.3 的结论，本节全部判据都以这条为准）

§1.3 写的是「`ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION == 1`，所以 `handle_text_input_enable()` 里的
版本判断恒成立 ⇒ enable 路径是死代码」。**这条不成立**，本次复核（主机侧，纯只读）：

| 证据 | 位置 | 结论 |
|---|---|---|
| `show_input_panel` 在当前 wayland-protocols 里是 **`since="2"`**，`zwp_text_input_v3` 接口本体 `version="2"` | `wayland-protocols` main `unstable/text-input/text-input-unstable-v3.xml:518`（`<request name="show_input_panel" since="2">`）、`:50`（`<interface name="zwp_text_input_v3" version="2">`）、`:585`（manager `version="2"`）；抓取：`curl -sL https://gitlab.freedesktop.org/wayland/wayland-protocols/-/raw/main/unstable/text-input/text-input-unstable-v3.xml` | 该宏 = **2**，不是 1 |
| phoc 0.58 自己把 wlroots 顶到 text-input v2，并把 `TEXT_INPUT_VERSION` 从 1 改 2 | 解包副本 `subprojects/packagefiles/wlroots/text-input-v2/0004-text-input-v3-Bump-protocol-version-to-2.patch:22-25`（`-#define TEXT_INPUT_VERSION 1` / `+#define TEXT_INPUT_VERSION 2`）；`src/desktop.c:60` `#define PHOC_TEXT_INPUT_VERSION 2` | 在机 phoc 的全局 version=2 |
| 现役客户端**仍然按 v1 绑定** | GTK4 `gtk/gtkimcontextwayland.c`（gtk-4-22 分支）`:727-728` `wl_registry_bind (…, &zwp_text_input_manager_v3_interface, 1)` | `wl_resource_get_version()==1 < 2` ⇒ **enable 路径对所有现役 GTK 客户端仍然生效**，phoc 在 enable 时会 `activate_osk()` |

⇒ 正确表述：**phoc 0.58 在「有焦点的 text-input-v3 客户端 enable」时确实会 `activate_osk()`**
（`src/input-method-relay.c:242-263`），版本判断只对「将来 bind 到 2 的客户端」短路；
`show_input_panel`（`:266-285`）是**并行的第二条**路径，不是唯一路径。
另外 GTK 直到 main 分支才加 `show_input_panel`（`gtk/gtkimcontextwayland.c:1381-1397`
`gtk_im_context_wayland_activate_osk_with_event()`，带 `get_version() >= SHOW_INPUT_PANEL_SINCE_VERSION` 判断 ⇒
v1 绑定会走 `else` 再发一次 `enable`）；gtk-4-16/4-18/4-20/4-22 四个分支里 `show_input_panel` 出现次数 = **0**（本地 grep 计数）。
**这条修正不改变 §7 的方向（断裂点在客户端），但改变了判据**：查「有没有发 show_input_panel」是**错的**，
该查「有没有 `zwp_text_input_v3.enable`」。

### 6.1 纯主机可做（零设备动作，本轮已做的标 ✅，其余是「复制命令即可复跑」）

| # | 目的 | 命令 / 看哪个文件 | 期望 | 失败意味着什么 | 设备 |
|---|---|---|---|---|---|
| **H1** ✅ | 钉死 `SHOW_INPUT_PANEL_SINCE_VERSION` 的真实值 | `grep -n 'show_input_panel\|interface name="zwp_text_input_v3"\|interface name="zwp_text_input_manager_v3"' <wayland-protocols>/unstable/text-input/text-input-unstable-v3.xml`；配合 `subprojects/packagefiles/wlroots/text-input-v2/0004-*.patch` | `since="2"` + `TEXT_INPUT_VERSION 2`（已见） | 若设备上的 wayland-protocols 仍是 v1 XML（没有 `show_input_panel`），则 phoc 0.58 根本编译不过 ⇒ 说明 Debian 那份 phoc 打包链与我读的 tarball 不同，§1.3 的原始说法反而要对——此时须先解包 Debian 源码包再判 | 否 |
| **H2** ✅ | 确认现役客户端 bind 到 v1、从不发 `show_input_panel` | `for b in gtk-4-16 gtk-4-18 gtk-4-20 gtk-4-22 main; do curl -sL https://raw.githubusercontent.com/GNOME/gtk/$b/gtk/gtkimcontextwayland.c \| grep -c show_input_panel; done` | 4.16–4.22 全 0；main = 3（已在本地验证） | 若某个在役分支非 0，则「客户端不请求 OSK」这个前提要重写 | 否 |
| **H3** ✅ | 确认 stevia 的可见性**只**由 IM `active` 驱动，并有三道静默闸 | 读 stevia `src/pos-app.c:292-302`（`surface-visible` ↔ `sm.puri.OSK0:visible` 双向绑定；`im:active` → `surface-visible`，`G_BINDING_SYNC_CREATE`）、`:173-198`（`set_surface_prop_surface_visible()`：`screen-keyboard-enabled` / `activation-filter` / `hw-tracker` 任一为假 ⇒ 强制 `visible=FALSE`，只打一行 `g_debug ("active: %d, enabled: %d")`） | 确认「收到 activate 但仍不显示」只有这 3 个出口 | 若有第四条出口（例如 layout 断言失败导致 surface 不 map，`reports/ime-chinese-20261109.md` §6 见过 `pos_osk_widget_locate_key: assertion` ），则 §7 的「三层」要加一层「OSK 自身渲染」 | 否 |
| **H4** ✅ | 确认「现役组合下 GTK 应用不创建 text-input-v3」是**构建默认**而不是现场手改 | `grep -n 'GTK_IM_MODULE' rootfs/debian/daily-baseline.sh`（`:134-145` 写 `/etc/environment.d/50-elden-ime.conf`，`GTK_IM_MODULE=fcitx`） | 默认就设 fcitx ⇒ GTK 侧走 DBus IM 模块，不建 `zwp_text_input_v3` | 若设备上环境文件实际不存在/被覆盖，则「无 text-input 客户端」这条要改成「客户端有但 phoc 没发 activate」 | 否（但需上机读 `/etc/environment.d/` 与进程环境才算实测，见 U3） |
| **H5** ✅ | 确认 fcitx5 waylandim 与 OSK **结构互斥**（不是配置问题） | 报告 §2.1/§2.2；对端源码 `src/frontend/waylandim/waylandimserverv2.cpp:51-71,214-222` | fcitx5 只要 `zwp_input_method_v2` + `zwlr_virtual_keyboard_v1`，自身无键盘视图 | 若发现 fcitx5 有 OSK 前端（目前无），则「B 臂无键盘」不再必然 | 否 |
| **H6** ✅ | 确认「不占槽位也能出键盘」的现成实现存在 | wvkbd `main.c:1240-1252`（无条件 `zwlr_virtual_keyboard_manager_v1_create_virtual_keyboard`）、`:1260-1264`（`im_mgr != NULL` 才额外抢 IM v2，仅用于自动显隐）、`:557-561`（`im_unavailable()` 空函数体） | 槽位被占也能弹、也能打字 | 若 `im_unavailable` 会退出进程，则「混合架构」需改 wvkbd | 否 |

### 6.2 必须上机（按「信息量/成本」排序；全部零装包、可秒回退，除 E8）

> 统一前置：`export XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus`（`su - xuqianhui1001` 里执行）。

| # | 目的 | 命令 / 改哪个文件 | 期望 | 失败意味着什么 | 需动设备 | 风险/回退 |
|---|---|---|---|---|---|---|
| **E0** | 一刀切两半：区分「OSK 本体坏了」与「信号没来」 | `gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible true`（`false` 收起） | 键盘**出现** | 键盘仍不出现 ⇒ 与 text-input 完全无关，问题在 stevia 渲染/合成器层（含 §6.1-H3 的第四条出口），后续 E1–E3 全部不用做 | 是（只点一下 D-Bus） | 无；`SetVisible false` 即回退 |
| **E1** | 判「有没有 text-input-v3 客户端 / 有没有 enable」（本轮最关键的判别） | `env -u GTK_IM_MODULE -u QT_IM_MODULE WAYLAND_DEBUG=1 /usr/bin/gnome-control-center 2>&1 \| grep -E 'zwp_text_input_v3\|zwp_input_method_v2'`，点进搜索框；对照臂 = 默认环境（带 `GTK_IM_MODULE=fcitx`）跑同一个程序 | 默认臂**无** `zwp_text_input_v3` 输出；`env -u GTK_IM_MODULE` 臂出现 `zwp_text_input_v3.enable` | 默认臂也出现 `enable` 却没有键盘 ⇒ 「客户端不建 text-input」这条根因被否掉，改查 phoc→stevia 的 `activate`（E2/E3） | 是（开 GUI 程序） | 无写盘；关窗即止。若设备无 `gnome-control-center`，用 `python3` + `Gtk.Entry`（`python3-gi` 已在基线）写 10 行临时窗口 |
| **E2** | 判 stevia 是否**拿到** IM v2 槽位（`sm.puri.OSK0` 的 owner ≠ 槽位持有者） | `journalctl --user -u phosh-osk-stevia -b --no-pager \| grep -c 'Input method unavailable'`（该 warning 在 `stevia/src/pos-input-method.c:221-226` `handle_unavailable()`，`g_warning` 一定入日志） | 计数 = **0** | 计数 ≥1 ⇒ 槽位被 fcitx5 或残留进程占了，phoc 的 `activate` 全进了黑洞；修法 = 确认 `fcitx5` 带 `--disable waylandim`（`rootfs/debian/daily-baseline.sh` 的 unit 已带）并重启 stevia 与 fcitx5 **按顺序**（先 fcitx5 后 stevia） | 是（只读日志） | 零改动（这条只读，理论上可 SSH 做；但按本轮纪律归入「上机」） |
| **E3** | 判 phoc 有没有发 `activate` | `systemctl --user restart phosh-osk-stevia` → `journalctl --user -u phosh-osk-stevia -f`（stevia 的 `handle_activate()` 有 `g_debug`，`src/pos-input-method.c:89-108`），再点输入框 | 每点一次出现一条 `handle_activate` | 不出现 ⇒ 信号断在 phoc 侧（`relay->input_method == NULL` 或 `text_input_is_focused()` 为假或压根没客户端 enable），回 E1/E2 | 是（重启 user service） | 回退 = `systemctl --user restart phosh-osk-stevia`；**不要**重启 phoc（会掉整个会话） |
| **E4** | 判「phosh 侧不兜底」是否唯一放大器：把 fcitx5 完全停掉再看 | `systemctl --user stop fcitx5 && env -u GTK_IM_MODULE <同一个 GTK4 程序>`，点输入框 | OSK **自动弹出**（说明协议链路完好，缺的只是「有 text-input 客户端」） | 仍不弹 ⇒ 问题不在 fcitx5 抢路，回到 E2/E3 | 是 | 回退 = `systemctl --user start fcitx5`（unit 在 `/etc/systemd/user/`，`Restart=on-failure` 不影响 stop） |
| **E5** | 判 stevia 的三道闸是否把键盘压住了 | `gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled`；`gsettings list-recursively \| grep -i 'ignore-hw-keyboard'`；并**拔掉所有外接键鼠/USB hub**后重试 E1 | `screen-keyboard-enabled=true`；无外接键盘时 `hw-tracker` 的 `allow-active=true` | 若 `screen-keyboard-enabled=false` ⇒ 一行 `gsettings set` 就修，与本报告的架构讨论无关；若有外接键盘 ⇒ 关掉 `ignore-hw-keyboards` 或拔掉 | 是（要拔插，属物理动作，需用户） | 无 |
| **E6** | 量化「无兜底」的代价：验证 phosh 不跟随焦点 | `gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled` 设为 `true` 后，**不点输入框**观察 OSK0 `Visible`；`busctl --user monitor sm.puri.OSK0` 一边点焦点 | `Visible` 恒 `false`，直到有 text-input 客户端 enable（或 E0 手动 true） | 若点任意窗口就 `Visible=true` ⇒ 存在我没找到的兜底路径（phosh 版本差异），§7 的「三层都沉默」要改 | 是 | 无 |
| **E7** | 把「键盘有、组词无」这一半也做掉的最小验证（**需先获批装包**，本轮不做） | 装 `fcitx5-frontend-gtk4` 后：`GTK_IM_MODULE=fcitx` + E0 手动弹键盘，点 stevia 键盘敲 `nihao` | 输入框出现候选/「你好」 | 只有字面量 ⇒ fcitx5 的 grab 拿不到 virtual-keyboard 注入的键（§4(c) 的未取证点），混合架构需另设「OSK 直接喂 fcitx5」通道 | 是（装包） | 需批准；`apt remove` 回退 |
| **E8** | 混合架构的可行性终判（**需装 wvkbd + phoc ≥0.59**，本轮不做，仅在 D2 立项后做） | `wvkbd -L 300` 与 `fcitx5 -r`（waylandim 开）同时跑，点输入框敲 `nihao` | 键盘由 wvkbd 画、候选由 fcitx5 出、上屏「你好」 | 若键被 fcitx5 grab 吃掉但 wvkbd 自己上屏 ⇒ 需禁用 grab 或改 fcitx5；若 wvkbd 因 `unavailable` 仍正常但按键重复 ⇒ 双写问题 | 是（装包 + 可能要换 phoc） | 需批准；phoc 换代风险高（`bb1f7465` 未在 0.58 里，见 §5） |

**建议执行顺序**：`E0 → E2 → E1 → E4 → E3 → E5`。E0 与 E2 各一条只读命令就能把「OSK 本体 / 槽位」两个
最便宜的假设排除，E1 才决定 §7 的三层结论落哪一层。

DONE 6

## §7 结论性问题：为什么「点输入框 OSK 不弹」——到底卡在哪一层

### 7.1 机制链（四段，每段都能单独否掉）

一次「点输入框」想让键盘出现，必须依次成立：

| 段 | 责任方 | 必要条件（源码出处） | 现役（A 模式）是否成立 |
|---|---|---|---|
| **① 客户端层** | 应用（GTK/Qt/Firefox） | 应用**创建 `zwp_text_input_v3` 对象并 `enable`**（或 `show_input_panel`，但现役客户端没有：§6.0-H2） | ❌ **不成立**：`GTK_IM_MODULE=fcitx`（`rootfs/debian/daily-baseline.sh:141-144`）让 GTK 走 fcitx 的 DBus IM 模块，**根本不建 text-input 对象** ⇒ 后面三段全部不会发生 |
| **② 合成器层** | phoc | 有聚焦的 text-input 客户端 + `relay->input_method != NULL`，才 `wlr_input_method_v2_send_activate()` + `elevate_osk()`（`src/input-method-relay.c:229-238`，触发点 `:242-263` / `:266-285`） | 前提①不成立 ⇒ 从未走到这里（**不是 phoc 的 bug**，它按规范只对「声明要用 IM 的客户端」发 activate） |
| **③ 槽位层** | phoc + IM 客户端 | 一个 seat 只容一个 `zwp_input_method_v2`；第二个直接被 `unavailable`（`:484-491`）。stevia 就是那个客户端（`stevia/src/pos-input-method.c:301`），收到 activate 才把 `im:active` 置真（`:89-108`） | 结构上成立（fcitx5 带 `--disable waylandim`），但**只有日志能证明**（E2/E3，未取证） |
| **④ 显示层** | stevia + phosh | stevia：`im:active` → `surface-visible`（`pos-app.c:292-302`），但被 `screen-keyboard-enabled` / `activation-filter` / `hw-tracker` 三闸压住（`pos-app.c:173-198`）；phosh：**只**代理 `sm.puri.OSK0.Visible`，注释原文 *“there's no way to ensure keyboard state via this interface … Any text input can make the keyboard…”*（`phosh/src/osk-manager.c:26-30`），并且明确把「显示/隐藏」交回给 OSK 自己（`on_visible_changed()` 注释 *“Just need to sync the property, osk shows/hides itself”*，`:157-172`） | 若①②真断了，这一层**永远不会被触发**；phosh 也**没有任何兜底**（它不做「焦点即弹」，这是设计不是遗漏） |

### 7.2 卡在哪一层（明确裁决）

- **协议层：不缺任何东西。** `zwp_text_input_manager_v3`(v2)、`zwp_input_method_manager_v2`、`zwlr_virtual_keyboard_manager_v1` 三个全局都在
  （`src/desktop.c:686-687,700`）；IM v2 的「单客户端」是规范行为（`:484-491`），不是残缺。
- **合成器层（phoc）：不是 bug，是语义。** 「谁声明要用 IM，才给谁弹键盘」是 text-input 协议的原意；phoc 把
  `activate` 发给占槽位的 IM 客户端，而不是自己去问焦点窗口「你要不要键盘」。
- **phosh 策略层：主动放弃兜底。** `osk-manager.c:26-30` 与 `:157-172` 是源码级证据：phosh 认为键盘的显隐
  **属于 text-input 客户端与 OSK 两者之间的事**，自己只转发一个 D-Bus 布尔值。
- ⇒ **实际卡在「①客户端层」**：`GTK_IM_MODULE=fcitx` 把 GTK 的输入路径整体搬到 DBus，桌面上可能一个
  `zwp_text_input_v3` 客户端都不剩；**「phosh/phoc 不兜底」是同一个故障的放大器**——正因为三层都不兜底，
  症状才是「完全没反应」而不是「弹了一个空键盘」。
- **phoc #302 不是本症状**：那条讲的是「IME 装了以后 OSK 不被提到最上层」（锁屏密码框被遮），
  属层叠层级，与「压根不弹」是两个故障面（§2.3 已划清）；上游至今未修，但它**不会**让键盘不出现。
- **一句话归因**：不是协议缺、不是 phoc 挂、不是 phosh 坏，是**「手机上没有应用在用 Wayland 的 text-input 协议」**，
  加上**「Phosh 生态没有任何人负责兜底弹键盘」** ⇒ 双因叠加。

### 7.3 三种候选架构的取舍表

| | **A1. stevia 独占（现状 + 聚焦桥）** | **A2. fcitx5 独占 IM 槽 + 自绘 OSK** | **A3. 混合（fcitx5 占槽 + wvkbd/自绘键盘走 virtual-keyboard）** |
|---|---|---|---|
| 谁能组词 | 只有 GTK/Qt/XWayland 应用（经 `GTK_IM_MODULE=fcitx` DBus 前端）；Wayland 原生应用（Firefox-Wayland、GTK4 未设模块时）**不能** | **所有** Wayland 原生应用（fcitx5 waylandim v2，`waylandimserverv2.cpp:51-71`）+ GTK/Qt 模块应用 | 同 A2（fcitx5 仍霸占 IM 槽与 grab），键盘只是另一个 virtual-keyboard 客户端 |
| 谁画键盘 | `phosh-osk-stevia`（唯一 OSK，`sm.puri.OSK0` 的 owner） | **fcitx5 不画**（结构性缺键盘，§2.2）⇒ 必须另配 OSK：wvkbd（不占槽，`main.c:1240-1252`）或自写 GTK4 layer-shell | wvkbd（现成，486★，2026-10-27 仍在更新）或自绘 |
| 「点输入框自动弹」怎么实现 | **必须外挂桥**：phoc 永远不发 activate（因为没有 text-input 客户端）⇒ `elden-ime-focusd` 抓 `org.kde.impanel` 的 `SetRelativeSpotRect` 当聚焦信号调 `SetVisible(true)`（仓库现成：`patches-userland/zh-ime/elden-ime-focusd.c`，Alpine 时代已验证，PITFALLS sessions/59 §5） | 天然成立：应用 enable ⇒ phoc `activate` ⇒ 但 fcitx5 收到 activate **不画键盘** ⇒ 仍需 wvkbd 的自动显隐（wvkbd 可选抢 IM 槽拿 activate：`main.c:1260-1264`，但那会与 fcitx5 **再抢同一个槽**，后到者 `unavailable` ⇒ 只能二选一：wvkbd 开 `im_auto` 关闭 或 用 focusd 类桥驱动 wvkbd） | 同 A2，且必须解决「键盘显隐信号从哪来」：要么 wvkbd 抢槽（则 fcitx5 拿不到 activate，组词链路可能断），要么外部桥（focusd 调 wvkbd 的命令行/信号） |
| 需要改谁 | **零上游改动**：只部署 focusd + 一个 systemd user unit（本仓已有二进制与 unit 模板） | phoc ≥0.59（`bb1f7465` keyboard-grab NULL 解引用修复，§5）否则 fcitx5 grab 会崩合成器；装 wvkbd；候选窗依赖 fcitx5（Phosh 无 SNI ⇒ #578 的顶栏问题仍在，需保留现有 `fcitx5-indicator.py`） | 同 A2 + 键盘显隐的桥（可复用 focusd 的 im panel 钩子，但目标从 `sm.puri.OSK0` 换成 wvkbd） |
| 上游接受度 | 不需要上游 | **不需要上游**（纯组合现成组件），但依赖 phoc 版本 ≥0.59；fcitx5 上游对 phoc 无兴趣（`gh search issues --repo fcitx/fcitx5 phosh` = 0 条） | 同 A2；wvkbd 上游对「与 IM 共存」无明确态度，`im_unavailable()` 是空实现说明它**本来就不在乎槽位** |
| 现成度 / 成本 | ★★★★★ 最低（158 行 C + unit；Debian 栈只是没部署） | ★★☆ 中（换 phoc 版本 + 装 wvkbd + 调 grab 互斥） | ★★☆ 中（同 A2 再加一个桥） |
| 主要风险 / 已知缺口 | ① **无自动收起**（fcitx5 无 FocusOut 信号，PITFALLS sessions/59 §5）；② Wayland 原生应用仍不能组词；③ 若 stevia 被三道闸压住，桥也白搭（E5） | ① phoc 0.58 上的 grab NULL 崩溃（§5）；② `phoc #302` 的层叠问题在 IME 下更明显（锁屏/密码框）；③ wvkbd 与 fcitx5 的 grab 交互**未取证**（§4 风险点 / E7 E8） | ① 两处「谁拿 activate」二选一，需代码级决策；② 键盘候选窗与 fcitx5 候选窗可能重叠（定位信号来自 fcitx5 的 `#1609` 光标矩形不可靠问题） |
| 结论 | **恢复屏幕键盘的最省路径**（先修「能不能打字」） | 结构最干净，但要动 phoc 版本 + 装包，属下一阶段 | A2 的落地形态；先把 A1 做出来再评估 |

DONE 7

## §8 未找到 / 未取证清单（推断一律不进结论）

> 口径：本报告 §1–§5 中标「✅」的是**读源码/调 API 得到的事实**；下面这些都是**推断或未复现**，不要当实测引用。

| # | 未取证项 | 现有依据（只能算间接） | 用什么补（§6 编号） |
|---|---|---|---|
| **U1** | **phoc 在设备上到底有没有发 `activate`** | 只有源码推断（`input-method-relay.c:242-263`）；设备侧从未抓到该日志 | E3（stevia 的 `handle_activate` g_debug） |
| **U2** | **stevia 是否真的持有 IM v2 槽位** | 只有 `sm.puri.OSK0` 的 owner = pid 2394（`busctl --user list`）；但 `handle_unavailable()` 只打 warning、进程不退（`pos-input-method.c:221-226`）⇒ **owner 名 ≠ 槽位** | E2（`grep -c 'Input method unavailable'`） |
| **U3** | **设备上 `GTK_IM_MODULE=fcitx` 是否真的生效到 GUI 进程** | 仓库构建默认写 `/etc/environment.d/50-elden-ime.conf`（`daily-baseline.sh:134-145`），但「文件在」≠「进程环境有」；`/etc/environment.d` 是否被 phosh/phoc 的会话吞掉未核 | `tr '\0' '\n' < /proc/<pid>/environ \| grep IM_MODULE`（E1 前置） |
| **U4** | **GTK4 在设了 `GTK_IM_MODULE=fcitx` 时确实不创建 `zwp_text_input_v3`** | 证据链是「fcitx5-gtk 是 DBus IM 模块」+ Alpine 时期 PITFALLS sessions/59 §5 的实测；**Debian 栈上没有 `WAYLAND_DEBUG` 抓包** | E1 |
| **U5** | **phoc 0.58.0-1（Debian 包）是否已 backport `bb1f7465`** | 只核了上游 tarball 与 tag，没有 `apt-get source phoc` 的 debian/patches | 主机侧可做（未做）：`apt-get source` 或查 Debian salsa 的 patch 队列 |
| **U6** | **设备上 wayland-protocols 版本是否含 text-input v2 XML** | 由「phoc 0.58 能编译」反推必然含（推断）；未读设备包版本 | `dpkg -l wayland-protocols`（上机只读） |
| **U7** | **stevia 的三道闸（`screen-keyboard-enabled`/activation-filter/hw-tracker）在设备上的取值** | 只知道 2026-11-09 核过 `screen-keyboard-enabled=true`（旧报告 §6），另两道从未核 | E5 |
| **U8** | **fcitx5 grab 键盘后，virtual-keyboard 注入的键是否被 IM 吃掉** | §4 已标为风险点，纯推断（按 wlroots grab 语义猜「会进 IM」） | E7（需装包） |
| **U9** | **wvkbd 与 fcitx5 同时运行时，按键是否重复上屏** | 无任何实测 | E8（需装包 + 可能换 phoc） |
| **U10** | **Firefox 在设备上走 Wayland 还是 XWayland** | 旧报告 §7.2 已列为未定；未读 `about:support` | 上机 GUI 查看（成本高、收益低，暂缓） |
| **U11** | **stevia 的 `pos_osk_widget_locate_key: assertion 'row_num < self->layout.n_rows' failed`（2026-11-09 10:01 一条）是否与本症状同源** | 单条日志，无上下文；可能只是 layout 越界，与不弹无关 | 若 E0 通过（手动 `SetVisible` 能弹）则可判定**不同源**；否则需复现 |
| **U12** | **fcitx5 的 kimpanel 钩子在 Debian 栈上是否仍活**（A1 的桥依赖它） | 源码层确信（`fcitx5/src/ui/kimpanel/kimpanel.cpp:248-250` 在 FocusIn/CursorRectChanged 触发）；设备侧从未 `busctl --user list \| grep org.kde.impanel` | `busctl --user list \| grep -F org.kde.impanel`（只读） |
| **U13** | **`phosh` 是否有我漏掉的第三处兜底路径**（除 `osk-manager.c` 外） | 只读了 `osk-manager.c`（322 行，main 分支）；`phosh-shell.c` 只扫过 | E6（行为判据：不点输入框时 `Visible` 是否变） |

**另记两处文档不一致**（不改，只登记）：
1. `rootfs/debian/daily-baseline.sh:145` 的注释写「Phosh 0.55 的 phosh-osk-stevia 走 `zwp_virtual_keyboard`（不是 input-method v2）」——
   与源码不符：stevia 明确拿 `zwp_input_method_manager_v2`（`stevia/src/pos-input-method.c:301`），virtual-keyboard 是**输出**方向（键盘敲键送给应用），
   不是它获取 activate 的通道。注释过时，会让后来人误判「槽位无关」。
2. `reports/ime-chinese-20261109.md` §3 写「Wayland 的输入法槽位（`text-input-v3`）同一时刻只能有一个客户端」——
   单占的是 **`zwp_input_method_v2`（IM 槽）**，不是 `text-input-v3`（后者可以有任意多个客户端，每个应用一个）。

DONE 8

## §9 给 Main 的 3 句话结论 + 建议下一步

**三句话**

1. **协议面齐全、phoc 不背锅**：phoc 0.58 有 `text-input-v3`(v2) + `input-method-v2`(单槽) + `virtual-keyboard-v1`
   （`src/desktop.c:686-687,700`、`input-method-relay.c:484-491`），且对现役 v1 绑定客户端仍会在 `enable` 时发 `activate`
   （`input-method-relay.c:242-263`；§6.0 更正了 §1.3 关于版本常量的错误说法）；「点输入框不弹」的真正断裂点是
   **`GTK_IM_MODULE=fcitx` 让 GTK 完全不创建 `zwp_text_input_v3`**，于是 phoc 从无 activate 可发。
2. **phosh 只会放大故障、不会兜底**：`osk-manager.c:26-30` 与 `:157-172` 的注释明写「键盘显隐是 text-input 客户端与 OSK 之间的事，
   phosh 只用 D-Bus 表达偏好」⇒ 三层（客户端 / 合成器 / shell）同时沉默，症状才是「完全没反应」；`phoc #302` 讲的是层叠遮挡，不是本症状。
3. **两条路，先走便宜那条**：A1 = 维持「stevia 独占槽位 + fcitx5 `--disable waylandim`」，补部署仓库现成的
   `elden-ime-focusd`（focusd 抓 kimpanel `SetRelativeSpotRect` → `sm.puri.OSK0.SetVisible(true)`）即可恢复屏幕键盘，
   **零上游改动、零装包**，代价是无自动收起 + Wayland 原生应用仍不能组词；想「能组词 + 有键盘」必须上 A2/A3
   （fcitx5 开 waylandim 独占 IM 槽 + wvkbd 走 virtual-keyboard 画键盘），前提是 **phoc ≥ 0.59（`bb1f7465`）** 否则 grab NULL 崩合成器。

**最省的上机验证路径（一条链，全部零装包、可秒回退，约 5 分钟）**

```sh
# 0) 会话环境（su - xuqianhui1001 后执行）
export XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus

# 1) 一刀切：OSK 本体 + 渲染是否完好（E0）—— 期望：键盘立刻出现
gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible true

# 2) 槽位是否真在 stevia 手里（E2，只读）—— 期望：0
journalctl --user -u phosh-osk-stevia -b --no-pager | grep -c 'Input method unavailable'

# 3) 断裂点定位（E4，最有信息量的一步）—— 期望：停 fcitx5 + 去掉 IM 模块后，点输入框键盘自动弹
systemctl --user stop fcitx5
env -u GTK_IM_MODULE -u QT_IM_MODULE WAYLAND_DEBUG=1 gnome-control-center 2>&1 | grep -E 'zwp_text_input_v3\.(enable|commit)'
systemctl --user start fcitx5   # 回退

# 4) 若 2 = 0 且 3 里出现 enable 且键盘自动弹 ⇒ 只缺「聚焦桥」
#    部署 patches-userland/zh-ime/elden-ime-focusd.c（Alpine 时代已验证），零上游改动收口。
#    若 2 ≥ 1 ⇒ 先修槽位占用（fcitx5 必须带 --disable waylandim，且先起 fcitx5 再起 stevia）。
#    若 3 里无 enable 且键盘仍不弹 ⇒ 回到 E3（stevia handle_activate 日志）判 phoc 侧。
```

DONE 9
