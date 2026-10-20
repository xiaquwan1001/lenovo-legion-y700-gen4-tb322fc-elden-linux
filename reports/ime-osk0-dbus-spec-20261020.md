# 输入法控制面取证：sm.puri.OSK0 / Phosh 驱动链 / fcitx5 kimpanel / wvkbd 0.19.4

- 日期：2026-10-20
- 类型：**纯静态源码取证**（未接触设备、未 ssh、未改内核树、未重启/刷写）
- 方法：拉上游打包源码到 `/tmp/osk-probe/`（可复现命令见 §5），逐行核对 0.55 / 5.1.15 / 0.19.4 三个**已钉版本**，不用 `main`
- 适用前提（项目已知实测，本报告不重新质疑）：Alpine + Phosh 0.55.0 / phoc 0.55.1（内嵌 wlroots 0.20.0，已打 input-method keyboard grab NULL 补丁）；
  fcitx5(-u kimpanel)+Rime 持有 `zwp_input_method_v2`；wvkbd-mobintl 经 `zwp_virtual_keyboard_v1` 注入；
  `fcitx5-candbar` 经 `org.kde.impanel2` 取候选、用 wlr-layer-shell 画。

---

## 0. 结论速览（先数字后细节）

| # | 结论 | 证据 |
|---|---|---|
| 1 | `sm.puri.OSK0` 只有 **1 个方法 + 1 个只读属性**：`SetVisible(in b visible)`、`Visible`(b, **read**)；对象路径 **`/sm/puri/OSK0`**；接口名 **`sm.puri.OSK0`**；**没有** `Show/Hide/Toggle` 之类别的方法，**没有**可写属性，**没有**信号 | phosh v0.55.0 `src/dbus/sm.puri.OSK0.xml`（全文仅 21 行） |
| 2 | Phosh 内部只有 **3 处**会调 `SetVisible`（锁屏隐藏 / 关机键长按切换 / 「不可用」时强制 FALSE）；**普通 App 文本框获得焦点时 Phosh 完全不经手**，弹键盘是 OSK 客户端自己的事 | `src/osk-manager.c` L99-111/145-181；`src/home.c` L268-296 |
| 3 | 只实现 show/hide 的 `sm.puri.OSK0` 服务后，Phosh 侧**会生效** 2 个 UI 入口（关机键长按、锁屏键盘按钮使能）+ 1 个 gsettings 门；**不会**因此获得任何「文本框焦点→自动弹键盘」能力 | 同 §2 |
| 4 | fcitx5 kimpanel 的 `Enable(bool)` **不能**当「有输入框获得焦点」信号：它在构造/resume/每次 FocusIn/切输入法/`PanelCreated`/`StatusArea` 更新时都会发 `Enable(true)`，**从不发 `Enable(false)`** | fcitx5 5.1.15 `src/ui/kimpanel/kimpanel.cpp` L135-165, L437-443 |
| 5 | 「没输入框」时 kimpanel **仍然**会调 `ShowLookupTable(false)`+`ShowPreedit(false)`（focus 全失事件里）；`ShowPreedit(true)` 只在**有 preedit 文本**时才发，纯英文直出不会发 → 不能当焦点信号 | 同文件 L251-263, L272-327 |
| 6 | **最可靠的焦点信号 = `SetSpotRect(x,y,w,h)`（org.kde.impanel2）+ `SetRelativeSpotRect`**，只在 `InputContextCursorRectChanged` 与 `InputContextFocusIn` 两事件触发，且要求 `inputContext->hasFocus()` | 同文件 L206-230；`src/lib/fcitx/inputcontext.cpp` L246-254 |
| 7 | wvkbd 0.19.4 信号语义**确认**：`SIGUSR1`=hide、`SIGUSR2`=show、`SIGRTMIN`=toggle、`--hidden` 初始隐藏；hide 是**销毁 layer surface**（连带撤掉 exclusive zone），show 是重建 | wvkbd v0.19.4 `main.c` L644-727, L1072-1081；`README.md` L24/L69；`wvkbd.1.scd` L99-105 |

---

## 1. `sm.puri.OSK0` 的精确契约

### 1.1 权威 XML（Phosh v0.55.0 `src/dbus/sm.puri.OSK0.xml`，逐字）

```xml
<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node xmlns:doc="http://www.freedesktop.org/dbus/1.0/doc.dtd">
  <!--
      sm.puri.OSK0:

      This interface is exported by on screen keyboards (OSK) to
      indicate and set state like visibility.
  -->
  <interface name="sm.puri.OSK0">
    <method name="SetVisible">
      <arg type="b" direction="in" name="visible"/>
    </method>
    <property name="Visible" type="b" access="read"/>
  </interface>
</node>
```

- 源码：<https://gitlab.gnome.org/World/Phosh/phosh/-/raw/v0.55.0/src/dbus/sm.puri.OSK0.xml>
- 生成文档（同样只有 2 项）：`docs/phosh-dbus-sm.puri.OSK0.md`（v0.55.0 tarball 内）
- meson 声明（**Phosh 是 client，不是 server**）：`src/dbus/meson.build` L125
  `['phosh-osk0-dbus', 'sm.puri.OSK0.xml', 'sm.puri', false, false],` —— 位于 `dbus_client_protos` 数组，
  即 `gdbus-codegen` 给它生成的是 **proxy**（`phosh_dbus_osk0_proxy_new_for_bus_sync`），不是 skeleton。

### 1.2 名字 / 路径常量（Phosh 侧写死，v0.55.0 `src/osk-manager.c` L18-19）

```c
#define VIRTBOARD_DBUS_NAME      "sm.puri.OSK0"
#define VIRTBOARD_DBUS_OBJECT    "/sm/puri/OSK0"
```

### 1.3 服务端参照实现（squeekboard，`master`，`src/dbus.h` / `src/dbus.c`）

