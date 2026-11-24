/* SPDX-License-Identifier: GPL-3.0-or-later
 *
 * pos-completer-rime.c — phosh-osk-stub 的 RIME 候选后端（B 方案：直连 librime）
 *
 * 与 A 方案（pipe + 常驻守护）相比，B 方案多出三件 A 结构上做不到的事：
 *   ① 空格 = 选第一个候选（A 的 pipe 协议里空格必然把**原始拼音**提交上屏，
 *      因为 pos-completer-pipe.c:341 走的是 pos_completer_add_preedit() 的
 *      "分隔符 ⇒ 原样 commit" 分支，候选引擎没有插话的机会）；
 *   ② 数字 1..9 = 选第 N 个候选（A 里数字只会被拼进 preedit）；
 *   ③ 退格交给 RIME 原生语义（退一个音节/一个候选而非一个字母）。
 * 代价：必须重编 phosh-osk-stub（layout 与 completer 都编进 gresource/二进制），
 * 且每次上游升级都要重打补丁（PITFALLS #654 的 divert+hold 纪律）。
 *
 * 本文件是**最小可用实现**：不做 premium/预测、不改 preedit 分段显示、
 * 不写用户词典（learn），只有"打字→候选→选词上屏"这一条主链。
 *
 * 接线方式（见同目录 0003-osk-stub-rime-completer-wiring.patch（0.46.0 树 patch -p1 直投，含 B 案 .c/.h + 五文件接线））：
 *   src/completers/pos-completer-rime.{c,h}   ← 本文件
 *   src/meson.build                           ← 加进 pos_sources + rime_dep
 *   src/pos-completer-manager.c               ← init_completer() 里认 "rime"
 *   data/sm.puri.phosh.osk.gschema.xml        ← Completers.Rime.{shared-data,user-data,schema}
 *   meson_options.txt / meson.build           ← -Drime=true 才编译（默认关）
 */
#define G_LOG_DOMAIN "pos-completer-rime"

#include "pos-completer.h"
#include "pos-completer-priv.h"
#include "pos-completer-rime.h"

#include <errno.h>

#include <gio/gio.h>
#include <glib/gstdio.h>
#include <rime_api.h>

#define XK_BACKSPACE 0xff08

enum {
  PROP_0,
  PROP_NAME,
  PROP_PREEDIT,
  PROP_BEFORE_TEXT,
  PROP_AFTER_TEXT,
  PROP_COMPLETIONS,
  PROP_LAST_PROP
};
static GParamSpec *props[PROP_LAST_PROP];

struct _PosCompleterRime {
  GObject       parent;

  char         *name;
  GString      *preedit;
  GStrv         completions;

  GSettings    *settings;
  RimeApi      *api;
  RimeSessionId sid;
  gboolean      ready;
  guint         limit;
};


static void pos_completer_rime_interface_init (PosCompleterInterface *iface);
G_DEFINE_TYPE_WITH_CODE (PosCompleterRime, pos_completer_rime, G_TYPE_OBJECT,
                         G_IMPLEMENT_INTERFACE (POS_TYPE_COMPLETER,
                                                pos_completer_rime_interface_init))

/* ------------------------------------------------------------ 候选刷新 */

static void
pos_completer_rime_refresh (PosCompleterRime *self)
{
  g_auto (GStrv) completions = NULL;
  RIME_STRUCT (RimeContext, ctx);
  GStrvBuilder *builder;

  if (!self->ready || self->preedit->len == 0) {
    g_strfreev (self->completions);
    self->completions = NULL;
    g_object_notify_by_pspec (G_OBJECT (self), props[PROP_COMPLETIONS]);
    return;
  }

  if (!self->api->get_context (self->sid, &ctx))
    return;

  builder = g_strv_builder_new ();
  for (int i = 0; i < ctx.menu.num_candidates && i < (int) self->limit; i++) {
    const char *text = ctx.menu.candidates[i].text;
    if (text == NULL || *text == '\0')
      continue;
    if (g_strcmp0 (text, self->preedit->str) == 0) /* RIME 的原串候选，OSK 不需要 */
      continue;
    g_strv_builder_add (builder, text);
  }
  completions = g_strv_builder_end (builder);
  self->api->free_context (&ctx);

  g_strfreev (self->completions);
  self->completions = g_steal_pointer (&completions);
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_COMPLETIONS]);
}

