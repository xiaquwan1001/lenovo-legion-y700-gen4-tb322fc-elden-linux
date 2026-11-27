# phosh/phoc「输入法弹窗 / 键盘意图」上游化调研 — 2026-11-28

> **lane 类型**：只读调研。**未接触设备**（零 adb/ssh/qdl）、**未发信**、**未 push**、未改
> `TASKS|INDEX|README|PITFALLS|DEVICE|RESOURCES|AGENTS`。本文件与
> `reports/artifacts/phosh-ime-20261128/`（新建）是本轮唯二写入。
> **不重推先例**：`reports/ime-phosh-fcitx5-invest-20261110.md`（下称 **I1**，协议面/槽位/三条弹出路径）、
> `reports/phosh-mr-2005-rework-20261124.md`（**I2**，我们的 MR 流程与 guidog 口径）、
> `reports/mobian-phosh-upstream-20261125.md`（**I3**，版本线/API 取数口径）、
> `reports/ime-osk-zh-matrix-20261122.md`（**Z**，0.46 vs 0.58 源码差异、classicui 无窗、elevate 对 toplevel 是 no-op）。
> **本轮新增** = 「input popup（`zwp_input_popup_surface_v2`）」与「keyboard intent（hint/purpose）」两条链的
> **端点级源码取证** + **上游 2019 年至今的账单** + **一份可投递的 MR 草稿**。

---

## 0. 一页结论 & 一行账

**三句话**

1. **弹窗（popup）这一面，phoc 是真空的**：`zwp_input_method_v2.new_popup_surface` 从未被监听
   （设备版 `phoc 0.46.0` 与上游 `main`/`0.59.0` 同），`text_input_rectangle` 从未被发送，
   渲染路径里没有 popup 项 ⇒ **任何走协议的候选窗都画不出来**；上游 issue **#77 开了 7 年、0 条评论**，
   期间 phoc 侧**零 MR**（`World/Phosh` 组内 `search=popup` 全历史无 input-popup 件）。
2. **键意（intent）这一面，链是通的、但没有人把它用满**：`text-input-v3.content_hint/purpose → phoc
   relay_send_im_done() → zwp_input_method_v2.content_type → stevia` 每一段都有代码
   （`input-method-relay.c:221-223` → `pos-input-method.c:165-181` → `pos-input-surface.c:1422-1465`），
   但 phoc 自己留着一行 `/* TODO: pass intent, display popup size */`，而 stevia 侧仍有三个未实现的 hint
   （`inhibit-osk` / `no-emoji` / `sensitive-data`，**stevia #117 仍 open**）。⇒ 这一面**不是上游缺能力**，
   是**上游缺实现**，且已有人排队做。
3. **对我们的产品问题，这两条都不是当务之急**：本栈「候选窗画不出」的已定因是 **fcitx5 classicui 只认
   `zwp_input_panel_v1`**（Z §0-C3），而 OSK 侧的正解正在上游发生 —— **stevia !343「Add Fcitx5 support」**
   （2026-11-27 新开，GClient/DBus 后端，把 fcitx5 的候选搬进 OSK 自己的 surface）。⇒ 我们的
   **拟投递件优先级**：**P2 = phoc input-popup（协议完整性，写好了再投）**，P0 = 观望 !343 + 先落我们自己的
   kimpanel 桥（零上游改动）。

### 一行账

