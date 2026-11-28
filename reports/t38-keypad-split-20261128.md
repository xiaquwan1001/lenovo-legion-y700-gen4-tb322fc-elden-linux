# T38 单变量实验（2026-11-28 第二阶段）：数字键盘自隐 / 再唤不出，拆出两个独立结论

- **机件**：droidloom 0.1.0-51、默认 IME `com.android.droidloom.ime/.HostInputMethod`（宿主 phosh OSK `phosh-osk-stub` 0.46）、内核 `vk189-suspend`、宿主 `Scale: 3.0`。
- **注入通道**：`/usr/local/bin/uinput-touch`（虚拟多点触控，`INPUT_PROP_DIRECT`）+ `ydotool`（鼠标/键盘）——**本次实验的关键发现之一就是这条通道到不了 OSK**（见 §3）。
- **一句话**：
  1. **「再唤不出」已定因归属**：`onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` 与 droidloom issue **#65** 同签名 ⇒ 属**已知上游缺陷**（droidloom `text_input` 在 dismiss 后不再 `enable()`），不是本机新 bug。
  2. **「点一个数字就自隐」这半仍缺一次真人触摸**：自动化注入的触摸**根本到不了宿主 OSK 表面**（连 Settings 的全键盘也一个字符打不进），所以「触点归属」这一层我这条通道判不了 —— 需要用户 2 分钟真手复验（判据见 §5），或下一步给 `phosh-osk-stub` 挂 `WAYLAND_DEBUG=1`。

## 1. 复现（与用户报告一致）

| 步 | 命令/动作 | 观察 |
|---|---|---|
| 1 | `droidloomctl launch com.xingin.xhs` → 小红书「Log In」→ 勾协议 → 点号段输入框 | 宿主 OSK 出**数字键盘**（1–9/ABC/`.`/⌫/↵）：`artifacts/t38-20261128/t38-5-login.png` |
| 2 | `uinput-touch tap 315 2346`（= 数字 `1`） | 键盘消失、号码仍 `15`、输入框失焦：`t38-6-after1.png` |
| 3 | 再点输入框 | 键盘**不再出现**：`t38-7-refocus.png` |

Android 侧日志（逐字）：

```
02:45:21.914 I/ImeTracker( 1823): com.xingin.xhs:df3c0ae2: onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT fromUser true
02:45:21.916 I/DroidloomIME( 1030): hide input panel
02:45:39.825 I/ImeTracker( 1823): com.xingin.xhs:b48d3ebc: onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser true
02:45:39.828 I/DroidloomIME( 1030): show request configChange=false
02:45:39.828 I/ImeTracker( 1030): com.xingin.xhs:b48d3ebc: onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE   ← 与 issue #65 同签名
```

## 2. 结论 A：再唤不出 = 已知上游缺陷（不需要真人，可先收）

- `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` 正是 **droidloom issue #65**（2026-11-27 我方提，见 `TASKS/NEXT.md` ~~T3~~）的签名；#65 未被修，51 复现依旧。
- 机制解释（与 §1 日志一致）：宿主 OSK 的显示由 `droidloom-wayland` 的 text-input `enable/disable` 驱动，`HostInputMethod.onShowInputRequested()` 恒 `false`；一次 dismiss 之后 `Editor.needs_enable()` 认为 task/session 未变 ⇒ 不重发 `enable()` ⇒ 后续 `onRequestShow` 永远落 `onFailed`。
- 处置（已完成）：**已在该 issue 下补复现**（2026-11-28T02:51:40Z，<https://github.com/denialwm/droidloom/issues/65#issuecomment-7232640301>，正文原件 `out/gh-20261128/droidloom-65-comment.md`）：明确「不是占位 IME 专属，headless IME + 宿主 OSK 同样复现」，给出触发条件（一次 show 后 dismiss）与三条日志，并把 `needs_enable()` 写成**假设**（未用 `DROIDLOOM_TRACE=input` 取证）。本机不做规避（占位 IME 已证无效）。

## 3. 关键工具发现：注入的触摸/指针**到不了宿主 OSK 表面**

对照组（同一注入工具、同一会话、同一时刻）：

| 目标 | 注入 | 结果 |
|---|---|---|
| 小红书号段输入框（应用窗口） | `uinput-touch tap` | ✅ 点击生效（出键盘、光标进框） |
| Settings 搜索框（应用窗口） | `uinput-touch tap` | ✅ 聚焦、弹出**全键盘**（`t38-10-settings.png`） |
| 全键盘的 `q`/`e` 键（OSK 表面） | `uinput-touch tap` | ❌ 一个字符不进，键盘不消失（`t38-11-typed.png`） |
| 数字键盘的 `1`（OSK 表面） | `uinput-touch tap` | ❌ 数字不进；**应用**反而收到 `HIDE_SOFT_INPUT fromUser true`（即触摸穿透到应用） |
| 数字键盘的 `1`（OSK 表面） | `ydotool` 鼠标点击 | ❌ 既不进数字也不进应用日志；反而把 phosh 切进 overview（`t38-15-mouse-on-keypad.png`） |

⇒ 两个后果：
- **自动化测键盘不可行**（`uinput-touch` 只对 toplevel 有效，对 phosh 的 OSK 层表面无效）——这条已足够写成判据坑。
- 用户报的「点数字就自隐」在自动化下**可复现**（应用收到 `fromUser=true` 的隐藏请求），但**无法区分**「OSK 的 keypad 布局 input region 坏了」与「注入触摸绕过 OSK 直接落到应用」——因为 **在没有故障的全键盘上，注入触摸同样绕过 OSK**。

## 4. 顺带观察（未定因，登记）

- 同一会话里，点了「Log in with password」切到**密码框**（`inputType=textPassword`）后，OSK **仍显示数字键盘**（`t38-8-password.png`）——布局没有跟随新的 text-input 请求切回全键盘。这可能是「一次失败 session 之后 osk-stub 布局滞留在上一布局」的独立缺陷；下一步用真人触摸复验时顺带看一眼即可判定（若真手在密码框上仍见数字键盘 ⇒ 实锤）。

## 5. 需要用户 2 分钟（判据最小集）

1. 打开小红书号段输入框（数字键盘出现）→ **用手指**点 `1`：数字进框且键盘不消失 = 触点归属 OK，问题只在 §2；数字没进、键盘消失 = 触点确实穿到应用（keypad input region 缺陷，属 phosh/phosh-osk-stub 上游）。
2. 接着点密码登录 → 看键盘是**全键盘**还是仍是数字键盘（判 §4）。
3. 若 1 表现为「触点穿到应用」，我再按「keypad 布局 input region」方向取证（`phosh-osk-stub` 的 `WAYLAND_DEBUG=1` + 输入区域对账）。

## 6. 证据文件

`reports/artifacts/t38-20261128/`：`t38-1-launch.png`（锁屏）、`t38-2/3`（锁屏，鼠标解不开）、`t38-4-unlocked.png`、`t38-5-login.png`（数字键盘出）、`t38-6-after1.png`（点 1 后自隐）、`t38-7-refocus.png`（唤不出）、`t38-8-password.png`（密码框仍数字键盘）、`t38-9-pwtap.png`、`t38-10-settings.png`（全键盘）、`t38-11-typed.png`（注入点键不进字）、`t38-12/15`（鼠标点击 → overview）、`t38-14-keypad2.png`（再次出数字键盘）。
