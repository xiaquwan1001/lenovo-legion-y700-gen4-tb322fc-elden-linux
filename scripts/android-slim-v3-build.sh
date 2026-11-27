#!/bin/bash
# RETIRED 2026-11-27：v3 super 已写入并 EDL 读回校验通过（一次性构建器），配方与判据在 reports/android-slim-v3-20261119.md；替代/复核：该报告 §7/§8；可复核：reports/disk-audit-20261126.md
# android-slim-v3-build.sh — 安卓「彻底精简 + 无占位 + 可共存」system/super 构建器（主机侧，需 root）
#
# v3 = v2-B（删全部 /system/preinstall 池与 etc/AI/bgmusic）+ 一批「无用功能」leaf 包；
#       三件 v1 缺的动作：① 空目录占位（File#list() 得空数组而不是 null）② 按包名裁桌面默认布局
#       ③ 重建 ext4 后 e2fsck/round-trip 自检。**不含 root（KernelSU 刷完系统后单独补装）**。
#
# 与 v1/v2 的关键差异（判据来自 reports/android-slim-v2-20261119.md）：
#   v1 直接删 /system/preinstall ⇒ 首启 PreInstallPackageHelper 无输入 + launcher.db 47 条占位布局 = 卡动画。
#   v3 保留空目录 + 裁剪布局 + 删掉布局指向的包，三者一致。
#
# 用法（必须 root）：
#   sudo bash scripts/android-slim-v3-build.sh                # 全流程
#   sudo bash scripts/android-slim-v3-build.sh --verify-only  # 只重跑自检
# 环境变量：
#   SRC_SYSTEM=out/android-min-avb-20261118/parts/system_a.img（原厂 11.43 GiB，只读）
#   LANE=out/android-slim-v3-20261119
#   MKFS_FEATURES=（见下；与 v1 一致：无 journal、-m 0）
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC_SYSTEM=${SRC_SYSTEM:-$ROOT/out/android-min-avb-20261118/parts/system_a.img}
PARTS=${PARTS:-$ROOT/out/android-min-avb-20261118/parts}
LANE=${LANE:-$ROOT/out/android-slim-v3-20261119}
WORK=$LANE/work/system_v3
NEW=$LANE/new
LOG=$LANE/build.log
PARSER=$ROOT/scripts/android-apk-pkgname.py
TRIM=$ROOT/scripts/android-launcher-db-trim.py
SUPER_TOOL=$ROOT/scripts/android-super.py
LPMAKE=${LPMAKE:-/home/xuqianhui/bin/lpmake}
SRC_V2_DROP=$ROOT/out/android-slim-v2-20261119/drop-pkgs-B.txt
MNT=$LANE/work/.mnt-system
MKFS_FEATURES=${MKFS_FEATURES:-"-O ^has_journal,^resize_inode,extent,ext_attr,dir_index,filetype,sparse_super,large_file,huge_file,uninit_bg,dir_nlink,extra_isize -I 256 -m 0"}
SUPER_DEV_SIZE=23622320128   # super 分区 22.00 GiB（GPT LBA 90504..5857671，4096 B/扇区）
SUPER_ALIGN=524288
SUPER_ALIGN_OFF=491520

# 整目录删除（相对镜像根）。空目录占位单独处理（preinstall / etc/AI）。
# EXTRA_LEAF=1（默认）：连 18 个无用 leaf 包一起删；=0：只删池/AI/bgmusic/动画（= v2-B 变体，用于二分）。
BASE_DROP=(
	system/etc/AI
	system/etc/bgmusic
	system/media/bootanimation_mcdonalds.zip
	system/media/shutdownanimation_mcdonalds.zip
)
LEAF_DROP=(
	# —— 无用功能 leaf 包（不删任何启动链/桌面/设置/权限/Provider/相机）——
	system/priv-app/ZUIEpos              # POS/销售点服务（373.7 MiB，单 apk）
	system/priv-app/ZuiNewBrowser        # 联想浏览器
	system/priv-app/LFHTianjiaoTablet    # 天骄教育
	system/priv-app/ZUILenovoLevision    # 乐视视频
	system/priv-app/ZuiAILens            # AI 识屏（模型已随 etc/AI 删除）
	system/priv-app/ZuiAIStylus          # AI 手写（同上）
	system/priv-app/ZuiGameHelper        # 游戏助手
	system/priv-app/ZuiStandbyMode       # 待机模式卡片
	system/priv-app/LenovoWhatsNew       # 新品推荐
	system/priv-app/LenovoLoggerPannel   # 日志面板
	system/priv-app/LenovoOTA            # OTA（自签/已 root 镜像无法走 OTA，留着只占位）
	system/priv-app/XiaotianTrigger      # 小天才联动
	system/priv-app/TabletPushOut        # 推送推广
	system/priv-app/TabletUE             # 平板用户体验上报
	system/priv-app/ZuiXlog              # 日志采集
	system/priv-app/EngineeringCode      # 工程码
	system/priv-app/UDSEngine            # UDS 引擎（推广/服务端下发）
)
if [ "${EXTRA_LEAF:-1}" = "1" ]; then DROP_DIRS=("${BASE_DROP[@]}" "${LEAF_DROP[@]}"); else DROP_DIRS=("${BASE_DROP[@]}"); fi
# 只删子项、保留空目录（调用方 File#list() 返回空数组）
DROP_CHILDREN=(system/preinstall system/etc/AI)

