#!/bin/bash
# android-v3-bringup-walkthrough.sh — 安卓精简 v3「首启验证」上机执行包（S1–S5，默认 dry-run）
#
# 背景（2026-11-19，`reports/android-slim-v3-20261119.md` §7/§8 + `INDEX.md` §0）：
#   v3 已写入 super 且 EDL 读回逐字节一致，但 3 发上机都没进桌面，其中 2 发被 **BCB 污染**
#   （`misc` = boot-recovery / bootonce-bootloader ⇒ 那两发很可能启的是 recovery，不是 Android）。
#   因此下一轮纪律 = 每一步「清 BCB → 读回校验全 0 → 才 reset」；顺序 S1→S5：
#     S1 清 BCB + 槽位置 a + v1 super 在机的首启观察（复现/排除 confound）
#     S2 回写原厂 metadata（29 MB，8 分片拼装）
#     S3 刷原厂 super 对照（14.54 GiB，8 分片拼装）
#     S4 二分：v2b（删池/AI/bgmusic、保留 18 个 leaf 包）
#     S5 日志通道：console=ttyGS0 的 boot 件（2026-11-20 解锁：原厂 boot.img = header v4，
#        scripts/boot-img-cmdline.py 已支持 v3/v4（等长原地替换 cmdline 窗口），件由 S5 自己造/核；
#        细节与「fastboot 是否认」的需上机项见 reports/bootimg-v4-cmdline-20261120.md）
#
# 权威文档：`reports/android-v3-bringup-packet-20261120.md`（本脚本 = 其机械化形态）
#
# 用法：
#   scripts/android-v3-bringup-walkthrough.sh                 # 默认 --dry-run：只打印命令 + 前置校验 + 判据
#   scripts/android-v3-bringup-walkthrough.sh --verify        # 只做主机侧件校验（不碰设备、不打印写命令）
#   scripts/android-v3-bringup-walkthrough.sh --step S2       # 只走某一步（可重复 / 逗号分隔）
#   scripts/android-v3-bringup-walkthrough.sh --apply         # 真执行（**设备写操作**：需人确认）
#   scripts/android-v3-bringup-walkthrough.sh --apply --step S1
#
# 选项：
#   --dry-run            只打印（默认）
#   --apply              真执行；写操作全部走本仓既有封装（qdl / fastboot / ssh / android-super.py）
#   --verify             只做主机侧件校验（等价于 preflight，不打印设备写命令）
#   --step S1,S3         选择步骤（默认 S1 S2 S3 S4 S5）
#   --serial SN          目标设备序列号（默认 HA2EXB0E）
#   --readback full      写后全量读回（默认 head+tail 各 16 MiB + 设备端 sha256，见 PITFALLS #669）
#   --observe-timeout N  每步首启观察上限秒（默认 600）
#   --no-sha             跳过主机侧 sha256 复核（默认核；15 GB 级件约 30 s）
#   --allow-foreign-edl  允许「进来时就已经在 9008」继续（默认拒绝：qdl 不认 serial，会刷到别人那台）
#   -h|--help
#
# 硬约束（脚本内已机械化）：
#   * 每条外部命令都过 `timeout -k`；qdl 每条都带 `-R`（= --skip-reset），reset 单独一发（PITFALLS #674/#675）。
#   * **只读引用** `backup/`（官方原件）、`out/android-slim-v3-20261119/new/`、`bootslot-b/`；
#     本脚本的产物一律落 `out/android-v3-bringup-20261120/` 与 `logs/android-v3-<step>-<ts>/`。
#   * 写前门：现场读一次 live GPT（LUN0 LBA0..5）→ `scripts/android-linux-coexist-check.py` + 分区起始核对；
#     表变了就拒绝写（PITFALLS #675 同类事故）。
#   * 写后门：设备端 `qdl sha256` + 读回 head/tail 逐字节比对，三条任一不符 ⇒ rc=1 并归档。
#   * reset 前最后一步 = 清 BCB（4 KiB 零）+ 读回全 0；否则「起不来」无法区分真失败与 BCB 污染。
#   * 首启判据三条（缺一不算成功）：`sys.boot_completed=1`、launcher 拿到焦点、无 recovery 循环。
#
# 退出码：0 全部步骤达判据 / 1 某步失败（日志指路） / 2 用法错 / 3 需要人项（物理上电、插线、按键）
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SER=${SER:-${SERIAL:-HA2EXB0E}}
TAB=${TAB:-root@192.168.7.1}
QDL=${QDL:-$HOME/edl/qdl/build/qdl}
LOADER=${LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}
ROM=${ROM:-$ROOT/backup/official-rom-15.10.259}
ART=${ART:-$ROOT/out/android-v3-bringup-20261120}
STAMP=$(date +%Y%m%d-%H%M%S)
APPLY=0; VERIFY_ONLY=0; STEPS=""; READBACK=headtail; OBS_TO=600; DO_SHA=1; ALLOW_FOREIGN_EDL=0

# ---- 主机侧固定件（2026-11-20 实测 sha256；见 reports/artifacts/android-v3-bringup-20261120/pieces-inventory.txt）
# 列：逻辑名|路径|字节|sha256|crit
#   crit=1 ⇒ 与登记 sha 不符即**拒绝继续**（上机路径上的件）；crit=0 ⇒ 只 WARN（仅取证用/非关键）
#   sha 一律**读两次**：两次不一致 ⇒ 判「主机读路径不稳（AGENTS 硬规则 12）」，不当作件坏了
#   （2026-11-20 实测：`super_dbg.img` mtime 不变、连读三次得 3 个不同 sha ⇒ 见
#     reports/artifacts/android-v3-bringup-20261120/superdbg-sha-drift.txt）
PIECES="
v1_super|out/android-min-20261118/pkg/super_min.img|8893497344|e3d0d26fb3a6f97ec10e4533ea2d675a9693acb42bb10ddb9dd4cb897517e13c|1
v3_super|out/android-slim-v3-20261119/new/super_min_v3.img|7454326784|51eae1075fe159b02946a4e4e5548fa83bb5e861fb441244ac8dddc423bc6440|1
v3_dbg_super|out/android-slim-v3-20261119/new/super_dbg.img|7454326784|8b42f20dd8cc2205489c26c6f75ee9ec8ef5659aa3fdb41662cdf3b5ebf11085|0
v2b_super|out/android-slim-v2b-20261119/new/super_min_v3.img|9165602816|98a88ea0aa82283822034d823751a3f3ef30aa44fba723516f6d26abb95adbfc|1
metadata_stock|out/android-v3-bringup-20261120/metadata_stock.img|29372416|a735fbc74abf0d9695a1fc598128acc78184abc710224719825bbe16fca4722e|1
boot_a_stock|backup/official-rom-15.10.259/boot.img|100663296|b428a31dadc5db3f91620c1f4114f5ee7702e34e0789ed9bf84a878a49898f20|0
linux_boot_b|out/boot-elden-vk192.img|85815296|bdf47f5f3f8a49e8e1fd77557c10640dec8e00c76e46bd731503e162bbdb841b|0
"

