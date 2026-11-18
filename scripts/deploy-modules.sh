#!/bin/bash
# deploy-modules.sh — 把 `<构建树>/lib/modules/<UTS>` 部署到设备 `/lib/modules/<UTS>`
#                     的**唯一统一实现**（script-redundancy-audit S15 收口，2026-11-13）。
#
# 背景：同一动作（把 .ko 弄到设备 /lib/modules/<UTS>）曾有三种互不兼容的实现：
#   - scripts/mod-loop.sh:73            tar 管道（无备份、无读回）
#   - scripts/m1-73-modules-overlay.sh  只拷 2 个 .ko 进 cpio overlay（不同产物形态，保留）
#   - scripts/deploy-camera-modules.sh  相机 tar（自备传输/无备份）
# 硬约束（AGENTS.md 项目记忆）：RAM 起新核前必须先部署整套 /lib/modules/<UTS>，否则所有 =m 驱动 defer。
#
# 统一口径（本脚本）：
#   1) 本地 `make modules_install` 到临时 INSTALL_MOD_PATH（--from 树推导 UTS，或显式 --uts）；
#   2) 打 tar.gz 推到设备 /var/tmp；部署前把设备上旧目录**打包备份**到 /var/tmp/modules-backup-<UTS>-<ts>.tar.gz；
#   3) 解包 + `depmod -a <UTS>`；**读回校验**：设备上 .ko 数量与本地 staging 一致、
#      抽样 sha256 一致（对 tar 内清单）；
#   4) 失败即报非零退码，不回滚（备份留在 /var/tmp 供人工回滚，避免脚本里再写一次设备）。
#
# 用法：
#   scripts/deploy-modules.sh --from <kernel树> [--uts <UTS>] [--modules <mod1,mod2>]
#                             [--target root@192.168.7.1] [--no-verify]
#   KDIR=build/daily scripts/deploy-modules.sh        # 等价 --from $KDIR
#
# 两种「不直连设备」的形态（B13 §2，2026-11-17：把 4 处重复的传输实现收进这里）：
#   --stage <dir>     只在本地做 staging：`make modules_install` 到 <dir> 并打 tar，**不碰设备**；
#                     打印 `STAGE_UTS=<UTS>` / `STAGE_TAR=<tar>` / `STAGE_KO=<n>`
#   --bundle <tar>    部署**已打好的** tar.gz（不做本地构建；需 --uts）；
#                     deploy-camera-modules.sh / mod-loop.sh 都单向调用它 ⇒ 传输/备份/读回只有一份实现
#
# 纪律：写设备侧；先 scripts/device-lock.sh 串行（调用方负责，或加 --lock 让本脚本自取）。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FROM=""; UTS=""; MODULES=""; TARGET=${TAB:-root@192.168.7.1}; VERIFY=1; LOCK=0
STAGE_DIR=""; BUNDLE=""
while [ $# -gt 0 ]; do
	case "$1" in
		--from) FROM=$2; shift 2 ;;
		--uts) UTS=$2; shift 2 ;;
		--modules) MODULES=$2; shift 2 ;;
		--target) TARGET=$2; shift 2 ;;
		--stage) STAGE_DIR=$2; shift 2 ;;
		--bundle) BUNDLE=$2; shift 2 ;;
		--no-verify) VERIFY=0; shift ;;
		--lock) LOCK=1; shift ;;
		*) echo "unknown arg $1" >&2; exit 2 ;;
	esac
done
[ -n "$STAGE_DIR" ] && [ -n "$BUNDLE" ] && { echo "--stage 与 --bundle 互斥" >&2; exit 2; }
if [ -n "$BUNDLE" ]; then
	[ -f "$BUNDLE" ] || { echo "--bundle 文件不存在: $BUNDLE" >&2; exit 2; }
	BUNDLE=$(cd "$(dirname "$BUNDLE")" && pwd)/$(basename "$BUNDLE")
else
	[ -n "$FROM" ] || FROM=${KDIR:-}
	[ -n "$FROM" ] || { echo "usage: $0 --from <kernel树> [--uts <UTS>] [--target user@host] | --stage <dir> | --bundle <tar> --uts <UTS>" >&2; exit 2; }
	FROM=$(cd "$FROM" && pwd)
	. "$ROOT/scripts/env-build.sh"
	KDIR="$FROM"
	# UTS：显式 > --from 树推导（与 mod-loop.sh 同法）
	[ -n "$UTS" ] || UTS=$(make -s -C "$KDIR" ARCH=arm64 kernelrelease)