```c
/* src/dbus.h */
#define DBUS_SERVICE_PATH "/sm/puri/OSK0"
#define DBUS_SERVICE_INTERFACE "sm.puri.OSK0"
...
    self->dbus_interface = sm_puri_osk0_skeleton_new();
```

```c
/* src/dbus.c —— SetVisible 的语义：true 强制显示（并清 content-hint），false 立即隐藏 */
static gboolean
handle_set_visible(SmPuriOSK0 *object, GDBusMethodInvocation *invocation,
                   gboolean arg_visible, gpointer user_data) {
    DBusHandler *service = user_data;
    if (service->context) {
        if (arg_visible) {
            server_context_service_force_show_keyboard (service->context);
        } else {
            server_context_service_hide_keyboard (service->context);
        }
    }
    sm_puri_osk0_complete_set_visible(object, invocation);
    return TRUE;
}
/* 只读属性的唯一赋值来源：内部 GTK window 的 map/unmap */
static void on_visible(DBusHandler *service, GParamSpec *pspec,
                       ServerContextService *context) {
    g_object_get (context, "visible", &visible, NULL);
    sm_puri_osk0_set_visible(service->dbus_interface, visible);
}
```

- 源码：<https://source.puri.sm/Librem5/squeekboard/-/blob/master/src/dbus.c>（raw：`/api/v4/projects/626/repository/files/src%2Fdbus.c/raw?ref=master`）
- 关键点：**`Visible` 由 OSK 自己的 window map/unmap 决定**，`SetVisible` **不会**直接写 `Visible`；
  写回发生在下一次 `notify::visible`（`server_context_service_real_show_keyboard/hide_keyboard` 里
  `g_object_set(self,"visible",TRUE/FALSE)` → emit → `on_visible` → `sm_puri_osk0_set_visible()`）。
  源码 `src/server-context-service.c` L229-268。

### 1.4 可直接照抄的 GDBus 注册要点（C / glib）

**(a) 用 introspection XML 直接注册（不依赖 gdbus-codegen 生成物，最简单）**

```c
/* osk0-service.c —— 最小 sm.puri.OSK0 骨架，只做 show/hide 回调 */
#include <gio/gio.h>

#define OSK0_NAME  "sm.puri.OSK0"        /* bus name   */
#define OSK0_PATH  "/sm/puri/OSK0"       /* object path */
#define OSK0_IFACE "sm.puri.OSK0"        /* interface  */

static const gchar osk0_xml[] =
  "<node>"
  "  <interface name='sm.puri.OSK0'>"
  "    <method name='SetVisible'>"
  "      <arg type='b' direction='in' name='visible'/>"
  "    </method>"
  "    <property name='Visible' type='b' access='read'/>"
  "  </interface>"
  "</node>";

static gboolean want_visible = FALSE;    /* 你自己的状态 */

static void
on_method_call (GDBusConnection *conn, const gchar *sender, const gchar *path,
                const gchar *iface, const gchar *method, GVariant *params,
                GDBusMethodInvocation *inv, gpointer user)
{
  if (g_strcmp0 (method, "SetVisible") == 0) {
    gboolean v;
    g_variant_get (params, "(b)", &v);
    want_visible = v;
    /* >>> 在这里 show()/hide() 你的键盘（如 kill -USR2 / kill -USR1 wvkbd） <<< */
    g_dbus_method_invocation_return_value (inv, NULL);   /* SetVisible 无返回值 */
  }
}

/* 只读属性：Get 时按当前状态返回；Set 会被 glib 直接拒（因为 XML 里 access='read'）*/
static GVariant *
on_get_property (GDBusConnection *conn, const gchar *sender, const gchar *path,
                 const gchar *iface, const gchar *prop, GError **err, gpointer user)
{
  if (g_strcmp0 (prop, "Visible") == 0)
    return g_variant_new_boolean (want_visible);
  return NULL;
}

static const GDBusInterfaceVTable vtable = { on_method_call, on_get_property, NULL };

/* 主流程 */
GError *err = NULL;
GDBusConnection *bus = g_bus_get_sync (G_BUS_TYPE_SESSION, NULL, &err);
GDBusNodeInfo *info = g_dbus_node_info_new_for_xml (osk0_xml, &err);
guint reg = g_dbus_connection_register_object (bus, OSK0_PATH,
                                               info->interfaces[0], &vtable,
                                               NULL, NULL, &err);
g_bus_own_name_on_connection (bus, OSK0_NAME,
                              G_BUS_NAME_OWNER_FLAGS_NONE /* 或 REPLACE */,
                              NULL, NULL, NULL, NULL);
```

要点清单（每条都对应上面 XML 的硬约束）：

1. **方法无返回值**：`SetVisible` 的 `<arg>` 只有 `direction='in'`，所以 `return_value(inv, NULL)`。
   别返回 `(b)`，否则 dconf/`gdbus call` 侧虽然不报错，但 Phosh 的 `call_set_visible_finish` 对签名有校验，
   签名不符会走 `g_warning("Unable to toggle OSK: ...")`（`osk-manager.c` L86-87）。
2. **`Visible` 只读**：XML `access='read'`，vtable 只给 `get_property`。想改状态**必须**自己
   `g_dbus_connection_emit_signal(bus, NULL, OSK0_PATH, "org.freedesktop.DBus.Properties",
   "PropertiesChanged", ...)` 主动通知，Phosh 才会更新按钮态（`osk-manager.c` L218-222 连的是 proxy 的
   `notify::visible`，即 `PropertiesChanged` 驱动）。
3. **不要 `auto-start`**：Phosh 建 proxy 时带了 `G_DBUS_PROXY_FLAGS_DO_NOT_AUTO_START_AT_CONSTRUCTION`
   （`osk-manager.c` L193-199），但它只影响「构造 proxy 时不去拉服务」，后续你**不常驻**时
   `has_name_owner` 会变 FALSE → `available` FALSE → `on_availability_changed` 会主动
   `set_visible(FALSE)`（L145-153）。所以：**本服务要常驻**，不要按需退出。
