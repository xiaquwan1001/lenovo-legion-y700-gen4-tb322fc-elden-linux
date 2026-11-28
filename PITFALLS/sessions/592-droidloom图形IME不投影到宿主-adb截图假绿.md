# #753 droidloom 不投影「图形 Android IME」窗口 ⇒ 宿主看不到软键盘；用 `adb screencap` 验键盘 = 假绿

**场景**：2026-11-28 用户报「cell 里点输入框不出键盘」（T32）。当时默认 IME = `com.osfans.trime/.ime.core.TrimeInputMethodService`（T30 于 11-27 设定，验收时用 `adb exec-out screencap` 看到键盘并打出「你好」）。

**三条事实（本机实测 + droidloom 0.1.0-51 源码）**：
- **A. cell 里键盘是好的**：`dumpsys input_method` = `mCurImeId=…trime…`、`mImeWindowVis=3`、`mInputShown=true`；`adb exec-out screencap`（整条 Android display）里 Settings 搜索框 + 朙月拼音键盘完整可见。
- **B. 宿主上什么都不显示**：同一时刻宿主 `grim` 只有 App 窗口，底部全黑；`wlrctl toplevel list` 无 OSK/IME 顶层。换 `org.fossify.keyboard` 同样（`mInputShown=true`、宿主无键盘）⇒ **与具体 IME 无关**。
- **C. 这是架构选择，不是 bug**：droidloom `docs/architecture.md:419`「Android's own IME source is untouched; **Droidloom's headless input method never shows a window**」；`HostInputMethod.java:21`「No Android keyboard window: the host owns the input panel」。图形 Android IME 的窗口只在 Android 合成器里，永远不投到宿主。

**判据（区分「键盘在不在」的层次）**：
- 判「用户能不能看见键盘」**必须用宿主截图**（`grim`）或 `wlrctl toplevel list`，**不能**用 `adb screencap`/`uiautomator`（它们看的是 Android 合成结果）。
- `mInputShown=true` / `mImeWindowVis=3` 只说明 **Android 认为** IME 可见，不代表宿主有画面。
- 想用键盘 ⇒ 默认 IME 必须是 droidloom 的 headless `com.android.droidloom.ime/.HostInputMethod`（宿主 phosh OSK；Android 侧 `onShowInputRequested()` 恒 `return false` 属设计，日志里 `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` 不代表没键盘）。

**一句话**：在 droidloom 里，Android 软键盘的「画面」归宿主所有；把 Trime/Fossify 设成默认 = 键盘只画在 cell 的 framebuffer 里，用户永远摸不到。
