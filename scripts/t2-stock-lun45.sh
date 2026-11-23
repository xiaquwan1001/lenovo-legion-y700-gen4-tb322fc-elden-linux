#!/bin/sh
# ★ STALE 头注（2026-11-23，D5 批 4 / reports/scripts-hardening-4-20261123.md §2）：**保留为取证指针，不归档**。
#   不归档的理由：RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md:146 + TASKS/README.md 把本件当「卡 BL 后一条命令恢复」的
#   入口；它是 2026-11-17/18 那次**真恢复成功**的现场驱动程序（不可重建的一次性经验）。
#   ❗ 再启用硬约束（qdl 全 LUN 覆写是全仓最高危动作之一）：必须先过 `scripts/rawprogram-preflight.py`
#   + 写前六 LUN GPT dump（本件的 `-R`/rc 判据只解决会话生命周期，**不**解决「拿错包/拿错单元」）。
#     旧日志 = reports/artifacts/bl-stuck-20261118/flash/T2.log；坑见 PITFALLS #674/#675。
#
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
# 目标设备：不再写死序列号（U1/U2 任一台都能跑）；adb/fastboot 侧永不猜设备（PITFALLS #371）
SER=${SER:-HA2EXB0E}
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

# 0) 进 EDL。9008 归属必须先定：qdl 不认 serial（`-s ufs` 只选存储类型），会打到总线上
#    第一台 9008（PITFALLS #669 第一缺陷）。只接受「本脚本刚对 $SER 发过 oem edl」这条路径；
#    「已在 9008」必须由人显式确认 ALREADY_EDL=1。
edl_present() { timeout -k 5 5 lsusb -d 05c6:9008 >/dev/null 2>&1; }
if edl_present; then
  [ "${ALREADY_EDL:-0}" = 1 ] || {
    say "!! 总线已有 9008 设备：若它不是本机 $SER，qdl 会刷到那台上。确认后 ALREADY_EDL=1 重跑"
    say "   拓扑: $(timeout -k 5 5 lsusb -d 05c6:9008)"
    exit 2; }
  say "already in EDL (ALREADY_EDL=1)"
else
  say "fastboot oem edl ($SER)"
  timeout -k 5 20 fastboot -s "$SER" oem edl 2>&1 | tee -a "$LOG" || { say "!! oem edl 失败，退出"; exit 2; }
  for i in 1 2 3 4 5 6 7 8 9 10; do edl_present && break; sleep 2; done
fi
if ! edl_present; then
  say "!! EDL 未出现，退出（不改任何东西）"
  exit 2
fi

# 0.5) 写前存证：现存主 GPT（LBA0..33）——全量刷会重写 gpt_main0/gpt_main4，不先落一份就没有回退件。
#      qdl 自动探测 512/4096 扇区，读回长度据此判定单位（34*512=17408 / 34*4096=139264）。
TS=$(date +%Y%m%d-%H%M%S); SNAP=$O/pre-gpt-$TS; mkdir -p "$SNAP"
# P0-6（2026-11-19，LTBox 判据）：基线 dump 不允许 `|| true` 吞掉失败。三值判定
# present/absent/error 见 scripts/dump-verdict.py；只有 present 才能往下写盘 ——
# 没有回退基线就开刷，等于把「刷坏了没法回滚」当成默认。
DV=$HOME/y700-elden/scripts/dump-verdict.py
for spec in 0:gpt0 4:gpt4; do
  lun=${spec%%:*}; tag=${spec##*:}
  rlog=$SNAP/$tag-read.log
  timeout -k 10 300 "$Q" -R -s ufs "$L" read "$lun/0+34" "$SNAP/$tag-lba0-33.bin" >"$rlog" 2>&1
  rc=$?
  cat "$rlog" >>"$LOG"
  vd=$(timeout -k 5 30 python3 "$DV" --part "$tag-lba0-33" --rc "$rc" --log "$rlog" \
         --file "$SNAP/$tag-lba0-33.bin" --expect-bytes-oneof 17408,139264 2>&1)
  vrc=$?
  say "pre-gpt $tag $vd"
  [ "$rc" -eq 0 ] || say "!! pre-gpt $tag qdl rc=$rc（日志 $rlog）"
  [ "$vrc" -eq 0 ] || { say "!! 写前基线 dump 不可信（verdict rc=$vrc，不是 present）⇒ 一个字节都不写；先查 EDL/USB 再重跑"; exit 6; }
  sz=$(stat -c%s "$SNAP/$tag-lba0-33.bin" 2>/dev/null || echo 0)
  case $sz in
    17408) unit=512 ;;
    139264) unit=4096 ;;
    *) unit=? ;;
  esac
  say "pre-gpt $tag size=$sz (sector_unit=$unit) sha256=$(sha256sum "$SNAP/$tag-lba0-33.bin" 2>/dev/null | cut -d' ' -f1)"
