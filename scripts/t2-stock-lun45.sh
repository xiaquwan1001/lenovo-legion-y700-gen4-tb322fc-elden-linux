#!/bin/sh
# T2: 按 LUN 刷原厂（LUN4 全套 + LUN0 全套），日志到 artifacts/bl-stuck-20261118/flash/T2.log
# 由 agent 2026-11-17 19:4x 驱动；用户口径「先做前两步，只有推到 T3 全量线刷才告知用户」。
set -u
PKG=$HOME/文档/TB322FC_15.10.259
L=$HOME/下载/tb322fc/xbl_s_devprg_ns.melf
Q=$HOME/edl/qdl/build/qdl
O=/home/xuqianhui/y700-elden/reports/artifacts/bl-stuck-20261118/flash
LOG=$O/T2.log
say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

say "=== T2 start ==="
cd "$PKG" || exit 1

# 0) 进 EDL（若已在 9008 则跳过）
if lsusb | grep -q '05c6:9008'; then
  say "already in EDL"
else
  say "fastboot oem edl"
  timeout -k 5 20 fastboot -s HA2EXB0E oem edl 2>&1 | tee -a "$LOG"
  sleep 6
fi
if ! lsusb | grep -q '05c6:9008'; then
  say "!! EDL 未出现，退出（不改任何东西）"
  exit 2
fi

# 1) LUN4（37 分区 / ~794 MiB）：boot/dtbo/vbmeta/固件 + GPT
say "--- step1: rawprogram4 + patch4"
timeout -k 10 1800 "$Q" -f -s ufs "$L" rawprogram4.xml patch4.xml 2>&1 | tail -6 | tee -a "$LOG"
say "step1 rc=$?"

# 2) LUN0（super/userdata/metadata/lenovoraw/lenovocust + GPT）：~15 GiB
say "--- step2: rawprogram_save_persist_unsparse0 + patch0"
timeout -k 10 3000 "$Q" -f -s ufs "$L" rawprogram_save_persist_unsparse0.xml patch0.xml 2>&1 | tail -6 | tee -a "$LOG"
say "step2 rc=$?"

# 3) reset 回正常启动
say "--- reset"
timeout -k 10 120 "$Q" -s ufs "$L" reset 2>&1 | tail -2 | tee -a "$LOG"

# 4) 观察 120 s：fastboot 消失 ⇒ 可能在起 Android
for i in 1 2 3 4 5 6; do
  sleep 20
  FB=$(timeout -k 5 8 fastboot devices 2>/dev/null | head -1)
  AD=$(timeout -k 5 6 adb devices 2>/dev/null | grep -v '^List' | grep -c 'device$')
  LU=$(lsusb | grep -Ec '18d1:d00d|05c6:9008')
  say "poll $i (t=$((i*20))s): fastboot='${FB:-none}' adb_dev=$AD usb_fb_edl=$LU"
  [ -n "$FB" ] || { say "fastboot 已消失 ⇒ 可能进系统"; break; }
done
say "=== T2 end ==="