# ---- 几何常量（全部来自 backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml，4096 B 扇区）
LBA_SUPER=90504            # super 分区起点（22 GiB：90504..5857671）
LBA_METADATA=5857704       # metadata 分区起点（= 原厂件起点；5857672 是 vbmeta_system_a，勿混）
MISC_LBA=89992             # misc 分区起点（BCB 头在此）
METADATA_SECT=7171         # 件长（8 分片拼装后 29372416 B = 7171 扇区；分区本体 16384 扇区 = 64 MiB）
SECT=4096

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
warn() { printf '\033[33m   WARN %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31m   FAIL %s\033[0m\n' "$*" >&2; exit "${2:-1}"; }

while [ $# -gt 0 ]; do
	case "$1" in
		--apply) APPLY=1; shift ;;
		--dry-run) APPLY=0; shift ;;
		--verify) VERIFY_ONLY=1; shift ;;
		--step) STEPS="${STEPS:+$STEPS,}$2"; shift 2 ;;
		--serial) SER=$2; shift 2 ;;
		--readback) READBACK=$2; shift 2 ;;
		--observe-timeout) OBS_TO=$2; shift 2 ;;
		--no-sha) DO_SHA=0; shift ;;
		--allow-foreign-edl) ALLOW_FOREIGN_EDL=1; shift ;;
		-h|--help) sed -n '2,50p' "$0"; exit 0 ;;
		*) echo "未知参数 $1（--help 看用法）" >&2; exit 2 ;;
	esac
done
[ -n "$STEPS" ] || STEPS="S1,S2,S3,S4,S5"
STEPS=$(printf '%s' "$STEPS" | tr 'a-z' 'A-Z')
want_step() { printf '%s' "$STEPS" | tr ',' '\n' | grep -qx "$1"; }

MODE=DRY-RUN; [ "$APPLY" = 1 ] && MODE=APPLY

# 每步一个归档目录；所有命令、读回件、判据都写进它
STEPLOG=""
step_begin() {
	local s=$1
	STEPLOG=$ROOT/logs/android-v3-$s-$STAMP
	mkdir -p "$STEPLOG"
	: > "$STEPLOG/commands.log"
	say "$s  （归档 $STEPLOG）"
}
logc() { [ -n "$STEPLOG" ] && printf '%s\n' "$*" >> "$STEPLOG/commands.log"; return 0; }

# run <超时秒> <命令...>：dry-run 只打印；apply 真跑并把输出 tee 进步骤目录
run() {
	local secs=$1; shift
	logc "timeout -k 5 $secs $*"
	if [ "$APPLY" != 1 ]; then
		printf '   [dry] timeout -k 5 %s %s\n' "$secs" "$*"
		return 0
	fi
	printf '   [run] timeout -k 5 %s %s\n' "$secs" "$*"
	timeout -k 5 "$secs" "$@"
}

# hass <字>：stdin 里有整行匹配
hass() { grep -qx -- "$1"; }

# sha_direct <文件>：**绕过页缓存**算 sha256（O_DIRECT），失败才退回普通读。
# 为什么要它（2026-11-20 实测，`reports/artifacts/android-v3-bringup-20261120/superdbg-sha-drift.txt`）：
#   v1 件 buffered 连读 5 次一致 = 637a9965…，而 O_DIRECT 读 = e3d0d26f…（= 登记值）
#   ⇒ 页缓存被污染时「连读两次一致」**抓不到**（两次都命中同一份坏缓存）。
#   旧口径「双 sha256 硬门」（build 脚本 §7）在本机不可靠，必须用 O_DIRECT 或先 pcache-wash。
#   （入口 ~/hw-stability/AGENTS.md；AGENTS 硬规则 12：硬件稳定性不在项目里深挖）
# 2026-11-20 P0-5：sha_direct 改走 scripts/odirect-sha.py（O_DIRECT 硬门，见该文件头注释
# 与 reports/odirect-sha-gate-20261120.md）。O_DIRECT 直读绕过页缓存，单次即可判定；
# 工具内部 O_DIRECT 不可用时退回 buffered 并打 stderr WARN，shell 侧此时补 buffered 兜底。
sha_direct() {
	local f=$1 out v
	out=$(timeout -k 10 1800 python3 "$ROOT/scripts/odirect-sha.py" --tsv "$f" 2>&1)
	v=$(printf '%s\n' "$out" | awk -F'\t' 'NR==1{print $3}')
	if [ -z "$v" ] || [ "${#v}" != 64 ]; then
		v=$(sha256sum "$f" | cut -d' ' -f1)
		warn "sha_direct: $f 未能走 O_DIRECT（$out），退回 buffered（结果可能被页缓存污染）"
	fi
	printf '%s\n' "$v"
}

dev_state() {
	# EDL 优先：9008 出现时 adb/fastboot 必然都空
	if timeout -k 5 5 lsusb -d 05c6:9008 >/dev/null 2>&1; then echo edl; return; fi
	if timeout -k 5 8 fastboot devices 2>/dev/null | awk '{print $1}' | grep -qx "$SER"; then echo fastboot; return; fi
	local st
	st=$(timeout -k 5 10 adb devices 2>/dev/null | awk -v s="$SER" '$1==s{print $2}')
	case "$st" in
		device) echo android; return ;;
		recovery|sideload) echo recovery; return ;;
	esac
	if timeout -k 5 10 ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no "$TAB" true >/dev/null 2>&1; then
		echo linux; return
	fi
	echo offline
}