| 项 | 现状 | 缺口 | 上游已否 | 拟投递件 |
|---|---|---|---|---|
| **A. input popup（`zwp_input_popup_surface_v2`）** | phoc 不监听、不定位、不发送 `text_input_rectangle`、不渲染（`input-method-relay.c:226` 只有一行 TODO；`src/` 内 `popup`/`cursor_rectangle` 零命中）；wlroots 0.18.2（设备版）与 0.20（上游）都已提供对象 | **是真缺口**：任何走协议的候选窗/预测窗都无处显示；层叠不参与 OSK 提层 | ❌ **无**：phoc **#77**（2019-09-20 至今 open，**0 notes**）；近 60 天 phoc 16 条 MR 无一涉及；组内全历史无相关 MR | ✅ **P2**：`mr-draft.md`（标题 + 正文 + 复现 + 期望 + AI 披露），**未发送**；前置 = 先写代码 + 加 test |
| **B. keyboard intent（hint / purpose）** | 链通：phoc 转发 `content_type`（`:221-223`），stevia 消费 purpose→布局（`pos-input-surface.c:1422-1465`）、hint→候选条（`:1526-1540`） | 上游自认的缺口在 **OSK 侧**（`inhibit-osk`/`no-emoji`/`sensitive-data` 未处理）与 phoc 的 `TODO: pass intent`；**不是协议缺** | ⚠️ **部分**：stevia **#117** open（2026-10-04）；**!329**「hints 变位域 + sensitivity」**已 merged 2026-11-26** | ❌ 不投（别人正在做；我们插进去只会变成重复劳动） |
| **C. OSK 提层 / 层叠（#302）** | `elevate_osk()` 只在焦点表面**本身是 layer surface** 时动作（`input-method-relay.c:49-51`）；`update_osk()` 见 `seat->focused_layer == NULL` 就跳过（`layer-shell.c:479`）；渲染序 BOTTOM→views→TOP→OVERLAY（`render.c:698-722`） | 焦点在**普通应用窗口**时，OSK 停在它声明的层（stevia=TOP），**不会被提到 overlay** | ❌ 无（**#302** 2022-10-10 至今 open、0 notes、无 workaround 之外的 MR） | ❌ 不投（与 A 同文件同函数族；先做 A，C 的修法依赖 A 的 popup 层级决策） |
| **D. IM 槽独占 + OSK 无候选**（本栈主症状） | fcitx5 waylandim 与 stevia 争同一 `zwp_input_method_v2`；fcitx5 不画键盘、classicui 在本栈建不出窗（Z §0-C3） | 产品缺口，**协议不缺** | ⚠️ **正在被上游解决**：stevia **!343 Add Fcitx5 support**（opened 2026-11-27，GClient 后端，作者自测 FuriOS 拼音候选） | ❌ 不投（不抢别人的 MR）；先按 I1 §7.3-A1 落 `elden-ime-focusd` + kimpanel |
| **E. IM 键盘 grab 的语义边界** | phoc 实现 `grab_keyboard`（!419，2023）；我们补的 NULL 解引用修复**已 merged**（**!820**，2026-10-31） | stevia 侧**根本不处理** `zwp_input_method_keyboard_grab_v2`（**#120** open）⇒ 混合键鼠场景无解 | ⚠️ 部分（stevia #120 open；phoc 侧已完成） | ❌ 不投 |

---

## 1. 现状：实现路径（file:line）

> 双列理由：**设备现役 = `phoc 0.46.0-1` / `phosh 0.46.0-3+deb13u1` / `phosh-osk-stub 0.46.0-1` /
> `libwlroots-0.18 0.18.2-3`**（`reports/artifacts/phosh-gestures-20261128/device-probe.log`，2026-11-27T22:12Z
> `dpkg -l` 逐字）；而上游 = `phoc 0.59.0` / `main`。两代在**本轮关心的四件事上结论相同**，
> 差异只有 ①版本门 ②`show_input_panel` 监听（0.58+ 才有，**!813**）。**I3 §4.3 里「设备跑 0.58」那句与现查不符**（同
> `phosh-gestures-assessment-20261128.md` 已记冲突），本报告一律按 **0.46** 立论。

### 1.1 phoc：三个全局都在，两代无差