4. **`available` = `has_name_owner && gsettings screen-keyboard-enabled`**（`osk-manager.c` L295-301）。
   服务器起了但 gsettings 关着，Phosh 仍判「不可用」→ 会反过来把 `Visible` 打成 FALSE。
   本机 `zh-osk` 脚本里那句 `gsettings set ... screen-keyboard-enabled false` **必须删掉/改 true**，
   否则新服务等于白起（这是当前脚本 `patches-userland/zh-ime/zh-osk` L14-15 的直接冲突）。
5. **必须让 `Visible` 反映真实状态**：Phosh 用 `Visible==TRUE` 来（a）折叠锁屏数字键盘
   `keypad_revealer`（`lockscreen.c` L925-927，`INVERT_BOOLEAN`），（b）给 PIN 输入框设
   `im-module=gtk-im-context-none`（L430-441）。谎报 TRUE 会让锁屏 PIN 框失去 GTK 输入法。

**(b) 若想走 gdbus-codegen（与 squeekboard 完全同路线）**

```meson
# meson.build
phosh_osk0 = gnome.gdbus_codegen('sm.puri.OSK0',
  'data/sm.puri.OSK0.xml',        # 直接从 phosh v0.55.0 拷，路径/接口一字不改
  interface_prefix : 'sm.puri',
  namespace : 'SmPuri',
  object_manager : false,
  annotations : [['org.gtk.GDBus.C.Name', 'SmPuriOSK0']],
)
# 生成 sm.puri.OSK0.h/.c，提供 SmPuriOSK0 / SmPuriOSK0Iface / sm_puri_osk0_skeleton_new()
```

```c
SmPuriOSK0 *iface = sm_puri_osk0_skeleton_new();             /* 自动导出 Visible 属性 */
g_signal_connect (iface, "handle-set-visible",
                  G_CALLBACK (on_handle_set_visible), self);
g_dbus_interface_skeleton_export (G_DBUS_INTERFACE_SKELETON (iface),
                                  bus, "/sm/puri/OSK0", &err);
/* 状态变化时： */
sm_puri_osk0_set_visible (iface, now_visible);              /* 触发 PropertiesChanged */
```

> **注意（本机 Glib 版本未查证）**：squeekboard 用 `dbus_server_protos` 的 `false,false` 后两参数，
> phosh 用 `gnome.gdbus_codegen`；具体参数签名随 meson 版本有差异，本报告未在主机 meson 上实测，
> 因此推荐 **(a) 手写 XML + register_object** 路线（零代码生成依赖，musl/Alpine 上最稳）。

### 1.5 版本确认

| 项 | 值 | 证据 |
|---|---|---|
| 取证基线 | Phosh **v0.55.0** tag（对应设备 0.55.0） | tarball `phosh-v0.55.0.tar.gz`，1 562 026 B |
| sm.puri.OSK0 自 0.38 起未变 | 与 squeekboard master 的 `dbus.h` 完全一致 | 两份常量化比对 |
| 上游文档入口 | <https://phosh.mobi/posts/phosh-osk-interface/> | `docs/phosh-dbus-sm.puri.OSK0.md` 的 See also |

---

## 2. Phosh 侧如何驱动 `SetVisible`

### 2.1 全部调用点（v0.55.0 全树 grep `osk_manager`，仅 3 个文件）

| 位置 | 触发条件 | 调用 |
|---|---|---|
| `src/lockscreen.c` L173-181 → `on_shell_locked_changed` | shell **上锁**（`notify::locked` 变 TRUE） | `set_visible_real(self, FALSE)` —— 锁屏时**只隐藏，不显示** |
| `src/home.c` L268-296 → `on_powerbar_pressed` | **电源键（home bar 电源按钮）长按** `GtkGestureLongPress` 的 `pressed` 信号（模板 `src/ui/home.ui` L70-75） | `phosh_osk_manager_set_visible(osk, !osk_current_state)` —— **切换** |
| `src/osk-manager.c` L145-153 → `on_availability_changed` | `available` 变 FALSE（bus name 丢 / gsettings 关） | `set_visible(FALSE)` |

**没有第 4 处**。`grep -rn "phosh_osk_manager_set_visible" src/` 只命中 `home.c:292` + `osk-manager.c` 内部。

### 2.2 快捷设置 / 锁屏键盘按钮到底做什么

- **锁屏的键盘按钮**：`osk_button_clicked_cb`（`lockscreen.c` L414-428）**根本不碰 OSK**，
  它只是 `focus_pin_entry(self, TRUE)` —— 把 PIN 输入框的 `im-module` 恢复成默认并 `grab_focus`。
  真正的弹出由 **GTK 的 OSK 集成**（GtkSettings `gtk-shell-shows-on-screen-keyboard` + Phosh 侧
  `phosh_shell` 的 text-input 桥）在焦点进入 `GtkEntry` 时完成，**不经过 `sm.puri.OSK0`**。
  同一文件里 `on_osk_visibility_changed`（L429-441）只在 OSK 变**不可见**时把 `im-module` 设成
  `gtk-im-context-none`（禁用 GTK 侧 IM，让 OSK 独占输入）。
  → 也就是说：**锁屏的「键盘」按钮 = 让 PIN 框拿焦点 → 由文本输入协议触发 OSK；
  `sm.puri.OSK0` 只用来「读」当前状态以同步 UI，以及在上锁瞬间「写 FALSE」**。
- **快捷设置（quick settings）**：v0.55.0 全树 grep `osk_manager` **无 quick-settings 命中**
  （`src/quick-settings/` 里没有 `#include "osk-manager.h"`）。0.55 的 OSK 开关在 **home bar 电源按钮长按**，
  不是下拉快捷设置。**未查证**：若 0.55.0 之后的版本把开关移入 quick settings，本报告不覆盖。

### 2.3 结论：只做 show/hide 的 `sm.puri.OSK0` 服务能/不能得到什么

