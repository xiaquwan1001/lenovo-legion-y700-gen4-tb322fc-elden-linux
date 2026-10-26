# 100 · OpenRC oneshot 里同步 `sleep` 会阻塞整个 default runlevel；WCD939X 冷起 5k 行错误读吃掉 20 s

- 日期：2026-10-26（vk163 真 POR 实测）
- **#420** `bt-alias`（oneshot）脚本里 `sleep 30` 等蓝牙固件：OpenRC default runlevel 串行 ⇒
  `elogind`/`greetd` 被一起推迟 30 s，现象 =「开机黑屏/logo 卡一会、桌面晚来」。
  修法 = 等待逻辑放**后台子 shell**，oneshot 立即 `exit 0`；实测子 shell 存活、alias 正常。
  判据：`elogind` 的 `/proc/<pid>/stat` starttime 从 50 s 降到 27 s。
- **#421** `wcd939x_codec` 冷起 `ASoC error (-16)` 连续 **5425 行**（t=9.5→29.3 s，~3.7 ms/行）⇒
  **20 s** 是驱动读重试本身，不是 tty0 刷屏；把 `printk` console level 降到 1 只消除刷屏与观感，
  耗时不减。音频最终可用，待查 regmap EBUSY 调用循环。
- 附带：`/init` 的 `echo 8 > printk` 改成 `elden_console_loglevel`（默认 1），`greetd` 起后恢复 7；
  dmesg 内容不变。
