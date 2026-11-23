#!/bin/bash
# uefi-a-slot-prepare.sh — 让 **a 槽**能跑自研件（G1-29 flashed 形态的前置；幂等）
#
# 为什么需要它（2026-11-10 深夜定案）：
#   ABL 在 `BootLinux` 之后会 `Apply Overlay`，把 **`dtbo_<slot>`** 的 overlay 合进**我们自己的** DTB。
#   原厂 `dtbo_a` 是合法 Android DTBO（magic D7B7AB1E / 23.3 MB）⇒ 合进我们的 Linux DTB ⇒ **卡联想 logo**、
#   USB 不枚举、~10 s 后 ABL 放弃回落。`dtbo_b` 早在 2026-10-03 就写成全 0（「假 dtbo」）⇒「`_b` 一直好、`_a` 一直坏」。
#   这是项目第一天的坑（PITFALLS/sessions/01「假 dtbo 必须两个槽都写」、sessions/02 第 10 条），
#   2026-11-09/10 的 p60–p69 全部打在 `_a` 上故每发注定卡 logo。正文 reports/uefi-dtbo-a-rootcause-20261110.md。
#
# 做什么：
#   1) 首次运行把 `dtbo_a` 原厂件备份到 `backup/dtbo_a-pre-uefi-<日期>.img`（存在且 sha 一致则跳过）；
#   2) `dtbo_a` 写成 32 MiB 全 0（= 与 `dtbo_b` 同款「假 dtbo」）；
#   3) 写后**读回校验**（sha 必须等于全 0 文件的 sha）；
#   4) 打印回滚命令（恢复原厂 dtbo_a + 回 `_b` 日常）。
#   ⚠ 副作用：**Android 不再能从 a 槽启动**（Android 需要真 dtbo）。要回 Android 就先跑本脚本打印的回滚。
#
# 用法：
#   scripts/uefi-a-slot-prepare.sh --check     # 只报告状态（不写盘）
#   scripts/uefi-a-slot-prepare.sh             # 真做（备份 + 写 dtbo_a + 读回校验）
#   SER=HA2EXB0E scripts/uefi-a-slot-prepare.sh   # 目标已锁定（推荐）
#
# 之后刷件仍按单条 fastboot 命令（**不要**用脚本代跑一次刷多件）：
#   fastboot -s <SER> flash boot_a out/r21-sbstop-p69/uefi-preamble69-r1.img
#   fastboot -s <SER> set_active a
# 或直接：SER=<SER> scripts/uefi-flashed-trial.sh --part boot_a --image <件> --label <标签>
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DTBO_SIZE=33554432      # 32 MiB（= a/b 两槽 dtbo 分区大小）
BLANK_SHA=83ee47245398adee79bd9c0a8bc57b821e92aba10f5f9ade8a5d1fae4d8c4302   # 全 0 32 MiB
SER=${SER:-}; MODE=do
case "${1:-}" in
	--check) MODE=check;;
	-h|--help) sed -n '2,30p' "$0"; exit 0;;
	'') ;;
	*) echo "unknown arg: $1" >&2; exit 2;;
esac
. "$ROOT/scripts/lib-device-lock.sh"
. "$ROOT/scripts/lib-fastboot.sh"
device_lock_acquire
say() { echo "[$(date +%H:%M:%S)] $*"; }
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

BK=""   # 原厂 dtbo_a 备份路径（已是全 0 时不产生，回滚提示会显式说明）

# ---- 目标锁定：优先用 SER；未给则从 ssh 侧那一台拿不到，明确要求 ----
[ -n "$SER" ] || { say "需要显式 SER=<serial>（本机总线上可能有多台设备，禁止猜）"; exit 2; }

# ---- 1) 读现状（必须设备在 Linux；fastboot 模式下读不到分区内容）----
CUR=$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	"${TAB:-root@192.168.7.1}" 'sha256sum /dev/disk/by-partlabel/dtbo_a' 2>/dev/null | awk '{print $1}')
if [ -z "${CUR:-}" ]; then
	say "读不到 dtbo_a（设备不在 Linux）⇒ 先回 Linux（或 fastboot 里直接按脚本尾部命令操作）"
	exit 3
fi
say "dtbo_a 当前 sha256 = $CUR"
if [ "$CUR" = "$BLANK_SHA" ]; then
	say "已是全 0（= 假 dtbo）⇒ 无需改动"
	[ "$MODE" = check ] && { echo "STATUS=READY"; exit 0; }
