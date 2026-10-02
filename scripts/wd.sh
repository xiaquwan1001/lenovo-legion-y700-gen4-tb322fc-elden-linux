#!/bin/bash
# wd.sh — 主机侧 Waydroid 快捷控制（**每次 <15s 返回，绝不长等待**）
#
# 用法：
#   scripts/wd.sh state            # 设备/容器/网络 全景快照
#   scripts/wd.sh start            # 后台起容器（立即返回）
#   scripts/wd.sh stop|session|net|log [n]|elapsed
#   scripts/wd.sh raw '<cmd>'      # 在设备上执行任意命令
#   scripts/wd.sh sync             # 同时打印主机侧 repo sync 状态
set -u
TAB=${TABLET:-root@192.168.7.1}
HERE="$(cd "$(dirname "$0")" && pwd)"
SSH=(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o ServerAliveInterval=5)
TMO=${TMO:-25}

remote() { timeout "$TMO" "${SSH[@]}" "$TAB" "$@"; }

case "${1:-state}" in
  raw) shift; remote "$*";;
  sync)
    TREE="${TREE:-${AOSP_TREE:-/mnt/Samsung/waydroid-build}}"
    cd "$TREE" 2>/dev/null || exit 1
    a=$(du -sb .repo 2>/dev/null | cut -f1); sleep 5; b=$(du -sb .repo 2>/dev/null | cut -f1)
    echo "repo: $((b/1024/1024/1024)) GiB (+$(( (b-a)/1024/1024 )) MiB/5s)"
    df -h /mnt/Samsung | tail -1
    if pgrep -f 'sync-resume2' >/dev/null 2>&1 || pgrep -f 'sync-adaptive' >/dev/null 2>&1; then
      echo "sync: 运行中"
    else
      echo "sync: 未运行"
    fi
    ;;
  *)
    remote "sh /usr/local/sbin/wd-ctl.sh $*";;
esac