| 项 | 设备 `phoc 0.46.0` | 上游 `main` / `0.59.0` |
|---|---|---|
| `zwp_input_method_manager_v2` | `src/desktop.c:613` | `src/desktop.c:686` |
| `zwp_text_input_manager_v3`（版本：0.46 = **1**，0.58+ = **2**） | `src/desktop.c:614`（无 `PHOC_TEXT_INPUT_VERSION`） | `src/desktop.c:687` + `:60 #define PHOC_TEXT_INPUT_VERSION 2` |
| `zwlr_virtual_keyboard_manager_v1` | `src/desktop.c:627` | `src/desktop.c:700` |

### 1.2 弹出（show）

| 路径 | 设备 0.46 | 上游 main |
|---|---|---|
| text-input `enable` → `activate_osk()` | `handle_text_input_enable()` `:224-243`，**无版本门**，直接 `send_activate` + `elevate_osk`（`:240-242`） | `:243-264`，带 **版本门** `if (wl_resource_get_version(...) >= ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION) return;`（`:258-261`） |
| text-input `show_input_panel` | **不监听**（0.46 无此 listener） | `handle_text_input_show_input_panel()` `:268-285`（`g_debug "Explcit request to show input panel"`） |
| 汇聚点 | `activate_osk()`（0.46 内联，`:240-242`） | `activate_osk()` `:231-239`（`send_activate :235`、`elevate_osk :238`） |

### 1.3 收回（hide）

| 路径 | 设备 0.46 | 上游 main |
|---|---|---|
| `disable` | `handle_text_input_disable()` `:314-320` → `relay_disable_text_input()` `:266-280` → `send_deactivate` + `im_done` | `:372-378` / `:308-321` |
| `hide_input_panel` | **不监听** | `handle_text_input_hide_input_panel()` `:325-332` |
| 焦点离开 | `text_input_relay_unset_focus()` `:303-310`：先 `submit_preedit()`（`:283-299`），再 `disable` + `send_leave` | `:361-368` / `:336-357` |
| IM 客户端销毁 | `handle_im_destroy` 把焦点表面存成 `pending_focused_surface` 等 IM 回来 | 同形 `:170-190` |

**注意**：`deactivate` 只是**信号**，phoc 自己**不碰 OSK 的可见性**；OSK 收 `deactivate` 后自行收键盘
（stevia `pos-input-method.c:110-123`）。⇒ 「收回」完全由 OSK 负责，phoc 无兜底（与 **I1 §7.2** 一致）。

### 1.4 焦点移交

`phoc_input_method_relay_set_focus()`（0.46 `:481-510`；main `:547-576`）按「同一 client 才 `enter`」匹配
`PhocTextInput`，三处调用点：

| 调用点 | 0.46 | main |
|---|---|---|
| 焦点清空（`phoc_seat_set_focus(NULL)`） | `seat.c:1487` | `seat.c:1344` |
| 焦点给 view（toplevel） | `seat.c:1527` | `seat.c:1462` |
| 焦点给 layer surface | `seat.c:1586` | `seat.c:1436` |
| text-input 新对象时补发 | `input-method-relay.c:406` | `:472` |

### 1.5 keyboard intent（hint / purpose）

```
text-input-v3 client: set_content_type(hint, purpose) + commit
  → wlroots wlr_text_input_v3 current.content_type
  → phoc relay_send_im_done():  if (active_features & CONTENT_TYPE) wlr_input_method_v2_send_content_type(hint, purpose)
       0.46 : src/input-method-relay.c:214
       main : src/input-method-relay.c:221-223
  → stevia handle_content_type()  src/pos-input-method.c:165-181  → pending->hint / ->purpose
  → pos-input-surface.c:1422-1465 select_layout_by_im_purpose()   （number/phone/pin/date/email/url…→布局）
  → pos-input-surface.c:1526-1540 on_im_hint_changed()            （HINT_COMPLETION → 候选条开/关）
```

