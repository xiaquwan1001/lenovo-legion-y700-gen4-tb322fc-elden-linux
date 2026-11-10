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

## §4 hook 方法全集（OSK 与 fcitx5 共存） —— 待填

DONE 4（待补）

## §5 上游是否已合并修复 —— 待填

DONE 5（待补）

## §6 最小判别实验清单（不在本次执行） —— 待填

DONE 6（待补）

## §7 结论性问题：为什么「点输入框 OSK 不弹」 —— 待填

DONE 7（待补）

## §8 未找到 / 未取证清单 —— 待填

DONE 8（待补）

## §9 给 Main 的 3 句话结论 + 建议下一步 —— 待填

DONE 9（待补）