say() { printf '\n=== %s\n' "$*" | tee -a "$LOG"; }
step() { printf '  [%s] %s\n' "$1" "$2" | tee -a "$LOG"; }
die() { printf 'FATAL  %s\n' "$*" | tee -a "$LOG" >&2; exit 1; }
need_root() { [ "$(id -u)" = 0 ] || die "需要 root（loop 挂载 / 属主与 xattr 保真）：sudo bash $0 $*"; }

VERIFY_ONLY=0
[ "${1:-}" = "--verify-only" ] && VERIFY_ONLY=1

mkdir -p "$LANE" "$NEW"
: > "$LOG"

# ---------------------------------------------------------------- 0. 输入
[ -f "$SRC_SYSTEM" ] || die "缺原厂 system：$SRC_SYSTEM"
for p in vendor_a product_a system_ext_a vendor_dlkm_a system_dlkm_a odm_a; do
	[ -f "$PARTS/$p.img" ] || die "缺 $PARTS/$p.img"
done
[ -x "$LPMAKE" ] || die "缺 lpmake：$LPMAKE"
SUPER_SRC_BYTES=$(stat -c%s "$SRC_SYSTEM")

DROP_N=${DROP_N:-0}
if [ "$VERIFY_ONLY" = 0 ]; then
	need_root

	# ------------------------------------------------------------ 1. 解出原厂 system（rsync + 排除）
	say "1. 解出原厂 system（只读 loop 挂载 + rsync -aHAX，排除已定删除项）"
	mkdir -p "$MNT" "$WORK" "$LANE/work"
	if [ ! -f "$WORK/.extract.done" ]; then
		mount -o loop,ro "$SRC_SYSTEM" "$MNT" || die "mount 失败：$SRC_SYSTEM"
		step run "收集被删目录的包名（裁布局用）：$LANE/pkgs-dropped.tsv"
		: > "$LANE/pkgs-dropped.tsv"
		for d in "${DROP_DIRS[@]}"; do
			[ -d "$MNT/$d" ] || continue
			python3 "$PARSER" --dir "$MNT/$d" >> "$LANE/pkgs-dropped.tsv" 2>>"$LOG"
		done
		for d in "${DROP_CHILDREN[@]}"; do
			[ -d "$MNT/$d" ] || continue
			python3 "$PARSER" --dir "$MNT/$d" >> "$LANE/pkgs-dropped.tsv" 2>>"$LOG"
		done
		# 池目录里没有 apk 时（只有安装包/配置文件）用 v2 的包清单兜底
		step ok "包名 $(wc -l < "$LANE/pkgs-dropped.tsv") 条（含 pool 与 leaf 包）"

		EXCL=()
		for d in "${DROP_DIRS[@]}"; do EXCL+=(--exclude="/$d"); done
		for d in "${DROP_CHILDREN[@]}"; do EXCL+=(--exclude="/$d/*"); done
		step run "rsync -aHAX --numeric-ids ${EXCL[*]}"
		rsync -aHAX --numeric-ids --delete "${EXCL[@]}" "$MNT/" "$WORK/" || { umount "$MNT"; die "rsync 失败"; }
		umount "$MNT" && rmdir "$MNT" || die "umount 失败"
		touch "$WORK/.extract.done"
		step ok "解出完成：$(du -sh --exclude=.extract.done "$WORK" | cut -f1)"
	else
		step skip "已解出（$WORK/.extract.done）"
	fi

	# ------------------------------------------------------------ 2. 删除 + 空目录占位
	say "2. 删除整目录 + 空目录占位"
	for d in "${DROP_DIRS[@]}"; do
		[ -e "$WORK/$d" ] && { rm -rf "$WORK/$d"; step ok "删除 $d"; } || step skip "$d 不在（已删）"
	done
	for d in "${DROP_CHILDREN[@]}"; do
		mkdir -p "$WORK/$d"
		find "$WORK/$d" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
		chown root:root "$WORK/$d"; chmod 755 "$WORK/$d"
		# 本机没装 attr 包（无 setfattr/getfattr）⇒ 用 python 的 os.setxattr 打标签；
		# 缺 security.selinux 的目录在设备上会是 unlabeled，system_server 访问可能被拒。
		LAB=$(python3 -c "import os,sys; os.setxattr(sys.argv[1],'security.selinux',b'u:object_r:system_file:s0\\x00'); print(os.getxattr(sys.argv[1],'security.selinux'))" "$WORK/$d" 2>&1)
		[ -n "$LAB" ] && step ok "空目录占位 $d（0 子项，$LAB）" || die "空目录 $d 打 selinux 标签失败"
	done

	# ------------------------------------------------------------ 3. 按包名裁桌面默认布局
	say "3. 裁 /system/etc/launcher.db 与 launcher_2layer.db"
	grep -h -v '^FAIL\|^#' "$LANE/pkgs-dropped.tsv" 2>/dev/null | cut -f1 | sort -u > "$LANE/drop-pkgs-v3.txt"
	[ -f "$SRC_V2_DROP" ] && grep -v '^#' "$SRC_V2_DROP" >> "$LANE/drop-pkgs-v3.txt"
	sort -u "$LANE/drop-pkgs-v3.txt" -o "$LANE/drop-pkgs-v3.txt"
	DROP_N=$(grep -c . "$LANE/drop-pkgs-v3.txt")
	step ok "待删包名 $DROP_N 条（$LANE/drop-pkgs-v3.txt）"
	for db in launcher.db launcher_2layer.db; do
		src=$WORK/system/etc/$db
		[ -f "$src" ] || { step skip "$db 不在"; continue; }
		python3 "$TRIM" --db "$src" --drop-pkgs "$LANE/drop-pkgs-v3.txt" \
			--out "$LANE/$db.v3" >> "$LOG" 2>&1 || die "裁 $db 失败"
		sqlite3 "$LANE/$db.v3" 'pragma integrity_check' | tee -a "$LOG"
		chown root:root "$LANE/$db.v3"; chmod 644 "$LANE/$db.v3"
		cp -a "$LANE/$db.v3" "$src"
		step ok "$db 已裁并装回（$(sqlite3 "$src" 'select count(*) from favorites') 行 favorites）"
	done

	# ------------------------------------------------------------ 4. 体积 + mkfs
	say "4. 体积核算 + 重建 ext4"
	CONTENT=$(du -sb "$WORK" | cut -f1)
	MKFS_MIB=$(python3 -c "import math,sys; print(int(math.ceil(($CONTENT*1.10+96*1048576)/1048576/16.0))*16)")
	SUPER_MIB=$(python3 -c "import math; print(int(math.ceil((1466+993+571+141+12+2+$MKFS_MIB+1)/16.0))*16)")
	step ok "内容 $((CONTENT/1048576)) MiB → system_a.img ${MKFS_MIB} MiB，super ${SUPER_MIB} MiB"
	rm -f "$NEW/system_a.img"
	mke2fs -q -t ext4 -b 4096 $MKFS_FEATURES -L system -d "$WORK" "$NEW/system_a.img" "${MKFS_MIB}M" \
		|| die "mke2fs 失败（size ${MKFS_MIB}M 可能太小）"
	e2fsck -fn "$NEW/system_a.img" >/dev/null 2>&1 || { e2fsck -fn "$NEW/system_a.img" 2>&1 | tail -8 | tee -a "$LOG"; die "e2fsck 报错"; }
	step ok "system_a.img $(stat -c%s "$NEW/system_a.img") B；e2fsck clean"
	echo "$MKFS_MIB" > "$LANE/system_mib.txt"
