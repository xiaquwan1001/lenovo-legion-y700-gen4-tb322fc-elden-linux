# #709 `phosh-osk-stub` 0.46 的 `completion-mode` **没有 `always`**（枚举只有 none/hint/manual）——照新版本文档配会静默「什么都不发生」

- 日期：2026-11-21 17:0x（U2 HA2EXB0E，现役 trixie 栈 `phosh-osk-stub 0.46.0-1`）
- 触发：按 `reports/ime-osk-zh-matrix-20261122.md` 的推荐路线 R1 落地「`completion-mode=always`」时，
  `gsettings set` 直接报 **`提供的值不在有效范围内`**；`sm.puri.phosh.osk.enums.xml` 里只有 `nick="none|hint|manual"`。

## 判据（三条，都可离线复现）

- **1)** `gsettings set sm.puri.phosh.osk completion-mode "['always']"` ⇒ 报「值不在有效范围内」；
   `gsettings get sm.puri.phosh.osk completion-mode` 仍 `['hint']`。
- **2)** `grep -o 'nick="[a-z]*"' /usr/share/glib-2.0/schemas/sm.puri.phosh.osk.enums.xml | sort -u`
   ⇒ **none / hint / manual**（无 always）。Debian 侧同版本只有 `0.46.0-1`（sources.debian.org API 现查：仅 trixie 一版）。
- **3)** `Completers` 家族在机存在且可设：`sm.puri.phosh.osk.Completers default`（默认 `''`）、
   `sm.puri.phosh.osk.Completers.Pipe command`（**默认 `cat`**，即候选=preedit 本身）。
   ⇒ 「pipe 候选引擎」这条路本身成立，卡的是**触发模式**名字。

## 处置

- 现役可用组合 = `completion-mode ['hint','manual']` + `Completers default=pipe` + `Completers.Pipe.command=<helper>`；
  `hint` 只在客户端声明 completion hint 时触发（GTK3 多数输入框不声明），`manual` 需 OSK 上的完成键。
- 真想要「每键都喂」得 **1 行源码补丁**（给 `PhoshOskCompletionModeFlags` 加 `ALWAYS` 并在 `pos-input-surface`
  里把 `POS_COMPLETION_MODE_ALWAYS` 视作常开），或等上游发版 —— **不要**把新版本 README 的参数直接写进本机配置。
- 已落地（H-a 档 helper）：`packaging/elden-userland/rootfs-overlay/usr/local/bin/elden-pinyin-completer`
  （pypinyin 反查单字 + 常用词表；`printf nihao | elden-pinyin-completer` → `你好 / 尼好`），
  契约按 `pos-completer-pipe.c`「**每键 spawn 一次**」实现；设备侧需 `python3-pypinyin`（`apt install` 0.54.0-1 已装）。
- **`manual` 的入口就是 OSK 菜单里的「Word completion」开关**（GResource `completion-bar.ui` 里的
  `GtkModelButton id="word_completion_btn"` → action `win.word-completion`，属性名 `completion-enabled`），
  没有对应的 gsettings 键 ⇒ 只能点 GUI（☰ 菜单项）。实测：只设 `completion-mode ['hint','manual']` 且不点该开关时，
  completer **一次都不会被 spawn**（helper 的调用日志为空）。
- 人工判据（2 min，需真 IC）：Firefox 地址栏敲 `nihao` ⇒ OSK 候选条出现「你好」且点选后中文上屏；
  未验证项 = GTK3 输入框是否会声明 completion hint（决定 `hint` 是否足够）。
