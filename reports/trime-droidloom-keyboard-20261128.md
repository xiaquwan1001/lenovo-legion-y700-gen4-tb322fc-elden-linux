# T32 — Trime 在 droidloom 内「不唤键盘」：取证与层次结论（2026-11-28，上机，纯 adb + 宿主 grim）

- **性质**：只读取证 + 一次默认 IME 切换（secure settings，不动系统分区、不重装 runtime）。
- **设备**：U2 `ssh elden` / `ssh elden-root`；cell = `adb -s 10.177.0.2:5555`（adb 在**设备宿主**上跑，工作站无 10.177.0.0/30 路由）。
- **在机内核** `7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty`；droidloom = 0.1.0-51（cell `Android is ready`）。
- **前置现场**：此前默认 IME = `com.osfans.trime/.ime.core.TrimeInputMethodService`（T30 于 2026-11-27 设定）。

## 0. 一句话结论（层次判定）

**「键盘不出」发生在 droidloom 的宿主投影层，不是 Trime、不是焦点、也不是 IME 抢占。**
图形化 Android IME（Trime 与 Fossify **都复现**）在 cell 内部完全正常（`mInputShown=true`、`mImeWindowVis=3`、IME 窗口 `Window{… InputMethod}` 有真实 surface、`uiautomator`+`screencap` 都能看到键盘），但 **droidloom 从设计上就不把 Android IME 窗口投影到宿主**（`docs/architecture.md:419`「Android's own IME source is untouched; **Droidloom's headless input method never shows a window**」）⇒ 宿主 `grim` 里没有任何键盘，用户摸不到。
改回 droidloom 自带的 headless IME `com.android.droidloom.ime/.HostInputMethod` 后，**宿主 phosh OSK 立即出现且可输入**（用户 2026-11-28 09:1x 真机确认「可以输入了」）。

> **T30 的验收是假绿**：当时用 `adb exec-out screencap`（整条 Android display，包含 IME 图层）判「键盘出现」，而宿主侧从未显示过键盘。见 PITFALLS 新增条目。

## 1. 判据表

| # | 判据 | 结果 | 证据 |
|---|---|---|---|
| ① | Trime 在 cell 内是否真的把键盘画出来 | ✅ 是 | `adb screencap` 1904×3040 全屏图里 Settings 搜索 + 朙月拼音键盘完整可见：`artifacts/t32-droidloom-ime-20261128/cell-display-trime-keyboard.png`；`dumpsys input_method` = `mCurImeId=com.osfans.trime/...`、`mImeWindowVis=3`、`mInputShown=true` |
| ② | 宿主（用户真正看到的）上有没有键盘 | ❌ 没有 | 同一时刻 `grim`（宿主 phosh 合成）只有 Settings 窗口，底部整块黑：`host-trime-no-keyboard.png`；`wlrctl toplevel list` 只有 `com.android.settings: Settings`，无 OSK/IME 顶层 |
| ③ | 换 IME 实现能不能修 | ❌ 不能（与 Trime 无关） | 切 `org.fossify.keyboard/.services.SimpleKeyboardIME` 后同样 `mInputShown=true` / `mImeWindowVis=3`，宿主 grim 仍无键盘：`host-fossify-no-keyboard.png` |
| ④ | `com.android.droidloom.ime` 是否在抢 IME 槽 | ❌ 没有抢 | 默认 IME 一直是 Trime；它只出现在 `enabled_input_methods` 列表里（与 Fossify/LatinIME 并列），`mCurImeId` 从未变成它 |
| ⑤ | 焦点层是否问题 | ❌ 不是 | `mCurrentFocus=…settings.intelligence/…SearchActivity`，`mServedInputConnection` 是 `EditableInputConnection`，`mServedView=SearchView$SearchAutoComplete`；即输入连接已就绪，只差「键盘画面在宿主不可见」 |
| ⑥ | droidloom 设计的输入路径是否可用 | ✅ 可用 | 切 `ime set com.android.droidloom.ime/.HostInputMethod` 后：宿主 `grim` 出现 phosh OSK（`host-hostinputmethod-osk.png`），按键可落进 Settings 搜索框；**用户真机确认可输入** |
| ⑦ | 宿主 OSK 路径下的已知日志噪声 | 🟡 有（不阻塞） | logcat 仍有 `ImeTracker: … onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`（`HostInputMethod.onShowInputRequested()` 按设计 `return false`，改由宿主 panel 接管）；宿主 OSK 照样出现 ⇒ 该行**不能**再当「没有键盘」的判据 |

## 2. 代码层依据（droidloom 0.1.0-51 源码，`~/dl-droidloom-51/src/droidloom`）

