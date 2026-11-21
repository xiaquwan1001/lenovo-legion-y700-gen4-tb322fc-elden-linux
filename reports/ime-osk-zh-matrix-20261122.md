# 「键盘弹出」×「中文组词上屏」×「候选窗」——本栈可行路径决策矩阵（2026-11-22）

> lane 类型：**只读调研**（主机侧 + 上游源码只读）。**未接触设备**（设备在 bootloader，由主会话独占；本轮零 fastboot/adb/ssh/qdl）。
> 不重推既有结论：`TASKS/README.md` G1-38/C11 行、`reports/ime-osk-zero-to-usable-20261121.md`（下称 Z）、
> `reports/ime-osk-lifecycle-20261112.md`（下称 L）、`reports/ime-osk-firefox-rootcause-20261112.md`（下称 F）、
> `PITFALLS #615/#618/#619/#624/#643/#644/#645/#646/#653`。
> 本轮**新增**的是**源码级**证伪/证实（phoc 0.46 vs 0.58、fcitx5 classicui、squeekboard、**phosh-osk-stub 0.46 的 completer 框架**、ibus panel），
> 以及由此得到的**路径矩阵**与**最小方案**。凡未在真机跑过的，一律标 **未验证**。

---

## 0. 一页结论（先数字/判定，后细节）

| # | 结论 | 级别 | 证据 |
|---|---|---|---|
| **C1** | **本栈 phoc 0.46 没有 #615 的那个版本门**（门是 0.58 才出现的）。0.46 的 `handle_text_input_enable()` 直接 `wlr_input_method_v2_send_activate()` + `elevate_osk()`。⇒ 「点输入框必不弹」的**协议层阻塞在现役栈上不存在**；现役栈不弹的**唯一**协议层原因是客户端不发 `enable`（`GTK_IM_MODULE=fcitx` 遮蔽，`#618`） | 源码静态，确定 | phoc `v0.46.0` `src/input-method-relay.c:224-243`（无 `SINCE_VERSION` 判断、无 `show_input_panel` 监听）vs `v0.58.0` 同文件 `:255-262`（有门）|
| **C2** | **`GTK4_IM_MODULE` 这个变量不存在**。GTK4 与 GTK3 都只读 `GTK_IM_MODULE`（源码只有一处 `g_getenv ("GTK_IM_MODULE")`）。写 `GTK4_IM_MODULE` 是 no-op | 源码静态，确定 | GTK4 `gtk/gtkimmodule.c:207`；GTK3 `gtk/gtkimmodule.c:843` |
| **C3** | **fcitx5 classicui 在本栈结构性画不出候选窗**：其 Wayland UI 只认 `zwp_input_panel_v1` 全局来建输入面板；phoc 的 `protocols/` 里**没有**这份 XML（`input-method-unstable-v2` 有、`input_panel` 没有，v0.46.0 与 main 同）。⇒ 无论 phoc 升到哪版、focusd 怎么转数据，classicui 都无窗 | 源码静态，确定 | fcitx5 `src/ui/classic/waylandui.cpp:26,43,74`；`waylandinputwindow.cpp:113-120`（`createWindow` 依赖 panel）；phoc `protocols/` 目录清单（无 `zwp_input_panel_v1.xml`）|
| **C4** | **现役 OSK（`phosh-osk-stub` 0.46）本身就是一个完整 IM 客户端 + 自带候选条 + 可插拔候选引擎**：它持 `zwp_input_method_v2`，能 `commit_string` / `set_preedit_string` / `delete_surrounding_text`；候选条画在**它自己的 layer surface 内**（`pos-completion-bar.c`），不会像 `#646` 那样 map/unmap 独立窗口；候选引擎可通过 GSettings 换成 **`pipe`**（外部进程：stdin=preedit，stdout=每行一个候选）。**这是本轮最重要的发现**：中文组词 + 候选窗可以在**不改任何客户端、不装 fcitx5**的前提下做出来 | 源码静态，确定（Debian 包 `phosh-osk-stub 0.46.0-1` = 设备现役版本）| `src/pos-input-method.c:301,519-543,579`；`src/pos-osk-widget.c`→`pos-input-surface.c:282-348`；`src/pos-completer-manager.c:88`；`data/sm.puri.phosh.osk.gschema.xml:81-92`（`Completers.Pipe.command` 语义原文）|
| **C5** | **「GTK3 在本栈不建 fcitx IC」不是一个已定因的结论，而是 4 个候选成因之一**（缓存缺失 / dlopen 失败 / 探针窗口从未真正获得焦点 / 探针环境）；`#653` 自己记录的 `DebugInfo` 里**有 `program:phosh`**（phosh 也是 GTK3）⇒ 模块在同一栈里是能工作的，不对称发生在**测试客户端侧**。GTK3 在模块名解析失败或 create 失败时**静默回落** `GtkIMContextSimple`（只打一条 `g_warning`），所以「不建 IC」不会自己报错 | 源码静态 + `#653` 原文，**未定因** | GTK3 `gtk/gtkimmodule.c:620-660`（失败→`gtk_im_context_simple_new()`）、`:829-880`（`GTK_IM_MODULE`→cache 查名）；`#653` 正文「DebugInfo 只有 `program:phosh`」|
| **C6** | **squeekboard 的边界（源码级）**：打字只有两条出口——① 拿到 IM 槽时 `zwp_input_method_v2.commit_string(text)`（**整串提交**，无 preedit、无候选）；② 否则 `zwp_virtual_keyboard_v1.key(keycode)`（**evdev 键码**，不是文本）。⇒ 「squeekboard 直接注入汉字上屏」**只对「布局里写死一个字」成立**，拼音→汉字组词**结构上不可能** | 源码静态，确定 | squeekboard `src/submission.rs:106-150`、`src/vkeyboard.rs:60-90`（`eek_virtual_keyboard_v1_key`，参数是 keycode）|
| **C7** | **ibus 路线在本栈的风险是官方写明的**：ibus panel 在 Wayland 上只有三种合法形态（GNOME / KDE / 「被桌面以 Wayland input method 拉起」），其它会话它自己就打印「IBus should be called from the desktop session in Wayland…」。而「Wayland IM 形态」要独占 `zwp_input_method_v2`，与 `phosh-osk-stub` **互斥** | 源码静态，确定（降级为高风险） | ibus `ui/gtk3/panel.vala:1010-1030`；`phosh-osk-stub src/pos-input-method.c:301`（独占 IM 槽）|
| **C8** | **推荐路线 = R1**：`phosh-osk-stub` 单栈（IM 槽归它）+ `completion-mode=always` + `Completers default=pipe` + 一个 **拼音→汉字的 helper**（stdin 收 `nihao`，stdout 出 `你好\n妳好\n…`）。**弹出、组词、候选条三件事一次全解**，零客户端改动、零合成器重编 | 源码 + 设计，**未上机** | C4 + 本文件 §5.1 |

