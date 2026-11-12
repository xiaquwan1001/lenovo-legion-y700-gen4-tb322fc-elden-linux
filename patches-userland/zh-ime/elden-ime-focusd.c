// elden-ime-focusd — 让 squeekboard 在「输入框获得焦点」时自动弹出
//
// 背景（2026-10-20 实测，TB322FC / phoc 0.55.1 / squeekboard 1.43.1 / fcitx5 5.1.19）：
//   * 本机中文输入走 `GTK_IM_MODULE=fcitx`（数据库前端），GTK **不走** wayland text-input-v3
//     ⇒ phoc 不会告诉 squeekboard「有输入框获得了焦点」
//     ⇒ squeekboard 只有启动时显示、以及 sm.puri.OSK0.SetVisible() 手动控制，**不会**自动弹。
//   * fcitx5 的 kimpanel 后端在输入上下文 FocusIn / 光标矩形变化时会稳定调用
//     `SetRelativeSpotRect`（本机 v5.1.19 实测每次都来；`Enable` 反而不发）
//     ⇒ 用它当「有人要打字了」的信号，再调 sm.puri.OSK0.SetVisible(true) 弹键盘。
//
// 折叠（2026-11-11 补）：原来写「fcitx5 没有 FocusOut 的可靠信号」是**错的**。
//   `org.fcitx.Fcitx.Controller1.State`（fcitx5 的 InputContext 状态）实测 0↔1 精确跟随输入焦点：
//   无输入上下文 = 0、Entry 拿到焦点 = 1、窗口关闭 = 0。⇒ 用它做收起判据（1 s 轮询，代价可忽略）。
//   注意：不是所有客户端都走 fcitx 前端（`GTK_IM_MODULE=wayland` 时 GTK 走 text-input-v3），
//   那种情况下 phoc 自己会把 activate 转发给 OSK，本程序只看到 State 恒 0 ⇒ 不会误收起。
//
// 2026-11-12（G1-38「自动弹/收没做好」的静态定案，reports/ime-osk-lifecycle-20261112.md）：
//   ① 零矩形误弹 —— fcitx5 建 IC 时先发 SetRelativeSpotRect(0,0,0,0)，旧代码 `(void)params`
//      把它也当「有人要打字」⇒ 现在解析矩形，w<=0&&h<=0 只记「疑似失焦」，不再弹。
//   ② 收起漏收 —— 旧代码只认 State==0；现在补三条：零矩形持续 2 s（同窗换控件/关输入框）、
//      fcitx5 消失（State==-1 连续 5 次）、长时间无 kimpanel 活动（ELDEN_IME_IDLE_SEC，默认 300 s）。
//   ③ 打字卡顿 —— 旧代码每次光标更新都在回调里做同步 D-Bus `Get Visible`（500 ms 超时，
//      会顶住 SetLookupTable）。现在订阅 PropertiesChanged 维护本地状态，回调路径零往返。
//
// 编译：见同目录 build-elden-ime.sh（gcc + gio-2.0 + glib-2.0）

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdarg.h>
#include <gio/gio.h>
#include <glib.h>

static GDBusConnection *bus;
static gboolean osk_visible = FALSE;
static gint64 last_show_us = 0;
static gint64 last_activity_us = 0;   // 最近一次「真有人要打字」的 kimpanel 活动
static gint64 zero_rect_since_us = 0; // 非 0 = 见到零矩形，等 2 s 确认再收（避免打字抖动误收）
static gint fcitx_gone_ticks = 0;     // State==-1 的连续次数（5 s ⇒ fcitx5 真没了）
static gint idle_sec = 300;           // 兜底超时：有 IC 但长时间无 kimpanel 活动

static void logmsg(const char *fmt, ...) {
    static FILE *f;
    if (!f) {
        const char *p = getenv("ELDEN_IME_LOG");
        f = fopen(p ? p : "/tmp/elden-ime-focusd.log", "a");
    }
    if (!f) return;
    va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap);
    fputc('\n', f); fflush(f);
}