- `docs/architecture.md:404-419` §On-screen keyboard：宿主 OSK 是独立 IME source；`KeyboardInset` 只给 Android 一个 inset 高度；
  「Android's own IME source is untouched; **Droidloom's headless input method never shows a window**」。
- `docs/contracts/navigation-insets.md:46` 同口径：「The host's on-screen keyboard is a separate IME source with its own id…」。
- `android/framework/droidloom-ime/src/com/android/droidloom/ime/HostInputMethod.java:21`：`/** No Android keyboard window: the host owns the input panel. */`；
  `onShowInputRequested()` 恒 `return false`（`:47-55`），`onStartInput` 把 `active/task` 发布到宿主 text-input 桥。
- `graphics/droidloom-wayland/src/text_input.rs`（headless IME ↔ `zwp_text_input_v3` 桥）：宿主 OSK 的 commit 只在
  `editor.active && editor.task == focused_task && entered.is_some()` 时启用。

⇒ **结论不是「Trime 坏了」，而是「droidloom 只支持 headless IME + 宿主键盘；任何图形化 Android IME 的窗口都不会出现在宿主」。**

## 3. 复现命令（全部在 `ssh elden-root` 里）

```sh
A="adb -s 10.177.0.2:5555"
# 唤醒 + 解锁（DPMS Off 时 adb/ grim 都是黑图；解锁见 reports/droidloom-upgrade-51-ime-20261127.md §3.1）
ssh elden 'wlr-randr --output DSI-1 --on; sudo -n /usr/local/bin/uinput-touch swipe 952 2800 952 500'
# 起窗口（必须是 droidloomctl，不是 am start：am start 只把 task 拉到 cell 里，droidloom 不建宿主窗口）
ssh elden 'droidloomctl launch com.android.settings'      # ⇒ launched … task=N
# 点搜索框 + 读三层状态
$A shell input tap 985 283
$A shell dumpsys input_method | grep -E 'mCurImeId|mInputShown|mImeWindowVis'
$A exec-out screencap -p > /tmp/cell.png                  # 整条 Android display（会看到键盘）
ssh elden 'grim /tmp/host.png'                            # 宿主实际画面（Trime = 无键盘）
# 对照：切图形 IME / headless IME
$A shell ime set org.fossify.keyboard/.services.SimpleKeyboardIME
$A shell ime set com.android.droidloom.ime/.HostInputMethod
```

⚠️ 两条操作坑（本轮踩到）：
1. **必须在设备宿主上跑 adb**（cell = `10.177.0.2:5555`，工作站没有 10.177.0.0/30 路由）。
2. `am start -a android.settings.SETTINGS` 在 droidloom 下**不会**建宿主窗口（task 存在但 `visible=false`）；必须 `droidloomctl launch`。
   另外 **DPMS Off / 锁屏**时 droidloom 窗口“看着像没起”，先 `wlr-randr --output DSI-1 --on` + 触摸解锁。

## 4. 已落地的设备态（本轮唯一改动）

- `settings get secure default_input_method` = **`com.android.droidloom.ime/.HostInputMethod`**（持久项，重启保持）。
- `enabled_input_methods` 未动（Trime/Fossify/LatinIME 仍 enabled，可随时切回）。
- 未改系统分区、未 `pm clear`、未重装 runtime；`/etc/droidloom/*` 与 `/var/lib/droidloom/users/1001` 原样。

## 5. 残留 / 待裁

| # | 事项 | 判据 | 阻塞 |
|---|---|---|---|
| ① | **中文输入**：宿主 OSK 当前只有 `xkb us`（`gsettings get org.gnome.desktop.input-sources sources` = `[('xkb','us')]`），没有拼音 | 宿主 OSK 能出中文候选 | 需决定：给宿主装中文 IME / 或等 droidloom 支持投影图形 Android IME（上游特性，不是配置） |
| ② | **图形 Android IME 投影**（让 Trime 在 droidloom 里可见） | 宿主 `grim` 出现 Android IME 图层 / 或 droidloom 有对应开关 | 需改 droidloom 源码（架构上明确「never shows a window」）⇒ 属上游 feature request，按 T2 口径只写结论与备料，不自行重编镜像 |
| ③ | `PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` 日志噪音 | 与「键盘是否可见」解耦后不再误判 | 无；已在 PITFALLS 记录 |

## 6. 产物

- 截图：`reports/artifacts/t32-droidloom-ime-20261128/{cell-display-trime-keyboard,host-trime-no-keyboard,host-fossify-no-keyboard,host-hostinputmethod-osk}.png`
- 关联：`reports/droidloom-trime-default-20261127.md`（T30，判据①的“真机出中文”其实是 cell 内 screencap 假绿）、`reports/droidloom-upgrade-51-ime-20261127.md` §2/§3。