else
	[ "$MODE" = check ] && { echo "STATUS=NEEDS_PREP（a 槽会被 Android DTBO overlay 卡 logo）"; exit 1; }
	# 2026-11-18 审计 R2 P1-11：回滚提示原来用通配 `dtbo_a-pre-uefi-*.img`，多份备份时会选错件。
	# 现在把**确切**路径写进 ROLLBACK.txt（含 sha），回滚只认它。
	BK="$ROOT/backup/dtbo_a-pre-uefi-$(date +%Y%m%d).img"
	if [ -f "$BK" ] && [ "$(sha_direct "$BK")" = "$CUR" ]; then
		say "备份已在：$BK（sha 一致，跳过备份）"
	else
		say "备份原厂 dtbo_a → $BK"
		timeout -k 5 180 ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no \
			-o UserKnownHostsFile=/dev/null "${TAB:-root@192.168.7.1}" \
			'dd if=/dev/disk/by-partlabel/dtbo_a bs=1M 2>/dev/null' > "$BK" || { say "备份失败"; exit 4; }
		[ "$(sha_direct "$BK")" = "$CUR" ] || { say "备份 sha 不一致（短读？）⇒ 放弃"; rm -f "$BK"; exit 4; }
		say "备份 OK（$DTBO_SIZE 字节）"
	fi
fi

# ---- 2) 进 fastboot（已在 fastboot 就跳过）----
fbd() { local f l; f=$(mktemp /tmp/fbd.XXXXXX); timeout -k 2 8 fastboot devices >"$f" 2>/dev/null
	l=$(awk 'NF{print $1}' "$f" | grep -x -- "$SER" || true); rm -f "$f"; [ -n "$l" ]; }
if fbd; then say "已在 fastboot"; else
	say "Linux → fastboot（软路径，PITFALLS #712）"
	. "$(dirname "$0")/lib-soft-bootloader.sh"
	SER="$SER" soft_to_bootloader 45 || true   # 成败由下方 fbd 轮询统一判
	for i in $(seq 1 30); do fbd && break; sleep 3; done
	fbd || { say "90 s 内没进 fastboot"; exit 5; }
fi

# ---- 3) 写假 dtbo + 读回 ----
BLANK=$(mktemp /tmp/dtbo-blank.XXXXXX); truncate -s "$DTBO_SIZE" "$BLANK"
[ "$(sha_direct "$BLANK")" = "$BLANK_SHA" ] || { say "全 0 件 sha 异常"; exit 6; }
say "flash dtbo_a = 32 MiB 全 0"
fbx flash dtbo_a "$BLANK"; rc=$?
say "$_FB_OUT"
rm -f "$BLANK"
[ "$rc" = 0 ] || { say "flash 失败 rc=$rc"; exit 7; }

say "回 Linux 读回校验（fastboot 里读不到分区内容）"
fbx reboot; say "$_FB_OUT"
up=0; for i in $(seq 1 60); do
	if timeout 4 ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${TAB:-root@192.168.7.1}" true 2>/dev/null; then up=1; break; fi
	sleep 3
done
[ "$up" = 1 ] || {
	say "重启后 SSH 未起（设备可能停在 fastboot 或卡 logo）"
	say "回滚（可直接复制执行）：fastboot -s $SER flash dtbo_a ${BK:-<本次未改 dtbo_a，无需回滚>} && fastboot -s $SER set_active b"
	say "  备份件：$BK（sha $(sha_direct "$BK")）"
	echo "STATUS=ROLLBACK_NEEDED"; exit 8; }
NEW=$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	"${TAB:-root@192.168.7.1}" 'sha256sum /dev/disk/by-partlabel/dtbo_a' 2>/dev/null | awk '{print $1}')
say "dtbo_a 读回 = $NEW"
if [ "$NEW" = "$BLANK_SHA" ]; then say "✅ a 槽已就绪（假 dtbo 在机）"; echo "STATUS=READY"; else
	say "✗ 读回不一致（期望 $BLANK_SHA）"; echo "STATUS=VERIFY_FAIL"; exit 9; fi

RB="$ROOT/backup/uefi-a-slot-ROLLBACK-$SER.txt"
{
  echo "# $SER 的 a 槽回滚配方（由 scripts/uefi-a-slot-prepare.sh 于 $(date -Is) 生成）"
  echo "# 回滚只认下面这些**确切**路径；不要用通配符（多份备份会选错件）"
  echo "DTBO_A_BACKUP=$BK"
  echo "DTBO_A_BACKUP_SHA=$(sha_direct "$BK")"
  echo "BOOT_A_BACKUP=$ROOT/backup/boot_a-pre-uefi-20261108.img"
  echo "BOOT_A_BACKUP_SHA=$(sha_direct "$ROOT/backup/boot_a-pre-uefi-20261108.img")"
  echo "# 执行："
  echo "fastboot -s $SER flash dtbo_a ${BK:-<本次未改 dtbo_a，无需回滚>}"
  echo "fastboot -s $SER flash boot_a $ROOT/backup/boot_a-pre-uefi-20261108.img"
  echo "fastboot -s $SER set_active b"
} > "$RB"
cat <<EOF

回滚（恢复 a 槽 Android / b 槽日常）；配方已写 $RB：
  fastboot -s $SER flash dtbo_a ${BK:-<本次未改 dtbo_a，无需回滚>}
  fastboot -s $SER flash boot_a $ROOT/backup/boot_a-pre-uefi-20261108.img
  fastboot -s $SER set_active b
EOF
