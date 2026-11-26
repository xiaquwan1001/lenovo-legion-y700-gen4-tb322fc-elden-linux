# droidloom 输入法：「输入第一个字符后键盘缩回、再也唤不出」（2026-11-26，父代理上机取证 + adb 自动化复现）

> 用户报：小红书登录页点手机号框能弹出键盘；**输入第一个数字后键盘缩回，且再也唤不出**；此前一轮还出现过「整轮唤不出」。
> 本轮在拿到 **cell 网络 + adb 端点**后，用 `adb input tap` / `input text` / `screencap` 做了**无人复现**（不再需要用户按键）。

---

## 0. 一致性结论

**这是 droidloom「空占位 IME ↔ 宿主 OSK」这条桥的状态机缺陷，不是小红书、不是 dpi/窗口改动、也不是 phosh-osk-stub 崩溃。**

cell 里**只有一个 IME**：`com.android.droidloom.ime/.HostInputMethod`（label 就叫 "Droidloom host keyboard"），它是**空占位器**，真正键盘由宿主 OSK 画（上游 `denialwm/droidloom#34` 已写明「Make android keyboard empty spacer so apps fit to actual OSK」，且 App 不会随键盘 resize）。

---

## 1. 实测证据（cell 内 `logcat -b all`，时间为 Android UTC）

复现路径（adb 注入，等价用户操作）：点框 → `input text 3` → 再点框。

```
10:20:56.077 I/DroidloomIME(960): start input restarting=false editable=true
10:20:56.078 I/DroidloomIME(960): show request configChange=false
10:20:56.078 I/ImeTracker(960): com.xingin.xhs:6844a963: onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE
10:20:56.079 I/DroidloomIME(960): finish input
10:20:56.079 I/DroidloomIME(960): start input restarting=false editable=true
10:20:56.079 I/ImeTracker(960): com.xingin.xhs:a44a4784: onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE
10:20:57.597 I/ImeTracker(1451): … onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser true
10:21:01.024 W/RemoteInputConnectionImpl(1451): Session id mismatch header.sessionId: 0 currentSessionId: 1
10:21:01.030 I/DroidloomIME(960): start input restarting=true editable=true
10:21:01.990 I/ImeTracker(1451): … onRequestShow … fromUser true
10:21:01.991 I/ImeTracker(1451): … onCancelled at PHASE_CLIENT_REPORT_REQUESTED_VISIBLE_TYPES
10:27:53.481 I/ImeTracker(15756): com.xingin.xhs:… onRequestHide at ORIGIN_CLIENT reason HIDE_SOFT_INPUT
10:27:56.921 I/ImeTracker(15756): com.xingin.xhs:… onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT
10:27:56.924 I/ImeTracker(960): com.xingin.xhs:… onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE
```

判读：
1. **App 侧没问题**：它反复 `onRequestShow … SHOW_SOFT_INPUT`（多数 `fromUser true`），说明「再点框」时 App **确实在求键盘**；
2. **失败点在占位 IME**：每次请求都以 `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` 收尾（由 pid 960 = `com.android.droidloom.ime` 报），且伴随 `start input restarting=true` 与 `RemoteInputConnectionImpl: Session id mismatch` ⇒ **占位 IME 的输入会话反复重启/失配，showSoftInput 永远返回 false**；
3. 该 IME 的窗口在 Android 侧是 `mViewVisibility=0x8(GONE) / mHasSurface=false / frame 高 0` —— 与第 2 点同源：**它没有可显示窗口，所以「报告 shown」永远失败**；而宿主 OSK 侧 `sm.puri.OSK0` 的 `Visible` 也是 false ⇒ 两头都没人真把键盘画出来。

---

## 2. 复现与取证工具（本轮新增能力，后续可复用）

拿回网络后 cell 的 adb 端点可用：宿主 `adb devices -l` ⇒ `10.177.0.2:5555  device product:aosp_cf_arm64_only_phone model:Lenovo_Legion_Y700_Gen4 device:droidloom`。因此后续 UI 问题**不需要用户按屏幕**：