> 一句话：**我们一直在「客户端侧 IM 模块」这条路上打补丁（fcitx5-gtk + focusd + 自绘浮条），而现役 OSK 自己就是 IM，并且自带原位候选条 + 外部进程候选引擎接口。**
> 中文组词的缺口是「给 OSK 一个拼音候选引擎」，不是「让 GTK3 建 fcitx IC」。

---

## 1. 取证方法与边界

- **主机侧只读**：`curl` 拉上游源码（GNOME GitLab API raw、sources.debian.org、GitHub raw）、读本仓既有报告/PITFALLS、读**本机**（Ubuntu 26.04）同代件做旁证（`/usr/lib/x86_64-linux-gnu/gtk-3.0/3.0.0/immodules.cache` 里 fcitx/ibus 条目）。
- **设备零接触**：设备在 bootloader，`fastboot/adb/ssh/qdl` 一条未跑。凡是需要设备状态的（phoc 二进制是否被打过补丁、`immodules.cache` 是否含 fcitx、`DebugInfo` 内容），本轮只给**判据命令**，结论标「未验证」。
- 版本对齐（现役栈，来自 Z §0.1 与 `INDEX.md` §0 的实测记录）：`phoc 0.46.0-1` / `phosh 0.46.0-3+deb13u1` / `phosh-osk-stub 0.46.0-1` / `fcitx5 5.1.12-2` / Debian 13.7。
- 外部命令一律 `timeout -k`（本轮实际带的 `--max-time`/`timeout -k 5 30`）。

---

## 2. 两条链必须分开（这是本轮的核心结构性结论）

### 2.1 链 P（弹出）：谁决定键盘出现

```
客户端获得焦点
  ├─(P-a) 走 text-input-v3：get_text_input → enable() → commit()
  │        → phoc input-method-relay: handle_text_input_enable
  │        → 若 relay->input_method == NULL ⇒ 打日志返回（无 IM 即无键盘）
  │        → wlr_input_method_v2_send_activate(im)
  │        → OSK（phosh-osk-stub / squeekboard）收到 activate ⇒ 显示 layer surface
  └─(P-b) 走客户端 IM 模块（GTK_IM_MODULE=fcitx/ibus）：DBus 直连 IM，
           完全不发 enable ⇒ P-a 整条链不被触发
```

- **P-a 在本栈是通的**（C1）：phoc 0.46 无版本门；`phosh-osk-stub` 把 IM `active` 直接绑到自己的 `surface-visible`（`pos-stub.c:343-346`：`g_object_bind_property_full(im,"active" → input_surface,"surface-visible")`）。
- **P-b 是现役栈的默认态**（`/etc/environment.d/50-elden-ime.conf` 有 `GTK_IM_MODULE=fcitx`，Z §0.1/§9.3），所以「点输入框不弹」在客户端侧就被短路了。
- **两条链的取舍是互斥的**：选了 P-b（中文靠 fcitx5-gtk 模块），就必须另建 P-b→P-a 的桥（现役 `elden-ime-focusd`），或者接受 P-b 的 IM 自己画候选；选了 P-a（text-input），中文就必须由**拿到 IM 槽的那个进程**（= OSK）来做。
- **历史弯路的原因**：C11（Alpine/0.55 世代）能「弹 + 组词 + 候选」= P-b 全通（squeekboard 只管出键盘、fcitx5-gtk 在客户端内组词并自绘候选）；换 Debian/0.46 栈后 P-b 断（C5 未定因）而 P-a 又被 `GTK_IM_MODULE=fcitx` 遮蔽 ⇒ 两头都不通，于是才有了 focusd 桥 + 自绘浮条（后者按 `#646` 撤下）。

### 2.2 链 Z（组词上屏）：preedit 归谁

要出现「输入 `nihao` → 候选 → 选 1 → 上屏 `你好`」，**必须**有进程持有 **preedit 缓冲区**，并且候选与 preedit 同时可见。三种持有人：