/* 取第 idx 个候选文本（调用者 g_free），没有则 NULL */
static char *
pos_completer_rime_candidate (PosCompleterRime *self, guint idx)
{
  if (self->completions == NULL)
    return NULL;
  return g_strdup (g_strv_length (self->completions) > idx ? self->completions[idx] : NULL);
}

static void
pos_completer_rime_reset (PosCompleterRime *self)
{
  if (self->ready)
    self->api->clear_composition (self->sid);
  g_string_truncate (self->preedit, 0);
  g_strfreev (self->completions);
  self->completions = NULL;
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_PREEDIT]);
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_COMPLETIONS]);
}

/* 提交第 idx 个候选（idx 越界则提交原始 preedit，保持"不丢键"） */
static gboolean
pos_completer_rime_commit (PosCompleterRime *self, guint idx)
{
  g_autofree char *text = pos_completer_rime_candidate (self, idx);

  if (text == NULL)
    text = g_strdup (self->preedit->str);
  if (text == NULL || *text == '\0')
    return FALSE;

  g_debug ("commit candidate %u: '%s' (preedit '%s')", idx, text, self->preedit->str);
  pos_completer_rime_reset (self);
  g_signal_emit_by_name (self, "commit-string", text);
  return TRUE;
}

/* ------------------------------------------------------------------ iface */

static const char *
pos_completer_rime_get_name (PosCompleter *iface)
{
  PosCompleterRime *self = POS_COMPLETER_RIME (iface);

  return self->name;
}

static const char *
pos_completer_rime_get_preedit (PosCompleter *iface)
{
  PosCompleterRime *self = POS_COMPLETER_RIME (iface);

  return self->preedit->str;
}

static void
pos_completer_rime_set_preedit (PosCompleter *iface, const char *preedit)
{
  PosCompleterRime *self = POS_COMPLETER_RIME (iface);

  if (g_strcmp0 (self->preedit->str, preedit ?: "") == 0)
    return;

  if (preedit == NULL || *preedit == '\0') {
    pos_completer_rime_reset (self);
    return;
  }

  g_string_truncate (self->preedit, 0);
  g_string_append (self->preedit, preedit);
  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_PREEDIT]);
}

/*
 * 每键：先让 RIME 处理这个符号，再从 RIME 的菜单取候选。
 * 返回 TRUE = 这个键已被候选引擎消费（OSK 不再把它当虚拟键盘/文本发出去）。
 */