done

# 0b) 写前几何预检（LTBox 评估 P0-1..4 的等价物，2026-11-18）：
#     缺字段/区间重叠/越界/镜像大于分区跨度/缺件 → 一律拒绝。`-f`(--allow-missing) 只在
#     显式 ALLOW_MISSING=1 时才加，否则它会把你「少带了 11 个 userdata_*.img」变成静默跳过。
say "--- pre: rawprogram 几何预检"
PRE=scripts/rawprogram-preflight.py
[ -f "$HOME/y700-elden/$PRE" ] && PRE=$HOME/y700-elden/$PRE
PF_EXTRA=""; [ "${ALLOW_MISSING:-0}" = 1 ] && PF_EXTRA="--allow-missing"
timeout -k 5 300 python3 "$PRE" rawprogram4.xml rawprogram_save_persist_unsparse0.xml \
  --gpt-for 0=gpt_main0.bin --gpt-for 4=gpt_main4.bin $PF_EXTRA 2>&1 | tee -a "$LOG"
pf_rc=${PIPESTATUS[0]}
say "preflight rc=$pf_rc"
[ "$pf_rc" -eq 0 ] || { say "!! 几何预检失败 ⇒ 一个字节都不写（改包或显式 ALLOW_MISSING=1）"; exit 5; }
QF=""; [ "${ALLOW_MISSING:-0}" = 1 ] && { QF="-f"; say "（ALLOW_MISSING=1：qdl 允许缺件跳过，缺的件不会写）"; }

# 1) LUN4（37 分区 / ~794 MiB）：boot/dtbo/vbmeta/固件 + GPT
#    -R = 跳过会话末 reset ⇒ 设备留在 9008，下一发才能接上（#674）
say "--- step1: rawprogram4 + patch4"
: > "$O/step1.raw.log"
timeout -k 10 1800 "$Q" -R $QF -s ufs "$L" rawprogram4.xml patch4.xml >"$O/step1.raw.log" 2>&1
rc1=$?
tail -6 "$O/step1.raw.log" | tee -a "$LOG"
say "step1 rc=$rc1"
[ "$rc1" -eq 0 ] || { say "!! step1 失败 ⇒ 停止（不再写 LUN0），设备留在 9008"; exit 3; }

# 2) LUN0（super/userdata/metadata/lenovoraw/lenovocust + GPT）：~15 GiB
say "--- step2: rawprogram_save_persist_unsparse0 + patch0"
: > "$O/step2.raw.log"
timeout -k 10 3000 "$Q" -R $QF -s ufs "$L" rawprogram_save_persist_unsparse0.xml patch0.xml >"$O/step2.raw.log" 2>&1
rc2=$?
tail -6 "$O/step2.raw.log" | tee -a "$LOG"
say "step2 rc=$rc2"
[ "$rc2" -eq 0 ] || { say "!! step2 失败 ⇒ 停止，设备留在 9008（不要盲发 reset）"; exit 3; }

