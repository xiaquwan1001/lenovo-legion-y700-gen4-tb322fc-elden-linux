# 2026-11-28 规划：安卓兼容路线裁决材料 + 原生 APK 基础设施 + phosh 三回复

## 背景（本轮起点）
- 传感器 lane（子代理 `impl-worker`，08:44–09:01Z）因上游 502 中途死掉。已取得的进展：
  SSC 链路通（`HasAccelerometer=true`、`ssccli` 出值）；**ALS 抖动实锤**（60 s lux 12 次变化 64→240，背光 10 次写入）；
  重启 `iio-sensor-proxy` 后 **gsd-power 的 LightLevel claim 丢失**（LightLevel 恒 0）⇒ 卡在这一步。
- outlook 收到 Guido Günther 三封真回复（2026-11-28 16:43–16:50 CST）：
  - phoc `!829`（cursor edge-swipe）：**Linux 没有 "back" 概念，先在 Wayland 协议/工具包层立起来**；先做 follow-up 里列的讨论，代码后补；**是否 AI 生成？降 verbose**。
  - phoc `#125`：问题不在 phoc 代码而在 toolkit/协议整合，让我接手 !829 里的那条。
  - gmobile `!131`（Y700 面板）：是否 AI 生成？看 `codeberg.org/Phosh/phosh-dev-site/pulls/15` 的 GenAI 规约；**对齐同区域其他人做法、改 commit message 与 MR 描述**，以后都注意。

## 本轮派发（并行）
| lane | 归属 | 产物 |
|---|---|---|
| A droidloom vs Waydroid 路线裁决 | 子代理（主机只读） | `reports/android-compat-route-decision-20261128.md` |
| B 自建安卓基础设施 / 原生 APK 安装+运行 | 子代理（主机只读） | `reports/native-apk-install-feasibility-20261128.md` |
| C 传感器收尾（ALS 迟滞 + 姿态矩阵 + gsd-power claim） | 子代理（**唯一设备 lane**） | `reports/sensors-orientation-als-20261128.md` |
| D phosh 三回复处置 | 父代理 | 三处回帖 + `!829` 转 draft 且描述瘦身 + `!131` 描述/commit 瘦身 + 协议层讨论起头 + 台账 |

## 硬约束
- 子代理只写自己那一个报告文件，**不改 TASKS/ / INDEX.md**（父代理统一并入，避免多 writer 冲突）。
- 设备 lane 串行：同一时刻只有 lane C 碰设备；任何 `restart greetd`/重装/改属主一律不做。
- 外发（GitLab comment / 邮件）由父代理执行，子代理只出稿。
