# #756 别 `pkill -x phosh-osk-stub`：键盘会「画得出来但按不动」，只能重启会话来复原

- 日期：2026-11-28（T38 实验期间的操作事故，用户当场报「数字键盘和字母键盘都无法键入、退格无效」）
- 我做了什么：为「重置 OSK 布局滞留」在设备上执行 `pkill -x phosh-osk-stub`（10:49:5x）。phosh 随即拉起新进程（新 PID `365710`，`phosh-osk-stub` 仍是 active），桌面看起来正常。
- 后果（用户真手实测）：OSK 仍**画得出来**，但按键**不响应** —— 数字键盘、字母键盘都打不进字符，退格也无效；随机按到一个位置反而冒出字符（`8`）随后键盘自己收回。随后自动化侧也无法判（注入触摸本来就到不了 OSK，见 `PITFALLS #755`）。
- 处置：`sudo systemctl restart greetd`（= 重开会话）⇒ phoc/phosh/phosh-osk-stub 三件新起（10:59:1x），桌面与键盘恢复（截图 `reports/artifacts/t38-20261128/t38-18-clean.png`、`t38-20-desk.png`）。
- 结论与纪律（**这是纪律，不是待查项**）：**不要用 `pkill phosh-osk-stub` 来重置键盘**；要重置就重启会话（`systemctl restart greetd`，约 25 s，`droidloom.service` 是 user unit 会停 ⇒ 重启后 `systemctl --user start droidloom.service` 拉回 cell）。
- 归因口径：本条证据 = 「pkill 前键盘可输入（用户此前正常打字）→ pkill 后立刻不可输入 → 重开会话后恢复」的时间序，**未做**「不经 pkill 时同现象」的阴性对照，所以表述为「pkill 后 OSK 状态不一致」而非唯一因果。
- 旁证价值：它也是解释「键盘能显示却打不进字」的**本机可造成的原因**之一 —— 以后遇到这类报告先问「这轮有没有动过 osk-stub / 会话」，再怀疑上游。