phoc 同一函数里留着一行 **`/* TODO: pass intent, display popup size */`（0.46 `:219`，main `:226`）** ——
这句话两半分别对应本报告的 A/B 两个子题：`display popup size` = A 的缺口；`pass intent` 指仍未转发的那部分
（`set_input_region` / 未来 text-input 3.2 的语义，见 phoc **#430**）。**同一行注释在 sway
`sway/input/text_input.c:241` 逐字存在** ⇒ phoc 的 relay 是从 sway 抄来的，**抄的时候把 popup 那半砍掉了**
（sway 有 `:126-204` + `:506-592`，phoc 没有）。

### 1.6 input popup（`zwp_input_popup_surface_v2`）— **零实现**

| 事实 | 证据 |
|---|---|
| phoc `src/` 内 `input_popup` / `popup_surface` / `new_popup` **零命中** | `grep -rn`（两代都跑过，见 `evidence.md` §1） |
| phoc `src/` 内 `cursor_rectangle` **零命中** | 同上 ⇒ 连「popup 该放哪」的输入都没取 |
| `PhocInputMethodRelay` 结构体无 popup 监听器 | `src/input-method-relay.h:26-40`（只列 6 个 listener） |
| wlroots **已经给了对象** | 设备版 `subprojects/wlroots` = 0.18.2：`include/wlr/types/wlr_input_method_v2.h:55 new_popup_surface`；上游 0.20.x 同 + `types/wlr_input_method_v2.c:153-158 wlr_input_popup_surface_v2_send_text_input_rectangle()` |
| 协议要求「合成器负责摆」 | `protocols/input-method-unstable-v2.xml`「The compositor **should place it near the active text input area**. It must be visible iff the IM is active.」 |
| 别的 wlroots 合成器做了 | sway `sway/input/text_input.c:126-204`（`constrain_popup()` 用 `text_input->input->current.cursor_rectangle:160`，`:197` 发 rectangle）、`:506-592`（监听）；Hyprland `src/managers/input/InputMethodPopup.cpp`（178 行，含 damage/position） |

### 1.7 layer-shell 面（OSK 的面本身是好的）

| 项 | 值 |
|---|---|
| OSK 声明 | stevia `pos-app.c:280-285`：`layer=TOP`、`anchor=bottom|left|right`、`kbd-interactivity=FALSE`、`namespace="osk"`、`exclusive-zone=height`；设备版 0.46 同形（`phosh-osk-stub.c:325,328`） |
| phoc 认领 OSK | `layer-shell.c:244-250` `phoc_layer_shell_find_osk()`：**namespace 必须字面 `"osk"`** |
| 避让（panel 高度） | stevia 自己改 `exclusive_zone`：`pos-input-surface.c:1103`（显示=height）/`:1106`（隐藏=0）→ phoc 的 `arrange_layer()` 重排 usable area |
| 提层 | `phoc_layer_shell_update_osk()` `layer-shell.c:458-501`：**只有 `seat->focused_layer != NULL` 才可能 `force_overlay`**；`elevate_osk()`（`input-method-relay.c:42-54`）只在「要键盘的那个表面本身是 layer surface」时调用它 ⇒ **普通应用窗口聚焦时没有任何提层路径**（= **#302** 的代码级根因） |
| 渲染序 | `render.c:698-722`（0.46 `:495-514`）：BOTTOM → **views** → unmanaged → **TOP** → drag icons → OVERLAY ⇒ OSK 在 TOP，普通窗口在其下；若某天把 OSK 放到 BOTTOM 就会被窗口盖住 |

### 1.8 phosh：shell 不参与（两代同形）

- `src/osk-manager.c` **0.46 与 0.59 都是 322 行**，行为一致：只代理 `sm.puri.OSK0` 的
  `Visible`/`SetVisible`（`set_visible_real() :100-110`、`phosh_osk_manager_set_visible() :314-321`）、跟随
  `screen-keyboard-enabled`（`:136-152`）、锁屏强制隐藏（`:178-180`）。
- 注释原文（0.46 `:28`、0.59 同）：*“there's no way to ensure keyboard state via this interface as it just
  uses DBus to express preference”*；`:165` *“Just need to sync the property, osk shows/hides itself”*。
