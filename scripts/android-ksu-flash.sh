#!/usr/bin/env bash
# android-ksu-flash.sh — 刷/回退「KernelSU(LKM) init_boot + 自洽 vbmeta_a」（TB322FC / elden / 259）
#
# 默认 = **dry-run**：只打印每条命令 + 写前/写后的核对命令，不动设备。加 --apply 才真执行。
#
#   只动两个分区：`vbmeta_a`、`init_boot_a`（命令行里带 `_a`，**结构上不可能碰到 b 槽**）
#   绝不触碰：abl / boot / recovery / dtbo / vbmeta_system / super / GPT
#
# 用法：
#   scripts/android-ksu-flash.sh                     # dry-run，看会做什么
#   scripts/android-ksu-flash.sh --apply             # 真刷（需设备在 fastboot、current-slot=a）
#   scripts/android-ksu-flash.sh --revert            # 回退到 259 原厂 init_boot+vbmeta（Flags=0，verity 开）
#   scripts/android-ksu-flash.sh --revert-preksu     # 回退到 2026-11-18 在机状态（自签 Flags=1，testkey 不是我方）
#   scripts/android-ksu-flash.sh --backup-only       # 只做 EDL 只读备份（写前必做）
#
# 判据（写完怎么算成功，见报告 §6）：刷完 `ro.boot.veritymode=disabled` 且 KernelSU Manager 显示「工作中」。
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
PKG=${KSU_PKG:-$REPO/out/android-root-20261119}
QDL=${QDL:-$HOME/edl/qdl/build/qdl}
LOADER=${LOADER:-$REPO/backup/official-rom-15.10.259/xbl_s_devprg_ns.melf}
SERIAL=${SERIAL:-}
APPLY=0
MODE=flash

# GPT 里的固定地址（来源 backup/official-rom-15.10.259/rawprogram4.xml，4096B 扇区）
LBA_VBMETA_A=4/137946+16        # 65536 B
LBA_INIT_BOOT_A=4/205962+2048   # 8388608 B

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    --revert) MODE=revert ;;
    --revert-preksu) MODE=revert-preksu ;;
    --backup-only) MODE=backup ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

FB="fastboot"
[ -n "$SERIAL" ] && FB="fastboot -s $SERIAL"
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
# sha_direct <文件>：**O_DIRECT 直读**算 sha256（绕过页缓存），工具回退 buffered 时 shell 侧
# 兜底并打 WARN。为什么必须 O_DIRECT（2026-11-20 实测）：页缓存被污染时 buffered 连读多次
# 「稳定但错」（v1 件 637a9965… vs 真值 e3d0d26f…），旧「双 sha256 硬门」抓不到。
# 工具：scripts/odirect-sha.py（--tsv 第 3 列 = sha）；取证：reports/odirect-sha-gate-20261120.md。
ODIRECT_SHA=${ODIRECT_SHA:-$(cd "$(dirname "$0")/.." && pwd)/scripts/odirect-sha.py}
sha_direct() {
	local f=$1 out v
	[ -n "$f" ] && [ -e "$f" ] || { printf '%s\n' ""; return 0; }
	out=$(timeout -k 10 1800 python3 "$ODIRECT_SHA" --tsv "$f" 2>&1)
	v=$(printf '%s\n' "$out" | awk -F'\t' 'NR==1{print $3}')
	if [ -z "$v" ] || [ "${#v}" != 64 ]; then
		v=$(sha256sum "$f" | cut -d' ' -f1)
		echo "WARN sha_direct: $f 未走 O_DIRECT（$out），退回 buffered（结果可能被页缓存污染）" >&2
	fi
	printf '%s\n' "$v"
}


# 各模式的「目标件」
case "$MODE" in
  flash)
    SRC_VBMETA=$PKG/vbmeta_a_root.img
    SRC_INIT_BOOT=$PKG/init_boot_ksu.img
    DESC="刷 KSU 件：vbmeta_a_root.img(Flags=1,testkey 2597c218) + init_boot_ksu.img" ;;
  revert)
    SRC_VBMETA=$PKG/revert/vbmeta_a_259stock.img
    SRC_INIT_BOOT=$PKG/revert/init_boot_a_259stock.img
    DESC="回退 259 原厂件：vbmeta_a(Flags=0) + init_boot_a" ;;
  revert-preksu)
    SRC_VBMETA=$PKG/revert/vbmeta_a_flags1_selfsigned_20261118.img
    SRC_INIT_BOOT=$PKG/revert/init_boot_a_259stock.img
    DESC="回退到 2026-11-18 在机状态：vbmeta_a 自签 Flags=1 + 原厂 init_boot_a" ;;
  backup) DESC="只做 EDL 只读备份" ;;
