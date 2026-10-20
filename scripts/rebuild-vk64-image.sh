#!/bin/bash
# rebuild-vk64-image.sh — 重建 Q24/N5b 台架镜像 out/boot-elden-vk64.img
#
# 为什么需要它：换机后 out/*.img 未随迁（reports/migration-rebuild-audit-20261017.md），
#   而 scripts/n5b-vk64-death-rate.sh 依赖该镜像；旧脚本 scripts/q24-rebuild-arms.sh 已丢失。
#   本脚本把 vk64 的重放配方固化，避免配方再次随机器消失。
#
# ★ 身份必须逐字命中（否则设备上 /lib/modules/7.2.0-debug-vk64-gd02658e63cf6 里
#   1497 个 .ko 全部 vermagic 失配 ⇒ 相机栈加载不起来 ⇒ N5b 测的就不是 Q24）：
#     UTS_RELEASE = 7.2.0-debug-vk64-gd02658e63cf6
#   达成方式 = vk64 树（tag vk64 = d02658e63，干净工作树）+ LOCALVERSION=-vk64
#              + CONFIG_LOCALVERSION="-debug" + LOCALVERSION_AUTO=y。
#
# 单变量纪律（与 reports/q24-n5-vk64-death-reproduced-20261015.md 对齐）：
#   内核 = vk64 树（build/vk83-tree @ d02658e63）
#   config = patches/config-vk40-bringup（sha256 a383cdb9…，与 vk64 manifest 一致）
#   DTB = 该树自己的（含 H2 cambist→MX 绑定，与历史致死镜像逐字同源）
#   ramdisk = 显式指定（默认 out/rootfs-vk127.cpio.gz；历史那份 initramfs-full-elden 已丢）
#
# 用法：
#   scripts/rebuild-vk64-image.sh              # 全量：编内核 + 打包 + manifest
#   scripts/rebuild-vk64-image.sh --check-only # 只做前置检查与身份推演（零编译）
#   JOBS=28 scripts/rebuild-vk64-image.sh
#
# 退出码：0=成功；1=前置检查失败；2=构建失败；3=身份不匹配（产物已生成但不应用）
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
KDIR=${KDIR:-$ROOT/build/vk83-tree}
VERSION=${VERSION:-vk64}
IMG=$ROOT/out/boot-elden-$VERSION.img
CONFIG=$ROOT/patches/config-vk40-bringup
EXPECT_UTS=7.2.0-debug-vk64-gd02658e63cf6
EXPECT_CONFIG_SHA=a383cdb99dfee7a9f7a21c915541af05edf6efa3d2bb7cda552b270a263cbf4d
EXPECT_KERNEL_COMMIT=d02658e63cf607e71231b077ddd73f42408463c0
RAMDISK=${RAMDISK:-$ROOT/out/rootfs-vk127.cpio.gz}
LOG=$ROOT/logs/rebuild-vk64-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$ROOT/logs"
exec > >(tee -a "$LOG") 2>&1

echo "### rebuild-vk64 $(date '+%F %T')  log=$LOG"
fail() { echo "❌ $*" >&2; exit 1; }

# ---------- 1. 前置检查 ----------
[ -d "$KDIR" ] || fail "缺内核树 $KDIR（换机后需重新准备 vk64 树：tag vk64 = d02658e63）"
git -C "$KDIR" rev-parse --verify vk64 >/dev/null 2>&1 || fail "$KDIR 里没有 tag vk64"
[ "$(git -C "$KDIR" rev-parse vk64^{commit})" = "$EXPECT_KERNEL_COMMIT" ] \
	|| fail "tag vk64 指向 $(git -C "$KDIR" rev-parse --short vk64^{commit})，期望 ${EXPECT_KERNEL_COMMIT:0:12}"
DIRTY=$(git -C "$KDIR" status --porcelain | grep -v '^?? \.config$' | wc -l)
[ "$DIRTY" -eq 0 ] || fail "$KDIR 工作树脏（$DIRTY 项）⇒ UTS 会带 -dirty ⇒ 模块失配。先 git stash/clean"
[ "$(git -C "$KDIR" rev-parse HEAD)" = "$EXPECT_KERNEL_COMMIT" ] \
	|| echo "⚠️  HEAD=$(git -C "$KDIR" rev-parse --short HEAD) ≠ vk64；构建将落在此 HEAD（若非 vk64 请检查）"

