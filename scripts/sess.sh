#!/bin/sh
# sess.sh — 本项目（y700-elden）的会话检索入口。
#
# 为什么需要它：pi 的项目级 sessionDir = .pi/sessions（.pi/settings.json），
# 而全局 sess 默认扫 ~/.pi/agent/sessions ⇒ 直接跑 sess 会漏掉本项目 95% 的会话，
# 还会混入其它项目里提到 elden 的会话（实测：顶层 198 个 jsonl，全局目录只有 9 个旧文件）。
#
# 用法：
#   scripts/sess.sh 相机            # 关键词/正则
#   scripts/sess.sh -n 10 Q28       # 透传 sess 的所有参数
#   scripts/sess.sh -a 3 vk127      # 只看最近 3 天
#
# 另两条等价途径：pi 会话选择器 /resume（按 cwd + sessionDir 列本项目会话）；直接 rg .pi/sessions。
root=$(cd "$(dirname "$0")/.." && pwd)
PI_SESSION_DIR="$root/.pi/sessions" exec sess "$@"
