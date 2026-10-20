// osk-ime — 触摸中文输入法的「唤起 / 折叠隐藏」控制面
//
// 设计（依据 reports/ime-osk0-dbus-spec-20261020.md 的源码取证）：
//   * 本进程是 zwp_input_method_v2 的客户端（和 fcitx5 抢同一个 seat slot），
//     因此它**能**看到 focus 事件：activate() / deactivate()。
//     ⇒ 文本框获得焦点 = activate ⇒ 唤起 wvkbd；失焦 = deactivate ⇒ 折叠 wvkbd。
//   * 它同时注册 DBus 名 sm.puri.OSK0（SetVisible(b) 方法 + 只读 Visible 属性），
//     ⇒ Phosh 自己的「屏幕键盘」入口（长按电源条 / 锁屏键盘键）也能唤起/折叠。
//   * 显示/隐藏一律用信号驱动 wvkbd：SIGUSR2=show、SIGUSR1=hide（wvkbd 0.19.4，
//     hide 会销毁 layer surface，--hidden 启动时不建 surface）。
//   * fcitx5 仍持有真正的 IM slot 做中文组词；本进程收到 unavailable 时不会退出，
//     只是失去 focus 事件源（此时靠 DBus 手动开关）。见 README 的权衡说明。
//
// 用法：
//   osk-ime            # 前台运行（由 zh-osk 以 setsid 拉起）
//   osk-ime --toggle   # 手动切换一次（等价于触摸按钮），走 DBus 调用
//   osk-ime --show / --hide
//   osk-ime --status
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <gio/gio.h>
#include <gio/gunixfdlist.h>
#include <wayland-client.h>
#include "im-v2-client.h"

#define WKBD_NAME "wvkbd-mobintl"
#define LOG_PATH "/tmp/osk-ime.log"

static FILE *lf;
static void logmsg(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void logmsg(const char *fmt, ...) {
    va_list ap;
    if (!lf) lf = fopen(LOG_PATH, "a");
    if (!lf) return;
    va_start(ap, fmt);
    vfprintf(lf, fmt, ap);
    va_end(ap);
    fputc('\n', lf);
    fflush(lf);
}

/* ---------------- wvkbd 控制 ---------------- */

static int wvkbd_pid(void) {
    /* 只认进程名精确等于 wvkbd-mobintl 的（避免 pkill -f 自杀类事故） */
    FILE *p = popen("pidof " WKBD_NAME " 2>/dev/null", "r");
    if (!p) return 0;
    int pid = 0;
    if (fscanf(p, "%d", &pid) != 1) pid = 0;
    pclose(p);
    return pid;
}

static void wvkbd_signal(int sig) {
    int pid = wvkbd_pid();
    if (pid > 0) {
        kill(pid, sig);
        logmsg("wvkbd pid=%d <- signal %d", pid, sig);
    } else {
        logmsg("wvkbd not running (signal %d ignored)", sig);
    }
}

static void wvkbd_show(void) {
    if (wvkbd_pid() > 0) {
        wvkbd_signal(SIGUSR2);
        return;
    }
    /* 不在就拉起来（--hidden 保证先不建 surface，随后统一用 SIGUSR2 显示） */
    logmsg("starting " WKBD_NAME);
    pid_t c = fork();
    if (c == 0) {
        setsid();
        execlp(WKBD_NAME, WKBD_NAME, (char *)NULL);
        _exit(127);
    }
    usleep(600 * 1000);
    wvkbd_signal(SIGUSR2);
}

static void wvkbd_hide(void) { wvkbd_signal(SIGUSR1); }

/* ---------------- DBus（sm.puri.OSK0） ---------------- */

static int g_visible = 0;

static const char *osk0_xml =
    "<node>"
    "<interface name='sm.puri.OSK0'>"
    "<method name='SetVisible'><arg type='b' name='visible' direction='in'/></method>"
    "<property name='Visible' type='b' access='read'/>"
    "</interface>"
    "</node>";

/* 由 main 里注册；这里声明以解耦顺序 */
static void osk0_set_visible(gboolean visible);

static void osk0_method_call(GDBusConnection *c, const gchar *sender, const gchar *path,
                             const gchar *iface, const gchar *method, GVariant *params,
                             GDBusMethodInvocation *inv, gpointer user) {
    (void)c; (void)sender; (void)path; (void)iface; (void)user;
    if (!strcmp(method, "SetVisible")) {
        gboolean v = FALSE;
        g_variant_get(params, "(b)", &v);
        logmsg("dbus SetVisible(%d)", v);
        osk0_set_visible(v);
    }
    g_dbus_method_invocation_return_value(inv, NULL);
}

static GVariant *osk0_get_property(GDBusConnection *c, const gchar *sender, const gchar *path,
                                   const gchar *iface, const gchar *prop, GError **err,
                                   gpointer user) {
    (void)c; (void)sender; (void)path; (void)iface; (void)user; (void)err;
    if (!strcmp(prop, "Visible"))
        return g_variant_new_boolean(g_visible);
    return NULL;
}

static const GDBusInterfaceVTable osk0_vtable = { osk0_method_call, osk0_get_property, NULL };

static void osk0_set_visible(gboolean visible) {
    g_visible = visible ? 1 : 0;
    if (g_visible) wvkbd_show(); else wvkbd_hide();
}

static GDBusConnection *bus;

static void dbus_init(void) {
    GError *err = NULL;
    bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &err);
    if (!bus) { logmsg("dbus connect failed: %s", err ? err->message : "?"); return; }

    GDBusNodeInfo *info = g_dbus_node_info_new_for_xml(osk0_xml, &err);
    if (!info) { logmsg("dbus xml failed: %s", err->message); return; }
    guint id = g_dbus_connection_register_object(bus, "/sm/puri/OSK0", info->interfaces[0],
                                                &osk0_vtable, NULL, NULL, &err);
    if (!id) { logmsg("register object failed: %s", err->message); return; }

    /* 抢占名字；若已被 squeekboard 占着，走 REPLACE 会把它踢掉，这里不 REPLACE，
     * 只报告失败（squeekboard 在场说明用户/vendor 方案在跑，不该硬顶）。 */
    GVariant *ret = g_dbus_connection_call_sync(bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                                                "org.freedesktop.DBus", "RequestName",
                                                g_variant_new("(su)", "sm.puri.OSK0", 0u),
                                                NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, &err);
    if (!ret) {
        logmsg("RequestName failed: %s", err ? err->message : "?");
        return;
    }
    guint32 r = 0;
    g_variant_get(ret, "(u)", &r);
    g_variant_unref(ret);
    logmsg("sm.puri.OSK0 acquired (reply=%u)", r);
}