| 持有人 | 通道 | 候选画在哪 | 本栈可行性 |
|---|---|---|---|
| 客户端内 IM 模块（`im-fcitx5.so` / `im-ibus.so`） | D-Bus（fcitx5/ibus）| 客户端进程内自绘 | 需 C5 定因；且与 P-a 互斥（`#618`）|
| **OSK（`phosh-osk-stub`）** | `zwp_input_method_v2` + text-input-v3 | **OSK 自己的 layer surface 内** | **通**（C4），只缺拼音引擎 |
| 合成器（phoc）| 无 | 无 | phoc 不做任何 UI/组词（源码里没有候选相关代码）⇒ 只能靠外部 overlay |

> 结论：**链 Z 只有两个落点能同时满足「不改客户端」和「候选不打断输入上下文」——OSK 内绘制（C4）或合成器 overlay（§6.2，代价高）。**

---

## 3. 现状路径为什么不通：源码级逐条

### 3.1 `GTK_IM_MODULE=fcitx` 让客户端不发 text-input（已实测，`#618`）

- 机制（源码）：GTK3 的 IM 模块选择 = `GTK_IM_MODULE` 环境变量 → immodules 缓存查名 → 命中则 `g_type_module_use()` + `create()`；**取 `fcitx` 时加载 `im-fcitx5.so`，输入走 D-Bus（`org.fcitx.Fcitx5`）**，GTK 不再 bind `zwp_text_input_v3`。
- 判据（已有，F §2）：`WAYLAND_DEBUG=1` 里 `get_text_input` / `enable()` 计数；`GTK_IM_MODULE=fcitx` ⇒ 0/0；`=wayland` ⇒ 1/1。
- 本机旁证（Ubuntu 26.04，`fcitx5-frontend-gtk3` 已装）：`immodules.cache` 里 fcitx 条目**存在**且带 `ja:ko:zh:*` 上下文（`/usr/lib/x86_64-linux-gnu/gtk-3.0/3.0.0/immodules.cache:19-21`）⇒ 显式 `GTK_IM_MODULE=fcitx` **不受 locale 影响**，只要有缓存条目就会被选中。**若缓存里没有这条，GTK3 静默回落 simple（不报错）**。

**这条给 C5 提供了第一个可判定的候选成因**：Z 的 G7 只核了 phoc 版本，从没核过设备上 `immodules.cache` 是否含 fcitx（C11 在 Alpine 上的修复恰恰就是「装包 + `gtk-query-immodules-3.0` 重建缓存」）。

### 3.2 phoc 的 text-input：0.46 与 0.58 **不是一回事**（新事实，推翻 G7/C-档 的一条）

| 版本 | `handle_text_input_enable` | 有 `show_input_panel` 监听 | 结论 |
|---|---|---|---|
| **0.46.0（现役）** | `input_method==NULL → return`；否则 `send_activate` + `relay_send_im_done` + `elevate_osk`（`src/input-method-relay.c:224-243`） | **无** | 每个 `enable()` 都会走到 `activate` ⇒ **无版本门** |
| 0.58.0 / 0.59~rc1 | 多一条 `if (wl_resource_get_version(...) >= ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION) return;`（`:255-262`）| 有（`:267-283`）| `#615` 的门 |

附带两条与设计相关的事实（同一文件）：
- `elevate_osk()` 只在焦点表面**本身是 layer surface** 时才动作（`phoc046-relay.c:37-49`）；普通应用 toplevel 上它是 no-op ⇒ **键盘显隐始终是 OSK 自己的事**（与 `reports/ime-osk0-dbus-spec-20261020.md` §0 结论 2 一致）。
- preedit 是**正经中继**的：`relay_send_im_done` 里 `wlr_text_input_v3_send_preedit_string`；`submit_preedit()` 只在**焦点离开/销毁**时把未决 preedit 提交掉（`phoc046-relay.c:283-306, 568`）⇒ 「inline preedit」在本栈可用，不是只剩 commit。

### 3.3 fcitx5 classicui 为什么「画不出候选窗」（C3，源码级）

- fcitx5 的 Wayland UI 在构造时就 `requestGlobals<ZwpInputPanelV1>()`，`panelCreated` 后才 `initPanel()`；`WaylandInputWindow::initPanel()` 的第一步是 `window_->createWindow()`（`src/ui/classic/waylandui.cpp:43,74`；`waylandinputwindow.cpp:113-120`）。
- phoc 的 `protocols/` 清单（v0.46.0 与 main 相同）：`gtk-shell` `input-method-unstable-v2` `phoc-*` `phosh-private` `wlr-*` `xx-cutouts` —— **没有 `zwp_input_panel_v1.xml`**；`zwp_input_panel_v1` 是 weston 系协议，wlroots 不实现。
- 所以 `fcitx5-diagnose`/日志里那句「Created classicui for wayland display:」之后就没下文，屏上无面板 —— 这与 `#619` 层 A、`reports/ime-chinese-20261109.md` §1 的实测现象**逐字吻合**，但**成因从此定死**：不是「没调好」，是协议不存在。

### 3.4 squeekboard 的上屏边界（C6，源码级）

- `Submission::handle_press()`：若 `imservice` 存在且当前无修饰键，`SubmitData::Text(t)` ⇒ `imservice.commit_string(t)`，成功即算已提交（`src/submission.rs:117-150`）；否则退化为 `zwp_virtual_keyboard_v1.key(keycode)`（`src/vkeyboard.rs:60-90`，`type KeyCode = u32`，evdev 键码）。
- `imservice` 的 preedit 只有 `imservice.preedit_string = String::new()` 这一处赋值（`src/imservice.rs:66,329,350`）⇒ **squeekboard 不发 preedit**。
- ⇒ 「squeekboard 送 committed text 实现拼音→汉字」**不可能**：committed text 是最终串，没有中间态可被候选替换；而拼音组词的本质就是「中间态 + 替换」。**能做的只有「布局里每个键写死一个字/词」**（§4 R3）。

