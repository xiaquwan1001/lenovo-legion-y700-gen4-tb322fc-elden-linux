#!/bin/sh
# ★ STALE 头注（2026-11-23，D5 批 4 / reports/scripts-hardening-4-20261123.md §2）：**保留 + 本头注，不归档**。
#   不归档的理由：它是「Linux 进度被改后怎么查」的**活入口**，INDEX.md:239,260,358 与
#   RUNBOOK-BRINGUP/{LINUX-STATE-REPRO,ZERO-TO-DESKTOP,GPT-MINIMAL-DESIGN}.md 都直接指它（归档会成批悬挂）。
#   ⚠ 已知债务（本轮**未修**，属审计 §5 批 2 第 9 条）：A/H 段的 GPT 基线路径写死单机序列号/容量档
#     `backup/HA2EXB0E-16+512/`（:86-91，U1）⇒ 在别的单元/U2 布局上会整段报 MISSING（不是缺陷而是前提不符）。
#     修法 = `--sn` / `--unit` 参数化（默认保留现值，行为不变），待单独一轮 + 真机复核。
#
# linux-state-audit.sh — 「Linux 进度」8 项状态的只读体检（主机侧 + 设备侧），永不做写操作。
#
# 配套文档：RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md（§2 = 8 项清单，§3 = 复现步骤）
# 判据纪律：本脚本只回答「有哪些、缺哪些、哪些和台账不一致」，不下任何故障结论；
#          硬件结论需要文档 §1.2 的四道门，脚本不参与。
#
# 用法：
#   bash scripts/linux-state-audit.sh --host                 # 只查主机资产（无需设备）
#   bash scripts/linux-state-audit.sh --device               # 加查设备现态（adb/fastboot，自动选）
#   bash scripts/linux-state-audit.sh --snapshot F.tsv       # 写成 TSV（--device 的超集）
#   SN=HA2EXB0E bash scripts/linux-state-audit.sh --device   # 多机同总线时必须给 SN
#   bash scripts/linux-state-audit.sh --edl                  # 额外做 EDL 只读（会切 9008，需人确认）
#
# 退出码：0 = 关键资产齐、无 DRIFT；1 = 有缺失/漂移/不可判（细节见输出，不阻塞继续实验）
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 2
SN=${SN:-HA2EXB0E}
PKG=${PKG:-$HOME/文档/TB322FC_15.10.259}
LOADER=${LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}
QDL=${QDL:-$HOME/edl/qdl/build/qdl}
MODE=host; SNAP=""; DO_EDL=0
for a in "$@"; do
  case "$a" in
    --host) MODE=host ;;
    --device) MODE=device ;;
    --edl) DO_EDL=1; MODE=device ;;
    --snapshot) SNAP=NEXT ;;
    --*) echo "未知参数 $a（见文件头用法）" >&2; exit 2 ;;
    *) [ "${SNAP:-}" = NEXT ] && SNAP=$a ;;
  esac
done
[ "${SNAP:-}" = NEXT ] && { echo "--snapshot 需要文件路径" >&2; exit 2; }
OUT=${SNAP:-/dev/stdout}
: >"$OUT" 2>/dev/null || true
slen=0; warn=0; miss=0

emit() { # emit <项> <状态> <值/说明>
  [ -n "$SNAP" ] && printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$SNAP"
  printf '  %-8s %-28s %s\n' "$2" "$1" "$3"
}
sec() { [ -z "$SNAP" ] && printf '\n== %s ==\n' "$1"; }
cnt() { # cnt <STATUS>  # 计缺失/漂移
  case "$1" in MISSING|DRIFT) miss=$((miss+1)) ;; WARN|UNKNOWN) warn=$((warn+1)) ;; esac
}
sha8() { [ -f "$1" ] && sha256sum "$1" 2>/dev/null | cut -c1-16 || echo MISSING; }
check_file() { # check_file <名字> <路径> [台账前缀]
  p=$2; e=${3:-}
  if [ ! -f "$p" ]; then emit "$1" MISSING "$p"; cnt MISSING; return; fi
  s=$(sha8 "$p")
  if [ -n "$e" ]; then
    case "$s" in "$e"*) emit "$1" OK "$p  sha=$s（=台账 $e…）" ;;
      *) emit "$1" DRIFT "$p  sha=$s ≠台账 $e…"; cnt DRIFT ;; esac
  else
    emit "$1" OK "$p  sha=$s"
  fi
}
size_h() { du -sh "$1" 2>/dev/null | awk '{print $1}'; }

