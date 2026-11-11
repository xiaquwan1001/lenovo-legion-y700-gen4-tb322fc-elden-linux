# OSK 不弹的真根因：不是 phoc，是 `GTK_IM_MODULE=fcitx` —— Firefox 实测收口（2026-11-11 晚）

- 线：G1-37 / C11「点输入框 OSK 不弹」，用户 2026-11-11 晚现场报「**Firefox 搜索栏点输入框依然弹不出键盘**」。
- 设备：在机 `7.3.1-debug-vk184-00002-g4da9a8b69fc8`，`boot_b` sha `8ab357ed…`（本轮零写盘、未重启）。
- 前置：phoc 版本门已在同日 19:20 修好并上机（`phoc-0.58.0-syncobj-osk`，sha `cbfaa59a…`，`PITFALLS #615`）。
- 结论级别：**上机实测 + A/B 单变量**，截图目视确认（`reports/artifacts/ime-osk-firefox-20261111.png`）。

---

## §0 结论（先看这 6 行）

| 问题 | 结论 | 判据 |
|---|---|---|
| **phoc 修完后 OSK 链路通不通？** | **通**。同一套 phoc + stevia，客户端只要走 text-input-v3，`enable()` → OSK `Visible=true` 100% 复现 | GTK3 `env -u GTK_IM_MODULE -u QT_IM_MODULE` 臂：`get_text_input=1 enable=1 mid Visible=(<true>,)`；关窗回 false |
| **那为什么 Firefox 不弹？** | **`GTK_IM_MODULE=fcitx`（本机 `/etc/environment` 全局设置）** ⇒ GTK 走 fcitx 的 DBus IM 前端（`im-fcitx5.so`），**根本不向 phoc 请求 `zwp_text_input_v3`** ⇒ phoc 没有 activate 可发 ⇒ OSK 不动 | Firefox 三臂 A/B（§2）：`GTK_IM_MODULE=fcitx` / 未设 / `GTK_IM_MODULE=wayland`；只有第三臂 `Visible=(<true>,)` |
| **GTK 测试窗之前为什么能弹？** | 之前那次是 `env -u GTK_IM_MODULE` 起的（`reports/ime-osk-pop-20261111.md` §2 原文），**不是默认会话环境** | 本轮同法复现 E4；改用默认环境（`GTK_IM_MODULE=fcitx`）后 `get_text_input=0` |
| **有没有既保中文、又能弹键盘的解？** | **有，且已上机验证**：保留 fcitx 链路，用 **`elden-ime-focusd` 的 kimpanel 桥**把「有输入框获得焦点」翻译成 `sm.puri.OSK0.SetVisible(true)`；收起用 **`org.fcitx.Fcitx.Controller1.State` 0↔1** | §3/§4：GTK3 + Firefox 两臂都弹；关窗 2 s 内自动收起 |
| **"fcitx5 没有可靠 FocusOut 信号"这条旧结论？** | **推翻**。`org.fcitx.Fcitx.Controller1.State` 实测 `idle=0 / focused=1 / after close=0`，精确跟随焦点 | §4 原始输出 |
| **还剩什么？** | 中文**组词上屏**仍需真人触摸（agent 合成键是字面量）；XWayland/原生 X11 客户端、Qt 应用未验 | §6 |

> **对 `PITFALLS #615` 的定位不变但需补一句**：phoc 的版本门是真缺陷（挡住所有走 text-input-v3 的客户端），修它是对的；
> **但本机默认环境下的常见客户端（GTK3 全系 + Firefox）压根不走那条路**，所以「修完 phoc 就能弹」这个预期不成立。

---

## §1 环境与协议面（原始输出）

```
phoc    = /usr/bin/phoc sha256 cbfaa59adf34c929892229f241073747b624f07c17a98b59f4e50f2d0c3cb71f（19:20，含 OSK 版本门补丁）
stevia  = /usr/bin/phosh-osk-stevia --allow-replacement（pid 135492，owns sm.puri.OSK0）
fcitx5  = /usr/bin/fcitx5 -r --disable waylandim（pid 124897）
phosh   = phosh 0.59~alpha1 / gtk 3.24.52-3 / gtk4 4.24.1

wayland-info（GUI 用户）:
  interface: 'zwp_input_method_manager_v2', version: 1, name: 23
  interface: 'zwp_text_input_manager_v3',  version: 2, name: 24

/etc/environment（PAM 注入到每个会话进程）:
  GTK_IM_MODULE=fcitx
  QT_IM_MODULE=fcitx
  XMODIFIERS=@im=fcitx
```

`/etc/environment` 是 **PAM `pam_env`** 注入的 ⇒ `sudo -u USER` 也会带上；只有 `env -u ...`（在 sudo **之后**）才能清掉。
这一点是上一轮「E4 能弹、默认环境不弹」被误读的直接原因。

---

## §2 决定性 A/B：客户端的 IM 前端决定了走哪条协议