// ---- squeekboard: sm.puri.OSK0 ----
static void osk_get_visible(void) {
    GError *err = NULL;
    GVariant *ret = g_dbus_connection_call_sync(
        bus, "sm.puri.OSK0", "/sm/puri/OSK0", "org.freedesktop.DBus.Properties", "Get",
        g_variant_new("(ss)", "sm.puri.OSK0", "Visible"),
        G_VARIANT_TYPE("(v)"), G_DBUS_CALL_FLAGS_NO_AUTO_START, 500, NULL, &err);
    if (!ret) {
        if (err) { logmsg("Get Visible failed: %s", err->message); g_error_free(err); }
        osk_visible = FALSE;
        return;
    }
    GVariant *v = NULL;
    g_variant_get(ret, "(v)", &v);
    osk_visible = v ? g_variant_get_boolean(v) : FALSE;
    if (v) g_variant_unref(v);
    g_variant_unref(ret);
}

static void osk_set_visible(gboolean vis) {
    GError *err = NULL;
    GVariant *ret = g_dbus_connection_call_sync(
        bus, "sm.puri.OSK0", "/sm/puri/OSK0", "sm.puri.OSK0", "SetVisible",
        g_variant_new("(b)", vis), NULL, G_DBUS_CALL_FLAGS_NO_AUTO_START, 500, NULL, &err);
    if (ret) g_variant_unref(ret);
    if (err) { logmsg("SetVisible(%d) failed: %s", vis, err->message); g_error_free(err); return; }
    osk_visible = vis;
    logmsg("SetVisible(%d)", vis);
}

// ---- fcitx5 输入上下文状态：0 = 无输入上下文（可收起），非 0 = 有输入框在编辑 ----
static gint fcitx_state(void) {
    GError *err = NULL;
    GVariant *ret = g_dbus_connection_call_sync(
        bus, "org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1", "State",
        NULL, G_VARIANT_TYPE("(i)"), G_DBUS_CALL_FLAGS_NO_AUTO_START, 300, NULL, &err);
    if (!ret) {
        if (err) g_error_free(err);
        return -1;   // fcitx5 不在/未就绪：不据此收起
    }
    gint st = -1;
    g_variant_get(ret, "(i)", &st);
    g_variant_unref(ret);
    return st;
}

static void osk_hide(const char *why) {
    logmsg("hide requested by %s", why);
    osk_visible = FALSE;   // 先本地置位，避免往返
    zero_rect_since_us = 0;
    osk_set_visible(FALSE);
}

static gboolean idle_check(gpointer user) {
    (void)user;
    if (!osk_visible) { fcitx_gone_ticks = 0; return G_SOURCE_CONTINUE; }
    gint64 now = g_get_monotonic_time();
    gint st = fcitx_state();
    if (st == 0) { fcitx_gone_ticks = 0; osk_hide("fcitx State=0"); return G_SOURCE_CONTINUE; }
    if (st == -1) {
        // fcitx5 不在/未就绪：旧代码故意不收起 ⇒ fcitx5 崩了键盘会永久悬浮。给 5 s 宽限。
        if (++fcitx_gone_ticks >= 5) osk_hide("fcitx5 gone (State=-1 x5)");
        return G_SOURCE_CONTINUE;
    }
    fcitx_gone_ticks = 0;
    if (zero_rect_since_us && now - zero_rect_since_us > 2000000) {
        osk_hide("zero spot rect persisted 2s");
        return G_SOURCE_CONTINUE;
    }
    if (idle_sec > 0 && last_activity_us && (now - last_activity_us) / G_USEC_PER_SEC > idle_sec) {
        osk_hide("idle timeout");
    }
    return G_SOURCE_CONTINUE;
}

