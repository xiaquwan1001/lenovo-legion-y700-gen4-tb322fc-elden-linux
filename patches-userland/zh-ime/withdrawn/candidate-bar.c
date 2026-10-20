// fcitx5-candbar —— Phosh/phoc 下显示 fcitx5 候选词的可点击候选条。
//
// 背景：fcitx5 的 classicui 候选窗用 zwp_input_popup_surface_v2，phoc 不渲染，
// 所以在 Phosh 上看不到候选词。这里改用 fcitx5 的 kimpanel 后端：
//   1) 本程序占用 org.kde.impanel，实现 org.kde.impanel2.SetLookupTable
//   2) 用 wlr-layer-shell 画一条候选条（layer=top，锚在屏幕底部、wvkbd 上方）
//   3) 点击候选时用 zwp_virtual_keyboard_v1 注入对应数字键，交给 fcitx5 选词
#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <glib.h>
#include <glib-unix.h>
#include <gio/gio.h>
#include <wayland-client.h>
#include <cairo/cairo.h>
#include <pango/pangocairo.h>
#include <xkbcommon/xkbcommon.h>
#include "layer-shell-client.h"
#include "vk-client.h"

#define MAX_CAND 16

static struct wl_display *dpy;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct wl_seat *seat;
static struct wl_output *output;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct zwlr_layer_surface_v1 *lsurf;
static struct wl_surface *surface;
static struct wl_buffer *buffer;
static void *pixels;
static size_t pixels_size;
static int buf_w, buf_h;

static struct zwp_virtual_keyboard_manager_v1 *vk_mgr;
static struct zwp_virtual_keyboard_v1 *vk;
static int vk_ready = 0;

static int out_scale = 1;
static int cfg_w = 0, cfg_h = 64;
static int margin_bottom = 300;
static int bar_font_px = 22;
static int mapped = 0;

static char *labels[MAX_CAND];
static char *cands[MAX_CAND];
static int ncand = 0;

typedef struct { int x0, x1, keycode; } Cell;
static Cell cells[MAX_CAND];
static int ncells = 0;
static double pointer_x = -1;

static void logmsg(const char *fmt, ...) {
    static FILE *f;
    if (!f) f = fopen("/tmp/fcitx5-candbar.log", "a");
    if (!f) return;
    va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap);
    fputc('\n', f); fflush(f);
}

static int digit_keycode(char c) {
    switch (c) {
        case '1': return 2; case '2': return 3; case '3': return 4; case '4': return 5;
        case '5': return 6; case '6': return 7; case '7': return 8; case '8': return 9;
        case '9': return 10; case '0': return 11;
    }
    return 0;
}

static void inject_keycode(int keycode) {
    if (!vk_ready || keycode <= 0) return;
    uint32_t t = (uint32_t)(clock() / 1000);
    zwp_virtual_keyboard_v1_key(vk, t, (uint32_t)keycode, 1);
    zwp_virtual_keyboard_v1_key(vk, t + 5, (uint32_t)keycode, 0);
    wl_display_flush(dpy);
    logmsg("inject keycode=%d", keycode);
}

// ---------------- drawing ----------------

static void ensure_buffer(int w, int h) {
    if (buffer && w == buf_w && h == buf_h) return;
    if (buffer) { wl_buffer_destroy(buffer); buffer = NULL; }
    if (pixels) { munmap(pixels, pixels_size); pixels = NULL; }
    buf_w = w; buf_h = h;
    pixels_size = (size_t)w * h * 4;
    int fd = memfd_create("candbar", MFD_CLOEXEC);
    if (ftruncate(fd, (off_t)pixels_size) < 0) { perror("ftruncate"); exit(1); }
    pixels = mmap(NULL, pixels_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int)pixels_size);
    buffer = wl_shm_pool_create_buffer(pool, 0, w, h, w * 4, WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);
}