Firefox 159.0.1（`/usr/lib/firefox/firefox`，默认 Wayland 后端 + GTK3），`WAYLAND_DEBUG=1`，
新 profile，`file:///home/xuqianhui1001/ffprobe.html`（`<input autofocus>`）：

| 臂 | 环境 | `get_text_input` | `enable()` | OSK `Visible` |
|---|---|---|---|---|
| **A** | `GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx`（**默认**） | **0** | **0** | `(<false>,)` |
| **B** | 同上 + `MOZ_ENABLE_WAYLAND=1` | 0 | 0 | `(<false>,)` |
| **C** | 三个变量都不设 | 0 | 0 | `(<false>,)` |
| **D** | **`GTK_IM_MODULE=wayland`** | **1** | **1** | **`(<true>,)`** |
| **E** | `GDK_BACKEND=wayland GTK_IM_MODULE=wayland` | 1 | 1 | `(<true>,)` |

`fx` 侧原始判据（A/C 臂都只看到 global、从不 bind）：
```
{Default Queue} wl_registry#2.global(24, "zwp_text_input_manager_v3", 2)   ← 只看见 global
（全程无 get_text_input / zwp_text_input_v3#N.enable）
```

**GTK3 对照（同一机制、更小变量面）**：

| 臂 | 环境 | `get_text_input` | `enable()` | OSK `Visible` |
|---|---|---|---|---|
| GTK3 | `GTK_IM_MODULE=fcitx` | 0 | 0 | `(<false>,)` |
| GTK3 | `env -u GTK_IM_MODULE -u QT_IM_MODULE -u XMODIFIERS` | 1 | 1 | **`(<true>,)`** |
| GTK4 | `GTK_IM_MODULE=fcitx` | 0 | 0 | `(<false>,)` |
| GTK4 | 同上清空 | — | — | （GTK4 无 Entry 用例，仅收 global） |

⇒ **判据链完整**：phoc（修后）能接住 `enable()`，但 `GTK_IM_MODULE=fcitx` 让 GTK **不发** `enable()`。
两者是**串联**关系，任一处断都表现为「键盘不弹」，此前只修了前一处。

**机制层**（静态可核）：`GTK_IM_MODULE` 是 GTK 的 IM 模块选择器；取值 `fcitx` 时加载
`/usr/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/im-fcitx5.so`，输入事件走 DBus
（`org.fcitx.Fcitx5`）而不是 Wayland `zwp_text_input_v3`。实测 Firefox A 臂进程 maps 里有
`im-fcitx5.so` + `libFcitx5GClient.so.5.1.7`（C 臂同样加载，因为 GTK 会用环境里第一个可用 module，
但 F 臂 `-u` 后被 PAM 塞回——见 §1 的注意事项）。
`GTK_IM_MODULE=wayland` 则强制 GTK 用自带的 Wayland IM 后端 ⇒ 走 text-input-v3 ⇒ phoc → stevia → OSK。

---

## §3 处置方案（已落地）：focusd kimpanel 桥

**为什么不是「改 `GTK_IM_MODULE=wayland`」**：那样 GTK 客户端的中文输入要靠 phoc 的
`zwp_input_method_v2` 转发给 stevia；而 stevia 的**组词能力**未验证，且 2026-11-11 白天已确认
stevia 侧 `handle_activate` 只在 phoc 转发后才有——换这条路等于把「已验证可用的 fcitx/Rime 中文」
换成「未验证的 stevia 组词」。**风险不对称 ⇒ 保留 fcitx，补一条唤起通路**。

**桥的工作原理**（`patches-userland/zh-ime/elden-ime-focusd.c`）：
- 以 `org.kde.impanel` owner 身份注册最小 kimpanel panel 桩（`/org/kde/impanel`，`org.kde.impanel2`）；
- fcitx5 的 `libkimpanel.so` 在**输入上下文 FocusIn / 光标矩形变化**时调用 `SetRelativeSpotRect`
  ⇒ 收到即 `sm.puri.OSK0.SetVisible(true)`（400 ms 去抖 + 先查 `Visible` 幂等）；
- 收起：**本轮新增**，1 s 轮询 `org.fcitx.Fcitx.Controller1.State`，回到 **0** 即 `SetVisible(false)`。

**kimpanel 桩实测（`probes/ime/kimpanel-probe.py`，本轮新建）**——先证明信号真的存在，再做产品化：
```
CALL[1] org.kde.impanel2.SetRelativeSpotRect (0, 0, 0, 0)          ← fcitx5 启动/上下文建立
CALL[2] org.kde.impanel2.SetRelativeSpotRect (27, 114, 0, 2781)    ← GTK3 Entry 拿到焦点
```
⇒ 旧注释里「`Enable` 反而不发」正确，但 `SetRelativeSpotRect` **每次都来**，可作触发信号。

---

## §4 上机验证（本轮实测，含截图）