sec "A. 主机资产：刷机通路（EDL）"
check_file loader "$LOADER"
if [ -f "$LOADER" ]; then emit "loader-alt" OK "backup/fw/tb322fc-edl/xbl_s_devprg_ns.melf sha=$(sha8 backup/fw/tb322fc-edl/xbl_s_devprg_ns.melf)"; fi
if [ -x "$QDL" ]; then emit qdl OK "$QDL"; else emit qdl MISSING "$QDL（~/edl/qdl 未构建）"; cnt MISSING; fi
for f in rawprogram1.xml rawprogram2.xml rawprogram3.xml rawprogram4.xml rawprogram5.xml \
         rawprogram_save_persist_unsparse0.xml patch0.xml patch1.xml patch2.xml patch3.xml patch4.xml patch5.xml \
         gpt_main0.bin gpt_backup0.bin gpt_main4.bin; do
  [ -f "$PKG/$f" ] || { emit "官方包:$f" MISSING "$PKG/$f"; cnt MISSING; }
done
[ -f "$PKG/super_1.img" ] && emit "官方包:super_1..8" OK "合计 $(du -ch "$PKG"/super_*.img 2>/dev/null | tail -1 | awk '{print $1}')"
if ls "$PKG"/userdata_*.img >/dev/null 2>&1; then
  emit "官方包:userdata_*" OK "在（$(du -ch "$PKG"/userdata_*.img | tail -1 | awk '{print $1}')）"
else
  emit "官方包:userdata_*" WARN "缺（包内被瘦身）⇒ 基线步骤必须 fastboot -w 显式擦 userdata/metadata"
  cnt WARN
fi

sec "B/C/D. 槽镜像与 AVB 件（台账 2026-11-17）"
check_file boot_b bootslot-b/boot_b.img 06c081ca
check_file boot-elden-vk192 out/boot-elden-vk192.img bdf47f5f
check_file vbmeta_b backup/vbmeta_b-20261110.img e974ebab
check_file dtbo-dummy out/dtbo-dummy.img ad7facb2

sec "A/H. GPT 基线与回退件"
check_file gpt_main0基线 backup/HA2EXB0E-16+512/gpt_main0.bin
check_file gpt_backup0基线 backup/HA2EXB0E-16+512/gpt_backup0.bin
check_file gpt_new_main0 backup/HA2EXB0E-16+512/gpt_new_main0.bin
if [ -d backup/stock-259 ]; then emit stock-259 OK "$(ls backup/stock-259 | wc -l) 件 / $(size_h backup/stock-259)"; else emit stock-259 MISSING backup/stock-259; cnt MISSING; fi
if [ -d backup/official-rom-15.10.259 ]; then emit "官方全量包" OK "backup/official-rom-15.10.259 ($(size_h backup/official-rom-15.10.259))"; else emit "官方全量包" WARN "未见 backup/official-rom-15.10.259（软链？）"; cnt WARN; fi
if [ -d backup/HA2EXB0E-16+512/unique ]; then emit "独有分区 dump" OK "unique/ $(size_h backup/HA2EXB0E-16+512/unique)"; else emit "独有分区 dump" WARN "无 unique/"; cnt WARN; fi

sec "E. ESP 源件（GRUB/Loader/boot.img）"
ls out/grub-arm64-*/ out/grub-*/ 2>/dev/null | head -0
GN=$(ls -t out/grub-arm64-*/grubaa64*.efi out/grub-*/grubaa64*.efi 2>/dev/null | head -1)
[ -n "$GN" ] && emit grub-efi OK "$GN sha=$(sha8 "$GN")" || { emit grub-efi WARN "out/ 下未找到 grubaa64*.efi（现役件只在 ESP 上？按台账重建）"; cnt WARN; }
[ -f bootslot-b/README.md ] && emit "ESP 件台账" OK "bootslot-b/README.md + DEVICE/README.md §1.1"

