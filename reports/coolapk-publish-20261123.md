# 酷安发布记录（2026-11-23）

- 通道：coolapk-desktop 1.47.0 本地 Agent Bridge（MCP `127.0.0.1:47654`，用户授权直发）
- 纪律：每篇间隔 65s（>60s 冷却）；图经 `imagePaths` 由应用自读盘上传
- 稿件：`/tmp/coolapk-drafts/`（子代理备稿，数字逐一对照 INDEX §0 / TASKS / reports）

| # | 标题 | 配图 | feed id |
|---|---|---|---|
| 1 | 给 Y700 四代刷上纯主线 Linux —— 进度汇报 | `assets/coolapk-20261123/phosh-desktop-half-20261123.png`（现拍） | **75235220** |
| 2 | 原生桌面实拍篇：phosh + 触屏中文输入 + 每键震动 | `assets/coolapk-20261123/phosh-desktop-20261123.png`（3040×1902 现拍） | **75235246** |
| 3 | 安卓兼容与下一步：Waydroid / droidloom / Steam | 无图 | **75235266** |

- 三篇均 code=200、`dateline_text=刚刚`；`adminInfo=动态审核后可见`（正常审核流）
- 发布脚本：`/tmp/publish.py`（JSON-RPC over MCP，60s 冷却内建）

## 发布后核查（2026-11-23 20:3x）
- 三篇在线：feed_detail block_status=0、`dateline_text=23分钟前`；互动数初始 0（正常）
- 注意：帖面「设备」显示账号挂的 Redmi K70（账号级设置），正文首篇已写明 Y700 四代——如介意可后续 coolapk_update_feed 或改账号设备名
- v13 lore 复核：投出 ~1.5h 尚未入索引（v11/v12 均已在档）；`!46` pipeline #2 success（ea9fe3d5）；INBOX 0 回复