**会生效：**

1. `PhoshOskManager::available` 变 TRUE（前提：gsettings `screen-keyboard-enabled=true`）。
   → 连带 3 个 UI：`home.c` L580-583 绑定 `osk-enabled`（home bar 电源按钮 OSK 手势可用）、
   `lockscreen.c` L930-932 绑定 `btn_keyboard.sensitive`（**锁屏键盘按钮从灰变可点**）、
   `osk-manager.c` L150-153 不再强推 FALSE。
2. **电源键长按 → 真的发 `SetVisible(!Visible)` 到你进程**：你能收到 show/hide 通知。
   但注意 `on_powerbar_pressed` 先读 `osk_current_state = get_visible()`，所以**你的 `Visible`
   属性必须诚实**，否则「长按一次」在你侧表现为「永远 show」或「永远 hide」（L278-292）。
3. **上锁 → 真的发 `SetVisible(FALSE)`**（L173-181）：可实现「锁屏自动收键盘」。

**不会生效（必须自己另做）：**

1. **普通 App 文本框获得焦点 → 自动弹键盘**：Phosh 0.55.0 **没有任何代码**在 text-input focus 时
   调 `SetVisible(TRUE)`。类注释写得很直白（`osk-manager.c` L27-30）：
   > *"Note that there's no way to ensure keyboard state via this interface as it just uses DBus to
   > express preference. **Any text input can make the keyboard show again.**"*
   → 这条路径归 **OSK 客户端自己**（squeekboard 走 `zwp_input_method_v2` activate/done）。
4. **`Visible` 反向控制 Phosh 的其它行为**只有两处（锁屏 keypad + PIN `im-module`），别指望它影响别的。

**实施建议（与现有 wvkbd 方案对齐）**：写一个常驻小守护（`osk0-bridge`）：
`SetVisible(true)` → `kill -USR2 $(pgrep -x wvkbd-mobintl)`；`false` → `kill -USR1 ...`；
另外监听 wvkbd 真实状态（最简单：自己维护 `hidden` 布尔，在收到信号后 emit `PropertiesChanged`）。
**不要**再用 `pkill wvkbd` 实现 hide（现有 `osk-toggle` 的做法），那会重启进程、丢布局与
input-method 关联（见 §4.3）。

---

## 3. fcitx5 kimpanel（`org.kde.impanel2`）语义

版本：**fcitx5 5.1.15**（`codeload .../refs/tags/5.1.15`，tarball 7 737 443 B）。源码只有一处：
`src/ui/kimpanel/kimpanel.cpp`（594 行）+ `kimpanel.h`。**`src/modules/kimpanel` 不存在**（本版本的
kimpanel 是 UI addon，不是 module），旧文档若写 `src/modules/kimpanel` 属过期路径。

### 3.1 发送通道：信号名是 DBus **方法调用**（不是 signal 名带前缀）

```cpp
/* kimpanel.cpp L86-101：全是 FCITX_OBJECT_VTABLE_SIGNAL，即 KimpanelProxy 的“出站信号” */
FCITX_OBJECT_VTABLE_SIGNAL(showPreedit,       "ShowPreedit",       "b");
FCITX_OBJECT_VTABLE_SIGNAL(showLookupTable,   "ShowLookupTable",   "b");
FCITX_OBJECT_VTABLE_SIGNAL(updateSpotLocation,"UpdateSpotLocation","ii");
FCITX_OBJECT_VTABLE_SIGNAL(enable,            "Enable",            "b");
```

实际发送方式是 **method call**（对端必须实现成 method，而不是订阅 signal）：

```cpp
/* L71-73 updateCursor()：SetSpotRect 系 */
auto msg = bus_->createMethodCall("org.kde.impanel", "/org/kde/impanel",
                                  "org.kde.impanel2", name);   /* name = SetSpotRect 等 */
msg << x << y << w << h;                                        /* int32 ×4 */
if (method == CursorRectMethod::SetRelativeSpotRectV2) msg << inputContext->scaleFactor();
msg.send();
```

```cpp
/* L333-334 SetLookupTable 同理，接口 org.kde.impanel2 */
auto msg = bus_->createMethodCall("org.kde.impanel", "/org/kde/impanel",
                                  "org.kde.impanel2", "SetLookupTable");
msg << labels << texts << attrs;          /* as,as,as */
msg << hasPrev << hasNext << pos << layout; /* b,b,i,i */
```

> 与 `fcitx5-candbar` 对照（`patches-userland/zh-ime/candidate-bar.c` L386-408）：XML 里
> `org.kde.impanel2` 的方法签名完全对得上（`SetLookupTable` = `as as as b b i i`；
> `SetSpotRect` = `i i i i`）。✔ 现实现正确。
> **但 `Enable` / `ShowPreedit` / `ShowLookupTable` 在 candbar 里有声明、`method_call` 里只打日志**（L378），
> 也就是说这两个信号现在被静默丢弃 —— §3.4 要用它们做控制，属于「改动量最小」的落点。

### 3.2 各信号的调用时机（逐条带行号）

