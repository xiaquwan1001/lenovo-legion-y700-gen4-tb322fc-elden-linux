#!/bin/bash
# uefi-grubcfg-arming.sh — 把设备 /boot/grub/grub.cfg 的「默认臂」改成可诊断的 UEFI 复测臂
#
# ⚠ 2026-11-14 定案：**当前 ESP 上的 GRUB 是「嵌入菜单」件，不读这个文件**（见下）。
#   本脚本只对「ESP 里放的是 stub 版 GRUB」那种布置有效（stub 会 `configfile …/boot/grub/grub.cfg`）。
#   现役布置（`\EFI\BOOT\BOOTAA64.EFI` = v3b-bigfont `244c5f65…`，二进制里含 6 个 menuentry、
#   不含 configfile 桩）**改菜单必须重打 EFI** ⇒ 用 `scripts/grub-arm64-arming-build.sh`
#   + `scripts/esp-install-grub.sh --activate`。
#
# 仍然有用：如果哪天把 ESP 换成 stub 版（`scripts/grub-arm64-standalone.sh` 默认产物），
#   本脚本的 --check/--stage/--apply/--rollback 就是那个布置下的菜单切换工具。
#
# 背景（2026-11-14 现查）：linux17 上的 `/boot/grub/grub.cfg` 当前是 **2026-11-11 的 A/B/C 实验菜单**：
#     `set timeout=20` + `set default=0` = **A 臂**，cmdline 里 **没有** `earlycon=efifb keep_bootcon`
#   ⇒ 若由 stub GRUB 读它，从 a 槽起来必然「黑屏/无字」（PITFALLS #622）。
#
# 做什么（只写一个文件：`/boot/grub/grub.cfg`；先备份、写完读回校验）：
#   --stage   生成新 grub.cfg 并 scp 到设备 /tmp（不落 /boot，不改变引导）
#   --apply   stage 之后 `install` 到 /boot/grub/grub.cfg（备份 `grub.cfg.bak-<ts>`）
#   --rollback 用最近一次 `.bak-<ts>` 回滚
#   --check   只读：打印当前 default / timeout / 各臂是否带 earlycon + grubenv 留痕
#
# 设计口径：
#   · 默认臂 = **A2'**：真 DTB（`elden.dtb`，不是 `nopstorecons`）+ `earlycon=efifb keep_bootcon` + `panic=0`
#     （panic=0 是为了「挂住可拍屏」而不是 panic 后自动重启，PITFALLS #622 判据纪律）；
#   · 每步写 `/boot/grub/grubenv`（`elden_grub_log`）⇒ 不拍屏也能知道走到哪；
#   · 保留 `panic=15` 基线臂与 `Loader.efi` 链式臂做对照，保留 `reboot`/`poweroff`；
#   · 只动 linux17 的 `/boot/grub/grub.cfg`，**不动 ESP 上的任何文件**（BOOTAA64.EFI 身份不变）。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEVICE=${DEVICE:-root@192.168.7.1}
MODE=check
TS=$(date +%Y%m%d-%H%M%S)
OUT=${OUT:-$ROOT/out/grubcfg-arming-$TS}

say() { echo "[arming] $*" >&2; }
die() { echo "[arming] ERROR: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
	case "$1" in
		--stage)    MODE=stage; shift;;
		--apply)    MODE=apply; shift;;
		--rollback) MODE=rollback; shift;;
		--check)    MODE=check; shift;;
		--device)   DEVICE=$2; shift 2;;
		--out)      OUT=$2; shift 2;;
		-h|--help)  sed -n '2,26p' "$0"; exit 0;;
		*) die "unknown arg: $1";;
	esac
done

SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=8 $DEVICE"
S() { timeout "${2:-30}" $SSH "$1" 2>/dev/null; }

S true || die "ssh 不通：$DEVICE（设备是否在 Linux？UEFI 复测前设备必须在 b 槽 Linux）"

# ---------------- 只读检查 ----------------
do_check() {
	echo "== 设备 $(S 'date -Is; uname -r; cat /proc/sys/kernel/random/boot_id' | tr '\n' ' ')"
	echo "== 槽位"
	S 'qbootctl'
	echo "== /boot/grub/grub.cfg 关键行"
	S 'grep -nE "^set (timeout|default)|^menuentry" /boot/grub/grub.cfg'
	echo "== 各臂是否带 earlycon"
	S 'awk "/^menuentry/{n=\$0} /earlycon=efifb/{print \"  earlycon: \" n}" /boot/grub/grub.cfg'
	echo "== 设备上的件"
	S 'ls -l /boot/Image /boot/initrd.img /boot/elden.dtb /boot/elden-nopstorecons.dtb 2>&1'
	echo "== grubenv 留痕"
	S 'cat /boot/grub/grubenv 2>/dev/null | head -2'
	echo "== ESP 侧（只读，不动）"
	S 'ls -l /efi/EFI/BOOT/BOOTAA64.EFI 2>/dev/null; sha256sum /efi/EFI/BOOT/BOOTAA64.EFI 2>/dev/null'
}