---

## 4. 决策矩阵（路径 × 可行性 × 代价 × 判据）

代价列 = **人时估算** / **设备窗口分钟**（设备窗口 = 需要人在 Linux 桌面上的分钟数；纯 ssh 只读探测不计窗口）。
可行性列：**通** / **半通（需补件）** / **不通（结构性）**。

| # | 路径 | 装什么 | 弹出 | 组词上屏 | 候选窗 | 需改源码/合成器 | 代价 | 主要风险（证据）|
|---|---|---|---|---|---|---|---|---|
| **R1** | **phosh-osk-stub 单栈 + `pipe` 拼音 completer**（**推荐**）| 无新包（现役已有；helper 用 python3 或 C）| **通**（P-a 原生，C1+C4）| **通**（preedit + commit_string）| **通**（OSK 内 `pos-completion-bar`，不新建窗口）| **否**（只写 helper 脚本 + 3 条 gsettings；若要去掉「选中后追加空格」需 1 行源码补丁）| **2–3 h / 10–15 min** | ①`completion-mode` 默认是 `['hint']`，普通输入框不请求 ⇒ 必须设 `always`（否则「什么都不发生」）；②候选条高度挤占 200 px 键盘面（`INPUT_SURFACE_HEIGHT 200`，`pos-stub.c:279`）；③选中会追加一个空格（`pos-input-surface.c:290` `g_strdup_printf("%s ", …)`）；④GTK4 是否显示 inline preedit **未验证** |
| **R2** | 现状 `squeekboard`+`fcitx5`：**先按 C5 定因**修 GTK3 的 fcitx IC | 无（已装）| 半通（P-b 需 focusd 桥，已有 `#653` 版件）| **通**（若 IC 建成：客户端自绘候选，C11 已验证过这套）| 通（客户端内自绘）| 否 | **0.5 h 诊断 / 5–20 min**；若定因为缓存 ⇒ 修复 5 min | 若定因为「探针从没拿到焦点」则一切都好，只是没人测过；若为 dlopen 失败则需查 `libFcitx5GClient` 依赖 |
| **R3** | squeekboard 自带布局写汉字/词（`text:` 提交）| 无 | 通（现状）| **不通**（只能一键一个字/词，无拼音）| 通（布局自带「候选行」= 另一 view）| 写 yaml | 1–1.5 h / 10 min | 不能组词；`#644`/`#645` 的候选语感不可得。**仅作兜底** |
| **R4** | `ibus` + `ibus-libpinyin` / `ibus-rime` | `ibus ibus-libpinyin ibus-gtk3 ibus-gtk4 librime-data`（+ `ibus-rime`）| 半通（客户端 `GTK_IM_MODULE=ibus` ⇒ 同样遮蔽 P-a，仍需桥）| 通（`im-ibus.so` 在客户端内）| **高风险**：ibus panel 在非 GNOME/KDE Wayland 会话自己就告警「IBus should be called from the desktop session in Wayland…」，且「Wayland IM」形态会独占 IM 槽与 OSK 互斥 | 否 | 2–3 h / 20–30 min（两次窗口）| ibus `ui/gtk3/panel.vala:1010-1030`；panel 定位/置顶在 wlroots 合成器上的行为**未验证**（很可能变成一颗普通浮窗）|
| **R5** | `fcitx5` 开 `waylandim` + `wvkbd`（单栈 B）| `wvkbd`（Debian sid 有 0.15）| 通（IM 槽归 fcitx5）| 通（fcitx5 自持 IM+preedit）| 仍无（classicui 需 `zwp_input_panel_v1`，C3）| 需 phoc 打 grab-NULL 补丁并重编 | **3–5 h / 30–45 min**（含 phoc 重编 15–25 min + 显示回归）| `#615` 三条处置③；候选窗问题**不因此消失** |
| **R6** | 现状 + 客户端自绘候选（focusd 桥保有）| 无 | 通（现状实测）| 依赖 R2 | 依赖 R2 | 否 | 0 h（已落地）| `#653` 的 `fcitx_seen_active` 闸门依赖「客户端确实建了 fcitx IC」——R2 不定因则此项不可信 |
| **R7** | phoc 侧 overlay 候选窗（合成器自绘）| 无 | 通 | 需另配 IM | 通（合成器画）| **需改 phoc + 新进程 + 输入上下文策略**| **6–10 h / 40–60 min** | §6.2 的失败判据；收益被 R1 完全覆盖 ⇒ **不推荐**（见 §6.3）|

> 矩阵的一条硬边界：**「不改客户端」+「要组词」⇒ 组词必须落在 P-a 链的 IM 槽持有者身上**（OSK 或 fcitx5-waylandim）。R1 选了前者（不需要重编合成器、不需要改客户端、候选天然不打断上下文）。

---

## 5. 推荐路线 R1：`phosh-osk-stub` 单栈 + `pipe` 拼音 completo（含前置条件与判据）

### 5.1 架构（每段都有源码落点）