/* ---------------- wayland IM（focus 事件源） ---------------- */

static struct wl_display *dpy;
static struct wl_seat *seat;
static struct zwp_input_method_manager_v2 *im_mgr;
static struct zwp_input_method_v2 *im;
static struct zwp_input_method_keyboard_grab_v2 *kb_grab;

static void im_activate(void *d, struct zwp_input_method_v2 *x) {
    (void)d; (void)x;
    logmsg("activate -> show");
    osk0_set_visible(TRUE);
}
static void im_deactivate(void *d, struct zwp_input_method_v2 *x) {
    (void)d; (void)x;
    logmsg("deactivate -> hide");
    osk0_set_visible(FALSE);
}
static void im_surrounding_text(void *d, struct zwp_input_method_v2 *x, const char *t, uint32_t c1, uint32_t c2) {
    (void)d; (void)x; (void)t; (void)c1; (void)c2;
}
static void im_text_change_cause(void *d, struct zwp_input_method_v2 *x, uint32_t c) { (void)d; (void)x; (void)c; }
static void im_content_type(void *d, struct zwp_input_method_v2 *x, uint32_t h, uint32_t p) { (void)d; (void)x; (void)h; (void)p; }
static void im_done(void *d, struct zwp_input_method_v2 *x) { (void)d; (void)x; }
static void im_unavailable(void *d, struct zwp_input_method_v2 *x) {
    (void)d; (void)x;
    /* 槽位被别的 IM（正常是 fcitx5）占着 ⇒ 收不到 focus 事件。
     * 不退出：DBus 手动开关仍然可用。 */
    logmsg("unavailable (another IM holds the seat slot; focus-driven show/hide disabled)");
}
static const struct zwp_input_method_v2_listener im_listener = {
    .activate = im_activate,
    .deactivate = im_deactivate,
    .surrounding_text = im_surrounding_text,
    .text_change_cause = im_text_change_cause,
    .content_type = im_content_type,
    .done = im_done,
    .unavailable = im_unavailable,
};

static void kb_grab_keymap(void *d, struct zwp_input_method_keyboard_grab_v2 *g, uint32_t fmt, int32_t fd, uint32_t size) {
    (void)d; (void)g; (void)fmt; (void)size; if (fd >= 0) close(fd);
}
static void kb_grab_modifiers(void *d, struct zwp_input_method_keyboard_grab_v2 *g, uint32_t serial, uint32_t mdep, uint32_t mlat, uint32_t mlock, uint32_t group) {
    (void)d; (void)g; (void)serial; (void)mdep; (void)mlat; (void)mlock; (void)group;
}
static void kb_grab_key(void *d, struct zwp_input_method_keyboard_grab_v2 *g, uint32_t serial, uint32_t t, uint32_t key, uint32_t st) {
    (void)d; (void)g; (void)serial; (void)t; (void)key; (void)st;
}
static void kb_grab_repeat(void *d, struct zwp_input_method_keyboard_grab_v2 *g, uint32_t r, uint32_t dl) {
    (void)d; (void)g; (void)r; (void)dl;
}
static const struct zwp_input_method_keyboard_grab_v2_listener kb_grab_listener = {
    .keymap = kb_grab_keymap,
    .key = kb_grab_key,
    .modifiers = kb_grab_modifiers,
    .repeat_info = kb_grab_repeat,
};

