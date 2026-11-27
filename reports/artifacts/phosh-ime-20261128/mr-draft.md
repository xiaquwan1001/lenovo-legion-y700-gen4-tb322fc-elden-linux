# MR 草稿（**未发送、未 push**）— phoc: implement `zwp_input_popup_surface_v2`

> 状态：DRAFT ONLY。本轮无凭据使用、无 `git push`、无 GitLab POST。
> 目标仓库：`World/Phosh/phoc`（id 16763）。目标 issue：**#77 “Support input-popup”**（opened 2019-09-20，0 notes）。
> 基线：`main`（`src/input-method-relay.c` 与 `v0.59.0`/`v0.59.rc1` 逐字节相同，md5 `a405390ab2016138ee9b77fdb6fb89ee`）。
> 关联证据：`reports/phosh-ime-popup-research-20261128.md` §1–§3。

---

## 1. 标题

```
input-method-relay: Support zwp_input_popup_surface_v2
```

（备选短标题：`input-method: Place and track input popups`）

## 2. 正文（可直接粘贴；约 780 字符，遵循 guidog 的「少写话」要求）

```
phoc ignores `zwp_input_method_v2.new_popup_surface`, so an input method that
draws its candidate window as an input popup gets an unmapped surface: the
object exists (wlroots creates it) but nothing is rendered, positioned or
damaged, and `text_input_rectangle` is never sent. Input methods that follow the
protocol therefore cannot show candidates; the only way to get a candidate
window today is out-of-band (a separate toplevel / layer surface / D-Bus panel,
as fcitx5 does with classicui or kimpanel).

Issue #77 asks for this ("useful for displaying CJK alternatives, or for some
prediction scheme"). wlroots already hands us everything: `new_popup_surface`
gives a `wlr_input_popup_surface_v2` whose `surface` is mapped while the input
method is active. The compositor only has to place it and feed it the cursor
rectangle. sway (`sway/input/text_input.c:126-204`) and Hyprland
(`src/managers/input/InputMethodPopup.cpp`) do exactly that.

Approach (mirrors sway, adapted to phoc's render path):

- track `relay->input_popup_surfaces`, listen to `new_popup_surface` and to the
  surface's commit/destroy;
- position the popup from the focused `PhocTextInput`'s
  `current.cursor_rectangle`, translated by the focused surface's geometry into
  output coordinates, clamped to the output (flip above/below, slide left/right);
- send `wlr_input_popup_surface_v2_send_text_input_rectangle()` with the cursor
  rectangle in surface-local coordinates, and re-send on focus / rect change;
- render the popup in `src/render.c` after the overlay layer, and include it in
  `phoc_output_for_each_surface()` so frame callbacks and damage work;
- drop the popup when the text input loses focus, the input method is
  destroyed, or the surface is unmapped.

Testing: extend `tests/test-input-method-relay.c` (it already binds
`zwp_input_method_v2` for the keyboard-grab test) with a client that creates a
popup surface, activates, and asserts it receives `text_input_rectangle` and
gets rendered.

No client in our tree uses this yet; it is protocol completeness plus parity with
sway/Hyprland, and a prerequisite for IM-side CJK candidates.
```

## 3. 复现步骤（给 reviewer 的最小手工路径）

环境：任何 phoc（0.46 起都有 `zwp_input_method_manager_v2`；复现于 `v0.59.rc1`/`main` 与 `v0.46.0`）。

1. 起 phoc（任意输出，`phoc -S -E <shell>`）。
2. 让一个 text-input-v3 客户端拿到焦点并 `enable`（`gtk4-demo` 的 entry、或 `tests/test-input-method-relay.c` 里的 test client 扩展）。
3. 让一个 `zwp_input_method_v2` 客户端占槽并创建 `zwp_input_popup_surface_v2`，attach 任意 buffer 后 commit：
   ```
   input_method = zwp_input_method_manager_v2.get_input_method (seat);
   popup  = zwp_input_method_v2.get_input_popup_surface (input_method, wl_surface);
   wl_surface.attach (buffer); wl_surface.commit ();
   ```
4. 观察：
   - `text_input_rectangle` 事件：**一次也不来**（phoc 无此调用）。
   - 屏幕：popup buffer **不出现**（`src/render.c:698-722` 只渲染 background/bottom/views/unmanaged/top/drag-icons/overlay，无 popup 项）。
   - `wl_display` 侧没有任何错误 → 客户端无法区分「合成器不支持」与「还没摆好」。

## 4. 期望行为

- IM `active` 且 popup surface 有 buffer 时，popup 显示在被聚焦文本区域旁边（默认在光标矩形下方，空间不足时翻到上方，横向夹在输出内）。
- 每次聚焦的 `text-input-v3` 客户端发出新的 `cursor_rectangle`（`commit` 后）都重发一次 `text_input_rectangle`（surface-local 坐标）。
- 焦点离开 / IM 销毁 / surface unmap 时 popup 消失，且不残留 damage。
- 层叠位置：在 overlay 层之上（锁屏上也能显示），不参与 layer-shell 的 OSK 提层逻辑（`phoc_layer_shell_update_osk()`）。

## 5. AI 披露段（按 `AGENTS.md`「上游发信」三件套；正文末尾附上）

```
AI disclosure: this description and the code were prepared with AI assistance
(LLM) and reviewed by the author; all statements above are backed by the cited
sources (wlroots header, sway/Hyprland implementations, phoc source lines) and
can be reproduced with the steps in this description.
```

## 6. 投递前必须先做的三件事（不是草稿的一部分）

1. **代码**：本草稿只有设计，没有 patch。按 §2 的 5 个动点写 `PhocInputPopup` 需要 ≥1 个工作日 + 一次 `meson test`；未写之前不该开 MR。
2. **测试**：`tests/test-input-method-relay.c` 扩一个 popup 用例（现有用例已绑定 IM v2，可直接复用 globals）。
3. **谁受益**：上游一定会问「哪个 IM 用这个」。事实：**fcitx5 目前不消费**（`src/frontend/waylandim/*` 里 `popup` 零命中，`src/lib/fcitx-wayland/input-method-v2/zwp_input_popup_surface_v2.*` 是未使用的绑定）；**ibus main 也没有**；真正消费的是未来 IM 侧 CJK 候选 UI 与 KDE 系。⇒ 正文里只能写成「protocol completeness + parity + #77」，**不能**写成「修复某用户可见 bug」。