// 统一入口：why = kimpanel 方法名；w/h = 光标矩形（<0 表示该方法不带矩形）
static void want_keyboard(const char *why, int w, int h) {
    gint64 now = g_get_monotonic_time();
    if (w == 0 && h == 0) {
        // 零矩形：fcitx5 建 IC / 离开输入框时都发。不当「要打字」，只记「可能失焦」。
        if (osk_visible && !zero_rect_since_us) zero_rect_since_us = now;
        return;
    }
    zero_rect_since_us = 0;
    last_activity_us = now;
    if (osk_visible) return;                      // 本地状态由 PropertiesChanged 维护，零往返
    if (now - last_show_us < 200000) return;      // 200 ms 去抖（防 show/hide 抖动）
    logmsg("show requested by %s (%dx%d)", why, w, h);
    osk_set_visible(TRUE);
    last_show_us = now;
    last_activity_us = now;
}

// ---- kimpanel panel side (org.kde.impanel) ----
// 订阅 OSK 的 Visible 变化：别处（phoc/stevia/用户手势）收起时同步本地状态，
// 这样 want_keyboard 里不必再做阻塞 Get。
static void on_props_changed(GDBusConnection *c, const gchar *sender, const gchar *path,
                             const gchar *iface, const gchar *signal, GVariant *params,
                             gpointer user) {
    (void)c; (void)sender; (void)path; (void)iface; (void)signal; (void)user;
    if (!params || !g_variant_is_of_type(params, G_VARIANT_TYPE("(sa{sv}as)"))) return;
    GVariant *changed = g_variant_get_child_value(params, 1);
    GVariant *v = changed ? g_variant_lookup_value(changed, "Visible", G_VARIANT_TYPE_BOOLEAN) : NULL;
    if (v) {
        gboolean vis = g_variant_get_boolean(v);
        if (vis != osk_visible) { logmsg("Visible->%d (signal)", vis); osk_visible = vis; }
        g_variant_unref(v);
    }
    if (changed) g_variant_unref(changed);
}

static const gchar *impanel_xml =
    "<node><interface name='org.kde.impanel2'>"
    "<method name='SetLookupTable'><arg type='as' direction='in'/><arg type='as' direction='in'/>"
    "<arg type='as' direction='in'/><arg type='b' direction='in'/><arg type='b' direction='in'/>"
    "<arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='SetSpotRect'><arg type='i' direction='in'/><arg type='i' direction='in'/>"
    "<arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='SetRelativeSpotRect'><arg type='i' direction='in'/><arg type='i' direction='in'/>"
    "<arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='Enable'><arg type='b' direction='in'/></method>"
    "<method name='ShowAux'><arg type='b' direction='in'/></method>"
    "<method name='ShowPreedit'><arg type='b' direction='in'/></method>"
    "<method name='ShowLookupTable'><arg type='b' direction='in'/></method>"
    "<method name='UpdateAux'><arg type='s' direction='in'/><arg type='s' direction='in'/></method>"
    "<method name='UpdatePreeditText'><arg type='s' direction='in'/><arg type='s' direction='in'/></method>"
    "<method name='UpdatePreeditCaret'><arg type='i' direction='in'/></method>"
    "<method name='UpdateLookupTableCursor'><arg type='i' direction='in'/></method>"
    "<method name='UpdateSpotLocation'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='UpdateScreen'><arg type='i' direction='in'/></method>"
    "<method name='RegisterProperties'><arg type='as' direction='in'/></method>"
    "<method name='UpdateProperty'><arg type='s' direction='in'/></method>"
    "<method name='RemoveProperty'><arg type='s' direction='in'/></method>"
    "<method name='ExecMenu'><arg type='as' direction='in'/></method>"
    "<method name='ExecDialog'><arg type='s' direction='in'/></method>"
    "</interface></node>";

