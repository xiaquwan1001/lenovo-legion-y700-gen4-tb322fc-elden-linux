# 取证日志 — phosh/phoc 输入法弹窗 / 键盘意图（2026-11-28）

口径：全部**只读**。源码树 = 盘上既有副本（设备版本 `phoc 0.46.0` / `phosh 0.46.0` /
`phosh-osk-stub 0.46.0` 与上游 `main`）；上游状态 = `gitlab.gnome.org` API v4 现查
（**必须 `--noproxy '*'`**，走代理会 406）。**未接触设备**，设备版本取自
`reports/artifacts/phosh-gestures-20261128/device-probe.log`（2026-11-27T22:12Z 现查）。

## 0 盘上源码树（本轮实际读的副本）

| 用途 | 路径 | 版本 / 校验 |
|---|---|---|
| phoc 设备版 | `/tmp/ph046/phoc-0.46.0` | `meson.build` 0.46.0；`subprojects/wlroots.wrap revision=0.18.2` |
| phoc 上游 | `/tmp/clean/phoc-0.59.rc1` + `main` 单文件 | `src/input-method-relay.c` md5 `a405390ab2016138ee9b77fdb6fb89ee`（0.59.rc1 == main） |
| phosh 上游 | `/tmp/phosh-mr2005` | `meson.build` 0.59.0；`src/osk-manager.c` 322 行 |
| phosh 设备版 | `/tmp/ph046/phosh-0.46.0` | `src/osk-manager.c` 322 行（与 0.59.0 行数相同） |
| stevia 上游 | `/tmp/stevia-main` | 0.59.0 |
| stevia 设备版 | `/tmp/osk-pristine/phosh-osk-stub-0.46.0` | 0.46.0 |
| 旁证 | `/tmp/sway-ti.c`、`/tmp/hypr-im.cpp` | sway master `sway/input/text_input.c`；Hyprland `InputMethodPopup.cpp` |

```sh
md5sum /tmp/phoc-main-imr.c /tmp/clean/phoc-0.59.rc1/src/input-method-relay.c
# a405390ab2016138ee9b77fdb6fb89ee  两份相同
```

## 1 phoc：popup 支持为「零」

```sh
grep -rn 'input_popup\|popup_surface\|new_popup' /tmp/clean/phoc-0.59.rc1/src/    # 0 命中
grep -n  'popup' /tmp/clean/phoc-0.59.rc1/src/input-method-relay.c
# 226:  /* TODO: pass intent, display popup size */
grep -rn 'cursor_rectangle' /tmp/clean/phoc-0.59.rc1/src/                          # 0 命中（不做 popup 定位就不用它）
grep -n  'new_popup_surface' /tmp/phoc/.../subprojects/wlroots/include/wlr/types/wlr_input_method_v2.h
# 55:      struct wl_signal new_popup_surface; // struct wlr_input_popup_surface_v2   ← wlroots 0.18.2（设备版）就有
```

`src/input-method-relay.h:26-40` 的 `PhocInputMethodRelay` 只登记
`text_input_new / input_method_new / input_method_commit / input_method_grab_keyboard /
input_method_destroy / input_method_keyboard_grab_destroy` —— 无 popup 监听器。

## 2 phoc：OSK 提层只对 layer surface 生效

```
/tmp/clean/phoc-0.59.rc1/src/input-method-relay.c:42-54   elevate_osk()
  49: layer = wlr_layer_surface_v1_try_from_wlr_surface (surface);
  50: if (!layer) return;                                   ← 普通 toplevel 直接 no-op
/tmp/clean/phoc-0.59.rc1/src/layer-shell.c:458-501        phoc_layer_shell_update_osk()
 479: if (!seat->focused_layer) continue;                   ← 焦点在 view 上时永不提层
 485: if (seat->focused_layer->pending.layer >= osk->… && im enabled) force_overlay = TRUE;
/tmp/clean/phoc-0.59.rc1/src/render.c:698-722             BOTTOM → views → unmanaged → TOP → drag icons → OVERLAY
/tmp/clean/phoc-0.59.rc1/src/layer-shell.c:244-250        find_osk(): namespace 必须字面 "osk"
```

## 3 stevia：`intent`（hint/purpose）链路消费点

```
/tmp/stevia-main/src/pos-input-method.c:165-181   handle_content_type() → pending->hint / ->purpose
/tmp/stevia-main/src/pos-input-surface.c:1422-1465 select_layout_by_im_purpose()（number/phone/pin/date…→布局）
/tmp/stevia-main/src/pos-input-surface.c:1526-1540 on_im_hint_changed()（COMPLETION 位→候选条开关）
/tmp/stevia-main/src/pos-app.c:280-285             layer=TOP, kbd-interactivity=FALSE, namespace="osk"
/tmp/stevia-main/src/pos-input-surface.c:1099-1106 exclusive_zone = height / 0（显隐即避让）
```

设备版同形：`/tmp/osk-pristine/phosh-osk-stub-0.46.0/src/phosh-osk-stub.c:325,328`（layer TOP / namespace "osk"）。

## 4 phosh：shell 不参与

```sh
grep -rn 'text_input\|input_method\|popup_surface' /tmp/phosh-mr2005/src/*.c   # 0 命中
grep -n 'no way to ensure\|osk shows/hides itself' /tmp/ph046/phosh-0.46.0/src/osk-manager.c
# 28:  * there's no way to ensure keyboard state via this interface as it just
# 165:  /* Just need to sync the property, osk shows/hides itself */
```

## 5 上游 API 现查（2026-11-27T22:xxZ–22:3xZ）

```sh
curl -sS --noproxy '*' "https://gitlab.gnome.org/api/v4/projects/16763/issues/77"
curl -sS --noproxy '*' "https://gitlab.gnome.org/api/v4/projects/19269/merge_requests?per_page=100&state=opened"
curl -sS --noproxy '*' "https://gitlab.gnome.org/api/v4/groups/61154/merge_requests?search=popup&per_page=20&state=all"
# 注意：单 MR 端点 /merge_requests/<iid> 该时段返回 406（Fastly），列表端点 200 ⇒ 用列表取正文
```

结果见同目录 `upstream-scan.tsv`。

## 6 未做（本轮边界）

设备侧任何命令、MR 创建/推送、任何发信、`TASKS|INDEX|README|PITFALLS|DEVICE|RESOURCES|AGENTS` 改动。
