#!/bin/bash
# sync-adaptive.sh — 每次 attempt 前**自动探测** github 该走直连还是代理，避免网络拓扑反转后静默卡死。
#
# 背景：本机 github 的「直连 vs 代理(127.0.0.1:7897)」可用性会互相反转，
#       写死任一路径的脚本会在拓扑变了之后 0 B/s 挂着（git fetch 存活但不传数据）。
#       清华 AOSP 镜像始终直连（no_proxy 保证）。
#
# 用法： nohup ./sync-adaptive.sh >> sync.log 2>&1 &
set -u
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/bin:$PATH"

PROXY="${PROXY:-http://127.0.0.1:7897}"
PROBE_HOST="${PROBE_HOST:-https://github.com/}"
TUNA="${TUNA:-mirrors.tuna.tsinghua.edu.cn}"

log() { echo "[syncA] $*"; }

probe() {  # $1=url  $2=proxy|direct
  if [ "$2" = proxy ]; then
    curl -s -o /dev/null -w '%{http_code}' --max-time 8 -x "$PROXY" "$1" 2>/dev/null
  else
    env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
      curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$1" 2>/dev/null
  fi
}

set_proxy_mode() {   # $1 = proxy | direct
  # 清掉环境代理，用 git 的**按主机**配置，精准控制
  unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
  export no_proxy="$TUNA,127.0.0.1,localhost,::1"
  export NO_PROXY="$no_proxy"
  for host in github.com gitlab.com raw.githubusercontent.com; do
    if [ "$1" = proxy ]; then
      git config --global "http.https://$host.proxy" "$PROXY"
    else
      git config --global --unset "http.https://$host.proxy" 2>/dev/null || true
    fi
  done
  git config --global --unset http.proxy  2>/dev/null || true
  git config --global --unset https.proxy 2>/dev/null || true
  log "模式: github/gitlab -> $1   (AOSP -> 清华直连)"
}

choose_mode() {
  dc="$(probe "$PROBE_HOST" direct)"
  pc="$(probe "$PROBE_HOST" proxy)"
  log "探测 github: 直连=$dc  代理=$pc"
  if [ "$dc" = 200 ]; then echo direct
  elif [ "$pc" = 200 ]; then echo proxy
  else echo none; fi
}

attempt=0
while true; do
  attempt=$((attempt + 1))
  mode="$(choose_mode)"
  if [ "$mode" = none ]; then
    log "attempt $attempt: github 直连与代理都不可用，等 30s 重试（检查 Clash/网络）"
    sleep 30; continue
  fi
  set_proxy_mode "$mode"
  log "attempt $attempt $(date)"
  repo sync -j4 --no-clone-bundle --optimized-fetch
  rc=$?
  if [ $rc -eq 0 ]; then log "SUCCESS after $attempt attempt(s) $(date)"; break; fi
  log "attempt $attempt failed rc=$rc $(date)"
  [ "$attempt" -ge 20 ] && { log "giving up after 20 attempts"; break; }
  sleep 20
done
log "end $(date)"
