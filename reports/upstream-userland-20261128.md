# 2026-11-28 用户态上游/外发台账（droidloom issue + gmobile MR + phoc #125 证据回帖）

> 三件都是用户 2026-11-28 当面裁决后执行；均按「AI 披露 / 可复现证据 / 逐条回应」三件前提，文末已加披露行。

## 1. droidloom issue #69（T32 的层次结论反馈）

- URL：<https://github.com/denialwm/droidloom/issues/69>
- 标题：*Graphical Android IMEs are never presented on the host (Trime/Fossify), so selecting one yields no visible keyboard; only the bundled headless IME + host OSK works*
- 正文留档：`reports/artifacts/droidloom-graphical-ime-20261128/body.md`（含环境、复现命令、`mInputShown`/`grim` 对照、源码指针、#65 关系、三条 asks）
- 关键事实：图形 IME 在 cell 内 `mInputShown=true`/`mImeWindowVis=3`/`screencap` 有键盘，宿主 `grim` 无键盘；`HostInputMethod` + 宿主 OSK 可用（含 RIME 中文）。
- 发布方式：`gh issue create`（工作站需 `env -u *_proxy`，否则 TLS handshake timeout）。

## 2. gmobile MR !131（T33 的 `lenovo,elden` 面板条目）

- URL：<https://gitlab.gnome.org/World/Phosh/gmobile/-/merge_requests/131>
- 分支：`xuqianhui1001/gmobile:lenovo-elden-panel` → `World/Phosh/gmobile:main`；commit `ac5aae2a6e20c792ca743cc99105b03175b5acb1`
- 改动：`data/devices/display-panels/lenovo,elden.json`（新增）+ `data/gmobile.gresources.xml`（登记一行）
- 数据：1904×3040、8.8" 16:10（有效区 118.6×189.4 mm → width 119 / height 189）、无 cutout、`corner-radii: [80,80,80,80]`
- 半径来源：原厂 Android persist 存档 dump `backup/HA2EXB0E-16+512/unique/part-persist.bin` 中 WindowManager 的
  `roundedCorners RoundedCorners{[RoundedCorner{position=TopLeft, radius=80, center=Point(80, 80)} …]}`（同一 dump 记 1904×3040）；
  旁证 = 原厂 ROM `super_6.img` 的 `vendor.display.enable_rounded_corner=1`
- 本机验证：JSON 可解析；`glib-compile-resources --sourcedir=data` 能生成 gresource（17 700 B，含新 JSON）
- MR 状态：`opened` / `mergeable` / **pipeline success**（<https://gitlab.gnome.org/xuqianhui1001/gmobile/-/pipelines/1154683>）

## 3. phoc #125 证据回帖（D13「吞事件」的上游路线起点）

- URL：<https://gitlab.gnome.org/World/Phosh/phoc/-/issues/125>（note id `2948914`，2026-11-28T01:55:21Z）
- 内容：实测边界（lisgd 旁听 ⇒ 事件照送应用，Firefox 误滚动；`EVIOCGRAB` 重放不该放在守护里）、方向死区数据
  （`-r 45` 后 20.8°/44.7°/315.1° 才可用）、以及一个具体实现提议：phoc 内 `PhocGestureSwipe` 绑左右边缘 + 识别时 cancel 触摸序列，
  并问「关窗动作放 phoc 还是由 phosh 消费」。
- 待维护者表态后再决定是否按该形状提 MR（避免先交未编未测的补丁）。

## 4. 合规与复核

| 项 | 状态 |
|---|---|
| AI 披露（三件前提之一） | 三处均已加「AI-drafted, human-reviewed」行（issue 正文末、MR 描述末、phoc #125 note 末，note 于 01:57:09Z 补编辑） |
| 可复现证据 | issue/MR 都带命令或数据来源；本仓对应报告 `reports/trime-droidloom-keyboard-20261128.md`、`reports/gmobile-panel-entry-prep-20261128.md` |
| 凭据 | GNOME GitLab token 来自 keyring；API 走 bettbox `127.0.0.1:7890`（直连 406），push 走 `git@ssh.gitlab.gnome.org` |
| 复核 | issue URL 200、MR `mergeable`、note 返回 id；均未改写既有线程结论 |