# ---------------- 生成新 grub.cfg ----------------
gen_cfg() {
	mkdir -p "$OUT"
	cat > "$OUT/grub.cfg" <<'EOF'
# /boot/grub/grub.cfg —— 2026-11-14 由 scripts/uefi-grubcfg-arming.sh 生成
#   ESP 的 GRUB（\EFI\BOOT\BOOTAA64.EFI = v3b-bigfont）会 configfile 到本文件；
#   default=0 已指向带 `earlycon=efifb keep_bootcon` 的 A2' 臂 —— 否则 a 槽起来必然黑屏（PITFALLS #622）。
#   每步写 /boot/grub/grubenv 的 elden_grub_log ⇒ 不拍屏也能判「GRUB 走到哪」（PITFALLS #277）。
#   回滚：grub.cfg.bak-<ts>（同目录）。
set timeout=20
set default=0

insmod all_video
insmod video
insmod font
insmod gfxterm
insmod gfxmenu
insmod ext2

menuentry "A2' UEFI 复测：真 DTB + earlycon=efifb + panic=0（默认）" {
  search --no-floppy --label --set=root linux17
  set elden_grub_log="21-A2p-selected"; save_env -f ($root)/boot/grub/grubenv elden_grub_log
  if devicetree ($root)/boot/elden.dtb; then set elden_grub_log="21-A2p-dtb-ok"; else set elden_grub_log="2A-A2p-dtb-FAIL"; fi
  save_env -f ($root)/boot/grub/grubenv elden_grub_log
  if linux ($root)/boot/Image console=ttyGS0,115200 console=tty0 earlycon=efifb keep_bootcon loglevel=8 ignore_loglevel printk.devkmsg=on panic=0 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1 root=LABEL=linux17 elden_bootmenu=grub-A2p; then set elden_grub_log="21-A2p-linux-ok"; else set elden_grub_log="2A-A2p-linux-FAIL"; fi
  save_env -f ($root)/boot/grub/grubenv elden_grub_log
  if initrd ($root)/boot/initrd.img; then set elden_grub_log="21-A2p-initrd-ok-booting"; else set elden_grub_log="2A-A2p-initrd-FAIL"; fi
  save_env -f ($root)/boot/grub/grubenv elden_grub_log
}

menuentry "A2 panic=15 变体（对照：失败会自己重启回 b 槽）" {
  search --no-floppy --label --set=root linux17
  set elden_grub_log="22-A2p15-selected"; save_env -f ($root)/boot/grub/grubenv elden_grub_log
  devicetree ($root)/boot/elden.dtb
  linux ($root)/boot/Image console=ttyGS0,115200 console=tty0 earlycon=efifb keep_bootcon loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1 root=LABEL=linux17 elden_bootmenu=grub-A2p15
  initrd ($root)/boot/initrd.img
}

menuentry "A 基线（无 earlycon，预期黑屏；留作单变量对照）" {
  search --no-floppy --label --set=root linux17
  set elden_grub_log="23-Abase-selected"; save_env -f ($root)/boot/grub/grubenv elden_grub_log
  devicetree ($root)/boot/elden.dtb
  linux ($root)/boot/Image console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17 androidboot.slot_suffix=_b elden_nocamera=1 root=LABEL=linux17 elden_bootmenu=grub-Abase
  initrd ($root)/boot/initrd.img
}

menuentry "D 走 ESP Loader.efi（原 11-08 路径，对照）" {
  search --no-floppy --label --set=esp ELDENESP
  chainloader ($esp)/EFI/elden/Loader.efi
}

menuentry "reboot" { reboot }
menuentry "poweroff" { halt }
EOF
	say "生成 $OUT/grub.cfg（$(wc -l < "$OUT/grub.cfg") 行）"
}

do_stage() {
	gen_cfg
	scp -q -o BatchMode=yes -o StrictHostKeyChecking=no "$OUT/grub.cfg" "$DEVICE:/tmp/grub.cfg.new" || die "scp 失败"
	say "已 stage 到设备 /tmp/grub.cfg.new（未生效）"
	S 'sha256sum /tmp/grub.cfg.new; echo "--- 与在用的差异："; diff -u /boot/grub/grub.cfg /tmp/grub.cfg.new | head -40' 60
}

do_apply() {
	[ -f "$OUT/grub.cfg" ] || do_stage
	S "
	  set -e
	  [ -f /tmp/grub.cfg.new ] || { echo '缺 /tmp/grub.cfg.new'; exit 1; }
	  cp -a /boot/grub/grub.cfg /boot/grub/grub.cfg.bak-$TS
	  install -m 0644 /tmp/grub.cfg.new /boot/grub/grub.cfg
	  sync
	  echo '--- 落盘后校验'
	  sha256sum /boot/grub/grub.cfg /tmp/grub.cfg.new
	  grep -nE '^set (timeout|default)' /boot/grub/grub.cfg
	  ls -l /boot/grub/
	" 60 || die "写 /boot/grub/grub.cfg 失败"
	say "已生效；备份 /boot/grub/grub.cfg.bak-$TS"
	say "下一步（需设备窗口）：set_active a 后观察屏与 grubenv 留痕"
}

do_rollback() {
	last=$(S 'ls -1t /boot/grub/grub.cfg.bak-* 2>/dev/null | head -1')
	[ -n "$last" ] || die "设备上没有 grub.cfg.bak-*"
	say "回滚到 $last"
	S "install -m 0644 '$last' /boot/grub/grub.cfg && sync && sha256sum /boot/grub/grub.cfg '$last'" 60 || die "回滚失败"
	say "回滚完成"
}

case "$MODE" in
	check)    do_check;;
	stage)    do_stage;;
	apply)    do_stage; do_apply;;
	rollback) do_rollback;;
esac
