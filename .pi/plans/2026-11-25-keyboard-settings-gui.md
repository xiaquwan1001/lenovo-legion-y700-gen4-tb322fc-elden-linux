# 2026-11-25 · 自研「键盘设置」GUI（震动 / 词库引擎 / 按键声音 / 自定义功能键）— 只读设计 lane

> **数字（诚实的账，别虚报）**：设置项盘点 **12 项** →
> **5 项零补丁可用**（#7 引擎切换、#8 补全触发、#11 快捷键条 = **实时**；#9 RIME 用户目录、#10 方案/每页候选 = **需重启 osk-stub**，GUI 给个按钮即可）=
> **5/12 ≈ 42%**；**2 项（#5/#6 按键声音）零补丁的可行性取决于 PoC-0**（若 feedbackd 路通 +2 → **7/12 ≈ 58%**）；
> **4 项（#1–#4 震动组）**今天只有 `root + 重新登录` 一条路，**一枚约 15 行补丁（0007）**才能变成「免 root、免重启」；
> **1 项（#12 网格里加键）必须重编 osk-stub**。
> **推荐形态 = A（独立 GTK4/libadwaita 应用）**，首选 **Python3 + PyGObject(Adw)** 实现（零交叉编译）；
> **B（phosh 设置面板）作为迁 stevia 之后的归并目标**（现役栈上不可用，见 §3.1）。
> **唯一新增物 = 本文件**（未 ssh、未改既有文件、未发信）。

> **口径 / 取证方式**
> - 设备现役栈 = **phosh-osk-stub 0.46**（Debian trixie 包 + 我们 `dpkg-divert` 的五枚补丁自编件），
>   单栈收敛由 `scripts/ime-single-stack.sh`（C1–C9）把关；RIME completer 为 B 案（`Completers default=rime`）。
> - 0.46 源码取证：本机缓存 `/tmp/osks/phosh-osk-stub-0.46.0`（Debian orig.tar）；**引用一律带**
>   `仓库内可见的等价物`（patch 文件 / `out/` 下的 gschema 副本 / `scripts/*.sh`），因为 `/tmp` 可能被清。
> - 上游与生态：本 lane **没有** `web_search`/`web_fetch` 工具；改用 `bash`+`curl` 经本机代理取
>   GitLab API 与源码 tarball（访问日 **2026-11-25**）：
>   `World/Phosh/stevia`（= osk-stub 改名后的上游，`main` 最后活动 2026-11-24，NEWS 里 0.59.0 已发）、
>   `World/Phosh/phosh-mobile-settings`（下称 **pms**）。**未做**：GitHub / ML / patchwork 检索。
> - 本 lane **未 ssh**：所有「设备上现在是什么」的断言都注明是 `仓库证据` 还是 `待上机核实`。

---

## 0. TL;DR（结论先行）

1. **4 个诉求里 3 个的上游「旋钮」已经在机上、只是没有 GUI**：词库引擎 = `gsettings sm.puri.phosh.osk.Completers default`（**实时生效**，源码有 `changed::default` 监听）；词库目录/每页数 = `Completers.Rime user-data` + `~/.local/share/rime/default.custom.yaml`（**要重启 osk-stub**）；自定义功能键 = `sm.puri.phosh.osk.Terminal shortcuts`（**实时生效**，就是「快捷键条」）。
2. **震动**：机上有**两条并行**的震动链路 —— ① 我们的 `haptic/0001` 补丁每键 `spawn ffrumble`（env 开关，改值要**重登或重启 osk-stub**）；② **0.46 自己**每键已通过 libfeedback 给 feedbackd 发 `button-pressed` 事件（`/tmp/osks/phosh-osk-stub-0.46.0/src/pos-input-surface.c:237-246`，key-down 时在 `:376` 调用；另有 `clicked` 全局 emission hook `:1927-1928`）。**② 那条路为什么当时没震感，本 lane 未能定位**（候选：feedbackd `profile=full` 的主题只映射 Sound / 主题缺 `button-pressed` 映射 / feedbackd 未运行），**这是 PoC-0 必须先测清的事**：测清了，「震动强度」和「按键声音」可能**零补丁**（只需 gsettings + 一条主题 JSON）。
3. **按键声音**：**0.46 没有 sound 支持**（`grep -riE 'sound|click|bell|canberra|gsound' src/ data/` 只命中 `data/keymap.txt` 的 X `AudibleBell` 控制，不是点击音）。两条可行路：**(a) feedbackd 主题**（若 PoC-0 证明 feedbackd 路通）+ `pw-play` 级联都现成（`/usr/share/sounds/freedesktop/stereo/button-pressed.oga` 已在机 —— `scripts/asset-install-linux.sh:94`；`pw-play` 实测 rc=0 —— `PITFALLS/sessions/330-*.md:26`）；**(b) 一枚 ~10 行补丁**（与 haptic 同形：`on_osk_key_symbol()` 里 `g_spawn` 一个 `pw-play`）。
4. **形态**：**A**。理由不是"更方便"，而是**B 在现役栈上不可用**：pms 的 OSK/反馈面板硬编码 `mobi.phosh.osk` schema（pms `src/ms-osk-panel.c:32,38`）并且按进程名 `phosh-osk-stevia` 判活（`src/ms-osk-panel.c:508-509`），我们是 `sm.puri.phosh.osk` + `phosh-osk-stub`；pms 的补全引擎目录也写死 `<datadir>/phosh-osk-stevia/completers`（pms `meson.build:187-190`）而 0.46 装到 `/usr/share/phosh-osk-stub/completers`（`out/osk-stub-rime-20261123/DEPLOY.md:10`）。
5. **PoC 顺序**：**PoC-0 = 震动三角定位（30 min，纯命令）** → **PoC-1 = 震动强度 + 引擎切换（半天，CLI）** → PoC-2 = GUI 壳 + 声音 + RIME 词库。失败判据见 §6.2。

---

## 1. 现有旋钮到底在哪（逐项，带 file:line）

### 1.1 震动

