# #755 `uinput-touch` 注入的触摸只到 toplevel，**到不了宿主 OSK 层表面** ⇒ 自动化测键盘会是假阴性

- 日期：2026-11-28（T38 第二阶段）
- 现象：同一会话、同一注入工具，点击**应用窗口**（小红书输入框 / Settings 搜索框）100% 生效；点击**宿主 phosh OSK 的按键**（全键盘 `q`/`e`、数字键盘 `1`）**一个字符都进不去**，键盘也不消失。
- 更坏的一点：点数字键盘 `1` 时，**应用**反而收到 `HIDE_SOFT_INPUT fromUser true`（触摸穿到应用）——与用户报的「点一个数字键盘就自隐」同形，于是**无法用这条通道区分**「OSK 的 keypad 布局 input region 坏了」和「注入触摸本来就绕过 OSK」。
- 交叉对照：`ydotool` 鼠标点击 OSK 同样不进字，反而把 phosh 推进 overview。
- 判据/影响：
  - 「键盘能不能用」这类验收**必须用真手**（T36/T38 口径），或用 `WAYLAND_DEBUG=1` 观察 osk-stub 有没有收到 `wl_touch`，**不能**拿 `uinput-touch tap` 的失败当作「OSK 坏了」的证据（假阴性），也不能拿它的「应用收到隐藏请求」当作「触点归属缺陷」的证据。
  - 这条同时解释了为什么「用户在真机上打字正常，而自动化总失败」不矛盾。
- 复现：`reports/t38-keypad-split-20261128.md` §3 的五行对照表；截图 `reports/artifacts/t38-20261128/{t38-10-settings,t38-11-typed,t38-15-mouse-on-keypad}.png`。