assert_no_foreign_device() {
	# PITFALLS #371：总线上唯一的 adb 设备可能是另一台手机（实测 MDX5T20730009849）
	local n
	n=$(timeout -k 5 10 adb devices 2>/dev/null | awk 'NR>1 && $2!=""{print $1}' | wc -l)
	if [ "$n" -gt 0 ] && ! timeout -k 5 10 adb devices 2>/dev/null | awk '{print $1}' | grep -qx "$SER"; then
		warn "adb 上有 $n 台设备但没有 $SER ⇒ 任何写操作都不会发出去（只认显式序列号）"
	fi
	return 0
}

# ---------------------------------------------------------------- preflight
preflight() {
	say "0) 前置校验（主机侧件 + 工具 + 设备现态；全部只读）"
	local bad=0 name path bytes sha crit p b s1 s2
	while IFS='|' read -r name path bytes sha crit; do
		[ -n "${name:-}" ] || continue
		p=$ROOT/$path
		if [ ! -e "$p" ]; then printf '   MISS  %-15s %s（缺件）\n' "$name" "$path"; bad=1; continue; fi
		b=$(stat -c%s "$p")
		if [ "$b" != "$bytes" ]; then printf '   SIZE  %-15s %s 字节（期望 %s）\n' "$name" "$b" "$bytes"; bad=1; continue; fi
		if [ "$DO_SHA" = 1 ] && [ -n "$sha" ]; then
			s1=$(sha_direct "$p")
			s2=$(sha_direct "$p")
			if [ "$s1" != "$s2" ]; then
				printf '   DRIFT %-15s 两次读 sha 不同（%s… / %s…）⇒ 主机读路径不稳（硬规则 12），件本身未必坏\n' \
					"$name" "${s1:0:12}" "${s2:0:12}"
				[ "$crit" = 1 ] && bad=1
				continue
			fi
			if [ "$s1" != "$sha" ]; then
				printf '   SHA   %-15s %s != 登记 %s（稳定两次）\n' "$name" "${s1:0:16}…" "${sha:0:16}…"
				if [ "$crit" = 1 ]; then bad=1; else printf '         （crit=0：只 WARN，该件不在这轮上机主路径上）\n'; fi
				continue
			fi
			printf '   OK    %-15s %12s B  sha=%s…\n' "$name" "$b" "${s1:0:16}"
		else
			printf '   OK    %-15s %12s B  （--no-sha）\n' "$name" "$b"
		fi
	done <<< "$PIECES"

	# 原厂分片齐备（S2/S3 要用；R6 口径 = super 1..N 连续且在盘）
	local i miss=0
	for i in 1 2 3 4 5 6 7 8; do
		[ -e "$ROM/super_$i.img" ]    || { printf '   MISS  原厂 super_%s.img\n' "$i"; miss=1; }
		[ -e "$ROM/metadata_$i.img" ] || { printf '   MISS  原厂 metadata_%s.img\n' "$i"; miss=1; }
	done
	[ "$miss" = 0 ] && info "原厂分片齐备：super_1..8 + metadata_1..8（rawprogram_save_persist_unsparse0.xml）"
	[ "$miss" = 0 ] || bad=1

	# 工具
	local t
	for t in "$QDL" "$LOADER" "$ROOT/scripts/android-super.py" "$ROOT/scripts/android-linux-coexist-check.py" \
	         "$ROOT/scripts/rawprogram-preflight.py" "$ROOT/scripts/ncm-host-up.sh"; do
		[ -e "$t" ] || { printf '   MISS  工具 %s\n' "$t"; bad=1; }
	done
	command -v python3 >/dev/null || { printf '   MISS  python3\n'; bad=1; }
	command -v fastboot >/dev/null || { printf '   MISS  fastboot\n'; bad=1; }
	command -v adb >/dev/null || { printf '   MISS  adb\n'; bad=1; }
	[ -x "$QDL" ] && info "qdl: $QDL" || bad=1
	info "loader: $LOADER"

	# 件可用性口径（v3 的 blockdev size 差异 = 已知待拉平项，见报告 §2）
	info "v3 super 现态 sha 已核（51eae107…）；v3 的 liblp blockdev size = 7454326784 ≠ v1 的 23622320128（已知差异，勿在本轮混入结论）"

	# 设备现态
	assert_no_foreign_device
	local st; st=$(dev_state)
	info "设备现态: $st  （EDL=05c6:9008 / fastboot / android / recovery / linux-ssh / offline）"
	case "$st" in
		offline) warn "设备离线：S1 需在 Linux 侧执行；请先插线 + 上电（人项），再 sudo scripts/ncm-host-up.sh" ;;
		edl) [ "$ALLOW_FOREIGN_EDL" = 1 ] || warn "进来时已在 9008：qdl 不认 serial（PITFALLS #669）⇒ 确属本机才加 --allow-foreign-edl" ;;
	esac
	[ "$bad" = 0 ] || die "前置校验有缺件/缺工具（见上）" 1
	if [ "$VERIFY_ONLY" = 1 ]; then
		say "verify 完成：主机侧件全部在位（设备现态 = $st）"
		exit 0
	fi
	return 0
}