sec "F. rootfs 源件"
# 库里没有全量 rootfs 归档 ⇒ F 项的备份实质 = 设备 linux17 分区本体（见文档 §2 F 行 / §3 S3 路径 a）
if [ -d rootfs ]; then emit rootfs-overlay OK "rootfs/（$(size_h rootfs)，仅 overlay 骨架，≠ 全量 rootfs）"; else emit rootfs-overlay WARN "无 rootfs/"; cnt WARN; fi
emit rootfs-全量 WARN "库里无全量 rootfs 归档 ⇒ 依赖设备 linux17 本体 + LBA 台账（§3 S3a）"; cnt WARN
MT=$(ls -t out/modules-*.tar.gz 2>/dev/null | head -1)
[ -n "$MT" ] && emit modules OK "$MT ($(size_h "$MT"))" || { emit modules WARN "无 out/modules-*.tar.gz"; cnt WARN; }

# ---------------- 设备侧 ----------------
if [ "$MODE" = device ]; then
  sec "设备现态"
  AD=$(timeout -k 5 6 adb devices 2>/dev/null | awk -v s="$SN" '$1==s {print $2}')
  FB=$(timeout -k 5 8 fastboot devices 2>/dev/null | awk -v s="$SN" '$1==s {print $2}')
  EDL=$(lsusb 2>/dev/null | grep -q '05c6:9008' && echo yes || echo no)
  orphan=$(pgrep -fc '[f]astboot' 2>/dev/null); [ -n "${orphan:-}" ] || orphan=0  # pgrep -c 为 0 时 rc≠0，别用 `|| echo 0`（会产出两行）
  emit channel OK "adb='${AD:-none}' fastboot='${FB:-none}' edl=$EDL 孤儿fastboot=$orphan"
  [ "$orphan" -gt 0 ] && { emit "通道风险" WARN "有 $orphan 个 fastboot 进程（#658：先清孤儿）"; cnt WARN; }
  if [ -n "$AD" ] && [ "$AD" = device ]; then
    g() { timeout -k 5 10 adb -s "$SN" shell getprop "$1" 2>/dev/null | tr -d '\r' | head -1; }
    BC=$(g sys.boot_completed)
    if [ "$BC" = 1 ]; then
      emit "状态机" OK "Android: $(g ro.build.display.id) / boot_completed=1 / slot=$(g ro.boot.slot_suffix)"
    else
      emit "状态机" DRIFT "adb 在线但 boot_completed='${BC:-空}' ⇒ 只能证明 adbd 起来，不能证明系统起全"; cnt DRIFT
    fi
    ROOTMNT=$(timeout -k 5 10 adb -s "$SN" shell "findmnt -n -o SOURCE,FSTYPE / 2>/dev/null || awk '\$2==\"/\"{print \$1,\$3; exit}' /proc/mounts" 2>/dev/null | tr -d '\r')
    emit "F.rootfs" OK "findmnt / = ${ROOTMNT:-未知}"
    UTS=$(timeout -k 5 10 adb -s "$SN" shell uname -r 2>/dev/null | tr -d '\r')
    MODS=$(timeout -k 5 10 adb -s "$SN" shell "ls /lib/modules 2>/dev/null | wc -l" 2>/dev/null | tr -d '\r')
    emit "F.内核/模块" OK "uname=$(echo "$UTS" | head -c 60) /lib/modules 目录数=${MODS:-?}"
    # Android 的 by-partlabel 是跨 LUN 合并视图（命名也不一定等于 Linux 侧）⇒ 同时记 LUN 归属
    esp=$(timeout -k 5 10 adb -s "$SN" shell "ls -l /dev/disk/by-partlabel 2>/dev/null | tr '\n' ' '" 2>/dev/null | tr -d '\r')
    case "$esp" in *linux17*) emit "A.GPT条目" OK "分区标签含 linux17/eldenesp" ;; *) emit "A.GPT条目" DRIFT "设备上无 linux17/eldenesp（= 原厂 GPT，Linux 条目已丢）"; cnt DRIFT ;; esac
    blk=$(timeout -k 5 10 adb -s "$SN" shell 'for p in /dev/block/sd*; do printf "%s->%s " "$p" "$(readlink -f "$p")"; done' 2>/dev/null | tr -d '\r')
    emit "A.LUN映射" OK "Android 块设备→LUN：$(printf '%s' "$blk" | cut -c1-200)"
    pre=$(g ro.boot.verifiedbootstate); emit "D.verity" OK "verifiedbootstate=${pre:-?}"
  elif [ -n "$FB" ]; then
    v() { timeout -k 5 8 fastboot -s "$SN" getvar "$1" 2>&1 | head -1 | sed 's/^(bootloader) //'; }
    emit "状态机" OK "fastboot 模式"
    for k in current-slot slot-retry-count:a slot-retry-count:b slot-successful:a slot-successful:b \
             slot-unbootable:a slot-unbootable:b battery-voltage battery-soc-ok; do
      emit "getvar:$k" OK "$(v "$k")"
    done
    emit "下一步" OK "先跑 LINUX-STATE-REPRO.md §3 S1 只读对账，再谈任何写/结论"
  else
    emit "设备" UNKNOWN "adb/fastboot 都没枚举（脱线/关机/EDL未开）"; cnt UNKNOWN
  fi

  if [ "$DO_EDL" = 1 ] && [ -z "$FB" ] && [ -z "$AD" ]; then
    echo "  --edl 需要设备在 fastboot；跳过"
  elif [ "$DO_EDL" = 1 ]; then
    sec "EDL 只读取证（GPT 对账）"
    D=$(mktemp -d)
    timeout -k 5 20 fastboot -s "$SN" oem edl >/dev/null 2>&1
    # 有上限地等 9008（不是固定 sleep 6）；9008 归属仍靠「刚从 $SN 切过去」这条链路
    for i in 1 2 3 4 5 6 7 8 9 10; do lsusb -d 05c6:9008 >/dev/null 2>&1 && break; sleep 2; done
    if lsusb | grep -q 05c6:9008; then
      # 主表 34 扇区（header + 完整 entry array）。扇区单位由 qdl 探测 ⇒ 读回长度必须落在
      # 512/4096 两档之一，否则 gpt-audit 吃的是一份截断/错位的表（B 项）。
      timeout -k 10 300 "$QDL" -s ufs "$LOADER" \
        read 0/0+34 "$D/gpt0-lba0-33.bin" read 4/0+34 "$D/gpt4-lba0-33.bin" >/dev/null 2>&1
      timeout -k 10 90 "$QDL" -s ufs "$LOADER" reset >/dev/null 2>&1
      rc=0
      for f in "$D/gpt0-lba0-33.bin" "$D/gpt4-lba0-33.bin"; do
        sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
        case $sz in
          17408|139264) emit "EDL读:$(basename "$f")" OK "size=$sz sha256=$(sha256sum "$f" | cut -c1-16)" ;;
          *) emit "EDL读:$(basename "$f")" UNKNOWN "size=$sz（既非 34*512 也非 34*4096 ⇒ 表不完整/单位错）"; cnt UNKNOWN; rc=1 ;;
        esac
      done
      # reset 落点校验：必须离开 9008，否则设备被留在 EDL 而本脚本 return 0（A 项）
      out_edl=no
      for i in 1 2 3 4 5 6 7 8 9 10; do lsusb -d 05c6:9008 >/dev/null 2>&1 || { out_edl=yes; break; }; sleep 3; done
      [ "$out_edl" = yes ] || { emit "EDL出" DRIFT "reset 后 60 s 仍在 9008（设备停在 EDL）"; cnt DRIFT; }
      if [ "$rc" = 0 ] && [ -f "$D/gpt0-lba0-33.bin" ]; then
        echo "  （EDL GPT 已取到 $D；运行：python3 scripts/gpt-audit-tb322fc.py --dev $D --stock $PKG）"
        python3 scripts/gpt-audit-tb322fc.py --dev "$D" --stock "$PKG" --luns 0,4 2>&1 | sed -n '1,12p'
      else
        emit "EDL读" UNKNOWN "读 GPT 失败/不完整（loader/通道/单位）⇒ 不得据此判『GPT 无漂移』"; cnt UNKNOWN
      fi
    else
      emit "EDL进" UNKNOWN "未进 9008"; cnt UNKNOWN
    fi
  fi
fi

sec "汇总"
printf '  缺失/漂移=%d  警告/不可判=%d\n' "$miss" "$warn"
[ -n "$SNAP" ] && echo "  快照已写：$SNAP"
echo "  下一步：RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md §3（S1 只读对账 → S2 基线 → S3…）"
[ "$miss" -eq 0 ]