| 信号/方法 | 何时发 | 行号 |
|---|---|---|
| `Enable(true)` | ① `registerAllProperties()` 末尾（构造、resume、**每次 `InputContextFocusIn`**、`StatusArea` 组件更新、`PanelCreated/PanelCreated2`）② `updateCurrentInputMethod()`（**每次切输入法**、`InputMethodGroupChanged`） | L161；调用者 L243-250（FocusIn）、L288-290（StatusArea）、L562-567、L570-577、L232-235、L236-242 |
| `Enable(false)` | **从不发送**（全文件无 `enable(false)`） | grep 结果 0 命中 |
| `ShowPreedit(bool)` | `updateInputPanel()`：有 preedit 或 auxUp 文本→`true`（L316），两者都空→`false`（L321, L325-326）；**焦点全失**→`false`（L258-260） | L251-263, L298-327 |
| `ShowAux(bool)` | 同上（aux 文本走 aux 通道） | L317, L322, L325 |
| `SetLookupTable` + `ShowLookupTable(bool)` | `updateInputPanel()` 尾部：`visible = !auxDown.empty() \|\| candidateList->size()`；**无论 true/false 都发 `SetLookupTable`**（false 时发空表），随后 `showLookupTable(visible)`，再 `bus_->flush()` | L329-390 |
| `SetSpotRect` / `SetRelativeSpotRect` / `SetRelativeSpotRectV2` | **只有 2 个事件**：`EventType::InputContextCursorRectChanged`、`EventType::InputContextFocusIn`；且 `if (inputContext->hasFocus())` | L206-230 |
| 选 `SetSpotRect` 还是 Relative 系 | `capabilityFlags().test(CapabilityFlag::RelativeRect)` 且对端 Introspect 里出现 `SetRelativeSpotRect[V2]` 才用 Relative；否则 `SetSpotRect` | L213-221, L189-203 |
| `UpdateSpotLocation` | 本版本 kimpanel 的 vtable 有声明（L99）但**全文件无发送点** → **实际是死信号** | grep `updateSpotLocation(` 仅声明行 |

### 3.3 关键问题的直接回答

**Q：能否用 `Enable(true)` / `Enable(false)` 作为「有输入框获得焦点」触发弹键盘？**
**不能。** 三条硬证据：
1. `Enable(false)` **在这个版本根本不存在发送路径** → 收起侧完全无信号。
2. `Enable(true)` 的发送条件与「焦点」仅部分相关：`StatusArea` 更新（L288-290）与
   `InputMethodGroupChanged`（L236-242）都会无条件发；`registerAllProperties()` 在 `resume()` 里也发（L186-187）。
   → 会出现「没有输入框也 Enable(true)」。
3. 反过来，焦点离开时只有 `ShowPreedit(false)/ShowLookupTable(false)`，**没有 `Enable(false)`**。
   → 用它做 show/hide 会造成：「一点键盘就弹、切不动焦点、永不收起」。

**Q：有没有更可靠的信号？**
**有 —— `SetSpotRect(x,y,w,h)`（或 `SetRelativeSpotRect[V2]`）是唯一「严格绑定焦点」的信号**，
判据链：
```cpp
/* kimpanel.cpp L206-230：只在 CursorRectChanged 或 FocusIn，且必须 hasFocus() */
instance_->watchEvent(EventType::InputContextCursorRectChanged, ..., check);
instance_->watchEvent(EventType::InputContextFocusIn, ..., check);
auto *inputContext = icEvent.inputContext();
if (inputContext->hasFocus()) proxy_->updateCursor(inputContext, method);
```
```cpp
/* src/lib/fcitx/inputcontext.cpp L246-254：光标矩形“真的变了”才发事件（去重） */
void InputContext::setCursorRect(Rect rect, double scale) {
    if (d->cursorRect_ == rect && d->scale_ == scale) return;
    d->cursorRect_ = rect; d->scale_ = scale;
    d->emplaceEvent<CursorRectChangedEvent>(this);
}
```
即 **`SetSpotRect` = 「某个有焦点的输入框报告了新的光标矩形」**，语义上等价于
「有文本框获得焦点 / 光标移动」。收起的判定要用**反面条件**：一段时间内没有
`SetSpotRect` 且 `ShowPreedit(false) && ShowLookupTable(false)`（focus 全失路径 L251-263）。

**Q：候选条隐藏时是否仍调用 `Enable`？**
会。`Enable(true)` 与 looked-up-table 状态**无关**：候选表空时 `SetLookupTable(空) + ShowLookupTable(false)`
照样发（L380-389），紧随其后的 `bus_->flush()` 之前/之后没有任何 `enable(false)`。
→ **候选条隐藏 ≠ 焦点丢失**，反过来也成立。

### 3.4 误判风险清单（按发生率排）

| # | 风险 | 根因 | 规避 |
|---|---|---|---|
| R1 | **永不收起** | 无 `Enable(false)`（L161/L442 只有 true） | 别用 Enable 当 hide 信号；用「无 SetSpotRect + ShowPreedit(false)+ShowLookupTable(false)」+ 超时 |
| R2 | **无输入框也弹键盘**（误 show） | `StatusArea` 更新、`InputMethodGroupChanged`、`resume()` 都发 `Enable(true)`（L186, L289, L441） | 以 `SetSpotRect` 为 show 的唯一触发；Enable 只当「UI 就绪」 |
| R3 | **纯英文/直出候选为空时看起来“没焦点”** | `SetLookupTable` 空表 + `ShowLookupTable(false)`（L380-389） | 用 `SetSpotRect`（光标仍在，必发）而非候选表判焦点 |
| R4 | **`ShowPreedit(true)` 不是焦点信号** | 只在 preedit/auxUp 非空时发（L302-317）；拼音首字母之前不发 | 同上 |
| R5 | **`UpdateSpotLocation` 永远不来** | 本版本无发送点（仅 L99 声明） | 实现它只为兼容，别依赖 |
| R6 | **Kimpanel 不是当前 UI 时全部信号消失** | `ui_` 只指向优先级最高的可用 UI（`UIPriority`：kimpanel=50，virtualkeyboard=0），见 `kimpanel.conf.in.in` 与 `virtualkeyboard.conf.in.in`；`UserInterfaceManager::updateAvailability()`（`userinterfacemanager.cpp` L288-305） | 启动务必 `fcitx5 -u kimpanel`（本机 `zh-osk` L31 已这么做 ✔）；并保证 `org.kde.impanel` 有 owner（`Kimpanel` 构造时 `watcher_.watchService("org.kde.impanel")`，L113-118，无 owner ⇒ `available_=false`），candbar 必须**先于** fcitx5 起（`zh-osk` L22-30 已如此 ✔） |
| R7 | 若某前端走 **Wayland 原生 IM** 且桌面被判为 KDE 且 classicui 在，则走 classicui 不发 kimpanel | L272-284 `isKDE() && frontendName 前缀 "wayland"` | Phosh 不是 KDE，`misc_p.h` L197-201 `isKDE()` 为假 ⇒ 本机不会命中；**仅当有人给设备注入 XDG_CURRENT_DESKTOP=KDE 时才会** |