static void draw(void) {
    int scale = out_scale > 0 ? out_scale : 1;
    if (getenv("CANDBAR_SIMPLE")) scale = 1;
    int w = cfg_w * scale, h = cfg_h * scale;
    ensure_buffer(w, h);
    cairo_surface_t *cs = cairo_image_surface_create_for_data(pixels, CAIRO_FORMAT_ARGB32, w, h, w * 4);
    cairo_t *cr = cairo_create(cs);
    cairo_scale(cr, scale, scale);

    cairo_set_source_rgba(cr, 0.10, 0.10, 0.12, 0.97);
    cairo_paint(cr);

    PangoLayout *layout = pango_cairo_create_layout(cr);
    PangoFontDescription *fd = pango_font_description_new();
    pango_font_description_set_family(fd, "Sans");
    pango_font_description_set_absolute_size(fd, bar_font_px * PANGO_SCALE);
    pango_layout_set_font_description(layout, fd);

    ncells = 0;
    int x = 8;
    for (int i = 0; i < ncand; i++) {
        char lab[32];
        snprintf(lab, sizeof lab, "%s", labels[i] ? labels[i] : "");
        g_strstrip(lab);
        char text[512];
        snprintf(text, sizeof text, "%s%s%s", lab, lab[0] ? " " : "", cands[i] ? cands[i] : "");
        pango_layout_set_text(layout, text, -1);
        int tw = 0, th = 0;
        pango_layout_get_pixel_size(layout, &tw, &th);
        int cell_w = tw + 26;
        if (x + cell_w > cfg_w - 6) break;
        cairo_set_source_rgba(cr, 0.20, 0.21, 0.26, 1.0);
        cairo_rectangle(cr, x, 6, cell_w - 6, cfg_h - 12);
        cairo_fill(cr);
        cairo_set_source_rgba(cr, 0.93, 0.93, 0.97, 1.0);
        cairo_move_to(cr, x + 10, (cfg_h - th) / 2.0);
        pango_cairo_show_layout(cr, layout);
        cells[ncells].x0 = x;
        cells[ncells].x1 = x + cell_w - 6;
        cells[ncells].keycode = digit_keycode(lab[0]);
        ncells++;
        x += cell_w;
    }
    pango_font_description_free(fd);
    g_object_unref(layout);
    cairo_destroy(cr);
    cairo_surface_flush(cs);
    cairo_surface_destroy(cs);
}

static void commit_bar(void) {
    if (ncand == 0) {
        if (mapped) {
            wl_surface_attach(surface, NULL, 0, 0);
            wl_surface_commit(surface);
            wl_display_flush(dpy);
            mapped = 0;
        }
        return;
    }
    if (cfg_w <= 0) return;
    draw();
    if (!getenv("CANDBAR_SIMPLE")) {
        wl_surface_set_buffer_scale(surface, out_scale > 0 ? out_scale : 1);
        wl_surface_attach(surface, buffer, 0, 0);
        wl_surface_damage_buffer(surface, 0, 0, buf_w, buf_h);
    } else {
        wl_surface_attach(surface, buffer, 0, 0);
        wl_surface_damage(surface, 0, 0, cfg_w, cfg_h);
    }
    wl_surface_commit(surface);
    int fr = wl_display_flush(dpy);
    logmsg("commit %dx%d scale=%d flush=%d errno=%d", buf_w, buf_h, out_scale, fr, errno);
    mapped = 1;
}

// ---------------- wayland ----------------

static void ls_configure(void *d, struct zwlr_layer_surface_v1 *s, uint32_t serial, uint32_t w, uint32_t h) {
    (void)d;
    zwlr_layer_surface_v1_ack_configure(s, serial);
    if ((int)w > 0) cfg_w = (int)w;
    if ((int)h > 0) cfg_h = (int)h;
    logmsg("configure %dx%d scale=%d", cfg_w, cfg_h, out_scale);
    if (getenv("CANDBAR_TEST")) {
        ncand = 0;
        labels[ncand] = g_strdup("1"); cands[ncand] = g_strdup("你"); ncand++;
        labels[ncand] = g_strdup("2"); cands[ncand] = g_strdup("那"); ncand++;
    }
    commit_bar();
}
static void ls_closed(void *d, struct zwlr_layer_surface_v1 *s) { (void)d; (void)s; logmsg("closed"); exit(0); }
static const struct zwlr_layer_surface_v1_listener ls_listener = { .configure = ls_configure, .closed = ls_closed };

