/* SPDX-License-Identifier: GPL-3.0-or-later
 *
 * pos-completer-rime.h — RIME 候选后端（B 方案）的公开构造器
 */
#pragma once

#include <glib-object.h>

#include "pos-completer.h"

G_BEGIN_DECLS

#define POS_TYPE_COMPLETER_RIME (pos_completer_rime_get_type ())
G_DECLARE_FINAL_TYPE (PosCompleterRime, pos_completer_rime, POS, COMPLETER_RIME, GObject)

PosCompleter *pos_completer_rime_new (GError **err);

G_END_DECLS
