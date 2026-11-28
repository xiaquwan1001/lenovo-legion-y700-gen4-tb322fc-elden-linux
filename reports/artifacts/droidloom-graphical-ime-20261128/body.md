**Summary**

When a *graphical* Android IME (a normal on-screen keyboard such as Trime or Fossify Keyboard) is the selected input method, Android believes the IME is visible — `mInputShown=true`, `mImeWindowVis=3`, and `adb exec-out screencap` shows the keyboard — but nothing is ever drawn on the **host**: `grim` shows only the app window and `wlrctl toplevel list` has no IME/OSK surface. The only configuration that produces a usable keyboard is the bundled headless IME `com.android.droidloom.ime/.HostInputMethod` plus the host's on-screen keyboard.

I could only find this stated in the source (`docs/architecture.md`, "Droidloom's headless input method never shows a window"), not in the user-facing docs, and a user selecting a third-party keyboard has no way to know why the keyboard disappears. If presenting Android IME windows is out of scope, could the documentation (and ideally the IME picker/doctor) say so?

**Environment**

- Lenovo Legion Y700 Gen4 (`TB322FC`, SM8750), aarch64
- Debian 13 (trixie), phoc/phosh 0.46
- `droidloom-{runtime,image,base}` 0.1.0-51 (installed over 0.1.0-49, additive)
- cell: `Android is ready`; `droidloomctl launch` works

**Steps to reproduce**

1. Select any graphical IME, e.g.
   ```
   adb shell ime set com.osfans.trime/.ime.core.TrimeInputMethodService
   # or org.fossify.keyboard/.services.SimpleKeyboardIME
   ```
2. Launch an app with a text field and tap it:
   ```
   droidloomctl launch com.android.settings
   adb shell input tap 985 283
   ```
3. On the Android side everything looks correct:
   ```
   $ adb shell dumpsys input_method | grep -E 'mCurImeId|mInputShown|mImeWindowVis'
         mCurImeId=com.osfans.trime/.ime.core.TrimeInputMethodService
         mImeWindowVis=3
         mInputShown=true
   ```
   and `adb exec-out screencap -p` contains the full keyboard in the Android frame buffer.
4. On the host side there is no keyboard:
   ```
   $ grim /tmp/host.png          # app window only, the bottom area is empty
   $ wlrctl toplevel list
   com.android.settings: Settings
   ```
   Same result with Fossify Keyboard, so it is not specific to one IME.

**What works**

```
adb shell ime set com.android.droidloom.ime/.HostInputMethod
```
then tapping the field shows the host OSK (phosh-osk-stub) and typing is delivered into the Android editor. In my test the host OSK used its RIME completer and committing a pinyin candidate inserted the Chinese text into the Android app, so the headless path is fully usable for CJK input as well.

**Why this happens (from the 0.1.0-51 source)**

- `docs/architecture.md`, section "On-screen keyboard": "Android's own IME source is untouched; Droidloom's headless input method never shows a window."
- `android/framework/droidloom-ime/src/com/android/droidloom/ime/HostInputMethod.java:21`: `/** No Android keyboard window: the host owns the input panel. */`, and `onShowInputRequested()` returns `false` by design.
- `graphics/droidloom-wayland/src/text_input.rs` bridges the headless IME to `zwp_text_input_v3` and forwards commits to Android.
- So a graphical IME's window lives only in the Android compositor and is never mapped as a host surface.

**Also relevant to #65**

With `HostInputMethod` selected, the host OSK *does* appear on this setup, and the logcat line `ImeTracker: … onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` still shows up (expected, because `onShowInputRequested()` returns false and the host panel takes over). So that log line alone does not mean "no keyboard"; on 0.1.0-51 I could not reproduce "no keyboard is drawn" with the headless IME.

**Asks**

1. Document in the user-facing IME/keyboard docs that only the headless host-OSK path is supported, and that selecting a graphical Android IME results in no visible keyboard.
2. If graphical IMEs are meant to be supported eventually, present the Android IME window as a host surface (or an overlay inside the task surface).
3. Optionally, make `droidloom-doctor` (or a log warning) flag "selected IME is not the bundled headless one" so the failure is diagnosable.

Happy to test patches on this device.

---
Filed with AI assistance (LLM-drafted, human-reviewed; all commands, logs and screenshots above were produced and checked by the author on the device).