```
点输入框
 └─ GTK3 发 text-input-v3 enable（前提：GTK_IM_MODULE 不得是 fcitx/ibus）
    └─ phoc 0.46 relay: send_activate  ─────────────► phosh-osk-stub（IM 槽持有者）
                                                        │ im.active → surface-visible（pos-stub.c:343）
                                                        ▼
                                                    layer surface 弹出（anchor BOTTOM/LR，layer TOP，exclusive-zone 200）
 敲 latin 键（OSK 按键）
 └─ pos-input-surface: completion_mode ⇒ pos_completer_feed_symbol()
    ├─ 累计 preedit（"n","ni","nih"…）
    ├─ 每次变化：spawn `Completers.Pipe.command`，stdin 灌 preedit，stdout 取候选（\n 分隔）
    ├─ set_preedit_string(preedit)  →  客户端**内联**显示拼音（不再是「字面漏字」）
    └─ 候选条 set_completions(...)  →  OSK 自己的完成条（不新建窗口 ⇒ 不打断输入上下文）
 点候选「你好」
 └─ commit_string("你好 ") → 客户端上屏；preedit 清空
```

### 5.2 需要什么（包 / 配置 / 源码）

- **包**：无（`phosh-osk-stub 0.46.0-1` 已含 `pipe` completer，`pos-completer-manager.c:88` 无 `#ifdef` 守卫 ⇒ Debian 构建里一定有）。
- **配置**（三条 GSettings，schema 见 `data/sm.puri.phosh.osk.gschema.xml:4,71-92`）：
  ```sh
  gsettings set sm.puri.phosh.osk completion-mode "['always']"        # 默认 ['hint']：普通输入框不会触发
  gsettings set sm.puri.phosh.osk.Completers default "pipe"           # 默认 ''（OSK 自选，通常是 hunspell）
  gsettings set sm.puri.phosh.osk.Completers.Pipe command "<helper 路径>"
  ```
  > `completion-mode` 的合法枚举值 = `gsettings range sm.puri.phosh.osk completion-mode` 现读（`PhoshOskCompletionModeFlags`；`hint`/`always`/`manual` 语义来自 gschema 描述与 `pos-input-surface.c:1841-1868`），**以设备实读为准**。
- **环境**：`GTK_IM_MODULE`/`QT_IM_MODULE`/`XMODIFIERS` **必须不指向 fcitx/ibus**（否则回到 P-b 遮蔽）。这与 `#618` 的 T4 裁决一致，但与 `rootfs/debian/daily-baseline.sh:139-146` 现在**写回** `GTK_IM_MODULE=fcitx` 直接冲突（Z §8 G1）。R1 落地的第一步就是把这条基线改掉。
- **helper（唯一新代码）**：一个「读 stdin 一行拼音、输出 N 行汉字候选」的程序。三个实现档：
  | 档 | 做法 | 依赖 | 代价 | 质量 |
  |---|---|---|---|---|
  | H-a | `python3` + `python3-pypinyin`（音节级）| `python3-pypinyin` | 0.5 h | 单字/词够用，整句不行 |
  | H-b | `librime` one-shot：新建 session → `process_key` 逐字母 → `RimeGetContext` 取 candidates | `librime1`/`rime-data` | 1.5 h | 与现役 Rime 一致（含词/整句），但每键重建 session（延迟需量测）|
  | H-c | 常驻小 daemon + Unix socket，pipe command 用 `socat`/`nc` 转发（保持 session 状态）| `socat` | +0.5 h | 最好；但 helper 契约是「一次进程一次问答」（`pos-completer-pipe.c:340-355` 每键 kill 旧进程再 spawn）⇒ 需要转发层 |
  **建议先 H-a 打通判据，再换 H-b。**
- **可选 1 行源码补丁**：`pos-input-surface.c:290` `send = g_strdup_printf ("%s ", completion);` → 中文候选后会多一个空格。MVP 可接受（`你好 `），要干净则改为「completion 末字节是多字节 UTF-8 时不追加空格」，需重编 `phosh-osk-stub`（`debian/rules` 级别的小 patch，10 min 编译）。

### 5.3 上机验证判据（命令 + 目视）

| # | 判据 | 命令 | 期望 |
|---|---|---|---|
| R1-1 | OSK 持 IM 槽、fcitx5 没抢 | `ps -eo args \| grep -c -- '--disable waylandim'`；`busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible` | 前者 ≥1（或 fcitx5 不在跑）；后者 `b false`（无焦点时）|
| R1-2 | 完成条配置生效 | `gsettings get sm.puri.phosh.osk completion-mode` / `… .Completers default` / `… .Completers.Pipe command` | `['always']` / `'pipe'` / helper 路径 |
| R1-3 | **弹出**（不靠桥） | `WAYLAND_DEBUG=1` 跑 `probes/ime/ime-gtk3-entry.py`（`env -u GTK_IM_MODULE`）→ 另开一路读 `Visible` | `get_text_input=1 enable=1`，且 `Visible` false→**true** |
| R1-4 | preedit 到位 | 同窗口 `WAYLAND_DEBUG=1` 打 OSK 按键（或 `wtype ni`）| 客户端出现 `set_preedit_string`；**屏幕**上输入框里显示带下划线/中间态的 `ni`（目视）|
| R1-5 | **候选条** | `journalctl --user -u phosh-osk-stub -f` + 截图 | 日志有 `Looking up string 'ni'`（`pos-completer-pipe.c:333`）；屏上键盘上方出现 `你好 妳好 …` |
| R1-6 | **上屏** | 目视 + 读输入框内容 | 点候选后输入框 = `你好`（含/不含尾空格按 §5.2 是否打补丁）|
| R1-7 | 不打断输入上下文 | 打字期间看客户端是否收到 `disable`/`leave`（`WAYLAND_DEBUG`），并检查 preedit 不丢 | 全程无 `text_input.disable`；`#646` 的「页面被顶掉」不再出现 |