fi
[ -n "$UTS" ] || { echo "[deploy-modules] 无法确定 UTS（--bundle/--stage 模式必须显式 --uts）" >&2; exit 2; }
[ -n "$STAGE_DIR" ] && { mkdir -p "$STAGE_DIR"; STAGE_DIR=$(cd "$STAGE_DIR" && pwd); }

SSH="ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no $TARGET"

echo "[deploy-modules] from=$FROM uts=$UTS target=$TARGET"

# 1) staging：全量 modules_install（或白名单子集打包）；--bundle 直接用已打好的 tar
STAGE=$(mktemp -d)
TAR=$(mktemp --suffix=.tar.gz)
trap 'rm -rf "$STAGE"' EXIT
if [ -n "$BUNDLE" ]; then
	STAGE=""
	TAR=$BUNDLE
	local_n=$(tar tzf "$TAR" | grep -c '\.ko' || true)
	echo "[deploy-modules] bundle=$TAR uts=$UTS ko=$local_n"
elif [ -n "$STAGE_DIR" ]; then
	# --stage：只产出，不写设备（传输只能再走本脚本 --bundle，不允许调用方自写一份）
	make -C "$KDIR" ARCH=arm64 INSTALL_MOD_PATH="$STAGE_DIR" modules_install >/dev/null
	local_n=$(find "$STAGE_DIR/lib/modules/$UTS" -name '*.ko*' 2>/dev/null | wc -l)
	OUT_TAR=$STAGE_DIR/modules-$UTS.tar.gz
	( cd "$STAGE_DIR/lib/modules/$UTS" && find . -name '*.ko*' -print0 | tar czf "$OUT_TAR" --null -T - ) || true
	[ -s "$OUT_TAR" ] || { echo "[deploy-modules] --stage 产物为空" >&2; exit 1; }
	echo "STAGE_UTS=$UTS"
	echo "STAGE_TAR=$OUT_TAR"
	echo "STAGE_KO=$local_n"
	exit 0
elif [ -n "$MODULES" ]; then
	# 白名单：modules_install 后只取列出的 .ko（保持与 m1-73 overlay 相同的「最小集」用法）
	make -C "$KDIR" ARCH=arm64 INSTALL_MOD_PATH="$STAGE" modules_install >/dev/null
	( cd "$STAGE/lib/modules/$UTS" && find . -name '*.ko*' -print0 | tar czf "$TAR" --null -T - ) || true
	echo "[deploy-modules] 白名单模式：$(tar tzf "$TAR" | wc -l) 个 .ko"
else
	make -C "$KDIR" ARCH=arm64 INSTALL_MOD_PATH="$STAGE" modules_install >/dev/null
	local_n=$(find "$STAGE/lib/modules/$UTS" -name '*.ko*' | wc -l)
	( cd "$STAGE/lib/modules/$UTS" && find . -name '*.ko*' -print0 | tar czf "$TAR" --null -T - ) || true
	echo "[deploy-modules] 全量：本地 $local_n 个 .ko"
fi
[ -s "$TAR" ] || { echo "[deploy-modules] staging tar 为空，中止" >&2; exit 1; }

# 2) 推 tar + 备份设备侧旧目录（幂等：有就备份，没有就跳过）
$SSH "cat > /var/tmp/modules-deploy.tar.gz" < "$TAR"
$SSH "mkdir -p /lib/modules/$UTS"
$SSH "if [ -d /lib/modules/$UTS ] && [ -n \"\$(ls -A /lib/modules/$UTS 2>/dev/null)\" ]; then
	ts=\$(date -u +%Y%m%dT%H%M%SZ)
	tar czf /var/tmp/modules-backup-$UTS-\$ts.tar.gz -C /lib/modules \$(basename $UTS) 2>/dev/null || true
	echo \"backup=/var/tmp/modules-backup-$UTS-\$ts.tar.gz\"
else
	echo backup=none
fi"