| 事实 | 证据 |
|---|---|
| 补丁入口 = `on_osk_key_symbol()`（0.46 所有按键的唯一汇聚点） | `/tmp/osks/phosh-osk-stub-0.46.0/src/pos-input-surface.c:381`（函数首行）、`:387`（`g_debug ("Key: '%s' symbol")`，即补丁 hunk 起点 `@@ -386`）；仓库内等价物 = `patches-userland/zh-ime-rime-20261123/haptic/0001-osk-stub-keypress-haptic-hook.patch:7`（`@@ -386,6 +386,20 @@`） |
| 三个 env 键与语义 | 同上 patch 文件 `:13-20`：`ELDEN_OSK_HAPTIC_DEV`（未设 = 与上游逐字节一致）、`_MS`（默认 `30`，**十进制**）、`_MAG`（默认 `0x3333`，强/弱各取 mag）。`ffrumble` 的解析口径 = `scripts/ffrumble.c:56`（`ms` 走 `atol`，十进制；`"0x2000"` 给 0）与 `:37,63-65`（mag 走 `strtol` base 0，`0x..` 与十进制都行） |
| 马达节点 | 两枚 FF 节点：`/dev/input/event2` = 马达 A（i2c `6-005a`）、`event3` = 马达 B（`6-005b`）—— `patches-userland/zh-ime-rime-20261123/haptic/README.md:5-7`；硬件就绪判据 = `scripts/deploy-desktop-shell.sh:396-413`（≥2 个 `aw86927-haptics` event 节点 + `ffrumble` 在） |
| 值现在存在哪 | `/etc/environment` 的 `ELDEN_OSK_HAPTIC_{DEV,MS,MAG}` 三键（**root 可写、登录时由 pam_env 注入**）—— 判据 `scripts/ime-single-stack.sh:222`（`grep -c '^ELDEN_OSK_HAPTIC_DEV=' /etc/environment`）、运行时证据 `patches-userland/.../haptic/haptic-verify-60s.sh:27-28`（读 `/proc/<osk>/environ`） |
| 装机器自检 | 二进制里必须能 grep 到钩子字符串：`strings /usr/bin/phosh-osk-stub \| grep -c ELDEN_OSK_HAPTIC` **=3** —— `scripts/ime-single-stack.sh:221`（C8）、事故史 `PITFALLS/sessions/350-重编osk-stub漏打补丁会静默丢功能.md:11-22` |
| **[新] 第二条链路：0.46 自己就发 feedbackd 事件** | `/tmp/osks/phosh-osk-stub-0.46.0/src/pos-input-surface.c:237-246`（`pos_input_surface_notify_key_press()` → `lfb_event_new ("button-pressed")` `:244` + `lfb_event_trigger_feedback_async` `:245`）；触发点 4 处：键盘 **key-down**（`:370-377`，`:376` 调用）、按下/抬起路径（`:578`、`:612`）、以及 `clicked` 全局 emission hook（`:249-259` 的 `on_click_hook`，安装于 `:1927-1928`）；按键确实是 GtkButton（`src/pos-keypad-button.h:18`）；`lfb_init` 在 `src/phosh-osk-stub.c:596`；包依赖 `src/meson.build:16` |

**可调值一览（震动）**：设备节点（A/B）、时长 ms（十进制，建议 20–60；`haptic/README.md:18-19` 只给了默认 `30ms 0x3333`）、幅度 mag（0–0xffff；现役 0x3333，README 给了 `0x2000/0x3333/0x6666` 三档）。
**要不要重启**：**要**。env 是进程环境 ⇒ 改完必须让 osk-stub 重新 exec（`pkill -x phosh-osk-stub`，phosh 按需重拉 —— `scripts/ime-single-stack.sh:217-228` 的 C7 修复路径就这么做）。若改的是 `/etc/environment`，还要**重新登录**（pam_env 只在登录会话建立时读）。

> **⚠️ 顺手发现的一处文档错误（本 lane 只读，未改）**：`patches-userland/zh-ime-rime-20261123/haptic/README.md:39-43` 教的是
> `systemctl --user restart phosh-osk-stub`。**0.46 包不提供 systemd user unit**（`data/` 里只有
> `sm.puri.OSK0.desktop.in.in`，且带 `X-GNOME-Autostart-Phase=Panel` / `X-GNOME-AutoRestart=true`，见其 `:10` 与 `:13`；
> `data/meson.build:1-30` 也只装 .desktop）。设备上**待上机核实**：`systemctl --user list-unit-files | grep -i osk`。
> 已知在 deb 生态里 `mobi.phosh.OSK.service`（user unit）属于**stevia** 那版（`/opt/elden/mobian-rootfs/usr/lib/systemd/user/mobi.phosh.OSK.service` 存在，`/usr/bin/phosh-osk-stevia` 也只在那个 root 里）——
> **这直接决定「震动配置 GUI 能不能免 root」**：若设备上 osk-stub 是 **systemd user unit**，`~/.config/systemd/user/*.service.d/*.conf` 是用户可写的 ⇒ 免 root；若是 XDG autostart，env 只能来自 `/etc/environment` ⇒ **必须 root**。§5 的补丁 0007 就是为了绕开这个不确定性。

### 1.2 词库引擎（RIME / pipe / …）