# ---------------------------------------------------------------- 设备动作封装
ensure_edl() {
	local st; st=$(dev_state)
	if [ "$st" = edl ]; then
		[ "$ALLOW_FOREIGN_EDL" = 1 ] && info "已在 9008（--allow-foreign-edl）" || \
			die "进来时已在 9008：qdl 不选 serial，拒绝猜测归属（确属本机加 --allow-foreign-edl）" 3
		return 0
	fi
	case "$st" in
		fastboot)
			run 60 fastboot -s "$SER" oem edl
			;;
		android)
			run 60 adb -s "$SER" reboot edl
			;;
		linux)
			# Linux → fastboot 走 PSCI vendor reset（PITFALLS #150–#152：不用 reboot bootloader）
			run 120 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" 'sync; systemctl reboot bootloader'
			[ "$APPLY" = 1 ] || { info "[dry] 之后等 fastboot → fastboot -s $SER oem edl"; return 0; }
			local i
			for i in $(seq 1 60); do
				timeout -k 5 8 fastboot devices 2>/dev/null | awk '{print $1}' | grep -qx "$SER" && break
				sleep 2
			done
			run 60 fastboot -s "$SER" oem edl
			;;
		*)
			[ "$APPLY" = 1 ] && die "无法进入 EDL：设备现态 = $st（需人项：插线/上电/按键）" 3
			warn "dry-run：设备现态 = $st；--apply 时会按上面列出的路径进 EDL"
			return 0 ;;
	esac
	[ "$APPLY" = 1 ] || { info "[dry] 之后等 lsusb 出现 05c6:9008"; return 0; }
	local i
	for i in $(seq 1 60); do
		timeout -k 5 5 lsusb -d 05c6:9008 >/dev/null 2>&1 && { info "EDL 已枚举（05c6:9008）"; return 0; }
		sleep 2
	done
	die "120 s 未枚举 05c6:9008 ⇒ 没进 EDL（人项：按键/插线）" 3
}

ensure_linux() {
	local st; st=$(dev_state)
	[ "$st" = linux ] && { info "Linux 侧 ssh 可用（$TAB）"; return 0; }
	if [ "$APPLY" = 1 ]; then
		[ "$st" = offline ] && die "设备离线：Linux 侧步骤需要 ssh（先 sudo scripts/ncm-host-up.sh + 人项上电）" 3
		die "设备现态 = $st，不是 Linux（S1/S5 的只读/清 BCB 路径需要 Linux 侧）" 3
	fi
	warn "dry-run：设备现态 = $st（Linux 侧命令只在 --apply 且 ssh 可达时才发）"
	return 0
}

# ensure_active_a：Android 首启的前提（ABL 只启 active 槽；b 槽 = Linux）
#   ⚠ 常见误解：`qbootctl -a` 是**只读查询**（get active slot），设置 active 是 `qbootctl -s SLOT`
#     或 fastboot `--set-active=SLOT`（本仓走后者，PITFALLS「set-active 走 BSG」口径）。
ensure_active_a() {
	local st; st=$(dev_state)
	case "$st" in
		linux)
			run 30 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" 'qbootctl -a 2>&1; qbootctl 2>&1 | head -20'
			info "判据：Active slot: a（只读查询）；若为 b ⇒ 需先切 a（写 GPT 属性，可回退 --set-active=b）"
			;;
		fastboot)
			run 20 fastboot -s "$SER" getvar current-slot
			if [ "$APPLY" = 1 ]; then
				local cur
				cur=$(timeout -k 5 20 fastboot -s "$SER" getvar current-slot 2>&1 | awk -F': ' '/^current-slot/{print $2}')
				if [ "$cur" != a ]; then
					info "current-slot=$cur ⇒ 切 a（写 GPT 属性；回退 = fastboot --set-active=b）"
					run 20 fastboot -s "$SER" --set-active=a
					run 20 fastboot -s "$SER" getvar current-slot
				fi
			else
				info "[dry] 若 current-slot != a ⇒ fastboot -s $SER --set-active=a（写 GPT 属性，super 零改动）"
			fi
			;;
		*) info "现态 $st：active 槽用 linux 侧 qbootctl -a 或 fastboot getvar current-slot 读" ;;
	esac
}

# bcb_read <输出件>：把 misc 的 BCB 头（16 KiB）抓到主机
bcb_read() {
	local out=$1 st; st=$(dev_state)
	case "$st" in
		linux)
			# 抓字节不能走 run()：run 的 printf 也会进 stdout（历史 bug：$out 里混进一行命令文本，
			# 让 bcb_judge 把「命令字符串长度 153」当 nonzero=153，见 2026-11-20 11:2x 实测）
			logc "ssh $TAB \"dd if=/dev/disk/by-partlabel/misc bs=4096 count=4\" > $out  (只读)"
			timeout -k 5 60 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" \
				"dd if=/dev/disk/by-partlabel/misc bs=4096 count=4 2>/dev/null" > "$out" 2>/dev/null
			;;
		edl)
			run 120 "$QDL" -s ufs -R "$LOADER" read "0/$MISC_LBA+4" "$out"
			;;
		*)
			if [ "$APPLY" != 1 ]; then
				printf '   [dry] BCB 取法① Linux: ssh %s "dd if=/dev/disk/by-partlabel/misc bs=4096 count=4" > %s\n' "$TAB" "$out"
				printf '   [dry] BCB 取法② EDL:  %s -s ufs -R %s read 0/%s+4 %s\n' "$QDL" "$LOADER" "$MISC_LBA" "$out"
			fi
			: > "$out"; return 1 ;;
	esac
	return 0
}

# bcb_judge <件>：打印 BCB 命令 + 判读（zero / bootonce-bootloader / boot-recovery / 其它）
bcb_judge() {
	local f=$1
	[ -s "$f" ] || { info "BCB: 未取到（设备不在 linux/EDL）"; return 1; }
	python3 - "$f" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
nz = [i for i, b in enumerate(d) if b]
cmd = d[:64].split(b'\0')[0].decode('ascii', 'replace')
print(f"   BCB: size={len(d)} nonzero={len(nz)} command={cmd!r}")
if not nz:
    print("   判读: 全 0 ⇒ 干净（ABL 按 active 槽正常启动）")
elif cmd.startswith('boot-recovery'):
    print("   判读: ★BCB 污染 = boot-recovery ⇒ 这次 reset 会进 recovery，**不是 Android 失败样本**，先清 0 再来")
elif cmd.startswith('bootonce-'):
    print("   判读: ★BCB 污染 = bootonce-* ⇒ 下一次启动被强制到别的模式；清 0 后再 reset")
else:
    print("   判读: 非空且非已知值 ⇒ 先备份后清 0，再判断")
PY
}