# 3) 解包 + depmod
#   2026-11-18 审计 R4 P0-3：旧版 `tar xzf -C /lib/modules/$UTS` **直接解包进在用目录**，
#   中断即半部署（缺模块/ABI 不齐），而项目铁律是「RAM 起新核前先部署整套 /lib/modules/<UTS>」。
#   改：先解到同盘 staging → 校验 UTS/vermagic → 原子 rename 顶替（旧目录已备份成 tar）。
#   另加 UTS 门：设备 `uname -r` 与要部署的 UTS 不同时默认拒绝（DEPLOY_ANY_UTS=1 才放行）。
dev_uts=$($SSH 'uname -r' 2>/dev/null | tr -d '\r')
if [ -n "$dev_uts" ] && [ "$dev_uts" != "$UTS" ]; then
	if [ "${DEPLOY_ANY_UTS:-0}" = 1 ]; then
		echo "[deploy-modules] WARN 设备在跑 $dev_uts，部署的是 $UTS（DEPLOY_ANY_UTS=1 放行）"
	else
		echo "[deploy-modules] REFUSE 设备在跑 $dev_uts != 目标 UTS $UTS（要预部署下一版内核请显式 DEPLOY_ANY_UTS=1）" >&2
		exit 2
	fi
fi

# vermagic 门（抽样 2 个 .ko，避免把错 ABI 的树装上设备）
vm_local=$(tar xzOf "$TAR" "$(tar tzf "$TAR" | grep '\.ko$' | head -1)" 2>/dev/null | strings -a | grep -m1 '^vermagic=' || true)
if [ -n "$vm_local" ]; then
	case "$vm_local" in
		*"$UTS"*) : ;;
		*) echo "[deploy-modules] REFUSE tar 里的 $vm_local 与目标 UTS $UTS 不符" >&2; exit 2 ;;
	esac
	echo "[deploy-modules] $vm_local"
fi

$SSH "set -e
rm -rf /lib/modules/.new-$UTS && mkdir -p /lib/modules/.new-$UTS
tar xzf /var/tmp/modules-deploy.tar.gz -C /lib/modules/.new-$UTS
n=\$(find /lib/modules/.new-$UTS -name '*.ko*' | wc -l)
[ \"\$n\" -gt 0 ] || { echo '[deploy-modules] staging 解包后 0 个 .ko，中止（原目录未动）' >&2; exit 1; }
# 原子顶替：同一文件系统内两次 rename，中间不存在「半棵树」
if [ -d /lib/modules/$UTS ]; then mv /lib/modules/$UTS /lib/modules/.old-$UTS.tmp; fi
mv /lib/modules/.new-$UTS /lib/modules/$UTS
rm -rf /lib/modules/.old-$UTS.tmp
depmod -a '$UTS'
rm -f /var/tmp/modules-deploy.tar.gz
echo '[deploy-modules] installed (atomic swap)'"

# 4) 读回校验
if [ "$VERIFY" = 1 ]; then
	local_n=${local_n:-$(tar tzf "$TAR" | grep -c '\.ko')}
	dev_n=$($SSH "find /lib/modules/$UTS -name '*.ko*' 2>/dev/null | wc -l")
	# 抽样 3 个 .ko 比对 sha（本地侧直接从 tar 取 ⇒ --bundle/--stage 都不依赖 staging 目录）
	sample=$(tar tzf "$TAR" | grep '\.ko$' | shuf -n3 --random-source=<(yes))
	ok=1
	for m in $sample; do
		lsha=$(tar xzOf "$TAR" "$m" | sha256sum | awk '{print $1}')
		dsha=$($SSH "sha256sum /lib/modules/$UTS/$m 2>/dev/null | awk '{print \$1}'")
		if [ "$lsha" != "$dsha" ]; then echo "[deploy-modules] SHA MISMATCH: $m" >&2; ok=0; fi
	done
	echo "[deploy-modules] verify: local=$local_n device=$dev_n sample_sha_ok=$ok"
	[ "$dev_n" -ge "$local_n" ] || { echo "[deploy-modules] 设备侧 .ko 数少于本地——部署不完整" >&2; exit 1; }
	[ "$ok" = 1 ] || exit 1
fi
echo "[deploy-modules] DONE uts=$UTS"
