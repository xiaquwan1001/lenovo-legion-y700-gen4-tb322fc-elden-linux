/* SPDX-License-Identifier: GPL-3.0-or-later
 *
 * rime-completer-probe.c — 复刻 phosh-osk-stub 的 Rime completer 初始化顺序，
 * 判定 `Completers.Rime.user-data` 的取值对 librime 的影响（不触摸、不用 OSK）。
 *
 * 对应设备件：patches-userland/zh-ime-rime-20261123/rime/pos-completer-rime.c:349-397
 * （g_settings_new → traits.{shared,user}_data_dir → setup/initialize →
 *   start_maintenance(True) → create_session → select_schema → process_key）
 *
 * 用法：rime-probe [USER_DATA_DIR] [KEYS] [SCHEMA]
 *   USER_DATA_DIR  空串 = 复现当前缺陷配置；绝对路径 = 复现修复配置
 *   KEYS           默认 "nihao"
 *   SCHEMA         默认 "luna_pinyin"
 * 退出码：0 = 有候选；1 = schema 选择失败；2 = create_session 失败；3 = 无候选
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <rime_api.h>

int
main (int argc, char **argv)
{
  const char *user_dir = argc > 1 ? argv[1] : "";
  const char *keys = argc > 2 ? argv[2] : "nihao";
  const char *schema = argc > 3 ? argv[3] : "luna_pinyin";
  RIME_STRUCT (RimeTraits, traits);
  RimeApi *api = rime_get_api ();
  RimeSessionId sid;
  Bool started, selected;
  int ncand = 0;

  if (api == NULL) {
    fprintf (stderr, "rime_get_api() == NULL\n");
    return 4;
  }

  RIME_STRUCT_INIT (RimeTraits, traits);
  traits.shared_data_dir = "/usr/share/rime-data";
  traits.user_data_dir = user_dir;          /* 与 completer 逐字一致：空串照样传 */
  traits.distribution_name = "Phosh OSK";
  traits.distribution_code_name = "phosh-osk-stub";
  traits.distribution_version = "0.46";
  traits.app_name = "rime.phosh-osk";
  traits.min_log_level = 2;
  traits.log_dir = "";

  api->setup (&traits);
  api->initialize (&traits);

  printf ("user_data_dir=[%s]\n", user_dir);
  started = api->start_maintenance (True);
  printf ("start_maintenance(True) = %d\n", started);
  if (started)
    api->join_maintenance_thread ();

  sid = api->create_session ();
  printf ("create_session = %llu\n", (unsigned long long) sid);
  if (sid == 0)
    return 2;

  selected = api->select_schema (sid, schema);
  printf ("select_schema(%s) = %d\n", schema, selected);

  for (const char *k = keys; *k; k++) {
    char sym[2] = {*k, '\0'};
    api->simulate_key_sequence (sid, sym);
  }

  {
    RIME_STRUCT (RimeContext, ctx);

    if (!api->get_context (sid, &ctx)) {
      printf ("get_context = FAILED\n");
    } else {
      ncand = ctx.menu.num_candidates;
      printf ("preedit=[%s] num_candidates=%d\n",
              ctx.composition.preedit ? ctx.composition.preedit : "", ncand);
      for (int i = 0; i < ncand && i < 9; i++)
        printf ("  cand[%d]=%s\n", i, ctx.menu.candidates[i].text);
      api->free_context (&ctx);
    }
  }

  api->destroy_session (sid);
  api->finalize ();

  if (!selected)
    return 1;
  return ncand > 0 ? 0 : 3;
}
