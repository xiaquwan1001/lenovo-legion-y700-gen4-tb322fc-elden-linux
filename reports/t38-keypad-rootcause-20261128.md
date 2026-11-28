# T38 定因（2026-11-28 第三阶段）：`commit_string("8")` 是干净的 —— 空格来自小红书分组格式；「收回」= droidloom 在 Android 侧 IME 被 IMMS 收起后 `disable()` 了宿主 text-input

- 机件：droidloom 0.1.0-51 / 默认 IME `com.android.droidloom.ime/.HostInputMethod` / phosh-osk-stub（`Completers default` **临时置空**，即 RIME 桥不参与）/ Debian 13 + phosh 0.46 / `Scale 3.0`。
- 取证手段：`droidloom-wayland` 开 `WAYLAND_DEBUG=1`（协议原文）+ `DROIDLOOM_TRACE=input`（输入路由）+ `adb logcat`（Android 侧 IME）+ `uiautomator dump`（直读 cell 里的输入框文本）。

## 0. 两条结论（各自独立）

| 现象 | 结论 | 判据 |
|---|---|---|
| 「输入的字**自带空格**」 | **不是 bug**：宿主发出的提交是干净的 `"8"`；空格是**小红书手机号输入框自己的分组格式**（3-4-4，输到 3 位后补空格） | 协议原文 `<- zwp_text_input_v3@25.commit_string, (Some("8"))`；`uiautomator dump` 的 EditText `text="151 "`（3 位 + 空格） |
| 「输入一个字符**键盘收回**、之后唤不出」 | **= issue #65 的完整因果链**（不是第二个 bug）：Android 认为 IME 从未 show 成功（`onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`）⇒ 应用提交后一重排/重启输入，IMMS 就把「没在显示」的 IME 收掉 ⇒ droidloom-wayland 忠实 `disable()` 宿主 text-input ⇒ 宿主 OSK 收起；之后 `Editor.needs_enable()` 认为 session 没变、不再 `enable()` ⇒ 点输入框再也不出键盘 | 见 §2 的三段时间线 |

## 1. 空格：协议层干净，格式化在应用侧

协议原文（原日志 2.6 MB / 22 018 行，按仓库 artifacts 白名单只留**摘录** `reports/artifacts/t38-20261128/9b-protocol-excerpt.txt`，原件的 `zwp_text_input_v3@25.*` 五行逐字如下）：

```
11:38:24  -> zwp_text_input_v3@25.enable()
11:38:24  -> zwp_text_input_v3@25.set_content_type(0, 3)     # hint=0, purpose=3(number)
11:38:26  <- zwp_text_input_v3@25.commit_string, (Some("8"))  # ← 干净，无空格
11:38:26  <- zwp_text_input_v3@25.done, (2)
11:38:26  -> zwp_text_input_v3@25.disable()                   # ← 5.3 s 后客户端自己 disable
```

- 同期把候选引擎整条关掉（`sm.puri.phosh.osk.Completers default` = 空）后现象**不变** ⇒ 排除我方 RIME 桥（`pos-completer-rime.c` 的「分隔符补空格」路径没参与）。
- 也排除了 `pos-keypad.c`（只发单字符 / `KEY_BACKSPACE` / `KEY_ENTER`，不拼空格）与 droidloom `HostInputMethod.java`（`commitText(edit.commit, 1)` 原样提交）。
- `uiautomator` 直读：`text="151 "` —— 之前是 `15`，按一次 `8` 的上一轮是 `151`，本次是 `8`；**空格出现在第 3 位之后**，正是手机号分组格式（+86 分组同款）。
- 收尾：`Completers default` 已还原为 `rime`（`gsettings get` 复核 = `'rime'`）。

## 2. 收回：Android 侧 IMMS 收 IME ⇒ droidloom `disable()` ⇒ 宿主 OSK 收

同一轮（11:38）三侧时间线对齐：

| 时刻（cell/log 本地） | 侧 | 事件 |
|---|---|---|
| 03:38:24.383 | Android | `onRequestShow … SHOW_SOFT_INPUT fromUser false`（点输入框） |
| 03:38:24.387 | Android | `DroidloomIME: show request configChange=false` → **`onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`**（= **#65**：headless IME 的 `onShowInputRequested()` 恒 false） |
| 11:38:24 | 宿主 | 但 `zwp_text_input_v3.enable()` 已经发出（phosh 侧照常弹 OSK，所以**用户能看见键盘**） |
| 03:38:26.524 | Android | `start input restarting=true editable=true`（输入会话被重启：应用提交后重排输入框） |
| 03:38:26.573 | 宿主 | `commit_string("8")` → 应用收到 |
| 03:38:26.9x | 宿主 | 客户端 `disable()`（droidloom-wayland 判定 editor 没了）→ **OSK 收起** |
| 之后 | Android | 再点输入框：`onRequestShow … fromUser true` 有、`DroidloomIME` 侧**没有** `show request` 行（会话未重新 enable）⇒ 键盘不再出现，直到重启 cell |

**因果要点**：因为 show 在 Android 侧**从未成功**，Android 的 `mInputShown` 一直是 false；应用一提交就重排/重启输入（`restarting=true`），IMMS 自然把「没在显示」的 IME 收掉 —— 于是「输入一个字符就收回」。这与「点空白处收回」是同一个状态机，只是触发者是应用自己的重排。

## 3. 上游口径

- 这两条都已并进 **droidloom issue #65**（本轮补了 `commit_string("8")` 协议原文与 `restarting=true` → `disable()` 的因果链），措辞明确「**宿主提交是干净的**，空格属应用格式化，不是 droidloom 的锅」。
- 若要本机先用，唯一有效方向在 Android 侧：让 `HostInputMethod.onShowInputRequested()` 不再恒 `false`（例如首次 show 时返回 true 并靠 headless 面板占位），但那要重编 Android 镜像 —— 与 `TASKS/NEXT.md` ~~T2~~ 的 001 裁决同一条限制（podman+AOSP 缓存，>1 GiB 下载），**本轮不做**，登记为待裁决。

## 4. 本轮临时改动与还原（已全部还原）

| 改动 | 用途 | 还原 |
|---|---|---|
| `gsettings set sm.puri.phosh.osk.Completers default ""` | 排除 RIME 桥 | ✅ 已回 `rime` |
| 设备 `/usr/local/sbin/elden-session-user` 追加 `G_MESSAGES_DEBUG` 钩子 + `/etc/elden-osk-debug` | 抓 OSK 侧日志（**实践证明没生效**：osk-stub 由 phosh 起、日志没落到 user journal） | ✅ 已用 `.bak-20261128` 原样恢复并删备份 |
| `systemctl --user set-environment WAYLAND_DEBUG=1` + 重启 droidloom.service | 抓协议原文（**有效**） | ✅ 已 `unset-environment` 并重启一次 |
| `systemctl --user set-environment DROIDLOOM_TRACE=input` | 输入路由取证 | ✅ 已 unset（下次启动即无） |

## 5. 证据文件

`reports/artifacts/t38-20261128/`：`9b-protocol-excerpt.txt`（协议事件摘录，含 §1 那五行原文；原件 2.6 MB 未入库）、`7-logcat-capture-1121-1126.log`、`8-journal-trace-1121-1126.log`、以及 §1/§2 引用到的截图与 `t38-1x` 系列。
