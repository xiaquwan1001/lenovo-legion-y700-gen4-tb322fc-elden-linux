## Summary

On a Debian/aarch64 host (phoc/phosh Wayland session), the built-in placeholder IME
(`com.android.droidloom.ime/.HostInputMethod`) never manages to report "soft input shown":
the application keeps asking for the keyboard, `ImeTracker` always ends with
`onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`, and no keyboard is drawn. The pool of
characters typed via `input text` lands in the field, but a human has no on-screen keyboard
at all. Installing a third-party IME (Fossify Keyboard) works around it entirely.

Reproduced on **both** `0.1.0-49` and `0.1.0-51`.

## Environment

- Droidloom: `0.1.0-49` (first seen) and `0.1.0-51` (re-tested today; package `droidloom-image` + `droidloom-runtime`, `droidloom-base=0.1.0-49`)
- Host: aarch64, Debian trixie, kernel 7.3.1 mainline, phoc 0.59~rc1 + phosh, `phosh-osk-stub` running
- Cell: `aosp_cf_arm64_only_phone`, Android 17, `droidloomctl doctor` = READY (0 blockers)
- Devices touched: Settings search field (system app) and a third-party app; same result

## Steps to reproduce

```sh
# 1. make the placeholder IME the default one
adb shell ime set com.android.droidloom.ime/.HostInputMethod
adb shell settings get secure default_input_method   # com.android.droidloom.ime/.HostInputMethod

# 2. open any app with a text field, e.g.
droidloomctl launch com.android.settings

# 3. tap the search field (coordinates for a 1904x3040 panel)
adb shell input tap 950 330
```

## Observed (0.1.0-51, Android UTC 12:39:46)

```
I ImeTracker: com.android.settings.intelligence:... onRequestShow at ORIGIN_SERVER reason SHOW_AUTO_EDITOR_FORWARD_NAV fromUser false userId 0 displayId 0
I ImeTracker: com.android.settings.intelligence:... onFailed at PHASE_SERVER_UPDATE_CLIENT_VISIBILITY
I DroidloomIME: finish input
I DroidloomIME: start input restarting=false editable=true
I DroidloomIME: show request configChange=false
I ImeTracker: system_server:... onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE
I ImeTracker: com.android.settings.intelligence:... onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser true
I ImeTracker: com.android.settings.intelligence:... onCancelled at PHASE_CLIENT_REPORT_REQUESTED_VISIBLE_TYPES
```

- `dumpsys input_method` on 0.1.0-51: `mInputShown=true` (on 0.1.0-49 it stayed `mInputShown=false`);
  either way **nothing is drawn** — a host-side screenshot (`grim`) shows no keyboard, and
  `wlrctl toplevel list` contains only the app window, no OSK toplevel, although `phosh-osk-stub` is alive.
- On 0.1.0-49 the same tap produced additionally `DroidloomIME: start input restarting=true` and
  `RemoteInputConnectionImpl: Session id mismatch header.sessionId: 0 currentSessionId: 1`
  (0.1.0-51 samples all show `restarting=false`).
- `dumpsys window` shows the placeholder IME window as `mViewVisibility=0x8 (GONE)`, `mHasSurface=false`,
  `frame` height 0 — consistent with "no window to show", so the `SHOW_SOFT_INPUT_TRUE` phase can never succeed.

## Workaround that works

A real IME inside the cell (e.g. `org.fossify.keyboard`) draws its own window and behaves normally:

```sh
adb shell ime set org.fossify.keyboard/.Services.SimpleKeyboardIME
# after tapping the field: mInputShown=true, dumpsys window shows Window{... InputMethod},
# and 'adb shell input text hello' lands in the field
```

## Why this may not be "by design"

`HostInputMethod.onShowInputRequested()` returning `false` and `onEvaluateInputViewShown()` returning
`false` are clearly intentional (the host is supposed to draw the OSK, cf. #34). What is not covered by
that design is this: with the placeholder IME selected, the **host OSK never appears** either, so the
user gets no keyboard at all rather than a host-drawn one. If the host side is supposed to react to
`zwp_text_input_v3` and draw the OSK, that path does not seem to be reached from the placeholder IME's
`show request`; if it is not supposed to be reached, then selecting the placeholder IME leaves the user
with no input method.

## Question

Is there a recommended configuration for "host draws the OSK" that we are missing (e.g. a host-side
`zwp_text_input_v3` observer, a setting, or a different default IME), or is the `show request` path from
`HostInputMethod` supposed to notify the host and currently does not?

Happy to run further instrumentation (extra `logcat -b all` captures, `wayland-info`, `WAYLAND_DEBUG=1`
on the host compositor, `dumpsys input_method` dumps) if that helps.

---

*Filed with AI assistance (LLM-drafted, human-reviewed; all logs and commands above were produced and
reproduced by me on my own hardware).*