- `grep -rn 'text_input|input_method|popup_surface' phosh/src/*.c` = **0 命中**（main 全树）。

---

## 2. 缺口判定（现象 → 代码 → 归因层级）

| # | 我方实测现象 | 代码位置 | 归因层级 | 判定 |
|---|---|---|---|---|
| **G1** | 「键盘能弹、中文能上屏，**但无候选窗**」——fcitx5 候选窗在本栈画不出来；**2026-11-11 用户目视确认**：把 UI 后端从 classicui 换到 kimpanel（owner = 我们自己的 `elden-ime-focusd`）后候选词恢复可见（`TASKS/sessions/2026-11-11-IME候选窗四层根因.md` §1/§4；`dbus-monitor` 抓到 `SetLookupTable ["你","那","呢","能","年"]`） | fcitx5 `src/ui/classic/` 的 Wayland UI 只认 `zwp_input_panel_v1`（Z §0-C3）；phoc `protocols/` **无**该 XML | **下游配置**（换 UI 后端即解）＋ **协议**（phoc 不提供 panel-v1，但那是已废弃协议，不该补） | **不是 A 的直接因果**：即使 phoc 实现了 input-popup，fcitx5 waylandim **也不消费**（`src/frontend/waylandim/*` `popup` 零命中，库里的 `zwp_input_popup_surface_v2.*` 是未使用绑定）。**别把 G1 记到 #77 头上** |
| **G2** | 任何「走 IM 协议的候选窗」在本栈**必然不可见**（本轮未上机复现，属源码级必然性） | phoc `src/` 无 popup 处理（§1.6） | **phoc**（合成器职责） | **真缺口 A**：上游 #77 未做。对我们是**能力储备**，不是当日 blocker |
| **G3** | 锁屏/系统弹层上 OSK 被压住（上游 #302 原样现象：`pkexec echo test` 前 OSK 不置顶）；本栈未专门复现 | `elevate_osk` 对 toplevel no-op（`input-method-relay.c:49-51`）＋ `update_osk` 跳过 `focused_layer==NULL`（`layer-shell.c:479`） | **phoc** | **真缺口 C**：上游 4 年未动；修法与 A 同函数族，**建议等 A 落地时一起提交**（否则两次 rebase） |
| **G4** | 「点输入框 OSK 不弹」 | 本轮不重推：已定因 = 无 `zwp_text_input_v3` 客户端（`GTK_IM_MODULE=fcitx` 遮蔽），见 **I1 §7.2** + Z §0-C1 | **下游配置 + shell 策略** | **不是协议缺**（I1 已裁）；不在本报告范围 |
| **G5** | 锁屏上键盘被手动收起后**再也唤不回来**（点同一个已聚焦输入框无效） | stevia `handle_activate()` 开头 `if (self->pending->active == TRUE) return;`（`pos-input-method.c:89-96`，判据行 `:96`）⇒ 重复 activate 被吞 | **OSK（stevia）** | ⚠️ 上游**已在修**：**!334**（Henry-Hiles，2026-11-25，opened）。我们不投 |
| **G6** | 数字/电话/密码框不切布局（假如某客户端只发 hint 不发 purpose 之外的信号） | 链通（§1.5）；但 `inhibit-osk` / `no-emoji` / `sensitive-data` 三 hint **未实现** | **OSK（stevia）** | ⚠️ 上游 **#117** open（2026-10-04）；**!329** 已 merged 铺好位域。我们不投 |
| **G7** | 混合键鼠 + OSK 同时用（内屏键盘与外接键盘共存）行为未定义 | stevia **不实现** `grab_keyboard`（stevia #120 open）；phoc 侧已实现（!419）并已修 NULL 解引用（!820） | **OSK（stevia）** | ⚠️ 上游 #120 open。我们不投 |
| **G8** | （相邻，**不同栈**）Android 侧 IME `showSoftInput` 永不完成、无键盘 —— `droidloom` 内置 placeholder IME | 不在 phosh/phoc：`reports/artifacts/droidloom-ime-issue-20261127/body.md` | **Android 容器（droidloom）+ 宿主 text-input 能力协商** | 与 #77 **无关**，不要合并叙事；该 issue 另线处理 |