**构建与部署**：
```
bash packaging/elden-userland/build/elden-ime-focusd.sh
  → out/ime-host/elden-ime-focusd   sha256 782f79e4542507fddbbe6116bb1eb1739ef6ee88aef5cc06141b6e2a45207f8f
     （arm64 glibc 动态，BuildID f600691d，在 /opt/elden/arm64-sid chroot 内编）
install -m755 → /usr/local/bin/elden-ime-focusd（设备读回同 sha）
install -D -m644 → /etc/xdg/autostart/elden-ime-focusd.desktop（登录自启）
```
**门禁**：`packaging/elden-userland/tools/verify.sh --rebuildable` → `FAIL=0 WARN=0`，`elf=7 ok=7 missing=0`。

**T1 — GTK3 Entry（默认 fcitx 环境）**
```
pre=(<false>,)
mid=(<true>,)        ← 焦点进入 1 s 内弹出
post=(<false>,)      ← 关窗 2 s 内自动收起
focusd log:
  show requested by SetRelativeSpotRect
  SetVisible(1)
  hide requested by fcitx State=0
  SetVisible(0)
```

**T2 — Firefox 159.0.1 搜索/页面输入框（用户现场现象）**
```
Visible=(<true>,)     ← 弹了
firefox maps 含 /usr/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/im-fcitx5.so
focusd log: show requested by SetRelativeSpotRect / SetVisible(1)
截图 reports/artifacts/ime-osk-firefox-20261111.png：Firefox 窗口 + 底部 stevia 键盘（English US 布局，含 123/地球/回车）
```
> 注：截图键盘是 **English (US)** 布局而不是 Rime 候选条——因为该 profile 是全新空 profile，
> 且 stevia 只负责「出键盘」，中文候选由 fcitx5 的 GTK IM 模块在**回退到 DBus 路径**时提供。
> 组词上屏是否成立仍需真人敲一次（§6）。

**T3 — 自动收起的独立信号验证**
```
idle:        (0,)
focused:     (1,)
after close: (0,)
```
（`org.fcitx.Fcitx.Controller1.State`，三次采样，精确跟随焦点，无抖动）

---

## §5 被本轮推翻/收紧的旧结论

1. **「phoc 版本门修好后点输入框就该弹」** → 不成立。对**默认 fcitx 环境下的 GTK3/Firefox** 无效，
   因为它们根本不发 `text_input_v3.enable`。`PITFALLS #615` 的机制描述仍正确，但**作用域**要收窄为
   「只影响 `GTK_IM_MODULE=wayland` 或原生 Wayland IM 客户端」。
2. **「fcitx5 没有 FocusOut 的可靠信号 ⇒ focusd 只负责唤起、不负责收起」**（`elden-ime-focusd.c` 原头注释）
   → 错。`org.fcitx.Fcitx.Controller1.State` 0↔1 就是可靠信号，本轮已产品化。
3. **「E4 抓包里客户端发了 enable ⇒ 说明默认环境会发」** → 该抓包是 `env -u GTK_IM_MODULE` 起的，
   不代表默认会话。本轮用默认环境重跑，`get_text_input=0`。

---

## §6 未闭环 / 边界

1. **中文组词上屏**：仍需真人手指在 OSK 上敲（agent 用 `wtype`/uinput 合成的是字面量，不触发 IM）。
   判据：点输入框 → 键盘弹 → 敲 `nihao` → 出候选 → 选 1 上屏「你好」。
2. **Rime 候选窗位置**：fcitx5 的候选窗由 GTK IM 模块自绘（`fcitx5-frontend-gtk3`），
   与 stevia 键盘会重叠；需真人看一次是否压住键盘。若无解，退路 = 给 fcitx5 配
   `kimpanel` 前端让 focusd 同时充当候选窗（本轮未做）。
3. **XWayland / 原生 X11 客户端**：本机当前无 Xwayland 进程，未验。
4. **Qt 应用**：`libfcitx5-qt6-1` 已装、`fcitx5-qt` 未装；未验。
5. **登录后自启**：`/etc/xdg/autostart/elden-ime-focusd.desktop` 已装，但**本轮未重启桌面会话验证**
   （`PITFALLS` 的教训：autostart 要重启一次才算数）。判据 = 重启后 `busctl --user list | grep -c org.kde.impanel` = 1。

---

## §7 复现命令（全部在本仓）

```bash
# 1) 证明 phoc 侧通（客户端强制走 wayland IM）
ssh root@192.168.7.1 'env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
  GTK_IM_MODULE=wayland setpriv --reuid=1001 --regid=1001 --init-groups \
  WAYLAND_DEBUG=1 python3 /tmp/e7-gtk3.py 2>&1 | grep -c get_text_input'

# 2) 证明 fcitx 环境不发 text_input（默认环境）
#    同上但 GTK_IM_MODULE=fcitx  → 期望 0

# 3) kimpanel 信号存在性
scp probes/ime/kimpanel-probe.py root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'sh /tmp/kp-run.sh'      # 见 reports 的 §3 原始输出

# 4) focusd 唤起 + 收起
scp patches-userland/zh-ime/... ; sh /tmp/e10-autohide.sh
```
