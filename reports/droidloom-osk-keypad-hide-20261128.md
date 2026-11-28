# 新发现/回归记录（2026-11-28 收尾轮，用户真机报告）

## A. 侧滑返回：弧度已正常，但**边缘滑动仍透传给应用**（回归性质 = 固有边界被用户确认）

**用户实测（2026-11-28，PiliPlus + Firefox）**：弧度识别已经正常（D13 的 `-r 45` + 多档手势生效，不再要求水平）；**但边缘滑动仍被前台应用当成它自己的交互**（Firefox 滚动、PiliPlus 里被当触摸手势）。

**定性**：不是 D13 的配置问题，是路线①的固有边界 —— lisgd 只 `open(O_RDONLY)` 旁听 evdev，**不 `EVIOCGRAB`**，同一次触摸照常送到应用。
代码级依据：`lisgd.c` 只读设备、无 grab；`uinput-back` 是独立注入设备，对原触摸流没有任何影响。

**用户裁决（2026-11-28 10:0x）**：**应该封装起来**，并且要**方便日后做逐级 UI 返回意图的传递**（应用内返回 → 应用栈 → shell 级关闭）。
⇒ 这条并入 **T35（上游 MR）**，并把「逐级返回意图」写进设计目标；本机不再加「边缘带 grab + 重放」的兜底（用户未选，且与封装目标重复）。

## B. 新 bug：小红书手机号字段，数字键盘输入一个数字就自隐，之后再也唤不出

**用户原话**：「小红书输入，数字键盘唤起以后，输入一个数字就自动收回去，再也弹不出」。

**本轮复现（droidloom 0.1.0-51，默认 IME = `com.android.droidloom.ime/.HostInputMethod`，宿主 OSK）**

| 步 | 观察 | 证据 |
|---|---|---|
| 1 | `droidloomctl launch com.xingin.xhs` → 手机号登录页，点输入框 | 宿主 OSK 的**电话键盘**出现（1–9 + ABC + `.` + ⌫ + ↵）：`artifacts/.../1-keypad-visible.png` |
| 2 | 点键盘上的 `1` | 键盘消失；输入框**没有**变成 `151`（原值 `15` 不变），光标/焦点丢失：`2-after-one-digit-keypad-gone.png` |
| 3 | 再点输入框 | **键盘不再出现**（`mInputShown=false`、`mImeWindowVis=0`）：`3-refocus-no-keypad.png` |

**Android 侧日志（关键三行）**

```
02:07:42.488 ImeTracker(78952): com.xingin.xhs:…: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser true
02:07:42.491 DroidloomIME: show request configChange=false
02:07:42.491 ImeTracker(58222): …: onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE
02:07:58.505 ImeTracker(78952): …: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser true   ← 应用自己请求隐藏
02:07:58.507 DroidloomIME: hide input panel
```

之后每次「点输入框 → 键盘不出」都伴随同样的 `onRequestShow … fromUser true`，但**宿主 OSK 不再出现**（`grim` 连续截图确认）。

**初步定位（未定因，两条独立疑点）**

1. **键盘触点是否到了 OSK**：点 `1` 后应用收到「用户隐藏」请求（`HIDE_SOFT_INPUT fromUser=true`），且输入框失焦 —— 更像触点落到了应用而不是 OSK 的按键上（同在数字键盘上的 `ABC` 也点不动布局）。若成立，与 A 是同一类「宿主 OSK 的触摸与 droidloom 应用窗口的输入归属」问题。
2. **隐藏后再唤不出**：`HostInputMethod.onShowInputRequested()` 恒 `false`（设计），宿主 OSK 的显示靠 `droidloom-wayland` 的 text-input enable/disable；隐藏（`hideWindow` → `publish(false)`）之后再 `show request`，`droidloom-wayland` 的 `update()` 是否重新 `enable()` 取决于 `Editor.needs_enable()`（`task`/`session` 未变则不重发 enable）⇒ 可能是「dismiss 后没有重新 enable」的状态机缺陷。

**对照**：同一 IME/OSK 在 **Settings 搜索框**（普通文本 `inputType=text`）里，拼音候选与 ASCII 输入都正常，键盘不会被隐藏（T32 §4.1 已验）；差异点在「电话/数字 `inputType` ⇒ phosh-osk-stub 用 `PosKeypad`」这条路径。

**下一步（已登记 T38）**：用 `journalctl --user` + `DROIDLOOM_TRACE=input` 的单变量实验分离「触点归属」与「re-enable 状态机」；需要 droidloom 侧 `text_input.rs` 的 `editor=` 诊断行（当前默认不开）。

## C. 本轮未做（登记指针）

- T35（上游封装/逐级返回）、T36（D13 人手验收）、T38（本节 B）、T37（上游线程跟进）、T34（gmobile 本机编）。