static gboolean
pos_completer_rime_feed_symbol (PosCompleter *iface, const char *symbol)
{
  PosCompleterRime *self = POS_COMPLETER_RIME (iface);
  gboolean active = self->preedit->len > 0;
  gboolean is_sep = pos_completer_symbol_is_word_separator (symbol, NULL);

  g_return_val_if_fail (symbol != NULL, FALSE);

  if (g_strcmp0 (symbol, "KEY_BACKSPACE") == 0) {
    if (!active)
      return FALSE; /* 没有组字：交给 OSK 删正常文本 */
    self->api->process_key (self->sid, XK_BACKSPACE, 0);
    if (g_utf8_strlen (self->preedit->str, -1) <= 1) {
      pos_completer_rime_reset (self);
      return TRUE;
    }
    {   /* 退掉一个 UTF-8 字符（拼音场景下就是退一个字母） */
      const char *end = self->preedit->str + self->preedit->len;
      const char *prev = g_utf8_find_prev_char (self->preedit->str, end);
      g_string_truncate (self->preedit, prev - self->preedit->str);
    }
    g_object_notify_by_pspec (G_OBJECT (self), props[PROP_PREEDIT]);
    pos_completer_rime_refresh (self);
    return TRUE;
  }

  /* 其它 KEY_*（方向键/回车/ESC…）不是文本，交回 OSK */
  if (g_str_has_prefix (symbol, "KEY_"))
    return FALSE;

  /* 数字选词：只在组字中且该位有候选时生效 */
  if (active && symbol[0] >= '1' && symbol[0] <= '9' && symbol[1] == '\0' &&
      self->api->get_option (self->sid, "ascii_mode") == False) {
    guint idx = (guint) (symbol[0] - '1');
    if (pos_completer_rime_candidate (self, idx) != NULL)
      return pos_completer_rime_commit (self, idx);
    /* 没有这么多候选 ⇒ 当成普通数字，落到下面 */
  }

  /* 分隔符（空格/标点）：有组字就先上屏首选，再让 RIME 出标点 */
  if (active && is_sep) {
    g_autofree char *first = pos_completer_rime_candidate (self, 0);

    if (first != NULL && symbol[0] != ' ') {
      g_autofree char *both = g_strconcat (first, symbol, NULL);
      pos_completer_rime_reset (self);
      g_signal_emit_by_name (self, "commit-string", both); /* 候选 + 标点，一次提交 */
      return TRUE;
    }
    pos_completer_rime_commit (self, 0);
    if (symbol[0] == ' ')
      return TRUE; /* 空格纯选词，不额外上屏空格 */
    /* 标点：继续往下走，让它作为普通符号提交 */
    pos_completer_rime_set_preedit (POS_COMPLETER (self), NULL);
  }

  /* 普通字符：喂给 RIME，并把 OSK 的 preedit 同步成"刚敲的原始串" */
  {
    gboolean should_commit;

    should_commit = pos_completer_add_preedit (POS_COMPLETER (self), self->preedit, symbol);
    if (should_commit) { /* 极端路径（分隔符但 RIME 无候选）：原样提交 */
      g_autofree char *raw = g_strdup (self->preedit->str);
      pos_completer_rime_reset (self);
      g_signal_emit_by_name (self, "commit-string", raw);
      return TRUE;
    }
    g_object_notify_by_pspec (G_OBJECT (self), props[PROP_PREEDIT]);

    /* 把这个键喂给 RIME（不重放整串） */
    self->api->process_key (self->sid, (unsigned char) symbol[0], 0);
    pos_completer_rime_refresh (self);
    return TRUE;
  }
}

static void
pos_completer_rime_interface_init (PosCompleterInterface *iface)
{
  iface->get_name = pos_completer_rime_get_name;
  iface->feed_symbol = pos_completer_rime_feed_symbol;
  iface->get_preedit = pos_completer_rime_get_preedit;
  iface->set_preedit = pos_completer_rime_set_preedit;
}

/* ---------------------------------------------------------------- GObject */

static void
pos_completer_rime_set_property (GObject *object, guint prop_id,
                                 const GValue *value, GParamSpec *pspec)
{
  PosCompleterRime *self = POS_COMPLETER_RIME (object);

  switch (prop_id) {
  case PROP_PREEDIT:
    pos_completer_rime_set_preedit (POS_COMPLETER (self), g_value_get_string (value));
    break;
  default:
    G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
  }
}

static void
pos_completer_rime_get_property (GObject *object, guint prop_id,
                                 GValue *value, GParamSpec *pspec)
{
  PosCompleterRime *self = POS_COMPLETER_RIME (object);

  switch (prop_id) {
  case PROP_NAME:        g_value_set_string (value, self->name); break;
  case PROP_PREEDIT:     g_value_set_string (value, self->preedit->str); break;
  case PROP_BEFORE_TEXT: g_value_set_string (value, ""); break;
  case PROP_AFTER_TEXT:  g_value_set_string (value, ""); break;
  case PROP_COMPLETIONS: g_value_set_boxed (value, self->completions); break;
  default:
    G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
  }
}

static void
pos_completer_rime_finalize (GObject *object)
{
  PosCompleterRime *self = POS_COMPLETER_RIME (object);

  if (self->ready) {
    self->api->destroy_session (self->sid);
    self->api->finalize ();
    self->ready = FALSE;
  }
  g_clear_object (&self->settings);
  g_clear_pointer (&self->completions, g_strfreev);
  g_string_free (self->preedit, TRUE);

  G_OBJECT_CLASS (pos_completer_rime_parent_class)->finalize (object);
}