else
	MKFS_MIB=$(cat "$LANE/system_mib.txt" 2>/dev/null) || die "缺 $LANE/system_mib.txt（先跑全流程）"
	SUPER_MIB=$(python3 -c "import math; print(int(math.ceil((1466+993+571+141+12+2+$MKFS_MIB+1)/16.0))*16)")
	step skip "--verify-only：不重建镜像"
fi

# ---------------------------------------------------------------- 5. lpmake 重打 super
say "5. lpmake 重打 super（7×_a，单 extent，virtual-ab，-d auto 只写实占长度）"
rm -f "$NEW/super_min_v3.img"
# 本机 lpmake（AOSP 源码自编）分区尺寸**只吃字节**（带 M 后缀报 Partition must have a valid size），
# 且要 -d auto 才能出「实占」长度的镜像（给具体 22 GiB 会写满整个分区）；v1 件即此口径。
declare -A PSZ
PSZ[system_a]=$(( MKFS_MIB * 1048576 ))
for p in vendor_a product_a system_ext_a vendor_dlkm_a system_dlkm_a odm_a; do
	b=$(stat -c%s "$PARTS/$p.img")
	PSZ[$p]=$(( ((b + 1048575) / 1048576) * 1048576 ))
done
"$LPMAKE" -d auto -m 65536 -s 3 --alignment=524288 --alignment-offset=491520 --super-name=super --virtual-ab \
	-g qti_dynamic_partitions_a:23618125824 \
	-p system_a:readonly:${PSZ[system_a]}:qti_dynamic_partitions_a -i system_a=$NEW/system_a.img \
	-p vendor_a:readonly:${PSZ[vendor_a]}:qti_dynamic_partitions_a -i vendor_a=$PARTS/vendor_a.img \
	-p product_a:readonly:${PSZ[product_a]}:qti_dynamic_partitions_a -i product_a=$PARTS/product_a.img \
	-p system_ext_a:readonly:${PSZ[system_ext_a]}:qti_dynamic_partitions_a -i system_ext_a=$PARTS/system_ext_a.img \
	-p vendor_dlkm_a:readonly:${PSZ[vendor_dlkm_a]}:qti_dynamic_partitions_a -i vendor_dlkm_a=$PARTS/vendor_dlkm_a.img \
	-p system_dlkm_a:readonly:${PSZ[system_dlkm_a]}:qti_dynamic_partitions_a -i system_dlkm_a=$PARTS/system_dlkm_a.img \
	-p odm_a:readonly:${PSZ[odm_a]}:qti_dynamic_partitions_a -i odm_a=$PARTS/odm_a.img \
	-o "$NEW/super_min_v3.img" 2>&1 | tee -a "$LOG" || die "lpmake 失败"