**归因小结**：本栈可投递的上游缺能力**只有两条**（G2/A、G3/C），都在 **phoc** 同一个
`input-method-relay.c` + 渲染路径上；其余不是「上游缺」而是「下游配置」（G1/G4）或「别人正在做」（G5/G6/G7）。

---

## 3. 上游已否（近 60 天窗口 = 2026-09-28 → 2026-11-27，现查 2026-11-27T22:xxZ）

口径：`gitlab.gnome.org` API v4，**`--noproxy '*'`**；项目 id：phoc `16763`、phosh `16747`、stevia `19269`、
squeekboard `16777`、组 `World/Phosh` = `61154`。原始行见 `artifacts/phosh-ime-20261128/upstream-scan.tsv`。

### 3.1 与缺口对应的条目

| 上游件 | 状态 | 时间 | 与我们的缺口 | 结论 |
|---|---|---|---|---|
| **phoc #77** “Support input-popup” <https://gitlab.gnome.org/World/Phosh/phoc/-/issues/77> | **opened**（**0 notes，自 2019-09-20 创建后从未更新**） | 2019-09-20 | **= G2/A 全部**。原文：「This would be useful for displaying **CJK alternatives**, or for some prediction scheme」（指向 input-method-v2 XML 的 popup 段） | **明确未做**；我们的 MR 就是关它 |
| **phoc #302** “If IME is installed … OSK will not be elevated to top surface” <…/issues/302> | opened（0 notes） | 2022-10-10 | **= G3/C** | 未做；建议与 A 合并提交 |
| **phoc #153** “input-method-v2 not setting cursor correctly” <…/issues/153> | opened（1 note） | 2020-09-15 → 2025-12-17 | A 的**下游并发症**（没有 cursor rect 就没有 popup 定位；virtual-keyboard 注入后偏移不更新） | 未做；我们实现 A 时会碰到，需在 MR 里说明取的是 `text_input->input->current.cursor_rectangle` |
| **phoc #430** “text-input protocol 3.2 support” <…/issues/430> | opened（0 notes） | 2026-04-01 | B 的**上位**（`show/hide_input_panel` 语义 + `set_input_region`）；phoc 0.58+ 已监听 show/hide（!813 之后） | 部分完成（tracking issue 仍开） |
| **phoc #113** “Sends set_surrounding_text even when text input doesn't support it” <…/issues/113> | opened（1 note） | 2020-02-12 | 协议卫生，非本主题 | 不投 |
| **stevia !343** “Add Fcitx5 support” <…/stevia/-/merge_requests/343> | **opened** | 2026-11-27（作者 `matrixkernel`） | **= G1/D 的上游正解**：可选 Fcitx5 后端（`-Dfcitx5=enabled`，走 `Fcitx5GClient`），**候选与 preedit 在 OSK 自己的 surface 内**，选中经 fcitx5 提交；fcitx5 不在时回落直发按键。作者自测 FuriOS 上 Firefox/文管拼音候选 | **正在做**。⇒ 我们的 D 路线应先观望它，而不是再起一条 |
| **stevia !334** “Notify when activated again while active” <…/merge_requests/334> | opened | 2026-11-25 | **= G5** | 正在做 |
| **stevia #117** “Handle more hints” <…/issues/117> | opened（0 notes） | 2026-10-04 | **= G6/B 的 OSK 侧**（`inhibit-osk`/`no-emoji`/`sensitive-data`） | 已登记未做 |
| **stevia !329** “input-method: Make hints a bitfield and add sensitivity property” <…/merge_requests/329> | **merged** | 2026-11-26 | B 的基础设施（为 #117 铺路） | 已完成 |
| **stevia #120** “Handle zwp_input_method_keyboard_grab_v2” <…/issues/120> | opened（0 notes） | 2026-10-26 | **= G7** | 已登记未做 |
| **phoc !820**（我们的） “Fix NULL deref in keyboard grab destroy handler” | **merged** | 2026-10-31 | 已收口（I1 §5 那条） | 无需再动 |
| **phoc !813** “text-input: Add basic text-input-v3 version 2 support” | merged | 2026-09-19 | 版本门来源 | 已完成 |
| **phoc !488** “text-input: Elevate OSK when text input gets enabled” | merged | 2023-10-04 | C 的现状来源 | 已完成（且是 C 的不完整之处） |