static void
pos_completer_rime_class_init (PosCompleterRimeClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->get_property = pos_completer_rime_get_property;
  object_class->set_property = pos_completer_rime_set_property;
  object_class->finalize = pos_completer_rime_finalize;

  g_object_class_override_property (object_class, PROP_NAME, "name");
  props[PROP_NAME] = g_object_class_find_property (object_class, "name");
  g_object_class_override_property (object_class, PROP_PREEDIT, "preedit");
  props[PROP_PREEDIT] = g_object_class_find_property (object_class, "preedit");
  g_object_class_override_property (object_class, PROP_BEFORE_TEXT, "before-text");
  props[PROP_BEFORE_TEXT] = g_object_class_find_property (object_class, "before-text");
  g_object_class_override_property (object_class, PROP_AFTER_TEXT, "after-text");
  props[PROP_AFTER_TEXT] = g_object_class_find_property (object_class, "after-text");
  g_object_class_override_property (object_class, PROP_COMPLETIONS, "completions");
  props[PROP_COMPLETIONS] = g_object_class_find_property (object_class, "completions");
}

static void
pos_completer_rime_init (PosCompleterRime *self)
{
  g_autofree char *shared = NULL;
  g_autofree char *user = NULL;
  g_autofree char *schema = NULL;
  RIME_STRUCT (RimeTraits, traits);

  self->preedit = g_string_new (NULL);
  self->name = "rime";
  self->limit = 9;
  self->settings = g_settings_new ("sm.puri.phosh.osk.Completers.Rime");

  self->api = rime_get_api ();
  if (self->api == NULL)
    return;

  shared = g_settings_get_string (self->settings, "shared-data");
  user = g_settings_get_string (self->settings, "user-data");
  schema = g_settings_get_string (self->settings, "schema");

  /* Empty user-data means "use the XDG default" rather than "no user data":
   * librime takes a non-NULL empty string as a real (empty) path and its
   * deployment then fails with "Error creating user data dir:" on every
   * start, silently losing the user dictionary. A failure to create the
   * directory is non-fatal: we only lose persistence, not the keyboard.
   */
  if (*user == '\0') {
    g_free (user);
    user = g_build_filename (g_get_user_data_dir (), "rime", NULL);
    if (g_mkdir_with_parents (user, 0700) < 0)
      g_warning ("Rime: can't create user data dir '%s': %s; "
                 "the user dictionary won't persist",
                 user, g_strerror (errno));
  }

  RIME_STRUCT_INIT (RimeTraits, traits);
  traits.shared_data_dir = shared;
  traits.user_data_dir = user;
  traits.distribution_name = "Phosh OSK";
  traits.distribution_code_name = "phosh-osk-stub";
  traits.distribution_version = "0.46";
  traits.app_name = "rime.phosh-osk";
  traits.min_log_level = 2;
  traits.log_dir = "";

  self->api->setup (&traits);
  self->api->initialize (&traits);
  if (self->api->start_maintenance (True))
    self->api->join_maintenance_thread ();

  self->sid = self->api->create_session ();
  if (self->sid == 0) {
    g_warning ("Rime: create_session failed");
    self->api->finalize ();
    return;
  }
  if (schema && *schema && !self->api->select_schema (self->sid, schema))
    g_warning ("Rime: schema '%s' not available", schema);
  self->api->set_option (self->sid, "simplification", True);
  self->ready = TRUE;
}

/* ------------------------------------------------------------------- ctor */

PosCompleter *
pos_completer_rime_new (GError **err)
{
  PosCompleterRime *self = g_object_new (POS_TYPE_COMPLETER_RIME, NULL);

  if (self->ready == FALSE) {
    g_set_error (err, POS_COMPLETER_ERROR, POS_COMPLETER_ERROR_ENGINE_INIT,
                 "RIME engine failed to init");
    g_object_unref (self);
    return NULL;
  }
  return POS_COMPLETER (self);
}