| 旋钮 | 默认 / 取值 | 写入点 | 生效时机 | 证据 |
|---|---|---|---|---|
| 引擎选择 | 默认 `''`（空 = osk 自选） | `gsettings set sm.puri.phosh.osk.Completers default 'rime'\|'pipe'` | **实时** | schema：`out/osk-stub-rime-userdir-20261124/sm.puri.phosh.osk.gschema.xml:71-79`；监听：`/tmp/osks/…/src/pos-completer-manager.c:246`（`changed::default` → `on_default_completer_changed`，`:138-176`）；现役值 = `rime`（`scripts/ime-single-stack.sh:121-127` C2） |
| pipe helper 路径 | 默认 `'cat'` | `gsettings set sm.puri.phosh.osk.Completers.Pipe command /usr/local/bin/elden-pinyin-completer` | **重启 osk-stub** | schema `…:81-89`；读取点 = `/tmp/osks/…/src/completers/pos-completer-pipe.c:212`（在 `GInitable::init` 里读，之后不再读）；实例缓存 = `pos-completer-manager.c:131-133`（同名 completer 只 new 一次） |
| RIME 用户数据目录 | 默认 `''`（补丁 0004 起 = `$XDG_DATA_HOME/rime` 并自建） | `gsettings set sm.puri.phosh.osk.Completers.Rime user-data /home/<u>/.local/share/rime` | **重启 osk-stub** | schema `…:100-107`；读取点 = `patches-userland/zh-ime-rime-20261123/rime/pos-completer-rime.c:352-360`（`pos_completer_rime_init()` 里读，无 changed 监听）；坑史 `PITFALLS/sessions/346-rime-user-data空串让候选静默为空.md:27`、判据 `scripts/deploy-desktop-shell.sh:495-560` |
| RIME 共享数据 / schema | `/usr/share/rime-data` / `luna_pinyin` | `Completers.Rime shared-data` / `.schema` | **重启 osk-stub** | schema `…:92-99`（shared-data）、`:108-112`（schema）；读取同 `pos-completer-rime.c:358-360,398-399` |
| 词库本体 / 每页候选数 | RIME 默认每页 5 | 用户级 `~/.local/share/rime/default.custom.yaml`（`patch: menu/page_size: 20`） | **重启 osk-stub**（librime 的 deploy 在 init 里跑：`pos-completer-rime.c:385-390`） | `scripts/ime-single-stack.sh:232-247`（C9，含写法） |
| 补全开关（何时出候选） | `['hint']`；枚举只有 `none/manual/hint`（**没有 `always`**） | `gsettings set sm.puri.phosh.osk completion-mode "['hint','manual']"` | **实时** | `/tmp/osks/…/src/phosh-osk-enums.h:16-27`、`data/sm.puri.phosh.osk.gschema.xml:4-11`、`src/pos-input-surface.c:1911`（`changed::completion-mode`）；坑史 `PITFALLS/README.md:384`（#709） |

**切换引擎要改什么**：只改 `Completers default`（实时）。**换词库/换引擎细化参数**：改 `.Rime`/`.Pipe` 子 schema 或 `default.custom.yaml`，**然后 `pkill -x phosh-osk-stub`**（phosh 重拉后才重新 `init`）。
不需要重启**整个会话**（osk-stub 是会话里的应用，重拉 ~1–2 s，键盘在下次 activate 时重新出现）。

### 1.3 按键声音

- **0.46 没有任何 sound/click 代码**：`grep -rniE 'sound|bell|click_?audio|gsound|canberra|libpulse' /tmp/osks/phosh-osk-stub-0.46.0/src /data /meson.build` 只命中 `data/keymap.txt:1029-1030`（X keymap 的 `AudibleBell`，与我们无关）。
- **上游 stevia 也没有 sound 代码**，它把这件事交给 feedbackd：`src/pos-input-surface.c:45-46`（`KEY_PRESS_EVENT "key-pressed"` / `BUTTON_PRESS_EVENT "button-pressed"`）、`:213-223`（`pos_input_surface_trigger_feedback()` → `lfb_event_trigger_feedback_async`）、调用点 `:267,416,556,799,834`；依赖 `meson.build:121-123`（`libfeedback-0.0`）。**我们 0.46 用的是同一族 API，只是事件名固定成 `button-pressed`**（见 §1.1 最后一行）。
- **音频侧现成件**（都已核实）：键盘点击音资产 `/usr/share/sounds/freedesktop/stereo/button-pressed.oga` 由 `scripts/asset-install-linux.sh:88-104` 从 ZUI 的 `sounds/ui/Effect_Tick.ogg` 映射而来（`:94`）；播放器 `pw-play` 在机上实测可用（`PITFALLS/sessions/330-重建根丢的是音频UCM与tplg资产.md:26`：`pw-play tone.wav` rc=0），会话里 pipewire/wireplumber/pipewire-pulse 三件 active（`reports/device-window-20261121-night.md:52`）。
- **feedbackd 侧现成件**：我们自己的 `feedback` 包装脚本已经在打 `org.sigxcpu.Feedback.TriggerFeedback`（`packaging/elden-userland/files/usr/local/bin/feedback:1-9`）；目标包根里有 `libfeedback-0.0.so.0`（`/opt/elden/mobian-rootfs/usr/lib/aarch64-linux-gnu/libfeedback-0.0.so.0`）。
- **结论**：**要么走 feedbackd 主题（零补丁，但要先测通 §1.1 ②），要么补一枚补丁**。补丁点与 haptic **同一处**（`on_osk_key_symbol()`，0.46 `:381-390`），形态照抄 `haptic/0001` 的 `g_spawn`（默认命令 `pw-play /usr/share/sounds/freedesktop/stereo/button-pressed.oga`，env/config gated，未配置 = 与上游逐字节一致）。

### 1.4 自定义功能键