### 3.2 「没有」的证据（空结果也要写清口径）

| 检索 | 结果 |
|---|---|
| 组内全历史 `search=popup`（MR，state=all） | 20 条，**全部是 xdg-popup / 字符弹窗 / 按键预览**；**无** input-popup |
| 组内全历史 `search=input popup`、`search=popup_surface` | 无 input-popup 件 |
| phoc 近 60 天 MR（16 条） | 只有 **!820（我们的）** 属 input-method 范畴；其余 = 光标隐藏/协议搬迁/层效果/发布 |
| phosh 近 60 天 MR（54 条） | **零** OSK/IM/popup 相关（全是 tray/battery/audio/overview/lockscreen） |
| phoc issue `search=popup`（全历史） | 20 条，与 IM 相关的只有 **#77**（open）与 #332（squeekboard 菜单按钮，closed 2023） |
| squeekboard 近 60 天 | 唯一活动 = **!714**（rust 1.98 构建修复，open）；项目描述仍写 **unmaintained** |

### 3.3 一个「不是上游问题」的确认

fcitx5 上游对 phoc 依然**零条目**（I1 §2.4 结论仍成立：`gh search issues --repo fcitx/fcitx5 phosh` = 0）。
本轮新增一条正面证据：**fcitx5 有 `zwp_input_popup_surface_v2` 的协议绑定但不用**
（`src/lib/fcitx-wayland/input-method-v2/zwp_input_popup_surface_v2.{cpp,h}` 存在，
`src/frontend/waylandim/*` 引用 0）⇒ 写 MR 时**不能**声称「修 fcitx5 用户的候选窗」。

---

## 4. 拟投递件（**未发送、未 push**）

产物：`reports/artifacts/phosh-ime-20261128/mr-draft.md`
目标：`World/Phosh/phoc`，关 **#77**；标题 `input-method-relay: Support zwp_input_popup_surface_v2`。
草稿含：正文（约 780 字符，按 I2 的「guidog 要短」口径）、复现步骤、期望行为、AI 披露段、以及投递前必做三件事。

**投递闸门（本报告建议，不是自动执行）**：
1. **先有代码**（草稿只有设计）：5 个动点 = relay 里加 `popup_surfaces` 列表 + `new_popup_surface`/commit/destroy 监听；
   位置计算（focused text-input 的 `current.cursor_rectangle` + 表面 geometry → 输出坐标 → 夹在输出内）；
   `wlr_input_popup_surface_v2_send_text_input_rectangle()`；`render.c` 在 OVERLAY 之后渲染；
   `output.c::phoc_output_for_each_surface` 纳入 frame-callback/damage。
2. **先有测试**：`tests/test-input-method-relay.c` 已有 IM v2 绑定用例（`:14-42`），扩一个 popup 用例即可。
3. **口径**：不写「修用户 bug」，写「协议完整性 + 与 sway/Hyprland 对齐 + #77」；`#302`（提层）如果一起改，
   必须在正文里分开说，别把两件事混成一条。

**优先级**：**P2**（本栈有更省的路）；若上游 !343 落地（stevia 自带 fcitx5 候选），A 对我们就降为
「协议完整性/未来 IM 储备」，仍值得投 —— 它同时是 #302 的前置。

---

## 5. 未证实 / 风险（一律不写成结论）