### 5.4 已知风险与失败判据

| 风险 | 失败判据（怎么知道它死了） | 处置 |
|---|---|---|
| `completion-mode` 值名不对 | `gsettings set` 报 `Cannot set…` / `gsettings range` 列出的不是我写的 | 用 `gsettings range` 输出改写 |
| 候选条被 `is_completer_active` 的门挡掉 | 日志无 `Looking up string`；且 `pos_input_surface_is_completer_active()` 的三条前置（completer≠NULL、IM active、非 terminal 布局、purpose=NORMAL）任一不满足（`pos-input-surface.c:2016-2044`）| 逐条查：`busctl` 看 IM active、布局选择器确认不是 terminal、输入框 purpose 正常 |
| helper 太慢（每键 spawn + rime 重建 session）| `Looking up string` 与候选出现的时间差 > 300 ms（目视/日志时间戳）| 换 H-c 常驻 daemon |
| 候选条挤掉键盘 | 截图：键盘被压成半屏 / `INPUT_SURFACE_HEIGHT 200` 不够 | 调 `completion-bar` 样式或减少候选数（helper 只出 5 个）|
| GTK4 不显示 preedit | GTK4 应用里拼音直接不显示、候选条照常出现 | 仍可用（候选条是主通道）；把 preedit 依赖降级，或对 GTK4 用 H-c 的 `commit_string` 模式 |

---

## 6. 候选窗：最小可行方案设计（「不动客户端输入上下文」前提下）

### 6.1 方案 A（首选，已在树上）：OSK 内原位候选条

- **前置条件**：① IM 槽归 `phosh-osk-stub`（`fcitx5 --disable waylandim` 或 fcitx5 不跑）；② 客户端发 text-input（`GTK_IM_MODULE` 不指 fcitx）；③ `completion-mode` 打开；④ helper 在位。
- **为什么不打断上下文**：候选条是 `PosInputSurface` 里的一个 `GtkBox`（`pos-completion-bar.c:31-35`），而 `PosInputSurface` 本身是**一块常驻 layer surface**（`pos-stub.c:323-336`：anchor/layer/exclusive-zone 一次性设置；显隐走 `surface-visible` 动画 `pos-input-surface.c:1974-1994`）⇒ 不存在 `#646` 那种「每次组字 map/unmap 一个新窗口」的动作 ⇒ 不会触发焦点重算。
- **失败判据**：① 打字过程中客户端收到 `text_input.disable` 或 `leave`；② 日志出现 `hide requested`/键盘闪烁；③ 候选条出现但键盘消失。任一命中即判「方案 A 失败」，转 §6.2。
- **代价**：0 新增 UI 代码（复用），只在 helper 上花时间。

### 6.2 方案 B（备选，代价高）：phoc 侧 overlay

- 形态：phoc 内新增一块独立 layer surface（`layer-surface.c` 已有基础设施，`layer-shell.c` 提供协议），由 focusd 的 `org.elden.ImePanel` 信号驱动（数据侧已就绪，Z §7.3 第 5 条）。
- **前置条件**：① 候选数据来自**当前 IM 槽持有者**（否则只有客户端 IM 有数据 ⇒ 又回到「客户端内自绘」）；② overlay 必须**全程 mapped**，显隐只改 opacity/内容（`#646` 教训）；③ 需要 phoc 重编 + `dpkg-divert` + `apt-mark hold`（PITFALLS #654）。
- **失败判据**：打字期间合成器侧 `NotifyFocusOut` 计数 ≠ 0（Z §7.3 第 2 条；本栈取法**未验证**）；或候选与键盘重叠遮挡输入区。
- **代价**：6–10 人时 + 40–60 min 窗口 + 每次 phoc 升级都要重打。

### 6.3 为什么本轮判定「方案 B 不值得做」（证据化否定）

1. **收益被方案 A 完全覆盖**：A 已经给出「原位候选条 + 不新建窗口 + 不改客户端」的同一结果（C4）。
2. **B 的额外风险是结构性的**：它必须自己维护「合成器侧不打断输入上下文」这条不变量，而 `#646` 已经证明这条不变量在本栈**极易被打破**（map/unmap ⇒ 焦点重算 ⇒ fcitx 提交并重置组字）。
3. **B 的维护成本是长期的**：phoc 是发行版包，重编件必须 `divert + hold`（`PITFALLS #654`，实测被 apt 冲出过一次），而 phoc 版本还会随 Debian 漂移。
⇒ **只在 A 的失败判据（§6.1）命中时再启动 B**，并把 B 的立项前提写死为「A 的失败判据已归档」。

---

## 7. 上机脚本骨架（主机侧驱动；纯 ssh 侧动作，零刷写）

> 纪律：`set -eu` + `timeout -k` + **不碰 fastboot/adb**、不写 `boot_*`、不改 `/etc/environment` 之外的东西；
> `--dry-run` 打印命令不执行（默认）。设备侧命令一律经会话用户总线（以 root 直接 `busctl --user` 恒假，`PITFALLS #663`）。
> 本骨架本轮**未落盘为脚本**（只允许写本报告），下面代码块可直接另存为 `scripts/ime-zh-r1-verify.sh` 再由主会话审。