### 3.5 与「虚拟键盘 UI」的关系（附带发现，可能更省事）

fcitx5 自带一个 D-Bus 虚拟键盘 UI（`src/ui/virtualkeyboard/`）：
- `UIType=OnScreenKeyboard`，`UIPriority=0`，`OnDemand=True`（`virtualkeyboard.conf.in.in`）。
- fcitx5 **在 FocusIn 时会自动调 `ShowVirtualKeyboard`**（`lib/fcitx/instance.cpp` L1071-1075
  `if (!clientControlVirtualkeyboardShow()) inputContext->showVirtualKeyboard();`），
  FocusOut 时自动 `HideVirtualKeyboard`（L1121-1124）。
- 它通过 DBus 名 **`org.fcitx.Fcitx5.VirtualKeyboard`**、路径 **`/org/fcitx/virtualkeyboard/impanel`**、
  接口 **`org.fcitx.Fcitx5.VirtualKeyboard1`**，方法 `ShowVirtualKeyboard` / `HideVirtualKeyboard`
  （`ui/virtualkeyboard/virtualkeyboard.cpp` L55-61, L290-311）。
- 反方向：后端名 `org.fcitx.Fcitx5.VirtualKeyboardBackend` / 接口 `…Backend1`（L55-58, L246-252）。

→ **这是一个现成的、语义精确的「show/hide 虚拟键盘」D-Bus 面**（比 kimpanel 的 Enable 强得多）。
**但**：只有当 `virtualkeyboard` 是**当前 UI**（`userinterfacemanager.cpp` L376-385 要求
`ui_->addonInfo()->uiType()==UIType::OnScreenKeyboard`）时 `showVirtualKeyboard()` 才真的发消息；
而 `-u kimpanel` 会让 kimpanel（priority 50）成为当前 UI ⇒ **两者互斥，不能同时当 UI**。
若要复用，需让 `virtualkeyboard` 成为 UI 并把候选条改挂 kimpanel 的 `KimpanelProxy` 之外的通道
—— 工程成本高于 §3.4 的方案。**结论：不走这条，作为备选记录。**
（**未查证**：`fcitx5-wayland` 的 `waylandim` 是否也在 FocusIn 时调 `showVirtualKeyboard()`——
`waylandimserverv2.cpp` L160-241 只见 `focusInWrapper()`，未直接调；实际的 FocusIn 事件由
`VirtualInputContextGlue::focusInWrapper()` → `ic->focusIn()` 触发 `instance.cpp` L1071-1075 的通用路径，
所以**是会被调用的**，但仍受「当前 UI 必须是 OnScreenKeyboard 类型」约束。）

---

## 4. wvkbd 0.19.4 的显示/隐藏控制面

版本钉定：tag **v0.19.4 = commit `4366d88ecae8648c416d645aabbee2b1947eb3d6`**
（取自 `https://git.sr.ht/~proycon/wvkbd/refs/rss.xml`；tarball 1 476 102 B）。

### 4.1 信号语义（**全部确认**，不是猜测）

```c
/* main.c L1043-1056：把信号塞进 signalfd */
sigemptyset (&signal_mask);
sigaddset (&signal_mask, SIGUSR1);
sigaddset (&signal_mask, SIGUSR2);
sigaddset (&signal_mask, SIGRTMIN);
sigaddset (&signal_mask, SIGPIPE);
sigprocmask (SIG_BLOCK, &signal_mask, NULL);
fds[SIGNAL_FD].fd = signalfd (-1, &signal_mask, 0);
```
```c
/* main.c L1072-1081：poll 循环里分派 —— 注意 SIGRTMIN 走的是第三个分支 */
if (read (fds[SIGNAL_FD].fd, &si, sizeof(si)) != sizeof(si))
    fprintf (stderr, "Signal read error: %d", errno);
else if (si.ssi_signo == SIGUSR1)   hide();
else if (si.ssi_signo == SIGUSR2)   show();
else if (si.ssi_signo == SIGRTMIN)  toggle_visibility();
else if (si.ssi_signo == SIGPIPE)   pipewarn();
```

| 信号 | 动作 | 备注 |
|---|---|---|
| `SIGUSR1` | **hide** | ✔ 用户假设正确 |
| `SIGUSR2` | **show** | ✔ 用户假设正确 |
| `SIGRTMIN` | **toggle**（`if (hidden) show(); else hide();`，L727-733） | 附加事实，用户未提，可省掉自己维护状态 |
| `SIGPIPE` | 仅打印 `cannot pipe data out`（L735-739） | 与显示无关，别误用 |

文档侧同源确认：
- `README.md` L24：`Show/hide keyboard on signals (SIGUSR1 = hide, SIGUSR2 = show, SIGRTMIN = toggle)`
- `README.md` L69：「The keyboard can be hidden by sending it a `SIGUSR1` … shown again by `SIGUSR2`
  or toggled by `SIGRTMIN`. **This saves some start up time**」
- `wvkbd.1.scd` L99-105：`*SIGUSR1* Hide the keyboard.` / `*SIGUSR2* Show the keyboard` / `*SIGRTMIN* Toggle visibility`
- `main.c` L605 用法串：`--hidden    - Start hidden (send SIGUSR2 to show)`

### 4.2 `--hidden` 与 layer surface / exclusive zone 的真实行为