| 层次 | 能不能 live 改 | 证据 |
|---|---|---|
| **终端「快捷键条」按钮（含 ctrl/tab/方向键宏）** —— 现役就是「自定义功能键」的可用形态 | **实时**（`changed::shortcuts` → 重建 FlowBox） | schema `sm.puri.phosh.osk.Terminal.shortcuts`（`out/osk-stub-rime-userdir-20261124/sm.puri.phosh.osk.gschema.xml:55-69`，默认值含 `<ctrl>`,`<alt>`,`Home`,`End`,`<ctrl>c`…）；监听 = `/tmp/osks/…/src/pos-shortcuts-bar.c:14-15`（schema/key 常量）、`:350-357`（`g_settings_new` + `changed::shortcuts` → `on_shortcuts_changed`），解析 = `gtk_accelerator_parse`（`:212`）。**注意：该条只在 terminal 布局显示** —— `src/pos-input-surface.c:221-223`（`POS_INPUT_SURFACE_IS_TERMINAL_LAYOUT(child)` 才 visible） |
| **布局网格里加一枚键**（长期显示在键盘面上） | **不行**，要重编 | 布局 JSON 是**编进 gresource** 的资源：查找 `g_resources_lookup_data("/mobi/phosh/osk-stub/layouts/<id>.json")`（`src/pos-osk-widget.c:1827-1835`（路径拼接 `:1827-1829`、`g_resources_lookup_data` `:1831`））、清单 `src/phosh-osk-stub.gresources.xml`（`<file preprocess="json-stripblanks">layouts/*.json</file>`）；且同名布局**不会重载**（`pos-osk-widget.c:1814-1815`：同名直接 `return TRUE`） |
| 已有「自定义键」先例（照它加就行） | — | `patches-userland/zh-ime-rime-20261123/layout/0002-osk-stub-terminal-arrows.patch`：① `src/pos-vk-driver.c` 的 `keycodes_common[]` 尾部补 `{ "KEY_HOME", KEY_HOME, … }`/`KEY_END`（hunk `@@ -83,6 +83,8 @@`）；② `src/layouts/terminal.json` 里写 `{"symbol":"KEY_HOME","label":"⇱","style":"sys"}`。**keysym 规则**：可打印字符直接写字面（`"a"`, `"中"`？—— 只走非拉丁布局需检查）；**特殊键必须先在 `keycodes_common[]` 有条目**（已有 `KEY_LEFT/UP/DOWN/RIGHT` = `pos-vk-driver.c:54-57`，见 `layout/README.md:8-13`），否则布局里写了也不映射（`KEY_HOME/KEY_END` 原本就缺，所以才要 0002 补） |

**⇒ 给 GUI 的两档**：
1. **实时档**（本次就能做）：编辑 `Terminal.shortcuts` 字符串数组 = 「加一枚自定义功能键（发一串按键宏）」，立即生效；限制：只在 terminal 布局可见、必须是合法 GTK accelerator 语法。
2. **静态档**（要重编）：往布局网格里塞新键。可选"免重编"技巧 = `G_RESOURCE_OVERLAYS=/mobi/phosh/osk-stub/layouts/=/usr/share/elden/osk-layouts/` + 重启 osk-stub（GLib 的 overlay 对 `g_resources_lookup_data()` 生效），**未验证**（放 PoC-3 / 不在首轮范围）。

### 1.5 三条结构性事实（决定形态选型，必须先看）

1. **0.46 已经会"叫设置面板"**：键盘菜单的「设置」项走 `pos_open_settings_panel("osk")`（`/tmp/osks/…/src/pos-input-surface.c:517-528`）→ D-Bus `mobi.phosh.MobileSettings` 的 `set-panel 'osk'`（`src/pos-settings-panel.c:67-81`）。**没有 pms 时它静默失败**（只一条 `g_warning`）。
2. **pms 的 OSK 面板已经把「引擎切换 + 快捷键编辑」做完了**：`src/ms-osk-panel.c:596-630`（completer combo / shortcuts box / add-shortcut dialog）、模板 `src/ui/ms-osk-panel.ui:142-192`（"Default Completer"、"Shortcuts"、"Reset to default"）；还有 **Feedback 面板**（`src/ui/ms-feedback-panel.ui:66-67`："Haptic strength — Maximum haptic feedback strength percentage" ↔ `src/ms-feedback-panel.c:36` `max-haptic-strength`）。**但**它整套绑在 `mobi.phosh.osk*`（`src/ms-osk-panel.c:32,38`）+ 只认 `phosh-osk-stevia` 进程（`:508-509`）+ 只读 `<datadir>/phosh-osk-stevia/{layouts.json,completers}`（`meson.build:187-190`）⇒ **在现役 0.46 栈上不能用**（schema id 与安装路径都不同）。
3. **上游已经把 0.46 换成 stevia**：`World/Phosh/stevia`（`main` 2026-11-24 活动，NEWS `0.59.0` 已发；`phosh-osk-stub` 名字作废）。stevia 的 gschema 前缀就是 `mobi.phosh.osk`（`/tmp/stevia-main/data/*.gschema.xml` 键名 `mobi.phosh.osk.PhoshOskCompletionModeFlags` 等），并有 `dh-dconf-migration.c` 专门做 `sm.puri→mobi` 迁移 ⇒ **我们自研 GUI 绑 `sm.puri.*` 是"绑定到已废弃前缀"**（风险 R5）。

---

## 2. 三列映射表（设置项 → 写入点 → 生效时机）

`R` = 需要重启 osk-stub（`pkill -x phosh-osk-stub`，phosh 重拉）；`live` = 无需重启；`root+relogin` = 需 root 且要重新登录。

| # | 设置项（用户语言） | 写入点 | 生效时机 | 现状判定 |
|---|---|---|---|---|
| 1 | 每键震动 开/关 | `~/.config/elden/osk.conf` 的 `haptic.enabled`（**补丁 0007**）；今天只能 `/etc/environment` 的 `ELDEN_OSK_HAPTIC_DEV`（有/无） | 今天 `root+relogin`+`R`；0007 后 **live** | 半可做 |
| 2 | 震动强度（幅度） | 同上 `haptic.mag`（0x0000–0xffff，十进制或 `0x` 均可）↔ `ELDEN_OSK_HAPTIC_MAG` | 同上 | 半可做 |
| 3 | 震动时长（ms） | 同上 `haptic.ms`（十进制，20–60 建议） | 同上 | 半可做 |
| 4 | 用哪个马达（A/B/双） | 同上 `haptic.dev`（`/dev/input/event2` \| `event3`） | 同上 | 半可做 |
| 5 | 按键声音 开/关（+音量） | `gsettings set org.sigxcpu.feedbackd profile 'quiet'/'full'`（主题侧决定 map）或补丁 0008 的 `sound.enabled`；音量 = 系统音量（`wpctl`） | `live`（gsettings）／0008 后 `live` | 需实测（见 PoC-0） |
| 6 | 用哪个声音文件 | 自定义 feedbackd 设备主题 JSON（`~/.local/share/feedbackd/themes/<name>.json` → `button-pressed: {sound: …}`）或 0008 的 `sound.file` | `live`（主题重读**待实测**） | 需实测 |
| 7 | 候选引擎（RIME / pipe / 关） | `gsettings set sm.puri.phosh.osk.Completers default '<id>'` | **live** | ✅ 可做 |
| 8 | 补全触发方式（关/手动/智能） | `gsettings set sm.puri.phosh.osk completion-mode "['manual']"` 等（只有 `none/manual/hint`） | **live** | ✅ 可做 |
| 9 | RIME 用户词库目录 | `gsettings set sm.puri.phosh.osk.Completers.Rime user-data <dir>` | `R` | ✅ 可做（带重启按钮） |
| 10 | RIME 方案（luna_pinyin/…）+ 每页候选数 | `Completers.Rime schema`；`~/.local/share/rime/default.custom.yaml` 的 `menu/page_size` | `R` | ✅ 可做（带重启按钮） |
| 11 | 自定义功能键（快捷键条加/删/排序） | `gsettings set sm.puri.phosh.osk.Terminal shortcuts "['<ctrl>','<alt>','Tab','<ctrl>c',…]"` | **live**（限 terminal 布局可见） | ✅ 可做 |
| 12 | 键盘网格里加一枚键 | `src/layouts/<id>.json` + `src/pos-vk-driver.c` 符号表 → 重编 gresource（或 `G_RESOURCE_OVERLAYS`+`R`，未验证） | 重编 / `R` | 需重编 |