```sh
#!/bin/sh
# ime-zh-r1-verify.sh — R1 路线（phosh-osk-stub 单栈 + pipe 拼音 completer）核查/落配置
# 用法: sh ime-zh-r1-verify.sh [--apply] [--dry-run]
set -eu
HOST=${ELDEN_SSH:-elden-root}
U=${ELDEN_UID:-1001}
DRY=1; APPLY=0
for a in "$@"; do case "$a" in --apply) APPLY=1; DRY=0;; --dry-run) DRY=1;; esac; done

run() {  # run <cmd...>  —— 经 ssh 到设备，会话用户总线
  if [ "$DRY" = 1 ]; then printf 'DRY  '; printf '%s ' "$@"; echo; return 0; fi
  timeout -k 5 30 ssh -o BatchMode=yes "$HOST" "su - $(id -un 2>/dev/null || echo xuqianhui1001) -c 'export XDG_RUNTIME_DIR=/run/user/$U; $*'" 2>&1
}

echo '== 0. 栈身份（只读，判据基线）'
run 'uname -r; dpkg -l phoc phosh phosh-osk-stub fcitx5 2>/dev/null | awk "/^ii/{print \$2, \$3}"'
run 'ps -eo args | grep -c -- "--disable waylandim" || true'
run 'busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible'

echo '== 1. 环境遮蔽（#618 / Z§8 G1）：三行必须消失'
run 'tr "\0" "\n" < /proc/$(pgrep -x phosh | head -1)/environ | grep -E "^(GTK|QT)_IM_MODULE=|^XMODIFIERS=" || echo "(clear)"'

echo '== 2. GTK3 IM 模块缓存（C5 定因第 1 支）'
run 'ls /usr/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules/ 2>/dev/null | grep -c fcitx || echo 0'
run 'grep -c fcitx /usr/lib/aarch64-linux-gnu/gtk-3.0/3.0.0/immodules.cache 2>/dev/null || echo 0'

echo '== 3. completer 能力与配置'
run 'gsettings range sm.puri.phosh.osk completion-mode'
run 'gsettings get sm.puri.phosh.osk completion-mode'
run 'gsettings get sm.puri.phosh.osk.Completers default'
run 'gsettings get sm.puri.phosh.osk.Completers.Pipe command'

if [ "$APPLY" = 1 ]; then
  echo '== 4. 落配置（幂等）'
  run 'gsettings set sm.puri.phosh.osk completion-mode "['"'"'always'"'"']"'
  run 'gsettings set sm.puri.phosh.osk.Completers default "pipe"'
  run 'gsettings set sm.puri.phosh.osk.Completers.Pipe command "/usr/local/bin/elden-pinyin-completer"'
  run 'systemctl --user restart phosh-osk-stub 2>/dev/null || true'
fi

echo '== 5. 端到端（需人在桌面：点输入框 → 目视候选）'
cat <<'TIP'
 设备侧（GUI 用户）：
   env -u GTK_IM_MODULE -u QT_IM_MODULE -u XMODIFIERS \
     WAYLAND_DISPLAY=wayland-0 python3 /tmp/ime-gtk3-entry.py
 同时另开一路看：
   journalctl --user -u phosh-osk-stub -f | grep -E 'Looking up|completion'
   busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible
 目视项：键盘弹出 / 输入框出现内联拼音 / 键盘上方出现汉字候选 / 点选后上屏
TIP
```

**helper 骨架（H-a 档，`python3-pypinyin`）**：

```sh
#!/bin/sh
# /usr/local/bin/elden-pinyin-completer
# 契约（gschema 原文）：读 stdin 的 preedit（拼音），stdout 每行一个候选
exec timeout -k 2 3 python3 - <<'PY'
import sys
pre = sys.stdin.read().strip().lower()
if not pre or not pre.isascii() or not pre.isalpha():
    sys.exit(0)
try:
    from pypinyin import lazy_pinyin, Style
    import pypinyin.contrib.tone_convert  # noqa
except Exception:
    sys.exit(0)
# MVP：音节级候选（词/整句由 H-b(librime) 替换）
try:
    from pypinyin.pinyin_dict import pinyin_dict
except Exception:
    pinyin_dict = None
# 退化实现：只给「整串作为一个词的拼音索引」预留位（H-b 落地后删除）
print("你好", "妳好", "拟好", sep="\n")
PY
```

> ⚠ 上面 helper 的第三种实现（写死 3 个候选）**只是把 R1 的判据跑通的占位**；真实候选必须换 H-b（`librime`）或 H-a 的真表。报告里显式标：**占位 helper ≠ 能力成立**（`#646` 教训：主机侧能画/能出串不等于真机可用）。

---

## 8. 未验证清单（本轮的诚实边界）

| 项 | 为什么没定 | 最小验证 |
|---|---|---|
| 设备 `phoc` 二进制**是否**被我们打过补丁（0.46 原件 vs 自编） | 设备不可达，未核 `dpkg-divert`/sha | `dpkg -V phoc`；`ls /var/lib/dpkg/diversions \| grep phoc`（`scripts/phoc-install.sh`/`PITFALLS #654`）|
| 设备 `immodules.cache` 是否含 fcitx | 同上 | 脚本骨架 §7 第 2 步 |
| `completion-mode` 的枚举字符串 | 需要 `gsettings range` 实读（gschema 未内联 enum）| 同上第 3 步 |
| `phosh-osk-stub` 在本栈**真的**在 `activate` 后显示 | 源码链条完整（`im active → surface-visible`），但 0.46 栈没有实测记录；历史证据分别来自 stevia(0.59)/squeekboard(0.55) | §7 第 5 步（R1-3）|
| GTK4 是否显示 inline preedit | 无源码依据（GTK4 的 preedit 渲染路径未核）| 一个 GTK4 Entry + `WAYLAND_DEBUG` |
| XWayland/X11 客户端 | X11 客户端不发 text-input-v3，只能走 XIM（`XMODIFIERS=@im=fcitx`）；本栈无 Xwayland 进程实测 | 起 Xwayland 应用后看 `WAYLAND_DEBUG`/`XMODIFIERS` 行为 |
| 拼音 helper 的延迟 | 未实测量测（每键 spawn + 可选 rime session 重建）| helper 单独 bench：`time echo nihao \| helper`（目标 <100 ms）|
| squeekboard yaml 里「写死文字」的字段名 | `Action::Submit{text}` 的构造点在 `layout.rs` 之外，未定位到 yaml 键名 | `grep -rn 'text:' data/keyboards/*.yaml`（上游仓）|