[ -f "$CONFIG" ] || fail "缺 config $CONFIG"
CSHA=$(sha256sum "$CONFIG" | cut -d' ' -f1)
[ "$CSHA" = "$EXPECT_CONFIG_SHA" ] || fail "config sha256=$CSHA ≠ 期望 $EXPECT_CONFIG_SHA（配方已漂移）"
grep -q '^CONFIG_ARCH_QCOM=y' "$CONFIG" || fail "config 缺 CONFIG_ARCH_QCOM=y（#162 死内核判据）"
grep -q '^CONFIG_LOCALVERSION="-debug"' "$CONFIG" || fail "config 的 CONFIG_LOCALVERSION 不是 \"-debug\""
grep -q '^CONFIG_LOCALVERSION_AUTO=y' "$CONFIG" || fail "config 缺 CONFIG_LOCALVERSION_AUTO=y（无 -g<sha> 后缀 ⇒ UTS 失配）"

[ -f "$RAMDISK" ] || fail "缺 ramdisk $RAMDISK"

# 工具链健康门（2026-10-19 实受）：gcc-15-aarch64-linux-gnu 15.2.0-16ubuntu1cross1
#   在 -O>=1 时对**任意**文件 ICE（in scev_initialize, tree-scalar-evolution.cc:3017），
#   连 `int main(void){return 0;}` 都过不了 —— 表现为内核构建里四处 ICE。
#   -O0 正常、native gcc-15 正常、clang 21 cross 正常 ⇒ 是 cross 包自身坏了，不是源码/配置。
TC=${CROSS_COMPILE:-aarch64-linux-gnu-}
printf 'int main(void){return 0;}\n' > /tmp/.elden-tc-probe.c
if ! ${TC}gcc -O2 -c /tmp/.elden-tc-probe.c -o /tmp/.elden-tc-probe.o 2>/tmp/.elden-tc-probe.err; then
	if grep -q 'internal compiler error' /tmp/.elden-tc-probe.err; then
		fail "交叉编译器在 -O2 下 ICE（$(grep -m1 -o 'internal compiler error.*' /tmp/.elden-tc-probe.err)）
    ⇒ 工具链坏了，不是本仓库问题。可选修法：
      ① sudo apt-get install --reinstall -y gcc-15-aarch64-linux-gnu cpp-15-aarch64-linux-gnu
      ② sudo apt-get install -y gcc-14-aarch64-linux-gnu  （然后 CROSS_COMPILE=aarch64-linux-gnu-14- 重跑）
      ③ 零 sudo 备选：make LLVM=1（clang 21 + ld.lld 已装，但会引入编译器差异，慎用）"
	fi
	fail "交叉编译器不可用：${TC}gcc -O2 编译 hello 失败（见 /tmp/.elden-tc-probe.err）"
fi
echo "✅ 工具链健康：${TC}gcc -O2 可编译（$(${TC}gcc -dumpversion)）"
echo "✅ 前置检查通过：tree=$KDIR@vk64  config_sha=${CSHA:0:8}  ramdisk=$RAMDISK"
echo "   目标 UTS = $EXPECT_UTS"

if [ "${1:-}" = "--check-only" ]; then
	echo "(--check-only：不编译、不打包)"
	exit 0
fi

# ---------- 2. 编内核 ----------
cp -f "$CONFIG" "$KDIR/.config"
echo "-- 编译 Image.gz + dtbs（LOCALVERSION=-vk64）"

# 工作树完整性门（2026-10-19 事故；2026-10-20 定性更正）：本机存在**内存侧位翻转**——
# 磁盘字节正确，但页缓存副本被翻转；症状 = 随机 ICE / 段错误 / ld 报 `bad reloc symbol index`。
# verify-tree-integrity.py 已能区分 CACHE（页缓存，不算失败）与 CORRUPT（磁盘真坏）。
# 更强的门 = kbuild-sanity.sh（树完整性 + 多轮页缓存污染率 + 工具链探针）。
if ! python3 "$ROOT/scripts/verify-tree-integrity.py" "$KDIR" --allow-dirty -q; then
	fail "工作树有**磁盘真损坏**文件（上面已列出）⇒ 先 `git -C $KDIR checkout -- <文件>` 修复再编。\n   注意：若报的是 CACHE 而非 CORRUPT，那是页缓存翻位，本项不判失败。"
fi
if ! bash "$ROOT/scripts/kbuild-sanity.sh" "$KDIR" --before --rounds "${SANITY_ROUNDS:-2}" --allow-dirty; then
	fail "构建前体检未过（内存位翻转 / 工具链异常）⇒ 本次构建不可信，先修环境"
fi