**计数（= 回执口径）**：
- **零补丁可用 5 项**：#7 #8 #11（live）+ #9 #10（重启 osk-stub）⇒ **5/12**；
- **有条件零补丁 2 项**：#5 #6（声音；走 feedbackd 主题则零补丁，否则要 0008）⇒ 通关后 **7/12**；
- **需 1 枚补丁才能好用 4 项**：#1–#4（震动组；**不补也能用**，只是每次改都要 root + 重新登出/登入）⇒ 补后 **11/12**；
- **必须重编 1 项**：#12（网格加键）。
即：**零补丁 5/12（42%）**、**补一枚 0007 后 9/12（75%）**、**再加声音（PoC-0 通）11/12（92%）**、**剩 1 项永远要重编**。

---

## 3. 形态选型

### 3.1 结论：**A —— 独立 GTK4/libadwaita 应用（首选 Python3 + PyGObject/Adw 实现）**

| 方案 | 判定 | 理由（证据） |
|---|---|---|
| **A 独立 GTK4/Adw app + `.desktop`** | **✅ 推荐** | ① 运行时就位：目标包根有 `libgtk-4.so.1`（4.24.1）与 `libadwaita-1.so.0`（1.10.0）（`/opt/elden/mobian-rootfs/usr/lib/aarch64-linux-gnu/`），**交叉编译的 dev 件也在**（`/opt/elden/arm64-sid/usr/lib/aarch64-linux-gnu/pkgconfig/{gtk4,libadwaita-1}.pc`）；② 全部 12 项都是「读写 gsettings / 写一个小 JSON / 触发一次重启」，一个 app 足够，不需要碰上游；③ `.desktop` 进应用网格是仓库既有手法（`patches-userland/zh-ime/elden-ime-toggle.desktop:1-11` + `scripts/deploy-zh-ime.sh:39`）；④ schema 分裂（`sm.puri.*` vs `mobi.phosh.*`）只影响**一处常量**，将来迁 stevia 只改一行 |
| **B phosh 设置面板插件** | **❌ 现役栈不可用 / 迁 stevia 后才是首选** | phosh 插件扩展点只有 lockscreen widget / quick setting / status icon（`/opt/elden/arm64-sid/build-phosh-upstream/phosh/plugins/phosh-plugin.h.in:10-15`）——**没有"设置面板"扩展点**；真正的设置面板在 pms，而 pms 的面板插件机制是 GIO extension point `ms-device-panel`（pms `src/ms-plugin.h:17`、`src/ms-plugin-loader.c:94-98`、插件目录 `src/ms-application.c:559,586`）+ 必须链 `MsPanel`/`libpms`（`src/ms-plugin-panel.h:18-25`）⇒ ① pms **不在**现役 root（`/opt/elden/mobian-rootfs/usr/bin/` 里只有 `phosh-osk-stevia`/`phosh-session`，**无** `phosh-mobile-settings`；设备待核实）；② 即便装了，其 OSK 面板说 `mobi.phosh.osk`（见 §1.5-2），**给我们 0.46 的键改了等于改空气**；③ 插件 .so 跟 pms ABI 漂。**迁移到 stevia 之后，B 反而是正解**（届时 pms 的 OSK+Feedback 面板已覆盖 #5/#7/#8/#11，只剩 `max-haptic-strength` 之外的东西） |
| **C 纯 shell + gsettings 包装** | **只当 PoC-1 的临时界面 / A 的后端** | 没有 GUI，用户诉求是"给用户一个 GUI"，C 不满足形态要求；但它正是 A 应该内部分层的"唯一写入点"（§4 的 `elden-osk-config`），也是 PoC 最快验证路径 |

**语言子选择（A 内部）**：首选 **Python3 + PyGObject**，因为仓库已有同形态件（`packaging/elden-userland/files/usr/local/bin/elden-pinyin-completer` 就是一个 700+ 行 python3 脚本，随 MANIFEST 发设备），**零交叉编译、零 meson**；代价 = 需在机上补两个 typelib 包（`gir1.2-gtk-4.0`、`gir1.2-adw-1`）——目标包根现在**只有** `Gtk-3.0.typelib`，**无** `Gtk-4.0`/`Adw-1`（`/opt/elden/mobian-rootfs/usr/lib/aarch64-linux-gnu/girepository-1.0/` 实查）。若要"绝对零新依赖"，退回 **C 语言 + meson**（dev 件现成，见上）；两者切换只影响 4 个文件（§4）。

### 3.2 为什么不用「键盘菜单里的『设置』直达我们的 app」