---

## 9. §结论

1. **两条链必须分开**：弹出（链 P）在本栈 **P-a 通道本来就是通的**（phoc 0.46 无 `#615` 版本门，实测口径的证据是源码 diff，见 C1）；现役不弹的原因是客户端被 `GTK_IM_MODULE=fcitx` 短路（P-b 遮蔽）。
2. **组词/候选的真正瓶颈不是 GTK3，而是「我们把 IM 放在客户端、把候选放在独立窗口」的选择**：现役 `phosh-osk-stub` 0.46 自身就是 IM 客户端，带**原位候选条**与**外部进程候选引擎接口**（`Completers.Pipe`）。
3. **推荐 R1**（`phosh-osk-stub` 单栈 + `completion-mode=always` + `Completers default=pipe` + 拼音 helper）：**2–3 人时 + 10–15 min 设备窗口**，零客户端改动、零合成器重编，且候选条天然不打断输入上下文（结构上避开 `#646`）。
4. **R2 仍值得做一次 20 分钟的诊断**（C5 的四个分支），因为结论会决定「保留 fcitx5 生态」是否还有价值；**但不再作为主路线**。
5. **ibus（R4）风险由上游自己写明**（`panel.vala:1010-1030`），且「Wayland IM」形态与 OSK 抢同一 IM 槽；**不推荐作为首个投入**。
6. **候选窗 overlay（R7/§6.2）不值得做**：收益被 R1 完全覆盖，风险与长期维护成本结构性更高（`#654` + `#646`）。
7. **两处文档需要回填**（本轮只写本文件，未改 SSOT）：① `Z §0.2 C-档` 的「phoc 版本门 ⇒ 现栈不可用」对 0.46 不成立（G7 已可结案）；② 全文/脚本里出现的 `GTK4_IM_MODULE` 若存在应删除（变量不存在）。

## 10. §下一步可执行清单（带代价/判据）

| 序 | 动作 | 代价 | 判据（做到什么算完成）|
|---|---|---|---|
| **N1** | **设备窗口内跑 §7 骨架的只读部分**（第 0–3 步，纯 ssh）| 5 min | 四件事有数：`immodules.cache` 是否含 fcitx、`completion-mode` 当前值/枚举、`Completers default`、OSK 进程与 fcitx5 参数 |
| **N2** | 按 N1 结果二选一：<br>• 若 `completion-mode` 枚举含 `always` ⇒ 进 N3（主路线）<br>• 若 R1-3（弹出）失败 ⇒ 先修 P-a（查 `relay->input_method` 是否有 owner：`busctl --user list \| grep -E 'impanel\|OSK0'` + OSK 日志）| 5 min | 有明确分支决定，写进 `TASKS/README.md` G1-38 行 |
| **N3** | 写 helper（先 H-a 占位→真表，再 H-b）并 `--apply` 落 3 条 gsettings | 1–2 h（主机侧）| helper 单测：`echo nihao \| helper` 输出 ≥3 行汉字、耗时 <100 ms |
| **N4** | 真机端到端：`env -u GTK_IM_MODULE` 起 GTK3 Entry → 目视键盘 + 内联拼音 + 候选条 + 上屏 | 10 min 窗口 | R1-3…R1-6 全过 + 一张截图（候选条 + 上屏结果）|
| **N5** | 把 `GTK_IM_MODULE=fcitx` 的基线冲突一次解决（`rootfs/debian/daily-baseline.sh:139-146` vs `#618` T4）| 30 min（主机侧）| 二选一写入 SSOT + 脚本幂等块 + `daily-baseline.sh --check` `MISS=0` |
| **N6** | R2 诊断（可选，20 min）：`immodules.cache`/`ldd im-fcitx5.so`/`GTK_DEBUG=modules`/「探针窗口真获焦」四项 | 20 min | C5 从「4 候选」收敛到 1 条定因，回填 `PITFALLS`（新条目，`#NNN` 现取最大+1）|
| **N7** | 选配：`pos-input-surface.c:290` 去掉中文候选后的尾随空格（重编 `phosh-osk-stub`）| 30 min + 10 min 窗口 | 上屏 = `你好`（无空格），且 `deploy-desktop-shell.sh --check` 仍 `MISS=0` |

收尾: 本轮只读调研完成，产出 `reports/ime-osk-zh-matrix-20261122.md`（C1–C8 判定 + R1–R7 矩阵 + R1 方案/脚本骨架）；关键新事实 = phoc 0.46 无 #615 版本门、`phosh-osk-stub 0.46` 自带 IM+原位候选条+`Completers.Pipe` 外部引擎接口；设备零接触。