# 重试环：交叉 gcc 在本机会偶发 ICE/段错误（同一文件重编必过，-O2 hello 探测正常），
# 不是源码问题；make 是增量的，重跑会从断点继续。若 ld 指名某个 .o 坏，则删掉重编它。
BUILD_OK=0
for attempt in 1 2 3 4; do
	[ "$attempt" -gt 1 ] && echo "   ↻ 第 $attempt 轮（上轮中断点续编）"
	BLOG=/tmp/.rebuild-vk64-round$attempt.log
	if (
		export ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE:-ccache aarch64-linux-gnu-}" \
			CC="${CC:-ccache aarch64-linux-gnu-gcc}" HOSTCC="${HOSTCC:-ccache gcc}" \
			KBUILD_BUILD_USER=elden KBUILD_BUILD_HOST=y700 \
			CCACHE_DIR="${CCACHE_DIR:-$HOME/.cache/ccache-elden}"
		timeout -k 30 "${BUILD_TIMEOUT:-5400}" make -C "$KDIR" -j"${JOBS:-$(nproc)}" LOCALVERSION=-vk64 Image.gz dtbs
	) >"$BLOG" 2>&1; then BUILD_OK=1; tail -6 "$BLOG"; break; fi
	tail -6 "$BLOG"
	# 定位 ld 指名的坏对象 / 编译坏对象，删掉让下一轮重编
	BAD=$(grep -oE "[A-Za-z0-9_./+-]+\.o(\([^)]*\))?" "$BLOG" \
		| grep -vE '^(scripts/|/usr/)' | sort -u \
		| while read -r o; do [ -f "$KDIR/$o" ] && echo "$o"; done)
	if [ -n "$BAD" ]; then
		echo "   隔离可疑对象：$(echo $BAD)"
		for o in $BAD; do rm -f "$KDIR/$o"; done
	fi
	sleep 5
done
[ "$BUILD_OK" -eq 1 ] || fail "编译失败（4 轮均未过，末轮日志 $BLOG）"

KIMG=$KDIR/arch/arm64/boot/Image.gz
DTB=$KDIR/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
[ -f "$KIMG" ] && [ -f "$DTB" ] || fail "编译产物缺失"

# 符号守卫（#162）：死内核能编过但不能点屏
for s in gcc_sm8750 msm_dsi_host_bonded_cmd_trigger rpmh; do
	grep -q "$s" "$KDIR/System.map" || fail "System.map 缺 $s ⇒ 死内核（ARCH_QCOM 丢失），不要打包"
done
echo "✅ 符号守卫通过"

# 构建后再验一次（本机存在内存位翻转，编译期间也可能发生）
if ! python3 "$ROOT/scripts/verify-tree-integrity.py" "$KDIR" --allow-dirty -q; then
	fail "构建期间工作树出现**磁盘真损坏** ⇒ 本镜像不可信，丢弃并重跑"
fi
if ! bash "$ROOT/scripts/kbuild-sanity.sh" "$KDIR" --after --rounds "${SANITY_ROUNDS:-2}" --allow-dirty; then
	fail "构建后体检未过（页缓存翻位 / 工具链）⇒ 本镜像不可信，丢弃并重跑"
fi

# ---------- 3. 身份核对 ----------
UTS=$(make -s -C "$KDIR" ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}" \
	LOCALVERSION=-vk64 kernelrelease 2>/dev/null | tr -d '\r')
echo "-- 树侧 kernelrelease = $UTS"
if [ "$UTS" != "$EXPECT_UTS" ]; then
	echo "❌ 身份不匹配：期望 $EXPECT_UTS"
	echo "   常见原因：tree 不干净(-dirty)、HEAD 不是 vk64、LOCALVERSION 没带上、tag 缺失"
	KSTATE=3
else
	echo "✅ 身份命中 $EXPECT_UTS"
	KSTATE=0
fi

# ---------- 4. 打包 + manifest ----------
echo "-- 打包（build-boot.sh，ramdisk=$RAMDISK）"
# LOCALVERSION 必须传下去：build-boot.sh 内的 build-manifest 用它算 kernel_release，
# 否则 manifest 会把 UTS 记成不带 -vk64 的样子（与镜像不符，事后无从对账）。
KDIR="$KDIR" VERSION="$VERSION" RAMDISK="$RAMDISK" LOCALVERSION="-vk64" \
	CMDLINE_EXTRA="${CMDLINE_EXTRA-elden_nocamera=1}" \
	bash "$ROOT/scripts/build-boot.sh" || fail "打包失败"
[ -f "$IMG" ] || fail "打包后缺 $IMG"


echo
echo "### 产物"
ls -la "$IMG" 2>/dev/null
echo "  image_sha256   = $(sha256sum "$IMG" | cut -d' ' -f1)"
echo "  kernel_sha256  = $(sha256sum "$KIMG" | cut -d' ' -f1)   （历史 vk64 = 60b683e1787598ff…，不要求相等：编译器/时间戳可变）"
echo "  dtb_sha256     = $(sha256sum "$DTB" | cut -d' ' -f1)    （历史 vk64 = 386cc9bd5d243425…）"
if [ "$KSTATE" -ne 0 ]; then
	echo "❌ 身份不匹配 ⇒ 不要用于 N5b（模块会全部失配）"; exit 3
fi
echo "✅ 就绪：可跑 scripts/n5b-vk64-death-rate.sh 5"
exit 0