0.46 的菜单项走 pms 的 D-Bus `set-panel`（§1.5-1）。不改上游就无法把它指向我们 —— 除非加第 6 枚补丁（`settings_activated()` 里 `g_spawn` 我们的 app，~3 行，与 haptic 同形）。**首轮不必要**：应用网格入口 + 桌面快捷方式足够；等 B 路线（stevia）再回到 `set-panel`。**若用户明确要"从键盘菜单进去"，就加这 3 行**（记为 0009，可选）。

---

## 4. 骨架

### 4.1 文件清单（推荐落地）

```
packaging/elden-userland/sources/elden-osk-settings/
  elden-osk-settings.py            # GTK4/Adw 应用（pygi）；窗口只有一个 AdwPreferencesPage
  elden-osk-config                 # CLI 后端（POSIX sh，唯一写入点；GUI 与 PoC 共用）
  elden-osk-settings.desktop       # 应用网格入口（Exec=…/elden-osk-settings.py；Icon=input-keyboard）
  README.md                        # 契约：每个设置项 → 写入点 → 生效时机（=本文 §2 的机读版）
scripts/build-elden-osk-settings.sh   # 交叉/本地构建或"仅装脚本"（照 scripts/build-hapticd.sh 形态）
packaging/elden-userland/build/elden-osk-settings.sh  # --dry-run 包装，追加进 all.sh 的 RECIPES
```

（C 语言版则换成 `meson.build` + `elden-osk-settings.c` + `data/*.gschema.xml`，其余同。）

### 4.2 最小构建（两条路，各 5 行）

**Python 路（推荐，无交叉编译）**
```sh
# 设备上直接跑 python3；宿主只需语法检查与桌面文件校验
python3 -m py_compile elden-osk-settings.py
desktop-file-validate elden-osk-settings.desktop    # 机上 deps: python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
```

**C 路（若坚持零新依赖）**
```meson
project('elden-osk-settings', 'c', version: '0.1')
gtk4 = dependency('gtk4', version: '>=4.10')
adw  = dependency('libadwaita-1', version: '>=1.4')
executable('elden-osk-settings', 'elden-osk-settings.c', dependencies: [gtk4, adw], install: true)
```
```sh
build-slot take y700-elden:osk-gui --jobs 8
PKG_CONFIG_SYSROOT_DIR=/opt/elden/arm64-sid PKG_CONFIG_LIBDIR=/opt/elden/arm64-sid/usr/lib/aarch64-linux-gnu/pkgconfig \
  meson setup /tmp/oskgui-build --cross-file /tmp/trixie-sysroot/cross.txt
ninja -C /tmp/oskgui-build && build-slot drop <id>     # 官方口径：AGENTS.md「构建抢槽位」
```
（`/tmp/trixie-sysroot` 无 gtk4.pc，**必须**用 `/opt/elden/arm64-sid` 当 sysroot；已核实两处 .pc 存在。）

### 4.3 与 `packaging/elden-userland` 的接入点（**这是容易踩空的一格，照实说**）

| 接入点 | 事实 | 要做的事 |
|---|---|---|
| `MANIFEST.tsv` | 唯一会被 `rootfs/debian/stage.sh:84-94` 装进 overlay 的用户态清单；但它是**采设备生成的**（`packaging/elden-userland/README.md:29,36`，`tools/sync-from-device.sh` 产出，"勿手改"） | 顺序 = 先上机 → 再 `bash packaging/elden-userland/tools/sync-from-device.sh` 采回 `files/` + MANIFEST 行。**这是仓库唯一"自动驾驶"路径** |
| `extra/` | **只被 `tools/verify.sh:245-264`、`rootfs/debian/tools/check-pkgmap.sh:189` 认，`stage.sh` 不装它**（`stage.sh` 只 loop MANIFEST + `units-extra/`）；现有 `extra/` 件是靠部署脚本 scp 上去的 | 若把 GUI 放 `extra/`，必须在部署脚本里自己 scp；**读了 README 会误以为 extra 会被安装 —— 这是一个真实的文档缺口**（本 lane 只读，未改） |
| `sources.tsv` | 每枚 ELF 的重建来源（`packaging/elden-userland/sources.tsv:3-9`；`build/artifacts.tsv:3-9` 是 `verify.sh --rebuildable` 的唯一真源） | C 路追加三行：`dst / build / source / status / note`；`artifacts.tsv` 加 `dst / recipe / artifact` |
| `.desktop` | 无 `files/usr/share/applications/` 目录（MANIFEST 里 `applications` 命中 0），但仓库有先例写法 | 新增 `files/usr/share/applications/elden-osk-settings.desktop`（首次上机后由 sync 采回） |
| 单元（unit） | **不需要**：GUI 是用户会话里的应用（`services.tsv` 只收长驻/oneshot 服务） | 但要重启 osk-stub ⇒ 需要「怎么重启」的唯一实现：`elden-osk-config restart-osk` 里 `pkill -x phosh-osk-stub`（与 `scripts/ime-single-stack.sh:217-228` 的 C7 修复动作一致） |

---

## 5. 需要的补丁（两枚，都可选、都 ~10–15 行，形态照抄 haptic/0001）

### 5.1 `0007-osk-stub-haptic-config-file.patch`（让震动设置免 root / 免重启）

现状：`g_getenv` 每键读一次，但 **env 不可被外部进程改** ⇒ 只能重启 osk-stub 才能生效。
最小改法：把三个 env 读取**降级为 fallback**，优先读 `~/.config/elden/osk.conf`（每次按键一次 `g_key_file_load_from_file`，与 `g_spawn` 相比成本可忽略）：