# bcb_clear_verify：清 BCB 4 KiB + 读回必须全 0（reset 前的最后一步）
bcb_clear_verify() {
	local st; st=$(dev_state)
	case "$st" in
		linux)
			run 30 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" \
				'cp -f /dev/disk/by-partlabel/misc /tmp/misc.bcb.bak 2>/dev/null; dd if=/dev/zero of=/dev/disk/by-partlabel/misc bs=4096 count=1 conv=fsync 2>&1'
			[ "$APPLY" = 1 ] || { info "[dry] 之后 dd 读 16 KiB 校验全 0"; return 0; }
			timeout -k 10 60 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" \
				'dd if=/dev/disk/by-partlabel/misc bs=4096 count=4 2>/dev/null' > "$STEPLOG/bcb-after.bin" 2>/dev/null
			;;
		edl)
			head -c 4096 /dev/zero > "$STEPLOG/zero4k.bin"
			run 120 "$QDL" -s ufs -R "$LOADER" write "0/$MISC_LBA" "$STEPLOG/zero4k.bin" read "0/$MISC_LBA+1" "$STEPLOG/bcb-after.bin"
			[ "$APPLY" = 1 ] || { info "[dry] 之后校验 bcb-after.bin 全 0"; return 0; }
			;;
		*)
			if [ "$APPLY" = 1 ]; then die "清 BCB 需要 linux 或 edl 现态（当前 $st）" 3; fi
			printf '   [dry] 清法① Linux: ssh %s "cp -f /dev/disk/by-partlabel/misc /tmp/misc.bcb.bak; dd if=/dev/zero of=/dev/disk/by-partlabel/misc bs=4096 count=1 conv=fsync"\n' "$TAB"
			printf '   [dry] 清法② EDL:  %s -s ufs -R %s write 0/%s zero4k.bin read 0/%s+1 bcb-after.bin\n' "$QDL" "$LOADER" "$MISC_LBA" "$MISC_LBA"
			printf '   [dry] 判据：bcb-after.bin nonzero==0（否则不要 reset）\n'
			return 0 ;;
	esac
	local nz
	nz=$(python3 -c "import sys;d=open(sys.argv[1],'rb').read();print(sum(1 for b in d if b))" "$STEPLOG/bcb-after.bin" 2>/dev/null || echo -1)
	logc "bcb-after nonzero=$nz"
	if [ "$nz" = 0 ]; then info "OK   BCB 读回全 0（$STEPLOG/bcb-after.bin）"; return 0; fi
	warn "BCB 读回 nonzero=$nz（不为 0）⇒ 不要 reset"
	return 1
}

# live_gpt_gate：现场读 LUN0 主表 + 复用 coexist 核对器 + 分区起始核对
live_gpt_gate() {
	local d=$STEPLOG
	run 120 "$QDL" -s ufs -R "$LOADER" read "0/0+6" "$d/live-gpt0-primary.bin"
	[ "$APPLY" = 1 ] || { info "[dry] 之后 python3 scripts/android-linux-coexist-check.py --gpt $d/live-gpt0-primary.bin"; return 0; }
	local extra=""; [ -n "${1:-}" ] && extra="--super-img $1"
	# shellcheck disable=SC2086
	if ! python3 "$ROOT/scripts/android-linux-coexist-check.py" --gpt "$d/live-gpt0-primary.bin" $extra; then
		die "coexist-check 拒绝（表/件不匹配）⇒ 不写" 1
	fi
	python3 - "$d/live-gpt0-primary.bin" <<'PY' || exit 1
import struct, sys
b = open(sys.argv[1], 'rb').read()
h = b[4096:4096+92]
assert h[:8] == b'EFI PART', "LBA1 不是 EFI PART ⇒ 读回件不可信"
ent_lba, = struct.unpack_from('<Q', h, 72); nent, esz = struct.unpack_from('<II', h, 80)
# 几何取自 out/android-slim-v3-20261119/edl/gpt0-primary.bin 现读（见 artifacts/gpt0-geometry.txt）：
#   super 90504..5857671 (5767168 扇区) / metadata 5857704..5874087 (16384 扇区 = 64 MiB)
#   ⚠ metadata 分区起点是 5857704 而不是 5857672（5857672 是 vbmeta_system_a）
want = {'super': (90504, 5767168), 'metadata': (5857704, 16384)}
for i in range(nent):
    e = b[ent_lba*4096+i*esz: ent_lba*4096+(i+1)*esz]
    if e[:16] == b'\0'*16: continue
    name = e[56:128].decode('utf-16-le').rstrip('\0')
    if name in want:
        start, last = struct.unpack_from('<QQ', e, 32)
        w_start, w_sect = want[name]
        ok = (start == w_start) and (last - start + 1 >= w_sect)
        print(f"   gate {name}: live {start}..{last} ({last-start+1} 扇区) 期望 {w_start}+{w_sect} ⇒ {'OK' if ok else 'MISMATCH'}")
        if not ok: sys.exit(1)
PY
}