# 2b) 写后校验：GPT 主表读回比 sha（qdl 退出码不可信，PITFALLS #669）
say "--- step2b: 读回六 LUN 主表并比 sha"
: > "$O/readback.log"
timeout -k 10 300 "$Q" -R -s ufs "$L" \
  read 0/0+6 "$O/rb-gpt0.bin" read 4/0+6 "$O/rb-gpt4.bin" >"$O/readback.log" 2>&1
rb_rc=$?
say "readback rc=$rb_rc （文件在 $O/rb-gpt*.bin；与 $PKG/gpt_main0.bin,gpt_main4.bin 逐字节比）"
# 写后读回同样是 dump：rc 与产物长度都要过硬，否则「读回失败」会被下面的 cmp 当成「表不对」。
for lun in 0 4; do
  vd=$(timeout -k 5 30 python3 "$DV" --part "rb-gpt$lun" --rc "$rb_rc" --log "$O/readback.log" \
         --file "$O/rb-gpt$lun.bin" --expect-bytes 24576 2>&1)
  vrc=$?
  say "readback $lun $vd"
  [ "$vrc" -eq 0 ] || { say "!! 写后读回不可信（verdict rc=$vrc）⇒ 本次刷写结果未知，不要发 reset、不要改槽属性"; exit 7; }
done
for p in 0 4; do
  if cmp -s "$O/rb-gpt$p.bin" "$PKG/gpt_main$p.bin"; then say "GPT LUN$p 读回 = 原厂件 OK"
  else say "WARN GPT LUN$p 读回 != 原厂件（属性字节差异属正常，几何差异要查）"; fi
done

# 3) reset 回正常启动（唯一一条不带 -R 的 qdl）
say "--- reset"
# rc 必须单独取（pipeline 的 $? 是 tee 的 0，PITFALLS #669 同族）；reset 失败不致命，
# 但必须留痕，因为「设备还在不在 9008」由下面的 poll 判，不靠这句话。
timeout -k 10 120 "$Q" -s ufs "$L" reset > /tmp/t2-reset-$$.log 2>&1; rrc=$?
tail -2 /tmp/t2-reset-$$.log | tee -a "$LOG"; rm -f /tmp/t2-reset-$$.log
say "reset rc=$rrc"; [ "$rrc" -eq 0 ] || say "!! reset 返回 $rrc（会话可能已断，继续按 poll 判落点）"

# 4) 观察 120 s：判据 = 本机 SN 重新以 adb 枚举（不是「任何 adb 设备在」，也不是「fastboot 消失」）
AD=
for i in 1 2 3 4 5 6; do
  sleep 20
  # PITFALLS #584：不要把 fastboot 接进 `| head -1`（SIGPIPE 打断设备侧 bulk 通道）
  FBRAW=$(timeout -k 5 8 fastboot devices 2>/dev/null)
  FB=$(printf '%s\n' "$FBRAW" | awk -v s="$SER" '$1==s{print $1; exit}')
  AD=$(timeout -k 5 6 adb devices 2>/dev/null | awk -v s="$SER" '$1==s && $2=="device"{print $1; exit}')
  LU=$(edl_present && echo edl || echo -)
  say "poll $i (t=$((i*20))s): fb($SER)='${FB:-none}' adb($SER)='${AD:-none}' edl=$LU"
  [ -n "$AD" ] && { say "本机已重新以 adb 枚举"; break; }
done
say "=== T2 end ==="
# 退出码必须反映「本机到底在哪」，否则「设备留在 9008/fastboot」也报成功（A 项）
edl_present && { say "!! 收尾时仍在 9008（reset 未生效）"; exit 4; }
[ -n "$AD" ] || { say "!! 收尾时本机 $SER 未以 adb 枚举（可能在 fastboot/黑屏），不得判 T2 成功"; exit 4; }
say "T2 OK: $SER 已重新枚举"
