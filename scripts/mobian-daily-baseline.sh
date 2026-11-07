#!/bin/bash
# mobian-daily-baseline.sh — 把 Debian/Mobian 目标根补齐到「日用可用」（幂等；主机侧驱动）
#
# 三件套（别混）：
#   rootfs/debian/daily-baseline.tsv   包清单（P0/P1 装，P2 只登记）
#   rootfs/debian/daily-baseline.sh    **配置**逻辑（sudo 组/NOPASSWD、locale、IM 自启、zram 门）——构建 chroot 与设备共用同一份
#   本脚本                              设备侧驱动：解析 tsv → apt-get → 推配置脚本并执行 → 复查
#
# 用法：
#   scripts/mobian-daily-baseline.sh              # 真跑（装 P0+P1 并配置）
#   scripts/mobian-daily-baseline.sh --check      # 只报告：缺哪些包 / 哪些配置项 MISS（不改设备）
#   scripts/mobian-daily-baseline.sh --list       # 只打印将被安装的包
#
# Env：TAB（缺省 root@192.168.7.1）、T（ssh 超时，缺省 8）
#
# 判据（--check 退出码 0 = 已达标）：
#   1) daily-baseline.tsv 的每个 P0/P1 包 dpkg 状态 = install ok installed
#   2) `daily-baseline.sh --check` 输出 MISS=0
#
# 纪律（.pi/AGENT-OPS.md）：设备写入走 scripts/device-lock.sh 串行；apt 只装不升级
# （`--no-install-*` 保持默认 recommends，但**不加** upgrade/dist-upgrade）；不动机器人内核/引导。
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
TSV=$ROOT/rootfs/debian/daily-baseline.tsv
CFG=$ROOT/rootfs/debian/daily-baseline.sh
TAB=${TAB:-root@192.168.7.1}
T=${T:-8}
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout="$T" -o ConnectionAttempts=1 -o BatchMode=yes -b 0 "$TAB")

MODE=run
case "${1:-}" in
	--check) MODE=check ;;
	--list)  MODE=list ;;
	-h|--help) sed -n '2,24p' "$0"; exit 0 ;;
esac

[ -f "$TSV" ] || { echo "缺 $TSV" >&2; exit 2; }
[ -f "$CFG" ] || { echo "缺 $CFG" >&2; exit 2; }

# P0+P1 包名（P2 只登记，不进安装）
mapfile -t PKGS < <(awk -F'\t' '$1 !~ /^#/ && $1 != "" && ($2 == "P0" || $2 == "P1") {print $1}' "$TSV" | sort -u)
mapfile -t P2 < <(awk -F'\t' '$1 !~ /^#/ && $1 != "" && $2 == "P2" {print $1}' "$TSV" | sort -u)
[ "${#PKGS[@]}" -gt 0 ] || { echo "tsv 解析出 0 个包（列是不是被空格破坏了？必须是 TAB）" >&2; exit 2; }

if [ "$MODE" = list ]; then
	printf '%s\n' "${PKGS[@]}"
	echo "# P2（只登记，不装）：${P2[*]:-无}" >&2
	exit 0
fi

echo "== 1) 设备可达性 =="
"${SSH[@]}" 'uname -r; . /etc/os-release; echo "$PRETTY_NAME"; id -un' || { echo "设备不可达（$TAB）" >&2; exit 3; }

echo "== 2) 缺失包盘点（P0+P1 共 ${#PKGS[@]} 个）=="
missing=$("${SSH[@]}" "bash -s" <<EOF
for p in ${PKGS[*]}; do
  s=\$(dpkg-query -W -f='\${Status}' "\$p" 2>/dev/null)
  [ "\$s" = "install ok installed" ] || echo "\$p"
done
EOF
)
missing=$(printf '%s\n' "$missing" | sed '/^$/d')
if [ -z "$missing" ]; then
	echo "  全部已安装"
else
	echo "  缺 $(printf '%s\n' "$missing" | wc -l) 个：$(printf '%s' "$missing" | tr '\n' ' ')"
fi

if [ "$MODE" = check ]; then
	echo "== 3) 配置项巡检（daily-baseline.sh --check）=="
	chk=$("$HERE/device-lock.sh" "${SSH[@]}" 'bash -s -- --check' < "$CFG" 2>/dev/null | tee /dev/stderr | grep -E '^结果: MISS=' | tail -1)
	rc=0
	[ -n "$missing" ] && rc=1
	case "$chk" in *"MISS=0"*) ;; *) rc=1 ;; esac
	echo ""
	if [ "$rc" = 0 ]; then echo "结果: 已达标（包齐 + 配置齐）"; else echo "结果: 未达标（见上）"; fi
	exit "$rc"
fi

echo "== 3) 安装缺失包（apt，--no-remove；不 upgrade）=="
if [ -n "$missing" ]; then
	"$HERE/device-lock.sh" "${SSH[@]}" "DEBIAN_FRONTEND=noninteractive apt-get install -y -q -o Dpkg::Options::=--force-confold $(printf '%s' "$missing" | tr '\n' ' ')" 2>&1 | tail -6 | sed 's/^/  /'
else
	echo "  跳过（无缺失）"
fi

echo "== 4) 配置（同一份 daily-baseline.sh）=="
"$HERE/device-lock.sh" "${SSH[@]}" 'bash -s' < "$CFG" 2>&1 | sed 's/^/  /'

echo "== 5) 复查 =="
rc=0
still=$("${SSH[@]}" "bash -s" <<EOF
for p in ${PKGS[*]}; do
  s=\$(dpkg-query -W -f='\${Status}' "\$p" 2>/dev/null)
  [ "\$s" = "install ok installed" ] || echo "\$p"
done
EOF
)
if [ -n "$(printf '%s' "$still" | sed '/^$/d')" ]; then
	echo "  FAIL 仍缺：$(printf '%s' "$still" | tr '\n' ' ')"; rc=1
else
	echo "  ok   包齐（${#PKGS[@]} 个）"
fi
chk=$("$HERE/device-lock.sh" "${SSH[@]}" 'bash -s -- --check' < "$CFG" 2>/dev/null | grep -E '^结果: MISS=' | tail -1)
echo "  配置巡检：${chk:-（无输出）}"
case "$chk" in *"MISS=0"*) ;; *) rc=1 ;; esac

echo ""
echo "结果: $([ "$rc" = 0 ] && echo '已达标（日用基线就绪）' || echo '未达标（见上）')"
exit "$rc"