| # | 未证实项 | 现有依据 | 怎么补 |
|---|---|---|---|
| V1 | 「本栈任何走 IM 协议的候选窗必然不可见」是源码级必然，但**本轮没有上机客户端验证**（无设备动作授权） | phoc `src/` 零 popup + 协议原文 + sway/Hyprland 对照 | 需要在设备上跑一个 `zwp_input_popup_surface_v2` 客户端（可先用 `tests/` 里的 harness 改） |
| V2 | **G1 的因果**：classicui 无窗是否 100% 只因为缺 `zwp_input_panel_v1`（Z §0-C3 判「确定」，本轮未重验） | Z 的源码引用；本轮只复核了「phoc `protocols/` 无该 XML」这半 | 若要写进 MR/issue，需再读 fcitx5 `src/ui/classic/` 全文 |
| V3 | `zwlr_virtual_keyboard` 注入的键在 IM 持有 keyboard grab 时是否被 IM 吃掉（I1 的 U8） | 纯推断 | E7/E8（需装包，本轮不做） |
| V4 | 设备 `phoc` 版本的两处记载冲突（I3 写 0.58，实为 0.46） | `device-probe.log` `dpkg -l` 逐字 | 已在 `phosh-gestures-assessment-20261128.md` 记录；**I3 那句建议由有写权的一方更正**（本 lane 不改） |
| V5 | phoc 若实现 popup，是否会与 phosh 的 layer popup / grab 冲突（例如锁屏键盘、顶栏菜单） | 无实测；渲染序与 layer-shell 提层逻辑只给出「可能」 | 实现时用 `tests/test-layer-shell.c` 类绕行；MR 正文里已把「popup 在 OVERLAY 之后」写成设计约束 |

**一条口径提醒**：`reports/phosh-ime-popup-research-20261128.md`（本文件）与
`reports/artifacts/droidloom-ime-issue-20261127/body.md` 是**两条不同的栈**（phosh/phoc 协议面 vs Android 容器 IME），
不要把「droidloom 无键盘」与「phoc 无 input popup」写成同一个根因。

---

## 6. 复现命令（全部只读；本报告数字的出处）

```bash
# 0) 设备版本（不接触设备：读既有 probe 日志）
grep -A12 '## versions' reports/artifacts/phosh-gestures-20261128/device-probe.log

# 1) 源码版本身份（设备版 vs 上游）
md5sum /tmp/phoc-main-imr.c /tmp/clean/phoc-0.59.rc1/src/input-method-relay.c   # 应相同
grep -n 'version:' /tmp/ph046/phoc-0.46.0/meson.build /tmp/clean/phoc-0.59.rc1/meson.build

# 2) popup 零实现（两代都跑）
grep -rn 'input_popup\|popup_surface\|new_popup\|cursor_rectangle' /tmp/ph046/phoc-0.46.0/src/ /tmp/clean/phoc-0.59.rc1/src/

# 3) intent 链路
grep -n 'send_content_type' /tmp/ph046/phoc-0.46.0/src/input-method-relay.c /tmp/clean/phoc-0.59.rc1/src/input-method-relay.c
grep -n 'select_layout_by_im_purpose\|on_im_hint_changed' /tmp/stevia-main/src/pos-input-surface.c

# 4) 提层限制
grep -n 'elevate_osk' /tmp/clean/phoc-0.59.rc1/src/input-method-relay.c
grep -n 'focused_layer' /tmp/clean/phoc-0.59.rc1/src/layer-shell.c
sed -n '698,722p' /tmp/clean/phoc-0.59.rc1/src/render.c

# 5) 上游状态（务必 --noproxy '*'；单 MR 端点可能 406，改用列表端点取正文）
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/projects/16763/issues/77'
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/projects/19269/merge_requests?per_page=100&state=opened'
curl -sS --noproxy '*' 'https://gitlab.gnome.org/api/v4/groups/61154/merge_requests?search=popup&per_page=20&state=all'
```