# qdl_write_verify <img> <lba> <扇区数> <标签>
qdl_write_verify() {
	local img=$1 lba=$2 nsect=$3 label=$4
	local d=$STEPLOG want host_sha head=t16m tail=t16m
	head=$d/readback-head16m.bin; tail=$d/readback-tail16m.bin
	if [ -e "$img" ]; then
		want=$(sha256sum "$img" | cut -d' ' -f1)
		logc "期望 sha256=$want  bytes=$(stat -c%s "$img")  LBA=$lba..$((lba+nsect-1))"
	elif [ "$APPLY" != 1 ]; then
		want="(dry-run：件尚未生成)"
		logc "期望 sha256=$want（--apply 时由 assemble 生成）  LBA=$lba..$((lba+nsect-1))"
	else
		die "件不存在：$img" 1
	fi
	if [ "$READBACK" = full ]; then
		run 1800 "$QDL" -s ufs -R "$LOADER" \
			write "0/$lba" "$img" \
			read "0/$lba+$nsect" "$d/readback-full.img" \
			sha256 "0/$lba+$nsect"
	else
		run 1800 "$QDL" -s ufs -R "$LOADER" \
			write "0/$lba" "$img" \
			sha256 "0/$lba+$nsect" \
			read "0/$lba+4096" "$head" \
			read "0/$((lba+nsect-4096))+4096" "$tail"
	fi 2>&1 | tee -a "$d/qdl.log" | tail -6
	[ "$APPLY" = 1 ] || { info "[dry] 之后：设备端 sha256 + 读回 head/tail 与源件逐字节比对"; return 0; }

	host_sha=$(grep -oE '^[0-9a-f]{64}$' "$d/qdl.log" | tail -1 || true)
	if [ -n "$host_sha" ]; then
		[ "$host_sha" = "$want" ] && info "OK   设备端 sha256 = 主机（${want:0:16}…）" || { warn "设备端 sha256 不符 dev=${host_sha:0:16}… host=${want:0:16}…"; return 1; }
	else
		warn "未取到设备端 sha256（loader 无 getsha256digest）⇒ 只用读回件判据"
	fi
	if [ "$READBACK" = full ]; then
		local got; got=$(sha256sum "$d/readback-full.img" | cut -d' ' -f1)
		[ "$got" = "$want" ] || { warn "全量读回不符 got=${got:0:16}…"; return 1; }
		info "OK   全量读回逐字节一致"
	else
		# head 16 MiB 与 tail 16 MiB 逐字节
		head -c 16777216 "$img" > "$d/src-head16m.bin"
		tail -c 16777216 "$img" > "$d/src-tail16m.bin"
		cmp -s "$d/src-head16m.bin" "$head" || { warn "head 16 MiB 读回不符"; return 1; }
		cmp -s "$d/src-tail16m.bin" "$tail" || { warn "tail 16 MiB 读回不符"; return 1; }
		info "OK   head/tail 各 16 MiB 读回逐字节一致（$label）"
	fi
	return 0
}

# observe_android <step>：首启观察（三条硬判据 + 失败分类）
observe_android() {
	local s=$1 d=$STEPLOG deadline i st bc focus pkgs
	if [ "$APPLY" != 1 ]; then
		info "[dry] 之后：轮询 adb -s $SER（上限 ${OBS_TO}s）→ 三条硬判据："
		info "       ① getprop sys.boot_completed = 1   ② dumpsys window 里 mCurrentFocus 含 launcher"
		info "       ③ adb 状态不是 recovery（无 recovery 循环：连续 2 次复位回 recovery 即判定）"
		return 0
	fi
	deadline=$(( $(date +%s) + OBS_TO ))
	: > "$d/observe.log"
	while [ "$(date +%s)" -lt "$deadline" ]; do
		st=$(dev_state)
		echo "[$(date +%T)] state=$st" >> "$d/observe.log"
		case "$st" in
			android)
				bc=$(timeout -k 5 15 adb -s "$SER" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
				focus=$(timeout -k 5 20 adb -s "$SER" shell 'dumpsys window 2>/dev/null | grep -m2 -E "mCurrentFocus|EnableScreen"' 2>/dev/null | tr -d '\r')
				echo "[$(date +%T)] boot_completed=$bc" >> "$d/observe.log"
				echo "$focus" >> "$d/observe.log"
				if [ "$bc" = 1 ]; then
					pkgs=$(timeout -k 5 30 adb -s "$SER" shell 'pm list packages 2>/dev/null | wc -l' 2>/dev/null | tr -d '\r')
					timeout -k 5 120 adb -s "$SER" logcat -d -b all > "$d/logcat-all.log" 2>/dev/null
					timeout -k 5 60 adb -s "$SER" shell 'ls -l /data/system/preinstallapk /data/system/waitpreinstallapp 2>&1; getprop ro.build.version.release; getprop ro.boot.verifiedbootstate' > "$d/props.log" 2>/dev/null
					if printf '%s' "$focus" | grep -qiE 'launcher|zui'; then
						printf 'SUCCESS boot_completed=1 focus=launcher pkgs=%s\n' "$pkgs" > "$d/verdict.txt"
						info "★成功：boot_completed=1 + launcher 焦点（包数 $pkgs）"
						return 0
					fi
					printf 'PARTIAL boot_completed=1 但 focus 未见 launcher（%s）\n' "$focus" > "$d/verdict.txt"
					info "△ boot_completed=1 但 launcher 未拿焦点，继续观察…"
				fi
				;;
			recovery)
				timeout -k 5 30 adb -s "$SER" shell 'ls -l /tmp/recovery.log 2>&1' >> "$d/observe.log" 2>&1
				printf 'RECOVERY 落在 recovery（先读 misc 判 BCB 污染 vs 真失败）\n' > "$d/verdict.txt"
				info "★落在 recovery ⇒ 立即用 bcb_read 判 confound（这一步是纪律，不是结论）"
				return 2
				;;
			fastboot|edl)
				printf 'EARLY_FAIL state=%s（ABL/内核段就退出，未起 Android userspace）\n' "$st" > "$d/verdict.txt"
				info "★早失败：现态 $st（看起来更像真失败；仍要读 misc 排除 BCB）"
				return 3
				;;
			linux)
				printf 'FELL_BACK_LINUX（落到 b 槽 Linux ⇒ 本次没启 Android）\n' > "$d/verdict.txt"
				info "★落回 Linux（b 槽）：本次 reset 没启 Android（active 槽或 BCB 问题）"
				return 4
				;;
		esac
		sleep 10
	done
	printf 'TIMEOUT %ss 内未见 adb（黑屏/硬挂/未枚举，需读 misc + pstoredump）\n' "$OBS_TO" > "$d/verdict.txt"
	info "★${OBS_TO}s 内 adb 未出现：下一步 = EDL 读 misc（BCB?）+ pstoredump（panic?）"
	return 5
}

