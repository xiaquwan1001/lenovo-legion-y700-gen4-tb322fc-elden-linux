# #761 Android 应用要出宿主键盘，droidloom 窗口必须**自己有宿主键盘焦点**；`adb shell input tap` 不给焦点 ⇒ 自动化会假阴性

- 日期：2026-11-28（T43 上机验收时定位；`reports/phoc-046-edge-swipe-deploy-20261128.md` §2）
- 现象：小红书号段框 / Android Settings 搜索框，看起来「点了有光标、但宿主 OSK 不出来」；
  Android 侧一切正常（`mInputShown=true`、`mImeWindowVis=1`，`DroidloomIME: start input restarting=false editable=true` + `show request`）。
- 因果链（本轮实测，`WAYLAND_DEBUG=1` + 探针 eprintln 双证）：
  1. `droidloom-wayland` 的 `self.focused` **只在 `wl_keyboard.enter` 里赋值**（`main.rs` `KeyboardHandler for App::enter` → `set_focus(task_for_surface(surface))`）；
  2. `text_input.rs::update()` 只有当 `editor.active && editor.task != 0 && Some(editor.task) == focused_task && entered.is_some()` 才发
     `zwp_text_input_v3.enable`；`focused_task=None` ⇒ **永远不发 enable** ⇒ 宿主 OSK 不起来；
  3. 探针实测：`focused=None entered=Some(...)` / `focused=Some(..) entered=Some(..) android_task=Some(65)` 两种状态都能稳定复现，
     `focused` 一有值，OSK 立刻出现（Android Settings 搜索框、小红书号段框各验一次）。
- **关键陷阱（自动化假阴性）**：`adb shell input tap X Y` 是**在 cell 里**点的，宿主 phoc 看不到指针/触摸事件，
  因此 **droidloom 窗口拿不到键盘焦点** ⇒ 用 adb 点击去验「键盘能不能弹出」必然失败，且看起来像「功能坏了」。
  正确做法 = 用宿主侧输入给焦点：`ydotool mousemove -a X Y` + `ydotool click 0x00`（鼠标点进窗口即触发 `wl_keyboard.enter`）。
  （`tools/uinput-touch` 也不行：见 `#760`/`#755`，它能 tap 到 toplevel，但触摸注入这条路对手势/焦点都不稳。）
- 判据/纪律：**验 Android 应用的宿主键盘，三步缺一不可** —— ① 宿主侧 `ydotool` 点输入框（拿焦点）② `grim` 看宿主截图（不看 `adb screencap`，`#753`）③ `adb shell uiautomator dump` 读文本框内容核对字符真的进去了。
- 附带：`droidloom-wayland` 的这个 `focused_task` 依赖意味着**虚拟键盘场景本身脆弱**（OSK 是 phosh 的 layer 表面，理论上会参与键盘焦点仲裁）；
  是否要放宽成「`entered` 即可 enable」属产品取舍，需先有真手指证据再动，勿凭推理改（本轮已试改并**回滚**，见 `out/` 无对应部署件）。
- 出处：`reports/phoc-046-edge-swipe-deploy-20261128.md` §2、PITFALLS `#65` 因果链（`reports/t38-keypad-rootcause-20261128.md`）。
