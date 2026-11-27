#!/bin/bash
# SEND.sh —— kaanapali TNOC periphid 草稿投递脚本（**硬拒绝：本版不投递**）
#
# 为什么拒绝：本目录的补丁与上游 2026-11-18 已投的
#   [2/4] arm64: dts: qcom: kaanapali: add periphid for traceNoC  (patchwork id 14995781,
#   Abel Vesa / Konrad Dybcio 已 Reviewed-by)
# 同实质；且已进 next 的 [v7,3/5] kaanapali: bind traceNoC on the platform bus 会改掉同一行。
# 证据：同目录 logs/patchwork-dupcheck.log、reports/kaanapali-tnoc-periphid-20261127.md。
#
# 若父级复核后仍要投（例如上游最终回退到 periphid 路线），必须**换一封新 diff**并重跑
# 同目录 GATES.md 的门禁，然后另写 SEND 脚本；本脚本故意不留后门。
set -uo pipefail
cd "$(dirname "$0")" || exit 1

cat <<'EOF'
⛔ 拒绝发送：kaanapali TNOC periphid 草稿已被上游同型投递覆盖（patchwork 14995781 / 14995782 / 14995780），
   且 in-next 的 v7 系列（[v7,3/5] kaanapali、[v7,4/5] sm8750）已将这两处节点改为平台总线绑定。
   见 README.md 与 ../reports/kaanapali-tnoc-periphid-20261127.md（本目录 logs/patchwork-dupcheck.log 为原始记录）。
EOF
exit 1