static void ptr_enter(void *d, struct wl_pointer *p, uint32_t serial, struct wl_surface *s, wl_fixed_t x, wl_fixed_t y) {
    (void)d;(void)p;(void)serial;(void)s;(void)y;
    pointer_x = wl_fixed_to_double(x);
    logmsg("ptr enter x=%.1f", pointer_x);
}
static void ptr_leave(void *d, struct wl_pointer *p, uint32_t serial, struct wl_surface *s) {
    (void)d;(void)p;(void)serial;(void)s;
    pointer_x = -1;
}
static void ptr_motion(void *d, struct wl_pointer *p, uint32_t t, wl_fixed_t x, wl_fixed_t y) {
    (void)d;(void)p;(void)t;(void)y;
    pointer_x = wl_fixed_to_double(x);
}
static void select_at(double x) {
    for (int i = 0; i < ncells; i++) {
        if (x >= cells[i].x0 && x <= cells[i].x1) {
            inject_keycode(cells[i].keycode);
            return;
        }
    }
    logmsg("tap x=%.1f no cell (ncells=%d)", x, ncells);
}

static void ptr_button(void *d, struct wl_pointer *p, uint32_t serial, uint32_t t, uint32_t button, uint32_t state) {
    (void)d;(void)p;(void)serial;(void)t;
    logmsg("ptr button btn=0x%x state=%u x=%.1f", button, state, pointer_x);
    if (state != WL_POINTER_BUTTON_STATE_PRESSED || button != 0x110) return;
    select_at(pointer_x);
}

// 触摸屏：手指按下/抬起
static void touch_down(void *d, struct wl_touch *t, uint32_t serial, uint32_t time, struct wl_surface *s,
                       int32_t id, wl_fixed_t x, wl_fixed_t y) {
    (void)d;(void)t;(void)serial;(void)time;(void)s;(void)id;(void)y;
    pointer_x = wl_fixed_to_double(x);
}
static void touch_up(void *d, struct wl_touch *t, uint32_t serial, uint32_t time, int32_t id) {
    (void)d;(void)t;(void)serial;(void)time;(void)id;
    select_at(pointer_x);
}
static void touch_motion(void *d, struct wl_touch *t, uint32_t time, int32_t id, wl_fixed_t x, wl_fixed_t y) {
    (void)d;(void)t;(void)time;(void)id;(void)y;
    pointer_x = wl_fixed_to_double(x);
}
static void touch_frame(void *d, struct wl_touch *t) { (void)d;(void)t; }
static void touch_cancel(void *d, struct wl_touch *t) { (void)d;(void)t; }
static void touch_shape(void *d, struct wl_touch *t, int32_t id, wl_fixed_t mx, wl_fixed_t my) { (void)d;(void)t;(void)id;(void)mx;(void)my; }
static void touch_orient(void *d, struct wl_touch *t, int32_t id, wl_fixed_t o) { (void)d;(void)t;(void)id;(void)o; }
static const struct wl_touch_listener touch_listener = {
    .down = touch_down, .up = touch_up, .motion = touch_motion, .frame = touch_frame,
    .cancel = touch_cancel, .shape = touch_shape, .orientation = touch_orient,
};
static const struct wl_pointer_listener ptr_listener = {
    .enter = ptr_enter, .leave = ptr_leave, .motion = ptr_motion, .button = ptr_button,
};

static void seat_caps(void *d, struct wl_seat *s, uint32_t caps) {
    (void)d;
    logmsg("seat caps=0x%x", caps);
    if (caps & WL_SEAT_CAPABILITY_POINTER) {
        static int have_ptr = 0;
        if (!have_ptr) {
            struct wl_pointer *ptr = wl_seat_get_pointer(s);
            wl_pointer_add_listener(ptr, &ptr_listener, NULL);
            have_ptr = 1;
        }
    }
    if (caps & WL_SEAT_CAPABILITY_TOUCH) {
        static int have_touch = 0;
        if (!have_touch) {
            struct wl_touch *t = wl_seat_get_touch(s);
            wl_touch_add_listener(t, &touch_listener, NULL);
            have_touch = 1;
        }
    }
}
static void seat_name(void *d, struct wl_seat *s, const char *n) { (void)d;(void)s;(void)n; }
static const struct wl_seat_listener seat_listener = { .capabilities = seat_caps, .name = seat_name };