```c
/* main.c L1027-1029：只有“不 hidden”才建 surface */
kbd_init (&keyboard, …);
if (!hidden) show();
/* main.c L1042 起进入 poll 循环 */
```
```c
/* main.c L687-727 show()：**重新**创建 wl_surface + layer_surface，并重设 exclusive zone */
layer_surface = zwlr_layer_shell_v1_get_layer_surface (layer_shell, draw_surf.surf,
                                                       current_output_data, layer, namespace);
zwlr_layer_surface_v1_set_size (layer_surface, 0, height);
zwlr_layer_surface_v1_set_anchor (layer_surface, anchor);
if (keyboard.exclusive) {                                      /* 默认 true：L806 */
    zwlr_layer_surface_v1_set_exclusive_zone (layer_surface, height);
}
zwlr_layer_surface_v1_set_keyboard_interactivity (layer_surface, false);
zwlr_layer_surface_v1_add_listener (layer_surface, &layer_surface_listener, NULL);
wl_surface_commit (draw_surf.surf);
```
```c
/* main.c L643-684 hide()：**销毁** surface 链，最后 hidden = true */
wp_fractional_scale_v1_destroy/wfs_draw_surf= NULL;
wp_viewport_destroy (draw_surf_viewport); draw_surf_viewport = NULL;
xdg_popup_destroy(popup_xdg_popup); xdg_surface_destroy(popup_xdg_surface);
wl_surface_destroy(popup_draw_surf.surf);
zwlr_layer_surface_v1_destroy (layer_surface); layer_surface = NULL;
layer_surface_configured = false;
wl_callback_destroy(draw_surf.frame_cb); wl_surface_destroy (draw_surf.surf);
hidden = true;
```

由此可确定的语义（**关键，直接影响 Phosh 的窗口布局**）：

1. **hide = 销毁图层，不是 `wl_surface_attach(NULL)`**。`zwlr_layer_surface_v1_destroy()` 会把该
   surface 从合成器的 layer 栈移除 ⇒ **exclusive zone 随之撤销**，底下的 App 窗口不会保留
   键盘高度的空白（如果 compositor 正确实现了 layer-shell resize；phoc 内嵌 wlroots 0.20.0，
   理论路径如此，**本机 phoc 上的实际 resize 行为未经实测**）。
2. **show = 重新 configure，有新 serial / 新尺寸**。`layer_surface_configure`（L515-560）里有
   `if (keyboard.w != w || keyboard.h != h) { ack; hide(); show(); return; }` —— 出现
   `hide()`→`show()` 的自递归重启，且 `hidden = false` 在 **configure 成功之后**才置（L544）。
   → **不要在 `SIGUSR2` 之后立刻 `SIGUSR1`**（连点两次 toggle 有概率撞进 configure 重启窗口），
   建议 bridge 侧对 show/hide 做 ≥150 ms 去抖。
3. **`--hidden` 时不建任何 surface**（L1028），所以进程在 map 前**没有** layer surface、
   **不请求** exclusive zone；此时 `SIGUSR2` 会走完整 `show()` 路径（首次 configure）。
4. `layer_surface_closed`（L582-588）会 `run_display = false` 直接退出 —— 合成器主动关图层
   （例如 `zwlr_layer_surface_v1.close`）时进程自己退出，**不会**静默隐藏。做 bridge 时要把
   「进程消失」当成需要重启处理，不要和「隐藏」混淆。
5. 图层参数：`layer = ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY`，`anchor = BOTTOM|LEFT|RIGHT`
   （L61-63），`keyboard_interactivity = false`（L718）。→ **overlay 层 + 不交键盘焦点**，
   与 `fcitx5-candbar`（layer=top）叠放顺序：overlay 在 top 之上，candbar 不会被键盘盖住 ✔
   （candbar 的 `CANDBAR_MARGIN=300` 手动避让是必要 hack，因为 overlay 键盘不进 layer-shell 的
   exclusive 计算之外的部分；此点已由现有实现证明可用）。

### 4.3 「运行时 show/hide 而不重启进程」的准确做法

```sh
# 前提：wvkbd 已在跑（一次即可：wvkbd-mobintl --hidden  → 开机不占屏）
pgrep -x wvkbd-mobintl >/dev/null || { setsid wvkbd-mobintl --hidden >/dev/null 2>&1 & sleep 0.3; }

# 显示
pkill -USR2 -x wvkbd-mobintl          # show
# 收起
pkill -USR1 -x wvkbd-mobintl          # hide
# 切换（不需要自己记状态）
pkill -RTMIN -x wvkbd-mobintl         # toggle
```

注意：
- `pkill -USR2 -x wvkbd-mobintl` 精确按 **进程名**（`-x`），比 `pkill -f` 安全，不会误杀
  `zh-osk` 脚本自身（对比项目内 `PITFALLS` 的 pkill 自杀教训）。
- **不要**用现有 `osk-toggle`（`patches-userland/zh-ime/osk-toggle` L3-9：`pkill -x wvkbd-mobintl` /
  重新 `setsid wvkbd-mobintl &`）—— 那是**重启进程**，副作用：
  1. 丢当前 layer/layout 选择（`kbd_init` 重置）；
  2. `zwp_virtual_keyboard_v1` 对象重建，先前的 keymap 需重新下发，按下方注（**未查证**本机时序是否掉首键）；
  3. 用户体感是「闪一下」，且与 `SIGUSR1/2` 的 semantics 不一致（后者 README L69 明说是为省启动时间）。
- 与 `sm.puri.OSK0` bridge 结合的推荐实现（本报告建议落点）：

```sh
# /usr/local/bin/osk0-bridge   （伪代码，桥接 SetVisible → wvkbd 信号）
# SetVisible(true)  → kill -USR2 wvkbd ; Visible←true  (emit PropertiesChanged)
# SetVisible(false) → kill -USR1 wvkbd ; Visible←false
# 附加：以 fcitx5-candbar 收到的 SetSpotRect 事件作为 show 触发（见 §3.3）
```

---

## 5. 可复现命令（拉取上述全部源码）

