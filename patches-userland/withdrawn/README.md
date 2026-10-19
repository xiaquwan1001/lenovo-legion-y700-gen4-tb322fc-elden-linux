# withdrawn — 已撤销的用户态补丁

> 保留历史补丁原文以便追溯，**不再被任何构建/安装脚本引用**。

| 补丁 | 撤销日期 | 原因 |
|---|---|---|
| `0003-phosh-auto-rotation-quick-setting.patch` | 2026-10-19 | **重复实现**：phosh 0.55 核心已内置旋转快捷设置（`src/quick-settings.c` 直接翻转 `orientation-lock`，即“方向锁定/自动旋转”磁贴）。额外插件是重复的第二个开关，用户裁定撤销。设备侧插件文件已删除、`sm.puri.phosh.plugins quick-settings` 已 reset 回默认。 |