static void method_call(GDBusConnection *c, const gchar *sender, const gchar *path,
                        const gchar *iface, const gchar *method, GVariant *params,
                        GDBusMethodInvocation *inv, gpointer user) {
    (void)c; (void)sender; (void)path; (void)iface; (void)user;

    if (!strcmp(method, "SetSpotRect") || !strcmp(method, "SetRelativeSpotRect")) {
        int x = 0, y = 0, w = -1, h = -1;
        if (params && g_variant_is_of_type(params, G_VARIANT_TYPE("(iiii)")))
            g_variant_get(params, "(iiii)", &x, &y, &w, &h);
        (void)x; (void)y;
        want_keyboard(method, w, h);
    } else if (!strcmp(method, "UpdateSpotLocation")) {
        // 只带坐标不带尺寸：算「还在编辑」的活动，但不据此弹键盘
        if (last_activity_us) last_activity_us = g_get_monotonic_time();
    } else if (!strcmp(method, "Enable")) {
        gboolean en = FALSE;
        if (params && g_variant_is_of_type(params, G_VARIANT_TYPE("(b)")))
            g_variant_get(params, "(b)", &en);
        if (en) want_keyboard("Enable(true)", -1, -1);
        else if (osk_visible) osk_hide("Enable(false)");
    } else if (!strcmp(method, "ShowPreedit")) {
        gboolean en = FALSE;
        if (params && g_variant_is_of_type(params, G_VARIANT_TYPE("(b)")))
            g_variant_get(params, "(b)", &en);
        if (en) want_keyboard("ShowPreedit(true)", -1, -1);
    } else if (!strcmp(method, "SetLookupTable")) {
        if (params && g_variant_is_of_type(params, G_VARIANT_TYPE("(asasasbbii)"))) {
            GVariant *v = g_variant_get_child_value(params, 1);
            if (v) {
                if (g_variant_n_children(v) > 0) want_keyboard("SetLookupTable", -1, -1);
                g_variant_unref(v);
            }
        }
    }
    g_dbus_method_invocation_return_value(inv, NULL);
}

int main(void) {
    GError *err = NULL;
    const char *idleenv = getenv("ELDEN_IME_IDLE_SEC");
    if (idleenv && *idleenv) { gint v = atoi(idleenv); if (v >= 0) idle_sec = v; }
    logmsg("=== start pid=%d idle_sec=%d", getpid(), idle_sec);
    bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &err);
    if (!bus) { logmsg("no session bus: %s", err->message); return 1; }

    // 本地可见性状态：启动时取一次，之后靠信号。
    osk_get_visible();
    g_dbus_connection_signal_subscribe(bus, "sm.puri.OSK0", "org.freedesktop.DBus.Properties",
                                      "PropertiesChanged", "/sm/puri/OSK0", NULL, 0,
                                      on_props_changed, NULL, NULL);

    GDBusNodeInfo *info = g_dbus_node_info_new_for_xml(impanel_xml, &err);
    if (!info) { logmsg("xml: %s", err->message); return 1; }
    static const GDBusInterfaceVTable vt = { .method_call = method_call };
    guint id = g_dbus_connection_register_object(bus, "/org/kde/impanel", info->interfaces[0],
                                                &vt, NULL, NULL, &err);
    if (!id) { logmsg("register: %s", err->message); return 1; }
    GVariant *ret = g_dbus_connection_call_sync(
        bus, "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
        g_variant_new("(su)", "org.kde.impanel", 0u), G_VARIANT_TYPE("(u)"),
        G_DBUS_CALL_FLAGS_NONE, -1, NULL, &err);
    if (!ret) { logmsg("RequestName: %s", err->message); return 1; }
    guint32 rn = 0;
    g_variant_get(ret, "(u)", &rn);
    g_variant_unref(ret);
    if (rn != 1u && rn != 4u) {
        // 3 = 别人已是主属主（典型：旧 autostart 又起了一只）⇒ **退 0 不报错**，
        // 否则 unit 的 Restart=always 会每 3 s 拉起一次失败的实例（2026-11-12 实测坑）。
        logmsg("org.kde.impanel already owned (result=%u); exiting quietly", rn);
        return 0;
    }
    logmsg("ready: owns org.kde.impanel");

    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_timeout_add_seconds(1, idle_check, NULL);
    g_main_loop_run(loop);
    return 0;
}