```c
/* elden: per-keypress haptic; env 仍可用（未配 config 时行为不变） */
{
  g_autoptr (GKeyFile) kf = g_key_file_new ();
  g_autofree char *cfg = g_build_filename (g_get_user_config_dir (), "elden", "osk.conf", NULL);
  const char *dev = g_getenv ("ELDEN_OSK_HAPTIC_DEV");
  const char *ms  = g_getenv ("ELDEN_OSK_HAPTIC_MS")  ?: "30";
  const char *mag = g_getenv ("ELDEN_OSK_HAPTIC_MAG") ?: "0x3333";
  g_autofree char *dev_k = NULL, *ms_k = NULL, *mag_k = NULL;

  if (g_key_file_load_from_file (kf, cfg, G_KEY_FILE_NONE, NULL)) {
    dev_k = g_key_file_get_string (kf, "haptic", "dev", NULL);
    ms_k  = g_key_file_get_string (kf, "haptic", "ms",  NULL);
    mag_k = g_key_file_get_string (kf, "haptic", "mag", NULL);
    if (dev_k) dev = dev_k; if (ms_k) ms = ms_k; if (mag_k) mag = mag_k;
  }
  if (dev && *dev) { …既有 g_spawn ffrumble… }
}
```
- 兼容性：`osk.conf` 不存在 ⇒ 与今天逐字节一致；`ELDEN_OSK_HAPTIC_DEV` 未设且 config 无 `dev` ⇒ 上游戏行为。
- 判据：装机件 `strings … | grep -c 'elden/osk.conf'` ≥1；改 `mag` 后**不重启**点键手感变化（`getevent` 见 `EV_FF`）。

### 5.2 `0008-osk-stub-keypress-sound.patch`（仅当 feedbackd 路不通才需要）

同一函数、同形态：`sound.enabled=1` 时 `g_spawn_command_line_async("pw-play /usr/share/sounds/freedesktop/stereo/button-pressed.oga")`（声音文件可配）。~10 行；**默认关**（没配 = 与上游逐字节一致）。注意 `g_spawn` 每键一次 fork/exec ⇒ 与 `ffrumble` 同级开销（现役已验证可接受，`reports/ime-single-stack-20261124.md:93-106`（§5b））。

> **优先做 §1.1 ② 的 feedbackd 路**：若通，**声音+震动强度都由 feedbackd 的 gsettings/主题控制，两枚补丁都不需要**，且与上游 stevia 的形状一致（上游就是 libfeedback）。
> **但有一条旧结论必须先复核**：`archive/topics/AUDIO-INPUT-2026-10-04.md:121-123` 记录 feedbackd「每个事件只能一种类型（Sound 或 Vibra），要两者兼得需自定义主题」，且当时 `profile=full` 的主题**只映射 Sound**（Vibra 只在 `quiet`）。若这条仍成立，「声音 + 震动同时」的实用解恰好是**现状的两条并行链**（feedbackd 发声音、`ffrumble` 补丁发震动）。

---

## 6. PoC 顺序与失败判据

### 6.1 顺序（总 ~1.5 天，每步都有独立价值）

| # | 内容 | 产出 | 成本 |
|---|---|---|---|
| **PoC-0** | **震动三角定位**（纯命令，先于任何代码）：① 关掉我们的钩子（清 `/etc/environment` 的 `ELDEN_OSK_HAPTIC_DEV` → 重启 osk-stub），点键 → 读 `/dev/input/event2` 看有没有 `EV_FF`；② `gsettings get org.sigxcpu.feedbackd profile`；③ `journalctl --user -b \| grep -i lfb\|feedbackd`；④ `pw-play /usr/share/sounds/freedesktop/stereo/button-pressed.oga` | 一句话结论：feedbackd 路是否通、声音是否已经在响 | 30 min |
| **PoC-1** | **CLI 后端 + 两项**：`elden-osk-config haptic-mag 0x6666`（配 0007）与 `elden-osk-config engine rime\|pipe`（`gsettings set … Completers default`） | 两条命令能改行为；为 GUI 定死"唯一写入点" | 半天 |
| **PoC-2** | **GUI 壳**（Adw PreferencesPage）：震动滑杆（3 档/连续）+ 引擎下拉 + 声音开关 + RIME 三项（带"重启键盘"按钮）+ 快捷键条编辑器 | 可点的 app | 半天 |
| PoC-3（可延后） | 布局网格新键（`G_RESOURCE_OVERLAYS` 试水 → 不行就重编） | 决策：值不值得每次加键都重编 | 1 天 |

**为什么从「震动强度 + 引擎切换」开始**：这两项的写入点**已经存在且已证实**（env/0007 与 `Completers default` 的 live 监听），**不依赖任何未验证假设**；而且它们正好覆盖"手感"和"输入质量"两个用户最能立刻感知的面。声音与 RIME 词库都要么依赖 PoC-0 结论、要么带重启语义，适合放进 PoC-2。

### 6.2 失败判据（每步都能"当场判死"）

| 步 | 判据 | 判死时怎么办 |
|---|---|---|
| PoC-0 | ① 关掉钩子后点 3 键，`/dev/input/event2` **仍**无 `EV_FF` = feedbackd 路**不通**（方法照 `reports/ime-single-stack-20261124.md:93-106`（§5b）：`python3` 读 event2 7 s + `tools/uinput-touch.c` 点键）；② `pw-play …button-pressed.oga` 无声 = 音频侧或会话问题（先修音频，与键盘无关） | 不通 ⇒ 震动只走 `ffrumble` + 0007；声音走 0008；**并在文档里把"feedbackd 路不通"的原因写清**（若原因是 `profile`/主题，就不要动代码） |
| PoC-1（震动） | 改 `mag` 0x2000→0x6666 后**手感无差别**，或 `strings` 无 `elden/osk.conf` | 补丁没打上/读错路径；先 `tr '\0' '\n' </proc/<pid>/environ` 与 `~/.config/elden/osk.conf` 双向确认 |
| PoC-1（引擎） | `Completers default` 改了但打字候选**不变** | mid-combo 被打回（`pos-completer-manager.c:138-176` 的 fallback 会打 `g_critical`，看 journal）；或改的是 root 的 dconf（必须**会话用户+会话总线**：`XDG_RUNTIME_DIR=/run/user/<uid>` + `DBUS_SESSION_BUS_ADDRESS=…`，见 `scripts/deploy-desktop-shell.sh:525-540` 的正确写法） |
| PoC-2（GUI 写入） | GUI 改了值、`gsettings get` 也变了，但键盘行为不变 | 90% 是「GUI 跑在错误的会话总线」或「该键需要重启却没重启」⇒ 检查 §2 的"生效时机"列 |
| 全局 | 任何一项"改了没反应"且无法解释 | **停**，别继续加项：先在 `journalctl --user -b _COMM=phosh-osk-stub` 里找到那条键/那个 completer 的实际读取点 |

