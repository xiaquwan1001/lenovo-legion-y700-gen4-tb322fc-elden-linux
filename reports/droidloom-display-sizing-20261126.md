# droidloom 小红书「画面不全 / 同意弹窗被截断」定位（2026-11-26，父代理上机）

> 用户 2026-11-26 报：「小红书的 app 占用画面不全，而且政策同意以便允许 app 运行的弹窗被截断，无法进入 app」，随后追加「现在内部 UI 居中了，但屏幕依然没有占满」。
> 本文件 = 父代理自己在设备锁下做的定位与已改动的项；**结论未收口**（卡在 lane S2 的 `fastboot boot` 窗口内，cell 已停）。

---

## 1. 一页结论

| 项 | 实测值 | 判读 |
|---|---|---|
| 面板 | `1904x3040`（`/sys/class/drm/card0-DSI-1/modes`、`wlr-randr` 首选） | — |
| phoc 输出 scale | **1.0**（`wlr-randr` 无 scale 行、`gsettings scaling-factor`=0、`text-scaling-factor`=1.0） | 逻辑输出 = 1904x3040 |
| Android 侧显示 | `init=1904x3040 213dpi  cur=1904x3040  app=1904x3040`（`dumpsys window displays`） | **Android 自己认全屏**，不是 Android 把屏缩小了 |
| 小红书任务 | `mWindowingMode=**freeform**`、`mBounds=Rect(119,190 - 1559,2590)` = **1440x2400**（屏的 75.6% × 78.9%） | **根因层 1**：App 被塞进桌面浮动窗，只有四分之三屏 |
| host 侧 Wayland 窗 | `droidloom-wayland: composition targets … configure=1 size=480x800 → configure=2 size=**1440x2400**` | **根因层 2**：droidloom **把 Android task bounds 当作窗口尺寸**，窗口永远等于 task 大小，所以「Android 全屏」也救不了 |
| dpi | 原 213（=1430 dp 宽，被当平板）→ 已改 **690**（Android 现报 `414dp` 宽手机档） | 已生效（`cmd window density` = 736/690 覆盖值） |

**一句话**：不是分辨率、不是缩放，是 **Android 的 freeform 任务窗口尺寸（1440x2400）被 droidloom 原样映射成 Wayland 窗口**；UI「居中」= droidloom 把这块 1440x2400 的内容放在整屏中央，四周留黑。

---

## 2. 已做的改动（全部设备锁内，可回退）

| # | 命令 | 结果 | 回退 |
|---|---|---|---|
| 1 | `droidloomctl window-mode fit-output` | 本来就是 `fit_output`（证明不是这个的锅） | — |
| 2 | `droidloomctl dpi 736` → `dpi 690`（**以用户 1001 身份**写 `~xuqianhui1001/.config/droidloom/density-v1.json`） | Android `Override density: 736/690` 生效；`dumpsys` 报 `w414dp h661dp 690dpi` | 删该 json 或重设回 213 |
| 3 | `droidloomctl window-mode windowed --width 1904 --height 3040 --json` | 持久化成功（`~xuqianhui1001/.config/droidloom/window-policy-v1.json` 里 `height=3040`），但 **configure 仍是 1440x2400** ⇒ 该策略只作用于「无尺寸的初始 configure」，被 Android task bounds 覆盖 | 同上 |
| 4 | `cmd activity task resize 11 0 0 1904 3040`（cell 内） | **有效**：`dumpsys` 当前配置变 `mBounds=Rect(0,0 - 1904,3040) mWindowingMode=freeform`（旧值只剩 `mLastReported`） | 再 resize 回 119,190,1559,2590 |
| 5 | `droidloomctl restart`（以用户身份） | cell 重启正常（`Android is ready`），但新任务又回到 1440x2400 | — |

> ⚠ 权限坑（本轮踩到）：以 **root** 跑 `droidloomctl` 会把策略写进 `/root/.config/droidloom/`，而 cell 服务跑在 **用户 1001** 下、只读 `~xuqianhui1001/.config/droidloom/` ⇒ **必须 `sudo -u xuqianhui1001` + `XDG_RUNTIME_DIR=/run/user/1001`** 才持久。

---

## 3. 未做的决定性实验（等 lane S2 让出设备）

设备现被 lane S2 的试验核占着（`7.3.1-debug-vk189-suspend-fastrpc1-g4da8b69fc8-dirty`，`fastboot boot` 零写盘；cell 未在该核下自启）。设备锁释放后按序做，每步记 `dumpsys window windows | grep -oE "mBounds=Rect\([^)]+\)"`：

1. **关掉强可调整窗口**（最可能一次到位）：cell 内 `cmd settings put global force_resizable_activities 0`；再 `freeform` 支持：
   `cmd settings put global development_enable_freeform_windows_support 0` / `enable_freeform_support 0`（先 `get` 现值记档），然后 `droidloomctl restart` + 重开小红书。
   判据：`mWindowingMode=fullscreen`、`mBounds=Rect(0,0 - 1904,3040)`、`droidloom-wayland` configure = **1904x3040**。
2. 若 1 无效：保持 freeform，但在 `droidloomctl window-mode windowed --width 1904 --height 3040` 基础上，**每次 launch 后 `task resize`**（可包一个 wrapper）；或查 droidloom 是否支持 per-app 尺寸（`window-policy-v1.json` 里有 `applications: {}` 映射，说明**按包名覆写是设计内的**）。
3. 若 1 把 cell 弄坏：回滚两条 settings + restart（droidloom 的 `KNOWN_ISSUES` 明说 revision 7 起强制 `force_resizable` 以让不可调整的 App 进桌面窗，所以关掉它可能让部分 App 起不来 —— 这是已知代价）。

**持久化要求**：无论哪条生效，都必须落到「开机自启后仍生效」的位置（`~xuqianhui1001/.config/droidloom/*` 或 `deploy-desktop-shell.sh` 新增节），否则下次重启回退。

---

## 4. 与上游的关系（可提 issue）

`denialwm/droidloom` 的 `KNOWN_ISSUES.md` 只写了「revision 7 起强制 force-resizable，让不可调整窗口的 App 进桌面窗口模式；**不保证每个 App 能正确处理任意窗口尺寸**」。
我方现象是它自己把 Android task 的 1440x2400 原样映射成窗口、且**不提供 per-app 全屏开关**（`window-mode` 只有 fit-output / windowed 两档，windowed 用全局 W/H）⇒ 值得提一条 issue：「per-app fullscreen / per-app explicit size 缺失；默认 freeform bounds 会把手机 App 的同意弹窗截断」。