```sh
mkdir -p /tmp/osk-probe && cd /tmp/osk-probe
# Phosh 0.55.0（整树，含 src/osk-manager.c、src/dbus/sm.puri.OSK0.xml、docs/、src/home.ui）
curl -sS -m 60 -o phosh-0550.tar.gz \
  'https://gitlab.gnome.org/World/Phosh/phosh/-/archive/v0.55.0/phosh-v0.55.0.tar.gz'
tar xzf phosh-0550.tar.gz

# squeekboard（master；SetVisible 的参考服务端实现）
for f in src/dbus.c src/dbus.h src/server-context-service.c src/server-context-service.h \
         src/submission.rs src/imservice.rs src/ui_manager.rs src/server-main.c; do
  enc=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=""))' "$f")
  curl -sS "https://source.puri.sm/api/v4/projects/626/repository/files/$enc/raw?ref=master" \
    -o "sq-$(basename $f)"
done

# fcitx5 5.1.15（kimpanel + virtualkeyboard + waylandim + lib/fcitx 事件层）
curl -sSL -o fcitx5.tar.gz 'https://codeload.github.com/fcitx/fcitx5/tar.gz/refs/tags/5.1.15'
tar xzf fcitx5.tar.gz

# wvkbd v0.19.4（commit 4366d88e…）
curl -sSL -o wvkbd.tgz \
  'https://git.sr.ht/~proycon/wvkbd/archive/4366d88ecae8648c416d645aabbee2b1947eb3d6.tar.gz'
tar xzf wvkbd.tgz
```

> 网络注意（本机实测）：`gitlab.gnome.org` / `source.puri.sm` / `git.sr.ht` / `codeload.github.com`
> **必须走代理**（直连 `--noproxy '*'` 时 gitlab 返 406、raw.githubusercontent 连接失败、
> github api 403 限流）。上文命令均使用默认代理环境。

---

## 6. 未查证 / 明确边界

| 项 | 状态 |
|---|---|
| Phosh 0.55.0 之后版本把 OSK 开关移入 quick settings | **未查证**（本报告只对 v0.55.0 成立：无 quick-settings 引用） |
| phoc（wlroots 0.20.0）在 `zwlr_layer_surface_v1_destroy` 后是否立即重排 App 窗口 | **未查证**（静态源码不含 wlroots 侧行为；需上机测窗口 resize） |
| `meson gnome.gdbus_codegen` 参数签名在本机 meson 版本下的确切写法 | **未查证**（故推荐 §1.4(a) 手写 XML 路线） |
| wvkbd 重启后首键是否丢失（virtual-keyboard keymap 时序） | **未查证**（只确认「不应重启」这一设计意图，见 README L69） |
| `fcitx5-candbar` 对 `Enable/ShowPreedit/ShowLookupTable` 目前只记日志 | **已确认**（candidate-bar.c L378 `method_call` 只 `logmsg`，未落任何状态）；改造前不得假定这些信号已被消费 |
| `zwp_input_method_v2` 槽位归属与 phoc 补丁 | 属项目既有实测结论（`PITFALLS/sessions/48-…md`），本报告不重测 |

---

## 7. 小结表（≤15 行）

| 问题 | 答案 | 证据 |
|---|---|---|
| OSK0 接口名/路径 | `sm.puri.OSK0` / `/sm/puri/OSK0` | phosh v0.55.0 `osk-manager.c` L18-19 |
| OSK0 方法 | 仅 `SetVisible(in b visible)`，无返回值 | `src/dbus/sm.puri.OSK0.xml` |
| OSK0 属性 | 仅 `Visible`，`b`，**access=read**，无信号 | 同上 |
| 谁调 SetVisible | 仅 3 处：上锁→FALSE、电源键长按→toggle、available 变假→FALSE | `lockscreen.c` L173-181；`home.c` L268-296；`osk-manager.c` L145-153 |
| 文本框焦点是否经 OSK0 | **不经**；类注释明说「its just DBus preference」 | `osk-manager.c` L27-30 |
| 只做 show/hide 的收益 | `available` 生效→锁屏键盘按钮可点、home bar 手势可用、上锁自动收键盘；**无自动弹键盘** | §2.3 |
| 前置条件 | gsettings `screen-keyboard-enabled=true` **且** bus name 常驻 | `osk-manager.c` L295-301 |
| kimpanel 的 Enable | 只在有焦点/切IM/UI更新时发 **true**；**从不发 false** ⇒ 不能当焦点信号 | `kimpanel.cpp` L161,L442（无 false） |
| 最可靠的焦点信号 | `SetSpotRect` / `SetRelativeSpotRect[V2]`（CursorRectChanged + FocusIn，且 hasFocus） | `kimpanel.cpp` L206-230；`inputcontext.cpp` L246-254 |
| 候选条隐藏时是否还调 Enable | 会（候选表与 Enable 无关） | `kimpanel.cpp` L380-389 vs L161 |
| `UpdateSpotLocation` | 本版本**无发送点**（死信号） | `kimpanel.cpp` L99 仅声明 |
| wvkbd 信号 | `SIGUSR1`=hide、`SIGUSR2`=show、`SIGRTMIN`=toggle、`SIGPIPE`=无关 | `main.c` L1076-1081；README L24/L69；man L99-105 |
| wvkbd `--hidden` | 启动不建 surface（无 exclusive zone）；`SIGUSR2` 走完整 show() | `main.c` L1028, L687-727 |
| wvkbd hide 的实质 | **销毁 layer surface**（连撤 exclusive zone），非 attach NULL | `main.c` L643-684 |
| 正确 toggle 做法 | `pkill -USR2/-USR1/-RTMIN -x wvkbd-mobintl`；**不要**重启进程（现 `osk-toggle` 应改） | §4.3 + `patches-userland/zh-ime/osk-toggle` L3-9 |

---

### 附：本报告不影响任何 SSOT
仅新增本文件；`TASKS/README.md`、`PITFALLS/README.md` 等未改动。若需并入，建议在
`TASKS/README.md` §5 增一行 Q 指针（由宿主决定）。
