#!/bin/bash
# Resume Waydroid/LineageOS repo sync with a working network path.
#
# Network findings (2026-10-01, after the disk+reboot):
#   - Clash proxy 127.0.0.1:7897 is currently DEAD (all https via proxy -> 000).
#   - Direct works for: github.com, gitlab.com, storage.googleapis.com, raw.githubusercontent.com
#   - android.googlesource.com is blocked direct -> rewritten to the TUNA AOSP mirror.
#
# So: run everything with proxy env stripped, and rely on the global
# `url.https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/.insteadOf` rewrite for AOSP.
#
# Usage:  nohup ./sync-resume.sh >> sync.log 2>&1 &
# Re-runnable: repo sync is resumable.

set -u
cd "$(dirname "$0")" || exit 1
export PATH="$HOME/bin:$PATH"

# Strip any proxy from the environment for this process.
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
export no_proxy='*' NO_PROXY='*'

# git's *config* proxy beats the environment, so neutralise it for the duration.
for k in http.proxy https.proxy; do
  if git config --global --get "$k" >/dev/null 2>&1; then
    git config --global --unset "$k"
    echo "[sync-resume] unset global $k"
  fi
done

echo "[sync-resume] start $(date)"
attempt=0
while true; do
  attempt=$((attempt + 1))
  echo "[sync-resume] attempt $attempt $(date)"
  repo sync -j4 --no-clone-bundle --optimized-fetch
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "[sync-resume] SUCCESS after $attempt attempt(s) $(date)"
    break
  fi
  echo "[sync-resume] attempt $attempt failed rc=$rc $(date)"
  if [ "$attempt" -ge 20 ]; then
    echo "[sync-resume] giving up after $attempt attempts"
    break
  fi
  sleep 20
done
echo "[sync-resume] end $(date)"