esac

say "0) 目标：$DESC"
[ "$APPLY" = 1 ] && echo "   APPLY=1（真执行）" || echo "   DRY-RUN（只打印；加 --apply 才动设备）"

STAMP=$(date +%Y%m%d-%H%M%S)
PRE=$PKG/pre/$STAMP
echo "   写前备份目录：$PRE"

say "1) 写前备份（EDL 只读；单条 qdl 会话内多目标，避免第二发被 reset 打断）"
cat <<EOF
   # 进 EDL：fastboot 下 \`$FB oem edl\`（或 Android 下 \`adb reboot edl\`）
   mkdir -p $PRE
   $QDL -s ufs $LOADER \\
       read $LBA_VBMETA_A    $PRE/vbmeta_a.bin \\
       read $LBA_INIT_BOOT_A $PRE/init_boot_a.bin
   sha256sum $PRE/vbmeta_a.bin $PRE/init_boot_a.bin | tee $PRE/SHA256SUMS.txt
   # 期望尺寸：vbmeta_a=65536  init_boot_a=8388608
EOF

if [ "$MODE" = backup ]; then
  if [ "$APPLY" = 1 ]; then
    mkdir -p "$PRE"
    "$QDL" -s ufs "$LOADER" read "$LBA_VBMETA_A" "$PRE/vbmeta_a.bin" \
                                read "$LBA_INIT_BOOT_A" "$PRE/init_boot_a.bin"
    : > "$PRE/SHA256SUMS.txt"
    for _f in "$PRE"/vbmeta_a.bin "$PRE"/init_boot_a.bin; do
      printf '%s  %s\n' "$(sha_direct "$_f")" "$_f" | tee -a "$PRE/SHA256SUMS.txt"
    done
  fi
  exit 0
fi

say "2) 前置检查（任何一条不满足就停，不要硬刷）"
cat <<EOF
   $FB devices                          # 必须只列一台：<SN>  fastboot
   $FB getvar current-slot              # ★必须是 a。不是 a 就停：本包按 a 槽做，
                                        #   且【不要】用 --set-active 去切（PITFALLS #60/#114）
   $FB getvar unlocked                  # 期望 yes（若 no，说明 BL 被锁回去，自签件必被拒）
   $FB getvar product                   # 期望 TB322FC
   # 槽属性（防 UNBOOTABLE 白忙一场；#672 的坑）：
   python3 $REPO/scripts/slot-attr.py show | grep -E 'boot_a|boot_b'
   #   boot_a 的 byte6 若含 0x80（UNBOOTABLE），先清标志再刷，否则 ABL 直接拒绝尝试
EOF

say "3) 校验本地件指纹（不信手里的文件，先对 SHA256SUMS）"
cat <<EOF
   ( cd $PKG && sha256sum -c SHA256SUMS )
   # 还有一条硬校验：init_boot_ksu.img 自带 footer 的 hash 必须过（avbtool 按 <partition_name>.img 找文件，故先建软链）
   T=\$(mktemp -d) && ln -s $PKG/init_boot_ksu.img \$T/init_boot.img
   python3 $REPO/tools/avbtool.py verify_image --image \$T/init_boot.img   # 期望 2 行 Successfully verified
   python3 $REPO/tools/avbtool.py info_image --image $PKG/vbmeta_a_root.img | sed -n '1,10p'
   #   期望第 5/7 行：Public key (sha1): 2597c218aae470a130f61162feaae70afd97f011 / Flags: 1
EOF

say "4) 刷写命令（顺序：先 vbmeta、后 init_boot，中间不重启）"
CMDS=(
  "$FB flash vbmeta_a    $SRC_VBMETA"
  "$FB flash init_boot_a $SRC_INIT_BOOT"
  "$FB reboot"
)
for c in "${CMDS[@]}"; do echo "   $c"; done