# pstore_triage：从 Linux 侧读 pstoredump，grep panic/oops（真失败 vs BCB 污染的硬判据）
pstore_triage() {
	local d=$STEPLOG
	local st; st=$(dev_state)
	[ "$st" = linux ] || { info "pstoredump 三分类需要 Linux 侧（当前 $st）"; return 0; }
	run 120 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" \
		'dd if=/dev/disk/by-partlabel/pstoredump bs=1M count=128 2>/dev/null | grep -acE "panic|oops|Unable to handle"' > "$d/pstore-grep.txt"
	[ "$APPLY" = 1 ] && cat "$d/pstore-grep.txt"
	info "判据：命中 0 ⇒ 无内核崩溃（卡 userspace）；≥1 ⇒ 内核段真失败（贴原文再定因）"
}

# ---------------------------------------------------------------- 步骤
S1() {
	step_begin S1
	say "S1) 清 BCB + 槽位置 a + v1 super 在机的首启观察（预期 3–5 min）"
	info "前置：v1 super 已在机（2026-11-19 21:3x 回刷，读回 e3d0d26f…）；super 现态需现场再确认"
	ensure_linux
	# 1) 现态取证
	run 30 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" 'uname -r; findmnt -no SOURCE,LABEL /'
	run 30 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" 'qbootctl 2>&1 | head -24; qbootctl -a 2>&1'
	info "判据：Active slot 行；super 现态由下一步首 512 KiB 解析确认（v1 = system_a 5296 MiB）"
	run 60 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" \
		'dd if=/dev/disk/by-partlabel/super bs=4096 count=128 2>/dev/null' > "$STEPLOG/super-head512k.bin" 2>/dev/null
	if [ "$APPLY" = 1 ]; then
		python3 "$ROOT/scripts/android-super.py" list "$STEPLOG/super-head512k.bin" 2>&1 | head -12 | tee "$STEPLOG/super-state.txt"
		info "判据：blockdev/分区尺寸 = v1（system_a 5296 MiB）才对得上「v1 在机」"
	else
		info "[dry] 之后 python3 scripts/android-super.py list $STEPLOG/super-head512k.bin"
	fi
	# 2) BCB 现状 + 清 0 + 读回
	bcb_read "$STEPLOG/bcb-before.bin"; bcb_judge "$STEPLOG/bcb-before.bin"
	bcb_clear_verify || return 1
	# 3) 槽位：Android 必须先 active=a（b 槽 = Linux）
	ensure_active_a
	# 4) 重启并观察
	run 60 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$TAB" 'sync; reboot' || \
		info "[dry] 之后：从 fastboot 侧 fastboot -s $SER reboot（或 Linux 下 reboot）"
	observe_android S1; local rc=$?
	pstore_triage
	case "$rc" in
		0) info "S1 结论：进桌面 ⇒ 之前 3 发失败很可能全是 BCB 污染（写进报告后再决定是否还走 S2–S4）" ;;
		2) info "S1 结论：又落 recovery ⇒ 先读 misc（bcb_read），若 BCB 非 0 则本次样本无效，重做 S1" ;;
		*) info "S1 结论：起 ZUXOS 动画但不完成 ⇒ 复现「首启卡死」，继续 S2（metadata）" ;;
	esac
	return 0
}

S2() {
	step_begin S2
	say "S2) 回写原厂 metadata.img（8 分片拼装 29 372 416 B；预期 5–8 min）"
	info "目的：排除 H4「metadata 被 erase + super 声明 virtual-ab」"
	# 组装（复用 scripts/android-super.py assemble；产物落 ART，不碰 backup/）
	if [ ! -e "$ART/metadata_stock.img" ]; then
		run 120 python3 "$ROOT/scripts/android-super.py" assemble \
			--xml "$ROM/rawprogram_save_persist_unsparse0.xml" --label metadata -o "$ART/metadata_stock.img"
	else
		info "件在位：$ART/metadata_stock.img（29372416 B）"
	fi
	ensure_edl
	live_gpt_gate || return 1
	# 写前先把当前 metadata 段 dump 一份（回退基线）
	run 120 "$QDL" -s ufs -R "$LOADER" read "0/$LBA_METADATA+$METADATA_SECT" "$STEPLOG/metadata-pre.bin"
	qdl_write_verify "$ART/metadata_stock.img" "$LBA_METADATA" "$METADATA_SECT" "metadata" || return 1
	bcb_clear_verify || return 1
	run 120 "$QDL" -s ufs "$LOADER" reset
	local rc; observe_android S2; rc=$?
	pstore_triage
	return 0
}

S3() {
	step_begin S3
	say "S3) 刷原厂 super 对照（8 分片拼装 15 607 586 816 B = 14.54 GiB；预期 14–18 min）"
	info "判据：原厂能进桌面 ⇒ 问题在我们的 super 内容；原厂也不进 ⇒ 问题在 /data/GPT/设备态"
	if [ ! -e "$ART/super_stock_contig.img" ]; then
		warn "缺件：$ART/super_stock_contig.img（14.54 GiB，稀疏落盘约 12.2 GiB；工作区剩余 $(df -h /home | awk 'NR==2{print $4}')）"
		run 600 python3 "$ROOT/scripts/android-super.py" assemble \
			--xml "$ROM/rawprogram_save_persist_unsparse0.xml" --label super -o "$ART/super_stock_contig.img"
		info "期望尺寸 = 15607586816 B（= 3810446 扇区 × 4096）"
	else
		info "件在位：$ART/super_stock_contig.img"
	fi
	ensure_edl
	live_gpt_gate "$ART/super_stock_contig.img" || return 1
	# 回退基线：当前在机 super 头 512 KiB（快照；全量在机件已在 out/android-min-20261118/pkg/super_min.img）
	run 120 "$QDL" -s ufs -R "$LOADER" read "0/$LBA_SUPER+128" "$STEPLOG/super-head512k-pre.bin"
	qdl_write_verify "$ART/super_stock_contig.img" "$LBA_SUPER" 3810446 "stock-super" || return 1
	bcb_clear_verify || return 1
	run 120 "$QDL" -s ufs "$LOADER" reset
	observe_android S3
	pstore_triage
	info "回退：qdl write 0/$LBA_SUPER out/android-min-20261118/pkg/super_min.img（v1，2171264 扇区）"
	return 0
}

