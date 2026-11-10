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

## §2 fcitx5 侧：waylandim 需要哪个协议 + 与 phoc 的已知不兼容 —— 待填

DONE 2（待补）

## §3 xime 项目是什么 —— 待填

DONE 3（待补）

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