if [ "$APPLY" = 1 ]; then
  say "== 真执行 =="
  for c in "${CMDS[@]}"; do
    echo "+ $c"
    $c || { echo "!! 失败：停在这里，设备仍在 fastboot，直接按 --revert 回来" >&2; exit 1; }
  done
fi

say "5) 写后核对（刷完必须做；两条路径，任一可判）"
cat <<EOF
   # A. 系统起来后看 AVB/root 状态（不动设备写操作）：
   adb wait-for-device
   adb shell 'getprop ro.boot.veritymode; getprop ro.boot.verifiedbootstate; getprop ro.boot.slot_suffix'
   #   期望：veritymode=disabled（因为 Flags=1）、verifiedbootstate=orange、_a
   adb shell 'ls -l /data/adb/ 2>/dev/null; getprop | grep -i kernelsu'    # KSU 首次启动后建 /data/adb/ksu
   #   最终判据 = 装 KernelSU-Next Manager APK 打开后显示「工作中 / Working」+ 能授权 root

   # B. 分区逐字节核对（EDL 只读；与刷写件 sha256 必须相等）：
   # 进 EDL：adb reboot edl / fastboot oem edl
   mkdir -p $PKG/pre/$STAMP/post
   $QDL -s ufs $LOADER \\
       read $LBA_VBMETA_A    $PKG/pre/$STAMP/post/vbmeta_a.bin \\
       read $LBA_INIT_BOOT_A $PKG/pre/$STAMP/post/init_boot_a.bin
   sha256sum $PKG/pre/$STAMP/post/*.bin
   sha256sum $SRC_VBMETA $SRC_INIT_BOOT
EOF

say "6) 不可逆点 / 失败处置"
cat <<'EOF'
   不可逆点（本脚本全部避开，列出来是为了别手滑）：
   - `abl`（引导器，1 MiB，刷坏 = 只能 EDL 救）：本脚本不碰。
   - `super`（14.5 GiB 逻辑分区容器）：本脚本不碰；改它会推翻现有 AVB hashtree。
   - rollback index：本包 top-level rollback=0（与原厂 259 相同）⇒ 不推高 RPMB 计数，**可自由回退**。
     只有把 rollback 填成 > RPMB 存值 才会「一次性不可逆」——所以脚本没有这个开关。
   - `--set-active`：本脚本不调用。槽位切错会让 ABL 去 b 槽（另一套密钥链），表现为「卡 logo/回 fastboot」。

   失败表现与处置：
   1) 刷完不进系统、回 fastboot：不要连刷。先 `--revert`（原厂对）再判断。
   2) 卡开机动画 > 5 min：先 `fastboot getvar current-slot` 确认还是 a，再按 1) 回退。
      卡动画常见原因是「system/vbmeta_system 与当前 super 内容不搭」，与本 lane 两件无关。
   3) `fastboot flash` 报 `FAILED (remote: 'Flashing is not allowed for critical partitions')`
      ⇒ BL 被锁回去了（`getvar unlocked` = no），先解锁再谈刷写，不要改分区名绕过。
   4) init_boot 刷完但 KernelSU Manager 显示「未安装」：说明 ramdisk 没被内核采用
      （常见于 init_boot 刷到 b 槽 / 或 super 的 boot 走了别的 ramdisk），核对 `ro.boot.slot_suffix`。
   5) 设备彻底不进 fastboot/系统：`fastboot oem edl` 进不去就按电源 10 s 后重试；
      仍不行走 EDL 兜底（`backup/official-rom-15.10.259/xbl_s_devprg_ns.melf` + 同目录 rawprogram4.xml 重刷 a 槽）。
   6) b 槽保护：本脚本的每条 flash 都带 `_a` 后缀；**不要**把命令改成不带后缀的 `fastboot flash vbmeta`
      （那样会按当前槽写，可能写到 b 槽，而 b 槽是另一把密钥链）。
EOF

say "7) 收尾口径"
echo "   本 lane 的成功判据全部是「设备侧实测」，主机侧只能证明：avbtool 校验通过 + 描述符自洽 + sha256 固定。"