```sh
adb -s device:droidloom shell input tap 912 790      # 点手机号框（1904x3040 坐标）
adb -s device:droidloom shell input text 3
adb -s device:droidloom exec-out screencap -p > /tmp/x.png   # 直接看画面
# 宿主侧整屏（含 phosh 顶栏/手势条）：grim /tmp/x.png
```

本轮三张截图证据：`/tmp/xhs1.png`（登录页、全屏正常）、`/tmp/s2.png`（点框后**光标在、键盘不在**）、`/tmp/osk1.png`（宿主 `grim` 整屏，同上且顶栏正常）。

---

## 3. 可选的处置（按推荐序）

| 方案 | 做法 | 代价/风险 |
|---|---|---|
| **A. 给 cell 装一个「真」IME**（绕开桥） | 下载一个开源键盘 APK（如 F-Droid 的 Simple Keyboard / AOSP LatinIME，~1 MB）→ `adb -s device:droidloom install` → `ime enable/set` | 键盘由 Android 自己画（不再依赖宿主 OSK）⇒ 状态机缺陷绕过；未知 = droidloom 是否会把 IME 窗口正常映射（上游 #34 说 App 不 resize，但画出来应可行）。**需要用户点头**（要下载 APK 并改 cell 默认输入法） |
| **B. 提上游 issue** | 把 §1 日志 + 复现步骤（`input tap`/`input text`/`screencap`，droidloom 0.1.0-49）贴到 `denialwm/droidloom` | 纯记录，短期不解决可用性；但这是**唯一根治路径**（修 HostInputMethod 的 show 状态机） |
| **C. 暂用宿主侧输入** | 用物理键盘（USB/蓝牙）在 cell 里输入 | 零风险，但不满足「平板当手机用」 |
| **D. 停** | 小红书登录这一支不继续投入 | — |

**本轮明确不做**：不改 `/usr/lib/droidloom/current` 内文件、不热补丁 droidloom 二进制（`PITFALLS` 里同类做法已证不可行）。

---

## 4. 与本轮其它修复的关系

- **键盘整轮唤不出**（上一轮症状）的叠加因素已排除并修好：`phosh-osk-stub` 曾丢失 well-known 名 `sm.puri.OSK0`（phosh 报 `Unable to toggle OSK: … not provided by any .service files`），重启后由 pid 149969 持有；但**它只解释「整轮不响应」**，不解释本轮「输入一个字符后缩回」。
- 小红书**全屏**修复（`window-policy-v1.json` per-app 覆写）与 cell **联网**修复（nft DNS 重定向 + captive-portal 探针 + 解禁 `Droidloom` 网络）与本 bug 无关，均已生效（`dumpsys connectivity` = `VALIDATED`，`adb` 端点 `device:droidloom`）。


---

## 5. 已绕开（同日晚，lane D6 实测）

- 给 cell 装了 **Fossify Keyboard v1.9.1**（`org.fossify.keyboard_14.apk`，F-Droid 官方源，sha256 `e326885c08b68212fd9fdda9be8a4fa492d5daba7ff37bb4ff4511826f40a8d0`），默认 IME 切到 `org.fossify.keyboard/.services.SimpleKeyboardIME`，**占位器保留未禁用**。
- 验收：三轮「点框-输入-失焦-再点」9 张截图全过、`mInputShown=true` 6/6、字段累积 `113→333`、切换后 `onFailed at PHASE_IME_ON_SHOW` = 0。详见 `reports/droidloom-real-ime-20261126.md`。
- **根因仍未根治**（属 D24 范围）；D24 首轮补充一条候选解释：宿主合成器可能缺 `denial_text_input_panel_manager_v1`（`wayland-info | grep -c denial_text_input_panel` = 0 即为该假设的判据之一），与「占位 IME 状态机缺陷」并列，**尚未判定哪一个是主因**。
