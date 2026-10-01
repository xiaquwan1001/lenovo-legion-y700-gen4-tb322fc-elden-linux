#!/bin/bash
# net-egress.sh — 选择上网出口：教育网有线 enp6s0（快）vs wifi 热点 wlp5s0（慢）
#
# 背景（2026-10-01 实测，USTC 镜像同文件）：
#   enp6s0（教育网有线，114.214.188.166）  107 MB/s
#   wlp5s0（手机热点，192.168.43.197）      13 MB/s
# 但默认路由 metric 是 wifi 600 < 有线 20050 → **所有流量都在走慢的 wifi**
# （NetworkManager 给有线加了 +20000 惩罚，改 route-metric 也压不下去，所以这里用显式路由）。
#
# 用法：
#   bash net-egress.sh test                 # 测速对比（不需要 root）
#   sudo bash net-egress.sh mirrors         # ✅推荐：只把教育网镜像/校内段走有线（最安全）
#   sudo bash net-egress.sh all             # 默认路由也走有线（用于测代理/国际速度）
#   sudo bash net-egress.sh status          # 看当前生效的路由
#   sudo bash net-egress.sh revert          # 撤销本脚本加的路由
set -u

IF=enp6s0
GW=114.214.176.1
TAG=			# 用 metric 10/1 标识本脚本的条目

# 教育网常用段（可自行追加）
PREFIXES_MIRROR=(
  166.111.0.0/16    # 清华 TUNA
  202.38.0.0/16     # 中科大 USTC
  210.45.0.0/16     # 中科大 USTC（另一段）
  114.214.0.0/16    # 本校（含 114.214.176.1 网关段）
  202.112.0.0/16    # CERNET 骨干
)

need_root() { [ "$(id -u)" -eq 0 ] || { echo "需要 root：sudo bash $0 $*" >&2; exit 1; }; }

speedtest() {
  local url=$1 label=$2
  for i in enp6s0 wlp5s0; do
    local sp
    sp=$(timeout 15 curl -s --interface "$i" --max-time 8 -o /dev/null -w '%{speed_download}' "$url" 2>/dev/null)
    printf "  %-8s %-22s %7.2f MB/s\n" "$i" "$label" "$(echo "${sp:-0}/1048576" | bc -l)"
  done
}

cmd_test() {
  echo "== 国内镜像（CERNET）=="
  speedtest "https://mirrors.ustc.edu.cn/alpine/v3.21/releases/aarch64/alpine-virt-3.21.0-aarch64.iso" "ustc"
  speedtest "https://mirrors.tuna.tsinghua.edu.cn/anaconda/archive/Anaconda3-2024.10-1-Linux-x86_64.sh" "tuna"
  echo "== 当前出口判断 =="
  ip route get 202.38.95.110 | head -1
  ip route get 166.111.4.203 | head -1
}

cmd_mirrors() {
  need_root mirrors
  for p in "${PREFIXES_MIRROR[@]}"; do
    ip route replace "$p" via "$GW" dev "$IF" metric 10
    echo "  + $p via $IF"
  done
  echo "已把教育网段改走有线。验证："
  ip route get 202.38.95.110 | head -1
  ip route get 166.111.4.203 | head -1
  echo
  echo "提示：这是**临时**路由，重启失效。要持久化见同目录 NET-EGRESS-PLAN 文档。"
}

cmd_all() {
  need_root all
  ip route replace default via "$GW" dev "$IF" metric 1
  echo "  + default via $IF metric 1（优先于 wifi 600）"
  ip route show default
}

cmd_revert() {
  need_root revert
  for p in "${PREFIXES_MIRROR[@]}"; do
    ip route del "$p" via "$GW" dev "$IF" metric 10 2>/dev/null && echo "  - $p"
  done
  ip route del default via "$GW" dev "$IF" metric 1 2>/dev/null && echo "  - default via $IF metric 1"
  echo "已撤销，回到原状："
  ip route show default
}

cmd_status() {
  echo "== 默认路由 =="; ip route show default
  echo "== 本脚本条目 =="; ip route show | grep -E "dev $IF .*metric (1|10) " || echo "  (无)"
  echo "== 出口判断 =="
  for h in 202.38.95.110 166.111.4.203 140.82.121.4; do
    printf "  %-16s %s\n" "$h" "$(ip route get $h 2>/dev/null | head -1)"
  done
}

case "${1:-status}" in
  test)    cmd_test;;
  mirrors) cmd_mirrors;;
  all)     cmd_all;;
  revert)  cmd_revert;;
  status)  cmd_status;;
  *) echo "用法: $0 {test|mirrors|all|revert|status}" >&2; exit 1;;
esac