# 注：上面两行 `Invalid sparse file format at header magic` 是 lpmake 探测 -i 件是否 sparse 的回退提示，不是错误。
SIZE=$(stat -c%s "$NEW/super_min_v3.img"); SECT=$(( (SIZE + 4095) / 4096 ))
step ok "super_min_v3.img $SIZE B（$(( SIZE/1048576 )) MiB，$SECT 扇区 ≤ 22 GiB 分区）"

# ---------------------------------------------------------------- 6. 自检
say "6. 自检（placeholders / 删除项 / 保留项 / super 三槽 / round-trip）"
FAIL=0
ck() { if eval "$2"; then step ok "$1"; else step FAIL "$1"; FAIL=1; fi; }
ck "system_a 布局：/system/preinstall 存在且为空" \
	"[ \$(debugfs -R 'ls -l /system/preinstall' "$NEW/system_a.img" 2>/dev/null | grep -c '^ *[0-9]') -le 2 ]"
ck "system_a 布局：/system/etc/AI 存在且为空" \
	"[ \$(debugfs -R 'ls -l /system/etc/AI' "$NEW/system_a.img" 2>/dev/null | grep -c '^ *[0-9]') -le 2 ]"
for d in /system/preinstall /system/etc/AI; do
	ck "$d 在镜像里带 security.selinux" \
		"debugfs -R 'ea_list $d' '$NEW/system_a.img' 2>/dev/null | grep -q 'system_file'"
done
for d in "${DROP_DIRS[@]}"; do
	case " ${DROP_CHILDREN[*]} " in *" $d "*) continue ;; esac   # 空目录占位项「存在但为空」另判
	ck "已删 $d" "[ ! -e '$WORK/$d' ]"
