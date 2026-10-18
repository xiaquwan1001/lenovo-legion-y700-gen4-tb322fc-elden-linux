/* Minimal input-method-unstable-v2 client.
 * Connects, optionally grabs the keyboard, then exits.
 * Usage: imtest [grab|nograb]
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "im-v2.h"

static struct wl_seat *seat;
static struct zwp_input_method_manager_v2 *im_mgr;
static struct zwp_input_method_v2 *im;
static struct zwp_input_method_keyboard_grab_v2 *grab;
static int grabbed;

static void im_unavailable(void *d, struct zwp_input_method_v2 *x) {
  fprintf(stderr, "IM: unavailable\n");
}
static void im_activate(void *d, struct zwp_input_method_v2 *x) {
  fprintf(stderr, "IM: activate\n");
}
static void im_deactivate(void *d, struct zwp_input_method_v2 *x) {
  fprintf(stderr, "IM: deactivate\n");
}
static void im_surrounding_text(void *d, struct zwp_input_method_v2 *x,
    const char *t, uint32_t c, uint32_t a) {}
static void im_text_change_cause(void *d, struct zwp_input_method_v2 *x, uint32_t c) {}
static void im_content_type(void *d, struct zwp_input_method_v2 *x, uint32_t h, uint32_t p) {}
static void im_done(void *d, struct zwp_input_method_v2 *x) {}
static const struct zwp_input_method_v2_listener im_listener = {
  .unavailable = im_unavailable,
  .activate = im_activate,
  .deactivate = im_deactivate,
  .surrounding_text = im_surrounding_text,
  .text_change_cause = im_text_change_cause,
  .content_type = im_content_type,
  .done = im_done,
};
static const struct zwp_input_method_keyboard_grab_v2_listener grab_listener = {
  .keymap = NULL, .key = NULL, .modifiers = NULL, .repeat_info = NULL,
};
static void seat_caps(void *d, struct wl_seat *s, uint32_t caps) {}
static const struct wl_seat_listener seat_listener = { .capabilities = seat_caps, .name = NULL };
static void reg_global(void *d, struct wl_registry *r, uint32_t name,
                       const char *iface, uint32_t ver) {
  if (!strcmp(iface, "wl_seat"))
    seat = wl_registry_bind(r, name, &wl_seat_interface, ver < 7 ? ver : 7);
  else if (!strcmp(iface, "zwp_input_method_manager_v2"))
    im_mgr = wl_registry_bind(r, name, &zwp_input_method_manager_v2_interface,
                              ver < 2 ? ver : 2);
}
static void reg_remove(void *d, struct wl_registry *r, uint32_t name) {}
static const struct wl_registry_listener reg_listener = { reg_global, reg_remove };

int main(int argc, char **argv) {
  int want_grab = (argc > 1 && !strcmp(argv[1], "grab"));
  struct wl_display *dpy = wl_display_connect(NULL);
  if (!dpy) { fprintf(stderr, "no display\n"); return 1; }
  struct wl_registry *reg = wl_display_get_registry(dpy);
  wl_registry_add_listener(reg, &reg_listener, NULL);
  wl_display_roundtrip(dpy);
  if (!im_mgr) { fprintf(stderr, "no input_method_manager_v2\n"); return 2; }
  im = zwp_input_method_manager_v2_get_input_method(im_mgr, seat);
  zwp_input_method_v2_add_listener(im, &im_listener, NULL);
  wl_display_roundtrip(dpy);
  wl_display_roundtrip(dpy);
  if (want_grab) {
    grab = zwp_input_method_v2_grab_keyboard(im);
    if (!grab) {
      fprintf(stderr, "IM: grab_keyboard returned NULL\n");
    } else {
      zwp_input_method_keyboard_grab_v2_add_listener(grab, &grab_listener, NULL);
      wl_display_roundtrip(dpy);
      fprintf(stderr, "IM: holding grab, sleeping 2s\n");
      sleep(2);
      fprintf(stderr, "IM: releasing grab (crash trigger on unpatched phoc)\n");
      zwp_input_method_keyboard_grab_v2_release(grab);
      grab = NULL;
      wl_display_roundtrip(dpy);
    }
  }
  fprintf(stderr, "IM: destroying input method\n");
  zwp_input_method_v2_destroy(im);
  wl_display_roundtrip(dpy);
  wl_display_flush(dpy);
  wl_display_disconnect(dpy);
  return 0;
}
