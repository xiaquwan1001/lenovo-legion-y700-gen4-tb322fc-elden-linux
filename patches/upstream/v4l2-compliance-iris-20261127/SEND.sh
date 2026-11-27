#!/bin/sh
# SEND.sh — 投递 v4l2-compliance-iris 系列到 linux-media + linux-arm-msm。
# 默认 dry-run；--send 才真发。硬拒绝重复发送（sent.marker 存在即退出）。
#
# 发前三件（硬性）：
#   1) 把每贴 Signed-off-by 的 "Elden Upstream <upstream@example.invalid>" 换成真实作者；
#   2) 确认 0002（colorspace 默认）想清楚维护者会怎么说（见 REPORT.md §5）；
#   3) 走技能 upstream-mail-ustc 的 git send-email 配置（USTC 邮箱通道）。
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
MARKER="$DIR/sent.marker"
TO="--to=linux-media@vger.kernel.org --cc=linux-arm-msm@vger.kernel.org"
FROM="--from=<REPLACE-WITH-REAL-AUTHOR-EMAIL>"

if [ -f "$MARKER" ]; then
	echo "REFUSE: $MARKER exists — already sent once, not resending." >&2
	exit 2
fi

echo "== dry-run (default). 用 --send 真发。 =="
echo "targets: linux-media@vger.kernel.org + linux-arm-msm@vger.kernel.org"
echo "patches:"
ls -1 "$DIR"/0*.patch

if [ "${1:-}" != "--send" ]; then
	echo "== (dry-run only; nothing sent) =="
	exit 0
fi

# 真发：git send-email 需要 git 仓库上下文；用 format-patch 产物直接发。
git send-email $TO $FROM --confirm=never "$DIR"/0*.patch
date -u +"sent at %Y-%m-%dT%H:%M:%SZ" > "$MARKER"
echo "sent; marker written to $MARKER"