done
for p in system/build.prop system/framework system/apex system/etc/permissions system/etc/selinux \
         system/priv-app/ZuiLauncher system/priv-app/ZuiPermissionController system/priv-app/ZuiCoreService system/app/ZuiFileManager; do
	ck "保留 $p" "[ -e '$WORK/$p' ]"
done
for db in launcher.db launcher_2layer.db; do
	ck "$db 不引用已删包" \
		"! python3 '$ROOT/scripts/android-launcher-db-check.py' --db '$LANE/$db.v3' --drop '$LANE/drop-pkgs-v3.txt' | grep -q VIOLATION"
done
for slot in 0 1 2; do
	ck "super metadata slot $slot 可读" "python3 '$SUPER_TOOL' list '$NEW/super_min_v3.img' --slot $slot >/dev/null"
done
mkdir -p "$LANE/verify"
python3 "$SUPER_TOOL" extract "$NEW/super_min_v3.img" "$LANE/verify" --partition system_a --sparse >> "$LOG" 2>&1 \
	|| die "lpunpack system_a 失败"
ck "round-trip：super 里的 system_a == 新 system_a.img" "cmp -s '$LANE/verify/system_a.img' '$NEW/system_a.img'"

# ---------------------------------------------------------------- 7. 清单
say "7. 清单与 sha256（★两次独立读回，不一致即判本机读路径不稳，见 hw-stability 规则 12）"
stable_sha() { # $1 = 文件；两次哈希一致才返回，否则返回 1
	local a b
	a=$(sha256sum "$1" | cut -d' ' -f1); b=$(sha256sum "$1" | cut -d' ' -f1)
	[ "$a" = "$b" ] || { printf '  [FAIL] %s 两次哈希不一致：%s != %s\n' "$1" "$a" "$b" | tee -a "$LOG" >&2; return 1; }
	printf '%s  %s\n' "$a" "$(basename "$1")"
}
( cd "$NEW" && { stable_sha system_a.img && stable_sha super_min_v3.img ; } > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS ) \
	|| die "sha256 不稳定（疑似本机读路径/内存问题）——停在这里，先按 ~/hw-stability/AGENTS.md 取证"
{
	printf '# MANIFEST — 安卓精简 v3（TB322FC / elden，无 root，可共存）\n\n'
	printf '- 生成：%s；脚本 `scripts/android-slim-v3-build.sh`\n' "$(date -Is)"
	printf '- 输入：`%s`（%s B，原厂未改）\n' "$SRC_SYSTEM" "$SUPER_SRC_BYTES"
	printf '- 删除：/system/preinstall/*（空目录占位）、/system/etc/AI/*（空目录占位）、/system/etc/bgmusic、mcdonalds 动画、%s 个无用 leaf 包\n' "$((${#DROP_DIRS[@]}-4))"
	printf '- 桌面：launcher.db / launcher_2layer.db 按包名裁剪（%s 个包名，见 drop-pkgs-v3.txt）\n' "$DROP_N"
	printf '- 体积：system_a.img %s MiB；super_min_v3.img %s MiB（%s 扇区）\n\n' "$MKFS_MIB" "$(( SIZE/1048576 ))" "$SECT"
	printf '| 文件 | 字节 | sha256 |\n|---|---|---|\n'
	( cd "$NEW" && stat -c '%n %s' system_a.img super_min_v3.img | while read -r n s; do
		printf '| %s | %s | `%s…` |\n' "$n" "$s" "$(sha256sum "$n" | cut -c1-16)"
	done )
	printf '\n## 刷写（只动 super，不碰 Linux 的 linux17 / boot_b）\n'
	printf '```\nqdl write 0 90504 %s   # LBA 90504..5857671 = super 22 GiB\n' "$NEW/super_min_v3.img"
	printf 'qdl read 0 90504 %s /tmp/rb.img && sha256sum /tmp/rb.img %s\n' "$SECT" "$NEW/super_min_v3.img"
	printf 'fastboot -w && fastboot reboot     # 只擦 userdata+metadata（Android 的 /data），不碰 linux17\n'
	printf '```\n'
	printf '\n## 回退\n- v1（已上机两次 boot_completed=1）：`out/android-min-20261118/pkg/super_min.img` → 同样写回 90504\n'
	printf '- 原厂：`backup/official-rom-15.10.259/super_*.img`\n'
} > "$NEW/MANIFEST.md"

if [ "$FAIL" != 0 ]; then
	say "自检有 FAIL，未交付"; exit 1
fi
say "完成：$NEW/super_min_v3.img"
ls -la "$NEW"