# withdrawn — 已废弃的 zh-ime 组件（2026-10-20）

保留作证据，不要部署。

| 文件 | 为什么废弃 |
|---|---|
| `candidate-bar.c`、`layer-shell-*`、`xdg-shell-*`、`tmin.c` | 自编 kimpanel 候选条。**实测证明不必要**：候选窗由 `fcitx5-gtk` 的 IM 模块自己画；且它对 wlroots layer-shell 的 ack_configure 时序有竞态（`zwlr_layer_surface_v1 code=2 "wrong configure serial"`），打字过程中会崩。 |
| `osk-ime.c`、`input-method-unstable-v2.xml` | 子代理给的 zwp_input_method_v2 控制面原型（想自己抢槽位拿 focus 事件）。未采用：抢槽位会挤掉 squeekboard ⇒ 没有键盘。实际采用 `elden-ime-focusd`（kimpanel 聚焦信号桥）。 |
| `zh-osk`、`osk-toggle`、`build.sh` | wvkbd 时代的启动器。wvkbd 只是"注入按键的层壳"，与 squeekboard 功能重叠且没有 OSK0 控制面/自动弹出能力。 |
