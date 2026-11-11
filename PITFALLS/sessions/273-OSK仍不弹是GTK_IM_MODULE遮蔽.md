# #618 修好 phoc 版本门后 Firefox/GTK **仍不弹**：`GTK_IM_MODULE=fcitx` 让客户端根本不发 text-input-v3

> 索引行见 `PITFALLS/README.md` 第 273 行。首次取证：2026-11-11 晚（用户现场报「Firefox 搜索栏点输入框弹不出键盘」）。
> 权威报告 `reports/ime-osk-firefox-rootcause-20261112.md`；前置 #615 见 `sessions/270-OSK不弹是phoc版本门.md`。
> 新增探针 `probes/ime/kimpanel-probe.py`。

## 现象

- 2026-11-11 19:20 已把 phoc 的版本门补掉并上机（`phoc-0.58.0-syncobj-osk`，sha `cbfaa59a…`，`#615`）。
- 用户在 **Firefox 搜索栏 / 页面输入框** 点进去，**键盘仍不弹**。
- 同一台设备上，`GTK_IM_MODULE=wayland` 或 `env -u GTK_IM_MODULE` 起的 GTK 测试窗**能弹**（`Visible=(<true>,)`）。

## 真机制（两层串联，此前只修了后一层）

客户端收到 `enter` 之后必须**自己发** `zwp_text_input_v3.enable()`；而**发不发**由 GTK 的 IM 模块决定：

| `GTK_IM_MODULE` | GTK 输入通路 | 发 `text_input_v3.enable`? | phoc 修后 OSK 弹? |
|---|---|---|---|
| **`fcitx`**（本机 `/etc/environment` 默认） | 加载 `im-fcitx5.so` → DBus `org.fcitx.Fcitx5` | **否** | **不弹** |
| 未设 / `env -u` | GTK 自带 Wayland IM 后端 | 是 | 弹 |
| `wayland` | 强制 GTK 自带 Wayland IM 后端 | 是 | 弹 |

⇒ `#615`（phoc 版本门）与本题是**串联**关系：门修好了，客户端却压根没走这条路。

## 判据（决定性 A/B，各有原始输出）

Firefox 159.0.1，`WAYLAND_DEBUG=1`，`<input autofocus>`：

| 臂 | `get_text_input` | `enable()` | OSK `Visible` |
|---|---|---|---|
| `GTK_IM_MODULE=fcitx`（默认） | **0** | **0** | `(<false>,)` |
| 同上 + `MOZ_ENABLE_WAYLAND=1` | 0 | 0 | `(<false>,)` |
| 不设三个 IM 变量 | 0 | 0 | `(<false>,)` |
| **`GTK_IM_MODULE=wayland`** | 1 | 1 | **`(<true>,)`** |
| `GDK_BACKEND=wayland GTK_IM_MODULE=wayland` | 1 | 1 | `(<true>,)` |

GTK3 对照：`GTK_IM_MODULE=fcitx` → 0/0/false；`env -u GTK_IM_MODULE -u QT_IM_MODULE -u XMODIFIERS` → 1/1/**true**。

**两个必须知道的坑**：

- **`/etc/environment` 是 `pam_env` 注入的** ⇒ `sudo -u USER` 也会带上；
   只有 `sudo -u USER env -u GTK_IM_MODULE ...`（`env` 在 `sudo` **之后**）才清得掉。
   上一轮 `reports/ime-osk-pop-20261111.md` §2 的「客户端发了 enable」就是 `env -u` 起的，**不代表默认会话**。
- 判据**必须**看 `get_text_input`/`enable()` 计数，不能只看「窗口有没有焦点」——
   `wl_keyboard.enter` 在两条臂都正常（grab_focus 有效），差别只在 IM 协议面。

## 处置（已落地并上机验证）

**不换 `GTK_IM_MODULE=wayland`**（那会把已验证的 fcitx/Rime 中文换成未验证的 stevia 组词，风险不对称），
而是**保留 fcitx 链路 + 补一条唤起通路** = `elden-ime-focusd` 的 kimpanel 桥：

- fcitx5 的 `libkimpanel.so` 在 FocusIn / 光标矩形变化时**稳定调用** `org.kde.impanel2.SetRelativeSpotRect`
  （本轮用 `probes/ime/kimpanel-probe.py` 实测：`(0,0,0,0)` 跟 `(27,114,0,2781)` 两次，`Enable` 确实不发）；
- 收到即 `sm.puri.OSK0.SetVisible(true)`（400 ms 去抖 + 先查 `Visible` 幂等）；
- **收起**（本轮新增）：1 s 轮询 `org.fcitx.Fcitx.Controller1.State`，回到 **0** 即 `SetVisible(false)`。
  ⇒ 旧头注释「fcitx5 没有可靠 FocusOut 信号」**是错的**，实测 `idle=0 / focused=1 / after close=0`。

上机判据（全部通过，截图 `reports/artifacts/ime-osk-firefox-20261111.png`）：
```
GTK3 Entry（默认 fcitx 环境）:  focus → Visible true ；关窗 2 s 内 → false
Firefox 页面输入框（默认环境）: Visible true ；ff maps 含 im-fcitx5.so
focusd log: show requested by SetRelativeSpotRect → SetVisible(1) → hide requested by fcitx State=0 → SetVisible(0)
```

## 未闭环

- **中文组词上屏**仍需真人手指敲（agent 合成键是字面量）。
- fcitx5 候选窗与 stevia 键盘可能重叠（候选窗由 `fcitx5-frontend-gtk3` 自绘），需真人目视一次；
  退路 = 让 focusd 兼作 kimpanel 候选窗。
- 登录后 autostart **未重启验证**（判据 `busctl --user list | grep -c org.kde.impanel` = 1）。
- XWayland / Qt 客户端未验（本机当前无 Xwayland 进程，`fcitx5-qt` 未装）。
