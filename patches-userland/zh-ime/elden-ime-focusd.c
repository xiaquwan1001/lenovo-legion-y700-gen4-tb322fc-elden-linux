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
// 折叠：由 elden-ime-toggle（应用网格「键盘」图标）或 phosh 自身逻辑负责 —— fcitx5
//       没有 FocusOut 的可靠信号，所以本程序**只负责唤起，不负责自动收起**（诚实边界）。
//
// 编译：见同目录 build.sh（gcc + gio-2.0 + glib-2.0）

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

static void want_keyboard(const char *why) {
    gint64 now = g_get_monotonic_time();
    if (now - last_show_us < 400000) return;      // 400 ms 去抖
    osk_get_visible();
    if (osk_visible) return;
    logmsg("show requested by %s", why);
    osk_set_visible(TRUE);
    last_show_us = now;
}

// ---- kimpanel panel side (org.kde.impanel) ----
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
    (void)c; (void)sender; (void)path; (void)iface; (void)params; (void)user;

    if (!strcmp(method, "SetSpotRect") || !strcmp(method, "SetRelativeSpotRect") ||
        !strcmp(method, "UpdateSpotLocation")) {
        want_keyboard(method);
    } else if (!strcmp(method, "Enable")) {
        gboolean en = FALSE;
        if (params && g_variant_is_of_type(params, G_VARIANT_TYPE("(b)")))
            g_variant_get(params, "(b)", &en);
        if (en) want_keyboard("Enable(true)");
    } else if (!strcmp(method, "ShowPreedit")) {
        gboolean en = FALSE;
        if (params && g_variant_is_of_type(params, G_VARIANT_TYPE("(b)")))
            g_variant_get(params, "(b)", &en);
        if (en) want_keyboard("ShowPreedit(true)");
    } else if (!strcmp(method, "SetLookupTable")) {
        GVariant *cands = NULL;
        if (params && g_variant_is_of_type(params, G_VARIANT_TYPE("(asasasbbii)"))) {
            GVariant *v = g_variant_get_child_value(params, 1);
            if (v) { if (g_variant_n_children(v) > 0) want_keyboard("SetLookupTable"); g_variant_unref(v); }
        }
        (void)cands;
    }
    g_dbus_method_invocation_return_value(inv, NULL);
}

int main(void) {
    GError *err = NULL;
    logmsg("=== start pid=%d", getpid());
    bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &err);
    if (!bus) { logmsg("no session bus: %s", err->message); return 1; }

    GDBusNodeInfo *info = g_dbus_node_info_new_for_xml(impanel_xml, &err);
    if (!info) { logmsg("xml: %s", err->message); return 1; }
    static const GDBusInterfaceVTable vt = { .method_call = method_call };
    guint id = g_dbus_connection_register_object(bus, "/org/kde/impanel", info->interfaces[0],
                                                &vt, NULL, NULL, &err);
    if (!id) { logmsg("register: %s", err->message); return 1; }
    GVariant *ret = g_dbus_connection_call_sync(
        bus, "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
        g_variant_new("(su)", "org.kde.impanel", 0u), NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, &err);
    if (!ret) { logmsg("RequestName: %s", err->message); return 1; }
    g_variant_unref(ret);
    logmsg("ready: owns org.kde.impanel");

    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_main_loop_run(loop);
    return 0;
}
