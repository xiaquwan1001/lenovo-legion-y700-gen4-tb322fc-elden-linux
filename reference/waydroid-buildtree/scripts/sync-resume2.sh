#!/bin/bash
# sync-resume2.sh — 2026-10-01 晚网络拓扑：github 直连被墙、代理可用；AOSP 走清华直连。
#   github/gitlab  -> Clash 代理 127.0.0.1:7897
#   清华 AOSP 镜像 -> 直连（no_proxy）
# 用法： nohup ./sync-resume2.sh >> sync.log 2>&1 &
set -u
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/bin:$PATH"

PROXY="${PROXY:-http://127.0.0.1:7897}"
SOCKS="${SOCKS:-socks5://127.0.0.1:7897}"
export http_proxy="$PROXY" https_proxy="$PROXY" all_proxy="$SOCKS"
export HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY" ALL_PROXY="$SOCKS"
export no_proxy='mirrors.tuna.tsinghua.edu.cn,127.0.0.1,localhost,::1,ustc.edu.cn,.ustc.edu.cn'
export NO_PROXY="$no_proxy"

# git 的 config 代理优先于 env；清掉以免打架（env 已设）
for k in http.proxy https.proxy; do
  git config --global --get "$k" >/dev/null 2>&1 && git config --global --unset "$k" && echo "[sync2] unset global $k"
done

echo "[sync2] proxy=$PROXY  no_proxy=$no_proxy"
echo "[sync2] precheck github(proxy): $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://github.com/)"
echo "[sync2] precheck ustc(direct): $(env -u http_proxy -u https_proxy -u all_proxy curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://mirrors.ustc.edu.cn/aosp/)"

attempt=0
while true; do
  attempt=$((attempt + 1))
  echo "[sync2] attempt $attempt $(date)"
  repo sync -j4 --no-clone-bundle --optimized-fetch
  rc=$?
  if [ $rc -eq 0 ]; then echo "[sync2] SUCCESS after $attempt attempt(s) $(date)"; break; fi
  echo "[sync2] attempt $attempt failed rc=$rc $(date)"
  [ "$attempt" -ge 20 ] && { echo "[sync2] giving up after 20 attempts"; break; }
  sleep 20
done
echo "[sync2] end $(date)"