static void out_geometry(void *d, struct wl_output *o, int32_t x, int32_t y, int32_t pw, int32_t ph,
                         int32_t sub, const char *mk, const char *md, int32_t tr) {
    (void)d;(void)o;(void)x;(void)y;(void)pw;(void)ph;(void)sub;(void)mk;(void)md;(void)tr;
}
static void out_mode(void *d, struct wl_output *o, uint32_t f, int32_t w, int32_t h, int32_t r) {
    (void)d;(void)o;(void)f;(void)w;(void)h;(void)r;
}
static void out_done(void *d, struct wl_output *o) { (void)d;(void)o; }
static void out_scale_cb(void *d, struct wl_output *o, int32_t f) { (void)d;(void)o; if (f > 0) out_scale = f; }
static const struct wl_output_listener output_listener = {
    .geometry = out_geometry, .mode = out_mode, .done = out_done, .scale = out_scale_cb,
};

static void reg_global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    (void)d;
    if (!strcmp(iface, "wl_compositor"))
        compositor = wl_registry_bind(r, name, &wl_compositor_interface, 4);
    else if (!strcmp(iface, "wl_shm"))
        shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
    else if (!strcmp(iface, "wl_seat"))
        seat = wl_registry_bind(r, name, &wl_seat_interface, 3);
    else if (!strcmp(iface, "wl_output") && !output)
        output = wl_registry_bind(r, name, &wl_output_interface, 3);
    else if (!strcmp(iface, "zwlr_layer_shell_v1"))
        layer_shell = wl_registry_bind(r, name, &zwlr_layer_shell_v1_interface, 1);
    else if (!strcmp(iface, "zwp_virtual_keyboard_manager_v1"))
        vk_mgr = wl_registry_bind(r, name, &zwp_virtual_keyboard_manager_v1_interface, 1);
}
static void reg_remove(void *d, struct wl_registry *r, uint32_t name) { (void)d;(void)r;(void)name; }
static const struct wl_registry_listener reg_listener = { .global = reg_global, .global_remove = reg_remove };

static void vk_setup(void) {
    if (!seat || !vk_mgr) { logmsg("no seat/vk_mgr: seat=%p mgr=%p", (void*)seat, (void*)vk_mgr); return; }
    vk = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(vk_mgr, seat);
    struct xkb_context *ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    struct xkb_keymap *km = xkb_keymap_new_from_names(ctx, NULL, XKB_KEYMAP_COMPILE_NO_FLAGS);
    char *str = xkb_keymap_get_as_string(km, XKB_KEYMAP_FORMAT_TEXT_V1);
    size_t len = strlen(str) + 1;
    int fd = memfd_create("vk-keymap", MFD_CLOEXEC);
    if (ftruncate(fd, (off_t)len) < 0) { perror("ftruncate"); return; }
    void *p = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    memcpy(p, str, len);
    munmap(p, len);
    zwp_virtual_keyboard_v1_keymap(vk, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, fd, (uint32_t)len);
    vk_ready = 1;
    wl_display_flush(dpy);
}

static gboolean wl_cb(gint fd, GIOCondition cond, gpointer data) {
    (void)fd; (void)cond; (void)data;
    if (wl_display_dispatch(dpy) < 0) {
        int err = wl_display_get_error(dpy);
        if (err == EPROTO) {
            const struct wl_interface *iface = NULL; uint32_t id = 0;
            uint32_t code = wl_display_get_protocol_error(dpy, &iface, &id);
            logmsg("protocol error iface=%s code=%u id=%u", iface ? iface->name : "?", code, id);
        } else {
            logmsg("wl error %d", err);
        }
        exit(1);
    }
    return G_SOURCE_CONTINUE;
}

// ---------------- kimpanel DBus ----------------

static void set_lookup_table(GVariant *params) {
    if (!g_variant_is_of_type(params, G_VARIANT_TYPE("(asasasbbii)"))) return;
    GVariant *vlab = g_variant_get_child_value(params, 0);
    GVariant *vcan = g_variant_get_child_value(params, 1);
    for (int i = 0; i < MAX_CAND; i++) {
        g_free(labels[i]); labels[i] = NULL;
        g_free(cands[i]); cands[i] = NULL;
    }
    ncand = 0;
    gsize n = g_variant_n_children(vcan);
    gsize nl = g_variant_n_children(vlab);
    if (n > MAX_CAND) n = MAX_CAND;
    for (gsize i = 0; i < n; i++) {
        GVariant *e = g_variant_get_child_value(vcan, i);
        cands[ncand] = g_variant_dup_string(e, NULL);
        g_variant_unref(e);
        if (i < nl) {
            GVariant *l = g_variant_get_child_value(vlab, i);
            labels[ncand] = g_variant_dup_string(l, NULL);
            g_variant_unref(l);
        } else {
            labels[ncand] = g_strdup("");
        }
        ncand++;
    }
    g_variant_unref(vlab);
    g_variant_unref(vcan);
    logmsg("SetLookupTable n=%d first=%s", ncand, ncand ? cands[0] : "");
    commit_bar();
}