---

## 7. 开放风险与待上机核实清单

| # | 风险 / 待核实 | 影响 | 处置 |
|---|---|---|---|
| R1 | **osk-stub 的启动方式**（XDG autostart vs `mobi.phosh.OSK.service` user unit）未在设备上核实 | 决定震动配置能否**免 root**（若 user unit ⇒ 写 `~/.config/systemd/user/*.service.d`） | 一条命令：`systemctl --user list-unit-files \| grep -i osk`（**上机**）。0007 补丁把这风险整体绕开 |
| R2 | feedbackd 是否在跑、版本、主题是否映射 `button-pressed` | 决定声音/震动是否零补丁 | PoC-0（`gsettings get org.sigxcpu.feedbackd profile`；`busctl --user list \| grep Feedback`） |
| R3 | `archive/topics/AUDIO-INPUT-2026-10-04.md:123` 的「每事件只能一种类型」是否仍成立 | 决定"声音+震动同时"要不要保留双链 | PoC-0 顺带测：给 `button-pressed` 的主题同时写 `sound`+`vibra` 看是否两者都出 |
| R4 | `/etc/environment` 改完**必须重新登录**（pam_env 语义），且 `haptic/README.md:39-43` 的 `systemctl --user restart phosh-osk-stub` 疑似无效 | 用户会"改了没感觉" | 文档要写清；0007 后此问题消失 |
| R5 | **上游 0.46 已废**（改名 stevia，`mobi.phosh.osk` 前缀 + `dh-dconf-migration`） | 自研 GUI 绑 `sm.puri.*` 有贬值风险 | GUI 里把 schema id 收进**一个常量**；并在 §3.2 记录"迁 stevia 时改 1 行 + 面板可交回 pms" |
| R6 | 目标包根**无 `Gtk-4.0`/`Adw-1` typelib** | Python 路需装 `gir1.2-gtk-4.0`、`gir1.2-adw-1` | 要么装包（`rootfs/debian/pkgmap.tsv` 加两行），要么走 C+meson（dev 件现成） |
| R7 | `G_RESOURCE_OVERLAYS` 免重编换布局**未验证** | 只影响 #12 | 放 PoC-3；失败就明确"加键必须重编" |
| R8 | 取证依赖 `/tmp/osks/phosh-osk-stub-0.46.0` 与 `/tmp/stevia-main`、pms tarball —— **都是临时树，会被清** | 行号复现 | 已同步落 `out/`、patch 文件与本文引用；重建方法：`apt-get source phosh-osk-stub=0.46.0` / `curl <gitlab archive>`（URL 见文首口径） |
| R9 | 本 lane **未 ssh** | 一切"设备上是什么" | 已逐条标注 `仓库证据` / `待上机` |

---

## 8. 证据索引（速查）

- 震动：`patches-userland/zh-ime-rime-20261123/haptic/{0001-*.patch:7,13-20,haptic/README.md:5-7,18-19,39-43,51,haptic-verify-60s.sh:27-28}`；`scripts/ime-single-stack.sh:217-228`（C8）；`scripts/deploy-desktop-shell.sh:396-413`；`scripts/ffrumble.c:37,56-65,79-84`；0.46 `src/pos-input-surface.c:237-259,370-377,381-387,1927-1928`、`src/pos-keypad-button.h:18`、`src/phosh-osk-stub.c:596`。
- 引擎/词库：`out/osk-stub-rime-userdir-20261124/sm.puri.phosh.osk.gschema.xml:55-69,71-79,81-89,92-112`；0.46 `src/pos-completer-manager.c:131-133,138-176,246`、`src/completers/pos-completer-pipe.c:212`、`src/phosh-osk-enums.h:16-27`、`src/pos-input-surface.c:1911`；`patches-userland/zh-ime-rime-20261123/rime/pos-completer-rime.c:352-360,385-399`；`scripts/ime-single-stack.sh:121-136,232-247`；`scripts/deploy-desktop-shell.sh:495-560`；`PITFALLS/README.md:384`(#709)、`PITFALLS/sessions/346-*.md:27`。
- 声音：`scripts/asset-install-linux.sh:88-104`；`PITFALLS/sessions/330-*.md:26`；`packaging/elden-userland/files/usr/local/bin/feedback:1-9`；stevia `src/pos-input-surface.c:45-46,213-223`、`meson.build:121-123`；`archive/topics/AUDIO-INPUT-2026-10-04.md:119-123`。
- 自定义键：`out/…/sm.puri.phosh.osk.gschema.xml:55-69`；0.46 `src/pos-shortcuts-bar.c:14-15,212,350-357`、`src/pos-input-surface.c:214-226`、`src/pos-osk-widget.c:1814-1815,1827-1835`、`src/phosh-osk-stub.gresources.xml`；`patches-userland/zh-ime-rime-20261123/layout/{0002-*.patch,README.md:8-13}`。
- 生态/形态：0.46 `src/pos-settings-panel.c:67-81` + `src/pos-input-surface.c:517-528`；pms `src/ms-osk-panel.c:32,38,41,508-509,596-630,720-743`、`meson.build:187-190`、`src/ms-feedback-panel.c:33-37`、`src/ui/ms-feedback-panel.ui:66-67`、`src/ms-plugin.h:17`、`src/ms-plugin-loader.c:94-98`、`src/ms-application.c:559,586`、`src/ms-plugin-panel.h:18-25`；phosh `plugins/phosh-plugin.h.in:10-15`。
- 打包接入：`rootfs/debian/stage.sh:38-42,84-94,102-135`；`packaging/elden-userland/README.md:29,36`；`packaging/elden-userland/sources.tsv:3-9`；`build/artifacts.tsv:3-9`；`build/all.sh:22`；`tools/verify.sh:245-264`；`rootfs/debian/tools/check-pkgmap.sh:189`。
