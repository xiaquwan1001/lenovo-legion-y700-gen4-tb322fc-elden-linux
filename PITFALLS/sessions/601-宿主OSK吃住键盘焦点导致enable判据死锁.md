# #762 宿主 OSK 吃住键盘焦点 ⇒ droidloom 的 `enable` 判据死锁（「点输入框唤不出键盘」的真因，T43 ① 修不了）

- 日期：2026-11-28（用户报「手动点小红书还是唤不出输入法」，父代理探针定位并修；`reports/phoc-046-edge-swipe-deploy-20261128.md` §2）
- 现象：Android 应用（小红书号段框、Android Settings 搜索框）点输入框，**手指和鼠标都不起宿主键盘**；
  Android 侧完全正常（`mInputShown=true`、`mImeWindowVis=1`、`DroidloomIME: start input restartable=false editable=true` + `show request`）。
- 因果链（探针 eprintln + `WAYLAND_DEBUG` 双证）：
  1. `droidloom-wayland` 的 `self.focused` **只在 `wl_keyboard.enter`** 里赋值（`main.rs` `KeyboardHandler for App::enter`）；
  2. `text_input.rs::update()` 的 `desired` 要求 `Some(editor.task) == focused_task`，否则**永不发 `zwp_text_input_v3.enable`**；
  3. **phosh 的 OSK（phosh-osk-stub）是 layer 表面，被映射时就持有合成器键盘焦点** ⇒ 等输入的应用永远不是 focused task；
  4. 于是：没 `enable` ⇒ 没 OSK ⇒ 应用更回不到键盘焦点 ⇒ **死锁**。T43 ①（抑制 disable / held 后强制 re-enable）只处理
     「曾经 enable 过」的路径（`held` 要求 `enabled.is_some()`），对这条**首次 enable** 的死锁完全无效。
- 实证对照（同一设备、同一状态、探针输出可复算）：`focused_task=None`
  - 旧判据 ⇒ `desired=None enabled=None editor=Some((true,71,6,2)) entered=true` ⇒ 无 OSK（手指点、鼠标点都不起）；
  - 新判据 ⇒ `desired=Some((71,6,2))` ⇒ 有 `enable` ⇒ **单次手指点号段框，数字键盘出现**（`out/phoc-deploy-20261128/ime-test/f1.png`）。
- 修法（已落地，`patches/local/droidloom-local-20261128/0002-enable-text-input-without-keyboard-focus.patch`）：
  `Some(editor.task) == focused_task` → `focused_task.is_none_or(|task| task == editor.task)`。
  依据 = `entered` 已把请求绑定到本客户端自己的 text-input 表面（`zwp_text_input_v3.enter` → `task_for_surface()`），
  焦点换走时 `entered` 会清空 ⇒ 仍会 disable，不至于无限泛洪。
- 纪律：**任何「必须 X 有焦点才让出 Y」的状态机，都要问一句「虚拟键盘/IME 这类 layer 表面会不会把 X 的焦点抢走」**；
  一旦是，X 永远等不到，Y 永远不出来（互等）。诊断套路 = 在判据处 eprintln（`DROIDLOOM_TRACE=input` 门控）+ 一次 `grim` 复核。
- 出处：`reports/phoc-046-edge-swipe-deploy-20261128.md` §2、`patches/local/droidloom-local-20261128/README.md` §②。