static void method_call(GDBusConnection *c, const gchar *sender, const gchar *path,
                        const gchar *iface, const gchar *method, GVariant *params,
                        GDBusMethodInvocation *inv, gpointer user) {
    (void)c;(void)sender;(void)path;(void)iface;(void)user;
    if (!getenv("CANDBAR_QUIET")) logmsg("call %s", method);
    if (!strcmp(method, "SetLookupTable")) {
        set_lookup_table(params);
    }
    g_dbus_method_invocation_return_value(inv, NULL);
}

static const gchar *dbus_xml =
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

static void dbus_setup(void) {
    GError *err = NULL;
    GDBusConnection *conn = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &err);
    if (!conn) { logmsg("dbus connect failed: %s", err->message); exit(1); }
    GDBusNodeInfo *info = g_dbus_node_info_new_for_xml(dbus_xml, &err);
    if (!info) { logmsg("dbus xml failed: %s", err->message); exit(1); }
    static const GDBusInterfaceVTable vtable = { .method_call = method_call };
    guint id = g_dbus_connection_register_object(conn, "/org/kde/impanel",
                                                 info->interfaces[0], &vtable, NULL, NULL, &err);
    if (!id) { logmsg("register object failed: %s", err->message); exit(1); }
    GVariant *ret = g_dbus_connection_call_sync(conn, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                                                "org.freedesktop.DBus", "RequestName",
                                                g_variant_new("(su)", "org.kde.impanel", 0u),
                                                NULL, G_DBUS_CALL_FLAGS_NONE, -1, NULL, &err);
    if (!ret) { logmsg("RequestName failed: %s", err->message); exit(1); }
    g_variant_unref(ret);
    logmsg("dbus ready: org.kde.impanel");
}

int main(int argc, char **argv) {
    const char *e;
    if ((e = getenv("CANDBAR_HEIGHT"))) cfg_h = atoi(e);
    if ((e = getenv("CANDBAR_MARGIN"))) margin_bottom = atoi(e);
    if ((e = getenv("CANDBAR_FONT"))) bar_font_px = atoi(e);
    logmsg("=== start pid=%d h=%d margin=%d font=%d", getpid(), cfg_h, margin_bottom, bar_font_px);

    dpy = wl_display_connect(NULL);
    if (!dpy) { logmsg("no wayland"); return 1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &reg_listener, NULL);
    wl_display_roundtrip(dpy);
    if (!compositor || !shm || !layer_shell) { logmsg("missing globals"); return 1; }
    if (output) wl_output_add_listener(output, &output_listener, NULL);
    if (seat) wl_seat_add_listener(seat, &seat_listener, NULL);
    wl_display_roundtrip(dpy);
    if (!getenv("CANDBAR_NOVK")) vk_setup();
    if (getenv("CANDBAR_NOSCALE")) { out_scale = 1; logmsg("scale forced to 1"); }

    surface = wl_compositor_create_surface(compositor);
    lsurf = zwlr_layer_shell_v1_get_layer_surface(layer_shell, surface, NULL, 2 /*top*/, "candidate-bar");
    zwlr_layer_surface_v1_add_listener(lsurf, &ls_listener, NULL);
    zwlr_layer_surface_v1_set_size(lsurf, 0, (uint32_t)cfg_h);
    zwlr_layer_surface_v1_set_anchor(lsurf, 2 /*bottom*/ | 4 /*left*/ | 8 /*right*/);
    zwlr_layer_surface_v1_set_margin(lsurf, 0, 0, (int32_t)margin_bottom, 0);
    zwlr_layer_surface_v1_set_exclusive_zone(lsurf, -1);
    zwlr_layer_surface_v1_set_keyboard_interactivity(lsurf, 0);
    wl_surface_commit(surface);
    wl_display_flush(dpy);

    dbus_setup();
    g_unix_fd_add(wl_display_get_fd(dpy), G_IO_IN, wl_cb, NULL);
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_main_loop_run(loop);
    return 0;
}