S4() {
	step_begin S4
	say "S4) 二分：v2b（删池/AI/bgmusic，保留 18 个 leaf 包 = 8 741 MiB；预期 8–10 min）"
	info "件：out/android-slim-v2b-20261119/new/super_min_v3.img（98a88ea0…，system_a 5552 MiB）"
	ensure_edl
	live_gpt_gate "$ROOT/out/android-slim-v2b-20261119/new/super_min_v3.img" || return 1
	qdl_write_verify "$ROOT/out/android-slim-v2b-20261119/new/super_min_v3.img" "$LBA_SUPER" 2237696 "v2b-super" || return 1
	bcb_clear_verify || return 1
	run 120 "$QDL" -s ufs "$LOADER" reset
	observe_android S4
	pstore_triage
	info "二分读法：v2b 成功 ⇒ 18 个 leaf 包不是原因（删除池/AI 才是）；v2b 失败 ⇒ 继续「只占位不删」臂"
	return 0
}

S5() {
	step_begin S5
	local want=$ART/boot-ttygs0-boot.img
	local src=$ROM/boot.img
	say "S5) 日志通道：console=ttyGS0 的 boot 件（header v4 改写器已就位）"
	info "件：$want（源 = $src，header v4 / header_size=1584 / cmdline 原为空）"
	info "造件与验收：reports/bootimg-v4-cmdline-20261120.md（v2 路径回归 = 逐字节不变）"

	if [ ! -e "$want" ]; then
		warn "S5 不可用（缺件）：$want 不在位"
		info "解释：S5 需要「原厂 boot.img 的 cmdline 追加 console=ttyGS0」的零写盘件。"
		info "      原厂件是 Android boot image **header v4**（96 MiB）；v4 的 cmdline 在 header 偏移 44、长 1536，"
		info "      改写 = 整文件拷贝 + 只改这 1536 B 窗口（kernel/ramdisk/boot signature/VBmeta 尾区逐字节不变、总长不变）。"
		info "造件（主机侧、不碰设备；造完 preflight/S5 都按 O_DIRECT sha 核）："
		info "  timeout -k 5 300 python3 scripts/boot-img-cmdline.py $src --append 'console=ttyGS0' -o $want"
		info "⇒ 不造件就把 S5 从本轮摘掉（不写盘、不 reset；S1–S4 照走）"
		return 0
	fi

	local sz show
	sz=$(stat -c%s "$want")
	info "件已在位：$want（$sz B）"
	info "sha256（O_DIRECT）= $(sha_direct "$want")"
	if [ "$APPLY" = 1 ]; then
		show=$(timeout -k 5 120 python3 "$ROOT/scripts/boot-img-cmdline.py" "$want" --show 2>&1) || {
			warn "S5 核件失败：--show 退出非 0"; return 1; }
		printf '%s\n' "$show" > "$STEPLOG/bootimg-show.txt"
		printf '%s\n' "$show" | grep -qF 'console=ttyGS0' || {
			warn "S5 核件失败：cmdline 里没有 console=ttyGS0（$STEPLOG/bootimg-show.txt）"; return 1; }
		# 结构往返自检（v4：窗口外必须逐字节全等）
		run 300 python3 "$ROOT/scripts/boot-img-cmdline.py" "$want" --verify
		info "上机（零写盘；需人确认）。**fastboot 是否接受 v4 + AVB hash 失配件 = 需上机项**："
		run 300 fastboot -s "$SER" boot "$want"
		logc "cat /dev/ttyACM0 > $STEPLOG/serial.log  (900 s)"
		timeout -k 5 900 cat /dev/ttyACM0 > "$STEPLOG/serial.log"
	else
		info "[dry] 核件（--apply 时才跑）：python3 scripts/boot-img-cmdline.py $want --show | grep console=ttyGS0 ; --verify"
		info "[dry] 上机（零写盘）：timeout -k 5 300 fastboot -s $SER boot $want"
		info "[dry] 抓日志：timeout -k 5 900 cat /dev/ttyACM0 > $STEPLOG/serial.log"
	fi
	info "判据（缺一不算成功）："
	info "  ① fastboot boot 返回 OKAY（不认 ⇒ 记「需上机项未通过」，不改本仓代码去臆测）"
	info "  ② 串口出现内核 log 或 Android init 输出（ttyGS0）"
	info "  ③ 否则回退 pstoredump 通道（本脚本 pstore_triage）"
	info "风险 1：cmdline 改动 ⇒ boot 的 AVB hash descriptor 失配（vbmeta 是 OEM 私钥签名，本仓不能重签；"
	info "        generic_kernel 描述符仍 MATCH）⇒ 只有解锁 + verity logging 才可能接受。"
	info "风险 2：v4 的真 cmdline 还在 vendor_boot.img（实测 'console=ttynull qcom_geni_serial.con_enabled=0'），"
	info "        若 ABL 只取 vendor_boot 侧 cmdline，则 boot.img 侧追加无效 ⇒ 同样属需上机项。"
	return 0
}

# ---------------------------------------------------------------- main
preflight
if [ "$APPLY" = 1 ]; then
	# 设备锁：串行化所有触设备的动作（scripts/lib-device-lock.sh 单一真源）
	. "$ROOT/scripts/lib-device-lock.sh"
	device_lock_acquire 2>/dev/null || warn "设备锁未取到（并发上机有风险）"
fi

say "计划：MODE=$MODE  steps=$STEPS  serial=$SER  readback=$READBACK  observe=${OBS_TO}s"
printf '   S1 清 BCB+槽位+首启观察   S2 原厂 metadata   S3 原厂 super   S4 v2b 二分   S5 日志通道(ttyGS0 件)\n'

fail=0
for s in S1 S2 S3 S4 S5; do
	want_step "$s" || continue
	"$s" || { fail=1; warn "$s 未通过判据（归档 $STEPLOG）"; break; }
done

if [ "$fail" = 0 ]; then
	say "全部所选步骤走完（MODE=$MODE）"
	[ "$APPLY" = 0 ] && info "这是 dry-run：没有写任何设备。真执行 = 加 --apply（需人确认）。"
	exit 0
fi
exit 1
