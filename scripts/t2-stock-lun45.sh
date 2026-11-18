#!/bin/sh
# T2: 按 LUN 刷原厂（LUN4 全套 + LUN0 全套），日志到 artifacts/bl-stuck-20261118/flash/T2.log
# 由 agent 2026-11-17 19:4x 驱动；用户口径「先做前两步，只有推到 T3 全量线刷才告知用户」。
#
# ⚠ 2026-11-18 修复（PITFALLS #674/#675 + 本轮审查）：
#   * 每条 qdl 都必须带 `-R`（= --skip-reset）**除了最后那发 reset**：2026-11-17 19:37 就是
#     「step1 未加 -R ⇒ 会话末自动 reset ⇒ step2 立刻 SAHARA: failed to read request」。
#   * rc 不能写成 `say "step1 rc=$?"`：pipeline 的 $? 恒等于最后一段（tail/tee）= 0，失败被吞。
#     改成先落日志文件再取 `${PIPESTATUS[0]}`，非 0 立刻停止（失败即停，不再往下刷 LUN0 15 GiB）。
#   * 写前先 `slot-attr.py show` 一次并把结果打进日志（#672：UNBOOTABLE 未清 ⇒ 任何实验都无效）。
set -u
PKG=$HOME/文档/TB322FC_15.10.259
L=$HOME/下载/tb322fc/xbl_s_devprg_ns.melf
Q=$HOME/edl/qdl/build/qdl
O=/home/xuqianhui/y700-elden/reports/artifacts/bl-stuck-20261118/flash
LOG=$O/T2.log
say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

say "=== T2 start ==="
cd "$PKG" || exit 1

# 写前取证：槽属性一次（失败路径也留日志；判据见 PITFALLS #672/#308）
say "--- pre: A/B 槽属性（LUN4 boot_a/boot_b byte6）"
if command -v python3 >/dev/null 2>&1 && [ -f "$HOME/y700-elden/scripts/slot-attr.py" ]; then
  timeout -k 5 20 python3 "$HOME/y700-elden/scripts/slot-attr.py" --device /dev/sde show 2>&1 | tee -a "$LOG" \
    || say "（设备不在 Linux，拿不到槽属性；本次按 EDL 直刷，刷完要复核）"
else
  say "（主机侧无法读槽属性；刷完必须复核）"
fi

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
#    -R = 跳过会话末 reset ⇒ 设备留在 9008，下一发才能接上（#674）
say "--- step1: rawprogram4 + patch4"
: > "$O/step1.raw.log"
timeout -k 10 1800 "$Q" -R -f -s ufs "$L" rawprogram4.xml patch4.xml >"$O/step1.raw.log" 2>&1
rc1=$?
tail -6 "$O/step1.raw.log" | tee -a "$LOG"
say "step1 rc=$rc1"
[ "$rc1" -eq 0 ] || { say "!! step1 失败 ⇒ 停止（不再写 LUN0），设备留在 9008"; exit 3; }

# 2) LUN0（super/userdata/metadata/lenovoraw/lenovocust + GPT）：~15 GiB
say "--- step2: rawprogram_save_persist_unsparse0 + patch0"
: > "$O/step2.raw.log"
timeout -k 10 3000 "$Q" -R -f -s ufs "$L" rawprogram_save_persist_unsparse0.xml patch0.xml >"$O/step2.raw.log" 2>&1
rc2=$?
tail -6 "$O/step2.raw.log" | tee -a "$LOG"
say "step2 rc=$rc2"
[ "$rc2" -eq 0 ] || { say "!! step2 失败 ⇒ 停止，设备留在 9008（不要盲发 reset）"; exit 3; }

# 2b) 写后校验：GPT 主表读回比 sha（qdl 退出码不可信，PITFALLS #669）
say "--- step2b: 读回六 LUN 主表并比 sha"
: > "$O/readback.log"
timeout -k 10 300 "$Q" -R -s ufs "$L" \
  read 0/0+6 "$O/rb-gpt0.bin" read 4/0+6 "$O/rb-gpt4.bin" >"$O/readback.log" 2>&1
say "readback rc=$? （文件在 $O/rb-gpt*.bin；与 $PKG/gpt_main0.bin,gpt_main4.bin 逐字节比）"
for p in 0 4; do
  if cmp -s "$O/rb-gpt$p.bin" "$PKG/gpt_main$p.bin"; then say "GPT LUN$p 读回 = 原厂件 OK"
  else say "WARN GPT LUN$p 读回 != 原厂件（属性字节差异属正常，几何差异要查）"; fi
done

# 3) reset 回正常启动（唯一一条不带 -R 的 qdl）
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