static void seat_caps(void *d, struct wl_seat *s, uint32_t caps) { (void)d; (void)s; (void)caps; }
static void seat_name(void *d, struct wl_seat *s, const char *n) { (void)d; (void)s; (void)n; }
static const struct wl_seat_listener seat_listener = { .capabilities = seat_caps, .name = seat_name };

static void reg_global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    (void)d; (void)ver;
    if (!strcmp(iface, "wl_seat")) {
        if (!seat) {
            seat = wl_registry_bind(r, name, &wl_seat_interface, 3);
            wl_seat_add_listener(seat, &seat_listener, NULL);
        }
    } else if (!strcmp(iface, "zwp_input_method_manager_v2")) {
        im_mgr = wl_registry_bind(r, name, &zwp_input_method_manager_v2_interface, 1);
    }
}
static void reg_remove(void *d, struct wl_registry *r, uint32_t name) { (void)d; (void)r; (void)name; }
static const struct wl_registry_listener reg_listener = { .global = reg_global, .global_remove = reg_remove };

static gboolean wl_fd_cb(gint fd, GIOCondition cond, gpointer data) {
    struct wl_display *D = data;
    (void)fd; (void)cond;
    if (wl_display_dispatch(D) < 0) {
        logmsg("wayland dispatch failed: %d", wl_display_get_error(D));
        return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}

static int wl_init(void) {
    dpy = wl_display_connect(NULL);
    if (!dpy) { logmsg("no wayland display"); return -1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &reg_listener, NULL);
    wl_display_roundtrip(dpy);
    if (!im_mgr) { logmsg("compositor has no zwp_input_method_manager_v2"); return -1; }
    if (!seat) { logmsg("no wl_seat"); return -1; }
    im = zwp_input_method_manager_v2_get_input_method(im_mgr, seat);
    zwp_input_method_v2_add_listener(im, &im_listener, NULL);
    wl_display_roundtrip(dpy);
    logmsg("wayland IM registered");
    return 0;
}

/* ---------------- DBus 一次性调用（--show/--hide/--toggle/--status） ---------------- */

static int dbus_call(const char *method, GVariant *arg) {
    GError *err = NULL;
    GDBusConnection *c = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &err);
    if (!c) { fprintf(stderr, "dbus: %s\n", err ? err->message : "?"); return 1; }
    GVariant *ret = g_dbus_connection_call_sync(c, "sm.puri.OSK0", "/sm/puri/OSK0",
                                                "sm.puri.OSK0", method, arg,
                                                NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, &err);
    if (!ret) { fprintf(stderr, "%s failed: %s\n", method, err ? err->message : "?"); return 1; }
    g_variant_unref(ret);
    return 0;
}

static int dbus_get_visible(void) {
    GError *err = NULL;
    GDBusConnection *c = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &err);
    if (!c) return -1;
    GVariant *ret = g_dbus_connection_call_sync(c, "sm.puri.OSK0", "/sm/puri/OSK0",
                                                "org.freedesktop.DBus.Properties", "Get",
                                                g_variant_new("(ss)", "sm.puri.OSK0", "Visible"),
                                                NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, &err);
    if (!ret) return -1;
    GVariant *v = g_variant_get_child_value(ret, 0);
    GVariant *b = g_variant_get_variant(v);
    int r = g_variant_get_boolean(b) ? 1 : 0;
    g_variant_unref(b); g_variant_unref(v); g_variant_unref(ret);
    return r;
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);

    if (argc > 1 && argv[1][0] == '-') {
        const char *cmd = argv[1];
        if (!strcmp(cmd, "--status")) {
            int v = dbus_get_visible();
            if (v < 0) { fprintf(stderr, "osk-ime service not reachable\n"); return 2; }
            printf("%s\n", v ? "visible" : "hidden");
            return 0;
        }
        if (!strcmp(cmd, "--show"))   return dbus_call("SetVisible", g_variant_new("(b)", TRUE));
        if (!strcmp(cmd, "--hide"))   return dbus_call("SetVisible", g_variant_new("(b)", FALSE));
        if (!strcmp(cmd, "--toggle")) {
            int v = dbus_get_visible();
            if (v < 0) { fprintf(stderr, "osk-ime service not reachable\n"); return 2; }
            return dbus_call("SetVisible", g_variant_new("(b)", v ? FALSE : TRUE));
        }
        fprintf(stderr, "usage: %s [--show|--hide|--toggle|--status]\n", argv[0]);
        return 2;
    }

    logmsg("=== osk-ime start pid=%d", (int)getpid());

    dbus_init();

    /* DBus 服务是主体；wayland IM 只是 focus 事件源，拿不到 slot 也继续跑。 */
    if (wl_init() == 0) {
        g_unix_fd_add(wl_display_get_fd(dpy), G_IO_IN, wl_fd_cb, dpy);
    }

    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    logmsg("running (dbus %s, wayland %s)", bus ? "up" : "down", dpy ? "up" : "down");
    g_main_loop_run(loop);
    return 0;
}
